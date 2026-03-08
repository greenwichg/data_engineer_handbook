# PySpark Implementation: List Products Ordered in a Period

## Problem Statement

Given a `Products` table and an `Orders` table, find products that had **at least 100 units ordered** in **February 2025**. Return the product name and total units ordered. This is **LeetCode 1327 — List the Products Ordered in a Period**.

### Sample Data

```
Products:
product_id  product_name  product_category
1           Laptop        Electronics
2           Phone         Electronics
3           Mouse         Accessories

Orders:
product_id  order_date   unit
1           2025-02-05   50
1           2025-02-15   60
2           2025-02-10   80
2           2025-03-01   30
3           2025-02-20   120
```

### Expected Output

| product_name | unit |
|-------------|------|
| Laptop      | 110  |
| Mouse       | 120  |

**Explanation:** Laptop: 50+60=110 ≥ 100. Phone: 80 < 100. Mouse: 120 ≥ 100. Phone's March order is excluded.

---

## Method 1: Filter + GroupBy + Having + Join (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, year, month

spark = SparkSession.builder.appName("ProductsInPeriod").getOrCreate()

products_data = [
    (1, "Laptop", "Electronics"),
    (2, "Phone", "Electronics"),
    (3, "Mouse", "Accessories")
]
products = spark.createDataFrame(products_data, ["product_id", "product_name", "product_category"])

orders_data = [
    (1, "2025-02-05", 50),
    (1, "2025-02-15", 60),
    (2, "2025-02-10", 80),
    (2, "2025-03-01", 30),
    (3, "2025-02-20", 120)
]
orders = spark.createDataFrame(orders_data, ["product_id", "order_date", "unit"])

# Filter to February 2025
feb_orders = orders.filter(
    (year("order_date") == 2025) & (month("order_date") == 2)
)

# Group by product and sum units
product_totals = feb_orders.groupBy("product_id") \
    .agg(spark_sum("unit").alias("unit")) \
    .filter(col("unit") >= 100)

# Join with products to get names
result = product_totals.join(products, on="product_id") \
    .select("product_name", "unit")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Filter orders to February 2025
- `year("order_date") == 2025` AND `month("order_date") == 2`
- Keeps only February orders, excluding the March order for Phone.

#### Step 2: Group by product_id and sum units

  | product_id | unit |
  |------------|------|
  | 1          | 110  |
  | 2          | 80   |
  | 3          | 120  |

#### Step 3: Filter sum >= 100 (HAVING equivalent)
- Product 2 (Phone) with 80 is excluded.

#### Step 4: Join to get product names

---

## Method 2: Using date_format for Period Filter

```python
from pyspark.sql.functions import col, sum as spark_sum, date_format

result = orders.filter(date_format("order_date", "yyyy-MM") == "2025-02") \
    .groupBy("product_id") \
    .agg(spark_sum("unit").alias("unit")) \
    .filter(col("unit") >= 100) \
    .join(products, on="product_id") \
    .select("product_name", "unit")

result.show()
```

---

## Method 3: Spark SQL

```python
products.createOrReplaceTempView("products")
orders.createOrReplaceTempView("orders")

result = spark.sql("""
    SELECT p.product_name, SUM(o.unit) AS unit
    FROM orders o
    JOIN products p ON o.product_id = p.product_id
    WHERE o.order_date >= '2025-02-01' AND o.order_date < '2025-03-01'
    GROUP BY p.product_name
    HAVING SUM(o.unit) >= 100
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Product with no orders in period | Not in result | Correct — filtered out by inner join |
| Product exactly at threshold (100) | Included (>= 100) | Correct |
| Leap year February | Date filter handles it | Use year/month extraction, not hardcoded dates |
| NULL order_date | Excluded by date filter | Correct behavior |

## Key Interview Talking Points

1. **Date filtering approaches:**
   - `year() + month()` — explicit and readable.
   - `date_format(col, "yyyy-MM") == "2025-02"` — compact.
   - `BETWEEN '2025-02-01' AND '2025-02-28'` — fragile (leap year issue!).
   - `>= '2025-02-01' AND < '2025-03-01'` — safe range approach.

2. **HAVING vs. filter after groupBy:**
   - In SQL: `HAVING SUM(unit) >= 100`.
   - In PySpark: `.groupBy(...).agg(...).filter(...)` — the filter after agg IS the HAVING.

3. **Filter before vs. after join:**
   - Filter orders to the target period BEFORE joining — reduces data shuffled.
   - Pushing predicates down is a standard optimization.

4. **Follow-up: "Make the period dynamic?"**
   - Parameterize year and month as variables. In PySpark, use Python variables directly in filter expressions.
