# PySpark Implementation: Complex Ranking Scenarios

## Problem Statement
Given sales transactions by product category, produce a summary that shows the **top 5
categories by total revenue**, groups every remaining category into an **"Other" bucket**,
and includes each row's **percentage of the grand total**. Additionally, apply Olympic-style
medal ranking (gold = 3 pts, silver = 2 pts, bronze = 1 pt) to rank regions by weighted
medal count, handling ties with a custom tie-breaking rule.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("ComplexRanking").getOrCreate()

# --- Dataset 1: Category Sales ---
sales_data = [
    ("Electronics", 520000), ("Clothing", 310000), ("Groceries", 290000),
    ("Furniture", 185000), ("Toys", 150000), ("Books", 95000),
    ("Sports", 88000), ("Beauty", 72000), ("Automotive", 61000),
    ("Garden", 45000),
]
sales_df = spark.createDataFrame(sales_data, ["category", "revenue"])

# --- Dataset 2: Olympic Medals ---
medal_data = [
    ("CountryA", "gold"), ("CountryA", "gold"), ("CountryA", "silver"),
    ("CountryB", "gold"), ("CountryB", "silver"), ("CountryB", "silver"),
    ("CountryB", "bronze"),
    ("CountryC", "gold"), ("CountryC", "bronze"), ("CountryC", "bronze"),
    ("CountryD", "silver"), ("CountryD", "bronze"),
    ("CountryE", "gold"), ("CountryE", "gold"), ("CountryE", "silver"),
    ("CountryE", "bronze"),
]
medals_df = spark.createDataFrame(medal_data, ["country", "medal"])
```

### Expected Output -- Top N with "Other"
| category    | revenue | pct_of_total | rank |
|-------------|---------|--------------|------|
| Electronics | 520000  | 28.59        | 1    |
| Clothing    | 310000  | 17.04        | 2    |
| Groceries   | 290000  | 15.94        | 3    |
| Furniture   | 185000  | 10.17        | 4    |
| Toys        | 150000  | 8.25         | 5    |
| Other       | 361000  | 19.84        | 6    |

### Expected Output -- Medal Ranking
| country  | gold | silver | bronze | weighted_score | rank |
|----------|------|--------|--------|----------------|------|
| CountryE | 2    | 1      | 1      | 9              | 1    |
| CountryA | 2    | 1      | 0      | 8              | 2    |
| CountryB | 1    | 2      | 1      | 8              | 2    |
| CountryC | 1    | 0      | 2      | 5              | 4    |
| CountryD | 0    | 1      | 1      | 3              | 5    |

---

## Method 1: Window-Based Top-N with "Other" Bucket (Recommended)
```python
# Step 1 -- Rank categories by revenue
w = Window.orderBy(F.desc("revenue"))
ranked = sales_df.withColumn("rn", F.row_number().over(w))

# Step 2 -- Label: keep original name for top 5, replace rest with "Other"
labeled = ranked.withColumn(
    "display_category",
    F.when(F.col("rn") <= 5, F.col("category")).otherwise(F.lit("Other"))
)

# Step 3 -- Aggregate: sum revenue within each display_category
grouped = labeled.groupBy("display_category").agg(
    F.sum("revenue").alias("revenue")
)

# Step 4 -- Compute percentage of grand total
grand_total = sales_df.agg(F.sum("revenue")).collect()[0][0]

result = grouped.withColumn(
    "pct_of_total",
    F.round(F.col("revenue") / F.lit(grand_total) * 100, 2)
)

# Step 5 -- Final ordering: top categories first, "Other" last
result = result.withColumn(
    "rank",
    F.row_number().over(Window.orderBy(
        F.when(F.col("display_category") == "Other", 1).otherwise(0),
        F.desc("revenue")
    ))
).orderBy("rank")

result.show(truncate=False)
```

### Step-by-Step Explanation

**Step 1 -- After row_number (ranked):**
| category    | revenue | rn |
|-------------|---------|-----|
| Electronics | 520000  | 1   |
| Clothing    | 310000  | 2   |
| Groceries   | 290000  | 3   |
| Furniture   | 185000  | 4   |
| Toys        | 150000  | 5   |
| Books       | 95000   | 6   |
| Sports      | 88000   | 7   |
| Beauty      | 72000   | 8   |
| Automotive  | 61000   | 9   |
| Garden      | 45000   | 10  |

**Step 2 -- After labeling (labeled):**
| category    | revenue | rn | display_category |
|-------------|---------|-----|------------------|
| Electronics | 520000  | 1   | Electronics      |
| Books       | 95000   | 6   | Other            |
| Sports      | 88000   | 7   | Other            |
| ...         | ...     | ... | Other            |

**Step 3 -- After groupBy (grouped):**
| display_category | revenue |
|------------------|---------|
| Electronics      | 520000  |
| Clothing         | 310000  |
| Other            | 361000  |
| ...              | ...     |

**Step 4 -- Grand total = 1,816,000. Percentages computed.**

**Step 5 -- Final result sorted with "Other" last (see Expected Output above).**

---

## Method 2: Olympic Medal-Style Weighted Ranking with Ties
```python
# Step 1 -- Pivot medals into columns
medal_counts = medals_df.groupBy("country").pivot("medal", ["gold", "silver", "bronze"]).count()
medal_counts = medal_counts.na.fill(0)

# Step 2 -- Compute weighted score: gold=3, silver=2, bronze=1
scored = medal_counts.withColumn(
    "weighted_score",
    F.col("gold") * 3 + F.col("silver") * 2 + F.col("bronze") * 1
)

# Step 3 -- Rank with dense_rank to allow ties
#   Tie-breaking: same weighted_score -> same rank (Olympic convention)
#   Secondary sort by gold count descending for display order
w_rank = Window.orderBy(F.desc("weighted_score"))
result_medals = scored.withColumn("rank", F.dense_rank().over(w_rank))

result_medals = result_medals.orderBy("rank", F.desc("gold"))
result_medals.show()
```

### Intermediate Steps for Medal Ranking

**After pivot (medal_counts):**
| country  | gold | silver | bronze |
|----------|------|--------|--------|
| CountryA | 2    | 1      | 0      |
| CountryB | 1    | 2      | 1      |
| CountryC | 1    | 0      | 2      |
| CountryD | 0    | 1      | 1      |
| CountryE | 2    | 1      | 1      |

**After weighted_score:**
| country  | gold | silver | bronze | weighted_score |
|----------|------|--------|--------|----------------|
| CountryE | 2    | 1      | 1      | 9              |
| CountryA | 2    | 1      | 0      | 8              |
| CountryB | 1    | 2      | 1      | 8              |
| CountryC | 1    | 0      | 2      | 5              |
| CountryD | 0    | 1      | 1      | 3              |

**After dense_rank -- CountryA and CountryB share rank 2 (tied at 8 points).**

---

## Bonus: Custom Tie-Breaking (Gold Count, then Silver Count)
```python
w_tiebreak = Window.orderBy(
    F.desc("weighted_score"),
    F.desc("gold"),
    F.desc("silver")
)
scored_tiebreak = scored.withColumn("strict_rank", F.row_number().over(w_tiebreak))
scored_tiebreak.orderBy("strict_rank").show()
```
| country  | gold | silver | bronze | weighted_score | strict_rank |
|----------|------|--------|--------|----------------|-------------|
| CountryE | 2    | 1      | 1      | 9              | 1           |
| CountryA | 2    | 1      | 0      | 8              | 2           |
| CountryB | 1    | 2      | 1      | 8              | 3           |
| CountryC | 1    | 0      | 2      | 5              | 4           |
| CountryD | 0    | 1      | 1      | 3              | 5           |

---

## Key Interview Talking Points
1. **row_number vs. rank vs. dense_rank** -- `row_number` never produces ties, `rank` leaves gaps after ties (1,2,2,4), `dense_rank` does not leave gaps (1,2,2,3). Choose based on business rules.
2. **"Other" bucket pattern** -- Label rows beyond the top N before aggregating so the groupBy naturally collapses them. This avoids a separate union.
3. **pivot with explicit values** -- Always pass the list of expected values to `pivot()` to avoid an extra pass over the data to discover distinct values.
4. **Grand total via collect** -- Using `.collect()[0][0]` for a scalar is fine when the aggregation returns exactly one row. Alternatively use a window without partition to compute grand total inline.
5. **Ordering "Other" last** -- A `F.when` expression inside `orderBy` is cleaner than adding a separate sort-key column.
6. **Weighted scoring is just a linear combination** -- Expressing it as column arithmetic keeps the computation in the JVM and avoids UDFs.
7. **Percentage formatting** -- `F.round(..., 2)` keeps numeric precision; cast to string with `F.format_number` only at the presentation layer.
