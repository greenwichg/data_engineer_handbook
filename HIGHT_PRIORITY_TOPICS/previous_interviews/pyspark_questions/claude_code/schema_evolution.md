# PySpark Implementation: Schema Evolution Handling

## Problem Statement

In production data pipelines, source schemas frequently change -- new columns are added, old ones removed, data types change, or columns are renamed. A common interview question asks how you would handle schema evolution gracefully in PySpark so that downstream consumers are not broken by upstream changes. This tests your understanding of schema management, union operations with mismatched schemas, and defensive programming practices.

**Scenario:** You receive daily data feeds from multiple partners. Each partner may add or remove columns over time. You need to merge these feeds into a unified table while handling schema mismatches, filling missing columns with defaults, and preserving data type consistency.

### Sample Data

**Day 1 Feed (v1 schema):**
```
user_id | name       | email              | signup_date
--------|------------|--------------------|------------
1       | Alice      | alice@example.com  | 2024-01-15
2       | Bob        | bob@example.com    | 2024-02-20
```

**Day 2 Feed (v2 schema -- added phone, removed email):**
```
user_id | name       | phone        | signup_date | country
--------|------------|--------------|-------------|--------
3       | Charlie    | 555-0101     | 2024-03-10  | US
4       | Diana      | 555-0202     | 2024-03-15  | UK
```

### Expected Output

**Merged result with unified schema:**

| user_id | name | email | signup_date | phone | country |
|---------|------|-------|-------------|-------|---------|
| 1 | Alice | alice@example.com | 2024-01-15 | null | null |
| 2 | Bob | bob@example.com | 2024-02-20 | null | null |
| 3 | Charlie | null | 2024-03-10 | 555-0101 | US |
| 4 | Diana | null | 2024-03-15 | 555-0202 | UK |

---

## Method 1: Union by Name with Missing Column Handling

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, when, coalesce
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DateType
)

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("SchemaEvolutionHandling") \
    .master("local[*]") \
    .getOrCreate()

# --- Simulate Day 1 feed (v1 schema) ---
schema_v1 = StructType([
    StructField("user_id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("email", StringType(), True),
    StructField("signup_date", StringType(), True),
])

data_v1 = [
    (1, "Alice", "alice@example.com", "2024-01-15"),
    (2, "Bob", "bob@example.com", "2024-02-20"),
]

df_v1 = spark.createDataFrame(data_v1, schema_v1)

# --- Simulate Day 2 feed (v2 schema) ---
schema_v2 = StructType([
    StructField("user_id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("phone", StringType(), True),
    StructField("signup_date", StringType(), True),
    StructField("country", StringType(), True),
])

data_v2 = [
    (3, "Charlie", "555-0101", "2024-03-10", "US"),
    (4, "Diana", "555-0202", "2024-03-15", "UK"),
]

df_v2 = spark.createDataFrame(data_v2, schema_v2)

print("=== Day 1 Schema ===")
df_v1.printSchema()
df_v1.show()

print("=== Day 2 Schema ===")
df_v2.printSchema()
df_v2.show()

# --- Method 1a: unionByName with allowMissingColumns ---
# Available in Spark 3.1+
merged_df = df_v1.unionByName(df_v2, allowMissingColumns=True)

print("=== Merged with unionByName (allowMissingColumns=True) ===")
merged_df.show(truncate=False)
merged_df.printSchema()
```

## Method 2: Manual Schema Alignment Function

```python
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import col, lit
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType
)
from functools import reduce

spark = SparkSession.builder \
    .appName("ManualSchemaAlignment") \
    .master("local[*]") \
    .getOrCreate()

# Simulate multiple data sources with different schemas
data_partner_a = [
    (1, "Alice", "alice@example.com", "2024-01-15"),
    (2, "Bob", "bob@example.com", "2024-02-20"),
]
schema_a = StructType([
    StructField("user_id", IntegerType()),
    StructField("name", StringType()),
    StructField("email", StringType()),
    StructField("signup_date", StringType()),
])
df_a = spark.createDataFrame(data_partner_a, schema_a)

data_partner_b = [
    (3, "Charlie", "555-0101", "US"),
    (4, "Diana", "555-0202", "UK"),
]
schema_b = StructType([
    StructField("user_id", IntegerType()),
    StructField("name", StringType()),
    StructField("phone", StringType()),
    StructField("country", StringType()),
])
df_b = spark.createDataFrame(data_partner_b, schema_b)

data_partner_c = [
    (5, "Eve", 95000.0, "Engineering"),
]
schema_c = StructType([
    StructField("user_id", IntegerType()),
    StructField("name", StringType()),
    StructField("salary", DoubleType()),
    StructField("department", StringType()),
])
df_c = spark.createDataFrame(data_partner_c, schema_c)


def align_schemas(dataframes: list) -> list:
    """
    Align schemas of multiple DataFrames by adding missing columns as nulls.
    Returns list of DataFrames with identical schemas.
    """
    # Collect all unique columns and their types
    all_columns = {}
    for df in dataframes:
        for field in df.schema.fields:
            if field.name not in all_columns:
                all_columns[field.name] = field.dataType

    # Add missing columns to each DataFrame
    aligned = []
    for df in dataframes:
        existing_cols = {f.name for f in df.schema.fields}
        for col_name, col_type in all_columns.items():
            if col_name not in existing_cols:
                df = df.withColumn(col_name, lit(None).cast(col_type))
        # Reorder columns to match consistent order
        df = df.select(sorted(all_columns.keys()))
        aligned.append(df)

    return aligned


# Align and union all DataFrames
aligned_dfs = align_schemas([df_a, df_b, df_c])
unified_df = reduce(DataFrame.unionAll, aligned_dfs)

print("=== Unified DataFrame from 3 Partners ===")
unified_df.show(truncate=False)
unified_df.printSchema()
```

## Method 3: Schema Comparison and Migration Utilities

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, coalesce, when
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    DoubleType, LongType
)

spark = SparkSession.builder \
    .appName("SchemaMigration") \
    .master("local[*]") \
    .getOrCreate()

# --- Schema diff utility ---
def compare_schemas(old_schema: StructType, new_schema: StructType):
    """Compare two schemas and return added, removed, and changed columns."""
    old_fields = {f.name: f for f in old_schema.fields}
    new_fields = {f.name: f for f in new_schema.fields}

    added = {name: f for name, f in new_fields.items() if name not in old_fields}
    removed = {name: f for name, f in old_fields.items() if name not in new_fields}
    changed = {}
    for name in old_fields:
        if name in new_fields and old_fields[name].dataType != new_fields[name].dataType:
            changed[name] = {
                "old_type": old_fields[name].dataType,
                "new_type": new_fields[name].dataType
            }

    return {"added": added, "removed": removed, "type_changes": changed}


# Example schemas
old_schema = StructType([
    StructField("user_id", IntegerType()),
    StructField("name", StringType()),
    StructField("age", IntegerType()),
    StructField("email", StringType()),
])

new_schema = StructType([
    StructField("user_id", LongType()),       # type changed
    StructField("name", StringType()),         # unchanged
    StructField("phone", StringType()),        # added
    StructField("country", StringType()),      # added
    # email removed, age removed
])

diff = compare_schemas(old_schema, new_schema)
print("=== Schema Diff ===")
print(f"Added columns:   {list(diff['added'].keys())}")
print(f"Removed columns: {list(diff['removed'].keys())}")
print(f"Type changes:    {[(k, str(v['old_type']), str(v['new_type'])) for k, v in diff['type_changes'].items()]}")


# --- Migrate DataFrame from old schema to new schema ---
def migrate_dataframe(df, target_schema: StructType, drop_removed=False):
    """
    Migrate a DataFrame to a target schema:
    - Add missing columns as nulls
    - Cast changed types
    - Optionally drop columns not in target
    """
    target_fields = {f.name: f for f in target_schema.fields}
    current_fields = {f.name for f in df.schema.fields}

    # Add missing columns
    for name, field in target_fields.items():
        if name not in current_fields:
            df = df.withColumn(name, lit(None).cast(field.dataType))

    # Cast type mismatches
    for field in target_schema.fields:
        if field.name in current_fields:
            df = df.withColumn(field.name, col(field.name).cast(field.dataType))

    # Drop columns not in target schema
    if drop_removed:
        df = df.select([col(f.name) for f in target_schema.fields])
    else:
        # Keep all columns, reorder target cols first
        target_cols = [f.name for f in target_schema.fields]
        extra_cols = [c for c in df.columns if c not in target_cols]
        df = df.select(target_cols + extra_cols)

    return df


# Demonstrate migration
old_data = [(1, "Alice", 30, "alice@example.com"), (2, "Bob", 25, "bob@example.com")]
df_old = spark.createDataFrame(old_data, old_schema)

print("\n=== Before Migration ===")
df_old.show()
df_old.printSchema()

migrated_df = migrate_dataframe(df_old, new_schema, drop_removed=False)

print("=== After Migration (keeping removed cols) ===")
migrated_df.show()
migrated_df.printSchema()

migrated_df_clean = migrate_dataframe(df_old, new_schema, drop_removed=True)

print("=== After Migration (dropping removed cols) ===")
migrated_df_clean.show()
migrated_df_clean.printSchema()


# --- Rename columns mapping ---
def apply_column_renames(df, rename_map: dict):
    """Apply column renames from a mapping dict {old_name: new_name}."""
    for old_name, new_name in rename_map.items():
        if old_name in df.columns:
            df = df.withColumnRenamed(old_name, new_name)
    return df


# Example: rename columns
renamed_df = apply_column_renames(df_old, {"name": "full_name", "email": "email_address"})
print("=== After Column Renames ===")
renamed_df.show()
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| `unionByName(allowMissingColumns=True)` | Spark 3.1+ feature that unions DataFrames by column name, filling missing columns with null |
| Schema alignment | Manually adding missing columns as `lit(None).cast(type)` before union |
| Schema diff | Comparing StructType objects to detect added, removed, and type-changed columns |
| `cast()` | Converting column types during migration (e.g., IntegerType to LongType) |
| `withColumnRenamed()` | Renaming columns to handle naming convention changes |
| `mergeSchemas` option | Spark read option for Parquet/JSON to auto-merge schemas across files |

## Interview Tips

1. **Always mention `unionByName`** over `union` -- `union` matches by position, `unionByName` matches by column name, which is much safer for evolving schemas.
2. **Know the mergeSchema option**: When reading Parquet, `spark.read.option("mergeSchema", "true").parquet(path)` automatically merges schemas across partitions.
3. **Defensive coding**: In production, always validate incoming schemas against expected schemas before processing. Log diffs and alert on unexpected changes.
4. **Type widening is safe** (int -> long -> double), but narrowing (double -> int) can lose data. Be prepared to discuss safe type promotion rules.
5. **Delta Lake** handles schema evolution natively with `mergeSchema` and `overwriteSchema` options -- mention this if asked about production patterns.
6. **Column ordering** does not matter for Parquet but matters for CSV. Always use column names, not positions.
