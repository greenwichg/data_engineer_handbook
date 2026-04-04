# PySpark Implementation: Waterfall Chart Data Preparation

## Problem Statement

Waterfall charts (also called bridge charts) are common in financial reporting to show how an initial value is affected by a series of positive and negative changes to arrive at a final value. Preparing the underlying data requires computing running contributions and cumulative totals. This is a practical interview topic because it combines window functions with conditional logic in a business-relevant context.

Given a dataset of revenue changes by category, prepare the data needed to render a waterfall chart, including start values, positive/negative contributions, and running cumulative totals.

### Sample Data

```
+-----------+----------+----------+
| category  | q1_rev   | q2_rev   |
+-----------+----------+----------+
| Product A |  500000  |  550000  |
| Product B |  300000  |  280000  |
| Product C |  200000  |  250000  |
| Product D |  150000  |  120000  |
| Product E |   80000  |  110000  |
+-----------+----------+----------+
```

### Expected Output

**Waterfall chart data (Q1 to Q2 bridge):**

| step_order | label         | type     | value  | cumulative |
|------------|---------------|----------|--------|------------|
| 0          | Q1 Total      | total    | 1230000| 1230000    |
| 1          | Product A     | increase | 50000  | 1280000    |
| 2          | Product C     | increase | 50000  | 1330000    |
| 3          | Product E     | increase | 30000  | 1360000    |
| 4          | Product B     | decrease | -20000 | 1340000    |
| 5          | Product D     | decrease | -30000 | 1310000    |
| 6          | Q2 Total      | total    | 1310000| 1310000    |

---

## Method 1: DataFrame API with Window Functions

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("WaterfallChartData") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data: revenue by product for two periods
data = [
    ("Product A", 500000, 550000),
    ("Product B", 300000, 280000),
    ("Product C", 200000, 250000),
    ("Product D", 150000, 120000),
    ("Product E",  80000, 110000),
]

columns = ["category", "q1_rev", "q2_rev"]
df = spark.createDataFrame(data, columns)

# Step 1: Compute the change per category
changes = df.withColumn("change", F.col("q2_rev") - F.col("q1_rev")) \
    .withColumn("change_type",
        F.when(F.col("change") > 0, "increase")
         .when(F.col("change") < 0, "decrease")
         .otherwise("unchanged")
    )

print("=== Category Changes ===")
changes.show()

# Step 2: Compute totals
q1_total = df.agg(F.sum("q1_rev")).collect()[0][0]
q2_total = df.agg(F.sum("q2_rev")).collect()[0][0]

# Step 3: Build waterfall steps
# Sort: increases first (largest first), then decreases (largest absolute first)
waterfall_steps = changes.select(
    F.col("category").alias("label"),
    F.col("change").alias("value"),
    F.col("change_type").alias("type"),
).withColumn("sort_key",
    # Increases first (sorted desc by value), then decreases (sorted desc by value, i.e., least negative first)
    F.when(F.col("type") == "increase", F.col("value") * -1)  # negate so desc becomes first
     .otherwise(F.col("value") * -1 + 10000000)  # put decreases after increases
)

waterfall_steps = waterfall_steps.orderBy("sort_key")

# Step 4: Add start and end total rows
start_row = spark.createDataFrame([("Q1 Total", q1_total, "total", -999999999)],
                                   ["label", "value", "type", "sort_key"])
end_row = spark.createDataFrame([("Q2 Total", q2_total, "total", 999999999)],
                                 ["label", "value", "type", "sort_key"])

full_waterfall = start_row.unionByName(waterfall_steps).unionByName(end_row) \
    .orderBy("sort_key")

# Step 5: Add step order and cumulative total
w = Window.orderBy("sort_key")
result = full_waterfall \
    .withColumn("step_order", F.row_number().over(w) - 1) \
    .withColumn("cumulative",
        F.when(F.col("type") == "total", F.col("value"))
         .otherwise(F.lit(q1_total) + F.sum(
             F.when(F.col("type") != "total", F.col("value")).otherwise(0)
         ).over(Window.orderBy("sort_key").rowsBetween(Window.unboundedPreceding, Window.currentRow)))
    ) \
    .select("step_order", "label", "type", "value", "cumulative")

print("=== Waterfall Chart Data ===")
result.show(truncate=False)
```

## Method 2: Generic Waterfall Builder Function

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("WaterfallGeneric") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("Product A", 500000, 550000),
    ("Product B", 300000, 280000),
    ("Product C", 200000, 250000),
    ("Product D", 150000, 120000),
    ("Product E",  80000, 110000),
]

columns = ["category", "q1_rev", "q2_rev"]
df = spark.createDataFrame(data, columns)


def build_waterfall(df, category_col, before_col, after_col, start_label, end_label):
    """
    Build waterfall chart data from a before/after comparison DataFrame.

    Args:
        df: DataFrame with categories and two numeric period columns
        category_col: column name for the category labels
        before_col: column name for the starting period values
        after_col: column name for the ending period values
        start_label: label for the starting total bar
        end_label: label for the ending total bar

    Returns:
        DataFrame with columns: step_order, label, bar_type, value,
        bar_start, bar_end (for rendering the waterfall)
    """
    # Compute changes
    changes = df.select(
        F.col(category_col).alias("label"),
        (F.col(after_col) - F.col(before_col)).alias("value"),
    ).withColumn("bar_type",
        F.when(F.col("value") > 0, "increase")
         .when(F.col("value") < 0, "decrease")
         .otherwise("unchanged")
    ).filter(F.col("value") != 0)  # Skip unchanged

    # Get totals
    totals = df.agg(
        F.sum(before_col).alias("start_total"),
        F.sum(after_col).alias("end_total"),
    ).collect()[0]
    start_total = totals["start_total"]
    end_total = totals["end_total"]

    # Order: increases descending, then decreases descending (least negative first)
    ordered = changes.withColumn("sort_priority",
        F.when(F.col("bar_type") == "increase", 0).otherwise(1)
    ).orderBy("sort_priority", F.abs(F.col("value")).desc())

    # Add row numbers for ordering
    w = Window.orderBy("sort_priority", F.abs(F.col("value")).desc())
    ordered = ordered.withColumn("step_order", F.row_number().over(w))

    # Compute running cumulative from start_total
    w_cum = Window.orderBy("step_order") \
        .rowsBetween(Window.unboundedPreceding, Window.currentRow)

    ordered = ordered.withColumn("cumulative", F.lit(start_total) + F.sum("value").over(w_cum))

    # Add bar_start and bar_end for rendering
    ordered = ordered.withColumn("bar_start",
        F.col("cumulative") - F.when(F.col("value") > 0, F.col("value")).otherwise(0)
    ).withColumn("bar_end",
        F.col("cumulative") + F.when(F.col("value") < 0, F.abs(F.col("value"))).otherwise(0)
    )

    # Build start and end rows
    start_row = spark.createDataFrame(
        [(0, start_label, "total", start_total, 0.0, float(start_total))],
        ["step_order", "label", "bar_type", "value", "bar_start", "bar_end"]
    )

    max_step = ordered.agg(F.max("step_order")).collect()[0][0]
    end_row = spark.createDataFrame(
        [(max_step + 1, end_label, "total", end_total, 0.0, float(end_total))],
        ["step_order", "label", "bar_type", "value", "bar_start", "bar_end"]
    )

    # Select final columns and union
    body = ordered.select("step_order", "label", "bar_type", "value",
                          "bar_start", "bar_end")

    result = start_row.unionByName(body).unionByName(end_row) \
        .orderBy("step_order")

    return result


waterfall = build_waterfall(df, "category", "q1_rev", "q2_rev",
                            "Q1 Total Revenue", "Q2 Total Revenue")

print("=== Waterfall Chart Data (with bar coordinates) ===")
waterfall.show(truncate=False)
```

## Method 3: Spark SQL Approach

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("WaterfallSQL") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("Product A", 500000, 550000),
    ("Product B", 300000, 280000),
    ("Product C", 200000, 250000),
    ("Product D", 150000, 120000),
    ("Product E",  80000, 110000),
]

columns = ["category", "q1_rev", "q2_rev"]
df = spark.createDataFrame(data, columns)
df.createOrReplaceTempView("revenue")

result = spark.sql("""
    WITH totals AS (
        SELECT SUM(q1_rev) AS q1_total, SUM(q2_rev) AS q2_total
        FROM revenue
    ),
    changes AS (
        SELECT
            category AS label,
            (q2_rev - q1_rev) AS value,
            CASE
                WHEN q2_rev > q1_rev THEN 'increase'
                WHEN q2_rev < q1_rev THEN 'decrease'
                ELSE 'unchanged'
            END AS bar_type,
            CASE
                WHEN q2_rev >= q1_rev THEN 0
                ELSE 1
            END AS sort_group,
            ABS(q2_rev - q1_rev) AS abs_value
        FROM revenue
        WHERE q2_rev != q1_rev
    ),
    ordered_changes AS (
        SELECT
            label, value, bar_type,
            ROW_NUMBER() OVER (ORDER BY sort_group, abs_value DESC) AS step_order
        FROM changes
    ),
    waterfall_body AS (
        SELECT
            step_order,
            label,
            bar_type,
            value,
            (SELECT q1_total FROM totals)
                + SUM(value) OVER (ORDER BY step_order
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                AS cumulative
        FROM ordered_changes
    ),
    start_row AS (
        SELECT 0 AS step_order, 'Q1 Total' AS label, 'total' AS bar_type,
               q1_total AS value, q1_total AS cumulative
        FROM totals
    ),
    end_row AS (
        SELECT
            (SELECT MAX(step_order) + 1 FROM waterfall_body) AS step_order,
            'Q2 Total' AS label, 'total' AS bar_type,
            q2_total AS value, q2_total AS cumulative
        FROM totals
    )
    SELECT * FROM start_row
    UNION ALL
    SELECT * FROM waterfall_body
    UNION ALL
    SELECT * FROM end_row
    ORDER BY step_order
""")

print("=== Waterfall Chart Data (SQL) ===")
result.show(truncate=False)
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Waterfall chart** | Visualizes how positive/negative changes bridge from a start to an end value |
| **Running cumulative** | Each bar starts where the previous bar ended |
| **Bar coordinates** | `bar_start` and `bar_end` define the vertical position of each floating bar |
| **Sorting convention** | Typically increases shown first (largest to smallest), then decreases |
| **Total bars** | Start and end bars are grounded at zero (full height from baseline) |
| **Change classification** | Each component is labeled as increase, decrease, or total |

## Interview Tips

1. **Understand the visual**: A waterfall chart has total bars (grounded) and floating bars (contribution steps). The data prep is about computing the floating bar start/end positions.

2. **Sorting matters**: The conventional ordering is all increases (largest first), then all decreases (largest absolute first). Some variants preserve the original category order.

3. **Watch for rounding**: In financial data, always ensure the Q2 total bar matches the sum of Q1 total plus all changes. Floating-point issues can cause discrepancies.

4. **Multiple periods**: For multi-period waterfalls, you can chain the logic (e.g., Q1 -> Q2 -> Q3 -> Q4) by computing changes between consecutive periods.

5. **Common extension**: Adding subtotals at intermediate points (e.g., after all increases, show a subtotal bar before showing decreases).
