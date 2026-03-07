# PySpark Implementation: Data Type Casting and Schema Enforcement

## Problem Statement

Given a DataFrame with mixed or incorrect data types (e.g., numbers stored as strings, dates as strings), **cast columns to proper types**, handle invalid values gracefully, and enforce a target schema. This is a common interview topic covering data cleaning and type safety.

### Sample Data

```
id    name       age    salary      join_date     is_active
1     Alice      30     75000.50    2020-01-15    true
2     Bob        abc    60000       2019-03-22    false
3     Charlie    25     N/A         2021-06-01    1
4     Diana      35     85000.75    invalid       true
5     Eve        28     70000       2022-11-30    0
```

All columns arrive as StringType.

### Expected Output (after casting)

| id  | name    | age  | salary   | join_date  | is_active |
|-----|---------|------|----------|------------|-----------|
| 1   | Alice   | 30   | 75000.50 | 2020-01-15 | true      |
| 2   | Bob     | null | 60000.00 | 2019-03-22 | false     |
| 3   | Charlie | 25   | null     | 2021-06-01 | true      |
| 4   | Diana   | 35   | 85000.75 | null       | true      |
| 5   | Eve     | 28   | 70000.00 | 2022-11-30 | false     |

---

## Method 1: Using cast() for Column-Level Type Casting

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, when, lit
from pyspark.sql.types import IntegerType, DoubleType, BooleanType, DateType

spark = SparkSession.builder.appName("DataTypeCasting").getOrCreate()

# All columns as strings (simulating raw ingestion)
data = [
    ("1", "Alice", "30", "75000.50", "2020-01-15", "true"),
    ("2", "Bob", "abc", "60000", "2019-03-22", "false"),
    ("3", "Charlie", "25", "N/A", "2021-06-01", "1"),
    ("4", "Diana", "35", "85000.75", "invalid", "true"),
    ("5", "Eve", "28", "70000", "2022-11-30", "0"),
]
df = spark.createDataFrame(data, ["id", "name", "age", "salary", "join_date", "is_active"])

# Cast columns — invalid values become null automatically
df_casted = df \
    .withColumn("id", col("id").cast(IntegerType())) \
    .withColumn("age", col("age").cast(IntegerType())) \
    .withColumn("salary", col("salary").cast(DoubleType())) \
    .withColumn("join_date", to_date(col("join_date"), "yyyy-MM-dd")) \
    .withColumn("is_active",
        when(col("is_active").isin("true", "1", "yes"), lit(True))
        .when(col("is_active").isin("false", "0", "no"), lit(False))
        .otherwise(lit(None).cast(BooleanType()))
    )

df_casted.show()
df_casted.printSchema()
```

### Step-by-Step Explanation

- **cast(IntegerType()):** `"abc"` becomes `null` — PySpark does not throw errors on invalid casts
- **cast(DoubleType()):** `"N/A"` becomes `null`
- **to_date():** `"invalid"` becomes `null` since it doesn't match the date format
- **Boolean mapping:** Manually map `"1"/"0"` and `"true"/"false"` to proper booleans

---

## Method 2: Enforcing a Target Schema with StructType

```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType, DateType

# Define target schema
target_schema = StructType([
    StructField("id", IntegerType(), True),
    StructField("name", StringType(), True),
    StructField("age", IntegerType(), True),
    StructField("salary", DoubleType(), True),
    StructField("join_date", StringType(), True),
    StructField("is_active", StringType(), True),
])

# Read with enforced schema (e.g., from CSV)
# df = spark.read.schema(target_schema).csv("path/to/file.csv", header=True)

# Or apply schema to existing DataFrame using selectExpr
df_enforced = df.selectExpr(
    "CAST(id AS INT) AS id",
    "name",
    "CAST(age AS INT) AS age",
    "CAST(salary AS DOUBLE) AS salary",
    "CAST(join_date AS DATE) AS join_date",
    "is_active"
)

df_enforced.printSchema()
df_enforced.show()
```

---

## Method 3: Safe Casting with Validation

```python
from pyspark.sql.functions import col, when, regexp_replace

# Validate before casting — flag bad records
df_validated = df \
    .withColumn("age_valid", col("age").rlike("^[0-9]+$")) \
    .withColumn("salary_valid", col("salary").rlike("^[0-9]+(\\.[0-9]+)?$")) \
    .withColumn("date_valid", col("join_date").rlike("^\\d{4}-\\d{2}-\\d{2}$"))

# Show which records have issues
df_validated.select("id", "name", "age_valid", "salary_valid", "date_valid").show()

# Separate good vs bad records
good_records = df_validated.filter(
    col("age_valid") & col("salary_valid") & col("date_valid")
)
bad_records = df_validated.filter(
    ~(col("age_valid") & col("salary_valid") & col("date_valid"))
)

print(f"Good records: {good_records.count()}")
print(f"Bad records: {bad_records.count()}")
```

**Output:**
```
+---+-------+---------+------------+----------+
| id|   name|age_valid|salary_valid|date_valid|
+---+-------+---------+------------+----------+
|  1|  Alice|     true|        true|      true|
|  2|    Bob|    false|        true|      true|
|  3|Charlie|     true|       false|      true|
|  4|  Diana|     true|        true|     false|
|  5|    Eve|     true|        true|      true|
+---+-------+---------+------------+----------+

Good records: 2
Bad records: 3
```

---

## Method 4: Bulk Casting with a Mapping Dictionary

```python
# Define type mappings
type_mapping = {
    "id": "INT",
    "age": "INT",
    "salary": "DOUBLE",
    "join_date": "DATE"
}

# Apply all casts dynamically
df_bulk = df
for column_name, target_type in type_mapping.items():
    df_bulk = df_bulk.withColumn(column_name, col(column_name).cast(target_type))

df_bulk.printSchema()
df_bulk.show()
```

---

## Method 5: Handling Decimal Precision for Financial Data

```python
from pyspark.sql.types import DecimalType

# Financial data needs exact precision — avoid floating point errors
df_precise = df \
    .withColumn("salary", col("salary").cast(DecimalType(12, 2)))

df_precise.printSchema()
# root
#  |-- salary: decimal(12,2)

df_precise.select("name", "salary").show()
```

---

## Key Interview Talking Points

1. **cast() returns null on failure:** PySpark does not throw exceptions for invalid casts — it silently returns null. This is different from Python's `int()` which raises `ValueError`.

2. **StringType → DateType:** Use `to_date()` with explicit format rather than `cast("date")` for more control over parsing.

3. **Schema enforcement at read time:** When reading CSV/JSON, pass `schema=` to avoid type inference (which reads the full file and can be wrong). This is faster and more reliable.

4. **mode options for reads:** `PERMISSIVE` (default, nulls for bad records), `DROPMALFORMED` (drops bad rows), `FAILFAST` (throws exception on bad records).

5. **DecimalType vs DoubleType:** Use `DecimalType` for financial data to avoid floating-point precision issues. `DoubleType` is faster but imprecise.

6. **Column ordering:** `cast()` preserves column order. Schema enforcement with `StructType` controls both types and column order.
