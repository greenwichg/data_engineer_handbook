# AWS Glue Job - Comprehensive Deep Dive

Let me explain each module in extensive detail, including the reasoning behind each decision and how the code works line by line.

---

## 1. **LogBuffer Class** - Structured Logging System

```python
class LogBuffer:
    def __init__(self, run_id: str):
        self.lines = []
        self.run_id = run_id
```

### Purpose
This class creates a centralized logging system that:
1. Outputs logs to CloudWatch (via `print`)
2. Stores logs in memory for later export to S3
3. Uses structured JSON format for easy parsing and analysis

### Why Structured Logging?

Traditional logging:
```
2025-01-19 10:30:00 INFO Records read: 500
```

Structured JSON logging:
```json
{"level": "INFO", "ts": "2025-01-19T10:30:00Z", "run_id": "abc123", "msg": "Records read", "count": 500}
```

**Benefits of JSON logs:**
- Easily searchable in CloudWatch Logs Insights
- Can be parsed by log aggregation tools (Splunk, ELK, etc.)
- Supports arbitrary key-value pairs for context
- Machine-readable for automated alerting

### Detailed Method Breakdown

#### Timestamp Generator
```python
@staticmethod
def _ts() -> str:
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
```

- `@staticmethod` - Doesn't need `self`, can be called without instance
- `timezone.utc` - Always uses UTC to avoid timezone confusion
- Format: ISO 8601 (`2025-01-19T10:30:00Z`) - universal standard

#### Info Method
```python
def info(self, msg: str, **kv):
    payload = {"level": "INFO", "ts": self._ts(), "run_id": self.run_id, "msg": msg}
    if kv:
        payload.update(kv)  # Merge any additional key-value pairs
    self.lines.append(json.dumps(payload, ensure_ascii=False))
    print(json.dumps(payload))  # Also emit to CloudWatch
```

**How `**kv` works:**
```python
log.info("Processing complete", records=500, duration_ms=1234)
# Creates: {"level": "INFO", ..., "msg": "Processing complete", "records": 500, "duration_ms": 1234}
```

- `ensure_ascii=False` - Allows non-ASCII characters (international text)
- Stores in `self.lines` list AND prints to stdout (CloudWatch captures stdout)

#### Warning and Error Methods
```python
def warning(self, msg: str, **kv):
    # Same structure, just with "WARNING" level
    
def error(self, msg: str, **kv):
    # Same structure, just with "ERROR" level
```

These follow the same pattern but with different severity levels for filtering.

#### Export to S3
```python
def export_to_s3(self, bucket: str, key_prefix: str, base_filename: str) -> str:
    key = f"{key_prefix.rstrip('/')}/{base_filename}"  # Build full S3 key
    s3 = boto3.client('s3')
    body = "\n".join(self.lines).encode('utf-8')  # Join all logs with newlines
    s3.put_object(Bucket=bucket, Key=key, Body=body)
    print(f"Logs exported to s3://{bucket}/{key}")
    return f"s3://{bucket}/{key}"
```

**Step by step:**
1. `key_prefix.rstrip('/')` - Removes trailing slash to avoid `//` in path
2. `"\n".join(self.lines)` - Combines all log lines into single string
3. `.encode('utf-8')` - Converts string to bytes (required by S3)
4. `put_object` - Uploads to S3

**Example output path:**
```
s3://my-bucket/logs/2025/01/19/customers_log_20250119103000.txt
```

---

## 2. **Retry Decorator** - Automatic Retry Logic

```python
def retry_on_exception(max_attempts=3, delay_seconds=300, exceptions=(Exception,)):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            # ... retry logic
        return wrapper
    return decorator
```

### Understanding Decorators

A decorator is a function that wraps another function to add behavior. Here's how it works:

```python
@retry_on_exception(max_attempts=3, delay_seconds=180)
def alter_redshift_table(...):
    # function code
```

This is equivalent to:
```python
def alter_redshift_table(...):
    # function code
    
alter_redshift_table = retry_on_exception(max_attempts=3, delay_seconds=180)(alter_redshift_table)
```

### Detailed Code Walkthrough

```python
def retry_on_exception(max_attempts=3, delay_seconds=300, exceptions=(Exception,)):
```

**Parameters:**
- `max_attempts=3` - Try up to 3 times before giving up
- `delay_seconds=300` - Wait 5 minutes between retries (allows transient issues to resolve)
- `exceptions=(Exception,)` - Which exceptions to catch (default: all)

```python
def decorator(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
```

- `@functools.wraps(func)` - Preserves the original function's name and docstring
- `*args, **kwargs` - Accepts any arguments to pass through to the wrapped function

#### Logger Discovery Logic
```python
_log = kwargs.get('log') or kwargs.get('logger')
if _log is None:
    for obj in reversed(args):  # look through positional args
        if hasattr(obj, 'warning') and hasattr(obj, 'error'):
            _log = obj
            break
```

**Why this complexity?**
- The decorator needs to log retry attempts
- Different functions might pass the logger differently (as `log=`, `logger=`, or positionally)
- `reversed(args)` - Logger is often the last argument
- `hasattr(obj, 'warning')` - Duck typing to identify logger objects

#### Retry Loop
```python
while attempt < max_attempts:
    try:
        return func(*args, **kwargs)  # Try to execute the function
    except exceptions as e:
        attempt += 1
        if attempt >= max_attempts:
            # Log final failure and re-raise
            if _log:
                _log.error(f"{func.__name__} failed after {attempt} attempts: {e}")
            raise
        # Log retry and wait
        if _log:
            _log.warning(
                f"{func.__name__} failed with {type(e).__name__}: {e}. "
                f"Retrying in {delay_seconds} seconds (attempt {attempt}/{max_attempts})..."
            )
        time.sleep(delay_seconds)  # Wait before retry
```

**Flow:**
1. Try to execute the function
2. If it succeeds, return immediately
3. If it fails with a matching exception:
   - Increment attempt counter
   - If max attempts reached, log error and re-raise
   - Otherwise, log warning and sleep before retry

### Why These Specific Retry Settings?

| Function | Delay | Reason |
|----------|-------|--------|
| `alter_redshift_table` | 180s (3 min) | DDL operations may need time for locks to release |
| `alter_varchar_columns` | 300s (5 min) | Column alterations can be slow on large tables |
| `run_merge` | 300s (5 min) | Merge involves delete+insert, may hit concurrency issues |

---

## 3. **Glue Initialization**

```python
def initialize_glue(job_name: str):
    sc = SparkContext.getOrCreate()
    glue_context = GlueContext(sc)
    spark = glue_context.spark_session
    job = Job(glue_context)
    job.init(job_name, {"job_name": job_name})
    return spark, glue_context, job
```

### Component Breakdown

#### SparkContext
```python
sc = SparkContext.getOrCreate()
```
- The entry point for all Spark functionality
- `getOrCreate()` - Reuses existing context or creates new one (prevents errors if context exists)
- Manages cluster resources and job scheduling

#### GlueContext
```python
glue_context = GlueContext(sc)
```
- AWS Glue's wrapper around SparkContext
- Provides additional Glue-specific features:
  - DynamicFrames (schema flexibility)
  - Connection to Glue Data Catalog
  - Bookmarking (track processed data)

#### SparkSession
```python
spark = glue_context.spark_session
```
- The main interface for DataFrame operations
- Used for: reading files, SQL queries, data transformations
- This is what you use 90% of the time

#### Job Object
```python
job = Job(glue_context)
job.init(job_name, {"job_name": job_name})
```
- Tracks job execution
- `job.commit()` - Marks job as complete (enables bookmarking)
- The dictionary `{"job_name": job_name}` is job metadata

---

## 4. **DataFrame Helpers**

### 4a. Column Name Cleaner

```python
def _clean_colname(name: str) -> str:
    name = name.lower()                    # "First Name" → "first name"
    name = re.sub(r"[^a-z0-9]", "_", name) # "first name" → "first_name"
    name = re.sub(r"_+", "_", name)        # "first__name" → "first_name"
    return name.strip("_")                  # "_first_name_" → "first_name"
```

#### Why Clean Column Names?

**Problem:** Source CSV files often have messy column names:
- `"First Name"` (spaces)
- `"Email Address!"` (special characters)
- `"Customer ID#"` (symbols)
- `"TOTAL_AMOUNT"` (uppercase)

**Redshift requirements:**
- Identifiers should be lowercase (case-insensitive by default)
- No special characters except underscore
- No spaces

#### Regex Breakdown

```python
re.sub(r"[^a-z0-9]", "_", name)
```
- `[^a-z0-9]` - Match any character that is NOT lowercase letter or digit
- Replace with underscore
- Example: `"email@address.com"` → `"email_address_com"`

```python
re.sub(r"_+", "_", name)
```
- `_+` - Match one or more consecutive underscores
- Replace with single underscore
- Example: `"first___name"` → `"first_name"`

---

### 4b. CSV File Reader (Detailed)

```python
def read_csv_file(config: dict, spark):
    try:
        source_file = f"s3://{config['src_bucket']}/data/in/{config['source_file_name']}"
```

#### Initial Read
```python
df = (spark.read
      .option("header", "true")      # First row contains column names
      .option("inferSchema", "true") # Automatically detect data types
      .csv(source_file))
```

**Options explained:**
- `header=true` - Don't treat first row as data
- `inferSchema=true` - Spark samples data to determine types (Integer, String, etc.)

#### Column Normalization
```python
for old in df.columns:
    new = _clean_colname(old)
    if old != new:
        df = df.withColumnRenamed(old, new)
```

Renames each column using the cleaner function.

#### Schema Casting (Complex Part)
```python
df1 = (spark.read.option("header", "true").option("inferSchema", "true").csv(source_file))
```

**Why read twice?** This creates a reference DataFrame (`df1`) to use as a schema template.

```python
def cast_like(df, df1, config: dict):
    out_cols = []
    ref_fields = {f.name: f.dataType for f in df1.schema.fields}
    upsert_keys = [i.lower() for i in config['upsert_keys']]
    
    for name, dtype in ref_fields.items():
        if isinstance(dtype, T.DoubleType):
            if name in df.columns and name in upsert_keys:
                out_cols.append(F.col(name))  # Keep as-is for upsert keys
            else:
                # Convert Double to Decimal for precision
                out_cols.append(F.col(name).cast(T.DecimalType(38, 18)).alias(name))
        else:
            if name in df.columns:
                out_cols.append(F.col(name).cast(dtype).alias(name))
            else:
                out_cols.append(F.lit(None).cast(dtype).alias(name))
    
    return df.select(*out_cols)
```

**Why convert Double to Decimal?**
- `DoubleType` uses floating-point (imprecise): `0.1 + 0.2 = 0.30000000000000004`
- `DecimalType(38,18)` uses fixed precision (exact): `0.1 + 0.2 = 0.3`
- Critical for financial data!

**Why exclude upsert keys from conversion?**
- Upsert keys are used for matching records
- Type changes could cause matching failures

#### Add Metadata Columns
```python
run_ts = datetime.now(timezone.utc)
file_name = source_file.split("/")[-1]

df = (
    df.withColumn("run_date", lit(run_ts.strftime("%Y-%m-%d %H:%M:%S")).cast(TimestampType()))
      .withColumn("file_name", lit(file_name))
)
```

**Added columns:**
- `run_date` - When this ETL job ran (for auditing)
- `file_name` - Source file name (for traceability)

**`lit()` function:** Creates a literal/constant column (same value for all rows)

---

## 5. **Redshift Data API Utilities**

### Why Use Data API Instead of JDBC?

| JDBC Connection | Data API |
|-----------------|----------|
| Requires VPC/network setup | Works over HTTPS |
| Connection pooling needed | Stateless/serverless |
| Credentials in connection string | Uses IAM/Secrets Manager |
| Synchronous only | Async with polling |

### 5a. Poll Statement (Detailed)

```python
def _poll_statement(client, stmt_id: str, ctx: str, sleep_s: float = 0.5):
    while True:
        desc = client.describe_statement(Id=stmt_id)
        status = desc.get("Status")
        if status in ("FINISHED", "FAILED", "ABORTED"):
            break
        time.sleep(sleep_s)
    
    if status != "FINISHED":
        err = desc.get("Error")
        raise RuntimeError(f"{ctx} failed. Status={status}, Error={err}")
    return desc
```

**Data API Workflow:**
1. `execute_statement()` - Starts query execution, returns immediately with statement ID
2. Query runs asynchronously in Redshift
3. `describe_statement()` - Check if query is done
4. Poll until terminal status reached

**Status values:**
- `SUBMITTED` - Query accepted
- `PICKED` - Query being processed
- `STARTED` - Execution begun
- `FINISHED` - Success ✓
- `FAILED` - Error ✗
- `ABORTED` - Cancelled ✗

**Why 0.5 second sleep?**
- Balance between responsiveness and API rate limits
- Too fast = hit rate limits
- Too slow = unnecessary latency

### 5b. Execute SQL (Detailed)

```python
def execute_sql(sql: str, redshift_conn: dict, client):
    resp = client.execute_statement(
        WorkgroupName=redshift_conn['workgroup_name'],  # Serverless workgroup
        Database=redshift_conn['database'],             # Database name
        Sql=sql,                                        # SQL to execute
        SecretArn=redshift_conn['secret_arn']          # Credentials from Secrets Manager
    )
    return _poll_statement(client, resp["Id"], ctx="SQL")
```

**Parameters:**
- `WorkgroupName` - Redshift Serverless workgroup (or use `ClusterIdentifier` for provisioned)
- `SecretArn` - AWS Secrets Manager secret containing username/password

---

## 6. **Schema Discovery & Harmonization**

This module handles **schema evolution** - when source file structure changes over time.

### 6a. Read Redshift Table Schema

```python
def read_redshift_table_schema(config: dict, redshift_conn: dict, spark, client):
    schema_name = redshift_conn['schema_name']
    table_name = config['target_table']
    
    # Query that returns no rows but has correct schema
    sql = f"SELECT * FROM {schema_name}.{table_name} WHERE 1=0;"
```

**Why `WHERE 1=0`?**
- Returns zero rows (fast!)
- Still returns column metadata
- Avoids transferring actual data

#### Get Column Metadata
```python
resp = client.execute_statement(...)
desc = _poll_statement(client, resp["Id"], ctx="Read target schema")
result = client.get_statement_result(Id=resp["Id"])
metadata = result["ColumnMetadata"]
```

**`ColumnMetadata` structure:**
```python
[
    {"name": "customer_id", "typeName": "integer", "nullable": 0, ...},
    {"name": "customer_name", "typeName": "varchar", "nullable": 1, ...},
    ...
]
```

#### Type Mapping Function
```python
def map_dtype(dtype: str):
    d = dtype.lower()
    if d in ("varchar", "char", "character varying"):
        return StringType()
    if d in ("int", "integer", "int4"):
        return IntegerType()
    if d in ("bigint", "int8"):
        return LongType()
    if d in ("float", "float8", "double precision"):
        return DoubleType()
    if d in ("decimal", "numeric"):
        return DecimalType(38, 18)
    if d in ("boolean", "bool"):
        return BooleanType()
    if d in ("timestamp", "timestamp without time zone"):
        return TimestampType()
    if d == "date":
        return DateType()
    return StringType()  # Default fallback
```

**Type mapping table:**

| Redshift Type | Spark Type |
|--------------|------------|
| varchar, char | StringType |
| int, integer, int4 | IntegerType |
| bigint, int8 | LongType |
| smallint, int2 | IntegerType |
| float, double precision | DoubleType |
| decimal, numeric | DecimalType(38,18) |
| boolean, bool | BooleanType |
| timestamp | TimestampType |
| date | DateType |

#### Build Spark Schema
```python
schema = StructType([
    StructField(col_meta["name"], map_dtype(col_meta["typeName"]), True)
    for col_meta in metadata
])
return spark.createDataFrame([], schema)  # Empty DataFrame with schema
```

- `StructField(name, dataType, nullable)` - Defines one column
- `StructType([...])` - Collection of fields = complete schema
- Empty DataFrame serves as schema reference

---

### 6b. Check Table Exists

```python
def check_table_exists(redshift_conn: dict, config: dict, client) -> bool:
    sql = dedent(f"""
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = '{redshift_conn['schema_name']}'
          AND table_name   = '{config['target_table']}'
        LIMIT 1;
    """)
```

**`information_schema.tables`** - Standard SQL metadata table listing all tables.

```python
result = client.get_statement_result(Id=resp["Id"])
return bool(result.get("Records"))  # True if any rows returned
```

- If table exists → Returns one row → `bool([...])` = `True`
- If table doesn't exist → Returns no rows → `bool([])` = `False`

---

### 6c. Spark to Redshift Type Mapper

```python
def _spark_to_redshift_type(data_type) -> str:
    if isinstance(data_type, StringType):
        return "VARCHAR(256)"
    if isinstance(data_type, IntegerType):
        return "INTEGER"
    if isinstance(data_type, LongType):
        return "BIGINT"
    if isinstance(data_type, FloatType):
        return "REAL"
    if isinstance(data_type, DoubleType):
        return "DOUBLE PRECISION"
    if isinstance(data_type, BooleanType):
        return "BOOLEAN"
    if isinstance(data_type, DateType):
        return "DATE"
    if isinstance(data_type, TimestampType):
        return "TIMESTAMP"
    if isinstance(data_type, DecimalType):
        return "DECIMAL(38,18)"
    if isinstance(data_type, BinaryType):
        return "VARBYTE"
    return "VARCHAR(256)"  # Safe default
```

**Design decisions:**
- `VARCHAR(256)` - Reasonable default for strings (expandable later)
- `DECIMAL(38,18)` - Maximum precision for exact numeric storage
- Default to VARCHAR - Safe fallback for unknown types

---

### 6d. Create New Redshift Table

```python
def create_new_redshift_table(config: dict, redshift_conn: dict, df, client, log):
    log.info("Target table does not exist; creating")
    
    upsert_keys = set(config.get('upsert_keys', []))
    
    cols_ddls = []
    for field in df.schema.fields:
        col_type = _spark_to_redshift_type(field.dataType)
        # Upsert keys must not be NULL (for reliable matching)
        not_null_clause = " NOT NULL" if field.name in upsert_keys else ""
        cols_ddls.append(f"{field.name} {col_type}{not_null_clause}")
```

**Why NOT NULL on upsert keys?**
- Upsert uses these columns to match records
- NULL values don't match properly (`NULL != NULL` in SQL)
- Ensures data integrity

#### Build DDL
```python
ddl = dedent(f"""
    CREATE TABLE IF NOT EXISTS {redshift_conn['schema_name']}.{config['target_table']} (
        {', '.join(cols_ddls)}
    );
""")
```

**Example generated DDL:**
```sql
CREATE TABLE IF NOT EXISTS public.customers (
    customer_id INTEGER NOT NULL,
    customer_name VARCHAR(256),
    email VARCHAR(256),
    total_amount DECIMAL(38,18),
    run_date TIMESTAMP,
    file_name VARCHAR(256)
);
```

#### Create Associated Views
```python
if status == "FINISHED":
    log.info(f"'{config['target_table']}' table successfully created")
    create_views(config, redshift_conn, client, log)
```

After table creation, creates any configured views.

---

### 6e. Alter Redshift Table (Add Columns)

```python
@retry_on_exception(max_attempts=3, delay_seconds=180, exceptions=(Exception,))
def alter_redshift_table(config: dict, redshift_conn: dict, df, redshift_df, client, log, spark):
```

**This handles the scenario:** Source file has NEW columns that don't exist in Redshift.

#### Compare Columns
```python
df = read_redshift_table_schema(config, redshift_conn, spark, client)
if set(df.columns) != set(redshift_df.columns):
```

Using `set()` ignores column order, only checks if same columns exist.

#### Drop Views First
```python
drop_views(config, redshift_conn, client, log)
```

**Why?** Redshift doesn't allow `ALTER TABLE` on tables with dependent views.

#### Add Missing Columns
```python
target_cols = [c.name for c in redshift_df.schema.fields]
missed_cols = []

for colf in df.schema.fields:
    if colf.name not in target_cols:
        missed_cols.append(colf.name)
        rtype = _spark_to_redshift_type(colf.dataType)
        sql = f"ALTER TABLE {redshift_conn['schema_name']}.{config['target_table']} ADD COLUMN {colf.name} {rtype};"
        execute_sql(sql, redshift_conn, client)
```

**For each new column:**
1. Determine Redshift type
2. Execute `ALTER TABLE ... ADD COLUMN`

#### Recreate Views
```python
if missed_cols:
    log.info(f"columns: {missed_cols}' are added successfully")
    desc = create_views(config, redshift_conn, client, log)
```

After adding columns, recreate the views with new schema.

---

### 6f. Get Metadata (Column Info)

```python
def get_metadata(config: dict, redshift_conn: dict, client) -> dict:
    sql = dedent(f"""
        SELECT column_name, data_type, character_maximum_length
        FROM SVV_COLUMNS
        WHERE table_schema = '{redshift_conn['schema_name']}'
        AND table_name = '{config['target_table']}';
    """)
```

**`SVV_COLUMNS`** - Redshift system view with detailed column metadata.

#### Parse Results
```python
rows = client.get_statement_result(Id=desc["Id"]).get("Records", [])
meta = {}
for r in rows:
    colname = r[0]['stringValue']
    dtype = r[1]['stringValue'].lower()
    length = r[2].get('longValue') if r[2] else None
    meta[colname] = {"dtype": dtype, "length": length}
return meta
```

**Result structure:**
```python
{
    "customer_name": {"dtype": "varchar", "length": 256},
    "customer_id": {"dtype": "integer", "length": None},
    "email": {"dtype": "varchar", "length": 256}
}
```

---

### 6g. Alter VARCHAR Columns (Dynamic Resizing)

This is one of the most sophisticated functions - it automatically expands column sizes when data doesn't fit.

```python
@retry_on_exception(max_attempts=3, delay_seconds=300, exceptions=(Exception,))
def alter_varchar_columns(config: dict, redshift_conn: dict, df, client, log):
    metadata = get_metadata(config, redshift_conn, client)
```

#### Integer Type Ranges
```python
INT_RANGES = {
    "smallint": 32767,          # 2 bytes: -32,768 to 32,767
    "int2": 32767,
    "integer": 2147483647,       # 4 bytes: -2.1 billion to 2.1 billion
    "int": 2147483647,
    "int4": 2147483647,
    "bigint": 9223372036854775807,  # 8 bytes: -9.2 quintillion to 9.2 quintillion
    "int8": 9223372036854775807,
}
```

#### Identify Column Types
```python
string_cols = []
int_cols = []

for f in df.schema.fields:
    if isinstance(f.dataType, StringType):
        string_cols.append(f.name)
    elif isinstance(f.dataType, (IntegerType, LongType, ShortType)):
        int_cols.append(f.name)
```

#### Calculate Max Values (Single Pass!)
```python
agg_expr = []

for c in string_cols:
    agg_expr.append(F.max(F.length(F.col(c))).alias(c))  # Max string length

for c in int_cols:
    agg_expr.append(F.max(F.abs(F.col(c))).alias(c))  # Max absolute value

row = df.agg(*agg_expr).collect()[0]  # Single aggregation query
```

**Why single aggregation?**
- Scans data only once (efficient!)
- Gets max length/value for ALL columns simultaneously

#### Handle String Column Expansion
```python
for colname in string_cols:
    src_len = int(row[colname] or 0)           # Max length in source data
    curr_len = int(metadata.get(colname, {}).get("length") or 0)  # Current Redshift size
    
    if src_len > curr_len:  # Source data is longer than current column!
        drop_views(config, redshift_conn, client, log)  # Must drop views first
        
        new_len = min(src_len + 10, 65535)  # Add 10 char buffer, cap at max
        
        sql = f"""
            ALTER TABLE {redshift_conn['schema_name']}.{config['target_table']}
            ALTER COLUMN {colname} TYPE VARCHAR({new_len});
        """
        desc = execute_sql(sql, redshift_conn, client)
        str_altered_cols.append({...})
```

**Why add 10 character buffer?**
- Avoids repeated alterations for small increases
- Future-proofs against slightly longer data

**Why cap at 65535?**
- Redshift's maximum VARCHAR size

#### Handle Integer Type Widening

Redshift doesn't allow direct integer type changes, so we use a workaround:

```python
for colname in int_cols:
    max_val = int(row[colname] or 0)
    curr_dtype = metadata.get(colname, {}).get("dtype")
    
    if not curr_dtype or curr_dtype not in INT_RANGES:
        continue
    
    curr_max = INT_RANGES[curr_dtype]
    
    if max_val > curr_max:  # Value exceeds current type's range!
        # Determine new type
        if curr_dtype in ("smallint", "int2"):
            new_type = "INTEGER"
        elif curr_dtype in ("integer", "int", "int4"):
            new_type = "BIGINT"
        else:
            continue  # Already BIGINT, can't upgrade further
```

**Upgrade path:** `SMALLINT` → `INTEGER` → `BIGINT`

#### The Column Swap Workaround
```python
# 1. Add temporary column with new type
add_sql = f"ALTER TABLE ... ADD COLUMN sample_col {new_type};"

# 2. Copy data to new column (with type conversion)
set_sql = f"UPDATE ... SET sample_col = {colname}::{new_type};"

# 3. Drop old column
drop_sql = f"ALTER TABLE ... DROP COLUMN {colname};"

# 4. Rename new column to original name
rename_sql = f"ALTER TABLE ... RENAME COLUMN sample_col TO {colname};"
```

**Why this complexity?**
- Redshift doesn't support `ALTER COLUMN TYPE` for integers
- This workaround achieves the same result
- Data is preserved through the transformation

---

### 6h. Fill Missing Columns

```python
def fill_missing_columns(df, redshift_df):
    src_cols = set(df.columns)
    missed_cols = []
    
    for colf in redshift_df.schema.fields:
        if colf.name not in src_cols:  # Column exists in Redshift but not in source
            missed_cols.append(colf.name)
            default_value = get_default_value(colf.dataType)
            df = df.withColumn(colf.name, lit(default_value))
```

**Scenario:** Source file is MISSING columns that exist in Redshift (maybe an old file format).

#### Default Values by Type
```python
def get_default_value(dtype):
    if isinstance(dtype, StringType):
        return ""           # Empty string
    if isinstance(dtype, (IntegerType, FloatType, DoubleType, LongType)):
        return 0            # Zero
    if isinstance(dtype, DecimalType):
        return 0.0          # Zero (decimal)
    if isinstance(dtype, BooleanType):
        return False        # False
    if isinstance(dtype, (DateType, TimestampType)):
        return None         # NULL for dates
    if isinstance(dtype, BinaryType):
        return b""          # Empty bytes
    return None             # NULL as fallback
```

---

## 7. **Staging Table & COPY**

### Why Use Staging Tables?

**Direct approach (bad):**
```sql
INSERT INTO customers VALUES (...), (...), ...;  -- Slow! One transaction per batch
```

**Staging approach (good):**
```
1. COPY bulk data into staging table (very fast)
2. MERGE staging → target (single transaction)
3. Drop staging table
```

### 7a. Create Staging Table

```python
def create_staging_table(config: dict, redshift_conn: dict, staging_table_name: str, client, log):
    staging = staging_table_name
    log.info(f"Creating staging table: {staging}")
    schema = redshift_conn['schema_name']
    
    ddl = dedent(f"""
        DROP TABLE IF EXISTS {schema}.{staging};
        CREATE TABLE {schema}.{staging} AS
        SELECT * FROM {schema}.{config['target_table']} WHERE 1=0;
    """)
    execute_sql(ddl, redshift_conn, client)
```

**`CREATE TABLE ... AS SELECT ... WHERE 1=0`:**
- Creates table with identical structure to target
- Copies NO data (fast!)
- Inherits column types, but not constraints or keys

---

### 7b. Find Single CSV in Prefix

```python
def _find_single_csv_in_prefix(s3_uri: str) -> str:
    s3 = boto3.client('s3')
    bucket, prefix = s3_uri.replace("s3://", "").split("/", 1)
    resp = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    contents = resp.get("Contents", [])
```

**Problem:** When Spark writes with `coalesce(1)`, it creates:
```
s3://bucket/staging/run123/
├── _SUCCESS           ← Empty marker file
├── part-00000-abc.csv ← Actual data
└── .part-00000.crc    ← Checksum file
```

**Solution:** Find the actual CSV file:
```python
# Look for .csv files first
candidates = [o["Key"] for o in contents if o["Key"].endswith(".csv")]

if not candidates:
    # Fallback: any part-* file
    candidates = [o["Key"] for o in contents if "/part-" in o["Key"]]

if not candidates:
    raise RuntimeError(f"No CSV objects found under {s3_uri}")

return f"s3://{bucket}/{sorted(candidates)[0]}"
```

---

### 7c. Copy to Redshift

```python
def copy_to_redshift(s3_staging_path: str, redshift_conn: dict, staging_table_name: str, client, log):
    staging = staging_table_name
    log.info(f"Data is being copied from s3 to staging table({staging})")
    schema = redshift_conn['schema_name']
    
    s3_single_file = _find_single_csv_in_prefix(s3_staging_path)
    
    ddl = dedent(f"""
        COPY {schema}.{staging}
        FROM '{s3_staging_path}'
        IAM_ROLE '{redshift_conn['iam_role']}'
        FORMAT AS CSV
        TIMEFORMAT 'auto'
        DELIMITER ','
        QUOTE '"'
        IGNOREHEADER 1;
    """)
    execute_sql(ddl, redshift_conn, client)
```

**COPY options explained:**

| Option | Purpose |
|--------|---------|
| `IAM_ROLE` | Redshift uses this IAM role to access S3 |
| `FORMAT AS CSV` | Parse as CSV format |
| `TIMEFORMAT 'auto'` | Automatically detect timestamp formats |
| `DELIMITER ','` | Fields separated by commas |
| `QUOTE '"'` | Fields can be quoted with double quotes |
| `IGNOREHEADER 1` | Skip first row (header) |

**Why COPY is fast:**
- Massively parallel - Redshift reads from S3 in parallel
- Direct path loading - Bypasses SQL parser for bulk data
- Columnar storage optimization

---

## 8. **Merge Operation (Upsert)**

```python
@retry_on_exception(max_attempts=3, delay_seconds=300, exceptions=(Exception,))
def run_merge(config: dict, redshift_conn: dict, staging_table_name: str, client, log):
    
    keys = config['upsert_keys']  # e.g., ['customer_id', 'order_id']
    schema = redshift_conn['schema_name']
```

### Understanding Upsert

**UPSERT = UPDATE + INSERT**
- If record exists (matching keys) → Update it
- If record doesn't exist → Insert it

### Build Join Condition
```python
tgt = f"{schema}.{config['target_table']}"
stg = f"{schema}.{staging_table_name}"

# Build: "target.customer_id = staging.customer_id AND target.order_id = staging.order_id"
join_clause = " AND ".join([f"{tgt}.{k} = {stg}.{k}" for k in keys])
```

### The DELETE + INSERT Pattern
```python
ddl = dedent(f"""
    BEGIN;
    DELETE FROM {tgt}
    USING {stg}
    WHERE {join_clause};
    INSERT INTO {tgt}
    SELECT * FROM {stg};
    DROP TABLE {stg};
    COMMIT;
""")
```

**Step by step:**

1. **BEGIN** - Start transaction (all-or-nothing)

2. **DELETE** - Remove existing records that match staging keys
   ```sql
   DELETE FROM public.customers
   USING public.customers_staging
   WHERE public.customers.customer_id = public.customers_staging.customer_id;
   ```

3. **INSERT** - Insert ALL records from staging (new + updated)
   ```sql
   INSERT INTO public.customers
   SELECT * FROM public.customers_staging;
   ```

4. **DROP TABLE** - Clean up staging table

5. **COMMIT** - Make changes permanent

**Why not use MERGE statement?**
- Redshift doesn't have native MERGE (unlike other databases)
- This DELETE + INSERT pattern achieves the same result
- Wrapped in transaction ensures atomicity

---

## 9. **View Management**

### 9a. Create Views

```python
def create_views(config: dict, redshift_conn: dict, client, log):
    bucket = config['src_bucket']
    key = "config/view_config.json"
    
    # Download config from S3
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=bucket, Key=key)
    json_file = response['Body'].read().decode('utf-8')
    data = json.loads(json_file)
```

#### View Config Structure
```json
[
  {
    "source_table": "customers",
    "view_name": "v_customers",
    "schema_name": "public",
    "definition": "CREATE OR REPLACE VIEW {schema_name}.{view_name} AS SELECT * FROM {schema_name}.{source_table} WHERE active = true"
  },
  {
    "source_table": "orders",
    "view_name": "v_orders",
    "schema_name": "public", 
    "definition": "CREATE OR REPLACE VIEW {schema_name}.{view_name} AS SELECT * FROM {schema_name}.{source_table}"
  }
]
```

#### Find Matching Config
```python
v_config = None
for d in data:
    if d['source_table'] == config['target_table']:
        v_config = {
            'source_table': d['source_table'],
            'view_name': d['view_name'],
            'schema_name': d['schema_name'],
            'definition': d['definition']
        }

if not v_config:
    log.error("No configuration found for the target table")
    return None  # No view needed for this table
```

#### Create the View
```python
ddl = definition.format(
    schema_name=schema_name,
    view_name=view_name,
    source_table=source_table
)
```

**Template substitution:**
```python
# Before:
"CREATE OR REPLACE VIEW {schema_name}.{view_name} AS SELECT * FROM {schema_name}.{source_table}"

# After:
"CREATE OR REPLACE VIEW public.v_customers AS SELECT * FROM public.customers"
```

---

### 9b. Drop Views

```python
def drop_views(config: dict, redshift_conn: dict, client, log):
    # ... same config loading ...
    
    ddl = f"""DROP VIEW IF EXISTS {schema_name}.{view_name}"""
```

**`IF EXISTS`** - Prevents error if view doesn't exist.

**Why drop views before altering tables?**
- Redshift views are bound to table structure
- `ALTER TABLE ADD COLUMN` fails if views depend on table
- Must drop → alter → recreate

---

## 10. **Data Type Validation**

```python
def check_datatype_matching(redshift_df, df, log):
    log.info("checking for datatype mismatch between source file and redshift table")
    
    redshift_cols = {field.name: field.dataType for field in redshift_df.schema.fields}
```

#### Type Categories
```python
non_numeric_types = (
    StringType, BooleanType, BinaryType, DateType, TimestampType,
    ArrayType, MapType, StructType
)

numeric_types = (
    ByteType, ShortType, IntegerType, LongType,
    FloatType, DoubleType, DecimalType
)
```

#### Validation Logic
```python
for field in df.schema.fields:
    if field.name in redshift_cols:
        src_type = type(field.dataType)
        tgt_type = type(redshift_cols[field.name])

        # Count non-null values
        non_null_count = df.select(count(field.name)).collect()[0][0]
        
        # Error: Source is text but target expects number (and data exists)
        if issubclass(src_type, non_numeric_types) and issubclass(tgt_type, numeric_types) and non_null_count != 0:
            msg = f"Datatype mismatch for column '{field.name}': source={src_type.__name__}, target={tgt_type.__name__}"
            raise Exception(msg)
```

**Example failure:**
- Source: `customer_id` column contains `"ABC123"` (string)
- Target: `customer_id` column is `INTEGER`
- Result: Exception raised before loading corrupt data

---

## 11. **Audit Table Update**

```python
def update_job_sts_table(config: dict, redshift_conn: dict,
                         run_start_ts: str, run_end_ts: str,
                         source_filename: str,
                         records_read: int,
                         records_updated: int,
                         records_inserted: int,
                         status: str, error_message: str,
                         client):
```

#### Generate Run ID
```python
run_id = int(time.time())  # Unix timestamp as unique ID
```

#### Insert Audit Record
```python
sql = dedent(f"""
    INSERT INTO {schema}.JOB_STS (
        run_id, job_id, run_start_ts, run_end_ts,
        source_filename, target_table_name,
        records_read, records_updated, records_inserted,
        status, error_message)
    VALUES (
        {run_id}, '{job_id}', '{run_start_ts}', '{run_end_ts}',
        '{source_filename}', '{config['target_table']}',
        {records_read}, {records_updated}, {records_inserted},
        '{status}', '{error_message.replace("'", "''")}'
    );
""")
```

**Note:** `error_message.replace("'", "''")`  - Escapes single quotes to prevent SQL injection.

#### JOB_STS Table Structure
```sql
CREATE TABLE JOB_STS (
    run_id BIGINT,
    job_id VARCHAR(256),
    run_start_ts TIMESTAMP,
    run_end_ts TIMESTAMP,
    source_filename VARCHAR(256),
    target_table_name VARCHAR(256),
    records_read INTEGER,
    records_updated INTEGER,
    records_inserted INTEGER,
    status VARCHAR(50),       -- 'SUCCESS' or 'FAILED'
    error_message VARCHAR(MAX)
);
```

---

## 12. **S3 File Management**

### 12a. Move to Archive (Success)

```python
def move_s3_file_to_archive(config: dict, target_file_path: str, log):
    s3_client = boto3.client('s3')
    
    source_file_path = f"s3://{config['src_bucket']}/data/in/{config['source_file_name']}"
    
    # Parse S3 paths
    source_bucket, source_key = source_file_path.replace("s3://", "").split("/", 1)
    target_bucket, target_key = target_file_path.replace("s3://", "").split("/", 1)
```

#### Copy then Delete (Atomic Move)
```python
try:
    # Step 1: Copy to archive
    s3_client.copy_object(
        Bucket=target_bucket,
        CopySource={'Bucket': source_bucket, 'Key': source_key},
        Key=target_key
    )
    log.info(f"File copied from {source_file_path} to {target_file_path}")
    
    # Step 2: Delete original
    s3_client.delete_object(Bucket=source_bucket, Key=source_key)
    log.info(f"Original file {source_file_path} deleted.")
except Exception as e:
    log.error("Error while moving file", error=str(e))
```

**Why copy then delete?**
- S3 doesn't have a native "move" operation
- Copy first ensures file isn't lost if operation fails
- Two-step process is safe

**Archive path format:**
```
s3://bucket/data/archive/2025/01/customers_20250119103000.csv
                        ^^^^  ^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                        year month filename_timestamp.csv
```

---

### 12b. Delete Staging Files

```python
def delete_staging_s3_files(s3_staging_path: str, log):
    s3_client = boto3.client('s3')
    bucket_name, prefix = s3_staging_path.replace("s3://", "").split("/", 1)
    
    try:
        # List all objects under staging prefix
        objects = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        
        # Delete each object
        for obj in objects.get("Contents", []):
            s3_client.delete_object(Bucket=bucket_name, Key=obj["Key"])
            log.info(f"Deleted staging file: {obj['Key']}")
    except Exception as e:
        log.error("Error deleting staging files", error=str(e))
```

**Deletes all files in staging folder:**
```
s3://bucket/data/staging/customers_staging/run123/
├── _SUCCESS        ← deleted
├── part-00000.csv  ← deleted
└── .part-00000.crc ← deleted
```

---

### 12c. Move to Unprocessed (Failure)

```python
def move_s3_file_to_unprocessed(config: dict, target_file_path: str, log):
    # Same logic as archive, but different destination
```

**Unprocessed path format:**
```
s3://bucket/data/unprocessed/2025/01/customers.csv
```

**Use case:** When ETL fails, preserve the original file for investigation.

---

## 13. **Main Function - Complete Orchestration**

```python
def main():
```

### Parse Job Arguments
```python
args = getResolvedOptions(
    sys.argv,
    [
        'job_id', 'job_name', 'source_file_name', 'target_table', 'upsert_keys',
        'workgroup_name', 'database', 'region', 'secret_arn', 'iam_role',
        'schema_name', 'src_bucket'
    ]
)
```

**`getResolvedOptions`** - AWS Glue utility that parses command-line arguments.

**Example job invocation:**
```bash
aws glue start-job-run --job-name my-etl-job --arguments '{
    "--job_id": "JOB001",
    "--source_file_name": "customers.csv",
    "--target_table": "customers",
    "--upsert_keys": "[\"customer_id\"]",
    ...
}'
```

### Build Configuration Dictionaries
```python
config = {
    'job_id': args['job_id'],
    'job_name': args['job_name'],
    'source_file_name': args['source_file_name'],
    'target_table': args['target_table'],
    'upsert_keys': json.loads(args['upsert_keys']),  # Parse JSON array
    'src_bucket': args['src_bucket']
}

redshift_conn = {
    'workgroup_name': args['workgroup_name'],
    'database': args['database'],
    'region': args['region'],
    'secret_arn': args['secret_arn'],
    'iam_role': args['iam_role'],
    'schema_name': args['schema_name']
}
```

### Initialize Components
```python
run_id = uuid.uuid4().hex                  # Unique run identifier
log = LogBuffer(run_id)                     # Create logger
spark, glue_context, job = initialize_glue(config['job_name'])  # Init Spark
client = boto3.client("redshift-data", region_name=redshift_conn['region'])  # Redshift client
```

### Prepare Paths
```python
run_start_ts = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
year = datetime.now().strftime('%Y')
month = datetime.now().strftime('%m')
source_filename = config['source_file_name']

# Log file path
log_base_name = f"{source_filename.split('.')[0]}_log_{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}.txt"
# Example: customers_log_20250119103000.txt

# Archive path (success)
s3_archive_path = f"s3://{config['src_bucket']}/data/archive/{year}/{month}/{source_filename.split('.')[0]}_{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}.csv"

# Unprocessed path (failure)
s3_unprocessed_path = f"s3://{config['src_bucket']}/data/unprocessed/{year}/{month}/{source_filename}"

# Staging table name
staging = _clean_colname(config['source_file_name'].split('.')[0])
# Example: customers.csv → customers

# S3 staging path
s3_staging_path = f"s3://{config['src_bucket']}/data/staging/{config['target_table']}_{staging}/{run_id}"
```

### Main ETL Flow (Try Block)

```python
try:
    # 1. Read source file
    df = read_csv_file(config, spark)
    records_read = df.count()
    log.info("Records read", count=records_read)
```

#### Branch: Table Exists
```python
    if check_table_exists(redshift_conn, config, client):
        log.info("Target table exists")
        
        # Get current Redshift schema
        redshift_df = read_redshift_table_schema(config, redshift_conn, spark, client)
        rows_before = get_row_count(config, redshift_conn, client)
        
        # Schema reconciliation
        if set(df.columns) != set(redshift_df.columns):
            log.info("Reconciling new/missing columns")
            
            # Add missing columns to DataFrame (if target has more columns)
            df = fill_missing_columns(df, redshift_df)
            
            # Add new columns to Redshift (if source has more columns)
            alter_redshift_table(config, redshift_conn, df, redshift_df, client, log, spark)
```

#### Branch: New Table
```python
    else:
        log.info("Target table does not exist; creating")
        create_new_redshift_table(config, redshift_conn, df, client)
        rows_before = 0
```

#### Schema Finalization
```python
    # Expand VARCHAR columns if needed
    alter_varchar_columns(config, redshift_conn, df, client, log)
    
    # Re-read schema to get final structure
    redshift_df = read_redshift_table_schema(config, redshift_conn, spark, client)
    
    # Reorder DataFrame columns to match Redshift
    df = df.select(*[c.name for c in redshift_df.schema.fields])
```

**Why reorder columns?**
- Redshift `COPY` expects columns in specific order
- Ensures DataFrame matches target table exactly

#### Write to S3 and Load
```python
    # Write single CSV file to S3
    df.coalesce(1).write.mode("overwrite").option("header", True)\
        .option("quote", '"').option("escape", '"').csv(s3_staging_path)
    
    staging_table_name = f"{config['target_table']}_{re.sub(r'_', '', staging)}"
    
    # Create staging table in Redshift
    create_staging_table(config, redshift_conn, staging_table_name, client, log)
    
    # COPY data from S3 to staging
    copy_to_redshift(s3_staging_path, redshift_conn, staging_table_name, client, log)
    
    # Merge staging into target
    run_merge(config, redshift_conn, staging_table_name, client, log)
    
    # Mark Glue job complete
    job.commit()
```

**`coalesce(1)`** - Forces Spark to write single file (required for COPY).

#### Calculate Metrics
```python
    rows_after = get_row_count(config, redshift_conn, client)
    records_inserted = max(rows_after - rows_before, 0)
    records_updated = max(records_read - records_inserted, 0)
    run_end_ts = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
```

**Logic:**
- `records_inserted` = New records added (row count increase)
- `records_updated` = Existing records replaced (remaining from total read)

#### Record Success
```python
    update_job_sts_table(
        config, redshift_conn, run_start_ts, run_end_ts, source_filename,
        records_read, records_updated, records_inserted, "SUCCESS", "NULL", client
    )
    log.info("ETL Job Completed Successfully")
```

#### Cleanup
```python
    delete_staging_s3_files(s3_staging_path, log)
    move_s3_file_to_archive(config, s3_archive_path, log)
    log.export_to_s3(config['src_bucket'], f"logs/{datetime.now(timezone.utc).strftime('%Y/%m/%d')}", log_base_name)
```

### Error Handling (Except Block)

```python
except Exception as e:
    log.error("ETL FAILED", error=str(e))
    traceback.print_exc()  # Full stack trace to CloudWatch
```

#### Best-Effort Audit
```python
    try:
        run_end_ts = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
        df = read_csv_file(config, spark)  # Re-read to get count
        records_read = df.count()
        update_job_sts_table(
            config, redshift_conn, run_start_ts, run_end_ts, source_filename,
            records_read, 0, 0, "FAILED", str(e), client
        )
    except Exception as audit_ex:
        log.error("Failed to record job status", error=str(audit_ex))
```

**"Best-effort"** - Even if recording fails, we continue to cleanup.

#### Cleanup on Failure
```python
    finally:
        try:
            move_s3_file_to_unprocessed(config, s3_unprocessed_path, log)
            log.export_to_s3(config['src_bucket'], f"logs/{...}", log_base_name)
        except Exception:
            pass  # Ignore cleanup errors
    
    raise  # Re-raise original exception to mark Glue job as FAILED
```

---

## Complete Data Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                              ETL PIPELINE FLOW                                  │
└────────────────────────────────────────────────────────────────────────────────┘

     ┌─────────────────┐
     │  S3 Input File  │  s3://bucket/data/in/customers.csv
     │   (CSV)         │
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │   Spark Read    │  • Read CSV with inferred schema
     │   & Transform   │  • Clean column names
     └────────┬────────┘  • Cast DoubleType → DecimalType
              │           • Add run_date, file_name columns
              │
              ▼
     ┌─────────────────┐
     │ Schema Check    │  Does target table exist?
     └────────┬────────┘
              │
      ┌───────┴───────┐
      │               │
      ▼               ▼
┌─────────────┐ ┌─────────────┐
│  CREATE     │ │   ALTER     │  • Add missing columns
│  TABLE      │ │   TABLE     │  • Expand VARCHAR lengths
│  (new)      │ │  (existing) │  • Widen integer types
└──────┬──────┘ └──────┬──────┘
       │               │
       └───────┬───────┘
               │
               ▼
     ┌─────────────────┐
     │  Fill Missing   │  Add columns with defaults if source
     │    Columns      │  is missing columns from target
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │  Write to S3    │  s3://bucket/data/staging/{table}_{file}/{run_id}/
     │  (single CSV)   │  • coalesce(1) for single file
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │ CREATE STAGING  │  CREATE TABLE staging AS SELECT * FROM target WHERE 1=0
     │     TABLE       │
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │   COPY from S3  │  COPY staging FROM 's3://...' IAM_ROLE '...'
     │  to Staging     │  • Parallel bulk load
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │     MERGE       │  BEGIN;
     │  (DELETE+INSERT)│    DELETE FROM target USING staging WHERE keys match;
     └────────┬────────┘    INSERT INTO target SELECT * FROM staging;
              │             DROP TABLE staging;
              │           COMMIT;
              ▼
     ┌─────────────────┐
     │  Update Audit   │  INSERT INTO JOB_STS (...)
     │     Table       │
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │    Cleanup      │  • Delete S3 staging files
     │                 │  • Archive source file
     └────────┬────────┘  • Export logs to S3
              │
              ▼
         ┌─────────┐
         │  DONE   │
         └─────────┘


     ON ERROR:
     ┌─────────────────┐
     │  Record FAILED  │  → Update JOB_STS with error
     │    in audit     │  → Move source to unprocessed/
     └─────────────────┘  → Export error logs
```

---

This completes the comprehensive explanation of every module in the Glue job. Would you like me to dive deeper into any specific aspect, or explain how to modify any particular functionality?