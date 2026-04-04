# AWS Glue Job - Module-by-Module Explanation

I'll break down this Glue ETL job into its logical modules and explain each one in simple terms.

---

## 1. **LogBuffer Class** - Structured Logging System

```python
class LogBuffer:
```

**Purpose:** Creates structured JSON logs and exports them to S3.

| Method | What it does |
|--------|--------------|
| `info()` | Logs informational messages |
| `warning()` | Logs warning messages |
| `error()` | Logs error messages |
| `export_to_s3()` | Saves all collected logs to an S3 file |

**How it works:**
- Each log entry is a JSON object with: `level`, `timestamp`, `run_id`, `message`, and any extra key-value pairs
- Logs are printed to CloudWatch (via `print`) AND stored in a buffer
- At the end, all logs are uploaded to S3 as a single file

**Example log output:**
```json
{"level": "INFO", "ts": "2025-01-19T10:30:00Z", "run_id": "abc123", "msg": "Records read", "count": 500}
```

---

## 2. **Retry Decorator** - Automatic Retry Logic

```python
def retry_on_exception(max_attempts=3, delay_seconds=300, exceptions=(Exception,)):
```

**Purpose:** Automatically retries a function if it fails.

**How it works:**
1. Wraps any function
2. If the function throws an exception, it waits and tries again
3. Default: 3 attempts with 5-minute delays between retries
4. Logs each retry attempt
5. If all retries fail, raises the final exception

**Used on these critical functions:**
- `alter_redshift_table()` - Adding new columns
- `alter_varchar_columns()` - Changing column sizes
- `run_merge()` - The main merge operation

---

## 3. **Glue Initialization**

```python
def initialize_glue(job_name: str):
```

**Purpose:** Sets up the Spark and Glue environment.

**Returns:**
- `spark` - SparkSession for data processing
- `glue_context` - Glue-specific context
- `job` - Job object for tracking/committing

---

## 4. **DataFrame Helpers** - Reading & Transforming Data

### 4a. Column Name Cleaner
```python
def _clean_colname(name: str) -> str:
```

**Purpose:** Standardizes column names to be Redshift-compatible.

**Transformations:**
- Converts to lowercase
- Replaces special characters with underscores
- Removes duplicate underscores
- Trims leading/trailing underscores

**Example:** `"First Name!"` → `"first_name"`

---

### 4b. CSV File Reader
```python
def read_csv_file(config: dict, spark):
```

**Purpose:** Reads source CSV from S3 and prepares it for loading.

**Steps:**
1. Reads CSV from `s3://{bucket}/data/in/{filename}`
2. Infers schema automatically
3. Normalizes all column names
4. Converts `DoubleType` columns to `DecimalType(38,18)` for precision (except upsert keys)
5. Adds two metadata columns:
   - `run_date` - Current timestamp
   - `file_name` - Source filename

---

## 5. **Redshift Data API Utilities**

### 5a. Poll Statement
```python
def _poll_statement(client, stmt_id: str, ctx: str, sleep_s: float = 0.5):
```

**Purpose:** Waits for a Redshift SQL statement to complete.

**How it works:**
1. Loops until status is `FINISHED`, `FAILED`, or `ABORTED`
2. Checks status every 0.5 seconds
3. Raises error if not `FINISHED`

---

### 5b. Execute SQL
```python
def execute_sql(sql: str, redshift_conn: dict, client):
```

**Purpose:** Runs any SQL against Redshift and waits for completion.

---

## 6. **Schema Discovery & Harmonization**

This is the **most complex section** - it handles schema evolution (when source files change over time).

### 6a. Read Redshift Table Schema
```python
def read_redshift_table_schema(config, redshift_conn, spark, client):
```

**Purpose:** Gets the current Redshift table structure as a Spark DataFrame schema.

**How it works:**
1. Runs `SELECT * FROM table WHERE 1=0` (returns no rows, just metadata)
2. Maps Redshift types to Spark types
3. Returns an empty DataFrame with the correct schema

---

### 6b. Check Table Exists
```python
def check_table_exists(redshift_conn, config, client) -> bool:
```

**Purpose:** Checks if the target table already exists in Redshift.

---

### 6c. Spark to Redshift Type Mapper
```python
def _spark_to_redshift_type(data_type) -> str:
```

**Purpose:** Converts Spark data types to Redshift SQL types.

| Spark Type | Redshift Type |
|------------|---------------|
| StringType | VARCHAR(256) |
| IntegerType | INTEGER |
| LongType | BIGINT |
| DecimalType | DECIMAL(38,18) |
| TimestampType | TIMESTAMP |
| ... | ... |

---

### 6d. Create New Redshift Table
```python
def create_new_redshift_table(config, redshift_conn, df, client, log):
```

**Purpose:** Creates a brand new table based on the source DataFrame schema.

**Key feature:** Columns that are upsert keys get `NOT NULL` constraint.

---

### 6e. Alter Redshift Table (Add Columns)
```python
@retry_on_exception(max_attempts=3, delay_seconds=180)
def alter_redshift_table(config, redshift_conn, df, redshift_df, client, log, spark):
```

**Purpose:** Adds new columns to Redshift if source file has new columns.

**Steps:**
1. Compares source columns vs target columns
2. Drops dependent views (required before ALTER)
3. Adds missing columns with `ALTER TABLE ADD COLUMN`
4. Recreates views

---

### 6f. Get Metadata
```python
def get_metadata(config, redshift_conn, client) -> dict:
```

**Purpose:** Gets column metadata (data type, VARCHAR length) from Redshift.

**Returns:** Dictionary like:
```python
{
    "customer_name": {"dtype": "varchar", "length": 256},
    "age": {"dtype": "integer", "length": None}
}
```

---

### 6g. Alter VARCHAR Columns (Resize)
```python
@retry_on_exception(max_attempts=3, delay_seconds=300)
def alter_varchar_columns(config, redshift_conn, df, client, log):
```

**Purpose:** Automatically expands VARCHAR columns if source data is longer.

**For String Columns:**
1. Finds max length of each string column in source data
2. Compares with current Redshift column length
3. If source is longer, expands column (adds 10 char buffer, max 65535)

**For Integer Columns:**
1. Checks if max value exceeds current type's range
2. Upgrades: `SMALLINT` → `INTEGER` → `BIGINT`
3. Uses a workaround (add temp column, copy data, drop old, rename) because Redshift doesn't support direct integer type changes

---

### 6h. Fill Missing Columns
```python
def fill_missing_columns(df, redshift_df):
```

**Purpose:** If source file is missing columns that exist in Redshift, add them with default values.

| Data Type | Default Value |
|-----------|---------------|
| String | `""` (empty) |
| Integer/Float | `0` |
| Boolean | `False` |
| Date/Timestamp | `None` |

---

## 7. **Staging Table & COPY**

### 7a. Create Staging Table
```python
def create_staging_table(config, redshift_conn, staging_table_name, client, log):
```

**Purpose:** Creates an empty staging table with same structure as target.

```sql
CREATE TABLE schema.staging AS SELECT * FROM schema.target WHERE 1=0;
```

---

### 7b. Find Single CSV
```python
def _find_single_csv_in_prefix(s3_uri: str) -> str:
```

**Purpose:** When Spark writes with `coalesce(1)`, it creates a folder with one CSV file. This finds that file.

---

### 7c. Copy to Redshift
```python
def copy_to_redshift(s3_staging_path, redshift_conn, staging_table_name, client, log):
```

**Purpose:** Uses Redshift's `COPY` command to bulk-load data from S3.

```sql
COPY schema.staging
FROM 's3://bucket/path'
IAM_ROLE 'arn:aws:iam::...'
FORMAT AS CSV
...
```

---

## 8. **Merge Operation (Upsert)**

```python
@retry_on_exception(max_attempts=3, delay_seconds=300)
def run_merge(config, redshift_conn, staging_table_name, client, log):
```

**Purpose:** Performs upsert (update existing + insert new records).

**How it works (DELETE + INSERT pattern):**
```sql
BEGIN;
-- Delete matching records from target
DELETE FROM target
USING staging
WHERE target.key1 = staging.key1 AND target.key2 = staging.key2;

-- Insert all records from staging
INSERT INTO target SELECT * FROM staging;

-- Cleanup
DROP TABLE staging;
COMMIT;
```

**Why this approach?** Redshift doesn't have native `MERGE` statement, so this pattern achieves the same result atomically.

---

## 9. **View Management**

### 9a. Create Views
```python
def create_views(config, redshift_conn, client, log):
```

**Purpose:** Creates/refreshes views based on configuration in `view_config.json`.

**Config structure:**
```json
[
  {
    "source_table": "customers",
    "view_name": "v_customers",
    "schema_name": "public",
    "definition": "CREATE OR REPLACE VIEW {schema_name}.{view_name} AS SELECT * FROM {schema_name}.{source_table}"
  }
]
```

---

### 9b. Drop Views
```python
def drop_views(config, redshift_conn, client, log):
```

**Purpose:** Drops views before altering underlying tables (required by Redshift).

---

## 10. **Data Type Validation**

```python
def check_datatype_matching(redshift_df, df, log):
```

**Purpose:** Validates that source data types are compatible with target.

**Key rule:** Non-numeric source columns (strings, dates, etc.) cannot load into numeric target columns.

---

## 11. **Audit Table Update**

```python
def update_job_sts_table(config, redshift_conn, ...):
```

**Purpose:** Records job execution metadata in `JOB_STS` table.

**Tracked metrics:**
- `run_id`, `job_id`
- `run_start_ts`, `run_end_ts`
- `source_filename`, `target_table_name`
- `records_read`, `records_updated`, `records_inserted`
- `status` (SUCCESS/FAILED)
- `error_message`

---

## 12. **S3 File Management**

### 12a. Archive Processed File
```python
def move_s3_file_to_archive(config, target_file_path, log):
```
Moves successful files to: `s3://bucket/data/archive/{year}/{month}/`

### 12b. Delete Staging Files
```python
def delete_staging_s3_files(s3_staging_path, log):
```
Cleans up temporary staging files in S3.

### 12c. Move to Unprocessed
```python
def move_s3_file_to_unprocessed(config, target_file_path, log):
```
Moves failed files to: `s3://bucket/data/unprocessed/{year}/{month}/`

---

## 13. **Main Function - Orchestration**

```python
def main():
```

**This is the orchestrator that ties everything together:**

```
┌─────────────────────────────────────────────────────────────┐
│                        MAIN FLOW                            │
├─────────────────────────────────────────────────────────────┤
│ 1. Parse job arguments                                      │
│ 2. Initialize Glue/Spark                                    │
│ 3. Read CSV from S3                                         │
│ 4. Check if target table exists                             │
│    ├─ YES: Get schema, reconcile columns                    │
│    └─ NO:  Create new table                                 │
│ 5. Alter VARCHAR lengths if needed                          │
│ 6. Write DataFrame to S3 staging location                   │
│ 7. Create staging table in Redshift                         │
│ 8. COPY data from S3 to staging table                       │
│ 9. Run MERGE (delete + insert)                              │
│ 10. Update audit table (JOB_STS)                            │
│ 11. Cleanup: delete staging files, archive source           │
│ 12. Export logs to S3                                       │
└─────────────────────────────────────────────────────────────┘

On Error:
  → Log error
  → Update JOB_STS with FAILED status
  → Move source file to unprocessed/
  → Export logs
  → Re-raise exception
```

---

## Visual Summary: Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   S3 Input   │────▶│  Spark/Glue  │────▶│  S3 Staging  │────▶│   Redshift   │
│  (CSV file)  │     │  (Transform) │     │  (temp CSV)  │     │   (Target)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │                    │
       │              ┌─────┴─────┐              │              ┌─────┴─────┐
       │              │ • Clean   │              │              │ • COPY    │
       │              │   columns │              │              │ • MERGE   │
       │              │ • Add     │              │              │ • Views   │
       │              │   metadata│              │              │           │
       │              └───────────┘              │              └───────────┘
       │                                         │
       ▼                                         ▼
┌──────────────┐                         ┌──────────────┐
│   Archive    │                         │   Deleted    │
│  (success)   │                         │  (cleanup)   │
└──────────────┘                         └──────────────┘
```

---

Would you like me to elaborate on any specific module or explain any particular concept in more depth?