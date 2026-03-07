# PySpark Implementation: Inventory FIFO/LIFO Valuation

## Problem Statement

Inventory valuation using FIFO (First In, First Out) and LIFO (Last In, First Out) is a classic problem in financial and supply chain data engineering. FIFO assumes the oldest inventory is sold first, while LIFO assumes the newest inventory is sold first. Implementing these algorithms in PySpark requires careful use of window functions and cumulative logic. This is a challenging interview topic that tests both domain knowledge and advanced PySpark skills.

Given purchase and sales records for products, compute the cost of goods sold (COGS) and remaining inventory value using both FIFO and LIFO methods.

### Sample Data

**Purchases (inventory received):**
```
+----------+----------+-----+------------+
|product_id|purchase_dt| qty | unit_cost  |
+----------+----------+-----+------------+
| P001     |2024-01-01| 100 |  10.00     |
| P001     |2024-01-15|  50 |  12.00     |
| P001     |2024-02-01|  80 |  11.00     |
| P001     |2024-02-15|  60 |  13.00     |
+----------+----------+-----+------------+
```

**Sales (inventory sold):**
```
+----------+----------+-----+
|product_id| sale_dt  | qty |
+----------+----------+-----+
| P001     |2024-01-20| 120 |
| P001     |2024-02-10|  50 |
+----------+----------+-----+
```

### Expected Output

**FIFO COGS for sale on 2024-01-20 (qty=120):**

| source_purchase | qty_used | unit_cost | layer_cost |
|-----------------|----------|-----------|------------|
| 2024-01-01      | 100      | 10.00     | 1000.00    |
| 2024-01-15      | 20       | 12.00     | 240.00     |
| **Total COGS**  | **120**  |           | **1240.00**|

---

## Method 1: FIFO Inventory Valuation

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("InventoryFIFOLIFO") \
    .master("local[*]") \
    .getOrCreate()

# Purchase records
purchases_data = [
    ("P001", "2024-01-01", 100, 10.00),
    ("P001", "2024-01-15",  50, 12.00),
    ("P001", "2024-02-01",  80, 11.00),
    ("P001", "2024-02-15",  60, 13.00),
]
purchases = spark.createDataFrame(purchases_data,
    ["product_id", "purchase_dt", "qty", "unit_cost"])

# Sales records
sales_data = [
    ("P001", "2024-01-20", 120),
    ("P001", "2024-02-10",  50),
]
sales = spark.createDataFrame(sales_data,
    ["product_id", "sale_dt", "qty"])

# ============================================================
# FIFO: Process purchases from oldest to newest
# ============================================================

# Step 1: Add cumulative purchased qty (ordered by purchase date)
w_fifo = Window.partitionBy("product_id").orderBy("purchase_dt") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

purchases_cum = purchases \
    .withColumn("cum_qty", F.sum("qty").over(w_fifo)) \
    .withColumn("prev_cum_qty", F.col("cum_qty") - F.col("qty"))

print("=== Purchase Layers with Cumulative Qty ===")
purchases_cum.show()

# Step 2: Add cumulative sold qty
w_sales = Window.partitionBy("product_id").orderBy("sale_dt") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

sales_cum = sales \
    .withColumn("cum_sold", F.sum("qty").over(w_sales)) \
    .withColumn("prev_cum_sold", F.col("cum_sold") - F.col("qty"))

print("=== Sales with Cumulative Qty ===")
sales_cum.show()

# Step 3: Match sales to purchase layers using FIFO
# For each sale, determine how much comes from each purchase layer
fifo_match = sales_cum.join(purchases_cum, "product_id")

# A purchase layer contributes to a sale if:
# - The layer's cumulative range overlaps with the sale's cumulative range
fifo_match = fifo_match.withColumn("overlap_start",
    F.greatest(F.col("prev_cum_qty"), F.col("prev_cum_sold"))
).withColumn("overlap_end",
    F.least(F.col("cum_qty"), F.col("cum_sold"))
).withColumn("qty_used",
    F.greatest(F.col("overlap_end") - F.col("overlap_start"), F.lit(0))
).filter(F.col("qty_used") > 0)

fifo_match = fifo_match.withColumn("layer_cost",
    F.col("qty_used") * F.col("unit_cost")
)

print("=== FIFO: Sale-to-Purchase Layer Matching ===")
fifo_match.select(
    "product_id", "sale_dt", "purchase_dt",
    "qty_used", "unit_cost", "layer_cost"
).orderBy("sale_dt", "purchase_dt").show()

# FIFO COGS per sale
fifo_cogs = fifo_match.groupBy("product_id", "sale_dt").agg(
    F.sum("qty_used").alias("total_qty"),
    F.sum("layer_cost").alias("cogs"),
    F.round(F.sum("layer_cost") / F.sum("qty_used"), 2).alias("avg_unit_cost"),
)

print("=== FIFO COGS per Sale ===")
fifo_cogs.show()
```

## Method 2: LIFO Inventory Valuation

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("LIFOValuation") \
    .master("local[*]") \
    .getOrCreate()

purchases_data = [
    ("P001", "2024-01-01", 100, 10.00),
    ("P001", "2024-01-15",  50, 12.00),
    ("P001", "2024-02-01",  80, 11.00),
    ("P001", "2024-02-15",  60, 13.00),
]
purchases = spark.createDataFrame(purchases_data,
    ["product_id", "purchase_dt", "qty", "unit_cost"])

sales_data = [
    ("P001", "2024-01-20", 120),
    ("P001", "2024-02-10",  50),
]
sales = spark.createDataFrame(sales_data,
    ["product_id", "sale_dt", "qty"])

# ============================================================
# LIFO: Process purchases from newest to oldest
# ============================================================

# For LIFO, we only consider purchases that occurred BEFORE or ON the sale date
# Then we consume from newest purchase first

# Step 1: Cross join sales with eligible purchases
lifo_pairs = sales.join(purchases,
    (sales.product_id == purchases.product_id) &
    (purchases.purchase_dt <= sales.sale_dt),
    "inner"
).select(
    sales.product_id,
    sales.sale_dt,
    sales.qty.alias("sale_qty"),
    purchases.purchase_dt,
    purchases.qty.alias("purchase_qty"),
    purchases.unit_cost,
)

# Step 2: Order purchases newest-first within each sale
w_lifo = Window.partitionBy("product_id", "sale_dt") \
    .orderBy(F.col("purchase_dt").desc()) \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

lifo_pairs = lifo_pairs \
    .withColumn("cum_available", F.sum("purchase_qty").over(w_lifo)) \
    .withColumn("prev_cum", F.col("cum_available") - F.col("purchase_qty"))

# Step 3: Compute how much of each layer is consumed
lifo_result = lifo_pairs.withColumn("qty_used",
    F.greatest(
        F.least(F.col("cum_available"), F.col("sale_qty")) - F.col("prev_cum"),
        F.lit(0)
    )
).filter(F.col("qty_used") > 0)

lifo_result = lifo_result.withColumn("layer_cost",
    F.col("qty_used") * F.col("unit_cost")
)

print("=== LIFO: Sale-to-Purchase Layer Matching ===")
lifo_result.select(
    "product_id", "sale_dt", "purchase_dt",
    "qty_used", "unit_cost", "layer_cost"
).orderBy("sale_dt", F.col("purchase_dt").desc()).show()

# LIFO COGS per sale
lifo_cogs = lifo_result.groupBy("product_id", "sale_dt").agg(
    F.sum("qty_used").alias("total_qty"),
    F.sum("layer_cost").alias("cogs"),
    F.round(F.sum("layer_cost") / F.sum("qty_used"), 2).alias("avg_unit_cost"),
)

print("=== LIFO COGS per Sale ===")
lifo_cogs.show()
```

## Method 3: FIFO vs LIFO Comparison with Remaining Inventory

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("FIFOvsLIFOComparison") \
    .master("local[*]") \
    .getOrCreate()

purchases_data = [
    ("P001", "2024-01-01", 100, 10.00),
    ("P001", "2024-01-15",  50, 12.00),
    ("P001", "2024-02-01",  80, 11.00),
    ("P001", "2024-02-15",  60, 13.00),
]
purchases = spark.createDataFrame(purchases_data,
    ["product_id", "purchase_dt", "qty", "unit_cost"])

total_sold = 170  # total units sold across all sales

# ============================================================
# FIFO remaining inventory
# ============================================================
# Under FIFO, the oldest items are sold first
# So remaining inventory = newest layers

w = Window.partitionBy("product_id").orderBy("purchase_dt") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

fifo_remaining = purchases \
    .withColumn("cum_qty", F.sum("qty").over(w)) \
    .withColumn("remaining",
        F.greatest(F.col("cum_qty") - F.lit(total_sold), F.lit(0))
    ) \
    .withColumn("prev_remaining",
        F.greatest(F.col("cum_qty") - F.col("qty") - F.lit(total_sold), F.lit(0))
    ) \
    .withColumn("remaining_in_layer",
        F.col("remaining") - F.col("prev_remaining")
    ) \
    .filter(F.col("remaining_in_layer") > 0) \
    .withColumn("layer_value", F.col("remaining_in_layer") * F.col("unit_cost"))

print("=== FIFO Remaining Inventory ===")
fifo_remaining.select("product_id", "purchase_dt", "unit_cost",
                      "remaining_in_layer", "layer_value").show()

fifo_total = fifo_remaining.agg(
    F.sum("remaining_in_layer").alias("total_units"),
    F.sum("layer_value").alias("total_value"),
).collect()[0]
print(f"FIFO: {fifo_total['total_units']} units, ${fifo_total['total_value']:.2f}")

# ============================================================
# LIFO remaining inventory
# ============================================================
# Under LIFO, the newest items are sold first
# So remaining inventory = oldest layers

w_lifo = Window.partitionBy("product_id").orderBy(F.col("purchase_dt").desc()) \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

lifo_remaining = purchases \
    .withColumn("cum_qty_rev", F.sum("qty").over(w_lifo)) \
    .withColumn("remaining",
        F.greatest(F.col("cum_qty_rev") - F.lit(total_sold), F.lit(0))
    ) \
    .withColumn("prev_remaining",
        F.greatest(F.col("cum_qty_rev") - F.col("qty") - F.lit(total_sold), F.lit(0))
    ) \
    .withColumn("remaining_in_layer",
        F.col("remaining") - F.col("prev_remaining")
    ) \
    .filter(F.col("remaining_in_layer") > 0) \
    .withColumn("layer_value", F.col("remaining_in_layer") * F.col("unit_cost"))

print("=== LIFO Remaining Inventory ===")
lifo_remaining.select("product_id", "purchase_dt", "unit_cost",
                      "remaining_in_layer", "layer_value").show()

lifo_total = lifo_remaining.agg(
    F.sum("remaining_in_layer").alias("total_units"),
    F.sum("layer_value").alias("total_value"),
).collect()[0]
print(f"LIFO: {lifo_total['total_units']} units, ${lifo_total['total_value']:.2f}")

# ============================================================
# Summary comparison
# ============================================================
comparison = spark.createDataFrame([
    ("FIFO", int(fifo_total['total_units']), float(fifo_total['total_value'])),
    ("LIFO", int(lifo_total['total_units']), float(lifo_total['total_value'])),
], ["method", "remaining_units", "inventory_value"])

print("=== FIFO vs LIFO Comparison ===")
comparison.show()
```

## Key Concepts

| Concept | FIFO | LIFO |
|---------|------|------|
| **Sell order** | Oldest inventory first | Newest inventory first |
| **Remaining inventory** | Newest purchase layers | Oldest purchase layers |
| **Rising prices** | Lower COGS, higher profit | Higher COGS, lower profit |
| **Falling prices** | Higher COGS, lower profit | Lower COGS, higher profit |
| **Tax implication** | Higher taxable income (rising prices) | Lower taxable income (rising prices) |
| **GAAP/IFRS** | Allowed under both | Not allowed under IFRS |

## Interview Tips

1. **Understand the overlap technique**: The key insight for FIFO/LIFO in PySpark is computing cumulative quantities for both purchases and sales, then calculating the overlap between ranges. This avoids row-by-row iteration.

2. **Handle sequential sales**: When multiple sales occur, each sale consumes from the remaining inventory after previous sales. Use cumulative sold quantities to track the consumption watermark.

3. **Weighted average cost**: A simpler alternative is weighted average cost (WAC), where COGS = total cost / total units. This avoids layer tracking entirely.

4. **Scale considerations**: For large inventory systems, consider partitioning by product and date. The cross-join approach works for moderate data sizes but may need optimization for millions of SKUs.

5. **Edge cases to mention**: Overselling (selling more than available), returns (adding inventory back), and purchase cancellations. Discuss how your solution handles negative remaining quantities.
