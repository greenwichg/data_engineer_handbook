# PySpark Implementation: Data Quality Checks

## Problem Statement

Data quality validation is a critical step in any data pipeline. As a data engineer, you need to implement automated checks to ensure data meets expectations before it flows downstream. Common checks include completeness (no unexpected nulls), uniqueness (no duplicate keys), range/boundary validation, referential integrity, and format validation. This is a very common interview topic that tests practical pipeline engineering skills.

### Sample Data

```
customer_id | name     | email              | age  | signup_date | country | revenue
1           | Alice    | alice@test.com     | 30   | 2024-01-15  | US      | 1500.00
2           | Bob      | NULL               | 25   | 2024-02-20  | UK      | -50.00
3           | Charlie  | charlie@test.com   | 150  | 2024-03-10  | US      | 300.00
1           | Alice    | alice@test.com     | 30   | 2024-01-15  | US      | 1500.00
4           | Diana    | invalid-email      | NULL | 2024-13-01  | XX      | 0.00
5           | NULL     | eve@test.com       | 22   | 2024-04-05  | US      | 750.00
```

### Expected Output (Quality Report)

| check_name          | column      | status | details                          |
|---------------------|-------------|--------|----------------------------------|
| completeness        | name        | FAIL   | 1 null out of 6 rows (16.7%)     |
| completeness        | email       | FAIL   | 1 null out of 6 rows (16.7%)     |
| uniqueness          | customer_id | FAIL   | 1 duplicate found                |
| range_check         | age         | FAIL   | 1 value out of range [0, 120]    |
| non_negative        | revenue     | FAIL   | 1 negative value found           |
| email_format        | email       | FAIL   | 1 invalid email format           |

---

## Method 1: Comprehensive Data Quality Framework

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, when, isnan, isnull, sum as spark_sum,
    lit, countDistinct, min as spark_min, max as spark_max,
    mean, stddev, regexp_extract, length, concat_ws
)

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("DataQualityChecks") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data with intentional quality issues
data = [
    (1, "Alice",   "alice@test.com",   30,   "2024-01-15", "US", 1500.00),
    (2, "Bob",     None,               25,   "2024-02-20", "UK", -50.00),
    (3, "Charlie", "charlie@test.com", 150,  "2024-03-10", "US", 300.00),
    (1, "Alice",   "alice@test.com",   30,   "2024-01-15", "US", 1500.00),
    (4, "Diana",   "invalid-email",    None, "2024-13-01", "XX", 0.00),
    (5, None,      "eve@test.com",     22,   "2024-04-05", "US", 750.00),
]

df = spark.createDataFrame(
    data,
    ["customer_id", "name", "email", "age", "signup_date", "country", "revenue"]
)

total_rows = df.count()
quality_results = []

# --- CHECK 1: Completeness (null checks) ---
required_columns = ["customer_id", "name", "email", "age"]
for col_name in required_columns:
    null_count = df.filter(col(col_name).isNull()).count()
    status = "PASS" if null_count == 0 else "FAIL"
    pct = round(null_count / total_rows * 100, 1)
    quality_results.append((
        "completeness", col_name, status,
        f"{null_count} null out of {total_rows} rows ({pct}%)"
    ))

# --- CHECK 2: Uniqueness ---
unique_columns = ["customer_id"]
for col_name in unique_columns:
    distinct_count = df.select(col_name).distinct().count()
    dup_count = total_rows - distinct_count
    status = "PASS" if dup_count == 0 else "FAIL"
    quality_results.append((
        "uniqueness", col_name, status,
        f"{dup_count} duplicate(s) found"
    ))

# --- CHECK 3: Range checks ---
age_out_of_range = df.filter(
    (col("age") < 0) | (col("age") > 120)
).count()
status = "PASS" if age_out_of_range == 0 else "FAIL"
quality_results.append((
    "range_check", "age", status,
    f"{age_out_of_range} value(s) out of range [0, 120]"
))

# --- CHECK 4: Non-negative check ---
negative_revenue = df.filter(col("revenue") < 0).count()
status = "PASS" if negative_revenue == 0 else "FAIL"
quality_results.append((
    "non_negative", "revenue", status,
    f"{negative_revenue} negative value(s) found"
))

# --- CHECK 5: Format validation (email) ---
email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
invalid_emails = df.filter(
    col("email").isNotNull() &
    (regexp_extract(col("email"), email_pattern, 0) == "")
).count()
status = "PASS" if invalid_emails == 0 else "FAIL"
quality_results.append((
    "email_format", "email", status,
    f"{invalid_emails} invalid email format(s)"
))

# Create report DataFrame
report_df = spark.createDataFrame(
    quality_results,
    ["check_name", "column", "status", "details"]
)

print("=== DATA QUALITY REPORT ===")
report_df.show(truncate=False)

spark.stop()
```

## Method 2: Reusable Quality Check Class

```python
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import (
    col, count, when, isnull, sum as spark_sum,
    lit, countDistinct, regexp_extract, to_date
)
from dataclasses import dataclass
from typing import List, Optional

spark = SparkSession.builder \
    .appName("DataQualityChecks_Class") \
    .master("local[*]") \
    .getOrCreate()

@dataclass
class QualityCheckResult:
    check_name: str
    column: str
    status: str
    details: str

class DataQualityValidator:
    def __init__(self, df: DataFrame, spark_session):
        self.df = df
        self.spark = spark_session
        self.total_rows = df.count()
        self.results: List[QualityCheckResult] = []

    def check_completeness(self, columns: List[str], threshold: float = 1.0):
        """Check that columns have non-null values above a threshold."""
        for col_name in columns:
            null_count = self.df.filter(col(col_name).isNull()).count()
            completeness = 1 - (null_count / self.total_rows)
            status = "PASS" if completeness >= threshold else "FAIL"
            self.results.append(QualityCheckResult(
                "completeness", col_name, status,
                f"Completeness: {completeness:.1%} (threshold: {threshold:.0%})"
            ))
        return self

    def check_uniqueness(self, columns: List[str]):
        """Check that column values are unique (no duplicates)."""
        for col_name in columns:
            distinct = self.df.select(col_name).distinct().count()
            dup_count = self.total_rows - distinct
            status = "PASS" if dup_count == 0 else "FAIL"
            self.results.append(QualityCheckResult(
                "uniqueness", col_name, status,
                f"{dup_count} duplicate(s) in {self.total_rows} rows"
            ))
        return self

    def check_range(self, column: str, min_val, max_val):
        """Check values are within expected range."""
        out_of_range = self.df.filter(
            col(column).isNotNull() &
            ((col(column) < min_val) | (col(column) > max_val))
        ).count()
        status = "PASS" if out_of_range == 0 else "FAIL"
        self.results.append(QualityCheckResult(
            "range_check", column, status,
            f"{out_of_range} value(s) outside [{min_val}, {max_val}]"
        ))
        return self

    def check_allowed_values(self, column: str, allowed: List[str]):
        """Check that column only contains allowed values."""
        invalid = self.df.filter(
            col(column).isNotNull() & ~col(column).isin(allowed)
        ).count()
        status = "PASS" if invalid == 0 else "FAIL"
        self.results.append(QualityCheckResult(
            "allowed_values", column, status,
            f"{invalid} value(s) not in {allowed}"
        ))
        return self

    def check_regex(self, column: str, pattern: str, description: str = ""):
        """Check values match a regex pattern."""
        invalid = self.df.filter(
            col(column).isNotNull() &
            (regexp_extract(col(column), pattern, 0) == "")
        ).count()
        status = "PASS" if invalid == 0 else "FAIL"
        self.results.append(QualityCheckResult(
            f"format_{description}", column, status,
            f"{invalid} value(s) do not match pattern"
        ))
        return self

    def check_referential_integrity(self, column: str, reference_df: DataFrame, ref_column: str):
        """Check that all values exist in the reference table."""
        orphans = self.df.join(
            reference_df,
            self.df[column] == reference_df[ref_column],
            "left_anti"
        ).filter(col(column).isNotNull()).count()
        status = "PASS" if orphans == 0 else "FAIL"
        self.results.append(QualityCheckResult(
            "referential_integrity", column, status,
            f"{orphans} orphan record(s) found"
        ))
        return self

    def get_report(self) -> DataFrame:
        """Return results as a DataFrame."""
        rows = [(r.check_name, r.column, r.status, r.details)
                for r in self.results]
        return self.spark.createDataFrame(
            rows, ["check_name", "column", "status", "details"]
        )

# --- Run the checks ---
data = [
    (1, "Alice",   "alice@test.com",   30,   "2024-01-15", "US", 1500.00),
    (2, "Bob",     None,               25,   "2024-02-20", "UK", -50.00),
    (3, "Charlie", "charlie@test.com", 150,  "2024-03-10", "US", 300.00),
    (1, "Alice",   "alice@test.com",   30,   "2024-01-15", "US", 1500.00),
    (4, "Diana",   "invalid-email",    None, "2024-13-01", "XX", 0.00),
    (5, None,      "eve@test.com",     22,   "2024-04-05", "US", 750.00),
]

df = spark.createDataFrame(
    data,
    ["customer_id", "name", "email", "age", "signup_date", "country", "revenue"]
)

valid_countries = spark.createDataFrame(
    [("US",), ("UK",), ("CA",), ("DE",)], ["country_code"]
)

validator = DataQualityValidator(df, spark)
report = (
    validator
    .check_completeness(["customer_id", "name", "email", "age"])
    .check_uniqueness(["customer_id"])
    .check_range("age", 0, 120)
    .check_range("revenue", 0, float("inf"))
    .check_regex("email", r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', "email")
    .check_allowed_values("country", ["US", "UK", "CA", "DE"])
    .check_referential_integrity("country", valid_countries, "country_code")
    .get_report()
)

print("=== COMPREHENSIVE DATA QUALITY REPORT ===")
report.show(truncate=False)

# Summary
print("=== SUMMARY ===")
report.groupBy("status").count().show()

spark.stop()
```

## Interview Tips

- **Layered approach**: Explain that quality checks should run at multiple stages: at ingestion (schema validation), after transformation (business rules), and before loading (final gate).
- **Fail fast vs. collect**: Discuss whether the pipeline should halt on the first failure or collect all issues for a comprehensive report. Most production systems collect all issues.
- **Great Expectations**: Mention that in production, tools like Great Expectations or Deequ (by AWS) provide frameworks for declarative data quality rules. Show you know the ecosystem.
- **Quarantine pattern**: Bad records can be routed to a quarantine table for manual review rather than dropped silently.
- **Metrics over time**: Track quality metrics historically to detect degradation trends (e.g., null rate creeping up over weeks).
- **Performance**: For large datasets, use approximate functions (`approx_count_distinct`) and sampling for profiling checks to avoid expensive full scans.
