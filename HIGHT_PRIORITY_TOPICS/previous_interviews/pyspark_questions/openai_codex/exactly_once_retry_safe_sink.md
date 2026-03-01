# PySpark Implementation: Exactly-Once Semantics Across Retries

## Problem Statement 

A streaming job can fail and restart. Ensure no duplicate sink records after retries.

### Requirements

- Deterministic unique key per output record.
- Checkpointing for source offsets and state.
- Idempotent sink write behavior.

---

## PySpark Code Pattern

```python
from pyspark.sql import functions as F

output = events.withColumn(
    "record_key",
    F.sha2(F.concat_ws("||", "event_id", "event_time", "user_id"), 256)
)

query = output.writeStream.format("delta").outputMode("append").option("checkpointLocation", "/tmp/chk/exactly_once").start("/tmp/out/exactly_once")
```

For strict dedup on retries, merge `record_key` into a Delta sink table instead of blind append.
