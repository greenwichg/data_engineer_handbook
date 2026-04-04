# PySpark Implementation: String Parsing and Extraction

## Problem Statement
Given raw application log strings with embedded metadata, parse each line to extract
the timestamp, log level, service name, message text, and all embedded key-value pairs
into separate columns. This simulates a common data-engineering task where semi-structured
text must be converted into a queryable, columnar format.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, MapType

spark = SparkSession.builder.appName("StringParsing").getOrCreate()

raw_logs = [
    "2024-01-15 08:23:01 ERROR [auth-service] User login failed: user_id=123, ip=10.0.0.1",
    "2024-01-15 08:23:05 WARN  [payment-service] Retry limit approaching: order_id=456, attempt=3",
    "2024-01-15 08:24:12 INFO  [auth-service] User login succeeded: user_id=789, ip=10.0.0.5",
    "2024-01-15 08:25:00 ERROR [inventory-service] Stock check failed: sku=WIDGET-42, warehouse=US-EAST",
    "2024-01-15 08:25:33 DEBUG [api-gateway] Request routed: path=/api/v2/orders, method=POST",
]

df = spark.createDataFrame([(line,) for line in raw_logs], ["raw_log"])
df.show(truncate=False)
```

### Expected Output
| timestamp           | level | service           | message                  | kv_pairs                                        |
|---------------------|-------|-------------------|--------------------------|-------------------------------------------------|
| 2024-01-15 08:23:01 | ERROR | auth-service      | User login failed        | {user_id: 123, ip: 10.0.0.1}                   |
| 2024-01-15 08:23:05 | WARN  | payment-service   | Retry limit approaching  | {order_id: 456, attempt: 3}                     |
| 2024-01-15 08:24:12 | INFO  | auth-service      | User login succeeded     | {user_id: 789, ip: 10.0.0.5}                   |
| 2024-01-15 08:25:00 | ERROR | inventory-service | Stock check failed       | {sku: WIDGET-42, warehouse: US-EAST}            |
| 2024-01-15 08:25:33 | DEBUG | api-gateway       | Request routed           | {path: /api/v2/orders, method: POST}            |

---

## Method 1: regexp_extract with str_to_map (Recommended)
```python
parsed = df.select(
    # Extract timestamp -- first 19 characters matching datetime pattern
    F.regexp_extract("raw_log", r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", 1)
     .alias("timestamp"),

    # Extract log level -- word after the timestamp
    F.regexp_extract("raw_log", r"^\S+ \S+ (\w+)", 1).alias("level"),

    # Extract service name -- text inside square brackets
    F.regexp_extract("raw_log", r"\[([^\]]+)\]", 1).alias("service"),

    # Extract the human-readable message -- text between '] ' and ':'
    F.regexp_extract("raw_log", r"\]\s+(.+?):\s+\w+=", 1).alias("message"),

    # Extract the key-value portion -- everything after the first ': '
    F.regexp_extract("raw_log", r"\]\s+.+?:\s+(.+)$", 1).alias("kv_raw"),
)

# Convert the comma-separated key=value string into a MapType column
result = parsed.withColumn(
    "kv_pairs",
    F.str_to_map(F.col("kv_raw"), ",", "=")
).drop("kv_raw")

# Trim whitespace from map keys
result = result.withColumn(
    "kv_pairs",
    F.transform_keys("kv_pairs", lambda k, v: F.trim(k))
)

result.show(truncate=False)
```

### Step-by-Step Explanation

**Step 1 -- Raw input:**
| raw_log                                                                                  |
|------------------------------------------------------------------------------------------|
| 2024-01-15 08:23:01 ERROR [auth-service] User login failed: user_id=123, ip=10.0.0.1    |

**Step 2 -- After regexp_extract calls (parsed DataFrame):**
| timestamp           | level | service      | message           | kv_raw                      |
|---------------------|-------|--------------|-------------------|-----------------------------|
| 2024-01-15 08:23:01 | ERROR | auth-service | User login failed | user_id=123, ip=10.0.0.1    |

**Step 3 -- After str_to_map converts kv_raw to a map column:**
| timestamp           | level | service      | message           | kv_pairs                      |
|---------------------|-------|--------------|-------------------|-------------------------------|
| 2024-01-15 08:23:01 | ERROR | auth-service | User login failed | {user_id: 123, ip: 10.0.0.1} |

**Step 4 -- Optionally explode the map to pivot specific keys into columns:**
```python
final = result.select(
    "timestamp", "level", "service", "message",
    F.col("kv_pairs")["user_id"].alias("user_id"),
    F.col("kv_pairs")["ip"].alias("ip"),
)
```
| timestamp           | level | service      | message           | user_id | ip        |
|---------------------|-------|--------------|-------------------|---------|-----------|
| 2024-01-15 08:23:01 | ERROR | auth-service | User login failed | 123     | 10.0.0.1  |

---

## Method 2: Split-Based Parsing with UDF Fallback
```python
from pyspark.sql.types import MapType, StringType
import re

@F.udf(returnType=MapType(StringType(), StringType()))
def parse_kv_pairs(log_line):
    """Extract all key=value tokens from anywhere in the string."""
    if log_line is None:
        return {}
    pairs = re.findall(r"(\w[\w.-]*)=([\w./-]+)", log_line)
    return {k: v for k, v in pairs}

@F.udf(returnType=StringType())
def extract_message(log_line):
    """Extract the human-readable message between bracket-close and colon."""
    if log_line is None:
        return None
    match = re.search(r"\]\s+(.+?):\s+\w+=", log_line)
    return match.group(1).strip() if match else None

split_col = F.split("raw_log", r"\s+")

result2 = df.select(
    # Timestamp from positions 0 and 1
    F.concat_ws(" ", split_col[0], split_col[1]).alias("timestamp"),
    # Level at position 2
    F.trim(split_col[2]).alias("level"),
    # Service -- strip brackets from position 3
    F.regexp_replace(split_col[3], r"[\[\]]", "").alias("service"),
    # Message via UDF
    extract_message("raw_log").alias("message"),
    # Key-value pairs via UDF
    parse_kv_pairs("raw_log").alias("kv_pairs"),
)

result2.show(truncate=False)
```

---

## Bonus: Parsing URLs, Emails, and File Paths
```python
misc_data = spark.createDataFrame([
    ("https://api.example.com:8080/v2/users?role=admin&active=true",),
    ("jane.doe@engineering.example.co.uk",),
    ("/var/log/app/2024/01/service-auth.log.gz",),
], ["raw_value"])

url_parsed = misc_data.limit(1).select(
    F.regexp_extract("raw_value", r"^(https?)://", 1).alias("scheme"),
    F.regexp_extract("raw_value", r"://([^:/]+)", 1).alias("host"),
    F.regexp_extract("raw_value", r":(\d+)/", 1).alias("port"),
    F.regexp_extract("raw_value", r":\d+(\/[^?]+)", 1).alias("path"),
    F.regexp_extract("raw_value", r"\?(.+)$", 1).alias("query_string"),
)
url_parsed.show(truncate=False)

email_parsed = misc_data.filter(F.col("raw_value").contains("@")).select(
    F.regexp_extract("raw_value", r"^([^@]+)", 1).alias("local_part"),
    F.regexp_extract("raw_value", r"@(.+)$", 1).alias("domain"),
)
email_parsed.show(truncate=False)
```

---

## Key Interview Talking Points
1. **regexp_extract vs. split** -- `regexp_extract` is more resilient to format variations (extra spaces, optional fields) than positional splitting.
2. **str_to_map** -- A built-in function that converts delimited key-value strings into a native MapType column, avoiding the overhead of a Python UDF.
3. **UDF trade-offs** -- Python UDFs cause serialization between JVM and Python. Prefer built-in functions; use UDFs only when regex alone cannot express the logic.
4. **Schema-on-read** -- Parsing raw strings into typed columns at read time is a core data-engineering pattern (e.g., ingesting JSON logs from Kafka).
5. **Handling malformed rows** -- In production, wrap extractions with `F.when` or `F.coalesce` so that rows that do not match the pattern return nulls instead of causing failures.
6. **Performance at scale** -- Built-in regex functions are executed in the JVM and can leverage Spark's whole-stage code generation, while Python UDFs cannot.
7. **transform_keys / transform_values** -- Higher-order functions available since Spark 3.0 that let you clean map contents without exploding.
