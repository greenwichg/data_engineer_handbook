# Airflow Core Concepts - Interview Guide

A comprehensive guide to explain key Airflow concepts in interviews with simple examples.

---

## 1. DAG Design

### Definition
A **DAG (Directed Acyclic Graph)** is a collection of tasks with dependencies that define the execution order. It must be:
- **Directed**: Tasks flow in one direction
- **Acyclic**: No circular dependencies (Task A → Task B → Task A is invalid)

### Simple Example

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

# Define default arguments
default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'retries': 2,
    'retry_delay': timedelta(minutes=5)
}

# Create DAG
with DAG(
    dag_id='simple_etl_pipeline',
    default_args=default_args,
    schedule_interval='0 6 * * *',  # Daily at 6 AM
    catchup=False,
    tags=['example', 'etl']
) as dag:
    
    def extract():
        print("Extracting data...")
        return {'records': 1000}
    
    def transform():
        print("Transforming data...")
        return {'processed': 950}
    
    def load():
        print("Loading to warehouse...")
    
    # Define tasks
    extract_task = PythonOperator(
        task_id='extract',
        python_callable=extract
    )
    
    transform_task = PythonOperator(
        task_id='transform',
        python_callable=transform
    )
    
    load_task = PythonOperator(
        task_id='load',
        python_callable=load
    )
    
    # Define dependencies
    extract_task >> transform_task >> load_task
```

### DAG Design Patterns

#### Pattern 1: Linear Pipeline
```python
# Sequential execution
task_a >> task_b >> task_c >> task_d

# Execution: A → B → C → D
```

#### Pattern 2: Fan-Out (Parallel Execution)
```python
# One task triggers multiple parallel tasks
extract >> [transform_region_1, transform_region_2, transform_region_3] >> load

# Execution:
#     extract
#        ├─→ transform_region_1 ─┐
#        ├─→ transform_region_2 ─┤→ load
#        └─→ transform_region_3 ─┘
```

#### Pattern 3: Branching (Conditional Logic)
```python
from airflow.operators.python import BranchPythonOperator

def decide_branch(**context):
    if context['execution_date'].weekday() < 5:  # Mon-Fri
        return 'weekday_task'
    return 'weekend_task'

branch = BranchPythonOperator(
    task_id='branch_decision',
    python_callable=decide_branch
)

branch >> [weekday_task, weekend_task]

# Only ONE path executes based on condition
```

#### Pattern 4: Diamond Pattern (Join)
```python
# Multiple tasks converge to one
start >> [task_a, task_b, task_c] >> join >> end

# Execution:
#     start
#       ├─→ task_a ─┐
#       ├─→ task_b ─┤→ join → end
#       └─→ task_c ─┘
```

### Interview Talking Points

**Q: What makes a good DAG design?**

**Answer:**
"A good DAG design should be:

1. **Modular**: Break complex workflows into smaller, reusable tasks
2. **Idempotent**: Running the same task multiple times produces the same result
3. **Atomic**: Each task does one thing well
4. **Testable**: Tasks can be tested independently

**Example from my project:**
```python
# Bad: One monolithic task
extract_transform_load()  # Does everything, hard to debug

# Good: Separate concerns
extract() >> transform() >> validate() >> load()
# Each task is independent, testable, and can be retried
```

**Additional principles:**
- Use TaskGroups for logical grouping
- Set appropriate timeouts (execution_timeout)
- Use trigger_rules for complex dependencies
- Keep DAG files lightweight (no heavy imports)"

---

## 2. Custom Operators/Hooks

### Hooks
**Definition**: Hooks are interfaces to external systems (databases, APIs, cloud services). They handle connection logic and authentication.

#### Simple Hook Example

```python
from airflow.hooks.base import BaseHook
import psycopg2

class CustomPostgresHook(BaseHook):
    """Custom hook for PostgreSQL with additional functionality"""
    
    def __init__(self, postgres_conn_id='postgres_default'):
        self.postgres_conn_id = postgres_conn_id
        self.connection = None
    
    def get_conn(self):
        """Get database connection"""
        if not self.connection:
            # Get connection details from Airflow Connections
            conn = BaseHook.get_connection(self.postgres_conn_id)
            
            self.connection = psycopg2.connect(
                host=conn.host,
                database=conn.schema,
                user=conn.login,
                password=conn.password,
                port=conn.port
            )
        return self.connection
    
    def execute_query(self, sql):
        """Execute SQL and return results"""
        conn = self.get_conn()
        cursor = conn.cursor()
        cursor.execute(sql)
        results = cursor.fetchall()
        cursor.close()
        return results
    
    def bulk_load(self, table, data):
        """Custom method for bulk loading"""
        conn = self.get_conn()
        cursor = conn.cursor()
        # Bulk insert logic
        cursor.executemany(f"INSERT INTO {table} VALUES (%s, %s)", data)
        conn.commit()
        cursor.close()

# Usage in a task
def my_task():
    hook = CustomPostgresHook(postgres_conn_id='my_postgres')
    results = hook.execute_query("SELECT * FROM sales WHERE date = CURRENT_DATE")
    return results
```

### Operators
**Definition**: Operators define what work gets done. They encapsulate a single task's logic.

#### Simple Custom Operator Example

```python
from airflow.models.baseoperator import BaseOperator
from airflow.utils.decorators import apply_defaults

class DataQualityOperator(BaseOperator):
    """
    Custom operator to validate data quality
    
    :param table: Table name to check
    :param min_rows: Minimum expected row count
    :param check_columns: List of columns to check for NULLs
    """
    
    @apply_defaults
    def __init__(
        self,
        table: str,
        min_rows: int = 0,
        check_columns: list = None,
        postgres_conn_id: str = 'postgres_default',
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.table = table
        self.min_rows = min_rows
        self.check_columns = check_columns or []
        self.postgres_conn_id = postgres_conn_id
    
    def execute(self, context):
        """Execute data quality checks"""
        from airflow.providers.postgres.hooks.postgres import PostgresHook
        
        hook = PostgresHook(postgres_conn_id=self.postgres_conn_id)
        
        # Check 1: Row count
        row_count_query = f"SELECT COUNT(*) FROM {self.table}"
        row_count = hook.get_first(row_count_query)[0]
        
        if row_count < self.min_rows:
            raise ValueError(
                f"Data quality check failed: {self.table} has {row_count} rows, "
                f"expected at least {self.min_rows}"
            )
        
        self.log.info(f"✓ Row count check passed: {row_count} rows")
        
        # Check 2: NULL values
        for column in self.check_columns:
            null_query = f"""
                SELECT COUNT(*) 
                FROM {self.table} 
                WHERE {column} IS NULL
            """
            null_count = hook.get_first(null_query)[0]
            
            if null_count > 0:
                raise ValueError(
                    f"Data quality check failed: {column} has {null_count} NULL values"
                )
            
            self.log.info(f"✓ NULL check passed for {column}")
        
        return {
            'table': self.table,
            'row_count': row_count,
            'status': 'passed'
        }

# Usage in DAG
quality_check = DataQualityOperator(
    task_id='check_sales_data',
    table='sales_fact',
    min_rows=1000,
    check_columns=['sale_id', 'customer_id', 'total_amount'],
    postgres_conn_id='postgres_prod'
)
```

#### Real-World Example: S3 to Snowflake Operator

```python
from airflow.models.baseoperator import BaseOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook

class S3ToSnowflakeOperator(BaseOperator):
    """
    Load data from S3 to Snowflake using COPY command
    """
    
    @apply_defaults
    def __init__(
        self,
        s3_bucket: str,
        s3_key: str,
        snowflake_table: str,
        snowflake_stage: str,
        file_format: str = 'CSV',
        *args,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.s3_bucket = s3_bucket
        self.s3_key = s3_key
        self.snowflake_table = snowflake_table
        self.snowflake_stage = snowflake_stage
        self.file_format = file_format
    
    def execute(self, context):
        # 1. Verify S3 file exists
        s3_hook = S3Hook(aws_conn_id='aws_default')
        
        if not s3_hook.check_for_key(self.s3_key, self.s3_bucket):
            raise FileNotFoundError(f"File not found: s3://{self.s3_bucket}/{self.s3_key}")
        
        self.log.info(f"✓ File found in S3: {self.s3_key}")
        
        # 2. Copy to Snowflake
        sf_hook = SnowflakeHook(snowflake_conn_id='snowflake_default')
        
        copy_sql = f"""
        COPY INTO {self.snowflake_table}
        FROM @{self.snowflake_stage}/{self.s3_key}
        FILE_FORMAT = (TYPE = '{self.file_format}')
        ON_ERROR = 'ABORT_STATEMENT';
        """
        
        self.log.info(f"Executing COPY command...")
        sf_hook.run(copy_sql)
        
        # 3. Verify load
        count_sql = f"SELECT COUNT(*) FROM {self.snowflake_table}"
        row_count = sf_hook.get_first(count_sql)[0]
        
        self.log.info(f"✓ Loaded {row_count} rows to {self.snowflake_table}")
        
        return {'rows_loaded': row_count}

# Usage
load_to_snowflake = S3ToSnowflakeOperator(
    task_id='load_sales_to_snowflake',
    s3_bucket='data-staging',
    s3_key='sales/2024-01-15/sales.csv',
    snowflake_table='analytics.sales_fact',
    snowflake_stage='sales_stage'
)
```

### Interview Talking Points

**Q: When would you create a custom operator vs using PythonOperator?**

**Answer:**
"I create custom operators when:

1. **Reusability**: Logic used across multiple DAGs
2. **Encapsulation**: Complex logic that should be abstracted
3. **Type Safety**: Better IDE support and validation
4. **Testing**: Easier to unit test independently

**Example from my project:**
```python
# Instead of repeating this PythonOperator in every DAG:
def validate_data(**context):
    hook = PostgresHook(...)
    # 50 lines of validation logic
    
validate = PythonOperator(task_id='validate', python_callable=validate_data)

# I created DataQualityOperator:
validate = DataQualityOperator(
    task_id='validate',
    table='sales',
    min_rows=1000,
    check_columns=['id', 'amount']
)
# Much cleaner, reusable, testable
```

**For simple, one-off logic**: Use PythonOperator
**For repeated patterns**: Create custom operator"

---

## 3. Scheduling

### Schedule Interval Basics

```python
# Schedule formats (all equivalent to "daily at 6 AM UTC"):

# 1. Cron expression (most common)
schedule_interval='0 6 * * *'

# 2. Timedelta (for simple intervals)
schedule_interval=timedelta(days=1)

# 3. Preset (Airflow macros)
schedule_interval='@daily'  # Runs at midnight
```

### Cron Expression Cheat Sheet

```
 ┌───────────── minute (0-59)
 │ ┌───────────── hour (0-23)
 │ │ ┌───────────── day of month (1-31)
 │ │ │ ┌───────────── month (1-12)
 │ │ │ │ ┌───────────── day of week (0-6, Sunday=0)
 │ │ │ │ │
 * * * * *
```

### Common Schedule Examples

```python
# Every hour
schedule_interval='0 * * * *'

# Every 15 minutes
schedule_interval='*/15 * * * *'

# Daily at 2:30 AM
schedule_interval='30 2 * * *'

# Every Monday at 8 AM
schedule_interval='0 8 * * 1'

# First day of every month at midnight
schedule_interval='0 0 1 * *'

# Weekdays only at 9 AM
schedule_interval='0 9 * * 1-5'

# Every 6 hours
schedule_interval='0 */6 * * *'

# Manual trigger only (no automatic schedule)
schedule_interval=None
```

### Advanced Scheduling Example

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta

# Different schedules for different environments
def get_schedule_interval(environment):
    schedules = {
        'production': '0 6 * * *',      # Daily at 6 AM
        'staging': '0 */4 * * *',       # Every 4 hours
        'development': None              # Manual only
    }
    return schedules.get(environment, None)

with DAG(
    dag_id='sales_etl',
    schedule_interval=get_schedule_interval('production'),
    start_date=datetime(2024, 1, 1),
    catchup=False,  # Don't run for historical dates
    max_active_runs=1,  # Only one run at a time
    dagrun_timeout=timedelta(hours=2),  # Max runtime
) as dag:
    # Tasks...
    pass
```

### Execution Date vs Logical Date

```python
"""
Understanding Airflow's execution date:

schedule_interval = '0 6 * * *'  (Daily at 6 AM)

DAG scheduled for Jan 15, 2024 at 6 AM:
- execution_date: 2024-01-14 06:00:00 (previous period start)
- logical_date: 2024-01-14 06:00:00 (same as execution_date)
- data_interval_start: 2024-01-14 06:00:00
- data_interval_end: 2024-01-15 06:00:00
- run_date: 2024-01-15 06:00:00 (actual run time)

Why? You're processing data from the previous period!
"""

def extract_data(**context):
    # Process data for yesterday
    execution_date = context['execution_date']  # Jan 14
    data_interval_end = context['data_interval_end']  # Jan 15
    
    # Query: Get data from Jan 14 00:00 to Jan 15 00:00
    query = f"""
        SELECT * FROM sales
        WHERE sale_date >= '{execution_date.date()}'
          AND sale_date < '{data_interval_end.date()}'
    """
    return query
```

### Interview Talking Points

**Q: How do you schedule a DAG to run daily at 6 AM?**

**Answer:**
```python
# Simple answer
schedule_interval='0 6 * * *'  # Cron expression
start_date=datetime(2024, 1, 1)
catchup=False  # Important! Don't backfill historical runs

# In production, I also set:
max_active_runs=1  # Prevent overlapping runs
dagrun_timeout=timedelta(hours=2)  # Fail if exceeds 2 hours
```

**Q: What's the difference between execution_date and run_date?**

**Answer:**
"**execution_date** is the logical date - the period of data you're processing.
**run_date** is when the DAG actually runs (physical time).

**Example:** 
- Schedule: Daily at 6 AM
- Run date: Jan 15, 2024 at 6 AM (when it runs)
- Execution date: Jan 14, 2024 at 6 AM (data period)

This allows processing 'yesterday's data' - a common ETL pattern."

---

## 4. Backfilling

### What is Backfilling?

**Backfilling** = Running a DAG for historical dates that were missed or need reprocessing.

### Simple Backfill Example

```bash
# Backfill for a specific date range
airflow dags backfill \
    --start-date 2024-01-01 \
    --end-date 2024-01-15 \
    sales_etl_pipeline

# Backfill with specific configuration
airflow dags backfill \
    --start-date 2024-01-01 \
    --end-date 2024-01-15 \
    --rerun-failed-tasks \
    --reset-dagruns \
    sales_etl_pipeline
```

### Catchup Parameter

```python
# Controls whether DAG backfills automatically

# catchup=True (default in older versions)
with DAG(
    dag_id='sales_etl',
    start_date=datetime(2024, 1, 1),  # 30 days ago
    schedule_interval='@daily',
    catchup=True,  # ⚠️ Will create 30 DAG runs immediately!
):
    pass

# catchup=False (recommended for most cases)
with DAG(
    dag_id='sales_etl',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False,  # ✓ Only runs from today forward
):
    pass
```

### Selective Backfilling Example

```python
def should_process_date(**context):
    """Only backfill specific dates"""
    execution_date = context['execution_date']
    
    # Only process first day of each month
    if execution_date.day == 1:
        return 'process_task'
    return 'skip_task'

branch = BranchPythonOperator(
    task_id='check_date',
    python_callable=should_process_date
)
```

### Idempotent Backfilling Pattern

```python
def idempotent_load(**context):
    """Safe to run multiple times for same date"""
    execution_date = context['execution_date']
    batch_id = execution_date.strftime('%Y%m%d')
    
    # 1. Check if already processed
    existing = check_batch_exists(batch_id)
    if existing:
        print(f"Batch {batch_id} already exists, recreating...")
        delete_batch(batch_id)
    
    # 2. Process data
    data = extract_data(execution_date)
    transform_data(data)
    
    # 3. Load with batch_id for tracking
    load_data(data, batch_id=batch_id)
    
    return {'batch_id': batch_id, 'rows': len(data)}

# Can safely backfill:
# airflow dags backfill sales_etl --start-date 2024-01-01 --end-date 2024-01-15
```

### Backfill Best Practices

```python
with DAG(
    dag_id='sales_etl',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    catchup=False,  # 1. Disable auto-catchup
    max_active_runs=1,  # 2. Prevent parallel backfills
    default_args={
        'depends_on_past': False,  # 3. Each run is independent
    }
) as dag:
    
    # 4. Make tasks idempotent
    extract = PythonOperator(
        task_id='extract',
        python_callable=idempotent_extract
    )
    
    # 5. Use execution_date for data filtering
    load = PythonOperator(
        task_id='load',
        python_callable=lambda **ctx: load_data(
            date=ctx['execution_date']
        )
    )
```

### Interview Talking Points

**Q: How do you backfill missing data?**

**Answer:**
"There are two approaches:

**1. Manual backfill (my preferred method):**
```bash
# Backfill specific date range
airflow dags backfill sales_etl \
    --start-date 2024-01-01 \
    --end-date 2024-01-15
```

**2. Automatic catchup (use carefully):**
```python
DAG(..., catchup=True)  # Auto-backfills from start_date
```

**In production, I use:**
- `catchup=False` to prevent accidental backfills
- Manual backfill commands for control
- Idempotent tasks so multiple runs are safe
- `depends_on_past=False` so runs are independent

**Example scenario:**
Pipeline was down Jan 1-15. To recover:
```bash
# Reprocess all missing dates
airflow dags backfill sales_etl \
    --start-date 2024-01-01 \
    --end-date 2024-01-15 \
    --reset-dagruns
```

**Key**: Tasks must be idempotent - using MERGE in Snowflake ensures no duplicates on rerun."

---

## 5. Managing XComs

### What is XCom?

**XCom (Cross-Communication)** = Mechanism for tasks to share data.

### Simple XCom Example

```python
from airflow.operators.python import PythonOperator

def extract_data(**context):
    """Extract and push data to XCom"""
    data = {'records': 1000, 'date': '2024-01-15'}
    
    # Method 1: Return value (automatically pushed)
    return data

def transform_data(**context):
    """Pull data from XCom"""
    ti = context['task_instance']
    
    # Pull data from upstream task
    extracted_data = ti.xcom_pull(task_ids='extract')
    
    print(f"Received: {extracted_data}")
    # Output: {'records': 1000, 'date': '2024-01-15'}
    
    processed_data = {
        'original_records': extracted_data['records'],
        'processed_records': 950
    }
    
    return processed_data

extract = PythonOperator(
    task_id='extract',
    python_callable=extract_data
)

transform = PythonOperator(
    task_id='transform',
    python_callable=transform_data
)

extract >> transform
```

### Multiple XCom Values (Custom Keys)

```python
def complex_task(**context):
    ti = context['task_instance']
    
    # Push multiple values with custom keys
    ti.xcom_push(key='record_count', value=1000)
    ti.xcom_push(key='error_count', value=5)
    ti.xcom_push(key='processing_time', value=45.2)
    
    # Return value uses default 'return_value' key
    return {'status': 'success'}

def downstream_task(**context):
    ti = context['task_instance']
    
    # Pull specific keys
    record_count = ti.xcom_pull(task_ids='complex_task', key='record_count')
    error_count = ti.xcom_pull(task_ids='complex_task', key='error_count')
    
    # Pull default return value
    status = ti.xcom_pull(task_ids='complex_task')  # Gets 'return_value' key
    
    print(f"Records: {record_count}, Errors: {error_count}, Status: {status}")
```

### XCom from Multiple Upstream Tasks

```python
def aggregate_results(**context):
    """Aggregate XCom from multiple tasks"""
    ti = context['task_instance']
    
    # Pull from multiple tasks
    task_ids = ['extract_region_1', 'extract_region_2', 'extract_region_3']
    
    total_records = 0
    for task_id in task_ids:
        data = ti.xcom_pull(task_ids=task_id)
        total_records += data.get('records', 0)
    
    print(f"Total records from all regions: {total_records}")
    return {'total': total_records}

# Or pull all at once
def aggregate_all(**context):
    ti = context['task_instance']
    
    # Pull from multiple tasks at once
    results = ti.xcom_pull(task_ids=['task_a', 'task_b', 'task_c'])
    # Returns: [result_a, result_b, result_c]
    
    total = sum(r.get('count', 0) for r in results)
    return {'total': total}
```

### XCom Best Practices & Limitations

```python
# ❌ BAD: Storing large data in XCom
def bad_extract(**context):
    # DON'T do this - XCom is stored in Airflow DB
    large_dataframe = pd.read_csv('huge_file.csv')  # 1 GB
    return large_dataframe.to_dict()  # Crashes database!

# ✅ GOOD: Store references, not data
def good_extract(**context):
    # Process data and save to external storage
    df = pd.read_csv('huge_file.csv')
    
    # Save to S3/GCS
    s3_path = 's3://bucket/data/2024-01-15.parquet'
    df.to_parquet(s3_path)
    
    # Only pass metadata through XCom
    return {
        's3_path': s3_path,
        'record_count': len(df),
        'file_size_mb': 1024
    }

def good_transform(**context):
    ti = context['task_instance']
    metadata = ti.xcom_pull(task_ids='extract')
    
    # Load data from S3 using the path
    df = pd.read_parquet(metadata['s3_path'])
    # Process...
```

### Real-World XCom Example

```python
def extract_sales(**context):
    """Extract sales data and track metadata"""
    execution_date = context['execution_date']
    ti = context['task_instance']
    
    # Extract data
    sales_data = fetch_sales_from_db(execution_date)
    
    # Save data to external storage
    file_path = f's3://data/sales/{execution_date.date()}.csv'
    upload_to_s3(sales_data, file_path)
    
    # Share metadata via XCom
    metadata = {
        'file_path': file_path,
        'record_count': len(sales_data),
        'total_amount': sum(row['amount'] for row in sales_data),
        'extraction_time': datetime.now().isoformat()
    }
    
    # Push with custom keys for easy access
    ti.xcom_push(key='sales_metadata', value=metadata)
    ti.xcom_push(key='record_count', value=len(sales_data))
    
    return metadata

def validate_sales(**context):
    """Validate using metadata from XCom"""
    ti = context['task_instance']
    
    # Pull metadata
    metadata = ti.xcom_pull(task_ids='extract_sales', key='sales_metadata')
    
    # Validation
    if metadata['record_count'] < 100:
        raise ValueError(f"Too few records: {metadata['record_count']}")
    
    if metadata['total_amount'] <= 0:
        raise ValueError("Invalid total amount")
    
    print(f"✓ Validation passed: {metadata['record_count']} records")
    return {'status': 'validated'}

def load_sales(**context):
    """Load using file path from XCom"""
    ti = context['task_instance']
    
    metadata = ti.xcom_pull(task_ids='extract_sales', key='sales_metadata')
    
    # Load data from S3
    sales_data = read_from_s3(metadata['file_path'])
    
    # Load to warehouse
    load_to_snowflake(sales_data)
    
    return {'loaded': metadata['record_count']}
```

### Interview Talking Points

**Q: How do you pass data between tasks in Airflow?**

**Answer:**
"I use XCom for **metadata** only, not actual data:

```python
# Store metadata, not data
def extract(**context):
    df = process_large_dataset()  # 100MB dataframe
    
    # ❌ Bad: return df.to_dict()  # Stores in Airflow DB
    
    # ✓ Good: Save externally, return reference
    s3_path = save_to_s3(df)
    return {'s3_path': s3_path, 'rows': len(df)}

def transform(**context):
    ti = context['task_instance']
    metadata = ti.xcom_pull(task_ids='extract')
    df = read_from_s3(metadata['s3_path'])  # Load from S3
```

**XCom limits:**
- Typically 64KB (depends on backend database)
- Stored in Airflow database (expensive for large data)
- Serialized as JSON

**Best practices:**
- Use for counts, paths, flags, small config
- Store actual data in S3/GCS/database
- Clean up old XCom periodically"

---

## 6. SLAs (Service Level Agreements)

### What is an SLA?

**SLA** = Maximum time a task/DAG should take to complete. Triggers alerts if exceeded.

### Simple SLA Example

```python
from datetime import timedelta

def slow_task():
    import time
    time.sleep(120)  # Takes 2 minutes

# Task-level SLA
task_with_sla = PythonOperator(
    task_id='slow_process',
    python_callable=slow_task,
    sla=timedelta(minutes=1)  # Should complete in 1 minute
    # Alert triggered because task takes 2 minutes!
)
```

### DAG-level vs Task-level SLA

```python
# DAG-level SLA (entire pipeline)
with DAG(
    dag_id='sales_etl',
    start_date=datetime(2024, 1, 1),
    schedule_interval='@daily',
    default_args={
        'sla': timedelta(hours=2)  # Applies to ALL tasks
    },
    dagrun_timeout=timedelta(hours=3),  # Hard stop after 3 hours
) as dag:
    
    # Task-level SLA (overrides default)
    extract = PythonOperator(
        task_id='extract',
        python_callable=extract_data,
        sla=timedelta(minutes=30)  # This task: 30 min max
    )
    
    transform = PythonOperator(
        task_id='transform',
        python_callable=transform_data,
        sla=timedelta(minutes=45)  # This task: 45 min max
    )
    
    load = PythonOperator(
        task_id='load',
        python_callable=load_data,
        sla=timedelta(minutes=30)  # This task: 30 min max
    )
```

### SLA Miss Callback

```python
def sla_miss_callback(dag, task_list, blocking_task_list, slas, blocking_tis):
    """
    Custom function called when SLA is missed
    
    Args:
        dag: The DAG object
        task_list: List of tasks that missed SLA
        blocking_task_list: Tasks blocking the missed SLA tasks
        slas: List of SLA objects
        blocking_tis: TaskInstances that are blocking
    """
    print(f"SLA MISSED!")
    print(f"DAG: {dag.dag_id}")
    print(f"Tasks that missed SLA: {[t.task_id for t in task_list]}")
    
    # Send alert to monitoring system
    send_pagerduty_alert(
        message=f"SLA missed for {dag.dag_id}",
        details={'tasks': [t.task_id for t in task_list]}
    )
    
    # Log to external system
    log_to_datadog(
        metric='airflow.sla.miss',
        tags={'dag_id': dag.dag_id}
    )

# Apply to DAG
with DAG(
    dag_id='critical_pipeline',
    sla_miss_callback=sla_miss_callback,
    default_args={'sla': timedelta(hours=1)}
) as dag:
    # Tasks...
    pass
```

### Real-World SLA Example

```python
from datetime import datetime, timedelta

def send_sla_alert(context):
    """Custom alert for SLA misses"""
    dag_id = context['dag'].dag_id
    task_id = context['task'].task_id
    execution_date = context['execution_date']
    
    message = f"""
    ⚠️ SLA BREACH ALERT
    
    DAG: {dag_id}
    Task: {task_id}
    Execution Date: {execution_date}
    Time: {datetime.now()}
    
    Pipeline exceeding expected runtime.
    Please investigate immediately.
    """
    
    send_email(to='data-team@company.com', body=message)
    send_slack_alert(channel='#data-alerts', message=message)

# Production pipeline with SLAs
with DAG(
    dag_id='daily_sales_report',
    start_date=datetime(2024, 1, 1),
    schedule_interval='0 6 * * *',  # 6 AM daily
    sla_miss_callback=send_sla_alert,
    default_args={
        'owner': 'data-team',
        'sla': timedelta(hours=2),  # Must complete by 8 AM
        'email': ['data-team@company.com'],
        'email_on_failure': True,
    },
    dagrun_timeout=timedelta(hours=3),  # Hard kill at 9 AM
) as dag:
    
    extract = PythonOperator(
        task_id='extract',
        python_callable=extract_data,
        sla=timedelta(minutes=20),
        execution_timeout=timedelta(minutes=30)  # Kill task if stuck
    )
    
    # Critical task with tight SLA
    transform = PythonOperator(
        task_id='transform',
        python_callable=transform_data,
        sla=timedelta(minutes=45),
        execution_timeout=timedelta(hours=1),
        # This task MUST complete by 7 AM for business needs
    )
    
    load = PythonOperator(
        task_id='load',
        python_callable=load_data,
        sla=timedelta(minutes=30),
        execution_timeout=timedelta(minutes=45)
    )
    
    extract >> transform >> load
```

### SLA Monitoring Dashboard Query

```sql
-- Query Airflow DB for SLA misses
SELECT 
    dag_id,
    task_id,
    execution_date,
    timestamp as sla_miss_time,
    description
FROM sla_miss
WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY timestamp DESC;
```

### Interview Talking Points

**Q: How do you handle SLAs in Airflow?**

**Answer:**
"I use SLAs to ensure pipelines complete on time:

```python
# Set realistic SLAs based on historical data
default_args = {
    'sla': timedelta(hours=2),  # Pipeline must finish in 2 hours
}

# Add execution_timeout to prevent hanging
task = PythonOperator(
    task_id='transform',
    sla=timedelta(minutes=30),  # Alert if > 30 min
    execution_timeout=timedelta(minutes=45)  # Kill if > 45 min
)
```

**Real example:**
Daily report pipeline runs at 6 AM, must complete by 8 AM (business needs):
- Set `sla=timedelta(hours=2)`
- Set `dagrun_timeout=timedelta(hours=3)` as hard stop
- Custom `sla_miss_callback` sends PagerDuty alert

**SLA vs Timeout:**
- SLA: Alert if slow (soft warning)
- execution_timeout: Kill if stuck (hard limit)
- dagrun_timeout: Kill entire DAG run

**Monitoring:**
- Track SLA misses in Airflow DB
- Dashboard showing SLA trends
- Auto-scale resources if consistent misses"

---

## 7. Retries

### Basic Retry Configuration

```python
from datetime import timedelta

# Task-level retries
task = PythonOperator(
    task_id='flaky_task',
    python_callable=my_function,
    retries=3,  # Try up to 3 times after initial failure
    retry_delay=timedelta(minutes=5),  # Wait 5 min between retries
)

# DAG-level retries (applies to all tasks)
with DAG(
    dag_id='my_dag',
    default_args={
        'retries': 2,
        'retry_delay': timedelta(minutes=5)
    }
) as dag:
    # All tasks inherit these retry settings
    pass
```

### Retry Execution Flow

```
Attempt 1 (Initial)
    ↓ FAILS
    Wait 5 minutes
    ↓
Attempt 2 (Retry 1/3)
    ↓ FAILS
    Wait 5 minutes
    ↓
Attempt 3 (Retry 2/3)
    ↓ FAILS
    Wait 5 minutes
    ↓
Attempt 4 (Retry 3/3)
    ↓ SUCCESS → Task marked as SUCCESS
    OR
    ↓ FAILS → Task marked as FAILED
```

### Exponential Backoff

```python
# Exponential backoff: Increase wait time after each retry
task = PythonOperator(
    task_id='api_call',
    python_callable=call_external_api,
    retries=5,
    retry_delay=timedelta(minutes=1),
    retry_exponential_backoff=True,  # Enable exponential backoff
    max_retry_delay=timedelta(minutes=30),  # Cap maximum wait time
)

# Retry delays:
# Retry 1: Wait 1 minute
# Retry 2: Wait 2 minutes
# Retry 3: Wait 4 minutes
# Retry 4: Wait 8 minutes
# Retry 5: Wait 16 minutes (but capped at 30 min if max_retry_delay set)
```

### Conditional Retries

```python
from airflow.exceptions import AirflowException

def smart_retry_function(**context):
    """Only retry on specific errors"""
    import requests
    
    try:
        response = requests.get('https://api.example.com/data')
        response.raise_for_status()
        return response.json()
        
    except requests.exceptions.Timeout:
        # Timeout: Retry makes sense
        print("Timeout - will retry")
        raise  # Let Airflow retry
        
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 429:  # Rate limit
            print("Rate limited - will retry")
            raise  # Retry
        elif e.response.status_code == 400:  # Bad request
            print("Bad request - no point retrying")
            raise AirflowException("Bad request - skipping retries")
        elif e.response.status_code >= 500:  # Server error
            print("Server error - will retry")
            raise  # Retry
        else:
            # Other errors: Don't retry
            raise AirflowException(f"HTTP {e.response.status_code} - no retry")
    
    except Exception as e:
        # Unexpected error: Don't retry
        print(f"Unexpected error: {e}")
        raise AirflowException(f"Unexpected error - no retry: {e}")

task = PythonOperator(
    task_id='api_call',
    python_callable=smart_retry_function,
    retries=3,
    retry_delay=timedelta(minutes=2),
    retry_exponential_backoff=True
)
```

### Retry Callback

```python
def on_retry_callback(context):
    """Function called on each retry"""
    task_instance = context['task_instance']
    exception = context['exception']
    
    print(f"Task {task_instance.task_id} failed, retrying...")
    print(f"Error: {exception}")
    print(f"Retry number: {task_instance.try_number}")
    
    # Log to monitoring system
    log_retry_to_datadog(
        task_id=task_instance.task_id,
        error=str(exception),
        retry_number=task_instance.try_number
    )
    
    # Send alert on 3rd retry
    if task_instance.try_number >= 3:
        send_slack_alert(
            f"Task {task_instance.task_id} failing repeatedly!"
        )

task = PythonOperator(
    task_id='monitored_task',
    python_callable=my_function,
    retries=5,
    retry_delay=timedelta(minutes=5),
    on_retry_callback=on_retry_callback
)
```

### Real-World Retry Example

```python
import requests
from airflow.exceptions import AirflowException

def extract_from_api(**context):
    """
    Extract data from external API with intelligent retry logic
    """
    api_url = "https://api.partner.com/sales/daily"
    max_retries_internal = 3
    
    for attempt in range(max_retries_internal):
        try:
            print(f"API call attempt {attempt + 1}/{max_retries_internal}")
            
            response = requests.get(
                api_url,
                timeout=30,
                headers={'Authorization': 'Bearer TOKEN'}
            )
            
            # Success
            if response.status_code == 200:
                data = response.json()
                print(f"✓ Extracted {len(data)} records")
                return data
            
            # Rate limit - exponential backoff
            elif response.status_code == 429:
                wait_time = 60 * (2 ** attempt)  # 60s, 120s, 240s
                print(f"Rate limited, waiting {wait_time}s")
                time.sleep(wait_time)
                continue
            
            # Server error - retry via Airflow
            elif response.status_code >= 500:
                print(f"Server error {response.status_code}")
                raise  # Let Airflow retry
            
            # Client error - don't retry
            else:
                raise AirflowException(
                    f"API error {response.status_code}: {response.text}"
                )
                
        except requests.exceptions.Timeout:
            print(f"Timeout on attempt {attempt + 1}")
            if attempt == max_retries_internal - 1:
                raise  # Let Airflow retry after internal retries exhausted
            time.sleep(10)
            
        except requests.exceptions.ConnectionError:
            print(f"Connection error on attempt {attempt + 1}")
            if attempt == max_retries_internal - 1:
                raise  # Let Airflow retry
            time.sleep(10)
    
    raise AirflowException("All internal retry attempts failed")

# Task configuration
extract_api_data = PythonOperator(
    task_id='extract_api_data',
    python_callable=extract_from_api,
    retries=3,  # Airflow-level retries
    retry_delay=timedelta(minutes=5),
    retry_exponential_backoff=True,
    max_retry_delay=timedelta(minutes=30),
    execution_timeout=timedelta(minutes=10),  # Kill if takes too long
    on_retry_callback=lambda ctx: print(
        f"Retry {ctx['task_instance'].try_number}/3"
    )
)
```

### Different Retry Strategies by Task Type

```python
# Fast-failing task (database query)
db_query = PythonOperator(
    task_id='db_query',
    python_callable=query_database,
    retries=2,  # Few retries
    retry_delay=timedelta(seconds=30),  # Short delay
    # If DB is down, fails fast
)

# Flaky external API
api_call = PythonOperator(
    task_id='api_call',
    python_callable=call_api,
    retries=5,  # More retries
    retry_delay=timedelta(minutes=2),
    retry_exponential_backoff=True,  # Backing off helps
    max_retry_delay=timedelta(minutes=15)
)

# Data quality check (shouldn't retry on failure)
quality_check = PythonOperator(
    task_id='quality_check',
    python_callable=validate_data,
    retries=0,  # No retries - if data is bad, retrying won't fix it
)

# File processing (might have transient S3 issues)
process_file = PythonOperator(
    task_id='process_file',
    python_callable=process_s3_file,
    retries=3,
    retry_delay=timedelta(minutes=1)
)
```

### Monitoring Retries

```sql
-- Query Airflow DB for retry patterns
SELECT 
    dag_id,
    task_id,
    try_number,
    COUNT(*) as retry_count
FROM task_instance
WHERE try_number > 1  -- Only retried tasks
  AND execution_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY dag_id, task_id, try_number
ORDER BY retry_count DESC;

-- Find tasks that always fail after retries
SELECT 
    dag_id,
    task_id,
    COUNT(*) as total_failures
FROM task_instance
WHERE state = 'failed'
  AND try_number >= 3  -- Failed after all retries
  AND execution_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY dag_id, task_id
ORDER BY total_failures DESC;
```

### Interview Talking Points

**Q: How do you handle task failures in Airflow?**

**Answer:**
"I use retries strategically based on failure type:

**For transient failures** (network, rate limits):
```python
retries=3
retry_delay=timedelta(minutes=5)
retry_exponential_backoff=True  # 5min, 10min, 20min
```

**For permanent failures** (bad data):
```python
retries=0  # Don't retry - data won't magically fix itself
```

**Real example from my project:**
```python
# External API with rate limits
extract = PythonOperator(
    task_id='extract_api',
    retries=5,
    retry_exponential_backoff=True,
    max_retry_delay=timedelta(minutes=30)
)

# Data validation - no retries needed
validate = PythonOperator(
    task_id='validate',
    retries=0  # If validation fails, investigate, don't retry
)
```

**I also:**
- Set `execution_timeout` to prevent infinite hangs
- Use `on_retry_callback` for monitoring
- Implement smart retry logic inside functions for specific errors
- Monitor retry patterns to identify flaky tasks"

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│                    AIRFLOW CHEAT SHEET                      │
└─────────────────────────────────────────────────────────────┘

DAG DESIGN
──────────
extract >> transform >> load           # Linear
start >> [task_a, task_b] >> end      # Parallel
branch >> [path_a, path_b]            # Conditional

SCHEDULING
──────────
schedule_interval='0 6 * * *'         # Daily at 6 AM
schedule_interval='*/15 * * * *'      # Every 15 min
schedule_interval='@hourly'           # Every hour
catchup=False                         # No backfill

BACKFILLING
───────────
airflow dags backfill my_dag \
  --start-date 2024-01-01 \
  --end-date 2024-01-15

XCOM
────
return data                           # Auto-push
ti.xcom_pull(task_ids='extract')     # Pull from task
ti.xcom_push(key='count', value=100) # Custom key

SLA
───
sla=timedelta(hours=2)               # Task SLA
dagrun_timeout=timedelta(hours=3)    # DAG timeout
execution_timeout=timedelta(min=30)  # Kill if stuck

RETRIES
───────
retries=3                            # Retry 3 times
retry_delay=timedelta(minutes=5)     # Wait 5 min
retry_exponential_backoff=True       # 5, 10, 20 min
max_retry_delay=timedelta(min=30)    # Cap at 30 min
```

---

## Summary: Interview Tips

**When explaining these concepts:**

1. **Start simple**: Give basic definition and simple example
2. **Add context**: Explain *why* it's useful
3. **Show experience**: Reference your actual project
4. **Discuss trade-offs**: Show you understand pros/cons
5. **Scale considerations**: Mention production best practices

**Example structure:**
```
"[Concept] is [definition]. 

In my sales ETL project, I used [concept] to [solve problem].

For example, [code snippet or specific example].

The key benefits were [1, 2, 3], though I had to consider [trade-off].

In production, I also [additional consideration]."
```

**Common follow-ups to prepare:**
- "What would you do differently at 10x scale?"
- "How do you debug when this fails?"
- "What are the limitations?"
- "How do you monitor this in production?"

Good luck with your interviews! 🚀
