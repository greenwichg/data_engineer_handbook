# Spark Distributed Hardware Configuration - Calculation Framework

> Step-by-step calculation worksheet to derive **every** Spark configuration parameter for processing **5 TB** of data.
> Each value is computed from formulas - no magic numbers.

---

## TABLE OF CONTENTS

```
01. Inputs & Assumptions
02. STEP 1: Cores Per Executor
03. STEP 2: Executors Per Node
04. STEP 3: Executor Memory
05. STEP 4: Executor Memory Overhead
06. STEP 5: Number of Worker Nodes
07. STEP 6: Total Executors Across Cluster
08. STEP 7: Driver Memory
09. STEP 8: Driver Memory Overhead
10. STEP 9: Driver Max Result Size
11. STEP 10: Memory Fractions (Execution / Storage / User)
12. STEP 11: Off-Heap Memory
13. STEP 12: Shuffle Partitions
14. STEP 13: Default Parallelism
15. STEP 14: Broadcast Join Threshold
16. STEP 15: Partition Size Per Task
17. STEP 16: Output File Count & Size
18. STEP 17: Shuffle Disk (Local Storage)
19. STEP 18: Network & Timeout Settings
20. STEP 19: GC Tuning
21. STEP 20: Serialization
22. STEP 21: Dynamic Allocation Bounds
23. STEP 22: Speculation Settings
24. STEP 23: Compression Codec
25. STEP 24: Data Partitioning (Write Layout)
26. STEP 25: Number of Partitions — Master Formula (5 TB)
27. Full Calculation Summary
28. Final spark-submit Command
29. Scaling Formula: Any Data Size
30. Verification Checklist
```

---

## 1. Inputs & Assumptions

```
GIVEN:
  Data Size on Disk (compressed Parquet) ............ D = 5 TB = 5,120 GB
  Parquet Compression Ratio ......................... CR = 3x (typical Snappy)
  Shuffle Expansion Factor .......................... SF = 2x (joins/aggregations)
  Node Instance Type ................................ r5.4xlarge (AWS) or equivalent
  vCPUs per Node .................................... C_node = 16
  RAM per Node ...................................... M_node = 128 GB
  Local SSD per Node ................................ S_node = 500 GB (NVMe)
  OS + YARN/Hadoop Daemon Reserve per Node .......... OS_reserve = 1 core, 8 GB RAM
  Available Cores per Node .......................... C_avail = C_node - 1 = 15
  Available RAM per Node ............................ M_avail = M_node - OS_reserve = 120 GB
```

---

## 2. STEP 1: Cores Per Executor

```
FORMULA:
  cores_per_executor = 5

WHY 5?
  - HDFS I/O is optimized for 5 concurrent threads per JVM
  - > 5 cores → diminishing HDFS throughput, excessive GC pressure
  - < 3 cores → poor parallelism within executor
  - 5 is the industry-standard sweet spot (validated by Cloudera, Databricks)

CALCULATION:
  cores_per_executor = 5 ✅
```

**Config:** `spark.executor.cores = 5`

---

## 3. STEP 2: Executors Per Node

```
FORMULA:
  executors_per_node = floor(C_avail / cores_per_executor)
  executors_per_node = floor(15 / 5)
  executors_per_node = 3

BREAKDOWN:
  Total cores per node ............ 16
  Reserved for OS/YARN daemon ..... 1
  Available for Spark ............. 15
  Cores per executor .............. 5
  Executors that fit .............. 15 / 5 = 3

VERIFY:
  3 executors × 5 cores = 15 cores used
  1 core left for OS/daemons ✅
```

**Config:** _(derived, not a direct config - used in `spark.executor.instances`)_

---

## 4. STEP 3: Executor Memory

```
FORMULA:
  executor_memory = floor(M_avail / executors_per_node)
  executor_memory = floor(120 GB / 3)
  executor_memory = 40 GB

BUT we need to subtract overhead (calculated in Step 4), so:
  total_container_memory = floor(M_avail / executors_per_node) = 40 GB
  executor_memory = total_container_memory - memory_overhead  (see Step 4)

AFTER OVERHEAD SUBTRACTION:
  executor_memory = 40 GB - 4 GB = 36 GB

VERIFY:
  3 executors × 40 GB container = 120 GB ≤ 120 GB available ✅
  Each JVM heap = 36 GB (manageable for G1GC) ✅
```

**Config:** `spark.executor.memory = 36g`

---

## 5. STEP 4: Executor Memory Overhead

```
FORMULA:
  memory_overhead = max(384 MB, total_container_memory × 0.10)
  memory_overhead = max(384 MB, 40 GB × 0.10)
  memory_overhead = max(384 MB, 4 GB)
  memory_overhead = 4 GB

WHAT OVERHEAD COVERS:
  - Python process memory (PySpark)
  - JVM internal overhead (thread stacks, class metadata)
  - NIO direct buffers (network I/O)
  - Container safety margin

VERIFY:
  executor_memory + overhead = 36 GB + 4 GB = 40 GB = total_container_memory ✅
```

**Config:** `spark.executor.memoryOverhead = 4g`

---

## 6. STEP 5: Number of Worker Nodes

```
FORMULA:
  data_in_memory = D × CR = 5 TB × 3 = 15 TB = 15,360 GB
  peak_memory = data_in_memory × SF = 15 TB × 2 = 30 TB = 30,720 GB

  nodes_needed = ceil(peak_memory / M_avail)
  nodes_needed = ceil(30,720 GB / 120 GB)
  nodes_needed = ceil(256)
  nodes_needed = 256  ← This is if ALL data must be in memory at once

BUT Spark processes in stages (not all at once):
  active_data_fraction = 0.10 to 0.30  (only 10-30% of data active at any time)
  effective_memory_needed = peak_memory × active_data_fraction

  CONSERVATIVE (30%): 30,720 × 0.30 = 9,216 GB → ceil(9,216 / 120) = 77 nodes
  MODERATE (15%):     30,720 × 0.15 = 4,608 GB → ceil(4,608 / 120) = 39 nodes
  OPTIMISTIC (10%):   30,720 × 0.10 = 3,072 GB → ceil(3,072 / 120) = 26 nodes

RECOMMENDATION:
  nodes = 25 worker nodes (start here, scale if spilling/OOM)

VERIFY:
  Total cluster RAM = 25 × 128 GB = 3,200 GB = 3.1 TB
  Total usable RAM  = 25 × 120 GB = 3,000 GB = 2.9 TB
  Data / Cluster RAM ratio = 5 TB / 3.1 TB = 1.6x ← acceptable for staged processing ✅
```

**Config:** _(determines cluster size at provisioning time)_

---

## 7. STEP 6: Total Executors Across Cluster

```
FORMULA:
  total_executors = nodes × executors_per_node
  total_executors = 25 × 3
  total_executors = 75

DERIVED:
  total_cores = total_executors × cores_per_executor = 75 × 5 = 375 cores
  total_executor_memory = total_executors × executor_memory = 75 × 36 GB = 2,700 GB

VERIFY:
  375 cores processing 5 TB → each core handles ~13.6 GB input ✅
  2,700 GB total executor memory available ✅
```

**Config:** `spark.executor.instances = 75`
_(or use dynamic allocation, see Step 21)_

---

## 8. STEP 7: Driver Memory

```
FORMULA:
  driver_memory = max(
    broadcast_data_size × 2,
    max_collect_result_size × 2,
    base_minimum (4 GB)
  )

CALCULATION:
  Largest broadcast table .............. ~1 GB (estimated dimension table)
  Max collect result ................... ~2 GB (summary data)
  Metadata overhead .................... ~2 GB (job DAG, task tracking for 75 executors)

  driver_memory = max(1 × 2, 2 × 2, 4)
  driver_memory = max(2, 4, 4)
  driver_memory = 8 GB  (minimum for 5 TB job)

  RECOMMENDED: 8-16 GB (use 10 GB for safety)

WHY NOT MORE?
  - Driver doesn't process data
  - Only coordinates and collects small results
  - Large driver memory = wasted resources
```

**Config:** `spark.driver.memory = 10g`

---

## 9. STEP 8: Driver Memory Overhead

```
FORMULA:
  driver_memory_overhead = max(384 MB, driver_memory × 0.10)
  driver_memory_overhead = max(384 MB, 10 GB × 0.10)
  driver_memory_overhead = max(384 MB, 1 GB)
  driver_memory_overhead = 1 GB

  RECOMMENDED: Round up to 2 GB for safety with large job graphs
```

**Config:** `spark.driver.memoryOverhead = 2g`

---

## 10. STEP 9: Driver Max Result Size

```
FORMULA:
  max_result_size = min(driver_memory × 0.40, 4 GB)
  max_result_size = min(10 × 0.40, 4)
  max_result_size = min(4, 4)
  max_result_size = 4 GB

PURPOSE:
  - Limits serialized result sent back to driver per action
  - Prevents driver OOM from large collect() calls
  - If exceeded → "Total size of serialized results is bigger than spark.driver.maxResultSize"
```

**Config:** `spark.driver.maxResultSize = 4g`

---

## 11. STEP 10: Memory Fractions (Execution / Storage / User)

```
EXECUTOR MEMORY LAYOUT:

  executor_memory (JVM Heap) = 36 GB
  ├── reserved_memory = 300 MB (fixed, Spark internal)
  └── usable_memory = 36 GB - 300 MB = 35.7 GB

FORMULA:
  unified_memory = usable_memory × spark.memory.fraction
  unified_memory = 35.7 GB × 0.6
  unified_memory = 21.4 GB

  storage_memory (initial) = unified_memory × spark.memory.storageFraction
  storage_memory = 21.4 GB × 0.5
  storage_memory = 10.7 GB     ← for cached DataFrames/RDDs

  execution_memory (initial) = unified_memory - storage_memory
  execution_memory = 21.4 GB - 10.7 GB
  execution_memory = 10.7 GB   ← for shuffles, joins, sorts, aggregations

  user_memory = usable_memory - unified_memory
  user_memory = 35.7 GB - 21.4 GB
  user_memory = 14.3 GB        ← for UDFs, metadata, user data structures

FULL BREAKDOWN PER EXECUTOR:
  ┌─────────────────────────────────────────────┐
  │ Total Container: 40 GB                      │
  ├─────────────────────────────────────────────┤
  │ Memory Overhead (off-heap): 4 GB            │
  ├─────────────────────────────────────────────┤
  │ JVM Heap: 36 GB                             │
  │ ├── Reserved: 0.3 GB                        │
  │ ├── Unified Memory: 21.4 GB                 │
  │ │   ├── Execution: 10.7 GB (shuffle/join)   │
  │ │   └── Storage: 10.7 GB (cache)            │
  │ └── User Memory: 14.3 GB (UDFs/metadata)    │
  └─────────────────────────────────────────────┘

WHEN TO ADJUST:
  - Heavy caching needed → increase storageFraction to 0.7
  - Heavy shuffles/joins → decrease storageFraction to 0.3
  - Many UDFs → keep default (user memory stays at 40%)
```

**Config:**
```
spark.memory.fraction = 0.6
spark.memory.storageFraction = 0.5
```

---

## 12. STEP 11: Off-Heap Memory

```
FORMULA:
  offheap_size = executor_memory × 0.10 to 0.15  (for Tungsten optimized operations)
  offheap_size = 36 GB × 0.10
  offheap_size = 3.6 GB ≈ 4 GB

WHEN NEEDED:
  - Large sort/merge operations
  - Tungsten binary processing
  - Reducing GC pressure on large heaps

NOTE: This is INSIDE the memory_overhead (not additive to container)
```

**Config:**
```
spark.memory.offHeap.enabled = true
spark.memory.offHeap.size = 4g
```

---

## 13. STEP 12: Shuffle Partitions

```
METHOD 1: Based on data size (primary method)
  FORMULA:
    shuffle_data = D × CR × shuffle_selectivity
    shuffle_data = 5 TB × 3 × 0.5  (assume 50% of data survives filters before shuffle)
    shuffle_data = 7.5 TB = 7,680 GB

    target_partition_size = 256 MB  (sweet spot: 128 MB - 1 GB)
    shuffle_partitions = shuffle_data / target_partition_size
    shuffle_partitions = 7,680 GB / 0.256 GB
    shuffle_partitions = 30,000  ← upper bound

  With AQE enabled, start higher and let Spark coalesce down.

METHOD 2: Based on total cores (secondary method)
  FORMULA:
    shuffle_partitions = total_cores × parallelism_multiplier
    shuffle_partitions = 375 × 3 to 8
    shuffle_partitions = 1,125 to 3,000

METHOD 3: Balanced (recommended)
  FORMULA:
    shuffle_partitions = max(total_cores × 4, D_GB / target_partition_size_GB)
    shuffle_partitions = max(375 × 4, 5120 / 1)
    shuffle_partitions = max(1500, 5120)
    shuffle_partitions = 5,120

  RECOMMENDED: 2,000 - 5,000 with AQE enabled to auto-coalesce

VERIFY:
  5 TB / 2000 partitions = 2.56 GB per partition → acceptable for 36 GB executor ✅
  5 TB / 5000 partitions = 1.02 GB per partition → optimal ✅
```

**Config:** `spark.sql.shuffle.partitions = 3000`

---

## 14. STEP 13: Default Parallelism

```
FORMULA (for RDD operations):
  default_parallelism = total_cores × 2 to 3
  default_parallelism = 375 × 2
  default_parallelism = 750

NOTE:
  - This applies to RDD operations (groupByKey, reduceByKey)
  - DataFrame/SQL uses spark.sql.shuffle.partitions instead
  - Set both for completeness
```

**Config:** `spark.default.parallelism = 750`

---

## 15. STEP 14: Broadcast Join Threshold

```
FORMULA:
  broadcast_threshold = min(
    executor_memory × 0.15,    (< 15% of executor memory)
    driver_memory × 0.50,      (< 50% of driver memory, must fit in driver)
    practical_limit             (network transfer time must be reasonable)
  )

CALCULATION:
  executor_limit = 36 GB × 0.15 = 5.4 GB
  driver_limit = 10 GB × 0.50 = 5 GB
  practical_limit = 1 GB  (transfers quickly over network)

  broadcast_threshold = min(5.4 GB, 5 GB, 1 GB)
  broadcast_threshold = 1 GB

  For 5 TB workloads, many dimension tables are 100 MB - 2 GB.
  RECOMMENDED: 256 MB (conservative) to 1 GB (aggressive)

WHY THIS MATTERS:
  - Tables under this size → Broadcast Hash Join (fast, no shuffle)
  - Tables over this size → Sort Merge Join (shuffle required)
  - For 5 TB fact table joined with 500 MB dim table → broadcast the dim table
```

**Config:** `spark.sql.autoBroadcastJoinThreshold = 256MB`

---

## 16. STEP 15: Partition Size Per Task

```
FORMULA:
  memory_per_task = execution_memory / cores_per_executor
  memory_per_task = 10.7 GB / 5
  memory_per_task = 2.14 GB

  max_partition_size = memory_per_task × safety_factor
  max_partition_size = 2.14 GB × 0.80
  max_partition_size = 1.71 GB

  RECOMMENDED target_partition_size = 256 MB to 1 GB
  (well within the 1.71 GB limit per task)

VERIFY:
  With 3000 shuffle partitions:
    partition_size = 5 TB / 3000 = 1.7 GB  → borderline, increase partitions or memory
  With 5000 shuffle partitions:
    partition_size = 5 TB / 5000 = 1.0 GB  → good ✅
  With 3000 shuffle partitions (post-filter, 50% selectivity):
    partition_size = 2.5 TB / 3000 = 0.85 GB → good ✅
```

---

## 17. STEP 16: Output File Count & Size

```
FORMULA:
  target_output_file_size = 256 MB to 1 GB (Parquet best practice)
  output_data_size = result size after transformations

  If output ≈ 5 TB (similar size to input):
    output_files = output_data_size / target_file_size
    output_files = 5,120 GB / 0.512 GB
    output_files = 10,000 files (at 512 MB each)

  If output ≈ 500 GB (heavy aggregation):
    output_files = 500 GB / 0.256 GB
    output_files = ~2,000 files (at 256 MB each)

REPARTITION BEFORE WRITE:
  df.repartition(num_output_files).write.parquet(...)

  OR let coalesce handle it:
  df.coalesce(num_output_files).write.parquet(...)
```

---

## 18. STEP 17: Shuffle Disk (Local Storage)

```
FORMULA:
  shuffle_data_per_node = (D × CR × SF) / nodes
  shuffle_data_per_node = (5 TB × 3 × 2) / 25
  shuffle_data_per_node = 30 TB / 25
  shuffle_data_per_node = 1.2 TB  ← worst case (all data shuffled)

  With compression (shuffle.compress = true, ~2x reduction):
    shuffle_disk_per_node = 1.2 TB / 2 = 600 GB

  Safety margin (1.5x):
    required_local_disk = 600 GB × 1.5 = 900 GB

  RECOMMENDED: 500 GB - 1 TB NVMe SSD per node

NOTE: Not all data is shuffled at once. Spark processes in stages.
  Realistic shuffle per node per stage = 100-300 GB
  500 GB NVMe is sufficient for most workloads ✅
```

**Config:** `spark.local.dir = /mnt/nvme1,/mnt/nvme2`

---

## 19. STEP 18: Network & Timeout Settings

```
FORMULA:
  shuffle_transfer_time = largest_shuffle_stage / network_bandwidth
  largest_shuffle_stage = 5 TB (worst case: full data shuffle)
  network_bandwidth = 10 Gbps per node × 25 nodes = 250 Gbps cluster bisection

  transfer_time = 5 TB / (250 Gbps / 8) = 5,120 GB / 31.25 GB/s = 164 seconds

  timeout = transfer_time × safety_multiplier
  timeout = 164 × 3 = 492 seconds ≈ 600 seconds (10 minutes)

CALCULATION:
  network_timeout = 600s
  rpc_timeout = 600s
  broadcast_timeout = 600s
  shuffle_io_retries = 10  (for transient network failures)
  shuffle_io_retry_wait = 30s
```

**Config:**
```
spark.network.timeout = 600s
spark.rpc.askTimeout = 600s
spark.sql.broadcastTimeout = 600s
spark.shuffle.io.maxRetries = 10
spark.shuffle.io.retryWait = 30s
```

---

## 20. STEP 19: GC Tuning

```
DECISION:
  IF executor_memory > 32 GB → Use G1GC
  IF executor_memory ≤ 32 GB → Default (Parallel GC) is fine

  executor_memory = 36 GB > 32 GB → Use G1GC ✅

G1GC SETTINGS:
  InitiatingHeapOccupancyPercent = 35  (start GC earlier to avoid long pauses)
  G1HeapRegionSize = 16m  (for heaps 32-64 GB; use 32m for > 64 GB)
  ParallelRefProcEnabled = true  (parallel reference processing)
```

**Config:**
```
spark.executor.extraJavaOptions = -XX:+UseG1GC -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16m -XX:+ParallelRefProcEnabled
```

---

## 21. STEP 20: Serialization

```
DECISION:
  Java serialization → slow, large (default)
  Kryo serialization → 10x faster, 2-5x smaller

  For 5 TB workloads → ALWAYS use Kryo

CALCULATION (impact on shuffle):
  Java serialized shuffle size ≈ 5 TB
  Kryo serialized shuffle size ≈ 5 TB / 3 ≈ 1.7 TB
  Savings: ~3.3 TB less data shuffled across the network
```

**Config:**
```
spark.serializer = org.apache.spark.serializer.KryoSerializer
spark.kryoserializer.buffer.max = 1024m
```

---

## 22. STEP 21: Dynamic Allocation Bounds

```
FORMULA:
  min_executors = total_executors × 0.10 to 0.20  (keep minimum warm)
  min_executors = 75 × 0.15 = 11 ≈ 10

  max_executors = total_executors × 1.5 to 2.0  (allow burst)
  max_executors = 75 × 1.5 = 112 ≈ 100

  initial_executors = total_executors × 0.30 to 0.50
  initial_executors = 75 × 0.40 = 30

IDLE TIMEOUT:
  executor_idle_timeout = 120s  (release idle executors after 2 minutes)
  cached_executor_idle_timeout = 600s  (keep executors with cached data longer)
  scheduler_backlog_timeout = 5s  (request new executors within 5s of pending tasks)
```

**Config:**
```
spark.dynamicAllocation.enabled = true
spark.dynamicAllocation.minExecutors = 10
spark.dynamicAllocation.maxExecutors = 100
spark.dynamicAllocation.initialExecutors = 30
spark.dynamicAllocation.executorIdleTimeout = 120s
spark.dynamicAllocation.cachedExecutorIdleTimeout = 600s
spark.dynamicAllocation.schedulerBacklogTimeout = 5s
spark.shuffle.service.enabled = true
```

---

## 23. STEP 22: Speculation Settings

```
FORMULA:
  Enable speculation when:
    - Job has many tasks (> 100)
    - Data skew is possible
    - Stragglers can waste cluster time

  speculation_quantile = 0.75  (trigger when 75% of tasks complete)
  speculation_multiplier = 1.5  (task must be 1.5x slower than median)

  For 5 TB with 3000+ tasks → speculation is useful ✅

CALCULATION:
  At 75% completion of a 3000-task stage:
    2250 tasks done, median time = 60s
    Any task running > 60s × 1.5 = 90s → re-launched on another node
```

**Config:**
```
spark.speculation = true
spark.speculation.interval = 100ms
spark.speculation.multiplier = 1.5
spark.speculation.quantile = 0.75
```

---

## 24. STEP 23: Compression Codec

```
DECISION MATRIX:
                     Compress Speed   Decompress Speed   Ratio   Splittable
  Snappy             Fast             Fast               2-3x    Yes (Parquet)
  ZSTD               Medium           Fast               3-5x    Yes (Parquet)
  LZ4                Very Fast        Very Fast           2x      Yes
  Gzip               Slow             Medium             5-8x    No (raw files)

FOR 5 TB:
  Input/Output format → Parquet with Snappy (balanced speed + compression)
  Shuffle compression → LZ4 or Snappy (speed > ratio for shuffles)

STORAGE SAVINGS:
  Uncompressed:  15 TB
  Snappy Parquet: 5 TB  (3x compression)
  ZSTD Parquet:   3.5 TB (4.3x compression) → saves 1.5 TB storage
```

**Config:**
```
spark.sql.parquet.compression.codec = snappy
spark.shuffle.compress = true
spark.shuffle.spill.compress = true
spark.io.compression.codec = lz4
```

---

## 25. STEP 24: Data Partitioning (Write Layout)

```
FORMULA:
  data_per_partition_value = D / num_unique_partition_values

  Example: Partition by year/month (24 months of data)
    data_per_partition = 5 TB / 24 = ~213 GB per month partition
    files_per_partition = 213 GB / 512 MB = ~416 files per partition

  Example: Partition by year/month/day (730 days)
    data_per_partition = 5 TB / 730 = ~7 GB per day partition
    files_per_partition = 7 GB / 512 MB = ~14 files per partition ✅ (good!)

RULES:
  Target per-partition size: 100 MB - 10 GB
  Target files per partition: 1 - 50
  Avoid partition cardinality > 50,000

  GOOD: partitionBy("year", "month", "day")   → 730 partitions ✅
  BAD:  partitionBy("year", "month", "day", "hour", "event_type")
        → 730 × 24 × 50 = 876,000 partitions ❌ (small files problem)
```

---

## 26. STEP 25: Number of Partitions — Master Formula (5 TB)

> This section unifies all partition calculations into one place with clear formulas applied to the 5 TB dataset.

### A. Input Read Partitions (when Spark reads the 5 TB source)

```
FORMULA:
  input_partitions = ceil(total_file_size / maxPartitionBytes)

GIVEN:
  total_file_size     = D = 5 TB = 5,120 GB = 5,242,880 MB
  maxPartitionBytes   = spark.sql.files.maxPartitionBytes = 128 MB (default)
  openCostInBytes     = spark.sql.files.openCostInBytes   = 4 MB  (default)

CALCULATION:
  input_partitions = ceil(5,242,880 MB / 128 MB)
  input_partitions = ceil(40,960)
  input_partitions = 40,960 partitions

WHAT THIS MEANS:
  - Spark will create ~40,960 tasks for the initial read stage
  - Each task reads ~128 MB of compressed Parquet
  - Each task decompresses to ~384 MB in memory (128 MB × 3x compression ratio)

VERIFY:
  partition_in_memory = 128 MB × CR = 128 × 3 = 384 MB
  384 MB << 2.14 GB memory_per_task → fits comfortably ✅
  40,960 tasks / 375 cores = ~109 waves → acceptable for initial scan ✅
```

**Config:** `spark.sql.files.maxPartitionBytes = 128MB` _(default, rarely needs changing)_

### B. Shuffle Partitions (after joins, groupBy, aggregations)

```
FORMULA:
  shuffle_partitions = ceil(data_in_memory_after_shuffle / target_partition_size)

GIVEN:
  data_in_memory = D × CR = 5 TB × 3 = 15 TB = 15,360 GB
  shuffle_selectivity = 0.50  (assume 50% of data survives filters before shuffle)
  shuffled_data = 15,360 GB × 0.50 = 7,680 GB
  target_partition_size = 256 MB (sweet spot for shuffle: 128 MB – 1 GB)

CALCULATION:
  shuffle_partitions = ceil(7,680 GB / 0.256 GB)
  shuffle_partitions = ceil(30,000)
  shuffle_partitions = 30,000 (theoretical upper bound)

PRACTICAL ADJUSTMENT (with AQE):
  Start with fewer partitions; AQE will split skewed partitions automatically.
  Recommended = 3,000 to 5,000

VERIFY (at 3,000 partitions):
  partition_size = 7,680 GB / 3,000 = 2.56 GB
  memory_per_task = 2.14 GB → BORDERLINE (may spill to disk) ⚠️
  With AQE auto-coalesce, small partitions merge → effective sizes stay optimal ✅

VERIFY (at 5,000 partitions):
  partition_size = 7,680 GB / 5,000 = 1.54 GB
  memory_per_task = 2.14 GB → fits with headroom ✅
```

**Config:** `spark.sql.shuffle.partitions = 3000` _(with AQE enabled)_

### C. Output/Write Partitions (final write to storage)

```
FORMULA:
  output_partitions = ceil(output_data_size / target_output_file_size)

GIVEN:
  output_data_compressed = 5 TB  (assuming 1:1 output-to-input ratio)
  target_output_file_size = 512 MB (Parquet best practice: 256 MB – 1 GB)

CALCULATION:
  output_partitions = ceil(5,120 GB / 0.512 GB)
  output_partitions = ceil(10,000)
  output_partitions = 10,000 output files

  If heavy aggregation reduces output to 500 GB:
    output_partitions = ceil(500 GB / 0.256 GB) = 1,953 ≈ 2,000 files

APPLY:
  df.repartition(10000).write.parquet(...)   # uniform file sizes
  # OR
  df.coalesce(10000).write.parquet(...)      # if already near target count
```

### D. Unified Partition Count Summary for 5 TB

```
┌──────────────────────────┬─────────────────────────────────────────────────┬──────────────┐
│ Stage                    │ Formula                                         │ Value (5 TB) │
├──────────────────────────┼─────────────────────────────────────────────────┼──────────────┤
│ Input Read Partitions    │ ceil(D / maxPartitionBytes)                     │ 40,960       │
│                          │ ceil(5 TB / 128 MB)                             │              │
├──────────────────────────┼─────────────────────────────────────────────────┼──────────────┤
│ Shuffle Partitions       │ ceil(D × CR × selectivity / target_part_size)  │ 3,000–5,000  │
│                          │ ceil(5 TB × 3 × 0.5 / 256 MB)                 │ (30K theor.) │
├──────────────────────────┼─────────────────────────────────────────────────┼──────────────┤
│ Default Parallelism(RDD) │ total_cores × 2                                │ 750          │
│                          │ 375 × 2                                         │              │
├──────────────────────────┼─────────────────────────────────────────────────┼──────────────┤
│ Output Write Partitions  │ ceil(output_size / target_file_size)            │ 2,000–10,000 │
│                          │ ceil(5 TB / 512 MB)                             │              │
├──────────────────────────┼─────────────────────────────────────────────────┼──────────────┤
│ Data Layout Partitions   │ unique(partition_columns)                       │ ~730         │
│ (year/month/day)         │ ~365 days/year × 2 years                       │              │
└──────────────────────────┴─────────────────────────────────────────────────┴──────────────┘

KEY CONSTRAINT:
  Every partition must satisfy:
    partition_size_in_memory ≤ memory_per_task
    partition_size_in_memory ≤ execution_memory / cores_per_executor
    partition_size_in_memory ≤ 10.7 GB / 5 = 2.14 GB
```

---

## 27. Full Calculation Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    5 TB SPARK CLUSTER - COMPLETE CALCULATIONS               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  INPUT                                                                      │
│  ─────                                                                      │
│  Data Size .......................... 5 TB (Parquet compressed)              │
│  In-Memory Size ..................... 15 TB (3x compression ratio)           │
│  Peak with Shuffle .................. 30 TB (2x shuffle factor)             │
│  Node Type .......................... r5.4xlarge (16 cores, 128 GB)         │
│                                                                             │
│  CLUSTER                                                                    │
│  ───────                                                                    │
│  Worker Nodes ....................... 25                                     │
│  Total Cores ........................ 375  (25 × 15 available)              │
│  Total RAM .......................... 3,200 GB  (25 × 128 GB)              │
│  Total Local SSD .................... 12.5 TB  (25 × 500 GB)              │
│                                                                             │
│  PER EXECUTOR (75 total = 25 nodes × 3 per node)                           │
│  ────────────                                                               │
│  Cores per Executor ................. 5                                      │
│  Container Memory ................... 40 GB                                  │
│  Executor Memory (JVM Heap) ......... 36 GB                                 │
│  Memory Overhead (Off-Heap) ......... 4 GB                                  │
│  Off-Heap (Tungsten) ................ 4 GB                                  │
│                                                                             │
│  MEMORY BREAKDOWN PER EXECUTOR                                              │
│  ─────────────────────────────                                              │
│  Reserved Memory .................... 0.3 GB                                │
│  Usable Memory ...................... 35.7 GB                               │
│  Unified Memory (60%) ............... 21.4 GB                               │
│  ├── Execution Memory (50%) ......... 10.7 GB                               │
│  └── Storage Memory (50%) ........... 10.7 GB                               │
│  User Memory (40%) .................. 14.3 GB                               │
│  Memory Per Task .................... 2.14 GB  (10.7 GB / 5 cores)         │
│                                                                             │
│  DRIVER                                                                     │
│  ──────                                                                     │
│  Driver Memory ...................... 10 GB                                  │
│  Driver Memory Overhead ............. 2 GB                                   │
│  Max Result Size .................... 4 GB                                   │
│                                                                             │
│  PARALLELISM & PARTITIONS                                                   │
│  ────────────────────────                                                   │
│  Total Executors .................... 75                                     │
│  Total Cores ........................ 375                                    │
│  Input Read Partitions .............. 40,960  (5 TB / 128 MB)              │
│  Shuffle Partitions ................. 3,000   (with AQE; 30K theoretical)   │
│  Default Parallelism (RDD) .......... 750     (375 cores × 2)              │
│  Output Write Partitions ............ 2,000–10,000  (target 512 MB files)  │
│  Data Layout Partitions ............. ~730    (year/month/day)              │
│  Partition Size (shuffle) ........... ~1.7 GB  (5 TB / 3000)              │
│  Memory Per Task Limit .............. 2.14 GB (10.7 GB / 5 cores)         │
│  Broadcast Join Threshold ........... 256 MB                                │
│                                                                             │
│  DYNAMIC ALLOCATION                                                         │
│  ──────────────────                                                         │
│  Min Executors ...................... 10                                     │
│  Max Executors ...................... 100                                    │
│  Initial Executors .................. 30                                     │
│                                                                             │
│  NETWORK                                                                    │
│  ───────                                                                    │
│  Network Timeout .................... 600s                                   │
│  Shuffle IO Retries ................. 10                                     │
│  Shuffle IO Retry Wait .............. 30s                                   │
│                                                                             │
│  STORAGE                                                                    │
│  ───────                                                                    │
│  Format ............................. Parquet                                │
│  Compression ........................ Snappy                                 │
│  Output Files ....................... ~5,000 - 10,000                       │
│  Target File Size ................... 512 MB - 1 GB                         │
│  Data Partitioning .................. year/month/day (~730 partitions)      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 28. Final spark-submit Command

```bash
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  \
  # ── Executor Settings (Step 1-4, 6) ──
  --num-executors 75 \
  --executor-cores 5 \
  --executor-memory 36g \
  --conf spark.executor.memoryOverhead=4g \
  \
  # ── Driver Settings (Step 7-9) ──
  --driver-memory 10g \
  --conf spark.driver.memoryOverhead=2g \
  --conf spark.driver.maxResultSize=4g \
  \
  # ── Memory Fractions (Step 10-11) ──
  --conf spark.memory.fraction=0.6 \
  --conf spark.memory.storageFraction=0.5 \
  --conf spark.memory.offHeap.enabled=true \
  --conf spark.memory.offHeap.size=4g \
  \
  # ── Parallelism (Step 12-13) ──
  --conf spark.sql.shuffle.partitions=3000 \
  --conf spark.default.parallelism=750 \
  \
  # ── Broadcast (Step 14) ──
  --conf spark.sql.autoBroadcastJoinThreshold=256MB \
  \
  # ── Shuffle & Compression (Step 17, 23) ──
  --conf spark.shuffle.compress=true \
  --conf spark.shuffle.spill.compress=true \
  --conf spark.shuffle.file.buffer=1m \
  --conf spark.reducer.maxSizeInFlight=96m \
  --conf spark.shuffle.service.enabled=true \
  --conf spark.io.compression.codec=lz4 \
  --conf spark.local.dir=/mnt/nvme1,/mnt/nvme2 \
  \
  # ── Network (Step 18) ──
  --conf spark.network.timeout=600s \
  --conf spark.rpc.askTimeout=600s \
  --conf spark.sql.broadcastTimeout=600s \
  --conf spark.shuffle.io.maxRetries=10 \
  --conf spark.shuffle.io.retryWait=30s \
  \
  # ── Serialization (Step 20) ──
  --conf spark.serializer=org.apache.spark.serializer.KryoSerializer \
  --conf spark.kryoserializer.buffer.max=1024m \
  \
  # ── GC (Step 19) ──
  --conf "spark.executor.extraJavaOptions=-XX:+UseG1GC -XX:InitiatingHeapOccupancyPercent=35 -XX:G1HeapRegionSize=16m -XX:+ParallelRefProcEnabled" \
  \
  # ── Speculation (Step 22) ──
  --conf spark.speculation=true \
  --conf spark.speculation.interval=100ms \
  --conf spark.speculation.multiplier=1.5 \
  --conf spark.speculation.quantile=0.75 \
  \
  # ── AQE (Adaptive Query Execution) ──
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  --conf spark.sql.adaptive.skewJoin.enabled=true \
  --conf spark.sql.adaptive.skewJoin.skewedPartitionFactor=5 \
  --conf spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes=256MB \
  --conf spark.sql.adaptive.advisoryPartitionSizeInBytes=256MB \
  \
  # ── Dynamic Allocation (Step 21) ──
  --conf spark.dynamicAllocation.enabled=true \
  --conf spark.dynamicAllocation.minExecutors=10 \
  --conf spark.dynamicAllocation.maxExecutors=100 \
  --conf spark.dynamicAllocation.initialExecutors=30 \
  --conf spark.dynamicAllocation.executorIdleTimeout=120s \
  --conf spark.dynamicAllocation.cachedExecutorIdleTimeout=600s \
  \
  # ── I/O Optimization ──
  --conf spark.sql.parquet.filterPushdown=true \
  --conf spark.sql.parquet.mergeSchema=false \
  --conf spark.sql.parquet.enableVectorizedReader=true \
  --conf spark.sql.parquet.compression.codec=snappy \
  \
  my_5tb_etl_job.py
```

---

## 29. Scaling Formula: Any Data Size

Replace `D` with your data size and recalculate every parameter:

```
GIVEN:
  D = your data size in TB
  CR = compression ratio (3 for Parquet/Snappy, 4 for ZSTD)
  SF = shuffle factor (2 for ETL, 3 for heavy joins)
  M_node = RAM per node in GB
  C_node = cores per node

CALCULATE:
  cores_per_executor     = 5  (constant)
  C_avail                = C_node - 1
  executors_per_node     = floor(C_avail / 5)
  container_memory       = floor((M_node - 8) / executors_per_node)
  memory_overhead        = max(0.384, container_memory × 0.10)
  executor_memory        = container_memory - memory_overhead
  nodes                  = ceil((D × 1024 × CR × SF × 0.15) / (M_node - 8))
  total_executors        = nodes × executors_per_node
  total_cores            = total_executors × 5
  driver_memory          = max(8, total_executors / 10)  in GB
  driver_overhead        = max(1, driver_memory × 0.10)
  max_result_size        = min(driver_memory × 0.4, 4)
  input_read_partitions  = ceil((D × 1024) / 0.128)  in GB (128 MB maxPartitionBytes)
  shuffle_partitions     = max(total_cores × 4, (D × 1024) / 1)
  default_parallelism    = total_cores × 2
  output_write_partitions= ceil((D × 1024) / 0.512)  (target 512 MB files)
  broadcast_threshold    = min(executor_memory × 0.15, 1)  in GB
  network_timeout        = max(300, (D × 1024) / 31.25 × 3)  in seconds
```

### Quick Lookup Table

| Data Size | Nodes (128GB) | Executors | Total Cores | Input Partitions | Shuffle Partitions | Output Partitions | Executor Mem |
|-----------|---------------|-----------|-------------|------------------|--------------------|-------------------|--------------|
| 100 GB    | 3             | 9         | 45          | 800              | 200                | 200               | 36g          |
| 500 GB    | 5             | 15        | 75          | 4,096            | 500                | 1,000             | 36g          |
| 1 TB      | 8             | 24        | 120         | 8,192            | 1,000              | 2,000             | 36g          |
| 2 TB      | 13            | 39        | 195         | 16,384           | 2,000              | 4,000             | 36g          |
| 5 TB      | 25            | 75        | 375         | 40,960           | 3,000              | 10,000            | 36g          |
| 10 TB     | 45            | 135       | 675         | 81,920           | 6,000              | 20,000            | 36g          |
| 20 TB     | 85            | 255       | 1,275       | 163,840          | 10,000             | 40,000            | 36g          |
| 50 TB     | 200           | 600       | 3,000       | 409,600          | 25,000             | 100,000           | 36g          |
| 100 TB    | 380           | 1,140     | 5,700       | 819,200          | 50,000             | 200,000           | 36g          |

---

## 30. Verification Checklist

After calculating, verify every parameter passes these checks:

```
MEMORY CHECKS:
  ☐ executor_memory + overhead ≤ container_memory
  ☐ executors_per_node × container_memory ≤ M_node - OS_reserve
  ☐ executor_memory ≤ 64 GB (avoid long GC pauses; if > 64 GB, split into more executors)
  ☐ driver_memory ≥ broadcast_threshold × 2
  ☐ max_result_size ≤ driver_memory × 0.5

CORE CHECKS:
  ☐ cores_per_executor = 3 to 5 (never > 5)
  ☐ executors_per_node × cores_per_executor ≤ C_node - 1
  ☐ total_cores ≥ shuffle_partitions / 10 (else too many waves)

PARTITION CHECKS:
  ☐ partition_size = D / shuffle_partitions ≤ memory_per_task (execution_memory / cores)
  ☐ partition_size ≥ 64 MB (avoid scheduling overhead)
  ☐ shuffle_partitions ≥ total_cores × 2 (enough work for all cores)

NETWORK CHECKS:
  ☐ network_timeout ≥ 300s for multi-TB workloads
  ☐ shuffle_io_retries ≥ 5

STORAGE CHECKS:
  ☐ local_ssd_per_node ≥ (D × CR × SF) / nodes × 0.5
  ☐ output_file_size between 128 MB and 1 GB
  ☐ partition cardinality < 50,000

OVERALL:
  ☐ Data / Cluster RAM ratio ≤ 5x (if higher, need more nodes)
  ☐ Total executor memory ≥ D × 0.3 (at least 30% of data fits at once)
  ☐ AQE enabled = true (Spark 3.0+)
```

---

**Every number in this document is derived from a formula. Plug in your data size, node spec, and follow the steps to calculate your configuration from scratch.**
