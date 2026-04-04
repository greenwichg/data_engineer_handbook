# AWS/Data Engineering Interview Preparation

---

## General Guidance

**Kindly ensure that our level is also matching their standards.**

### Key Questions

1. **Where did you use the partitions and how did it help you for better data analytics?**
2. **How would you detect the malformed data and how would you get rid of it and process the data for data analytics?**
3. **Suppose you have a large data set in S3 bucket and there you need to query only last 2 years of data,** \
   **but other than the last 2 years sometimes we need to query other data when required.** \
   **How would you make the solution to reduce the storage cost and improve the performance as well?**

---

## Introduction

- **Are you certified in AWS?**

---

## Technical Questions

1. **Critical HIVE Query is taking long to run. How to fix it?**
2. **We are reading .csv file. The spark job fails with malformed line error.** \
   **Data Quality issue is there. How to fix it?**
4. **Let's say occasionally file will have these issues. Data Quality issue.** \
   **Implement a data quality check beforehand. Automate in your data pipeline.** \
   **Let's say it’s a huge file. How to scan it? Sampling will not give 100% response. Suggest something else.**
7. **We are reading Parquet file from S3. Check invalid errors. How to diagnose?**
8. **Let's say you are working on on-premise data. How to migrate to AWS.** \
   **Tell challenges and steps to anticipate here. Can we do this with Zero Downtime?**
9. **What are the services in AWS you are aware of?**
10. **Let's say Source file doesn’t have a Business Date in the filename.** \
    **The file is basically overwritten. The file is landing in S3. Is there a way to retrieve old file? Is it Bucket level or File level?**
13. **Let’s say you have a source dataset with employees data. Give 2 solutions:  SQL and Python** \
    **Write a query to get max annual CTC for each department. _Hint_: Use Windows function for SQL**

---

## Additional Technical Topics

### Core Concepts
- **What is the PHI data and how to handle the PHI data**
- **What is hash generator**
- **What is partition and types of partitions**
- **What is mean by data skewness and how to handle it**
- **S3 storage level how to improve the performance** \
  **and cost optimization to store large data set in S3 bucket**
- **What is the EMR, Glue and what is data catalog** \
  **and when triggered the data catalog (scheduled based or ad-hoc based)**
- **What is Slowly Changing Dimensions (SCD)**
- **How to check the data is skewed**
- **How to Improve the Spark job**

### Project and Resume Related Questions
- **Lots of Questions about current project and from your Resume.**

### Debugging and Troubleshooting
- **Failed Spark job in EMR → Check driver/executor logs for OOM, schema, IAM issues.**
- **Malformed data fix → Enforce schema, clean source, quarantine bad rows.**
- **Logs to check → Error types, stage, executor memory, failing file/path.**
- **Resolve malformed data → Find root cause, sanitize upstream, configure Spark mode.**
- **Drop bad records → Use DROPMALFORMED or custom filtering with quarantine path.**
- **Handling failed jobs → Debug logs, isolate cause, retry, document & monitor.**

### Performance Optimization
- **Partitioning vs bucketing → Partition = directory structure; Bucketing = joins/group by.**
- **Cluster size factors → Data volume, query complexity, concurrency, SLAs.**
- **Other query performance → Use ORC/Parquet, compression, vectorization, stats.**
- **Automated DQ checks examples → Null %, referential integrity, duplicates, anomaly detection.**

---

1. **Examples of Spark production issues -> Data skew, Out of Memory, small files problem.**
2. **Job not running for 3 days -> Start with scheduler/logs, check cluster resources, data availabilty, rollback if needed.**
3. **Other jobs running but mine failed -> Could be skewed data, bad input, resource misconfig, or dependency failure.**
4. **Starting point for debuggung -> Check Spark job logs and Spark UI to identify stage/type of failure.**
5. **Job failed due to OOM -> Optimize transformations, handle skew, repartition, tune memory, avoid driver collect.**
6. **How to implement salting -> Add random salt to skewed dataset, replicate small dataset with all salt value, join on (key, salt).**
7. **Map-side join vs Salting -> Broadcast join works when one dataset is small; salting fixes skew when both are large.**
8. **Implement salting for A.key = B.key -> Add random salt to Table A, expand Table B with all salts, join on (key, salt).**
9. **Why use explode array(lit) -> To replicate smaller dataset with all salt values so it matches salted keys.**
10. **How salt values match between A and B -> A gets random salt, B has all salts -> guarantees join correctness.**
11. **Products example (apple, banana, orange, grape) -> Skew occurs on qty=0; salting distributes join equally.**
12. **List of products with zero stock -> Result: banana and grape.**
14. **SQL: Latest account balance per id -> Use ROW_NUMBER() over timestamp desc, or MAX(timestamp) join.**
    
---

1. **How to calculate the Compliance result.**
2. **Malformed Data Schema validation, what happened if dropped the correct records.**
3. **Data Skewness: How to know that data is skewed.**
4. **When you decide to go with Salting key and Broadcast join.**
5. **AWS Services like (EMR, Glue, S3, CloudWatch).**
6. **SQL question to find the Max Salary department wise, Row_Number().**
7. **How to implement the production changes if any hot fix and urgent changes.**

---------