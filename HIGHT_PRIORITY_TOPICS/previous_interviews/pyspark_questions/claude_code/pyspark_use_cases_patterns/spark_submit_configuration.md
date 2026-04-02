# PySpark Implementation: Spark-Submit Configuration and Tuning

## Problem Statement

In production environments, properly configuring `spark-submit` parameters is critical for job performance, resource utilization, and cost efficiency. Misconfigured Spark jobs can lead to out-of-memory errors, excessive shuffle spills, underutilized clusters, or wasted resources. A data engineer must understand how to calculate optimal executor sizing, tune memory parameters, and leverage dynamic allocation for varying workloads.

This guide covers the key `spark-submit` parameters, how to calculate optimal values for different cluster sizes, and best practices for production deployments.

---

## Key spark-submit Parameters

### Core Resource Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `--executor-memory` | Memory per executor | 1g |
| `--executor-cores` | CPU cores per executor | 1 |
| `--num-executors` | Number of executors | 2 |
| `--driver-memory` | Memory for the driver | 1g |
| `--driver-cores` | CPU cores for the driver | 1 |

### Sample Data

```python
# We'll use a simple workload to demonstrate the impact of different configurations
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import time

# Simulated large dataset scenario
# Imagine: 500GB of transaction data, 100M rows
# Cluster: 10 nodes, each with 16 cores and 64GB RAM

sample_data = [
    ("txn_001", "2024-01-15", "user_100", 250.00, "electronics"),
    ("txn_002", "2024-01-15", "user_101", 89.99, "clothing"),
    ("txn_003", "2024-01-15", "user_102", 1200.00, "electronics"),
    ("txn_004", "2024-01-16", "user_100", 45.50, "groceries"),
    ("txn_005", "2024-01-16", "user_103", 670.00, "furniture"),
    ("txn_006", "2024-01-17", "user_101", 32.00, "groceries"),
    ("txn_007", "2024-01-17", "user_104", 899.00, "electronics"),
    ("txn_008", "2024-01-18", "user_102", 150.00, "clothing"),
]

schema = StructType([
    StructField("txn_id", StringType()),
    StructField("txn_date", StringType()),
    StructField("user_id", StringType()),
    StructField("amount", DoubleType()),
    StructField("category", StringType()),
])
```

### Expected Output

Understanding how different configurations affect job execution time, memory usage, and resource utilization.

---

## Method 1: Basic spark-submit with Manual Configuration

### The Naive Approach (Anti-Pattern)

```bash
# DON'T DO THIS - uses defaults, wastes resources
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  my_job.py
```

### Properly Configured spark-submit

```bash
# Well-configured spark-submit for a 10-node cluster (16 cores, 64GB each)
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 19g \
  --executor-cores 5 \
  --num-executors 29 \
  --driver-memory 4g \
  --driver-cores 2 \
  --conf spark.sql.shuffle.partitions=200 \
  --conf spark.default.parallelism=200 \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.dynamicAllocation.enabled=false \
  my_job.py
```

### How to Calculate Optimal Values

```python
"""
=== EXECUTOR SIZING FORMULA ===

Given a cluster:
  - Nodes: 10
  - Cores per node: 16
  - RAM per node: 64 GB

Step 1: Reserve resources for OS and Hadoop daemons
  - Reserve 1 core per node for OS/HDFS/YARN daemons
  - Available cores per node = 16 - 1 = 15

Step 2: Choose executor cores (recommended: 5)
  - Too few cores (1-2): poor multithreading, high overhead
  - Too many cores (>5): excessive HDFS throughput bottleneck, GC pressure
  - Sweet spot: 5 cores per executor

Step 3: Calculate executors per node
  - Executors per node = Available cores / Executor cores = 15 / 5 = 3

Step 4: Calculate executor memory
  - Available RAM per node (after OS reserve ~1GB) = 63 GB
  - Memory per executor = 63 / 3 = 21 GB
  - Subtract overhead (max of 384MB or 10% of executor memory)
  - Overhead = max(384MB, 21 * 0.10) = 2.1 GB
  - Usable executor memory = 21 - 2.1 ~= 19 GB

Step 5: Calculate total executors
  - Total executors = (Executors per node * Nodes) - 1 (for ApplicationMaster)
  - Total executors = (3 * 10) - 1 = 29

FINAL CONFIGURATION:
  --executor-cores 5
  --executor-memory 19g
  --num-executors 29
"""

# Programmatic calculator
def calculate_spark_config(num_nodes, cores_per_node, ram_per_node_gb):
    """Calculate optimal spark-submit parameters."""
    
    # Step 1: Reserve for OS
    os_core_reserve = 1
    os_ram_reserve_gb = 1
    available_cores = cores_per_node - os_core_reserve
    available_ram = ram_per_node_gb - os_ram_reserve_gb
    
    # Step 2: Executor cores (5 is the sweet spot)
    executor_cores = 5
    
    # Step 3: Executors per node
    executors_per_node = available_cores // executor_cores
    
    # Step 4: Executor memory
    raw_memory_per_executor = available_ram / executors_per_node
    overhead = max(0.384, raw_memory_per_executor * 0.10)
    executor_memory = int(raw_memory_per_executor - overhead)
    
    # Step 5: Total executors (minus 1 for AM)
    total_executors = (executors_per_node * num_nodes) - 1
    
    config = {
        "executor_cores": executor_cores,
        "executor_memory_gb": executor_memory,
        "num_executors": total_executors,
        "executors_per_node": executors_per_node,
        "overhead_gb": round(overhead, 1),
        "total_cores": total_executors * executor_cores,
        "total_memory_gb": total_executors * executor_memory,
    }
    
    return config

# Example calculations for different cluster sizes
clusters = [
    {"name": "Small (5 nodes)", "nodes": 5, "cores": 8, "ram": 32},
    {"name": "Medium (10 nodes)", "nodes": 10, "cores": 16, "ram": 64},
    {"name": "Large (20 nodes)", "nodes": 20, "cores": 32, "ram": 128},
    {"name": "XLarge (50 nodes)", "nodes": 50, "cores": 48, "ram": 256},
]

for cluster in clusters:
    config = calculate_spark_config(cluster["nodes"], cluster["cores"], cluster["ram"])
    print(f"\n{'='*60}")
    print(f"Cluster: {cluster['name']}")
    print(f"  Nodes: {cluster['nodes']} x {cluster['cores']} cores x {cluster['ram']}GB")
    print(f"  --executor-cores {config['executor_cores']}")
    print(f"  --executor-memory {config['executor_memory_gb']}g")
    print(f"  --num-executors {config['num_executors']}")
    print(f"  Total parallelism: {config['total_cores']} cores")
    print(f"  Total memory: {config['total_memory_gb']}GB")
```

---

## Method 2: Dynamic Allocation

```bash
# spark-submit with dynamic allocation enabled
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 19g \
  --executor-cores 5 \
  --driver-memory 4g \
  --conf spark.dynamicAllocation.enabled=true \
  --conf spark.dynamicAllocation.minExecutors=5 \
  --conf spark.dynamicAllocation.maxExecutors=50 \
  --conf spark.dynamicAllocation.initialExecutors=10 \
  --conf spark.dynamicAllocation.executorIdleTimeout=60s \
  --conf spark.dynamicAllocation.schedulerBacklogTimeout=1s \
  --conf spark.dynamicAllocation.sustainedSchedulerBacklogTimeout=5s \
  --conf spark.shuffle.service.enabled=true \
  my_job.py
```

```python
"""
Dynamic Allocation Parameters Explained:

spark.dynamicAllocation.enabled=true
  - Spark automatically adds/removes executors based on workload

spark.dynamicAllocation.minExecutors=5
  - Minimum executors to keep alive (prevents cold start on spikes)

spark.dynamicAllocation.maxExecutors=50
  - Cap to prevent consuming entire cluster

spark.dynamicAllocation.initialExecutors=10
  - Start with this many (ramps up/down from here)

spark.dynamicAllocation.executorIdleTimeout=60s
  - Remove idle executors after 60 seconds

spark.dynamicAllocation.schedulerBacklogTimeout=1s
  - Add executors if tasks are pending for 1 second

spark.shuffle.service.enabled=true
  - REQUIRED: external shuffle service so shuffle data survives
    executor removal
"""

# PySpark code demonstrating dynamic allocation in action
spark = SparkSession.builder \
    .appName("DynamicAllocationDemo") \
    .config("spark.dynamicAllocation.enabled", "true") \
    .config("spark.dynamicAllocation.minExecutors", "2") \
    .config("spark.dynamicAllocation.maxExecutors", "20") \
    .config("spark.dynamicAllocation.initialExecutors", "5") \
    .config("spark.dynamicAllocation.executorIdleTimeout", "60s") \
    .config("spark.shuffle.service.enabled", "true") \
    .getOrCreate()

# Monitor executor count during job
def log_executor_info(spark):
    sc = spark.sparkContext
    print(f"Active executors: {sc._jsc.sc().getExecutorMemoryStatus().size()}")

# Phase 1: Light workload (fewer executors needed)
df_small = spark.createDataFrame(sample_data, schema)
result_small = df_small.groupBy("category").agg(sum("amount"))
result_small.show()
log_executor_info(spark)

# Phase 2: Heavy workload (more executors auto-added)
df_large = df_small
for _ in range(10):
    df_large = df_large.union(df_small)

result_large = df_large.repartition(200).groupBy("user_id", "category") \
    .agg(sum("amount"), count("*"))
result_large.show()
log_executor_info(spark)
```

---

## Method 3: Memory Tuning Deep Dive

```python
"""
Spark Memory Architecture per Executor:

Total Executor Memory (--executor-memory) = 19 GB
  |
  ├── Execution Memory (shuffle, join, sort, aggregation)
  |     Default: 50% of (heap - 300MB reserved)
  |     = 0.5 * (19GB - 300MB) ~ 9.35 GB
  |
  ├── Storage Memory (cache, broadcast variables)
  |     Default: 50% of (heap - 300MB reserved)
  |     = 0.5 * (19GB - 300MB) ~ 9.35 GB
  |
  └── Reserved Memory: 300MB (Spark internal)

NOTE: Since Spark 1.6, Execution and Storage share a unified pool.
      Execution can borrow from Storage and vice versa.
      spark.memory.fraction = 0.6 (total for both)
      spark.memory.storageFraction = 0.5 (storage's share within that)

Plus OFF-HEAP:
  Memory Overhead = max(384MB, 0.10 * executor-memory) = 1.9 GB
  Used for: VM overhead, interned strings, NIO buffers, Netty
"""

spark = SparkSession.builder \
    .appName("MemoryTuningDemo") \
    .config("spark.executor.memory", "19g") \
    .config("spark.executor.memoryOverhead", "2g") \
    .config("spark.memory.fraction", "0.6") \
    .config("spark.memory.storageFraction", "0.5") \
    .config("spark.memory.offHeap.enabled", "true") \
    .config("spark.memory.offHeap.size", "4g") \
    .getOrCreate()

# Scenario: Large join causing OOM
# BEFORE tuning (might OOM):
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "10485760")  # 10MB default

# AFTER tuning for large joins:
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")  # disable broadcast
spark.conf.set("spark.memory.fraction", "0.8")  # more memory for execution
spark.conf.set("spark.memory.storageFraction", "0.3")  # less for caching

# Scenario: Heavy caching workload
spark.conf.set("spark.memory.fraction", "0.75")
spark.conf.set("spark.memory.storageFraction", "0.6")  # more for storage/cache

# Check current memory configuration
print("Memory Fraction:", spark.conf.get("spark.memory.fraction"))
print("Storage Fraction:", spark.conf.get("spark.memory.storageFraction"))
```

---

## Method 4: Configuration for Different Workload Types

```bash
# === ETL Batch Job (Heavy shuffles, large data) ===
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 19g \
  --executor-cores 5 \
  --num-executors 29 \
  --driver-memory 4g \
  --conf spark.sql.shuffle.partitions=400 \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  --conf spark.sql.adaptive.skewJoin.enabled=true \
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.sql.parquet.compression.codec=snappy \
  --conf spark.sql.files.maxPartitionBytes=134217728 \
  etl_job.py

# === Streaming Job (Low latency, sustained resources) ===
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 8g \
  --executor-cores 3 \
  --num-executors 10 \
  --driver-memory 4g \
  --conf spark.streaming.backpressure.enabled=true \
  --conf spark.sql.shuffle.partitions=50 \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.executor.heartbeatInterval=20s \
  --conf spark.network.timeout=300s \
  streaming_job.py

# === ML Training Job (Memory intensive, iterative) ===
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --executor-memory 24g \
  --executor-cores 4 \
  --num-executors 15 \
  --driver-memory 8g \
  --conf spark.memory.fraction=0.8 \
  --conf spark.memory.storageFraction=0.4 \
  --conf spark.kryoserializer.buffer.max=1024m \
  --conf spark.driver.maxResultSize=4g \
  --conf spark.rpc.message.maxSize=256 \
  ml_training.py

# === Interactive / Ad-hoc Queries ===
spark-submit \
  --master yarn \
  --deploy-mode client \
  --executor-memory 8g \
  --executor-cores 3 \
  --conf spark.dynamicAllocation.enabled=true \
  --conf spark.dynamicAllocation.minExecutors=2 \
  --conf spark.dynamicAllocation.maxExecutors=20 \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.localShuffleReader.enabled=true \
  interactive_queries.py
```

```python
# Full working example with configuration profiles
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

def create_spark_session(profile="default"):
    """Create SparkSession with predefined configuration profiles."""
    
    profiles = {
        "etl_heavy": {
            "spark.executor.memory": "19g",
            "spark.executor.cores": "5",
            "spark.sql.shuffle.partitions": "400",
            "spark.sql.adaptive.enabled": "true",
            "spark.sql.adaptive.coalescePartitions.enabled": "true",
            "spark.sql.adaptive.skewJoin.enabled": "true",
            "spark.serializer": "org.apache.spark.serializer.KryoSerializer",
        },
        "streaming": {
            "spark.executor.memory": "8g",
            "spark.executor.cores": "3",
            "spark.sql.shuffle.partitions": "50",
            "spark.streaming.backpressure.enabled": "true",
            "spark.dynamicAllocation.enabled": "false",
        },
        "ml_training": {
            "spark.executor.memory": "24g",
            "spark.executor.cores": "4",
            "spark.memory.fraction": "0.8",
            "spark.memory.storageFraction": "0.4",
            "spark.driver.maxResultSize": "4g",
        },
        "default": {
            "spark.executor.memory": "4g",
            "spark.executor.cores": "2",
            "spark.sql.adaptive.enabled": "true",
        },
    }
    
    builder = SparkSession.builder.appName(f"Job_{profile}")
    
    for key, value in profiles.get(profile, profiles["default"]).items():
        builder = builder.config(key, value)
    
    return builder.getOrCreate()

# Usage
spark = create_spark_session("etl_heavy")

# Create sample data and run workload
data = [
    ("txn_001", "2024-01-15", "user_100", 250.00, "electronics"),
    ("txn_002", "2024-01-15", "user_101", 89.99, "clothing"),
    ("txn_003", "2024-01-15", "user_102", 1200.00, "electronics"),
    ("txn_004", "2024-01-16", "user_100", 45.50, "groceries"),
    ("txn_005", "2024-01-16", "user_103", 670.00, "furniture"),
]

schema = StructType([
    StructField("txn_id", StringType()),
    StructField("txn_date", StringType()),
    StructField("user_id", StringType()),
    StructField("amount", DoubleType()),
    StructField("category", StringType()),
])

df = spark.createDataFrame(data, schema)

# Verify configuration at runtime
print("=== Active Configuration ===")
for key in ["spark.executor.memory", "spark.executor.cores",
            "spark.sql.shuffle.partitions", "spark.sql.adaptive.enabled"]:
    print(f"  {key} = {spark.conf.get(key, 'not set')}")

# Run a workload
result = df.groupBy("category").agg(
    count("*").alias("txn_count"),
    sum("amount").alias("total_amount"),
    avg("amount").alias("avg_amount")
)

result.show()
# +------------+---------+------------+----------+
# |    category|txn_count|total_amount|avg_amount|
# +------------+---------+------------+----------+
# | electronics|        2|      1450.0|     725.0|
# |    clothing|        1|       89.99|     89.99|
# |   groceries|        1|        45.5|      45.5|
# |   furniture|        1|       670.0|     670.0|
# +------------+---------+------------+----------+

spark.stop()
```

---

## Method 5: Advanced --conf Options Reference

```bash
# === Comprehensive production spark-submit ===
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --name "Production_ETL_Daily" \
  --queue production \
  \
  # Resource allocation
  --executor-memory 19g \
  --executor-cores 5 \
  --num-executors 29 \
  --driver-memory 4g \
  --driver-cores 2 \
  \
  # Serialization
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryoserializer.buffer=64m \
  --conf spark.kryoserializer.buffer.max=512m \
  \
  # Shuffle tuning
  --conf spark.sql.shuffle.partitions=200 \
  --conf spark.shuffle.compress=true \
  --conf spark.shuffle.spill.compress=true \
  --conf spark.reducer.maxSizeInFlight=96m \
  --conf spark.shuffle.file.buffer=1m \
  \
  # Adaptive Query Execution (Spark 3.x)
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.minPartitionSize=64m \
  --conf spark.sql.adaptive.skewJoin.enabled=true \
  --conf spark.sql.adaptive.skewJoin.skewedPartitionFactor=5 \
  --conf spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes=256m \
  --conf spark.sql.adaptive.localShuffleReader.enabled=true \
  \
  # I/O and compression
  --conf spark.sql.parquet.compression.codec=snappy \
  --conf spark.sql.files.maxPartitionBytes=134217728 \
  --conf spark.sql.files.openCostInBytes=4194304 \
  \
  # Network and timeout
  --conf spark.network.timeout=600s \
  --conf spark.executor.heartbeatInterval=30s \
  --conf spark.rpc.message.maxSize=256 \
  \
  # Speculation (retry slow tasks)
  --conf spark.speculation=true \
  --conf spark.speculation.multiplier=1.5 \
  --conf spark.speculation.quantile=0.9 \
  \
  # GC tuning
  --conf spark.executor.extraJavaOptions="-XX:+UseG1GC -XX:G1HeapRegionSize=16m -XX:InitiatingHeapOccupancyPercent=35" \
  \
  # Dependencies
  --jars /path/to/extra.jar \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
  --py-files utils.zip \
  \
  main_etl.py --date 2024-01-15 --env production
```

```python
# Inspecting and validating configuration at runtime
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("ConfigInspector") \
    .getOrCreate()

# Print all active Spark configurations
all_configs = spark.sparkContext.getConf().getAll()
print("=== All Spark Configurations ===")
for key, value in sorted(all_configs):
    print(f"  {key} = {value}")

# Key configs to validate in production
critical_configs = [
    "spark.executor.memory",
    "spark.executor.cores",
    "spark.executor.instances",
    "spark.driver.memory",
    "spark.sql.shuffle.partitions",
    "spark.sql.adaptive.enabled",
    "spark.dynamicAllocation.enabled",
    "spark.serializer",
    "spark.sql.adaptive.skewJoin.enabled",
]

print("\n=== Critical Configuration Check ===")
for config in critical_configs:
    value = spark.conf.get(config, "NOT SET")
    print(f"  {config}: {value}")

# Check cluster resources
sc = spark.sparkContext
print(f"\nDefault Parallelism: {sc.defaultParallelism}")
print(f"Application ID: {sc.applicationId}")
print(f"Master: {sc.master}")

spark.stop()
```

---

## Key Takeaways

1. **The 5-core rule**: Keep executor cores at 5 or fewer to avoid HDFS throughput bottlenecks and excessive GC pauses.

2. **Memory overhead matters**: Always account for the 10% (or 384MB minimum) overhead that sits outside the JVM heap. Forgetting this causes container kills by YARN.

3. **Leave room for the AM**: Subtract 1 executor from your total to account for the YARN ApplicationMaster container.

4. **Dynamic allocation for variable workloads**: Use it for ad-hoc queries and jobs with varying data sizes. Disable it for streaming jobs that need stable resources.

5. **AQE is a game-changer**: In Spark 3.x, always enable Adaptive Query Execution. It auto-tunes shuffle partitions, handles skew, and optimizes joins at runtime.

6. **Profile your workloads**: ETL, streaming, and ML jobs have fundamentally different resource profiles. Never use one-size-fits-all configuration.

7. **deploy-mode cluster vs client**: Use `cluster` for production (driver runs on cluster, survives client disconnect). Use `client` for debugging (logs visible locally).

## Interview Tips

- When asked about spark-submit tuning, always walk through the **calculation formula** step by step. Interviewers want to see you can derive values, not just recite them.
- Mention the **tradeoff** between fewer large executors vs. many small executors (GC pressure vs. parallelism).
- Know that `spark.sql.shuffle.partitions` defaults to 200, which is often too many for small datasets and too few for large ones. AQE fixes this dynamically.
- Always mention **external shuffle service** when discussing dynamic allocation -- it is a hard requirement.
- Be ready to explain what happens when you set executor memory too high (GC pauses, YARN container overhead) or too low (spills to disk, OOM errors).
