# Netflix Data Engineering Interview Experience

**CTC:** ₹30-31 LPA  
**Experience:** 4+ years

---

## Round 1 – Technical

1. Write a SQL query to identify the top 10 users with the most watch hours in the last month.

2. Given a click-stream dataset (user_id, session_id, show_id, event_timestamp, event_type like play/pause/stop), how would you compute per-session duration by device type?

3. Explain batch vs stream processing in the context of a video-streaming platform.

4. How would you optimize a Spark job that is suffering from data skew and excessive shuffle?

5. Design a data model for storing user watch-history at scale for global users, and explain your choice of schema design.

---

## Round 2 – Technical (Advanced)

1. You're ingesting real-time viewing events from millions of devices globally into your data lakehouse. How would you design the pipeline (ingest → transform → serve) to support near-real-time analytics?

2. A nightly job that used to finish in 45 minutes suddenly takes 3 hours — outline your approach to root-cause analysis.

3. How do you ensure data quality and monitor pipelines in a streaming + batch architecture (including drift, late data, duplicate handling)?

4. How would you manage schema evolution in a data warehouse used by multiple analytics teams?

5. Describe a large-scale ETL you worked on and explain how you improved performance or reduced cost.

6. Design an end-to-end architecture for user-watch-history and recommendation feed, including ingestion, storage, and reporting layers.

---

## Round 3 – Managerial / Behavioral

1. Share a project where you improved a data pipeline's performance — what metrics did you track and what impact did it have?

2. How do you handle conflicts when business teams demand faster delivery while the engineering team focuses on pipeline stability?

3. Describe a situation where you had to deliver under tight deadlines, such as before a major product launch — how did you manage scope and priorities?

4. How do you ensure data quality, reliability, and observability in a production environment handling petabytes of data?