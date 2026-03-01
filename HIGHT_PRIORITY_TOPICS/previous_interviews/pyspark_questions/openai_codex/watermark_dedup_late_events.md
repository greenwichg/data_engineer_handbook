# PySpark Implementation: Streaming Late Arrivals with Watermark + Dedup

## Problem Statement 

A clickstream pipeline receives **out-of-order** and **duplicate** events from Kafka. Build a Structured Streaming job that:
1. Parses event-time correctly.
2. Uses a watermark to bound state.
3. Deduplicates by `event_id` while still accepting late arrivals up to the watermark delay.

### Sample Input Events

| event_id | user_id | event_time           | page      |
|----------|---------|----------------------|-----------|
| E1       | U1      | 2025-01-15 10:00:00  | /home     |
| E2       | U1      | 2025-01-15 10:03:00  | /products |
| E2       | U1      | 2025-01-15 10:03:00  | /products |
| E3       | U2      | 2025-01-15 09:56:00  | /cart     |

### Expected Output

A cleaned stream where duplicate `event_id` rows are removed and only events within watermark tolerance are retained.

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType

spark = SparkSession.builder.appName("WatermarkDedup").getOrCreate()

schema = StructType([
    StructField("event_id", StringType()),
    StructField("user_id", StringType()),
    StructField("event_time", StringType()),
    StructField("page", StringType())
])

raw = spark.readStream.format("kafka").option("kafka.bootstrap.servers", "localhost:9092").option("subscribe", "clickstream").load()

parsed = raw.select(from_json(col("value").cast("string"), schema).alias("r")).select("r.*").withColumn("event_time", to_timestamp("event_time"))

clean = parsed.withWatermark("event_time", "10 minutes").dropDuplicates(["event_id"])

query = clean.writeStream.format("delta").option("checkpointLocation", "/tmp/chk/watermark_dedup").outputMode("append").start("/tmp/out/watermark_dedup")
```
