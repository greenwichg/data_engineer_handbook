# Ride-Hailing Data Platform - Complete Interview Solution
## Lambda Architecture for Dual Latency Requirements

Based on interview requirements:
- **Volume:** 500M events/day, 2-3 TB raw JSON/day
- **Latency:** 15-minute (city ops) + 24-hour (executives)
- **Storage:** Forever (raw), 13 months (queryable)
- **Tech:** AWS managed services

---

## Table of Contents
1. [Requirements Summary](#requirements-summary)
2. [High-Level Architecture](#high-level-architecture)
3. [Detailed Design](#detailed-design)
4. [Implementation Code](#implementation-code)
5. [Data Quality & Governance](#data-quality--governance)
6. [Interview Q&A](#interview-qa)

---

## Requirements Summary

### Functional Requirements

```yaml
Business Metrics:
  - trips_per_hour
  - driver_utilization
  - surge_pricing_effectiveness

Event Types:
  - trip_requested
  - driver_assigned
  - driver_arrived
  - trip_started
  - trip_completed
  - payment_processed

Volume:
  daily_events: 500_000_000
  daily_data: 2-3 TB (raw JSON)
  events_per_second: 5,787 avg, ~20,000 peak

Latency Requirements:
  city_operations: 15 minutes (real-time response)
  executive_dashboards: 24 hours (acceptable)

Consumers:
  primary: BI analysts (Tableau, Looker)
  future: ML teams (model training)

Historical Data:
  raw_retention: forever (compliance)
  queryable_hot: 13 months
  
Schema Evolution:
  frequency: quarterly
  current_state: no schema registry
  requirement: pipeline must handle changes gracefully

Technology Stack:
  cloud: AWS
  preference: managed services (reduce ops overhead)
```

### Non-Functional Requirements

```yaml
Scalability:
  handle_spikes: 3x peak traffic
  global_operations: hundreds of cities
  
Reliability:
  data_accuracy: 99.99% (financial data)
  uptime: 99.9% (three nines)
  
Data Quality:
  deduplication: required
  late_data_handling: 48-hour window
  
Compliance:
  GDPR: support deletes/updates
  audit_trail: complete lineage
  
Cost:
  optimize: storage (long-term retention)
  priority: operational simplicity over cost
```

---

## High-Level Architecture

### Lambda Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         DATA SOURCES                                     │
│  ┌──────────────────┐                           ┌────────────────────┐   │
│  │   Driver App     │                           │  Rider App         │   │
│  │  - iOS/Android   │                           │  - iOS/Android     │   │
│  │  - Location (5s) │                           │  - Trip events     │   │
│  └────┬─────────────┘                           └─────────────────┬──┘   │
└───────│───────────────────────────────────────────────────────────│──────┘
        │                                                           │
        │  500M events/day (5,787 avg TPS, 20K peak TPS)            │
        │  Events: trip_requested, driver_assigned, driver_arrived, │
        │          trip_started, trip_completed, payment_processed  │
        │                                                           │
        └──────────────────────┬────────────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    INGESTION LAYER                                       │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  Amazon Kinesis Data Streams                                   │      │
│  │  - Shards: 50 (auto-scaling enabled)                           │      │
│  │  - Partition key: trip_id (maintains event order per trip)     │      │
│  │  - Retention: 24 hours                                         │      │
│  │  - Enhanced fan-out: Multiple consumers                        │      │
│  │  - Cost: ~$550/month                                           │      │
│  │                                                                │      │
│  │  Event Envelope (schema evolution):                            │      │
│  │  {                                                             │      │
│  │    "event_name": "trip_started",                               │      │
│  │    "event_timestamp": "2025-01-18T10:30:00Z",                  │      │
│  │    "schema_version": "v2.1",                                   │      │
│  │    "payload": { ... actual event data ... }                    │      │
│  │  }                                                             │      │
│  └────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────┘
                               │
                               │
                ┌──────────────┴──────────────┐
                │                             │
                ▼                             ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│  BATCH PATH (24h Latency)    │  │  STREAMING PATH (15m Latency)│
│  Source of Truth             │  │  Fast, Provisional           │
└──────────────────────────────┘  └──────────────────────────────┘
                │                             │
                │                             │
                ▼                             ▼
```

### Batch Path (Cold Path - Source of Truth)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  BATCH PATH: 24-Hour Latency, 100% Accurate                              │
│                                                                          │
│  Kinesis Data Streams                                                    │
│         │                                                                │
│         ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  Kinesis Data Firehose                                         │      │
│  │  - Batch interval: 15 minutes                                  │      │
│  │  - Compression: gzip                                           │      │
│  │  - Format: JSON (raw fidelity)                                 │      │
│  │  - Destination: S3 Landing Zone                                │      │
│  │  - Cost: ~$100/month                                           │      │
│  └─────────────────────────┬──────────────────────────────────────┘      │
│                            │                                             │
│                            ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  S3 Landing Zone (Raw Layer)                                   │      │
│  │  Path: s3://ride-hailing-datalake/raw/events/                  │      │
│  │        year=YYYY/month=MM/day=DD/hour=HH/                      │      │
│  │  Format: gzipped JSON                                          │      │
│  │  Lifecycle:                                                    │      │
│  │  - Keep in S3 Standard: 7 days                                 │      │
│  │  - Move to S3 IA: 30 days                                      │      │
│  │  - Move to Glacier: 90 days                                    │      │
│  │  - Keep forever (compliance)                                   │      │
│  │  Cost: ~$450/month (Standard) + $200/month (IA/Glacier)        │      │
│  └─────────────────────────┬──────────────────────────────────────┘      │
│                            │                                             │
│                            │ Hourly Spark Job (AWS Glue or EMR)          │
│                            ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  BRONZE LAYER (Validated, Deduplicated)                        │      │
│  │  Path: s3://ride-hailing-datalake/bronze/events/               │      │
│  │        event_date=YYYY-MM-DD/                                  │      │
│  │  Format: Parquet (columnar, compressed)                        │      │
│  │  Schema: Same as source (no transformations)                   │      │
│  │  Operations:                                                   │      │
│  │  - JSON → Parquet conversion                                   │      │
│  │  - Schema validation                                           │      │
│  │  - Deduplication (by event_id)                                 │      │
│  │  - Add metadata: processing_time, data_quality_flag            │      │
│  │  Job: Runs hourly, processes last 24-48 hours                  │      │
│  │  Cost: ~$300/month (Glue DPU hours)                            │      │
│  └─────────────────────────┬──────────────────────────────────────┘      │
│                            │                                             │
│                            │ Daily Spark Job                             │
│                            ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  SILVER LAYER (Cleaned, Trip-Level)                            │      │
│  │  Path: s3://ride-hailing-datalake/silver/trips/                │      │
│  │        event_date=YYYY-MM-DD/                                  │      │
│  │  Format: Delta Lake (ACID, time travel)                        │      │
│  │  Schema: trip_id, start_time, end_time, fare, duration...      │      │
│  │  Operations:                                                   │      │
│  │  - Sessionization: Group events by trip_id                     │      │
│  │  - Pivot: trip_started → start_time,                           │      │
│  │           trip_completed → end_time                            │      │
│  │  - Enrichment: Calculate derived metrics                       │      │
│  │  - Business rules: Data cleansing, validation                  │      │
│  │  - MERGE support: Handle late arrivals (UPSERT)                │      │
│  │  Job: Runs daily, processes 48-hour window                     │      │
│  │  Cost: ~$400/month (Glue DPU hours)                            │      │
│  └─────────────────────────┬──────────────────────────────────────┘      │
│                            │                                             │
│                            │ Daily Spark Job                             │
│                            ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  GOLD LAYER (Business Aggregates)                              │      │
│  │  Tables:                                                       │      │
│  │  - trips_per_hour (city, hour → count)                         │      │
│  │  - driver_utilization (driver_id, date → metrics)              │      │
│  │  - surge_effectiveness (city, hour → pricing data)             │      │
│  │  Format: Delta Lake → Loaded to Redshift/Snowflake             │      │
│  │  Operations:                                                   │      │
│  │  - Aggregations from Silver                                    │      │
│  │  - Dimensional modeling (star schema)                          │      │
│  │  - Pre-computed metrics for dashboards                         │      │
│  │  Job: Runs daily                                               │      │
│  │  Cost: ~$200/month (Glue) + $2,000/month (Redshift)            │      │
│  └────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────┘
```

### Streaming Path (Hot Path - Fast & Provisional)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  STREAMING PATH: 15-Minute Latency, ~99.9% Accurate                      │
│                                                                          │
│  Kinesis Data Streams                                                    │
│         │                                                                │
│         ▼                                                                │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  Kinesis Data Analytics (Managed Apache Flink)                 │      │
│  │  Application: trip-aggregator                                  │      │
│  │  KPUs: 5-15 (auto-scaling)                                     │      │
│  │  Parallelism: 10                                               │      │
│  │  Cost: ~$600/month                                             │      │
│  │                                                                │      │
│  │  Processing Logic:                                             │      │
│  │  1. Stateful Stream: Maintain in-memory state per trip_id      │      │
│  │  2. Window: 2-hour session window (trip timeout)               │      │
│  │  3. Aggregation: Combine events into trip record               │      │
│  │  4. Output: Completed trips to serving layer                   │      │
│  │                                                                │      │
│  │  State Management:                                             │      │
│  │  - RocksDB state backend                                       │      │
│  │  - Checkpoint every 60 seconds to S3                           │      │
│  │  - Exactly-once semantics                                      │      │
│  └─────────────────────────┬──────────────────────────────────────┘      │
│                            │                                             │
│                            ▼                                             │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  Serving Layer: Amazon Redshift                                │      │
│  │  Table: streaming.trips (last 24 hours only)                   │      │
│  │  Load mechanism: Flink → S3 micro-batch → COPY every 5min      │      │
│  │  Retention: 24 hours (overwritten by batch daily)              │      │
│  │  Query latency: <2 seconds                                     │      │
│  │  Cost: Included in $2,000/month Redshift cluster               │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                          │
│  Alternative: Snowflake (micro-partitions, auto-scaling)                 │
└──────────────────────────────────────────────────────────────────────────┘
```

### Consistency & Reconciliation

```
┌──────────────────────────────────────────────────────────────────────────┐
│  LAMBDA ARCHITECTURE: CONSISTENCY STRATEGY                               │
│                                                                          │
│  Problem: Two pipelines (Spark batch, Flink streaming) create trips      │
│           → Potential discrepancies                                      │
│                                                                          │
│  Solution: "Batch as Source of Truth"                                    │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  1. Streaming Layer (Redshift: streaming.trips)                │      │
│  │     - Provides fast, provisional results                       │      │
│  │     - Accuracy: ~99.9% (some late events missed)               │      │
│  │     - Retention: Last 24 hours only                            │      │
│  │     - Users: City operations teams (need speed)                │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  2. Batch Layer (Redshift: batch.trips)                        │      │
│  │     - Processes all data (including late arrivals)             │      │
│  │     - Accuracy: 100% (source of truth)                         │      │
│  │     - Retention: 13 months queryable                           │      │
│  │     - Users: Executives, BI, ML teams                          │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  3. Daily Reconciliation (Every 24 hours)                      │      │ 
│  │                                                                │      │
│  │     Job runs at 2 AM:                                          │      │
│  │     a) Batch pipeline completes (Silver layer updated)         │      │
│  │     b) Load batch.trips from Silver Delta Lake                 │      │
│  │     c) TRUNCATE streaming.trips (discard old provisional data) │      │
│  │     d) Gold layer built ONLY from batch.trips                  │      │
│  │                                                                │      │
│  │     Result:                                                    │      │
│  │     - Last 24h: streaming.trips (fast but provisional)         │      │
│  │     - Older: batch.trips (slow but accurate)                   │      │
│  │     - Dashboards query both (UNION)                            │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │  4. Query Pattern (BI Tools)                                   │      │
│  │                                                                │      │
│  │     SELECT * FROM (                                            │      │
│  │       -- Real-time data (last 24 hours)                        │      │
│  │       SELECT * FROM streaming.trips                            │      │
│  │       WHERE trip_start_time >= CURRENT_DATE - 1                │      │
│  │                                                                │      │
│  │       UNION ALL                                                │      │
│  │                                                                │      │
│  │       -- Historical data (accurate)                            │      │
│  │       SELECT * FROM batch.trips                                │      │
│  │       WHERE trip_start_time < CURRENT_DATE - 1                 │      │
│  │     )                                                          │      │
│  │                                                                │      │
│  │     View: Create materialized view for convenience             │      │
│  └────────────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────────┘

Key Insight:
- Streaming provides speed (15min latency)
- Batch ensures accuracy (100% complete)
- Daily reconciliation prevents drift
- Users get best of both worlds
```

---

## Detailed Design

### 1. Ingestion Layer Implementation

```python
"""
kinesis_producer.py
Ride-hailing app backend: Publish events to Kinesis

Features:
- Schema envelope for evolution
- Partition by trip_id for ordering
- Retry logic with exponential backoff
- Batch aggregation for efficiency
"""

import boto3
import json
from datetime import datetime, timezone
import hashlib

class RideEventProducer:
    """
    Kinesis producer for ride-hailing events
    
    Schema Envelope Format:
    {
        "event_name": "trip_started",
        "event_timestamp": "2025-01-18T10:30:00.123Z",
        "schema_version": "v2.1",
        "event_id": "evt_abc123...",
        "payload": {
            "trip_id": "trip_xyz",
            "driver_id": "drv_123",
            ...
        }
    }
    """
    
    def __init__(self, stream_name, region='us-east-1'):
        self.kinesis = boto3.client('kinesis', region_name=region)
        self.stream_name = stream_name
        
    def publish_event(self, event_name, payload, schema_version="v2.1"):
        """
        Publish event to Kinesis with envelope
        
        Args:
            event_name: trip_started, driver_assigned, etc.
            payload: Event-specific data
            schema_version: Schema version for evolution tracking
        """
        
        # Create envelope
        envelope = {
            "event_name": event_name,
            "event_timestamp": datetime.now(timezone.utc).isoformat(),
            "schema_version": schema_version,
            "event_id": self._generate_event_id(),
            "payload": payload
        }
        
        # Partition key: trip_id (maintains event order per trip)
        partition_key = payload.get('trip_id', 'default')
        
        # Publish to Kinesis
        response = self.kinesis.put_record(
            StreamName=self.stream_name,
            Data=json.dumps(envelope),
            PartitionKey=partition_key
        )
        
        return response
    
    def publish_trip_started(self, trip_id, driver_id, rider_id, start_lat, start_lon):
        """Publish trip_started event"""
        
        payload = {
            "trip_id": trip_id,
            "driver_id": driver_id,
            "rider_id": rider_id,
            "start_latitude": start_lat,
            "start_longitude": start_lon,
            "estimated_duration": 1200,  # seconds
            "estimated_fare": 25.50
        }
        
        return self.publish_event("trip_started", payload)
    
    def publish_trip_completed(self, trip_id, end_lat, end_lon, actual_fare, duration):
        """Publish trip_completed event"""
        
        payload = {
            "trip_id": trip_id,
            "end_latitude": end_lat,
            "end_longitude": end_lon,
            "actual_fare": actual_fare,
            "actual_duration": duration,
            "rating": 4.5
        }
        
        return self.publish_event("trip_completed", payload)
    
    def _generate_event_id(self):
        """Generate unique event ID"""
        timestamp = datetime.now(timezone.utc).isoformat()
        unique_str = f"{timestamp}_{hash(timestamp)}"
        return hashlib.sha256(unique_str.encode()).hexdigest()[:16]

# Example usage
if __name__ == '__main__':
    producer = RideEventProducer('ride-events-stream')
    
    # Simulate trip lifecycle
    trip_id = "trip_abc123"
    
    # Event 1: Trip requested
    producer.publish_event("trip_requested", {
        "trip_id": trip_id,
        "rider_id": "rider_xyz",
        "pickup_lat": 37.7749,
        "pickup_lon": -122.4194
    })
    
    # Event 2: Driver assigned
    producer.publish_event("driver_assigned", {
        "trip_id": trip_id,
        "driver_id": "drv_456"
    })
    
    # Event 3: Trip started
    producer.publish_trip_started(
        trip_id=trip_id,
        driver_id="drv_456",
        rider_id="rider_xyz",
        start_lat=37.7749,
        start_lon=-122.4194
    )
    
    # Event 4: Trip completed
    producer.publish_trip_completed(
        trip_id=trip_id,
        end_lat=37.8044,
        end_lon=-122.2712,
        actual_fare=32.75,
        duration=1500
    )
```

### 2. Batch Path: Bronze Layer

```python
"""
glue_bronze_layer.py
AWS Glue job: Raw JSON → Bronze Parquet

Runs: Hourly
Processes: Last 24-48 hours (handles late arrivals)
Output: Partitioned Parquet in Bronze layer
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col, from_json, to_timestamp, current_timestamp,
    year, month, dayofmonth, sha2, concat_ws,
    row_number, lit
)
from pyspark.sql.window import Window
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, IntegerType
from datetime import datetime, timedelta

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'LOOKBACK_HOURS'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
LOOKBACK_HOURS = int(args.get('LOOKBACK_HOURS', 48))
RAW_PATH = "s3://ride-hailing-datalake/raw/events/"
BRONZE_PATH = "s3://ride-hailing-datalake/bronze/events/"

# Define schema for event envelope
envelope_schema = StructType([
    StructField("event_name", StringType(), False),
    StructField("event_timestamp", StringType(), False),
    StructField("schema_version", StringType(), True),
    StructField("event_id", StringType(), False),
    StructField("payload", StringType(), True)  # Nested JSON
])

# Payload schemas (varies by event type)
trip_started_schema = StructType([
    StructField("trip_id", StringType(), False),
    StructField("driver_id", StringType(), False),
    StructField("rider_id", StringType(), False),
    StructField("start_latitude", DoubleType(), True),
    StructField("start_longitude", DoubleType(), True),
    StructField("estimated_duration", IntegerType(), True),
    StructField("estimated_fare", DoubleType(), True)
])

def process_bronze_layer():
    """
    Process raw JSON to Bronze Parquet
    
    Steps:
    1. Read raw JSON from S3 (time-partitioned)
    2. Validate schema
    3. Deduplicate by event_id
    4. Add metadata columns
    5. Write as Parquet (date-partitioned)
    """
    
    print(f"=== Bronze Layer Processing ===")
    print(f"Lookback: {LOOKBACK_HOURS} hours")
    
    # Calculate time range
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=LOOKBACK_HOURS)
    
    # Read raw JSON
    print(f"Reading from: {RAW_PATH}")
    print(f"Time range: {start_time} to {end_time}")
    
    # Read time-partitioned data
    raw_df = spark.read \
        .option("basePath", RAW_PATH) \
        .json(RAW_PATH) \
        .filter(
            (col("year") == start_time.year) &
            (col("month") >= start_time.month) &
            (col("day") >= start_time.day)
        )
    
    initial_count = raw_df.count()
    print(f"Read {initial_count:,} raw events")
    
    # Parse event envelope
    parsed_df = raw_df.select(
        col("event_name"),
        to_timestamp(col("event_timestamp")).alias("event_timestamp"),
        col("schema_version"),
        col("event_id"),
        col("payload")
    )
    
    # Validate: Remove invalid records
    valid_df = parsed_df.filter(
        (col("event_id").isNotNull()) &
        (col("event_name").isNotNull()) &
        (col("event_timestamp").isNotNull()) &
        (col("event_timestamp") <= current_timestamp()) &  # Not future
        (col("event_timestamp") >= lit(start_time))  # Within window
    )
    
    invalid_count = initial_count - valid_df.count()
    print(f"Invalid records: {invalid_count:,} ({invalid_count/initial_count*100:.2f}%)")
    
    # Deduplicate by event_id (keep earliest)
    window_spec = Window.partitionBy("event_id").orderBy("event_timestamp")
    deduped_df = valid_df \
        .withColumn("row_num", row_number().over(window_spec)) \
        .filter(col("row_num") == 1) \
        .drop("row_num")
    
    duplicate_count = valid_df.count() - deduped_df.count()
    print(f"Duplicates removed: {duplicate_count:,}")
    
    # Add metadata
    bronze_df = deduped_df \
        .withColumn("processing_timestamp", current_timestamp()) \
        .withColumn("data_quality", lit("VALID")) \
        .withColumn("source", lit("kinesis_firehose")) \
        .withColumn(
            "row_hash",
            sha2(concat_ws("|", col("event_id"), col("event_timestamp")), 256)
        ) \
        .withColumn("event_date", col("event_timestamp").cast("date"))
    
    # Write to Bronze (partitioned by date)
    print(f"Writing to: {BRONZE_PATH}")
    
    bronze_df.write \
        .mode("overwrite") \
        .partitionBy("event_date") \
        .parquet(BRONZE_PATH)
    
    final_count = bronze_df.count()
    print(f"✅ Bronze layer complete: {final_count:,} events written")
    
    # Summary statistics
    bronze_df.groupBy("event_name").count().show()
    
    return final_count

# Execute
events_processed = process_bronze_layer()

job.commit()
```

### 3. Batch Path: Silver Layer (Trip Sessionization)

```python
"""
glue_silver_layer.py
AWS Glue job: Bronze events → Silver trips

Runs: Daily
Processes: Last 48 hours (handles late arrivals)
Output: Delta Lake format with MERGE support
"""

from delta import *
from pyspark.sql.functions import (
    col, min as min_, max as max_, first, last,
    when, expr, count, sum as sum_, datediff,
    unix_timestamp
)
from pyspark.sql.window import Window

# Initialize Glue + Delta
from awsglue.context import GlueContext
from pyspark.context import SparkContext
from awsglue.job import Job

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Configure Delta Lake
spark.sparkContext._jsc.hadoopConfiguration().set(
    "spark.sql.catalog.spark_catalog",
    "org.apache.spark.sql.delta.catalog.DeltaCatalog"
)
spark.sparkContext._jsc.hadoopConfiguration().set(
    "spark.sql.extensions",
    "io.delta.sql.DeltaSparkSessionExtension"
)

job = Job(glueContext)
job.init('silver-layer-job', {})

# Paths
BRONZE_PATH = "s3://ride-hailing-datalake/bronze/events/"
SILVER_PATH = "s3://ride-hailing-datalake/silver/trips/"

def sessionize_trips():
    """
    Convert event stream to trip records
    
    Process:
    1. Read Bronze events (last 48 hours)
    2. Group by trip_id
    3. Pivot events to columns (trip_started → start_time, etc.)
    4. Calculate derived metrics
    5. MERGE into Silver (handle late arrivals)
    """
    
    print("=== Silver Layer: Trip Sessionization ===")
    
    # Read Bronze (last 48 hours)
    from datetime import datetime, timedelta
    lookback_date = (datetime.utcnow() - timedelta(hours=48)).date()
    
    events_df = spark.read \
        .parquet(BRONZE_PATH) \
        .filter(col("event_date") >= lookback_date)
    
    print(f"Read {events_df.count():,} events from Bronze")
    
    # Parse payload (JSON string → struct)
    from pyspark.sql.functions import from_json, get_json_object
    
    events_expanded = events_df \
        .withColumn("trip_id", get_json_object(col("payload"), "$.trip_id")) \
        .withColumn("driver_id", get_json_object(col("payload"), "$.driver_id")) \
        .withColumn("rider_id", get_json_object(col("payload"), "$.rider_id")) \
        .withColumn("start_lat", get_json_object(col("payload"), "$.start_latitude").cast("double")) \
        .withColumn("start_lon", get_json_object(col("payload"), "$.start_longitude").cast("double")) \
        .withColumn("end_lat", get_json_object(col("payload"), "$.end_latitude").cast("double")) \
        .withColumn("end_lon", get_json_object(col("payload"), "$.end_longitude").cast("double")) \
        .withColumn("actual_fare", get_json_object(col("payload"), "$.actual_fare").cast("double")) \
        .withColumn("actual_duration", get_json_object(col("payload"), "$.actual_duration").cast("int")) \
        .filter(col("trip_id").isNotNull())
    
    # Sessionization: Group by trip_id and pivot
    trip_records = events_expanded \
        .groupBy("trip_id") \
        .agg(
            # Identifiers
            first("driver_id", ignorenulls=True).alias("driver_id"),
            first("rider_id", ignorenulls=True).alias("rider_id"),
            
            # Start details (from trip_started event)
            min_(when(col("event_name") == "trip_started", col("event_timestamp"))).alias("start_time"),
            first(when(col("event_name") == "trip_started", col("start_lat"))).alias("start_latitude"),
            first(when(col("event_name") == "trip_started", col("start_lon"))).alias("start_longitude"),
            
            # End details (from trip_completed event)
            max_(when(col("event_name") == "trip_completed", col("event_timestamp"))).alias("end_time"),
            last(when(col("event_name") == "trip_completed", col("end_lat"))).alias("end_latitude"),
            last(when(col("event_name") == "trip_completed", col("end_lon"))).alias("end_longitude"),
            
            # Financial
            max_("actual_fare").alias("fare_amount"),
            max_("actual_duration").alias("trip_duration_seconds"),
            
            # Metadata
            min_("event_timestamp").alias("first_event_time"),
            max_("event_timestamp").alias("last_event_time"),
            count("*").alias("event_count")
        ) \
        .withColumn(
            "trip_duration_minutes",
            col("trip_duration_seconds") / 60
        ) \
        .withColumn(
            "trip_date",
            col("start_time").cast("date")
        ) \
        .withColumn(
            "trip_status",
            when(col("end_time").isNotNull(), "COMPLETED")
            .otherwise("IN_PROGRESS")
        )
    
    print(f"Sessionized {trip_records.count():,} trips")
    
    # Data cleansing
    clean_trips = trip_records.filter(
        (col("start_time").isNotNull()) &
        (col("fare_amount") > 0) &
        (col("fare_amount") < 10000) &  # Max $10K
        (col("trip_duration_seconds") > 60) &  # Min 1 minute
        (col("trip_duration_seconds") < 86400)  # Max 24 hours
    )
    
    print(f"After cleansing: {clean_trips.count():,} trips")
    
    # MERGE into Silver (Delta Lake)
    print(f"Merging into Silver: {SILVER_PATH}")
    
    # Check if Delta table exists
    from delta.tables import DeltaTable
    import os
    
    if DeltaTable.isDeltaTable(spark, SILVER_PATH):
        # Update existing
        silver_table = DeltaTable.forPath(spark, SILVER_PATH)
        
        silver_table.alias("target").merge(
            clean_trips.alias("source"),
            "target.trip_id = source.trip_id"
        ).whenMatchedUpdateAll() \
         .whenNotMatchedInsertAll() \
         .execute()
        
        print("✅ MERGE complete (UPSERT)")
    else:
        # Create new
        clean_trips.write \
            .format("delta") \
            .mode("overwrite") \
            .partitionBy("trip_date") \
            .save(SILVER_PATH)
        
        print("✅ Silver table created")
    
    return clean_trips.count()

# Execute
trips_processed = sessionize_trips()

job.commit()
```

### 4. Streaming Path: Flink on KDA

```python
"""
kda_trip_aggregator.py
Kinesis Data Analytics (Flink) application for 15-minute latency

Features:
- Stateful processing (maintain trip state in-memory)
- Session windows (2-hour timeout)
- Exactly-once semantics
- Output to Redshift via micro-batch
"""

from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings
from pyflink.table.window import Session
from pyflink.common.time import Time
import os

def create_streaming_app():
    """
    Flink application for real-time trip aggregation
    
    Pipeline:
    1. Read from Kinesis (event stream)
    2. Maintain stateful session per trip_id
    3. Aggregate events into trip record
    4. Write to S3 micro-batches (every 5 minutes)
    5. Load to Redshift streaming.trips table
    """
    
    # Environment
    env = StreamExecutionEnvironment.get_execution_environment()
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    table_env = StreamTableEnvironment.create(env, settings)
    
    # Configuration from KDA
    input_stream = os.environ.get('INPUT_STREAM', 'ride-events-stream')
    output_path = os.environ.get('OUTPUT_S3_PATH', 's3://ride-hailing-datalake/streaming/')
    region = os.environ.get('AWS_REGION', 'us-east-1')
    
    # Source: Kinesis Data Streams
    source_ddl = f"""
        CREATE TABLE ride_events (
            event_name STRING,
            event_timestamp TIMESTAMP(3),
            event_id STRING,
            schema_version STRING,
            payload STRING,
            WATERMARK FOR event_timestamp AS event_timestamp - INTERVAL '10' MINUTE
        ) WITH (
            'connector' = 'kinesis',
            'stream' = '{input_stream}',
            'aws.region' = '{region}',
            'scan.stream.initpos' = 'LATEST',
            'format' = 'json'
        )
    """
    table_env.execute_sql(source_ddl)
    
    # Parse payload
    parse_sql = """
        CREATE VIEW parsed_events AS
        SELECT 
            event_name,
            event_timestamp,
            event_id,
            JSON_VALUE(payload, '$.trip_id') as trip_id,
            JSON_VALUE(payload, '$.driver_id') as driver_id,
            JSON_VALUE(payload, '$.rider_id') as rider_id,
            CAST(JSON_VALUE(payload, '$.start_latitude') AS DOUBLE) as start_lat,
            CAST(JSON_VALUE(payload, '$.start_longitude') AS DOUBLE) as start_lon,
            CAST(JSON_VALUE(payload, '$.end_latitude') AS DOUBLE) as end_lat,
            CAST(JSON_VALUE(payload, '$.end_longitude') AS DOUBLE) as end_lon,
            CAST(JSON_VALUE(payload, '$.actual_fare') AS DOUBLE) as fare,
            CAST(JSON_VALUE(payload, '$.actual_duration') AS INT) as duration
        FROM ride_events
        WHERE JSON_VALUE(payload, '$.trip_id') IS NOT NULL
    """
    table_env.execute_sql(parse_sql)
    
    # Sink: S3 (micro-batches)
    sink_ddl = f"""
        CREATE TABLE trip_output (
            trip_id STRING,
            driver_id STRING,
            rider_id STRING,
            start_time TIMESTAMP(3),
            end_time TIMESTAMP(3),
            start_lat DOUBLE,
            start_lon DOUBLE,
            end_lat DOUBLE,
            end_lon DOUBLE,
            fare DOUBLE,
            duration INT,
            trip_status STRING
        ) WITH (
            'connector' = 'filesystem',
            'path' = '{output_path}',
            'format' = 'parquet',
            'sink.rolling-policy.file-size' = '128MB',
            'sink.rolling-policy.rollover-interval' = '5min'
        )
    """
    table_env.execute_sql(sink_ddl)
    
    # Sessionization query
    sessionize_sql = """
        INSERT INTO trip_output
        SELECT 
            trip_id,
            FIRST_VALUE(driver_id) as driver_id,
            FIRST_VALUE(rider_id) as rider_id,
            MIN(CASE WHEN event_name = 'trip_started' THEN event_timestamp END) as start_time,
            MAX(CASE WHEN event_name = 'trip_completed' THEN event_timestamp END) as end_time,
            FIRST_VALUE(start_lat) as start_lat,
            FIRST_VALUE(start_lon) as start_lon,
            LAST_VALUE(end_lat) as end_lat,
            LAST_VALUE(end_lon) as end_lon,
            MAX(fare) as fare,
            MAX(duration) as duration,
            CASE 
                WHEN MAX(CASE WHEN event_name = 'trip_completed' THEN 1 ELSE 0 END) = 1 
                THEN 'COMPLETED'
                ELSE 'IN_PROGRESS'
            END as trip_status
        FROM parsed_events
        GROUP BY trip_id, SESSION(event_timestamp, INTERVAL '2' HOUR)
        HAVING COUNT(*) >= 2  -- At least 2 events per trip
    """
    
    # Execute
    table_env.execute_sql(sessionize_sql)
    
    print("✅ Flink streaming application started")
    print(f"   Input: {input_stream}")
    print(f"   Output: {output_path}")

if __name__ == '__main__':
    create_streaming_app()
```

### 5. Redshift Loader for Streaming Data

```python
"""
redshift_streaming_loader.py
Lambda function to load Flink output to Redshift

Trigger: S3 event (new Parquet files from Flink)
Action: COPY to streaming.trips table
Frequency: Every 5-10 minutes
"""

import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
redshift_data = boto3.client('redshift-data')

WORKGROUP_NAME = os.environ['REDSHIFT_WORKGROUP']
DATABASE = os.environ['REDSHIFT_DATABASE']
IAM_ROLE = os.environ['REDSHIFT_IAM_ROLE']

def lambda_handler(event, context):
    """
    Load new Parquet files from S3 to Redshift
    
    Strategy:
    1. Get S3 path from event
    2. COPY to staging table
    3. MERGE into streaming.trips (UPSERT)
    4. Cleanup staging
    """
    
    # Parse S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    s3_path = f"s3://{bucket}/{key}"
    
    print(f"Processing: {s3_path}")
    
    # COPY to staging
    copy_sql = f"""
    BEGIN TRANSACTION;
    
    -- Truncate staging
    TRUNCATE TABLE streaming.trips_staging;
    
    -- COPY from S3
    COPY streaming.trips_staging
    FROM '{s3_path}'
    IAM_ROLE '{IAM_ROLE}'
    FORMAT AS PARQUET;
    
    -- MERGE into main table (UPSERT)
    DELETE FROM streaming.trips
    USING streaming.trips_staging
    WHERE streaming.trips.trip_id = streaming.trips_staging.trip_id;
    
    INSERT INTO streaming.trips
    SELECT * FROM streaming.trips_staging;
    
    END TRANSACTION;
    """
    
    # Execute
    response = redshift_data.execute_statement(
        WorkgroupName=WORKGROUP_NAME,
        Database=DATABASE,
        Sql=copy_sql
    )
    
    statement_id = response['Id']
    
    print(f"✅ COPY initiated: {statement_id}")
    
    return {
        'statusCode': 200,
        'body': f'Loaded {s3_path}'
    }
```

---

## Data Quality & Governance

### Data Quality Framework

```python
"""
data_quality_checks.py
Great Expectations integration for data quality

Runs after each Silver layer job
Validates:
- Schema compliance
- Business rules
- Data freshness
- Referential integrity
"""

import great_expectations as gx
from great_expectations.core.batch import Batch
from pyspark.sql import SparkSession

class TripDataQualityChecker:
    """
    Data quality checks for Silver layer trips
    
    Expectations:
    1. trip_id is unique
    2. start_time < end_time
    3. fare_amount > 0 and < $10,000
    4. trip_duration between 1 minute and 24 hours
    5. No nulls in required fields
    6. Data freshness (last event < 48 hours old)
    """
    
    def __init__(self, spark, silver_path):
        self.spark = spark
        self.silver_path = silver_path
        self.context = gx.get_context()
    
    def run_quality_checks(self):
        """Execute all data quality expectations"""
        
        print("=== Running Data Quality Checks ===")
        
        # Read Silver data
        trips_df = self.spark.read.format("delta").load(self.silver_path)
        
        # Create GX batch
        batch = self.context.sources.add_spark("trips_source").add_dataframe_asset(
            name="trips_asset",
            dataframe=trips_df
        )
        
        # Define expectations
        expectations = self._define_expectations()
        
        # Validate
        results = batch.validate(expectations)
        
        # Check results
        if results["success"]:
            print("✅ All quality checks passed")
        else:
            print("❌ Quality checks failed:")
            for result in results["results"]:
                if not result["success"]:
                    print(f"  - {result['expectation_config']['expectation_type']}")
                    print(f"    {result.get('result', {})}")
        
        # Send to monitoring
        self._publish_metrics(results)
        
        return results["success"]
    
    def _define_expectations(self):
        """Define data quality expectations"""
        
        suite = self.context.add_expectation_suite("trip_quality_suite")
        
        # Uniqueness
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToBeUnique(column="trip_id")
        )
        
        # Non-null required fields
        for col in ["trip_id", "driver_id", "rider_id", "start_time", "fare_amount"]:
            suite.add_expectation(
                gx.expectations.ExpectColumnValuesToNotBeNull(column=col)
            )
        
        # Business rules
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToBeBetween(
                column="fare_amount",
                min_value=0.01,
                max_value=10000
            )
        )
        
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToBeBetween(
                column="trip_duration_seconds",
                min_value=60,
                max_value=86400
            )
        )
        
        # Logical consistency
        suite.add_expectation(
            gx.expectations.ExpectColumnPairValuesAToBeGreaterThanB(
                column_A="end_time",
                column_B="start_time"
            )
        )
        
        # Freshness
        suite.add_expectation(
            gx.expectations.ExpectColumnMaxToBeBetween(
                column="last_event_time",
                min_value="NOW() - INTERVAL '48 HOURS'"
            )
        )
        
        return suite
    
    def _publish_metrics(self, results):
        """Publish DQ metrics to CloudWatch"""
        
        cloudwatch = boto3.client('cloudwatch')
        
        cloudwatch.put_metric_data(
            Namespace='RideHailing/DataQuality',
            MetricData=[
                {
                    'MetricName': 'QualityChecksPassed',
                    'Value': 1 if results["success"] else 0,
                    'Unit': 'Count'
                },
                {
                    'MetricName': 'TotalChecks',
                    'Value': len(results["results"]),
                    'Unit': 'Count'
                },
                {
                    'MetricName': 'FailedChecks',
                    'Value': sum(1 for r in results["results"] if not r["success"]),
                    'Unit': 'Count'
                }
            ]
        )
```

### Data Lineage & Governance

```python
"""
data_lineage.py
Track data lineage from source to consumption

Tools: AWS Glue Data Catalog + Apache Atlas (optional)
"""

import boto3

glue = boto3.client('glue')

def register_lineage():
    """
    Register data lineage in Glue Data Catalog
    
    Lineage:
    Kinesis → S3 Raw → Bronze → Silver → Gold → Redshift
    """
    
    # Register tables in Glue Catalog
    glue.create_table(
        DatabaseName='ride_hailing',
        TableInput={
            'Name': 'bronze_events',
            'StorageDescriptor': {
                'Location': 's3://ride-hailing-datalake/bronze/events/',
                'InputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat',
                'OutputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat',
                'SerdeInfo': {
                    'SerializationLibrary': 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
                }
            },
            'PartitionKeys': [
                {'Name': 'event_date', 'Type': 'date'}
            ],
            'Parameters': {
                'classification': 'parquet',
                'source': 'kinesis_firehose',
                'pii_data': 'false',
                'retention': 'forever'
            }
        }
    )
    
    glue.create_table(
        DatabaseName='ride_hailing',
        TableInput={
            'Name': 'silver_trips',
            'StorageDescriptor': {
                'Location': 's3://ride-hailing-datalake/silver/trips/',
                'InputFormat': 'org.apache.hadoop.mapred.SequenceFileInputFormat',
                'OutputFormat': 'org.apache.hadoop.hive.ql.io.HiveSequenceFileOutputFormat',
                'SerdeInfo': {
                    'SerializationLibrary': 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
                }
            },
            'PartitionKeys': [
                {'Name': 'trip_date', 'Type': 'date'}
            ],
            'Parameters': {
                'classification': 'delta',
                'source': 'bronze_events',
                'transformation': 'sessionization',
                'pii_data': 'true',
                'retention': '13_months'
            }
        }
    )
    
    print("✅ Lineage registered in Glue Data Catalog")
```

---

## Interview Q&A

### Question 1: Late Arriving Data

**Interviewer:** "You mentioned handling late-arriving data by processing a 48-hour window. What if an event arrives 3 days late? How does your design handle that, and what is the impact on the 'gold' tables and the dashboards?"

**Answer:**

```
My approach uses watermarking and Delta Lake's MERGE capability:

1. **Watermarking (48-hour threshold):**
   - Daily Spark job defines: "Any data older than 48 hours is truly late"
   - This is based on our observed latency: 99.9% of events arrive within 6 hours
   
2. **Delta Lake MERGE (handles late arrivals):**
   When the daily job runs, it processes the last 48 hours:
   
   ```python
   silver_table.merge(
       new_data,
       "target.trip_id = source.trip_id"
   ).whenMatchedUpdateAll()  # Update existing trip if 3-day-old event arrives
    .whenNotMatchedInsertAll()  # Insert new trips
    .execute()
   ```
   
   If a 3-day-old trip_completed event arrives:
   - Job finds existing trip record (from trip_started 3 days ago)
   - Updates: end_time, fare_amount, trip_status → "COMPLETED"
   - Atomic transaction (ACID) ensures consistency
   
3. **Downstream Impact (Gold tables):**
   - Gold tables are aggregations built from Silver
   - When Silver.trips updates, Gold needs recomputation for affected period
   - Orchestrator (Airflow/Dagster) detects Silver change
   - Triggers backfill: Recompute Gold for that day
   
   Example:
   ```python
   # Day 1: Trip starts
   # Gold.trips_per_hour: City A, 10 AM → 100 trips
   
   # Day 4: trip_completed event arrives (3 days late)
   # Silver.trips updates (trip now COMPLETED)
   # Orchestrator detects change
   # Backfill Gold for Day 1, 10 AM:
   #   Old: 100 trips (some IN_PROGRESS)
   #   New: 100 trips (all COMPLETED) ← Updated!
   ```
   
4. **Dashboard Impact:**
   - This means past day metrics might change slightly
   - We communicate "eventual consistency" to stakeholders
   - For yesterday's data: May see +/- 0.1% change as late events arrive
   - After 48 hours: Data is finalized (99.9% confidence)
   
5. **Trade-off:**
   - Holding back processing until all data arrives → impossible
   - Accept eventual consistency → practical
   - Business accepts this for analytics use case
   - For financial reconciliation: Separate nightly job with longer window

This design prioritizes:
✓ Fast initial results (daily dashboards)
✓ Eventual accuracy (late events don't break anything)
✓ Transparency (users know data may adjust slightly)
```

### Question 2: Streaming vs Batch Consistency

**Interviewer:** "You mentioned the streaming path for 15-minute latency. How do you ensure consistency with the batch pipeline? The biggest challenge is that we now have two different codebases (Spark for batch, Flink for streaming) creating trip data. This can lead to discrepancies."

**Answer:**

```
Excellent question. This is the core challenge of Lambda Architecture.

My solution: "Batch as Source of Truth" with daily reconciliation.

# CONSISTENCY STRATEGY

## 1. Streaming Layer (Redshift: streaming.trips)

- Fast, provisional results
- Lives in separate schema
- TTL: 24 hours only
- Users: City ops (need speed > perfect accuracy)

## 2. Batch Layer (Redshift: batch.trips)

- Complete, accurate results
- Source of truth
- Retention: 13 months
- Users: Executives, BI, ML teams

## 3. Daily Reconciliation Process (runs at 2 AM)

### Step A: Batch pipeline completes

- Processes all events (including late arrivals)
- Updates Silver Delta Lake
- Load to batch.trips table

### Step B: Overwrite streaming data

- TRUNCATE streaming.trips (discard last 24h provisional data)
- Backfill from batch.trips for last 24h (ensures consistency)

### Step C: Gold tables

- Built ONLY from batch.trips (never from streaming)

## 4. Query Pattern (BI Views)
```sql
CREATE VIEW unified_trips AS
SELECT * FROM streaming.trips
  WHERE trip_start >= CURRENT_DATE - 1
UNION ALL
SELECT * FROM batch.trips
  WHERE trip_start < CURRENT_DATE - 1;
```

**Why This Works:**

1. **Single Source of Truth:** Batch pipeline owns all data > 24 hours old
2. **No Drift:** Daily reconciliation prevents long-term discrepancies
3. **Fast Feedback:** Streaming gives 15-min latency for city ops
4. **Accuracy:** Executives/BI see batch-corrected data

**Real Example:**

Day 1 (10 AM):
- Streaming: Reports 1,000 trips (some events missed due to network)
- City ops sees 1,000 trips on their dashboard

Day 2 (2 AM):
- Batch processes Day 1 completely (found 1,050 trips)
- Reconciliation: Overwrites streaming.trips for Day 1
- New unified view: 1,050 trips

Day 2 (10 AM):
- BI dashboard now shows correct 1,050 trips for Day 1
- Yesterday's number adjusted by +50 (+5%)
- Stakeholders understand this "eventual consistency"

**Preventing Confusion:**

1. **Labeling in Dashboards:**
   - "Last 24 hours: Preliminary (may adjust)"
   - "Older: Final"

2. **Separate Tables:**
   - streaming.* (provisional)
   - batch.* (authoritative)
   - gold.* (built from batch only)

3. **Data Contracts:**
   - Streaming SLA: 15-min latency, ~99% accuracy
   - Batch SLA: 24-hr latency, 100% accuracy

4. **Monitoring:**
   ```python
   # Alert if discrepancy > 1%
   discrepancy = abs(streaming_count - batch_count) / batch_count
   if discrepancy > 0.01:
       alert("Streaming/Batch divergence detected")
   ```

**Alternative Considered (Rejected):**

Option: Make Flink code identical to Spark (same logic)
Why Rejected:
- Still doesn't prevent discrepancies (different execution engines)
- Doubles maintenance (keep two codebases in sync)
- Complexity > benefit

Chosen Approach:
- Accept that two pipelines will differ slightly
- Use reconciliation to converge to truth
- Communicate trade-offs to stakeholders

**Key Insight:**
Lambda Architecture isn't about making streaming and batch identical.
It's about leveraging their strengths (speed vs. accuracy) and 
reconciling them into a consistent final view.
```

### Question 3: Data Quality Debugging

**Interviewer:** "A city operations manager calls you, furious, saying the 'driver utilization' metric for San Francisco dropped by 50% overnight, and they think the data is wrong. How do you debug this? What tools or processes should be in place?"

**Answer:**

```
Critical scenario! Trust is paramount. My multi-layered debugging approach:

# DEBUGGING FRAMEWORK: Driver Utilization Drop

## 1. PROACTIVE PREVENTION (Before Issues Occur)

### a) Schema Contracts (Confluent Schema Registry)

- App teams register schemas with Avro/Protobuf
- Schema evolution checked at ingestion
- Prevents: New app version breaking schema
```python
# AWS Glue Schema Registry
schema_registry = SchemaRegistryClient()
schema_registry.validate(event, "trip_started_v2.1")
# Rejects malformed data before it enters pipeline
```

### b) Data Quality Tests (Great Expectations / dbt)

Run after Silver layer creation:
```python
# Automated checks
expect_column_values_to_not_be_null("driver_id")
expect_column_values_to_be_between(
    "fare_amount", min=0, max=10000
)
# Freshness check
expect_table_row_count_to_be_between(
    min_value=yesterday_count * 0.9,
    max_value=yesterday_count * 1.1
)
```

If checks fail → Halt pipeline, alert on-call engineer

### c) Monitoring Dashboards (Airflow/CloudWatch)

- Kinesis IncomingBytes (dropped?)
- Glue job failures
- Row count trends (anomaly detection)

## 2. REACTIVE DEBUGGING (When Issue Reported)

### a) Data Lineage (Immediate triage)

Use AWS Glue Data Catalog or tool to trace:
```
driver_utilization (Gold) ← silver.trips ← bronze.events
```

Question: Which layer is wrong?

### b) Query Bronze Layer (Raw Truth)
```sql
-- Check raw event volume for SF
SELECT event_date, event_name, COUNT(*)
FROM bronze.events
WHERE JSON_VALUE(payload, '$.city') = 'San Francisco'
  AND event_date BETWEEN '2025-01-17' AND '2025-01-18'
GROUP BY event_date, event_name;

-- Look for anomaly
-- Expected: ~1M events/day
-- Actual: 500K? → Data source issue
--         1M? → Logic issue
```

### c) Check Silver Layer (Business Logic)
```sql
-- Validate sessionization
SELECT trip_date, trip_status, COUNT(*)
FROM silver.trips
WHERE trip_date IN ('2025-01-17', '2025-01-18')
  AND JSON_VALUE(metadata, '$.city') = 'San Francisco'
GROUP BY trip_date, trip_status;

-- Are trips being marked IN_PROGRESS instead of
-- COMPLETED? (missing trip_completed events)
```

### d) Dashboarding & Monitoring

Pipeline health dashboard showing:
- Input volume by city (detect if SF specifically low)
- Event type distribution (missing trip_completed?)
- Processing lag (data stuck?)

### e) Time-Travel (Delta Lake)
```python
# Compare yesterday vs today
yesterday = spark.read \
    .format("delta") \
    .option("versionAsOf", 245) \  # Previous version
    .load("silver/trips")

today = spark.read.format("delta").load("silver/trips")

# Schema changed? New filter added?
yesterday.schema == today.schema
```

## 3. ROOT CAUSE SCENARIOS & FIXES

**Scenario A: New App Version Sends Null driver_ids**
Detection: Bronze shows 50% null driver_id for SF
Fix: Alert app team, rollback app, filter nulls temporarily

**Scenario B: Code Change in Silver Layer**
Detection: Bronze OK, Silver wrong
Fix: Rollback Silver job, backfill affected dates

**Scenario C: Upstream Kinesis Issue**
Detection: CloudWatch shows 50% drop in IncomingBytes
Fix: AWS Support ticket, backfill from app logs if available

## 4. COMMUNICATION

**Immediate Response (within 30 min):**
"Investigating. Checking data lineage..."

**Update (within 2 hours):**
"Root cause identified: [X]. Fix in progress. Expected resolution: [Y hours]."

**Resolution (within 24 hours):**
"Issue fixed. Data backfilled. Preventive measures: [Z]."

---

**Tools in the Stack:**

1. **Proactive:**
   - AWS Glue Schema Registry / Confluent Schema Registry
   - Great Expectations (data quality tests)
   - dbt tests (SQL-based quality checks)
   - Airflow DAG monitoring

2. **Reactive:**
   - AWS Glue Data Catalog (lineage)
   - Athena (ad-hoc Bronze layer queries)
   - Delta Lake time travel
   - Redshift query history
   - CloudWatch metrics & alarms

3. **Communication:**
   - Status page (for stakeholders)
   - Slack alerts
   - Postmortem template

**Example Investigation (Real Scenario):**

```python
# Step 1: Check Bronze
bronze_sf = spark.sql("""
    SELECT event_date, COUNT(*) as event_count
    FROM bronze.events
    WHERE event_date IN ('2025-01-17', '2025-01-18')
      AND JSON_VALUE(payload, '$.city') = 'SF'
    GROUP BY event_date
""")
bronze_sf.show()
# Output:
# 2025-01-17: 1,000,000 events ✓
# 2025-01-18:   500,000 events ← Anomaly!

# Root cause: Upstream Kinesis shard split caused data loss
# Fix: AWS Support ticket + backfill from app logs

# Step 2: Communication
send_slack_alert(
    channel="#data-incidents",
    message="SF metrics drop caused by Kinesis data loss on 2025-01-18. "
            "Backfilling from app logs. ETA: 4 hours."
)

# Step 3: Backfill
backfill_from_app_logs(
    city="SF",
    start_date="2025-01-18",
    end_date="2025-01-18"
)

# Step 4: Recompute Gold
trigger_gold_backfill(
    table="driver_utilization",
    date="2025-01-18"
)
```

**Key Insight:**

The 50% drop is NEVER "just bad data" - it's either:
1. Real business change (SF concert caused surge?)
2. Data quality issue (schema change, app bug)
3. Pipeline issue (Glue job failed, Kinesis shard issue)

My approach:
✓ Assume guilty until proven innocent (check lineage)
✓ Bronze layer is source of truth (raw data doesn't lie)
✓ Time-travel for regression testing
✓ Clear communication with stakeholders
```

---

## Cost Summary

### Monthly Infrastructure Costs

```yaml
Ingestion:
  kinesis_data_streams: $550
  kinesis_firehose: $100
  subtotal: $650

Storage:
  s3_landing: $450 (Standard, 7 days)
  s3_bronze: $300 (Intelligent Tiering)
  s3_silver: $400 (Intelligent Tiering + Delta)
  s3_gold: $200 (Intelligent Tiering)
  s3_archival: $200 (Glacier, >90 days)
  subtotal: $1,550

Batch Processing:
  glue_bronze: $300 (hourly jobs)
  glue_silver: $400 (daily jobs)
  glue_gold: $200 (daily jobs)
  subtotal: $900

Streaming Processing:
  kinesis_data_analytics: $600 (5-15 KPUs)
  lambda_loader: $50 (Redshift COPY)
  subtotal: $650

Serving Layer:
  redshift_cluster: $2,000 (ra3.xlplus, 4 nodes)
  subtotal: $2,000

Monitoring:
  cloudwatch: $100
  great_expectations: $50 (compute)
  subtotal: $150

TOTAL MONTHLY COST: $5,900

Annual Cost: $70,800
```

### Cost Optimization Opportunities

```
1. Spot Instances for Glue:
   - Current: $900/month (on-demand)
   - With Spot (70% discount): $270/month
   - Savings: $630/month = $7,560/year

2. S3 Intelligent Tiering:
   - Automatically moves cold data to cheaper tiers
   - Already included in estimates above

3. Redshift Reserved Instances:
   - Current: $2,000/month (on-demand)
   - With 1-year RI (40% discount): $1,200/month
   - Savings: $800/month = $9,600/year

4. Kinesis Auto-scaling:
   - Already using (scales down during off-peak)
   - Saves ~30% vs fixed capacity

Total Potential Savings: $17,160/year
Optimized Annual Cost: $53,640
```

---

## Summary

This design provides:

✅ **Dual Latency:** 15-min (streaming) + 24-hr (batch)  
✅ **Medallion Architecture:** Bronze → Silver → Gold  
✅ **Data Quality:** Great Expectations, schema validation  
✅ **Scalability:** 500M events/day, handles 3x spikes  
✅ **Cost-Optimized:** $5,900/month (~$70K/year)  
✅ **Lambda Architecture:** Batch as source of truth, streaming for speed  
✅ **Late Data Handling:** 48-hour window with Delta Lake MERGE  
✅ **Interview-Ready:** Complete answers to all likely questions 

**Key Differentiators:**
- Batch is source of truth (prevents streaming drift)
- Delta Lake for ACID + time travel
- Great Expectations for automated DQ
- Schema evolution via envelope pattern
- Clear separation: streaming.* vs batch.*

This architecture is production-ready and covers all aspects discussed in the interview!