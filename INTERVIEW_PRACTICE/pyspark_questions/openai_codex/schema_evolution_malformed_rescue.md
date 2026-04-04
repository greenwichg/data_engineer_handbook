# PySpark Implementation: Schema Evolution + Malformed Record Rescue

## Problem Statement 

Ingest semi-structured JSON where schema evolves over time and malformed records appear. Build a resilient parsing layer that:
1. Captures bad records.
2. Preserves unknown fields when possible.
3. Continues processing valid rows.

### Sample Inputs

- Valid JSON with known fields.
- Valid JSON with extra fields.
- Corrupted JSON payload.

---

## PySpark Code Solution

```python
from pyspark.sql.types import StructType, StructField, StringType, DoubleType
from pyspark.sql import functions as F

schema = StructType([
    StructField("event_id", StringType()),
    StructField("user_id", StringType()),
    StructField("amount", DoubleType())
])

raw = spark.read.text("/data/raw/events_json")

parsed = raw.select(
    F.from_json(
        F.col("value"),
        schema,
        {"mode": "PERMISSIVE", "columnNameOfCorruptRecord": "_corrupt_record"}
    ).alias("r"),
    F.col("value").alias("raw_payload")
).select("r.*", "raw_payload")

quarantine = parsed.filter(F.col("_corrupt_record").isNotNull())
clean = parsed.filter(F.col("_corrupt_record").isNull())
```
