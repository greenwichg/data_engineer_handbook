# Auto Loader - File Options

## Introduction

Alright, now that you understand how Auto Loader works at a high level, let's dive into the
file options that give you fine-grained control over how Auto Loader discovers, reads, and
processes files. These options are what make Auto Loader flexible enough to handle real-world
data ingestion scenarios where files come in different formats, naming conventions, and
directory structures.

Auto Loader options fall into two categories: **cloudFiles options** (prefixed with
`cloudFiles.`) that control Auto Loader's behavior, and **format-specific options** that
control how individual file formats (JSON, CSV, etc.) are parsed. Understanding these options
is critical for both the exam and real-world pipeline development.

## Core cloudFiles Options

### File Format

The most fundamental option -- tells Auto Loader what format the incoming files are in:

```python
.option("cloudFiles.format", "json")      # JSON files
.option("cloudFiles.format", "csv")       # CSV files
.option("cloudFiles.format", "parquet")   # Parquet files
.option("cloudFiles.format", "avro")      # Avro files
.option("cloudFiles.format", "text")      # Plain text files
.option("cloudFiles.format", "binaryFile") # Binary files
```

### Schema Location

Where Auto Loader persists the inferred schema:

```python
.option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
```

This is required when using schema inference (which is the default for formats like JSON and CSV).
Auto Loader writes a `_schemas` directory at this location containing the inferred schema. This
allows the schema to persist across stream restarts without re-inferring from scratch.

For self-describing formats like Parquet and Avro, schema inference reads the schema from the
file metadata, so it's lightweight. For JSON and CSV, Auto Loader samples a subset of files
to infer the schema.

### Schema Hints

Schema hints let you override or supplement the inferred schema for specific columns:

```python
.option("cloudFiles.schemaHints", "price DOUBLE, quantity INT, order_date TIMESTAMP")
```

This is extremely useful when Auto Loader infers a wrong type. For example, if a JSON field
contains `"123"` as a string but you want it as an integer, or if dates come in a format that
Auto Loader can't automatically parse:

```python
# Common use case: fix type inference issues
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
    .option("cloudFiles.schemaHints", "order_id LONG, amount DECIMAL(10,2)")
    .load("/mnt/landing/orders/")
)
```

Schema hints take precedence over inferred types. If you provide a hint for a column, Auto Loader
uses your specified type regardless of what it infers from the data.

## File Filtering Options

### Include/Exclude Glob Patterns

Control which files Auto Loader picks up using glob patterns:

```python
# Only process JSON files (ignore other files in the directory)
.option("pathGlobFilter", "*.json")

# Only process files matching a specific pattern
.option("pathGlobFilter", "orders_*.csv")
```

This is useful when your landing directory contains a mix of file types or when you want to
selectively process files based on naming conventions.

### Exclude Specific Patterns

```python
# Exclude files that start with underscore (common for checkpoint/metadata files)
.option("cloudFiles.excludeRegex", "_.*|.*\\.crc")
```

### Recursive File Discovery

By default, Auto Loader only looks at the top-level directory. To recursively process
subdirectories:

```python
.option("recursiveFileLookup", "true")
```

```
Directory structure:
/landing/orders/
  ├── 2024/
  │   ├── 01/
  │   │   ├── orders_001.json
  │   │   └── orders_002.json
  │   └── 02/
  │       └── orders_003.json
  └── 2025/
      └── 01/
          └── orders_004.json

With recursiveFileLookup=true:
  → Processes ALL .json files in all subdirectories

Without recursiveFileLookup:
  → Only processes files directly in /landing/orders/
```

## Format-Specific Options

### JSON Options

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    # Handle multi-line JSON (one JSON object spans multiple lines)
    .option("multiLine", "true")
    # Allow single quotes instead of double quotes
    .option("allowSingleQuotes", "true")
    # Parse dates in a custom format
    .option("dateFormat", "yyyy-MM-dd")
    .option("timestampFormat", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/events")
    .load("/mnt/landing/events/")
)
```

Common JSON options:
- **`multiLine`** -- Set to `true` for prettified JSON (default `false` assumes one JSON object per line)
- **`allowSingleQuotes`** -- Allow `'value'` instead of `"value"`
- **`primitivesAsString`** -- Read all primitive values as strings (useful for raw ingestion)
- **`dateFormat` / `timestampFormat`** -- Custom date/timestamp parsing patterns

### CSV Options

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "csv")
    # CSV has headers
    .option("header", "true")
    # Custom delimiter (default is comma)
    .option("sep", "|")
    # Handle quoted fields containing delimiters
    .option("quote", '"')
    # Handle escaped characters
    .option("escape", "\\")
    # Infer column types (default is everything as string)
    .option("inferSchema", "true")
    # Handle null values
    .option("nullValue", "NULL")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/products")
    .load("/mnt/landing/products/")
)
```

Common CSV options:
- **`header`** -- Whether files have a header row (default `false`)
- **`sep`** -- Column delimiter (default `,`)
- **`inferSchema`** -- Infer types vs treat all as strings
- **`nullValue`** -- String that represents null
- **`encoding`** -- Character encoding (default UTF-8)
- **`multiLine`** -- Allow fields to span multiple lines

## File Notification Options

Options for configuring notification-based file discovery:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.useNotifications", "true")
    # AWS-specific options
    .option("cloudFiles.region", "us-east-1")
    # Optional: use an existing SQS queue instead of creating one
    .option("cloudFiles.queueUrl", "https://sqs.us-east-1.amazonaws.com/123456789/my-queue")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
    .load("s3://my-bucket/landing/orders/")
)
```

When `useNotifications` is `true`, Auto Loader will:
1. Create an SQS queue (or use an existing one if specified)
2. Configure S3 event notifications on the bucket
3. Poll the queue for new file events

## Handling Bad Records

Auto Loader provides options for dealing with malformed or corrupt records:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    # What to do with corrupt records
    .option("mode", "PERMISSIVE")        # Default: set corrupt fields to null
    # .option("mode", "DROPMALFORMED")   # Skip corrupt records entirely
    # .option("mode", "FAILFAST")        # Fail the stream on corrupt records
    # Store corrupt records in a special column
    .option("columnNameOfCorruptRecord", "_corrupt_record")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/events")
    .load("/mnt/landing/events/")
)
```

The three parse modes:
- **PERMISSIVE** (default) -- Sets corrupt fields to null, optionally stores the raw record
- **DROPMALFORMED** -- Silently drops corrupt records
- **FAILFAST** -- Throws an exception on the first corrupt record

### Rescued Data Column

Auto Loader has a powerful feature called the **rescued data column** that captures data that
doesn't match the schema:

```python
.option("cloudFiles.rescuedDataColumn", "_rescued_data")
```

```
Example: Schema expects {id: INT, name: STRING}

Input record: {"id": 1, "name": "Alice", "email": "alice@example.com"}

Result:
┌────┬───────┬──────────────────────────────────────┐
│ id │ name  │ _rescued_data                        │
├────┼───────┼──────────────────────────────────────┤
│ 1  │ Alice │ {"email": "alice@example.com"}       │
└────┴───────┴──────────────────────────────────────┘
```

The `_rescued_data` column captures any fields that were present in the record but not in the
schema. This is much better than losing data silently -- you can audit what was rescued and
decide whether to evolve your schema.

## Max Files and Bytes Per Trigger

Control how much data Auto Loader processes in each micro-batch:

```python
# Process at most 1000 new files per micro-batch
.option("cloudFiles.maxFilesPerTrigger", 1000)

# Process at most 10GB of new files per micro-batch
.option("cloudFiles.maxBytesPerTrigger", "10g")
```

These options are useful for:
- **Rate limiting** -- Prevent a large backlog of files from overwhelming your cluster
- **Cost control** -- Limit how much data is processed per trigger
- **Predictable performance** -- Keep micro-batch sizes consistent

## Putting It All Together

Here's a production-ready Auto Loader configuration:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/events")
    .option("cloudFiles.schemaHints", "event_ts TIMESTAMP, user_id LONG")
    .option("cloudFiles.rescuedDataColumn", "_rescued_data")
    .option("cloudFiles.useNotifications", "true")
    .option("cloudFiles.maxFilesPerTrigger", 1000)
    .option("pathGlobFilter", "*.json")
    .load("s3://data-lake/landing/events/")
)

(df.writeStream
    .option("checkpointLocation", "/mnt/checkpoints/events")
    .option("mergeSchema", "true")
    .trigger(availableNow=True)
    .toTable("catalog.schema.raw_events")
)
```

## Key Exam Points

1. **`cloudFiles.format`** is required -- specifies the file format (json, csv, parquet, etc.)
2. **`cloudFiles.schemaLocation`** is required for schema inference/evolution -- stores the
   inferred schema across restarts
3. **`cloudFiles.schemaHints`** lets you override inferred types for specific columns
4. **`pathGlobFilter`** filters files by glob pattern (e.g., `"*.json"`)
5. **`recursiveFileLookup`** controls whether subdirectories are scanned
6. **`cloudFiles.useNotifications`** enables notification mode for scalable file discovery
7. **`cloudFiles.rescuedDataColumn`** captures data that doesn't match the schema instead of
   dropping it
8. **Parse modes**: PERMISSIVE (default, nulls for bad fields), DROPMALFORMED (skip), FAILFAST (error)
9. **`cloudFiles.maxFilesPerTrigger`** limits the number of files processed per micro-batch
10. **Format-specific options** (header, sep, multiLine, etc.) are passed as regular Spark
    reader options alongside cloudFiles options
