# PySpark Implementation: SCD Type 1 vs Type 2 Comparison

## Problem Statement 

From the same customer updates feed, create:
1. **SCD Type 1** output (overwrite old values).
2. **SCD Type 2** output (preserve history with effective date ranges).

Explain business trade-offs between current-state simplicity (Type 1) and audit/history (Type 2).

### Sample Input

| customer_id | name  | city    | effective_date |
|-------------|-------|---------|----------------|
| 101         | Alice | NYC     | 2025-01-01     |
| 101         | Alice | Boston  | 2025-02-01     |

---

## PySpark Code Sketch

```python
# Type 1: keep latest per key
latest = updates.withColumn(
    "rn",
    F.row_number().over(Window.partitionBy("customer_id").orderBy(F.col("effective_date").desc()))
).filter("rn = 1").drop("rn")

# Type 2: add start/end and current flag
w = Window.partitionBy("customer_id").orderBy("effective_date")
scd2 = updates.withColumn("start_date", F.col("effective_date"))     .withColumn("next_start", F.lead("effective_date").over(w))     .withColumn("end_date", F.coalesce(F.date_sub("next_start", 1), F.lit("9999-12-31")))     .withColumn("is_current", F.col("next_start").isNull())     .drop("next_start")
```
