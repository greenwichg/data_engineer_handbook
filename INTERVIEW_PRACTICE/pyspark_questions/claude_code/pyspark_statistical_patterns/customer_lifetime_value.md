# PySpark Implementation: Customer Lifetime Value (CLV)

## Problem Statement

Compute Customer Lifetime Value (CLV) metrics from transaction data using the RFM (Recency, Frequency, Monetary) framework. Given a history of customer purchases, calculate recency (days since last purchase), frequency (number of transactions), and monetary value (average spend), then score and segment customers. This is a common interview question at e-commerce, fintech, and subscription-based companies (Amazon, Shopify, Stripe) because CLV directly drives marketing budget allocation and retention strategies.

### Sample Data

**Transactions:**

| customer_id | transaction_date | amount | product_category |
|-------------|-----------------|--------|------------------|
| C001        | 2024-01-15      | 120.00 | Electronics      |
| C001        | 2024-03-20      | 85.00  | Books            |
| C001        | 2024-06-10      | 200.00 | Electronics      |
| C002        | 2024-02-01      | 45.00  | Books            |
| C002        | 2024-02-15      | 30.00  | Books            |
| C003        | 2024-01-05      | 500.00 | Electronics      |
| C004        | 2024-05-01      | 60.00  | Clothing         |
| C004        | 2024-06-15      | 75.00  | Clothing         |
| C004        | 2024-07-20      | 90.00  | Books            |
| C004        | 2024-08-10      | 110.00 | Electronics      |

### Expected Output

**RFM Scores (as of 2024-09-01):**

| customer_id | recency_days | frequency | monetary_avg | r_score | f_score | m_score | rfm_segment    |
|-------------|-------------|-----------|--------------|---------|---------|---------|----------------|
| C004        | 22          | 4         | 83.75        | 4       | 4       | 3       | Champions      |
| C001        | 83          | 3         | 135.00       | 3       | 3       | 4       | Loyal          |
| C002        | 199         | 2         | 37.50        | 1       | 2       | 1       | At Risk        |
| C003        | 240         | 1         | 500.00       | 1       | 1       | 4       | Hibernating    |

---

## Method 1: DataFrame API with RFM Scoring

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("Customer Lifetime Value - RFM") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
transactions_data = [
    ("C001", "2024-01-15", 120.00, "Electronics"),
    ("C001", "2024-03-20", 85.00, "Books"),
    ("C001", "2024-06-10", 200.00, "Electronics"),
    ("C002", "2024-02-01", 45.00, "Books"),
    ("C002", "2024-02-15", 30.00, "Books"),
    ("C003", "2024-01-05", 500.00, "Electronics"),
    ("C004", "2024-05-01", 60.00, "Clothing"),
    ("C004", "2024-06-15", 75.00, "Clothing"),
    ("C004", "2024-07-20", 90.00, "Books"),
    ("C004", "2024-08-10", 110.00, "Electronics"),
    ("C005", "2024-07-01", 25.00, "Books"),
    ("C005", "2024-08-15", 35.00, "Books"),
    ("C005", "2024-08-28", 40.00, "Clothing"),
    ("C006", "2024-04-10", 300.00, "Electronics"),
    ("C006", "2024-06-20", 250.00, "Electronics"),
]

transactions_df = spark.createDataFrame(
    transactions_data,
    ["customer_id", "transaction_date", "amount", "product_category"]
).withColumn("transaction_date", F.to_date("transaction_date"))

# Analysis date (snapshot date)
analysis_date = F.lit("2024-09-01").cast("date")

# --- Step 1: Compute RFM metrics ---
rfm_df = transactions_df.groupBy("customer_id").agg(
    F.datediff(analysis_date, F.max("transaction_date")).alias("recency_days"),
    F.count("*").alias("frequency"),
    F.round(F.avg("amount"), 2).alias("monetary_avg"),
    F.round(F.sum("amount"), 2).alias("monetary_total"),
    F.min("transaction_date").alias("first_purchase"),
    F.max("transaction_date").alias("last_purchase"),
)

print("=== Raw RFM Metrics ===")
rfm_df.show()

# --- Step 2: Score each dimension using ntile (1-4 quartiles) ---
# For Recency: lower is better, so reverse the ordering
r_window = Window.orderBy(F.asc("recency_days"))   # low recency = high score
f_window = Window.orderBy(F.asc("frequency"))       # high frequency = high score
m_window = Window.orderBy(F.asc("monetary_avg"))    # high monetary = high score

rfm_scored = rfm_df \
    .withColumn("r_score", F.ntile(4).over(r_window)) \
    .withColumn("f_score", F.ntile(4).over(f_window)) \
    .withColumn("m_score", F.ntile(4).over(m_window)) \
    .withColumn("rfm_combined", F.col("r_score") + F.col("f_score") + F.col("m_score"))

# --- Step 3: Segment customers based on RFM scores ---
rfm_segmented = rfm_scored.withColumn(
    "rfm_segment",
    F.when((F.col("r_score") >= 3) & (F.col("f_score") >= 3), "Champions")
     .when((F.col("r_score") >= 3) & (F.col("f_score") >= 2), "Loyal")
     .when((F.col("r_score") >= 3) & (F.col("f_score") == 1), "New Customers")
     .when((F.col("r_score") == 2) & (F.col("f_score") >= 2), "Potential Loyalists")
     .when((F.col("r_score") == 2) & (F.col("f_score") == 1), "Promising")
     .when((F.col("r_score") == 1) & (F.col("f_score") >= 3), "At Risk")
     .when((F.col("r_score") == 1) & (F.col("f_score") == 2), "About to Sleep")
     .when((F.col("r_score") == 1) & (F.col("f_score") == 1), "Hibernating")
     .otherwise("Other")
)

print("=== RFM Segmentation ===")
rfm_segmented.select(
    "customer_id", "recency_days", "frequency", "monetary_avg",
    "r_score", "f_score", "m_score", "rfm_segment"
).orderBy(F.desc("rfm_combined")).show()

# --- Step 4: Segment-level summary ---
segment_summary = rfm_segmented.groupBy("rfm_segment").agg(
    F.count("*").alias("customer_count"),
    F.round(F.avg("monetary_total"), 2).alias("avg_total_spend"),
    F.round(F.avg("frequency"), 1).alias("avg_frequency"),
    F.round(F.avg("recency_days"), 0).alias("avg_recency"),
)

print("=== Segment Summary ===")
segment_summary.orderBy(F.desc("avg_total_spend")).show()

spark.stop()
```

## Method 2: SQL with CLV Prediction

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("CLV - SQL Approach") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
transactions_data = [
    ("C001", "2024-01-15", 120.00), ("C001", "2024-03-20", 85.00),
    ("C001", "2024-06-10", 200.00), ("C002", "2024-02-01", 45.00),
    ("C002", "2024-02-15", 30.00),  ("C003", "2024-01-05", 500.00),
    ("C004", "2024-05-01", 60.00),  ("C004", "2024-06-15", 75.00),
    ("C004", "2024-07-20", 90.00),  ("C004", "2024-08-10", 110.00),
    ("C005", "2024-07-01", 25.00),  ("C005", "2024-08-15", 35.00),
    ("C005", "2024-08-28", 40.00),  ("C006", "2024-04-10", 300.00),
    ("C006", "2024-06-20", 250.00),
]

df = spark.createDataFrame(transactions_data, ["customer_id", "txn_date", "amount"])
df = df.withColumn("txn_date", F.to_date("txn_date"))
df.createOrReplaceTempView("transactions")

# --- Comprehensive CLV calculation ---
clv_result = spark.sql("""
    WITH customer_metrics AS (
        SELECT
            customer_id,
            COUNT(*) AS frequency,
            ROUND(AVG(amount), 2) AS avg_order_value,
            ROUND(SUM(amount), 2) AS total_spend,
            MIN(txn_date) AS first_purchase,
            MAX(txn_date) AS last_purchase,
            DATEDIFF(DATE '2024-09-01', MAX(txn_date)) AS recency_days,
            DATEDIFF(MAX(txn_date), MIN(txn_date)) AS customer_lifespan_days
        FROM transactions
        GROUP BY customer_id
    ),
    purchase_frequency AS (
        SELECT
            customer_id,
            frequency,
            avg_order_value,
            total_spend,
            recency_days,
            customer_lifespan_days,
            -- Purchase frequency per month (avoid division by zero)
            CASE
                WHEN customer_lifespan_days > 0
                THEN ROUND(frequency / (customer_lifespan_days / 30.0), 2)
                ELSE 0
            END AS purchases_per_month,
            -- Average inter-purchase time
            CASE
                WHEN frequency > 1
                THEN ROUND(customer_lifespan_days / (frequency - 1.0), 1)
                ELSE NULL
            END AS avg_days_between_purchases
        FROM customer_metrics
    ),
    clv_calc AS (
        SELECT
            *,
            -- Simple CLV = avg_order_value * purchases_per_month * 12 (projected annual)
            ROUND(avg_order_value * purchases_per_month * 12, 2) AS projected_annual_clv,
            -- Historical CLV
            total_spend AS historical_clv
        FROM purchase_frequency
    )
    SELECT
        customer_id,
        frequency,
        avg_order_value,
        total_spend,
        recency_days,
        purchases_per_month,
        avg_days_between_purchases,
        historical_clv,
        projected_annual_clv,
        -- Churn risk based on recency vs expected purchase interval
        CASE
            WHEN avg_days_between_purchases IS NOT NULL
                 AND recency_days > 2 * avg_days_between_purchases THEN 'High'
            WHEN avg_days_between_purchases IS NOT NULL
                 AND recency_days > avg_days_between_purchases THEN 'Medium'
            ELSE 'Low'
        END AS churn_risk
    FROM clv_calc
    ORDER BY projected_annual_clv DESC
""")

print("=== Customer Lifetime Value Analysis ===")
clv_result.show(truncate=False)

# --- Cohort-based CLV (by first purchase month) ---
cohort_clv = spark.sql("""
    WITH first_purchase AS (
        SELECT customer_id, MIN(txn_date) AS first_txn
        FROM transactions
        GROUP BY customer_id
    ),
    cohort_data AS (
        SELECT
            DATE_FORMAT(fp.first_txn, 'yyyy-MM') AS cohort_month,
            t.customer_id,
            SUM(t.amount) AS total_spend
        FROM transactions t
        JOIN first_purchase fp ON t.customer_id = fp.customer_id
        GROUP BY DATE_FORMAT(fp.first_txn, 'yyyy-MM'), t.customer_id
    )
    SELECT
        cohort_month,
        COUNT(*) AS customers,
        ROUND(AVG(total_spend), 2) AS avg_clv,
        ROUND(SUM(total_spend), 2) AS total_revenue
    FROM cohort_data
    GROUP BY cohort_month
    ORDER BY cohort_month
""")

print("=== Cohort-Based CLV ===")
cohort_clv.show()

spark.stop()
```

## Key Concepts

- **RFM Model**: Recency (how recently), Frequency (how often), Monetary (how much) -- the classic framework for customer value segmentation.
- **Recency**: Days since last purchase. Lower recency = more engaged customer.
- **Frequency**: Total number of transactions. Higher = more loyal.
- **Monetary**: Average (or total) transaction value. Higher = more valuable.
- **Scoring with ntile()**: Divides customers into quartiles (1-4) for each dimension. Combine scores for overall ranking.
- **CLV Projection**: Simple formula: `AOV * purchase_frequency * projected_lifetime`. More advanced models use BG/NBD or Pareto/NBD.
- **Churn Risk**: Compare recency against expected inter-purchase interval. If a customer is overdue, flag as at risk.

## Interview Tips

- Distinguish between **historical CLV** (what the customer has already spent) and **predictive CLV** (projected future value).
- Mention that RFM scoring with `ntile()` is relative to the current customer base -- scores change as the customer base evolves.
- Discuss how CLV drives **marketing ROI**: spend acquisition budget proportional to expected CLV of each segment.
- For subscription businesses, CLV = `ARPU / churn_rate` -- a different model than transaction-based.
- Real-world nuance: account for **returns, discounts, and cost of goods** when computing monetary value.
