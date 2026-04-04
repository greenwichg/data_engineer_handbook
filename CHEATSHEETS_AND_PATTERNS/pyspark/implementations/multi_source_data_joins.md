I'll provide a comprehensive solution for joining data from Hive tables (batch/static) and Kafka topics (streaming) in a single PySpark job.

## Problem Understanding

**Scenario:** Enrich real-time streaming data from Kafka with reference/dimension data stored in Hive tables.

**Example Use Case:**
```
Kafka Stream: Real-time transactions (transaction_id, customer_id, amount, timestamp)
                        +
Hive Table: Customer details (customer_id, name, tier, credit_limit)
                        ↓
        Enriched Stream: Transactions with customer info
```

**Challenges:**
- Stream-static joins have different semantics than stream-stream joins
- Hive data is static (loaded once) - need refresh strategy
- Schema evolution handling
- Performance optimization for large Hive tables
- Memory management

## Solution 1: Basic Stream-Static Join

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

# ==========================================
# INITIALIZE SPARK WITH HIVE & KAFKA SUPPORT
# ==========================================

spark = SparkSession.builder \
    .appName("Hive_Kafka_Join") \
    .config("spark.sql.warehouse.dir", "/user/hive/warehouse") \
    .config("spark.sql.catalogImplementation", "hive") \
    .enableHiveSupport() \
    .getOrCreate()

# ==========================================
# READ FROM HIVE (STATIC DATA)
# ==========================================

# Method 1: Read Hive table using spark.table()
customer_dim = spark.table("sales_db.customers")

print("Customer dimension from Hive:")
customer_dim.printSchema()
customer_dim.show(5)

# Method 2: Using SQL
customer_dim = spark.sql("""
    SELECT 
        customer_id,
        customer_name,
        customer_tier,
        credit_limit,
        region
    FROM sales_db.customers
    WHERE active = true
""")

# IMPORTANT: Cache the Hive data for performance
customer_dim.cache()
customer_count = customer_dim.count()
print(f"Cached {customer_count} customers from Hive")

# ==========================================
# READ FROM KAFKA (STREAMING DATA)
# ==========================================

# Define schema for Kafka messages
transaction_schema = StructType([
    StructField("transaction_id", StringType(), False),
    StructField("customer_id", IntegerType(), False),
    StructField("product_id", StringType(), False),
    StructField("amount", DoubleType(), False),
    StructField("transaction_timestamp", TimestampType(), False)
])

# Read from Kafka
kafka_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "transactions") \
    .option("startingOffsets", "latest") \
    .load()

# Parse JSON messages
transactions_stream = kafka_stream.select(
    from_json(col("value").cast("string"), transaction_schema).alias("data")
).select("data.*")

print("Transaction stream from Kafka:")
transactions_stream.printSchema()

# ==========================================
# JOIN STREAMING DATA WITH HIVE DATA
# ==========================================

# Stream-static join (left join to keep all transactions)
enriched_stream = transactions_stream.join(
    customer_dim,
    transactions_stream.customer_id == customer_dim.customer_id,
    "left"  # Keep all transactions even if customer not found
).select(
    transactions_stream.transaction_id,
    transactions_stream.customer_id,
    customer_dim.customer_name,
    customer_dim.customer_tier,
    customer_dim.credit_limit,
    transactions_stream.product_id,
    transactions_stream.amount,
    transactions_stream.transaction_timestamp
)

# ==========================================
# WRITE ENRICHED STREAM
# ==========================================

# Write to console (for testing)
query = enriched_stream.writeStream \
    .outputMode("append") \
    .format("console") \
    .option("truncate", False) \
    .start()

query.awaitTermination()
```

## Solution 2: Production-Ready Implementation

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from delta import *
import logging
from typing import Dict, List

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==========================================
# PRODUCTION-GRADE MULTI-SOURCE JOIN
# ==========================================

class MultiSourceJoinPipeline:
    """
    Production pipeline for joining Kafka streams with Hive tables
    """
    
    def __init__(self, spark: SparkSession, config: Dict):
        self.spark = spark
        self.config = config
        self.dimension_cache = {}
    
    def load_hive_dimensions(self, tables: List[str]):
        """
        Load and cache multiple Hive dimension tables
        
        Args:
            tables: List of Hive table names to load
        """
        logger.info("Loading Hive dimension tables...")
        
        for table in tables:
            logger.info(f"Loading table: {table}")
            
            # Read from Hive
            df = self.spark.table(table)
            
            # Apply filters if configured
            filters = self.config.get('filters', {}).get(table, None)
            if filters:
                df = df.filter(filters)
            
            # Cache for performance
            df.cache()
            count = df.count()
            
            logger.info(f"Cached {count:,} records from {table}")
            
            # Store in cache dictionary
            self.dimension_cache[table] = df
        
        return self.dimension_cache
    
    def read_kafka_stream(
        self,
        topic: str,
        schema: StructType
    ):
        """
        Read and parse Kafka stream
        
        Args:
            topic: Kafka topic name
            schema: Schema for JSON messages
        """
        logger.info(f"Reading from Kafka topic: {topic}")
        
        kafka_config = self.config['kafka']
        
        # Read from Kafka
        kafka_stream = self.spark.readStream \
            .format("kafka") \
            .option("kafka.bootstrap.servers", kafka_config['brokers']) \
            .option("subscribe", topic) \
            .option("startingOffsets", kafka_config.get('starting_offsets', 'latest')) \
            .option("maxOffsetsPerTrigger", kafka_config.get('max_offsets_per_trigger', 10000)) \
            .load()
        
        # Parse JSON
        parsed_stream = kafka_stream.select(
            col("key").cast("string").alias("kafka_key"),
            from_json(col("value").cast("string"), schema).alias("data"),
            col("timestamp").alias("kafka_timestamp"),
            col("partition").alias("kafka_partition"),
            col("offset").alias("kafka_offset")
        ).select("data.*", "kafka_timestamp", "kafka_partition", "kafka_offset")
        
        return parsed_stream
    
    def join_stream_with_dimensions(
        self,
        stream_df,
        join_configs: List[Dict]
    ):
        """
        Join streaming data with multiple Hive dimensions
        
        Args:
            stream_df: Streaming DataFrame
            join_configs: List of join configurations
                [{
                    'dimension': 'customers',
                    'join_keys': ['customer_id'],
                    'join_type': 'left',
                    'select_columns': ['customer_name', 'tier']
                }]
        """
        enriched_df = stream_df
        
        for join_config in join_configs:
            dimension_name = join_config['dimension']
            dimension_df = self.dimension_cache.get(dimension_name)
            
            if dimension_df is None:
                logger.warning(f"Dimension {dimension_name} not found in cache!")
                continue
            
            logger.info(f"Joining with dimension: {dimension_name}")
            
            # Build join condition
            join_keys = join_config['join_keys']
            join_type = join_config.get('join_type', 'left')
            
            if len(join_keys) == 1:
                join_condition = enriched_df[join_keys[0]] == dimension_df[join_keys[0]]
            else:
                conditions = [
                    enriched_df[key] == dimension_df[key]
                    for key in join_keys
                ]
                join_condition = conditions[0]
                for cond in conditions[1:]:
                    join_condition = join_condition & cond
            
            # Perform join
            enriched_df = enriched_df.join(
                dimension_df,
                join_condition,
                join_type
            )
            
            # Select specific columns if configured
            if 'select_columns' in join_config:
                # Keep original stream columns + selected dimension columns
                stream_cols = [col(c) for c in stream_df.columns]
                dim_cols = [
                    dimension_df[c].alias(f"{dimension_name}_{c}")
                    for c in join_config['select_columns']
                ]
                enriched_df = enriched_df.select(*stream_cols, *dim_cols)
        
        return enriched_df
    
    def write_stream(
        self,
        stream_df,
        output_config: Dict
    ):
        """
        Write enriched stream to output sink
        
        Args:
            stream_df: DataFrame to write
            output_config: Output configuration
        """
        output_format = output_config['format']
        output_mode = output_config.get('mode', 'append')
        
        logger.info(f"Writing stream to {output_format}")
        
        query_builder = stream_df.writeStream \
            .outputMode(output_mode) \
            .format(output_format)
        
        # Add options based on format
        if output_format == "delta":
            query_builder = query_builder \
                .option("path", output_config['path']) \
                .option("checkpointLocation", output_config['checkpoint'])
        
        elif output_format == "kafka":
            # Convert to Kafka format
            kafka_df = stream_df.select(
                to_json(struct(*stream_df.columns)).alias("value")
            )
            
            query_builder = kafka_df.writeStream \
                .outputMode(output_mode) \
                .format("kafka") \
                .option("kafka.bootstrap.servers", output_config['brokers']) \
                .option("topic", output_config['topic']) \
                .option("checkpointLocation", output_config['checkpoint'])
        
        elif output_format == "console":
            query_builder = query_builder \
                .option("truncate", False)
        
        # Start query
        query = query_builder.start()
        
        return query
    
    def run_pipeline(self):
        """
        Execute the complete pipeline
        """
        logger.info("Starting multi-source join pipeline...")
        
        try:
            # 1. Load Hive dimensions
            hive_tables = self.config['hive_tables']
            self.load_hive_dimensions(hive_tables)
            
            # 2. Read Kafka stream
            stream_df = self.read_kafka_stream(
                topic=self.config['kafka']['topic'],
                schema=self.config['kafka']['schema']
            )
            
            # 3. Join with dimensions
            enriched_df = self.join_stream_with_dimensions(
                stream_df=stream_df,
                join_configs=self.config['join_configs']
            )
            
            # 4. Add processing metadata
            enriched_df = enriched_df.withColumn(
                "processing_timestamp",
                current_timestamp()
            )
            
            # 5. Write output
            query = self.write_stream(
                stream_df=enriched_df,
                output_config=self.config['output']
            )
            
            logger.info("Pipeline started successfully!")
            
            return query
            
        except Exception as e:
            logger.error(f"Pipeline failed: {e}", exc_info=True)
            raise

# ==========================================
# CONFIGURATION & USAGE
# ==========================================

# Initialize Spark
spark = SparkSession.builder \
    .appName("MultiSource_Join_Production") \
    .config("spark.sql.catalogImplementation", "hive") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .enableHiveSupport() \
    .getOrCreate()

# Define transaction schema
transaction_schema = StructType([
    StructField("transaction_id", StringType(), False),
    StructField("customer_id", IntegerType(), False),
    StructField("product_id", StringType(), False),
    StructField("amount", DoubleType(), False),
    StructField("quantity", IntegerType(), False),
    StructField("transaction_timestamp", TimestampType(), False)
])

# Configuration
config = {
    'hive_tables': [
        'sales_db.customers',
        'sales_db.products'
    ],
    'filters': {
        'sales_db.customers': 'active = true',
        'sales_db.products': 'status = "available"'
    },
    'kafka': {
        'brokers': 'localhost:9092',
        'topic': 'transactions',
        'schema': transaction_schema,
        'starting_offsets': 'latest',
        'max_offsets_per_trigger': 10000
    },
    'join_configs': [
        {
            'dimension': 'sales_db.customers',
            'join_keys': ['customer_id'],
            'join_type': 'left',
            'select_columns': ['customer_name', 'customer_tier', 'credit_limit', 'region']
        },
        {
            'dimension': 'sales_db.products',
            'join_keys': ['product_id'],
            'join_type': 'left',
            'select_columns': ['product_name', 'category', 'unit_price']
        }
    ],
    'output': {
        'format': 'delta',
        'mode': 'append',
        'path': '/data/enriched_transactions',
        'checkpoint': '/data/checkpoints/enriched_transactions'
    }
}

# Run pipeline
pipeline = MultiSourceJoinPipeline(spark, config)
query = pipeline.run_pipeline()

# Keep running
query.awaitTermination()
```

## Solution 3: Handling Refreshing Hive Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from delta import *
import logging
import time
from threading import Thread

logger = logging.getLogger(__name__)

# ==========================================
# AUTO-REFRESHING DIMENSION TABLES
# ==========================================

class RefreshableDimensionJoin:
    """
    Join streaming data with auto-refreshing Hive dimensions
    """
    
    def __init__(self, spark: SparkSession, config: Dict):
        self.spark = spark
        self.config = config
        self.dimension_versions = {}
        self.refresh_enabled = True
    
    def load_dimension(self, table_name: str):
        """
        Load dimension table from Hive
        """
        logger.info(f"Loading dimension: {table_name}")
        
        df = self.spark.table(table_name)
        df.cache()
        count = df.count()
        
        logger.info(f"Loaded {count:,} records from {table_name}")
        
        return df
    
    def refresh_dimensions_periodically(self, refresh_interval_seconds: int = 300):
        """
        Refresh dimension tables periodically in background
        
        Args:
            refresh_interval_seconds: Refresh interval (default 5 minutes)
        """
        
        def refresh_loop():
            while self.refresh_enabled:
                try:
                    logger.info("Refreshing dimension tables...")
                    
                    for table_name in self.config['hive_tables']:
                        # Unpersist old version
                        if table_name in self.dimension_versions:
                            self.dimension_versions[table_name].unpersist()
                        
                        # Load new version
                        new_df = self.load_dimension(table_name)
                        self.dimension_versions[table_name] = new_df
                    
                    logger.info("Dimension refresh complete")
                    
                except Exception as e:
                    logger.error(f"Dimension refresh failed: {e}")
                
                # Sleep until next refresh
                time.sleep(refresh_interval_seconds)
        
        # Start refresh thread
        refresh_thread = Thread(target=refresh_loop, daemon=True)
        refresh_thread.start()
        logger.info(f"Started dimension refresh thread (interval: {refresh_interval_seconds}s)")
    
    def join_with_broadcast(self, stream_df, dimension_name: str, join_key: str):
        """
        Join using broadcast for small dimensions (< 10 MB)
        """
        from pyspark.sql.functions import broadcast
        
        dimension_df = self.dimension_versions[dimension_name]
        
        # Broadcast small dimension for efficiency
        enriched_df = stream_df.join(
            broadcast(dimension_df),
            stream_df[join_key] == dimension_df[join_key],
            "left"
        )
        
        return enriched_df
    
    def stop_refresh(self):
        """
        Stop dimension refresh
        """
        self.refresh_enabled = False
        logger.info("Stopped dimension refresh")

# ==========================================
# USAGE WITH AUTO-REFRESH
# ==========================================

spark = SparkSession.builder \
    .appName("AutoRefresh_Join") \
    .enableHiveSupport() \
    .getOrCreate()

config = {
    'hive_tables': ['sales_db.customers', 'sales_db.products'],
    'kafka': {...},
    'refresh_interval': 300  # 5 minutes
}

# Initialize with auto-refresh
pipeline = RefreshableDimensionJoin(spark, config)

# Start auto-refresh (runs in background)
pipeline.refresh_dimensions_periodically(
    refresh_interval_seconds=config['refresh_interval']
)

# Read stream and join
stream_df = spark.readStream.format("kafka")...

enriched_df = pipeline.join_with_broadcast(
    stream_df,
    dimension_name='sales_db.customers',
    join_key='customer_id'
)

# Write output
query = enriched_df.writeStream...

query.awaitTermination()
```

## Solution 4: Multiple Kafka Topics + Multiple Hive Tables

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging

logger = logging.getLogger(__name__)

# ==========================================
# COMPLEX MULTI-SOURCE JOIN
# ==========================================

spark = SparkSession.builder \
    .appName("Complex_MultiSource_Join") \
    .enableHiveSupport() \
    .getOrCreate()

# ==========================================
# READ MULTIPLE KAFKA TOPICS
# ==========================================

# Topic 1: Transactions
transaction_schema = StructType([
    StructField("transaction_id", StringType()),
    StructField("customer_id", IntegerType()),
    StructField("product_id", StringType()),
    StructField("amount", DoubleType()),
    StructField("timestamp", TimestampType())
])

transactions = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "transactions") \
    .load() \
    .select(
        from_json(col("value").cast("string"), transaction_schema).alias("data")
    ).select("data.*")

# Topic 2: Events
event_schema = StructType([
    StructField("event_id", StringType()),
    StructField("customer_id", IntegerType()),
    StructField("event_type", StringType()),
    StructField("timestamp", TimestampType())
])

events = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "customer_events") \
    .load() \
    .select(
        from_json(col("value").cast("string"), event_schema).alias("data")
    ).select("data.*")

# ==========================================
# READ MULTIPLE HIVE TABLES
# ==========================================

# Dimension 1: Customers
customers = spark.sql("""
    SELECT 
        customer_id,
        customer_name,
        customer_tier,
        region,
        signup_date
    FROM sales_db.customers
    WHERE active = true
""").cache()

# Dimension 2: Products
products = spark.sql("""
    SELECT 
        product_id,
        product_name,
        category,
        subcategory,
        unit_price
    FROM sales_db.products
    WHERE status = 'available'
""").cache()

# Dimension 3: Regions
regions = spark.sql("""
    SELECT 
        region,
        region_manager,
        sales_target
    FROM sales_db.regions
""").cache()

logger.info(f"Cached customers: {customers.count():,}")
logger.info(f"Cached products: {products.count():,}")
logger.info(f"Cached regions: {regions.count():,}")

# ==========================================
# COMPLEX JOINING
# ==========================================

# Step 1: Enrich transactions with customer info
transactions_with_customer = transactions.join(
    customers,
    "customer_id",
    "left"
)

# Step 2: Add product info
transactions_enriched = transactions_with_customer.join(
    products,
    "product_id",
    "left"
)

# Step 3: Add region info
transactions_fully_enriched = transactions_enriched.join(
    regions,
    "region",
    "left"
)

# Step 4: Add calculated fields
final_enriched = transactions_fully_enriched \
    .withColumn("revenue", col("amount") * col("unit_price")) \
    .withColumn("is_high_value", 
        when(col("amount") > col("sales_target") * 0.1, True).otherwise(False)
    ) \
    .withColumn("processing_time", current_timestamp())

# ==========================================
# WRITE TO DELTA LAKE
# ==========================================

query = final_enriched.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("path", "/data/enriched_transactions") \
    .option("checkpointLocation", "/data/checkpoints/enriched") \
    .partitionBy("region", "category") \
    .start()

logger.info("Complex multi-source join pipeline started!")

query.awaitTermination()
```

## Solution 5: Performance Optimization Tips

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.functions import broadcast

# ==========================================
# OPTIMIZATION STRATEGIES
# ==========================================

spark = SparkSession.builder \
    .appName("Optimized_MultiSource_Join") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.autoBroadcastJoinThreshold", "10485760")  # 10 MB \
    .enableHiveSupport() \
    .getOrCreate()

# ==========================================
# OPTIMIZATION 1: Broadcast Small Dimensions
# ==========================================

# For small dimensions (< 10 MB), use broadcast join
small_dimension = spark.table("sales_db.small_lookup").cache()

enriched = stream_df.join(
    broadcast(small_dimension),  # Broadcast to all executors
    "lookup_key",
    "left"
)

# ==========================================
# OPTIMIZATION 2: Filter Hive Data Early
# ==========================================

# Only load necessary columns and rows
customers = spark.sql("""
    SELECT 
        customer_id,
        customer_name,
        customer_tier
    FROM sales_db.customers
    WHERE active = true
      AND signup_date > '2020-01-01'
""").cache()

# ==========================================
# OPTIMIZATION 3: Partition Hive Tables
# ==========================================

# Read from partitioned Hive table efficiently
spark.sql("SET hive.exec.dynamic.partition = true")
spark.sql("SET hive.exec.dynamic.partition.mode = nonstrict")

# Only scan relevant partitions
customers = spark.sql("""
    SELECT *
    FROM sales_db.customers_partitioned
    WHERE year = 2026 AND month = 1
""").cache()

# ==========================================
# OPTIMIZATION 4: Coalesce Stream Before Join
# ==========================================

# Reduce shuffle before join
stream_df_coalesced = stream_df.coalesce(10)

enriched = stream_df_coalesced.join(
    dimension_df,
    "key",
    "left"
)

# ==========================================
# OPTIMIZATION 5: Monitor Join Performance
# ==========================================

def monitor_stream_metrics(query):
    """
    Monitor streaming query metrics
    """
    while query.isActive:
        status = query.lastProgress
        
        if status:
            logger.info(f"Input rows: {status['numInputRows']}")
            logger.info(f"Processing rate: {status['processedRowsPerSecond']}")
            logger.info(f"Batch duration: {status['batchDuration']}ms")
        
        time.sleep(30)

# Start monitoring
monitor_thread = Thread(target=monitor_stream_metrics, args=(query,))
monitor_thread.start()
```

## Complete End-to-End Example:

```python
#!/usr/bin/env python3
"""
Complete Multi-Source Join Pipeline
Joins Kafka streams with multiple Hive dimensions
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

def main():
    # Initialize Spark
    spark = SparkSession.builder \
        .appName("MultiSource_Join_Pipeline") \
        .config("spark.sql.catalogImplementation", "hive") \
        .enableHiveSupport() \
        .getOrCreate()
    
    try:
        logger.info("="*60)
        logger.info("MULTI-SOURCE JOIN PIPELINE")
        logger.info("="*60)
        
        # ==========================================
        # LOAD HIVE DIMENSIONS
        # ==========================================
        logger.info("\n1. Loading Hive dimensions...")
        
        customers = spark.table("sales_db.customers").cache()
        products = spark.table("sales_db.products").cache()
        
        logger.info(f"   Customers: {customers.count():,}")
        logger.info(f"   Products: {products.count():,}")
        
        # ==========================================
        # READ KAFKA STREAM
        # ==========================================
        logger.info("\n2. Reading Kafka stream...")
        
        schema = StructType([
            StructField("transaction_id", StringType()),
            StructField("customer_id", IntegerType()),
            StructField("product_id", StringType()),
            StructField("amount", DoubleType()),
            StructField("timestamp", TimestampType())
        ])
        
        transactions = spark.readStream \
            .format("kafka") \
            .option("kafka.bootstrap.servers", "localhost:9092") \
            .option("subscribe", "transactions") \
            .option("startingOffsets", "latest") \
            .load() \
            .select(
                from_json(col("value").cast("string"), schema).alias("data")
            ).select("data.*")
        
        logger.info("   Stream initialized")
        
        # ==========================================
        # ENRICH WITH JOINS
        # ==========================================
        logger.info("\n3. Enriching stream with dimensions...")
        
        enriched = transactions \
            .join(customers, "customer_id", "left") \
            .join(products, "product_id", "left") \
            .withColumn("processing_timestamp", current_timestamp()) \
            .select(
                "transaction_id",
                "customer_id",
                customers.customer_name,
                customers.customer_tier,
                "product_id",
                products.product_name,
                products.category,
                "amount",
                "timestamp",
                "processing_timestamp"
            )
        
        # ==========================================
        # WRITE OUTPUT
        # ==========================================
        logger.info("\n4. Starting streaming write...")
        
        query = enriched.writeStream \
            .outputMode("append") \
            .format("console") \
            .option("truncate", False) \
            .start()
        
        logger.info("\n✓ Pipeline started successfully!")
        logger.info("="*60)
        
        query.awaitTermination()
        
    except Exception as e:
        logger.error(f"Pipeline failed: {e}", exc_info=True)
        raise
    
    finally:
        spark.stop()

if __name__ == "__main__":
    main()
```

## Key Takeaways:

**Stream-Static Join Characteristics:**
1. ✅ **Static side loaded once** (or refreshed periodically)
2. ✅ **No watermark needed** (unlike stream-stream joins)
3. ✅ **Cache static data** for performance
4. ✅ **Use broadcast** for small dimensions (< 10 MB)
5. ✅ **Left join** to keep all stream records

**Best Practices:**
- Cache Hive tables for repeated joins
- Filter Hive data early (reduce memory)
- Use broadcast for small dimensions
- Implement refresh strategy for Hive data
- Monitor join performance
- Partition output for efficiency

**Performance Tips:**
- `broadcast()` for tables < 10 MB
- Partition Hive tables by date
- Filter unnecessary columns/rows
- Enable adaptive query execution
- Coalesce stream partitions before join

**Common Patterns:**
- **Star schema**: One fact stream + multiple dimensions
- **Incremental refresh**: Reload Hive tables periodically
- **Multi-level joins**: Stream → Dim1 → Dim2 → Dim3

This solution provides comprehensive approaches for joining Kafka streaming data with Hive batch data in production PySpark jobs!