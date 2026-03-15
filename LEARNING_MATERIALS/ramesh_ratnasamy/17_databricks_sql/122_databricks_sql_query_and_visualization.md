# Databricks SQL - Query & Visualization

## Introduction

Now let's look at how to work with queries and visualizations in Databricks SQL. Beyond just
running SQL queries, DBSQL provides a complete analytics workflow -- you can write queries,
visualize results as charts and graphs, combine visualizations into dashboards, and schedule
everything to refresh automatically. This is how analysts and data engineers deliver insights
to stakeholders without leaving the Databricks platform.

## The Query Lifecycle

```
Query Lifecycle in DBSQL:

  ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
  │  Write   │────▶│   Run    │────▶│Visualize │────▶│ Dashboard│
  │  Query   │     │  Query   │     │ Results  │     │ & Share  │
  └──────────┘     └──────────┘     └──────────┘     └──────────┘
       │                │                │                │
       │                │                │                │
  SQL Editor       SQL Warehouse    Chart builder    Dashboard
  + Schema         executes the    creates visual   combines
  browser          query           representations  multiple
                                                    visualizations
```

## Writing Queries

### Basic Query Workflow

```sql
-- Step 1: Explore available data using the schema browser
SHOW CATALOGS;
SHOW SCHEMAS IN production;
SHOW TABLES IN production.finance;
DESCRIBE TABLE production.finance.transactions;

-- Step 2: Write your query
SELECT
    DATE_TRUNC('month', transaction_date) AS month,
    region,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_transaction_value
FROM production.finance.transactions
WHERE transaction_date >= '2025-01-01'
GROUP BY 1, 2
ORDER BY month, region;

-- Step 3: Save the query (give it a name and optional description)
-- Done via UI: Save button → name your query
```

### Query Parameters

Parameters make queries reusable and interactive:

```sql
-- Parameters use double curly braces: {{ parameter_name }}
SELECT *
FROM production.finance.transactions
WHERE region = '{{ region }}'
  AND transaction_date BETWEEN '{{ start_date }}' AND '{{ end_date }}'
  AND amount >= {{ min_amount }};
```

```
Parameter Types:

┌─────────────────┬────────────────────────────────────────────┐
│ Type            │ Description                                │
├─────────────────┼────────────────────────────────────────────┤
│ Text            │ Free-form text input                       │
│ Number          │ Numeric input                              │
│ Date            │ Date picker widget                         │
│ Date Range      │ Start and end date pickers                 │
│ Dropdown List   │ Choose from predefined values              │
│ Query Based     │ Dropdown populated from another query      │
│                 │ (e.g., list of regions from a table)       │
└─────────────────┴────────────────────────────────────────────┘

Query-based dropdown example:
  Parameter "region" → populated by:
  SELECT DISTINCT region FROM production.finance.dim_regions ORDER BY region;

  User sees a dropdown: [US ▼]
                         US
                         EU
                         APAC
```

### Query Sharing and Permissions

```
Query Permissions:

- CAN VIEW       → See the query and results
- CAN RUN        → Execute the query
- CAN EDIT       → Modify the query
- IS OWNER       → Full control (delete, transfer ownership)

Sharing options:
- Share with specific users or groups
- Share with all users in the workspace (make "public")
- Queries can reference a specific SQL Warehouse
```

## Visualizations

After running a query, you can create visualizations from the results.

### Creating a Visualization

```
Steps to Create a Visualization:

1. Run your query → see results in a table
2. Click "+" next to "Results" tab → "Visualization"
3. Choose visualization type
4. Configure axes, series, formatting
5. Save the visualization

Each query can have MULTIPLE visualizations attached to it.
```

### Visualization Types

```
Available Visualization Types:

┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  📊 Bar Chart          │  📈 Line Chart                    │
│  Categorical           │  Trends over time                 │
│  comparisons           │  Time series data                 │
│                        │                                    │
│  🥧 Pie Chart          │  📉 Area Chart                    │
│  Part-to-whole         │  Cumulative trends                │
│  proportions           │  Stacked volumes                  │
│                        │                                    │
│  📊 Scatter Plot       │  📊 Histogram                     │
│  Correlation between   │  Distribution of                  │
│  two variables         │  values                           │
│                        │                                    │
│  🗺️ Map                │  📊 Pivot Table                   │
│  Geographic data       │  Cross-tabulation                 │
│  Choropleth, markers   │  of dimensions                    │
│                        │                                    │
│  📊 Counter            │  📊 Table                         │
│  Single KPI value      │  Formatted data                   │
│  Big number display    │  table view                       │
│                        │                                    │
│  📊 Funnel             │  📊 Cohort                        │
│  Conversion stages     │  Retention analysis               │
│                        │                                    │
│  📊 Box Plot           │  📊 Word Cloud                    │
│  Distribution stats    │  Text frequency                   │
│                        │                                    │
└─────────────────────────────────────────────────────────────┘
```

### Visualization Configuration

```
Configuration Options (example: Bar Chart):

┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  X Column:    [month ▼]           (horizontal axis)         │
│  Y Columns:  [total_revenue ▼]   (vertical axis - can add  │
│                                    multiple series)         │
│                                                             │
│  Group By:   [region ▼]          (creates grouped/stacked  │
│                                    bars)                    │
│                                                             │
│  Stacking:   ( ) None  (●) Stack  ( ) 100% Stack           │
│                                                             │
│  Formatting:                                                │
│    Y-Axis Label:  [Revenue (USD)]                           │
│    Number Format: [$0,0]                                    │
│    Legend:        [✓ Show]                                  │
│    Data Labels:   [ ] Show values on bars                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Dashboards

Dashboards combine multiple visualizations from different queries into a single view.

### Creating a Dashboard

```
Dashboard Workflow:

1. Create a new dashboard (SQL → Dashboards → Create)
2. Add visualizations from saved queries
3. Arrange and resize widgets
4. Add text widgets for context/headers
5. Configure filters (cross-filter across widgets)
6. Set up auto-refresh schedule
7. Share with stakeholders

Dashboard Components:
┌──────────────────────────────────────────────────────────┐
│                 Monthly Revenue Dashboard                │
│                                                          │
│  ┌──────────────────┐  ┌──────────────────────────────┐ │
│  │  Total Revenue   │  │  Revenue by Region           │ │
│  │                  │  │  ┌───┐ ┌───┐ ┌───┐           │ │
│  │  $2.4M           │  │  │US │ │EU │ │AP │           │ │
│  │  ▲ 12% vs LM     │  │  │   │ │   │ │   │           │ │
│  │  (Counter widget) │  │  └───┘ └───┘ └───┘           │ │
│  └──────────────────┘  │  (Bar chart)                  │ │
│                         └──────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────┐│
│  │  Revenue Trend Over Time                             ││
│  │  ────────/\───/\────                                 ││
│  │  ──────/────\─────\──                                ││
│  │  (Line chart)                                        ││
│  └──────────────────────────────────────────────────────┘│
│                                                          │
│  ┌──────────────────────────────────────────────────────┐│
│  │  Top Customers by Revenue                            ││
│  │  ┌──────────────┬───────────┬─────────────┐          ││
│  │  │ Customer     │ Revenue   │ Orders      │          ││
│  │  ├──────────────┼───────────┼─────────────┤          ││
│  │  │ Acme Corp    │ $450,000  │ 1,234       │          ││
│  │  │ ...          │ ...       │ ...         │          ││
│  │  └──────────────┴───────────┴─────────────┘          ││
│  │  (Table widget)                                      ││
│  └──────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────┘
```

### Dashboard Filters

```sql
-- Dashboard-level filters apply across all widgets
-- When a user selects "US" in the region filter,
-- ALL charts on the dashboard filter to US data

-- This works because all underlying queries use the same
-- parameter name (e.g., {{ region }})
```

### Dashboard Refresh

```
Refresh Options:

1. Manual Refresh
   → Click refresh button on the dashboard
   → Each widget re-runs its query

2. Scheduled Refresh
   → Set a schedule (e.g., every hour, daily at 8 AM)
   → All queries run automatically
   → Dashboard always shows fresh data

3. On Open
   → Dashboard refreshes when a user opens it

Schedule Configuration:
  ┌────────────────────────────────────────────┐
  │ Refresh Schedule:                          │
  │   Every: [1] [hour ▼]                     │
  │   SQL Warehouse: [prod_analytics_wh ▼]    │
  │   End: [Never ▼]                          │
  │                                            │
  │   Subscribers: [analytics-team@co.com]    │
  └────────────────────────────────────────────┘
```

### Dashboard Permissions

```
Dashboard Permissions:

- CAN VIEW       → See the dashboard and interact with filters
- CAN RUN        → Refresh the dashboard (re-run underlying queries)
- CAN EDIT       → Modify the dashboard layout and widgets
- IS OWNER       → Full control

Sharing:
  → Share with individuals, groups, or the entire workspace
  → Embedded dashboards can be shared via URL
```

## Query History and Profiling

DBSQL tracks all queries for auditing and performance analysis:

```
Query History Features:

┌─────────────────────────────────────────────────────────────┐
│ Query History                                               │
│                                                             │
│ ┌────────┬──────────┬──────────┬──────────┬───────────────┐ │
│ │ Status │ Query    │ Duration │ User     │ Warehouse     │ │
│ ├────────┼──────────┼──────────┼──────────┼───────────────┤ │
│ │ ✓      │ SELECT.. │ 2.3s     │ alice@   │ prod_wh       │ │
│ │ ✓      │ SELECT.. │ 15.1s    │ bob@     │ prod_wh       │ │
│ │ ✗      │ SELECT.. │ 0.5s     │ alice@   │ dev_wh        │ │
│ └────────┴──────────┴──────────┴──────────┴───────────────┘ │
│                                                             │
│ Query Profile (click into a query):                         │
│ - Execution plan (physical plan)                            │
│ - Time breakdown (parsing, planning, execution)             │
│ - Data read/written metrics                                 │
│ - Photon vs non-Photon execution                            │
│ - Spill to disk indicators                                  │
└─────────────────────────────────────────────────────────────┘
```

## Key Exam Points

1. **Queries can be parameterized** using `{{ parameter_name }}` syntax
2. **Parameters support multiple types**: text, number, date, date range, dropdown, query-based
   dropdown
3. **Each query can have multiple visualizations** attached to it
4. **Dashboards combine visualizations** from different queries into a single view
5. **Dashboard filters** can apply across all widgets using shared parameter names
6. **Dashboards support scheduled refresh** -- automatically re-run queries on a schedule
7. **Query history** tracks all executed queries with duration, user, and warehouse details
8. **Query profile** provides execution plan details for performance analysis
9. **Visualization types** include bar, line, pie, scatter, map, counter, pivot table, and more
10. **Sharing**: queries and dashboards can be shared with users, groups, or the workspace
    with role-based permissions (VIEW, RUN, EDIT, OWNER)
