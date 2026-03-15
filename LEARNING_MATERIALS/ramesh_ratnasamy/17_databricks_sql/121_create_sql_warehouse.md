# Create SQL Warehouse

## Introduction

Now let's dive into SQL Warehouses -- the compute engine that powers Databricks SQL. A SQL
Warehouse is a managed cluster specifically optimized for running SQL queries against Delta
Lake tables. Unlike all-purpose clusters (which support notebooks, Spark jobs, and ML workloads),
SQL Warehouses are purpose-built for SQL analytics with features like auto-scaling, auto-suspend,
and the Photon engine for accelerated query performance.

Understanding SQL Warehouses is important for the exam because you need to know when to use
them, how to configure them, and how they differ from other compute types in Databricks.

## SQL Warehouse Types

Databricks offers three types of SQL Warehouses:

```
SQL Warehouse Types:

┌────────────────────────────────────────────────────────────────┐
│                     SERVERLESS                                 │
│                                                                │
│  - Fully managed by Databricks (no infrastructure to manage)  │
│  - Instant start-up (seconds, not minutes)                    │
│  - Auto-scales automatically                                   │
│  - Pay only for what you use                                   │
│  - Databricks manages the compute plane                        │
│  - Best for: most SQL workloads (recommended default)          │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                        PRO                                     │
│                                                                │
│  - Runs in your cloud account (customer-managed VPC)          │
│  - Start-up takes minutes (cluster provisioning)               │
│  - Auto-scales based on query load                             │
│  - Photon engine enabled                                       │
│  - Best for: workloads requiring network isolation              │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                      CLASSIC                                   │
│                                                                │
│  - Runs in your cloud account                                  │
│  - Basic SQL warehouse capabilities                            │
│  - Limited features compared to Pro                            │
│  - Being phased out in favor of Pro and Serverless             │
│  - Best for: legacy workloads                                  │
└────────────────────────────────────────────────────────────────┘
```

### Comparison

```
┌────────────────────────┬────────────┬──────────┬───────────┐
│ Feature                │ Serverless │ Pro      │ Classic   │
├────────────────────────┼────────────┼──────────┼───────────┤
│ Start-up time          │ Seconds    │ Minutes  │ Minutes   │
│ Infrastructure mgmt    │ Databricks │ Customer │ Customer  │
│ Auto-scaling           │ ✓          │ ✓        │ ✓         │
│ Photon engine          │ ✓          │ ✓        │ ✓         │
│ Intelligent workload   │ ✓          │ ✓        │           │
│ management             │            │          │           │
│ Network in your VPC    │            │ ✓        │ ✓         │
│ Cost model             │ Per-query  │ Per-hour │ Per-hour  │
└────────────────────────┴────────────┴──────────┴───────────┘
```

## Creating a SQL Warehouse

### Via the UI

```
Databricks UI: SQL Warehouses → Create SQL Warehouse

Configuration Options:
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  Name:           [production_analytics_wh]                   │
│                                                              │
│  Cluster Size:   [Medium ▼]                                  │
│                  (2X-Small, X-Small, Small, Medium,          │
│                   Large, X-Large, 2X-Large, 3X-Large,       │
│                   4X-Large)                                   │
│                                                              │
│  Auto Stop:      [✓] After [10] minutes of inactivity       │
│                                                              │
│  Scaling:        Min clusters: [1]  Max clusters: [8]        │
│                                                              │
│  Type:           (●) Serverless  ( ) Pro  ( ) Classic        │
│                                                              │
│  Tags:           [environment: production]                    │
│                                                              │
│  Advanced:                                                   │
│    Spot instances:        [✓ Use spot instances]             │
│    Unity Catalog:         [✓ Enabled]                        │
│    Channel:               [Current ▼]                        │
│                                                              │
│                    [ Create ]                                 │
└──────────────────────────────────────────────────────────────┘
```

### Via SQL

```sql
-- Create a SQL Warehouse using the API/CLI (not SQL syntax)
-- SQL Warehouses are typically created via UI or REST API
-- But you can manage them with Databricks CLI:
-- databricks warehouses create --json '{"name": "my_warehouse", ...}'
```

## Cluster Size and Scaling

### T-Shirt Sizing

SQL Warehouses use a T-shirt sizing model. Each size corresponds to a number of
Databricks SQL Compute Units (DBUs):

```
Cluster Sizes:

┌────────────┬──────────────────────────────────────────────┐
│ Size       │ Description                                  │
├────────────┼──────────────────────────────────────────────┤
│ 2X-Small   │ Smallest, for light workloads / development │
│ X-Small    │ Small queries, few concurrent users          │
│ Small      │ Moderate queries, several users              │
│ Medium     │ Standard production workloads                │
│ Large      │ Heavy queries, many concurrent users         │
│ X-Large    │ Complex queries, large datasets              │
│ 2X-Large   │ Very heavy workloads                         │
│ 3X-Large   │ Extreme workloads                            │
│ 4X-Large   │ Maximum capacity                             │
└────────────┴──────────────────────────────────────────────┘

Each step up approximately DOUBLES the compute capacity.
```

### Auto-Scaling (Multi-Cluster)

SQL Warehouses can scale horizontally by adding more clusters:

```
Auto-Scaling:

Low Load:                    High Load:
┌──────────┐                 ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Cluster 1│                 │ Cluster 1│ │ Cluster 2│ │ Cluster 3│
│ (active) │                 │ (active) │ │ (active) │ │ (active) │
└──────────┘                 └──────────┘ └──────────┘ └──────────┘
Min clusters: 1              Scaled up to handle more queries
Max clusters: 8              (each cluster handles independent queries)

How it works:
1. Queries arrive at the SQL Warehouse
2. If current clusters are busy, a new cluster is added
3. New cluster handles the overflow queries
4. When load decreases, extra clusters are removed
5. Each cluster is a full replica of the same size

This is HORIZONTAL scaling (more clusters of the same size),
not VERTICAL scaling (bigger clusters).
```

### Auto-Stop

```
Auto-Stop Behavior:

  Active    ──────────────────┐
                              │ Last query finishes
  Idle      ──────────────────┼─────────────────┐
                              │                 │ Auto-stop timer
  Stopped   ──────────────────┘─────────────────┼──▶ Warehouse stops
                                                │
                              ◄── idle timeout ─┤
                              (e.g., 10 minutes)

- Configurable idle timeout (default: 10 minutes for Pro/Classic)
- Serverless warehouses can stop in as little as minutes
- When stopped, no compute costs are incurred
- When a new query arrives, warehouse restarts automatically
  - Serverless: seconds to restart
  - Pro/Classic: minutes to restart
```

## Photon Engine

Photon is a native vectorized query engine written in C++ that accelerates SQL queries:

```
Photon Engine:

Traditional Spark SQL:
  Query → JVM-based Spark → Row-by-row processing → Result
                            (relatively slow)

With Photon:
  Query → Photon (C++) → Vectorized columnar processing → Result
                         (much faster, especially for:)
                         - Scans and filters
                         - Aggregations
                         - Joins
                         - String operations

Performance improvement: Often 2-8x faster for analytical queries

Photon is:
  ✓ Enabled by default on SQL Warehouses
  ✓ Compatible with Delta Lake
  ✓ Transparent (no code changes needed)
  ✓ Handles most SQL operations natively
```

## SQL Warehouse vs All-Purpose Cluster

```
┌─────────────────────────┬───────────────────┬──────────────────────┐
│ Feature                 │ SQL Warehouse     │ All-Purpose Cluster  │
├─────────────────────────┼───────────────────┼──────────────────────┤
│ Designed for            │ SQL queries       │ Notebooks, jobs, ML  │
│ Supports notebooks      │ No                │ Yes                  │
│ Supports Python/Scala   │ No (SQL only)     │ Yes                  │
│ Auto-scaling            │ Multi-cluster     │ Worker-based         │
│                         │ (horizontal)      │ (vertical)           │
│ Auto-stop               │ Yes               │ Yes                  │
│ Photon                  │ Always on         │ Optional             │
│ BI tool connectivity    │ Optimized         │ Possible but not     │
│                         │ (JDBC/ODBC)       │ optimized            │
│ Serverless option       │ Yes               │ Yes (Jobs only)      │
│ Unity Catalog enforced  │ Always            │ Depends on config    │
│ Cost optimization       │ Query-specific    │ General-purpose      │
│ Concurrent queries      │ Excellent (multi- │ Limited              │
│                         │ cluster scaling)  │                      │
└─────────────────────────┴───────────────────┴──────────────────────┘
```

## Access Control for SQL Warehouses

```sql
-- Grant permission to use a SQL Warehouse
-- (managed via UI or REST API, not SQL directly)

-- Permissions:
-- CAN USE        → Can run queries on the warehouse
-- CAN MANAGE     → Can configure and manage the warehouse
-- CAN MONITOR    → Can view warehouse status and metrics
-- IS OWNER       → Full control over the warehouse
```

```
Permission Hierarchy:

IS OWNER
  └── CAN MANAGE
       └── CAN MONITOR
            └── CAN USE (minimum permission to run queries)
```

## Query Routing and Queuing

```
Query Lifecycle on a SQL Warehouse:

  Query submitted
       │
       ▼
  ┌──────────────┐     ┌──────────────┐
  │ Query Queue  │────▶│ Cluster 1    │──▶ Result
  │              │     └──────────────┘
  │ (if all      │     ┌──────────────┐
  │  clusters    │────▶│ Cluster 2    │──▶ Result
  │  are busy)   │     └──────────────┘
  │              │     ┌──────────────┐
  │              │────▶│ Cluster 3    │──▶ Result
  └──────────────┘     └──────────────┘
                       (auto-scaled)

- Queries are routed to available clusters
- If all clusters are busy, queries are queued
- If queue grows, auto-scaling adds clusters (up to max)
- Each cluster handles queries independently
```

## Best Practices

```
SQL Warehouse Best Practices:

1. Use Serverless for most workloads
   → Fastest start-up, automatic scaling, lowest management overhead

2. Right-size your warehouse
   → Start small, scale up if queries are slow
   → Monitor query performance to find the right size

3. Set appropriate auto-stop
   → Development: 5-10 minutes
   → Production: 10-15 minutes (balance cost vs start-up time)

4. Use multi-cluster scaling for concurrent users
   → Set min=1, max based on peak concurrent users
   → Each cluster handles ~10 concurrent queries efficiently

5. Separate warehouses for different workloads
   → Interactive queries: smaller, fast start-up
   → Scheduled reports: larger, can tolerate start-up time
   → BI tool connections: dedicated, always-on or low auto-stop
```

## Key Exam Points

1. **Three SQL Warehouse types**: Serverless (recommended), Pro, Classic
2. **Serverless starts in seconds**; Pro/Classic take minutes
3. **Auto-scaling is horizontal** -- adds more clusters of the same size (multi-cluster)
4. **Auto-stop** shuts down the warehouse after an idle timeout to save costs
5. **T-shirt sizing** determines cluster capacity (2X-Small to 4X-Large)
6. **Photon engine** is always enabled on SQL Warehouses for accelerated query performance
7. **SQL Warehouses are SQL-only** -- they don't support notebooks or Python/Scala
8. **Unity Catalog is always enforced** on SQL Warehouses
9. **SQL Warehouses vs all-purpose clusters**: warehouses are optimized for SQL analytics
   with multi-cluster scaling; all-purpose clusters support all workloads
10. **Query queuing** handles overflow when all clusters are busy; auto-scaling adds
    capacity up to the configured maximum
