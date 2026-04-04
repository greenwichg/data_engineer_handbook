# Complete Guide: Handling Nested JSON in Apache Spark

## Table of Contents
1. [Understanding the Problem](#understanding-the-problem)
2. [Approach 1: Explode and Flatten](#approach-1-explode-and-flatten)
3. [Approach 2: Array Functions](#approach-2-array-functions)
4. [Approach 3: Pivoting Nested Data](#approach-3-pivoting-nested-data)
5. [Approach 4: Higher-Order Functions](#approach-4-higher-order-functions)
6. [Joining Strategy](#joining-strategy)
7. [Performance Considerations](#performance-considerations)
8. [Best Practices](#best-practices)

---

## Understanding the Problem

### Sample Nested JSON Structure

```json
{
  "player_id": "P001",
  "player_name": "Virat Kohli",
  "skills": [
    {"skill_name": "Batting", "skill_level": 95},
    {"skill_name": "Fielding", "skill_level": 85}
  ],
  "contact": {
    "email": "virat@example.com",
    "phone": "+91-9876543210"
  }
}
```

### Challenges
1. **Nested Structs**: `contact.email`, `contact.phone`
2. **Arrays of Structs**: `skills[]` containing multiple objects
3. **Variable Array Sizes**: Different players have different number of skills
4. **Null Handling**: Some players might not have certain nested fields

---

## Approach 1: Explode and Flatten

### When to Use
- When you need to analyze **individual array elements**
- When array elements need to be treated as separate entities
- For one-to-many relationships (one player → many skills)

### Implementation

```python
from pyspark.sql.functions import col, explode, explode_outer

# Basic explode - fails on null/empty arrays
players_exploded = df.select(
    col("player_id"),
    col("player_name"),
    explode("skills").alias("skill")
)

# Explode outer - handles null/empty arrays gracefully
players_exploded = df.select(
    col("player_id"),
    col("player_name"),
    explode_outer("skills").alias("skill")
)

# Further flatten the struct
players_flattened = players_exploded.select(
    col("player_id"),
    col("player_name"),
    col("skill.skill_name").alias("skill_name"),
    col("skill.skill_level").alias("skill_level")
)
```

### Result Example

| player_id | player_name | skill_name | skill_level |
|-----------|-------------|------------|-------------|
| P001      | Virat Kohli | Batting    | 95          |
| P001      | Virat Kohli | Fielding   | 85          |
| P002      | Rohit Sharma| Batting    | 92          |
| P002      | Rohit Sharma| Fielding   | 80          |

### Pros & Cons

**Pros:**
- Simple and intuitive
- Easy to aggregate and analyze individual skills
- Standard SQL-like operations

**Cons:**
- Multiplies row count (data explosion)
- Increases shuffle size in joins
- Not suitable when you need to keep player as single row

---

## Approach 2: Array Functions

### When to Use
- When you want to **keep player as single row**
- When you need to query/filter based on array contents
- When array size is reasonable

### Implementation

```python
from pyspark.sql.functions import (
    array_contains, filter as array_filter, 
    transform, size, exists
)

# Keep skills as array
players_with_array = df.select(
    col("player_id"),
    col("player_name"),
    col("skills")
)

# Filter: Players with Batting skill
players_with_batting = players_with_array.filter(
    array_contains(col("skills.skill_name"), "Batting")
)

# Get size of array
players_with_array = players_with_array.withColumn(
    "skill_count",
    size(col("skills"))
)

# Check if any skill level > 90
from pyspark.sql.functions import exists
players_expert = players_with_array.filter(
    exists(col("skills"), lambda x: x.skill_level > 90)
)

# Get max skill level
from pyspark.sql.functions import aggregate
players_with_max = players_with_array.withColumn(
    "max_skill_level",
    aggregate(
        col("skills"),
        lit(0),
        lambda acc, x: when(x.skill_level > acc, x.skill_level).otherwise(acc)
    )
)
```

### Pros & Cons

**Pros:**
- Maintains row-level integrity (one row per player)
- More efficient for certain queries
- Good for filtering and existence checks

**Cons:**
- Limited aggregation capabilities
- Complex syntax for nested operations
- Not suitable for detailed skill-level analysis

---

## Approach 3: Pivoting Nested Data

### When to Use
- When array has **fixed, known elements**
- When you want column-based access
- For ML feature engineering (fixed feature set)

### Implementation

```python
from pyspark.sql.functions import expr

# Create separate columns for each skill
players_pivoted = df.select(
    col("player_id"),
    col("player_name"),
    # Filter array and extract first element's skill_level
    expr("filter(skills, x -> x.skill_name = 'Batting')[0].skill_level").alias("batting_skill"),
    expr("filter(skills, x -> x.skill_name = 'Bowling')[0].skill_level").alias("bowling_skill"),
    expr("filter(skills, x -> x.skill_name = 'Fielding')[0].skill_level").alias("fielding_skill")
)
```

### Result Example

| player_id | player_name | batting_skill | bowling_skill | fielding_skill |
|-----------|-------------|---------------|---------------|----------------|
| P001      | Virat Kohli | 95            | null          | 85             |
| P002      | Rohit Sharma| 92            | null          | 80             |
| P003      | Bumrah      | null          | 98            | 75             |

### Alternative: Using map_from_arrays

```python
from pyspark.sql.functions import map_from_arrays

# Convert array of structs to map
players_with_map = df.select(
    col("player_id"),
    col("player_name"),
    map_from_arrays(
        col("skills.skill_name"),
        col("skills.skill_level")
    ).alias("skills_map")
)

# Access specific skill
players_with_map = players_with_map.withColumn(
    "batting_skill",
    col("skills_map")["Batting"]
)
```

### Pros & Cons

**Pros:**
- Column-based access (easier for ML)
- Efficient for fixed schema
- Good for comparison across skills

**Cons:**
- Requires knowing all possible array elements in advance
- Not scalable for dynamic/unknown array elements
- Lots of null values if arrays vary significantly

---

## Approach 4: Higher-Order Functions

### When to Use
- For **complex transformations** on arrays
- When you need to apply functions to each array element
- For conditional operations within arrays

### Key Functions

```python
from pyspark.sql.functions import transform, filter as array_filter, aggregate

# TRANSFORM - Apply function to each array element
df_transformed = df.select(
    col("player_id"),
    transform(
        col("skills"),
        lambda x: struct(
            x.skill_name.alias("name"),
            (x.skill_level * 1.1).alias("boosted_level")  # Boost all skills by 10%
        )
    ).alias("boosted_skills")
)

# FILTER - Keep only certain array elements
df_filtered = df.select(
    col("player_id"),
    array_filter(
        col("skills"),
        lambda x: x.skill_level >= 90  # Only keep skills >= 90
    ).alias("expert_skills")
)

# AGGREGATE - Reduce array to single value
df_aggregated = df.select(
    col("player_id"),
    aggregate(
        col("skills"),
        lit(0),  # initial value
        lambda acc, x: acc + x.skill_level,  # accumulator function
        lambda acc: acc  # finish function
    ).alias("total_skill_points")
)

# EXISTS - Check if condition is true for any element
df_with_expert = df.filter(
    exists(col("skills"), lambda x: x.skill_level > 95)
)

# FORALL - Check if condition is true for all elements
df_all_proficient = df.filter(
    forall(col("skills"), lambda x: x.skill_level >= 70)
)
```

### Complex Example: Multi-level Nesting

```python
# Suppose skills have sub-skills
# skills: [
#   {
#     "skill_name": "Batting",
#     "sub_skills": [
#       {"type": "Cover Drive", "rating": 95},
#       {"type": "Pull Shot", "rating": 90}
#     ]
#   }
# ]

# Flatten multi-level nesting
df_multi_level = df.select(
    col("player_id"),
    transform(
        col("skills"),
        lambda skill: transform(
            skill.sub_skills,
            lambda sub: struct(
                skill.skill_name.alias("main_skill"),
                sub.type.alias("sub_skill"),
                sub.rating.alias("rating")
            )
        )
    ).alias("nested_transform")
)

# Flatten the result (array of arrays → single array)
from pyspark.sql.functions import flatten
df_flattened = df_multi_level.select(
    col("player_id"),
    flatten(col("nested_transform")).alias("all_sub_skills")
)
```

---

## Joining Strategy

### Schema Design for Analytics

```
Facts Table (Scores) → Central table with metrics
  ├─ Dimension: Players (one-to-many with skills)
  ├─ Dimension: Teams (one-to-many with matches)
  └─ Dimension: Matches (context for scores)
```

### Best Join Approach

```python
# 1. Start with fact table (scores)
analytics_df = scores_df

# 2. Join with base dimensions (without explosions)
# Use base player table (one row per player)
analytics_df = analytics_df.join(
    players_base,  # NOT players_exploded
    on="player_id",
    how="left"
)

# 3. Join with matches
analytics_df = analytics_df.join(
    matches_df,
    on="match_id",
    how="left"
)

# 4. Join with teams
analytics_df = analytics_df.join(
    teams_df,
    analytics_df.team_id == teams_df.team_id,
    how="left"
).drop(teams_df.team_id)  # Avoid duplicate column
```

### Join Optimization

```python
# Broadcast small dimensions
from pyspark.sql.functions import broadcast

analytics_df = scores_df.join(
    broadcast(players_base),  # Broadcast if < 10MB
    on="player_id",
    how="left"
)

# Bucketing for large-scale joins
players_base.write \
    .bucketBy(10, "player_id") \
    .sortBy("player_id") \
    .saveAsTable("players_bucketed")

scores_df.write \
    .bucketBy(10, "player_id") \
    .sortBy("player_id") \
    .saveAsTable("scores_bucketed")

# Join bucketed tables (no shuffle!)
spark.sql("""
    SELECT * 
    FROM scores_bucketed s
    JOIN players_bucketed p ON s.player_id = p.player_id
""")
```

### Handling Multiple Array Dimensions

If you need both player skills and team performance arrays:

```python
# Approach A: Create two separate views
# 1. Player-Skill level (exploded)
player_skills_view = players_df.select(...).explode("skills")

# 2. Player-Team level (not exploded)
player_team_view = players_df.join(teams_df)

# Approach B: Use window functions to denormalize
from pyspark.sql.window import Window
from pyspark.sql.functions import collect_list

# Aggregate skills back after analysis
player_agg = player_skills_exploded.groupBy("player_id").agg(
    collect_list(
        struct("skill_name", "skill_level")
    ).alias("skills")
)
```

---

## Performance Considerations

### Data Explosion Problem

```python
# Before explode: 1,000 players
# After explode: 5,000 rows (avg 5 skills per player)
# After join: 5,000 * 10 matches = 50,000 rows

# Problem: Shuffle size increases dramatically
```

### Solution 1: Explode After Join (When Possible)

```python
# BAD: Explode early, then join
players_exploded = df.explode("skills")  # 5,000 rows
result = players_exploded.join(scores_df)  # Large shuffle

# GOOD: Join first, explode later (if analytics allows)
joined = players_df.join(scores_df)  # 1,000 rows
result = joined.explode("skills")  # Explode after join
```

### Solution 2: Filter Before Explode

```python
# Filter to reduce data before explosion
players_filtered = players_df.filter(col("role") == "Batsman")
players_exploded = players_filtered.explode("skills")
```

### Solution 3: Use Aggregate Instead of Explode

```python
# Instead of exploding to analyze
players_exploded = df.explode("skills")
max_skill = players_exploded.groupBy("player_id").agg(max("skill_level"))

# Use higher-order function
max_skill = df.select(
    col("player_id"),
    aggregate(
        col("skills"),
        lit(0),
        lambda acc, x: when(x.skill_level > acc, x.skill_level).otherwise(acc)
    ).alias("max_skill_level")
)
```

### Partitioning Strategy

```python
# Partition by date for time-series data
matches_df.write \
    .partitionBy("year", "month") \
    .parquet("matches/")

# Partition by team for team-level analysis
scores_df.write \
    .partitionBy("team_id") \
    .parquet("scores/")

# Read only required partitions
recent_matches = spark.read.parquet("matches/") \
    .filter(col("year") == 2024 & col("month") == 1)
```

### Caching Strategy

```python
# Cache frequently used base tables
players_base.cache()
teams_df.cache()

# Cache intermediate results if reused
exploded_df = df.explode("skills")
exploded_df.cache()

result1 = exploded_df.filter(...)
result2 = exploded_df.groupBy(...)

exploded_df.unpersist()  # Release when done
```

---

## Best Practices

### 1. Choose the Right Approach

| Scenario | Approach | Reason |
|----------|----------|---------|
| Need individual skill analysis | Explode | Direct aggregation |
| One row per player required | Array functions | Maintains granularity |
| Fixed set of skills | Pivot | Column-based access |
| Complex transformations | Higher-order functions | Flexibility |
| Large-scale analytics | Aggregate then explode | Minimize shuffle |

### 2. Handle Nulls Properly

```python
# Use explode_outer instead of explode
df.select(explode_outer("skills"))  # Keeps rows with null arrays

# Use coalesce for default values
df.withColumn(
    "skill_level",
    coalesce(col("skill.skill_level"), lit(0))
)

# Check for null arrays before operations
df.filter(col("skills").isNotNull() & (size(col("skills")) > 0))
```

### 3. Validate Data Quality

```python
# Check for unexpected array sizes
df.select(
    col("player_id"),
    size(col("skills")).alias("skill_count")
).groupBy("skill_count").count().show()

# Identify missing nested fields
df.select(
    sum(when(col("contact.email").isNull(), 1).otherwise(0)).alias("missing_emails"),
    sum(when(col("contact.phone").isNull(), 1).otherwise(0)).alias("missing_phones")
).show()
```

### 4. Use Schema Inference Carefully

```python
# Explicit schema is better for production
schema = StructType([
    StructField("player_id", StringType(), False),
    StructField("player_name", StringType(), False),
    StructField("skills", ArrayType(
        StructType([
            StructField("skill_name", StringType(), True),
            StructField("skill_level", IntegerType(), True)
        ])
    ), True)
])

df = spark.read.schema(schema).json("players.json")
```

### 5. Document Your Explosions

```python
# Add comments explaining explosion strategy
# Explosion Strategy: One row per player-skill combination
# Original: 1,000 players
# After explode: ~5,000 rows (avg 5 skills/player)
# Use for: Skill-level aggregations
players_exploded = df.explode("skills")
```

### 6. Test with Subsets

```python
# Test transformations on small subset first
test_df = df.limit(100)
test_result = complex_transformation(test_df)
test_result.show()

# Validate row counts
original_count = test_df.count()
result_count = test_result.count()
print(f"Explosion factor: {result_count / original_count}")
```

---

## Common Patterns Summary

### Pattern 1: Explode → Group Back
```python
# Explode for analysis
exploded = df.select(col("id"), explode("items").alias("item"))

# Analyze
analyzed = exploded.groupBy("id", "item.category").agg(sum("item.value"))

# Group back if needed
result = analyzed.groupBy("id").agg(
    collect_list(struct("category", "sum(value)")).alias("summary")
)
```

### Pattern 2: Array to Columns
```python
# Convert array to multiple columns
df.select(
    col("id"),
    col("items")[0].alias("item_1"),
    col("items")[1].alias("item_2"),
    col("items")[2].alias("item_3")
)
```

### Pattern 3: Conditional Explosion
```python
# Explode only when needed
df.withColumn(
    "processed",
    when(size(col("items")) > 1,
         explode(col("items")))
    .otherwise(col("items")[0])
)
```

---

## Troubleshooting Guide

### Issue 1: "java.lang.NullPointerException during explode"
**Solution:** Use `explode_outer` instead of `explode`

### Issue 2: "Cannot resolve column name"
**Solution:** Check for nested access with correct dot notation

```python
# Wrong
df.select(col("contact").col("email"))

# Right
df.select(col("contact.email"))
```

### Issue 3: "Array index out of bounds"
**Solution:** Use `element_at` with null handling

```python
# Wrong
df.select(col("items")[0])

# Right
from pyspark.sql.functions import element_at
df.select(element_at(col("items"), 1))  # Returns null if out of bounds
```

### Issue 4: "Duplicate column names after join"
**Solution:** Rename columns before join or drop after

```python
# Rename before
df2 = df2.withColumnRenamed("id", "id2")
result = df1.join(df2, df1.id == df2.id2)

# Or drop after
result = df1.join(df2, "id").drop(df2.id)
```

---

## Conclusion

Handling nested JSON in Spark requires understanding:
1. **When to explode** vs when to keep arrays
2. **Join order** to minimize data explosion
3. **Performance implications** of different approaches
4. **Trade-offs** between readability and efficiency

Choose your approach based on:
- Analytics requirements
- Data volume
- Query patterns
- Performance constraints
