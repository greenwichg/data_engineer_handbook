# PySpark Implementation: Regex and String Operations

## Problem Statement

Given a dataset of raw log entries and unstructured text, extract structured information using **regular expressions** and **string functions**. Demonstrate `regexp_extract()`, `regexp_replace()`, and common string transformations. Regex operations are commonly asked in data engineering interviews because real-world data is often messy and unstructured.

### Sample Data

```
log_id  raw_log
L001    2025-01-15 10:30:45 ERROR [UserService] User john.doe@email.com failed login from 192.168.1.100
L002    2025-01-15 10:31:12 INFO [OrderService] Order #ORD-2025-0042 placed by jane_smith@company.org amount $1,250.00
L003    2025-01-15 10:32:00 WARN [PaymentService] Payment FAILED for card ending 4532 IP: 10.0.0.55
L004    2025-01-15 10:33:15 ERROR [AuthService] Suspicious activity detected from 172.16.0.1 user admin@internal.net
L005    2025-01-15 10:34:00 INFO [ShipService] Shipped ORD-2025-0038 to ZIP 94105 tracking TRK-789456123
```

### Expected Output (Extracted Fields)

| log_id | timestamp           | log_level | service        | email                    | ip_address    |
|--------|---------------------|-----------|----------------|--------------------------|---------------|
| L001   | 2025-01-15 10:30:45 | ERROR     | UserService    | john.doe@email.com       | 192.168.1.100 |
| L002   | 2025-01-15 10:31:12 | INFO      | OrderService   | jane_smith@company.org   | null          |
| L003   | 2025-01-15 10:32:00 | WARN      | PaymentService | null                     | 10.0.0.55     |
| L004   | 2025-01-15 10:33:15 | ERROR     | AuthService    | admin@internal.net       | 172.16.0.1    |
| L005   | 2025-01-15 10:34:00 | INFO      | ShipService    | null                     | null          |

---

## Method 1: regexp_extract() — Extract Patterns

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, regexp_extract, regexp_replace, trim, upper, \
    lower, initcap, length, substring, split, concat_ws, when, lit

# Initialize Spark session
spark = SparkSession.builder.appName("RegexOperations").getOrCreate()

# Sample data
data = [
    ("L001", "2025-01-15 10:30:45 ERROR [UserService] User john.doe@email.com failed login from 192.168.1.100"),
    ("L002", "2025-01-15 10:31:12 INFO [OrderService] Order #ORD-2025-0042 placed by jane_smith@company.org amount $1,250.00"),
    ("L003", "2025-01-15 10:32:00 WARN [PaymentService] Payment FAILED for card ending 4532 IP: 10.0.0.55"),
    ("L004", "2025-01-15 10:33:15 ERROR [AuthService] Suspicious activity detected from 172.16.0.1 user admin@internal.net"),
    ("L005", "2025-01-15 10:34:00 INFO [ShipService] Shipped ORD-2025-0038 to ZIP 94105 tracking TRK-789456123")
]
columns = ["log_id", "raw_log"]
df = spark.createDataFrame(data, columns)

# Extract structured fields using regex
df_parsed = df.withColumn(
    "timestamp",
    regexp_extract(col("raw_log"), r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", 1)
).withColumn(
    "log_level",
    regexp_extract(col("raw_log"), r"\d{2}:\d{2}:\d{2} (\w+)", 1)
).withColumn(
    "service",
    regexp_extract(col("raw_log"), r"\[(\w+)\]", 1)
).withColumn(
    "email",
    regexp_extract(col("raw_log"), r"([\w.+-]+@[\w-]+\.[\w.]+)", 1)
).withColumn(
    "ip_address",
    regexp_extract(col("raw_log"), r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", 1)
)

# Replace empty strings with null for clean output
from pyspark.sql.functions import when

df_clean = df_parsed.select(
    "log_id",
    "timestamp",
    "log_level",
    "service",
    when(col("email") == "", None).otherwise(col("email")).alias("email"),
    when(col("ip_address") == "", None).otherwise(col("ip_address")).alias("ip_address")
)

df_clean.show(truncate=False)
```

### Step-by-Step Explanation

#### Understanding regexp_extract(column, pattern, group_index)

| Parameter | Meaning |
|-----------|---------|
| `column` | The column to search |
| `pattern` | The regex pattern (use parentheses for capture groups) |
| `group_index` | Which capture group to return (1 = first group, 0 = entire match) |

#### Regex Patterns Used

| Pattern | What It Matches | Example Match |
|---------|----------------|---------------|
| `(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})` | Timestamp | 2025-01-15 10:30:45 |
| `\d{2}:\d{2}:\d{2} (\w+)` | Log level after time | ERROR |
| `\[(\w+)\]` | Service name in brackets | UserService |
| `([\w.+-]+@[\w-]+\.[\w.]+)` | Email address | john.doe@email.com |
| `(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})` | IP address | 192.168.1.100 |

**Note:** `regexp_extract` returns an empty string (not null) when there's no match.

---

## Method 2: regexp_replace() — Replace Patterns

```python
# Clean and standardize data using regex replace

# Sample messy data
messy_data = [
    ("P001", "  Laptop  Pro  ", "$1,299.99"),
    ("P002", "Phone--XL", "$899.00"),
    ("P003", "tablet_mini", "$499.99"),
    ("P004", "HEADPHONES (wireless)", "$149.50"),
]
messy_df = spark.createDataFrame(messy_data, ["product_id", "product_name", "price_str"])

# Clean product names: remove extra spaces, special chars
cleaned = messy_df.withColumn(
    "clean_name",
    trim(regexp_replace(col("product_name"), r"[\s_-]+", " "))
).withColumn(
    "clean_name",
    regexp_replace(col("clean_name"), r"[()]", "")
).withColumn(
    # Extract numeric price: remove $ and commas
    "price",
    regexp_replace(col("price_str"), r"[$,]", "").cast("double")
)

cleaned.show(truncate=False)
```

- **Output:**

  | product_id | product_name          | price_str | clean_name          | price   |
  |------------|----------------------|-----------|---------------------|---------|
  | P001       |   Laptop  Pro        | $1,299.99 | Laptop Pro          | 1299.99 |
  | P002       | Phone--XL            | $899.00   | Phone XL            | 899.00  |
  | P003       | tablet_mini          | $499.99   | tablet mini         | 499.99  |
  | P004       | HEADPHONES (wireless)| $149.50   | HEADPHONES wireless | 149.50  |

---

## Method 3: Common String Functions

```python
# String transformation functions
string_data = [
    ("john doe", "  hello world  ", "2025-01-15"),
    ("JANE SMITH", "pyspark rocks", "2025/02/20"),
]
str_df = spark.createDataFrame(string_data, ["name", "text", "date_str"])

str_demo = str_df.withColumn("upper_name", upper(col("name"))) \
    .withColumn("lower_name", lower(col("name"))) \
    .withColumn("title_name", initcap(col("name"))) \
    .withColumn("trimmed", trim(col("text"))) \
    .withColumn("name_length", length(col("name"))) \
    .withColumn("first_3", substring(col("name"), 1, 3)) \
    .withColumn("words", split(col("text"), r"\s+"))

str_demo.show(truncate=False)
```

### String Functions Quick Reference

| Function | Purpose | Input → Output |
|----------|---------|----------------|
| `upper(col)` | Uppercase | "hello" → "HELLO" |
| `lower(col)` | Lowercase | "HELLO" → "hello" |
| `initcap(col)` | Title case | "hello world" → "Hello World" |
| `trim(col)` | Remove leading/trailing spaces | "  hi  " → "hi" |
| `ltrim(col)` | Remove leading spaces | "  hi" → "hi" |
| `rtrim(col)` | Remove trailing spaces | "hi  " → "hi" |
| `length(col)` | String length | "hello" → 5 |
| `substring(col, pos, len)` | Substring (1-indexed) | "hello", 1, 3 → "hel" |
| `split(col, pattern)` | Split to array | "a,b,c", "," → ["a","b","c"] |
| `concat_ws(sep, cols...)` | Join with separator | "-", "a", "b" → "a-b" |
| `lpad(col, len, pad)` | Left pad | "42", 5, "0" → "00042" |
| `rpad(col, len, pad)` | Right pad | "hi", 5, "." → "hi..." |
| `translate(col, from, to)` | Character-level replace | "abc", "ab", "XY" → "XYc" |
| `instr(col, substr)` | Find substring position | "hello", "ll" → 3 |
| `locate(substr, col)` | Find substring (reversed args) | "ll", "hello" → 3 |
| `reverse(col)` | Reverse string | "hello" → "olleh" |
| `repeat(col, n)` | Repeat string | "ab", 3 → "ababab" |

---

## Method 4: Extracting Multiple Groups

```python
# Extract order ID, amount, and tracking from logs
df_orders = df.withColumn(
    "order_id",
    regexp_extract(col("raw_log"), r"(ORD-\d{4}-\d{4})", 1)
).withColumn(
    "amount",
    regexp_extract(col("raw_log"), r"\$([0-9,]+\.\d{2})", 1)
).withColumn(
    "zip_code",
    regexp_extract(col("raw_log"), r"ZIP (\d{5})", 1)
).withColumn(
    "tracking",
    regexp_extract(col("raw_log"), r"(TRK-\d+)", 1)
)

df_orders.select("log_id", "order_id", "amount", "zip_code", "tracking") \
    .filter(col("order_id") != "").show(truncate=False)
```

- **Output:**

  | log_id | order_id       | amount   | zip_code | tracking       |
  |--------|---------------|----------|----------|----------------|
  | L002   | ORD-2025-0042 | 1,250.00 |          |                |
  | L005   | ORD-2025-0038 |          | 94105    | TRK-789456123  |

---

## Method 5: Regex with rlike() for Filtering

```python
# Filter rows matching a pattern
# Find all ERROR logs
errors = df.filter(col("raw_log").rlike(r"\bERROR\b"))
errors.show(truncate=False)

# Find logs with email addresses
has_email = df.filter(col("raw_log").rlike(r"[\w.+-]+@[\w-]+\.[\w.]+"))
has_email.show(truncate=False)

# Find logs from internal IPs (10.x.x.x or 172.16.x.x or 192.168.x.x)
internal_ips = df.filter(
    col("raw_log").rlike(r"\b(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.16\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b")
)
internal_ips.show(truncate=False)
```

---

## Method 6: Using SQL with Regex

```python
df.createOrReplaceTempView("logs")

sql_regex = spark.sql("""
    SELECT
        log_id,
        regexp_extract(raw_log, '(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})', 1) AS timestamp,
        regexp_extract(raw_log, '\\d{2}:\\d{2}:\\d{2} (\\w+)', 1) AS log_level,
        regexp_extract(raw_log, '\\[(.+?)\\]', 1) AS service
    FROM logs
""")

sql_regex.show(truncate=False)
```

**Note:** In SQL strings, backslashes need double escaping: `\\d` instead of `\d`.

---

## Common Regex Patterns for Interviews

| Pattern | What It Matches | Regex |
|---------|----------------|-------|
| Email | user@domain.com | `[\w.+-]+@[\w-]+\.[\w.]+` |
| IP Address | 192.168.1.1 | `\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}` |
| Phone (US) | (555) 123-4567 | `\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}` |
| Date (YYYY-MM-DD) | 2025-01-15 | `\d{4}-\d{2}-\d{2}` |
| URL | https://example.com | `https?://[\w./\-?=&#]+` |
| Currency | $1,250.00 | `\$[\d,]+\.\d{2}` |
| UUID | 550e8400-e29b... | `[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}` |

## Key Interview Talking Points

1. **regexp_extract returns empty string, not null:** When there's no match, `regexp_extract` returns `""`. Always check with `when(col == "", None)` if you need null semantics.

2. **Escape characters:** In PySpark Python strings, use `r"..."` (raw strings) to avoid double-escaping. In SQL, you must double-escape: `\\d` for `\d`.

3. **Performance:** Regex operations are CPU-intensive. For simple patterns (like splitting on comma), prefer `split()` over `regexp_replace()`. For column-level operations, built-in functions are always faster than regex.

4. **rlike vs regexp_extract:** `rlike()` returns boolean (for filtering). `regexp_extract()` returns the matched string (for extraction).

5. **Real-world use cases:**
   - Log parsing (as demonstrated)
   - Data cleaning (phone numbers, addresses)
   - PII detection and masking
   - URL parsing and parameter extraction
