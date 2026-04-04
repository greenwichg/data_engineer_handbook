1. **I am working with two PySpark files where *File-A* creates a SparkSession. How can I import or reference this existing SparkSession in *File-B* to avoid creating duplicate sessions and ensure I'm working with the same Spark context?**

2. **Given a poorly performing SQL statement, how would you approach its optimization? Consider aspects such as query execution plans, indexing strategies, join operations, and query rewriting techniques in your answer.**

3. **You need to build an incremental data pipeline using PySpark that captures inserts, updates, and deletes from a source system. How would you implement CDC (Change Data Capture) logic to identify changes and synchronize them with the target data system while maintaining data consistency?**

4. **In a production PySpark streaming ingestion pipeline, upstream source systems frequently update their schemas without prior notice. How would you architect the ingestion layer to automatically detect, validate, and accommodate these schema changes in real-time?**

5. **Your production Spark job is failing due to memory pressure during join operations on datasets with billions of records. Walk through your troubleshooting process and explain the specific optimizations you would apply, including partitioning strategies, join type selection, data skew handling, and resource configuration adjustments.**

6. **When ingesting multi-level nested JSON files into a data system using PySpark, what systematic approach would you use to flatten deeply nested structures into a relational format? Describe your strategy for handling arrays, nested objects, varying nesting depths.**

7. **During the data ingestion process using PySpark, if you encounter data skew that causes certain partitions to process significantly slower than others, how would you detect the skew at the ingestion layer and what techniques would you apply to mitigate it?**

8. **During the data ingestion process using PySpark, how would you design and implement a comprehensive data quality framework to cleanse, impute missing values, and validate incoming data for inconsistencies or incompleteness?**

9. **Describe how you would handle joining two DataFrames on a nullable column, including potential issues like null mismatches and strategies such as replacing nulls with sentinel values or using custom join conditions to ensure accurate results.**

---------

1. **Difference between reparation and coalesce and when to use which one.** <br>
   **When working with big data, partition management is everything. Two common tools we use in PySpark: Repartition and Coalesce.** <br><br>
   🔹 **Repartition:** <br>
      **Redistributes data across all partitions** <br>
      **Involves a shuffle → data is moved across the cluster** <br>
      **Can increase or decrease the number of partitions** <br>
      **Useful when you want to balance the data evenly across executors** <br><br>
   🔹 **Coalesce** <br>
      **Merges existing partitions without a full shuffle** <br>
      **Only reduces the number of partitions (cannot increase)** <br>
      **Faster and cheaper than repartition** <br>
      **Great for optimizing after a heavy filter (when data is already smaller)** <br><br>
   ✅ **Rule of Thumb** <br>
   **Use Repartition when you need even distribution (scaling up or balancing work).** <br>
   **Use Coalesce when you just need fewer partitions quickly (scaling down).** <br>
   **Both are essential to keeping Spark workloads balanced, efficient, and cost-effective.** <br>
   **Next time you optimize your PySpark jobs, remember: <br> it’s not just about transformations — it’s also about how your data is partitioned.**

---

2. **To process 25gb in spark.** <br>
   a. **How many cpu cores are required?** <br>
   b. **How many executors are required?** <br>
   c. **How much each executor memory is required?** <br>
   d. **What is the total memory required?** <br><br>
   **How many executor CPU cores are required to proceess 25GB data?** <br>
   **25GB = 25*1024 = 25600MB** <br>
   **Number of Partitions = 25600MB/128MB = 200** <br>
   **Number of CPU cores = Number of partitions = 200**

   **How many executors are required to proceess 25GB data?** <br>
   **Avg CPU cores for eaxch executor = 4** <br>
   **Total number of executors = 200/4 = 50**

   **How much each executor memory is required to process 25GB data?** <br>
   **CPU cores for each executor = 4** <br>
   **Memory for each executor = 4*512MB = 2GB**

   **What is the total memory required to process 25GB data?** <br>
   **Total number of executors = 50** <br>
   **Memory for each executor = 2GB** <br>
   **Total Memory for all the executor = 50*2GB = 100GB**

#### **Notes:** <br>
**By default, Spark creates one partition for each block of the file (Blocks being 128MB by default in HDFS), <br> but you can also ask for a higher number of partitions by passing a larger value.** <br>
**To get the better job performance in Spark, researchers have found that we can take 2 to 5 maximum core for each executor.** <br>
**Expected memory for each core = Minimum 4 x (default partition size) = 4*128MB = 512MB.** <br>
**Executor memory is not less than 1.5 times of Spark reserved memory (Single core executor memory should not be less than 450MB)**

---

3. **How do you handle schema evolution.**
4. **How do you setup external libraries in AWS lambda before using it.**
5. **Expalin how do you spin up data services in AWS, and also how do you configure AWS CLI.**
6. **What is the difference between Athena and Redshift spectrum and which one of them is powerful.**
7. **What is the difference between standard views and materialised views.**
8. **What is the difference between internal tables and external tables.**
9. **Managing Partitions in AWS Athena with MSCK REPAIR TABLE**
10. **Difference between dataframe and dynamicframe, and how dynamicframe supports schema evolution.**
11. **How can we access s3 bucket in one account from another account.**
12. **What is the main difference between SparkContext and SparkSession.**
13. **What is the main difference between RDD, DataFrame, and DynamicFrame.**
14. **What are the deployment modes available in Amazon EMR.**
15. **Be prepared with how to enable the configurations for known services in aws cloud.**