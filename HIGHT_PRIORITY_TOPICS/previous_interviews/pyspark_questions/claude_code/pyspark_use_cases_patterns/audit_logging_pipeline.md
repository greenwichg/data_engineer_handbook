# PySpark Implementation: Audit Logging Pipeline

## Problem Statement

Production data pipelines need **audit logging** to track what happened, when, how much data was processed, and whether anything went wrong. This is essential for **debugging failures**, **data quality monitoring**, **SLA tracking**, and **regulatory compliance**.

---

## Sample Data

```python
from pyspark.sql import SparkSession, Row
from pyspark.sql.functions import col, count, sum as spark_sum, current_timestamp, lit
from datetime import datetime
import traceback

spark = SparkSession.builder.appName("AuditLogging").getOrCreate()

orders = spark.createDataFrame([
    (1, "C001", 100.0, "2024-01-01"),
    (2, "C002", 200.0, "2024-01-02"),
    (3, "C001", 150.0, "2024-01-03"),
    (4, "C003", None, "2024-01-03"),   # bad record
    (5, "C002", 250.0, "2024-01-04"),
], ["order_id", "customer_id", "amount", "order_date"])
```

---

## Method 1: Pipeline Audit Logger Class

```python
class PipelineAuditLogger:
    """Tracks pipeline execution metadata for audit purposes."""
    
    def __init__(self, spark, audit_table_path, pipeline_name, batch_id):
        self.spark = spark
        self.audit_table_path = audit_table_path
        self.pipeline_name = pipeline_name
        self.batch_id = batch_id
        self.start_time = datetime.now()
        self.metrics = {}
    
    def log_metric(self, key, value):
        """Record a custom metric."""
        self.metrics[key] = value
    
    def log_stage(self, stage_name, input_count, output_count, status="SUCCESS", error=None):
        """Log a pipeline stage execution."""
        stage_entry = self.spark.createDataFrame([Row(
            pipeline_name=self.pipeline_name,
            batch_id=self.batch_id,
            stage_name=stage_name,
            input_row_count=int(input_count),
            output_row_count=int(output_count),
            rows_dropped=int(input_count - output_count),
            drop_rate=round((input_count - output_count) / max(input_count, 1) * 100, 2),
            status=status,
            error_message=error,
            stage_timestamp=datetime.now().isoformat()
        )])
        stage_entry.write.format("delta").mode("append").save(f"{self.audit_table_path}/stages")
    
    def finalize(self, status="SUCCESS", error=None):
        """Write final pipeline summary."""
        end_time = datetime.now()
        summary = self.spark.createDataFrame([Row(
            pipeline_name=self.pipeline_name,
            batch_id=self.batch_id,
            start_time=self.start_time.isoformat(),
            end_time=end_time.isoformat(),
            duration_seconds=int((end_time - self.start_time).total_seconds()),
            status=status,
            error_message=error,
            metrics=str(self.metrics)
        )])
        summary.write.format("delta").mode("append").save(f"{self.audit_table_path}/runs")


# --- Usage ---
audit = PipelineAuditLogger(
    spark=spark,
    audit_table_path="/tmp/delta/audit",
    pipeline_name="orders_pipeline",
    batch_id=f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
)

try:
    # Stage 1: Read source
    raw_count = orders.count()
    audit.log_metric("raw_count", raw_count)
    
    # Stage 2: Clean data
    cleaned = orders.filter(col("amount").isNotNull())
    clean_count = cleaned.count()
    audit.log_stage("data_cleaning", raw_count, clean_count)
    
    # Stage 3: Transform
    enriched = cleaned.withColumn("amount_with_tax", col("amount") * 1.1)
    enriched_count = enriched.count()
    audit.log_stage("enrichment", clean_count, enriched_count)
    
    # Stage 4: Write output
    enriched.write.format("delta").mode("overwrite").save("/tmp/delta/enriched_orders")
    audit.log_stage("write_output", enriched_count, enriched_count)
    
    audit.log_metric("final_count", enriched_count)
    audit.finalize(status="SUCCESS")

except Exception as e:
    audit.finalize(status="FAILED", error=str(e))
    raise
```

---

## Method 2: Row Count Reconciliation

```python
def reconcile_counts(spark, source_df, target_path, table_name):
    """Verify source and target row counts match."""
    source_count = source_df.count()
    target_df = spark.read.format("delta").load(target_path)
    target_count = target_df.count()
    
    match = source_count == target_count
    
    result = {
        "table": table_name,
        "source_count": source_count,
        "target_count": target_count,
        "difference": abs(source_count - target_count),
        "status": "PASS" if match else "FAIL",
        "timestamp": datetime.now().isoformat()
    }
    
    print(f"Reconciliation [{table_name}]: {result['status']} "
          f"(source={source_count}, target={target_count})")
    
    if not match:
        print(f"  WARNING: {result['difference']} rows discrepancy!")
    
    return result

# Usage
reconcile_counts(spark, cleaned, "/tmp/delta/enriched_orders", "enriched_orders")
```

---

## Method 3: Data Quality Metrics Logging

```python
def log_data_quality_metrics(df, table_name):
    """Calculate and log data quality metrics for a DataFrame."""
    total_rows = df.count()
    total_cols = len(df.columns)
    
    metrics = {"table": table_name, "total_rows": total_rows}
    
    # Null counts per column
    for col_name in df.columns:
        null_count = df.filter(col(col_name).isNull()).count()
        null_pct = round(null_count / max(total_rows, 1) * 100, 2)
        metrics[f"{col_name}_null_count"] = null_count
        metrics[f"{col_name}_null_pct"] = null_pct
    
    # Duplicate check on key columns
    distinct_count = df.select("order_id").distinct().count()
    metrics["duplicate_keys"] = total_rows - distinct_count
    
    print(f"\n--- Data Quality Report: {table_name} ---")
    print(f"Total rows: {total_rows}")
    print(f"Duplicate keys: {metrics['duplicate_keys']}")
    for col_name in df.columns:
        null_pct = metrics.get(f"{col_name}_null_pct", 0)
        if null_pct > 0:
            print(f"  {col_name}: {null_pct}% nulls")
    
    return metrics

# Usage
metrics = log_data_quality_metrics(orders, "raw_orders")
```

---

## Method 4: Alert on Anomalies

```python
def check_anomalies(current_count, historical_avg, threshold_pct=20, table_name=""):
    """Alert if row count deviates significantly from historical average."""
    if historical_avg == 0:
        return True
    
    deviation_pct = abs(current_count - historical_avg) / historical_avg * 100
    
    if deviation_pct > threshold_pct:
        print(f"ALERT [{table_name}]: Row count {current_count} deviates "
              f"{deviation_pct:.1f}% from avg {historical_avg} "
              f"(threshold: {threshold_pct}%)")
        return False
    else:
        print(f"OK [{table_name}]: Row count {current_count} within "
              f"{deviation_pct:.1f}% of avg {historical_avg}")
        return True

# Usage
check_anomalies(
    current_count=orders.count(),
    historical_avg=100,
    threshold_pct=20,
    table_name="orders"
)
```

---

## Key Takeaways

| Audit Component | What It Tracks | Why It Matters |
|----------------|---------------|----------------|
| Pipeline run log | Start/end time, status, duration | SLA monitoring, failure debugging |
| Stage-level log | Row counts per stage, drop rates | Find where data is lost |
| Reconciliation | Source vs target counts | Validate completeness |
| Data quality metrics | Null rates, duplicates, distributions | Catch quality regressions |
| Anomaly detection | Count deviations from historical | Alert on unexpected changes |

## Interview Tips

1. **Audit tables should be append-only** — use Delta Lake for immutability
2. **Track row counts at every stage** — the #1 debugging tool for data pipelines
3. **Drop rate alerts** catch silent data loss (e.g., a join silently dropping rows)
4. **Reconciliation** is non-negotiable in financial/regulated pipelines
5. **Historical baselines** enable anomaly detection (e.g., "today's load is 50% smaller than usual")
