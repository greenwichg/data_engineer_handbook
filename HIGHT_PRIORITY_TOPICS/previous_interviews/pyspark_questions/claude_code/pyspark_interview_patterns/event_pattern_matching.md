# PySpark Implementation: Event Pattern Matching

## Problem Statement
Given a clickstream dataset with user sessions, detect users who completed a conversion funnel
in order: **login -> add_to_cart -> purchase**. The events must occur in this exact sequence
(though other events may appear in between) within the same user's activity, ordered by timestamp.

Two approaches:
1. Use `lead()` window functions to look ahead at subsequent events.
2. Use `collect_list()` with ordering to build an event sequence array, then check for the pattern.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("EventPatternMatching").getOrCreate()

data = [
    ("u1", "2024-01-10 09:00:00", "login"),
    ("u1", "2024-01-10 09:05:00", "browse"),
    ("u1", "2024-01-10 09:10:00", "add_to_cart"),
    ("u1", "2024-01-10 09:15:00", "purchase"),      # u1: full funnel
    ("u2", "2024-01-10 10:00:00", "login"),
    ("u2", "2024-01-10 10:05:00", "browse"),
    ("u2", "2024-01-10 10:10:00", "logout"),          # u2: no purchase
    ("u3", "2024-01-10 11:00:00", "add_to_cart"),
    ("u3", "2024-01-10 11:05:00", "purchase"),         # u3: missing login
    ("u4", "2024-01-10 12:00:00", "login"),
    ("u4", "2024-01-10 12:02:00", "add_to_cart"),
    ("u4", "2024-01-10 12:05:00", "browse"),
    ("u4", "2024-01-10 12:10:00", "purchase"),         # u4: full funnel
    ("u5", "2024-01-10 13:00:00", "login"),
    ("u5", "2024-01-10 13:05:00", "purchase"),
    ("u5", "2024-01-10 13:10:00", "add_to_cart"),      # u5: wrong order
]

schema = StructType([
    StructField("user_id", StringType()),
    StructField("event_time", StringType()),
    StructField("event_type", StringType()),
])

events = spark.createDataFrame(data, schema) \
    .withColumn("event_time", to_timestamp("event_time"))
```

### Expected Output
Users who completed the full funnel (login -> add_to_cart -> purchase) in order:

| user_id | completed_funnel |
|---------|-----------------|
| u1      | true            |
| u2      | false           |
| u3      | false           |
| u4      | true            |
| u5      | false           |

---

## Method 1: collect_list with Array Position Check (Recommended)
```python
# Define time-ordered window per user
w = Window.partitionBy("user_id").orderBy("event_time")

# Assign a row number to preserve ordering
events_numbered = events.withColumn("seq", row_number().over(w))

# Filter to only funnel events and collect in order
funnel_events = events_numbered.filter(
    col("event_type").isin("login", "add_to_cart", "purchase")
)

# Collect events as ordered list per user
user_sequences = funnel_events.groupBy("user_id").agg(
    collect_list(struct("seq", "event_type")).alias("event_pairs")
)

# Sort the collected structs by seq to guarantee ordering
user_sequences = user_sequences.withColumn(
    "event_pairs", array_sort("event_pairs")
).withColumn(
    "event_sequence", transform("event_pairs", lambda x: x.event_type)
)

# Check if the pattern [login, add_to_cart, purchase] appears as a subsequence
# Find the positions of each required event
user_sequences = user_sequences.withColumn(
    "login_pos", array_position("event_sequence", "login")
).withColumn(
    "cart_pos", array_position("event_sequence", "add_to_cart")
).withColumn(
    "purchase_pos", array_position("event_sequence", "purchase")
)

# Funnel is complete when all three exist AND appear in order
# array_position returns 0 if not found, 1-based index otherwise
user_sequences = user_sequences.withColumn(
    "completed_funnel",
    (col("login_pos") > 0) &
    (col("cart_pos") > 0) &
    (col("purchase_pos") > 0) &
    (col("login_pos") < col("cart_pos")) &
    (col("cart_pos") < col("purchase_pos"))
)

result = user_sequences.select("user_id", "completed_funnel").orderBy("user_id")

# Join back to include users who had no funnel events at all
all_users = events.select("user_id").distinct()
final = all_users.join(result, on="user_id", how="left") \
    .fillna(False, subset=["completed_funnel"]) \
    .orderBy("user_id")

final.show()
```

### Step-by-Step Explanation

**Step 1 -- Row numbering** assigns a global sequence per user based on event_time:

| user_id | event_time          | event_type  | seq |
|---------|---------------------|-------------|-----|
| u1      | 2024-01-10 09:00:00 | login       | 1   |
| u1      | 2024-01-10 09:05:00 | browse      | 2   |
| u1      | 2024-01-10 09:10:00 | add_to_cart | 3   |
| u1      | 2024-01-10 09:15:00 | purchase    | 4   |

**Step 2 -- Filter and collect** keeps only funnel-relevant events:

| user_id | event_sequence                      |
|---------|-------------------------------------|
| u1      | [login, add_to_cart, purchase]       |
| u2      | [login]                             |
| u3      | [add_to_cart, purchase]             |
| u4      | [login, add_to_cart, purchase]       |
| u5      | [login, purchase, add_to_cart]       |

**Step 3 -- Position check:** `array_position` returns 1-based indices.
- u1: login=1, cart=2, purchase=3 -> 1 < 2 < 3 -> TRUE
- u5: login=1, purchase=2, cart=3 -> 2 < 3 but 1 < 2 is true... wait, cart=3 > purchase=2 -> FALSE

---

## Method 2: Lead-Based Look-Ahead Approach
```python
# Filter to funnel events only, then use lead() to check ordering
w_user = Window.partitionBy("user_id").orderBy("event_time")

funnel_only = events.filter(
    col("event_type").isin("login", "add_to_cart", "purchase")
)

# Look at the next 1 and next 2 funnel events
with_leads = funnel_only.withColumn(
    "next_event_1", lead("event_type", 1).over(w_user)
).withColumn(
    "next_event_2", lead("event_type", 2).over(w_user)
)

# A row where current=login, next=add_to_cart, next2=purchase means funnel completion
funnel_matches = with_leads.filter(
    (col("event_type") == "login") &
    (col("next_event_1") == "add_to_cart") &
    (col("next_event_2") == "purchase")
)

# Get distinct users who matched
completed_users = funnel_matches.select("user_id").distinct() \
    .withColumn("completed_funnel", lit(True))

# Join back to all users
all_users = events.select("user_id").distinct()
result_lead = all_users.join(completed_users, on="user_id", how="left") \
    .fillna(False, subset=["completed_funnel"]) \
    .orderBy("user_id")

result_lead.show()
```

### Lead Method Intermediate State

| user_id | event_type  | next_event_1 | next_event_2 |
|---------|-------------|--------------|--------------|
| u1      | login       | add_to_cart  | purchase     |
| u1      | add_to_cart | purchase     | null         |
| u1      | purchase    | null         | null         |
| u4      | login       | add_to_cart  | purchase     |
| u5      | login       | purchase     | add_to_cart  |

Row u1-login and u4-login match the pattern; u5-login does not because next_event_1 is "purchase".

**Caveat:** The lead approach only detects *consecutive* funnel events (no non-funnel events
in between among the filtered set). Pre-filtering to funnel events handles interleaved
non-funnel events (like "browse"), but it would miss patterns where a user logs in, adds to
cart, logs in again, then purchases -- the second login would break the lead chain.

---

## Key Interview Talking Points
1. **collect_list + array_position** is more flexible than `lead()` because it handles arbitrary gaps and repeated events in the sequence.
2. **lead() approach** is simpler but assumes the pattern events appear consecutively after filtering; it works well for fixed-length patterns (exactly 3 steps).
3. **Ordering guarantee:** `collect_list` does NOT guarantee order unless used with `array_sort` on a struct containing the sort key, or within a window with an `orderBy` clause.
4. **Scalability:** The `collect_list` approach collects all events per user into memory on one executor -- for users with millions of events, this can cause OOM. The `lead()` approach streams through the partition.
5. **Session boundaries:** In production, you would add a session_id and partition by `(user_id, session_id)` to scope the funnel to a single session.
6. **Time constraints:** Real funnels often require completion within a time window (e.g., 30 minutes). Add a filter: `purchase_time - login_time < interval 30 minutes`.
7. **Multiple completions:** If a user can complete the funnel multiple times, use `row_number()` to identify each funnel instance.
8. **Alternative:** For complex sequence patterns at scale, consider Spark's `Sessionize` pattern or specialized libraries like sequence mining algorithms.
