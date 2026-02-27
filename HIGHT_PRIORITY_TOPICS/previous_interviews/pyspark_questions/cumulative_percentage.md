# PySpark Implementation: Cumulative Percentage and Distribution

## Problem Statement

Given a dataset of product sales, calculate the **cumulative percentage of total sales** for each product when sorted by sales in descending order. This is used for **Pareto analysis** (80/20 rule) — identifying which products contribute to 80% of revenue. This question tests your knowledge of window functions, aggregation, and analytical thinking.

### Sample Data

```
product_id  product_name  total_sales
P001        Laptop        50000
P002        Phone         35000
P003        Tablet        20000
P004        Headphones    12000
P005        Charger       8000
P006        Case          5000
P007        Cable         3000
P008        Screen Guard  2000
```

### Expected Output

| product_name | total_sales | sales_rank | pct_of_total | cumulative_pct | pareto_group |
|-------------|-------------|------------|-------------|----------------|--------------|
| Laptop      | 50000       | 1          | 37.04       | 37.04          | Top 80%      |
| Phone       | 35000       | 2          | 25.93       | 62.96          | Top 80%      |
| Tablet      | 20000       | 3          | 14.81       | 77.78          | Top 80%      |
| Headphones  | 12000       | 4          | 8.89        | 86.67          | Remaining    |
| Charger     | 8000        | 5          | 5.93        | 92.59          | Remaining    |
| Case        | 5000        | 6          | 3.70        | 96.30          | Remaining    |
| Cable       | 3000        | 7          | 2.22        | 98.52          | Remaining    |
| Screen Guard| 2000        | 8          | 1.48        | 100.00         | Remaining    |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, round as spark_round, \
    row_number, when, lit
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("CumulativePercentage").getOrCreate()

# Sample data
data = [
    ("P001", "Laptop", 50000),
    ("P002", "Phone", 35000),
    ("P003", "Tablet", 20000),
    ("P004", "Headphones", 12000),
    ("P005", "Charger", 8000),
    ("P006", "Case", 5000),
    ("P007", "Cable", 3000),
    ("P008", "Screen Guard", 2000)
]

columns = ["product_id", "product_name", "total_sales"]
df = spark.createDataFrame(data, columns)

# Step 1: Calculate the grand total of all sales
grand_total = df.agg(spark_sum("total_sales")).collect()[0][0]

# Step 2: Add percentage of total for each product
df_pct = df.withColumn(
    "pct_of_total",
    spark_round((col("total_sales") / lit(grand_total)) * 100, 2)
)

# Step 3: Define window ordered by sales descending
window_sales = Window.orderBy(col("total_sales").desc())

# Step 4: Add rank and cumulative sum of percentages
df_cumulative = df_pct.withColumn("sales_rank", row_number().over(window_sales)) \
    .withColumn(
        "cumulative_pct",
        spark_round(
            spark_sum("pct_of_total").over(
                window_sales.rowsBetween(Window.unboundedPreceding, Window.currentRow)
            ), 2
        )
    )

# Step 5: Add Pareto classification (Top 80% vs Remaining)
df_pareto = df_cumulative.withColumn(
    "pareto_group",
    when(col("cumulative_pct") <= 80, "Top 80%").otherwise("Remaining")
)

# Display results
df_pareto.select("product_name", "total_sales", "sales_rank",
                 "pct_of_total", "cumulative_pct", "pareto_group") \
    .orderBy("sales_rank").show(truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Calculate Grand Total
- **What happens:** Sums all sales values: 50000 + 35000 + 20000 + 12000 + 8000 + 5000 + 3000 + 2000 = **135000**
- **Output:** `grand_total = 135000`

### Step 2: Add Percentage of Total
- **What happens:** Each product's sales as a percentage of grand total.
- **Output (df_pct):**

  | product_id | product_name | total_sales | pct_of_total |
  |-----------|-------------|-------------|-------------|
  | P001      | Laptop      | 50000       | 37.04       |
  | P002      | Phone       | 35000       | 25.93       |
  | P003      | Tablet      | 20000       | 14.81       |
  | P004      | Headphones  | 12000       | 8.89        |
  | P005      | Charger     | 8000        | 5.93        |
  | P006      | Case        | 5000        | 3.70        |
  | P007      | Cable       | 3000        | 2.22        |
  | P008      | Screen Guard| 2000        | 1.48        |

  **Calculation:** Laptop = (50000 / 135000) * 100 = 37.04%

### Step 3: Window Specification
- **What happens:** Orders by `total_sales` descending, so cumulative sum starts from the highest-selling product.

### Step 4: Add Rank and Cumulative Percentage
- **What happens:** Running sum of `pct_of_total` in descending sales order.
- **Output (df_cumulative):**

  | product_name | total_sales | sales_rank | pct_of_total | cumulative_pct |
  |-------------|-------------|------------|-------------|----------------|
  | Laptop      | 50000       | 1          | 37.04       | 37.04          |
  | Phone       | 35000       | 2          | 25.93       | 62.96          |
  | Tablet      | 20000       | 3          | 14.81       | 77.78          |
  | Headphones  | 12000       | 4          | 8.89        | 86.67          |
  | Charger     | 8000        | 5          | 5.93        | 92.59          |
  | Case        | 5000        | 6          | 3.70        | 96.30          |
  | Cable       | 3000        | 7          | 2.22        | 98.52          |
  | Screen Guard| 2000        | 8          | 1.48        | 100.00         |

  **Calculation:**
  - Row 1: 37.04
  - Row 2: 37.04 + 25.93 = 62.96
  - Row 3: 62.96 + 14.81 = 77.78
  - Row 4: 77.78 + 8.89 = 86.67

### Step 5: Pareto Classification
- **What happens:** Products with cumulative_pct <= 80 are classified as "Top 80%".
- **Result:** Laptop, Phone, and Tablet make up ~78% of sales (the top 37.5% of products drive ~78% of revenue — close to the Pareto principle).

---

## Alternative: Using percent_rank() and cume_dist()

```python
from pyspark.sql.functions import percent_rank, cume_dist

window_sales = Window.orderBy(col("total_sales").desc())

df_distribution = df.withColumn("percent_rank", spark_round(percent_rank().over(window_sales), 4)) \
    .withColumn("cume_dist", spark_round(cume_dist().over(window_sales), 4))

df_distribution.show()
```

### Understanding the Difference

| Function | Description | Formula |
|----------|-------------|---------|
| `percent_rank()` | Relative rank (0 to 1) | (rank - 1) / (total_rows - 1) |
| `cume_dist()` | Cumulative distribution (0 to 1) | count of rows <= current / total_rows |
| Manual cumulative % | Running sum of individual percentages | sum(pct_of_total) up to current row |

**Output (df_distribution):**

| product_name | total_sales | percent_rank | cume_dist |
|-------------|-------------|-------------|-----------|
| Laptop      | 50000       | 0.0         | 0.125     |
| Phone       | 35000       | 0.1429      | 0.25      |
| Tablet      | 20000       | 0.2857      | 0.375     |
| Headphones  | 12000       | 0.4286      | 0.5       |
| Charger     | 8000        | 0.5714      | 0.625     |
| Case        | 5000        | 0.7143      | 0.75      |
| Cable       | 3000        | 0.8571      | 0.875     |
| Screen Guard| 2000        | 1.0         | 1.0       |

**Note:** `cume_dist` tells you the proportion of rows, not the proportion of sales value. For Pareto analysis, the manual cumulative percentage approach is more appropriate.

---

## Per-Category Cumulative Percentage

```python
# Add category to sample data
data_with_cat = [
    ("P001", "Laptop", "Electronics", 50000),
    ("P002", "Phone", "Electronics", 35000),
    ("P003", "Tablet", "Electronics", 20000),
    ("P004", "Headphones", "Accessories", 12000),
    ("P005", "Charger", "Accessories", 8000),
    ("P006", "Case", "Accessories", 5000)
]

df_cat = spark.createDataFrame(data_with_cat,
    ["product_id", "product_name", "category", "total_sales"])

# Window per category
window_cat = Window.partitionBy("category").orderBy(col("total_sales").desc()) \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Category total using a separate window (no ordering needed)
window_cat_total = Window.partitionBy("category")

df_cat_cum = df_cat.withColumn(
    "category_total", spark_sum("total_sales").over(window_cat_total)
).withColumn(
    "cumulative_sales", spark_sum("total_sales").over(window_cat)
).withColumn(
    "cumulative_pct_in_category",
    spark_round((col("cumulative_sales") / col("category_total")) * 100, 2)
)

df_cat_cum.select("category", "product_name", "total_sales",
                  "cumulative_pct_in_category").show()
```

---

## Key Interview Talking Points

1. **Pareto Principle (80/20 rule):** ~80% of effects come from ~20% of causes. In business: 80% of revenue from 20% of products/customers.

2. **Window frame matters:** `rowsBetween(Window.unboundedPreceding, Window.currentRow)` ensures the cumulative sum includes all rows from the start up to and including the current row.

3. **collect() caution:** Using `collect()[0][0]` for grand_total works but brings data to the driver. For very large datasets, use a window without partition: `spark_sum("total_sales").over(Window.rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing))`.

4. **Real-world applications:**
   - ABC analysis in inventory management
   - Customer segmentation by revenue contribution
   - Feature importance ranking in ML
   - Cost attribution analysis

5. **Follow-up: "How would you identify the top products contributing to exactly 80%?"**
   ```python
   top_80 = df_pareto.filter(col("cumulative_pct") <= 80)
   # But the last product might push over 80%, so use lag to check
   ```
