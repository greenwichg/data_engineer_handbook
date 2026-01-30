# Airflow Concepts - Quick Interview Reference Card

**Print this and review 30 minutes before your interview!**

---

## 1. DAG DESIGN 🔄

### One-Liner
"A DAG is a collection of tasks with dependencies that must be directed and acyclic."

### Code to Memorize
```python
# Basic structure
with DAG('my_dag', schedule_interval='@daily', catchup=False) as dag:
    extract >> transform >> load  # Linear
    start >> [task_a, task_b, task_c] >> end  # Parallel (fan-out)
```

### Interview Answer Template
*"In my retail sales pipeline, I used [PATTERN]:*
- **Linear**: extract → transform → validate → load
- **Parallel**: 4 regional extractions running concurrently
- **Branching**: BranchOperator routes to load OR alert based on validation"

### Key Principles
✓ Modular (small, single-purpose tasks)  
✓ Idempotent (safe to rerun)  
✓ Testable (can test tasks independently)

---

## 2. CUSTOM OPERATORS/HOOKS 🔧

### One-Liner
"Hooks connect to external systems; Operators define work to be done."

### When to Create Custom

**Hook**: Reusable connection logic
```python
class CustomPostgresHook:
    def get_conn(self): ...
    def bulk_load(self, table, data): ...
```

**Operator**: Encapsulate repeated task patterns
```python
class DataQualityOperator(BaseOperator):
    def __init__(self, table, min_rows, check_columns): ...
    def execute(self, context): ...
```

### Interview Answer
*"I created DataQualityOperator instead of repeating PythonOperator because:*
1. Used across 5 different DAGs
2. Better type safety and validation
3. Easier to test independently
4. Cleaner DAG code: `DataQualityOperator(table='sales', min_rows=1000)`"

### Rule of Thumb
- **One-off logic**: PythonOperator ✓
- **Repeated pattern**: Custom Operator ✓

---

## 3. SCHEDULING ⏰

### Cron Cheat Sheet
```
 ┌─── minute (0-59)
 │ ┌─── hour (0-23)
 │ │ ┌─── day (1-31)
 │ │ │ ┌─── month (1-12)
 │ │ │ │ ┌─── weekday (0-6)
 * * * * *

'0 6 * * *'      → Daily at 6 AM
'*/15 * * * *'   → Every 15 minutes
'0 9 * * 1-5'    → Weekdays at 9 AM
'0 0 1 * *'      → First of month at midnight
```

### Critical Concepts

**execution_date vs run_date**
```
Schedule: Daily at 6 AM
Run date: Jan 15 at 6 AM (when it physically runs)
Execution date: Jan 14 at 6 AM (data period you're processing)

Why? ETL processes "yesterday's data"
```

### Interview Answer
*"My sales pipeline:*
```python
schedule_interval='0 6 * * *'  # 6 AM daily
start_date=datetime(2024, 1, 1)
catchup=False  # No backfill
max_active_runs=1  # No overlapping runs
dagrun_timeout=timedelta(hours=2)  # Max 2 hours
```
*Processes previous day's data, must complete before 8 AM for business reports."*

---

## 4. BACKFILLING 🔙

### Command to Memorize
```bash
airflow dags backfill sales_etl \
  --start-date 2024-01-01 \
  --end-date 2024-01-15 \
  --reset-dagruns
```

### Critical Setting
```python
catchup=False  # ← ALWAYS set this!
# Prevents accidental backfill on deploy
```

### Interview Scenario

**Q: Pipeline was down Jan 1-15, how do you recover?**

**A:** *"Three steps:*
1. Ensure tasks are idempotent (MERGE in Snowflake, not INSERT)
2. Manual backfill: `airflow dags backfill ... --start-date 2024-01-01 --end-date 2024-01-15`
3. Verify: Check record counts, no duplicates

*With `catchup=False` + idempotent tasks + batch_id tracking, safe to rerun multiple times."*

---

## 5. MANAGING XCOMs 📦

### Golden Rule
**Store metadata, NOT data in XCom!**

### Good vs Bad
```python
# ❌ BAD - Storing 1GB dataframe
return df.to_dict()  # Kills Airflow DB!

# ✅ GOOD - Store reference only
s3_path = save_to_s3(df)
return {'s3_path': s3_path, 'rows': len(df)}
```

### Basic Operations
```python
# Push (automatic)
def extract():
    return {'count': 1000}

# Pull
def transform(**context):
    ti = context['task_instance']
    data = ti.xcom_pull(task_ids='extract')
    
# Custom key
ti.xcom_push(key='metadata', value={'count': 1000})
ti.xcom_pull(task_ids='extract', key='metadata')

# Multiple tasks
results = ti.xcom_pull(task_ids=['task_a', 'task_b', 'task_c'])
```

### Interview Answer
*"In my pipeline, XCom passes:*
- S3 file paths
- Record counts for validation
- Processing timestamps
- Status flags

*Actual 100MB CSVs stored in S3. XCom limit is typically 64KB, and it's stored in Airflow DB—expensive for large data."*

---

## 6. SLAs ⏱️

### One-Liner
"SLA = Maximum time a task should take. Triggers alert (not kill) if exceeded."

### SLA vs Timeout
```python
sla=timedelta(hours=1)              # Alert if slow (soft)
execution_timeout=timedelta(hours=2) # Kill if stuck (hard)
dagrun_timeout=timedelta(hours=3)    # Kill entire DAG (hard)
```

### Example Configuration
```python
# Production pipeline
default_args = {
    'sla': timedelta(hours=2),  # Alert at 2 hours
}

extract = PythonOperator(
    task_id='extract',
    sla=timedelta(minutes=30),  # This task: 30 min
    execution_timeout=timedelta(minutes=45),  # Kill at 45 min
)
```

### Interview Answer
*"My daily report pipeline:*
- Runs at 6 AM
- Must complete by 8 AM (business requirement)
- Set `sla=timedelta(hours=2)`
- Set `dagrun_timeout=timedelta(hours=3)` as absolute stop
- Custom `sla_miss_callback` sends PagerDuty alert

*If consistently missing SLA → investigate performance, maybe auto-scale Snowflake warehouse"*

---

## 7. RETRIES 🔄

### Basic Configuration
```python
retries=3  # Try 3 times after initial failure
retry_delay=timedelta(minutes=5)
retry_exponential_backoff=True  # 5min, 10min, 20min
max_retry_delay=timedelta(minutes=30)  # Cap at 30min
```

### Execution Flow
```
Initial → FAIL → wait 5min → Retry 1/3 → FAIL → wait 10min → 
Retry 2/3 → FAIL → wait 20min → Retry 3/3 → SUCCESS or FAILED
```

### Strategy by Task Type
```python
# External API (flaky)
retries=5, retry_exponential_backoff=True

# Database query (fast-fail)
retries=2, retry_delay=timedelta(seconds=30)

# Data validation (don't retry)
retries=0  # Bad data won't fix itself
```

### Interview Answer
*"I use retries strategically:*

**Transient failures** (network, rate limits):
```python
retries=3
retry_exponential_backoff=True
```

**Permanent failures** (bad data):
```python
retries=0  # Retrying won't help
```

*Example: External API gets `retries=5` with exponential backoff. Data validation gets `retries=0` because if data is invalid, retrying won't fix it—need to investigate source."*

---

## Interview Formula 🎯

**For ANY concept, use this structure:**

1. **Definition** (1 sentence)
2. **Your project example** (specific)
3. **Code snippet** (memorized)
4. **Why you chose this approach** (trade-offs)
5. **Production consideration** (scale/monitoring)

### Example: Retries
1. *"Retries automatically rerun failed tasks after a delay"*
2. *"In my sales pipeline, API extraction gets 5 retries with exponential backoff"*
3. `retries=5, retry_exponential_backoff=True, max_retry_delay=timedelta(minutes=30)`
4. *"Exponential backoff prevents overwhelming rate-limited APIs. Max delay prevents infinite waits."*
5. *"I monitor retry patterns—if a task consistently retries, it indicates a systematic issue to investigate."*

---

## Common Follow-Up Questions

### "What would you do at 10x scale?"

**DAG Design**: Partition by region/date, more parallelism  
**Scheduling**: More frequent micro-batches instead of daily batch  
**XCom**: Use external metadata store (Redis) instead of Airflow DB  
**Retries**: More sophisticated circuit breakers, external retry systems

### "How do you debug failures?"

1. Check Airflow UI → Task logs
2. Check XCom values for context
3. Query Airflow DB for retry history
4. Check external systems (database, S3)
5. Run task locally: `airflow tasks test dag_id task_id 2024-01-15`

### "What are limitations?"

**DAG Design**: No cycles allowed, can't create dynamic DAGs at runtime  
**XCom**: 64KB limit, stored in DB (expensive)  
**Scheduling**: Timezone confusion, no sub-minute scheduling  
**Retries**: All-or-nothing, can't retry specific exceptions easily  

---

## One-Pagers to Memorize

### DAG Design
"Linear for simple ETL, parallel for independent tasks, branching for conditional logic"

### Custom Operators
"Create when logic repeats across DAGs or needs encapsulation"

### Scheduling  
"`schedule_interval='0 6 * * *'` runs daily at 6 AM, `catchup=False` prevents backfill"

### Backfilling
"`airflow dags backfill` with idempotent tasks (MERGE, not INSERT)"

### XComs
"Store S3 paths/counts, NOT actual data. Limit: 64KB in Airflow DB"

### SLAs
"`sla` alerts if slow (soft), `execution_timeout` kills if stuck (hard)"

### Retries
"3 retries with exponential backoff for APIs, 0 retries for data validation"

---

## Final 30-Second Check ✅

Before walking into interview:

- [ ] Can you draw a DAG with parallel extraction?
- [ ] Can you explain execution_date vs run_date?
- [ ] Can you write a cron for "daily at 6 AM"?
- [ ] Can you explain why NOT to store DataFrames in XCom?
- [ ] Can you differentiate SLA vs execution_timeout?
- [ ] Can you explain when to use retries=0 vs retries=5?
- [ ] Can you describe your actual project's DAG structure?

**If yes to all → You're ready! 🚀**

---

## Quick Wins

**Things that impress interviewers:**

✓ "I set `catchup=False` to prevent accidental backfills"  
✓ "I use `max_active_runs=1` to prevent overlapping executions"  
✓ "I store S3 paths in XCom, not actual data"  
✓ "I set `retries=0` for data validation—bad data won't fix itself"  
✓ "I use `execution_timeout` AND `sla` for belt-and-suspenders safety"  
✓ "I implemented custom DataQualityOperator for reusability across DAGs"

**Things that raise red flags:**

✗ "I store dataframes in XCom"  
✗ "I use `catchup=True` by default"  
✗ "I retry failed data validations"  
✗ "I don't set timeouts"  
✗ "All my logic is in one massive PythonOperator"

---

**Remember**: Be confident but honest. If you don't know something, say "I haven't used that in production, but here's how I'd approach it..."

**Good luck! 🎯**
