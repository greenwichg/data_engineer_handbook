# PySpark Implementation: Stateful Streaming with `flatMapGroupsWithState`

## Problem Statement 

Track per-user inactivity in a streaming application. For each user, emit an alert when no event has been seen for **30 minutes**.

### Sample Input

| user_id | event_time           | event_type |
|---------|----------------------|------------|
| U1      | 2025-01-15 10:00:00  | click      |
| U1      | 2025-01-15 10:10:00  | click      |
| U2      | 2025-01-15 10:05:00  | login      |

### Expected Output

User-level state updates and timeout alerts (e.g., `U2 inactive since 10:05:00`).

---

## PySpark Code Solution (conceptual API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import to_timestamp
from pyspark.sql.streaming.state import GroupStateTimeout

spark = SparkSession.builder.appName("StatefulStreaming").getOrCreate()

# Assume input stream already parsed with columns: user_id, event_time, event_type
events = ...

# Event-time timeout setup
keyed = events.withColumn("event_time", to_timestamp("event_time"))

# NOTE: Python supports applyInPandasWithState for many stateful use-cases in modern Spark.
# Equivalent interview expectation: maintain last_seen_event_time per user and emit timeout alert.

def update_user_state(key, pdf_iter, state):
    # Pseudocode: track max event_time and emit alert on timeout
    pass

alerts = keyed.groupBy("user_id").applyInPandasWithState(
    func=update_user_state,
    outputStructType="user_id string, status string, last_seen timestamp",
    stateStructType="last_seen timestamp",
    outputMode="append",
    timeoutConf="EventTimeTimeout"
)

query = alerts.writeStream.format("console").start()
```
