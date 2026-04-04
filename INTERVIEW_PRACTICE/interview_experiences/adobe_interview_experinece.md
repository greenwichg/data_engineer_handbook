# Adobe Data Engineering Interview

**CTC:** 42-50 LPA  
**Experience:** 4+ years

Questions asked in Round 1 & Round 2

## Round 1: Data Engineering Fundamentals + Spark + SQL

This round focuses on your core data engineering foundations and hands-on experience.

1) Explain your end-to-end data pipeline for handling large-scale user interaction data (clicks, events, logs).

2) What is the difference between a Data Lake, Lakehouse, and Data Warehouse? Which one fits Adobe-scale analytics and why?

3) Explain batch vs streaming pipelines with a real example from product or marketing analytics.

4) How do you optimize Spark jobs at scale? (partitioning, caching, shuffle tuning, join optimization)

5) Explain different Spark join strategies (broadcast, sort-merge, shuffle hash). When would each cause performance issues?

6) What is the difference between Hive managed and external tables? How does it impact cost, recovery, and governance?

7) How would you implement Slowly Changing Dimensions (SCD Type 1 & Type 2) for customer data?

8) What data quality checks do you implement before exposing data to analytics teams?

9) How would you design a query to calculate user session duration, drop-off funnels, and daily active users from raw event logs?

## Round 2: System Design + Streaming + Platform Architecture

This round focuses on large-scale thinking, reliability, and production-grade design.

1) How would you design a data platform to support real-time analytics for millions of users globally?

2) How do you manage schema evolution when upstream teams frequently add or modify fields?

3) How do you handle late-arriving, duplicate, or out-of-order events in streaming systems?

4) What is exactly-once vs at-least-once processing? How do you ensure idempotency in production pipelines?

5) How do you decide between Kafka, Kinesis, and Pub/Sub for large-scale event ingestion?

6) How do you ensure pipeline reliability, monitoring, and alerting in production environments?