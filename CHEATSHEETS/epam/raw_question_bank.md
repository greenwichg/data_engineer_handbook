# Interview Questions

## Interview 1

**Position Role:** A3

**Technology Areas:** Python, Sql, Spark, Pyspark, DataBricks +UC, DevOps, ADF

### Questions

1. Project Discussion
    1. Medallion arch deep dive
2. Datasets in ADF
3. Different Authentications in ADF (MI, SPN)
4. Web Activity and Logic Apps
5. Cluster Config in Spark and Types of clusters and difference
6. OOM in Databricks jobs and mitigation
7. How to migrate from existing meta store to UC
8. Delta Shares and difference between Lakehouse and DW
7. WorkFlows in Databricks + CDC
8. External Tables
9. Merge (upsert) - SQL Coding (related to SCD2)
10. Python - From List of numbers move 0 to the end of the list and keep other positions as is
11. How to append two dfs with uneven schema - Coding - Pyspark
12. Lead lag and range in SQL - Coding
13. Devops workflow, How to push code from Lower envi - Higher envis
14. Quality Gates in Github Actions
15. Code Quality and Data accuracy checks

---

## Interview 2

**Position Role:** A3

**Technology Areas:** Sql, Python, AWS, PySpark

### Questions

1. Project Discussion
2. Explain OOPS concept
3. Why used AWS Glue instead of EMR
4. What is the size of the data processed in Glue
5. How many Glue Jobs runner instantly
6. Which case you will go for EMR and Glue
7. What are the sources you are getting data to run glue job
8. What is the target to landing the data
9. From S3 you will directly consume the files
10. In S3 you will use event trigger mechanism which is Lambda function
11. What is the format for getting the data in S3
12. What is the data strategic process
13. What are the different kind of transformations
14. Did you do any aggregation in your project
15. Did you face any technical level issues in your project
16. How did you identify the delays in your job
17. How do you handle the shuffling and data skewness
18. Explain the salting techniques
19. If you do repartition, will it directly trigger a transformation/execution
20. Do you have idea about Airflow
21. Explain the architecture about Airflow
22. What are the different kind of executors in Airflow
23. Airflow any kindly of messaging queue
24. Do you any expose in CI/CD pipeline
25. What are the databases did you worked and explain mysql database.
26. Coding: Python two questions, SQL 2 questions.

---

## Interview 3

**Technology Areas:** Spark, SQL, Scala

**Date:** 5th Oct 2025 — [Added By Gulfam Zahiruddin]

**Interviewer:** Mukul Garg (Client Round)

### Questions

**Project & Data Loading:**
- Tell me about your recent project?
- How are you pushing data from s3 to rds PostgreSQL?
- Anything additional that you need to do for that to just make sure that the load is spark is going to generate and postgres not hampering other things?
- Did you try the S3 utility that AWS provide in the RDS, which allows you to directly import the data from S3 into postgradable.

**Scenario: Customer sales data**

Schema: `c_id, c_name, c_state, c_city, c_membership, month, year, total_sales`

- Write a spark sql query customer with max in their state
- What if there are multiple customer having the same total sales value
- What if I want to know the customers? Who? Are like top tier or I say who are more than 90 percentile.

**Spark Performance:**
- Have you debug any Spark applications or pipeline? For performance.
- Could you tell me more about how will you enable the or how will you utilize the predicate push down
- So predicate pushdown is more of a coding practice, or it's more of a spark functionality.

**Scala:**
- What kind of project you have done in scala?
- What build tool you have used in that project?
- Why you choose scala to write that project?

---

## Interview 4

**Technology Areas:** PySpark, AWS

### Questions

1. Project discussion, should have clear understanding
2. EMR vs EMR serverless, why did we choose serverless. Pros and cons.
3. What are they key points that you keep in mind while configuring EMR serverless
4. Shallow vs deep copy in python? Its relation with mutability/immutablity? When to use which one?
5. Multi threading in python
6. Spring boot knowledge
7. Airflow architecture and how to configure? What are the main components.
8. Spark optimizations
9. Fat vs tiny executors? Pros and cons? Use cases.
10. How would u decide resource allocation for spark job and cluster configuration?
11. Is there any similiarity between snowflake/postgres? What do you think about query optimization?
12. What are materialized views in snowflake?

---

## Interview 5

**Technology Areas:** PySpark

### Questions

1. Project discussion, End to End flow.
2. ETL migration scenarios from Talend to ADB.
3. Coding - Find the 2nd highest Salary in Pyspark from the imports, spark session creation, df creation, window functions and condition, if no 2nd highest salary, then to show null.
4. Explain pyspark architecture in detail.
5. How do you debug the pyspark job failures.
6. All the jobs are completed, expect on single task is still running in a job, what could be the possible root cause (Ans: due to data skewness)
7. As part of the migration project, we need to create a dynamic data processing framework that can handle various data sources and processing requirements. Our customers have different data processing needs, and we want to provide a flexible solution that can adapt to their changing requirements.

    Your task is to design and implement a Python class that can dynamically generate data processing pipelines based on user-defined configurations.

    **Requirements:**
    1. Create a `PipelineConfig` class that represents a user-defined configuration for a data processing pipeline. The configuration should include the data source type (CSV, JSON), processing steps (e.g., data cleansing, feature engineering), and any additional parameters required for each step.
    2. Implement a `PipelineFactory` class that takes a `PipelineConfig` object as input and generates a corresponding data processing pipeline. The pipeline should be composed of `DataSource` and `DataProcessor` objects, which are instantiated based on the configuration.
    3. Design a `PipelineExecutor` class that takes a generated pipeline and executes it, returning the processed data.
    4. Provide an example usage of the `PipelineFactory` and `PipelineExecutor` classes, demonstrating how to create a pipeline configuration, generate a pipeline, and execute it.

    **Constraints:**
    - Use PySpark's `SparkSession` to create a Spark context for data processing.
    - Ensure that the `PipelineFactory` class can handle different data source types and processing steps.
    - Consider using Databricks' `dbutils` module to interact with the Databricks environment (e.g., for file storage).

---

## Interview 6

**Technology Areas:** PySpark

### Questions

1. Project discussion
2. Spark architecture
3. Spark optimizations and scenario based
4. Optimizing your SQL query
5. Broadcasting
6. Long running jobs, how you will debug?
7. If pipelines are running from so long, how you will debug it? What can be potential bottleneck/issues?
8. Try catch and alert mechanisms implemented in your project, for what purpose do you use them?
9. Different file types
10. Delta table/Deltalake concepts
11. Spark OOM - Drive and Executor, why we get OOM and what can be done to handle it?
12. Catalyst optimizer and different plans involved in SQL optimizer
13. Spark Jobs, stages, tasks and how it is decided how many jobs/stages/tasks will be created of a spark application?
14. Spark shuffling (sort-merge/hash)
15. Data skewness - how you will handle it?
16. Spark UI - uses, how it helps in debugging
17. DAG, lazy evaluation, narrow/wide transformations

#### 18. SQL problem

Given table:

| user  | site   | time  |
|-------|--------|-------|
| user1 | Site 1 | 10:00 |
| user1 | Site 2 | 10:17 |
| user1 | Site 3 | 10:35 |
| user1 | Site 4 | 11:00 |
| user2 | Site 1 | 11:15 |
| user2 | Site 2 | 11:32 |
| user2 | Site 3 | 12:05 |
| user2 | Site 4 | 12:20 |
| user3 | Site 1 | 12:30 |
| user3 | Site 2 | 13:05 |
| user3 | Site 3 | 13:15 |
| user3 | Site 4 | 13:37 |

Find the time for each User, for each site they have spend on? (considering 1st site default to 0 for each user)

Example:
- User1 at site2, spent 10:00-10:17 = 17mins
- User1 at site3, spent 10:35-10:17 = 18mins and so on.....

#### 19. CSV malformed records

You have a csv file, and there are some malformed records in it...instead of stopping and failing the ingestion, you need to implement a try-catch block to handle the malformed records, so correct records will be processed further and malformed will be filtered out and stored in error path.

#### 20. Decorators in python

#### 21. Dataset vs Dataframe

#### 22. Write pyspark code

**A)** Input: `1|aaa|111|2|bbb|222|3|ccc|333`

Output:
```
1 aaa 111
2 bbb 222
3 ccc 333
```

**B)** Input:

```
|Product|Amount|Country|
+-------+------+-------+
| Banana|  1000|   USA |
|Carrots|  1500|   USA |
| Beans |  1600|   USA |
| Orange|  2000|   USA |
| Orange|  2000|   USA |
| Banana|   400| China |
|Carrots|  1200| China |
| Beans |  1500| China |
| Orange|  4000| China |
| Banana|  2000| Canada|
|Carrots|  2000| Canada|
| Beans |  2000| Mexico|
+-------+------+-------+
```

Output:

```
+-------+------+-----+------+-----+
|Product|Canada|China|Mexico| USA |
+-------+------+-----+------+-----+
| Orange|  null| 4000|  null| 4000|
| Beans |  null| 1500|  2000| 1600|
| Banana|  2000|  400|  null| 1000|
|Carrots|  2000| 1200|  null| 1500|
+-------+------+-----+------+-----+
```

#### 23. Employees who are also managers

Employee table → `Emp(empid, managerid)`

SQL query to find id of employees who are also manager

#### 24. Deptwise third highest salary

Employee table → `Emp(empid, managerid, dept, salary)`

SQL query to find deptwise third highest salary

---

## Interview 7

**Technology Areas:** Spark, SQL, Scala

### Questions

1. Project discussion
2. There were hacker rank coding questions.
    - a) A S3 path was given which consists of few parquet file, and from here we need to read the data.
    - b) Source data is in Oracle and fields were given such as op_type, trans_date_time, product_type, amount and currency_code. We have to process data in Iceberg Table by defining the table and CDC table will have inserts, updates and deletes. It was asked to write a Spark application to process data as a daily job. Also below questions were asked w.r.t above scenario.
        - a) Find monthly/yearly total amount.
        - b) Currency wise amount trend over the time.
        - c) Product wise amount for last 7 days.

---

## Interview 8

**Technology Areas:** Spark, Python, SQL

### Questions

1. Project discussion
2. Spark Optimisation use cases in the projects worked? Challenges faced and how did you overcome it?
3. Python
    - a. Parentheses complete check program
    - b. Check whether a string is substring of another string
    - c. Input: `l = [73, 76, 72, 69, 71, 75, 74, 70]`
        - `# Output: [2, 1, 1, 0, 3, 1, 1, 0]` → how far first lower number on right for each number. If not consider 0.
4. SQL
    - a. There were multiple tables with fact-dimension tables from which multiple use cases were asked like maximum hrs work logged by users; second max events with some specific event type;
    - b. A generic question on sql. Use case of partitioning.
    - c. Exchange Seats - LeetCode
