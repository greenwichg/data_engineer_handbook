# PySpark Implementation: Product Sales Analysis — First Year

## Problem Statement

Given a `Sales` table (sale_id, product_id, year, quantity, price) and a `Product` table (product_id, product_name), find the first year and quantity sold for each product's **first sale**. This is **LeetCode 1070 — Product Sales Analysis III**.

### Sample Data

```
Sales:
sale_id  product_id  year  quantity  price
1        100         2022  10        5000
2        100         2023  15        6000
3        200         2023  20        3000
4        200         2024  25        4000
5        300         2024  5         2000

Product:
product_id  product_name
100         iPhone
200         Galaxy
300         Pixel
```

### Expected Output

| product_id | first_year | quantity | price |
|------------|-----------|----------|-------|
| 100        | 2022      | 10       | 5000  |
| 200        | 2023      | 20       | 3000  |
| 300        | 2024      | 5        | 2000  |

---

## Method 1: Using row_number() (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, row_number
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("ProductFirstYear").getOrCreate()

sales_data = [
    (1, 100, 2022, 10, 5000),
    (2, 100, 2023, 15, 6000),
    (3, 200, 2023, 20, 3000),
    (4, 200, 2024, 25, 4000),
    (5, 300, 2024, 5, 2000)
]
sales = spark.createDataFrame(sales_data, ["sale_id", "product_id", "year", "quantity", "price"])

# Row number partitioned by product, ordered by year
w = Window.partitionBy("product_id").orderBy("year")

result = sales.withColumn("rn", row_number().over(w)) \
    .filter(col("rn") == 1) \
    .select(
        col("product_id"),
        col("year").alias("first_year"),
        "quantity",
        "price"
    ).orderBy("product_id")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Assign row_number per product ordered by year
- Product 100: 2022 → rn=1, 2023 → rn=2
- Product 200: 2023 → rn=1, 2024 → rn=2
- Product 300: 2024 → rn=1

#### Step 2: Filter rn == 1 to get first year only

---

## Method 2: Using groupBy + min + Join

```python
from pyspark.sql.functions import col, min as spark_min

# Get first year per product
first_years = sales.groupBy("product_id") \
    .agg(spark_min("year").alias("first_year"))

# Join back to get full row details
result = sales.join(
    first_years,
    (sales["product_id"] == first_years["product_id"]) &
    (sales["year"] == first_years["first_year"])
).select(
    sales["product_id"],
    col("first_year"),
    "quantity",
    "price"
).orderBy("product_id")

result.show()
```

---

## Method 3: Spark SQL

```python
sales.createOrReplaceTempView("sales")

result = spark.sql("""
    SELECT product_id, year AS first_year, quantity, price
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY year) AS rn
        FROM sales
    ) t
    WHERE rn = 1
    ORDER BY product_id
""")

result.show()

-- Alternative with subquery
result2 = spark.sql("""
    SELECT s.product_id, s.year AS first_year, s.quantity, s.price
    FROM sales s
    JOIN (
        SELECT product_id, MIN(year) AS min_year
        FROM sales
        GROUP BY product_id
    ) m ON s.product_id = m.product_id AND s.year = m.min_year
    ORDER BY s.product_id
""")

result2.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Multiple sales in first year | row_number picks one; min+join returns all | Clarify if you want one or all |
| Product with single sale | That sale is the first | Works correctly |
| Ties in year (same year, different sales) | row_number breaks tie arbitrarily | Add sale_id as tiebreaker |

## Key Interview Talking Points

1. **row_number vs. min+join:**
   - `row_number()` always returns exactly one row per product — cleaner.
   - `min() + join` may return multiple rows if there are ties in the first year.

2. **Pattern: "First event per entity"**
   - This is the same pattern as: first login, first purchase, first transaction.
   - Always use `row_number() OVER (PARTITION BY entity ORDER BY time)` and filter `rn = 1`.

3. **Follow-up: "What about the last year?"**
   - Change `ORDER BY year` to `ORDER BY year DESC`.
