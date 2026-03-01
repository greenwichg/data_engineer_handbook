# PySpark Implementation: CDC Ingestion with Idempotent Upserts

## Problem Statement 

Given a CDC stream (`I`, `U`, `D`) for customer records, build an idempotent silver table so retries/replays do not create duplicates or stale rows.

### Sample CDC Input

| customer_id | op | name  | city    | updated_at           |
|-------------|----|-------|---------|----------------------|
| 101         | I  | Alice | NYC     | 2025-01-15 10:00:00  |
| 101         | U  | Alice | Boston  | 2025-01-15 10:05:00  |
| 102         | D  | Bob   | Chicago | 2025-01-15 10:07:00  |

### Expected Output

A target table with latest valid state per key, honoring delete operations and deterministic ordering by `updated_at`.

---

## PySpark + Delta MERGE Solution

```python
from delta.tables import DeltaTable
from pyspark.sql import functions as F

cdc = spark.read.table("bronze.customer_cdc")

latest_per_key = cdc.withColumn(
    "rn",
    F.row_number().over(
        Window.partitionBy("customer_id").orderBy(F.col("updated_at").desc())
    )
).filter("rn = 1").drop("rn")

silver = DeltaTable.forName(spark, "silver.customer")

(silver.alias("t")
 .merge(latest_per_key.alias("s"), "t.customer_id = s.customer_id")
 .whenMatchedUpdate(condition="s.op IN ('I','U')", set={
     "name": "s.name",
     "city": "s.city",
     "updated_at": "s.updated_at"
 })
 .whenMatchedDelete(condition="s.op = 'D'")
 .whenNotMatchedInsert(condition="s.op IN ('I','U')", values={
     "customer_id": "s.customer_id",
     "name": "s.name",
     "city": "s.city",
     "updated_at": "s.updated_at"
 })
 .execute())
```
