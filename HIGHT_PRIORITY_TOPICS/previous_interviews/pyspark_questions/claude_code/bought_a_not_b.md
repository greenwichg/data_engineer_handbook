# PySpark Implementation: Customers Who Bought Product A but Not Product B

## Problem Statement
Given a table of customer purchases, find all customers who bought "Laptop" but never bought "Warranty". This is a common pattern for identifying cross-sell opportunities or finding gaps in purchasing behavior.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("BoughtANotB").getOrCreate()

data = [
    (1, "Alice", "Laptop"),
    (1, "Alice", "Warranty"),
    (1, "Alice", "Mouse"),
    (2, "Bob", "Laptop"),
    (2, "Bob", "Mouse"),
    (3, "Charlie", "Laptop"),
    (3, "Charlie", "Keyboard"),
    (4, "Diana", "Warranty"),
    (4, "Diana", "Mouse"),
    (5, "Eve", "Laptop"),
    (5, "Eve", "Warranty"),
    (6, "Frank", "Laptop"),
    (6, "Frank", "Headphones"),
]

df = spark.createDataFrame(data, ["customer_id", "customer_name", "product"])
df.show()
```

```
+-----------+-------------+-----------+
|customer_id|customer_name|    product|
+-----------+-------------+-----------+
|          1|        Alice|     Laptop|
|          1|        Alice|   Warranty|
|          1|        Alice|      Mouse|
|          2|          Bob|     Laptop|
|          2|          Bob|      Mouse|
|          3|      Charlie|     Laptop|
|          3|      Charlie|   Keyboard|
|          4|        Diana|   Warranty|
|          4|        Diana|      Mouse|
|          5|          Eve|     Laptop|
|          5|          Eve|   Warranty|
|          6|        Frank|     Laptop|
|          6|        Frank| Headphones|
+-----------+-------------+-----------+
```

### Expected Output
```
+-----------+-------------+
|customer_id|customer_name|
+-----------+-------------+
|          2|          Bob|
|          3|      Charlie|
|          6|        Frank|
+-----------+-------------+
```
These three customers bought a Laptop but never purchased a Warranty.

---

## Method 1: Left Anti-Join Approach (Recommended)
```python
# Step 1: Get customers who bought Laptop
laptop_buyers = (
    df.filter(F.col("product") == "Laptop")
    .select("customer_id", "customer_name")
    .distinct()
)

# Step 2: Get customers who bought Warranty
warranty_buyers = (
    df.filter(F.col("product") == "Warranty")
    .select("customer_id")
    .distinct()
)

# Step 3: Left anti-join to find Laptop buyers who never bought Warranty
result = laptop_buyers.join(warranty_buyers, on="customer_id", how="left_anti")
result.show()
```

### Step-by-Step Explanation

**Step 1 -- Filter for Laptop buyers:**
```
+-----------+-------------+
|customer_id|customer_name|
+-----------+-------------+
|          1|        Alice|
|          2|          Bob|
|          3|      Charlie|
|          5|          Eve|
|          6|        Frank|
+-----------+-------------+
```

**Step 2 -- Filter for Warranty buyers:**
```
+-----------+
|customer_id|
+-----------+
|          1|
|          4|
|          5|
+-----------+
```

**Step 3 -- Left anti-join removes any Laptop buyer whose customer_id appears in the Warranty buyers set:**
The anti-join keeps only rows from the left DataFrame that have NO match in the right DataFrame. Customers 1 (Alice) and 5 (Eve) are removed because they also bought Warranty. Customer 4 (Diana) was never in the Laptop set.

```
+-----------+-------------+
|customer_id|customer_name|
+-----------+-------------+
|          2|          Bob|
|          3|      Charlie|
|          6|        Frank|
+-----------+-------------+
```

---

## Method 2: Filter with NOT EXISTS Equivalent Using Spark SQL
```python
df.createOrReplaceTempView("purchases")

result_sql = spark.sql("""
    SELECT DISTINCT p1.customer_id, p1.customer_name
    FROM purchases p1
    WHERE p1.product = 'Laptop'
      AND NOT EXISTS (
          SELECT 1
          FROM purchases p2
          WHERE p2.customer_id = p1.customer_id
            AND p2.product = 'Warranty'
      )
    ORDER BY p1.customer_id
""")
result_sql.show()
```

---

## Method 3: Pivot / Aggregation Approach
```python
result_agg = (
    df.groupBy("customer_id", "customer_name")
    .agg(
        F.max(F.when(F.col("product") == "Laptop", 1).otherwise(0)).alias("has_laptop"),
        F.max(F.when(F.col("product") == "Warranty", 1).otherwise(0)).alias("has_warranty"),
    )
    .filter((F.col("has_laptop") == 1) & (F.col("has_warranty") == 0))
    .select("customer_id", "customer_name")
)
result_agg.show()
```

---

## Method 4: Left Join with Null Check
```python
laptop_buyers = (
    df.filter(F.col("product") == "Laptop")
    .select("customer_id", "customer_name")
    .distinct()
)

warranty_buyers = (
    df.filter(F.col("product") == "Warranty")
    .select(F.col("customer_id").alias("w_customer_id"))
    .distinct()
)

result_left = (
    laptop_buyers.join(
        warranty_buyers,
        laptop_buyers["customer_id"] == warranty_buyers["w_customer_id"],
        how="left",
    )
    .filter(F.col("w_customer_id").isNull())
    .select("customer_id", "customer_name")
)
result_left.show()
```

---

## Key Interview Talking Points
1. **Left anti-join** is the most idiomatic PySpark solution for "in A but not in B" problems. It is clean and expressive.
2. The anti-join only checks for existence of a matching key -- it never duplicates rows, unlike a regular left join which can produce multiple matches.
3. The **left join + null filter** approach is the traditional SQL pattern (`WHERE b.key IS NULL`). It works but is less readable than anti-join in PySpark.
4. The **aggregation approach** is useful when you need to check membership in multiple product categories at once (e.g., bought A, not B, and also bought C).
5. Always apply `.distinct()` before joining to avoid row multiplication if a customer can buy the same product multiple times.
6. In Spark SQL, `NOT EXISTS` is generally optimized to the same physical plan as a left anti-join.
7. When discussing performance, mention that all approaches benefit from a **broadcast join** if one side is small: `laptop_buyers.join(F.broadcast(warranty_buyers), ..., "left_anti")`.
8. This pattern generalizes to any "set difference" query: users who logged in but never converted, accounts that were opened but never funded, etc.
