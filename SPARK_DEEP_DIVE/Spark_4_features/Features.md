# Apache Spark 4.0 — New Features Guide

> Released: February 2025 | Resolved 5,100+ tickets | 390+ contributors

---

## 🧠 Mnemonic to Remember Spark 4.0 Features

### **"SCALE VP"**

| Letter | Feature |
|--------|---------|
| **S** | **S**park Connect (remote client-server) |
| **C** | **C**ollation Support (multilingual string comparison) |
| **A** | **A**NSI SQL Mode by default |
| **L** | **L**ogging — Structured JSON logging |
| **E** | **E**rror Class Framework (standardised errors) |
| **V** | **V**ARIANT data type (semi-structured JSON) |
| **P** | **P**ython advances (UDTFs, Data Source API, Plotly) |

> Think: **"Spark will SCALE VP (Vice President)"** — because Spark 4.0 levelled up!

---

## 1. S — Spark Connect

### What it is
A lightweight **client-server architecture** that lets you connect to a remote Spark cluster from any device or IDE — without needing a full Spark installation.

- Old PySpark client: **355 MB**
- New `pyspark-connect` client: **1.5 MB** ⚡

### Simple Example

```python
# Install: pip install pyspark-connect

from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MyApp") \
    .remote("sc://my-spark-server:15002") \  # Connect to remote cluster!
    .getOrCreate()

df = spark.read.csv("data.csv", header=True)
df.show()
```

**Before Spark 4.0:** You had to install the full PySpark (355 MB) and run code locally tied to the cluster.

**After Spark 4.0:** Install a tiny 1.5 MB client, point it to any remote Spark server, and run your code from PyCharm, Jupyter, or even a laptop.

---

## 2. C — Collation Support

### What it is
Collation controls **how strings are compared and sorted** — especially useful for multilingual data where case sensitivity and accents matter.

### Simple Example

```sql
-- Without collation: 'apple' ≠ 'APPLE'
SELECT * FROM fruits WHERE name = 'apple';   -- misses 'Apple', 'APPLE'

-- With collation: case-insensitive comparison
SELECT * FROM fruits WHERE name = 'apple' COLLATE UTF8_CI;  -- matches all variants
```

```python
from pyspark.sql.functions import col

# Create DataFrame with collation-aware column
df = spark.createDataFrame([("café",), ("Cafe",), ("CAFE",)], ["name"])

# Case-insensitive + accent-insensitive grouping
df.groupBy(col("name").collate("UTF8_CI_AI")).count().show()
# All three rows now group as one!
```

**Real-world use:** An e-commerce app searching for "jose" should also return "José" and "JOSE". Collation makes that possible without writing custom logic.

---

## 3. A — ANSI SQL Mode (Now Default)

### What it is
Spark 4.0 enables **ANSI SQL compliance by default**. This means Spark now behaves like a standard SQL database — stricter type handling, proper error throwing instead of silent nulls.

### Simple Example

```python
# Spark 3.x — silently returned NULL on overflow (bad!)
df = spark.sql("SELECT 2147483647 + 1")  # Returns NULL silently
df.show()
# +----+
# |null|

# Spark 4.0 — throws a proper error (good!)
df = spark.sql("SELECT 2147483647 + 1")
# ArithmeticException: integer overflow
```

```python
# Type casting is also stricter
spark.sql("SELECT CAST('abc' AS INT)")
# Spark 3.x: returns NULL
# Spark 4.0: raises an error — no more silent data corruption!
```

**Why it matters:** In Spark 3.x, bad data would silently produce NULLs and corrupt your pipeline without any warning. Now you get a loud error immediately — much safer for production.

---

## 4. L — Structured Logging (JSON Format)

### What it is
Spark 4.0 introduces **structured JSON logging** — logs are now machine-readable JSON instead of plain text, making it easier to parse, search, and monitor.

### Simple Example

**Old log format (Spark 3.x) — plain text:**
```
24/01/15 10:23:45 INFO SparkContext: Running Spark version 3.5.0
24/01/15 10:23:46 WARN TaskSetManager: Lost task 1.0 in stage 0.0
```

**New log format (Spark 4.0) — structured JSON:**
```json
{
  "ts": "2025-01-15T10:23:45.123Z",
  "level": "INFO",
  "logger": "SparkContext",
  "msg": "Running Spark version 4.0.0",
  "context": {
    "appId": "app-001",
    "executor": "driver"
  }
}
```

**Why it matters:** You can now feed Spark logs directly into tools like **Elasticsearch, Splunk, or Datadog** without any custom parsing. Searching for all WARN logs from a specific app becomes a simple JSON query.

---

## 5. E — Error Class Framework

### What it is
Standardised, **human-readable error codes and messages** across all of Spark. Every error now has a consistent class name, a clear description, and actionable guidance.

### Simple Example

**Old error (Spark 3.x) — cryptic:**
```
org.apache.spark.sql.AnalysisException:
cannot resolve '`salary`' given input columns: [id, name, age]
```

**New error (Spark 4.0) — structured and clear:**
```
[UNRESOLVED_COLUMN.WITH_SUGGESTION]
A column or function parameter with name `salary` cannot be resolved.
Did you mean one of the following? [`id`, `name`, `age`]

Error class: UNRESOLVED_COLUMN
Suggestion: Check the column name spelling or the DataFrame schema.
```

```python
# Errors are now catchable by class
try:
    df.select("salary")
except AnalysisException as e:
    print(e.getErrorClass())   # "UNRESOLVED_COLUMN.WITH_SUGGESTION"
    print(e.getMessageParameters())  # {'name': 'salary', 'proposal': '...'}
```

**Why it matters:** Debugging Spark jobs used to mean Googling cryptic Java stack traces. Now every error tells you exactly what went wrong and how to fix it.

---

## 6. V — VARIANT Data Type

### What it is
A **native data type for semi-structured JSON** — no more storing JSON as a plain string and parsing it manually every time.

### Simple Example

```python
# Old way (Spark 3.x) — store JSON as string, parse every query
df = spark.createDataFrame([('{"name": "Alice", "age": 30}',)], ["data"])
from pyspark.sql.functions import get_json_object
df.select(get_json_object("data", "$.name")).show()  # Slow — parses string each time

# New way (Spark 4.0) — VARIANT type stores it natively
spark.sql("""
  CREATE TABLE users (
    id INT,
    profile VARIANT   -- stores JSON natively and efficiently
  )
""")

spark.sql("""
  INSERT INTO users VALUES
  (1, PARSE_JSON('{"name": "Alice", "age": 30, "city": "Bangalore"}'))
""")

# Query directly — fast, no string parsing
spark.sql("SELECT profile:name, profile:age FROM users").show()
# +-----+---+
# |Alice| 30|
```

**Real-world use:** API responses, clickstream data, IoT sensor payloads — all have varying JSON structures. VARIANT handles them without forcing a fixed schema.

---

## 7. P — Python Advances

### 7a. Python Data Source API

Build **custom data sources entirely in Python** — no Scala or Java needed.

```python
from pyspark.sql.datasource import DataSource, DataSourceReader

class MyAPIDataSource(DataSource):
    """Read data from a custom REST API as a Spark DataFrame."""

    @classmethod
    def name(cls):
        return "my_api"

    def reader(self, schema):
        return MyAPIReader(self.options)

class MyAPIReader(DataSourceReader):
    def read(self, partition):
        import requests
        data = requests.get("https://api.example.com/data").json()
        for row in data:
            yield (row["id"], row["value"])

# Register and use
spark.dataSource.register(MyAPIDataSource)
df = spark.read.format("my_api").load()
df.show()
```

---

### 7b. Polymorphic Python UDTFs (User-Defined Table Functions)

Functions that return **multiple rows and a dynamic schema** — the output shape can change based on input.

```python
from pyspark.sql.functions import udtf

@udtf(returnType="word: string, length: int")
class WordSplitter:
    """Takes a sentence and returns one row per word."""
    def eval(self, sentence: str):
        for word in sentence.split():
            yield (word, len(word))

# Use it like a table
spark.udtf.register("split_words", WordSplitter)
spark.sql("""
  SELECT * FROM split_words('Hello World from Spark')
""").show()
# +------+------+
# |  word|length|
# +------+------+
# | Hello|     5|
# | World|     5|
# |  from|     4|
# | Spark|     5|
```

---

### 7c. Native Plotly Plotting on DataFrames

```python
df = spark.createDataFrame([
    ("Jan", 1000), ("Feb", 1500), ("Mar", 1200)
], ["month", "sales"])

# Plot directly on a Spark DataFrame — no .toPandas() needed!
df.plot.bar(x="month", y="sales", title="Monthly Sales")
```

---

## 8. Bonus: SQL Scripting & Pipe Syntax

### SQL Scripting (session variables + control flow)

```sql
-- Session variables
DECLARE total_sales INT DEFAULT 0;

SET total_sales = (SELECT SUM(amount) FROM orders);

IF total_sales > 100000 THEN
    SELECT 'High revenue quarter' AS status;
ELSE
    SELECT 'Normal quarter' AS status;
END IF;
```

### PIPE Syntax (|> operator — cleaner query chaining)

```sql
-- Old way — nested subqueries, hard to read
SELECT dept, avg_sal FROM (
  SELECT dept, AVG(salary) AS avg_sal FROM employees GROUP BY dept
) WHERE avg_sal > 50000;

-- New PIPE syntax — reads top to bottom like a pipeline!
FROM employees
|> AGGREGATE AVG(salary) AS avg_sal GROUP BY dept
|> WHERE avg_sal > 50000
|> SELECT dept, avg_sal;
```

---

## Quick Reference Summary

| Feature | One-liner |
|---------|-----------|
| **Spark Connect** | Tiny 1.5 MB client connects to remote Spark cluster |
| **Collation** | Case/accent-insensitive string comparison for multilingual data |
| **ANSI SQL** | Strict SQL compliance — errors instead of silent NULLs |
| **Structured Logging** | JSON logs, easy to integrate with monitoring tools |
| **Error Classes** | Readable errors with class names and fix suggestions |
| **VARIANT type** | Native JSON storage — no more string parsing |
| **Python Data Source** | Write custom connectors in pure Python |
| **Polymorphic UDTFs** | Python functions that return multiple rows dynamically |
| **Plotly Plotting** | Plot Spark DataFrames directly without converting to pandas |
| **SQL Scripting** | Variables, IF/ELSE, loops in SQL |
| **PIPE syntax** | Chain SQL operations top-to-bottom with `\|>` |

---

## 🧠 Mnemonic Recap

```
S — Spark Connect        (lightweight remote client)
C — Collation            (smart string comparison)
A — ANSI SQL default     (strict, no silent NULLs)
L — Logging (structured) (JSON logs)
E — Error Classes        (readable, actionable errors)
V — VARIANT type         (native semi-structured JSON)
P — Python advances      (UDTFs, Data Source, Plotly)

👉 "Spark will SCALE VP" 🚀
```

---

*Apache Spark 4.0 — Released February 27, 2025*
