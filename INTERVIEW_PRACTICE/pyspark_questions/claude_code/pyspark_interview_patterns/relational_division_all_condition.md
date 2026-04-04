# PySpark Implementation: Relational Division (Find Entities with ALL Items)

## Problem Statement
Given a table of customer purchases and a required product list, find all customers who have purchased **every** product in the list. This is the relational algebra "division" operation — one of the trickiest SQL patterns and a favorite in senior-level interviews.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("RelationalDivision").getOrCreate()

purchase_data = [
    ("Alice", "Laptop"),
    ("Alice", "Phone"),
    ("Alice", "Tablet"),
    ("Alice", "Headphones"),
    ("Bob", "Laptop"),
    ("Bob", "Phone"),
    ("Charlie", "Laptop"),
    ("Charlie", "Phone"),
    ("Charlie", "Tablet"),
    ("Diana", "Phone"),
    ("Diana", "Tablet"),
    ("Eve", "Laptop"),
    ("Eve", "Phone"),
    ("Eve", "Tablet"),
]

purchases = spark.createDataFrame(purchase_data, ["customer", "product"])

# Required product list
required_products = spark.createDataFrame(
    [("Laptop",), ("Phone",), ("Tablet",)], ["product"]
)

purchases.show()
required_products.show()
```

```
+--------+----------+
|customer|   product|
+--------+----------+
|   Alice|    Laptop|
|   Alice|     Phone|
|   Alice|    Tablet|
|   Alice|Headphones|
|     Bob|    Laptop|
|     Bob|     Phone|
| Charlie|    Laptop|
| Charlie|     Phone|
| Charlie|    Tablet|
|   Diana|     Phone|
|   Diana|    Tablet|
|     Eve|    Laptop|
|     Eve|     Phone|
|     Eve|    Tablet|
+--------+----------+

+-------+
|product|
+-------+
| Laptop|
|  Phone|
| Tablet|
+-------+
```

### Expected Output
```
+--------+
|customer|
+--------+
|   Alice|
| Charlie|
|     Eve|
+--------+
```
- Alice bought all 3 required products (plus extras).
- Charlie and Eve bought exactly the 3 required products.
- Bob is missing Tablet. Diana is missing Laptop.

---

## Method 1: Count Matching Products (Recommended)

```python
# Step 1: Inner join purchases with required products to keep only relevant purchases
matched = purchases.join(required_products, on="product", how="inner")

# Step 2: Count distinct matched products per customer
customer_counts = matched.groupBy("customer").agg(
    F.countDistinct("product").alias("matched_count")
)

# Step 3: Get the total number of required products
required_count = required_products.count()  # = 3

# Step 4: Filter customers who matched ALL required products
result = customer_counts.filter(F.col("matched_count") == required_count)
result.select("customer").orderBy("customer").show()
```

### Step-by-Step Explanation

#### Step 1: Inner join to keep only required products that each customer bought
- **Output (matched):**

  | customer | product |
  |----------|---------|
  | Alice    | Laptop  |
  | Alice    | Phone   |
  | Alice    | Tablet  |
  | Bob      | Laptop  |
  | Bob      | Phone   |
  | Charlie  | Laptop  |
  | Charlie  | Phone   |
  | Charlie  | Tablet  |
  | Diana    | Phone   |
  | Diana    | Tablet  |
  | Eve      | Laptop  |
  | Eve      | Phone   |
  | Eve      | Tablet  |

- Note: Alice's "Headphones" is excluded since it's not in the required list.

#### Step 2: Count distinct matched products per customer
- **Output (customer_counts):**

  | customer | matched_count |
  |----------|---------------|
  | Alice    | 3             |
  | Bob      | 2             |
  | Charlie  | 3             |
  | Diana    | 2             |
  | Eve      | 3             |

#### Step 3-4: Filter where count equals required count (3)
- Alice (3), Charlie (3), Eve (3) pass the filter. Bob (2) and Diana (2) do not.

---

## Method 2: Double Negation — "No Required Product is Missing"

```python
# Relational division via double negation:
# "Customers for whom there is NO required product that they did NOT buy"

# Step 1: Get distinct customers
customers = purchases.select("customer").distinct()

# Step 2: Cross join to get all (customer, required_product) combinations
all_combinations = customers.crossJoin(required_products)

# Step 3: Left anti-join with actual purchases to find missing (customer, product) pairs
missing = all_combinations.join(purchases, on=["customer", "product"], how="left_anti")

# Step 4: Customers NOT in the missing set have bought everything
result = customers.join(
    missing.select("customer").distinct(),
    on="customer",
    how="left_anti"
)
result.orderBy("customer").show()
```

### Step-by-Step Explanation

#### Step 2: All possible (customer, required_product) combinations
- **Output:** 5 customers × 3 products = 15 rows.

#### Step 3: Find what's missing
- **Output (missing):**

  | customer | product |
  |----------|---------|
  | Bob      | Tablet  |
  | Diana    | Laptop  |

#### Step 4: Exclude customers who have any missing product
- Bob and Diana appear in `missing`, so they are excluded. Alice, Charlie, Eve remain.

---

## Method 3: Spark SQL with HAVING

```python
purchases.createOrReplaceTempView("purchases")
required_products.createOrReplaceTempView("required_products")

result_sql = spark.sql("""
    SELECT p.customer
    FROM purchases p
    INNER JOIN required_products r ON p.product = r.product
    GROUP BY p.customer
    HAVING COUNT(DISTINCT p.product) = (SELECT COUNT(*) FROM required_products)
    ORDER BY p.customer
""")
result_sql.show()
```

---

## Method 4: Spark SQL with Double Negation (NOT EXISTS)

```python
result_sql_ne = spark.sql("""
    SELECT DISTINCT customer
    FROM purchases p1
    WHERE NOT EXISTS (
        SELECT 1
        FROM required_products r
        WHERE NOT EXISTS (
            SELECT 1
            FROM purchases p2
            WHERE p2.customer = p1.customer
              AND p2.product = r.product
        )
    )
    ORDER BY customer
""")
result_sql_ne.show()
```

- **Read as:** "Find customers for whom there is no required product that they haven't purchased."

---

## Variation: Exact Division (Bought ONLY the Required Products, Nothing Extra)

```python
# Customers who bought exactly the required set — nothing more, nothing less
exact_match = (
    purchases.join(required_products, on="product", how="inner")
    .groupBy("customer")
    .agg(F.countDistinct("product").alias("matched_count"))
    .filter(F.col("matched_count") == required_count)
    .join(
        # Exclude customers who bought non-required products
        purchases.join(required_products, on="product", how="left_anti")
        .select("customer").distinct(),
        on="customer",
        how="left_anti",
    )
)
exact_match.show()
```

**Output:**
```
+--------+
|customer|
+--------+
| Charlie|
|     Eve|
+--------+
```
Alice is excluded because she also bought Headphones.

---

## Comparison of Methods

| Method | Readability | Performance | Handles Duplicates? |
|--------|-------------|-------------|---------------------|
| Count matching (Method 1) | Best — simple and clear | Fast — single join + groupBy | Yes — uses countDistinct |
| Double negation (Method 2) | Complex — hard to explain | Slower — cross join involved | Yes |
| SQL HAVING (Method 3) | Clean SQL | Same as Method 1 | Yes — uses COUNT(DISTINCT) |
| SQL NOT EXISTS (Method 4) | Classic relational algebra | Depends on optimizer | Yes |

## Key Interview Talking Points

1. **Method 1 (count-based) is the go-to answer** for interviews. It's simple, efficient, and easy to explain.
2. **Method 2 (double negation)** demonstrates deep understanding of relational algebra. Mention it if the interviewer asks for alternative approaches.
3. **`countDistinct` is critical** — if a customer bought Laptop twice, plain `count` would give 2, making the comparison wrong.
4. **Division with remainder** (exact match) is a common follow-up: "What if we want customers who bought ONLY these products and nothing else?"
5. This pattern generalizes to: "Find students who passed ALL required courses", "Find warehouses that stock ALL items in a catalog", "Find employees certified in ALL required skills."
