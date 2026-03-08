# PySpark Implementation: Average Selling Price (Weighted Average with Date Range Join)

## Problem Statement

Given a `Prices` table (product_id, start_date, end_date, price) and a `UnitsSold` table (product_id, purchase_date, units), find the **average selling price** for each product. The price depends on the date the purchase was made. This is **LeetCode 1251 — Average Selling Price**.

### Sample Data

```
Prices:
product_id  start_date   end_date     price
1           2025-01-01   2025-01-15   10
1           2025-01-16   2025-01-31   15
2           2025-01-01   2025-01-31   20

UnitsSold:
product_id  purchase_date  units
1           2025-01-05     50
1           2025-01-20     30
2           2025-01-10     100
```

### Expected Output

| product_id | average_price |
|------------|--------------|
| 1          | 11.88        |
| 2          | 20.00        |

**Explanation:** Product 1: (50×10 + 30×15) / (50+30) = 950/80 = 11.875 ≈ 11.88. Product 2: (100×20)/100 = 20.00.

---

## Method 1: Range Join + Weighted Average (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, round as spark_round

spark = SparkSession.builder.appName("AvgSellingPrice").getOrCreate()

prices_data = [
    (1, "2025-01-01", "2025-01-15", 10),
    (1, "2025-01-16", "2025-01-31", 15),
    (2, "2025-01-01", "2025-01-31", 20)
]
prices = spark.createDataFrame(prices_data, ["product_id", "start_date", "end_date", "price"])

units_data = [
    (1, "2025-01-05", 50),
    (1, "2025-01-20", 30),
    (2, "2025-01-10", 100)
]
units_sold = spark.createDataFrame(units_data, ["product_id", "purchase_date", "units"])

# Range join: match units to the correct price period
joined = units_sold.join(
    prices,
    (units_sold["product_id"] == prices["product_id"]) &
    (col("purchase_date") >= col("start_date")) &
    (col("purchase_date") <= col("end_date"))
)

# Weighted average = sum(price * units) / sum(units)
result = joined.groupBy(units_sold["product_id"]) \
    .agg(
        spark_round(
            spark_sum(col("price") * col("units")) / spark_sum("units"),
            2
        ).alias("average_price")
    ).orderBy("product_id")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Range join to match purchase to price period
- **What happens:** Each purchase is matched to the price row where `purchase_date` falls within `[start_date, end_date]`.

  | product_id | purchase_date | units | start_date | end_date   | price |
  |------------|--------------|-------|------------|------------|-------|
  | 1          | 2025-01-05   | 50    | 2025-01-01 | 2025-01-15 | 10    |
  | 1          | 2025-01-20   | 30    | 2025-01-16 | 2025-01-31 | 15    |
  | 2          | 2025-01-10   | 100   | 2025-01-01 | 2025-01-31 | 20    |

#### Step 2: Compute weighted average per product
- **Product 1:** (50×10 + 30×15) / (50+30) = 950/80 = 11.88
- **Product 2:** (100×20) / 100 = 20.00

---

## Method 2: Using Left Join to Handle Products with No Sales

```python
from pyspark.sql.functions import col, sum as spark_sum, round as spark_round, coalesce, lit

# Left join from prices to handle products with no sales
joined = prices.join(
    units_sold,
    (prices["product_id"] == units_sold["product_id"]) &
    (col("purchase_date") >= col("start_date")) &
    (col("purchase_date") <= col("end_date")),
    "left"
)

result = joined.groupBy(prices["product_id"]) \
    .agg(
        spark_round(
            coalesce(
                spark_sum(col("price") * col("units")) / spark_sum("units"),
                lit(0)
            ),
            2
        ).alias("average_price")
    ).orderBy("product_id")

result.show()
```

---

## Method 3: Spark SQL

```python
prices.createOrReplaceTempView("prices")
units_sold.createOrReplaceTempView("units_sold")

result = spark.sql("""
    SELECT
        p.product_id,
        ROUND(COALESCE(SUM(p.price * u.units) / SUM(u.units), 0), 2) AS average_price
    FROM prices p
    LEFT JOIN units_sold u
        ON p.product_id = u.product_id
        AND u.purchase_date BETWEEN p.start_date AND p.end_date
    GROUP BY p.product_id
    ORDER BY p.product_id
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Product with no sales | Division by zero (sum(units) = 0) | Use COALESCE to return 0 |
| Purchase outside any price period | No match in join | Row excluded; may need to flag |
| Overlapping price periods | Purchase matches multiple prices | Duplicates units — fix data or pick one |
| NULL units or price | Propagates NULL in calculations | Filter NULLs or use COALESCE |

## Key Interview Talking Points

1. **Weighted average formula:**
   - `SUM(price × units) / SUM(units)` — NOT `AVG(price)`. A simple average ignores volume.

2. **Range join pattern:**
   - `purchase_date BETWEEN start_date AND end_date` is a range/temporal join. Common in pricing, exchange rates, and SCD lookups.

3. **Performance of range joins:**
   - Range joins can be expensive (no equi-join optimization). In PySpark, broadcast the smaller table (prices) if possible.

4. **Follow-up: "What if a purchase falls in no price period?"**
   - Use LEFT JOIN from units_sold to detect unmatched purchases. Flag or use a default price.

5. **Pattern generalization:**
   - This exact pattern applies to: exchange rate conversions, tax bracket lookups, insurance premium calculations — any scenario where a rate varies by date range.
