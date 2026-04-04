# PySpark Implementation: Row-Level Security Filter

## Problem Statement

Implement row-level security (RLS) by filtering data based on user roles and permissions. Given a dataset and a permissions table that defines which users can access which data partitions (e.g., by region, department, or classification level), dynamically filter the data so each user only sees rows they are authorized to view. This is a common interview question at enterprise data platform companies and tests your understanding of access control patterns in data engineering.

### Sample Data

**Sales Data:**

| sale_id | region    | department | amount | customer    | classification |
|---------|-----------|------------|--------|-------------|----------------|
| 1       | US-East   | Sales      | 5000   | Acme Corp   | public         |
| 2       | US-West   | Marketing  | 3000   | Beta Inc    | internal       |
| 3       | EU-West   | Sales      | 7000   | Euro Ltd    | confidential   |
| 4       | US-East   | Finance    | 12000  | Acme Corp   | restricted     |
| 5       | APAC      | Sales      | 4000   | Asia Corp   | public         |
| 6       | EU-West   | Marketing  | 6000   | Euro Ltd    | internal       |

**Permissions:**

| user_name | role    | allowed_regions       | allowed_departments  | max_classification |
|-----------|---------|----------------------|---------------------|--------------------|
| alice     | analyst | US-East,US-West      | Sales,Marketing     | internal           |
| bob       | manager | US-East,US-West,APAC | Sales,Marketing,Finance | confidential  |
| carol     | admin   | ALL                  | ALL                 | restricted         |
| dave      | analyst | EU-West              | Sales               | public             |

### Expected Output (for user "alice")

| sale_id | region  | department | amount | customer  | classification |
|---------|---------|------------|--------|-----------|----------------|
| 1       | US-East | Sales      | 5000   | Acme Corp | public         |
| 2       | US-West | Marketing  | 3000   | Beta Inc  | internal       |

---

## Method 1: DataFrame API with Dynamic Filtering

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import ArrayType, StringType

# Initialize Spark
spark = SparkSession.builder \
    .appName("Row-Level Security Filter") \
    .master("local[*]") \
    .getOrCreate()

# --- Sales Data ---
sales_data = [
    (1, "US-East", "Sales", 5000, "Acme Corp", "public"),
    (2, "US-West", "Marketing", 3000, "Beta Inc", "internal"),
    (3, "EU-West", "Sales", 7000, "Euro Ltd", "confidential"),
    (4, "US-East", "Finance", 12000, "Acme Corp", "restricted"),
    (5, "APAC", "Sales", 4000, "Asia Corp", "public"),
    (6, "EU-West", "Marketing", 6000, "Euro Ltd", "internal"),
    (7, "US-East", "Sales", 2500, "Gamma LLC", "public"),
    (8, "APAC", "Finance", 9000, "Asia Corp", "restricted"),
]

sales_df = spark.createDataFrame(
    sales_data,
    ["sale_id", "region", "department", "amount", "customer", "classification"]
)

# --- Permissions Data ---
permissions_data = [
    ("alice", "analyst", "US-East,US-West", "Sales,Marketing", "internal"),
    ("bob", "manager", "US-East,US-West,APAC", "Sales,Marketing,Finance", "confidential"),
    ("carol", "admin", "ALL", "ALL", "restricted"),
    ("dave", "analyst", "EU-West", "Sales", "public"),
]

permissions_df = spark.createDataFrame(
    permissions_data,
    ["user_name", "role", "allowed_regions", "allowed_departments", "max_classification"]
)

# Classification hierarchy for comparison
classification_levels = {"public": 1, "internal": 2, "confidential": 3, "restricted": 4}
classification_df = spark.createDataFrame(
    [(k, v) for k, v in classification_levels.items()],
    ["classification", "level"]
)

# --- Function to apply RLS for a specific user ---
def apply_rls(sales_df, permissions_df, classification_df, user_name):
    """Filter sales data based on user permissions."""

    # Get this user's permissions
    user_perms = permissions_df.filter(F.col("user_name") == user_name).first()

    if user_perms is None:
        print(f"User '{user_name}' not found. Returning empty DataFrame.")
        return sales_df.limit(0)

    allowed_regions = user_perms["allowed_regions"]
    allowed_depts = user_perms["allowed_departments"]
    max_class = user_perms["max_classification"]
    max_level = classification_levels[max_class]

    filtered = sales_df

    # Apply region filter (unless ALL)
    if allowed_regions != "ALL":
        region_list = [r.strip() for r in allowed_regions.split(",")]
        filtered = filtered.filter(F.col("region").isin(region_list))

    # Apply department filter (unless ALL)
    if allowed_depts != "ALL":
        dept_list = [d.strip() for d in allowed_depts.split(",")]
        filtered = filtered.filter(F.col("department").isin(dept_list))

    # Apply classification filter
    filtered = filtered.join(classification_df, "classification") \
        .filter(F.col("level") <= max_level) \
        .drop("level")

    return filtered

# --- Test for each user ---
for user in ["alice", "bob", "carol", "dave"]:
    print(f"=== Data visible to '{user}' ===")
    result = apply_rls(sales_df, permissions_df, classification_df, user)
    result.show()

spark.stop()
```

## Method 2: SQL View-Based RLS with Join

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("RLS - SQL Join Approach") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
sales_data = [
    (1, "US-East", "Sales", 5000, "public"),
    (2, "US-West", "Marketing", 3000, "internal"),
    (3, "EU-West", "Sales", 7000, "confidential"),
    (4, "US-East", "Finance", 12000, "restricted"),
    (5, "APAC", "Sales", 4000, "public"),
    (6, "EU-West", "Marketing", 6000, "internal"),
]

sales_df = spark.createDataFrame(
    sales_data, ["sale_id", "region", "department", "amount", "classification"]
)

# Exploded permissions: one row per (user, region) and (user, department)
region_perms = [
    ("alice", "US-East"), ("alice", "US-West"),
    ("bob", "US-East"), ("bob", "US-West"), ("bob", "APAC"),
    ("carol", "US-East"), ("carol", "US-West"), ("carol", "EU-West"), ("carol", "APAC"),
    ("dave", "EU-West"),
]

dept_perms = [
    ("alice", "Sales"), ("alice", "Marketing"),
    ("bob", "Sales"), ("bob", "Marketing"), ("bob", "Finance"),
    ("carol", "Sales"), ("carol", "Marketing"), ("carol", "Finance"),
    ("dave", "Sales"),
]

class_perms = [
    ("alice", 2),  # up to internal
    ("bob", 3),    # up to confidential
    ("carol", 4),  # up to restricted
    ("dave", 1),   # public only
]

region_perms_df = spark.createDataFrame(region_perms, ["user_name", "allowed_region"])
dept_perms_df = spark.createDataFrame(dept_perms, ["user_name", "allowed_dept"])
class_perms_df = spark.createDataFrame(class_perms, ["user_name", "max_class_level"])

classification_map = spark.createDataFrame(
    [("public", 1), ("internal", 2), ("confidential", 3), ("restricted", 4)],
    ["classification", "class_level"]
)

# Register views
sales_df.createOrReplaceTempView("sales")
region_perms_df.createOrReplaceTempView("region_permissions")
dept_perms_df.createOrReplaceTempView("dept_permissions")
class_perms_df.createOrReplaceTempView("class_permissions")
classification_map.createOrReplaceTempView("class_levels")

# --- RLS via JOIN: only rows matching ALL permission dimensions pass ---
rls_query = """
    SELECT DISTINCT
        :user_name AS viewing_user,
        s.sale_id,
        s.region,
        s.department,
        s.amount,
        s.classification
    FROM sales s
    -- Region check
    JOIN region_permissions rp
        ON rp.user_name = :user_name AND rp.allowed_region = s.region
    -- Department check
    JOIN dept_permissions dp
        ON dp.user_name = :user_name AND dp.allowed_dept = s.department
    -- Classification check
    JOIN class_levels cl ON cl.classification = s.classification
    JOIN class_permissions cp
        ON cp.user_name = :user_name AND cl.class_level <= cp.max_class_level
    ORDER BY s.sale_id
"""

# Since parameterized queries vary by Spark version, build dynamically
for user in ["alice", "bob", "carol", "dave"]:
    query = rls_query.replace(":user_name", f"'{user}'")
    print(f"=== Sales visible to '{user}' ===")
    spark.sql(query).show()

spark.stop()
```

## Method 3: Partition-Level Security with Predicate Pushdown

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("RLS - Partition Predicate Pushdown") \
    .master("local[*]") \
    .getOrCreate()

# --- Simulate partitioned data (region-partitioned table) ---
sales_data = [
    (1, "US-East", "Sales", 5000),
    (2, "US-West", "Marketing", 3000),
    (3, "EU-West", "Sales", 7000),
    (4, "US-East", "Finance", 12000),
    (5, "APAC", "Sales", 4000),
    (6, "EU-West", "Marketing", 6000),
]

sales_df = spark.createDataFrame(
    sales_data, ["sale_id", "region", "department", "amount"]
)

# User-to-partition mapping (what partitions can each user read)
user_partitions = {
    "alice": ["US-East", "US-West"],
    "bob": ["US-East", "US-West", "APAC"],
    "carol": None,  # None = all partitions (admin)
    "dave": ["EU-West"],
}

def read_with_rls(df, user_name, partition_map):
    """
    Apply partition-level security filter.
    In production with Parquet/Delta, this enables predicate pushdown
    so unauthorized partitions are never even read from storage.
    """
    allowed = partition_map.get(user_name)

    if allowed is None:
        # Admin: no filter
        return df

    return df.filter(F.col("region").isin(allowed))

# Test partition-level RLS
for user in ["alice", "bob", "carol", "dave"]:
    print(f"=== Partitions accessible to '{user}' ===")
    filtered = read_with_rls(sales_df, user, user_partitions)
    filtered.show()

    # Show the physical plan to verify predicate pushdown would apply
    print(f"Plan for '{user}':")
    filtered.explain(True)

spark.stop()
```

## Key Concepts

- **Row-Level Security (RLS)**: Restricting which rows a user can see based on their identity or role. Implemented as a filter applied before data reaches the user.
- **Multi-Dimensional Permissions**: Real RLS often involves multiple axes (region AND department AND classification level). All conditions must be met.
- **Predicate Pushdown**: When filters align with partition columns, the storage layer can skip reading unauthorized partitions entirely -- critical for performance.
- **Classification Hierarchy**: Security levels are ordered (public < internal < confidential < restricted). Users can see data at or below their clearance level.
- **View-Based Security**: Creating SQL views with built-in filters is the simplest RLS implementation. Each role gets a different view.

## Interview Tips

- Mention that cloud data platforms implement RLS natively: **Databricks Unity Catalog**, **Snowflake Row Access Policies**, **BigQuery Row-Level Security**.
- Discuss the performance implication: RLS via joins can be expensive on large datasets. Partition-aligned filters are more efficient.
- Emphasize that RLS must be **enforced at the platform level**, not just the application level -- users should not be able to bypass it with direct SQL.
- For Delta Lake interviews, mention that row-level and column-level security can be combined with **dynamic views** in Unity Catalog.
- Always consider **audit logging**: track who accessed what data for compliance.
