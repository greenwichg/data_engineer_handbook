# AWS/Data Engineering Interview Questions & Answers
## Complete Guide Based on Data Ingestion Project

---

## Table of Contents
1. [General Guidance Questions](#general-guidance-questions)
2. [Introduction](#introduction)
3. [Core Technical Questions](#core-technical-questions)
4. [Additional Technical Topics](#additional-technical-topics)
5. [Production Issues & Troubleshooting](#production-issues--troubleshooting)
6. [Project Architecture](#project-architecture)

---

## General Guidance Questions

### 1. Where did you use partitions and how did it help for better data analytics?

**In my project, I used partitions in multiple places:**

#### a) S3 Data Organization (Year/Month/Day partitioning):
```
ingestion/
├── data/
│   ├── archive/YYYY/MM/
│   ├── unprocessed/YYYY/MM/
│   └── logs/YYYY/MM/DD/
```

**Benefits:**
- **Reduced scan time**: When querying last 2 years of archived files, S3 Select or Athena only scans relevant partitions instead of entire bucket
- **Cost optimization**: Lifecycle policies can be applied at partition level
- **Easier data lifecycle management**: Delete old partitions without scanning entire bucket
- **Performance improvement**: 80% reduction in query time for date-filtered queries

**Implementation in my code:**
```python
# Archive with year/month partitioning
year = datetime.now().strftime('%Y')
month = datetime.now().strftime('%m')
s3_archive_path = f"s3://{bucket}/data/archive/{year}/{month}/{filename}_{timestamp}.csv"

# Logs with year/month/day partitioning
log_path = f"logs/{datetime.now(timezone.utc).strftime('%Y/%m/%d')}"
```

#### b) Spark DataFrame Partitioning:
```python
# Current implementation - coalesce for single file
df.coalesce(1).write.mode("overwrite").csv(s3_staging_path)

# For large datasets, would partition by business attributes
df.repartition(200, "date_column") \
  .write \
  .partitionBy("year", "month", "region") \
  .parquet(path)
```

**Benefits:**
- **Parallel processing**: 200 partitions = 200 parallel tasks
- **Predicate pushdown**: Filter on partition columns doesn't require reading data
- **Smaller file management**: Each partition is separate, easier to manage

#### c) Redshift Table Design:
```sql
-- Distribution and Sort Keys
CREATE TABLE transactions (
    transaction_id BIGINT,
    customer_id BIGINT,
    transaction_date DATE,
    amount DECIMAL(10,2)
)
DISTKEY(customer_id)  -- Co-locate related data
SORTKEY(transaction_date);  -- Speed up range queries
```

**Performance Impact:**
- **Before partitioning**: Query on 2023 data scanned entire 5-year dataset (500GB) - took 5 minutes
- **After partitioning**: Query only scanned 2023 partition (100GB) - took 45 seconds
- **Cost savings**: 80% reduction in data scanned = 80% lower Athena query costs

---

### 2. How would you detect malformed data and how would you get rid of it for data analytics?

**My comprehensive approach:**

#### a) Schema Enforcement at Read Time:
```python
def read_csv_with_validation(source_file, spark, log):
    """Read CSV with malformed record handling"""
    
    # Option 1: Drop malformed records
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .option("mode", "DROPMALFORMED") \
        .option("columnNameOfCorruptRecord", "_corrupt_record") \
        .csv(source_file)
    
    # Option 2: Permissive mode - capture for analysis
    df_permissive = spark.read \
        .option("mode", "PERMISSIVE") \
        .option("columnNameOfCorruptRecord", "_corrupt_record") \
        .csv(source_file)
    
    # Separate good vs bad data
    good_data = df_permissive.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
    bad_data = df_permissive.filter(col("_corrupt_record").isNotNull())
    
    # Quarantine bad records
    if bad_data.count() > 0:
        quarantine_path = f"s3://{bucket}/data/quarantine/{run_id}/"
        bad_data.write.mode("overwrite").csv(quarantine_path)
        log.warning(f"Quarantined {bad_data.count()} malformed records to {quarantine_path}")
    
    return good_data
```

#### b) Comprehensive Data Quality Validation:
```python
def validate_data_quality(df, config, log):
    """Implement comprehensive DQ checks"""
    
    total_records = df.count()
    failed_records = []
    
    # 1. Check for null values in mandatory columns
    upsert_keys = config['upsert_keys']
    for key in upsert_keys:
        null_count = df.filter(col(key).isNull()).count()
        if null_count > 0:
            log.error(f"Found {null_count} null values in key column: {key}")
            failed_records.append(df.filter(col(key).isNull()))
    
    # 2. Data type validation
    malformed = df.filter(
        # Invalid email format
        (~col("email").rlike("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$")) |
        
        # Non-numeric in numeric fields
        (col("amount").cast("double").isNull() & col("amount").isNotNull()) |
        
        # Invalid date format
        (to_date(col("date"), "yyyy-MM-dd").isNull() & col("date").isNotNull())
    )
    
    # 3. Business rule validation
    business_violations = df.filter(
        (col("amount") < 0) |  # Negative amounts
        (col("quantity") > 10000) |  # Unrealistic quantities
        (col("transaction_date") > current_date()) |  # Future dates
        (col("age") < 0) | (col("age") > 150)  # Invalid age
    )
    
    # 4. Referential integrity (if applicable)
    # Check if foreign keys exist in reference table
    
    # Combine all malformed records
    all_malformed = malformed.union(business_violations)
    malformed_count = all_malformed.count()
    
    if malformed_count > 0:
        # Quarantine path with timestamp
        quarantine_path = f"s3://{config['src_bucket']}/data/quarantine/{run_id}/"
        
        # Write with details about failure reason
        all_malformed.withColumn("failure_reason", lit("validation_failed")) \
                     .withColumn("quarantine_timestamp", current_timestamp()) \
                     .write.mode("overwrite").parquet(quarantine_path)
        
        log.warning(f"Quarantined {malformed_count} malformed records")
        
        # Alert if threshold exceeded
        failure_rate = (malformed_count / total_records) * 100
        if failure_rate > 5:  # More than 5% failure
            raise Exception(f"Data quality failure rate {failure_rate:.2f}% exceeds threshold")
    
    # Return clean data
    clean_data = df.subtract(all_malformed)
    log.info(f"Clean records: {clean_data.count()} out of {total_records}")
    
    return clean_data
```

#### c) Already Implemented in My Code:
```python
def check_datatype_matching(redshift_df, df, log):
    """Prevents type mismatches between source and target"""
    
    redshift_cols = {field.name: field.dataType for field in redshift_df.schema.fields}
    
    non_numeric_types = (StringType, BooleanType, BinaryType, DateType, TimestampType)
    numeric_types = (ByteType, ShortType, IntegerType, LongType, FloatType, DoubleType, DecimalType)
    
    for field in df.schema.fields:
        if field.name in redshift_cols:
            src_type = type(field.dataType)
            tgt_type = type(redshift_cols[field.name])
            
            # Check if source is non-numeric but target is numeric
            if issubclass(src_type, non_numeric_types) and issubclass(tgt_type, numeric_types):
                non_null_count = df.select(count(field.name)).collect()[0][0]
                if non_null_count != 0:
                    raise Exception(
                        f"Datatype mismatch for column '{field.name}': "
                        f"source={src_type.__name__}, target={tgt_type.__name__}"
                    )
```

#### d) Automated DQ Framework:
```python
def automated_dq_checks(df, config, log):
    """Production-grade automated data quality framework"""
    
    dq_rules = {
        'null_percentage': {
            'columns': config.get('mandatory_columns', []),
            'threshold': 0  # 0% nulls allowed
        },
        'duplicate_percentage': {
            'keys': config['upsert_keys'],
            'threshold': 0.01  # Max 1% duplicates
        },
        'referential_integrity': {
            'foreign_keys': [('customer_id', 'customers', 'id')],
            'threshold': 0  # All FKs must exist
        },
        'value_ranges': {
            'amount': {'min': 0, 'max': 1000000},
            'age': {'min': 0, 'max': 150},
            'quantity': {'min': 1, 'max': 10000}
        },
        'anomaly_detection': {
            'numeric_columns': ['amount', 'quantity'],
            'std_dev_threshold': 3  # Flag outliers beyond 3 std devs
        }
    }
    
    dq_report = {}
    clean_df = df
    
    # Execute each rule
    for rule_name, rule_config in dq_rules.items():
        result = execute_dq_rule(clean_df, rule_name, rule_config, log)
        dq_report[rule_name] = result
        
        if not result['passed']:
            # Remove failed records
            clean_df = result['clean_data']
    
    # Store DQ report
    store_dq_report(dq_report, config)
    
    return clean_df
```

#### e) What Happens if Correct Records are Dropped?

**Risk Mitigation Strategy:**
```python
def safe_malformed_handling(df, config, log):
    """Prevent accidental loss of good records"""
    
    # 1. Use PERMISSIVE mode instead of DROPMALFORMED
    # This captures malformed records for review, not automatic deletion
    
    # 2. Human-in-the-loop for edge cases
    quarantine_df = get_quarantined_records()
    
    if quarantine_df.count() > 0:
        # Send sample to data steward for review
        sample = quarantine_df.limit(100).toPandas()
        send_email_with_sample(sample, "Please review quarantined records")
    
    # 3. Implement rescue column
    df_with_rescue = df.withColumn("_rescue", 
                                    to_json(struct(*[col(c) for c in df.columns])))
    
    # If validation fails, preserve original in rescue column
    
    # 4. Audit trail
    log.info(f"Original count: {df.count()}")
    log.info(f"After validation: {clean_df.count()}")
    log.info(f"Dropped: {df.count() - clean_df.count()}")
    
    # 5. Configurable strictness
    if config.get('strict_mode', False):
        # Fail job if any records dropped
        if df.count() != clean_df.count():
            raise Exception("Records were dropped in strict mode")
    else:
        # Allow some loss but alert
        loss_pct = ((df.count() - clean_df.count()) / df.count()) * 100
        if loss_pct > 1:  # Alert if >1% lost
            send_alert(f"Warning: {loss_pct:.2f}% of records dropped")
    
    return clean_df
```

---

### 3. Large dataset in S3 - Query last 2 years frequently, older data occasionally. Reduce cost + improve performance?

**My Comprehensive Solution:**

#### a) S3 Storage Tiering Strategy (Cost Optimization):
```python
# Implement intelligent lifecycle policy
lifecycle_policy = {
    "Rules": [
        {
            "Id": "Hot-Warm-Cold-Archive",
            "Status": "Enabled",
            "Filter": {"Prefix": "data/"},
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"  # Infrequent Access (54% cheaper)
                },
                {
                    "Days": 730,  # 2 years
                    "StorageClass": "GLACIER_IR"  # Instant Retrieval (68% cheaper)
                },
                {
                    "Days": 1095,  # 3 years
                    "StorageClass": "DEEP_ARCHIVE"  # 95% cheaper, 12-hour retrieval
                }
            ],
            "NoncurrentVersionTransitions": [
                {
                    "NoncurrentDays": 90,
                    "StorageClass": "GLACIER"
                }
            ]
        }
    ]
}

# Apply lifecycle policy
s3.put_bucket_lifecycle_configuration(
    Bucket=bucket_name,
    LifecycleConfiguration=lifecycle_policy
)
```

**Cost Breakdown:**
- **S3 Standard** (0-30 days): $0.023/GB/month → Recent data
- **S3 Standard-IA** (30-730 days): $0.0125/GB/month → Recent analytics
- **Glacier Instant Retrieval** (2-3 years): $0.004/GB/month → Occasional queries (millisecond access)
- **Glacier Deep Archive** (3+ years): $0.00099/GB/month → Compliance/rare access

**Example Savings:**
- 1 TB dataset, 5 years retention
- Year 1: $23/month (Standard)
- Year 2: $12.50/month (Standard-IA)
- Year 3-5: $4/month (Glacier IR)
- **Total: $285/year vs $1,380 all-Standard = 79% savings**

#### b) Partition Strategy (Performance):
```python
# Hierarchical partitioning
partition_structure = """
s3://bucket/data/
├── year=2025/
│   ├── month=01/
│   │   ├── region=US/
│   │   └── region=EU/
│   └── month=02/
├── year=2024/
└── year=2023/
"""

# Write data with partitioning
df.write \
  .partitionBy("year", "month", "region") \
  .mode("append") \
  .parquet("s3://bucket/data/")

# Query automatically prunes partitions
spark.sql("""
    SELECT * FROM sales
    WHERE year >= 2023 AND month >= 6
""")
# Only scans: 2023/06-12, 2024/01-12, 2025/01 partitions
```

**Performance Impact:**
- **Without partitioning**: Scans 5 TB for 2-year query → 5 minutes
- **With partitioning**: Scans 2 TB (only 2023-2025 partitions) → 1.5 minutes
- **70% reduction in scan time and cost**

#### c) Hot/Cold Data Architecture:
```python
# Architecture design
"""
┌─────────────────────────────────────────────┐
│         HOT TIER (Last 2 years)             │
│                                             │
│  Redshift Cluster                           │
│  - Fast queries (<1 second)                 │
│  - Fully indexed                            │
│  - High compute capacity                    │
│  - Data: 2023-01-01 to present              │
└─────────────────────────────────────────────┘
                    ↑
                    │ Federated Query
                    ↓
┌─────────────────────────────────────────────┐
│        WARM TIER (2-3 years old)            │
│                                             │
│  Redshift Spectrum / Athena                 │
│  - External tables on S3                    │
│  - Glacier Instant Retrieval                │
│  - Query time: 5-30 seconds                 │
│  - Data: 2020-2022                          │
└─────────────────────────────────────────────┘
                    ↑
                    │ Restore on demand
                    ↓
┌─────────────────────────────────────────────┐
│        COLD TIER (3+ years old)             │
│                                             │
│  Glacier Deep Archive                       │
│  - Restore time: 12 hours                   │
│  - Lowest cost                              │
│  - Data: <2020                              │
└─────────────────────────────────────────────┘
"""

# Implementation
# 1. Hot tier - Load to Redshift
recent_data = df.filter(col("year") >= 2023)
recent_data.write \
    .format("io.github.spark_redshift_community.spark.redshift") \
    .option("url", redshift_url) \
    .option("dbtable", "sales_hot") \
    .option("tempdir", "s3://bucket/temp/") \
    .mode("append") \
    .save()

# 2. Warm tier - External table in Redshift Spectrum
spark.sql("""
    CREATE EXTERNAL SCHEMA spectrum
    FROM DATA CATALOG 
    DATABASE 'warm_data'
    IAM_ROLE 'arn:aws:iam::account:role/RedshiftSpectrumRole'
    REGION 'us-east-1';
""")

spark.sql("""
    CREATE EXTERNAL TABLE spectrum.sales_warm (
        transaction_id BIGINT,
        customer_id BIGINT,
        amount DECIMAL(10,2),
        transaction_date DATE
    )
    PARTITIONED BY (year INT, month INT)
    STORED AS PARQUET
    LOCATION 's3://bucket/data/warm/';
""")

# 3. Unified query across hot and warm
query = """
    -- Query combines hot (Redshift) + warm (Spectrum)
    SELECT customer_id, SUM(amount) as total_spend
    FROM (
        SELECT * FROM sales_hot WHERE year >= 2023
        UNION ALL
        SELECT * FROM spectrum.sales_warm WHERE year BETWEEN 2020 AND 2022
    )
    GROUP BY customer_id
    ORDER BY total_spend DESC
    LIMIT 100;
"""
```

#### d) Query Optimization with Athena:
```python
# Create Athena table with partition projection
athena_ddl = """
    CREATE EXTERNAL TABLE sales_data (
        transaction_id BIGINT,
        customer_id BIGINT,
        amount DECIMAL(10,2)
    )
    PARTITIONED BY (
        year INT,
        month INT,
        day INT
    )
    STORED AS PARQUET
    LOCATION 's3://bucket/data/'
    TBLPROPERTIES (
        'projection.enabled' = 'true',
        'projection.year.type' = 'integer',
        'projection.year.range' = '2020,2025',
        'projection.month.type' = 'integer',
        'projection.month.range' = '1,12',
        'projection.day.type' = 'integer',
        'projection.day.range' = '1,31',
        'storage.location.template' = 's3://bucket/data/year=${year}/month=${month}/day=${day}'
    );
"""

# Query only last 2 years (automatic partition pruning)
query = """
    SELECT * FROM sales_data
    WHERE year >= 2023  -- Only scans 2023-2025 partitions
    AND month >= 6;
"""
```

**Athena Cost Savings:**
- **Before**: Scanning 5 TB → $25/query
- **After**: Scanning 2 TB → $10/query (60% savings)

#### e) Intelligent Caching Layer:
```python
# Use S3 Select for hot data subsets
def query_recent_data_efficiently():
    """Query only necessary columns from recent partitions"""
    
    s3 = boto3.client('s3')
    
    # S3 Select - push down filter to S3, only return needed data
    response = s3.select_object_content(
        Bucket='my-bucket',
        Key='data/year=2024/month=12/data.parquet',
        ExpressionType='SQL',
        Expression="""
            SELECT customer_id, amount, transaction_date 
            FROM S3Object 
            WHERE amount > 1000
        """,
        InputSerialization={'Parquet': {}},
        OutputSerialization={'JSON': {}}
    )
    
    # Process streamed results
    for event in response['Payload']:
        if 'Records' in event:
            records = event['Records']['Payload'].decode('utf-8')
            process(records)

# ElastiCache for frequently accessed aggregations
def cache_hot_aggregations():
    """Cache common queries in Redis"""
    
    redis_client = redis.Redis(host='elasticache-endpoint')
    
    # Check cache first
    cache_key = "sales_summary_2024"
    cached = redis_client.get(cache_key)
    
    if cached:
        return json.loads(cached)
    
    # Query and cache
    result = spark.sql("SELECT * FROM sales WHERE year = 2024")
    redis_client.setex(cache_key, 3600, result.toJSON())  # 1 hour TTL
    
    return result
```

#### f) Complete Solution Summary:

**Architecture:**
```
Query Pattern: Last 2 years frequent, older occasional

┌──────────────────────────────────────────────────────────┐
│  APPLICATION LAYER                                       │
│  - Redshift for hot data (sub-second)                    │
│  - Spectrum/Athena for warm data (5-30 sec)              │
│  - On-demand restore for cold data (12 hours)            │
└──────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────┐
│  STORAGE OPTIMIZATION                                    │
│  - S3 Standard: 0-30 days                                │
│  - S3 Standard-IA: 30 days - 2 years                     │
│  - Glacier IR: 2-3 years (instant access)                │
│  - Glacier Deep: 3+ years (compliance)                   │
└──────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────┐
│  PERFORMANCE OPTIMIZATION                                │
│  - Partitioning: year/month/day/region                   │
│  - File format: Parquet with Snappy compression          │
│  - Partition projection for Athena                       │
│  - Columnar storage for analytical queries               │
└──────────────────────────────────────────────────────────┘
```

**Results:**
- **Cost**: 79% reduction ($285/year vs $1,380/year for 1TB)
- **Performance**: 70% faster queries on recent data (partitioning + hot tier)
- **Flexibility**: Can still access old data when needed (12-hour restore)

---

## Introduction

### Are you certified in AWS?

**Answer Option 1 (If Certified):**
"Yes, I hold the **AWS Certified Solutions Architect - Associate** certification, which I obtained in [month/year]. I'm currently preparing for the **AWS Certified Data Analytics - Specialty** certification to deepen my expertise in AWS data services like Glue, EMR, Redshift, Athena, and Kinesis. 

In my current role, I actively use services covered in these certifications including S3 lifecycle management, Glue ETL jobs, Redshift data warehousing, IAM security, and CloudWatch monitoring."

**Answer Option 2 (If Not Certified):**
"I don't have formal AWS certifications yet, but I have **extensive hands-on production experience** with AWS data services including:
- **AWS Glue** for ETL orchestration
- **Amazon Redshift** for data warehousing
- **S3** for data lake storage with lifecycle policies
- **CloudWatch** for logging and monitoring
- **Secrets Manager** for credential management
- **IAM** for security and access control

I'm planning to pursue the **AWS Certified Data Analytics - Specialty** certification in Q2 2026 to formalize my knowledge. I learn best through practical application, and my current project has given me deep experience with the AWS data ecosystem."

**Follow-up Points:**
- Mention specific AWS features you've implemented (in my case: S3 versioning, Glue job retry logic, Redshift Data API)
- Show continuous learning through AWS documentation, re:Invent sessions, or AWS blogs
- Demonstrate understanding of AWS best practices (cost optimization, security, performance)

---

## Core Technical Questions

### 1. Critical HIVE/Spark Query Taking Long to Run - How to Fix?

**My Troubleshooting Approach:**

#### Step 1: Identify the Bottleneck
```python
# Check Spark UI (http://<driver>:4040)
"""
Key Metrics to Check:
1. Stages tab → Which stage is slowest?
2. Tasks distribution → Is one task taking 10x longer? (Data skew indicator)
3. Storage tab → Cached RDDs consuming too much memory?
4. Executors tab → Are executors idle or failing?
5. SQL tab → DAG visualization for expensive operations
"""

# Check logs for specific errors
def analyze_spark_logs():
    """Common patterns to look for"""
    patterns = {
        'OutOfMemoryError': 'Increase executor memory or optimize transformations',
        'shuffle read': 'Large shuffle indicates join/groupBy issues',
        'GC time': 'High GC time means memory pressure',
        'task serialization': 'Closures too large, broadcasting variables'
    }
```

#### Step 2: Common Fixes I've Implemented

##### a) Data Skew - Salting for Skewed Joins
```python
def handle_skewed_join(large_df, small_df, join_key, num_salts=10):
    """
    Scenario: Joining on customer_id where 80% of transactions 
    belong to top 5 customers (skewed distribution)
    """
    
    # Add random salt to large skewed table
    large_df_salted = large_df.withColumn(
        "salt",
        (rand() * num_salts).cast("int")
    )
    
    # Replicate small table with all salt values
    small_df_exploded = small_df.withColumn(
        "salt",
        explode(array([lit(i) for i in range(num_salts)]))
    )
    
    # Join on both key and salt
    result = large_df_salted.join(
        small_df_exploded,
        [join_key, "salt"]
    ).drop("salt")
    
    return result

# Performance improvement: 10 min → 2 min (5x faster)
```

##### b) Broadcast Join for Small Tables
```python
from pyspark.sql.functions import broadcast

# Before: Sort-merge join taking 5 minutes
result = large_df.join(small_df, "key")

# After: Broadcast join taking 30 seconds
result = large_df.join(broadcast(small_df), "key")

# Rule: Use broadcast when one side < 10MB (configurable)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10485760)  # 10MB
```

##### c) Optimize File Format
```python
# Problem: Reading 100 CSV files (10GB) taking 3 minutes

# Solution 1: Convert to Parquet
df.write.mode("overwrite") \
    .option("compression", "snappy") \
    .parquet("s3://bucket/data/parquet/")

# Read time reduced: 3 min → 30 seconds (6x faster)
# Storage reduced: 10GB → 2GB (5x compression)

# Solution 2: Coalesce small files
df.repartition(10).write.parquet(path)  # Create 10 files instead of 100
```

##### d) Partition Optimization
```python
# Problem: GroupBy on 200 partitions too many for small dataset

# Check current partitions
print(f"Current partitions: {df.rdd.getNumPartitions()}")  # 200

# Solution: Adjust shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", "50")  # Reduce overhead

# For large datasets
spark.conf.set("spark.sql.shuffle.partitions", "400")  # Increase parallelism

# Dynamic: Use Adaptive Query Execution (AQE)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
```

##### e) Cache Intermediate Results
```python
# Problem: Reading same base table 3 times in complex query

# Solution: Cache after expensive operations
df_base = spark.read.parquet("s3://bucket/large_table/")
df_filtered = df_base.filter(col("year") >= 2023)

# Cache before multiple uses
df_filtered.cache()  # Or .persist(StorageLevel.MEMORY_AND_DISK)

# Use multiple times without re-reading
daily_agg = df_filtered.groupBy("date").sum("amount")
monthly_agg = df_filtered.groupBy("month").sum("amount")
customer_agg = df_filtered.groupBy("customer_id").sum("amount")

# Don't forget to unpersist when done
df_filtered.unpersist()
```

##### f) Optimize Transformations
```python
# Bad: Multiple passes over data
df = df.filter(col("amount") > 0)
df = df.filter(col("status") == "ACTIVE")
df = df.withColumn("new_col1", col("a") + col("b"))
df = df.withColumn("new_col2", col("c") * col("d"))

# Good: Single pass with multiple operations
df = df.filter(
    (col("amount") > 0) & (col("status") == "ACTIVE")
).withColumn("new_col1", col("a") + col("b")) \
 .withColumn("new_col2", col("c") * col("d"))

# Better: Use select for multiple columns
df = df.filter(
    (col("amount") > 0) & (col("status") == "ACTIVE")
).select(
    "*",
    (col("a") + col("b")).alias("new_col1"),
    (col("c") * col("d")).alias("new_col2")
)
```

#### Step 3: Configuration Tuning
```python
# Memory optimization
spark.conf.set("spark.executor.memory", "8g")
spark.conf.set("spark.driver.memory", "4g")
spark.conf.set("spark.memory.fraction", "0.8")  # 80% for execution/storage

# Parallelism tuning
spark.conf.set("spark.default.parallelism", "200")
spark.conf.set("spark.sql.shuffle.partitions", "200")

# Enable Adaptive Query Execution (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")

# Broadcast threshold
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "10485760")  # 10MB

# Serialization (faster than Java)
spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
```

#### Step 4: Query Rewrite
```python
# Inefficient: Multiple aggregations
df.groupBy("customer_id").agg(sum("amount").alias("total"))
df.groupBy("customer_id").agg(avg("amount").alias("average"))
df.groupBy("customer_id").agg(count("*").alias("count"))

# Efficient: Single aggregation
df.groupBy("customer_id").agg(
    sum("amount").alias("total"),
    avg("amount").alias("average"),
    count("*").alias("count")
)

# Inefficient: Reading full table for count
total_count = df.count()
filtered_count = df.filter(col("status") == "ACTIVE").count()

# Efficient: Single pass
counts = df.groupBy().agg(
    count("*").alias("total"),
    sum(when(col("status") == "ACTIVE", 1).otherwise(0)).alias("active_count")
).collect()[0]
```

**Real Project Example:**
```python
# Problem: HIVE query taking 45 minutes
# Original query (simplified):
SELECT customer_id, SUM(amount) 
FROM transactions 
WHERE year = 2024
GROUP BY customer_id

# Issues identified:
# 1. Data skew on customer_id (top 10 customers = 60% of data)
# 2. No partitioning by year (scanning all years)
# 3. Using ORC format (suboptimal for Spark)

# Solution applied:
# 1. Partition by year
# 2. Convert to Parquet
# 3. Apply salting for skewed customers

# Result: 45 min → 5 min (9x improvement)
```

---

### 2. CSV File with Malformed Line Error - How to Fix?

**My Implementation:**

#### Option 1: Drop Malformed Records (Production Default)
```python
def read_csv_drop_malformed(source_file, spark, log):
    """Safe mode - drop and quarantine bad records"""
    
    df = spark.read \
        .option("header", "true") \
        .option("inferSchema", "true") \
        .option("mode", "DROPMALFORMED") \
        .csv(source_file)
    
    log.info(f"Loaded {df.count()} valid records (malformed dropped)")
    return df
```

#### Option 2: Capture Malformed Records (Debugging Mode)
```python
def read_csv_capture_malformed(source_file, spark, log, run_id):
    """Permissive mode - capture for analysis"""
    
    # Add corrupt record column
    df = spark.read \
        .option("header", "true") \
        .option("mode", "PERMISSIVE") \
        .option("columnNameOfCorruptRecord", "_corrupt_record") \
        .csv(source_file)
    
    # Separate good vs bad
    good_data = df.filter(col("_corrupt_record").isNull()).drop("_corrupt_record")
    bad_data = df.filter(col("_corrupt_record").isNotNull())
    
    bad_count = bad_data.count()
    
    if bad_count > 0:
        # Quarantine for investigation
        quarantine_path = f"s3://{bucket}/data/quarantine/{run_id}/"
        bad_data.write.mode("overwrite") \
                      .option("header", "true") \
                      .csv(quarantine_path)
        
        log.warning(f"Quarantined {bad_count} malformed records to {quarantine_path}")
        
        # Sample for debugging
        bad_sample = bad_data.limit(10).collect()
        for row in bad_sample:
            log.error(f"Malformed record: {row._corrupt_record}")
    
    log.info(f"Loaded {good_data.count()} valid records")
    return good_data
```

#### Option 3: Enforce Schema (Strictest)
```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType

def read_csv_with_schema(source_file, spark, log):
    """Enforce expected schema - fail on mismatch"""
    
    # Define expected schema
    schema = StructType([
        StructField("customer_id", IntegerType(), False),
        StructField("name", StringType(), False),
        StructField("email", StringType(), True),
        StructField("amount", DoubleType(), False),
        StructField("transaction_date", StringType(), False)
    ])
    
    try:
        df = spark.read \
            .option("header", "true") \
            .option("mode", "FAILFAST") \
            .schema(schema) \
            .csv(source_file)
        
        return df
        
    except Exception as e:
        log.error(f"Schema mismatch or malformed data: {str(e)}")
        # Fall back to permissive mode for diagnosis
        return read_csv_capture_malformed(source_file, spark, log, run_id)
```

#### Root Cause Analysis
```python
def diagnose_malformed_data(bad_data, log):
    """Analyze patterns in malformed records"""
    
    # Sample corrupted records
    samples = bad_data.select("_corrupt_record").limit(100).collect()
    
    issues = {
        'extra_columns': 0,
        'missing_columns': 0,
        'quote_issues': 0,
        'delimiter_issues': 0,
        'encoding_issues': 0
    }
    
    for row in samples:
        corrupt_line = row._corrupt_record
        
        # Check for extra columns
        if corrupt_line.count(',') > expected_columns:
            issues['extra_columns'] += 1
        
        # Check for missing columns
        elif corrupt_line.count(',') < expected_columns:
            issues['missing_columns'] += 1
        
        # Check for unescaped quotes
        if corrupt_line.count('"') % 2 != 0:
            issues['quote_issues'] += 1
        
        # Check for non-UTF8 characters
        try:
            corrupt_line.encode('utf-8')
        except UnicodeEncodeError:
            issues['encoding_issues'] += 1
    
    log.info("Malformed data analysis:", **issues)
    return issues
```

#### Production Implementation in My Code
```python
# Enhanced version of my read_csv_file function
def read_csv_file_enhanced(config: dict, spark, log, run_id):
    try:
        source_file = f"s3://{config['src_bucket']}/data/in/{config['source_file_name']}"
        
        # Try strict read first
        df = spark.read \
            .option("header", "true") \
            .option("inferSchema", "true") \
            .option("mode", "DROPMALFORMED") \
            .option("columnNameOfCorruptRecord", "_corrupt_record") \
            .csv(source_file)
        
        # Normalize column names (already in my code)
        for old in df.columns:
            new = _clean_colname(old)
            if old != new:
                df = df.withColumnRenamed(old, new)
        
        # Add metadata
        run_ts = datetime.now(timezone.utc)
        df = df.withColumn("run_date", lit(run_ts.strftime("%Y-%m-%d %H:%M:%S")).cast(TimestampType())) \
               .withColumn("file_name", lit(source_file.split("/")[-1]))
        
        return df
        
    except Exception as e:
        log.error(f"Failed to read CSV: {str(e)}")
        # Attempt recovery with permissive mode
        return read_csv_capture_malformed(source_file, spark, log, run_id)
```

---

### 4. Huge File DQ Check - Sampling Won't Give 100%. Suggest Alternative?

**My Comprehensive Approaches:**

#### Option 1: Distributed Full Scan with Spark (Best for Accuracy)
```python
def comprehensive_dq_check_full_scan(df, config, log):
    """
    Full scan using distributed processing
    Best for: Files up to 100GB
    Time: 5-10 minutes for 50GB file
    """
    
    total_records = df.count()
    log.info(f"Starting full DQ scan on {total_records} records")
    
    # Define all validation rules
    validation_results = {}
    
    # 1. Null checks (single pass)
    null_counts = df.select([
        sum(when(col(c).isNull(), 1).otherwise(0)).alias(c)
        for c in config.get('mandatory_columns', [])
    ]).collect()[0].asDict()
    
    validation_results['null_checks'] = null_counts
    
    # 2. Data type validation (single pass)
    type_errors = df.filter(
        (col("email").rlike("^[^@]+@[^@]+$") == False) |
        (col("amount").cast("double").isNull() & col("amount").isNotNull()) |
        (col("age").cast("int").isNull() & col("age").isNotNull())
    ).count()
    
    validation_results['type_errors'] = type_errors
    
    # 3. Business rule validation (single pass)
    business_errors = df.filter(
        (col("amount") < 0) |
        (col("quantity") > 10000) |
        (col("transaction_date") > current_date())
    ).count()
    
    validation_results['business_errors'] = business_errors
    
    # 4. Duplicate check
    duplicate_count = df.count() - df.dropDuplicates(config['upsert_keys']).count()
    validation_results['duplicates'] = duplicate_count
    
    # 5. Referential integrity (if applicable)
    # Load reference tables and check foreign keys
    
    # Total failed records
    total_failed = type_errors + business_errors + duplicate_count
    failure_rate = (total_failed / total_records) * 100
    
    log.info(f"DQ Check Complete: {failure_rate:.2f}% failure rate", **validation_results)
    
    # Fail job if threshold exceeded
    if failure_rate > config.get('max_failure_rate', 5.0):
        raise Exception(f"DQ failure rate {failure_rate:.2f}% exceeds threshold")
    
    return validation_results
```

#### Option 2: Incremental/Chunk Processing (Best for Very Large Files)
```python
def incremental_dq_check(file_path, chunk_size_mb=500, spark, log):
    """
    Process file in chunks
    Best for: Files > 100GB
    Time: Linear with file size, but memory-efficient
    """
    
    # Get file size
    s3 = boto3.client('s3')
    bucket, key = file_path.replace("s3://", "").split("/", 1)
    file_size_mb = s3.head_object(Bucket=bucket, Key=key)['ContentLength'] / (1024**2)
    
    num_chunks = int(file_size_mb / chunk_size_mb) + 1
    log.info(f"Processing {file_size_mb:.2f}MB file in {num_chunks} chunks")
    
    # Process each chunk
    aggregated_results = {
        'total_records': 0,
        'null_errors': 0,
        'type_errors': 0,
        'business_errors': 0
    }
    
    for chunk_id in range(num_chunks):
        # Read chunk
        chunk_df = spark.read \
            .option("header", "true") \
            .option("maxFilesPerTrigger", 1) \
            .csv(file_path)
        
        # Validate chunk
        chunk_results = validate_chunk(chunk_df, config, log)
        
        # Aggregate results
        for key in aggregated_results:
            aggregated_results[key] += chunk_results[key]
        
        log.info(f"Chunk {chunk_id+1}/{num_chunks} processed")
    
    # Final report
    failure_rate = (
        (aggregated_results['null_errors'] + 
         aggregated_results['type_errors'] + 
         aggregated_results['business_errors']) / 
        aggregated_results['total_records']
    ) * 100
    
    log.info(f"Full file DQ check complete: {failure_rate:.2f}% failure rate")
    
    return aggregated_results
```

#### Option 3: Two-Pass Strategy (Efficient Compromise)
```python
def two_pass_dq_check(df, config, log):
    """
    Pass 1: Quick statistical checks
    Pass 2: Detailed validation on suspicious records only
    
    Best for: 50-500GB files
    Time: 2x faster than full scan, near 100% accuracy
    """
    
    # PASS 1: Statistical profile (FAST)
    log.info("Pass 1: Statistical profiling")
    
    stats = df.select([
        count("*").alias("total_count"),
        countDistinct(*config['upsert_keys']).alias("unique_keys"),
        *[sum(when(col(c).isNull(), 1).otherwise(0)).alias(f"{c}_nulls") 
          for c in config.get('mandatory_columns', [])],
        *[min(col(c)).alias(f"{c}_min") for c in config.get('numeric_columns', [])],
        *[max(col(c)).alias(f"{c}_max") for c in config.get('numeric_columns', [])],
        *[avg(col(c)).alias(f"{c}_avg") for c in config.get('numeric_columns', [])]
    ]).collect()[0].asDict()
    
    # Identify potential issues from stats
    suspicious_patterns = []
    
    if stats['total_count'] != stats['unique_keys']:
        suspicious_patterns.append('duplicates')
    
    for col in config.get('mandatory_columns', []):
        if stats.get(f'{col}_nulls', 0) > 0:
            suspicious_patterns.append(f'nulls_in_{col}')
    
    # PASS 2: Detailed validation on identified issues only
    log.info(f"Pass 2: Validating {len(suspicious_patterns)} suspicious patterns")
    
    detailed_errors = {}
    
    if 'duplicates' in suspicious_patterns:
        # Check duplicates in detail
        duplicates = df.groupBy(*config['upsert_keys']).count() \
                       .filter(col("count") > 1)
        detailed_errors['duplicate_keys'] = duplicates.count()
    
    # Validate only records with nulls
    for pattern in suspicious_patterns:
        if pattern.startswith('nulls_in_'):
            col_name = pattern.replace('nulls_in_', '')
            null_records = df.filter(col(col_name).isNull())
            detailed_errors[pattern] = null_records.count()
    
    # Business rule validation (always run)
    business_errors = df.filter(
        (col("amount") < 0) | 
        (col("quantity") > 10000)
    ).count()
    
    detailed_errors['business_rule_violations'] = business_errors
    
    log.info("DQ Check complete", **detailed_errors)
    
    return {'stats': stats, 'errors': detailed_errors}
```

#### Option 4: AWS Glue Data Quality Rules (Managed Service)
```python
def use_glue_dq_rules(database, table, ruleset):
    """
    Use AWS Glue Data Quality for automated checks
    Scales automatically, fully managed
    """
    
    glue = boto3.client('glue')
    
    # Define DQ ruleset
    ruleset_string = """
    Rules = [
        RowCount > 1000,
        IsComplete "customer_id",
        IsComplete "email",
        IsUnique "customer_id",
        ColumnDataType "amount" in ["DOUBLE", "DECIMAL"],
        ColumnValues "amount" > 0,
        ColumnValues "age" between 0 and 150,
        ColumnLength "email" between 5 and 255,
        Completeness "email" > 0.95,
        Uniqueness "customer_id" > 0.99
    ]
    """
    
    # Create DQ ruleset
    response = glue.create_data_quality_ruleset(
        Name='sales_data_quality',
        Ruleset=ruleset_string,
        TargetTable={
            'DatabaseName': database,
            'TableName': table
        }
    )
    
    # Run DQ evaluation
    eval_response = glue.start_data_quality_rule_recommendation_run(
        DataSource={
            'GlueTable': {
                'DatabaseName': database,
                'TableName': table
            }
        }
    )
    
    # Get results
    results = glue.get_data_quality_result(
        ResultId=eval_response['RunId']
    )
    
    return results
```

#### Option 5: Hybrid - Sample + Full Scan on Failures
```python
def hybrid_dq_approach(df, config, log):
    """
    1. Quick sample validation (1%)
    2. If sample passes, assume file is good
    3. If sample fails, run full scan
    
    Best for: Variable quality files
    Time: Fast if file is good, thorough if suspicious
    """
    
    total_count = df.count()
    sample_size = max(10000, int(total_count * 0.01))  # 1% or 10K min
    
    # Stage 1: Sample validation
    log.info(f"Stage 1: Validating {sample_size} sample records")
    sample_df = df.sample(fraction=sample_size/total_count, seed=42)
    
    sample_errors = validate_records(sample_df, config)
    sample_failure_rate = (sample_errors / sample_size) * 100
    
    log.info(f"Sample failure rate: {sample_failure_rate:.2f}%")
    
    # Decision point
    if sample_failure_rate < 1.0:  # Less than 1% errors in sample
        log.info("Sample passed. Assuming file is good.")
        return {'stage': 'sample', 'estimated_errors': sample_errors * (total_count / sample_size)}
    
    else:
        # Stage 2: Full scan
        log.warning("Sample showed issues. Running full scan...")
        return comprehensive_dq_check_full_scan(df, config, log)
```

#### Recommendation for Production

**My approach in the project would be:**

```python
def production_dq_strategy(df, config, log):
    """
    Adaptive strategy based on file size and history
    """
    
    file_size_gb = df.count() * avg_row_size_bytes / (1024**3)
    
    # Small files (< 10GB): Full scan always
    if file_size_gb < 10:
        return comprehensive_dq_check_full_scan(df, config, log)
    
    # Medium files (10-100GB): Two-pass
    elif file_size_gb < 100:
        return two_pass_dq_check(df, config, log)
    
    # Large files (100GB+): Incremental
    else:
        return incremental_dq_check(file_path, chunk_size_mb=500, spark, log)
```

**Why not sampling?**
- Sampling misses rare but critical errors (e.g., 1 malformed record in 1M)
- Compliance requirements often mandate 100% validation
- Distributed processing (Spark) makes full scan feasible even for large files

---

### 7. Reading Parquet from S3 - Invalid Errors - How to Diagnose?

**My Diagnostic Approach:**

#### Step 1: Identify the Specific Error
```python
def diagnose_parquet_errors(file_path, spark, log):
    """Systematic diagnosis of Parquet read failures"""
    
    try:
        df = spark.read.parquet(file_path)
        log.info("File read successfully")
        return df
        
    except Exception as e:
        error_msg = str(e)
        log.error(f"Parquet read failed: {error_msg}")
        
        # Categorize error
        if "schema" in error_msg.lower():
            return diagnose_schema_issues(file_path, spark, log)
        
        elif "corrupt" in error_msg.lower() or "magic" in error_msg.lower():
            return diagnose_corruption(file_path, spark, log)
        
        elif "permission" in error_msg.lower() or "access denied" in error_msg.lower():
            return diagnose_permissions(file_path, log)
        
        elif "encoding" in error_msg.lower():
            return diagnose_encoding_issues(file_path, spark, log)
        
        else:
            return diagnose_general_issues(file_path, spark, log)
```

#### Step 2: Schema Evolution Issues (Most Common)
```python
def diagnose_schema_issues(file_path, spark, log):
    """Handle schema evolution and mismatches"""
    
    s3 = boto3.client('s3')
    bucket, prefix = file_path.replace("s3://", "").split("/", 1)
    
    # List all parquet files
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    parquet_files = [
        f"s3://{bucket}/{obj['Key']}" 
        for obj in response.get('Contents', []) 
        if obj['Key'].endswith('.parquet')
    ]
    
    log.info(f"Found {len(parquet_files)} parquet files")
    
    # Read schema from each file
    schemas = {}
    for i, file in enumerate(parquet_files[:10]):  # Sample first 10
        try:
            file_df = spark.read.parquet(file)
            schema_str = str(file_df.schema)
            
            if schema_str not in schemas:
                schemas[schema_str] = []
            schemas[schema_str].append(file)
            
        except Exception as e:
            log.error(f"File {file} unreadable: {str(e)}")
    
    # Report schema variations
    if len(schemas) > 1:
        log.error(f"Schema mismatch detected! Found {len(schemas)} different schemas")
        
        for idx, (schema, files) in enumerate(schemas.items()):
            log.info(f"Schema variant {idx+1} (used by {len(files)} files):")
            log.info(schema)
        
        # Solution 1: Merge schemas
        log.info("Attempting to merge schemas...")
        try:
            df = spark.read.option("mergeSchema", "true").parquet(file_path)
            log.info("Successfully merged schemas")
            return df
        except Exception as e:
            log.error(f"Schema merge failed: {str(e)}")
        
        # Solution 2: Read each schema separately and union
        log.info("Attempting to read and union different schemas...")
        dfs = []
        for schema, files in schemas.items():
            schema_df = spark.read.parquet(*files)
            dfs.append(schema_df)
        
        # Union with null filling for missing columns
        result_df = dfs[0]
        for df in dfs[1:]:
            result_df = union_with_missing_cols(result_df, df)
        
        return result_df
    
    else:
        log.info("All files have consistent schema")
        return spark.read.parquet(file_path)


def union_with_missing_cols(df1, df2):
    """Union two DataFrames with different schemas"""
    
    # Get all columns
    all_cols = set(df1.columns + df2.columns)
    
    # Add missing columns with null values
    for col_name in all_cols:
        if col_name not in df1.columns:
            df1 = df1.withColumn(col_name, lit(None))
        if col_name not in df2.columns:
            df2 = df2.withColumn(col_name, lit(None))
    
    # Ensure same column order
    df1 = df1.select(*sorted(all_cols))
    df2 = df2.select(*sorted(all_cols))
    
    return df1.union(df2)
```

#### Step 3: File Corruption Detection
```python
def diagnose_corruption(file_path, spark, log):
    """Identify and isolate corrupted Parquet files"""
    
    import pyarrow.parquet as pq
    
    s3 = boto3.client('s3')
    bucket, prefix = file_path.replace("s3://", "").split("/", 1)
    
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    parquet_files = [
        obj['Key'] 
        for obj in response.get('Contents', []) 
        if obj['Key'].endswith('.parquet')
    ]
    
    corrupted_files = []
    valid_files = []
    
    for file_key in parquet_files:
        file_path = f"s3://{bucket}/{file_key}"
        
        try:
            # Test 1: Read metadata only
            # Download file to temp location for pyarrow validation
            local_path = f"/tmp/{file_key.split('/')[-1]}"
            s3.download_file(bucket, file_key, local_path)
            
            # Validate with pyarrow
            pq.read_metadata(local_path)
            
            # Test 2: Try to read with Spark
            test_df = spark.read.parquet(file_path)
            test_df.count()  # Force read
            
            valid_files.append(file_path)
            log.info(f"✓ Valid: {file_key}")
            
        except Exception as e:
            corrupted_files.append(file_path)
            log.error(f"✗ Corrupted: {file_key} - {str(e)}")
    
    # Report
    log.info(f"Validation complete: {len(valid_files)} valid, {len(corrupted_files)} corrupted")
    
    if corrupted_files:
        # Move corrupted files to quarantine
        for corrupt_file in corrupted_files:
            quarantine_key = corrupt_file.replace("/data/", "/data/corrupted/")
            source_key = corrupt_file.replace(f"s3://{bucket}/", "")
            target_key = quarantine_key.replace(f"s3://{bucket}/", "")
            
            s3.copy_object(
                Bucket=bucket,
                CopySource={'Bucket': bucket, 'Key': source_key},
                Key=target_key
            )
            log.info(f"Moved corrupted file to {quarantine_key}")
    
    # Read only valid files
    if valid_files:
        return spark.read.parquet(*valid_files)
    else:
        raise Exception("All Parquet files are corrupted")
```

#### Step 4: Permission Issues
```python
def diagnose_permissions(file_path, log):
    """Check IAM permissions and bucket policies"""
    
    s3 = boto3.client('s3')
    sts = boto3.client('sts')
    
    bucket, key = file_path.replace("s3://", "").split("/", 1)
    
    # Check current IAM identity
    identity = sts.get_caller_identity()
    log.info(f"Current IAM identity: {identity['Arn']}")
    
    # Test bucket access
    try:
        s3.head_bucket(Bucket=bucket)
        log.info(f"✓ Bucket {bucket} is accessible")
    except Exception as e:
        log.error(f"✗ Cannot access bucket: {str(e)}")
        return
    
    # Test object access
    try:
        s3.head_object(Bucket=bucket, Key=key)
        log.info(f"✓ Object {key} exists and is accessible")
    except Exception as e:
        log.error(f"✗ Cannot access object: {str(e)}")
        log.error("Check: IAM role, bucket policy, object ACL, KMS encryption key")
        return
    
    # Check encryption
    try:
        metadata = s3.head_object(Bucket=bucket, Key=key)
        encryption = metadata.get('ServerSideEncryption', 'None')
        log.info(f"Encryption: {encryption}")
        
        if encryption == 'aws:kms':
            kms_key = metadata.get('SSEKMSKeyId')
            log.info(f"KMS Key: {kms_key}")
            log.info("Ensure Glue/EMR role has kms:Decrypt permission")
    except Exception as e:
        log.error(f"Cannot read metadata: {str(e)}")
```

#### Step 5: Encoding/Compression Issues
```python
def diagnose_encoding_issues(file_path, spark, log):
    """Handle encoding and compression problems"""
    
    # Try different read options
    read_options = [
        {},  # Default
        {"encoding": "UTF-8"},
        {"encoding": "ISO-8859-1"},
        {"compression": "snappy"},
        {"compression": "gzip"},
        {"compression": "lz4"},
    ]
    
    for idx, options in enumerate(read_options):
        try:
            log.info(f"Attempt {idx+1}: Reading with options {options}")
            df = spark.read.options(**options).parquet(file_path)
            df.count()  # Force read
            log.info(f"✓ Success with options: {options}")
            return df
        except Exception as e:
            log.warning(f"✗ Failed with {options}: {str(e)}")
    
    raise Exception("All encoding/compression attempts failed")
```

#### Step 6: General Troubleshooting Checklist
```python
def diagnose_general_issues(file_path, spark, log):
    """Comprehensive checklist"""
    
    checklist = {
        "1. File exists": check_file_exists(file_path),
        "2. File size > 0": check_file_size(file_path),
        "3. File extension": check_extension(file_path),
        "4. Parquet magic number": check_magic_number(file_path),
        "5. Readable metadata": check_metadata(file_path),
        "6. Schema consistency": check_schema_consistency(file_path),
        "7. Row group validity": check_row_groups(file_path),
        "8. Spark version compatibility": check_spark_version(),
    }
    
    for check, result in checklist.items():
        status = "✓" if result else "✗"
        log.info(f"{status} {check}: {result}")
    
    # Detailed diagnostics
    log.info("\n=== Detailed Diagnostics ===")
    
    # Check Spark configuration
    log.info("Spark Configs:")
    log.info(f"spark.sql.parquet.compression.codec: {spark.conf.get('spark.sql.parquet.compression.codec', 'snappy')}")
    log.info(f"spark.sql.parquet.mergeSchema: {spark.conf.get('spark.sql.parquet.mergeSchema', 'false')}")
    log.info(f"spark.sql.parquet.filterPushdown: {spark.conf.get('spark.sql.parquet.filterPushdown', 'true')}")
    
    # Recommendations
    log.info("\n=== Recommendations ===")
    log.info("1. Try: spark.read.option('mergeSchema', 'true').parquet(path)")
    log.info("2. Validate files with pyarrow: pq.read_metadata(file)")
    log.info("3. Check for mixed Parquet versions (v1 vs v2)")
    log.info("4. Verify network connectivity to S3")
```

#### Real-World Example from My Project
```python
# Issue encountered: "org.apache.parquet.io.ParquetDecodingException"
# Cause: Schema evolution - new column added to source

# Solution applied:
def read_parquet_with_schema_evolution(file_path, spark, log):
    """Handle schema changes gracefully"""
    
    try:
        # First attempt: Normal read
        df = spark.read.parquet(file_path)
        return df
        
    except Exception as e:
        if "schema" in str(e).lower():
            log.warning("Schema mismatch detected, enabling schema merge")
            
            # Enable schema merging
            df = spark.read \
                .option("mergeSchema", "true") \
                .parquet(file_path)
            
            log.info(f"Schema merged successfully. Columns: {df.columns}")
            return df
        else:
            raise
```

---

### 8. On-Premise to AWS Migration - Challenges & Zero Downtime?

**My Migration Strategy:**

#### Phase 1: Assessment & Planning (Week 1-2)

```python
# Migration Assessment Checklist
assessment = {
    "data_inventory": {
        "total_volume_tb": 50,
        "databases": ["Oracle", "SQL Server", "Postgres"],
        "tables": 250,
        "average_daily_growth_gb": 500,
        "peak_data_velocity": "10K records/sec"
    },
    "dependencies": {
        "upstream_systems": 15,
        "downstream_consumers": 25,
        "batch_jobs": 40,
        "real_time_pipelines": 5
    },
    "network": {
        "bandwidth_mbps": 1000,
        "latency_to_aws_ms": 20,
        "transfer_time_days": 4.6  # 50TB / 1Gbps = ~4.6 days
    },
    "compliance": {
        "data_classification": ["PHI", "PII", "Financial"],
        "retention_years": 7,
        "encryption_required": True,
        "audit_logging": True
    }
}
```

#### Phase 2: Infrastructure Setup (Week 2-3)

```python
# Setup AWS infrastructure
def setup_aws_infrastructure():
    """Provision AWS resources"""
    
    # 1. Network connectivity
    setup_direct_connect()  # or VPN for smaller migrations
    
    # 2. Data storage
    redshift_cluster = provision_redshift_cluster(
        node_type='ra3.4xlarge',
        num_nodes=4,
        encryption=True,
        kms_key='arn:aws:kms:...'
    )
    
    # 3. Data lake
    s3_buckets = create_s3_buckets([
        'raw-data',
        'processed-data',
        'archive',
        'logs',
        'metadata'
    ])
    
    # 4. ETL infrastructure
    glue_jobs = setup_glue_jobs()
    
    # 5. Security
    setup_iam_roles_and_policies()
    setup_vpc_and_security_groups()
    
    # 6. Monitoring
    setup_cloudwatch_dashboards()
    setup_alarms_and_alerts()
    
    return {
        'redshift': redshift_cluster,
        's3': s3_buckets,
        'glue': glue_jobs
    }


def setup_direct_connect():
    """Establish dedicated network connection"""
    
    # For 50TB migration, Direct Connect is essential
    # Provides: 1-10 Gbps dedicated bandwidth
    # Reduces: Transfer time from 4.6 days to hours
    # Benefits: Consistent performance, lower data transfer costs
    
    dx = boto3.client('directconnect')
    
    connection = dx.create_connection(
        location='EqDC2',  # AWS Direct Connect location
        bandwidth='10Gbps',
        connectionName='OnPrem-to-AWS'
    )
    
    # Create virtual interface
    vif = dx.create_private_virtual_interface(
        connectionId=connection['connectionId'],
        newPrivateVirtualInterface={
            'virtualInterfaceName': 'prod-migration-vif',
            'vlan': 100,
            'asn': 65000,
            'amazonAddress': '169.254.1.1/30',
            'customerAddress': '169.254.1.2/30'
        }
    )
    
    return connection, vif
```

#### Phase 3: Zero-Downtime Migration Strategy

```python
class ZeroDowntimeMigration:
    """
    Strategy: Dual-write + CDC (Change Data Capture)
    
    Timeline:
    - Week 1-2: Setup
    - Week 3-4: Initial bulk load (historical data)
    - Week 5-6: CDC sync (ongoing changes)
    - Week 7: Validation
    - Week 8: Cutover (gradual)
    """
    
    def __init__(self, source_db, target_redshift):
        self.source = source_db
        self.target = target_redshift
        self.dms_client = boto3.client('dms')
    
    def phase1_initial_bulk_load(self):
        """
        Migrate historical data without downtime
        Uses: AWS DMS (Database Migration Service)
        """
        
        # Create DMS replication instance
        replication_instance = self.dms_client.create_replication_instance(
            ReplicationInstanceIdentifier='onprem-to-redshift',
            ReplicationInstanceClass='dms.c5.4xlarge',
            AllocatedStorage=1000,
            VpcSecurityGroupIds=['sg-xxxxx'],
            MultiAZ=True,
            PubliclyAccessible=False
        )
        
        # Create source endpoint (on-premise database)
        source_endpoint = self.dms_client.create_endpoint(
            EndpointIdentifier='source-oracle',
            EndpointType='source',
            EngineName='oracle',
            ServerName='onprem-db.company.com',
            Port=1521,
            DatabaseName='PROD',
            Username='dms_user',
            Password='secure_password'
        )
        
        # Create target endpoint (Redshift)
        target_endpoint = self.dms_client.create_endpoint(
            EndpointIdentifier='target-redshift',
            EndpointType='target',
            EngineName='redshift',
            ServerName='redshift-cluster.amazonaws.com',
            Port=5439,
            DatabaseName='analytics',
            Username='admin',
            Password='redshift_password'
        )
        
        # Create replication task: Full Load + CDC
        replication_task = self.dms_client.create_replication_task(
            ReplicationTaskIdentifier='full-load-cdc',
            SourceEndpointArn=source_endpoint['Endpoint']['EndpointArn'],
            TargetEndpointArn=target_endpoint['Endpoint']['EndpointArn'],
            ReplicationInstanceArn=replication_instance['ReplicationInstance']['ReplicationInstanceArn'],
            MigrationType='full-load-and-cdc',  # Key: Continuous replication
            TableMappings=json.dumps({
                "rules": [{
                    "rule-type": "selection",
                    "rule-id": "1",
                    "rule-name": "include-all-tables",
                    "object-locator": {
                        "schema-name": "%",
                        "table-name": "%"
                    },
                    "rule-action": "include"
                }]
            }),
            ReplicationTaskSettings=json.dumps({
                "TargetMetadata": {
                    "SupportLobs": True,
                    "LobMaxSize": 32  # MB
                },
                "FullLoadSettings": {
                    "TargetTablePrepMode": "DROP_AND_CREATE",
                    "MaxFullLoadSubTasks": 8
                },
                "ChangeProcessingTuning": {
                    "BatchApplyTimeoutMin": 1,
                    "BatchApplyTimeoutMax": 30,
                    "BatchSplitSize": 0,
                    "CommitTimeout": 1,
                    "MemoryLimitTotal": 1024,
                    "MemoryKeepTime": 60,
                    "StatementCacheSize": 50
                }
            })
        )
        
        # Start task
        self.dms_client.start_replication_task(
            ReplicationTaskArn=replication_task['ReplicationTask']['ReplicationTaskArn'],
            StartReplicationTaskType='start-replication'
        )
        
        print("Phase 1: Initial bulk load started (full-load-and-cdc mode)")
        print("DMS will continuously sync changes from on-prem to AWS")
        print("On-prem database remains operational - ZERO DOWNTIME")
    
    def phase2_validation_and_reconciliation(self):
        """
        Validate data parity between on-prem and AWS
        """
        
        validation_queries = [
            {
                "name": "row_count_check",
                "source_query": "SELECT COUNT(*) FROM {table}",
                "target_query": "SELECT COUNT(*) FROM {table}"
            },
            {
                "name": "checksum_validation",
                "source_query": "SELECT SUM(CAST(amount AS DECIMAL(18,2))) FROM transactions",
                "target_query": "SELECT SUM(amount) FROM transactions"
            },
            {
                "name": "latest_timestamp",
                "source_query": "SELECT MAX(updated_at) FROM {table}",
                "target_query": "SELECT MAX(updated_at) FROM {table}"
            }
        ]
        
        results = {}
        
        for check in validation_queries:
            source_result = execute_query(self.source, check['source_query'])
            target_result = execute_query(self.target, check['target_query'])
            
            match = (source_result == target_result)
            results[check['name']] = {
                'source': source_result,
                'target': target_result,
                'match': match
            }
            
            if not match:
                print(f"❌ Validation failed: {check['name']}")
                print(f"   Source: {source_result}")
                print(f"   Target: {target_result}")
            else:
                print(f"✅ Validation passed: {check['name']}")
        
        return results
    
    def phase3_gradual_cutover(self):
        """
        Gradual traffic shift from on-prem to AWS
        Uses: Blue-Green deployment pattern
        """
        
        # Week 7: Shadow mode - Route reads to AWS, writes to on-prem
        print("Week 7: Shadow mode")
        self.route_traffic(read_pct_aws=10, write_pct_aws=0)
        self.monitor_for_days(3)
        
        # Week 7.5: Increase read traffic
        print("Week 7.5: Increasing AWS read traffic")
        self.route_traffic(read_pct_aws=50, write_pct_aws=0)
        self.monitor_for_days(2)
        
        # Week 8: Dual-write mode - Write to both systems
        print("Week 8: Dual-write mode")
        self.route_traffic(read_pct_aws=75, write_pct_aws=50)
        self.monitor_for_days(2)
        
        # Week 8.5: Full cutover
        print("Week 8.5: Full cutover to AWS")
        self.route_traffic(read_pct_aws=100, write_pct_aws=100)
        
        # Week 9: Keep on-prem as backup (30 days)
        print("Week 9+: On-prem kept as backup for 30 days")
        # Continue CDC from AWS back to on-prem for safety
        
    def route_traffic(self, read_pct_aws, write_pct_aws):
        """Application-level traffic routing"""
        
        # Update application config (e.g., via feature flags)
        config = {
            "database": {
                "read": {
                    "aws_redshift_weight": read_pct_aws,
                    "onprem_oracle_weight": 100 - read_pct_aws
                },
                "write": {
                    "aws_redshift_weight": write_pct_aws,
                    "onprem_oracle_weight": 100 - write_pct_aws
                }
            }
        }
        
        # Push to config service (e.g., AWS AppConfig, Consul)
        update_application_config(config)
        
        print(f"Traffic routing updated: {read_pct_aws}% reads, {write_pct_aws}% writes to AWS")
    
    def monitor_for_days(self, days):
        """Monitor key metrics during cutover"""
        
        metrics_to_monitor = [
            "application_error_rate",
            "database_query_latency_p99",
            "data_freshness_lag_seconds",
            "dms_replication_lag_seconds",
            "transaction_success_rate"
        ]
        
        for day in range(days):
            print(f"Day {day+1}/{days}: Monitoring...")
            
            for metric in metrics_to_monitor:
                value = get_cloudwatch_metric(metric)
                
                if is_anomaly(metric, value):
                    print(f"⚠️  Anomaly detected in {metric}: {value}")
                    # Trigger rollback if critical
                    if is_critical(metric):
                        self.rollback()
                        return False
            
            print(f"✅ Day {day+1} validation passed")
        
        return True
    
    def rollback(self):
        """Emergency rollback to on-prem"""
        
        print("🔄 INITIATING ROLLBACK TO ON-PREM")
        
        # Instantly route 100% traffic back to on-prem
        self.route_traffic(read_pct_aws=0, write_pct_aws=0)
        
        # Alert teams
        send_alert("Migration rollback executed. All traffic routed to on-prem.")
        
        # Investigate issues
        generate_incident_report()
```

#### Challenges & Solutions

```python
challenges_and_solutions = {
    "1. Network Bandwidth": {
        "challenge": "50TB transfer over internet = 4.6 days",
        "solution": "AWS Direct Connect (10Gbps) reduces to ~11 hours",
        "cost": "$0.02/GB vs $0.09/GB over internet = 78% savings"
    },
    
    "2. Schema Differences": {
        "challenge": "Oracle → Redshift incompatible data types",
        "solution": """
            - Create mapping layer in DMS
            - Oracle NUMBER → Redshift DECIMAL
            - Oracle CLOB → Redshift VARCHAR(MAX)
            - Oracle DATE → Redshift TIMESTAMP
        """,
        "code": '''
            table_mappings = {
                "rules": [{
                    "rule-type": "transformation",
                    "rule-id": "1",
                    "rule-name": "convert-number-to-decimal",
                    "object-locator": {
                        "schema-name": "%",
                        "table-name": "%",
                        "column-name": "%"
                    },
                    "rule-action": "change-data-type",
                    "data-type": {
                        "type": "decimal",
                        "precision": 38,
                        "scale": 10
                    }
                }]
            }
        '''
    },
    
    "3. Data Encryption": {
        "challenge": "PHI data requires encryption at rest and in transit",
        "solution": """
            - In transit: SSL/TLS for all connections (DMS, Direct Connect)
            - At rest: 
                - S3: SSE-KMS with customer-managed keys
                - Redshift: Cluster encryption with KMS
                - Glue: Encrypted job bookmarks
        """,
        "code": '''
            # S3 encryption
            s3.put_bucket_encryption(
                Bucket=bucket,
                ServerSideEncryptionConfiguration={
                    'Rules': [{
                        'ApplyServerSideEncryptionByDefault': {
                            'SSEAlgorithm': 'aws:kms',
                            'KMSMasterKeyID': kms_key_arn
                        }
                    }]
                }
            )
            
            # Redshift encryption
            redshift.create_cluster(
                ClusterIdentifier='prod-cluster',
                Encrypted=True,
                KmsKeyId=kms_key_arn
            )
        '''
    },
    
    "4. Compliance & Auditing": {
        "challenge": "Need audit trail for all data access/changes",
        "solution": """
            - Enable CloudTrail for all API calls
            - Redshift audit logging to S3
            - VPC Flow Logs for network monitoring
            - AWS Config for configuration compliance
        """,
        "code": '''
            # Enable Redshift audit logging
            redshift.enable_logging(
                ClusterIdentifier='prod-cluster',
                BucketName='audit-logs-bucket',
                S3KeyPrefix='redshift-logs/'
            )
            
            # CloudTrail
            cloudtrail.create_trail(
                Name='data-migration-audit',
                S3BucketName='audit-trail-bucket',
                IncludeGlobalServiceEvents=True,
                IsMultiRegionTrail=True,
                EnableLogFileValidation=True
            )
        '''
    },
    
    "5. Application Compatibility": {
        "challenge": "40 batch jobs written for Oracle SQL",
        "solution": """
            - Automated SQL translation (AWS SCT - Schema Conversion Tool)
            - Manual fixes for complex stored procedures
            - Wrapper layer for gradual migration
        """,
        "approach": "Strangler Fig Pattern - Incrementally replace components"
    },
    
    "6. Performance Degradation": {
        "challenge": "Initial queries slower on Redshift vs Oracle",
        "solution": """
            - Proper distribution keys (DISTKEY)
            - Sort keys for frequently filtered columns (SORTKEY)
            - Analyze table statistics: ANALYZE table_name
            - Vacuum to reclaim space: VACUUM table_name
        """,
        "code": '''
            CREATE TABLE transactions (
                transaction_id BIGINT,
                customer_id BIGINT,
                amount DECIMAL(10,2),
                transaction_date DATE
            )
            DISTKEY(customer_id)  -- Co-locate related data
            SORTKEY(transaction_date)  -- Speed up date range queries
            ;
            
            -- After initial load
            ANALYZE transactions;
            VACUUM FULL transactions;
        '''
    },
    
    "7. Cutover Coordination": {
        "challenge": "25 downstream systems need to switch connection strings",
        "solution": """
            - Central configuration management (AWS Systems Manager Parameter Store)
            - Feature flags for gradual rollout
            - DNS CNAME switch for instant cutover
        """,
        "code": '''
            # Store connection strings in Parameter Store
            ssm.put_parameter(
                Name='/prod/database/connection',
                Value='redshift-cluster.amazonaws.com',
                Type='SecureString',
                Overwrite=True
            )
            
            # Applications read from Parameter Store
            # Single update switches all systems
        '''
    }
}
```

#### Zero-Downtime Achievement

**Yes, zero-downtime migration is possible with:**

1. **AWS DMS full-load-and-cdc mode**
   - Initial bulk load runs in background
   - CDC captures ongoing changes
   - On-prem remains operational

2. **Dual-write period**
   - Write to both on-prem and AWS
   - Read from on-prem (for safety)
   - Validate consistency

3. **Gradual traffic shift**
   - 10% → 50% → 100% over weeks
   - Monitor each stage
   - Instant rollback capability

4. **Backup strategy**
   - Keep on-prem live for 30 days
   - Reverse CDC if needed
   - Point-in-time recovery

**Timeline:**
- Total migration: 8 weeks
- Actual downtime: **0 minutes**
- Business continuity: 100%

---

### 9. What AWS Services Are You Aware Of?

**Based on my project experience:**

#### Compute & Processing
- **AWS Glue**: Serverless ETL (used in my data ingestion project)
- **EMR (Elastic MapReduce)**: Managed Hadoop/Spark clusters for big data processing
- **Lambda**: Serverless compute for event-driven processing
- **Batch**: Managed batch computing service

#### Storage
- **S3 (Simple Storage Service)**: 
  - Object storage (data lake in my project)
  - Storage classes: Standard, IA, Glacier, Deep Archive
  - Lifecycle policies for cost optimization
  - Versioning (used for file recovery)
- **EBS**: Block storage for EC2
- **EFS**: Network file system

#### Database & Data Warehouse
- **Redshift**: 
  - Columnar data warehouse (target system in my project)
  - Redshift Spectrum for S3 queries
  - Redshift Data API (used in my code)
- **RDS**: Managed relational databases (PostgreSQL, MySQL, Oracle, SQL Server)
- **DynamoDB**: NoSQL key-value store
- **Aurora**: MySQL/PostgreSQL compatible, 5x faster
- **ElastiCache**: In-memory cache (Redis, Memcached)

#### Data Transfer & Migration
- **DMS (Database Migration Service)**: Database migration with CDC
- **DataSync**: Automated data transfer (on-prem to AWS)
- **Snowball/Snowmobile**: Petabyte-scale physical data transfer
- **Transfer Family**: Managed SFTP/FTPS

#### Analytics
- **Athena**: Serverless SQL queries on S3
- **QuickSight**: Business intelligence dashboards
- **Kinesis**: Real-time data streaming
  - Kinesis Data Streams: Real-time data ingestion
  - Kinesis Data Firehose: Load streaming data to S3/Redshift
  - Kinesis Data Analytics: Real-time analytics
- **MSK (Managed Streaming for Kafka)**: Apache Kafka service

#### Orchestration & Workflow
- **Step Functions**: Serverless workflow orchestration
- **EventBridge**: Event-driven architecture (used for S3 file triggers in my project)
- **MWAA (Managed Workflows for Apache Airflow)**: Airflow orchestration
- **Glue Workflows**: ETL workflow management

#### Monitoring & Logging
- **CloudWatch**: 
  - Logs (Glue job logs in my project)
  - Metrics and dashboards
  - Alarms and alerts
- **CloudTrail**: API call auditing
- **X-Ray**: Distributed tracing
- **Config**: Resource configuration tracking

#### Security & Identity
- **IAM (Identity and Access Management)**: 
  - Roles (used for Glue, Redshift access in my project)
  - Policies
  - Users and groups
- **Secrets Manager**: Secure credential storage (Redshift credentials in my code)
- **KMS (Key Management Service)**: Encryption key management
- **Macie**: Data privacy and security (PII detection)
- **GuardDuty**: Threat detection

#### Developer Tools
- **CodeCommit**: Git repositories
- **CodeBuild**: Build and test automation
- **CodeDeploy**: Deployment automation
- **CodePipeline**: CI/CD pipelines

#### Management & Governance
- **Systems Manager**: 
  - Parameter Store (configuration management)
  - Session Manager (secure shell access)
- **Organizations**: Multi-account management
- **Cost Explorer**: Cost analysis and optimization
- **Budgets**: Cost alerts

#### Networking
- **VPC (Virtual Private Cloud)**: Isolated network
- **Direct Connect**: Dedicated network connection
- **Route 53**: DNS service
- **CloudFront**: CDN

**My hands-on experience (from the project):**
- ✅ S3 (data lake, lifecycle policies, versioning)
- ✅ AWS Glue (ETL jobs, data catalog, crawlers)
- ✅ Redshift (data warehouse, Data API, Spectrum)
- ✅ EventBridge (S3 event triggers)
- ✅ CloudWatch (logging, monitoring)
- ✅ IAM (roles, policies)
- ✅ Secrets Manager (credential management)
- ✅ Boto3 SDK (Python AWS interactions)

---

### 10. Source File Without Business Date - Overwritten in S3 - Retrieve Old File?

**Answer: Yes, using S3 Versioning (File-level)**

#### Understanding S3 Versioning

**Is it bucket-level or file-level?**
- S3 versioning is **enabled at the bucket level**
- But **versions are tracked per file (object)**
- Each file has its own independent version history

#### Implementation

```python
# Step 1: Enable S3 Versioning (one-time setup)
def enable_s3_versioning(bucket_name):
    """Enable versioning on S3 bucket"""
    
    s3 = boto3.client('s3')
    
    # Enable versioning
    s3.put_bucket_versioning(
        Bucket=bucket_name,
        VersioningConfiguration={
            'Status': 'Enabled'
        }
    )
    
    print(f"Versioning enabled on bucket: {bucket_name}")
    print("All future uploads will be versioned")
    print("Overwriting a file will create a new version, not delete the old one")


# Step 2: List all versions of a file
def list_file_versions(bucket, key):
    """List all versions of a specific file"""
    
    s3 = boto3.client('s3')
    
    response = s3.list_object_versions(
        Bucket=bucket,
        Prefix=key
    )
    
    versions = response.get('Versions', [])
    delete_markers = response.get('DeleteMarkers', [])
    
    print(f"File: s3://{bucket}/{key}")
    print(f"Total versions: {len(versions)}")
    print(f"Delete markers: {len(delete_markers)}")
    print("\nVersion History:")
    print("-" * 80)
    
    for v in versions:
        version_id = v['VersionId']
        last_modified = v['LastModified']
        size_mb = v['Size'] / (1024**2)
        is_latest = v.get('IsLatest', False)
        
        status = "CURRENT" if is_latest else "PREVIOUS"
        
        print(f"{status:8} | {version_id:32} | {last_modified} | {size_mb:.2f} MB")
    
    return versions


# Step 3: Retrieve a specific version
def retrieve_old_version(bucket, key, version_id=None, target_date=None):
    """Retrieve old version of overwritten file"""
    
    s3 = boto3.client('s3')
    
    # Get all versions
    versions = s3.list_object_versions(Bucket=bucket, Prefix=key).get('Versions', [])
    
    if not versions:
        raise Exception(f"No versions found for {key}")
    
    # Option 1: Get specific version by ID
    if version_id:
        target_version = next((v for v in versions if v['VersionId'] == version_id), None)
        
        if not target_version:
            raise Exception(f"Version {version_id} not found")
    
    # Option 2: Get version by date
    elif target_date:
        # Find version closest to target date
        target_version = min(
            versions,
            key=lambda v: abs((v['LastModified'].date() - target_date).days)
        )
        
        print(f"Found version from {target_version['LastModified'].date()} (closest to {target_date})")
    
    # Option 3: Get previous version (before current)
    else:
        # Sort by LastModified descending
        versions_sorted = sorted(versions, key=lambda v: v['LastModified'], reverse=True)
        
        if len(versions_sorted) < 2:
            raise Exception("Only one version exists (current)")
        
        target_version = versions_sorted[1]  # Second most recent
        print(f"Retrieving previous version from {target_version['LastModified']}")
    
    # Download the version
    version_id = target_version['VersionId']
    
    response = s3.get_object(
        Bucket=bucket,
        Key=key,
        VersionId=version_id
    )
    
    # Save to local file
    local_path = f"/tmp/{key.split('/')[-1]}_{version_id}.csv"
    with open(local_path, 'wb') as f:
        f.write(response['Body'].read())
    
    print(f"Downloaded version {version_id} to {local_path}")
    
    return local_path


# Step 4: Restore old version to current
def restore_old_version_as_current(bucket, key, version_id):
    """Make an old version the current version"""
    
    s3 = boto3.client('s3')
    
    # Method 1: Copy old version to create new current version
    s3.copy_object(
        Bucket=bucket,
        CopySource={
            'Bucket': bucket,
            'Key': key,
            'VersionId': version_id
        },
        Key=key
    )
    
    print(f"Restored version {version_id} as current")
    print("Old current version is preserved as a previous version")


# Step 5: Upload old version to different location
def save_old_version_to_new_location(bucket, key, version_id, new_key):
    """Copy old version to a new S3 location"""
    
    s3 = boto3.client('s3')
    
    s3.copy_object(
        Bucket=bucket,
        CopySource={
            'Bucket': bucket,
            'Key': key,
            'VersionId': version_id
        },
        Key=new_key
    )
    
    print(f"Copied version {version_id} to s3://{bucket}/{new_key}")
```

#### Real-World Example

```python
# Scenario: Daily sales file overwrites same name
# - File: s3://my-bucket/data/in/daily_sales.csv
# - Uploaded daily at 6 AM
# - Need to retrieve yesterday's version

def retrieve_yesterdays_sales_file():
    """Retrieve yesterday's overwritten sales file"""
    
    bucket = 'my-bucket'
    key = 'data/in/daily_sales.csv'
    
    # List versions
    versions = list_file_versions(bucket, key)
    
    # Find version from yesterday
    yesterday = (datetime.now() - timedelta(days=1)).date()
    
    yesterday_version = next(
        (v for v in versions if v['LastModified'].date() == yesterday),
        None
    )
    
    if not yesterday_version:
        print(f"No version found for {yesterday}")
        return None
    
    # Retrieve it
    version_id = yesterday_version['VersionId']
    local_file = retrieve_old_version(bucket, key, version_id=version_id)
    
    # Save to archive with date in filename
    archive_key = f"data/archive/{yesterday.strftime('%Y/%m')}/daily_sales_{yesterday}.csv"
    save_old_version_to_new_location(bucket, key, version_id, archive_key)
    
    print(f"Yesterday's file archived to: s3://{bucket}/{archive_key}")
    
    return local_file
```

#### Enhanced Solution: Prevent Overwrite in My Project

```python
# Instead of relying on versioning, prevent overwrite by design
def upload_with_timestamp(config: dict, file_path: str):
    """Upload file with timestamp to prevent overwrite"""
    
    s3 = boto3.client('s3')
    
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')
    original_filename = config['source_file_name']
    base_name = original_filename.rsplit('.', 1)[0]
    extension = original_filename.rsplit('.', 1)[1]
    
    # Add timestamp to filename
    versioned_filename = f"{base_name}_{timestamp}.{extension}"
    
    year = datetime.now().strftime('%Y')
    month = datetime.now().strftime('%m')
    
    # Upload to archive with timestamp
    archive_key = f"data/archive/{year}/{month}/{versioned_filename}"
    
    s3.upload_file(
        Filename=file_path,
        Bucket=config['src_bucket'],
        Key=archive_key
    )
    
    print(f"Uploaded to: s3://{config['src_bucket']}/{archive_key}")
    print("No overwrite - each file has unique timestamp")
    
    return archive_key


# This is already implemented in my code:
s3_archive_path = f"s3://{config['src_bucket']}/data/archive/{year}/{month}/{source_filename.split('.')[0]}_{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}.csv"
```

#### Cost Considerations

```python
# S3 Versioning costs
versioning_costs = {
    "storage": "Each version is stored and billed separately",
    "example": {
        "daily_file_size_gb": 10,
        "retention_days": 365,
        "total_storage_gb": 10 * 365,  # 3,650 GB = 3.65 TB
        "cost_per_month": 3650 * 0.023,  # $83.95/month
    },
    "optimization": "Use lifecycle policy to delete old versions",
    "lifecycle_policy": {
        "delete_noncurrent_after_days": 90,  # Keep 90 days of versions
        "transition_to_glacier_after_days": 30  # Move old versions to Glacier
    }
}

# Implement lifecycle policy
def optimize_versioning_costs(bucket):
    """Reduce versioning costs with lifecycle policy"""
    
    s3 = boto3.client('s3')
    
    s3.put_bucket_lifecycle_configuration(
        Bucket=bucket,
        LifecycleConfiguration={
            'Rules': [{
                'Id': 'delete-old-versions',
                'Status': 'Enabled',
                'NoncurrentVersionTransitions': [{
                    'NoncurrentDays': 30,
                    'StorageClass': 'GLACIER'
                }],
                'NoncurrentVersionExpiration': {
                    'NoncurrentDays': 90
                }
            }]
        }
    )
    
    print("Lifecycle policy applied:")
    print("- Old versions moved to Glacier after 30 days")
    print("- Old versions deleted after 90 days")
    print("- Cost reduced by ~70%")
```

**Summary:**
- **Yes, you can retrieve overwritten files using S3 Versioning**
- **It's file-level** (tracked per object, enabled per bucket)
- **Best practice**: Combine versioning with timestamp-based filenames (as in my project)
- **Cost optimization**: Use lifecycle policies to manage version retention

---

### 13. Max Annual CTC per Department - SQL & Python

#### SQL Solution

```sql
-- Method 1: Using ROW_NUMBER() Window Function (Best Practice)
WITH ranked_salaries AS (
    SELECT 
        employee_id,
        employee_name,
        department,
        annual_ctc,
        ROW_NUMBER() OVER (
            PARTITION BY department 
            ORDER BY annual_ctc DESC
        ) AS rank
    FROM employees
)
SELECT 
    department,
    employee_id,
    employee_name,
    annual_ctc AS max_ctc
FROM ranked_salaries
WHERE rank = 1
ORDER BY department;

-- Method 2: Using RANK() (Handles ties differently)
WITH ranked_salaries AS (
    SELECT 
        employee_id,
        employee_name,
        department,
        annual_ctc,
        RANK() OVER (
            PARTITION BY department 
            ORDER BY annual_ctc DESC
        ) AS rank
    FROM employees
)
SELECT 
    department,
    employee_id,
    employee_name,
    annual_ctc AS max_ctc
FROM ranked_salaries
WHERE rank = 1
ORDER BY department;

-- Method 3: Using DENSE_RANK() (For consecutive ranks)
WITH ranked_salaries AS (
    SELECT 
        employee_id,
        employee_name,
        department,
        annual_ctc,
        DENSE_RANK() OVER (
            PARTITION BY department 
            ORDER BY annual_ctc DESC
        ) AS rank
    FROM employees
)
SELECT 
    department,
    employee_id,
    employee_name,
    annual_ctc AS max_ctc
FROM ranked_salaries
WHERE rank = 1
ORDER BY department;

-- Method 4: Using FIRST_VALUE() Window Function
SELECT DISTINCT
    department,
    FIRST_VALUE(employee_id) OVER (
        PARTITION BY department 
        ORDER BY annual_ctc DESC
    ) AS employee_id,
    FIRST_VALUE(employee_name) OVER (
        PARTITION BY department 
        ORDER BY annual_ctc DESC
    ) AS employee_name,
    FIRST_VALUE(annual_ctc) OVER (
        PARTITION BY department 
        ORDER BY annual_ctc DESC
    ) AS max_ctc
FROM employees
ORDER BY department;

-- Method 5: Simple GROUP BY with MAX (Only CTC, not employee details)
SELECT 
    department,
    MAX(annual_ctc) AS max_ctc
FROM employees
GROUP BY department
ORDER BY department;

-- Method 6: JOIN with MAX (Get employee details)
SELECT 
    e.department,
    e.employee_id,
    e.employee_name,
    e.annual_ctc AS max_ctc
FROM employees e
INNER JOIN (
    SELECT 
        department,
        MAX(annual_ctc) AS max_ctc
    FROM employees
    GROUP BY department
) max_dept
ON e.department = max_dept.department 
AND e.annual_ctc = max_dept.max_ctc
ORDER BY e.department;

-- Method 7: Correlated Subquery
SELECT 
    e1.department,
    e1.employee_id,
    e1.employee_name,
    e1.annual_ctc AS max_ctc
FROM employees e1
WHERE e1.annual_ctc = (
    SELECT MAX(e2.annual_ctc)
    FROM employees e2
    WHERE e2.department = e1.department
)
ORDER BY e1.department;
```

**Difference between ROW_NUMBER(), RANK(), and DENSE_RANK():**

```sql
-- Sample data with ties
-- Engineering: Alice ($150K), Bob ($150K), Charlie ($140K)

-- ROW_NUMBER(): Arbitrary order for ties
-- Alice: 1, Bob: 2, Charlie: 3

-- RANK(): Same rank for ties, skips next rank
-- Alice: 1, Bob: 1, Charlie: 3

-- DENSE_RANK(): Same rank for ties, no skip
-- Alice: 1, Bob: 1, Charlie: 2
```

#### Python Solution (PySpark)

```python
from pyspark.sql import SparkSession
from pyspark.sql.window import Window
from pyspark.sql.functions import (
    col, max as max_, row_number, rank, dense_rank, first
)

# Initialize Spark
spark = SparkSession.builder.appName("MaxCTC").getOrCreate()

# Sample data
data = [
    (1, "Alice", "Engineering", 150000),
    (2, "Bob", "Engineering", 150000),
    (3, "Charlie", "Engineering", 140000),
    (4, "Diana", "Sales", 120000),
    (5, "Eve", "Sales", 110000),
    (6, "Frank", "HR", 90000),
    (7, "Grace", "HR", 95000),
]

df = spark.createDataFrame(data, ["employee_id", "employee_name", "department", "annual_ctc"])

# Method 1: Using ROW_NUMBER() (Most Common)
window_spec = Window.partitionBy("department").orderBy(col("annual_ctc").desc())

result = df.withColumn("rank", row_number().over(window_spec)) \
           .filter(col("rank") == 1) \
           .select("department", "employee_id", "employee_name", "annual_ctc") \
           .orderBy("department")

result.show()
"""
+------------+-----------+-------------+----------+
|  department|employee_id|employee_name|annual_ctc|
+------------+-----------+-------------+----------+
| Engineering|          1|        Alice|    150000|
|          HR|          7|        Grace|     95000|
|       Sales|          4|        Diana|    120000|
+------------+-----------+-------------+----------+
"""

# Method 2: Using RANK() (Handles ties - returns both Alice and Bob)
result_rank = df.withColumn("rank", rank().over(window_spec)) \
                .filter(col("rank") == 1) \
                .select("department", "employee_id", "employee_name", "annual_ctc") \
                .orderBy("department")

result_rank.show()
"""
+------------+-----------+-------------+----------+
|  department|employee_id|employee_name|annual_ctc|
+------------+-----------+-------------+----------+
| Engineering|          1|        Alice|    150000|
| Engineering|          2|          Bob|    150000|  # Both returned
|          HR|          7|        Grace|     95000|
|       Sales|          4|        Diana|    120000|
+------------+-----------+-------------+----------+
"""

# Method 3: Using groupBy with agg (Only CTC, not employee details)
result_groupby = df.groupBy("department") \
                   .agg(max_("annual_ctc").alias("max_ctc")) \
                   .orderBy("department")

result_groupby.show()
"""
+------------+-------+
|  department|max_ctc|
+------------+-------+
| Engineering| 150000|
|          HR|  95000|
|       Sales| 120000|
+------------+-------+
"""

# Method 4: Join approach (Get employee details with max CTC)
max_ctc_per_dept = df.groupBy("department") \
                     .agg(max_("annual_ctc").alias("max_ctc"))

result_join = df.join(
    max_ctc_per_dept,
    (df.department == max_ctc_per_dept.department) &
    (df.annual_ctc == max_ctc_per_dept.max_ctc)
).select(
    df.department,
    df.employee_id,
    df.employee_name,
    df.annual_ctc.alias("max_ctc")
).orderBy(df.department)

result_join.show()

# Method 5: Using first() with window (Alternative)
window_first = Window.partitionBy("department").orderBy(col("annual_ctc").desc())

result_first = df.withColumn("max_ctc", first("annual_ctc").over(window_first)) \
                 .withColumn("max_employee_id", first("employee_id").over(window_first)) \
                 .withColumn("max_employee_name", first("employee_name").over(window_first)) \
                 .filter(col("annual_ctc") == col("max_ctc")) \
                 .select(
                     "department",
                     col("max_employee_id").alias("employee_id"),
                     col("max_employee_name").alias("employee_name"),
                     col("max_ctc")
                 ).dropDuplicates(["department"]) \
                 .orderBy("department")

# Method 6: Pandas-like approach (for smaller datasets)
pandas_df = df.toPandas()

result_pandas = pandas_df.loc[
    pandas_df.groupby("department")["annual_ctc"].idxmax()
][["department", "employee_id", "employee_name", "annual_ctc"]]

print(result_pandas)

# Method 7: SQL API
df.createOrReplaceTempView("employees")

result_sql = spark.sql("""
    WITH ranked AS (
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY department ORDER BY annual_ctc DESC) as rank
        FROM employees
    )
    SELECT department, employee_id, employee_name, annual_ctc as max_ctc
    FROM ranked
    WHERE rank = 1
    ORDER BY department
""")

result_sql.show()
```

#### Performance Comparison

```python
# For large datasets, compare performance

import time

def benchmark_methods(df):
    """Compare performance of different approaches"""
    
    methods = {
        "Method 1: ROW_NUMBER()": lambda: (
            df.withColumn("rank", row_number().over(window_spec))
              .filter(col("rank") == 1)
              .count()
        ),
        
        "Method 2: GroupBy + Join": lambda: (
            df.join(
                df.groupBy("department").agg(max_("annual_ctc").alias("max_ctc")),
                (df.department == df.groupBy("department").agg(max_("annual_ctc").alias("max_ctc")).department)
            ).count()
        ),
        
        "Method 3: GroupBy Only": lambda: (
            df.groupBy("department").agg(max_("annual_ctc")).count()
        )
    }
    
    results = {}
    
    for method_name, method_func in methods.items():
        start = time.time()
        method_func()
        elapsed = time.time() - start
        results[method_name] = elapsed
        print(f"{method_name}: {elapsed:.4f} seconds")
    
    return results

# Typical results for 10M records:
# Method 1 (ROW_NUMBER): 3.2 seconds
# Method 2 (GroupBy + Join): 4.1 seconds
# Method 3 (GroupBy Only): 1.8 seconds (but no employee details)
```

#### Which Method to Choose?

```python
decision_tree = """
1. Need employee details + handle ties?
   → Use ROW_NUMBER() if you want exactly one employee per department
   → Use RANK() if you want all employees with max salary (ties)

2. Only need max CTC value (no employee details)?
   → Use simple GROUP BY with MAX (fastest)

3. Very large dataset (100M+ rows)?
   → Window functions might be slow
   → Consider: GROUP BY + JOIN approach
   → Or: Partition data first, then apply window functions

4. Multiple aggregations needed?
   → Combine in single groupBy().agg() for efficiency

5. Interactive/exploratory analysis?
   → Window functions (more readable)

6. Production pipeline?
   → Benchmark and choose optimal for your data size
"""

print(decision_tree)
```

**My Recommendation:**
- **For interviews**: Use `ROW_NUMBER()` window function (shows advanced SQL knowledge)
- **For production**: Benchmark both approaches; window functions are usually faster for this use case

---

## Additional Technical Topics

### What is PHI Data and How to Handle It?

**PHI (Protected Health Information):**

PHI is any health information that can be linked to an individual, as defined by HIPAA (Health Insurance Portability and Accountability Act).

**Examples of PHI:**
- Names, dates (birth, admission, discharge, death)
- Contact information (address, phone, email)
- Social Security Number
- Medical Record Number
- Health plan beneficiary number
- Account numbers
- Certificate/license numbers
- Vehicle identifiers
- Device identifiers/serial numbers
- Biometric identifiers (fingerprints, voice prints)
- Full-face photos
- IP addresses
- Medical records, diagnoses, treatments

#### How to Handle PHI in My Project

```python
class PHIDataHandler:
    """Comprehensive PHI data protection implementation"""
    
    def __init__(self, kms_key_arn):
        self.kms_key_arn = kms_key_arn
        self.s3 = boto3.client('s3')
        self.kms = boto3.client('kms')
    
    # 1. Encryption at Rest
    def encrypt_data_at_rest(self, df, output_path):
        """Encrypt PHI data when storing in S3"""
        
        # Write with KMS encryption
        df.write.mode("overwrite") \
            .option("encryption", "SSE-KMS") \
            .option("kmsKeyId", self.kms_key_arn) \
            .parquet(output_path)
        
        print(f"Data encrypted at rest with KMS key: {self.kms_key_arn}")
    
    # 2. Encryption in Transit
    def setup_encryption_in_transit(self):
        """Ensure all connections use SSL/TLS"""
        
        # Glue connections use SSL by default
        spark.conf.set("spark.ssl.enabled", "true")
        
        # Redshift requires SSL
        redshift_conn = {
            'url': 'jdbc:redshift://cluster:5439/db?ssl=true&sslfactory=com.amazon.redshift.ssl.NonValidatingFactory',
            'sslmode': 'require'
        }
        
        return redshift_conn
    
    # 3. Data Masking
    def mask_phi_data(self, df, phi_columns):
        """Mask PHI data for non-production environments"""
        
        from pyspark.sql.functions import sha2, concat_ws, substring
        
        masked_df = df
        
        for col_name in phi_columns:
            if col_name == 'ssn':
                # Mask SSN: XXX-XX-1234
                masked_df = masked_df.withColumn(
                    col_name,
                    concat_ws("-", lit("XXX"), lit("XX"), substring(col(col_name), -4, 4))
                )
            
            elif col_name == 'email':
                # Mask email: j***@example.com
                masked_df = masked_df.withColumn(
                    col_name,
                    concat(
                        substring(col(col_name), 1, 1),
                        lit("***@"),
                        substring(col(col_name), F.instr(col(col_name), "@") + 1, 100)
                    )
                )
            
            elif col_name in ('first_name', 'last_name'):
                # Replace with hashed value
                masked_df = masked_df.withColumn(
                    col_name,
                    sha2(col(col_name), 256)
                )
            
            else:
                # Generic masking
                masked_df = masked_df.withColumn(col_name, lit("***MASKED***"))
        
        return masked_df
    
    # 4. Access Control
    def enforce_access_control(self):
        """Implement fine-grained access control"""
        
        # IAM policy for PHI data access
        phi_access_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "s3:GetObject",
                        "s3:PutObject"
                    ],
                    "Resource": "arn:aws:s3:::phi-data-bucket/*",
                    "Condition": {
                        "IpAddress": {
                            "aws:SourceIp": ["10.0.0.0/8"]  # Only from VPC
                        },
                        "StringEquals": {
                            "aws:PrincipalTag/Department": "Healthcare"
                        }
                    }
                },
                {
                    "Effect": "Allow",
                    "Action": ["kms:Decrypt", "kms:Encrypt"],
                    "Resource": self.kms_key_arn,
                    "Condition": {
                        "StringEquals": {
                            "kms:ViaService": "s3.us-east-1.amazonaws.com"
                        }
                    }
                }
            ]
        }
        
        return phi_access_policy
    
    # 5. Audit Logging
    def setup_audit_logging(self, bucket):
        """Enable comprehensive audit logging"""
        
        # S3 bucket logging
        self.s3.put_bucket_logging(
            Bucket=bucket,
            BucketLoggingStatus={
                'LoggingEnabled': {
                    'TargetBucket': f'{bucket}-access-logs',
                    'TargetPrefix': 'phi-access-logs/'
                }
            }
        )
        
        # CloudTrail for API calls
        cloudtrail = boto3.client('cloudtrail')
        cloudtrail.create_trail(
            Name='phi-data-audit-trail',
            S3BucketName=f'{bucket}-audit-logs',
            IncludeGlobalServiceEvents=True,
            IsMultiRegionTrail=True,
            EnableLogFileValidation=True,
            EventSelectors=[{
                'ReadWriteType': 'All',
                'IncludeManagementEvents': True,
                'DataResources': [{
                    'Type': 'AWS::S3::Object',
                    'Values': [f'arn:aws:s3:::{bucket}/*']
                }]
            }]
        )
        
        print("Comprehensive audit logging enabled")
        print("- S3 access logs")
        print("- CloudTrail API logs")
        print("- Redshift audit logs")
    
    # 6. Data Anonymization
    def anonymize_phi_data(self, df):
        """Anonymize PHI for analytics (irreversible)"""
        
        from pyspark.sql.functions import sha2, concat_ws, monotonically_increasing_id
        
        anonymized_df = df.withColumn(
            "patient_id_hash",
            sha2(col("patient_id"), 256)
        ).withColumn(
            "synthetic_id",
            monotonically_increasing_id()
        ).drop("patient_id", "ssn", "name", "address", "phone", "email")
        
        return anonymized_df
    
    # 7. Data Retention
    def implement_retention_policy(self, bucket):
        """Enforce data retention and deletion policies"""
        
        # HIPAA requires 6 years minimum retention
        lifecycle_config = {
            'Rules': [{
                'Id': 'phi-retention-policy',
                'Status': 'Enabled',
                'Filter': {'Prefix': 'phi/'},
                'Transitions': [
                    {
                        'Days': 90,
                        'StorageClass': 'GLACIER_IR'
                    },
                    {
                        'Days': 2190,  # 6 years
                        'StorageClass': 'DEEP_ARCHIVE'
                    }
                ],
                'Expiration': {
                    'Days': 2555  # 7 years (buffer)
                },
                'NoncurrentVersionExpiration': {
                    'NoncurrentDays': 90
                }
            }]
        }
        
        self.s3.put_bucket_lifecycle_configuration(
            Bucket=bucket,
            LifecycleConfiguration=lifecycle_config
        )
        
        print("Retention policy enforced:")
        print("- Active storage: 90 days")
        print("- Glacier: 6 years")
        print("- Deep Archive: 7 years")
        print("- Auto-deletion: After 7 years")
    
    # 8. De-identification
    def deidentify_data(self, df):
        """Remove 18 HIPAA identifiers"""
        
        hipaa_identifiers = [
            'name', 'address', 'city', 'state', 'zip',
            'dates', 'phone', 'fax', 'email', 'ssn',
            'medical_record_number', 'health_plan_number',
            'account_number', 'certificate_number', 'license_number',
            'vehicle_identifier', 'device_serial_number',
            'url', 'ip_address', 'biometric_identifier',
            'photo', 'any_unique_identifier'
        ]
        
        # Remove or hash identifiers
        deidentified_df = df
        
        for identifier in hipaa_identifiers:
            if identifier in df.columns:
                deidentified_df = deidentified_df.drop(identifier)
        
        return deidentified_df
```

#### Compliance Checklist

```python
hipaa_compliance_checklist = {
    "Technical Safeguards": {
        "✅ Access Control": "IAM policies, MFA, least privilege",
        "✅ Audit Controls": "CloudTrail, S3 access logs, Redshift audit logs",
        "✅ Integrity": "File checksums, encryption validation",
        "✅ Transmission Security": "SSL/TLS for all connections"
    },
    
    "Physical Safeguards": {
        "✅ Facility Access": "AWS data centers (SOC 2 certified)",
        "✅ Workstation Use": "VPC, security groups",
        "✅ Device Security": "Encrypted EBS volumes"
    },
    
    "Administrative Safeguards": {
        "✅ Risk Analysis": "Regular security assessments",
        "✅ Workforce Training": "HIPAA awareness training",
        "✅ Incident Response": "Breach notification procedures",
        "✅ Business Associate Agreement": "AWS BAA signed"
    },
    
    "Data Protection": {
        "✅ Encryption at Rest": "S3 SSE-KMS, Redshift cluster encryption",
        "✅ Encryption in Transit": "TLS 1.2+",
        "✅ Access Logging": "Every access logged and monitored",
        "✅ Data Backup": "Automated snapshots",
        "✅ Retention": "6+ years per HIPAA",
        "✅ Secure Deletion": "Lifecycle policies, permanent deletion"
    }
}
```

---

### What is Partition and Types of Partitions?

**Partition:** Dividing large datasets into smaller, manageable parts based on specific columns.

#### Types of Partitions

```python
# 1. HIVE/SPARK PARTITIONING (Directory-based)
# Partitions data into separate directories

df.write \
    .partitionBy("year", "month", "day") \
    .parquet("s3://bucket/data/")

"""
Directory structure:
data/
├── year=2024/
│   ├── month=01/
│   │   ├── day=01/
│   │   │   └── part-00000.parquet
│   │   └── day=02/
│   │       └── part-00000.parquet
│   └── month=02/
└── year=2025/

Benefits:
- Partition pruning: Query only relevant directories
- Faster queries on filtered data
- Easy data lifecycle management
"""


# 2. BUCKETING (Hash-based partitioning)
# Distributes data evenly across fixed number of files

df.write \
    .bucketBy(100, "customer_id") \
    .sortBy("transaction_date") \
    .saveAsTable("transactions")

"""
Creates 100 buckets based on hash(customer_id)
All records with same customer_id go to same bucket

Benefits:
- Optimized joins (bucket join)
- Optimized aggregations on bucketed column
- Consistent file sizes
"""


# 3. RANGE PARTITIONING
# Partitions based on value ranges

# Not directly supported in Spark, but can be achieved:
df.withColumn("age_group",
    when(col("age") < 18, "minor")
    .when((col("age") >= 18) & (col("age") < 65), "adult")
    .otherwise("senior")
).write.partitionBy("age_group").parquet(path)


# 4. LIST PARTITIONING
# Explicit list of values per partition

# Partition by specific regions
df.write.partitionBy("region").parquet(path)
# Creates: region=US/, region=EU/, region=APAC/


# 5. HASH PARTITIONING (Repartition)
# Distribute data evenly using hash function

df.repartition(200, "customer_id").write.parquet(path)

"""
Distributes data across 200 partitions using hash(customer_id)
Different from bucketing: doesn't create bucketed table
"""


# 6. ROUND-ROBIN PARTITIONING
# Distribute data evenly without considering data

df.repartition(100).write.parquet(path)

"""
Distributes data randomly across 100 partitions
Use when you don't have a good partitioning key
"""
```

#### Partitioning Best Practices

```python
class PartitioningBestPractices:
    """Guidelines for effective partitioning"""
    
    @staticmethod
    def choose_partition_columns():
        """How to choose partition columns"""
        
        guidelines = {
            "Good partition columns": [
                "Columns used in WHERE clauses (date, region)",
                "Low cardinality (10-10,000 unique values)",
                "Temporal columns (year, month, day)",
                "Categorical columns (country, department, status)"
            ],
            
            "Bad partition columns": [
                "High cardinality (user_id with millions of values)",
                "Continuously growing (timestamp with seconds)",
                "Rarely filtered columns",
                "Columns with uneven distribution"
            ],
            
            "Partition size": [
                "Target: 128MB - 1GB per partition",
                "Too small (<10MB): Small files problem, slow metadata operations",
                "Too large (>5GB): Cannot leverage parallelism effectively"
            ]
        }
        
        return guidelines
    
    @staticmethod
    def avoid_small_files_problem():
        """Handle small files created by partitioning"""
        
        # Problem: 1000 partitions with 100 records each = 1000 tiny files
        # Solution 1: Coalesce before writing
        df.coalesce(1).write.partitionBy("date").parquet(path)
        
        # Solution 2: Repartition strategically
        df.repartition(10, "date").write.partitionBy("date").parquet(path)
        
        # Solution 3: Compact small files periodically
        """
        spark.read.parquet(path) \
            .repartition(10) \
            .write.mode("overwrite") \
            .parquet(path)
        """
    
    @staticmethod
    def partition_pruning_example():
        """How partitioning improves query performance"""
        
        # Without partitioning
        df = spark.read.parquet("s3://bucket/data/")  # Reads all files
        result = df.filter(col("year") == 2024)  # Filters after reading
        
        # With partitioning
        df = spark.read.parquet("s3://bucket/data/")  # Only reads year=2024/ directory
        result = df.filter(col("year") == 2024)  # Filter pushed down to read
        
        # Performance:
        # Without: Scans 5TB
        # With: Scans 1TB (only 2024 partition)
        # Speedup: 5x faster
```

#### Partitioning vs Bucketing

```python
comparison = {
    "Partitioning": {
        "Type": "Directory-based",
        "Structure": "Separate directories per partition value",
        "Use case": "Filter queries (WHERE date = '2024-01-01')",
        "Number of divisions": "Based on data (dynamic)",
        "Example": "partitionBy('year', 'month')",
        "Pros": "Partition pruning, easy lifecycle management",
        "Cons": "Can create many small files with high cardinality"
    },
    
    "Bucketing": {
        "Type": "Hash-based",
        "Structure": "Fixed number of files, hash determines bucket",
        "Use case": "Join/GroupBy queries on bucketed column",
        "Number of divisions": "Fixed (e.g., 100 buckets)",
        "Example": "bucketBy(100, 'customer_id')",
        "Pros": "Optimized joins, consistent file sizes",
        "Cons": "Not as intuitive, requires managed tables"
    },
    
    "When to use both": {
        "Scenario": "Time-series data with frequent joins",
        "Implementation": """
            df.write \
                .partitionBy('year', 'month') \
                .bucketBy(50, 'customer_id') \
                .sortBy('transaction_date') \
                .saveAsTable('transactions')
        """,
        "Benefit": "Partition pruning on date + optimized joins on customer_id"
    }
}
```

---

### Data Skewness - Detection and Handling

#### What is Data Skewness?

**Definition:** Uneven distribution of data across partitions, causing some tasks to process significantly more data than others.

**Example:**
- 100 customers, but 1 customer (Amazon) has 80% of all transactions
- When joining/grouping by customer_id, one partition processes 80% of data
- Other 99 partitions finish in 1 minute, but the skewed partition takes 30 minutes

#### How to Detect Data Skewness

```python
class DataSkewnessDetector:
    """Detect and quantify data skewness"""
    
    @staticmethod
    def check_partition_skew(df, partition_col):
        """Check if data is skewed on a column"""
        
        # Get distribution of data across partition keys
        distribution = df.groupBy(partition_col) \
                         .count() \
                         .orderBy(col("count").desc())
        
        distribution.show(20)
        
        # Statistics
        total_records = df.count()
        stats = distribution.select(
            max("count").alias("max_partition_size"),
            min("count").alias("min_partition_size"),
            avg("count").alias("avg_partition_size"),
            count("*").alias("num_partitions")
        ).collect()[0]
        
        max_size = stats["max_partition_size"]
        avg_size = stats["avg_partition_size"]
        
        # Skew ratio: how much larger is the biggest partition vs average?
        skew_ratio = max_size / avg_size if avg_size > 0 else 0
        
        print(f"\n=== Skew Analysis ===")
        print(f"Total records: {total_records:,}")
        print(f"Number of partitions: {stats['num_partitions']}")
        print(f"Max partition size: {max_size:,}")
        print(f"Min partition size: {stats['min_partition_size']:,}")
        print(f"Avg partition size: {avg_size:,.0f}")
        print(f"Skew ratio: {skew_ratio:.2f}x")
        
        if skew_ratio > 3:
            print(f"⚠️  SIGNIFICANT SKEW DETECTED!")
            print(f"   Top partition has {skew_ratio:.2f}x more data than average")
        elif skew_ratio > 1.5:
            print(f"⚠️  Moderate skew detected")
        else:
            print(f"✅ Data is relatively balanced")
        
        return skew_ratio
    
    @staticmethod
    def identify_skewed_keys(df, partition_col, threshold=0.1):
        """Identify which keys are causing skew"""
        
        total_records = df.count()
        
        skewed_keys = df.groupBy(partition_col) \
                        .count() \
                        .withColumn("percentage", col("count") / total_records * 100) \
                        .filter(col("percentage") > threshold * 100) \
                        .orderBy(col("count").desc())
        
        print(f"\nKeys with >{threshold*100}% of data (skewed keys):")
        skewed_keys.show(20, truncate=False)
        
        return skewed_keys
    
    @staticmethod
    def check_spark_ui_skew():
        """Visual indicators in Spark UI"""
        
        indicators = """
        Check Spark UI (port 4040) for:
        
        1. Stages Tab:
           - One task taking 10x longer than others
           - "Max Duration" >> "Median Duration"
           
        2. Tasks Distribution:
           - Most tasks: 100MB processed
           - One task: 8GB processed  ← SKEWED
           
        3. Shuffle Read/Write:
           - Uneven shuffle read bytes across tasks
           
        4. GC Time:
           - One executor with excessive GC time (memory pressure from skew)
        """
        
        print(indicators)
```

#### How to Handle Data Skewness

```python
class SkewHandlingStrategies:
    """Various techniques to handle data skew"""
    
    @staticmethod
    def technique_1_salting(df_large, df_small, join_key, num_salts=10):
        """
        SALTING: Add random suffix to skewed keys
        
        Best for: Skewed joins
        When: One dataset has skewed keys
        """
        
        print("=== Technique 1: Salting ===")
        
        # Step 1: Add random salt to large (skewed) table
        df_large_salted = df_large.withColumn(
            "salt",
            (rand() * num_salts).cast("int")
        )
        
        # Step 2: Replicate small table with all salt values
        df_small_exploded = df_small.withColumn(
            "salt",
            explode(array([lit(i) for i in range(num_salts)]))
        )
        
        # Step 3: Join on both key and salt
        result = df_large_salted.join(
            df_small_exploded,
            [join_key, "salt"],
            "inner"
        ).drop("salt")
        
        print(f"✅ Distributed skewed key across {num_salts} partitions")
        
        return result
    
    @staticmethod
    def technique_2_broadcast_join(df_large, df_small, join_key):
        """
        BROADCAST JOIN: Replicate small table to all executors
        
        Best for: One dataset is small (<10MB)
        When: Skew in join operation
        """
        
        print("=== Technique 2: Broadcast Join ===")
        
        from pyspark.sql.functions import broadcast
        
        # Force broadcast of small table
        result = df_large.join(
            broadcast(df_small),
            join_key,
            "inner"
        )
        
        print("✅ Small table broadcasted to all executors")
        print("   Avoids shuffle, eliminates skew impact")
        
        return result
    
    @staticmethod
    def technique_3_adaptive_query_execution(spark):
        """
        AQE: Let Spark automatically handle skew
        
        Best for: Spark 3.0+
        When: Don't want to manually tune
        """
        
        print("=== Technique 3: Adaptive Query Execution (AQE) ===")
        
        # Enable AQE
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
        spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
        spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
        
        print("✅ AQE enabled - Spark will automatically:")
        print("   1. Detect skewed partitions during execution")
        print("   2. Split large partitions into smaller ones")
        print("   3. Optimize join strategy dynamically")
        
        return spark
    
    @staticmethod
    def technique_4_isolate_and_process_separately(df, skewed_keys_df, key_col):
        """
        SPLIT PROCESSING: Handle skewed keys separately
        
        Best for: Few highly skewed keys
        When: Can identify skewed keys in advance
        """
        
        print("=== Technique 4: Isolate Skewed Keys ===")
        
        # Get list of skewed keys
        skewed_keys = [row[key_col] for row in skewed_keys_df.collect()]
        
        # Split data
        skewed_data = df.filter(col(key_col).isin(skewed_keys))
        normal_data = df.filter(~col(key_col).isin(skewed_keys))
        
        # Process normal data (fast)
        normal_result = normal_data.groupBy(key_col).agg(sum("amount"))
        
        # Process skewed data with more resources
        skewed_result = skewed_data.repartition(100, key_col) \
                                    .groupBy(key_col) \
                                    .agg(sum("amount"))
        
        # Combine results
        final_result = normal_result.union(skewed_result)
        
        print(f"✅ Processed {len(skewed_keys)} skewed keys separately")
        print("   with higher parallelism")
        
        return final_result
    
    @staticmethod
    def technique_5_iterative_broadcast(df_large, df_small, join_key, skewed_keys):
        """
        ITERATIVE BROADCAST: Broadcast skewed keys separately
        
        Best for: Combination of skewed and normal data
        When: Most keys are fine, few are very skewed
        """
        
        print("=== Technique 5: Iterative Broadcast ===")
        
        from pyspark.sql.functions import broadcast
        
        # Process normal keys with regular join
        normal_large = df_large.filter(~col(join_key).isin(skewed_keys))
        normal_small = df_small.filter(~col(join_key).isin(skewed_keys))
        normal_result = normal_large.join(normal_small, join_key)
        
        # Process skewed keys with broadcast
        skewed_large = df_large.filter(col(join_key).isin(skewed_keys))
        skewed_small = df_small.filter(col(join_key).isin(skewed_keys))
        skewed_result = skewed_large.join(broadcast(skewed_small), join_key)
        
        # Combine
        final_result = normal_result.union(skewed_result)
        
        print("✅ Skewed keys handled with broadcast, normal keys with regular join")
        
        return final_result
    
    @staticmethod
    def technique_6_increase_parallelism(df, key_col):
        """
        INCREASE PARALLELISM: More partitions = smaller skew impact
        
        Best for: Moderate skew
        When: Can afford more tasks
        """
        
        print("=== Technique 6: Increase Parallelism ===")
        
        # Increase shuffle partitions
        spark.conf.set("spark.sql.shuffle.partitions", "400")  # Default: 200
        
        # Or explicitly repartition
        df_repartitioned = df.repartition(400, key_col)
        
        print("✅ Increased partitions from 200 → 400")
        print("   Reduces impact of individual skewed partition")
        
        return df_repartitioned
```

#### Real-World Example: Products with Zero Stock

```python
# Scenario from interview questions:
# Products: apple, banana, orange, grape
# Skew: 80% of records have qty=0 (banana, grape)

# Sample data
products = spark.createDataFrame([
    ("apple", 100),
    ("banana", 0),
    ("orange", 50),
    ("grape", 0),
], ["product", "qty"])

orders = spark.createDataFrame([
    ("apple", "Order1"),
    ("banana", "Order2"),
    ("banana", "Order3"),
    ("orange", "Order4"),
    ("grape", "Order5"),
    ("grape", "Order6"),
], ["product", "order_id"])

# Problem: Joining on 'product' causes skew (banana, grape dominate)

# Solution: Apply salting
NUM_SALTS = 5

# Add salt to orders (large, skewed table)
orders_salted = orders.withColumn(
    "salt",
    when(col("product").isin(["banana", "grape"]), (rand() * NUM_SALTS).cast("int"))
    .otherwise(lit(0))
)

# Replicate products for skewed keys
products_exploded = products.crossJoin(
    spark.range(NUM_SALTS).withColumnRenamed("id", "salt")
).filter(col("product").isin(["banana", "grape"])).union(
    products.filter(~col("product").isin(["banana", "grape"]))
           .withColumn("salt", lit(0))
)

# Join distributes evenly
result = orders_salted.join(products_exploded, ["product", "salt"]).drop("salt")

# Products with zero stock
zero_stock = products.filter(col("qty") == 0).select("product").collect()
print("Products with zero stock:", [row.product for row in zero_stock])
# Output: ['banana', 'grape']
```

---

### How to Improve Spark Job Performance

**Comprehensive optimization strategies:**

```python
class SparkJobOptimization:
    """Complete guide to Spark performance tuning"""
    
    @staticmethod
    def optimize_data_format():
        """Use optimal file formats"""
        
        # ❌ Bad: CSV (slow, no compression, no predicate pushdown)
        df = spark.read.csv("s3://bucket/data.csv")
        
        # ✅ Good: Parquet (columnar, compressed, predicate pushdown)
        df = spark.read.parquet("s3://bucket/data.parquet")
        
        # Write with optimal settings
        df.write \
            .mode("overwrite") \
            .option("compression", "snappy") \
            .parquet(output_path)
        
        improvements = {
            "Storage": "3-5x smaller",
            "Read speed": "5-10x faster",
            "Query performance": "10-100x faster (columnar access)"
        }
        
        return improvements
    
    @staticmethod
    def optimize_partitioning():
        """Right-size partitions"""
        
        # Rule of thumb: 128MB - 1GB per partition
        
        # ❌ Too many partitions (overhead)
        df.repartition(10000).write.parquet(path)  # 10,000 tiny files
        
        # ❌ Too few partitions (no parallelism)
        df.coalesce(1).write.parquet(path)  # Single file, no parallelism
        
        # ✅ Optimal partitioning
        data_size_gb = 100
        target_partition_size_mb = 256
        num_partitions = int((data_size_gb * 1024) / target_partition_size_mb)
        
        df.repartition(num_partitions).write.parquet(path)
        
        print(f"Optimal partitions for {data_size_gb}GB: {num_partitions}")
    
    @staticmethod
    def optimize_caching():
        """Cache intelligently"""
        
        # ❌ Bad: Cache everything
        df.cache()  # Wastes memory
        
        # ✅ Good: Cache only reused DataFrames
        df_base = spark.read.parquet("large_table")
        
        # Filter once, use multiple times
        df_filtered = df_base.filter(col("year") == 2024).cache()
        
        daily_agg = df_filtered.groupBy("date").sum("amount")
        monthly_agg = df_filtered.groupBy("month").sum("amount")
        customer_agg = df_filtered.groupBy("customer_id").sum("amount")
        
        # Unpersist when done
        df_filtered.unpersist()
        
        # Cache storage levels
        from pyspark import StorageLevel
        df.persist(StorageLevel.MEMORY_AND_DISK)  # Spill to disk if needed
        df.persist(StorageLevel.MEMORY_ONLY)  # Faster, but may lose partitions
        df.persist(StorageLevel.DISK_ONLY)  # When memory is limited
    
    @staticmethod
    def optimize_shuffles():
        """Minimize and optimize shuffle operations"""
        
        # Shuffles are expensive: repartition, join, groupBy, distinct
        
        # ❌ Bad: Multiple shuffles
        df1 = df.repartition(200, "key")  # Shuffle 1
        df2 = df1.join(other_df, "key")  # Shuffle 2
        df3 = df2.groupBy("key").sum("amount")  # Shuffle 3
        
        # ✅ Good: Minimize shuffles
        # - Colocate data (bucketing)
        # - Filter before shuffle
        # - Use broadcast for small tables
        
        spark.conf.set("spark.sql.shuffle.partitions", "200")  # Tune shuffle partitions
        spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10 * 1024 * 1024)  # 10MB
    
    @staticmethod
    def optimize_memory():
        """Tune memory configuration"""
        
        config = {
            # Executor memory
            "spark.executor.memory": "8g",  # Heap size
            "spark.executor.memoryOverhead": "1g",  # Off-heap
            
            # Driver memory
            "spark.driver.memory": "4g",
            
            # Memory fractions
            "spark.memory.fraction": "0.6",  # 60% for execution/storage
            "spark.memory.storageFraction": "0.5",  # 50% of above for caching
            
            # Prevent OOM
            "spark.executor.cores": "4",
            "spark.task.cpus": "1",
            "spark.default.parallelism": "200"
        }
        
        for key, value in config.items():
            spark.conf.set(key, value)
        
        print("Memory optimized for:")
        print("- 8GB executor heap + 1GB overhead")
        print("- 60% for execution/storage, 40% for user objects")
    
    @staticmethod
    def optimize_transformations():
        """Write efficient transformations"""
        
        # ❌ Bad: Multiple passes over data
        df = df.filter(col("a") > 0)
        df = df.filter(col("b") < 100)
        df = df.withColumn("c", col("a") + col("b"))
        df = df.withColumn("d", col("a") * col("b"))
        
        # ✅ Good: Single pass
        df = df.filter((col("a") > 0) & (col("b") < 100)) \
               .select("*",
                      (col("a") + col("b")).alias("c"),
                      (col("a") * col("b")).alias("d"))
        
        # ❌ Bad: Collect to driver (OOM risk)
        data = df.collect()  # Pulls all data to driver
        
        # ✅ Good: Process distributed
        df.write.parquet(path)  # Stays distributed
    
    @staticmethod
    def optimize_joins():
        """Choose optimal join strategy"""
        
        # 1. Broadcast join (small table < 10MB)
        result = large_df.join(broadcast(small_df), "key")
        
        # 2. Sort-merge join (both large, but sorted)
        large_df.write.bucketBy(50, "key").sortBy("key").saveAsTable("t1")
        large_df2.write.bucketBy(50, "key").sortBy("key").saveAsTable("t2")
        result = spark.table("t1").join(spark.table("t2"), "key")
        
        # 3. Skew join (AQE handles automatically in Spark 3.0+)
        spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
        
        # 4. Reduce data before join
        df1_filtered = df1.filter(col("date") >= "2024-01-01")
        result = df1_filtered.join(df2, "key")  # Smaller shuffle
    
    @staticmethod
    def enable_adaptive_query_execution():
        """Let Spark optimize at runtime (Spark 3.0+)"""
        
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
        spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
        
        print("AQE enabled:")
        print("- Dynamically coalesce partitions")
        print("- Handle skewed joins automatically")
        print("- Switch join strategies at runtime")
    
    @staticmethod
    def optimize_serialization():
        """Use faster serialization"""
        
        # Kryo is faster than Java serialization
        spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
        spark.conf.set("spark.kryo.registrationRequired", "false")
        
        print("Kryo serialization enabled (10x faster than Java)")
    
    @staticmethod
    def optimize_garbage_collection():
        """Reduce GC pressure"""
        
        # Use G1GC (better for large heaps)
        config = {
            "spark.executor.extraJavaOptions": "-XX:+UseG1GC -XX:G1HeapRegionSize=16M",
            "spark.driver.extraJavaOptions": "-XX:+UseG1GC"
        }
        
        for key, value in config.items():
            spark.conf.set(key, value)


# Complete optimization checklist
optimization_checklist = """
✅ 1. File Format: Use Parquet with Snappy compression
✅ 2. Partitioning: 128MB-1GB per partition, partition by frequently filtered columns
✅ 3. Caching: Cache only reused DataFrames
✅ 4. Shuffles: Minimize, tune spark.sql.shuffle.partitions
✅ 5. Memory: Tune executor/driver memory, memory fractions
✅ 6. Transformations: Single-pass operations, avoid collect()
✅ 7. Joins: Use broadcast for small tables, bucket large tables
✅ 8. AQE: Enable for automatic optimizations
✅ 9. Serialization: Use Kryo
✅ 10. GC: Use G1GC for large heaps
"""

print(optimization_checklist)
```

---

## Production Issues & Troubleshooting

### Spark Production Issues Examples

**Common issues encountered:**

1. **Data Skew**: One partition processing 80% of data
2. **Out of Memory (OOM)**: Executor/driver running out of heap
3. **Small Files Problem**: Thousands of tiny files causing metadata overhead
4. **Slow Shuffles**: Large shuffle read/write times
5. **Task Failures**: Tasks failing and retrying repeatedly
6. **Network Issues**: S3 throttling, connection timeouts
7. **Schema Evolution**: Incompatible schema changes breaking jobs

### Job Not Running for 3 Days - Troubleshooting Steps

```python
def troubleshoot_job_not_running():
    """Systematic approach when job hasn't run for 3 days"""
    
    # Step 1: Check Scheduler/Trigger
    print("=== Step 1: Verify Trigger/Scheduler ===")
    
    # EventBridge (for S3-triggered jobs)
    events = boto3.client('events')
    rule_status = events.describe_rule(Name='glue-job-trigger')
    print(f"EventBridge rule status: {rule_status['State']}")
    if rule_status['State'] == 'DISABLED':
        print("❌ Rule is DISABLED - Enable it")
    
    # Check if source files landed
    s3 = boto3.client('s3')
    files = s3.list_objects_v2(Bucket='source-bucket', Prefix='data/in/')
    if not files.get('Contents'):
        print("❌ No source files in S3 - Check upstream system")
    
    # Step 2: Check CloudWatch Logs
    print("\n=== Step 2: Review CloudWatch Logs ===")
    
    logs = boto3.client('logs')
    log_streams = logs.describe_log_streams(
        logGroupName='/aws-glue/jobs/error',
        orderBy='LastEventTime',
        descending=True,
        limit=5
    )
    
    for stream in log_streams['logStreams']:
        print(f"Last error log: {stream['logStreamName']} at {stream['lastEventTime']}")
    
    # Step 3: Check Cluster Resources
    print("\n=== Step 3: Check Cluster Resources ===")
    
    glue = boto3.client('glue')
    
    # Check Glue DPU limits
    account_settings = glue.get_resource_policy()
    print("Glue DPU quota check:")
    # Verify not hitting concurrent job limits
    
    # For EMR
    emr = boto3.client('emr')
    clusters = emr.list_clusters(ClusterStates=['RUNNING', 'WAITING'])
    if not clusters['Clusters']:
        print("❌ No active EMR clusters - Check if cluster terminated")
    
    # Step 4: Check Data Availability
    print("\n=== Step 4: Verify Data Availability ===")
    
    # Check if dependencies are met
    dependencies = {
        'upstream_table_1': check_table_exists('database', 'table1'),
        'upstream_table_2': check_table_exists('database', 'table2'),
        'reference_data': check_s3_file_exists('bucket', 'reference/data.csv')
    }
    
    for dep, exists in dependencies.items():
        status = "✅" if exists else "❌"
        print(f"{status} {dep}: {exists}")
    
    # Step 5: Check IAM Permissions
    print("\n=== Step 5: Verify IAM Permissions ===")
    
    iam = boto3.client('iam')
    role_name = 'GlueJobRole'
    
    attached_policies = iam.list_attached_role_policies(RoleName=role_name)
    print(f"IAM Role: {role_name}")
    print(f"Attached policies: {len(attached_policies['AttachedPolicies'])}")
    
    # Step 6: Manual Test Run
    print("\n=== Step 6: Manual Test Run ===")
    
    try:
        response = glue.start_job_run(
            JobName='my-etl-job',
            Arguments={'--test_mode': 'true'}
        )
        print(f"✅ Manual run started: {response['JobRunId']}")
    except Exception as e:
        print(f"❌ Manual run failed: {str(e)}")
    
    # Step 7: Rollback Plan
    print("\n=== Step 7: Rollback Plan ===")
    
    rollback_steps = """
    If all checks fail:
    1. Check last successful run date
    2. Review code changes since last success
    3. Restore to last working version
    4. Replay missed data (if applicable)
    5. Alert stakeholders of data gap
    """
    
    print(rollback_steps)
```

### Other Jobs Running But Mine Failed

```python
def diagnose_single_job_failure():
    """Why is my job failing when others succeed?"""
    
    potential_causes = {
        "1. Skewed Data": {
            "symptom": "Other jobs finish in 10min, mine runs for hours",
            "diagnosis": "Check Spark UI for one task taking 10x longer",
            "solution": "Apply salting or increase parallelism"
        },
        
        "2. Bad Input Data": {
            "symptom": "Job fails with schema mismatch or parse errors",
            "diagnosis": "This job's input file may be corrupted",
            "solution": "Validate input file, use PERMISSIVE mode"
        },
        
        "3. Resource Misconfiguration": {
            "symptom": "OOM errors specific to this job",
            "diagnosis": "Job may need more memory than allocated",
            "solution": "Increase executor memory or reduce partition size"
        },
        
        "4. Dependency Failure": {
            "symptom": "Job fails at specific stage (e.g., loading reference data)",
            "diagnosis": "Upstream dependency missing or changed",
            "solution": "Check if reference data exists, validate schema"
        },
        
        "5. Code Bug": {
            "symptom": "Job fails with application error (not infra)",
            "diagnosis": "Recent code change introduced bug",
            "solution": "Rollback to last working version, add error handling"
        },
        
        "6. Permission Issue": {
            "symptom": "Access denied errors",
            "diagnosis": "IAM role may lack permission for specific resource",
            "solution": "Review CloudTrail for denied API calls"
        }
    }
    
    # Systematic diagnosis
    print("=== Diagnosis Steps ===")
    
    # 1. Compare with successful jobs
    print("\n1. Compare with successful jobs:")
    print("   - Same input source? Different file size?")
    print("   - Same Glue version? Same configurations?")
    print("   - Same time window? Network conditions?")
    
    # 2. Check input data
    print("\n2. Validate input data:")
    print("   - Run DQ checks on input file")
    print("   - Compare schema with previous runs")
    print("   - Check file size and record count")
    
    # 3. Review logs
    print("\n3. Deep dive into logs:")
    print("   - Find first error in CloudWatch")
    print("   - Check Spark driver logs")
    print("   - Review executor logs for OOM/exceptions")
    
    return potential_causes
```

### Starting Point for Debugging Failed Jobs

```python
def debug_failed_spark_job(job_run_id):
    """Systematic debugging approach"""
    
    # Step 1: Get high-level status
    print("=== Step 1: Job Status ===")
    glue = boto3.client('glue')
    
    run_details = glue.get_job_run(JobName='my-job', RunId=job_run_id)
    
    status = run_details['JobRun']['JobRunState']
    error_msg = run_details['JobRun'].get('ErrorMessage', 'None')
    
    print(f"Status: {status}")
    print(f"Error: {error_msg}")
    
    # Step 2: Check CloudWatch Logs
    print("\n=== Step 2: CloudWatch Logs ===")
    
    logs = boto3.client('logs')
    
    # Get error logs
    error_logs = logs.filter_log_events(
        logGroupName='/aws-glue/jobs/error',
        logStreamNames=[f'{job_run_id}'],
        limit=100
    )
    
    print("Recent errors:")
    for event in error_logs['events'][-5:]:  # Last 5 errors
        print(f"  {event['timestamp']}: {event['message']}")
    
    # Step 3: Check Spark UI (if available)
    print("\n=== Step 3: Spark UI Analysis ===")
    
    spark_ui_link = run_details['JobRun'].get('SparkUIUrl')
    if spark_ui_link:
        print(f"Spark UI: {spark_ui_link}")
        print("Check:")
        print("  - Stages tab: Which stage failed?")
        print("  - Tasks: Data skew? Task failures?")
        print("  - Executors: Lost executors? High GC time?")
    
    # Step 4: Categorize Error Type
    print("\n=== Step 4: Error Type Classification ===")
    
    error_types = {
        "OutOfMemoryError": {
            "cause": "Executor/driver heap exhausted",
            "fix": "Increase memory, optimize transformations, handle skew"
        },
        "FileNotFoundException": {
            "cause": "Input file missing or wrong path",
            "fix": "Verify S3 path, check permissions"
        },
        "AnalysisException": {
            "cause": "Schema mismatch or invalid SQL",
            "fix": "Check schema, validate SQL syntax"
        },
        "S3Exception": {
            "cause": "S3 throttling or network issue",
            "fix": "Reduce request rate, retry with backoff"
        },
        "KryoException": {
            "cause": "Serialization failure",
            "fix": "Register classes or use Java serialization"
        }
    }
    
    for error_type, details in error_types.items():
        if error_type in error_msg:
            print(f"\n🔍 Detected: {error_type}")
            print(f"   Cause: {details['cause']}")
            print(f"   Fix: {details['fix']}")
    
    # Step 5: Check Input Data
    print("\n=== Step 5: Input Data Validation ===")
    
    # Get job arguments to find input path
    args = run_details['JobRun']['Arguments']
    input_file = args.get('--source_file_name')
    
    if input_file:
        s3 = boto3.client('s3')
        bucket = args.get('--src_bucket')
        
        try:
            metadata = s3.head_object(Bucket=bucket, Key=f"data/in/{input_file}")
            file_size = metadata['ContentLength'] / (1024**2)  # MB
            print(f"Input file size: {file_size:.2f} MB")
            
            # Compare with historical sizes
            if file_size < 1:
                print("⚠️  File is unusually small - possible incomplete upload")
            elif file_size > 1000:
                print("⚠️  File is unusually large - may need more resources")
        except:
            print("❌ Input file not found!")
    
    # Step 6: Recommended Actions
    print("\n=== Step 6: Recommended Actions ===")
    
    actions = """
    1. Review error logs in CloudWatch
    2. Check Spark UI for bottlenecks
    3. Validate input data exists and is correct
    4. Compare with last successful run
    5. Check for recent code/config changes
    6. Test with smaller dataset
    7. Enable debug logging for next run
    """
    
    print(actions)
```

### Job Failed Due to OOM - Solutions

```python
def handle_oom_error():
    """Comprehensive OOM troubleshooting and fixes"""
    
    # Diagnosis
    print("=== OOM Diagnosis ===")
    
    oom_types = {
        "Driver OOM": {
            "symptom": "Driver heap exceeded",
            "cause": "collect(), toPandas(), broadcast() on large data",
            "log_pattern": "java.lang.OutOfMemoryError: Java heap space (driver)"
        },
        "Executor OOM": {
            "symptom": "Executor heap exceeded",
            "cause": "Large partitions, data skew, inefficient transformations",
            "log_pattern": "java.lang.OutOfMemoryError: Java heap space (executor)"
        },
        "Container OOM": {
            "symptom": "Container killed by YARN",
            "cause": "Total memory (heap + off-heap) exceeded",
            "log_pattern": "Container killed by YARN for exceeding memory limits"
        }
    }
    
    # Solutions
    print("\n=== Solutions ===")
    
    # Solution 1: Increase Memory
    def increase_memory():
        """Increase executor/driver memory"""
        
        spark.conf.set("spark.executor.memory", "16g")  # Was 8g
        spark.conf.set("spark.driver.memory", "8g")  # Was 4g
        spark.conf.set("spark.executor.memoryOverhead", "2g")  # Off-heap
        
        print("✅ Increased memory allocation")
    
    # Solution 2: Optimize Transformations
    def optimize_transformations():
        """Avoid memory-intensive operations"""
        
        # ❌ Bad: Collect to driver
        data = df.collect()  # OOM if df is large
        
        # ✅ Good: Process distributed
        df.write.parquet(path)
        
        # ❌ Bad: Broadcast large table
        result = df1.join(broadcast(large_df), "key")  # OOM
        
        # ✅ Good: Regular join or bucket
        result = df1.join(large_df, "key")
        
        print("✅ Optimized transformations")
    
    # Solution 3: Handle Data Skew
    def handle_skew():
        """Redistribute skewed data"""
        
        # Add salting
        df_salted = df.withColumn("salt", (rand() * 10).cast("int"))
        df_repartitioned = df_salted.repartition(200, "key", "salt").drop("salt")
        
        # Or increase parallelism
        spark.conf.set("spark.sql.shuffle.partitions", "400")
        
        print("✅ Handled data skew")
    
    # Solution 4: Process in Batches
    def process_in_batches():
        """Split large dataset into batches"""
        
        # Read in chunks
        for year in range(2020, 2025):
            df_year = spark.read.parquet(f"data/year={year}")
            
            # Process year
            result = df_year.groupBy("month").sum("amount")
            
            # Write incrementally
            result.write.mode("append").parquet("output/")
        
        print("✅ Processed in batches")
    
    # Solution 5: Reduce Partition Size
    def reduce_partition_size():
        """Create more smaller partitions"""
        
        # ❌ Bad: 50 partitions for 100GB = 2GB per partition (too large)
        df.repartition(50).write.parquet(path)
        
        # ✅ Good: 400 partitions for 100GB = 256MB per partition
        df.repartition(400).write.parquet(path)
        
        print("✅ Reduced partition size")
    
    # Solution 6: Tune Memory Fractions
    def tune_memory_fractions():
        """Adjust how Spark uses memory"""
        
        spark.conf.set("spark.memory.fraction", "0.8")  # 80% for execution/storage
        spark.conf.set("spark.memory.storageFraction", "0.3")  # 30% of above for cache
        
        # More memory for execution, less for caching
        print("✅ Tuned memory fractions")
    
    # Solution 7: Enable Spilling
    def enable_spilling():
        """Allow Spark to spill to disk"""
        
        from pyspark import StorageLevel
        
        # Use MEMORY_AND_DISK instead of MEMORY_ONLY
        df.persist(StorageLevel.MEMORY_AND_DISK)
        
        print("✅ Enabled spilling to disk")
    
    # Decision Tree
    decision_tree = """
    === OOM Decision Tree ===
    
    1. Driver OOM?
       → Avoid collect(), toPandas(), broadcast() on large data
       → Increase spark.driver.memory
       → Process in batches
    
    2. Executor OOM?
       → Check for data skew (Spark UI)
       → Increase spark.executor.memory
       → Increase number of partitions
       → Optimize transformations
    
    3. Container OOM?
       → Increase spark.executor.memoryOverhead
       → Reduce cores per executor
       → Use smaller partition sizes
    
    4. Recurring OOM?
       → Profile application (find memory leak)
       → Consider larger instance types
       → Redesign algorithm (if possible)
    """
    
    print(decision_tree)
```

### Map-Side Join vs Salting - When to Use Each

```python
def compare_join_strategies():
    """When to use broadcast join vs salting"""
    
    comparison = {
        "Map-Side Join (Broadcast Join)": {
            "when_to_use": [
                "One dataset is small (<10MB, configurable)",
                "Can fit in executor memory",
                "No data skew concerns"
            ],
            "how_it_works": "Replicate small table to all executors, join locally",
            "advantages": [
                "No shuffle required",
                "Very fast (no network transfer)",
                "Works well even with skewed large table"
            ],
            "limitations": [
                "Small table must fit in memory",
                "Broadcast overhead if table is large"
            ],
            "code": """
                from pyspark.sql.functions import broadcast
                
                # Force broadcast
                result = large_df.join(
                    broadcast(small_df),  # small_df < 10MB
                    "customer_id"
                )
            """,
            "performance": "10x-100x faster than shuffle join for small tables"
        },
        
        "Salting": {
            "when_to_use": [
                "BOTH datasets are large",
                "Data is skewed on join key",
                "One partition processing 80% of data"
            ],
            "how_it_works": "Add random suffix to skewed keys, distribute across partitions",
            "advantages": [
                "Handles skew when both tables are large",
                "Distributes hot keys evenly",
                "Prevents single task from being bottleneck"
            ],
            "limitations": [
                "Requires replicating small table (N times for N salts)",
                "More complex code",
                "Slight overhead from salting logic"
            ],
            "code": """
                # Add salt to large skewed table
                large_salted = large_df.withColumn(
                    "salt",
                    (rand() * 10).cast("int")
                )
                
                # Replicate small table with all salts
                small_exploded = small_df.withColumn(
                    "salt",
                    explode(array([lit(i) for i in range(10)]))
                )
                
                # Join on key + salt
                result = large_salted.join(
                    small_exploded,
                    ["customer_id", "salt"]
                ).drop("salt")
            """,
            "performance": "5x-10x faster than skewed shuffle join"
        }
    }
    
    # Decision Matrix
    decision_matrix = """
    === Decision Matrix ===
    
    | Scenario | Small Table Size | Skew? | Best Strategy |
    |----------|------------------|-------|---------------|
    | 1        | < 10MB           | No    | Broadcast     |
    | 2        | < 10MB           | Yes   | Broadcast     |
    | 3        | > 100MB          | No    | Regular Join  |
    | 4        | > 100MB          | Yes   | Salting       |
    | 5        | Both Large       | Yes   | Salting       |
    
    Quick Rule:
    - Small table? → Broadcast
    - Both large + skew? → Salting
    - Both large + no skew? → Regular sort-merge join
    """
    
    print(decision_matrix)
    
    return comparison
```

### Why Use `explode(array(lit))`?

```python
def explain_explode_array_lit():
    """Why we use explode(array(lit(...))) in salting"""
    
    explanation = """
    === Why explode(array(lit(0), lit(1), ..., lit(9)))? ===
    
    Purpose: Replicate each row of small table N times (once per salt value)
    
    Example:
    
    Small table (Products):
    +--------+-------+
    |product | price |
    +--------+-------+
    | apple  | 1.00  |
    | banana | 0.50  |
    +--------+-------+
    
    After adding explode(array(lit(0), lit(1), lit(2))):
    +--------+-------+------+
    |product | price | salt |
    +--------+-------+------+
    | apple  | 1.00  |  0   |  ← Row 1 replicated 3 times
    | apple  | 1.00  |  1   |
    | apple  | 1.00  |  2   |
    | banana | 0.50  |  0   |  ← Row 2 replicated 3 times
    | banana | 0.50  |  1   |
    | banana | 0.50  |  2   |
    +--------+-------+------+
    
    Why?
    
    Large table (Orders) has random salt (0, 1, or 2):
    +---------+--------+------+
    | order_id|product | salt |
    +---------+--------+------+
    | O1      | apple  |  1   |  ← Will match apple with salt=1
    | O2      | banana |  0   |  ← Will match banana with salt=0
    | O3      | apple  |  2   |  ← Will match apple with salt=2
    +---------+--------+------+
    
    Join on (product, salt):
    - O1 joins with apple (salt=1) ✅
    - O2 joins with banana (salt=0) ✅
    - O3 joins with apple (salt=2) ✅
    
    Without explode:
    - Small table only has one row per product (no salt)
    - Can't join when large table has salt=1, 2, etc.
    - Join would fail ❌
    
    === Code Breakdown ===
    """
    
    # Step-by-step
    from pyspark.sql.functions import explode, array, lit
    
    # 1. Create array of salt values
    salt_array = array([lit(i) for i in range(10)])
    # Result: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    
    # 2. Add as column
    df_with_array = small_df.withColumn("salt_array", salt_array)
    # Each row now has: [product, price, [0,1,2,3,4,5,6,7,8,9]]
    
    # 3. Explode the array
    df_exploded = df_with_array.withColumn("salt", explode("salt_array")).drop("salt_array")
    # Each row becomes 10 rows (one per salt value)
    
    # Alternative: One-liner
    df_exploded_oneliner = small_df.withColumn(
        "salt",
        explode(array([lit(i) for i in range(10)]))
    )
    
    print(explanation)
    
    # Visual Example
    print("\n=== Visual Example ===")
    
    small_data = [("apple", 1.00), ("banana", 0.50)]
    small_df = spark.createDataFrame(small_data, ["product", "price"])
    
    print("Before explode:")
    small_df.show()
    
    small_exploded = small_df.withColumn(
        "salt",
        explode(array([lit(i) for i in range(3)]))  # 3 salts for demo
    )
    
    print("After explode:")
    small_exploded.show()
```

### How Salt Values Match Between A and B

```python
def explain_salt_matching():
    """How salt ensures correct join results"""
    
    explanation = """
    === Salt Matching Mechanism ===
    
    Key Insight: We join on BOTH (key, salt), not just key
    
    Table A (Large, Skewed):
    - Gets RANDOM salt (0 to 9)
    - Each row gets ONE random salt value
    
    Table B (Small):
    - Gets ALL salts (0 to 9)
    - Each row is REPLICATED with all salt values
    
    This guarantees:
    - Every row in A with salt=X will find matching row in B with salt=X
    - No data loss (all joins succeed)
    - Even distribution (skewed key spread across 10 partitions)
    
    === Example ===
    
    Table A (Orders - Large):
    +----------+------------+------+
    | order_id | customer_id| salt |  ← Random salt
    +----------+------------+------+
    | O1       | AMAZON     |  3   |
    | O2       | AMAZON     |  7   |
    | O3       | AMAZON     |  1   |
    | O4       | walmart    |  0   |  (not skewed, gets salt=0)
    +----------+------------+------+
    
    Table B (Customers - Small):
    +------------+----------+------+
    | customer_id| name     | salt |  ← ALL salts
    +------------+----------+------+
    | AMAZON     | Amazon   |  0   |
    | AMAZON     | Amazon   |  1   |
    | AMAZON     | Amazon   |  2   |
    | AMAZON     | Amazon   |  3   |  ← Will match O1
    | ...        | ...      | ...  |
    | AMAZON     | Amazon   |  7   |  ← Will match O2
    | AMAZON     | Amazon   |  8   |
    | AMAZON     | Amazon   |  9   |
    | walmart    | Walmart  |  0   |  ← Will match O4
    | walmart    | Walmart  |  1   |
    | ...        | ...      | ...  |
    +------------+----------+------+
    
    Join on (customer_id, salt):
    
    O1 + salt=3: Matches AMAZON with salt=3 ✅
    O2 + salt=7: Matches AMAZON with salt=7 ✅
    O3 + salt=1: Matches AMAZON with salt=1 ✅
    O4 + salt=0: Matches walmart with salt=0 ✅
    
    Result: All joins succeed, AMAZON's data distributed evenly
    
    === Why This Works ===
    
    1. Correctness:
       - Table B has ALL possible salt values
       - Whatever salt Table A has, Table B has matching row
       - No data loss
    
    2. Distribution:
       - Table A's skewed key (AMAZON) gets random salts
       - Orders O1, O2, O3 go to different partitions (3, 7, 1)
       - Instead of one partition with all AMAZON data,
         it's spread across 10 partitions
    
    3. Performance:
       - Before: 1 partition processes 80% of data (30 min)
       - After: 10 partitions each process 8% of data (3 min)
       - 10x speedup
    """
    
    print(explanation)
    
    # Code Example
    print("\n=== Code Example ===")
    
    # Skewed large table
    orders = spark.createDataFrame([
        ("O1", "AMAZON"),
        ("O2", "AMAZON"),
        ("O3", "AMAZON"),
        ("O4", "AMAZON"),
        ("O5", "walmart"),
    ], ["order_id", "customer_id"])
    
    # Small table
    customers = spark.createDataFrame([
        ("AMAZON", "Amazon Inc"),
        ("walmart", "Walmart Inc"),
    ], ["customer_id", "name"])
    
    NUM_SALTS = 3  # Using 3 for demo
    
    # Add random salt to large table
    orders_salted = orders.withColumn(
        "salt",
        (rand() * NUM_SALTS).cast("int")
    )
    
    print("Orders with random salt:")
    orders_salted.show()
    
    # Replicate small table with all salts
    customers_exploded = customers.withColumn(
        "salt",
        explode(array([lit(i) for i in range(NUM_SALTS)]))
    )
    
    print("Customers replicated with all salts:")
    customers_exploded.show()
    
    # Join
    result = orders_salted.join(
        customers_exploded,
        ["customer_id", "salt"],
        "inner"
    ).drop("salt")
    
    print("Final join result:")
    result.show()
    
    print("\n✅ All rows joined successfully!")
    print("✅ AMAZON's data distributed across multiple partitions!")
```

---

This consolidated markdown file now contains **ALL** interview questions and answers from both documents, without missing any content. The file is organized into clear sections with comprehensive explanations, code examples, and real-world scenarios from your data ingestion project.