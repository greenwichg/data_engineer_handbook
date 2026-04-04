# Ride-Hailing Data Platform - Complete System Design Interview Solution
## MAANG-Level Interview Case Study with Lambda Architecture

---

## Table of Contents
1. [Problem Statement & Requirements](#problem-statement--requirements)
2. [Clarifying Questions & Answers](#clarifying-questions--answers)
3. [High-Level Architecture](#high-level-architecture)
4. [Detailed Component Design](#detailed-component-design)
5. [Implementation Details](#implementation-details)
6. [Data Quality & Governance](#data-quality--governance)
7. [Handling Edge Cases](#handling-edge-cases)
8. [Monitoring & Operations](#monitoring--operations)
9. [Interview Questions & Answers](#interview-questions--answers)

---

## Problem Statement & Requirements

### Business Context

**Company**: Large ride-hailing company operating in hundreds of cities globally

**Challenge**: Design a core data platform to process and analyze trip data

**Primary Goal**: Generate key business metrics for city operations teams:
- Trips per hour
- Driver utilization
- Surge pricing effectiveness

### Data Characteristics

**Event Generation:**
```
Single Trip Lifecycle:
├── trip_requested
├── driver_assigned
├── driver_arrived
├── trip_started
├── trip_completed
└── payment_processed
```

**Volume:**
- **Daily**: 500 million events
- **Data Size**: 2-3 terabytes of raw JSON per day
- **Event Size**: ~4-6 KB per event (JSON)
- **Peak Load**: Rush hour (5-7 PM, 7-9 AM)

**Format:**
- Raw JSON events from driver and rider mobile apps
- Schema evolves quarterly (new fields added)
- No mature schema registry in place today

---

## Clarifying Questions & Answers

### Q1: Latency Requirements

**Question:** How fresh does the data on these dashboards need to be? Are the city ops teams okay with data that is 24 hours old, or do they need near real-time visibility, say, within 5-15 minutes?

**Answer:** 
> **Dual-use case:**
> - **Executive-level dashboards**: 24-hour delay is fine
> - **City operations teams**: Need to react to live events (e.g., concert ending, subway shutting down)
> - **Target latency for ops**: 15 minutes

**Implication:** This suggests a **Lambda Architecture** with both batch and streaming paths.

---

### Q2: Consumers

**Question:** Are the primary consumers BI analysts running ad-hoc queries and viewing dashboards (e.g., in Tableau or Looker), or are there also machine learning teams that need this data for model training?

**Answer:**
> **Primarily**: BI and Operations
> **Future**: Fraud detection ML team has expressed interest
> **Current focus**: BI and operational dashboards

**Implication:** Optimize for analytical queries, but design with ML extensibility in mind.

---

### Q3: Data Schema

**Question:** You mentioned JSON events. Is the schema stable, or does it evolve frequently as the app teams add new features? Is there a central schema registry?

**Answer:**
> - Schema **evolves** but not chaotically
> - Expect new fields added **quarterly**
> - **No mature schema registry** today
> - Pipeline should be **resilient to schema changes**

**Implication:** Need schema evolution handling (envelope pattern, versioning).

---

### Q4: Historical Data

**Question:** How far back do we need to store queryable data? A year? Five years? Indefinitely? This will impact storage choices.

**Answer:**
> - **Raw data**: Keep **forever** (compliance)
> - **Queryable "hot" data**: At least **13 months** for dashboards
> - **Compliance**: Legal and regulatory requirements

**Implication:** Tiered storage strategy (hot/warm/cold).

---

### Q5: Technology Stack

**Question:** Is this a greenfield project, or are we building on an existing cloud platform like AWS, GCP, or Azure? Are there any preferred technologies I should consider?

**Answer:**
> - **Cloud**: AWS
> - **Preference**: Managed services to reduce operational overhead
> - **Philosophy**: Less ops burden = more time on data quality

**Implication:** Favor AWS managed services (Kinesis, Glue, EMR, Redshift).

---

## High-Level Architecture

### Lambda Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          DATA SOURCES                                   │
│                                                                         │
│  ┌──────────────────────┐           ┌──────────────────────┐            │
│  │    Driver Apps       │           │     Rider Apps       │            │
│  │  - iOS/Android       │           │  - iOS/Android       │            │
│  │  - Location updates  │           │  - Trip requests     │            │
│  │  - Status changes    │           │  - Ratings           │            │
│  └──────────┬───────────┘           └───────────┬──────────┘            │
└─────────────┼───────────────────────────────────┼───────────────────────┘
              │                                   │
              │   500M events/day (2-3 TB JSON)   │
              │                                   │
              └───────────────┬───────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      INGESTION LAYER                                    │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │           Amazon Kinesis Data Streams                          │     │
│  │  - Shards: 50-100 (auto-scaling)                               │     │
│  │  - Partition Key: driver_id / rider_id                         │     │
│  │  - Retention: 24 hours (for replay)                            │     │
│  │  - Throughput: ~6,000 events/sec avg, 12,000 peak              │     │
│  │                                                                │     │
│  │  Event Envelope (Schema Evolution):                            │     │
│  │  {                                                             │     │
│  │    "event_name": "trip_started",                               │     │
│  │    "event_timestamp": "2025-01-18T10:30:00.000Z",              │     │
│  │    "schema_version": "v2.1",                                   │     │
│  │    "payload": { ... actual event data ... }                    │     │
│  │  }                                                             │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  Cost: ~$1,200/month (100 shards × 730 hours × $0.015)                  │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │
                ┌─────────────┴──────────────┐
                │                            │
                ▼                            ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│      BATCH PATH              │  │    STREAMING PATH            │
│   (24-hour latency)          │  │   (15-minute latency)        │
│                              │  │                              │
│  Purpose:                    │  │  Purpose:                    │
│  ✓ Source of truth           │  │  ✓ Live operational metrics  │
│  ✓ 100% data accuracy        │  │  ✓ Fast, provisional data    │
│  ✓ Executive dashboards      │  │  ✓ City ops dashboards       │
│  ✓ ML training data          │  │  ✓ Real-time alerts          │
│                              │  │                              │
│  Consumer: Executives, ML    │  │  Consumer: City ops teams    │
└──────────────────────────────┘  └──────────────────────────────┘
                │                            │
                │                            │
                ▼                            ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│  BATCH PROCESSING            │  │  STREAM PROCESSING           │
│                              │  │                              │
│  Firehose → S3 → Spark       │  │  Flink (KDA) → Redshift      │
│  Bronze → Silver → Gold      │  │  Stateful, windowed          │
└──────────────────────────────┘  └──────────────────────────────┘
                │                            │
                │                            │
                ▼                            ▼
┌──────────────────────────────┐  ┌──────────────────────────────┐
│  SERVING LAYER (BATCH)       │  │  SERVING LAYER (STREAMING)   │
│                              │  │                              │
│  Redshift / Athena           │  │  Redshift (live tables)      │
│  13 months queryable         │  │  Last 24 hours               │
│  Gold tables                 │  │  Overwritten daily by batch  │
└──────────────────────────────┘  └──────────────────────────────┘
                │                            │
                └────────────┬───────────────┘
                             │
                             ▼
              ┌───────────────────────────────┐
              │    BI & ANALYTICS LAYER       │
              │  - Tableau / Looker           │
              │  - Custom dashboards          │
              │  - Ad-hoc queries             │
              └───────────────────────────────┘
```

### Architecture Decisions Summary

| Component | Technology Choice | Rationale |
|-----------|------------------|-----------|
| **Ingestion** | Kinesis Data Streams | Fully managed, auto-scaling, AWS-native |
| **Batch Storage** | S3 + Parquet + Delta Lake | Cost-effective, ACID transactions, time travel |
| **Batch Processing** | Apache Spark on EMR/Glue | Flexible transformations, stateful processing |
| **Stream Processing** | Flink on Kinesis Data Analytics | Managed Flink, stateful stream processing |
| **Serving (Hot)** | Amazon Redshift | Fast analytical queries, BI tool integration |
| **Serving (Cold)** | S3 + Athena | Cost-effective for historical queries |
| **Orchestration** | AWS Step Functions / Airflow | Managed workflow, monitoring |

---

## Detailed Component Design

### 1. Ingestion Layer: Kinesis Data Streams

#### Configuration

```python
kinesis_config = {
    "stream_name": "ride-hailing-events",
    "shards": {
        "initial": 50,
        "auto_scaling": {
            "enabled": True,
            "min": 50,
            "max": 200,
            "target_utilization": 70  # Scale at 70% utilization
        }
    },
    "retention_period_hours": 24,  # For replay capability
    "encryption": {
        "type": "KMS",
        "key_id": "arn:aws:kms:us-east-1:xxx:key/xxx"
    },
    "enhanced_monitoring": True
}
```

#### Event Envelope Pattern (Schema Evolution)

```json
{
  "event_name": "trip_started",
  "event_id": "evt_7xk2p9m3n4",
  "event_timestamp": "2025-01-18T10:30:15.234Z",
  "schema_version": "v2.1",
  "app_version": "ios-4.5.2",
  "payload": {
    "trip_id": "trip_abc123",
    "driver_id": "drv_xyz789",
    "rider_id": "rid_def456",
    "pickup_location": {
      "latitude": 37.7749,
      "longitude": -122.4194,
      "address": "123 Market St, SF"
    },
    "estimated_fare": 15.50,
    "surge_multiplier": 1.5,
    "vehicle_type": "uberX"
  }
}
```

**Why envelope pattern?**
- Metadata (event_name, timestamp, schema_version) separate from payload
- Easy schema evolution tracking
- Enables schema validation at ingestion
- Helps with debugging (app_version tracking)

---

### 2. Batch Path (24-Hour Latency)

#### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        BATCH PATH PIPELINE                              │
│                                                                         │
│  Step 1: Kinesis → S3 (Landing Zone)                                    │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  Kinesis Data Firehose                                         │     │
│  │  - Buffer: 15 minutes OR 128 MB (whichever first)              │     │
│  │  - Compression: GZIP                                           │     │
│  │  - Format: JSON (raw, as received)                             │     │
│  │  - Output: s3://bucket/raw/events/year=YYYY/month=MM/day=DD/   │     │
│  │            hour=HH/batch-XXX.json.gz                           │     │
│  │                                                                │     │
│  │  Why Firehose?                                                 │     │
│  │  ✓ Fully managed (zero ops)                                    │     │
│  │  ✓ Automatic batching, compression                             │     │
│  │  ✓ Built-in retry logic                                        │     │
│  │  ✓ Creates immutable raw data (audit trail)                    │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                              │                                          │
│                              │ Every hour (scheduled)                   │
│                              ▼                                          │
│  Step 2: JSON → Parquet Conversion (Bronze Layer)                       │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  AWS Glue Job (Spark)                                          │     │
│  │  - Read: s3://bucket/raw/events/ (last 1-2 hours)              │     │
│  │  - Transform: JSON → Parquet (columnar)                        │     │
│  │  - Validation: Schema validation, null checks                  │     │
│  │  - Deduplication: By event_id                                  │     │
│  │  - Write: s3://bucket/bronze/events/event_date=YYYY-MM-DD/     │     │
│  │                                                                │     │
│  │  Why Parquet?                                                  │     │
│  │  ✓ Columnar storage (10x faster queries)                       │     │
│  │  ✓ Better compression (3-5x vs JSON)                           │     │
│  │  ✓ Schema evolution support                                    │     │
│  │  ✓ Native support in Spark, Athena, Redshift Spectrum          │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                              │                                          │
│                              │ Daily (midnight + 1 hour)                │
│                              ▼                                          │
│  Step 3: Event Sessionization (Silver Layer)                            │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  AWS Glue Job / EMR Spark                                      │     │
│  │  - Read: Bronze events (last 24-48 hours)                      │     │
│  │  - Group by trip_id                                            │     │
│  │  - Sessionize: Stitch trip_requested → payment_processed       │     │
│  │  - Business logic: Calculate duration, fare validation         │     │
│  │  - Write: s3://bucket/silver/trips/trip_date=YYYY-MM-DD/       │     │
│  │                                                                │     │
│  │  Format: Delta Lake (ACID on S3)                               │     │
│  │  ✓ ACID transactions                                           │    │
│  │  ✓ Time travel (for debugging)                                 │    │
│  │  ✓ MERGE support (for late-arriving data)                      │    │
│  └────────────────────────────────────────────────────────────────┘     │
│                              │                                          │
│                              │ Daily (after silver layer)               │
│                              ▼                                          │
│  Step 4: Business Aggregations (Gold Layer)                            │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  AWS Glue Job (Spark)                                          │    │
│  │  - Read: Silver trips table                                    │    │
│  │  - Aggregations:                                               │    │
│  │    * Trips per hour (by city, by vehicle type)                 │    │
│  │    * Driver utilization (active hours, trips/hour)             │    │
│  │    * Surge pricing effectiveness                               │    │
│  │  - Write: s3://bucket/gold/metrics/                            │    │
│  │                                                                │    │
│  │  Also: Load to Redshift                                        │    │
│  │  - COPY command from Gold S3                                   │    │
│  │  - UPSERT via staging table                                    │    │
│  │  - Optimize for BI queries                                     │    │
│  └────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────────┘
```

#### Medallion Architecture (Bronze/Silver/Gold)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  BRONZE LAYER: Raw, Validated Events                                    │
│                                                                         │
│  Purpose: Immutable source of truth                                     │
│  Format: Parquet (from JSON)                                            │
│  Partitioning: event_date=YYYY-MM-DD                                    │
│  Retention: Forever (compliance)                                        │
│  Schema: Exactly as received (envelope + payload)                       │
│                                                                         │
│  Example: s3://bucket/bronze/events/event_date=2025-01-18/              │
│  ├── part-00000.parquet                                                 │
│  ├── part-00001.parquet                                                 │
│  └── ...                                                                │
│                                                                         │
│  Transformations:                                                       │
│  ✓ JSON → Parquet conversion                                            │
│  ✓ Schema validation                                                    │
│  ✓ Deduplication (by event_id)                                          │
│  ✓ Add processing_timestamp                                             │
│  ✗ NO business logic                                                    │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ (Stateful processing)
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  SILVER LAYER: Cleaned, Trip-Level Data                                 │
│                                                                         │
│  Purpose: Clean, integrated trip records                                │
│  Format: Delta Lake (Parquet + transaction log)                         │
│  Partitioning: trip_date=YYYY-MM-DD                                     │
│  Retention: 13 months in Redshift, forever in S3                        │
│  Schema: Trip-centric (one row per trip)                                │
│                                                                         │
│  Example: s3://bucket/silver/trips/trip_date=2025-01-18/                │
│                                                                         │
│  Table: silver.trips                                                    │
│  ┌──────────────┬───────────────────────────────────────────────┐       │
│  │ trip_id      │ Primary key                                   │       │
│  │ driver_id    │ Foreign key                                   │       │
│  │ rider_id     │ Foreign key                                   │       │
│  │ start_time   │ From trip_started event                       │       │
│  │ end_time     │ From trip_completed event                     │       │
│  │ start_lat    │ Pickup location                               │       │
│  │ start_lon    │ Pickup location                               │       │
│  │ end_lat      │ Dropoff location                              │       │
│  │ end_lon      │ Dropoff location                              │       │
│  │ fare_amount  │ From payment_processed event                  │       │
│  │ duration_min │ Calculated: end_time - start_time             │       │
│  │ distance_km  │ Calculated from coordinates                   │       │
│  │ surge_mult   │ From trip_requested event                     │       │
│  │ status       │ COMPLETED, CANCELLED, etc.                    │       │
│  └──────────────┴───────────────────────────────────────────────┘       │
│                                                                         │
│  Transformations:                                                       │
│  ✓ Event sessionization (group by trip_id)                              │
│  ✓ Data pivoting (events → columns)                                     │
│  ✓ Business rules (fare validation, duration calculation)               │
│  ✓ Data cleansing (handle nulls, outliers)                              │
└─────────────────────────────────────────────────────────────────────────┘
                              │
                              │ (Aggregations, joins)
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  GOLD LAYER: Business-Ready Metrics                                     │
│                                                                         │
│  Purpose: Dimensional models for BI tools                               │
│  Format: Parquet + Redshift tables                                      │
│  Partitioning: metric_date, city_id                                     │
│  Retention: 13 months (hot), 5 years (warm/cold)                        │
│  Schema: Star schema (fact + dimension tables)                          │
│                                                                         │
│  Tables:                                                                │
│                                                                         │
│  1. fact_hourly_metrics                                                 │
│     ┌─────────────────┬──────────────────────────────────┐              │
│     │ metric_hour     │ Timestamp (hour granularity)     │              │
│     │ city_id         │ Dimension key                    │              │
│     │ vehicle_type    │ Dimension key                    │              │
│     │ trips_count     │ Number of trips                  │              │
│     │ total_fare      │ Sum of fares                     │              │
│     │ avg_duration    │ Average trip duration            │              │
│     │ surge_trips     │ Count of surged trips            │              │
│     │ driver_hours    │ Total driver active hours        │              │
│     │ utilization_pct │ Trips / available driver hours   │              │
│     └─────────────────┴──────────────────────────────────┘              │
│                                                                         │
│  2. dim_city                                                            │
│     ┌─────────────────┬──────────────────────────────────┐              │
│     │ city_id         │ Primary key                      │              │
│     │ city_name       │ San Francisco, New York, etc.    │              │
│     │ country         │ USA, UK, etc.                    │              │
│     │ timezone        │ America/Los_Angeles              │              │
│     └─────────────────┴──────────────────────────────────┘              │
│                                                                         │
│  3. dim_vehicle_type                                                    │
│     ┌─────────────────┬──────────────────────────────────┐              │
│     │ vehicle_type_id │ Primary key                      │              │
│     │ type_name       │ uberX, uberXL, Black             │              │
│     │ base_rate       │ Per-mile rate                    │              │
│     └─────────────────┴──────────────────────────────────┘              │
│                                                                         │
│  Loaded to: Amazon Redshift for BI queries                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### 3. Streaming Path (15-Minute Latency)

#### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     STREAMING PATH PIPELINE                             │
│                                                                         │
│  Kinesis Data Streams                                                   │
│         │                                                               │
│         │ (Continuous consumption)                                      │
│         ▼                                                               │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  Flink on Kinesis Data Analytics                               │     │
│  │                                                                │     │
│  │  Job: Trip Sessionization (Stateful Streaming)                 │     │
│  │  ┌───────────────────────────────────────────────────────────┐ │     │
│  │  │  1. Read from Kinesis                                     │ │     │
│  │  │  2. Maintain in-memory state for active trips             │ │     │
│  │  │  3. Update state as events arrive:                        │ │     │
│  │  │     - trip_requested → Create trip record                 │ │     │
│  │  │     - driver_assigned → Update trip.driver_id             │ │     │
│  │  │     - trip_started → Update trip.start_time               │ │     │
│  │  │     - trip_completed → Finalize trip                      │ │     │
│  │  │  4. Windowing: 2-hour timeout (if no update)              │ │     │
│  │  │  5. Output completed trips                                │ │     │
│  │  └───────────────────────────────────────────────────────────┘ │     │
│  │                                                                │     │
│  │  State Management:                                             │     │
│  │  - State backend: RocksDB (managed by KDA)                     │     │
│  │  - Checkpointing: Every 60 seconds to S3                       │     │
│  │  - Watermarking: 10 minutes (for late arrivals)                │     │
│  │                                                                │     │
│  │  Output:                                                       │     │
│  │  - Micro-batches every 5-10 minutes                            │     │
│  │  - Target: Redshift staging table                              │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                              │                                          │
│                              │ Every 5-10 minutes (micro-batch)         │
│                              ▼                                          │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  Redshift Staging Table: streaming.trips_live                  │     │
│  │  - Receives trip records from Flink                            │     │
│  │  - COPY from S3 (Flink writes to S3 first)                     │     │
│  │  - MERGE into production table every 10 minutes                │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                              │                                          │
│                              ▼                                          │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │  Redshift Production Table: public.trips_realtime              │     │
│  │  - Queryable by BI tools                                       │     │
│  │  - Data freshness: 5-15 minutes                                │     │
│  │  - Retention: Last 24 hours                                    │     │
│  │  - Reconciliation: Overwritten by batch job daily              │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  Cost: ~$700/month (KDA) + $300/month (Redshift micro-batches)          │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Flink Stateful Processing Code

```python
"""
flink_trip_sessionization.py
Kinesis Data Analytics (Flink) job for real-time trip sessionization

Features:
- Stateful processing (maintain active trip state)
- Event-time windowing (2-hour timeout)
- Watermarking (10-minute late arrival tolerance)
- Micro-batch output to Redshift
"""

from pyflink.datastream import StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment, EnvironmentSettings
from pyflink.table.window import Tumble
from pyflink.table.expressions import col, lit
import os

def create_trip_sessionization_job():
    """
    Flink job to sessionize trip events in real-time
    
    Flow:
    1. Read from Kinesis (trip events)
    2. Maintain state for each trip_id
    3. Update state as events arrive
    4. Output completed trips
    5. Write to S3 (for Redshift COPY)
    """
    
    # Create Flink environment (managed by KDA)
    env = StreamExecutionEnvironment.get_execution_environment()
    settings = EnvironmentSettings.new_instance().in_streaming_mode().build()
    table_env = StreamTableEnvironment.create(env, settings)
    
    # Configuration from KDA
    input_stream = os.environ.get('INPUT_STREAM', 'ride-hailing-events')
    output_s3_path = os.environ.get('OUTPUT_S3_PATH', 's3://bucket/streaming/trips/')
    region = os.environ.get('AWS_REGION', 'us-east-1')
    
    # Define source table (Kinesis Data Stream)
    source_ddl = f"""
        CREATE TABLE ride_events (
            event_id STRING,
            event_name STRING,
            event_timestamp TIMESTAMP(3),
            schema_version STRING,
            trip_id STRING,
            driver_id STRING,
            rider_id STRING,
            start_lat DOUBLE,
            start_lon DOUBLE,
            end_lat DOUBLE,
            end_lon DOUBLE,
            fare_amount DOUBLE,
            status STRING,
            WATERMARK FOR event_timestamp AS event_timestamp - INTERVAL '10' MINUTE
        ) WITH (
            'connector' = 'kinesis',
            'stream' = '{input_stream}',
            'aws.region' = '{region}',
            'scan.stream.initpos' = 'LATEST',
            'format' = 'json',
            'json.fail-on-missing-field' = 'false',
            'json.ignore-parse-errors' = 'true'
        )
    """
    table_env.execute_sql(source_ddl)
    
    # Define sink table (S3 for Redshift COPY)
    sink_ddl = f"""
        CREATE TABLE completed_trips (
            trip_id STRING,
            driver_id STRING,
            rider_id STRING,
            start_time TIMESTAMP(3),
            end_time TIMESTAMP(3),
            start_lat DOUBLE,
            start_lon DOUBLE,
            end_lat DOUBLE,
            end_lon DOUBLE,
            fare_amount DOUBLE,
            duration_seconds BIGINT,
            status STRING,
            processing_time TIMESTAMP(3)
        ) WITH (
            'connector' = 'filesystem',
            'path' = '{output_s3_path}',
            'format' = 'parquet',
            'sink.rolling-policy.rollover-interval' = '5min',
            'sink.rolling-policy.check-interval' = '1min'
        )
    """
    table_env.execute_sql(sink_ddl)
    
    # Trip sessionization logic
    # Use SESSION window to group events by trip_id
    sessionization_query = """
        INSERT INTO completed_trips
        SELECT 
            trip_id,
            
            -- Driver and rider (from any event with non-null value)
            FIRST_VALUE(driver_id) FILTER (WHERE driver_id IS NOT NULL) as driver_id,
            FIRST_VALUE(rider_id) FILTER (WHERE rider_id IS NOT NULL) as rider_id,
            
            -- Start time (from trip_started event)
            MIN(CASE WHEN event_name = 'trip_started' THEN event_timestamp END) as start_time,
            
            -- End time (from trip_completed event)
            MAX(CASE WHEN event_name = 'trip_completed' THEN event_timestamp END) as end_time,
            
            -- Start location (from trip_started)
            FIRST_VALUE(start_lat) FILTER (WHERE event_name = 'trip_started') as start_lat,
            FIRST_VALUE(start_lon) FILTER (WHERE event_name = 'trip_started') as start_lon,
            
            -- End location (from trip_completed)
            LAST_VALUE(end_lat) FILTER (WHERE event_name = 'trip_completed') as end_lat,
            LAST_VALUE(end_lon) FILTER (WHERE event_name = 'trip_completed') as end_lon,
            
            -- Fare (from payment_processed)
            MAX(CASE WHEN event_name = 'payment_processed' THEN fare_amount END) as fare_amount,
            
            -- Duration (calculated)
            TIMESTAMPDIFF(
                SECOND,
                MIN(CASE WHEN event_name = 'trip_started' THEN event_timestamp END),
                MAX(CASE WHEN event_name = 'trip_completed' THEN event_timestamp END)
            ) as duration_seconds,
            
            -- Status (from last event)
            LAST_VALUE(status) as status,
            
            -- Processing time (current)
            CURRENT_TIMESTAMP as processing_time
            
        FROM ride_events
        WHERE trip_id IS NOT NULL
        GROUP BY 
            trip_id,
            SESSION(event_timestamp, INTERVAL '2' HOUR)  -- 2-hour timeout
        HAVING 
            -- Only output when we have both start and end
            MIN(CASE WHEN event_name = 'trip_started' THEN 1 END) = 1
            AND MAX(CASE WHEN event_name = 'trip_completed' THEN 1 END) = 1
    """
    
    # Execute query
    table_env.execute_sql(sessionization_query)
    
    print("✅ Flink trip sessionization job started")
    print(f"   Input: Kinesis stream {input_stream}")
    print(f"   Output: S3 {output_s3_path}")
    print(f"   Windowing: 2-hour session timeout")
    print(f"   Watermark: 10-minute late arrival tolerance")

def main():
    """Entry point for KDA application"""
    create_trip_sessionization_job()

if __name__ == '__main__':
    main()
```

---

### 4. Lambda Architecture Consistency Challenge

#### The Problem

```
┌──────────────────────────────────────────────────────────────────┐
│  CHALLENGE: Two Codebases, Potential Discrepancies               │
│                                                                  │
│  Batch Path (Spark):                                             │
│  ├── Sessionization logic in Spark SQL                           │
│  ├── Business rules in Python/Scala                              │
│  └── Result: silver.trips table                                  │
│                                                                  │
│  Streaming Path (Flink):                                         │
│  ├── Sessionization logic in Flink SQL                           │
│  ├── Business rules in Python (PyFlink)                          │
│  └── Result: trips_realtime table                                │
│                                                                  │
│  Risk: Logic diverges → Different trip metrics in each path      │
└──────────────────────────────────────────────────────────────────┘
```

#### The Solution: Batch as Source of Truth

```python
"""
Reconciliation Strategy:
Every 24 hours, the batch pipeline's output OVERWRITES
the streaming pipeline's output for the last 24 hours
"""

# Redshift reconciliation (daily at 2 AM)
reconciliation_sql = """
BEGIN TRANSACTION;

-- Step 1: Backup streaming data (for debugging)
CREATE TABLE IF NOT EXISTS public.trips_realtime_backup_20250118 AS
SELECT * FROM public.trips_realtime
WHERE start_time >= CURRENT_DATE - 1;

-- Step 2: Delete last 24 hours from streaming table
DELETE FROM public.trips_realtime
WHERE start_time >= CURRENT_DATE - 1;

-- Step 3: Insert batch-processed data (source of truth)
INSERT INTO public.trips_realtime
SELECT 
    trip_id,
    driver_id,
    rider_id,
    start_time,
    end_time,
    start_lat,
    start_lon,
    end_lat,
    end_lon,
    fare_amount,
    duration_seconds,
    status,
    CURRENT_TIMESTAMP as processing_time
FROM gold.trips  -- From batch pipeline
WHERE trip_date >= CURRENT_DATE - 1;

-- Step 4: Verify reconciliation
SELECT 
    'Batch count' as source,
    COUNT(*) as trip_count
FROM gold.trips
WHERE trip_date >= CURRENT_DATE - 1

UNION ALL

SELECT 
    'Streaming count (after reconciliation)' as source,
    COUNT(*) as trip_count
FROM public.trips_realtime
WHERE start_time >= CURRENT_DATE - 1;

END TRANSACTION;
"""
```

**Reconciliation Flow:**

```
┌────────────────────────────────────────────────────────────────┐
│  RECONCILIATION TIMELINE                                       │
│                                                                │
│  Day 1:                                                        │
│  ├── 00:00 - 23:59: Streaming path serves live data            │
│  └── 02:00 (next day): Batch job completes                     │
│                                                                │
│  Day 2:                                                        │
│  ├── 02:00: Reconciliation starts                              │
│  ├── 02:05: Batch data overwrites Day 1 streaming data         │
│  └── 02:10: Dashboard now shows 100% accurate Day 1 data       │
│                                                                │
│  Result:                                                       │
│  - Live data: Fast but ~99.5% accurate (streaming)             │
│  - Historical data: 100% accurate (batch corrected)            │
└────────────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### Bronze Layer: JSON to Parquet Conversion

```python
"""
glue_job_json_to_parquet.py
Hourly job to convert raw JSON to Parquet (Bronze layer)

Triggered by: EventBridge (hourly schedule)
Input: s3://bucket/raw/events/year=YYYY/month=MM/day=DD/hour=HH/
Output: s3://bucket/bronze/events/event_date=YYYY-MM-DD/
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col, from_json, to_date, current_timestamp,
    get_json_object, sha2, concat_ws
)
from pyspark.sql.types import StructType, StructField, StringType, TimestampType
from datetime import datetime, timedelta

# Initialize Glue context
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
RAW_BUCKET = "s3://ride-hailing-datalake/raw/events/"
BRONZE_BUCKET = "s3://ride-hailing-datalake/bronze/events/"

def process_hour(processing_hour):
    """
    Process one hour of raw JSON events
    
    Args:
        processing_hour: datetime object for the hour to process
    """
    
    print(f"Processing hour: {processing_hour}")
    
    # Input path (partitioned by year/month/day/hour)
    input_path = (
        f"{RAW_BUCKET}"
        f"year={processing_hour.year}/"
        f"month={processing_hour.month:02d}/"
        f"day={processing_hour.day:02d}/"
        f"hour={processing_hour.hour:02d}/"
    )
    
    print(f"Reading from: {input_path}")
    
    try:
        # Read raw JSON files
        raw_df = spark.read.json(input_path)
        
        if raw_df.count() == 0:
            print(f"No data found for {processing_hour}. Skipping.")
            return
        
        # Extract payload (JSON string within JSON)
        # Event structure: {event_name, event_timestamp, schema_version, payload}
        events_df = raw_df.select(
            col("event_id"),
            col("event_name"),
            to_timestamp(col("event_timestamp")).alias("event_timestamp"),
            col("schema_version"),
            col("app_version"),
            get_json_object(col("payload"), "$.trip_id").alias("trip_id"),
            get_json_object(col("payload"), "$.driver_id").alias("driver_id"),
            get_json_object(col("payload"), "$.rider_id").alias("rider_id"),
            get_json_object(col("payload"), "$.pickup_location.latitude").cast("double").alias("start_lat"),
            get_json_object(col("payload"), "$.pickup_location.longitude").cast("double").alias("start_lon"),
            get_json_object(col("payload"), "$.dropoff_location.latitude").cast("double").alias("end_lat"),
            get_json_object(col("payload"), "$.dropoff_location.longitude").cast("double").alias("end_lon"),
            get_json_object(col("payload"), "$.estimated_fare").cast("double").alias("estimated_fare"),
            get_json_object(col("payload"), "$.actual_fare").cast("double").alias("actual_fare"),
            get_json_object(col("payload"), "$.surge_multiplier").cast("double").alias("surge_multiplier"),
            get_json_object(col("payload"), "$.vehicle_type").alias("vehicle_type"),
            get_json_object(col("payload"), "$.status").alias("status"),
            col("payload")  # Keep full payload for future schema evolution
        )
        
        # Data quality: Filter out invalid events
        valid_events = events_df.filter(
            (col("event_id").isNotNull()) &
            (col("event_name").isNotNull()) &
            (col("event_timestamp").isNotNull()) &
            (col("event_timestamp") <= current_timestamp()) &  # Not future events
            (col("event_timestamp") >= "2024-01-01")  # Not ancient events
        )
        
        # Deduplication by event_id
        deduped_events = valid_events.dropDuplicates(["event_id"])
        
        # Add metadata
        final_df = deduped_events \
            .withColumn("processing_timestamp", current_timestamp()) \
            .withColumn("event_date", to_date(col("event_timestamp"))) \
            .withColumn(
                "row_hash",
                sha2(concat_ws("|", col("event_id"), col("event_name"), col("event_timestamp")), 256)
            )
        
        # Output path (partitioned by event_date)
        output_path = f"{BRONZE_BUCKET}"
        
        # Write as Parquet (partitioned by event_date)
        final_df.write \
            .mode("append") \
            .partitionBy("event_date") \
            .parquet(output_path)
        
        record_count = final_df.count()
        print(f"✅ Processed {record_count:,} events for {processing_hour}")
        print(f"   Written to: {output_path}")
        
    except Exception as e:
        print(f"❌ Error processing {processing_hour}: {str(e)}")
        raise

# Process last 2 hours (to handle late-arriving data)
current_hour = datetime.utcnow().replace(minute=0, second=0, microsecond=0)

for hour_offset in [2, 1]:
    processing_hour = current_hour - timedelta(hours=hour_offset)
    process_hour(processing_hour)

job.commit()
print("✅ Bronze layer conversion complete")
```

### Silver Layer: Trip Sessionization (Batch)

```python
"""
glue_job_trip_sessionization.py
Daily job to create trip-level data from events (Silver layer)

Triggered by: EventBridge (daily at 1 AM)
Input: s3://bucket/bronze/events/
Output: s3://bucket/silver/trips/ (Delta Lake format)
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col, row_number, first, last, min as min_, max as max_,
    when, unix_timestamp, expr, lit
)
from pyspark.sql.window import Window
from delta import *
from datetime import datetime, timedelta

# Initialize
args = getResolvedOptions(sys.argv, ['JOB_NAME'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Enable Delta Lake
builder = SparkSession.builder.appName("TripSessionization") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")

job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
BRONZE_PATH = "s3://ride-hailing-datalake/bronze/events/"
SILVER_PATH = "s3://ride-hailing-datalake/silver/trips/"

def sessionize_trips(start_date, end_date):
    """
    Sessionize trip events into trip records
    
    Process:
    1. Read events from bronze (48-hour window)
    2. Group by trip_id
    3. Pivot events to columns
    4. Calculate trip metrics
    5. Write to Delta Lake (with MERGE for late data)
    """
    
    print(f"Sessionizing trips from {start_date} to {end_date}")
    
    # Read bronze events (48-hour window to handle late arrivals)
    events_df = spark.read.parquet(BRONZE_PATH) \
        .filter(
            (col("event_date") >= start_date) &
            (col("event_date") <= end_date) &
            (col("trip_id").isNotNull())
        )
    
    print(f"Read {events_df.count():,} events")
    
    # Deduplication: Keep latest event_id (in case of duplicates)
    window_spec = Window.partitionBy("event_id").orderBy(col("processing_timestamp").desc())
    events_deduped = events_df \
        .withColumn("row_num", row_number().over(window_spec)) \
        .filter(col("row_num") == 1) \
        .drop("row_num")
    
    # Sessionization: Group by trip_id and pivot events
    trips_df = events_deduped.groupBy("trip_id").agg(
        # Driver and rider (from any non-null event)
        first(when(col("driver_id").isNotNull(), col("driver_id")), ignorenulls=True).alias("driver_id"),
        first(when(col("rider_id").isNotNull(), col("rider_id")), ignorenulls=True).alias("rider_id"),
        
        # Start time (from trip_started event)
        min_(when(col("event_name") == "trip_started", col("event_timestamp"))).alias("start_time"),
        
        # End time (from trip_completed event)
        max_(when(col("event_name") == "trip_completed", col("event_timestamp"))).alias("end_time"),
        
        # Start location
        first(when(col("event_name") == "trip_started", col("start_lat")), ignorenulls=True).alias("start_lat"),
        first(when(col("event_name") == "trip_started", col("start_lon")), ignorenulls=True).alias("start_lon"),
        
        # End location
        last(when(col("event_name") == "trip_completed", col("end_lat")), ignorenulls=True).alias("end_lat"),
        last(when(col("event_name") == "trip_completed", col("end_lon")), ignorenulls=True).alias("end_lon"),
        
        # Fare (from payment_processed event)
        max_(when(col("event_name") == "payment_processed", col("actual_fare"))).alias("fare_amount"),
        
        # Surge multiplier (from trip_requested)
        first(when(col("event_name") == "trip_requested", col("surge_multiplier")), ignorenulls=True).alias("surge_multiplier"),
        
        # Vehicle type
        first(when(col("vehicle_type").isNotNull(), col("vehicle_type")), ignorenulls=True).alias("vehicle_type"),
        
        # Status (last event status)
        last("status", ignorenulls=True).alias("status"),
        
        # Event count (for debugging)
        expr("COUNT(*)").alias("event_count")
    )
    
    # Calculate derived metrics
    trips_enriched = trips_df \
        .withColumn(
            "duration_seconds",
            when(
                (col("start_time").isNotNull()) & (col("end_time").isNotNull()),
                unix_timestamp(col("end_time")) - unix_timestamp(col("start_time"))
            ).otherwise(lit(None))
        ) \
        .withColumn(
            "trip_date",
            expr("DATE(start_time)")
        ) \
        .withColumn(
            "is_completed",
            when(col("status") == "COMPLETED", lit(True)).otherwise(lit(False))
        ) \
        .withColumn(
            "processing_timestamp",
            expr("CURRENT_TIMESTAMP()")
        )
    
    # Data quality: Filter invalid trips
    valid_trips = trips_enriched.filter(
        (col("trip_id").isNotNull()) &
        (col("start_time").isNotNull()) &
        # Only include trips with at least 2 events
        (col("event_count") >= 2)
    )
    
    print(f"Sessionized {valid_trips.count():,} trips")
    
    # Write to Delta Lake (MERGE for handling late arrivals)
    # If trip already exists, update it; otherwise insert
    
    # Check if Delta table exists
    try:
        existing_trips = DeltaTable.forPath(spark, SILVER_PATH)
        
        # MERGE operation (UPSERT)
        existing_trips.alias("target").merge(
            valid_trips.alias("source"),
            "target.trip_id = source.trip_id"
        ).whenMatchedUpdateAll() \
         .whenNotMatchedInsertAll() \
         .execute()
        
        print(f"✅ MERGED trips into Delta table")
        
    except Exception as e:
        # Table doesn't exist, create it
        print("Delta table doesn't exist, creating...")
        valid_trips.write \
            .format("delta") \
            .mode("overwrite") \
            .partitionBy("trip_date") \
            .save(SILVER_PATH)
        
        print(f"✅ Created Delta table with {valid_trips.count():,} trips")
    
    return valid_trips.count()

# Process last 48 hours (to handle late data)
end_date = datetime.now().date()
start_date = end_date - timedelta(days=2)

trip_count = sessionize_trips(start_date, end_date)

job.commit()
print(f"✅ Silver layer sessionization complete: {trip_count:,} trips")
```

---

## Data Quality & Governance

### Proactive Prevention (In-Pipeline Checks)

```python
"""
data_quality_framework.py
Great Expectations integration for data quality checks
"""

from great_expectations.dataset import SparkDFDataset
from pyspark.sql import DataFrame
import great_expectations as ge

class DataQualityChecker:
    """
    Data quality framework using Great Expectations
    
    Checks run at each layer:
    - Bronze: Schema validation, completeness
    - Silver: Business rules, referential integrity
    - Gold: Aggregate consistency
    """
    
    def __init__(self, spark_session):
        self.spark = spark_session
        self.context = ge.get_context()
    
    def validate_bronze_events(self, events_df: DataFrame) -> dict:
        """
        Validate Bronze layer events
        
        Checks:
        1. Required fields not null
        2. Event timestamp reasonable (not future, not too old)
        3. Schema version present
        4. Event types valid
        """
        
        ge_df = SparkDFDataset(events_df)
        
        # Check 1: Non-null columns
        ge_df.expect_column_values_to_not_be_null("event_id")
        ge_df.expect_column_values_to_not_be_null("event_name")
        ge_df.expect_column_values_to_not_be_null("event_timestamp")
        ge_df.expect_column_values_to_not_be_null("schema_version")
        
        # Check 2: Event timestamp range
        ge_df.expect_column_values_to_be_between(
            "event_timestamp",
            min_value="2024-01-01",
            max_value=datetime.now() + timedelta(hours=1),  # Allow 1-hour future (clock skew)
            parse_strings_as_datetimes=True
        )
        
        # Check 3: Valid event types
        valid_event_types = [
            "trip_requested",
            "driver_assigned",
            "driver_arrived",
            "trip_started",
            "trip_completed",
            "trip_cancelled",
            "payment_processed"
        ]
        ge_df.expect_column_values_to_be_in_set(
            "event_name",
            valid_event_types
        )
        
        # Check 4: Schema version format
        ge_df.expect_column_values_to_match_regex(
            "schema_version",
            r"^v\d+\.\d+$"  # e.g., v2.1, v3.0
        )
        
        # Run validation
        results = ge_df.validate()
        
        # Log results
        print(f"\n{'='*60}")
        print("Bronze Layer Data Quality Results")
        print(f"{'='*60}")
        print(f"Total Expectations: {results['statistics']['evaluated_expectations']}")
        print(f"Successful: {results['statistics']['successful_expectations']}")
        print(f"Failed: {results['statistics']['unsuccessful_expectations']}")
        print(f"Success Rate: {results['statistics']['success_percent']:.2f}%")
        
        # If failures, log details
        if not results['success']:
            print("\n❌ FAILED CHECKS:")
            for result in results['results']:
                if not result['success']:
                    print(f"   - {result['expectation_config']['expectation_type']}")
                    print(f"     Column: {result['expectation_config'].get('kwargs', {}).get('column', 'N/A')}")
                    print(f"     Details: {result.get('result', {})}")
        
        return results
    
    def validate_silver_trips(self, trips_df: DataFrame) -> dict:
        """
        Validate Silver layer trips
        
        Business Rules:
        1. trip_id is unique
        2. start_time < end_time
        3. fare_amount positive and reasonable (<$1000)
        4. duration reasonable (> 0, < 24 hours)
        5. Coordinates valid (lat: -90 to 90, lon: -180 to 180)
        """
        
        ge_df = SparkDFDataset(trips_df)
        
        # Check 1: Primary key uniqueness
        ge_df.expect_column_values_to_be_unique("trip_id")
        
        # Check 2: Temporal consistency
        # (handled via SQL: WHERE start_time < end_time)
        
        # Check 3: Fare validation
        ge_df.expect_column_values_to_be_between(
            "fare_amount",
            min_value=0,
            max_value=1000,
            mostly=0.999  # Allow 0.1% outliers
        )
        
        # Check 4: Duration validation
        ge_df.expect_column_values_to_be_between(
            "duration_seconds",
            min_value=60,  # Minimum 1 minute
            max_value=86400,  # Maximum 24 hours
            mostly=0.99  # Allow 1% outliers
        )
        
        # Check 5: Coordinate validation
        ge_df.expect_column_values_to_be_between("start_lat", -90, 90)
        ge_df.expect_column_values_to_be_between("start_lon", -180, 180)
        ge_df.expect_column_values_to_be_between("end_lat", -90, 90, mostly=0.95)
        ge_df.expect_column_values_to_be_between("end_lon", -180, 180, mostly=0.95)
        
        # Check 6: Status values
        ge_df.expect_column_values_to_be_in_set(
            "status",
            ["COMPLETED", "CANCELLED", "PENDING", "FAILED"]
        )
        
        results = ge_df.validate()
        
        print(f"\n{'='*60}")
        print("Silver Layer Data Quality Results")
        print(f"{'='*60}")
        print(f"Success Rate: {results['statistics']['success_percent']:.2f}%")
        
        return results
    
    def validate_gold_metrics(self, metrics_df: DataFrame, expected_counts: dict) -> dict:
        """
        Validate Gold layer metrics
        
        Consistency Checks:
        1. Trip counts match expected ranges
        2. Utilization percentages between 0-100
        3. Aggregates are reasonable
        """
        
        ge_df = SparkDFDataset(metrics_df)
        
        # Check 1: Utilization percentage
        ge_df.expect_column_values_to_be_between(
            "utilization_pct",
            min_value=0,
            max_value=100
        )
        
        # Check 2: Trip counts reasonable
        if "trips_count" in expected_counts:
            ge_df.expect_column_values_to_be_between(
                "trips_count",
                min_value=expected_counts["trips_count"]["min"],
                max_value=expected_counts["trips_count"]["max"],
                mostly=0.95
            )
        
        results = ge_df.validate()
        
        return results

# Integration into Glue job
def run_with_data_quality_checks(spark, source_df, stage="bronze"):
    """
    Wrapper to run DQ checks before processing
    """
    
    dq_checker = DataQualityChecker(spark)
    
    if stage == "bronze":
        results = dq_checker.validate_bronze_events(source_df)
    elif stage == "silver":
        results = dq_checker.validate_silver_trips(source_df)
    elif stage == "gold":
        results = dq_checker.validate_gold_metrics(source_df, expected_counts={})
    
    # If critical failures, halt pipeline
    if results['statistics']['success_percent'] < 95:
        raise Exception(
            f"Data quality check failed: {results['statistics']['success_percent']:.2f}% success rate"
        )
    
    return source_df
```

### Reactive Debugging (When Issues Are Reported)

```python
"""
data_lineage_debugger.py
Tools for debugging data quality issues
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as sum_
from delta import DeltaTable
from datetime import datetime, timedelta

class DataLineageDebugger:
    """
    Debugging toolkit for data quality issues
    
    Features:
    1. Data lineage: Trace metric back to source events
    2. Time travel: Compare snapshots
    3. Anomaly detection: Identify sudden drops/spikes
    """
    
    def __init__(self, spark_session):
        self.spark = spark_session
    
    def trace_trip_lineage(self, trip_id: str):
        """
        Trace a trip from Gold → Silver → Bronze → Raw
        
        Use case: "Why is trip XYZ showing $0 fare?"
        """
        
        print(f"\n{'='*60}")
        print(f"LINEAGE TRACE: trip_id = {trip_id}")
        print(f"{'='*60}\n")
        
        # Step 1: Check Gold layer
        print("🔍 Checking Gold layer...")
        gold_df = self.spark.sql(f"""
            SELECT *
            FROM gold.trips
            WHERE trip_id = '{trip_id}'
        """)
        
        if gold_df.count() == 0:
            print("❌ Trip not found in Gold layer")
        else:
            gold_df.show(truncate=False)
            print(f"✅ Found in Gold: {gold_df.select('fare_amount').collect()[0][0]}")
        
        # Step 2: Check Silver layer
        print("\n🔍 Checking Silver layer (Delta Lake)...")
        silver_path = "s3://ride-hailing-datalake/silver/trips/"
        silver_df = self.spark.read.format("delta").load(silver_path) \
            .filter(col("trip_id") == trip_id)
        
        if silver_df.count() == 0:
            print("❌ Trip not found in Silver layer")
        else:
            silver_df.show(truncate=False)
            print(f"✅ Found in Silver: {silver_df.select('fare_amount').collect()[0][0]}")
        
        # Step 3: Check Bronze layer (raw events)
        print("\n🔍 Checking Bronze layer (events)...")
        bronze_path = "s3://ride-hailing-datalake/bronze/events/"
        bronze_df = self.spark.read.parquet(bronze_path) \
            .filter(col("trip_id") == trip_id) \
            .orderBy("event_timestamp")
        
        event_count = bronze_df.count()
        print(f"Found {event_count} events in Bronze:")
        bronze_df.select(
            "event_name",
            "event_timestamp",
            "actual_fare",
            "status"
        ).show(truncate=False)
        
        # Step 4: Identify issue
        print("\n🔎 ANALYSIS:")
        
        # Check if payment_processed event exists
        payment_events = bronze_df.filter(col("event_name") == "payment_processed")
        if payment_events.count() == 0:
            print("⚠️  ISSUE: No 'payment_processed' event found!")
            print("   Possible causes:")
            print("   1. Event not yet arrived (late data)")
            print("   2. Payment processing failed")
            print("   3. Event lost in transit")
        
        # Check if fare is null in payment event
        elif payment_events.filter(col("actual_fare").isNull()).count() > 0:
            print("⚠️  ISSUE: 'payment_processed' event has NULL fare!")
            print("   Possible causes:")
            print("   1. Bug in driver app sending null fare")
            print("   2. Schema change not handled")
        
        else:
            fare_value = payment_events.select("actual_fare").collect()[0][0]
            print(f"✅ Payment event found with fare: ${fare_value}")
            print("   Issue may be in Silver layer sessionization logic")
    
    def compare_snapshots(self, trip_date: str):
        """
        Compare Silver layer snapshots using Delta Lake time travel
        
        Use case: "Why did trip counts change for yesterday?"
        """
        
        print(f"\n{'='*60}")
        print(f"SNAPSHOT COMPARISON: trip_date = {trip_date}")
        print(f"{'='*60}\n")
        
        silver_path = "s3://ride-hailing-datalake/silver/trips/"
        delta_table = DeltaTable.forPath(self.spark, silver_path)
        
        # Get version history
        history = delta_table.history()
        print("Recent versions:")
        history.select("version", "timestamp", "operation", "operationMetrics") \
            .orderBy(col("version").desc()) \
            .limit(5) \
            .show(truncate=False)
        
        # Compare current vs yesterday's version
        current_df = self.spark.read.format("delta").load(silver_path) \
            .filter(col("trip_date") == trip_date)
        
        # Time travel to previous version
        previous_version = history.select("version").orderBy(col("version").desc()).limit(2).collect()[1][0]
        
        previous_df = self.spark.read.format("delta") \
            .option("versionAsOf", previous_version) \
            .load(silver_path) \
            .filter(col("trip_date") == trip_date)
        
        current_count = current_df.count()
        previous_count = previous_df.count()
        
        print(f"\nTrip count comparison:")
        print(f"  Version {previous_version} (previous): {previous_count:,} trips")
        print(f"  Version {previous_version + 1} (current):  {current_count:,} trips")
        print(f"  Difference: {current_count - previous_count:,} trips")
        
        if current_count != previous_count:
            print("\n🔎 Investigating difference...")
            
            # Find trips that were added
            added_trips = current_df.join(
                previous_df,
                on="trip_id",
                how="left_anti"
            )
            
            print(f"\nAdded trips: {added_trips.count():,}")
            if added_trips.count() > 0:
                print("Sample added trips:")
                added_trips.select("trip_id", "start_time", "processing_timestamp") \
                    .limit(5) \
                    .show(truncate=False)
            
            # Find trips that were removed
            removed_trips = previous_df.join(
                current_df,
                on="trip_id",
                how="left_anti"
            )
            
            print(f"\nRemoved trips: {removed_trips.count():,}")
            if removed_trips.count() > 0:
                print("Sample removed trips:")
                removed_trips.select("trip_id", "start_time", "processing_timestamp") \
                    .limit(5) \
                    .show(truncate=False)
    
    def detect_anomalies(self, city_id: str, days_back: int = 7):
        """
        Detect anomalies in metrics
        
        Use case: "Driver utilization for San Francisco dropped 50% overnight"
        """
        
        print(f"\n{'='*60}")
        print(f"ANOMALY DETECTION: city = {city_id}, last {days_back} days")
        print(f"{'='*60}\n")
        
        # Query Gold metrics
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=days_back)
        
        metrics_df = self.spark.sql(f"""
            SELECT 
                metric_date,
                trips_count,
                total_fare,
                avg_duration,
                driver_hours,
                utilization_pct
            FROM gold.fact_hourly_metrics
            WHERE city_id = '{city_id}'
              AND metric_date BETWEEN '{start_date}' AND '{end_date}'
            ORDER BY metric_date
        """)
        
        print("Metrics trend:")
        metrics_df.show()
        
        # Calculate day-over-day change
        from pyspark.sql.window import Window
        from pyspark.sql.functions import lag
        
        window_spec = Window.orderBy("metric_date")
        
        anomalies = metrics_df.withColumn(
            "prev_trips",
            lag("trips_count").over(window_spec)
        ).withColumn(
            "trips_pct_change",
            ((col("trips_count") - col("prev_trips")) / col("prev_trips") * 100)
        ).filter(
            col("trips_pct_change").isNotNull()
        )
        
        # Flag significant changes (>20%)
        significant_changes = anomalies.filter(
            (col("trips_pct_change") > 20) | (col("trips_pct_change") < -20)
        )
        
        if significant_changes.count() > 0:
            print("\n⚠️  ANOMALIES DETECTED:")
            significant_changes.select(
                "metric_date",
                "trips_count",
                "trips_pct_change"
            ).show()
            
            print("\n🔎 INVESTIGATION STEPS:")
            print("1. Check Kinesis metrics: Was there a drop in incoming events?")
            print("   → CloudWatch: Kinesis IncomingBytes, IncomingRecords")
            
            print("2. Check Bronze layer: Were events properly converted?")
            print("   → Query: SELECT COUNT(*) FROM bronze.events WHERE event_date = 'YYYY-MM-DD'")
            
            print("3. Check Silver layer: Were trips properly sessionized?")
            print("   → Query: SELECT COUNT(*) FROM silver.trips WHERE trip_date = 'YYYY-MM-DD'")
            
            print("4. Check for app version changes:")
            print("   → Query: SELECT app_version, COUNT(*) FROM bronze.events")
            print("            WHERE event_date = 'YYYY-MM-DD' GROUP BY app_version")
        
        else:
            print("✅ No significant anomalies detected")

# Example usage
"""
# Scenario: "Driver utilization metric dropped 50% for San Francisco"

debugger = DataLineageDebugger(spark)

# Step 1: Detect the anomaly
debugger.detect_anomalies(city_id='san_francisco', days_back=7)

# Step 2: Trace a specific trip that shows $0 utilization
debugger.trace_trip_lineage(trip_id='trip_abc123')

# Step 3: Compare yesterday vs today's data
debugger.compare_snapshots(trip_date='2025-01-17')
"""
```

---

## Handling Edge Cases

### Late Arriving Data (48-Hour Window)

```python
"""
Late arriving data strategy:
- Main batch job processes last 24-48 hours (rolling window)
- Delta Lake MERGE handles updates to existing trips
- Watermarking: 48 hours (any data older = truly late)
"""

def handle_late_data(spark, processing_date):
    """
    Handle late-arriving events
    
    Watermarking: 48 hours
    - Events arriving within 48 hours: Processed normally
    - Events arriving after 48 hours: Flagged as late
    
    Impact on Gold tables:
    - Affected date range recomputed
    - Downstream dashboards see updated metrics
    """
    
    # Processing window: Today - 2 days to Today
    end_date = processing_date
    start_date = processing_date - timedelta(days=2)
    
    print(f"Processing window: {start_date} to {end_date}")
    
    # Read events (including late arrivals)
    events_df = spark.read.parquet("s3://bucket/bronze/events/") \
        .filter(
            (col("event_date") >= start_date) &
            (col("event_date") <= end_date)
        )
    
    # Sessionize into trips
    trips_df = sessionize_trips(events_df)
    
    # MERGE into Silver layer (Delta Lake)
    silver_path = "s3://bucket/silver/trips/"
    delta_table = DeltaTable.forPath(spark, silver_path)
    
    delta_table.alias("target").merge(
        trips_df.alias("source"),
        "target.trip_id = source.trip_id"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
    
    print("✅ Late data merged into Silver layer")
    
    # Trigger Gold layer backfill for affected dates
    affected_dates = trips_df.select("trip_date").distinct().collect()
    
    print(f"\nAffected dates requiring Gold layer recomputation:")
    for row in affected_dates:
        date = row['trip_date']
        print(f"  - {date}")
        
        # Trigger backfill job for this date
        trigger_gold_backfill(date)
    
    return len(affected_dates)

def trigger_gold_backfill(trip_date):
    """
    Recompute Gold layer aggregations for a specific date
    
    This ensures downstream dashboards reflect late-arriving data
    """
    
    print(f"Recomputing Gold metrics for {trip_date}...")
    
    # Read Silver trips for this date
    trips_df = spark.read.format("delta") \
        .load("s3://bucket/silver/trips/") \
        .filter(col("trip_date") == trip_date)
    
    # Recompute aggregations
    hourly_metrics = trips_df.groupBy("trip_date", "city_id", "vehicle_type").agg(
        count("*").alias("trips_count"),
        sum_("fare_amount").alias("total_fare"),
        # ... other metrics
    )
    
    # UPSERT into Gold layer
    # (Delete + Insert for this date)
    gold_path = "s3://bucket/gold/fact_hourly_metrics/"
    
    gold_delta = DeltaTable.forPath(spark, gold_path)
    
    # Delete existing records for this date
    gold_delta.delete(f"metric_date = '{trip_date}'")
    
    # Insert recomputed records
    hourly_metrics.write \
        .format("delta") \
        .mode("append") \
        .save(gold_path)
    
    print(f"✅ Gold metrics recomputed for {trip_date}")
```

---

## Monitoring & Operations

### CloudWatch Dashboards

```python
"""
cloudwatch_monitoring.py
Set up CloudWatch dashboards for end-to-end monitoring
"""

import boto3
import json

def create_pipeline_dashboard():
    """
    Create comprehensive CloudWatch dashboard
    
    Monitors:
    1. Kinesis ingestion
    2. Batch processing (Glue jobs)
    3. Streaming processing (Flink)
    4. Data quality metrics
    5. End-to-end latency
    """
    
    cloudwatch = boto3.client('cloudwatch')
    
    dashboard_body = {
        "widgets": [
            # Row 1: Ingestion Metrics
            {
                "type": "metric",
                "properties": {
                    "metrics": [
                        ["AWS/Kinesis", "IncomingRecords", {"stat": "Sum", "label": "Events/Min"}],
                        [".", "IncomingBytes", {"stat": "Sum", "yAxis": "right"}]
                    ],
                    "period": 60,
                    "stat": "Average",
                    "region": "us-east-1",
                    "title": "Kinesis Ingestion",
                    "yAxis": {
                        "left": {"label": "Records"},
                        "right": {"label": "Bytes"}
                    }
                }
            },
            
            # Row 2: Batch Processing
            {
                "type": "metric",
                "properties": {
                    "metrics": [
                        ["AWS/Glue", "glue.driver.ExecutorAllocationManager.executors.numberAllExecutors", 
                         {"label": "Active Executors"}],
                        [".", "glue.ALL.s3.filesystem.read_bytes", 
                         {"stat": "Sum", "label": "S3 Read (GB)", "yAxis": "right"}]
                    ],
                    "period": 300,
                    "stat": "Average",
                    "region": "us-east-1",
                    "title": "Glue Job Execution"
                }
            },
            
            # Row 3: Data Quality
            {
                "type": "metric",
                "properties": {
                    "metrics": [
                        ["RideHailing/DataQuality", "bronze_validation_success_rate", 
                         {"stat": "Average"}],
                        [".", "silver_validation_success_rate", {"stat": "Average"}]
                    ],
                    "period": 300,
                    "stat": "Average",
                    "region": "us-east-1",
                    "title": "Data Quality Success Rate",
                    "yAxis": {
                        "left": {"min": 0, "max": 100}
                    },
                    "annotations": {
                        "horizontal": [
                            {"value": 95, "label": "Threshold", "color": "#d62728"}
                        ]
                    }
                }
            },
            
            # Row 4: End-to-End Latency
            {
                "type": "metric",
                "properties": {
                    "metrics": [
                        ["RideHailing/Pipeline", "batch_processing_latency_hours", 
                         {"stat": "Maximum", "label": "Batch Latency (hours)"}],
                        [".", "streaming_processing_latency_minutes", 
                         {"stat": "Maximum", "label": "Streaming Latency (min)", "yAxis": "right"}]
                    ],
                    "period": 300,
                    "stat": "Average",
                    "region": "us-east-1",
                    "title": "Processing Latency",
                    "annotations": {
                        "horizontal": [
                            {"value": 24, "label": "Batch SLA", "color": "#2ca02c"},
                            {"value": 15, "label": "Streaming SLA", "color": "#ff7f0e", "yAxis": "right"}
                        ]
                    }
                }
            },
            
            # Row 5: Record Counts (Data Lineage)
            {
                "type": "metric",
                "properties": {
                    "metrics": [
                        ["RideHailing/Pipeline", "raw_events_count", 
                         {"stat": "Sum", "label": "Raw Events"}],
                        [".", "bronze_events_count", 
                         {"stat": "Sum", "label": "Bronze Events"}],
                        [".", "silver_trips_count", 
                         {"stat": "Sum", "label": "Silver Trips"}]
                    ],
                    "period": 3600,  # Hourly
                    "stat": "Sum",
                    "region": "us-east-1",
                    "title": "Data Lineage (Hourly Counts)"
                }
            }
        ]
    }
    
    # Create dashboard
    cloudwatch.put_dashboard(
        DashboardName='RideHailingDataPipeline',
        DashboardBody=json.dumps(dashboard_body)
    )
    
    print("✅ CloudWatch dashboard created: RideHailingDataPipeline")

def publish_custom_metrics(spark, layer, metrics):
    """
    Publish custom metrics to CloudWatch
    
    Example usage:
    publish_custom_metrics(
        spark,
        layer="bronze",
        metrics={
            "events_count": 1_500_000,
            "validation_success_rate": 99.5,
            "processing_time_seconds": 300
        }
    )
    """
    
    cloudwatch = boto3.client('cloudwatch')
    
    metric_data = []
    for metric_name, value in metrics.items():
        metric_data.append({
            'MetricName': f"{layer}_{metric_name}",
            'Value': value,
            'Unit': 'None',
            'Timestamp': datetime.now(),
            'Dimensions': [
                {
                    'Name': 'Layer',
                    'Value': layer
                }
            ]
        })
    
    cloudwatch.put_metric_data(
        Namespace='RideHailing/Pipeline',
        MetricData=metric_data
    )
    
    print(f"✅ Published {len(metrics)} metrics to CloudWatch")

# Example integration in Glue job
"""
# In glue_job_json_to_parquet.py

# After processing
record_count = final_df.count()
processing_time = time.time() - start_time

publish_custom_metrics(
    spark,
    layer="bronze",
    metrics={
        "events_count": record_count,
        "processing_time_seconds": processing_time,
        "validation_success_rate": (valid_events.count() / raw_df.count()) * 100
    }
)
"""
```

### Alerting Strategy

```python
"""
alerting_configuration.py
CloudWatch Alarms for pipeline monitoring
"""

import boto3

def create_pipeline_alarms():
    """
    Create CloudWatch Alarms for critical metrics
    
    Severity Levels:
    - P0 (Critical): Page on-call immediately
    - P1 (High): Notify team channel
    - P2 (Medium): Log and review daily
    """
    
    cloudwatch = boto3.client('cloudwatch')
    sns = boto3.client('sns')
    
    # Create SNS topics for alerting
    oncall_topic = sns.create_topic(Name='ride-hailing-oncall-critical')
    team_topic = sns.create_topic(Name='ride-hailing-team-alerts')
    
    oncall_topic_arn = oncall_topic['TopicArn']
    team_topic_arn = team_topic['TopicArn']
    
    # P0: Kinesis ingestion stopped
    cloudwatch.put_metric_alarm(
        AlarmName='P0-KinesisIngestionStopped',
        ComparisonOperator='LessThanThreshold',
        EvaluationPeriods=2,
        MetricName='IncomingRecords',
        Namespace='AWS/Kinesis',
        Period=300,  # 5 minutes
        Statistic='Sum',
        Threshold=1000,  # Alert if <1000 records in 5 min
        ActionsEnabled=True,
        AlarmActions=[oncall_topic_arn],
        AlarmDescription='CRITICAL: Kinesis stream has stopped receiving events',
        TreatMissingData='breaching'
    )
    
    # P0: Glue job failed
    cloudwatch.put_metric_alarm(
        AlarmName='P0-GlueJobFailed',
        ComparisonOperator='GreaterThanThreshold',
        EvaluationPeriods=1,
        MetricName='glue.driver.ExecutorAllocationManager.executors.numberAllExecutors',
        Namespace='AWS/Glue',
        Period=300,
        Statistic='Minimum',
        Threshold=0,  # Alert if executors drop to 0
        ActionsEnabled=True,
        AlarmActions=[oncall_topic_arn],
        AlarmDescription='CRITICAL: Glue job has failed or stopped',
        TreatMissingData='breaching'
    )
    
    # P1: Data quality below threshold
    cloudwatch.put_metric_alarm(
        AlarmName='P1-DataQualityDegraded',
        ComparisonOperator='LessThanThreshold',
        EvaluationPeriods=2,
        MetricName='bronze_validation_success_rate',
        Namespace='RideHailing/DataQuality',
        Period=300,
        Statistic='Average',
        Threshold=95,  # Alert if success rate <95%
        ActionsEnabled=True,
        AlarmActions=[team_topic_arn],
        AlarmDescription='HIGH: Data quality has degraded below 95%'
    )
    
    # P1: Streaming latency exceeds SLA
    cloudwatch.put_metric_alarm(
        AlarmName='P1-StreamingLatencyHigh',
        ComparisonOperator='GreaterThanThreshold',
        EvaluationPeriods=3,
        MetricName='streaming_processing_latency_minutes',
        Namespace='RideHailing/Pipeline',
        Period=300,
        Statistic='Maximum',
        Threshold=15,  # Alert if latency >15 minutes
        ActionsEnabled=True,
        AlarmActions=[team_topic_arn],
        AlarmDescription='HIGH: Streaming latency exceeds 15-minute SLA'
    )
    
    # P2: Batch processing delayed
    cloudwatch.put_metric_alarm(
        AlarmName='P2-BatchProcessingDelayed',
        ComparisonOperator='GreaterThanThreshold',
        EvaluationPeriods=1,
        MetricName='batch_processing_latency_hours',
        Namespace='RideHailing/Pipeline',
        Period=3600,
        Statistic='Maximum',
        Threshold=26,  # Alert if >26 hours (2 hours past SLA)
        ActionsEnabled=True,
        AlarmActions=[team_topic_arn],
        AlarmDescription='MEDIUM: Batch processing is delayed beyond SLA'
    )
    
    print("✅ CloudWatch alarms created")
    print(f"   On-call topic: {oncall_topic_arn}")
    print(f"   Team topic: {team_topic_arn}")

# Runbook for each alarm
RUNBOOKS = {
    "P0-KinesisIngestionStopped": """
    RUNBOOK: Kinesis Ingestion Stopped
    
    1. Check Kinesis stream status:
       aws kinesis describe-stream --stream-name ride-hailing-events
    
    2. Check producer applications:
       - Are driver/rider apps sending events?
       - Check app logs for connection errors
    
    3. Check AWS service health:
       https://status.aws.amazon.com/
    
    4. If Kinesis is healthy, restart producers
    
    5. If issue persists >30 min, escalate to Platform team
    """,
    
    "P1-DataQualityDegraded": """
    RUNBOOK: Data Quality Degraded
    
    1. Check which validations failed:
       - View Great Expectations results in CloudWatch Logs
    
    2. Investigate source:
       - New app version deployed?
       - Schema change in events?
    
    3. Query Bronze layer for sample invalid events:
       SELECT * FROM bronze.events 
       WHERE event_date = CURRENT_DATE 
       AND <validation_condition>
       LIMIT 100
    
    4. If schema change detected:
       - Update envelope parsing logic
       - Deploy updated Glue job
    
    5. Document root cause and prevention strategy
    """
}
```

---

## Interview Questions & Answers

### Q1: Why Lambda Architecture instead of Kappa?

**Answer:**
> "Great question. Kappa architecture (stream-only) is simpler, but doesn't meet our dual requirements:
> 
> **Our Requirements:**
> - Executive dashboards: 24-hour latency acceptable
> - City ops dashboards: 15-minute latency required
> 
> **Kappa Limitations:**
> - Single processing path = single latency characteristic
> - To achieve 15-min latency for ALL data = expensive
> - Streaming-only loses reprocessability for corrections
> 
> **Lambda Benefits:**
> - Batch path: 100% accurate (reprocess with corrected logic)
> - Streaming path: Fast provisional data
> - Batch reconciles streaming daily (eventual consistency)
> - Cost-effective: Optimize each path separately
> 
> **Real Example:**
> - Week 1: Launched streaming for city ops (15-min latency)
> - Month 2: Found bug in fare calculation
> - Batch path: Reprocessed 2 months of data with fix
> - Streaming path: Deployed fix, but no reprocessing needed
> - Result: Historical accuracy maintained without streaming reprocessing cost"

---

### Q2: Why convert JSON to Parquet in Bronze layer?

**Answer:**
> "Storing raw JSON is good for fidelity, but terrible for query performance.
> 
> **Performance Comparison** (actual benchmarks):
> ```
> Query: SELECT COUNT(*) FROM events WHERE event_date = '2025-01-18'
> 
> JSON (gzipped):
> - File size: 2.5 GB
> - Scan time: 45 seconds
> - Cost: $0.005 per query (full scan)
> 
> Parquet:
> - File size: 350 MB (86% smaller)
> - Scan time: 3 seconds (15x faster)
> - Cost: $0.0003 per query (columnar)
> 
> Savings: 15x faster, 17x cheaper
> ```
> 
> **Additional Benefits:**
> - **Athena queries**: Parquet columnar → only scan needed columns
> - **Compression**: Better than gzipped JSON (5-7x)
> - **Schema evolution**: Parquet supports adding columns
> - **Ecosystem**: Native support in Spark, Redshift Spectrum, Athena
> 
> **Why not go directly to Parquet from Kinesis Firehose?**
> - Firehose can convert to Parquet, BUT:
>   * Limited transformation logic
>   * No deduplication
>   * No schema validation
> - Better to have immutable raw JSON for audit trail
> - Then convert with full validation in Glue"

---

### Q3: How do you handle late-arriving data affecting Gold tables?

**Answer:**
> "Late data is inevitable in distributed systems. My strategy:
> 
> **Watermarking (48 hours):**
> - Daily Spark job processes last 48 hours (rolling window)
> - Events within 48 hours: Processed normally
> - Events after 48 hours: Flagged as truly late
> 
> **Delta Lake MERGE:**
> - Late trip events → Silver layer updated via MERGE
> - Example: Trip completed on Monday, but payment event arrives Wednesday
> - Wednesday's batch job: Updates Monday's trip with correct fare
> 
> **Downstream Impact (Gold layer):**
> - Affected dates flagged for recomputation
> - Gold tables recomputed for those dates
> - Dashboards see updated metrics next refresh
> 
> **Eventual Consistency Model:**
> - Communicate to stakeholders: Metrics settle within 48 hours
> - Real-time dashboard: \"~99.5% accurate, finalizes in 48h\"
> - SLA: Last 2 days subject to updates, beyond that = final
> 
> **Real Example:**
> ```
> Monday 3PM: Trip completed, 5 events received
> Monday 3PM: Streaming shows trip in dashboard (no fare yet)
> Monday 4PM: Payment event arrives (late), batch hasn't run
> Tuesday 2AM: Batch job processes Monday data
> Tuesday 2AM: MERGE updates Monday's trip with fare
> Tuesday 2AM: Gold tables recomputed for Monday
> Tuesday 8AM: Dashboard shows correct Monday revenue
> ```
> 
> **Backfill Orchestration:**
> - Airflow DAG detects affected dates (via Delta Lake change log)
> - Triggers Gold layer backfill for those dates only
> - Incremental recomputation (not full reprocessing)"

---

### Q4: How do you ensure consistency between batch and streaming pipelines?

**Answer:**
> "The biggest Lambda Architecture challenge. My solution:
> 
> **Batch as Source of Truth:**
> - Batch pipeline = authoritative version
> - Streaming = fast provisional view
> - Daily reconciliation: Batch overwrites streaming
> 
> **Reconciliation Process** (runs daily at 2 AM):
> ```sql
> -- Step 1: Delete last 24 hours from streaming table
> DELETE FROM public.trips_realtime
> WHERE start_time >= CURRENT_DATE - 1;
> 
> -- Step 2: Insert batch-processed data
> INSERT INTO public.trips_realtime
> SELECT * FROM gold.trips  -- From batch pipeline
> WHERE trip_date >= CURRENT_DATE - 1;
> ```
> 
> **Preventing Logic Divergence:**
> - Shared SQL functions for sessionization logic
> - Store in Git, referenced by both Spark and Flink
> - Example: `calculate_trip_duration(start_time, end_time)` used in both
> - CI/CD: Unit tests ensure both produce same results
> 
> **Monitoring Divergence:**
> - Daily reconciliation job logs discrepancies:
>   ```
>   Streaming count: 1,000,523 trips
>   Batch count: 1,000,891 trips
>   Difference: 368 trips (0.037%)
>   ```
> - Alert if difference >1% (indicates logic drift)
> 
> **Communication to Stakeholders:**
> - City ops dashboard: \"Last 24h data is provisional\"
> - Executive dashboard: \"Historical data (>24h) is final\"
> - Explicit label on real-time metrics
> 
> **Alternative Considered:**
> - Kappa (stream-only): Simpler but can't reprocess without stream replay
> - Rejected because: Need to correct historical data for billing"

---

## Cost Summary

### Monthly Infrastructure Costs

| Component | Service | Monthly Cost | Notes |
|-----------|---------|--------------|-------|
| **Ingestion** | Kinesis Data Streams | $1,200 | 100 shards × 730 hours |
| | Kinesis Data Firehose | $300 | 2-3 TB/day delivery |
| **Batch Processing** | AWS Glue (Spark) | $500 | Hourly jobs + daily sessionization |
| | EMR (Spot) for large jobs | $800 | Ad-hoc large transformations |
| **Stream Processing** | Kinesis Data Analytics | $700 | 8 KPUs average |
| **Storage** | S3 (Bronze/Silver/Gold) | $1,500 | 100 TB total, tiered |
| | Delta Lake metadata | $50 | S3 for transaction logs |
| **Serving** | Redshift | $4,000 | ra3.xlplus, 4 nodes |
| | Athena queries | $200 | Ad-hoc queries on cold data |
| **Orchestration** | Step Functions / Airflow | $100 | Workflow management |
| **Monitoring** | CloudWatch | $300 | Logs, metrics, dashboards |
| **Data Quality** | Great Expectations (compute) | $50 | Validation checks |
| **TOTAL** | | **$9,700/month** | **$116,400/year** |

### Cost Optimization Strategies

1. **S3 Intelligent Tiering**: Automatically moves data to cheaper tiers
2. **EMR Spot Instances**: 70% savings on batch processing
3. **Redshift Reserved Instances**: 40% savings with 1-year commitment
4. **Data Lifecycle**: Archive >5 years to Glacier (90% cheaper)

---

## Conclusion

This system design provides:

✅ **Lambda Architecture** for dual latency requirements (15-min + 24-hour) <br>
✅ **Medallion Pattern** (Bronze/Silver/Gold) for organized data lake <br>
✅ **Schema Evolution** handling via envelope pattern <br>
✅ **Late-Arriving Data** handling with 48-hour watermark <br>
✅ **Data Quality** framework with Great Expectations <br>
✅ **Exactly-Once Semantics** via Delta Lake + Kinesis + Flink <br>
✅ **Batch-Streaming Consistency** via daily reconciliation <br>
✅ **Production Monitoring** with CloudWatch + alerting <br>
✅ **Cost-Optimized** architecture at $9,700/month

**Scale Achieved:**
- 500M events/day
- 2-3 TB/day throughput
- 15-minute latency (streaming)
- 24-hour latency (batch)
- 99.9% data quality
- 13 months queryable history

This architecture is production-ready for a global ride-hailing platform.