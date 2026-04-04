# PySpark Implementation: Interval Overlap Join at Scale

## Problem Statement 

Join high-volume user events with interval tables (pricing windows, entitlements, campaigns) using overlap logic:
`event_ts BETWEEN valid_from AND valid_to`.
Then optimize for skew and shuffle pressure.

### Expected Focus

- Correct temporal matching.
- Partitioning/bucketing strategy.
- Salting for hot keys.

---

## PySpark Code Solution

```python
from pyspark.sql import functions as F

# Optional skew mitigation for hot keys
salted_events = events.withColumn("salt", (F.rand() * 16).cast("int"))
salted_dims = dims.withColumn("salt", F.explode(F.array([F.lit(i) for i in range(16)])))

joined = salted_events.join(
    salted_dims,
    on=[
        salted_events.account_id == salted_dims.account_id,
        salted_events.salt == salted_dims.salt,
        salted_events.event_ts.between(salted_dims.valid_from, salted_dims.valid_to)
    ],
    how="left"
)
```
