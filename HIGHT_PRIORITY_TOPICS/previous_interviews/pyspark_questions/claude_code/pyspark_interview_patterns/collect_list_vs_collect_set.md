# PySpark Implementation: collect_list() vs collect_set()

## Problem Statement

`collect_list()` and `collect_set()` are aggregate functions that gather values into arrays. They are heavily used in PySpark for denormalization, creating nested structures, and reverse-exploding data. Understanding their differences in ordering, NULL handling, deduplication, and performance is critical for interviews.

| Feature | `collect_list()` | `collect_set()` |
|---|---|---|
| Duplicates | Keeps all duplicates | Removes duplicates |
| Order guarantee | **No guaranteed order** | No guaranteed order |
| NULL handling | **Excludes NULLs** | **Excludes NULLs** |
| Performance | Faster (no dedup) | Slower (hash-based dedup) |

**Key Gotcha:** Neither function guarantees order. If you need ordered results, you must use `collect_list()` combined with `array_sort()` or a window function approach.

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql import Window
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, DoubleType
)

spark = SparkSession.builder \
    .appName("collect_list vs collect_set") \
    .master("local[*]") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
```

---

## Part 1: Basic Comparison

### Sample Data

```python
data = [
    ("sales",    "Alice",   100),
    ("sales",    "Bob",     200),
    ("sales",    "Alice",   100),  # duplicate name and amount
    ("sales",    "Charlie", 150),
    ("eng",      "Diana",   300),
    ("eng",      "Eve",     250),
    ("eng",      "Diana",   300),  # duplicate
    ("eng",      "Frank",   None), # NULL amount
    ("marketing", None,     175),  # NULL name
]

schema = StructType([
    StructField("dept", StringType()),
    StructField("name", StringType()),
    StructField("amount", IntegerType()),
])

df = spark.createDataFrame(data, schema)
df.show(truncate=False)
```

```
+---------+-------+------+
|dept     |name   |amount|
+---------+-------+------+
|sales    |Alice  |100   |
|sales    |Bob    |200   |
|sales    |Alice  |100   |
|sales    |Charlie|150   |
|eng      |Diana  |300   |
|eng      |Eve    |250   |
|eng      |Diana  |300   |
|eng      |Frank  |null  |
|marketing|null   |175   |
+---------+-------+------+
```

### Method 1: collect_list() with groupBy

```python
df.groupBy("dept").agg(
    F.collect_list("name").alias("names_list"),
    F.collect_list("amount").alias("amounts_list"),
).show(truncate=False)
```

### Expected Output

```
+---------+-------------------------------+-----------------+
|dept     |names_list                     |amounts_list     |
+---------+-------------------------------+-----------------+
|sales    |[Alice, Bob, Alice, Charlie]   |[100, 200, 100, 150]|
|eng      |[Diana, Eve, Diana, Frank]     |[300, 250, 300]  |
|marketing|[]                             |[175]            |
+---------+-------------------------------+-----------------+
```

**Notice:**
- Duplicates are kept in `collect_list`
- Frank's NULL amount is excluded from `amounts_list`
- marketing's NULL name produces an empty list for `names_list`

### Method 2: collect_set() with groupBy

```python
df.groupBy("dept").agg(
    F.collect_set("name").alias("names_set"),
    F.collect_set("amount").alias("amounts_set"),
).show(truncate=False)
```

### Expected Output

```
+---------+-----------------------+------------+
|dept     |names_set              |amounts_set |
+---------+-----------------------+------------+
|sales    |[Charlie, Alice, Bob]  |[100, 150, 200]|
|eng      |[Eve, Frank, Diana]   |[250, 300]  |
|marketing|[]                     |[175]       |
+---------+-----------------------+------------+
```

**Notice:**
- Duplicates removed
- Order is not deterministic (may vary across runs)
- NULLs are excluded from both

---

## Part 2: Guaranteeing Order with array_sort()

### Sample Data

```python
order_data = [
    ("team_a", "2024-01-01", "task_1"),
    ("team_a", "2024-01-03", "task_3"),
    ("team_a", "2024-01-02", "task_2"),
    ("team_b", "2024-01-05", "task_5"),
    ("team_b", "2024-01-04", "task_4"),
]

df_order = spark.createDataFrame(order_data, ["team", "date", "task"])
```

### Method 1: collect_list + array_sort (sorts alphabetically)

```python
df_order.groupBy("team").agg(
    F.array_sort(F.collect_list("task")).alias("tasks_sorted"),
    F.array_sort(F.collect_list("date")).alias("dates_sorted"),
).show(truncate=False)
```

### Expected Output

```
+------+------------------------+--------------------------------------+
|team  |tasks_sorted            |dates_sorted                          |
+------+------------------------+--------------------------------------+
|team_a|[task_1, task_2, task_3]|[2024-01-01, 2024-01-02, 2024-01-03] |
|team_b|[task_4, task_5]        |[2024-01-04, 2024-01-05]              |
+------+------------------------+--------------------------------------+
```

### Method 2: Struct trick for ordering by one column, collecting another

```python
# Collect tasks ordered by date using struct + sort + transform
df_order.groupBy("team").agg(
    F.array_sort(
        F.collect_list(F.struct("date", "task"))
    ).alias("sorted_structs")
).select(
    "team",
    F.transform("sorted_structs", lambda x: x["task"]).alias("tasks_by_date"),
).show(truncate=False)
```

### Expected Output

```
+------+------------------------+
|team  |tasks_by_date           |
+------+------------------------+
|team_a|[task_1, task_2, task_3]|
|team_b|[task_4, task_5]        |
+------+------------------------+
```

**How it works:** `array_sort` on structs sorts by the first field. By placing `date` first in the struct, tasks end up sorted by date.

---

## Part 3: Window Function Approach (Ordered collect_list)

### Sample Data

```python
window_data = [
    ("Alice", "2024-01-01", 100),
    ("Alice", "2024-01-02", 200),
    ("Alice", "2024-01-03", 150),
    ("Bob",   "2024-01-01", 300),
    ("Bob",   "2024-01-02", 250),
]

df_window = spark.createDataFrame(window_data, ["name", "date", "amount"])
```

### Running collect_list with Window (Cumulative)

```python
w = Window.partitionBy("name").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_window.withColumn(
    "running_amounts", F.collect_list("amount").over(w)
).show(truncate=False)
```

### Expected Output

```
+-----+----------+------+-----------------+
|name |date      |amount|running_amounts  |
+-----+----------+------+-----------------+
|Alice|2024-01-01|100   |[100]            |
|Alice|2024-01-02|200   |[100, 200]       |
|Alice|2024-01-03|150   |[100, 200, 150]  |
|Bob  |2024-01-01|300   |[300]            |
|Bob  |2024-01-02|250   |[300, 250]       |
+-----+----------+------+-----------------+
```

### collect_set with Window

```python
w_full = Window.partitionBy("name").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

df_window.withColumn(
    "all_amounts_set", F.collect_set("amount").over(w_full)
).show(truncate=False)
```

---

## Part 4: NULL Handling Deep Dive

```python
null_data = [
    ("grp1", "a"),
    ("grp1", None),
    ("grp1", "b"),
    ("grp1", None),
    ("grp2", None),
    ("grp2", None),
]

df_null = spark.createDataFrame(null_data, ["group", "value"])

df_null.groupBy("group").agg(
    F.collect_list("value").alias("list_result"),
    F.collect_set("value").alias("set_result"),
    F.count("value").alias("non_null_count"),
    F.count("*").alias("total_count"),
).show(truncate=False)
```

### Expected Output

```
+-----+-----------+----------+--------------+-----------+
|group|list_result|set_result|non_null_count|total_count|
+-----+-----------+----------+--------------+-----------+
|grp1 |[a, b]    |[a, b]   |2             |4          |
|grp2 |[]        |[]       |0             |2          |
+-----+-----------+----------+--------------+-----------+
```

**Key point:** Both functions silently exclude NULLs. grp2 has 2 rows but produces empty arrays. If you need to include NULLs, coalesce first:

```python
df_null.groupBy("group").agg(
    F.collect_list(F.coalesce(F.col("value"), F.lit("UNKNOWN"))).alias("list_with_nulls"),
).show(truncate=False)
```

### Expected Output

```
+-----+----------------------------+
|group|list_with_nulls             |
+-----+----------------------------+
|grp1 |[a, UNKNOWN, b, UNKNOWN]   |
|grp2 |[UNKNOWN, UNKNOWN]         |
+-----+----------------------------+
```

---

## Part 5: Performance Considerations

```python
# Generate a large dataset to illustrate performance
import time

large_df = spark.range(1_000_000).withColumn(
    "group", (F.col("id") % 100).cast("string")
).withColumn(
    "value", F.col("id").cast("string")
)

# collect_list is generally faster than collect_set
start = time.time()
large_df.groupBy("group").agg(F.collect_list("value")).count()
list_time = time.time() - start

start = time.time()
large_df.groupBy("group").agg(F.collect_set("value")).count()
set_time = time.time() - start

print(f"collect_list: {list_time:.2f}s")
print(f"collect_set:  {set_time:.2f}s")
```

**Why `collect_set` is slower:**
- It maintains an internal hash set for deduplication
- Each element must be hashed and compared
- Memory overhead is higher due to the hash structure

**Danger with large groups:** Both functions collect all values for a group into a single executor's memory. If a group has millions of values, this can cause OOM errors. Consider:

```python
# Safer alternative: use size limit
df.groupBy("dept").agg(
    F.slice(F.collect_list("name"), 1, 100).alias("first_100_names")
)
```

---

## Part 6: Common Interview Pattern -- Pivot Alternative

```python
# Simulating a pivot using collect_list + map
pivot_data = [
    ("Alice", "Q1", 100),
    ("Alice", "Q2", 200),
    ("Alice", "Q1", 150),
    ("Bob",   "Q1", 300),
    ("Bob",   "Q3", 250),
]

df_pivot = spark.createDataFrame(pivot_data, ["name", "quarter", "revenue"])

# Aggregate into a map: quarter -> list of revenues
df_pivot.groupBy("name").agg(
    F.map_from_entries(
        F.collect_list(F.struct("quarter", "revenue"))
    ).alias("quarter_revenue_map")
).show(truncate=False)
```

**Note:** `map_from_entries` will keep only the last value for duplicate keys. To keep all, use a different approach:

```python
df_pivot.groupBy("name", "quarter").agg(
    F.collect_list("revenue").alias("revenues")
).groupBy("name").agg(
    F.map_from_entries(
        F.collect_list(F.struct("quarter", "revenues"))
    ).alias("quarter_revenues")
).show(truncate=False)
```

---

## Part 7: Concatenating Strings (Alternative to collect_list)

```python
# Often you want a comma-separated string instead of an array
df.groupBy("dept").agg(
    F.concat_ws(", ", F.collect_list("name")).alias("names_csv"),
    F.concat_ws(", ", F.array_sort(F.collect_set("name"))).alias("unique_names_sorted"),
).show(truncate=False)
```

### Expected Output

```
+---------+----------------------------+---------------------+
|dept     |names_csv                   |unique_names_sorted  |
+---------+----------------------------+---------------------+
|sales    |Alice, Bob, Alice, Charlie  |Alice, Bob, Charlie  |
|eng      |Diana, Eve, Diana, Frank    |Diana, Eve, Frank    |
|marketing|                            |                     |
+---------+----------------------------+---------------------+
```

---

## Key Takeaways

1. **Neither `collect_list` nor `collect_set` guarantees order.** If ordering matters, use `array_sort()` after collecting, or use the struct-sort trick to order by a different column.

2. **Both exclude NULLs silently.** Use `F.coalesce()` before collecting if you need to preserve NULL indicators.

3. **`collect_set` is slower** due to hash-based deduplication overhead. Only use it when you truly need unique values.

4. **Memory danger:** Both functions materialize all group values in memory on a single executor. Very large groups (millions of elements) can cause OOM. Consider `F.slice()` to limit output size.

5. **Window function usage:** Both can be used with window functions for running/cumulative aggregations. The window must have a proper frame specification.

6. **Interview tip:** When asked to "reverse an explode," the answer is `groupBy` + `collect_list`. Mention that you should use `collect_list` (not `collect_set`) to preserve the original data, and `array_sort` if ordering is needed.

7. **`concat_ws` + `collect_list`** is the standard pattern for creating comma-separated string aggregations in PySpark.
