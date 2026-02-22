# **Delta Lake Problem Types - Complete Cheat Sheet**

## **TABLE OF CONTENTS**

```
01. Table Creation & Conversion
02. MERGE / Upsert Patterns (CDC)
03. Time Travel & Versioning
04. OPTIMIZE, Z-ORDER & Liquid Clustering
05. VACUUM & Retention Management
06. Schema Evolution & Column Mapping
07. Streaming with Delta Lake
08. Change Data Feed (CDF)
09. Deletion Vectors & Update Patterns
10. CHECK Constraints & Data Quality
11. Clone Operations (SHALLOW / DEEP)
12. Performance Tuning & Data Skipping
```

---

## **PROBLEM TYPE 1: Table Creation & Conversion**

### **Trigger Words:**
```
"create delta table", "convert parquet to delta", "managed vs external",
"save as delta", "create or replace", "CTAS", "migrate to delta"
```

### **Key Pattern:**
```python
# Template: Create managed Delta table
df.write.format("delta").saveAsTable("catalog.schema.table_name")

# Template: Create external Delta table at path
df.write.format("delta").save("/delta/path/table_name")
```

### **Creation Choice Matrix:**

| Need | Use | Notes |
|------|-----|-------|
| Managed table (catalog-controlled) | `saveAsTable("name")` | Catalog manages location + metadata |
| External table (you control path) | `.save("/path")` | You manage storage lifecycle |
| SQL DDL | `CREATE TABLE ... USING DELTA` | Explicit schema definition |
| Create or overwrite | `CREATE OR REPLACE TABLE` | Atomic replacement |
| From query results | `CREATE TABLE ... AS SELECT` | CTAS pattern |
| Convert existing Parquet | `CONVERT TO DELTA` | In-place, no data copy |

### **Examples:**
```python
# Example 1: DataFrame API — managed table
df.write \
    .format("delta") \
    .mode("overwrite") \
    .partitionBy("year", "month") \
    .saveAsTable("analytics.sales")

# Example 2: DataFrame API — external table
df.write \
    .format("delta") \
    .mode("overwrite") \
    .option("path", "/delta/analytics/sales") \
    .saveAsTable("analytics.sales")

# Example 3: SQL DDL with full options
spark.sql("""
    CREATE TABLE IF NOT EXISTS analytics.customers (
        customer_id     STRING      NOT NULL,
        name            STRING,
        email           STRING,
        signup_date     DATE        GENERATED ALWAYS AS (CAST(created_at AS DATE)),
        created_at      TIMESTAMP,
        status          STRING
    )
    USING DELTA
    CLUSTER BY (customer_id)
    TBLPROPERTIES (
        'delta.columnMapping.mode' = 'name',
        'delta.enableDeletionVectors' = 'true'
    )
""")

# Example 4: CTAS (Create Table As Select)
spark.sql("""
    CREATE OR REPLACE TABLE analytics.active_customers
    USING DELTA
    AS SELECT * FROM analytics.customers WHERE status = 'active'
""")

# Example 5: Convert existing Parquet to Delta (in-place)
spark.sql("""
    CONVERT TO DELTA parquet.`/data/legacy_table`
    PARTITIONED BY (year INT, month INT)
""")

# Example 6: Convert with DeltaTable API
from delta.tables import DeltaTable
DeltaTable.convertToDelta(spark, "parquet.`/data/legacy_table`",
                          "year INT, month INT")
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Forgetting to specify USING DELTA
spark.sql("CREATE TABLE t (id INT, name STRING)")
# Default format may be Parquet or Hive depending on config

# ✅ CORRECT: Always specify USING DELTA
spark.sql("CREATE TABLE t (id INT, name STRING) USING DELTA")

# ❌ WRONG: Using mode("overwrite") without partitionOverwriteMode
df.write.format("delta").mode("overwrite").save("/delta/events")
# Overwrites ENTIRE table even if you only want to replace one partition

# ✅ CORRECT: Dynamic partition overwrite
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
df.write.format("delta").mode("overwrite").save("/delta/events")
# Only overwrites partitions present in the DataFrame

# ❌ WRONG: Converting partitioned Parquet without specifying partitions
spark.sql("CONVERT TO DELTA parquet.`/data/partitioned_table`")
# Fails if table is partitioned

# ✅ CORRECT: Specify partition schema
spark.sql("""
    CONVERT TO DELTA parquet.`/data/partitioned_table`
    PARTITIONED BY (date STRING)
""")
```

---

## **PROBLEM TYPE 2: MERGE / Upsert Patterns (CDC)**

### **Trigger Words:**
```
"upsert", "merge", "CDC", "change data capture", "slowly changing dimension",
"SCD Type 1/2", "insert or update", "deduplicate on write", "sync tables"
```

### **Key Pattern:**
```python
from delta.tables import DeltaTable

# Template: Basic MERGE (upsert)
delta_table = DeltaTable.forName(spark, "target_table")
delta_table.alias("t").merge(
    source_df.alias("s"),
    "t.id = s.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

### **MERGE Clause Matrix:**

| Clause | Use When | Common Options |
|--------|----------|----------------|
| `whenMatchedUpdate` | Row exists, update specific cols | `set={"col": "s.col"}` |
| `whenMatchedUpdateAll` | Row exists, update all cols | No args needed |
| `whenMatchedDelete` | Row exists, need to remove | Optional `condition` |
| `whenNotMatchedInsert` | New row, insert specific cols | `values={"col": "s.col"}` |
| `whenNotMatchedInsertAll` | New row, insert all cols | No args needed |
| `whenNotMatchedBySourceUpdate` | In target but not source | Useful for SCD |
| `whenNotMatchedBySourceDelete` | In target but not source | Mark as deleted |

### **Examples:**
```python
# Example 1: Basic upsert (SCD Type 1 — overwrite)
delta_table.alias("t").merge(
    updates_df.alias("s"),
    "t.customer_id = s.customer_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# Example 2: Conditional update (only if data changed)
delta_table.alias("t").merge(
    updates_df.alias("s"),
    "t.customer_id = s.customer_id"
).whenMatchedUpdate(
    condition="t.updated_at < s.updated_at",
    set={
        "name": "s.name",
        "email": "s.email",
        "updated_at": "s.updated_at"
    }
).whenNotMatchedInsertAll() \
 .execute()

# Example 3: SCD Type 2 (preserve history)
from pyspark.sql.functions import current_timestamp, lit

# Step 1: Find rows that changed
delta_table = DeltaTable.forName(spark, "dim_customer")
staged_updates = updates_df.alias("s").join(
    delta_table.toDF().alias("t"),
    "customer_id"
).where("s.name != t.name OR s.email != t.email") \
 .where("t.is_current = true") \
 .selectExpr(
    "NULL as merge_key",    # NULL key forces NOT MATCHED → INSERT
    "s.*"
).unionByName(
    updates_df.select(col("customer_id").alias("merge_key"), "*")
)

# Step 2: MERGE — close old + insert new
delta_table.alias("t").merge(
    staged_updates.alias("s"),
    "t.customer_id = s.merge_key AND t.is_current = true"
).whenMatchedUpdate(set={
    "is_current": "false",
    "end_date": "current_timestamp()"
}).whenNotMatchedInsertAll() \
 .execute()

# Example 4: Delete + upsert (full CDC pattern)
delta_table.alias("t").merge(
    cdc_events.alias("s"),
    "t.id = s.id"
).whenMatchedDelete(
    condition="s.operation = 'DELETE'"
).whenMatchedUpdate(
    condition="s.operation = 'UPDATE'",
    set={"name": "s.name", "email": "s.email", "updated_at": "s.updated_at"}
).whenNotMatchedInsert(
    condition="s.operation = 'INSERT'",
    values={"id": "s.id", "name": "s.name", "email": "s.email",
            "updated_at": "s.updated_at"}
).execute()

# Example 5: Deduplicate on insert (skip existing)
delta_table.alias("t").merge(
    new_data.alias("s"),
    "t.event_id = s.event_id"
).whenNotMatchedInsertAll() \
 .execute()
# Matched rows (duplicates) are silently skipped

# Example 6: SQL MERGE syntax
spark.sql("""
    MERGE INTO target t
    USING source s
    ON t.id = s.id
    WHEN MATCHED AND s.op = 'DELETE' THEN DELETE
    WHEN MATCHED AND s.op = 'UPDATE' THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Merge key matches multiple source rows per target row
# If source has duplicates for the same key, MERGE fails!
delta_table.alias("t").merge(
    duplicated_source.alias("s"),  # s has 2 rows for id=123
    "t.id = s.id"
).whenMatchedUpdateAll().execute()
# Error: "multiple source rows matched a single target row"

# ✅ CORRECT: Deduplicate source first
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number

window = Window.partitionBy("id").orderBy(col("updated_at").desc())
deduped_source = source_df.withColumn("rn", row_number().over(window)) \
    .filter("rn = 1").drop("rn")

delta_table.alias("t").merge(
    deduped_source.alias("s"), "t.id = s.id"
).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

# ❌ WRONG: Forgetting partition predicate on large tables
delta_table.alias("t").merge(source.alias("s"), "t.id = s.id")
# Scans entire target table!

# ✅ CORRECT: Add partition filter to merge condition
delta_table.alias("t").merge(
    source.alias("s"),
    "t.id = s.id AND t.date = s.date"  # date is partition column
)
```

---

## **PROBLEM TYPE 3: Time Travel & Versioning**

### **Trigger Words:**
```
"previous version", "point in time", "rollback", "restore",
"as of", "version", "audit", "what changed", "undo", "history"
```

### **Key Pattern:**
```python
# Template: Query by version
spark.read.format("delta").option("versionAsOf", 5).load("/delta/table")

# Template: Query by timestamp
spark.read.format("delta").option("timestampAsOf", "2024-02-08").load("/delta/table")
```

### **Time Travel Options:**

| Need | Python API | SQL |
|------|-----------|-----|
| Read version N | `.option("versionAsOf", N)` | `SELECT * FROM t VERSION AS OF N` |
| Read at timestamp | `.option("timestampAsOf", ts)` | `SELECT * FROM t TIMESTAMP AS OF ts` |
| View history | `delta_table.history()` | `DESCRIBE HISTORY t` |
| Restore to version | `delta_table.restoreToVersion(N)` | `RESTORE TABLE t TO VERSION AS OF N` |
| Restore to timestamp | `delta_table.restoreToTimestamp(ts)` | `RESTORE TABLE t TO TIMESTAMP AS OF ts` |

### **Examples:**
```python
from delta.tables import DeltaTable

# Example 1: Read specific version
df_v5 = spark.read.format("delta").option("versionAsOf", 5).load("/delta/events")

# Example 2: Read at specific timestamp
df_yesterday = spark.read.format("delta") \
    .option("timestampAsOf", "2024-02-07T00:00:00") \
    .load("/delta/events")

# Example 3: View full history
delta_table = DeltaTable.forPath(spark, "/delta/events")
history = delta_table.history()
history.select("version", "timestamp", "operation", "operationMetrics").show()

# Example 4: Compare two versions (diff)
df_before = spark.read.format("delta").option("versionAsOf", 10).load("/delta/events")
df_after  = spark.read.format("delta").option("versionAsOf", 15).load("/delta/events")

added   = df_after.subtract(df_before)    # new rows
removed = df_before.subtract(df_after)    # deleted rows

# Example 5: Restore (undo bad write)
delta_table.restoreToVersion(10)
# Creates a NEW version that matches version 10's state

# Example 6: SQL time travel
spark.sql("SELECT * FROM events VERSION AS OF 5 WHERE user_id = 'u123'")
spark.sql("SELECT * FROM events TIMESTAMP AS OF '2024-02-07' LIMIT 100")
spark.sql("RESTORE TABLE events TO VERSION AS OF 10")

# Example 7: Audit — find who changed what
delta_table.history().select(
    "version", "timestamp", "userId", "operation",
    "operationParameters", "operationMetrics"
).filter("operation IN ('MERGE', 'DELETE', 'UPDATE')") \
 .orderBy(col("version").desc()) \
 .show(truncate=False)
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Time travel after VACUUM deleted old files
delta_table.vacuum(168)  # 7-day retention
spark.read.format("delta").option("versionAsOf", 0).load("/delta/events")
# Error: FileNotFoundException — version 0 files were vacuumed!

# ✅ CORRECT: Ensure retention covers your time travel needs
# VACUUM retention >= max time travel window
delta_table.vacuum(720)  # 30 days retention

# ❌ WRONG: Assuming RESTORE undoes physical changes
delta_table.restoreToVersion(5)
# RESTORE creates a NEW version (e.g., version 20) that matches version 5
# It does NOT delete versions 6-19 from history

# ❌ WRONG: Using versionAsOf with the table name (not path)
spark.read.format("delta").option("versionAsOf", 5).table("events")
# Use .load(path) or SQL syntax instead

# ✅ CORRECT: SQL syntax for named tables
spark.sql("SELECT * FROM events VERSION AS OF 5")
```

---

## **PROBLEM TYPE 4: OPTIMIZE, Z-ORDER & Liquid Clustering**

### **Trigger Words:**
```
"small files", "compaction", "optimize", "z-order", "cluster by",
"liquid clustering", "file size", "data skipping", "query speed",
"too many files", "slow reads"
```

### **Key Pattern:**
```python
# Template: Compact small files
spark.sql("OPTIMIZE table_name")

# Template: Compact + Z-ORDER
spark.sql("OPTIMIZE table_name ZORDER BY (col1, col2)")

# Template: Liquid Clustering (modern replacement)
spark.sql("CREATE TABLE t (...) USING DELTA CLUSTER BY (col1, col2)")
```

### **Optimization Choice Matrix:**

| Problem | Solution | When to Use |
|---------|----------|-------------|
| Too many small files | `OPTIMIZE` | After streaming/frequent small writes |
| Slow queries on filter columns | `ZORDER BY` | Existing tables, up to ~4 columns |
| Need changeable clustering | `CLUSTER BY` (Liquid) | New tables (Delta 3.0+) |
| Partition too granular | Remove partition + use Liquid | Over-partitioned tables |
| Specific partition slow | `OPTIMIZE ... WHERE` | Target specific partitions |

### **Examples:**
```python
# Example 1: Basic compaction
spark.sql("OPTIMIZE events")

# Example 2: Z-ORDER for common filter columns
spark.sql("OPTIMIZE events ZORDER BY (user_id, event_date)")

# Example 3: Optimize specific partition only
spark.sql("OPTIMIZE events WHERE date = '2024-02-08'")

# Example 4: Liquid Clustering — create new table
spark.sql("""
    CREATE TABLE events_v2 (
        event_id STRING, user_id STRING, event_type STRING, event_date DATE
    ) USING DELTA
    CLUSTER BY (user_id, event_date)
""")

# Example 5: Liquid Clustering — enable on existing table
spark.sql("ALTER TABLE events CLUSTER BY (user_id, event_date)")

# Example 6: Change clustering columns (instant, no rewrite)
spark.sql("ALTER TABLE events CLUSTER BY (event_type, event_date)")

# Example 7: Disable clustering
spark.sql("ALTER TABLE events CLUSTER BY NONE")

# Example 8: Python API compaction
delta_table = DeltaTable.forPath(spark, "/delta/events")
delta_table.optimize().executeCompaction()

# Example 9: Python API Z-ORDER
delta_table.optimize().executeZOrderBy("user_id", "event_date")

# Example 10: Auto-optimization settings (Databricks)
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.autoOptimize.optimizeWrite' = 'true',
        'delta.autoOptimize.autoCompact' = 'true'
    )
""")
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Z-ORDER on too many columns (diminishing returns after ~4)
spark.sql("OPTIMIZE t ZORDER BY (c1, c2, c3, c4, c5, c6, c7)")
# Effectiveness drops sharply after 4 columns

# ✅ CORRECT: Choose 2-4 most-filtered columns
spark.sql("OPTIMIZE t ZORDER BY (user_id, event_date)")

# ❌ WRONG: Z-ORDER on partition column (redundant)
spark.sql("OPTIMIZE t ZORDER BY (date)")  # date is already partition col
# Partition pruning already handles this — Z-ORDER adds nothing

# ✅ CORRECT: Z-ORDER on non-partition filter columns
spark.sql("OPTIMIZE t ZORDER BY (user_id)")  # user_id is NOT a partition

# ❌ WRONG: Using PARTITIONED BY + ZORDER BY on new table (legacy)
# ✅ CORRECT: Use Liquid Clustering on new tables instead
spark.sql("CREATE TABLE t (...) USING DELTA CLUSTER BY (col1, col2)")

# ❌ WRONG: Never running OPTIMIZE on streaming tables
# Small files accumulate from micro-batches!
# ✅ CORRECT: Schedule OPTIMIZE or enable auto-compaction
```

---

## **PROBLEM TYPE 5: VACUUM & Retention Management**

### **Trigger Words:**
```
"storage cost", "clean up old files", "vacuum", "retention",
"delete old versions", "reclaim space", "stale files", "disk usage"
```

### **Key Pattern:**
```python
# Template: VACUUM with default retention (7 days)
delta_table.vacuum()

# Template: VACUUM with custom retention
delta_table.vacuum(720)  # 30 days in hours
```

### **Retention Settings:**

| Setting | Default | Purpose |
|---------|---------|---------|
| `delta.deletedFileRetentionDuration` | `interval 7 days` | VACUUM won't delete files newer than this |
| `delta.logRetentionDuration` | `interval 30 days` | How long to keep transaction log entries |
| `spark.databricks.delta.retentionDurationCheck.enabled` | `true` | Safety check preventing < 7 day vacuum |

### **Examples:**
```python
# Example 1: Standard VACUUM (7-day retention)
from delta.tables import DeltaTable
delta_table = DeltaTable.forPath(spark, "/delta/events")
delta_table.vacuum()

# Example 2: VACUUM with 30-day retention
delta_table.vacuum(720)  # hours

# Example 3: SQL VACUUM
spark.sql("VACUUM events")
spark.sql("VACUUM events RETAIN 720 HOURS")

# Example 4: Dry run (see what would be deleted)
delta_table.vacuum(720)  # In Databricks, DRY RUN is default on first call

# Example 5: Configure table-level retention
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.deletedFileRetentionDuration' = 'interval 30 days',
        'delta.logRetentionDuration' = 'interval 60 days'
    )
""")

# Example 6: Check table size before/after VACUUM
spark.sql("DESCRIBE DETAIL events").select(
    "name", "numFiles", "sizeInBytes"
).show()
# Run VACUUM
spark.sql("VACUUM events RETAIN 168 HOURS")
# Check again
spark.sql("DESCRIBE DETAIL events").select(
    "name", "numFiles", "sizeInBytes"
).show()

# Example 7: Production workflow — OPTIMIZE then VACUUM
spark.sql("OPTIMIZE events")               # Compact small files first
spark.sql("VACUUM events RETAIN 168 HOURS") # Then clean up old files
```

### **Common Pitfalls:**
```python
# ❌ WRONG: VACUUM with 0 hours (deletes ALL old files)
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
delta_table.vacuum(0)
# Breaks time travel, breaks concurrent readers, DANGEROUS!

# ✅ CORRECT: Always keep at least 7 days (168 hours)
delta_table.vacuum(168)

# ❌ WRONG: Running VACUUM while long-running queries are active
# If a query started reading version 5 files, and VACUUM deletes them:
# → Query fails with FileNotFoundException!

# ✅ CORRECT: VACUUM retention > longest running query time
# If queries take up to 4 hours: vacuum(168) is safe (7 days >> 4 hours)

# ❌ WRONG: Expecting VACUUM to fix small files
delta_table.vacuum()
# VACUUM only deletes OLD files — it does NOT compact small files

# ✅ CORRECT: OPTIMIZE compacts, VACUUM cleans
spark.sql("OPTIMIZE events")   # Step 1: compact small files into large ones
spark.sql("VACUUM events")     # Step 2: delete the old small files
```

---

## **PROBLEM TYPE 6: Schema Evolution & Column Mapping**

### **Trigger Words:**
```
"add column", "schema change", "new field", "rename column", "drop column",
"merge schema", "overwrite schema", "column mapping", "evolve schema",
"backwards compatible", "breaking change"
```

### **Key Pattern:**
```python
# Template: Additive schema evolution (safe)
df.write.format("delta").mode("append").option("mergeSchema", "true").save(path)

# Template: Full schema replacement (destructive)
df.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(path)
```

### **Schema Change Matrix:**

| Change Type | Method | Risk Level | Requires Column Mapping? |
|------------|--------|------------|-------------------------|
| Add column | `mergeSchema` or `ALTER TABLE ADD` | Low | No |
| Widen type (int → long) | `mergeSchema` | Low | No |
| Rename column | `ALTER TABLE RENAME COLUMN` | Medium | Yes |
| Drop column | `ALTER TABLE DROP COLUMN` | High | Yes |
| Replace schema | `overwriteSchema` | Destructive | No |
| Reorder columns | `ALTER TABLE ALTER COLUMN FIRST/AFTER` | Low | Yes |

### **Examples:**
```python
# Example 1: Add column automatically on write
new_df_with_extra_col.write \
    .format("delta") \
    .mode("append") \
    .option("mergeSchema", "true") \
    .saveAsTable("events")
# New column added, existing rows get NULL

# Example 2: Add column via SQL
spark.sql("ALTER TABLE events ADD COLUMN (phone STRING, score DOUBLE)")

# Example 3: Enable column mapping (required for rename/drop)
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.columnMapping.mode' = 'name',
        'delta.minReaderVersion' = '2',
        'delta.minWriterVersion' = '5'
    )
""")

# Example 4: Rename column (requires column mapping)
spark.sql("ALTER TABLE events RENAME COLUMN user_agent TO browser")

# Example 5: Drop column (requires column mapping)
spark.sql("ALTER TABLE events DROP COLUMN legacy_field")

# Example 6: Change column type (safe widening)
spark.sql("ALTER TABLE events ALTER COLUMN amount TYPE DOUBLE")
# INT → LONG → DOUBLE is safe; DOUBLE → INT is not allowed

# Example 7: Add NOT NULL constraint
spark.sql("ALTER TABLE events ALTER COLUMN event_id SET NOT NULL")

# Example 8: Full schema replacement (destructive)
completely_new_schema_df.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("/delta/events")

# Example 9: Nested schema evolution (structs)
spark.sql("""
    ALTER TABLE events ADD COLUMN
    (metadata STRUCT<source: STRING, version: INT>)
""")
# Add field to existing struct:
spark.sql("""
    ALTER TABLE events ADD COLUMN
    (metadata.environment STRING)
""")
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Renaming column without column mapping enabled
spark.sql("ALTER TABLE events RENAME COLUMN email TO email_address")
# Error: column rename requires column mapping to be enabled

# ✅ CORRECT: Enable column mapping first
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.columnMapping.mode' = 'name'
    )
""")
spark.sql("ALTER TABLE events RENAME COLUMN email TO email_address")

# ❌ WRONG: Using mergeSchema when you want to REPLACE the schema
df.write.format("delta").mode("overwrite") \
    .option("mergeSchema", "true").save(path)
# mergeSchema + overwrite = UNION of old + new columns (not replacement)

# ✅ CORRECT: Use overwriteSchema for full replacement
df.write.format("delta").mode("overwrite") \
    .option("overwriteSchema", "true").save(path)

# ❌ WRONG: Narrowing column type
spark.sql("ALTER TABLE events ALTER COLUMN amount TYPE INT")
# Cannot narrow DOUBLE → INT, would lose data

# ✅ CORRECT: Only widen types
spark.sql("ALTER TABLE events ALTER COLUMN amount TYPE DOUBLE")  # INT → DOUBLE OK
```

---

## **PROBLEM TYPE 7: Streaming with Delta Lake**

### **Trigger Words:**
```
"real-time", "streaming", "micro-batch", "continuous ingestion",
"readStream", "writeStream", "trigger", "checkpoint", "exactly-once",
"Kafka to Delta", "streaming merge", "foreachBatch"
```

### **Key Pattern:**
```python
# Template: Stream read from Delta
stream_df = spark.readStream.format("delta").load("/delta/source")

# Template: Stream write to Delta
stream_df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/checkpoints/stream1") \
    .start("/delta/target")
```

### **Streaming Configuration Matrix:**

| Setting | Options | Use When |
|---------|---------|----------|
| `outputMode` | `append`, `complete`, `update` | `append` for Delta sink (most common) |
| `trigger` | `availableNow`, `processingTime`, `once` | Batch cadence control |
| `checkpointLocation` | Path string | Always required (exactly-once) |
| `maxFilesPerTrigger` | Integer | Rate-limit reads from Delta source |
| `ignoreChanges` | `true` / `false` | Allow reading after MERGE/UPDATE on source |
| `ignoreDeletes` | `true` / `false` | Allow reading after DELETE on source |

### **Examples:**
```python
# Example 1: Simple Delta-to-Delta streaming
stream_df = spark.readStream.format("delta") \
    .option("maxFilesPerTrigger", 100) \
    .load("/delta/raw_events")

stream_df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/checkpoints/events") \
    .trigger(availableNow=True) \
    .start("/delta/processed_events")

# Example 2: Kafka → Delta streaming
kafka_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("subscribe", "events") \
    .load()

parsed_df = kafka_df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

parsed_df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/checkpoints/kafka_events") \
    .trigger(processingTime="30 seconds") \
    .start("/delta/events")

# Example 3: Streaming MERGE with foreachBatch
def upsert_micro_batch(batch_df, batch_id):
    delta_table = DeltaTable.forPath(spark, "/delta/customers")
    delta_table.alias("t").merge(
        batch_df.alias("s"),
        "t.customer_id = s.customer_id"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()

spark.readStream.format("delta").load("/delta/customer_updates") \
    .writeStream \
    .foreachBatch(upsert_micro_batch) \
    .option("checkpointLocation", "/checkpoints/customer_merge") \
    .trigger(processingTime="1 minute") \
    .start()

# Example 4: Trigger modes
# Process everything available now, then stop (batch-like)
.trigger(availableNow=True)

# Process every N seconds
.trigger(processingTime="30 seconds")

# Process once (deprecated, use availableNow instead)
.trigger(once=True)

# Example 5: Read past MERGE/UPDATE on source table
stream_df = spark.readStream.format("delta") \
    .option("ignoreChanges", "true") \
    .load("/delta/source_table")
# Without ignoreChanges, stream fails if source had UPDATE/MERGE
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Missing checkpointLocation
stream_df.writeStream.format("delta").start("/delta/target")
# May lose exactly-once guarantee on restart

# ✅ CORRECT: Always set checkpoint
stream_df.writeStream.format("delta") \
    .option("checkpointLocation", "/checkpoints/stream1") \
    .start("/delta/target")

# ❌ WRONG: Using outputMode("complete") with Delta sink
stream_df.writeStream.format("delta").outputMode("complete").start(path)
# Delta append-only sink doesn't support complete mode for most queries

# ✅ CORRECT: Use append mode (or foreachBatch for complex logic)
stream_df.writeStream.format("delta").outputMode("append").start(path)

# ❌ WRONG: Changing checkpoint location between restarts
# This loses streaming state and reprocesses from scratch!

# ✅ CORRECT: Keep same checkpoint location across restarts
# Only change if you intentionally want to reprocess
```

---

## **PROBLEM TYPE 8: Change Data Feed (CDF)**

### **Trigger Words:**
```
"change data feed", "CDF", "change data capture", "track changes",
"audit changes", "what changed", "incremental read", "downstream CDC",
"propagate changes"
```

### **Key Pattern:**
```python
# Template: Enable CDF
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
""")

# Template: Read changes between versions
changes = spark.read.format("delta") \
    .option("readChangeFeed", "true") \
    .option("startingVersion", 5) \
    .option("endingVersion", 10) \
    .table("events")
```

### **CDF Change Types:**

| `_change_type` Value | Meaning | Produced By |
|---------------------|---------|-------------|
| `insert` | New row added | INSERT, MERGE (not matched) |
| `update_preimage` | Row before update | UPDATE, MERGE (matched) |
| `update_postimage` | Row after update | UPDATE, MERGE (matched) |
| `delete` | Row was deleted | DELETE, MERGE (matched delete) |

### **Examples:**
```python
# Example 1: Enable CDF on table
spark.sql("""
    ALTER TABLE customers
    SET TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')
""")

# Example 2: Read all changes since version 5
changes = spark.read.format("delta") \
    .option("readChangeFeed", "true") \
    .option("startingVersion", 5) \
    .table("customers")

changes.select("customer_id", "name", "_change_type",
               "_commit_version", "_commit_timestamp").show()

# Example 3: Read changes by timestamp range
changes = spark.read.format("delta") \
    .option("readChangeFeed", "true") \
    .option("startingTimestamp", "2024-02-07") \
    .option("endingTimestamp", "2024-02-08") \
    .table("customers")

# Example 4: Stream changes (incremental downstream)
spark.readStream.format("delta") \
    .option("readChangeFeed", "true") \
    .option("startingVersion", 0) \
    .table("customers") \
    .writeStream \
    .format("delta") \
    .option("checkpointLocation", "/checkpoints/cdf_downstream") \
    .start("/delta/customers_changelog")

# Example 5: Process only updates (filter by change type)
updates_only = changes.filter("_change_type = 'update_postimage'")
deletes_only = changes.filter("_change_type = 'delete'")
inserts_only = changes.filter("_change_type = 'insert'")

# Example 6: Propagate changes to downstream table
def propagate_changes(batch_df, batch_id):
    target = DeltaTable.forPath(spark, "/delta/downstream")

    deletes = batch_df.filter("_change_type = 'delete'")
    upserts = batch_df.filter("_change_type IN ('insert', 'update_postimage')")

    if deletes.count() > 0:
        target.alias("t").merge(
            deletes.alias("s"), "t.id = s.id"
        ).whenMatchedDelete().execute()

    if upserts.count() > 0:
        target.alias("t").merge(
            upserts.alias("s"), "t.id = s.id"
        ).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Reading CDF before enabling it
spark.read.format("delta").option("readChangeFeed", "true") \
    .option("startingVersion", 0).table("events")
# Error: CDF not enabled — only versions AFTER enabling are tracked

# ✅ CORRECT: Enable CDF first, then changes are tracked going forward
spark.sql("ALTER TABLE events SET TBLPROPERTIES ('delta.enableChangeDataFeed'='true')")
# Now perform operations...
# Then read CDF starting from the version AFTER enable

# ❌ WRONG: Using CDF metadata columns in downstream writes
changes.write.format("delta").mode("append").save("/delta/downstream")
# Writes _change_type, _commit_version, _commit_timestamp as regular columns!

# ✅ CORRECT: Drop CDF metadata columns before writing
changes.drop("_change_type", "_commit_version", "_commit_timestamp") \
    .write.format("delta").mode("append").save("/delta/downstream")
```

---

## **PROBLEM TYPE 9: Deletion Vectors & Update Patterns**

### **Trigger Words:**
```
"deletion vectors", "fast delete", "write amplification",
"avoid file rewrite", "DV", "update without rewriting",
"MERGE performance", "delete performance"
```

### **Key Pattern:**
```python
# Template: Enable Deletion Vectors
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.enableDeletionVectors' = 'true'
    )
""")
# Then DELETE/UPDATE/MERGE automatically use DVs — no code change!
```

### **DV Impact Matrix:**

| Operation | Without DVs (CoW) | With DVs | Improvement |
|-----------|-------------------|----------|-------------|
| DELETE 100 rows / 10 GB table | Rewrite all touched files | Write 100-byte bitmap | ~1000x less I/O |
| UPDATE 1K rows | Rewrite files + new file | DV + small new file | ~100x less I/O |
| MERGE (1% match rate) | Rewrite all target files | DV for matched + append | ~50x less I/O |
| Full table scan | Normal | ~5% overhead (DV check) | Slightly slower reads |

### **Examples:**
```python
# Example 1: Enable DVs
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.enableDeletionVectors' = 'true'
    )
""")
# Requires: minReaderVersion=3, minWriterVersion=7

# Example 2: Delete with DVs (same syntax, faster execution)
spark.sql("DELETE FROM events WHERE user_id = 'user_to_forget'")
# Creates small bitmap instead of rewriting entire files

# Example 3: Update with DVs
spark.sql("UPDATE events SET status = 'processed' WHERE event_id = 'evt_123'")
# Old row marked in DV, new row in small file

# Example 4: MERGE with DVs
delta_table.alias("t").merge(
    source.alias("s"), "t.id = s.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
# Matched updates use DVs internally — much less I/O

# Example 5: Compact DVs periodically (materialize deletions)
spark.sql("OPTIMIZE events")
# OPTIMIZE rewrites files with accumulated DVs
# Resets DV overhead for reads

# Example 6: Check table properties for DV status
spark.sql("SHOW TBLPROPERTIES events").show(truncate=False)
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Enabling DVs on tables read by old Delta clients
# DVs require minReaderVersion=3 — old clients can't read!

# ✅ CORRECT: Verify all consumers support reader version 3
spark.sql("DESCRIBE DETAIL events").select(
    "minReaderVersion", "minWriterVersion"
).show()

# ❌ WRONG: Never running OPTIMIZE after enabling DVs
# DVs accumulate → read overhead increases
# Each file may have large DV bitmap to check

# ✅ CORRECT: Schedule periodic OPTIMIZE to compact DVs
spark.sql("OPTIMIZE events")
# Materializes deletions, resets DV overhead
```

---

## **PROBLEM TYPE 10: CHECK Constraints & Data Quality**

### **Trigger Words:**
```
"data quality", "validation", "constraint", "check constraint",
"enforce rules", "NOT NULL", "valid values", "prevent bad data",
"data contract", "invariant"
```

### **Key Pattern:**
```python
# Template: Add CHECK constraint
spark.sql("""
    ALTER TABLE orders
    ADD CONSTRAINT valid_amount CHECK (amount > 0)
""")
# Any write violating this constraint FAILS immediately
```

### **Constraint Types:**

| Constraint | Syntax | Enforcement |
|-----------|--------|-------------|
| CHECK | `ADD CONSTRAINT name CHECK (expr)` | Rejects writes that violate |
| NOT NULL | `ALTER COLUMN col SET NOT NULL` | Rejects NULL values |
| Generated column | `GENERATED ALWAYS AS (expr)` | Auto-computes value |
| Identity column | `GENERATED ALWAYS AS IDENTITY` | Auto-increment |

### **Examples:**
```python
# Example 1: Basic CHECK constraints
spark.sql("ALTER TABLE orders ADD CONSTRAINT pos_amount CHECK (amount > 0)")
spark.sql("ALTER TABLE orders ADD CONSTRAINT valid_status CHECK (status IN ('new','shipped','delivered'))")

# Example 2: Cross-column constraint
spark.sql("""
    ALTER TABLE orders ADD CONSTRAINT valid_dates
    CHECK (ship_date >= order_date)
""")

# Example 3: NOT NULL constraints
spark.sql("ALTER TABLE customers ALTER COLUMN customer_id SET NOT NULL")
spark.sql("ALTER TABLE customers ALTER COLUMN email SET NOT NULL")

# Example 4: Generated columns (auto-computed)
spark.sql("""
    CREATE TABLE events (
        event_id        STRING NOT NULL,
        event_timestamp TIMESTAMP,
        event_date      DATE GENERATED ALWAYS AS (CAST(event_timestamp AS DATE)),
        user_id         STRING
    ) USING DELTA
    PARTITIONED BY (event_date)
""")
# event_date auto-populated from event_timestamp

# Example 5: Identity column (auto-increment)
spark.sql("""
    CREATE TABLE dim_customer (
        sk      BIGINT GENERATED ALWAYS AS IDENTITY,
        id      STRING NOT NULL,
        name    STRING,
        email   STRING
    ) USING DELTA
""")
# sk: 1, 2, 3, ... (auto-generated surrogate key)

# Example 6: View constraints
spark.sql("SHOW TBLPROPERTIES orders").show(truncate=False)
# Constraints show as delta.constraints.valid_amount = "amount > 0"

# Example 7: Drop constraint
spark.sql("ALTER TABLE orders DROP CONSTRAINT valid_amount")

# Example 8: Combination — full data quality setup
spark.sql("""
    CREATE TABLE transactions (
        txn_id          STRING          NOT NULL,
        account_id      STRING          NOT NULL,
        amount          DECIMAL(15,2),
        txn_type        STRING,
        txn_timestamp   TIMESTAMP,
        txn_date        DATE GENERATED ALWAYS AS (CAST(txn_timestamp AS DATE))
    ) USING DELTA
    CLUSTER BY (account_id, txn_date)
""")
spark.sql("ALTER TABLE transactions ADD CONSTRAINT pos_amount CHECK (amount > 0)")
spark.sql("ALTER TABLE transactions ADD CONSTRAINT valid_type CHECK (txn_type IN ('credit','debit','transfer'))")
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Adding CHECK constraint to table with violating data
spark.sql("ALTER TABLE orders ADD CONSTRAINT pos_amount CHECK (amount > 0)")
# If existing rows have amount <= 0, the ALTER succeeds but
# FUTURE writes are checked — existing data is NOT validated

# ✅ CORRECT: Clean existing data before adding constraint
spark.sql("DELETE FROM orders WHERE amount <= 0")
spark.sql("ALTER TABLE orders ADD CONSTRAINT pos_amount CHECK (amount > 0)")

# ❌ WRONG: Expecting CHECK constraints to validate across tables
# CHECK only sees the current row being written

# ✅ CORRECT: Use foreachBatch or application-level validation for
# cross-table rules (e.g., foreign key checks)
```

---

## **PROBLEM TYPE 11: Clone Operations (SHALLOW / DEEP)**

### **Trigger Words:**
```
"clone table", "copy table", "test environment", "staging copy",
"backup", "shallow clone", "deep clone", "sandbox", "A/B testing",
"zero-copy", "snapshot"
```

### **Key Pattern:**
```python
# Template: SHALLOW CLONE (instant, zero-copy)
spark.sql("CREATE TABLE test_copy SHALLOW CLONE production_table")

# Template: DEEP CLONE (full independent copy)
spark.sql("CREATE TABLE backup DEEP CLONE production_table")
```

### **Clone Choice Matrix:**

| Need | Use | Time | Storage Cost |
|------|-----|------|-------------|
| Dev/test sandbox | SHALLOW | Instant | Zero |
| A/B testing | SHALLOW | Instant | Zero |
| Disaster recovery | DEEP | Proportional to size | Full copy |
| Schema migration | DEEP | Proportional to size | Full copy |
| Cross-region replica | DEEP | Proportional to size | Full copy |
| Point-in-time audit | DEEP + VERSION | Proportional to size | Full copy |

### **Examples:**
```python
# Example 1: SHALLOW CLONE for testing
spark.sql("CREATE TABLE events_test SHALLOW CLONE events")
# Instant — no data files copied
# Changes to events_test don't affect events

# Example 2: DEEP CLONE for backup
spark.sql("CREATE TABLE events_backup DEEP CLONE events")
# Full copy — independent of source

# Example 3: Clone specific version
spark.sql("CREATE TABLE events_audit DEEP CLONE events VERSION AS OF 100")

# Example 4: Clone to specific location
spark.sql("""
    CREATE TABLE events_staging
    SHALLOW CLONE events
    LOCATION '/delta/staging/events'
""")

# Example 5: A/B testing workflow
spark.sql("CREATE TABLE pricing_test SHALLOW CLONE pricing")
spark.sql("UPDATE pricing_test SET discount = 0.20 WHERE tier = 'premium'")
# Run A/B test against pricing_test...
# If test passes: apply to production
# If test fails: DROP TABLE pricing_test (zero cleanup cost)

# Example 6: Schema migration with deep clone
spark.sql("CREATE TABLE users_v2 DEEP CLONE users")
spark.sql("ALTER TABLE users_v2 ADD COLUMN (phone STRING)")
spark.sql("ALTER TABLE users_v2 DROP COLUMN legacy_field")
# Validate, then swap
spark.sql("ALTER TABLE users RENAME TO users_backup")
spark.sql("ALTER TABLE users_v2 RENAME TO users")

# Example 7: Incremental sync (re-clone only copies changes)
spark.sql("CREATE OR REPLACE TABLE backup DEEP CLONE production_table")
# Only new files are copied — not a full re-copy
```

### **Common Pitfalls:**
```python
# ❌ WRONG: VACUUMing source table while shallow clone exists
spark.sql("CREATE TABLE test SHALLOW CLONE production")
spark.sql("VACUUM production RETAIN 0 HOURS")
# Shallow clone references source's data files!
# VACUUM deletes them → clone reads break!

# ✅ CORRECT: Keep VACUUM retention >= shallow clone lifetime
# Or use DEEP CLONE if source will be vacuumed

# ❌ WRONG: Assuming SHALLOW CLONE is a backup
# It shares data files — not independent!

# ✅ CORRECT: Use DEEP CLONE for actual backups
spark.sql("CREATE TABLE backup DEEP CLONE production")
```

---

## **PROBLEM TYPE 12: Performance Tuning & Data Skipping**

### **Trigger Words:**
```
"slow query", "full table scan", "data skipping", "bloom filter",
"partition pruning", "file statistics", "predicate pushdown",
"point lookup", "UUID lookup", "performance", "scan too many files"
```

### **Key Pattern:**
```python
# Template: Check data skipping effectiveness
spark.sql("DESCRIBE DETAIL table_name").show()

# Template: Bloom filter for high-cardinality lookups
spark.sql("""
    CREATE BLOOMFILTER INDEX ON TABLE events
    FOR COLUMNS (event_id OPTIONS (fpp=0.01, numItems=10000000))
""")
```

### **Data Skipping Mechanism Matrix:**

| Mechanism | Works For | Skips By | Best For |
|-----------|----------|----------|----------|
| Partition pruning | Partition columns | Directory | Low-cardinality grouping (date, region) |
| Min/max stats | Any column (first 32) | File | Range queries, sorted data |
| Z-ORDER / Liquid Cluster | Non-partition cols | File | Multi-column filter queries |
| Bloom filter | High-cardinality cols | File | Point lookups (UUID, event_id) |
| Deletion Vectors | Deleted rows | Row | Avoiding stale row reads |

### **Examples:**
```python
# Example 1: Verify partition pruning
spark.sql("EXPLAIN SELECT * FROM events WHERE date = '2024-02-08'")
# Look for: PartitionFilters: [date = 2024-02-08]

# Example 2: Check file-level data skipping stats
delta_table = DeltaTable.forPath(spark, "/delta/events")
detail = spark.sql("DESCRIBE DETAIL events")
detail.select("numFiles", "sizeInBytes").show()

# Example 3: Create Bloom filter for UUID lookups
spark.sql("""
    CREATE BLOOMFILTER INDEX ON TABLE events
    FOR COLUMNS (
        event_id OPTIONS (fpp=0.01, numItems=50000000),
        user_id OPTIONS (fpp=0.01, numItems=5000000)
    )
""")
# Now these queries skip 99% of files:
spark.sql("SELECT * FROM events WHERE event_id = 'evt_abc123'")
spark.sql("SELECT * FROM events WHERE user_id IN ('u1', 'u2', 'u3')")

# Example 4: Optimize file sizes (target 128 MB - 1 GB)
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.targetFileSize' = '134217728'
    )
""")
# 128 MB = 134,217,728 bytes (good default)

# Example 5: Tune data skipping indexed columns
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.dataSkippingNumIndexedCols' = '32'
    )
""")
# Default 32 — increase if important filter columns are beyond position 32

# Example 6: Auto-optimize for write-heavy tables
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.autoOptimize.optimizeWrite' = 'true',
        'delta.autoOptimize.autoCompact' = 'true'
    )
""")
# optimizeWrite: coalesces small partitions within each write
# autoCompact: triggers compaction after writes when needed

# Example 7: Idempotent writes (prevent duplicate data on retry)
df.write.format("delta").mode("append") \
    .option("txnAppId", "daily_etl") \
    .option("txnVersion", "20240208") \
    .save("/delta/events")
# If retried with same txnAppId+txnVersion → write is skipped

# Example 8: Full performance tuning checklist
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.enableDeletionVectors' = 'true',
        'delta.autoOptimize.optimizeWrite' = 'true',
        'delta.autoOptimize.autoCompact' = 'true',
        'delta.targetFileSize' = '134217728',
        'delta.dataSkippingNumIndexedCols' = '32',
        'delta.columnMapping.mode' = 'name'
    )
""")
spark.sql("ALTER TABLE events CLUSTER BY (user_id, event_date)")
```

### **Common Pitfalls:**
```python
# ❌ WRONG: Bloom filter on low-cardinality column
spark.sql("CREATE BLOOMFILTER INDEX ON TABLE events FOR COLUMNS (status)")
# status has ~5 values → min/max stats already work perfectly

# ✅ CORRECT: Bloom filter on high-cardinality column (UUIDs)
spark.sql("CREATE BLOOMFILTER INDEX ON TABLE events FOR COLUMNS (event_id)")

# ❌ WRONG: Bloom filter for range queries
# Bloom filters only work for EQUALITY checks (=, IN)
# They do NOT help: WHERE amount > 100, WHERE date BETWEEN ...

# ❌ WRONG: Over-partitioning (too many small partitions)
df.write.format("delta").partitionBy("user_id").save(path)
# Millions of partitions → millions of tiny files → slow!

# ✅ CORRECT: Partition by low-cardinality (date) or use Liquid Clustering
df.write.format("delta").partitionBy("date").save(path)
# Or better: use CLUSTER BY instead
```

---

## **QUICK DECISION TREE**

```
What Delta Lake operation do I need?
│
├── Creating/Converting a table?
│   ├── New table → CREATE TABLE ... USING DELTA (or CLUSTER BY)
│   ├── From DataFrame → df.write.format("delta").save(path)
│   └── Migrate Parquet → CONVERT TO DELTA
│
├── Writing data?
│   ├── Append only → .mode("append")
│   ├── Insert/Update → MERGE (upsert)
│   ├── Full overwrite → .mode("overwrite")
│   ├── Partition overwrite → partitionOverwriteMode="dynamic"
│   └── Exactly-once → .option("txnAppId","job").option("txnVersion","v1")
│
├── Reading data?
│   ├── Current version → spark.read.format("delta").load(path)
│   ├── Past version → .option("versionAsOf", N)
│   ├── Past timestamp → .option("timestampAsOf", "2024-02-08")
│   ├── What changed → .option("readChangeFeed", "true")
│   └── Stream → spark.readStream.format("delta").load(path)
│
├── Fixing bad data?
│   ├── Undo last write → RESTORE TABLE t TO VERSION AS OF N
│   ├── Delete bad rows → DELETE FROM t WHERE condition
│   ├── Update values → UPDATE t SET col = val WHERE condition
│   └── Complex fix → MERGE (upsert with conditions)
│
├── Optimizing performance?
│   ├── Small files → OPTIMIZE
│   ├── Slow filtered queries → ZORDER BY or CLUSTER BY
│   ├── UUID point lookups → BLOOMFILTER INDEX
│   ├── Slow deletes/updates → enable Deletion Vectors
│   └── Storage bloat → VACUUM
│
├── Schema changes?
│   ├── Add column → ALTER TABLE ADD COLUMN or mergeSchema
│   ├── Rename column → enable column mapping + ALTER TABLE RENAME COLUMN
│   ├── Drop column → enable column mapping + ALTER TABLE DROP COLUMN
│   └── Replace schema → overwriteSchema (destructive)
│
├── Testing / Backup?
│   ├── Dev/test copy → SHALLOW CLONE
│   ├── Backup → DEEP CLONE
│   └── Point-in-time snapshot → DEEP CLONE VERSION AS OF N
│
└── Data quality?
    ├── Hard invariants → CHECK constraints
    ├── NOT NULL → ALTER COLUMN SET NOT NULL
    ├── Auto-compute values → Generated columns
    └── Auto-increment keys → Identity columns
```

---

## **ESSENTIAL TABLE PROPERTIES REFERENCE**

```
┌──────────────────────────────────────────────────────────────────────┐
│                 DELTA LAKE TABLE PROPERTIES REFERENCE                 │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ CORE:                                                                │
│   delta.columnMapping.mode = 'name'        Enable rename/drop cols   │
│   delta.enableDeletionVectors = 'true'     Fast DELETE/UPDATE/MERGE  │
│   delta.enableChangeDataFeed = 'true'      Track row-level changes   │
│                                                                      │
│ OPTIMIZATION:                                                        │
│   delta.autoOptimize.optimizeWrite = 'true'  Coalesce small writes   │
│   delta.autoOptimize.autoCompact = 'true'    Auto-compact after write│
│   delta.targetFileSize = '134217728'         Target file size (128MB)│
│   delta.dataSkippingNumIndexedCols = '32'    Cols with min/max stats │
│                                                                      │
│ RETENTION:                                                           │
│   delta.deletedFileRetentionDuration = 'interval 7 days'            │
│   delta.logRetentionDuration = 'interval 30 days'                    │
│                                                                      │
│ PROTOCOL:                                                            │
│   delta.minReaderVersion = '3'     (for DVs, Liquid Clustering)      │
│   delta.minWriterVersion = '7'     (for DVs, Liquid Clustering)      │
│                                                                      │
│ CROSS-FORMAT:                                                        │
│   delta.universalFormat.enabledFormats = 'iceberg'   UniForm         │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## **COMMON GOTCHAS & SOLUTIONS**

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| MERGE with duplicate source keys | "Multiple source rows matched" error | Deduplicate source before MERGE |
| Time travel after VACUUM | `FileNotFoundException` | Keep retention >= time travel window |
| Schema mismatch on append | `AnalysisException: schema mismatch` | Use `mergeSchema=true` or fix source |
| Streaming fails after UPDATE on source | `UnsupportedOperationException` | Set `ignoreChanges=true` on readStream |
| Slow MERGE on unpartitioned table | Full table scan in MERGE | Add partition column to merge condition |
| VACUUM breaks shallow clone | `FileNotFoundException` on clone | Use DEEP CLONE or don't vacuum source |
| Column rename fails | "column mapping required" error | Enable `delta.columnMapping.mode=name` |
| Protocol upgrade blocks old clients | Old clients can't read/write | Coordinate upgrade across all consumers |
| Z-ORDER on partition column | No improvement | Z-ORDER non-partition filter columns |
| Over-partitioning | Millions of tiny files | Use Liquid Clustering instead |
| Missing checkpoint in streaming | Data reprocessed on restart | Always set `checkpointLocation` |
| CDF metadata in downstream writes | Extra columns in target | Drop `_change_type`, `_commit_version`, `_commit_timestamp` |

---

## **INTERVIEW PATTERN RECOGNITION**

| When you hear... | Think... | Key API |
|-----------------|----------|---------|
| "upsert" / "merge" / "CDC" | MERGE pattern | `delta_table.merge().whenMatched...` |
| "rollback" / "undo" / "restore" | Time Travel | `RESTORE TABLE TO VERSION AS OF N` |
| "small files" / "slow reads" | Compaction | `OPTIMIZE` + `ZORDER BY` or `CLUSTER BY` |
| "storage costs" / "cleanup" | VACUUM | `VACUUM table RETAIN N HOURS` |
| "schema changed" / "new column" | Schema Evolution | `mergeSchema=true` or `ALTER TABLE` |
| "streaming" / "real-time" | Structured Streaming | `readStream` / `writeStream` + checkpoint |
| "what changed" / "audit" | Change Data Feed | `readChangeFeed=true` + CDF columns |
| "fast delete" / "write amplification" | Deletion Vectors | `enableDeletionVectors=true` |
| "data quality" / "validation" | CHECK Constraints | `ADD CONSTRAINT name CHECK (expr)` |
| "test environment" / "copy table" | CLONE | `SHALLOW CLONE` (dev) / `DEEP CLONE` (backup) |
| "rename column" / "drop column" | Column Mapping | `columnMapping.mode=name` first |
| "exactly-once" / "idempotent" | txnAppId | `.option("txnAppId","id").option("txnVersion","v")` |
| "Iceberg" / "multi-engine" | UniForm / comparison | `universalFormat.enabledFormats=iceberg` |
| "point lookup" / "UUID search" | Bloom Filter | `CREATE BLOOMFILTER INDEX ON TABLE ...` |
| "SCD Type 2" / "history" | MERGE + insert new version | Close old row + insert new (see MERGE patterns) |
| "concurrent writes" / "S3" | Multi-cluster | `S3DynamoDBLogStore` for external locking |

---

## **PRINTABLE QUICK REFERENCE CARD**

```
┌──────────────────────────────────────────────────────────────────────┐
│                  DELTA LAKE CHEAT SHEET — TOP 20 COMMANDS            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. CREATE TABLE t (...) USING DELTA CLUSTER BY (c1, c2)             │
│  2. df.write.format("delta").mode("append").save(path)               │
│  3. df.write.format("delta").option("mergeSchema","true").save(path) │
│  4. spark.read.format("delta").option("versionAsOf",N).load(path)    │
│  5. delta_table.merge(src, cond).whenMatchedUpdateAll()              │
│         .whenNotMatchedInsertAll().execute()                         │
│  6. OPTIMIZE table_name                                              │
│  7. OPTIMIZE table_name ZORDER BY (col1, col2)                       │
│  8. VACUUM table_name RETAIN 168 HOURS                               │
│  9. DESCRIBE HISTORY table_name                                      │
│ 10. RESTORE TABLE t TO VERSION AS OF N                               │
│ 11. ALTER TABLE t CLUSTER BY (col1, col2)                            │
│ 12. ALTER TABLE t ADD CONSTRAINT ck CHECK (amount > 0)               │
│ 13. ALTER TABLE t SET TBLPROPERTIES('delta.enableDeletionVectors'    │
│     = 'true')                                                        │
│ 14. ALTER TABLE t SET TBLPROPERTIES('delta.enableChangeDataFeed'     │
│     = 'true')                                                        │
│ 15. ALTER TABLE t SET TBLPROPERTIES('delta.columnMapping.mode'       │
│     = 'name')                                                        │
│ 16. ALTER TABLE t RENAME COLUMN old TO new                           │
│ 17. CREATE TABLE copy SHALLOW CLONE source                           │
│ 18. CREATE TABLE backup DEEP CLONE source VERSION AS OF N            │
│ 19. spark.readStream.format("delta").option("readChangeFeed",        │
│     "true").table("t")                                               │
│ 20. df.write.option("txnAppId","j").option("txnVersion","v")        │
│     .format("delta").save(path)                                      │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│  NEW TABLE CHECKLIST:                                                │
│  □ USING DELTA                                                       │
│  □ CLUSTER BY (top 2-4 filter columns)                               │
│  □ delta.columnMapping.mode = 'name'                                 │
│  □ delta.enableDeletionVectors = 'true'                              │
│  □ CHECK constraints for key invariants                              │
│  □ NOT NULL on required columns                                      │
│  □ Generated columns for partition derivation                        │
│  □ delta.enableChangeDataFeed = 'true' (if downstream CDC needed)    │
├──────────────────────────────────────────────────────────────────────┤
│  MAINTENANCE SCHEDULE:                                               │
│  Daily:   OPTIMIZE (if streaming or frequent small writes)           │
│  Weekly:  OPTIMIZE + ZORDER (batch tables)                           │
│  Monthly: VACUUM RETAIN 720 HOURS (30 days)                          │
│  As needed: DESCRIBE HISTORY, DESCRIBE DETAIL (monitoring)           │
└──────────────────────────────────────────────────────────────────────┘
```

**Master these Delta Lake patterns and you'll be ready for any lakehouse interview!**
