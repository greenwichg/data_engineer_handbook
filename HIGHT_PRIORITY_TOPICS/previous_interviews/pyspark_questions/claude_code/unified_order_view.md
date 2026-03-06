# PySpark Implementation: Unified Order View

## Problem Statement

You're working as a Data Engineer at a company that builds Customer Relationship Management (CRM) software. Your goal is to build a unified view that shows order details along with customer and product information — useful for internal dashboards and reporting.

You are given three datasets (or tables) that store customer, order, and product details.

### Task

Write a function that:
- Joins the customer, order, and product data.
- Creates a new column `customer_name` by concatenating `first_name` and `last_name` with a space in between.
- Returns a new DataFrame with the following reordered column layout:
  `order_id`, `customer_name`, `customer_email`, `product_name`, `product_category`, `order_date`

### Schema Details

**customers**

| Column Name  | Data Type |
|-------------|-----------|
| customer_id | Integer   |
| first_name  | String    |
| last_name   | String    |
| email       | String    |

**orders**

| Column Name  | Data Type |
|-------------|-----------|
| order_id    | Integer   |
| customer_id | Integer   |
| product_id  | Integer   |
| order_date  | Date      |

**products**

| Column Name   | Data Type |
|--------------|-----------|
| product_id   | Integer   |
| product_name | String    |
| category     | String    |

### Expected Output Schema

| Column Name       | Data Type |
|-------------------|-----------|
| order_id          | Integer   |
| customer_name     | String    |
| customer_email    | String    |
| product_name      | String    |
| product_category  | String    |
| order_date        | String    |

### Sample Data

**customers**
```
customer_id  first_name  last_name  email
1            John        Doe        john.doe@email.com
2            Jane        Smith      jane.smith@email.com
```

**orders**
```
order_id  customer_id  product_id  order_date
1001      1            101         2023-01-10
1002      2            102         2023-01-11
```

**products**
```
product_id  product_name  category
101         Product A     Category1
102         Product B     Category2
```

### Expected Output

```
order_id  customer_name  customer_email        product_name  product_category  order_date
1001      John Doe       john.doe@email.com    Product A     Category1         2023-01-10 00:00:00
1002      Jane Smith     jane.smith@email.com  Product B     Category2         2023-01-11 00:00:00
```

---

## Method 1: Using DataFrame Joins with concat

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import concat, lit, col

# Initialize Spark session
spark = SparkSession.builder.appName("UnifiedOrderView").getOrCreate()

# Sample data
customers_data = [
    (1, "John", "Doe", "john.doe@email.com"),
    (2, "Jane", "Smith", "jane.smith@email.com"),
]

orders_data = [
    (1001, 1, 101, "2023-01-10"),
    (1002, 2, 102, "2023-01-11"),
]

products_data = [
    (101, "Product A", "Category1"),
    (102, "Product B", "Category2"),
]

# Create DataFrames
customers = spark.createDataFrame(customers_data, ["customer_id", "first_name", "last_name", "email"])
orders = spark.createDataFrame(orders_data, ["order_id", "customer_id", "product_id", "order_date"])
products = spark.createDataFrame(products_data, ["product_id", "product_name", "category"])

# Cast order_date to date type
orders = orders.withColumn("order_date", col("order_date").cast("date"))

# Join orders with customers on customer_id
order_customer = orders.join(customers, on="customer_id", how="inner")

# Join result with products on product_id
unified = order_customer.join(products, on="product_id", how="inner")

# Create customer_name by concatenating first_name and last_name
unified = unified.withColumn("customer_name", concat(col("first_name"), lit(" "), col("last_name")))

# Rename columns and select in required order
result = unified.select(
    col("order_id"),
    col("customer_name"),
    col("email").alias("customer_email"),
    col("product_name"),
    col("category").alias("product_category"),
    col("order_date").cast("string").alias("order_date"),
)

result.show(truncate=False)
```

### Output
```
+--------+-------------+--------------------+------------+----------------+-------------------+
|order_id|customer_name|customer_email      |product_name|product_category|order_date         |
+--------+-------------+--------------------+------------+----------------+-------------------+
|1001    |John Doe     |john.doe@email.com  |Product A   |Category1       |2023-01-10 00:00:00|
|1002    |Jane Smith   |jane.smith@email.com|Product B   |Category2       |2023-01-11 00:00:00|
+--------+-------------+--------------------+------------+----------------+-------------------+
```

---

## Method 2: Using concat_ws (with separator)

```python
from pyspark.sql.functions import concat_ws, col

# concat_ws handles nulls more gracefully — skips null values instead of returning null
unified = orders \
    .join(customers, on="customer_id", how="inner") \
    .join(products, on="product_id", how="inner") \
    .withColumn("customer_name", concat_ws(" ", col("first_name"), col("last_name")))

result = unified.select(
    col("order_id"),
    col("customer_name"),
    col("email").alias("customer_email"),
    col("product_name"),
    col("category").alias("product_category"),
    col("order_date").cast("string").alias("order_date"),
)

result.show(truncate=False)
```

> **Key Difference:** `concat_ws(" ", ...)` skips null values and only places the separator between non-null values, while `concat(..., lit(" "), ...)` returns null if any argument is null.

---

## Method 3: Using Spark SQL

```python
# Register DataFrames as temp views
customers.createOrReplaceTempView("crm_customers")
orders.createOrReplaceTempView("crm_orders")
products.createOrReplaceTempView("crm_products")

result = spark.sql("""
    SELECT
        o.order_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        c.email AS customer_email,
        p.product_name,
        p.category AS product_category,
        CAST(o.order_date AS STRING) AS order_date
    FROM crm_orders o
    INNER JOIN crm_customers c ON o.customer_id = c.customer_id
    INNER JOIN crm_products p ON o.product_id = p.product_id
""")

result.show(truncate=False)
```

---

## Method 4: Using a Reusable Function

```python
from pyspark.sql import DataFrame
from pyspark.sql.functions import concat_ws, col


def create_unified_order_view(
    customers: DataFrame, orders: DataFrame, products: DataFrame
) -> DataFrame:
    """
    Joins customer, order, and product data into a unified order view.
    """
    unified = (
        orders
        .join(customers, on="customer_id", how="inner")
        .join(products, on="product_id", how="inner")
        .withColumn("customer_name", concat_ws(" ", col("first_name"), col("last_name")))
        .select(
            col("order_id"),
            col("customer_name"),
            col("email").alias("customer_email"),
            col("product_name"),
            col("category").alias("product_category"),
            col("order_date").cast("string").alias("order_date"),
        )
    )
    return unified


# Usage
result = create_unified_order_view(customers, orders, products)
result.show(truncate=False)
```

---

## SQL / dbt Version

```sql
SELECT
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email AS customer_email,
    p.product_name,
    p.category AS product_category,
    CAST(o.order_date AS STRING) AS order_date
FROM crm_orders o
INNER JOIN crm_customers c
    ON o.customer_id = c.customer_id
INNER JOIN crm_products p
    ON o.product_id = p.product_id;
```

---

## Key Concepts

| Concept | Details |
|---------|---------|
| **Inner Join** | Returns only rows with matching keys in both DataFrames. Use `how="left"` if you want to keep all orders even without matching customers/products. |
| **concat vs concat_ws** | `concat` returns null if any input is null. `concat_ws` skips nulls and only places the separator between non-null values. |
| **Column aliasing** | Use `.alias()` in DataFrame API or `AS` in SQL to rename columns (e.g., `email` → `customer_email`). |
| **Column ordering** | Use `.select()` to control the exact column order in the output DataFrame. |
| **Date casting** | Casting a date column to string produces the format `yyyy-MM-dd HH:mm:ss` by default in Spark. |

---

## Common Interview Follow-ups

1. **What if a customer has no orders?** Use a `left` join from customers to orders instead of `inner` to retain all customers.
2. **What if there are duplicate customer records?** Deduplicate the customers DataFrame before joining (e.g., using `dropDuplicates(["customer_id"])`).
3. **How would you handle nulls in first_name or last_name?** Use `concat_ws` which gracefully skips nulls, or use `coalesce` to provide defaults.
4. **How do you optimize this for large datasets?** If one table is small (e.g., products), use a broadcast join: `orders.join(broadcast(products), ...)`.
5. **What join type does Spark use by default?** Inner join. Always specify the join type explicitly for clarity.
