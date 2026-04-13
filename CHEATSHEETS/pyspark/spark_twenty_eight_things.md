 # Here are 28 things you should know about Apache Spark.

1. **MapReduce's disk-based data exchange made it a poor fit for ML and interactive queries. Spark fixed that with in-memory processing.**
2. **All DataFrames and Datasets are compiled to RDD.**
3. **RDDs are immutable; every transformation creates a new RDD.**
4. **Spark is lazy by default. Nothing runs until an action fires. This allows Spark to plan efficiently.**
5. **3 components run every Spark app. The driver manages the app. Cluster Manager handles machines. Executors run tasks.**
6. **3 modes. Cluster: driver on one of the workers. Client: driver on your machine. Local: single machine, threads only.**
7. **Job → Stage → Task is the full workflow. A job has multiple stages. A stage is shuffle-free. A task is one per partition.**
8. **Wide transformations → data shuffles (e.g., groupByKey) across partitions.**
9. **Catalyst Optimizer runs 4 phases: Analysis, Logical Optimization, Physical Planning, and Code Generation.**
10. **AQE re-plans mid-job based on real runtime stats.**
11. **3 components handle scheduling: DAGScheduler for stages, TaskScheduler for tasks, SchedulerBackend for resources.**
12. **FIFO: first job takes everything. Later jobs wait.**
13. **Fair scheduling: short jobs don't wait behind long ones.**
14. **Static allocation: fixed for the app's lifetime.**
15. **Dynamic allocation: Spark returns and reclaims resources on demand.**
16. **Executor memory has 3 regions: on-heap, off-heap, and overhead.**
17. **On-heap has 3 subregions: Reserved (300MB hardcoded), user (your data structures), and unified (shared between execution and storage).**
18. **Unified size: spark.memory.fraction. Default 0.6. With 4GB: (4096 - 300) × 0.6 = 2,877 MB.**
19. **Storage/Execution ratio: spark.memory.storageFraction (default 0.5). Storage = 2,877 × 0.5 = 1,438 MB. Execution gets the other half.**
20. **The boundary is crossable, but not equal. Both sides can borrow from each other. Only execution can force storage to free up space.**
21. **The Tungsten project bypasses JVM overhead by managing memory for binary data directly.**
22. **cache() and persist() "cache" data. The first uses MEMORY_AND_DISK. The latter lets you pick the strategy. Both are lazy.**
23. **2 join strategies: Sort-Merge Join (SMJ) and Shuffle Hash Join (SHJ). Broadcast Join and Bucket Join are optimizations built on top.**
24. **SMJ is the default. Shuffle, sort, and merge with two pointers. Spills to disk if needed.**
25. **SHJ builds a hash table from the smaller partition, probes with the larger. Faster, but OOM risk if partitions don't fit.**
26. **Broadcast Hash Join sends the small table to all executors. Every executor builds a hash table locally. No shuffle needed.**
27. **AQE can switch to BHJ mid-execution.**
28. **Bucket join moves shuffle to write time. Both tables are bucketed by the join key up front, so no shuffle occurs at join time.**
