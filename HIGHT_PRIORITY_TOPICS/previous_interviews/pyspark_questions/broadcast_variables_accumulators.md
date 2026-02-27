# PySpark Implementation: Broadcast Variables and Accumulators

## Problem Statement

Demonstrate the use of **broadcast variables** for efficient lookups in distributed processing and **accumulators** for aggregating values across executors. Given a dataset of transactions that need to be enriched with country names from a lookup dictionary, use broadcast variables to avoid shipping the lookup with every task. Also use accumulators to count records with missing or invalid data during processing.

These are Spark internals concepts frequently asked in interviews to assess your understanding of distributed computing.

### Sample Data

**Transactions:**
```
txn_id  country_code  amount
T001    US            500
T002    UK            300
T003    IN            200
T004    XX            150
T005    US            450
T006    DE            350
T007    ZZ            100
```

**Country Lookup (small dictionary):**
```python
{"US": "United States", "UK": "United Kingdom", "IN": "India", "DE": "Germany", "FR": "France"}
```

### Expected Output

| txn_id | country_code | amount | country_name   |
|--------|-------------|--------|----------------|
| T001   | US          | 500    | United States  |
| T002   | UK          | 300    | United Kingdom |
| T003   | IN          | 200    | India          |
| T004   | XX          | 150    | Unknown        |
| T005   | US          | 450    | United States  |
| T006   | DE          | 350    | Germany        |
| T007   | ZZ          | 100    | Unknown        |

**Accumulator result:** 2 records with unknown country codes.

---

## Method 1: Broadcast Variables

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf
from pyspark.sql.types import StringType

# Initialize Spark session
spark = SparkSession.builder.appName("BroadcastAccumulator").getOrCreate()
sc = spark.sparkContext

# Transaction data
txn_data = [
    ("T001", "US", 500), ("T002", "UK", 300),
    ("T003", "IN", 200), ("T004", "XX", 150),
    ("T005", "US", 450), ("T006", "DE", 350),
    ("T007", "ZZ", 100)
]
columns = ["txn_id", "country_code", "amount"]
txn_df = spark.createDataFrame(txn_data, columns)

# Country lookup dictionary (small data)
country_lookup = {
    "US": "United States",
    "UK": "United Kingdom",
    "IN": "India",
    "DE": "Germany",
    "FR": "France"
}

# Step 1: Broadcast the lookup dictionary to all executors
broadcast_countries = sc.broadcast(country_lookup)

# Step 2: Use broadcast variable in a UDF
@udf(StringType())
def get_country_name(code):
    """Lookup country name from broadcast variable."""
    lookup = broadcast_countries.value  # Access broadcast data
    return lookup.get(code, "Unknown")

# Step 3: Apply the UDF
result = txn_df.withColumn("country_name", get_country_name(col("country_code")))
result.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: sc.broadcast(country_lookup)
- **What happens:** Sends the dictionary to every executor node **once**. Without broadcasting, the lookup would be serialized and sent with every task (every partition), wasting network bandwidth.
- **Where it lives:** Cached in each executor's memory, shared across all tasks on that executor.

#### Step 2: broadcast_countries.value
- **What happens:** Inside the UDF, `.value` accesses the broadcast data. This is a local read — no network I/O.

#### Step 3: Output

  | txn_id | country_code | amount | country_name   |
  |--------|-------------|--------|----------------|
  | T001   | US          | 500    | United States  |
  | T002   | UK          | 300    | United Kingdom |
  | T003   | IN          | 200    | India          |
  | T004   | XX          | 150    | Unknown        |
  | T005   | US          | 450    | United States  |
  | T006   | DE          | 350    | Germany        |
  | T007   | ZZ          | 100    | Unknown        |

---

## How Broadcast Works Internally

```
Without Broadcast:
  Driver → Task 1: sends lookup (copy 1)
  Driver → Task 2: sends lookup (copy 2)
  Driver → Task 3: sends lookup (copy 3)
  ... (N copies for N tasks)

With Broadcast:
  Driver → Executor 1: sends lookup (1 copy per executor)
  Driver → Executor 2: sends lookup (1 copy per executor)
  All tasks on Executor 1 share the same copy
  All tasks on Executor 2 share the same copy
```

---

## Method 2: Accumulators

```python
# Step 1: Create accumulators
invalid_count = sc.accumulator(0)        # Count invalid country codes
total_amount = sc.accumulator(0)         # Sum total transaction amount

# Step 2: Use accumulators in a UDF
@udf(StringType())
def get_country_with_count(code):
    """Lookup with accumulator tracking."""
    lookup = broadcast_countries.value
    name = lookup.get(code, None)
    if name is None:
        invalid_count.add(1)  # Increment accumulator
        return "Unknown"
    return name

# Step 3: Apply (must trigger an action to execute)
result_with_acc = txn_df.withColumn(
    "country_name",
    get_country_with_count(col("country_code"))
)

# Trigger computation
result_with_acc.show()

# Step 4: Read accumulator values (only on the driver)
print(f"Records with invalid country codes: {invalid_count.value}")
```

- **Output:**
  ```
  Records with invalid country codes: 2
  ```

### Accumulator Rules

| Rule | Details |
|------|---------|
| Write from executors | `accumulator.add(value)` — works in tasks |
| Read on driver only | `accumulator.value` — only reliable on driver after action |
| No read in transformations | Reading accumulator in a transformation gives unreliable results |
| Idempotency | Accumulator may count twice if a task is re-executed (speculative execution, failures) |

---

## Method 3: Custom Accumulator (Advanced)

```python
from pyspark.accumulators import AccumulatorParam

# Custom accumulator that collects unique invalid codes
class SetAccumulatorParam(AccumulatorParam):
    def zero(self, initial_value):
        return set()

    def addInPlace(self, v1, v2):
        if isinstance(v2, set):
            return v1.union(v2)
        else:
            v1.add(v2)
            return v1

# Register custom accumulator
invalid_codes_set = sc.accumulator(set(), SetAccumulatorParam())

@udf(StringType())
def get_country_track_invalid(code):
    lookup = broadcast_countries.value
    name = lookup.get(code, None)
    if name is None:
        invalid_codes_set.add(code)
        return "Unknown"
    return name

result_track = txn_df.withColumn(
    "country_name",
    get_country_track_invalid(col("country_code"))
)
result_track.show()

print(f"Invalid country codes found: {invalid_codes_set.value}")
# Output: Invalid country codes found: {'XX', 'ZZ'}
```

---

## Method 4: Broadcast Join (DataFrame API Alternative)

```python
from pyspark.sql.functions import broadcast as broadcast_hint

# Convert lookup to DataFrame for join-based approach
country_df = spark.createDataFrame(
    [(k, v) for k, v in country_lookup.items()],
    ["country_code", "country_name"]
)

# Broadcast join — Spark sends the small DataFrame to all executors
result_join = txn_df.join(
    broadcast_hint(country_df),
    on="country_code",
    how="left"
).fillna({"country_name": "Unknown"})

result_join.orderBy("txn_id").show(truncate=False)
```

### Broadcast Variable vs Broadcast Join

| Aspect | Broadcast Variable (sc.broadcast) | Broadcast Join (broadcast hint) |
|--------|----------------------------------|-------------------------------|
| API level | RDD / low-level | DataFrame / high-level |
| Data type | Any Python object (dict, list) | DataFrame |
| Access | Inside UDFs via `.value` | Through join operation |
| Use case | Custom logic in UDFs | Standard lookups / enrichment |
| Recommended | When UDF is unavoidable | Preferred — lets Spark optimize |

---

## Method 5: Using map_from_arrays for Simple Lookups (No UDF Needed)

```python
from pyspark.sql.functions import create_map, lit, coalesce

# Build a map column from the lookup dictionary
keys = list(country_lookup.keys())
values = list(country_lookup.values())

# Create map expression
map_expr = create_map(*[item for k, v in country_lookup.items() for item in (lit(k), lit(v))])

# Use the map for lookup — no UDF, no broadcast needed!
result_map = txn_df.withColumn(
    "country_name",
    coalesce(map_expr[col("country_code")], lit("Unknown"))
)

result_map.show(truncate=False)
```

- **Explanation:** `create_map()` builds a map literal in the query plan. For small lookups (< 1000 entries), this is the most efficient approach — no UDF overhead, fully optimized by Catalyst.

---

## When to Use Each Approach

| Approach | Lookup Size | Custom Logic? | Performance |
|----------|------------|---------------|-------------|
| `create_map()` | < 1K entries | No | Best |
| Broadcast join | < 10MB DataFrame | No | Very good |
| Broadcast variable + UDF | Any size (fits in memory) | Yes | Good |
| Regular join | Any size | No | Depends on data |

## Key Interview Talking Points

1. **What is a broadcast variable?** A read-only variable cached on each executor (not each task). Reduces data transfer from O(tasks) to O(executors).

2. **When to use broadcast?** When a small dataset needs to be referenced by all tasks — lookup tables, configuration, ML model parameters.

3. **Accumulator gotcha:** Accumulators in transformations (map, filter) may count duplicates due to task retries or speculative execution. Only accumulators in **actions** (foreach) are guaranteed to be accurate.

4. **Broadcast size limit:** Default `spark.sql.autoBroadcastJoinThreshold` is 10MB. You can increase it, but very large broadcasts consume executor memory.

5. **Destroying broadcast:** Call `broadcast_countries.unpersist()` or `broadcast_countries.destroy()` to free memory when the broadcast is no longer needed.

6. **Real-world use cases:**
   - Broadcast: Country/currency code lookups, feature dictionaries in ML, configuration maps
   - Accumulators: Data quality counters, error tracking, logging metrics
