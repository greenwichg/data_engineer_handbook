# PySpark Implementation: Full Outer Join for Grouped Count Reconciliation

## Problem Statement 

Given two tables `tbl_1` and `tbl_2`, compare grouped row counts across a composite key (`column1`, `column2`, `column3`).

You need to:
1. Aggregate each table by the 3 columns.
2. Perform a **full outer join** across those grouped results.
3. Use `COALESCE` so keys appear even when present on only one side.
4. Return `tb1_count` and `tb2_count` to identify mismatches and missing groups.

This pattern is commonly asked for **data reconciliation** interviews.

### SQL Pattern (Given)

```sql
SELECT 
    COALESCE(t1.column1, t2.column1) AS column1,
    COALESCE(t1.column2, t2.column2) AS column2,
    COALESCE(t1.column3, t2.column3) AS column3,
    t1.tb1_count,
    t2.tb2_count
FROM
(
    SELECT column1, column2, column3, COUNT(*) AS tb1_count
    FROM tbl_1
    GROUP BY column1, column2, column3
) t1
FULL OUTER JOIN
(
    SELECT column1, column2, column3, COUNT(*) AS tb2_count
    FROM tbl_2
    GROUP BY column1, column2, column3
) t2
ON t1.column1 = t2.column1
AND t1.column2 = t2.column2
AND t1.column3 = t2.column3;
```

---

## Sample Input

### `tbl_1`

| column1 | column2 | column3 |
|---------|---------|---------|
| A       | X       | 1       |
| A       | X       | 1       |
| B       | Y       | 2       |
| C       | Z       | 3       |

### `tbl_2`

| column1 | column2 | column3 |
|---------|---------|---------|
| A       | X       | 1       |
| B       | Y       | 2       |
| B       | Y       | 2       |
| D       | W       | 4       |

### Expected Output

| column1 | column2 | column3 | tb1_count | tb2_count |
|---------|---------|---------|-----------|-----------|
| A       | X       | 1       | 2         | 1         |
| B       | Y       | 2       | 1         | 2         |
| C       | Z       | 3       | 1         | null      |
| D       | W       | 4       | null      | 1         |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, coalesce, when, lit

spark = SparkSession.builder.appName("GroupedCountReconciliation").getOrCreate()

# Example inputs
data1 = [
    ("A", "X", 1),
    ("A", "X", 1),
    ("B", "Y", 2),
    ("C", "Z", 3)
]

data2 = [
    ("A", "X", 1),
    ("B", "Y", 2),
    ("B", "Y", 2),
    ("D", "W", 4)
]

cols = ["column1", "column2", "column3"]
tbl_1 = spark.createDataFrame(data1, cols)
tbl_2 = spark.createDataFrame(data2, cols)

# 1) Aggregate each table
agg_1 = tbl_1.groupBy("column1", "column2", "column3").agg(
    count("*").alias("tb1_count")
)

agg_2 = tbl_2.groupBy("column1", "column2", "column3").agg(
    count("*").alias("tb2_count")
)

# 2) Full outer join on composite key
joined = agg_1.alias("t1").join(
    agg_2.alias("t2"),
    on=[
        col("t1.column1") == col("t2.column1"),
        col("t1.column2") == col("t2.column2"),
        col("t1.column3") == col("t2.column3")
    ],
    how="full_outer"
)

# 3) COALESCE keys + keep both counts
result = joined.select(
    coalesce(col("t1.column1"), col("t2.column1")).alias("column1"),
    coalesce(col("t1.column2"), col("t2.column2")).alias("column2"),
    coalesce(col("t1.column3"), col("t2.column3")).alias("column3"),
    col("t1.tb1_count"),
    col("t2.tb2_count")
)

# Optional: add reconciliation status
result_with_status = result.withColumn(
    "status",
    when(col("tb1_count").isNull(), lit("ONLY_IN_TBL_2"))
    .when(col("tb2_count").isNull(), lit("ONLY_IN_TBL_1"))
    .when(col("tb1_count") != col("tb2_count"), lit("COUNT_MISMATCH"))
    .otherwise(lit("MATCH"))
)

result_with_status.orderBy("column1", "column2", "column3").show(truncate=False)
```

---

## Interview Talking Points

1. Why `FULL OUTER JOIN` and not `INNER`/`LEFT` only?  
   - Full join retains groups missing in either table.

2. Why `COALESCE` on keys?  
   - Full joins produce null key columns on one side for non-matching groups.

3. What if null keys exist in source data?  
   - Standard equality joins do not match nulls; use null-safe equality (`<=>`) in SQL or `eqNullSafe` in PySpark if required.

4. How to scale this for large tables?  
   - Pre-aggregate first (as done), then join smaller grouped outputs; monitor skew and consider repartitioning on composite keys.
