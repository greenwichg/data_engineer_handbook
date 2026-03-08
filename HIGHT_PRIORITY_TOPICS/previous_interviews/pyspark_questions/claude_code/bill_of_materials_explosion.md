# PySpark Implementation: Bill of Materials (BOM) Explosion

## Problem Statement
Given a multi-level Bill of Materials where each product is composed of sub-components (which may themselves have sub-components), "explode" the BOM to calculate the total quantity of each raw material needed to produce one unit of the final product. This is a common manufacturing/supply chain interview problem that tests recursive/iterative thinking in PySpark.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("BOMExplosion").getOrCreate()

# parent_part → child_part with quantity required
bom_data = [
    ("Bicycle", "Frame", 1),
    ("Bicycle", "Wheel", 2),
    ("Bicycle", "Chain", 1),
    ("Frame", "Steel Tube", 3),
    ("Frame", "Welding Rod", 5),
    ("Wheel", "Rim", 1),
    ("Wheel", "Spoke", 36),
    ("Wheel", "Tire", 1),
    ("Rim", "Aluminum Sheet", 1),
    ("Tire", "Rubber Compound", 2),
]

columns = ["parent_part", "child_part", "quantity"]
bom = spark.createDataFrame(bom_data, columns)
bom.show(truncate=False)
```

```
+-----------+---------------+--------+
|parent_part|child_part     |quantity|
+-----------+---------------+--------+
|Bicycle    |Frame          |1       |
|Bicycle    |Wheel          |2       |
|Bicycle    |Chain          |1       |
|Frame      |Steel Tube     |3       |
|Frame      |Welding Rod    |5       |
|Wheel      |Rim            |1       |
|Wheel      |Spoke          |36      |
|Wheel      |Tire           |1       |
|Rim        |Aluminum Sheet |1       |
|Tire       |Rubber Compound|2       |
+-----------+---------------+--------+
```

### BOM Tree Structure
```
Bicycle (1)
├── Frame (1)
│   ├── Steel Tube (3)
│   └── Welding Rod (5)
├── Wheel (2)
│   ├── Rim (1)
│   │   └── Aluminum Sheet (1)
│   ├── Spoke (36)
│   └── Tire (1)
│       └── Rubber Compound (2)
└── Chain (1)
```

### Expected Output (Total raw materials for 1 Bicycle)
```
+---------------+--------------+
|raw_material   |total_quantity|
+---------------+--------------+
|Aluminum Sheet |2             |
|Chain          |1             |
|Rubber Compound|4             |
|Spoke          |72            |
|Steel Tube     |3             |
|Welding Rod    |5             |
+---------------+--------------+
```
- Spoke: 2 Wheels × 36 Spokes = 72
- Rubber Compound: 2 Wheels × 1 Tire × 2 Rubber = 4
- Aluminum Sheet: 2 Wheels × 1 Rim × 1 Aluminum Sheet = 2

---

## Method 1: Iterative Self-Join with Quantity Multiplication (Recommended)

```python
# Step 1: Start with top-level product's direct children
top_product = "Bicycle"

current_level = bom.filter(F.col("parent_part") == top_product).select(
    F.col("child_part").alias("part"),
    F.col("quantity").alias("total_qty"),
)

# Identify which parts are themselves parents (have children)
parent_parts = bom.select("parent_part").distinct()

# Separate raw materials (leaf nodes) from sub-assemblies
all_results = spark.createDataFrame([], "part STRING, total_qty INT")

# Step 2: Iteratively expand sub-assemblies
max_depth = 10  # safety limit
for i in range(max_depth):
    # Split current level into raw materials (no children) and sub-assemblies (have children)
    raw_materials = current_level.join(
        parent_parts,
        current_level.part == parent_parts.parent_part,
        how="left_anti",
    )
    all_results = all_results.union(raw_materials)

    sub_assemblies = current_level.join(
        parent_parts,
        current_level.part == parent_parts.parent_part,
        how="left_semi",
    )

    if sub_assemblies.count() == 0:
        break

    # Expand sub-assemblies: join with BOM and multiply quantities
    current_level = (
        sub_assemblies.join(
            bom,
            sub_assemblies.part == bom.parent_part,
            how="inner",
        )
        .select(
            F.col("child_part").alias("part"),
            (F.col("total_qty") * F.col("quantity")).alias("total_qty"),
        )
    )

# Step 3: Aggregate raw materials (same material may appear through different paths)
result = all_results.groupBy("part").agg(
    F.sum("total_qty").alias("total_quantity")
).withColumnRenamed("part", "raw_material")

result.orderBy("raw_material").show(truncate=False)
```

### Step-by-Step Explanation

#### Iteration 1: Expand Bicycle's direct children
- **Current level:** Frame(1), Wheel(2), Chain(1)
- **Raw materials found:** Chain(1) — it has no children in BOM
- **Sub-assemblies to expand:** Frame(1), Wheel(2)

#### Iteration 2: Expand Frame and Wheel
- Frame(1) → Steel Tube(1×3=3), Welding Rod(1×5=5)
- Wheel(2) → Rim(2×1=2), Spoke(2×36=72), Tire(2×1=2)
- **Raw materials found:** Steel Tube(3), Welding Rod(5), Spoke(72)
- **Sub-assemblies to expand:** Rim(2), Tire(2)

#### Iteration 3: Expand Rim and Tire
- Rim(2) → Aluminum Sheet(2×1=2)
- Tire(2) → Rubber Compound(2×2=4)
- **Raw materials found:** Aluminum Sheet(2), Rubber Compound(4)
- **Sub-assemblies to expand:** None → loop ends

#### Final aggregation
- All raw materials collected and summed.

---

## Method 2: Recursive CTE (Spark 3.4+)

```python
bom.createOrReplaceTempView("bom")

result_sql = spark.sql("""
    WITH RECURSIVE exploded AS (
        -- Base case: direct children of Bicycle
        SELECT
            child_part AS part,
            quantity AS total_qty
        FROM bom
        WHERE parent_part = 'Bicycle'

        UNION ALL

        -- Recursive case: expand sub-assemblies
        SELECT
            b.child_part AS part,
            e.total_qty * b.quantity AS total_qty
        FROM exploded e
        JOIN bom b ON e.part = b.parent_part
    )
    -- Only keep leaf nodes (parts that are never a parent)
    SELECT
        part AS raw_material,
        SUM(total_qty) AS total_quantity
    FROM exploded
    WHERE part NOT IN (SELECT DISTINCT parent_part FROM bom)
    GROUP BY part
    ORDER BY part
""")
result_sql.show(truncate=False)
```

---

## Variation: Full BOM Explosion with Path

```python
# Track the full assembly path for traceability
current_level = bom.filter(F.col("parent_part") == top_product).select(
    F.col("child_part").alias("part"),
    F.col("quantity").alias("total_qty"),
    F.concat(F.lit("Bicycle > "), F.col("child_part")).alias("path"),
    F.lit(1).alias("level"),
)

all_with_path = current_level

for i in range(10):
    sub_assemblies = current_level.join(
        parent_parts,
        current_level.part == parent_parts.parent_part,
        how="left_semi",
    )

    if sub_assemblies.count() == 0:
        break

    current_level = (
        sub_assemblies.join(bom, sub_assemblies.part == bom.parent_part, how="inner")
        .select(
            F.col("child_part").alias("part"),
            (F.col("total_qty") * F.col("quantity")).alias("total_qty"),
            F.concat(F.col("path"), F.lit(" > "), F.col("child_part")).alias("path"),
            (F.col("level") + 1).alias("level"),
        )
    )
    all_with_path = all_with_path.union(current_level)

all_with_path.orderBy("path").show(truncate=False)
```

**Output:**
```
+---------------+---------+----------------------------------------+-----+
|part           |total_qty|path                                    |level|
+---------------+---------+----------------------------------------+-----+
|Chain          |1        |Bicycle > Chain                         |1    |
|Frame          |1        |Bicycle > Frame                         |1    |
|Steel Tube     |3        |Bicycle > Frame > Steel Tube            |2    |
|Welding Rod    |5        |Bicycle > Frame > Welding Rod           |2    |
|Wheel          |2        |Bicycle > Wheel                         |1    |
|Rim            |2        |Bicycle > Wheel > Rim                   |2    |
|Aluminum Sheet |2        |Bicycle > Wheel > Rim > Aluminum Sheet  |3    |
|Spoke          |72       |Bicycle > Wheel > Spoke                 |2    |
|Tire           |2        |Bicycle > Wheel > Tire                  |2    |
|Rubber Compound|4        |Bicycle > Wheel > Tire > Rubber Compound|3    |
+---------------+---------+----------------------------------------+-----+
```

---

## Variation: Cost Roll-Up

```python
# Add unit costs to raw materials and calculate total cost
cost_data = [
    ("Steel Tube", 5.00),
    ("Welding Rod", 0.50),
    ("Spoke", 0.25),
    ("Aluminum Sheet", 15.00),
    ("Rubber Compound", 3.00),
    ("Chain", 12.00),
]

costs = spark.createDataFrame(cost_data, ["material", "unit_cost"])

total_cost = (
    result.join(costs, result.raw_material == costs.material, how="inner")
    .withColumn("line_cost", F.col("total_quantity") * F.col("unit_cost"))
    .select("raw_material", "total_quantity", "unit_cost", "line_cost")
)
total_cost.show(truncate=False)

# Total cost to produce one Bicycle
total_cost.agg(F.sum("line_cost").alias("total_bicycle_cost")).show()
```

---

## Comparison of Methods

| Method | Spark Version | Handles Cycles? | Traceability |
|--------|---------------|-----------------|--------------|
| Iterative self-join | All versions | Yes (max_depth limit) | Can add path tracking |
| Recursive CTE | 3.4+ | No — infinite loop risk | Harder to add path |

## Key Interview Talking Points

1. **Quantity multiplication across levels** is the key insight. Each level multiplies the parent's cumulative quantity by the child's per-unit quantity.
2. **Leaf node detection:** Raw materials are parts that never appear as a `parent_part` in the BOM. Use `left_anti` join to identify them.
3. **Cycle detection:** In real-world BOMs, circular references (A→B→A) can exist due to data errors. The `max_depth` limit prevents infinite loops.
4. **Performance:** Each iteration requires a join + count. For deep BOMs (10+ levels), consider caching intermediate results.
5. **Real-world extensions:** Cost roll-up, lead time calculation, where-used analysis (reverse BOM — "which products use this raw material?").
6. This pattern is used in: manufacturing (ERP systems), recipe management, software dependency trees, and organizational budgeting.
