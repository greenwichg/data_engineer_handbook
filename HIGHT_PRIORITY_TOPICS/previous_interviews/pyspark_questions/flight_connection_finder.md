# PySpark Implementation: Flight Connection Finder

## Problem Statement 

Given a dataset of flights with departure/arrival airports and times, find all valid **connecting flight pairs** where a passenger can depart from City A, arrive at City B, and then catch another flight from City B to City C — with a **minimum 1-hour and maximum 6-hour layover** at City B. This is a self-join problem where you join the flights table with itself to find pairs meeting time and location constraints.

### Sample Data

```
flight_id  departure  arrival  dep_time             arr_time             airline
F001       NYC        CHI      2025-01-15 08:00     2025-01-15 10:30     AA
F002       CHI        LAX      2025-01-15 12:00     2025-01-15 14:30     UA
F003       CHI        LAX      2025-01-15 11:00     2025-01-15 13:30     AA
F004       CHI        MIA      2025-01-15 17:00     2025-01-15 20:00     DL
F005       NYC        CHI      2025-01-15 06:00     2025-01-15 08:30     UA
F006       LAX        NYC      2025-01-15 16:00     2025-01-15 22:00     AA
F007       NYC        CHI      2025-01-15 14:00     2025-01-15 16:30     AA
F008       CHI        MIA      2025-01-15 18:00     2025-01-15 21:00     AA
```

### Expected Output (Valid Connections)

| first_flight | connection_city | second_flight | layover_min | route            |
|-------------|----------------|--------------|-------------|------------------|
| F001        | CHI            | F002         | 90          | NYC → CHI → LAX  |
| F001        | CHI            | F003         | 30          | (too short — excluded) |
| F005        | CHI            | F003         | 150         | NYC → CHI → LAX  |
| F005        | CHI            | F002         | 210         | NYC → CHI → LAX  |
| F007        | CHI            | F004         | 30          | (too short — excluded) |
| F007        | CHI            | F008         | 90          | NYC → CHI → MIA  |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, unix_timestamp, concat, \
    lit, round as spark_round
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("FlightConnections").getOrCreate()

# Sample data
data = [
    ("F001", "NYC", "CHI", "2025-01-15 08:00", "2025-01-15 10:30", "AA"),
    ("F002", "CHI", "LAX", "2025-01-15 12:00", "2025-01-15 14:30", "UA"),
    ("F003", "CHI", "LAX", "2025-01-15 11:00", "2025-01-15 13:30", "AA"),
    ("F004", "CHI", "MIA", "2025-01-15 17:00", "2025-01-15 20:00", "DL"),
    ("F005", "NYC", "CHI", "2025-01-15 06:00", "2025-01-15 08:30", "UA"),
    ("F006", "LAX", "NYC", "2025-01-15 16:00", "2025-01-15 22:00", "AA"),
    ("F007", "NYC", "CHI", "2025-01-15 14:00", "2025-01-15 16:30", "AA"),
    ("F008", "CHI", "MIA", "2025-01-15 18:00", "2025-01-15 21:00", "AA")
]
columns = ["flight_id", "departure", "arrival", "dep_time", "arr_time", "airline"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("dep_time", to_timestamp("dep_time")) \
       .withColumn("arr_time", to_timestamp("arr_time"))

# Layover constraints
MIN_LAYOVER_MIN = 60   # 1 hour minimum
MAX_LAYOVER_MIN = 360  # 6 hours maximum

# Self-join: first flight's arrival = second flight's departure
# with layover time constraints
f1 = df.alias("f1")  # First leg
f2 = df.alias("f2")  # Second leg

connections = f1.join(
    f2,
    # Connection city: first leg arrives where second leg departs
    (col("f1.arrival") == col("f2.departure")) &
    # Different flights
    (col("f1.flight_id") != col("f2.flight_id")) &
    # Second flight departs AFTER first flight arrives
    (col("f2.dep_time") > col("f1.arr_time")) &
    # Minimum layover (1 hour)
    (
        (unix_timestamp(col("f2.dep_time")) - unix_timestamp(col("f1.arr_time")))
        >= MIN_LAYOVER_MIN * 60
    ) &
    # Maximum layover (6 hours)
    (
        (unix_timestamp(col("f2.dep_time")) - unix_timestamp(col("f1.arr_time")))
        <= MAX_LAYOVER_MIN * 60
    ),
    "inner"
).select(
    col("f1.flight_id").alias("first_flight"),
    col("f1.departure").alias("origin"),
    col("f1.arrival").alias("connection_city"),
    col("f2.departure").alias("connection_depart"),
    col("f2.flight_id").alias("second_flight"),
    col("f2.arrival").alias("destination"),
    spark_round(
        (unix_timestamp(col("f2.dep_time")) - unix_timestamp(col("f1.arr_time"))) / 60,
        0
    ).alias("layover_min"),
    concat(
        col("f1.departure"), lit(" → "),
        col("f1.arrival"), lit(" → "),
        col("f2.arrival")
    ).alias("route")
).orderBy("origin", "first_flight", "layover_min")

connections.show(truncate=False)
```

### Step-by-Step Explanation

#### The Self-Join Logic

```
f1 (First Leg)                    f2 (Second Leg)
F001: NYC → CHI (arr 10:30)  ↔   F002: CHI → LAX (dep 12:00)
                                   F003: CHI → LAX (dep 11:00)
                                   F004: CHI → MIA (dep 17:00)
                                   F008: CHI → MIA (dep 18:00)
```

**Join condition breakdown:**
1. `f1.arrival == f2.departure` → Connection city must match
2. `f2.dep_time > f1.arr_time` → Second flight leaves after first arrives
3. Layover between 60-360 minutes

**For F001 (arrives CHI at 10:30):**
- F002 (departs CHI 12:00): layover = 90 min ✓
- F003 (departs CHI 11:00): layover = 30 min ✗ (< 60 min)
- F004 (departs CHI 17:00): layover = 390 min ✗ (> 360 min)
- F008 (departs CHI 18:00): layover = 450 min ✗ (> 360 min)

---

## Extension 1: Find Cheapest Connection

```python
# Add price data
price_data = [
    ("F001", 250.00), ("F002", 300.00), ("F003", 280.00),
    ("F004", 200.00), ("F005", 220.00), ("F006", 350.00),
    ("F007", 260.00), ("F008", 190.00)
]
prices_df = spark.createDataFrame(price_data, ["flight_id", "price"])
df_with_price = df.join(prices_df, on="flight_id")

# Re-do the self-join with prices
fp1 = df_with_price.alias("fp1")
fp2 = df_with_price.alias("fp2")

priced_connections = fp1.join(
    fp2,
    (col("fp1.arrival") == col("fp2.departure")) &
    (col("fp1.flight_id") != col("fp2.flight_id")) &
    (
        (unix_timestamp(col("fp2.dep_time")) - unix_timestamp(col("fp1.arr_time")))
        .between(MIN_LAYOVER_MIN * 60, MAX_LAYOVER_MIN * 60)
    ),
    "inner"
).select(
    col("fp1.flight_id").alias("first_flight"),
    col("fp2.flight_id").alias("second_flight"),
    concat(col("fp1.departure"), lit("→"), col("fp1.arrival"), lit("→"), col("fp2.arrival")).alias("route"),
    (col("fp1.price") + col("fp2.price")).alias("total_price"),
    spark_round(
        (unix_timestamp(col("fp2.dep_time")) - unix_timestamp(col("fp1.arr_time"))) / 60, 0
    ).alias("layover_min")
).orderBy("route", "total_price")

# Get cheapest connection per route
from pyspark.sql.functions import row_number

window_route = Window.partitionBy("route").orderBy("total_price")
cheapest = priced_connections.withColumn("rn", row_number().over(window_route)) \
    .filter(col("rn") == 1).drop("rn")

cheapest.show(truncate=False)
```

---

## Extension 2: Three-Leg Connections (Triple Self-Join)

```python
# Find A → B → C → D routes (two connections)
f1 = df.alias("f1")
f2 = df.alias("f2")
f3 = df.alias("f3")

three_leg = f1.join(
    f2,
    (col("f1.arrival") == col("f2.departure")) &
    (col("f1.flight_id") != col("f2.flight_id")) &
    (
        (unix_timestamp(col("f2.dep_time")) - unix_timestamp(col("f1.arr_time")))
        .between(MIN_LAYOVER_MIN * 60, MAX_LAYOVER_MIN * 60)
    ),
    "inner"
).join(
    f3,
    (col("f2.arrival") == col("f3.departure")) &
    (col("f2.flight_id") != col("f3.flight_id")) &
    (
        (unix_timestamp(col("f3.dep_time")) - unix_timestamp(col("f2.arr_time")))
        .between(MIN_LAYOVER_MIN * 60, MAX_LAYOVER_MIN * 60)
    ),
    "inner"
).select(
    col("f1.flight_id").alias("leg1"),
    col("f2.flight_id").alias("leg2"),
    col("f3.flight_id").alias("leg3"),
    concat(
        col("f1.departure"), lit("→"),
        col("f1.arrival"), lit("→"),
        col("f2.arrival"), lit("→"),
        col("f3.arrival")
    ).alias("route")
)

three_leg.show(truncate=False)
```

---

## Extension 3: Same-Airline Connections

```python
# Only find connections where both legs are on the same airline
same_airline = f1.join(
    f2,
    (col("f1.arrival") == col("f2.departure")) &
    (col("f1.airline") == col("f2.airline")) &          # Same airline
    (col("f1.flight_id") != col("f2.flight_id")) &
    (
        (unix_timestamp(col("f2.dep_time")) - unix_timestamp(col("f1.arr_time")))
        .between(MIN_LAYOVER_MIN * 60, MAX_LAYOVER_MIN * 60)
    ),
    "inner"
).select(
    col("f1.flight_id").alias("first_flight"),
    col("f2.flight_id").alias("second_flight"),
    col("f1.airline"),
    concat(col("f1.departure"), lit("→"), col("f1.arrival"), lit("→"), col("f2.arrival")).alias("route"),
    spark_round(
        (unix_timestamp(col("f2.dep_time")) - unix_timestamp(col("f1.arr_time"))) / 60, 0
    ).alias("layover_min")
)

same_airline.show(truncate=False)
```

---

## Method 2: Using SQL

```python
df.createOrReplaceTempView("flights")

spark.sql("""
    SELECT
        f1.flight_id AS first_flight,
        f1.departure AS origin,
        f1.arrival AS connection_city,
        f2.flight_id AS second_flight,
        f2.arrival AS destination,
        ROUND(
            (UNIX_TIMESTAMP(f2.dep_time) - UNIX_TIMESTAMP(f1.arr_time)) / 60
        ) AS layover_min,
        CONCAT(f1.departure, ' → ', f1.arrival, ' → ', f2.arrival) AS route
    FROM flights f1
    INNER JOIN flights f2
        ON f1.arrival = f2.departure
        AND f1.flight_id != f2.flight_id
        AND UNIX_TIMESTAMP(f2.dep_time) - UNIX_TIMESTAMP(f1.arr_time) BETWEEN 3600 AND 21600
    ORDER BY origin, first_flight, layover_min
""").show(truncate=False)
```

---

## Connection to Parent Pattern (self_join_comparisons)

| Concept | self_join (employee vs manager) | flight_connection_finder |
|---------|--------------------------------|------------------------|
| **Join type** | Self-join with alias | Self-join with alias |
| **Equality condition** | `emp.manager_id = mgr.emp_id` | `f1.arrival = f2.departure` |
| **Filter condition** | `emp.salary > mgr.salary` | Layover time BETWEEN min AND max |
| **Avoid self-match** | Implicit (different roles) | `f1.flight_id != f2.flight_id` |
| **Avoid duplicates** | N/A | N/A (directional — leg 1 before leg 2) |

Same self-join pattern — alias the table, define join and filter conditions. Different:
- Join key (manager_id vs arrival/departure airport)
- Filter logic (salary comparison vs time window)

---

## Key Interview Talking Points

1. **Self-join with temporal constraint:** This combines an equality join (airport matching) with a range condition (layover window). The equality condition allows hash/sort-merge join, making it much more efficient than a pure range join.

2. **Avoid duplicate pairs:** Unlike product pair-finding where you use `a.id < b.id`, here directionality is natural — first flight must arrive before second departs. The temporal condition handles this.

3. **Performance:** The equality on airport means Spark can use sort-merge or hash join, then filter on time. For large datasets, consider broadcasting a smaller table of connecting airports.

4. **Triple self-join complexity:** Three-leg connections produce O(n³) potential combinations. In practice, the equality + time constraints prune this dramatically, but for very large datasets, consider iterative approaches.

5. **Real-world use cases:**
   - Airline itinerary building
   - Supply chain route optimization (warehouse → warehouse → store)
   - Public transit trip planning (bus → bus or bus → train)
   - Network packet routing (hop-by-hop path finding)
   - Delivery route chaining
