# PySpark Implementation: Geographic Distance Calculations

## Problem Statement

Computing distances between geographic coordinates (latitude/longitude) is a common requirement in data engineering for logistics, ride-sharing, store locator, and delivery optimization applications. The Haversine formula calculates the great-circle distance between two points on a sphere. This is a practical interview topic that tests your ability to implement mathematical formulas as PySpark UDFs or native expressions.

Given a dataset of store locations and customer addresses, compute distances between each customer and nearby stores to find the closest store.

### Sample Data

**Stores:**
```
+--------+-----------+----------+-----------+
|store_id|store_name | latitude | longitude |
+--------+-----------+----------+-----------+
| S1     | Downtown  | 40.7128  | -74.0060  |
| S2     | Midtown   | 40.7549  | -73.9840  |
| S3     | Brooklyn  | 40.6782  | -73.9442  |
| S4     | Queens    | 40.7282  | -73.7949  |
+--------+-----------+----------+-----------+
```

**Customers:**
```
+---------+-----------+----------+-----------+
|cust_id  |cust_name  | latitude | longitude |
+---------+-----------+----------+-----------+
| C1      | Alice     | 40.7484  | -73.9857  |
| C2      | Bob       | 40.6892  | -73.9857  |
| C3      | Carol     | 40.7580  | -73.8855  |
+---------+-----------+----------+-----------+
```

### Expected Output

| cust_id | cust_name | nearest_store | distance_km |
|---------|-----------|---------------|-------------|
| C1      | Alice     | Midtown       | ~0.7        |
| C2      | Bob       | Brooklyn      | ~3.8        |
| C3      | Carol     | Queens        | ~8.5        |

---

## Method 1: Haversine Formula Using Native PySpark Functions

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window
import math

spark = SparkSession.builder \
    .appName("GeographicDistanceCalculations") \
    .master("local[*]") \
    .getOrCreate()

# Store locations
stores_data = [
    ("S1", "Downtown", 40.7128, -74.0060),
    ("S2", "Midtown",  40.7549, -73.9840),
    ("S3", "Brooklyn", 40.6782, -73.9442),
    ("S4", "Queens",   40.7282, -73.7949),
]
stores = spark.createDataFrame(stores_data,
    ["store_id", "store_name", "store_lat", "store_lon"])

# Customer locations
customers_data = [
    ("C1", "Alice", 40.7484, -73.9857),
    ("C2", "Bob",   40.6892, -73.9857),
    ("C3", "Carol", 40.7580, -73.8855),
]
customers = spark.createDataFrame(customers_data,
    ["cust_id", "cust_name", "cust_lat", "cust_lon"])

# ============================================================
# Haversine formula using native PySpark math functions
# ============================================================
# Haversine formula:
#   a = sin^2(dlat/2) + cos(lat1) * cos(lat2) * sin^2(dlon/2)
#   c = 2 * atan2(sqrt(a), sqrt(1-a))
#   distance = R * c   (R = 6371 km)

EARTH_RADIUS_KM = 6371.0

# Cross join to get all customer-store pairs
pairs = customers.crossJoin(stores)

# Convert degrees to radians and compute Haversine
pairs = pairs \
    .withColumn("lat1_rad", F.radians("cust_lat")) \
    .withColumn("lat2_rad", F.radians("store_lat")) \
    .withColumn("dlat_rad", F.radians(F.col("store_lat") - F.col("cust_lat"))) \
    .withColumn("dlon_rad", F.radians(F.col("store_lon") - F.col("cust_lon"))) \
    .withColumn("a",
        F.pow(F.sin(F.col("dlat_rad") / 2), 2) +
        F.cos(F.col("lat1_rad")) * F.cos(F.col("lat2_rad")) *
        F.pow(F.sin(F.col("dlon_rad") / 2), 2)
    ) \
    .withColumn("distance_km",
        F.lit(EARTH_RADIUS_KM) * 2 * F.atan2(F.sqrt("a"), F.sqrt(1 - F.col("a")))
    )

print("=== All Customer-Store Distances ===")
pairs.select("cust_id", "cust_name", "store_id", "store_name",
             F.round("distance_km", 2).alias("distance_km")) \
    .orderBy("cust_id", "distance_km").show()

# Find nearest store per customer
w = Window.partitionBy("cust_id").orderBy("distance_km")

nearest = pairs \
    .withColumn("rn", F.row_number().over(w)) \
    .filter(F.col("rn") == 1) \
    .select("cust_id", "cust_name", "store_name",
            F.round("distance_km", 2).alias("distance_km"))

print("=== Nearest Store per Customer ===")
nearest.show()
```

## Method 2: Using a PySpark UDF for Haversine

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType
from pyspark.sql.window import Window
import math

spark = SparkSession.builder \
    .appName("HaversineUDF") \
    .master("local[*]") \
    .getOrCreate()

stores_data = [
    ("S1", "Downtown", 40.7128, -74.0060),
    ("S2", "Midtown",  40.7549, -73.9840),
    ("S3", "Brooklyn", 40.6782, -73.9442),
    ("S4", "Queens",   40.7282, -73.7949),
]
stores = spark.createDataFrame(stores_data,
    ["store_id", "store_name", "store_lat", "store_lon"])

customers_data = [
    ("C1", "Alice", 40.7484, -73.9857),
    ("C2", "Bob",   40.6892, -73.9857),
    ("C3", "Carol", 40.7580, -73.8855),
]
customers = spark.createDataFrame(customers_data,
    ["cust_id", "cust_name", "cust_lat", "cust_lon"])

# Define Haversine as a UDF
@F.udf(DoubleType())
def haversine_km(lat1, lon1, lat2, lon2):
    """
    Compute the great-circle distance between two points
    on Earth using the Haversine formula.
    Returns distance in kilometers.
    """
    if any(v is None for v in [lat1, lon1, lat2, lon2]):
        return None

    R = 6371.0  # Earth radius in km

    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = (math.sin(dlat / 2) ** 2 +
         math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c

# Cross join and compute distance
pairs = customers.crossJoin(stores)
pairs = pairs.withColumn("distance_km",
    haversine_km("cust_lat", "cust_lon", "store_lat", "store_lon")
)

# Also compute distance in miles
MILES_PER_KM = 0.621371
pairs = pairs.withColumn("distance_miles",
    F.round(F.col("distance_km") * MILES_PER_KM, 2)
)

print("=== Distances (UDF approach) ===")
pairs.select("cust_id", "store_name",
             F.round("distance_km", 2).alias("km"),
             "distance_miles") \
    .orderBy("cust_id", "distance_km").show()

# Find stores within a radius
RADIUS_KM = 5.0
nearby = pairs.filter(F.col("distance_km") <= RADIUS_KM)

print(f"=== Stores within {RADIUS_KM} km ===")
nearby.select("cust_id", "cust_name", "store_name",
              F.round("distance_km", 2).alias("distance_km")) \
    .orderBy("cust_id", "distance_km").show()
```

## Method 3: Pandas UDF for Vectorized Performance

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import DoubleType
import pandas as pd
import numpy as np

spark = SparkSession.builder \
    .appName("HaversinePandasUDF") \
    .master("local[*]") \
    .getOrCreate()

stores_data = [
    ("S1", "Downtown", 40.7128, -74.0060),
    ("S2", "Midtown",  40.7549, -73.9840),
    ("S3", "Brooklyn", 40.6782, -73.9442),
    ("S4", "Queens",   40.7282, -73.7949),
]
stores = spark.createDataFrame(stores_data,
    ["store_id", "store_name", "store_lat", "store_lon"])

customers_data = [
    ("C1", "Alice", 40.7484, -73.9857),
    ("C2", "Bob",   40.6892, -73.9857),
    ("C3", "Carol", 40.7580, -73.8855),
]
customers = spark.createDataFrame(customers_data,
    ["cust_id", "cust_name", "cust_lat", "cust_lon"])

# Vectorized Pandas UDF for better performance at scale
@F.pandas_udf(DoubleType())
def haversine_vectorized(lat1: pd.Series, lon1: pd.Series,
                         lat2: pd.Series, lon2: pd.Series) -> pd.Series:
    """Vectorized Haversine using numpy for much better performance."""
    R = 6371.0

    lat1_r = np.radians(lat1)
    lat2_r = np.radians(lat2)
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)

    a = (np.sin(dlat / 2) ** 2 +
         np.cos(lat1_r) * np.cos(lat2_r) * np.sin(dlon / 2) ** 2)
    c = 2 * np.arctan2(np.sqrt(a), np.sqrt(1 - a))

    return pd.Series(R * c)

# Cross join and compute
pairs = customers.crossJoin(stores)
pairs = pairs.withColumn("distance_km",
    haversine_vectorized("cust_lat", "cust_lon", "store_lat", "store_lon")
)

print("=== Distances (Pandas UDF - vectorized) ===")
pairs.select("cust_id", "store_name",
             F.round("distance_km", 2).alias("distance_km")) \
    .orderBy("cust_id", "distance_km").show()

# ============================================================
# Bounding box pre-filter for optimization
# ============================================================
# At scale, cross join is expensive. Use a lat/lon bounding box
# to pre-filter before computing exact Haversine distances.

def add_bounding_box(df, lat_col, lon_col, radius_km):
    """Add bounding box columns to filter candidates before Haversine."""
    # 1 degree latitude ~ 111 km
    # 1 degree longitude ~ 111 * cos(latitude) km
    lat_delta = radius_km / 111.0
    lon_delta = radius_km / 85.0  # approximate for mid-latitudes

    return df \
        .withColumn("min_lat", F.col(lat_col) - lat_delta) \
        .withColumn("max_lat", F.col(lat_col) + lat_delta) \
        .withColumn("min_lon", F.col(lon_col) - lon_delta) \
        .withColumn("max_lon", F.col(lon_col) + lon_delta)

RADIUS = 10.0  # km
cust_bb = add_bounding_box(customers, "cust_lat", "cust_lon", RADIUS)

# Join with bounding box filter instead of full cross join
filtered_pairs = cust_bb.join(stores,
    (F.col("store_lat").between(F.col("min_lat"), F.col("max_lat"))) &
    (F.col("store_lon").between(F.col("min_lon"), F.col("max_lon")))
)

# Then compute exact distance only for candidates
filtered_pairs = filtered_pairs.withColumn("distance_km",
    haversine_vectorized("cust_lat", "cust_lon", "store_lat", "store_lon")
).filter(F.col("distance_km") <= RADIUS)

print(f"=== Stores within {RADIUS}km (with bounding box optimization) ===")
filtered_pairs.select("cust_id", "cust_name", "store_name",
                      F.round("distance_km", 2).alias("distance_km")) \
    .orderBy("cust_id", "distance_km").show()
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Haversine formula** | Computes great-circle distance on a sphere; accurate to ~0.5% for Earth |
| **Earth radius** | 6371 km (mean); use 6378 km for equatorial or 6357 km for polar |
| **Radians conversion** | All trig functions require radians, not degrees |
| **Cross join** | Generates all pairs; use bounding box pre-filter at scale |
| **Bounding box** | Rectangular lat/lon filter to reduce candidate pairs before exact computation |
| **Pandas UDF** | Vectorized computation with numpy is 10-100x faster than row-level UDFs |
| **Vincenty formula** | More accurate alternative (~0.5mm) but much more complex |

## Interview Tips

1. **Know the formula by heart**: Haversine is simple enough to write from memory. Key components: `sin^2(dlat/2)`, cosine product, `atan2(sqrt(a), sqrt(1-a))`, multiply by 2R.

2. **Performance at scale**: Never do a full cross join between millions of customers and thousands of stores. Use a bounding box filter or geohash bucketing first.

3. **UDF vs native**: Native PySpark math functions avoid serialization overhead and are preferred. Use Pandas UDFs when you need complex logic that native functions cannot express.

4. **Geohash alternative**: For very large datasets, convert lat/lon to geohash strings, join on geohash prefix, then compute exact distance for matches.

5. **Accuracy tradeoffs**: Haversine assumes a perfect sphere. For sub-meter accuracy, use the Vincenty formula. For most business applications, Haversine is more than sufficient.
