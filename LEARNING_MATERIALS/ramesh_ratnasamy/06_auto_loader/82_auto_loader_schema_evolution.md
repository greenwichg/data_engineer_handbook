# Auto Loader - Schema Evolution

## Introduction

Alright, let's tackle one of Auto Loader's most powerful features -- schema evolution. In the
real world, data schemas change all the time. A new field gets added to an API response, a column
gets renamed, a data type changes from integer to string. If your ingestion pipeline can't handle
these changes gracefully, you're going to spend a lot of time firefighting broken jobs.

Auto Loader's schema evolution capabilities let your pipeline automatically adapt to schema changes
in the source data without manual intervention. This is a massive productivity win and a key
differentiator that makes Auto Loader the preferred ingestion method on Databricks.

## How Schema Inference Works in Auto Loader

Before we talk about schema evolution, let's understand how Auto Loader infers the schema in
the first place.

When Auto Loader starts for the first time, it needs to determine the schema of the incoming data.
For self-describing formats like Parquet and Avro, the schema is embedded in the file metadata,
so this is straightforward. For formats like JSON and CSV, Auto Loader has to sample the data.

```
Schema Inference Flow:

First Run:
┌───────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│   Sample files    │────▶│  Infer schema    │────▶│  Store schema in  │
│   from input      │     │  from sample     │     │  schemaLocation   │
│   directory       │     │                  │     │  (_schemas dir)   │
└───────────────────┘     └──────────────────┘     └───────────────────┘

Subsequent Runs:
┌───────────────────┐     ┌──────────────────┐
│   Read stored     │────▶│  Use stored      │
│   schema from     │     │  schema for      │
│   schemaLocation  │     │  processing      │
└───────────────────┘     └──────────────────┘
```

The `cloudFiles.schemaLocation` option is critical -- it's where Auto Loader persists the
inferred schema. Without this, Auto Loader would have to re-infer the schema every time the
stream restarts, which is both slow and potentially inconsistent if new files have different
fields.

```python
# schemaLocation stores the inferred schema
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
    .load("/mnt/landing/orders/")
)
```

### What Gets Stored

At the schema location, Auto Loader creates a `_schemas` directory containing versioned schema
files:

```
/mnt/schemas/orders/_schemas/
  ├── 0                    # Initial inferred schema (version 0)
  ├── 1                    # Evolved schema (version 1)
  └── 2                    # Further evolved schema (version 2)
```

Each schema file contains the full schema definition including column names, types, and nullability.

## Schema Evolution Modes

Auto Loader provides several modes for handling schema changes through the
`cloudFiles.schemaEvolutionMode` option:

```python
.option("cloudFiles.schemaEvolutionMode", "addNewColumns")
```

### addNewColumns (Default for JSON/CSV)

When Auto Loader encounters a record with new columns that aren't in the current schema, it
automatically adds them to the schema and restarts the stream:

```
Schema Evolution with addNewColumns:

Current Schema: {id: INT, name: STRING, amount: DOUBLE}

New file arrives with: {"id": 5, "name": "Eve", "amount": 99.99, "email": "eve@example.com"}

Auto Loader:
1. Detects new column "email" (STRING)
2. Updates stored schema → {id: INT, name: STRING, amount: DOUBLE, email: STRING}
3. Restarts the stream with the new schema
4. Processes the file with the updated schema

Result: Stream continues with the new column included
```

This is the most common and recommended mode. The stream restart is automatic and transparent --
existing data gets `null` for the new column, and new data includes the field.

Important: the stream restart means the current micro-batch is interrupted and restarted. This
is safe because checkpointing ensures no data is lost or duplicated.

### rescue (Default for Parquet/Avro with rescuedDataColumn)

Instead of evolving the schema, new columns are captured in the rescued data column:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaEvolutionMode", "rescue")
    .option("cloudFiles.rescuedDataColumn", "_rescued_data")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
    .load("/mnt/landing/orders/")
)
```

```
Schema Evolution with rescue mode:

Current Schema: {id: INT, name: STRING}

New file: {"id": 5, "name": "Eve", "email": "eve@example.com"}

Result:
┌────┬──────┬──────────────────────────────────┐
│ id │ name │ _rescued_data                    │
├────┼──────┼──────────────────────────────────┤
│ 5  │ Eve  │ {"email": "eve@example.com"}     │
└────┴──────┴──────────────────────────────────┘

Schema stays the same -- no restart needed!
```

This mode is useful when you want strict schema control and prefer to handle new columns
manually rather than automatically evolving.

### failOnNewColumns

The stream fails with an error when new columns are detected:

```python
.option("cloudFiles.schemaEvolutionMode", "failOnNewColumns")
```

This is useful in production environments where schema changes should be reviewed and approved
by a data engineer before the pipeline accepts them. The stream failure alerts the team to
investigate.

### none

No schema evolution at all. New columns are silently ignored (dropped):

```python
.option("cloudFiles.schemaEvolutionMode", "none")
```

```
Schema Evolution with none mode:

Current Schema: {id: INT, name: STRING}

New file: {"id": 5, "name": "Eve", "email": "eve@example.com"}

Result:
┌────┬──────┐
│ id │ name │
├────┼──────┤
│ 5  │ Eve  │  (email is silently dropped)
└────┴──────┘
```

Use this when you explicitly don't want schema evolution and are okay with losing extra fields.

### Summary of Schema Evolution Modes

```
┌────────────────────┬───────────────────────────────────────────────────────┐
│ Mode               │ Behavior                                            │
├────────────────────┼───────────────────────────────────────────────────────┤
│ addNewColumns      │ Auto-add new columns, restart stream                │
│ rescue             │ Put new columns in _rescued_data, no restart        │
│ failOnNewColumns   │ Fail stream on new columns (alert for review)       │
│ none               │ Silently ignore new columns                         │
└────────────────────┴───────────────────────────────────────────────────────┘
```

## Schema Hints and Evolution

Schema hints interact with schema evolution in important ways. Hints take precedence over
inference and evolution:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("cloudFiles.schemaHints", "price DECIMAL(10,2), event_ts TIMESTAMP")
    .load("/mnt/landing/orders/")
)
```

```
Priority order:
1. Schema hints (highest priority -- always used for specified columns)
2. Stored schema from schemaLocation
3. Inferred schema from data (lowest priority)

Example:
- Data has "price": "29.99" (inferred as STRING)
- Schema hint says: price DECIMAL(10,2)
- Result: price is DECIMAL(10,2) ← hint wins
```

This is critical for handling type inference issues. Common scenarios where hints are needed:
- Numeric fields that sometimes appear as strings in JSON
- Date/timestamp fields with non-standard formats
- Fields that should be DECIMAL instead of DOUBLE for financial data
- ID fields that should be LONG instead of INT

## Schema Evolution with Delta Table Targets

When writing Auto Loader output to a Delta table, you also need to enable schema evolution
on the write side:

```python
# Read with Auto Loader (source schema evolution)
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/orders")
    .load("/mnt/landing/orders/")
)

# Write to Delta with mergeSchema (target schema evolution)
(df.writeStream
    .option("checkpointLocation", "/mnt/checkpoints/orders")
    .option("mergeSchema", "true")
    .trigger(availableNow=True)
    .toTable("catalog.schema.orders")
)
```

The `mergeSchema` option on the write side tells Delta Lake to accept new columns from the
incoming DataFrame. Without this, Delta Lake would reject writes that introduce new columns.

```
End-to-end Schema Evolution:

Source Files          Auto Loader           Delta Table
(new column          (detects new          (accepts new
 appears)             column, evolves       column via
                      read schema)          mergeSchema)
     │                     │                     │
     ▼                     ▼                     ▼
 {id, name,     →    Schema v2:          →   ALTER TABLE
  email}              id, name, email          ADD email
```

Both sides need to agree to evolve -- Auto Loader evolves the read schema, and `mergeSchema`
evolves the Delta table schema. If either side doesn't allow evolution, the pipeline will fail
or drop data.

## Handling Data Type Changes

Schema evolution handles new columns well, but what about changes to existing column types?
This is trickier:

```
Type Change Scenarios:

1. Compatible widening (INT → LONG): Usually handled automatically
2. Incompatible change (INT → STRING): Causes errors or data loss

Example:
  Version 1: {"quantity": 5}         → quantity inferred as INT
  Version 2: {"quantity": "five"}    → quantity is now STRING!

Without schema hints: This will cause parse errors
With schema hints: .option("cloudFiles.schemaHints", "quantity STRING")
  → Forces STRING from the start, both "5" and "five" are accepted
```

Best practice: If you know a field might have type changes, use schema hints to set the
broadest type from the start (e.g., STRING), and handle type conversion downstream.

## Rescued Data Column Deep Dive

The rescued data column deserves special attention because it's your safety net against data loss
during schema evolution:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/events")
    .option("cloudFiles.rescuedDataColumn", "_rescued_data")
    .load("/mnt/landing/events/")
)
```

What gets rescued:
1. **New columns** not in the schema (when using `rescue` or `none` evolution mode)
2. **Type mismatches** -- values that can't be parsed as the expected type
3. **Case mismatches** -- columns with different casing than the schema (e.g., `Name` vs `name`)

```
Rescued Data Examples:

Schema: {id: INT, name: STRING}

Record: {"id": 1, "name": "Alice", "email": "a@b.com"}
→ _rescued_data: {"email": "a@b.com"}              # New column rescued

Record: {"id": "not_a_number", "name": "Bob"}
→ id: null, _rescued_data: {"id": "not_a_number"}  # Type mismatch rescued

Record: {"id": 2, "Name": "Charlie"}
→ name: null, _rescued_data: {"Name": "Charlie"}   # Case mismatch rescued
```

This is incredibly valuable for data quality monitoring. You can set up alerts when
`_rescued_data IS NOT NULL` to detect schema issues early.

## Practical Schema Evolution Workflow

Here's a recommended workflow for managing schema evolution in production:

```
Production Schema Evolution Strategy:

1. Initial Setup:
   - Use addNewColumns mode
   - Enable rescuedDataColumn as safety net
   - Set schema hints for known problematic fields
   - Enable mergeSchema on Delta write

2. Monitoring:
   - Alert on _rescued_data IS NOT NULL
   - Monitor schema versions in schemaLocation
   - Track column count changes over time

3. When Issues Arise:
   - Check _rescued_data for unexpected fields
   - Update schema hints if type inference is wrong
   - Consider switching to failOnNewColumns for strict environments

4. Recovery:
   - Delete schemaLocation to force re-inference
   - Use schema hints to correct problematic types
   - Reprocess from checkpoint after schema fixes
```

## Key Exam Points

1. **`cloudFiles.schemaEvolutionMode`** has four options: `addNewColumns` (default for
   JSON/CSV), `rescue`, `failOnNewColumns`, `none`
2. **`addNewColumns`** automatically adds new columns and restarts the stream
3. **`cloudFiles.schemaLocation`** stores versioned schemas -- critical for persistence
   across restarts
4. **Schema hints take precedence** over both inferred and evolved schemas
5. **`cloudFiles.rescuedDataColumn`** captures data that doesn't match the schema (new columns,
   type mismatches, case mismatches)
6. **Both read and write sides** need to support evolution -- Auto Loader's `schemaEvolutionMode`
   on read, and `mergeSchema` on write to Delta
7. **`rescue` mode** does not restart the stream -- it puts unknown fields in the rescued column
8. **Stream restart on addNewColumns** is safe because checkpointing prevents data loss/duplication
9. **Schema hints** are essential for fields with inconsistent types (e.g., numbers appearing
   as strings in JSON)
10. **Deleting schemaLocation** forces re-inference -- useful for recovery but should be done
    carefully
