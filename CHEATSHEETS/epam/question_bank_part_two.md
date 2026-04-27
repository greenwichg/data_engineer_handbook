# Interview Questions — Part Two

## Table of Contents

- [Interview 70](#interview-70) — PySpark, Python, Databricks, SQL
- [Interview 71](#interview-71) — PySpark, Python, Databricks, SQL
- [Interview 72](#interview-72) — Java, SQL, Data Engineering, GCP
- [Interview 73](#interview-73) — Python, Pyspark, SQL, Data Engineering
- [Interview 74](#interview-74) — Spark
- [Interview 75](#interview-75) — A3-A4 — Spark, Scala, SQL
- [Interview 76](#interview-76) — A3-A4 — Spark, Databricks, SQL, PySpark, Pandas
- [Interview 77](#interview-77) — AWS, Delta Tables, Python
- [Interview 78](#interview-78) — A3-A4 — Python, PySpark, Databricks, AWS
- [Interview 79](#interview-79) — A3-A4 — Spark, Python, Databricks, Medallion Architecture
- [Interview 80](#interview-80) — A3-A4 — Python, Spark, SQL
- [Interview 81](#interview-81) — A3-A4 — Spark, SQL
- [Interview 82](#interview-82) — A3-A4 — PySpark, Databricks, SQL
- [Interview 83](#interview-83) — A3-A4 — PySpark, Databricks, Airflow, CICD, AWS
- [Interview 84](#interview-84) — A3-A4 — PySpark, Databricks, CICD, Azure, Python, SQL
- [Interview 85](#interview-85) — PySpark, SQL, Python
- [Interview 86](#interview-86) — Python, PySpark, SQL, AWS, Azure, Databricks, Airflow
- [Interview 87](#interview-87) — Python, PySpark, SQL, AWS, Azure, Databricks, Airflow
- [Interview 88](#interview-88) — Glue, EMR, Redshift, dbt
- [Interview 89](#interview-89) — Python
- [Interview 90](#interview-90) — Glue, Python, PySpark, SQL
- [Interview 91](#interview-91) — Python, PySpark, SQL, CI/CD
- [Interview 92](#interview-92) — GCP, Python, SQL, PySpark, Airflow
- [Interview 93](#interview-93) — SQL, PySpark, Azure
- [Interview 94](#interview-94) — PySpark
- [Interview 95](#interview-95) — PySpark, Pandas, Python, API
- [Interview 96](#interview-96) — AWS, Databricks, Unity Catalog
- [Interview 97](#interview-97) — Databricks, Delta Lake, Spark, AWS
- [Interview 98](#interview-98) — Spark, SQL, Data Modeling, Data Warehousing
- [Interview 99](#interview-99) — Databricks, Delta Lake, Spark, Azure, SQL, PySpark
- [Interview 100](#interview-100) — SQL, Scala, Airflow, Spark, AWS, Python
- [Interview 101](#interview-101) — Spark, Airflow, Python, SQL, Cloud, Data
- [Interview 102](#interview-102) — Snowflake, Airflow, ETL
- [Interview 103](#interview-103) — Spark, SQL, Python, AWS, Airflow
- [Interview 104](#interview-104) — SQL, GCP, Data
- [Interview 105](#interview-105) — ADF, Azure DevOps, Databricks, Apache Spark, PySpark
- [Interview 106](#interview-106) — Azure Databricks, Python, SQL, Apache Spark, PySpark
- [Interview 107](#interview-107) — Azure Databricks, Python, SQL, Apache Spark, PySpark
- [Interview 108](#interview-108) — Google Cloud Platform, Python, PySpark, SQL
- [Interview 109](#interview-109) — SQL, Python, PySpark, AWS
- [Interview 110](#interview-110) — Python, AWS, PySpark, CI/CD
- [Interview 111](#interview-111) — Spark, Databricks, Python, Snowflake, SQL
- [Interview 112](#interview-112) — A4 — AWS, Redshift, DynamoDB, PySpark, Spark
- [Interview 113](#interview-113) — A3 — PySpark, AWS, SQL, Python
- [Interview 114](#interview-114) — PySpark, SQL, Python, ADF, Databricks, Unity Catalog
- [Interview 115](#interview-115) — A3-A4 — Snowflake, DBT

---

## Interview 70

**Group:** A3

**Client Company:** Swiss Re Global HQ

**Topics:** PySpark, Python, Databricks, SQL

---

1. Explain about your project.
2. What data quality checks you did in your project?
3. How data quality was done in your project? Was there any tool used for it?
4. What were various optimizations done in your project?
5. Share any issue which you resolve in your previous projects.
6. How will you handle incremental data in your project? How to make sure only incremental data is processed?
7. What is difference between group by and window function?
8. What were various transformations done in your project and for what purposes they were used?
9. How did you perform data validation at various transformation steps in your project?
10. Did your project use any type of data governance mechanism?
11. What were some minor changes done in the project that led to increase in performance in your project?
12. How will you handle changing schema of your input data?

---

## Interview 71

**Group:** A3

**Client Company:** Swiss Re Global HQ

**Topics:** PySpark, Python, Databricks, SQL

**Interviewer:** shrivishnu and vishwas

**Interviewee:** Shruti Dhage

Hi I have recently attended interview for swiss re project and cleared it. Most of the questions are already covered in KB page. I have not faced any new questions. However for your ease of understanding and getting selected for swiss re i have created this attached document. This contains all the questions along with answers which i had faced or others faced. Please go through it in case if you have interview with Swiss re. All the best!

**Attachment:** SwissRe Interview.docx

**Note:** Project related questions are not covered in this document as the answers may variate depending on the project.

---

## Interview 72

**Group:** A4

**Client Company:** Google

**Topics:** Java, SQL, Data Engineering, GCP

---

1. Java program to validate if array_1 contains in array_2 or not in same order.

   For example,

   a = {1,2,3,4,5,6}

   b = {2,3,4}

   Output = Yes

   b = {2,4,5}

   Output = No

2. SQL query to self-join on employee (emp_id, name, manager_id) table to list employee nd his manager's name.
3. Hive tow tables (Product and Category), how many tow as output for inner_join, Left_join, Right_Join and Cross_Join
4. Design "Vanding machine" database tables and their relationship.
5. Design DB tables for employee staffing Mangement system. Three tables Employee, Projects, assignments

   Based on above tables design, various sql queries:
   - Total employee in each project?
   - Total active projects?
   - Employee working in multiple projects?
6. GCP BigQuery optimization, Partitioning, Cost analysis, Table Sharding, Materialized View, Caching etc.
7. SQL Query optimization techniques
8. Hive: Internal vs External tables, Partitions
9. Delete vs drop vs truncate command

---

## Interview 73

**Group:** A3-A4

**Client Company:** Swiss Re Global HQ

**Topics:** Python, PySpark, SQL, Data Engineering

---

1. l1 = [a,b,c] , l2 = [10,5,20]

   Write a python program to sort first list based on second list. Achieve this in pyspark as well.

   o/p = [b,a,c]

2. l = [0,1,1,2,3,3,4]

   Any 3 ways to remove duplicates from the above list. o/p: [0,1,2,3,4]

   Follow up question: completely remove the duplicated value. o/p: [0,2,4]

3. Table:
   ```
   emp_id,salary,year
   1,10,2019
   1,8,2018
   1,7,2017
   2,100,2019
   2,90,2018
   2,95,2017
   ```

   Write a sql query to identify the emp_id whose salary is consistently increasing each year.

   o/p:
   ```
   emp_id
   1
   ```

4. Table:
   ```
   emp_id,area,distance,flag
   A,x,10,Y
   A,x,20,Y
   A,x,30,N
   B,p,10,N
   ```

   Write a pyspark code to add a new column with logic = Banglore.emp_name.area.distance
   (here 'Bangalore' is literal and emp_name, area, distance are dynamic values. Distance here should be max_distance where flag=Y)

   Expected o/p:
   ```
   emp_id,area,distance,flag,result
   A,x,10,Y,Bangalore.A.x.20
   A,x,20,Y,Bangalore.A.x.20
   A,x,30,N,Bangalore.A.x.20
   B,p,10,N,null
   ```

5. Read a json file and flatten using pyspark.
6. Optimization techniques in spark. (Talked about data skewness, data spill, partitioning, columnar storage file formats like parquet)
7. Approach of unit testing (what are the things that you will consider)
8. input = 1995-12-01 (birth date)

   Calculate age of the person. Do this in Python, Pyspark and SQL.
9. Talk about any spark optimization that you have done in recent times.
10. Approach of debugging the long running spark jobs.

---

## Interview 74

**Group:** A2-A3

**Client Company:** Adidas

**Topics:** PySpark, Databricks, Spark, Python

---

1. Introduction and about responsibilities in most recent project.
2. Spark Architecture
3. Spark Optimization techniques
4. Spark submit basic configurations
5. Commands - select from table 1, select from table 2, join both table, filter, groupBy, filter, saveAsTable. Based on the commands how many stages, jobs and tasks will be created.
6. What makes RDD fault tolerant
7. Why spark is extensively used in bug data world.
8. Unity catalog advantages
9. About delta lake
10. Dataframe with 6 months of data. 1 row is 1 week of data. Each row will have number of stocks of that week and number of stocks sold. Now number of stocks remaining from previous week needs to be added to the coming week. Using for loop for this but it is slow what can be done to make it faster.
11. Where exactly spark runs? inside JVM, where
12. How does the on-heap memory comes? Off-heap
13. Garbage collector comes into the picture?
14. Define class in python?
15. Define static and class method, give promotion to employees of 10%
16. Wal_level, what is write ahead logs? why we use that?
17. ACID -> What exactly is that? Each step? how isolation works in background?
18. What exactly is container in spark? why we require it.
19. Hadoop 1 vs Hadoop 2.
20. cluster vs standalone
21. resource manager, constraints, executors where exactly it is running
22. Serialization -> how object data is stored in spark? why it is even needed in spark
23. medallion architecture
24. unity category in details vs glue catalog vs hive catalog vs without catalog
25. Spark framework, submit command, Dag creation
26. Why Kryo is More Lightweight than Java Serialization?
27. spark memory management (chache vs persist) - types or persist.
28. databricks vs snowflake in terms of catalog (lake house vs data warehourse)
29. create a decorator in code.
30. difference between decorator vs generator vs iterator
31. row_number, rank and dens_rank
32. Write code in spark sql then in dataframe and include OOPs concept.

   Table:
   ```
   transaction_id,customer_id,transaction_date,amount,category
   1,101,2023-01-01,100,Food
   2,102,2023-01-02,200,Electronics
   3,101,2023-01-03,50,Food
   4,103,2023-01-01,300,Clothing
   5,102,2023-01-03,150,Food
   6,104,2023-01-05,120,Electronics
   7,101,2023-01-06,30,Food
   8,105,2023-01-01,500,Travel
   9,102,2023-01-04,80,Food
   10,103,2023-01-02,200,Clothing
   ```

   Queries to write:
   1. 3 top spending customer per category
   2. Top spending customer per category
   3. Daily spending percentile
   4. Customer ranking by total spend
   5. Cumulative spending per customer

---

## Interview 75

**Group:** A3-A4

**Client Company:** Mastercard

**Topics:** Spark, Scala, SQL

---

### Section 1: Spark, Scala & SQL Concepts

1. Introduction and project?
2. What is shuffling in spark and when it happens?
3. Persist, cache in spark and what are the different storage levels. Does the data will spillover if using cache?
4. Predicate pushdown filter in spark and when it happens
5. Scala vs Java
6. What's the difference between 'Nil', 'null', 'None' and 'Nothing' in Scala?
7. What is delta table
8. What is fault tolerant in spark
9. Production issues in project
10. Why Scala can access Java libraries?
11. Scala garbage collection
12. What if the task1 failes in stage 3. From where it will take the data for reprocessing:

    ```
    stage1     stage2     stage3
    100/100    50/50      40/39 1fail
    ```

13. Given the below code, does it work?

    ```scala
    class A(f1: String, f2: String)

    var a = new A("1", "2")
    a.f1 = "v2"
    ```

14. How to find the columns of dataframe
15. 1000 files of each 50mb of below data (nationality:age). How to find avg age for nationality?

    ```
    us:56, .....
    ```

16. Given DS1, DS2 and the expected result below, write steps to get the result dataset which contains non null values.

    **DS1**
    ```
    id  name  salary  phone
    1   Bob   5000    333-555
    2   Rob   7000    null
    3   Snob  5000    null
    ```

    **DS2**
    ```
    id  name  salary  phone
    1   Bob   1000    null
    2   Rob   2000    777-666
    4   Nick  3000    444-333
    ```

    **Result**
    ```
    id  name  salary  Bunus  phone
    1   Bob   5000    1000   333-555
    2   Rob   7000    2000   777-666
    3   Snob  5000    null   null
    4   Nick  3000    3000   444-333
    ```

17. Write a function to take the nonnull columns of df1 and df2 after joining in spark scala
18. Describe below: `val`, `var`, `def`, `lazy val`
19. Spark internal working
20. What is AQE in Spark?
21. How many transformations in spark

---

### Section 2: Coding & Scenario Questions

**Q1.** Find the pairs from the list where sum is 13.

```python
from itertools import combinations
l1 = [2,11,9,4,5,8,6,10,3]

all_possible = combinations(l1,2)

for ele in all_possible:
    if ele[0] + ele[1] == 13:
        print(ele)
```

**Q2.** Create an external hive table, format as parquet, partititoned on date on below schema:

```text
custid, tsn data, txn time, txn amt
```

**Q3.** Identify the customers who have avg spend per day > $50

**Q4.** Identify duplicate records from a table.

**Q5.** What is SCD 2, implement it in pyspark.

**Q6.** Suppose for a customer, the transaction value is loaded as NULL, for that cust replace null with $1000.

**Q7.** Airflow or NIFI — which to use when.

**Q8.** Spark optimization techniques used.

**Q9.** How to identify problem in spark jobs.

**Q10.** Data frame is mutable or not, why?

**Q11.** Source is csv data, load this data to hive that is partitioned on date column using spark.

---

### Section 3: Spark Coding Questions

Given `customer.csv` with schema:

```text
c_id, f_name, city, state, country, dob
```

1. Validation: no additional columns & all columns should be there.
2. Identify null or empty values in all columns.
3. Create column name as `c_id_validation` with above validation values as "Failed" & "Passed".
4. If row exists with the value "Failed" have to generate exception and list down records.

---

### Section 4: Spark Scala Questions

1. Spark performance techniques?
2. How to define no of partitions to be created while creating repartition?
3. Scala case classes

---

## Interview 76

**Group:** A3-A4

**Client Company:** 

**Topics:** Spark, Databricks, SQL, PySpark, Pandas

---

1. Recent Project Discussion and cross questions on the same.
2. What is Apache Spark - High Level Overview
3. What is the role of Apache Spark in Databricks.
4. Overview on Distributed Computing.
5. Explain Data Shuffling in Spark.
6. How do you debug an ADF Pipline which is taking very long time to run.
7. Explain the SQL Query given below.

   ```sql
   WITH SalesSummary AS (
   SELECT
       Salesperson,
       SUM(Sales) AS TotalSales,
       COUNT(DISTINCT CustomerID) AS UniqueCustomers
   FROM SalesData
   WHERE SaleDate >= '2023-01-01'
   GROUP BY Salesperson
   )
   SELECT
       Salesperson,
       TotalSales,
       UniqueCustomers,
       CASE WHEN TotalSales > 10000 THEN 'High Performer'
            WHEN TotalSales BETWEEN 5000 AND 10000 THEN 'Moderate Performer'
            ELSE 'Low Performer' END AS PerformanceCategory
   FROM SalesSummary;
   ```

8. Explain this PySpark Code given below.

   ```python
   from pyspark.sql import SparkSession
   from pyspark.sql.functions import col, avg, when

   # Initialize SparkSession
   spark = SparkSession.builder.appName("DatabricksTest").getOrCreate()

   # Sample data
   data = [
       ("John", "Math", 85),
       ("Jane", "Math", 92),
       ("John", "Science", None),
       ("Jane", "Science", 88)
   ]

   # Create DataFrame
   columns = ["Student", "Subject", "Score"]
   df = spark.createDataFrame(data, columns)

   # Replace null values and calculate the average score
   df_cleaned = df.withColumn("Score", when(col("Score").isNotNull(), col("Score")).otherwise(0))
   df_avg = df_cleaned.groupBy("Student").agg(avg("Score").alias("Average_Score"))
   df_avg.show()
   ```

9. Explain the code given below.

   ```python
   import pandas as pd

   data = {
       "name": ["Alice", "Bob", "Charlie", "David"],
       "age": [25, 30, 35, 40],
       "salary": [50000, 60000, 70000, None]
   }

   df = pd.DataFrame(data)

   df["salary"] = df["salary"].fillna(df["salary"].mean())
   df["age_group"] = df["age"].apply(lambda x: "Young" if x < 30 else "Old")

   result = df.groupby("age_group")["salary"].mean()
   print(result)
   ```

---

## Interview 77

**Group:** 

**Client Company:** 

**Topics:** AWS, Delta Tables, Python

---

### General Questions

- Difference between Glue / EMR / EMR serverless?
- Difference between Redshift Spectrum and Athena?
- Delta tables and it's use case?
- Project overview.

### Python

1. How to get last element from a list by slicing?
2. How to retrieve every third element from a list by slicing?
3. Output of below?

   ```python
   tup = ('a', 'b', [1,2,3])
   tup[2].append(99)
   print(tup)
   ```

4. Output of below?

   ```python
   lst1 = ['cat'] + ['dog']
   lst2 = lst1
   lst2 += lst2
   print(lst1)
   ```

---

## Interview 78

**Group:** A3-A4

**Client Company:** 

**Topics:** Python, PySpark, Databricks, AWS

---

1. Project overview?
2. Usage of Python in your project?
3. What is the output of below?

   ```python
   lst = ['a', 'b', 'c']
   lst[-1:] = 'de'
   print(lst)
   ```

4. How to get last two element from a list by slicing?

   ```
   [1,4,7,9,12]
   ```

5. How to retrieve every third element from a list?

   ```
   [1,4,7,9,12,45,67,98,12]
   ```

6. Output of below?

   ```python
   tup = ('a', 'b', [1,2,3])
   tup[2].append(99)
   print(tup)
   ```

7. Output of below?

   ```python
   lst1 = ['cat'] + ['dog']
   lst2 = lst1
   lst2 += lst2
   print(lst1)
   ```

8. Given the below class, what is the output?

   ```python
   class Test:
       print("hello test")

       def displ(self):
           try:
               print("hello there")
           except Exception as e:
               print("Caught an exception:", e)
           finally:
               print("Reached finally block")

   tst = Test()
   tst.displ()
   ```

9. Which cloud warehouse you have used?
10. How do you maintain primary constrainst in databricks delta table?

---

## Interview 79

**Group:** A3-A4

**Client Company:** 

**Topics:** Spark, Python, Databricks, Medallion Architecture

---

1. Tell me about your role into past projects and which work you have done?
2. How you achieved CDC into databricks?
3. Tell about the databricks services you have utilized?
4. What is CDF in databricks?
5. Data modelling related questions?
6. Data warehouse related questions?
7. What is kafka topic and queue?
8. What is retention period for messages in kafka topic?
9. Which part of kafka integration have you worked on?
10. How you read data from the specified index of kafka topic from beginning?
11. How many files will be created when storing file into delta path in databricks?
12. What is partitioning into hive and how this achieved the optimization into spark?
13. What is cache and persist into spark?
14. Do we need to unpersist the dataframe?
15. What is potential cause for cache?
16. What is the error if cache doesnot work?
17. What is pySpark Context?
18. What is difference between delta table and delta file?
19. How do you acheive rollback from silver layer if bad data comes?
20. What is the strategy if the bad data comes to gold layer for particular area?
21. What is delta log files?
22. What is internal working of spark application?
23. What is Medallion Architecture?

---

## Interview 80

**Group:** A3-A4

**Client Company:** 

**Topics:** Python, Spark, SQL

---

### SQL Questions

1. Get top 3 Salary from each Department as per the given schema.

   ```
   EmpTable        : EmpName, EmpID, Salary, DepartmentID
   DepartmentTable : DepartmentID, DepartmentName

   Output : EmpName, Salary, DepartmentName
   ```

2. Find 7 Days Rolling SUM of SalesAmount as per each StoreID.

   ```
   SalesTable : StoreID, SaleDate, SalesAmount
   ```

### Python

Write a program to count the vowels from given list of strings.

```text
Input  : ["Kuldeep", "Chandra", "Hitesh"]
Output : [3, 2, 2]
```

### Theory and Conceptual

1. Explain how the partitioners work in Spark and how they partition the Data.
2. How can you optimize the Data Quality in Spark.
3. How can you ensure to load the defined columns in DF before processing.
4. Difference between Repartitioning and Coalesce.

---

## Interview 81

**Group:** A3-A4

**Client Company:** 

**Topics:** Spark, SQL

---

1. Broadcast Variables.
2. Spark Components.
3. RDD vs DF.
4. Data Bricks vs Spark.
5. Joins in Spark.
6. Explain lazy evolution in Spark.
7. What is DAG?
8. Different types of file formats.
9. Re-partition vs Coalesce.
10. What is the use of CTE (Common Table Expression)?
11. Window function in SQL.
12. How is CTE different from View in SQL.
13. There are two tables Employee and Department. Employee has emp_id, emp_name, emp_salary, dept_id and department has dept_id and dept_name. Write SQL query to find highest salary in each department.

---

## Interview 82

**Group:** A3-A4

**Client Company:** 

**Topics:** PySpark, Databricks, SQL

---

### Round 1

1. Introduce Yourself
2. Explain your past projects
3. What is Autoloader and when will you use that?
4. What if there is no Databricks or Pyspark, then how will you process data?
5. What are transformation and its types?
6. What is withColumn, lit, fillna, dropDuplicates, groupBy, Join?
7. Design a architecture to process 1000 files landing daily each of 200 mb (csv format) in adls gen2 to delta lake?
8. What is Kafka?
9. How would you debug slow running jobs and what optimization techniques will you apply to make it fast?
10. What is list, tuple, set and dictionary, multithreading, deep clone vs shallow clone, generators, decorators?
11. How would you check if the variable passed to function is list type or not?
12. How would you design a trigger?
13. How can you optimize SQL queries?
14. Any Questions for me - Ask about tools and technologies, roles and use cases?

### Round 2

1. Introduce Yourself
2. What is delta lake and explain its ACID Properties?
3. If 100 hundred different are firing same query from different notebooks to update table, then what will happen?
4. If you want to store historical data in delta table, what would be your approach?
5. What is dbfs and why do we need it?
6. How do you do CICD?

---

## Interview 83

**Group:** A3-A4

**Client Company:** 

**Topics:** PySpark, Databricks, Airflow, CICD, AWS

**Project:** Novartis (Round 2)

**Interviewers:** Kushal / Pradeep

---

### About the project

### DataBricks

1. Enzyme project in DataBricks
2. How to run a notebook from another notebook in databricks
3. Delta live table
4. Autoloader
5. How to install oracle driver in databricks
6. dbutils
7. How delta lake supports acid transactions
8. databricks workflows
9. How to load a csv file from local into databricks & show the data in it
10. z ordering
11. Difference between z order & partitioning.
12. Syntax for loading the data from a rdbms like oracle

### Spark

1. Is spark dataframe mutable or immutable?
2. Difference between DAG & Lineage.
3. Predicate pushdown
4. How does spark recovers a corrupted dataframe (Fault tolerance)

### Airflow

1. How to create dependency between two Dags?
2. Where are you saving the airflow metadata?

### Jenkins

1. How do you troubleshoot a failed step in a jenkins pipeline?
2. How are you rotating the credentials in a jenkins pipeline?

---

## Interview 84

**Group:** A3-A4

**Client Company:** 

**Topics:** PySpark, Databricks, CICD, Azure, Python, SQL

**Project:** Novo Nordisk

**Interviewer:** Shahed Mirza

---

### About the previous project

### DataBricks

1. Delta Live table
2. Types of CDC
3. How to process Real time data in DataBricks
4. Medallion Architecture
5. Difference between Delta lake & Delta table

### Spark

1. Difference between Narrow & wide transformation.
2. Difference between spark Dataframe & pandas Dataframe.
3. Types of cluster manager
4. What is cluster manager

### Data Modelling

1. Difference between Star & Snowflake schema
2. If the data from gold layer tables are consumed by data science team then which schema shall we choose & why.

### Python

1. Lambda functions & its examples

### ADF

1. There are several files in csv, parquet, orc, avro, excel present in Azure storage. How do you frame the ADF job so that the files are segregated in separate folders like csv, parquet, orc, avro, excel.

### SQL

Write the sql query to find the names of employees & their manager names for the below schema:

```text
employee
emp_id  emp_name  mgr_id
```

---

## Interview 85

**Group:** 

**Client Company:** 

**Topics:** PySpark, SQL, Python

---

0. Based on project questions will be asked
1. Out all parallel tasks, one tasks is running log, about data skewness?
2. How will you fix data skew, other than data skew what else you can do - like predicate push down and proper partitioning we can limit input data
3. Have you faced OOM issues, while reading data?
4. Spark optimization followed in project? Any issues faced.
5. Which spark version used, is there any latest update in spark
6. What is Off heap memory?
7. Get manager and their employee details using self join in pyspark & sql

   ```
   input
   empid, managerid, empname, managername


   expected output
   Manager_name1, Manager_name2
   emp1, emp4
   emp3, emp6
   emp5, emp8
   ```

---

## Interview 86

**Group:** 

**Client Company:** 

**Topics:** Python, PySpark, SQL, AWS, Azure, Databricks, Airflow

**Project:** LSEG-LPC

**Interviewer:** Manish Bhoge

---

Detailed discussion About the previous project

### DataBricks

1. Difference between Unity Catalog & Hive Metastore
2. Asset Bundle
3. Deployement of python notebooks in databricsks as .py file or .ipynb file
4. DataBricks Api
5. Deployment in DataBricks

### Python API

1. FastAPI

### Azure

1. Azure APIM

---

## Interview 87

**Group:** 

**Client Company:** 

**Topics:** Python, PySpark, SQL, AWS, Azure, Databricks, Airflow

**Project:** NBS-SCM1

**Interviewer:** Jithin Moncy

---

### DataBricks

1. Delta Table
2. Delta Live Table
3. Unity Catalog
4. Autoloader

### Spark

1. Spark architecture
2. Spark internal functioning
3. Spark Optimisation technique
4. Explode function
5. Flatten function

### Airflow

1. Scenario based questions on creating dependency between twi dags -- External Sensor.
2. Components of arirflow.
3. Dag, tasks

### SQL

1. Question on lead/lag

---

## Interview 88

**Group:** 

**Client Company:** 

**Topics:** Glue, EMR, Redshift, dbt

---

### Internal Project Interview

1. Redshift — why it different than traditional db. How to optimize queries there if taking time.
2. What is lambda and its limitation
3. S3 storage classes
4. Data catalog
5. Pyspark optmization and different join types
6. Rolling sum SQL/Pyspark: add new column with total_sum_sales which indicate current month sum + all previous month sum.
7. EMR vs Glue

### Client Interview

1. Past project end to end flow (all below questions were based what you explain in project flow)
2. Where you used which service and how
3. Whatever you mentioned in resume mostly that.
4. Incremental load in glue and job bookmark
5. What are the API you have used in pyspark
6. Persist and Cache
7. What are the different options with persist
8. Any complex or challenging scenario in project

### Client Interview (additional notes)

- Project experience
- Questions to explain end to end ETL pipeline from project
- Spark optimization/optimization used in project
- Structure for Airflow DAG, DBT, Pyspark - in coding
- All questions related to project in resume.

---

## Interview 89

**Group:** 

**Client Company:** 

**Topics:** Python

---

1. What are mutability and immutability in python
2. Declare a string and change it's certain character and create a new string
3. What would be the output of below?

   ```python
   l1 = [1,2,3,[4,5]]
   l2 = l1
   l1.append(7)
   l2[3].append(6)
   ```

4. Create a list2 without changing list1, write a python code for the same (can use deepcopy also)

   ```
   l1 = [1,2,3,[4,5]]
   l2 = l1 = [1,2,3,[4,5,6]]
   ```

5. What is virtual environment

   A virtual environment is an isolated environment where you can install Python packages specific to a particular project — without affecting the global Python environment on your system.

6. Have you created any python packages in your previous projects.

---

## Interview 90

**Group:** 

**Client Company:** 

**Topics:** Glue, Python, PySpark, SQL

---

### Round 1 (Internal)

1. Tell me about your project?
2. What are the services used?
3. Real time use case difference between lambda & Step function
4. What are the limitations of using lambda?
5. Difference between saveAsTable() & save() in spark dataframe?
6. How will you handle different datatype for same columns in Glue DynamicFrames?

### Round 2 (Internal)

1. Describe about project
2. Difference between At-least once delivery and at-most once delivery in messaging services?
3. Difference between checkpoint() and cache()
4. Identify spark errors and simple spark code to create dataframe

### Round 3 (Client)

1. Describe about project
2. Where does Spark stores its Physical and Logical plans?
3. Difference between At-least once delivery and at-most once delivery in messaging services?
4. How can we restrict user access in Athena? List ways and describe?
5. What the types of messaging services available in market?

### Softskill

1. What are the challenges faced in previous project

---

## Interview 91

**Group:** 

**Client Company:** 

**Topics:** Python, PySpark, SQL, CI/CD

---

### Client Round

1. Describe about project and yourself
2. Was given two tables:

   **1. Customer Location History Table** — contains the following columns:
   - `customer_id`
   - `nationality`
   - `city` (the city where the customer started living)
   - `start_date` (the date the customer began living in that city)

   **2. Transaction Table** — contains the following columns:
   - `customer_id`
   - `city` (the city where the transaction took place)
   - `transaction_date`

   **Task:** Create a new column in the transaction table to indicate whether the customer was living in the same city at the time the transaction occurred?

3. From the given string "DeepakD", find the first unique character?

---

## Interview 92

**Group:** 

**Client Company:** 

**Topics:** GCP, Python, SQL, PySpark, Airflow

---

### Round 1

1. Describe details on my project?
2. Told to write Airflow Code Implementation for Loading Data from Rest API to GCS do transforms and load to Big Query?
3. Given two tables in SQL Asked for Running total of sales for last 5 days using window operators?
4. Spark internal Memory allocations how on heap memory different from overhead and different memory issues you encounter in day to day projects?
5. What are GCP Tech Stacks you used other than composer and big query?
6. Asked a python Code to return list of words from a list in same order of occurrence?

   ```
   Example_input_string: "The cat, the cat, and the cat sat on the mat, the mat, and the mat"
   Output:

   ['the', 'cat', 'and', 'sat', 'on', 'mat']
   ```
7.

### Round 1 (additional)

1. Remove duplicate in list keeping order

2. SQL:

   ```
   Employees(emp_id, name, department_id, salary, hire_date)

   Departments(department_id, department_name)

   Projects(project_id, project_name, start_date, end_date)

   EmployeeProjects(emp_id, project_id, assigned_date) - most recent joined employee in each department
   ```

3. Airflow related questions:
   - Airflow — how to pass secret values?
   - Email notification in airflow?
   - GCP?
   - Big Query?

4. Sample scenario - read data from API, process and load to destination s3, on job completion enable notification? How to do this in airflow

5. Past project experience.

---

## Interview 93

**Group:** 

**Client Company:** 

**Topics:** SQL, PySpark, Azure

---

1. Describe about project
2. What is catalyst optimizer?
3. Where will projection pruning, partition pruning takes place?
4. Indexing and its types in SQL.
5. Primary key columns is what type of index?
6. Given the below tables, count of records for inner join, left join, full outer join, and write query for cross join.

   ```
   Table A    Table B
   1          1
   2          1
   3          2
   4          2
   5          3
   6          4
   ```

7. Given the schema:

   ```
   Orders(order_id, customer_id, order_date)
   Customers(customer_id, customer_name)
   ```

   Write SQL query to find customers who never placed any orders.

8. PySpark — given the table below, find the top 2 salaried employees per department.

   ```
   +-------+--------+--------+
   |emp_id |dept_id |salary  |
   +-------+--------+--------+
   |1      |10      |5000    |
   |2      |10      |6000    |
   |3      |20      |5500    |
   |4      |20      |5800    |
   |5      |10      |5200    |
   +-------+--------+--------+
   ```

9. You are joining a large transactions dataset (~1 TB) with a small merchants dataset (~2 MB) on merchant id. The join is taking too long, and a single task is significantly slower than the others.
   - What could be the issue? How to handle this.
   - How would you solve it? Provide the PySpark approach.
   - Any approach can be used other than broadcast join?

10. When we should use broadcast join?
11. Tell about optimization in Spark.
12. There are 100 jobs running in spark cluster, where 2-3 jobs taking long time, how to handle this?
13. What would be spark configuration to process 25Gb file. Explain your approach.
14. What are benefits to use Delta tables? How it befits than other file formats.
15. What is checkpoint.
16. Types of spark join strategies
17. What is Autoloader and why use Autoloader?

---

## Interview 94

**Group:** 

**Client Company:** 

**Topics:** PySpark

---

1. PySpark experience
2. Coding question on pyspark
3. PySpark solve — given the input below, produce the expected output.

   **Input:**
   ```
   id  topic    title    pages
   1   Nature   title1   [{"pagenumber": 1, "topic": "topic1"}, {"pagenumber": 2, "topic": "topic2"}, {"pagenumber": 3, "topic": "topic3"}]
   ```

   **Output:**
   ```
   id  topic    title    pagenumber  avg_char_per_title
   1   Nature   title1   1           6.0
   1   Nature   title1   2           6.0
   1   Nature   title1   3           6.0
   ```

   Solution — using explode function.

---

## Interview 95

**Group:** 

**Client Company:** 

**Date:** 2025-07-25

**Topics:** PySpark, Pandas, Python, API

---

**Q1)** Basic Introduction

**Q2)** Given below two CSV files, find the similarities and differences between files using spark or pandas.

```text
file1.csv contains
Name,Age,City
John,25,New York
Emily,30,Los Angeles
Michael,40,Chicago
```

```text
file2.csv contains
Name,Age,City
John,25,New York
Michael,45,Chicago
Emma,35,San Francisco
```

**Q3)** Given the below dataset, write code so that only priority 1 rows get fetched.

**Input:**

| Dataset_name | Source_var | Target_var | priority |
|--------------|------------|------------|----------|
| dm           | a          | C          | 1        |
| dm           | a          | B          | 2        |
| ex           | a          | A          | 4        |
| ex           | b          | B          | 4        |
| ex           | b          | X          | 3        |
| ex           | b          | Y          | 2        |

**Output:**

| Dataset_name | Source_var | Target_var | priority |
|--------------|------------|------------|----------|
| dm           | a          | C          | 1        |
| ex           | a          | A          | 4        |
| ex           | b          | Y          | 2        |

**Q4)** Design an application to take input values from frontend (in form) and push it to database.

**Q5)** How would you design an application that takes permissions from frontend and update the values in below database and update the folder permissions.

Here is structure:

```text
Project Name, Project Folder, VIEWER_USERS
A, <project_identifier_1>, [User1, User2]
B, <project_identifier_2>, [User3]
```

If new user like USER4 is added to project A, then VIEWED_USERS list should be added to corresponding row and using API permission should be granted.

---

## Interview 96

**Group:** 

**Client Company:** 

**Topics:** AWS, Databricks, Unity Catalog

---

- AWS Glue, Athena, Redshift
- EMR
- AWS experience
- Project experience
- How to read data — connection — glue catalog — athena — redshift
- Delta live table
- Unity catalog
- Workflow, task, schedule in databricks
- Cloud file in databricks
- Delta lake how to connect with unity catalog
- Features of unity catalog
- Cloud based storage
- AWS Lambda

---

## Interview 97

**Group:** 

**Client Company:** 

**Topics:** Databricks, Delta Lake, Spark, AWS

---

### Round 1

- Databricks unity catalog
- Delta lake
- Glue catalog vs unity catalog
- Pandas vs pyspark
- Shuffling in spark
- Data crawler (what special feature) vs Athena
- Databricks feature from other data warehouse / data lake — data + storage not coupled together

### Round 2

- Shuffling — what specific in coalesce. Do it work like action in spark? Do it create separate stage?
- SCD2 code SQL, pyspark?
- CSV zip file, can be read in 1 core? Will it be partitioned while reading in spark?
- Experience in past projects

---

## Interview 98

**Group:** 

**Client Company:** 

**Project:** CARG-MIEX

**Interviewee:** Gulfam

**Interviewers:** Amogh and Chandan

**Topics:** Spark, SQL, Data Modeling, Data Warehousing

---

1. Take one project and run it through end to end including what was your role in that project, what was that project about.
2. Have you worked on building any data products as such — data pipeline is one side where there is a source system you ingest the data and maintain all the pipelines, but now say some business gives some logic — have you built some data products from scratch?
3. What's the difference between a normalized and a denormalized data set?
4. Strong entity weak entity
5. Terms like constraint, insert constraint, delete constraint — are you aware of these terms?
6. Different SCD types
7. How do you manage the fast changing dimensions
8. Are you aware of the traps like in database design and database modeling — there is something called as chasm trap and fan trap. Are you aware of what exactly is a chasm trap and fan trap?
9. How do you work and design a particular spark pipeline to process incremental data loads?
10. How you are handling it i mean into the target table — how you are loading the data. Let's say it's a weekly job you are running and you have a data let's say on eighteenth of November you had an insert, then are you pulling the complete data or as we mentioned we are only pulling based on delta data, so how is that handled while inserting a table?
11. What kind of transform like wide and narrow transformations have you used? And with group by key and reduce by key — what's the difference?
12. Okay how do you handle any kind of schema evaluation in your data lake mainly on source table to target table side?

---

## Interview 99

**Group:** 

**Client Company:** 

**Topics:** Databricks, Delta Lake, Spark, Azure, SQL, PySpark

---

1. Introduction.
2. Can you explain about your recent project?
3. What is that the need of this project?
4. What is the cloud platform using for the project?
5. When you how you worked or used Azure database or Azure platform.
6. Data breaks. What is a shallow cloning and deep cloning?
7. What are the views in data bricks?
8. How would you troubleshoot the data brick jobs and how would you optimise the jobs?
9. What is a liquid clustering?
10. Can you difference between delta table and parquet file?
11. What is the advantage of using delta tables?
12. Have you worked on a streaming?
13. What is the checkpoint?
14. Do you know the difference between interactive cluster and job cluster?
15. There is a one static file I have and there's a as a one source I have a streaming data as a one source and I want to join. We'll be able to join this static data and streaming data.
16. Have you heard static streaming?
17. What are your aspirations from the project?
18. You need to fix something for the target and on top of that you need to give for the cluster right? So what is the ideal way that you can go for the configuration? The cluster — so what you will do? What is your ideology?
19. What is RDD?
20. What is the difference between RDD and data frame?
21. What is the catalyst optimizer?
22. So I have a table — for example you can say you have a job is running with the data of 1 terabytes in production which has been joining with another set up table with the data sizes one MB. So in production the job is taking long time. So with this case what will be the issue and what is a fix you will?
23. So what is the 4S? Do you know the S problems of spark? There are 4S problems of spark.
24. Do you know the joins in spark?
25. So how do you optimise for the spark jobs?
26. Do you know Common Table Expression. So what is the difference between CTE and SUBQUERY?
27. When can we use a group by and window function in sql?
28. What is the view and metalize the view?
29. What you understand from the query and is there any way of improvement from this code, let me know.

   **Orders:**
   ```
   | order_id | customer_id | order_date  | amount |
   |----------|-------------|-------------|--------|
   | 1        | 101         | 2024-06-01  | 200    |
   | 2        | 101         | 2024-06-05  | 150    |
   | 3        | 102         | 2024-06-07  | 300    |
   | 4        | 103         | 2024-06-10  | NULL   |
   ```

   **Customers:**
   ```
   | customer_id | name    | region |
   |-------------|---------|--------|
   | 101         | Alice   | East   |
   | 102         | Bob     | West   |
   | 103         | Charlie | North  |
   ```

   ```sql
   SELECT
       c.name,
       COUNT(o.order_id) AS total_orders,
       SUM(o.amount) AS total_amount
   FROM customers c
   JOIN orders o
       ON c.customer_id = o.customer_id
   WHERE o.amount > 0
   GROUP BY c.name
   ORDER BY total_amount DESC;
   ```

30. What is issue with this query and what it will do first?

    ```sql
    WITH ranked_orders AS (
        SELECT
            customer_id,
            amount,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
        FROM orders
    )
    SELECT
        c.customer_id,
        c.name,
        r.amount AS latest_order_amount
    FROM customers c
    LEFT JOIN ranked_orders r
        ON c.customer_id = r.customer_id
    WHERE r.rn = 1;
    ```

31. Go through following code:

    ```python
    fact_df = spark.read.parquet("fact_table")
    dim_df = spark.read.parquet("dim_table").filter("region = 'West'")

    df_joined = fact_df.join(dim_df, "region")
    df_joined.write.parquet("output_path")
    ```

    So there's a missing some optimization techniques. So what will be the fix? Can you write a query for that?

32. So do you have worked on adls Gen 2 storage systems? So what are the storage systems or storage accounts in Azure?
33. What is the difference between BLOB and adls?
34. I have a files which should keep under one roof. There's no hierarchy, there's no segregation, kind of a thing in that case, which can be suggestible, BLOB storage or ADLS2?
35. So now you have ADLS. Which location will be best? Suppose if you are using for the data bricks, will you go for the DBFS or will you go for the external storage account which can be mounting to data bricks either S3 or Azure. So what is a suggestion? Suppose you have a project you want to do that to work on the data bricks, which is storage account. Will you prefer if you are preferring to work with the data bricks?
36. What is the difference between Event Hub and Kafka.
37. So this one for the coming back to the storage account. So there's a hot type cold type archive. So do you know the difference between these types or data layers?
38. Do you have know on Azure logic apps and Azure functions?
39. So there's a unity catalogue in data bricks and there's a high meta store. What's the difference between both?
40. Have you worked on any Azure DevOps? Do you have any idea?
41. I have given one more query code. Please analyse it and let me know what is happening there.

    ```python
    from pyspark.sql.functions import current_date, lit, col
    from delta.tables import DeltaTable

    dim_path = "/mnt/data/customers_dim"

    customers_dim = DeltaTable.forPath(spark, dim_path)

    customers_stg = spark.table("customers_stg") \
        .withColumn("start_date", current_date()) \
        .withColumn("end_date", lit("9999-12-31")) \
        .withColumn("is_current", lit(True))

    stg_alias = "stg"
    dim_alias = "dim"

    merge_condition = "stg.customer_id = dim.customer_id AND dim.is_current = true"

    update_condition = (
        "dim.name <> stg.name OR dim.address <> stg.address"
    )

    customers_dim.alias(dim_alias).merge(
        customers_stg.alias(stg_alias),
        merge_condition
    ).whenMatchedUpdate(
        condition=update_condition,
        set={
            "end_date": current_date(),
            "is_current": lit(False)
        }
    ).whenNotMatchedInsert(
        values={
            "customer_id": "stg.customer_id",
            "name": "stg.name",
            "address": "stg.address",
            "start_date": "stg.start_date",
            "end_date": "stg.end_date",
            "is_current": "stg.is_current"
        }
    ).execute()
    ```

---

## Interview 100

**Group:** 

**Client Company:** 

**Topics:** SQL, Scala, Airflow, Spark, AWS, Python

---

1. Tell about yourself?
2. Databricks unity catalog
3. How many yrs you have worked on scala
4. Why scala is most familiar
5. When did you start with the scala trainings and projects.
6. Have you worked on akka, play framework and rest api creation
7. Have you worked on databricks
8. How do you handle exception in scala
9. What is option in scala
10. Have you worked on SQL
11. What is reconcilation script?
12. What is medallion architecture?
13. Have you worked on python?

### Programs

1. In scala — given `Seq(3, 7, 31, 20, 5)`, the result should be `Seq((31,2),(20,3))`.
2. Swap 2 variables a, b in python without using 3rd variable.

---

## Interview 101

**Group:** 

**Client Company:** 

**Topics:** Spark, Airflow, Python, SQL, Cloud, Data

---

1. Introduce yourself and talk about different project you have worked on
2. Spark job lifecycle
3. Design pipeline scenario:

   We are getting daily csv file on sftp vendor server. We want to source this file, perform different cleaning activty and load it into final warehouse. Tell me your approach to this problem.

4. Follow up question: How are you going to design if these are incremental files? Then discussion over solution.
5. What could be your solution if you have been asked to design dynamic airflow dag from provided underlying data (it means you have a metadata available of existing jobs and need to provide solution for writing the dynamic dag solution)?
6. When to use dynamic dag creation vs template based dag creation
7. Scheduling methodologies for orchestration
8. We are getting duplicates records which are already written to bigquery. What would be your solution to correct data on this?

### Python problem

Identify longest substring in O(n)

### SQL problem

Solve in SQL — You want to identify the hierarchy of employees based on the managerid.

```text
employee
id   name   managerid
1    abc    null
2    xyz    1
3    jhl    2
4    hfg    2
```

If given id = 3 then output should be:
```text
abc
xyz
jhl
```

---

## Interview 102

**Group:** 

**Client Company:** 

**Topics:** Snowflake, Airflow, ETL

---

1. Introduce yourself and experience with Snowflake, Airflow and any other Pipelines
3. Data Lake v/s Data warehouse
4. Have you created Slowly changing dimension
5. How to ingest data in snowflake
6. About Snowpipe — have you implemented that?
7. Have you used transient tables in snowflake?
8. If you have tables in Snowflake and these tables are queried by Power BI to build reports and someone from Power BI team query works slower than expected, then how to troubleshoot into that kind of issue?
9. If you're going to insert in the Snowflake table with primary key defined duplicates, will you be able to insert duplicated data into this table?
10. How you manage the secrets for the pipelines?
11. Sensors in Airflow
12. Best practices while creating pipelines
13. Have you ever implemented testing like data quality tests in your pipelines?
14. Can you explain about CI/CD pipeline from recent project
15. As a code reviewer how do you check and what process do you follow?
16. Create a python function to read csv file
17. If you need to choose between Pandas and python CSV, how you will choose what you will consider?
18. You deployed a new feature to production environment and it is already in production. The pipeline will be executed in two hours from now, so it's already in production but you just realized that you made something wrong and this solution will break the data in data warehouse. What you will do in this case?

---

## Interview 103

**Group:** 

**Client Company:** 

**Topics:** Spark, SQL, Python, AWS, Airflow

---

### Round 1 Client

**Project Architecture (25 mins)**

**Rest all questions (40 mins)**

1. There is a 1 TB data in a sql server table — how would you design a table from an end business user perspective? [focus on indexing, partitioning]

   Employee Table: id, salary. Salary → get me id, salary, and total_salary without using group by:

   ```sql
   select id, salary, sum(salary) over(partition by dept_id) as sum_salary from employees;
   ```

2. There is a stored proc very big, consists of loads of joins. You cannot rerun the proc once again to get the stats. How by just looking at procedure can you identify the pain points?
3. There is a data in table 1 TB. How can you read from db and bulk load in warehouse? You cannot use jdbc options.
4. There are 5 nodes, 5 diff nodes 200 GB each node, total 1 TB and you are joining with 1 GB table. What ways to do? (Cross question: what's the way we can have the 1 GB table being replicated in all the nodes?)
5. How would you handle dependency between Task X in DAG 1 with Task Y in DAG 2?

### Round 2 Client

- Tell me practically how would you resolve spark job? (don't tell bookish answers)
- SQL Server optimization techniques?
- Deep dive into architecture? Why used event bridge? Not sns?
- EMR vs Glue? When to use what?
- Python Group Anagrams Code?
- Python oops concepts like static method, class methods
- Why used redshift?

### SQL Question 1

- Find department wise highest salary using window func?
- Diff between rank, dense_rank, row_number?

### SQL Question 2

Solve using SQL.

**Source Table:**

| id | manager |
|----|---------|
| 1  | 2       |
| 2  | 3       |
| 3  | 4       |
| 4  | 5       |
| 5  | null    |

**Target Table:**

| id | m1   | m2   | m3   |
|----|------|------|------|
| 5  | null | null | null |
| 4  | 5    | null | null |
| 3  | 4    | 5    | null |

---

## Interview 104

**Group:** 

**Client Company:** 

**Topics:** SQL, GCP, Data

---

### SQL Questions

Tables:
- Customers(id, name, address, age, email)
- Products(id, name, price)
- Sales(date, customer_id, product_id, units_sold)

1. Find the most favorite product of each customer and how much revenue it generated.
2. Find the customer who buys 2 or more products at a single visit. (Optimise the query)
3. Identify customers who bought exactly 3 different products and count the total "Apple" units bought by them.

### Technical Theory Questions

1. Difference between OLAP and OLTP (include a real-life business scenario)
2. Give the approach to design OLAP in data warehouse.
3. Explain an example of ETL flow with data source and stage difference.

### Scenario Based Questions

1. How will you handle an error (transformation failed) if the developer working on the pipeline left.
2. Identify the error and give steps to resolve it.
3. How will you deal with the situation when the documentation and code base is a) hardcoded, b) no comments in code, c) legacy logic not defined — how will you resolve it and if not resolved what all can be the issues which can occur.
4. If a data pipeline is slow due to high demand, how to resolve?
5. What should be displayed to the users when the pipeline is slow or throwing errors.

---

## Interview 105

**Group:** 

**Client Company:** 

**Topics:** ADF, Azure DevOps, Databricks, Apache Spark, PySpark

---

### 1. ADF

a. How to build an end-to-end ADF pipeline to copy 50 sql tables sequentially into adls

b. Source files are coming to adls location daily. Build a pipeline to copy only the latest file.

### 2. Databricks & PySpark

a. Detailed discussion on Unity catalog — it's advantages over legacy hive metastore, permission assignments, delta share

b. PySpark optimization — Zorder, liquid clustering, partitions etc

c. CI/CD with Azure devops

### 3. Python

a. Write a python code for below

   ```
   Input  = [45, 12, 25, 56]
   Output = [9, 3, 7, 11]    -- (4+5 = 9, 1+2 = 3, 2+5 = 7, 5+6 = 11)
   ```

b. Explain about Python decorators

### 4. SQL

a. Write a sql query to find top n city with maximum total sales, considering only cities having atleast 3 sales records

   ```
   source_data
   City | Date | Sales
   A, 2025-10-01, 560
   A, 2025-10-02, 580
   B, 2025-10-02, 670
   B, 2025-10-02, 780
   C, 2025-10-02, 680
   C, 2025-10-03, 540
   C, 2025-10-04, 660
   B, 2025-10-04, 880
   ```

b. Explain inner, left, left_anti, rank(), dense_rank(), row_number()

c. What is dimension and fact table

---

## Interview 106

**Group:** 

**Client Company:** 

**Topics:** Azure Databricks, Python, SQL, Apache Spark, PySpark

---

0. Introduction and last project and roles and responsiblity
1. Difference between VACUUM vs OPTIMIZE BY and write the syntax
2. Coalesce and repartiton
3. Job, stage and task created in the sample code, and to check the number of partiton in the dataframe.
4. Databricks Secret Scope vs Azure Key Vault (AKV) Secret Scope
5. Python Question.

   Given the list:
   ```python
   li = [1,1,2,3,4,4,4]
   example: dic = {1:2, 2:1, 3:1, 4:3}
   ```
   Find the element with the second-highest occurrence in the list.
   Expected output: 1

6. SQL question

   ```
   table employee_salary
   dept_id, emp_id, salary

   table employee_detail
   emp_id, emp_name
   ```

   - Name of employee not present in employee_salary table
   - Name of employee 10 highest in each department

7. UC discussion.
8. Spark job optimization ways.

---

## Interview 107

**Group:** 

**Client Company:** 

**Topics:** Azure Databricks, Python, SQL, Apache Spark, PySpark

---

1. Difference between overloading and overriding in python
2. How to install external libraries in databricks
3. How to optimize cluster in databricks
4. How you used unity catalog in your project
5. What is service principal in databricks
6. Difference between pandas dataframe and pyspark dataframe
7. Spark optimization techniques and databricks additional optimization techniques
8. Suppose I have cached a dataframe and after which data at source side has been changed, then how will spark react?

---

## Interview 108

**Group:** 

**Client Company:** 

**Topics:** Google Cloud Platform, Python, PySpark, SQL

---

- Given the current project structure and workload requirements, where would your expertise be able to help?
- How do you identify ways to optimise data pipeline?
- Assume two or more jobs are running concurrently that update a table incrementally — how will you ensure data consistency in case interim errors are encountered?
- What is data modelling? What are some of the ways data is generally implemented?
- What is LookML? (Follow-up to it) What are Views in Looker Service?
- How is data accessed in the Looker dashboard?
- Design a streaming pipeline that stores data from multiple devices and is used to build dashboards for stakeholders. (Follow-up question) The data volume is fluctuating exponencially, how will the pipeline handle scaleability? (Follow-up to it) Define the stages that is helping the pipeline to capture, store and process the data.
- Maximum number of partition columns in bigquery.
- Difference between datetime and timestamp in bigquery.
- How to set dependency between 2 DAGs in Airflow
- How will you create a cluster for multiple Dataproc jobs, fleet or template?
- How will you do RCA if the spark job got failed on last saveAsTable action?
- How will you mitigate data skewness in Spark.
- What kind of performance tuning you did in your last project?
- What's your day-to-day work in your last project?
- How will you read the bigquery table inside the Dataproc job with filter condition?

---

## Interview 109

**Group:** 

**Client Company:** 

**Topics:** SQL, Python, PySpark, AWS

---

1. Difference between text file & parquet format

2. Given a sql table as below:

   ```
   1 eng 10
   1 math 8
   2 eng 5
   2 math 8
   ```

   Write a query to fetch below output:

   ```
   id  eng  math
   1   10   8
   2   5    8
   ```

3. Given a list of numbers in python as follow:

   ```
   d = [12, 4, 5, 6, 3, 13, 19]
   & target = 9
   ```

   Give me all the pairs of numbers from the list along with their indices whose sum equals target.

4. AWS S3:
   - How can you recover accidentally deleted files in AWS S3 buckets
   - Different storage classes

5. AWS Lambda
   - How can a function get triggered
   - Limitations of AWS Lambda

6. Difference between AWS SQS & SNS.

---

## Interview 110

**Group:** 

**Client Company:** 

**Topics:** Python, AWS, PySpark, CI/CD

---

### Project Discussion

1. Explain your recent project end-to-end.
2. List the document types used in NoSQL databases.
3. How did you implement incremental load in your project?
4. List the transformations you applied in your data processing.
5. List the validations you applied in your data processing.

### Python

1. Write Python code to get the 2nd highest number from a list without using sorted().
2. Explain all OOP concepts.
3. Explain the difference between multiple inheritance and multi-level inheritance.

### SQL

1. Write a query to get consecutive entries from the table (user_id, login_date).
2. Explain the difference between CTE and Recursive CTE.

### Spark

1. What are the types of join optimizations in Spark?
2. Explain broadcast join.
3. How is memory allocated when processing a 1 GB file (internal Spark memory allocation)?
4. What are the types of serialization in Spark?

### AWS

1. List the storage classes in AWS S3.
2. What are the limitations of AWS Lambda?
3. How can you trigger a Lambda function?
4. Explain AWS SNS.

### CI/CD Pipeline

1. Explain the CI/CD pipeline process.
2. What kind of scripts do we write to create a CI/CD pipeline?
3. If a git repository has multiple folders (e.g., SQL, AWS, EMR), how can we split a single repository into multiple deployment pipelines/images?

---

## Interview 111

**Group:** 

**Client Company:** 

**Topics:** Spark, Databricks, Python, Snowflake, SQL

---

### Spark

1. Spark is written using Scala. We write code using Python. How do Python, Spark, and Scala communicate internally?
2. Explain Broadcast Join.
3. While processing a 100MB file, we get an OOM error even after using a Broadcast Join. What could be the possible root causes?
4. What is data skew? How do we apply the salting technique?
5. A PySpark code reads a table, performs a few validations, and writes into the same table. We get a "table already in use" error. What could be the reason, and how can we fix it?
6. Explain cache and persist.
7. In a PySpark code, a cached DataFrame runs inside a loop, and we get a StackOverflow error. What could be the root cause, and how can we fix it?
8. List down the key benefits of AQE.

### Databricks

1. List the types of clusters.
2. There is a job that points to a notebook where the script accesses an Oracle DB. How are the ODBC/JDBC libraries/JARs configured or passed to the job at runtime in production?
3. Suppose a Databricks notebook connects to different source systems. How do we configure the connection details in Databricks?
4. How do you call a notebook from another notebook?
5. How is Spark memory allocation handled? Which library or engine manages memory internally in Spark?
6. Explain the Catalyst Optimizer.
7. What is constant folding?

### Python

1. How do we access AWS services from Python?
2. How do we process multiple tables in parallel? How is multithreading handled in Python?
3. Explain decorators.
4. How do we use a decorator for API retry?
5. How do we copy a large file from a source system to a data lake using Python?

### Snowflake

1. How do we create a table and load data into Snowflake from Databricks files (multiple files in a folder)?
2. What are the types of tables in Snowflake?
3. What are the disadvantages of a materialized view?
4. What is a dynamic table in Snowflake?

### SQL

1. List the window functions in SQL.
2. What is the difference between LEAD and LAG?

---

## Interview 112

**Group:** A4

**Client Company:** 

**Topics:** AWS, Redshift, DynamoDB, PySpark, Spark

---

### General / Project

- Explain your recent project.
- List the AWS services used in your recent project.
- What optimizations did you use in Redshift?
- How do you connect to the source system from Redshift?
- What is the maximum size of data handled on a daily basis?
- What is the difference between Redshift and DynamoDB?
- How did you schedule the jobs in your recent project?

### Spark Coding

Write PySpark code for the following:

```python
data = [
    (1, "2024-01-01 10:00", "login"),
    (1, "2024-01-01 10:05", "click"),
    (1, "2024-01-01 10:30", "logout"),
    (1, "2024-01-01 11:00", "login"),
    (1, "2024-01-01 11:10", "click"),
    (2, "2024-01-02 09:00", "login"),
    (2, "2024-01-02 09:45", "logout"),
]
schema = ['user_id', 'date_time', 'operation']
```

Expected output schema:
```text
["user_id", "start_time", "end_time", "operations", "duration"]
```

Sample output:
```text
1, 2024-01-01 10:00, 2024-01-01 10:30, 'login, click, logout', 30 mins
```

---

## Interview 113

**Group:** A3

**Client Company:** 

**Topics:** PySpark, AWS, SQL, Python

---

### General Questions

1. About my background with data engineering
2. Explain your most recent big data project end-to-end
3. What are the challenges you faced and how did you resolve them?

### Write SQL Query and PySpark Code to Solve the Problem

Find the best-selling product in each product category.
If there are two or more products with the same sales quantity, go by whichever product has the higher review rating.
Return the category name and product name in alphabetical order of the category.

```python
products_columns = ["product_id", "product_name", "category_name"]
products_data = [
    (3690, "Game of Thrones", "Books"),
    (5520, "Refrigerator", "Home Appliances"),
    (5952, "Dishwasher", "Home Appliances"),
    (3561, "IKGAI", "Books"),
    (8741, "Convertible Laptop", "Tech Gadgets"),
    (8154, "Gaming Keyboard", "Tech Gadgets"),
    (8963, "Ultra Slim Smartphone", "Tech Gadgets"),
    (5666, "Washing Machine", "Home Appliances"),
    (3300, "Ace the Data Science Interview", "Books"),
    (6078, "Kindle Oasis", "Amazon Kindle"),
    (6077, "Kindle Paperwhite", "Amazon Kindle"),
]

sales_columns = ["product_id", "sales_quantity", "rating"]
sales_data = [
    (3690, 300, 4.9),
    (5520, 70, 3.8),
    (5952, 70, 4.0),
    (3561, 290, 4.5),
    (3300, 450, 5.0),
    (6077, 126, 4.1),
    (6078, 230, 4.3),
    (8741, 40, 3.5),
    (8963, 190, 4.5),
    (5666, 30, 3.4),
    (8154, 190, 4.6),
]
```

### SQL Solution

```sql
WITH SALES AS (
    SELECT
        product_id,
        SUM(sales_quantity) AS total_sales,
        AVG(rating) AS avg_rating
    FROM sales_data
    GROUP BY product_id
),
best_selling AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category_name,
        RANK() OVER (PARTITION BY category_name ORDER BY total_sales DESC, avg_rating DESC) AS rnk
    FROM SALES s
    JOIN products_data p
        ON s.product_id = p.product_id
)
SELECT
    category_name,
    product_name
FROM best_selling
WHERE rnk = 1
ORDER BY
    category_name,
    product_name
```

### Convert to Spark Dataframe

`prd_df`, `sales_df`

```python
from pyspark.sql import functions as F
from pyspark.sql import Window

total_sales_df = sales_df.groupBy('product_id').agg(
    F.sum('sales_quantity').alias('total_sales'),
    F.avg('rating').alias('avg_rating'))

w = Window().partitionBy('category_name').orderBy(col('total_sales').desc(), col('avg_raitng').desc())

final_df = (
    total_sales_df
    .join(prd_df, how='inner', on='product_id')
    .withColumn('rnk', F.rank().over(w))
    .filter(col('rnk') == 1)
    .select(prd_df.category_name, prd_df.product_name)
    .orderBy(col(category_name), col(product_name))
)
```

### Python

Find the longest subsequence without repeating characters
string - 'aaabbcddddd' o/p a3b2c1d5

### Questions on Spark Architecture

- Broadcast join
- Need to broadcast smaller dataframes, shuffles
- Cloud technologies - SFTP, data transfer from cloud to cloud
- Spills - how to reduce spills due to large file sizes
- Any alternative for OPTIMIZE Command in native spark
- Handling spills in Native spark application
- EMR
- CI/CD concepts
- Kubernetes/Docker - What is the usage?

---

## Interview 114

**Group:** 

**Client Company:** 

**Topics:** PySpark, SQL, Python, ADF, Databricks, Unity Catalog

---

### SQL

Give me the rolling sum of trans_amt for 7 days for all dates from 2024-01-01 to 2025-12-31 -> 3 days before the trans date, current date and the following 3 days. Even if there is no date present, the result still should display the rolling sum for that date (taking into account that missing date has trans_amt of zero).

### Architecture Interview

- High-level architecture and design choice for ingesting 100+ sources into Databricks, tools and design requirements
- Incremental deployment & configuration settings used

---

## Interview 115

**Group:** A3-A4

**Client Company:** 

**Topics:** Snowflake, DBT

---

### Previous Exp

1. Explain your recent project and its end-to-end architecture.
2. What tools did you use to extract data from source systems?
3. Did you use built-in connectors/libraries or custom code for data extraction?
4. What types of source systems have you worked with in your data projects?

### dbt

1. Explain the dbt project folder structure.
2. If you need to implement SCD Type 2, which dbt feature would you use?
3. What are the strategies used in dbt incremental models?
4. How do you define and create a model in dbt?
5. How do you improve performance in dbt?
6. How do you perform data quality checks in dbt?
7. Where and how do you configure materialization (e.g., incremental) in dbt, block of code?
8. Which dbt environment you worked — dbt core, dbt cloud or hybrid?

### DevOps / Process

1. How do you implement CI/CD pipeline in dbt project?
2. During peer review, in what aspects do you check before promoting the code?

---
