## PySpark Problem Types - Complete Cheat Sheet
### TABLE OF CONTENTS
	1.Ranking & Top-N Problems
	2.Running/Cumulative Calculations
	3.Time-Series & Gap Analysis
	4.Aggregation Patterns
	5.Join Strategies & Optimization
	6.Data Quality & Validation
	7.Column Transformations
	8.Complex Filtering & Conditions
	9.Performance Optimization Patterns
	10.Deduplication Strategies
	11.Pivoting & Reshaping
	12.Advanced Patterns (UDFs, Broadcast, Caching)

### 1. Ranking & Top-N Problems
#### Trigger Words
	- “top N”, “highest”, “lowest”, “rank”, “best performers”
	- “nth highest”, “per group”, “for each partition”

**Key Pattern**

from pyspark.sql import Window
from pyspark.sql.functions import row_number, rank, dense_rank

# Template: Top N per group
window_spec = Window.partitionBy("group_col").orderBy(F.col("value_col").desc())

df_ranked = df.withColumn("rank", row_number().over(window_spec))
df_top_n = df_ranked.filter(F.col("rank") <= N)


Function Choice Matrix



|Need                      |Use             |Result Example    |
|--------------------------|----------------|------------------|
|Unique ranks, skip on ties|`row_number()`  |1,2,3,4,5         |
|Unique ranks, no gaps     |`dense_rank()`  |1,2,2,3,4         |
|Allow ties, skip numbers  |`rank()`        |1,2,2,4,5         |
|Percentile ranking        |`percent_rank()`|0.0 to 1.0        |
|Divide into N buckets     |`ntile(N)`      |Quartiles, deciles|

Examples

from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Example 1: Top 3 salaries per department
window_spec = Window.partitionBy("department").orderBy(F.col("salary").desc())

df_top_salaries = (df
    .withColumn("rank", F.dense_rank().over(window_spec))
    .filter(F.col("rank") <= 3)
    .select("department", "employee_name", "salary", "rank")
)

# Example 2: Second highest salary (handle ties with dense_rank)
window_spec = Window.orderBy(F.col("salary").desc())

second_highest = (df
    .select(F.col("salary"))
    .distinct()
    .withColumn("rank", F.dense_rank().over(window_spec))
    .filter(F.col("rank") == 2)
    .select("salary")
    .first()
)

# Example 3: Top 10% of earners
window_spec = Window.orderBy(F.col("salary").desc())

df_top_10pct = (df
    .withColumn("decile", F.ntile(10).over(window_spec))
    .filter(F.col("decile") == 1)
)

# Example 4: Rank with multiple sorting criteria
window_spec = Window.partitionBy("department").orderBy(
    F.col("performance_score").desc(),
    F.col("tenure").desc()
)

df_ranked = df.withColumn("rank", F.row_number().over(window_spec))

# Example 5: Get rank and show ties
window_spec = Window.partitionBy("category").orderBy(F.col("sales").desc())

df_with_ranks = (df
    .withColumn("row_num", F.row_number().over(window_spec))
    .withColumn("rank", F.rank().over(window_spec))
    .withColumn("dense_rank", F.dense_rank().over(window_spec))
)


Common Pitfalls

# ❌ WRONG: Using limit() on grouped data
df.orderBy(F.col("salary").desc()).limit(3)  
# Only gives top 3 overall, not per group!

# ✅ CORRECT: Use window function
window_spec = Window.partitionBy("dept").orderBy(F.col("salary").desc())
df.withColumn("rn", F.row_number().over(window_spec)).filter(F.col("rn") <= 3)

# ❌ WRONG: Not handling ties properly
df.orderBy(F.col("score").desc()).limit(10)
# If 10th and 11th have same score, one is randomly excluded

# ✅ CORRECT: Use dense_rank or rank
window_spec = Window.orderBy(F.col("score").desc())
df.withColumn("rank", F.dense_rank().over(window_spec)).filter(F.col("rank") <= 10)


2. Running/Cumulative Calculations
Trigger Words
	∙	“running total”, “cumulative sum”, “rolling average”
	∙	“moving average”, “YTD”, “MTD”, “progressive”, “trailing”
Key Pattern

from pyspark.sql.window import Window
from pyspark.sql.functions import sum, avg

# Template: Running total
window_spec = Window.partitionBy("group").orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)

df_running = df.withColumn("running_total", F.sum("amount").over(window_spec))


Frame Specification Options

# Cumulative from start (running total)
Window.rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Moving average (last 7 rows)
Window.rowsBetween(-6, 0)

# Centered window (3 before, 3 after)
Window.rowsBetween(-3, 3)

# All rows in partition (no row specification)
Window.partitionBy("category")  # No orderBy = all rows


Examples

# Example 1: Running total by month
window_spec = Window.partitionBy("product_id").orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)

df_running = df.withColumn(
    "running_total", 
    F.sum("revenue").over(window_spec)
)

# Example 2: 7-day moving average
window_spec = Window.partitionBy("product_id").orderBy("date").rowsBetween(-6, 0)

df_moving_avg = df.withColumn(
    "moving_avg_7day",
    F.avg("sales").over(window_spec)
)

# Example 3: Running total with month reset
from pyspark.sql.functions import year, month

df_with_month = df.withColumn(
    "year_month", 
    F.concat(F.year("date"), F.lit("-"), F.month("date"))
)

window_spec = Window.partitionBy("product_id", "year_month").orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)

df_monthly_running = df_with_month.withColumn(
    "monthly_running_total",
    F.sum("amount").over(window_spec)
)

# Example 4: Difference from previous row
window_spec = Window.partitionBy("product").orderBy("date")

df_change = df.withColumn(
    "prev_value",
    F.lag("value", 1).over(window_spec)
).withColumn(
    "change",
    F.col("value") - F.col("prev_value")
).withColumn(
    "pct_change",
    F.when(F.col("prev_value").isNotNull(),
           (F.col("value") - F.col("prev_value")) / F.col("prev_value") * 100
    ).otherwise(None)
)

# Example 5: Cumulative distinct count
window_spec = Window.partitionBy("customer_id").orderBy("purchase_date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)

df_cumulative = df.withColumn(
    "cumulative_distinct_products",
    F.size(F.collect_set("product_id").over(window_spec))
)

# Example 6: Rolling sum with time-based window (use rangeBetween)
# Get sum of sales in last 7 days
window_spec = Window.partitionBy("store_id").orderBy(
    F.col("date").cast("long")
).rangeBetween(-7*24*60*60, 0)  # 7 days in seconds

df_rolling = df.withColumn(
    "sales_last_7_days",
    F.sum("sales").over(window_spec)
)


Quick Reference



|Need                   |Function      |Window Specification                                 |
|-----------------------|--------------|-----------------------------------------------------|
|Running total          |`sum()`       |`rowsBetween(unboundedPreceding, currentRow)`        |
|Moving average (N rows)|`avg()`       |`rowsBetween(-N+1, 0)`                               |
|Previous value         |`lag(col, 1)` |No frame needed                                      |
|Next value             |`lead(col, 1)`|No frame needed                                      |
|First in partition     |`first()`     |`rowsBetween(unboundedPreceding, unboundedFollowing)`|
|Last in partition      |`last()`      |`rowsBetween(unboundedPreceding, unboundedFollowing)`|

rowsBetween vs rangeBetween

# rowsBetween: Physical row positions
Window.orderBy("date").rowsBetween(-6, 0)  # Last 7 rows

# rangeBetween: Logical value ranges (for dates/timestamps)
Window.orderBy(F.col("date").cast("long")).rangeBetween(
    -7*24*60*60, 0  # Last 7 days in seconds
)

# When to use which:
# - rowsBetween: When you want exactly N rows (e.g., "last 10 transactions")
# - rangeBetween: When you want time-based windows (e.g., "last 7 days")


3. Time-Series & Gap Analysis
Trigger Words
	∙	“missing dates”, “gaps”, “fill missing”, “consecutive days”
	∙	“streak”, “continuous”, “interpolate”, “date series”
Key Pattern

from pyspark.sql.functions import expr, explode, sequence, to_date

# Template: Generate date series and find gaps
date_range = spark.sql("""
    SELECT explode(sequence(
        to_date('2024-01-01'), 
        to_date('2024-12-31'), 
        interval 1 day
    )) as date
""")

# Find gaps
gaps = date_range.join(df, "date", "left_anti")


Common Patterns

# Pattern 1: Generate complete date series
from pyspark.sql.functions import explode, sequence, to_date, lit

# Method 1: Using SQL sequence
date_series = spark.sql("""
    SELECT explode(sequence(
        to_date('2024-01-01'),
        to_date('2024-12-31'),
        interval 1 day
    )) as date
""")

# Method 2: Using DataFrame API
date_series = spark.range(1, 366).select(
    F.expr("date_add('2024-01-01', cast(id as int))").alias("date")
)

# Pattern 2: Fill missing dates with 0 values
complete_dates = date_series.join(df, "date", "left").fillna(0)

# Pattern 3: Identify consecutive date groups (islands)
window_spec = Window.partitionBy("user_id").orderBy("date")

df_islands = (df
    .withColumn("prev_date", F.lag("date").over(window_spec))
    .withColumn("days_diff", F.datediff("date", "prev_date"))
    .withColumn("is_new_island", 
                F.when((F.col("days_diff") > 1) | F.col("days_diff").isNull(), 1)
                .otherwise(0))
    .withColumn("island_id", F.sum("is_new_island").over(
        window_spec.rowsBetween(Window.unboundedPreceding, Window.currentRow)
    ))
)

# Group consecutive dates
islands_summary = (df_islands
    .groupBy("user_id", "island_id")
    .agg(
        F.min("date").alias("streak_start"),
        F.max("date").alias("streak_end"),
        F.count("*").alias("streak_days")
    )
)


Examples

# Example 1: Find missing transaction IDs
from pyspark.sql.functions import expr, col

max_id = df.agg(F.max("transaction_id")).first()[0]
all_ids = spark.range(1, max_id + 1).select(F.col("id").alias("transaction_id"))

missing_ids = all_ids.join(df, "transaction_id", "left_anti")

# Example 2: Consecutive login streak
window_spec = Window.partitionBy("user_id").orderBy("login_date")

login_streaks = (df
    .select("user_id", F.to_date("login_timestamp").alias("login_date"))
    .distinct()
    .withColumn("row_num", F.row_number().over(window_spec))
    .withColumn("date_diff", 
                F.datediff("login_date", 
                          F.expr("date_add(login_date, -row_num)")))
    .groupBy("user_id", "date_diff")
    .agg(
        F.min("login_date").alias("streak_start"),
        F.max("login_date").alias("streak_end"),
        F.count("*").alias("streak_days")
    )
    .filter(F.col("streak_days") >= 7)  # 7+ day streaks
)

# Example 3: Fill gaps in sensor data with interpolation
window_spec = Window.partitionBy("sensor_id").orderBy("timestamp")

df_with_prev_next = (df
    .withColumn("prev_value", F.lag("temperature").over(window_spec))
    .withColumn("prev_time", F.lag("timestamp").over(window_spec))
    .withColumn("next_value", F.lead("temperature").over(window_spec))
    .withColumn("next_time", F.lead("timestamp").over(window_spec))
)

# Linear interpolation for missing values
df_interpolated = df_with_prev_next.withColumn(
    "interpolated_temp",
    F.when(F.col("temperature").isNotNull(), F.col("temperature"))
    .otherwise(
        F.col("prev_value") + 
        (F.col("next_value") - F.col("prev_value")) * 
        (F.unix_timestamp("timestamp") - F.unix_timestamp("prev_time")) /
        (F.unix_timestamp("next_time") - F.unix_timestamp("prev_time"))
    )
)

# Example 4: Detect gaps > threshold
window_spec = Window.partitionBy("device_id").orderBy("event_time")

gaps = (df
    .withColumn("next_event", F.lead("event_time").over(window_spec))
    .withColumn("gap_seconds", 
                F.unix_timestamp("next_event") - F.unix_timestamp("event_time"))
    .filter(F.col("gap_seconds") > 3600)  # Gaps > 1 hour
    .select("device_id", "event_time", "next_event", "gap_seconds")
)


4. Aggregation Patterns
Trigger Words
	∙	“total”, “count”, “average”, “sum”, “group by”
	∙	“per category”, “aggregate”, “summary”, “breakdown”
Key Patterns

# Pattern 1: Simple aggregation
df.groupBy("category").agg(
    F.count("*").alias("count"),
    F.sum("amount").alias("total"),
    F.avg("price").alias("avg_price")
)

# Pattern 2: Multiple aggregations on same column
df.groupBy("dept").agg(
    F.min("salary").alias("min_salary"),
    F.max("salary").alias("max_salary"),
    F.avg("salary").alias("avg_salary"),
    F.stddev("salary").alias("stddev_salary")
)

# Pattern 3: Conditional aggregation
df.groupBy("region").agg(
    F.sum(F.when(F.col("type") == "A", F.col("amount")).otherwise(0)).alias("type_a_total"),
    F.sum(F.when(F.col("type") == "B", F.col("amount")).otherwise(0)).alias("type_b_total")
)


Examples

# Example 1: Group by with multiple columns
sales_summary = df.groupBy("region", "product_category", "year").agg(
    F.sum("sales").alias("total_sales"),
    F.avg("sales").alias("avg_sales"),
    F.count("transaction_id").alias("num_transactions"),
    F.countDistinct("customer_id").alias("unique_customers")
)

# Example 2: Conditional aggregation (CASE WHEN equivalent)
df.groupBy("department").agg(
    F.count("*").alias("total_employees"),
    F.sum(F.when(F.col("salary") > 100000, 1).otherwise(0)).alias("high_earners"),
    F.sum(F.when(F.col("tenure") > 5, 1).otherwise(0)).alias("veterans"),
    F.avg(F.when(F.col("performance") == "Excellent", 
                 F.col("salary"))).alias("avg_salary_top_performers")
)

# Example 3: Collect list/set
df.groupBy("customer_id").agg(
    F.collect_list("product").alias("all_products"),
    F.collect_set("product").alias("unique_products"),
    F.count("*").alias("purchase_count")
)

# Example 4: First/Last value in group
window_spec = Window.partitionBy("customer_id").orderBy("purchase_date")

df_first_last = df.withColumn(
    "first_purchase",
    F.first("product").over(window_spec)
).withColumn(
    "last_purchase",
    F.last("product").over(window_spec)
)

# Example 5: Percentiles and quantiles
df.groupBy("category").agg(
    F.expr("percentile_approx(price, 0.5)").alias("median_price"),
    F.expr("percentile_approx(price, array(0.25, 0.5, 0.75))").alias("quartiles")
)

# Example 6: Multiple aggregations with different filters
df.groupBy("store_id").agg(
    # Total sales
    F.sum("sales").alias("total_sales"),
    
    # Sales by payment type
    F.sum(F.when(F.col("payment_type") == "cash", 
                 F.col("sales")).otherwise(0)).alias("cash_sales"),
    F.sum(F.when(F.col("payment_type") == "card", 
                 F.col("sales")).otherwise(0)).alias("card_sales"),
    
    # Average by customer segment
    F.avg(F.when(F.col("segment") == "premium", 
                 F.col("sales"))).alias("avg_premium_sale"),
    
    # Count distinct
    F.countDistinct("customer_id").alias("unique_customers")
)

# Example 7: Aggregation with filtering (HAVING equivalent)
high_volume_products = (df
    .groupBy("product_id")
    .agg(F.sum("quantity").alias("total_quantity"))
    .filter(F.col("total_quantity") > 1000)
)


Advanced Aggregation Functions

# Statistical aggregations
df.groupBy("category").agg(
    F.mean("price").alias("mean"),
    F.stddev("price").alias("stddev"),
    F.variance("price").alias("variance"),
    F.skewness("price").alias("skewness"),
    F.kurtosis("price").alias("kurtosis")
)

# Approximate aggregations (faster for large datasets)
df.groupBy("user_id").agg(
    F.approx_count_distinct("product_id", rsd=0.05).alias("approx_unique_products"),
    F.expr("percentile_approx(price, 0.5, 100)").alias("median_price")  # 100 = accuracy
)


5. Join Strategies & Optimization
Trigger Words
	∙	“combine”, “merge”, “match”, “lookup”, “enrich”
	∙	“left/right/inner/outer join”, “anti-join”, “semi-join”
Join Types

# Inner Join (only matching records)
df1.join(df2, "key", "inner")

# Left Join (all from left + matches from right)
df1.join(df2, "key", "left")

# Right Join (all from right + matches from left)
df1.join(df2, "key", "right")

# Full Outer Join (all records from both)
df1.join(df2, "key", "outer")

# Left Semi Join (like EXISTS - only left columns, where match exists)
df1.join(df2, "key", "left_semi")

# Left Anti Join (like NOT EXISTS - only left columns, where no match)
df1.join(df2, "key", "left_anti")

# Cross Join (Cartesian product)
df1.crossJoin(df2)


Join Optimization Patterns

# Pattern 1: Broadcast Join (for small tables)
from pyspark.sql.functions import broadcast

# When right table < 10MB (or configured threshold)
df_large.join(broadcast(df_small), "key")

# Pattern 2: Multiple conditions
df1.join(df2, 
    (df1.customer_id == df2.customer_id) & 
    (df1.date == df2.date),
    "inner"
)

# Pattern 3: Join with column renaming (avoid ambiguity)
df1.join(
    df2.withColumnRenamed("id", "customer_id"),
    df1.id == df2.customer_id,
    "left"
).drop(df2.customer_id)

# Pattern 4: Self-join
df.alias("a").join(
    df.alias("b"),
    (F.col("a.id") != F.col("b.id")) & 
    (F.col("a.category") == F.col("b.category")),
    "inner"
)


Examples

# Example 1: Enrich orders with customer data
orders_enriched = (orders
    .join(customers, "customer_id", "left")
    .select(
        orders["*"],
        customers["customer_name"],
        customers["email"],
        customers["segment"]
    )
)

# Example 2: Find customers with no orders (anti-join)
customers_no_orders = customers.join(
    orders, 
    "customer_id", 
    "left_anti"
)

# Example 3: Find customers with orders (semi-join)
active_customers = customers.join(
    orders,
    "customer_id",
    "left_semi"
)

# Example 4: Self-join to find pairs
product_pairs = (df.alias("a")
    .join(
        df.alias("b"),
        (F.col("a.transaction_id") == F.col("b.transaction_id")) &
        (F.col("a.product_id") < F.col("b.product_id")),  # Avoid duplicates
        "inner"
    )
    .select(
        F.col("a.product_id").alias("product_1"),
        F.col("b.product_id").alias("product_2"),
        F.col("a.transaction_id")
    )
)

# Example 5: Join with date range condition
df_events.join(
    df_campaigns,
    (df_events.user_id == df_campaigns.user_id) &
    (df_events.event_date >= df_campaigns.start_date) &
    (df_events.event_date <= df_campaigns.end_date),
    "inner"
)

# Example 6: Broadcast join for lookup enrichment
from pyspark.sql.functions import broadcast

# Product catalog is small (1000 products)
# Transactions is large (1B rows)
transactions_with_product_info = (transactions
    .join(
        broadcast(product_catalog),
        "product_id",
        "left"
    )
)

# Example 7: Multiple table joins
result = (orders
    .join(customers, "customer_id", "left")
    .join(products, "product_id", "left")
    .join(regions, orders.region_id == regions.id, "left")
    .select(
        orders["order_id"],
        customers["customer_name"],
        products["product_name"],
        regions["region_name"],
        orders["amount"]
    )
)


Join Performance Checklist



|Do                                       |Don’t                                            |
|-----------------------------------------|-------------------------------------------------|
|✅ Use broadcast for small tables (< 10MB)|❌ Join without filtering large tables            |
|✅ Filter before joining                  |❌ Use cross join accidentally (missing condition)|
|✅ Select only needed columns before join |❌ Keep all columns from both tables              |
|✅ Use appropriate join type              |❌ Use outer join when inner join suffices        |

6. Data Quality & Validation
Trigger Words
	∙	“validate”, “check quality”, “null values”, “duplicates”
	∙	“data profiling”, “schema validation”, “outliers”
Validation Patterns

# Pattern 1: Null checks
null_counts = df.select([
    F.count(F.when(F.col(c).isNull(), c)).alias(c)
    for c in df.columns
])

# Pattern 2: Duplicate detection
duplicates = df.groupBy("id").count().filter(F.col("count") > 1)

# Pattern 3: Range validation
invalid_values = df.filter(
    (F.col("age") < 0) | 
    (F.col("age") > 120) |
    (F.col("salary") < 0)
)


Comprehensive Examples

# Example 1: Complete data quality report
def data_quality_report(df):
    """Generate comprehensive DQ report"""
    
    total_rows = df.count()
    
    # Null counts per column
    null_counts = df.select([
        (F.count(F.when(F.col(c).isNull(), c)) / total_rows * 100).alias(f"{c}_null_pct")
        for c in df.columns
    ]).first().asDict()
    
    # Distinct counts
    distinct_counts = df.select([
        F.approx_count_distinct(c).alias(f"{c}_distinct")
        for c in df.columns
    ]).first().asDict()
    
    # Data types
    schema_info = {field.name: str(field.dataType) for field in df.schema.fields}
    
    return {
        "total_rows": total_rows,
        "null_percentages": null_counts,
        "distinct_counts": distinct_counts,
        "schema": schema_info
    }

# Example 2: Detect outliers using IQR method
from pyspark.sql.functions import expr

outliers_df = df.select(
    "*",
    F.expr("percentile_approx(price, 0.25)").over().alias("q1"),
    F.expr("percentile_approx(price, 0.75)").over().alias("q3")
).withColumn(
    "iqr",
    F.col("q3") - F.col("q1")
).withColumn(
    "lower_bound",
    F.col("q1") - 1.5 * F.col("iqr")
).withColumn(
    "upper_bound",
    F.col("q3") + 1.5 * F.col("iqr")
).filter(
    (F.col("price") < F.col("lower_bound")) |
    (F.col("price") > F.col("upper_bound"))
)

# Example 3: Schema validation
from pyspark.sql.types import StructType, StructField, IntegerType, StringType

expected_schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("email", StringType(), True),
    StructField("age", IntegerType(), True)
])

def validate_schema(df, expected_schema):
    """Validate DataFrame schema against expected"""
    issues = []
    
    # Check column names
    expected_cols = set([f.name for f in expected_schema.fields])
    actual_cols = set(df.columns)
    
    missing = expected_cols - actual_cols
    extra = actual_cols - expected_cols
    
    if missing:
        issues.append(f"Missing columns: {missing}")
    if extra:
        issues.append(f"Extra columns: {extra}")
    
    # Check data types
    for field in expected_schema.fields:
        if field.name in df.columns:
            actual_type = dict(df.dtypes)[field.name]
            expected_type = str(field.dataType).lower()
            if actual_type != expected_type:
                issues.append(
                    f"Column {field.name}: expected {expected_type}, got {actual_type}"
                )
    
    return issues

# Example 4: Pattern validation (regex)
invalid_emails = df.filter(
    ~F.col("email").rlike(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
)

invalid_phone = df.filter(
    ~F.col("phone").rlike(r'^\d{3}-\d{3}-\d{4}$')
)

# Example 5: Referential integrity check
orphaned_records = df_orders.join(
    df_customers,
    df_orders.customer_id == df_customers.customer_id,
    "left_anti"  # Orders with no matching customer
)

# Example 6: Duplicate detection with details
duplicates_detailed = (df
    .groupBy("email", "phone")
    .agg(
        F.count("*").alias("count"),
        F.collect_list("user_id").alias("duplicate_ids"),
        F.min("created_date").alias("first_created"),
        F.max("created_date").alias("last_created")
    )
    .filter(F.col("count") > 1)
    .orderBy(F.col("count").desc())
)

# Example 7: Cross-field validation
invalid_combinations = df.filter(
    (F.col("end_date") < F.col("start_date")) |
    (F.col("discounted_price") > F.col("original_price")) |
    ((F.col("status") == "shipped") & (F.col("shipped_date").isNull()))
)


Validation Framework Template

class DataValidator:
    def __init__(self, df):
        self.df = df
        self.errors = []
    
    def check_nulls(self, columns, threshold=0.1):
        """Check if null % exceeds threshold"""
        total = self.df.count()
        for col in columns:
            null_count = self.df.filter(F.col(col).isNull()).count()
            null_pct = null_count / total
            if null_pct > threshold:
                self.errors.append(
                    f"{col}: {null_pct*100:.2f}% nulls (threshold: {threshold*100}%)"
                )
    
    def check_duplicates(self, key_columns):
        """Check for duplicate keys"""
        dup_count = (self.df
            .groupBy(key_columns)
            .count()
            .filter(F.col("count") > 1)
            .count()
        )
        if dup_count > 0:
            self.errors.append(f"Found {dup_count} duplicate keys on {key_columns}")
    
    def check_range(self, column, min_val=None, max_val=None):
        """Check if values are within range"""
        if min_val is not None:
            invalid = self.df.filter(F.col(column) < min_val).count()
            if invalid > 0:
                self.errors.append(f"{column}: {invalid} values below {min_val}")
        
        if max_val is not None:
            invalid = self.df.filter(F.col(column) > max_val).count()
            if invalid > 0:
                self.errors.append(f"{column}: {invalid} values above {max_val}")
    
    def check_referential_integrity(self, ref_df, key_column):
        """Check foreign key integrity"""
        orphaned = self.df.join(ref_df, key_column, "left_anti").count()
        if orphaned > 0:
            self.errors.append(
                f"Found {orphaned} orphaned records (no matching {key_column})"
            )
    
    def get_report(self):
        """Return validation report"""
        if self.errors:
            return {"status": "FAILED", "errors": self.errors}
        else:
            return {"status": "PASSED", "errors": []}

# Usage
validator = DataValidator(df)
validator.check_nulls(["customer_id", "order_date"], threshold=0.05)
validator.check_duplicates(["order_id"])
validator.check_range("age", min_val=0, max_val=120)
validator.check_referential_integrity(customers_df, "customer_id")
report = validator.get_report()


7. Column Transformations
Trigger Words
	∙	“add column”, “transform”, “calculate”, “derive”
	∙	“convert”, “parse”, “extract”, “split”, “concat”
Common Transformations

# Pattern 1: Simple column operations
df.withColumn("new_col", F.col("existing_col") * 2)

# Pattern 2: Conditional logic
df.withColumn(
    "category",
    F.when(F.col("value") > 100, "High")
    .when(F.col("value") > 50, "Medium")
    .otherwise("Low")
)

# Pattern 3: String operations
df.withColumn("upper_name", F.upper(F.col("name")))
  .withColumn("email_domain", F.split(F.col("email"), "@").getItem(1))

# Pattern 4: Date operations
df.withColumn("year", F.year(F.col("date")))
  .withColumn("month", F.month(F.col("date")))
  .withColumn("day_of_week", F.dayofweek(F.col("date")))


Examples

# Example 1: Complex conditional logic
df_categorized = df.withColumn(
    "risk_category",
    F.when((F.col("age") < 25) & (F.col("income") < 30000), "High Risk")
    .when((F.col("age") >= 25) & (F.col("age") < 40) & 
          (F.col("credit_score") > 700), "Low Risk")
    .when(F.col("credit_score") < 600, "High Risk")
    .otherwise("Medium Risk")
)

# Example 2: String parsing and extraction
df_parsed = df.withColumn(
    "first_name",
    F.split(F.col("full_name"), " ").getItem(0)
).withColumn(
    "last_name",
    F.split(F.col("full_name"), " ").getItem(1)
).withColumn(
    "email_domain",
    F.regexp_extract(F.col("email"), r'@(.+)$', 1)
).withColumn(
    "phone_cleaned",
    F.regexp_replace(F.col("phone"), r'[^\d]', '')
)

# Example 3: Date transformations
df_dates = df.withColumn(
    "order_date",
    F.to_date(F.col("order_timestamp"))
).withColumn(
    "order_year",
    F.year(F.col("order_timestamp"))
).withColumn(
    "order_month",
    F.month(F.col("order_timestamp"))
).withColumn(
    "order_quarter",
    F.quarter(F.col("order_timestamp"))
).withColumn(
    "days_since_order",
    F.datediff(F.current_date(), F.col("order_date"))
).withColumn(
    "is_weekend",
    F.dayofweek(F.col("order_date")).isin([1, 7])  # Sunday=1, Saturday=7
)

# Example 4: Array and struct operations
df_array = df.withColumn(
    "tags_array",
    F.split(F.col("tags"), ",")
).withColumn(
    "num_tags",
    F.size(F.col("tags_array"))
).withColumn(
    "has_tag_premium",
    F.array_contains(F.col("tags_array"), "premium")
)

# Example 5: JSON parsing
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

json_schema = StructType([
    StructField("name", StringType()),
    StructField("age", IntegerType())
])

df_json = df.withColumn(
    "parsed_json",
    F.from_json(F.col("json_string"), json_schema)
).withColumn(
    "name",
    F.col("parsed_json.name")
).withColumn(
    "age",
    F.col("parsed_json.age")
)

# Example 6: Multiple column transformations
df_transformed = (df
    .withColumn("amount_usd", F.col("amount") * F.col("exchange_rate"))
    .withColumn("amount_rounded", F.round(F.col("amount_usd"), 2))
    .withColumn("amount_category", 
        F.when(F.col("amount_usd") > 1000, "Large")
        .when(F.col("amount_usd") > 100, "Medium")
        .otherwise("Small")
    )
    .withColumn("log_amount", F.log(F.col("amount_usd")))
)

# Example 7: Type casting
df_casted = df.withColumn(
    "price_decimal",
    F.col("price").cast("decimal(10,2)")
).withColumn(
    "quantity_int",
    F.col("quantity").cast("integer")
).withColumn(
    "timestamp_ts",
    F.col("timestamp_string").cast("timestamp")
)


String Function Quick Reference

# Concatenation
F.concat(F.col("first"), F.lit(" "), F.col("last"))
F.concat_ws("|", F.col("a"), F.col("b"), F.col("c"))

# Case conversion
F.upper(F.col("text"))
F.lower(F.col("text"))
F.initcap(F.col("text"))  # Title Case

# Trimming
F.trim(F.col("text"))
F.ltrim(F.col("text"))
F.rtrim(F.col("text"))

# Substrings
F.substring(F.col("text"), 1, 5)  # Position 1, length 5
F.substr(F.col("text"), 1, 5)     # Same as above

# Replacement
F.regexp_replace(F.col("text"), r'pattern', 'replacement')
F.translate(F.col("text"), "abc", "123")  # Character-level replacement

# Extraction
F.regexp_extract(F.col("text"), r'pattern', 1)  # Extract group 1

# Length
F.length(F.col("text"))

# Padding
F.lpad(F.col("text"), 10, "0")  # Left pad to length 10 with '0'
F.rpad(F.col("text"), 10, " ")  # Right pad


8. Complex Filtering & Conditions
Trigger Words
	∙	“filter”, “where”, “exclude”, “only”, “remove”
	∙	“condition”, “criteria”, “matching”, “satisfying”
Filtering Patterns

# Pattern 1: Simple conditions
df.filter(F.col("age") > 18)
df.filter((F.col("age") > 18) & (F.col("country") == "US"))

# Pattern 2: IN operator
df.filter(F.col("status").isin(["active", "pending"]))

# Pattern 3: NOT conditions
df.filter(~F.col("status").isin(["cancelled", "rejected"]))
df.filter(F.col("email").isNotNull())

# Pattern 4: String matching
df.filter(F.col("name").like("%smith%"))
df.filter(F.col("email").rlike(r'^[a-z]+@example\.com$'))


Examples

# Example 1: Multiple AND conditions
filtered = df.filter(
    (F.col("age") >= 18) &
    (F.col("age") <= 65) &
    (F.col("income") > 30000) &
    (F.col("credit_score") > 650)
)

# Example 2: OR conditions
high_value_customers = df.filter(
    (F.col("lifetime_value") > 10000) |
    ((F.col("recent_purchases") > 5) & (F.col("avg_purchase") > 500))
)

# Example 3: Complex nested conditions
eligible_users = df.filter(
    (
        (F.col("account_type") == "premium") &
        (F.col("active_days") > 30)
    ) |
    (
        (F.col("account_type") == "free") &
        (F.col("referrals") > 10)
    )
)

# Example 4: Date range filtering
recent_orders = df.filter(
    (F.col("order_date") >= F.lit("2024-01-01")) &
    (F.col("order_date") < F.lit("2024-02-01"))
)

# Or using between
recent_orders = df.filter(
    F.col("order_date").between("2024-01-01", "2024-01-31")
)

# Example 5: Null/Not Null filtering
# Only non-null emails
valid_contacts = df.filter(F.col("email").isNotNull())

# Either phone OR email exists
contactable = df.filter(
    F.col("email").isNotNull() | F.col("phone").isNotNull()
)

# Example 6: String pattern matching
# Emails from specific domains
company_emails = df.filter(
    F.col("email").rlike(r'@(company\.com|subsidiary\.com)$')
)

# Names starting with 'A'
a_names = df.filter(F.col("name").startswith("A"))

# Contains substring
df.filter(F.col("description").contains("special offer"))

# Example 7: Array/Collection filtering
# Has any of these tags
tagged_posts = df.filter(
    F.array_contains(F.col("tags"), "urgent") |
    F.array_contains(F.col("tags"), "important")
)

# Array overlap
from pyspark.sql.functions import array_intersect

df.filter(
    F.size(F.array_intersect(
        F.col("user_interests"),
        F.array(F.lit("tech"), F.lit("science"))
    )) > 0
)

# Example 8: Anti-pattern filtering (exclude matches)
# Customers who never purchased
non_purchasers = customers.join(
    orders,
    "customer_id",
    "left_anti"
)

# Example 9: Filtering with aggregates (requires subquery/window)
# Orders above category average
window_spec = Window.partitionBy("category")

above_avg_orders = (df
    .withColumn("category_avg", F.avg("amount").over(window_spec))
    .filter(F.col("amount") > F.col("category_avg"))
)

# Example 10: Case-insensitive filtering
df.filter(F.lower(F.col("status")) == "active")


9. Performance Optimization Patterns
Key Optimization Strategies

# 1. CACHING - For DataFrames used multiple times
df.cache()  # or df.persist()
# ... use df multiple times
df.unpersist()

# 2. BROADCAST - For small lookup tables
from pyspark.sql.functions import broadcast
large_df.join(broadcast(small_df), "key")

# 3. PARTITIONING - Distribute data evenly
df.repartition(200, "customer_id")  # 200 partitions by customer_id
df.coalesce(10)  # Reduce to 10 partitions (no shuffle)

# 4. FILTER EARLY - Before expensive operations
df.filter(F.col("date") >= "2024-01-01") \  # Filter first
  .join(other_df, "key") \                  # Then join
  .groupBy("category").agg(...)             # Then aggregate

# 5. SELECT ONLY NEEDED COLUMNS
df.select("id", "name", "amount")  # Not df.select("*")


Examples

# Example 1: Optimize multiple aggregations
# ❌ BAD: Multiple passes
count1 = df.filter(F.col("type") == "A").count()
count2 = df.filter(F.col("type") == "B").count()
count3 = df.filter(F.col("type") == "C").count()

# ✅ GOOD: Single pass
result = df.groupBy("type").count().collect()
counts = {row['type']: row['count'] for row in result}

# Example 2: Cache strategically
# ❌ BAD: Cache too early
df_cached = df.cache()
df_filtered = df_cached.filter(F.col("active") == True)  # Only 1% of data

# ✅ GOOD: Cache after filtering
df_filtered = df.filter(F.col("active") == True).cache()
# Now df_filtered is smaller and cached

# Example 3: Broadcast join
# Small dimension table (1000 rows)
# Large fact table (1B rows)

# ✅ GOOD: Broadcast small table
result = large_fact.join(broadcast(small_dim), "id")

# Example 4: Repartition for better parallelism
# ❌ BAD: Too few partitions for large dataset
df_few_partitions = df.coalesce(4)  # Only 4 tasks for 1TB data!

# ✅ GOOD: More partitions for large data
df_optimized = df.repartition(200)  # 200 parallel tasks

# Example 5: Avoid UDFs when possible
# ❌ SLOW: Python UDF
from pyspark.sql.types import StringType

def categorize_udf(value):
    if value > 100: return "High"
    elif value > 50: return "Medium"
    else: return "Low"

categorize = F.udf(categorize_udf, StringType())
df.withColumn("category", categorize(F.col("value")))

# ✅ FAST: Built-in functions
df.withColumn(
    "category",
    F.when(F.col("value") > 100, "High")
    .when(F.col("value") > 50, "Medium")
    .otherwise("Low")
)

# Example 6: Partition pruning
# ❌ BAD: Scans all partitions
df_partitioned.filter(F.col("amount") > 100)

# ✅ GOOD: Filter on partition column first
df_partitioned.filter(
    (F.col("date") == "2024-01-01") &  # Partition column
    (F.col("amount") > 100)
)

# Example 7: Avoid collect() on large datasets
# ❌ BAD: Brings all data to driver
all_data = df.collect()  # OOM if df is large!

# ✅ GOOD: Aggregate first or use iterators
summary = df.agg(F.sum("amount")).collect()  # Small result
# Or
for row in df.toLocalIterator():  # Process one partition at a time
    process(row)

# Example 8: Use approx functions for large datasets
# ❌ SLOW: Exact count distinct
exact_count = df.select(F.countDistinct("user_id")).collect()

# ✅ FAST: Approximate count distinct (faster, 95% accurate)
approx_count = df.select(F.approx_count_distinct("user_id", rsd=0.05)).collect()


Performance Checklist
✅ DO:
	1.	Cache only filtered/processed data
	2.	Broadcast small tables in joins
	3.	Filter before joins and aggregations
	4.	Select only needed columns
	5.	Use built-in functions over UDFs
	6.	Partition data appropriately (100-1000 partitions)
	7.	Use approx functions for aggregations
	8.	Persist intermediate results used multiple times
❌ DON’T:
	1.	Cache entire large datasets unnecessarily
	2.	Use collect() on large DataFrames
	3.	Create too many or too few partitions
	4.	Use Python UDFs when SQL functions work
	5.	Join without considering table sizes
	6.	Process data row-by-row (use batch operations)
	7.	Ignore data skew
	8.	Chain many operations without caching intermediate results

10. Deduplication Strategies
Trigger Words
	∙	“remove duplicates”, “unique”, “distinct”, “deduplicate”
	∙	“keep first/last”, “primary key”, “eliminate duplicates”
Deduplication Patterns

# Pattern 1: Simple distinct
df.distinct()

# Pattern 2: Distinct on specific columns
df.dropDuplicates(["email"])

# Pattern 3: Keep first/last based on criteria
window_spec = Window.partitionBy("email").orderBy(F.col("created_date").desc())
df.withColumn("rn", F.row_number().over(window_spec)) \
  .filter(F.col("rn") == 1) \
  .drop("rn")


Examples

# Example 1: Remove complete duplicates
df_unique = df.distinct()

# Example 2: Remove duplicates based on key columns
# Keep first occurrence
df_deduped = df.dropDuplicates(["customer_id", "order_id"])

# Example 3: Keep most recent record
window_spec = Window.partitionBy("customer_id").orderBy(F.col("updated_at").desc())

df_latest = (df
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn")
)

# Example 4: Keep record with most complete data
# Priority: non-null email > non-null phone > most recent
window_spec = Window.partitionBy("customer_id").orderBy(
    F.col("email").isNull().asc(),  # Non-null first
    F.col("phone").isNull().asc(),  # Then non-null phone
    F.col("created_date").desc()    # Then most recent
)

df_best = (df
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn")
)

# Example 5: Merge duplicate records (consolidate)
# Take non-null value from any duplicate
df_merged = df.groupBy("customer_id").agg(
    F.max("name").alias("name"),        # Take any non-null
    F.max("email").alias("email"),
    F.max("phone").alias("phone"),
    F.min("created_date").alias("created_date"),  # Earliest
    F.max("updated_date").alias("updated_date")   # Latest
)

# Example 6: Find duplicate records (for analysis)
duplicates = (df
    .groupBy("email")
    .agg(
        F.count("*").alias("count"),
        F.collect_list("customer_id").alias("duplicate_ids")
    )
    .filter(F.col("count") > 1)
    .orderBy(F.col("count").desc())
)

# Example 7: Remove duplicates keeping max value
window_spec = Window.partitionBy("product_id").orderBy(F.col("price").desc())

df_highest_price = (df
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn")
)

# Example 8: Fuzzy deduplication (similar records)
from pyspark.sql.functions import levenshtein

# Find records with similar names
df_similarity = df.alias("a").join(
    df.alias("b"),
    (F.col("a.id") < F.col("b.id")) &  # Avoid comparing same record twice
    (F.levenshtein(F.col("a.name"), F.col("b.name")) <= 3),  # Edit distance <= 3
    "inner"
).select(
    F.col("a.id").alias("id_1"),
    F.col("b.id").alias("id_2"),
    F.col("a.name").alias("name_1"),
    F.col("b.name").alias("name_2"),
    F.levenshtein(F.col("a.name"), F.col("b.name")).alias("edit_distance")
)


11. Pivoting & Reshaping
Trigger Words
	∙	“pivot”, “unpivot”, “wide to long”, “long to wide”
	∙	“transpose”, “crosstab”, “reshape”
Pivot Patterns

# Pattern 1: Pivot (long to wide)
df.groupBy("row_id").pivot("category").agg(F.sum("value"))

# Pattern 2: Unpivot (wide to long) - using stack
df.selectExpr(
    "id",
    "stack(3, 'col1', col1, 'col2', col2, 'col3', col3) as (metric, value)"
)


Examples

# Example 1: Pivot sales by month
# Input: product, month, sales
# Output: product, Jan, Feb, Mar, ...

df_pivoted = (df
    .groupBy("product")
    .pivot("month")  # Creates columns for each month
    .agg(F.sum("sales"))
)

# Example 2: Pivot with multiple aggregations
df_pivoted = (df
    .groupBy("region")
    .pivot("quarter")
    .agg(
        F.sum("revenue").alias("total_revenue"),
        F.avg("price").alias("avg_price")
    )
)

# Example 3: Unpivot (wide to long)
# Input: product, Q1_sales, Q2_sales, Q3_sales, Q4_sales
# Output: product, quarter, sales

df_unpivoted = df.selectExpr(
    "product",
    "stack(4, " +
    "'Q1', Q1_sales, " +
    "'Q2', Q2_sales, " +
    "'Q3', Q3_sales, " +
    "'Q4', Q4_sales" +
    ") as (quarter, sales)"
)

# Example 4: Dynamic unpivot (all columns except id)
from pyspark.sql.functions import expr

value_cols = [c for c in df.columns if c not in ['id', 'name']]
stack_expr = f"stack({len(value_cols)}, " + \
             ", ".join([f"'{c}', {c}" for c in value_cols]) + \
             ") as (metric, value)"

df_unpivoted = df.selectExpr("id", "name", stack_expr)

# Example 5: Pivot with specific values
df_pivoted = (df
    .groupBy("employee")
    .pivot("skill", ["Python", "SQL", "Spark"])  # Only these values
    .agg(F.max("proficiency"))
)

# Example 6: Conditional pivot
df_pivoted = (df
    .groupBy("product")
    .pivot("region")
    .agg(
        F.sum(F.when(F.col("status") == "completed", 
                     F.col("amount")).otherwise(0)).alias("completed_sales"),
        F.sum(F.when(F.col("status") == "pending", 
                     F.col("amount")).otherwise(0)).alias("pending_sales")
    )
)


12. Advanced Patterns (UDFs, Broadcast, Caching)
UDF Patterns

# Pattern 1: Simple UDF
from pyspark.sql.types import StringType

def categorize(value):
    if value > 100: return "High"
    elif value > 50: return "Medium"
    return "Low"

categorize_udf = F.udf(categorize, StringType())
df.withColumn("category", categorize_udf(F.col("amount")))

# Pattern 2: Pandas UDF (vectorized, much faster)
from pyspark.sql.functions import pandas_udf
import pandas as pd

@pandas_udf(StringType())
def categorize_pandas(amounts: pd.Series) -> pd.Series:
    return pd.cut(amounts, bins=[0, 50, 100, float('inf')], 
                  labels=['Low', 'Medium', 'High'])

df.withColumn("category", categorize_pandas(F.col("amount")))


Examples

# Example 1: Python UDF for complex logic
from pyspark.sql.types import FloatType

def complex_calculation(a, b, c):
    # Complex business logic that can't be expressed with built-in functions
    import math
    return math.sqrt(a**2 + b**2) / c if c != 0 else None

calc_udf = F.udf(complex_calculation, FloatType())
df.withColumn("result", calc_udf(F.col("a"), F.col("b"), F.col("c")))

# Example 2: Pandas UDF for better performance
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import DoubleType
import pandas as pd
import numpy as np

@pandas_udf(DoubleType())
def vectorized_calculation(a: pd.Series, b: pd.Series, c: pd.Series) -> pd.Series:
    return np.sqrt(a**2 + b**2) / c.replace(0, np.nan)

df.withColumn("result", vectorized_calculation(F.col("a"), F.col("b"), F.col("c")))

# Example 3: Struct return type UDF
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

schema = StructType([
    StructField("parsed_name", StringType()),
    StructField("name_length", IntegerType())
])

@F.udf(schema)
def parse_name(name):
    return {
        "parsed_name": name.upper() if name else None,
        "name_length": len(name) if name else 0
    }

df.withColumn("name_info", parse_name(F.col("name"))) \
  .withColumn("parsed_name", F.col("name_info.parsed_name")) \
  .withColumn("name_length", F.col("name_info.name_length"))

# Example 4: Broadcast variable
from pyspark.sql.functions import udf

# Create broadcast variable
lookup_dict = {"A": 1, "B": 2, "C": 3}
broadcast_dict = spark.sparkContext.broadcast(lookup_dict)

@F.udf(IntegerType())
def lookup_value(key):
    return broadcast_dict.value.get(key, 0)

df.withColumn("value", lookup_value(F.col("category")))

# Example 5: Cache complex computation
# Cache when DataFrame will be reused multiple times
df_processed = (df
    .filter(F.col("active") == True)
    .withColumn("score", complex_calc_udf(F.col("data")))
    .cache()  # Cache result
)

# Use multiple times
result1 = df_processed.filter(F.col("score") > 0.5)
result2 = df_processed.groupBy("category").agg(F.avg("score"))

# Don't forget to unpersist
df_processed.unpersist()

# Example 6: Accumulators for debugging/monitoring
from pyspark import AccumulatorParam

null_counter = spark.sparkContext.accumulator(0)

def count_nulls(value):
    global null_counter
    if value is None:
        null_counter.add(1)
    return value

count_nulls_udf = F.udf(count_nulls, StringType())
df.withColumn("checked", count_nulls_udf(F.col("name"))).count()
print(f"Null values found: {null_counter.value}")


Quick Reference Card

╔══════════════════════════════════════════════════════════════╗
║           PYSPARK PROBLEM TYPES QUICK REFERENCE              ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║ TOP N PER GROUP         → row_number().over(Window...)       ║
║ RUNNING TOTAL           → sum().over(rowsBetween(...))       ║
║ PREVIOUS/NEXT VALUE     → lag() / lead()                     ║
║ COMPARE TO GROUP AVG    → avg().over(partitionBy(...))       ║
║ FIND GAPS               → Generate series + left_anti join   ║
║ DEDUPLICATION           → dropDuplicates() or row_number()   ║
║ PIVOT                   → groupBy().pivot().agg()            ║
║ UNPIVOT                 → selectExpr("stack(...)")           ║
║ BROADCAST JOIN          → join(broadcast(small_df), ...)     ║
║ CONDITIONAL COLUMN      → when().when().otherwise()          ║
║                                                              ║
║ PERFORMANCE TIPS:                                            ║
║ • Filter before joins/aggregations                           ║
║ • Broadcast small tables (< 10MB)                            ║
║ • Cache filtered data, not raw                               ║
║ • Use built-in functions over UDFs                           ║
║ • Repartition for parallelism (100-1000 partitions)          ║
║ • Select only needed columns                                 ║
║ • Use approx functions for large datasets                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝


PySpark vs SQL Translation Guide



|SQL                       |PySpark                                         |
|--------------------------|------------------------------------------------|
|`SELECT * FROM table`     |`df.select("*")`                                |
|`SELECT col1, col2`       |`df.select("col1", "col2")`                     |
|`WHERE condition`         |`df.filter(condition)`                          |
|`GROUP BY col`            |`df.groupBy("col")`                             |
|`ORDER BY col DESC`       |`df.orderBy(F.col("col").desc())`               |
|`LIMIT 10`                |`df.limit(10)`                                  |
|`DISTINCT`                |`df.distinct()`                                 |
|`CASE WHEN... THEN... END`|`F.when(...).otherwise(...)`                    |
|`ROW_NUMBER() OVER (...)` |`F.row_number().over(Window...)`                |
|`LAG(col, 1)`             |`F.lag("col", 1).over(Window...)`               |
|`COUNT(DISTINCT col)`     |`F.countDistinct("col")`                        |
|`SUM(col)`                |`F.sum("col")`                                  |
|`AVG(col)`                |`F.avg("col")` or `F.mean("col")`               |
|`COALESCE(a, b, c)`       |`F.coalesce(F.col("a"), F.col("b"), F.col("c"))`|
|`CONCAT(a, b)`            |`F.concat(F.col("a"), F.col("b"))`              |
|`SUBSTRING(col, 1, 5)`    |`F.substring("col", 1, 5)`                      |
|`UPPER(col)`              |`F.upper("col")`                                |
|`IN (val1, val2)`         |`F.col("col").isin([val1, val2])`               |
|`NOT IN (...)`            |`~F.col("col").isin([...])`                     |
|`IS NULL`                 |`F.col("col").isNull()`                         |
|`IS NOT NULL`             |`F.col("col").isNotNull()`                      |
|`BETWEEN a AND b`         |`F.col("col").between(a, b)`                    |
|`LIKE '%pattern%'`        |`F.col("col").like("%pattern%")`                |
|`LEFT JOIN`               |`df1.join(df2, "key", "left")`                  |
|`UNION ALL`               |`df1.union(df2)`                                |

Common Pitfalls & Solutions



|Pitfall                       |Solution                        |
|------------------------------|--------------------------------|
|Using Python UDF unnecessarily|Use built-in functions          |
|Caching before filtering      |Filter first, then cache        |
|Not unpersisting cached data  |Always unpersist()              |
|Too many/too few partitions   |Aim for [100-1000](tel:100-1000)|
|Collect() on large DataFrame  |Aggregate first                 |
|Not broadcasting small tables |Use broadcast() hint            |
|Creating too many columns     |Drop intermediate cols          |
|Ignoring data skew            |Salt keys, repartition          |
|Column name ambiguity in joins|Use df.alias(“a”)               |
|Type mismatch in operations   |Explicit cast()                 |

Interview Pattern Recognition



|Interview Phrase     |PySpark Pattern                                          |
|---------------------|---------------------------------------------------------|
|“for each group”     |`Window.partitionBy()`                                   |
|“top 3”              |`row_number().over(Window...).filter(rn <= 3)`           |
|“compared to average”|`avg().over(Window.partitionBy())`                       |
|“consecutive”        |`lag()` + difference check or row_number trick           |
|“running total”      |`sum().over(rowsBetween(unboundedPreceding, currentRow))`|
|“fill missing dates” |Generate date series + left join                         |
|“remove duplicates”  |`dropDuplicates()` or `row_number() == 1`                |
|“previous value”     |`lag().over(Window...)`                                  |
|“pivot table”        |`groupBy().pivot().agg()`                                |
|“unique values”      |`distinct()` or `dropDuplicates()`                       |

Happy Sparking! 🎯
Would you like me to:
	1.	Create end-to-end PySpark examples for complete workflows?
	2.	Build a comparison guide (PySpark vs Pandas vs SQL)?
	3.	Add Spark optimization deep-dive (partitioning strategies, shuffle optimization)?
	4.	Create a troubleshooting guide for common Spark errors?​​​​​​​​​​​​​​​​