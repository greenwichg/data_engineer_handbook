# Data Engineer Handbook

A comprehensive, curated collection of resources, cheatsheets, interview preparation materials, and deep-dive guides for data engineering professionals. Whether you're preparing for FAANG-level interviews or looking to strengthen your foundational knowledge, this handbook has you covered.

---

## Table of Contents

- [Overview](#overview)
- [Repository Structure](#repository-structure)
- [CHEATSHEETS](#cheatsheets)
- [CORE CONCEPTS](#core-concepts)
- [INTERVIEW PRACTICE](#interview-practice)
- [LEARNING MATERIALS](#learning-materials)
- [ROADMAPS AND PLANS](#roadmaps-and-plans)
- [SPARK DEEP DIVE](#spark-deep-dive)
- [SYSTEM DESIGN](#system-design)
- [How to Use This Repository](#how-to-use-this-repository)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

This repository serves as a one-stop reference for data engineers at all levels. It consolidates knowledge across the entire data engineering stack including SQL, PySpark, Python, Snowflake, Databricks, AWS services, system design, and more. The materials are sourced from industry experts, personal interview experiences, and hands-on practice.

---

## Repository Structure

```
data_engineer_handbook/
├── CHEATSHEETS/              # Quick-reference guides and pattern sheets
├── CORE_CONCEPTS/            # Foundational data engineering concepts
├── INTERVIEW_PRACTICE/       # Interview questions, experiences, and patterns
├── LEARNING_MATERIALS/       # Books, courses, and structured learning content
├── ROADMAPS_AND_PLANS/       # Career roadmaps and preparation strategies
├── SPARK_DEEP_DIVE/          # Apache Spark internals and performance tuning
├── SYSTEM_DESIGN/            # Data system design scenarios and solutions
└── README.md                 # This file
```

---

## CHEATSHEETS

Quick-reference guides organized by technology and topic.

### SQL
- **Cheatsheets & Guides** - SQL optimization series, window functions, execution order, pivot/unpivot, ACID properties, and more
- **SQL Patterns** - 20+ SQL pattern collections, CTE patterns, join patterns, time series patterns, and reusable query templates
- **Patterns Explained** - Detailed walkthroughs of balance calculation, gap-and-island, forward fill, recursive patterns, SCD Type II, and other advanced techniques
- **Top Interview Questions** - Curated sets of the most frequently asked SQL problems with solutions
- **Cross-Reference** - SQL to PySpark equivalents for bilingual fluency

### PySpark
- **Interview Patterns** - Common PySpark coding patterns for interviews
- **Implementations** - Production-grade examples including anomaly detection, JSON handling, multi-source joins, REST API integration, SQL Server to Snowflake migration, and CI/CD deployment guides

### Frameworks
- **Delta Lake** - Cheatsheets and use cases for Delta Lake operations
- **PySpark** - Comprehensive cheatsheets, JSON processing, cluster configuration, and use case sets
- **SQL** - SQL cheatsheets, frameworks, methodologies, and use case collections

### Other Technologies
- **Databricks** - Databricks overview and cheatsheets for data engineers
- **Snowflake** - Snowflake interview patterns and best practices
- **Python** - Python data types reference and coding patterns
- **Last Minute Revise** - Quick revision plans for interview day

---

## CORE CONCEPTS

Foundational knowledge every data engineer needs to master.

### Data Engineering Fundamentals
- Data organization design and platform architecture
- Data storage formats (Parquet, Delta Lake, ORC, Avro, and comparisons)
- Ingestion fundamentals and pipeline design
- DE prerequisites, fundamental skills, and industry trends
- Delta Lake vs Parquet deep comparison

### Data Modeling
- **Notes** - Data modeling frameworks, database normalization, grain concepts, star vs snowflake schema
- **Scenarios** - Real-world modeling exercises (food delivery, ride-hailing platforms)
- **Terminologies** - Cardinality, data contracts, normalization forms, late-arriving data, natural vs surrogate keys, slowly changing dimensions, grain definitions

### Data Loading
- **Historical/Backfill** - Strategies and Python implementations for backfilling historical data
- **Incremental** - Incremental loading patterns with practical examples

### Data Quality & Schema
- Data quality check frameworks with Python implementations
- Schema evolution strategies and AWS Glue schema versioning
- Production-ready quality validation examples

### Python Essentials
- Object-oriented programming concepts for data engineers
- Python ETL essentials and best practices

---

## INTERVIEW PRACTICE

Extensive interview preparation materials organized by topic and difficulty.

### Interview Experiences
- Real interview experiences from **Adobe**, **Netflix**, and **Walmart** with detailed breakdowns of questions asked and strategies used

### Interview Introduction
- Self-introduction frameworks and talking points
- DynamoDB experience narratives and project descriptions

### PySpark Questions (100+ Patterns)

#### Core Interview Patterns
Comprehensive collection of PySpark coding patterns covering:
- **Joins** - Anti join, semi join, null-safe joins, self joins, cross joins, multiway joins, broadcast joins
- **Window Functions** - Rank vs dense_rank vs row_number, lead/lag, cumulative sums, conditional windows, window frames, windowed deduplication
- **Aggregations** - Conditional aggregations, multi-level aggregation, collect_list/set, group concat, rollup/cube
- **Data Manipulation** - Pivot/unpivot, explode, nested JSON flattening, struct operations, regex, string parsing, date ranges
- **Advanced Patterns** - Gaps and islands, forward fill, graph shortest path, recursive parent-child, temporal validity, overlapping intervals, event pattern matching
- **Performance** - Broadcast hints, coalesce vs repartition, cache vs persist vs checkpoint, UDF vs native functions

#### Statistical & Analytical Patterns
- A/B testing, cohort retention, funnel analysis, churn detection
- Moving averages, running median, percentiles, outlier detection
- Customer lifetime value, market basket analysis, attribution modeling
- Financial calculations, inventory FIFO/LIFO, payroll tax brackets
- Time zone conversions, time-weighted averages, rate of change detection

#### Use Case Patterns
- **Pipeline Patterns** - Medallion architecture, CDC, incremental loads, backfill/reprocessing, streaming basics
- **Data Quality** - Data profiling, quality checks, reconciliation, schema evolution
- **Performance Tuning** - Data skew/salted joins, shuffle optimization, partition pruning, Z-ordering, small file problem, write optimization
- **SCD Implementations** - Type 1, Type 2, and Type 3 slowly changing dimensions
- **Operations** - Delta Lake merge, idempotent writes, dynamic partition overwrite, table maintenance (vacuum/optimize)
- **Architecture** - Data lake vs lakehouse, Spark on Kubernetes, Spark SQL vs DataFrame API, execution plan analysis

### Knowledge Gaps
- Resolved confusions on SQL execution order, JSON handling, LEFT vs RIGHT joins, performance comparisons, RDD vs DataFrame vs Dataset, SparkContext vs SparkSession

### Problem Solving
- Previous interview questions compilation
- Spark cluster capacity planning exercises

---

## LEARNING MATERIALS

Structured learning content from industry experts and educators.

### Ajay Kadiyala's Collection
- **Core Tech Stacks** - Interview kits for Apache Spark, PySpark, Kafka, Hadoop, HBase, Snowflake, dbt, Airflow, AWS, Azure, GCP, Python, SQL, and more
- **Career Development** - Behavioral interview preparation, resume building, take-home assignment guides
- **Case Studies** - Real-world project-based interview kits
- **System Design** - System design, cost/performance optimization, and data quality interview kits
- **Additional Resources** - Spark architecture textbooks, SQL guides, cloud platform materials
- **Programming Mindset** - "Think Like a Programmer" and problem-solving frameworks

### Ankita Gulati's Interview Collection
- **70+ Company Interview Experiences** - Detailed interview breakdowns from companies including:
  - **FAANG+** - Amazon, Apple, Google, Meta, Netflix
  - **Tech Giants** - Microsoft, LinkedIn, Uber, Stripe, Databricks, Confluent, Nvidia, Atlassian, Salesforce
  - **Finance** - Goldman Sachs, JPMorgan, Morgan Stanley, American Express, Mastercard, Visa, Barclays
  - **Consulting** - McKinsey, Deloitte, Accenture, EY, KPMG, PwC, Capgemini
  - **E-commerce & Retail** - Walmart, Flipkart, Myntra, Target, Wayfair, Shopee
  - **And many more** - Each with years of experience context (2-8 YOE)
- **Interview Preparation Plan** - Structured study plan for data engineering interviews

### Manjinder Brar
- Data Modeling for Data Engineers
- System Design for Data Engineers

### Nikolai Schuler's Snowflake Course
Complete hands-on Snowflake curriculum with SQL scripts covering:
- **Data Loading** - Stages, COPY command, transformations, file formats, copy options
- **Architecture** - Snowflake architecture deep dive
- **Unstructured Data** - JSON parsing, nested data handling, Parquet loading
- **Performance** - Dedicated warehouses, scaling out, caching, clustering
- **Cloud Integration** - Loading from AWS S3, Azure Blob, and GCP Cloud Storage
- **Snowpipe** - Automated data ingestion with error handling
- **Time Travel** - Data recovery, undrop operations, storage costs
- **Advanced Features** - Fail-safe, table types (permanent, transient, temporary), zero-copy cloning, data sharing, data sampling
- **Scheduling** - Tasks, CRON jobs, task trees, stored procedures
- **Streams** - CDC with INSERT/UPDATE/DELETE tracking, streams + tasks integration
- **Materialized Views** - Creation, refresh strategies, maintenance costs
- **Security** - Dynamic data masking policies, access management (ACCOUNTADMIN, SECURITYADMIN, SYSADMIN, custom roles)

### Ramesh Ratnasamy's Databricks Series
- Databricks Lakehouse and Medallion Architecture
- Databricks Workspace, Compute, and Cluster Configuration
- Unity Catalog and Hive Metastore
- Cloud Storage Access Configuration
- Spark Structured Streaming

---

## ROADMAPS AND PLANS

Career roadmaps and structured preparation plans from multiple experts.

| Contributor | Content |
|---|---|
| **Ankita Gulati** | Data engineering prep guide, 90-day roadmap |
| **Darshil Parmar** | DE interview game plan, data engineer roadmap |
| **Marcel Dybalski** | 1% daily DE habits for continuous improvement |
| **Piyush Goyal** | 30-day focused preparation roadmap |
| **Shubham Wadekar** | DE preparation and interview prep strategies |
| **Surbhi Walecha** | Databricks learning plan |
| **Trendy Tech Academy** | Ultimate Data Engineering Detailed Curriculum |
| **Vu Trinh (Substack)** | Data engineer roadmap |

### LinkedIn Learnings
Curated insights from the data engineering community:
- Depth over breadth approach to learning
- Getting hands dirty with practical projects
- DE portfolio project ideas
- Skill-up strategies and fundamentals-first philosophy
- Primary tech stack selection guide
- The data engineering iceberg concept

---

## SPARK DEEP DIVE

In-depth exploration of Apache Spark internals and performance optimization.

### Runtime Architecture
- **Spark Submit & Options** - Configuration parameters and deployment commands
- **Deploy Modes** - Client vs cluster mode, YARN, Kubernetes
- **Runtime Architecture** - Driver, executors, cluster manager interactions
- **Job/Stage/Task Model** - Jobs, stages, shuffles, tasks, and slots explained
- **SQL Engine & Query Planning** - Catalyst optimizer and query execution pipeline

### Performance Optimization
- **Memory Management** - Spark memory model, allocation strategies, on-heap vs off-heap
- **Adaptive Query Execution (AQE)** - Runtime optimization strategies
- **Dynamic Features** - Resource allocation, partition pruning, join optimization
- **Data Distribution** - Repartition vs coalesce, data skew handling in joins
- **Caching & Persistence** - When and how to cache data effectively
- **Advanced** - Broadcast variables, accumulators, speculative execution, scheduler deep dive, infrastructure tuning

### Spark 4 Features
- Overview of new features and improvements in Spark 4.x

### Resources
- Spark playground exercises and comprehensive Spark textbook

---

## SYSTEM DESIGN

Data engineering system design scenarios with detailed solutions.

### Data Ingestion Scenario
- End-to-end data ingestion pipeline design
- Component deep dives: AWS Step Functions, Lambda Functions, Glue (high-level and low-level APIs)

### Data Streaming Scenarios
- **Ride-Hailing System** - Real-time streaming architecture for ride-hailing platforms with interview scenario breakdowns
- **Banking System** - Real-time transaction processing and fraud detection streaming pipeline
- Reference architectures and design diagrams

---

## How to Use This Repository

### For Interview Preparation
1. **Start with a roadmap** - Pick a plan from `ROADMAPS_AND_PLANS/` that matches your timeline (30-day, 90-day, or continuous)
2. **Build foundations** - Study `CORE_CONCEPTS/` for data modeling, data loading, and quality patterns
3. **Practice coding** - Work through `INTERVIEW_PRACTICE/pyspark_questions/` patterns (100+ problems organized by category)
4. **Study SQL** - Use `CHEATSHEETS/` for SQL patterns, window functions, and optimization techniques
5. **Learn from others** - Read real interview experiences in `LEARNING_MATERIALS/ankita_gulati/` and `INTERVIEW_PRACTICE/interview_experiences/`
6. **Master system design** - Practice with scenarios in `SYSTEM_DESIGN/`
7. **Deep dive into Spark** - Study `SPARK_DEEP_DIVE/` for architecture and performance questions

### For Day-to-Day Reference
- Use `CHEATSHEETS/` as a quick-reference for SQL, PySpark, and Snowflake syntax
- Refer to `CORE_CONCEPTS/` for data modeling decisions and schema design
- Check `SPARK_DEEP_DIVE/performance/` for optimization techniques

### For Learning a New Technology
- **Snowflake** - Follow `LEARNING_MATERIALS/nikolai_schuler/snowflake_commands/` (22 sections, hands-on SQL)
- **Databricks** - Follow `LEARNING_MATERIALS/ramesh_ratnasamy/` (lakehouse, workspace, Unity Catalog, streaming)
- **Spark** - Start with `SPARK_DEEP_DIVE/run_time_architecture/` then move to `performance/`

---

## Contributing

Contributions are welcome! If you'd like to add resources:

1. Fork this repository
2. Add your content in the appropriate directory
3. Follow the existing naming conventions and file organization
4. Submit a pull request with a description of what you've added

---

## License

This repository is maintained for educational and interview preparation purposes.
