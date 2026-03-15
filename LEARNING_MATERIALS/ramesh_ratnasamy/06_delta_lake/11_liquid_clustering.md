# Liquid Clustering

## Introduction

Alright, let's talk about Liquid Clustering -- this is a relatively new feature in Delta Lake and
it's a game changer for how we think about data layout optimization. If you've been following along,
you know about ZORDER for data co-location. Liquid Clustering takes that concept and makes it much
more flexible and easier to manage.

The core problem that Liquid Clustering solves is this: traditional partitioning and ZORDER are
rigid. Once you partition a table by a column, changing the partition scheme requires rewriting the
entire table. Similarly, ZORDER requires you to run OPTIMIZE explicitly, and you have to choose your
ZORDER columns upfront. Liquid Clustering eliminates these rigidities. You can change your clustering
columns at any time, and clustering is applied incrementally -- no full table rewrites needed.

## The Problem with Traditional Approaches

```
+====================================================================+
|      TRADITIONAL DATA LAYOUT CHALLENGES                            |
+====================================================================+
|                                                                    |
|  PARTITIONING                         ZORDER                      |
|  ─────────────                        ──────                      |
|                                                                    |
|  - Changing partition columns          - Must run OPTIMIZE         |
|    requires FULL TABLE REWRITE          explicitly                  |
|  - Over-partitioning creates           - Can't change ZORDER      |
|    small files                           columns without full      |
|  - Under-partitioning gives              re-ZORDER                 |
|    poor query pruning                  - Effectiveness decreases   |
|  - Must choose partition key             with more columns         |
|    at table creation time              - Not applied to new data   |
|  - Can't easily adapt to                automatically              |
|    changing query patterns                                         |
|                                                                    |
+====================================================================+
```

## What is Liquid Clustering?

Liquid Clustering is Delta Lake's next-generation data layout optimization technique. It
automatically organizes data within a table to co-locate related rows, similar to ZORDER,
but with key advantages:

1. **Flexible**: You can change clustering columns at any time without rewriting data
2. **Incremental**: Clustering is applied incrementally on new and changed data
3. **Automatic**: Works with OPTIMIZE without needing to specify ZORDER columns
4. **Adaptive**: The clustering adapts as your data grows and query patterns evolve

### Enabling Liquid Clustering

```sql
-- Create a table with Liquid Clustering
CREATE TABLE sales (
    order_id INT,
    customer_id INT,
    product_category STRING,
    amount DOUBLE,
    order_date DATE
)
CLUSTER BY (customer_id, product_category);
```

The key syntax is `CLUSTER BY` -- this replaces both PARTITIONED BY and ZORDER BY.

### Enabling on an Existing Table

```sql
-- Add clustering to an existing unpartitioned table
ALTER TABLE sales CLUSTER BY (customer_id, product_category);

-- Change clustering columns (no full rewrite needed!)
ALTER TABLE sales CLUSTER BY (order_date, customer_id);

-- Remove clustering
ALTER TABLE sales CLUSTER BY NONE;
```

## How Liquid Clustering Works

```
Liquid Clustering Data Flow:

+-------------------------------------------+
|  1. New data arrives (INSERT/MERGE/etc.)  |
|     - Data is written normally            |
|     - Files are NOT clustered yet         |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  2. OPTIMIZE is run                       |
|     - Identifies unclustered files        |
|     - Reads and re-organizes data using   |
|       Hilbert space-filling curve         |
|     - Writes new clustered files          |
|     - Only processes NEW/CHANGED data     |
|       (incremental, not full rewrite)     |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  3. Clustered data on disk                |
|     - Related rows are co-located         |
|     - Tight min/max statistics per file   |
|     - Enables efficient data skipping     |
+-------------------------------------------+
```

### Hilbert Space-Filling Curve

Liquid Clustering uses a **Hilbert space-filling curve** instead of the Z-order curve used by
ZORDER. The Hilbert curve provides better multi-dimensional data locality, meaning:

- More consistent data skipping across all clustering columns
- Better performance when filtering on any combination of clustering columns
- More even distribution of data across files

```
Z-Order Curve vs Hilbert Curve (2D visualization):

Z-Order:                    Hilbert:
+---+---+---+---+          +---+---+---+---+
| 1 | 2 | 5 | 6 |          | 1 | 2 | 3 | 4 |
+---+---+---+---+          +---+---+---+---+
| 3 | 4 | 7 | 8 |          | 8 | 7 | 6 | 5 |
+---+---+---+---+          +---+---+---+---+
| 9 |10 |13 |14 |          | 9 |10 |11 |12 |
+---+---+---+---+          +---+---+---+---+
|11 |12 |15 |16 |          |16 |15 |14 |13 |
+---+---+---+---+          +---+---+---+---+

Hilbert has better locality: consecutive
numbers are always adjacent (no jumps).
```

## Liquid Clustering vs Partitioning vs ZORDER

| Feature | Partitioning | ZORDER | Liquid Clustering |
|---------|-------------|--------|-------------------|
| **Data layout** | Separate directories | Co-located within files | Co-located within files |
| **Change columns** | Full rewrite required | Full re-ZORDER | ALTER TABLE (incremental) |
| **Applied when** | At write time | During OPTIMIZE | During OPTIMIZE |
| **Best cardinality** | Low (< 1000 values) | High | Any |
| **Multiple columns** | Can cause small files | Effectiveness decreases | Consistent across all |
| **Syntax** | PARTITIONED BY | OPTIMIZE ... ZORDER BY | CLUSTER BY |
| **Incremental** | N/A | No (re-ZORDERs all) | Yes (only new data) |
| **Algorithm** | Directory-based | Z-order curve | Hilbert curve |

## When to Use Liquid Clustering

### Use Liquid Clustering When:

- You're creating a **new table** (recommended default for new tables)
- Your table is **not currently partitioned**, or partitioning is causing small files
- You need to **change clustering columns** over time as query patterns evolve
- You want simpler maintenance (no need to specify ZORDER columns every time)
- You have **high-cardinality columns** that are poor partition keys but good for filtering

### Do NOT Use Liquid Clustering When:

- Your table is already well-partitioned with large, well-sized partitions (1+ GB each)
- You need to use `PARTITIONED BY` for specific requirements (e.g., partition-level operations
  in external systems)

### Key Restrictions

- A table **cannot** use both PARTITIONED BY and CLUSTER BY at the same time
- Liquid Clustering tables do not support `ZORDER BY` in OPTIMIZE
- Clustering is applied during OPTIMIZE, not at write time

## Running OPTIMIZE on Clustered Tables

```sql
-- For Liquid Clustered tables, just run OPTIMIZE without ZORDER
-- The clustering columns are already defined on the table
OPTIMIZE sales;

-- You can still target specific data with a WHERE clause
OPTIMIZE sales WHERE order_date >= '2025-01-01';
```

When you run OPTIMIZE on a Liquid Clustered table, it:
1. Identifies files that haven't been clustered yet (newly written data)
2. Applies the Hilbert curve clustering on the defined columns
3. Writes new clustered files and updates the transaction log

This incremental approach means OPTIMIZE only needs to process new data, not the entire table.

## PySpark Usage

```python
# Create a table with Liquid Clustering using PySpark
df.write.format("delta") \
    .clusterBy("customer_id", "product_category") \
    .saveAsTable("sales")

# Optimize a clustered table
spark.sql("OPTIMIZE sales")
```

---

## CONCEPT GAP: Migration from Partitioning to Liquid Clustering

Migrating from a partitioned table to a Liquid Clustered table requires careful planning:

**Option 1: Create new table with CTAS**
```sql
-- Create a new clustered table from the partitioned one
CREATE OR REPLACE TABLE sales_v2
CLUSTER BY (region, order_date)
AS SELECT * FROM sales;

-- Run OPTIMIZE to apply clustering
OPTIMIZE sales_v2;
```

**Option 2: Use Deep Clone**
```sql
-- Clone the table and apply clustering
CREATE TABLE sales_v2 DEEP CLONE sales;
ALTER TABLE sales_v2 CLUSTER BY (region, order_date);
OPTIMIZE sales_v2;
```

**Important**: You cannot simply ALTER an existing partitioned table to add CLUSTER BY. The table
must be unpartitioned first, which effectively means creating a new table.

The general recommendation from Databricks is:
- **New tables**: Use Liquid Clustering by default
- **Existing partitioned tables**: Keep partitioning if it's working well; migrate only if you're
  experiencing small files problems or need to change the layout frequently

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is Liquid Clustering in Delta Lake?
**A:** Liquid Clustering is Delta Lake's next-generation data layout optimization that automatically co-locates related data within files using a Hilbert space-filling curve. It replaces both traditional partitioning and ZORDER with a more flexible approach where clustering columns can be changed at any time without rewriting the entire table, and clustering is applied incrementally.

### Q2: How is Liquid Clustering different from ZORDER?
**A:** Liquid Clustering uses a Hilbert curve (better multi-dimensional locality than Z-order curve), applies clustering incrementally (only new data, not full table), allows changing clustering columns with a simple ALTER TABLE (no full re-ZORDER), and doesn't require specifying columns with each OPTIMIZE run. ZORDER requires explicit column specification each time and reprocesses all data.

### Q3: Can you use Liquid Clustering and partitioning together?
**A:** No, a table cannot use both PARTITIONED BY and CLUSTER BY simultaneously. They are mutually exclusive data layout strategies. If you want to migrate from partitioning to Liquid Clustering, you need to create a new table with CLUSTER BY and copy the data.

### Q4: How do you enable Liquid Clustering on a table?
**A:** For new tables, use `CREATE TABLE ... CLUSTER BY (col1, col2)`. For existing unpartitioned tables, use `ALTER TABLE table_name CLUSTER BY (col1, col2)`. To change clustering columns, use the same ALTER TABLE command with different columns. To remove clustering, use `ALTER TABLE table_name CLUSTER BY NONE`.

### Q5: When should you use Liquid Clustering vs traditional partitioning?
**A:** Use Liquid Clustering for new tables (it's the recommended default), tables with high-cardinality filter columns, when query patterns change over time, or when partitioning creates small files. Keep traditional partitioning if it's already working well with large well-sized partitions (1+ GB each) and you don't need to change the partition scheme.

### Q6: What is the Hilbert space-filling curve and why is it better than Z-order?
**A:** The Hilbert curve is a mathematical curve that maps multi-dimensional data to a single dimension while preserving locality. It's better than the Z-order curve because consecutive points along the Hilbert curve are always spatially adjacent (no jumps), providing more consistent data skipping across all clustering columns and better performance when filtering on any combination of columns.

### Q7: Is Liquid Clustering applied at write time or during OPTIMIZE?
**A:** Liquid Clustering is applied during OPTIMIZE, not at write time. New data is written normally without clustering. When OPTIMIZE runs, it identifies unclustered files, applies the Hilbert curve clustering on the defined columns, and writes new clustered files. This is incremental -- only new and changed data is processed.

---
