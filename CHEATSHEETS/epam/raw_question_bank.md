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

---

## Interview 9

### Questions

1. Project discussion in depth

2. **Python:** The question was more on to do in such a way that it gives most optimized results.

    **Question:** Given two strings, `str1` and `str2`, create a new string, `final_output`, where each character from `str1` is replaced by a corresponding character from `str2`.

    The mapping should follow these rules:
    - Each character from `str1` is mapped to the character from `str2` at the same index, but if the character of str1 is already mapped to char of str2, we will not change the mapping.

    **Example:**
    - Input:
        - `str1 = 'hljljq'`
        - `str2 = 'abcdef'`

    Mapping would look like: `{'h': 'a', 'l': 'b', 'j': 'c', 'q': 'f'}`

    - Output:
        - `final_output = 'abcbcf'`

    Thus, the final string combines these replacements to produce `'abcbcf'`.

3. Data warehouse
    - a. Data warehousing strategies
    - b. Difference between Slowly changing dimensions

4. SQL
    - a. There are multiple records for each id in a table, the column names are id, date. We need the latest record for every id.
    - b. Difference between rank(), row_number(), dense_rank().
    - c. Table name: event (all employee events will be present here) — Use Lead, Lag

        Input:
        ```
        123, 2023-01-01, 'Hire'
        456, 2023-02-01, 'Hire'
        123, 2023-12-31, 'Termination'
        456, 2024-01-31, 'Termination'
        123, 2024-05-01, 'Hire'
        ```

        Output:
        ```
        123, 2023-01-01, 2023-12-31
        456, 2023-02-01, 2024-01-31
        123, 2024-05-01, NULL
        ```

5. Python program to return a list of indices from the given list where the sum of the elements at those indices is equal to the target.
    - Input: `list = [1, 5, 3, 6]`, `target = 8`
    - Output: `[1, 2] # 5 + 3 = 8`, so the index of 5 is 1 and the index of 3 is 2.

6. **SQL:** Get a column "isProficient" and add 1 if sum of the skills from below table > 3 else add 0

    ```
    name | skills
    -----------------
    John | {"s0": "0.0", "s1": "1.0", "s2": "0.0", "s3": "1.0"}
    Mary | {"s0": "1.0", "s1": "1.0", "s2": "1.0", "s3": "1.0"}
    Alex | {"s0": "1.0", "s1": "0.0", "s2": "0.0", "s3": "1.0"}
    ```

---

## Interview 10 — Client Interview (Multi-round)

### Round 1

1. Project discussion in depth
2. Hacker Rank test: (2 SQL Ques + 1 Python Ques)
    - a. SQL Ques: Question on group By and other question was on using aggregation with case when and group by statements.
    - b. Python Ques: Find the index of substring from a string
3. Spark Architecture and failure scenarios

### Round 2

1. Project explanation and significance or the end of goal of the project/pipeline we built.
2. Spark
    - a. Data Skewness issue and resolution
    - b. Broadcast Join significance
    - c. Spark optimizations techniques
    - d. Different sources from where the data you pulled in last project and the quantity of data
    - e. How will check the quality of data. Basically, how can we calculate Data Quality metrics
    - f. What checks we keep in place while pulling the data from external sources with spark and how the failures are handled
3. SQL — Discussion on the Differences Between GROUP BY and DISTINCT
    - a. Could you explain the differences between the GROUP BY and DISTINCT clauses in SQL? In particular, when dealing with a table containing 100 million records, which approach would be more effective for retrieving distinct records, and why?
    - b. Follow up ques: What is that one case where distinct will be better, if in your answer is group by is better in general.

### Round 3: Interviewer — Santoshkumar Lakkanagaon

1. Spent about 30 minutes discussing various aspects of past projects.
2. How to notify developers effectively if a pipeline fails? Discussed strategies for failover and alerting systems.
3. Create a schema design to support specific business requirements and ensure scalability with respect to Snowflake Schema.
4. Differences between SCD1 and SCD2.
5. Explained the SCD2 used in the project and its implementation process.
6. Data Quality in your project.
7. Spark Optimization techniques used in past projects.
8. **SQL Problem:**

    Tables:
    - visits: Contains columns `visitor_id, visit_id, and date`.
    - visitors: Contains columns `visitor_id and user_name`.

    Task: Write a query to:
    - Identify the user with the maximum visits for each day.
    - Resolve ties by choosing the user with the lexicographically smallest name.

9. Determine the maximum profit that can be made by buying/selling 1 stock. Only one time selling and buying is allowed.
    - Array `SP = [7, 1, 5, 3, 6, 4]` contains stock prices for 6 days.
    - Expected output: 5.

---

## Interview 11 — Interviewer: Santosh Kumar Lakhagaon

### Questions

Hackerank questions: a link was shared to join hackerrank workspace and coding was done there.

1. **Python** — a list `[[1,3],[2,5],[7,9],[8,10]]` was given and asked to minimize the range if `b >= c` where `[[a, b],[c, d]]`
2. **SQL** — visitor_id, visit_id, visit_date and visitor details table visitor_id, visitor_name — find the max visitor details for each day.

---

## Interview 12 — Client Interviewer: Yamika Chauhan (Atlassian DE)

### Questions

- Introduction and about past projects, no cross-questions on past projects
- Asked about tech stack
- 2 SQL Hacker Rank questions

    Provided schema: `Customer, Product_name, action (either sale or refund amount), unit, amount, sale_date`

    1) Return top 2 products from a given table
    2) Based on action, we need to get sale_amount, total_revenue_amount (sale-refund), customer, and total amount per customer

---

## Interview 13 — Interviewer: Abhishek Gupta

### Questions

Hackerank questions: a link was shared to join hackerrank workspace and coding was done there.

1. **Python** — a list of words is provided and they need to be grouped together based on anagrams
2. **SQL** — customer, invoices, contacts tables were given and need to find out the customers who have invoices generated by user who never contacted that customer and also consider only those rows where contacted time is less than invoice created time and provide the total count of contacts

    Schema as per what I could remember:
    - customer: `customer id, customer name`
    - invoices: `customer id, invoice id, contact_user id, time issued`
    - contacts: `customer id, contact user id, contact start time`

- Asked previous project experiences
- Asked about effective documentation importance

---

## Interview 14 — Interviewer: Manoj Kumar (Round 1)

### Questions

1. Second highest salary for the employees
2. Total duplicate records rows and the occurrence of each records based on firstname and last name.
3. Given a list we need to return a list of anagrams.
4. Difference between star and snowflake schema. And the use of each one.
5. Factless fact tables
6. What is persist in spark
7. Various optimization techniques in spark.
8. How to debug a spark job

---

## Interview 15 — Interviewer: Manoj Kumar (Round 2)

### SQL

1. Second highest salary for the employees
2. Total duplicate records rows and the occurrence of each records based on firstname and last name.
3. Out of subquery & cte which one is more performant.
4. Use cases of ctes

### Python

1. Given a list we need to return a list of anagrams in the sorted order.
2. Time complexity of the written code.
3. Time complexity of sorted function
4. Why data structures like list, map etc are used in python not in sql.

### AWS

1. Types of EC2 instances.
2. How to retrieve the deleted object in a S3 bucket?

### Spark

1. Difference between Dynamic partitioning & static partitioning.
2. What is partitioning?
3. What is shuffle partitions?
4. How does spark read the metadata in hive/glue?

### Databricks

1. What is autoscaling?
2. What type of cluster used in Databricks?

### Airflow

1. How do you trigger the failed tasks in Airflow?

### Data Modelling

1. Difference between star & snowflake schema (draw a diagram of either one)
2. What is relationship (one-to-one or one-to-many)
3. Where to use star & snowflake schema?

---

## Interview 16 — Client interview questions from Harish Ankam

### Questions

- SQL query to find DAU (Daily Active Users) and MAU (Monthly Active Users), given an activity table. Schema: `user_id, date_id, activity, timestamp`
- Python coding question to return the group of list of anagrams
- Data modeling questions — diff between star schema and snowflake schema, explain the design, which is better and some use case questions
- Query optimization performance-based questions
- Previous project experiences

---

## Interview 17 — CI questions from Pulkit Gupta

### SQL

`social_media data facebook etc = src_member_id, dst_member_id, activity_type (add/remove), activity_date`

1. Write query to find out 2nd level of friend a member (friend of friend)
2. Write query to find 3rd level of friend a member (friend of 2nd level friend)

Note: need to filter out data first for member which are added and not removed yet (active added member)

SQL optimization for above query

### Python

String and substring as given return starting index of if substring is present in string, if not matching return -1, if both are empty return 0

- e.g. `string = "Hello"`, `substring = 'll'` return `= 2`
- Note: don't use built in function to search

---

## Interview 18 — Interviewer: Anurag Devagiri

### Questions

1. Project
2. What are the challenges you faced in project?
3. What are the option available to solve it?
4. Which one you choose why?
5. Optimization spark
6. Which schema you structure you build in your project why?
7. How you design joining keys?
8. How you handle high volume data?

**Schema:**

Table: interviewer
```
interviewer_id,
name,
designation,
org
```

Table: interview
```
id,
interview_round_type,
start_time,
end_time,
position_id,
role_id
application_id,
interviewer_id, (interviewer)
feedback_id, (feedback_id)
hiring_org,
hiring_manager
```

Table: Feedback
```
feedback_id,
interview_id, (id) interview
details_feedback,
hire_status, (1,2,3,4,5)
feedback_date
```

**Queries:**

- How many interviewers are there in marketing org who are eligible to take interviews at each designation level.
- How many interviews have been conducted for marketing org under John as hiring manager in 3rd quarter. (Assume Q1 starts from Jan-many)
- How many such interviews have been conducted by John who is in M60 designation where candidates got selected (rating 3 and above)
- How many number of interviews are taken by each employee per quarter.
- Optimize all the code

**Python:** Given string, the task is to find if pat is a substring of txt. If yes, return the index of the first occurrence, else return -1.
- Input: `txt = "Atlassian is ssiamazing"`, `pat = "ssi"`
- Output: `4`

---

## Interview 19 — Interviewer: Manoj

### Questions

2 SQL questions:
1. How to find the second highest salary using data frame and sql (sql should be ran through hacker rank and pyspark just to check knowledge)
2. How to find the duplicate records using data frame and sql (sql should be ran through hacker rank and pyspark just to check knowledge)

3. Python code — How to find the anagrams and sort them alphabetically while providing output.

Other questions:
- Star schema vs snowflake schema?
- When to use star schema and when to use snowflake schema for reporting?
- Design a scheme for the product sales? (ask for the which schema they want us to be design and then proceed) — relationship between dimension and fact table for the above scenario.
- There would be canvas provided to design schema so practice on the boards.
- What are partitions in spark?
- Difference between partition and shuffle partition?
- How dynamic and static partition works.
- How spark interacts with the hive metastore? Detailed description of how spark will communicate and would be informed about partition details?

---

## Interview 20 — Interview Name: Judy Thomas

### SQL

Visitors & visits table

Write the sql query to find the customer who has maximum number of visits everyday. If there is an overlapping count then the customer with lower alphabetical order should be given preference.

### Python

**Merge Overlapping Intervals**
- `intervals = [[1, 3], [2, 4], [5, 7], [6, 8], [9, 10]]`
- `output = [[1, 4], [5, 8], [9, 10]]`
- if `b >= c` where `[[a, b], [c, d]]`

**Python**
- `Input = [1, 3, 2, 2, 3, 1]`
- `Output = [1, 1, 2, 2, 3, 3]`
- Without using sorting and bubble sort method

---

## Interview 21 — Interviewer: Santoshkumar Lakkanagaon

### Project Questions

- What are the tools and technologies you have used?
- Explain the different dimensional modeling schemas you've worked with and how you decide which one to use.
- Discuss any challenges faced and how you overcame them.
- Describe your approach to designing efficient data warehouses using dimensional modeling for large datasets and complex reporting requirements, with an example of optimizing models for better performance.
- Have you used Kimball or Inmon approaches for data warehouse design? If so, explain the differences and how you choose between them.

### 1 SQL Question

Atlassian wants to measure website engagement over several days. Given two tables, 'visits' and 'visitors', with columns for visit date, visitor ID, number of pages viewed, and visitor name.

- Write a query to find the visitor who made the most visits each day.
- If there's a tie, select the visitor whose username is alphabetically first.

### 1 Python Question

You are given a collection of intervals, where each interval is represented as `[start, end]`. Your task is to merge overlapping intervals and return a list of merged intervals. Two intervals `[a, b]` and `[c, d]` are considered overlapping if `b >= c` (at least one common point).

For example: Input: `[[1, 3], [2, 6], [8, 10], [15, 18]]` Output: `[[1, 6], [8, 10], [15, 18]]` Explanation: `[1, 3]` and `[2, 6]` overlap, so merge them into `[1, 6]`.

---

## Interview 22 — Interviewer: Srushti Tijare

### Questions

1) Previous Project Experience
2) What techniques did you implemented in spark in your old projects
3) What are the best practises or developments which you have done in your previous data engineering experience
4) Did u do any optimisations
5) What is the size of the data you have worked with and based on the data few practical scenario questions
6) Few questions based on optimisation approach

### SQL queries — two queries

Schema based on remembrance: `user_name, date, status, sale, refund, amount, units` — Find the total sales and total refund and net revenue for each user and round the final output to two decimal places

**Query 2:**

`user_name, date, status, sale, refund, amount, units, frequency` — find the expiry date for each user and product level granularity

We need to calculate expiry date in such a way that it would be next purchase date and if the status is refund populate the date and if the purchase date is null, make sure to populate the expiry date based on frequency like weekly and monthly.

### Python question

- Input = `[1,2,3,4,5,6,7,7,7]`
- Target = `7`
- Output = `[6,8]`

Find the index of first and last position for target element in the array.

Explain how u could solve it and how u approach to the question and tell the complexity and write the code in the optimised way.

---

## Interview 23 — SQL Solutions (from reference page)

### SQL 1: Find Second Degree Friends — Friends of Friends

```sql
create table friends (
    src_id integer,
    dest_id integer,
    activity_type varchar,
    activity_time date
);

insert into friends values(1,2,'add','2024-01-01');
insert into friends values(1,3,'remove','2024-01-01');
insert into friends values(2,1,'add','2024-01-01');
insert into friends values(2,4,'add','2024-01-01');
insert into friends values(4,2,'add','2024-01-01');
insert into friends values(4,3,'add','2024-01-01');

with cte as (
    select *,
        row_number() over(partition by src_id, dest_id order by activity_time desc) as rn
    from friends
    where activity_type='add'
)
select distinct
    case
        when a.src_id < b.dest_id then a.src_id else b.dest_id
    end as src_id,
    case
        when a.src_id > b.dest_id then a.src_id else b.dest_id
    end as dest_id
from cte a
inner join cte b
on a.dest_id = b.src_id
where a.rn = 1 and b.rn = 1
and a.src_id != b.dest_id
order by src_id;
```

Expected output:
```
1, 4
2, 3
```

### SQL 2

Calculate next purchase date for the product based of sale type and subscription.

For a customer and product, use next purchase date - 1 and if there is no next purchase date, use 30 days (for monthly) and 365 days (for yearly)

Table structure: `customer, product, subscription, sale_type, date`

---

## Interview 24 — Interviewer: Santoshkumar Lakkanagaon (Additional)

### 1 SQL Question

1. `social_media data facebook etc = src_member_id, dst_member_id, activity_type (add/remove), activity_date`
    - a. Write query to find out 2nd level of friend a member (friend of friend)
    - b. Write query to find 3rd level of friend a member (friend of 2nd level friend)

Note: need to filter out data first for member which are added and not removed yet (active added member)

### 1 Python Question

Given string, the task is to find if pat is a substring of txt. If yes, return the index of the first occurrence, else return -1.

Time and Space Complexity were asked

### Other Questions

- Spark optimization Techniques
- How do you fix a long running job
- AWS Services Used
- What is SNS?
- Types of Data Modelling
- What is SCD 2? How to implement SCD2

---

## Interview 25 — Interviewer: Sriram

### Schema (ER Diagram)

```
+--------------------+
| salesperson        |
+--------------------+
| salesperson_id PK  |-----+
| salesperson_name   |     |
| manager_id FK      |     |
+--------------------+     |
         |                 |
         |                 |
+------------------+       |    +------------------+
| product          |       |    | sales            |
+------------------+       |    +------------------+
| product_id PK    |---+   |    | sale_id PK       |
| product_name     |   |   +----| salesperson_id FK|
+------------------+   |        | sale_amt         |
                       |        | sale_date        |
                       +--------| product_id FK    |
                                +------------------+
```

### Table: Salesperson

| salesperson_id | salesperson_name | manager_id |
|----------------|------------------|------------|
| 1              | Alice            | NULL       |
| 2              | Bob              | 1          |
| 3              | Charlie          | 1          |
| 4              | David            | 2          |
| 5              | Eve              | 2          |

### Table: Product

| product_id | product_name |
|------------|--------------|
| 101        | JIRA         |
| 102        | Confluence   |
| 103        | Compass      |
| 104        | Test Prd-1   |
| 105        | Test Prd-2   |

### Table: Sales

| sale_id | salesperson_id | sale_amt | sale_date  | product_id |
|---------|----------------|----------|------------|------------|
| 1001    | 1              | 500      | 2024-01-01 | 101        |
| 1002    | 2              | 300      | 2024-01-02 | 102        |
| 1003    | 3              | 700      | 2024-01-03 | 103        |
| 1004    | 4              | 450      | 2024-01-04 | 101        |
| 1005    | 5              | 600      | 2024-01-05 | 102        |
| 1006    | 1              | 500      | 2024-02-01 | 103        |
| 1007    | 2              | 300      | 2024-02-02 | 101        |
| 1008    | 3              | 700      | 2024-02-03 | 102        |
| 1009    | 4              | 450      | 2024-02-04 | 103        |
| 1010    | 5              | 600      | 2024-02-05 | 103        |

### SQL Questions

**1. Write a SQL query to calculate the average sales amount for each product in the year 2024.**

```sql
SELECT p.product_name, coalesce(avg(s.sale_amt), 0)
from Sales s
left join product p on s.product_id = p.product_id
where year(sale_date) = '2024'
group by p.product_name
```

**2. Write a SQL query to retrieve the names of the salespersons who sold both Jira and Confluence in Jan 2024.**

```sql
select
    s.salesperson_name,
    p.product_name
from sales s
join product p
    on s.product_id = p.product_id
join salesperson sp
    on s.salesperson_id = sp.salesperson_id
where date_trunc('month', s.sale_date) = '2024-01-01'
    and p.product_name in ('JIRA', 'Confluence')
group by p.product_name, s.salesperson_name
having count(distinct p.product_name) = 2
```

**3. Print the salesperson_name, manager_name**

Expected output:
```
Alice, NULL
Bob, Alice
Charlie, Alice
David, Bob
Eve, Bob
```

```sql
SELECT
    s.salesperson_name,
    m.salesperson_name manager_name
from salesperson s
join salesperson m
    on s.manager_id = m.salesperson_id
```

**4. Write a SQL query to retrieve the names of the products that made no sale in 2024.**

### Python Questions

**Q1:** Add two numbers
```python
def addNumbers(a, b):
    sum = a + b
    return sum

num1 = int(input())
num2 = int(input())
print("The sum is", addNumbers(num1, num2))
```

**Q2:** Given a list, print the elements in the odd position.
- Input: `[0, 1, 2, 3, 4, 5]`
- Output: `[1, 3, 5]`

```python
res = []
for i in range(0, len(Input)):
    if i % 2 != 0:
        res.append(Input[i])
return res
```

**Q3:** Given a list, print a running cumulative sum of its items.
- Input: `[1, 2, 3]`
- Output: `[1, 3, 6]`

```python
res = []
t_sum = 0
for i in range(0, len(Input)):
    t_sum += Input[i]
    res.append(t_sum)
return res
```

**Q4:** Given a string, write a python function to calculate the average length of the words in the string.
- Input: `"Hello World"`
- Output: 5

```python
l = Input.split(" ")  # ["Hello","World"]
n = len(l)

t_sum = 0
for i in range(0, n):
    t_sum += len(l[i])
return t_sum / n
```

**Q5:** Find the min and max element from the list and remove these element from the final results.
- Input: `[10, 57, 17, 90, 100]`
- Output: `[57, 17, 90]`

**Q6:** Remove the element which exceeds the threshold point
- Input: `[1, 5, 6, 2, 9, 10]`, threshold = 5
- Output: `[1, 5, 2]`

---

## Interview 26

**Technology Areas:** Spark, Pyspark, SQL

### Questions

1. Project Discussion
2. Why do we use spark?
3. What are spark drivers and executers?
4. How job get executed in spark?
5. What are different optimization techniques in spark?
6. How repartition and coalesce works?
7. What is full join?
8. Different types of joins.
9. How can we add a new column which gives us a numbering from 1 to n rows in pyspark
10. Any scenario where we use rank Window function and how it is different from row_number.
11. What is "concat_ws" function
12. What is the use of lit keyword?
13. Why do we use `select(df["*"])`?
14. How can you find duplicates in a dataset?
15. `df.withColumn("col1", "val")`. Is it valid?
16. Left anti join, cross join in sql
17. Window functions
18. What are indexes in sql, how do we decide which column to choose for index?
19. Reasons for OOM error for driver
20. How to debug a long running spark job
21. Spark joins
22. Difference between concat and concat_ws
23. How data is stored in parquet file format and how it is faster and different from other formats?
24. Decorators in python and it's usage example

25. Query optimization:
    ```
    user = (
        user.select("id", "name")
        .join(address.select("id", "country"), "id", "left")
        .filter(col("country") != "USA")
    )
    ```
    What can be changed in this query to optimize it?

26. How many stages will be created for the below query?
    ```
    df = (
        df.select("appliance", "order_num")
        .repartition(5)
        .filter(col("order_num").isNotNull())
        .join(order_df.select("appliance", "category", "sub_category"), "appliance")
        .filter(col("sub_category") != "phone")
        .groupBy("category")
        .count(agg(collect_set("order_num")).alias("order_list"))
    )
    ```

27. **Tables:**
    - `orders_outletB` (1.4B rows): order_id (string), item (string), purchase_date (Date: yyyy-mm-dd), payment_mode (string), customer_id (string: cust-x)
    - `item_df` (3M rows): item (string), cost (double), category (string: electronics, decoration, clothes, etc.), has_stopped_selling (boolean)
    - `customer` (48M rows): id (string: cust-xxxxxxxxxx), gender (string: m/f/nb)

    **Question:** Which item category has the highest purchase by "men" and "nb"?

---

## Interview 27

**Technology Areas:** SQL, PYSPARK, PYTHON, AWS

### SQL

1. What is CTEs, subquery vs cte
2. Window functions and why
3. Rank and dense rank
4. Tables / data bases
5. Why partitioning is required & how
6. Curser, triggers, UDFs
7. Types of views

### Python

1. List comprehension
2. Global variable
3. Do you know methods, class, object etc
4. Unit testing
5. Classes, flow controls, errors handling, methods, variables, globals, good base class library knowledge such as collections, working with json

### AWS

1. Athena queries
2. What is step functions
3. Do you know cdk
4. Glue crawlers, jobs, data catalog
5. S3 lifecycle, partitioning in s3, s3 global naming
6. Update partitions without using crawlers

### Spark

1. What is broadcast variable
2. groupByKey, reduceByKey
3. RDD, dataframe, dataset, df to RDD
4. How do you create a view that is accessible globally
5. Shuffling
6. Pandas vs spark for distributed network

### Others

1. What is CICD? A little in detail about CI/CD flow and tools that you have used
2. What is iceberg tables
3. Docker

---

## Interview 28

### SQL Questions

**1. Select category group from category table which were not placed in orders in order table.**

Note: Even if category group is present in orders but quantity is 0, that should be considered as category which is not ordered.

Tables: Category and Orders

HINT: Left join or minus

**2. From Orders table if there are categories then output is expected as below (Might ask to group using cust_id)**

Expected output:

| prod_category_a | prod_category_b | prod_category_others |
|-----------------|-----------------|----------------------|
| 4               | 8               | 8                    |

Input table — `category | quantity | Cust_id`:

| category | quantity |
|----------|----------|
| a        | 1        |
| b        | 2        |
| c10      | 5        |
| a        | 3        |
| b        | 6        |
| XYZ      | 3        |
| ...      | ...      |

HINT: Generate pivot

**3. Select top 10 products placed in US marketplace for year 2021 and consider only first purchase of those products by customer in that year**

Note: Table of orders is same as in Question 1 above

HINT: Filter (Year=2021 and id=1 which is related to US market), Agg, dense_rank

**4. Select top two products placed by each customer using orderitem table**

Expected output:

| cust_id | top1 product  | top2 product     |
|---------|---------------|------------------|
| cs1     | iron box      | washing machine  |
| cs2     | refrigerator  | -                |
| cs3     | Gas stove     | iron box         |

HINT: There will be two tables orders and orderitem, use only orderitem table and based on quantity and After defining top 1 and top 2 products for each customer generate result in pivot

**5.** (content cut off in image)

---

## Interview 29

**Technology Areas:** S3, Redshift

### Technical Skills

**Mandatory:**

- **Apache Spark / AWS Glue:** Extensive proficiency in utilizing Apache Spark and AWS Glue for efficient data processing and ETL workflows.
- **AWS:** In-depth knowledge of AWS services, particularly S3, Glue, and Redshift / Redshift Spectrum, for building scalable and robust data solutions.
- **Datalakes:** Proficiency in working with data lakes, employing Parquet or Iceberg tables for optimized storage and retrieval.
- **Python:** Strong scripting skills in Python for developing custom data processing scripts and automation.
- **Terraform:** Familiarity with Terraform for provisioning and managing infrastructure resources.
- **CI/CD with CircleCI or GitHub Actions:** Developing new CI/CD workflows to streamline development and deployment processes.

**Good to Have:**

- **Datadog:** Experience with Datadog for monitoring and observability, ensuring the health and performance of data systems.
- **Liquibase:** Knowledge of Liquibase for efficient database schema versioning and management.
- **Kubernetes / Argo Workflow:** Familiarity with Kubernetes and Argo Workflow for container orchestration and workflow management in a distributed environment.
- **Data Quality with Deequ:** Proficiency in utilizing Deequ for data validation and anomaly detection, ensuring high data quality standards.
- **Alation:** Understanding of Alation for comprehensive data cataloging and collaboration among team members.

### Interview Expectations

2) We're expecting practical tasks with Apache Spark
3) We're expecting practical tasks/coding task with Python
4) We're expecting theoretical questions about Glue, Spark and CI/CD.
5) How data is getting loaded to Redshift and how to connect to S3, how insert and update is happening, how to identify the new records and updated records. SCD1 and SCD2 logic.
6) AWS Athena, AWS Glue configurations, SNS and Project discussion.

### Questions

1. Tell me about your project
2. Things to check while extracting data from APIs
3. SQL query optimization
4. Spark skewed datasets - how to handle?
5. AWS architecture of the previous project
6. Glue vs Lambda, glue connectors, glue job optimization
7. While extracting data from databases, if its running slow - how to resolve?
8. SCD1 & SCD2
9. Any interesting thing you worked in your project?
10. Discussion on Agile

---

## Interview 30

### Questions

1. Project Explanation
2. Experience on Databricks SDKs, Databricks APIs, and building Databricks Apps. Databricks Unity Catalog.
3. Spark Job Optimization in depth
4. Python - Datatypes, Testing, Encryption & Decryption.
5. Pyspark

---

## Interview 31

**Technology Areas:** GCP

### Questions

1. Project discussion
2. Major challenges and issues
3. Apache Airflow concepts
    - a. Custom calendar concepts
    - b. Workflow template
    - c. Timedelta concepts
    - d. Difference between catchup and backfills
    - e. How to setup concurrency at airflow level
    - f. Airflow operators (GCP operators, Short circuit, branch, triggerDagRun etc)
4. Dataproc concepts
    - a. How to setup dynamic cluster
    - b. We have running a spark job on dataproc but that job is not utilizing full cluster how to correct that

---

## Interview 32

**Technology Areas:** Databricks, PySpark, Microsoft Azure, SQL

### Questions

1. Explain your recent project and your roles and responsibilities.
2. Explain any one of the user stories that you have worked on in your project (Interviewer asked 4 user stories).
3. What was your prior experience as a Data Engineer?

    (My Previous experience was in AS400, and interviewer also has experience in AS400. He asked questions related to AS400)
    - a. Explain the technologies you used in AS400.
    - b. What programming languages did you use in AS400 projects?
    - c. What is CL programming?
    - d. Which database did you use?

4. Fill the empty salary column with the Average salary

    | STAFF_ID | FIRST_NAME | SALARY | DEPARTMENT |
    |----------|------------|--------|------------|
    | 1        | Monika     | 10000  | HR         |
    | 2        | Niharika   | 8000   | Admin      |
    | 3        | Vishal     | 30000  | HR         |
    | 4        | Amitabh    | 50000  | Admin      |
    | 5        | Vivek      | 50000  | Admin      |
    | 6        | Vipul      | 20000  | Account    |
    | 7        | Satish     | 7500   | Account    |
    | 8        | Geetika    | 9000   | Admin      |
    | 9        | emp1       |        | Admin      |
    | 10       | emp2       |        | Account    |

5. Table name = STUDENTS and Column Name: SCORE, Values (10, 15, 20, 30, 35, 40, 55, 66, 88, 87). Write the Spark code to create a data frame as show:

    | REMARKS | COUNT |
    |---------|-------|
    | EVEN    | 6     |
    | ODD     | 4     |

6. The same question write in SQL

7. Find the missing overlapping dates in SQL from the table `calendar` contains only 2 rows

    | start_date  | end_date    |
    |-------------|-------------|
    | 01-JAN-2025 | 10-JAN-2025 |
    | 08-JAN-2025 | 15-JAN-2025 |

8. Write a query in SQL to print all the transaction history of all Top-10 customers. From the table `customer` and columns: `transaction_id, transaction_date, ar...` (content cut off)

---

## Interview 33

**Technology Areas:** Python, AWS

### Questions

1. Explain recent project and your tech stack.
2. Did you work on application development?
3. Have you work on API based development?
4. Which AWS services you have worked on?
5. Scenario based questions to solve migration of document analysis system to cloud
6. SQL and python questions - medium
7. How authentication in API works? And some questions around flask API
8. Questions around Medallion architecture
9. Discussion around lambda, ec2, airflow
10. Implementation of CICD pipeline
