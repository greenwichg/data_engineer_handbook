I'll provide detailed answers to the key DynamoDB questions. These are designed to help you prepare, but you should adapt them based on your actual experience at Quanted Technologies.

---

## **Partition Key & Schema Design**

### Q: "Walk me through how you chose partition keys for your DynamoDB tables. What was your decision-making process?"

**Answer:**
"When designing partition keys, I followed a systematic approach. First, I analyzed the access patterns - understanding how the application would query the data was crucial. The partition key needs to distribute data evenly across partitions to avoid hot partitions.

For example, at Quanted Technologies, we had a data reliability platform that tracked system health metrics. I designed a table with `system_id` as the partition key and `timestamp` as the sort key. I chose `system_id` because:
1. We had hundreds of systems being monitored, ensuring good distribution
2. Most queries were system-specific lookups
3. Each system generated roughly similar amounts of data, preventing hotspots

The key principle was: the partition key should have high cardinality and queries should filter on it. Using something like `status` (active/inactive) would be terrible because it creates only two partitions."

---

### Q: "What makes a good partition key? What makes a bad one?"

**Answer:**
"A **good partition key** has:
- **High cardinality**: Many distinct values (user_id, device_id, transaction_id)
- **Even distribution**: Each partition key value gets similar amounts of data and traffic
- **Query alignment**: Most queries filter on this attribute
- **Predictable access**: Avoids time-based hotspots

A **bad partition key** would be:
- **Low cardinality**: Status fields, boolean flags, date-only values (YYYY-MM-DD)
- **Uneven distribution**: Tenant_id in multi-tenant systems where one tenant is 80% of traffic
- **Sequential values**: Auto-incrementing IDs where everyone writes to the latest partition
- **Time-based only**: Using just timestamp or date creates hot partitions as all writes go to 'today'

For example, using `date` as a partition key is problematic because all writes for a given day go to one partition, creating a hot partition. Instead, I'd use something like `sensor_id#date` to distribute writes across many partitions."

---

### Q: "How did you handle hot partitions? Did you encounter any, and how did you detect and resolve them?"

**Answer:**
"Yes, I encountered this early in my DynamoDB work. We had a monitoring table where certain critical systems generated 10x more events than others, creating hot partitions.

**Detection:**
I used CloudWatch metrics, specifically `UserErrors` and `SystemErrors` metrics. When I saw `ProvisionedThroughputExceededException` throttling on certain partition key values, that indicated hot partitions. I also monitored the `ConsumedReadCapacityUnits` and `ConsumedWriteCapacityUnits` - if they were high but we still had throttling, it suggested uneven distribution.

**Resolution:**
I used a technique called **write sharding**. Instead of just `system_id`, I added a random suffix: `system_id#0` through `system_id#9`. This distributed writes for high-traffic systems across 10 partitions instead of 1.

For reads, the application had to fan out queries across all 10 shards and aggregate results, which added some complexity but solved the throttling issue completely. The key was choosing the right number of shards - too many increases query overhead, too few doesn't solve the problem."

---

## **Global Secondary Indexes (GSI)**

### Q: "What's the difference between a GSI and an LSI?"

**Answer:**
"**Global Secondary Index (GSI):**
- Can use any attribute as partition key and sort key - completely independent from base table
- Has its own provisioned throughput separate from the base table
- Eventually consistent reads only (can't do strongly consistent reads)
- Can be created or deleted at any time
- Projected attributes are customizable

**Local Secondary Index (LSI):**
- Must use the same partition key as base table, but different sort key
- Shares throughput with the base table
- Supports both eventually consistent AND strongly consistent reads
- Must be created at table creation time (can't add later)
- Limited to 10 GB per partition key value

I primarily used GSIs at Quanted because they offered more flexibility. I could create them after the table existed, which was crucial when we discovered new access patterns. LSIs were too limiting since you can't add them later, and we didn't need strong consistency for our analytics use cases."

---

### Q: "GSIs have their own provisioned throughput. How did you determine the right capacity for them?"

**Answer:**
"I used a data-driven approach:

**Initial Sizing:**
For writes, I calculated: `(items written per second) × (item size in KB) × (number of GSIs that include this attribute)`

For example, if we wrote 100 items/second at 2 KB each, and had 2 GSIs, I'd provision at least 200 WCUs per GSI.

For reads, I analyzed the access patterns. If a GSI supported dashboard queries that ran 50 times/minute pulling 20 items each at 2 KB:
- (50/60) × 20 items × 2 KB = ~33 RCUs (rounded up to 50 for headroom)

**Monitoring & Tuning:**
I monitored the `ConsumedReadCapacityUnits` and `ConsumedWriteCapacityUnits` metrics in CloudWatch. I set alarms at 80% consumed capacity. If we consistently stayed below 50% utilization, I'd reduce capacity to save costs.

**Auto Scaling:**
I enabled Auto Scaling with:
- Target utilization: 70%
- Minimum capacity: 20% of peak observed load
- Maximum capacity: 2x peak observed load

The key lesson was to monitor actual consumption patterns for at least a week before optimizing, because our traffic had daily and weekly patterns."

---

### Q: "What happens when a GSI gets throttled? How did you handle this?"

**Answer:**
"When a GSI gets throttled, the **base table writes also fail** - this is critical to understand. DynamoDB uses a synchronous indexing model, so if the GSI can't keep up, writes are rejected.

I encountered this when we had insufficient WCU capacity on a GSI. The symptoms were:
- `ProvisionedThroughputExceededException` errors
- Write operations failing even though base table had sufficient capacity
- CloudWatch showing high `UserErrors` metrics

**How I handled it:**

**Immediate fix:**
- Increased GSI WCU capacity manually (takes a few minutes to apply)
- Implemented exponential backoff with jitter in the application code for retries

**Code implementation:**
```python
import time
import random
from botocore.exceptions import ClientError

def write_with_retry(item, max_retries=5):
    for attempt in range(max_retries):
        try:
            table.put_item(Item=item)
            return True
        except ClientError as e:
            if e.response['Error']['Code'] == 'ProvisionedThroughputExceededException':
                if attempt < max_retries - 1:
                    # Exponential backoff with jitter
                    wait_time = (2 ** attempt) + random.uniform(0, 1)
                    time.sleep(wait_time)
                else:
                    raise
```

**Long-term solution:**
- Enabled Auto Scaling on all GSIs
- Set up CloudWatch alarms to alert when consumed capacity exceeded 70%
- Reviewed GSI projections - we were using `ALL` projection when we only needed `KEYS_ONLY`, which reduced write costs"

---

## **Access Patterns & Query Optimization**

### Q: "What access patterns were you supporting with your DynamoDB tables?"

**Answer:**
"At Quanted Technologies, our data reliability platform supported these key access patterns:

**1. Get latest metrics for a specific system:**
- Query: `system_id = 'sys_123'` with `ScanIndexForward=False` and `Limit=1`
- Table: PK=system_id, SK=timestamp

**2. Get all metrics for a system within a time range:**
- Query: `system_id = 'sys_123' AND timestamp BETWEEN t1 AND t2`
- Table: PK=system_id, SK=timestamp

**3. Find all systems with specific status:**
- Query: `status = 'ERROR'` sorted by timestamp
- GSI: PK=status, SK=timestamp

**4. Lookup system by device_id:**
- Query: `device_id = 'dev_456'`
- GSI: PK=device_id, SK=system_id

The pattern I followed was: one table with multiple GSIs to support different query patterns. Each GSI represented a different way of looking at the same data. The base table was optimized for the most frequent access pattern (querying by system_id), and GSIs handled less frequent patterns."

---

### Q: "How do you query DynamoDB? What's the difference between Query and Scan?"

**Answer:**
"**Query:**
- Requires you to specify the partition key
- Optionally uses sort key with conditions (begins_with, between, >, <, =)
- Returns only items matching the partition key
- Efficient - reads only the relevant partition
- Cost: Based on size of items returned
- Example: Get all events for user_123 in the last 24 hours

**Scan:**
- Reads the ENTIRE table
- Filters are applied AFTER reading all data
- Extremely inefficient and expensive
- Cost: Based on size of entire table scanned
- Use cases: Very rare - maybe for one-time data migrations or analytics on small tables

**In practice, I almost never used Scan** in production at Quanted. If I found myself needing a Scan, it was a sign that I needed to add a GSI to support that access pattern properly.

Here's a code example:
```python
# Query (efficient)
response = table.query(
    KeyConditionExpression=Key('system_id').eq('sys_123') & 
                          Key('timestamp').between(start, end)
)

# Scan (avoid in production)
response = table.scan(
    FilterExpression=Attr('status').eq('ERROR')  # This filters AFTER reading everything
)
```

If you're using FilterExpression with Scan, you're paying to read the entire table but only getting a subset back."

---

### Q: "How did you achieve low latency? What was your P99 latency target and did you meet it?"

**Answer:**
"Our target was **sub-10ms P99 latency** for point lookups (GetItem operations) and we consistently achieved **6-8ms P99**.

**How we achieved this:**

**1. Proper table design:**
- Used GetItem for single-item lookups (most efficient operation)
- Partition key design prevented hot partitions
- Sort keys enabled efficient range queries without scanning

**2. Right-sized capacity:**
- Provisioned adequate RCUs - under-provisioning causes throttling which spikes latency
- Used on-demand mode for unpredictable traffic patterns

**3. Regional considerations:**
- Table was in the same AWS region as the application (us-east-1)
- Reduced network latency significantly

**4. Connection pooling:**
```python
import boto3
from botocore.config import Config

# Reuse connections
config = Config(
    max_pool_connections=50,
    retries={'max_attempts': 3, 'mode': 'adaptive'}
)
dynamodb = boto3.resource('dynamodb', config=config)
```

**5. Monitoring:**
I tracked these CloudWatch metrics:
- `SuccessfulRequestLatency` - Median, P90, P99
- `UserErrors` - Throttling spikes latency dramatically
- `ConsumedReadCapacityUnits` - Approaching limits increases latency

**What DIDN'T work:**
- Using BatchGetItem for single items (added overhead)
- Strong consistency reads when not needed (2x RCU cost, higher latency)
- Large items > 4 KB (consider compressing or splitting)"

---

## **Capacity Planning & Auto Scaling**

### Q: "What's the difference between provisioned capacity and on-demand mode?"

**Answer:**
"**Provisioned Capacity:**
- You specify RCUs and WCUs upfront
- Charged per hour for provisioned capacity whether you use it or not
- Best for predictable, steady traffic
- Can use Auto Scaling to adjust capacity
- Cost: $0.00065/WCU and $0.00013/RCU per hour (us-east-1)

**On-Demand Mode:**
- No capacity planning required
- Charged per request
- Automatically scales up/down instantly
- Best for unpredictable or sporadic traffic
- Cost: $1.25/million WRUs and $0.25/million RRUs

**When I used each:**

At Quanted, I used **provisioned capacity** for our main monitoring tables because:
- Traffic was predictable (steady stream of metrics every minute)
- 70-80% cheaper than on-demand for our steady workload
- Auto Scaling handled daily/weekly patterns

I would use **on-demand for:**
- Development/staging environments with sporadic traffic
- New tables where traffic patterns are unknown
- Tables with huge spikes but low average throughput

**Cost example:**
For a table with 100 WCU steady load:
- Provisioned: 100 WCU × $0.00065 × 730 hours = $47.45/month
- On-demand: Assuming 100 writes/sec = 259M writes/month × $1.25/M = $323.75/month

Provisioned was 85% cheaper for our predictable workload."

---

### Q: "Walk me through how you configured Auto Scaling for your tables. What were your target utilization thresholds?"

**Answer:**
"I configured Auto Scaling with a balanced approach - aggressive enough to handle spikes but conservative enough to avoid constant scaling:

**Configuration:**
```python
# Target utilization: 70%
# This means scale up when consumed capacity hits 70% of provisioned

MinCapacity: 20 RCU/WCU
MaxCapacity: 200 RCU/WCU  
TargetValue: 70.0
ScaleInCooldown: 300 seconds (5 minutes)
ScaleOutCooldown: 60 seconds (1 minute)
```

**Why 70%?**
- Above 80%: Risk of throttling during traffic bursts
- Below 60%: Too much overprovisioning, wasting money
- 70% gave us headroom for spikes while scaling quickly

**Cooldown periods:**
- **Scale-out (60s):** Fast response to traffic increases
- **Scale-in (300s):** Slower to scale down, avoiding thrashing from temporary dips

**Real example:**
During a traffic spike from 50 writes/sec to 200 writes/sec:
- At 70% consumed: Auto Scaling triggered scale-out
- Capacity increased from 100 WCU → 140 WCU in ~2 minutes
- Then 140 → 200 WCU another 2 minutes later
- After spike ended, waited 5 minutes before scaling down

**Lessons learned:**
- Set MinCapacity to at least your baseline traffic + 20% headroom
- MaxCapacity should be realistic - we had runaway costs once when a bug caused infinite writes
- Monitor the `ConsumedReadCapacityUnits` CloudWatch metric to validate settings
- Auto Scaling works well but isn't instant - for massive spikes, you still need application-level backoff"

---

## **PySpark Integration & ETL**

### Q: "How did you read from DynamoDB in PySpark? What connector did you use?"

**Answer:**
"I used AWS's **EMR DynamoDB connector** which comes pre-installed on EMR clusters. Here's how I implemented it:

**Reading from DynamoDB:**
```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("DynamoDB-Read") \
    .config("spark.dynamodb.region", "us-east-1") \
    .getOrCreate()

# Read from DynamoDB table
df = spark.read \
    .format("dynamodb") \
    .option("tableName", "monitoring_metrics") \
    .option("region", "us-east-1") \
    .option("readPartitions", "10") \
    .option("targetCapacity", "50") \
    .load()

# Show schema
df.printSchema()
df.show()
```

**Key configurations:**
- `readPartitions`: Number of Spark partitions (parallelism). I set this to match the number of executors × cores
- `targetCapacity`: Percentage of provisioned RCU to use (50 = 50%). This prevents overwhelming DynamoDB

**Alternative approach using boto3 + Spark:**
For more control, I also used boto3 with parallel partitioning:
```python
import boto3
from pyspark.sql import Row

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('monitoring_metrics')

def read_partition(partition_key):
    response = table.query(
        KeyConditionExpression=Key('system_id').eq(partition_key)
    )
    return [Row(**item) for item in response['Items']]

# Get unique partition keys
partition_keys = ["sys_1", "sys_2", "sys_3", ...]  # from metadata table

# Parallelize reading
rdd = spark.sparkContext.parallelize(partition_keys, numSlices=10)
data_rdd = rdd.flatMap(read_partition)
df = spark.createDataFrame(data_rdd)
```

**Why the second approach sometimes?**
- More control over parallel reads
- Better error handling per partition
- Can implement custom retry logic"

---

### Q: "How did you write data from PySpark to DynamoDB?"

**Answer:**
"Writing to DynamoDB from PySpark required careful handling to avoid throttling. Here's my approach:

**Method 1: Using EMR DynamoDB Connector**
```python
# Prepare DataFrame
df = spark.read.parquet("s3://bucket/processed-data/")

# Write to DynamoDB
df.write \
    .format("dynamodb") \
    .option("tableName", "target_table") \
    .option("region", "us-east-1") \
    .option("writePartitions", "20") \
    .option("targetCapacity", "50") \
    .mode("append") \
    .save()
```

**Method 2: Custom boto3 batch writes (more control)**
```python
import boto3
from boto3.dynamodb.types import TypeSerializer

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('target_table')
serializer = TypeSerializer()

def write_batch(partition_data):
    """Write a partition of data to DynamoDB"""
    items = list(partition_data)
    
    # DynamoDB batch_write has max 25 items
    for i in range(0, len(items), 25):
        batch = items[i:i+25]
        
        with table.batch_writer() as writer:
            for item in batch:
                # Convert Row to dict
                item_dict = item.asDict()
                writer.put_item(Item=item_dict)
    
    return len(items)

# Repartition to control parallelism
df_repartitioned = df.repartition(20)

# Write using foreachPartition
write_counts = df_repartitioned.rdd.mapPartitions(write_batch).collect()
total_written = sum(write_counts)

print(f"Total items written: {total_written}")
```

**Critical considerations:**

**1. Batch size limitation:**
DynamoDB BatchWriteItem has a **25-item maximum**. I always chunked writes:
```python
for i in range(0, len(items), 25):
    batch = items[i:i+25]
    # write batch
```

**2. Throttling management:**
I set `targetCapacity` to 50% to avoid overwhelming the table. For 100 WCU provisioned, Spark would use max 50 WCU.

**3. Error handling:**
BatchWriteItem can partially fail. I implemented retry logic:
```python
def write_with_retry(items, max_retries=3):
    for attempt in range(max_retries):
        try:
            with table.batch_writer() as batch:
                for item in items:
                    batch.put_item(Item=item)
            return len(items)
        except ClientError as e:
            if 'ProvisionedThroughputExceededException' in str(e):
                time.sleep(2 ** attempt)  # exponential backoff
            else:
                raise
```

**4. Performance optimization:**
- Controlled parallelism: 20 Spark partitions for moderate write load
- Monitoring: Tracked `ConsumedWriteCapacityUnits` in CloudWatch
- If throttling occurred, I reduced `targetCapacity` or increased provisioned WCU"

---

### Q: "DynamoDB has a 25 write item limit for batch operations. How did you handle larger datasets in PySpark?"

**Answer:**
"The 25-item BatchWriteItem limit required careful chunking, especially when processing millions of records from Spark. Here's my approach:

**Solution 1: Chunking within foreachPartition**
```python
def write_partition(partition_iter):
    """Process entire partition with proper batching"""
    import boto3
    from itertools import islice
    
    dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
    table = dynamodb.Table('target_table')
    
    items = list(partition_iter)
    total_written = 0
    
    # Chunk into batches of 25
    def chunker(seq, size=25):
        it = iter(seq)
        while True:
            chunk = list(islice(it, size))
            if not chunk:
                break
            yield chunk
    
    for batch in chunker(items, 25):
        with table.batch_writer() as writer:
            for item in batch:
                item_dict = item.asDict()
                writer.put_item(Item=item_dict)
                total_written += 1
    
    return [total_written]

# Execute
result = df.rdd.mapPartitions(write_partition).collect()
print(f"Total written: {sum(result)}")
```

**Solution 2: Using batch_writer context manager (handles chunking automatically)**
```python
def write_partition_auto(partition_iter):
    """boto3's batch_writer automatically handles the 25-item batching"""
    import boto3
    
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('target_table')
    count = 0
    
    # batch_writer automatically chunks into 25-item batches
    with table.batch_writer(overwrite_by_pkeys=['system_id', 'timestamp']) as batch:
        for row in partition_iter:
            batch.put_item(Item=row.asDict())
            count += 1
    
    return [count]
```

**Key implementation details:**

**1. Parallelism control:**
```python
# For 1M records, 20 partitions = 50K records per partition
# Each partition writes in chunks of 25
df_optimized = df.repartition(20)
```

**2. Write rate limiting:**
To avoid throttling on large datasets:
```python
def rate_limited_write(partition_iter, writes_per_sec=50):
    import time
    
    items = list(partition_iter)
    batch_delay = 25 / writes_per_sec  # seconds to wait between 25-item batches
    
    for i in range(0, len(items), 25):
        batch = items[i:i+25]
        # write batch
        time.sleep(batch_delay)
```

**3. Unprocessed items handling:**
BatchWriteItem can return unprocessed items if throttled:
```python
response = client.batch_write_item(
    RequestItems={
        'table_name': batch_requests
    }
)

# Retry unprocessed items
unprocessed = response.get('UnprocessedItems', {})
while unprocessed:
    time.sleep(1)  # backoff
    response = client.batch_write_item(RequestItems=unprocessed)
    unprocessed = response.get('UnprocessedItems', {})
```

**Real-world example:**
For a daily ETL job processing 5M records:
- Provisioned 500 WCU on DynamoDB
- Used 30 Spark executors × 2 cores = 60 parallel writers
- Each partition writes ~83K items in batches of 25
- Total time: ~15 minutes
- Zero throttling with 50% target capacity"

---

## **Monitoring & Performance**

### Q: "What CloudWatch metrics did you monitor for DynamoDB?"

**Answer:**
"I had a comprehensive monitoring strategy with CloudWatch metrics and alarms:

**Primary Metrics:**

**1. Capacity Consumption:**
- `ConsumedReadCapacityUnits` - Actual RCU usage
- `ConsumedWriteCapacityUnits` - Actual WCU usage  
- `ProvisionedReadCapacityUnits` - Configured capacity
- `ProvisionedWriteCapacityUnits` - Configured capacity

**Alarm**: Alert when consumed > 70% of provisioned

**2. Throttling:**
- `ReadThrottleEvents` - Number of throttled read requests
- `WriteThrottleEvents` - Number of throttled write requests
- `UserErrors` - Client-side errors (often throttling)

**Alarm**: Alert on ANY throttle events (should be zero in production)

**3. Latency:**
- `SuccessfulRequestLatency` - P50, P90, P99
- For GetItem, Query, PutItem operations separately

**Alarm**: Alert if P99 > 15ms for GetItem

**4. System Errors:**
- `SystemErrors` - DynamoDB-side errors
- `ConditionalCheckFailedRequests` - Failed conditional writes

**Dashboard I created:**
```python
import boto3

cloudwatch = boto3.client('cloudwatch')

# Create custom dashboard
dashboard_body = {
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/DynamoDB", "ConsumedReadCapacityUnits", {"stat": "Sum"}],
                    [".", "ProvisionedReadCapacityUnits", {"stat": "Average"}]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Read Capacity"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/DynamoDB", "ReadThrottleEvents", {"stat": "Sum"}],
                    [".", "WriteThrottleEvents", {"stat": "Sum"}]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "us-east-1",
                "title": "Throttling Events",
                "yAxis": {"left": {"min": 0}}
            }
        }
    ]
}
```

**SNS Alarms configuration:**
```python
# Create alarm for write throttling
cloudwatch.put_metric_alarm(
    AlarmName='DynamoDB-WriteThrottling',
    MetricName='WriteThrottleEvents',
    Namespace='AWS/DynamoDB',
    Statistic='Sum',
    Period=300,
    EvaluationPeriods=1,
    Threshold=1,
    ComparisonOperator='GreaterThanThreshold',
    AlarmActions=['arn:aws:sns:us-east-1:123456789:alerts']
)
```

**What I checked daily:**
- Throttling events (should be 0)
- Capacity utilization trend (looking for growth patterns)
- P99 latency (catching degradation early)
- Cost metrics (unexpected usage spikes)"

---

## **Scenario/Behavioral Questions**

### Q: "Tell me about a time when you had to migrate data from one DynamoDB table to another with a different schema."

**Answer:**
"At Quanted Technologies, we needed to migrate our monitoring metrics table because the original partition key design created hot partitions during high-traffic periods.

**Original schema:**
- PK: `date` (YYYY-MM-DD)
- SK: `system_id#timestamp`

Problem: All writes for a given day went to one partition, causing throttling.

**New schema:**
- PK: `system_id`
- SK: `timestamp`
- GSI: `date` (for date-based queries)

**Migration approach:**

**1. Dual-write phase (2 weeks):**
```python
def write_to_both_tables(item):
    # Write to old table
    old_table.put_item(Item=format_for_old_schema(item))
    
    # Write to new table
    new_table.put_item(Item=format_for_new_schema(item))
```

**2. Backfill historical data:**
```python
# PySpark job to migrate historical data
old_df = spark.read \
    .format("dynamodb") \
    .option("tableName", "old_monitoring_metrics") \
    .load()

# Transform schema
new_df = old_df.selectExpr(
    "system_id as system_id",
    "timestamp as timestamp", 
    "date as date",
    "metric_value",
    "status"
)

# Write to new table with rate limiting
new_df.write \
    .format("dynamodb") \
    .option("tableName", "new_monitoring_metrics") \
    .option("targetCapacity", "30") \
    .save()
```

**3. Verification phase:**
- Ran consistency checks comparing row counts
- Validated random samples of records matched
- Monitored both tables for 3 days

**4. Cutover:**
- Switched application reads to new table
- Monitored for issues for 24 hours
- Stopped writes to old table
- Kept old table for 30 days as backup

**Result:**
- Eliminated throttling completely
- Reduced costs by 40% (better capacity utilization)
- Improved query latency from 50ms P99 to 8ms P99

**Key lesson:** Always dual-write during migrations - never trust a one-time copy for production data."

---

### Q: "Describe a situation where your initial DynamoDB design didn't work well. How did you identify and fix it?"

**Answer:**
"Early in my DynamoDB work at Quanted, I made a classic mistake with GSI projection that caused cost and latency issues.

**The problem:**

I created a table for system health metrics:
- Base table: PK=system_id, SK=timestamp
- GSI: PK=status, SK=timestamp with `ProjectionType='ALL'`

The GSI was meant to query: "Show me all ERROR systems in the last hour"

**What went wrong:**

Each metric record was ~10 KB (included full JSON payloads, metadata, etc.). The GSI with `ALL` projection duplicated this entire 10 KB for every item, doubling storage costs and write costs.

**How I identified it:**

1. Monthly bill jumped 120%
2. Investigated using AWS Cost Explorer - saw DynamoDB write costs were double expected
3. Checked CloudWatch metrics - `ConsumedWriteCapacityUnits` for GSI was equal to base table
4. Realized `ALL` projection meant every base table write = 2 writes (base + GSI)

**The fix:**

Changed GSI projection to `KEYS_ONLY`:
```python
GlobalSecondaryIndexes=[
    {
        'IndexName': 'status-timestamp-index',
        'KeySchema': [
            {'AttributeName': 'status', 'KeyType': 'HASH'},
            {'AttributeName': 'timestamp', 'KeyType': 'RANGE'}
        ],
        'Projection': {
            'ProjectionType': 'KEYS_ONLY'  # Changed from ALL
        }
    }
]
```

Then modified queries to fetch full items:
```python
# Query GSI for system_ids
gsi_response = table.query(
    IndexName='status-timestamp-index',
    KeyConditionExpression=Key('status').eq('ERROR'),
    ProjectionExpression='system_id, timestamp'  # Only keys
)

# BatchGetItem to fetch full items
keys = [{'system_id': item['system_id'], 'timestamp': item['timestamp']} 
        for item in gsi_response['Items']]

full_items = dynamodb.batch_get_item(
    RequestItems={
        'table_name': {'Keys': keys}
    }
)
```

**Results:**
- Write costs: Reduced by 50%
- Storage costs: Reduced by 45%
- Query latency: Increased slightly (15ms → 25ms) due to additional BatchGetItem call, but still acceptable

**Key lesson:** Always use `KEYS_ONLY` or `INCLUDE` projection unless you absolutely need `ALL`. The cost savings are massive, and the extra query is usually negligible."

---

## **Red Flag Questions - Be Honest**

### Q: "Why DynamoDB over RDS/PostgreSQL for your use case?"

**Answer:**
"For our monitoring metrics use case at Quanted, DynamoDB was the right choice because:

**1. Access pattern alignment:**
- We only needed key-value lookups and time-range queries
- No complex JOINs required
- Pattern: Get metrics for system X in last hour = perfect for Query operation

**2. Scale characteristics:**
- Write volume: ~1000 writes/second during peak
- RDS would require significant vertical scaling
- DynamoDB scaled horizontally effortlessly

**3. Operational overhead:**
- No schema migrations needed for new metric types (schemaless)
- No index tuning required
- Managed service with automatic backups

**However, DynamoDB would NOT have been right if:**
- We needed complex analytics queries with JOINs
- We needed transactions across multiple entities
- The data model had many relationships
- We needed ACID guarantees for financial data

For example, if this were a billing system with invoices, line items, customers, and payments all related, I would absolutely choose RDS/PostgreSQL because of foreign keys, JOINs, and transaction support."

**Be honest about what you didn't do:** "I didn't use DynamoDB Streams or DynamoDB Accelerator (DAX) at Quanted. My use cases didn't require real-time change capture or sub-millisecond caching. If asked about them in detail, I'd acknowledge I don't have hands-on experience with those features."

---

These answers give you comprehensive, technically accurate responses that you can confidently defend in an interview. Practice articulating these in your own words, and be ready to go deeper on any topic. Would you like me to elaborate on any specific area?
