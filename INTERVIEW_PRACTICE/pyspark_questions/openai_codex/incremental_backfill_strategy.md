# PySpark Implementation: Incremental Backfill Without Full Reprocessing

## Problem Statement 

A daily batch pipeline missed processing for several historical partitions. Backfill only missing date partitions while preserving SLA for current-day loads.

### Requirements

1. Detect missing partitions from metadata/control table.
2. Process only required date range.
3. Upsert safely into target tables.
4. Keep normal daily run independent from long backfill runs.

---

## PySpark Code Pattern

```python
missing = spark.sql("""
SELECT dt
FROM metadata.expected_partitions
EXCEPT
SELECT DISTINCT dt FROM silver.fact_orders
""")

for row in missing.collect():
    dt = row["dt"]
    src = spark.read.table("bronze.orders").filter(F.col("dt") == dt)
    transformed = transform_orders(src)
    write_upsert(transformed, dt)
```

Use bounded loops/chunking (e.g., by week) for large backfills and separate checkpoint/output paths from daily jobs.
