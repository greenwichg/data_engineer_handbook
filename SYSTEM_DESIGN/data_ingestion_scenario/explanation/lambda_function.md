# AWS Lambda Function - Comprehensive Deep Dive

This Lambda function serves as the **event-driven trigger** for your ETL pipeline. It acts as the "traffic controller" that decides what happens when files arrive in S3.

---

## 1. **High-Level Overview**

### Purpose

This Lambda function is the **entry point** of your data pipeline. When a file lands in S3, this function:
1. Identifies what the file is
2. Looks up configuration to determine how to handle it
3. Takes appropriate action (trigger ETL, move file, or send notification)

### Visual Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         LAMBDA FUNCTION FLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

    S3 Event (File Upload)
           │
           ▼
    ┌──────────────┐
    │ Lambda       │
    │ Triggered    │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Load Config  │  ◄── config/config.json
    │ from S3      │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ Find Match   │  Does filename match any job config?
    └──────┬───────┘
           │
     ┌─────┴─────┬─────────────┐
     │           │             │
     ▼           ▼             ▼
┌─────────┐ ┌─────────┐  ┌─────────────┐
│ NO      │ │INACTIVE │  │ACTIVE       │
│ MATCH   │ │ JOB     │  │ JOB         │
└────┬────┘ └────┬────┘  └──────┬──────┘
     │           │              │
     ▼           ▼              ▼
┌─────────┐ ┌─────────┐  ┌─────────────┐
│Move to  │ │ Send    │  │ Trigger     │
│new_files│ │ SNS     │  │ Step        │
│+ SNS    │ │ Alert   │  │ Functions   │
└─────────┘ └─────────┘  └─────────────┘
```

---

## 2. **Imports and AWS Clients**

```python
import json
import boto3
import os
import re
from datetime import datetime, timezone
from botocore.exceptions import ClientError
```

### Import Breakdown

| Import | Purpose |
|--------|---------|
| `json` | Parse and create JSON (config files, Step Functions input) |
| `boto3` | AWS SDK for Python - interact with AWS services |
| `os` | Access environment variables |
| `re` | Regular expressions for text sanitization |
| `datetime, timezone` | Generate timestamps in UTC |
| `ClientError` | Handle AWS-specific errors gracefully |

---

### AWS Clients

```python
# AWS clients
s3 = boto3.client("s3")
sns = boto3.client("sns")
sfn = boto3.client("stepfunctions")
```

| Client | Service | Purpose in this function |
|--------|---------|--------------------------|
| `s3` | Amazon S3 | Read config, move files |
| `sns` | Simple Notification Service | Send alerts/notifications |
| `sfn` | Step Functions | Trigger the ETL workflow |

**Why create clients at module level?**

```python
# GOOD: Module level (reused across invocations)
s3 = boto3.client("s3")  # Created once, kept in memory

def lambda_handler(event, context):
    s3.get_object(...)  # Uses existing client


# BAD: Inside handler (recreated every invocation)
def lambda_handler(event, context):
    s3 = boto3.client("s3")  # Created every time = slow!
    s3.get_object(...)
```

**Benefits of module-level clients:**
- **Connection reuse** - AWS SDK maintains connection pools
- **Faster cold starts** - Client initialization happens once
- **Lambda container reuse** - Subsequent invocations skip client creation

---

### Environment Variables

```python
# Environment variables
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
STEP_FUNCTION_ARN = os.environ["STEP_FUNCTION_ARN"]

CONFIG_KEY = "config/config.json"
```

| Variable | Purpose | Example Value |
|----------|---------|---------------|
| `SNS_TOPIC_ARN` | Where to send notifications | `arn:aws:sns:us-east-1:123456789:etl-alerts` |
| `STEP_FUNCTION_ARN` | Which state machine to trigger | `arn:aws:states:us-east-1:123456789:stateMachine:etl-pipeline` |
| `CONFIG_KEY` | Path to config file in S3 | `config/config.json` (hardcoded) |

**Why use environment variables?**

```python
# GOOD: Environment variable (configurable)
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
# Can change without code deployment
# Different values for dev/staging/prod

# BAD: Hardcoded (inflexible)
SNS_TOPIC_ARN = "arn:aws:sns:us-east-1:123456789:etl-alerts"
# Must redeploy to change
# Same value in all environments
```

**Setting environment variables in Lambda:**
```yaml
# AWS SAM template
Environment:
  Variables:
    SNS_TOPIC_ARN: !Ref AlertTopic
    STEP_FUNCTION_ARN: !Ref ETLStateMachine
```

---

## 3. **Utility Helpers**

### 3a. normalize() - Text Normalization

```python
def normalize(text):
    return text.strip().lower() if text else ""
```

#### Purpose
Standardizes text for reliable comparison by:
1. Removing leading/trailing whitespace
2. Converting to lowercase

#### Detailed Breakdown

```python
def normalize(text):
    # Handle None or empty string
    if text:
        return text.strip().lower()
    else:
        return ""
```

**The ternary expression:**
```python
text.strip().lower() if text else ""
#    ↑                    ↑      ↑
#    |                    |      └── Return empty string if text is falsy
#    |                    └── Condition: is text truthy?
#    └── Value if condition is True
```

#### Why Normalize?

**Problem:** File names can vary in formatting:
```
"Customers.csv"     vs  "customers.csv"      # Case difference
"  customers.csv"   vs  "customers.csv"      # Leading space
"customers.csv  "   vs  "customers.csv"      # Trailing space
```

**Solution:** Normalize both before comparing:
```python
normalize("  Customers.CSV  ")  # → "customers.csv"
normalize("customers.csv")       # → "customers.csv"
# Now they match!
```

#### Edge Cases Handled

| Input | Output | Explanation |
|-------|--------|-------------|
| `"Customers.CSV"` | `"customers.csv"` | Lowercased |
| `"  data.csv  "` | `"data.csv"` | Whitespace stripped |
| `""` | `""` | Empty string unchanged |
| `None` | `""` | None converted to empty string |

---

### 3b. sanitize() - Text Sanitization

```python
def sanitize(text):
    text = text.replace(" ", "-").replace("/", "-").replace(".", "-")
    return re.sub(r"[^a-zA-Z0-9_-]", "", text)[:50]
```

#### Purpose
Creates safe, clean identifiers for AWS resource names (like Step Functions execution names).

#### Step-by-Step Breakdown

```python
def sanitize(text):
    # Step 1: Replace common separators with hyphens
    text = text.replace(" ", "-")   # "my file" → "my-file"
    text = text.replace("/", "-")   # "data/file" → "data-file"
    text = text.replace(".", "-")   # "file.csv" → "file-csv"
    
    # Step 2: Remove any remaining invalid characters
    text = re.sub(r"[^a-zA-Z0-9_-]", "", text)
    #              ↑
    #              └── Keep only: letters, numbers, underscore, hyphen
    
    # Step 3: Truncate to 50 characters
    return text[:50]
```

#### Regex Explanation

```python
re.sub(r"[^a-zA-Z0-9_-]", "", text)
#       │ │           │  │
#       │ │           │  └── Replace with empty string (remove)
#       │ │           └── Hyphen (must be last in character class)
#       │ └── Allowed: a-z, A-Z, 0-9, underscore
#       └── ^ means "NOT these characters"
```

**Translation:** Remove any character that is NOT a letter, number, underscore, or hyphen.

#### Why Sanitize?

**AWS Step Functions execution names have rules:**
- Must be unique (within state machine)
- 1-80 characters
- Only: `a-zA-Z0-9-_`
- No spaces or special characters

**Without sanitization:**
```python
file_name = "Customer Data (2024).csv"
execution_name = f"run-{file_name}"
# Result: "run-Customer Data (2024).csv"  ← INVALID! Has spaces, parentheses, dot
```

**With sanitization:**
```python
file_name = "Customer Data (2024).csv"
sanitized = sanitize(file_name)
# Step 1: "Customer-Data-(2024)-csv"
# Step 2: "Customer-Data-2024-csv"  (parentheses removed)
# Step 3: "Customer-Data-2024-csv"  (already under 50 chars)
execution_name = f"run-{sanitized}"
# Result: "run-Customer-Data-2024-csv"  ← VALID!
```

#### Examples

| Input | Output | Explanation |
|-------|--------|-------------|
| `"customers.csv"` | `"customers-csv"` | Dot → hyphen |
| `"data/in/file.csv"` | `"data-in-file-csv"` | Slashes → hyphens |
| `"File (1).csv"` | `"File-1-csv"` | Parentheses removed |
| `"very_long_file_name_that_exceeds_fifty_characters_limit.csv"` | `"very_long_file_name_that_exceeds_fifty_characters"` | Truncated |
| `"file@#$%.csv"` | `"file-csv"` | Special chars removed |

---

## 4. **AWS Helper Functions**

### 4a. publish_notification() - SNS Publishing

```python
def publish_notification(subject, message):
    """Best-effort SNS publish"""
    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
    except Exception as error:
        print(f"SNS publish failed: {error}")
```

#### Purpose
Sends email/SMS notifications via SNS when events occur.

#### Parameter Breakdown

| Parameter | Type | Purpose | Example |
|-----------|------|---------|---------|
| `TopicArn` | string | SNS topic to publish to | `arn:aws:sns:us-east-1:123456789:alerts` |
| `Subject` | string | Email subject line (max 100 chars) | `"New File Alert"` |
| `Message` | string | Notification body | `"File uploaded: customers.csv"` |

#### "Best-Effort" Pattern

```python
try:
    sns.publish(...)
except Exception as error:
    print(f"SNS publish failed: {error}")
    # NO re-raise! Function continues
```

**Why "best-effort"?**

Notifications are **non-critical** - the pipeline should continue even if SNS fails:

```
CRITICAL PATH (must succeed):
Upload → Match Config → Trigger ETL → Load Data
                          ↓
OPTIONAL (can fail):    Send SNS
```

**Comparison:**

| Approach | Code | Behavior on SNS Failure |
|----------|------|-------------------------|
| Best-effort | `except: print()` | Log error, continue |
| Critical | `except: raise` | Lambda fails, retry |
| Silent | No try/except | Lambda fails, no info |

#### What SNS Does

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Lambda    │ ───► │  SNS Topic  │ ───► │ Subscribers │
│  (publish)  │      │             │      │             │
└─────────────┘      └─────────────┘      └─────────────┘
                                                │
                            ┌───────────────────┼───────────────────┐
                            ▼                   ▼                   ▼
                      ┌──────────┐        ┌──────────┐        ┌──────────┐
                      │  Email   │        │   SMS    │        │  Lambda  │
                      │  inbox   │        │  phone   │        │ function │
                      └──────────┘        └──────────┘        └──────────┘
```

---

### 4b. move_s3_object() - File Movement

```python
def move_s3_object(bucket_name, source_key, destination_key):
    """Move object within same bucket"""
    s3.copy_object(
        Bucket=bucket_name,
        CopySource={"Bucket": bucket_name, "Key": source_key},
        Key=destination_key
    )
    s3.delete_object(Bucket=bucket_name, Key=source_key)
```

#### Purpose
Moves a file from one location to another within the same S3 bucket.

#### Why Copy + Delete?

**S3 doesn't have a native "move" operation.** You must:
1. Copy the object to new location
2. Delete the original

```
BEFORE:
s3://bucket/
├── data/in/customers.csv    ← Original file
└── data/new_files/          ← Empty

AFTER copy_object():
s3://bucket/
├── data/in/customers.csv    ← Still exists!
└── data/new_files/
    └── customers.csv        ← Copy created

AFTER delete_object():
s3://bucket/
├── data/in/                 ← Original deleted
└── data/new_files/
    └── customers.csv        ← Only copy remains
```

#### Parameter Breakdown

```python
s3.copy_object(
    Bucket=bucket_name,                              # Destination bucket
    CopySource={"Bucket": bucket_name, "Key": source_key},  # Source location
    Key=destination_key                              # Destination path
)
```

| Parameter | Value | Example |
|-----------|-------|---------|
| `Bucket` | Destination bucket | `"my-data-bucket"` |
| `CopySource.Bucket` | Source bucket | `"my-data-bucket"` |
| `CopySource.Key` | Source path | `"data/in/customers.csv"` |
| `Key` | Destination path | `"data/new_files/customers.csv"` |

#### Safety Consideration

**Current code has a potential issue:**

```python
# If delete fails after copy succeeds, you have duplicates!
s3.copy_object(...)  # Success ✓
s3.delete_object(...)  # Fails ✗ → File exists in BOTH locations
```

**Safer approach:**

```python
def move_s3_object(bucket_name, source_key, destination_key):
    try:
        s3.copy_object(
            Bucket=bucket_name,
            CopySource={"Bucket": bucket_name, "Key": source_key},
            Key=destination_key
        )
        s3.delete_object(Bucket=bucket_name, Key=source_key)
    except Exception as e:
        # Cleanup: delete destination if copy succeeded but delete failed
        try:
            s3.delete_object(Bucket=bucket_name, Key=destination_key)
        except:
            pass
        raise e
```

---

### 4c. start_state_machine_execution() - Trigger Step Functions

```python
def start_state_machine_execution(file_name, job_config):
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    execution_name = f"run-{sanitize(file_name)}-{timestamp}"

    try:
        sfn.start_execution(
            stateMachineArn=STEP_FUNCTION_ARN,
            name=execution_name,
            input=json.dumps({
                "glue_jobs": [
                    {
                        "job_id": job_config["job_id"],
                        "job_name": job_config["job_name"],
                        "source_file_name": file_name,
                        "target_table": job_config["target_table"],
                        "upsert_keys": job_config["upsert_keys"]
                    }
                ]
            })
        )
        return {"status": "triggered", "execution": execution_name}

    except ClientError as error:
        if error.response["Error"]["Code"] == "ExecutionAlreadyExists":
            return {"status": "already_running"}
        raise
```

#### Purpose
Starts the Step Functions state machine to run the ETL pipeline.

#### Step-by-Step Breakdown

##### Step 1: Generate Unique Execution Name

```python
timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
# Example: "20250119143052" (Jan 19, 2025, 2:30:52 PM UTC)

execution_name = f"run-{sanitize(file_name)}-{timestamp}"
# Example: "run-customers-csv-20250119143052"
```

**Why include timestamp?**
- Step Functions requires **unique** execution names
- Same file might be uploaded multiple times
- Timestamp ensures uniqueness

**Format breakdown:**
```
run-customers-csv-20250119143052
│   │             │
│   │             └── Timestamp (YYYYMMDDHHmmss)
│   └── Sanitized filename
└── Prefix for identification
```

##### Step 2: Call Step Functions API

```python
sfn.start_execution(
    stateMachineArn=STEP_FUNCTION_ARN,    # Which state machine
    name=execution_name,                   # Unique execution ID
    input=json.dumps({...})               # Input data (must be JSON string)
)
```

**API Parameters:**

| Parameter | Type | Required | Purpose |
|-----------|------|----------|---------|
| `stateMachineArn` | string | Yes | ARN of state machine to execute |
| `name` | string | No (but recommended) | Unique identifier for this execution |
| `input` | string | No | JSON-formatted input data |

##### Step 3: Build Input Payload

```python
input=json.dumps({
    "glue_jobs": [
        {
            "job_id": job_config["job_id"],
            "job_name": job_config["job_name"],
            "source_file_name": file_name,
            "target_table": job_config["target_table"],
            "upsert_keys": job_config["upsert_keys"]
        }
    ]
})
```

**Why wrap in `"glue_jobs"` array?**

Remember the Step Functions state machine:
```json
{
  "ItemsPath": "$.glue_jobs",  // Expects array at this path
  ...
}
```

The state machine iterates over `glue_jobs` array, so we must provide that structure.

**Example generated input:**
```json
{
  "glue_jobs": [
    {
      "job_id": "JOB001",
      "job_name": "customers_etl",
      "source_file_name": "customers.csv",
      "target_table": "customers",
      "upsert_keys": ["customer_id"]
    }
  ]
}
```

##### Step 4: Handle Duplicate Execution

```python
except ClientError as error:
    if error.response["Error"]["Code"] == "ExecutionAlreadyExists":
        return {"status": "already_running"}
    raise
```

**Scenario:** If same file is uploaded twice quickly, execution name might collide.

**Error structure:**
```python
error.response = {
    "Error": {
        "Code": "ExecutionAlreadyExists",
        "Message": "Execution already exists: run-customers-csv-20250119143052"
    }
}
```

**Handling logic:**
```
┌─────────────────────────────────────────────┐
│ ExecutionAlreadyExists error?               │
├─────────────────────────────────────────────┤
│ YES → Return {"status": "already_running"}  │
│       (File already being processed)        │
│                                             │
│ NO  → Re-raise the error                    │
│       (Some other problem occurred)         │
└─────────────────────────────────────────────┘
```

#### Return Values

| Scenario | Return Value |
|----------|--------------|
| Success | `{"status": "triggered", "execution": "run-customers-csv-20250119143052"}` |
| Duplicate | `{"status": "already_running"}` |
| Other error | Exception raised |

---

## 5. **Configuration Helpers**

### 5a. load_job_configurations() - Load Config from S3

```python
def load_job_configurations(bucket_name):
    response = s3.get_object(Bucket=bucket_name, Key=CONFIG_KEY)
    job_configurations = json.loads(response["Body"].read())

    if not isinstance(job_configurations, list):
        raise Exception("config.json must be a list of job definitions")

    return job_configurations
```

#### Purpose
Loads the job configuration file from S3 and validates its structure.

#### Step-by-Step Breakdown

##### Step 1: Fetch from S3

```python
response = s3.get_object(Bucket=bucket_name, Key=CONFIG_KEY)
# CONFIG_KEY = "config/config.json"
```

**S3 get_object response structure:**
```python
response = {
    "Body": <StreamingBody>,      # File contents (stream)
    "ContentType": "application/json",
    "ContentLength": 1234,
    "LastModified": datetime(...),
    "ETag": "abc123...",
    # ... other metadata
}
```

##### Step 2: Read and Parse JSON

```python
job_configurations = json.loads(response["Body"].read())
#                              │              │
#                              │              └── Read stream to bytes
#                              └── Parse JSON string to Python object
```

**Flow:**
```
S3 Object → StreamingBody → bytes → json.loads() → Python list/dict
```

##### Step 3: Validate Structure

```python
if not isinstance(job_configurations, list):
    raise Exception("config.json must be a list of job definitions")
```

**Why validate?**

The code expects a **list** of job configurations:
```json
// VALID (list)
[
  {"job_id": "JOB001", ...},
  {"job_id": "JOB002", ...}
]

// INVALID (object)
{
  "jobs": [...]  // Wrapped in object - will fail!
}
```

#### Expected Config File Structure

**File location:** `s3://{bucket}/config/config.json`

```json
[
  {
    "job_id": "JOB001",
    "job_name": "customers_etl",
    "source_file_name": "customers.csv",
    "target_table": "customers",
    "upsert_keys": ["customer_id"],
    "is_active": true
  },
  {
    "job_id": "JOB002",
    "job_name": "orders_etl",
    "source_file_name": "orders.csv",
    "target_table": "orders",
    "upsert_keys": ["order_id", "customer_id"],
    "is_active": true
  },
  {
    "job_id": "JOB003",
    "job_name": "products_etl",
    "source_file_name": "products.csv",
    "target_table": "products",
    "upsert_keys": ["product_id"],
    "is_active": false
  }
]
```

**Field descriptions:**

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `job_id` | string | Yes | Unique identifier for the job |
| `job_name` | string | Yes | Name for logging/tracking |
| `source_file_name` | string | Yes | Expected filename to match |
| `target_table` | string | Yes | Redshift table to load into |
| `upsert_keys` | array | Yes | Columns for upsert matching |
| `is_active` | boolean | Yes | Whether job should run |

---

### 5b. find_matching_job() - Match File to Config

```python
def find_matching_job(job_configurations, s3_object_key):
    uploaded_file_name = normalize(s3_object_key.split("/")[-1])

    return next(
        (
            job_config
            for job_config in job_configurations
            if normalize(
                job_config.get("source_file_name", "").split("/")[-1]
            ) == uploaded_file_name
        ),
        None
    )
```

#### Purpose
Finds the job configuration that matches the uploaded file's name.

#### Step-by-Step Breakdown

##### Step 1: Extract and Normalize Uploaded Filename

```python
uploaded_file_name = normalize(s3_object_key.split("/")[-1])
```

**Example:**
```python
s3_object_key = "data/in/Customers.CSV"
#                        └─────────────┘
#                         split("/")[-1] = "Customers.CSV"
#                         normalize() = "customers.csv"
```

##### Step 2: Generator Expression with Filtering

```python
(
    job_config
    for job_config in job_configurations
    if normalize(
        job_config.get("source_file_name", "").split("/")[-1]
    ) == uploaded_file_name
)
```

**This is a generator expression (lazy evaluation).** Let's break it down:

```python
# Equivalent to:
def find_matches():
    for job_config in job_configurations:
        config_filename = job_config.get("source_file_name", "")
        config_filename = config_filename.split("/")[-1]
        config_filename = normalize(config_filename)
        
        if config_filename == uploaded_file_name:
            yield job_config  # Generator yields matches
```

##### Step 3: Get First Match with next()

```python
return next(
    (generator_expression),
    None  # Default if no match found
)
```

**`next()` function:**
- Returns the first item from an iterator
- If iterator is empty, returns the default value (None)

**Why use `next()` instead of a loop?**

```python
# WITH next() - clean and concise
return next((x for x in items if condition), None)

# WITHOUT next() - more verbose
for x in items:
    if condition:
        return x
return None
```

#### Matching Logic Visualization

```
Uploaded file: "data/in/Customers.CSV"
                         │
                         ▼
              normalize("Customers.CSV")
                         │
                         ▼
                  "customers.csv"


Config jobs:
┌─────────────────────────────────────────────────────┐
│ job_id: JOB001                                       │
│ source_file_name: "customers.csv"                   │
│ normalize() → "customers.csv"                       │
│ Match: "customers.csv" == "customers.csv" → YES ✓   │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
                  Return JOB001 config
```

#### Edge Cases

| Uploaded File | Config File | Match? | Reason |
|---------------|-------------|--------|--------|
| `customers.csv` | `customers.csv` | ✓ | Exact match |
| `Customers.CSV` | `customers.csv` | ✓ | Normalized |
| `data/in/customers.csv` | `customers.csv` | ✓ | Path stripped |
| `orders.csv` | `customers.csv` | ✗ | Different name |
| `customer.csv` | `customers.csv` | ✗ | Singular vs plural |
| `new_file.csv` | (not in config) | ✗ | Returns None |

---

## 6. **Lambda Entry Point**

```python
def lambda_handler(event, context):
```

This is the main function that AWS Lambda invokes when the function is triggered.

### Parameters

| Parameter | Type | Purpose |
|-----------|------|---------|
| `event` | dict | Contains trigger data (S3 event details) |
| `context` | object | Lambda runtime information (timeout, memory, request ID) |

### Event Structure (S3 via EventBridge)

```python
event = {
    "version": "0",
    "id": "abc123-...",
    "detail-type": "Object Created",
    "source": "aws.s3",
    "account": "123456789012",
    "time": "2025-01-19T14:30:52Z",
    "region": "us-east-1",
    "detail": {
        "version": "0",
        "bucket": {
            "name": "my-data-bucket"
        },
        "object": {
            "key": "data/in/customers.csv",
            "size": 1234,
            "etag": "abc123..."
        },
        "request-id": "xyz789...",
        "requester": "123456789012"
    }
}
```

**Why EventBridge format instead of S3 native?**

| S3 Native Event | EventBridge Event |
|-----------------|-------------------|
| `event["Records"][0]["s3"]["bucket"]["name"]` | `event["detail"]["bucket"]["name"]` |
| Must parse `Records` array | Direct access to `detail` |
| Batch events possible | Single event per trigger |
| Older format | Modern, consistent format |

---

### Extract Event Data

```python
bucket_name = event["detail"]["bucket"]["name"]
object_key = event["detail"]["object"]["key"]
file_name = object_key.split("/")[-1]

print(f"Processing file: {file_name}")
```

**Extraction flow:**
```python
# Full S3 path: s3://my-data-bucket/data/in/customers.csv

bucket_name = "my-data-bucket"           # Bucket name
object_key = "data/in/customers.csv"     # Full path within bucket
file_name = "customers.csv"               # Just the filename
```

---

### Load Configuration

```python
# Load config
job_configurations = load_job_configurations(bucket_name)

# Match job
matching_job = find_matching_job(job_configurations, object_key)
```

**Flow:**
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Load config    │ ──► │   Find match    │ ──► │  matching_job   │
│  from S3        │     │   for filename  │     │  (or None)      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

### Case 1: NOT CONFIGURED → Move + Notify

```python
if not matching_job:
    destination_key = f"data/new_files/{file_name}"

    move_s3_object(bucket_name, object_key, destination_key)

    publish_notification(
        subject="New / Not Configured File",
        message=(
            f"File not found in config.json\n"
            f"Original: {object_key}\n"
            f"Moved to: {destination_key}"
        )
    )

    return {
        "status": "not_configured",
        "moved_to": destination_key
    }
```

#### When This Happens

Someone uploaded a file that **doesn't have a matching job configuration**.

#### What Happens

1. **Move file** to `data/new_files/` folder for manual review
2. **Send notification** so admin knows about the new file
3. **Return status** indicating file wasn't processed

#### Visual Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Uploaded: data/in/mystery_file.csv                              │
│                                                                  │
│ Config search: No match found!                                   │
│                                                                  │
│ Actions:                                                         │
│   1. Move: data/in/mystery_file.csv → data/new_files/mystery_file.csv │
│   2. SNS: "New / Not Configured File" notification               │
│   3. Return: {"status": "not_configured", ...}                   │
└─────────────────────────────────────────────────────────────────┘
```

#### Why Move Instead of Delete?

- **Preserves data** - File might be important
- **Audit trail** - Can see what was uploaded
- **Easy recovery** - Admin can add config and re-process
- **Investigation** - Determine if this is a new data source

---

### Case 2: CONFIGURED but INACTIVE → Notify Only

```python
if not matching_job.get("is_active"):
    publish_notification(
        subject="Inactive Job",
        message=(
            f"File: {file_name}\n"
            f"Job ID: {matching_job.get('job_id')}"
        )
    )

    return {
        "status": "inactive",
        "job_id": matching_job.get("job_id")
    }
```

#### When This Happens

File matches a job config, but that job has `"is_active": false`.

#### Why Have Inactive Jobs?

- **Temporarily disabled** - Maintenance, debugging
- **Deprecated** - Old data source being phased out
- **Testing** - New job not ready for production
- **Seasonal** - Only needed certain times

#### What Happens

1. **Send notification** - Alert that inactive job received data
2. **File stays in place** - Not moved or processed
3. **Return status** - Indicate job is inactive

#### Visual Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Uploaded: data/in/products.csv                                   │
│                                                                  │
│ Config match: JOB003 (products_etl)                             │
│ is_active: false                                                 │
│                                                                  │
│ Actions:                                                         │
│   1. SNS: "Inactive Job" notification                           │
│   2. File stays at: data/in/products.csv                        │
│   3. Return: {"status": "inactive", "job_id": "JOB003"}         │
└─────────────────────────────────────────────────────────────────┘
```

**Note:** The file is NOT moved. This might be intentional (for later processing) or a bug (file accumulates). Consider if this is desired behavior.

---

### Case 3: CONFIGURED & ACTIVE → Trigger Pipeline

```python
result = start_state_machine_execution(file_name, matching_job)

print(f"Step Function triggered: {result}")

return result
```

#### When This Happens

File matches an **active** job configuration - this is the "happy path."

#### What Happens

1. **Trigger Step Functions** with job parameters
2. **Log result** for CloudWatch
3. **Return execution details**

#### Visual Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Uploaded: data/in/customers.csv                                  │
│                                                                  │
│ Config match: JOB001 (customers_etl)                            │
│ is_active: true                                                  │
│                                                                  │
│ Actions:                                                         │
│   1. Start Step Functions execution                              │
│   2. Return: {"status": "triggered", "execution": "run-..."}     │
│                                                                  │
│ Step Functions then:                                             │
│   → Runs Glue job                                                │
│   → Loads data to Redshift                                       │
│   → Archives/cleans up file                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 7. **Complete Execution Flow Diagram**

```
                            ┌──────────────────────┐
                            │    S3 Bucket         │
                            │  (File Uploaded)     │
                            └──────────┬───────────┘
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │    EventBridge       │
                            │  (S3 Object Created) │
                            └──────────┬───────────┘
                                       │
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                              LAMBDA FUNCTION                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ 1. EXTRACT EVENT DATA                                                    │ │
│  │    bucket_name = event["detail"]["bucket"]["name"]                       │ │
│  │    object_key = event["detail"]["object"]["key"]                         │ │
│  │    file_name = "customers.csv"                                           │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                       │
│                                       ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ 2. LOAD CONFIG FROM S3                                                   │ │
│  │    s3.get_object(Bucket, "config/config.json")                          │ │
│  │    → List of job configurations                                          │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                       │
│                                       ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ 3. FIND MATCHING JOB                                                     │ │
│  │    Compare normalized filenames                                          │ │
│  │    → matching_job (or None)                                              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                       │
│                    ┌──────────────────┼──────────────────┐                   │
│                    │                  │                  │                   │
│                    ▼                  ▼                  ▼                   │
│           ┌──────────────┐   ┌──────────────┐   ┌──────────────┐            │
│           │  NO MATCH    │   │   INACTIVE   │   │    ACTIVE    │            │
│           │              │   │              │   │              │            │
│           │ • Move file  │   │ • Send SNS   │   │ • Trigger    │            │
│           │   to new_    │   │   alert      │   │   Step       │            │
│           │   files/     │   │              │   │   Functions  │            │
│           │ • Send SNS   │   │              │   │              │            │
│           └──────┬───────┘   └──────┬───────┘   └──────┬───────┘            │
│                  │                  │                  │                     │
│                  ▼                  ▼                  ▼                     │
│           ┌──────────────┐   ┌──────────────┐   ┌──────────────┐            │
│           │   RETURN     │   │   RETURN     │   │   RETURN     │            │
│           │ {status:     │   │ {status:     │   │ {status:     │            │
│           │  "not_       │   │  "inactive"} │   │  "triggered"}│            │
│           │  configured"}│   │              │   │              │            │
│           └──────────────┘   └──────────────┘   └──────────────┘            │
│                                                        │                     │
└────────────────────────────────────────────────────────┼─────────────────────┘
                                                         │
                                                         ▼
                                              ┌──────────────────────┐
                                              │   Step Functions     │
                                              │   State Machine      │
                                              │                      │
                                              │   → Glue Job         │
                                              │   → Redshift Load    │
                                              │   → Archive File     │
                                              └──────────────────────┘
```

---

## 8. **IAM Permissions Required**

For this Lambda function to work, it needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-data-bucket/*"
      ]
    },
    {
      "Sid": "SNSPublish",
      "Effect": "Allow",
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:us-east-1:123456789:etl-alerts"
    },
    {
      "Sid": "StepFunctionsStart",
      "Effect": "Allow",
      "Action": "states:StartExecution",
      "Resource": "arn:aws:states:us-east-1:123456789:stateMachine:etl-pipeline"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Permission breakdown:**

| Permission | Purpose |
|------------|---------|
| `s3:GetObject` | Read config.json |
| `s3:PutObject` | Copy file during move |
| `s3:DeleteObject` | Delete original after move |
| `sns:Publish` | Send notifications |
| `states:StartExecution` | Trigger Step Functions |
| `logs:*` | Write CloudWatch logs |

---

## 9. **EventBridge Rule (Trigger)**

To trigger this Lambda when files arrive, you need an EventBridge rule:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": {
      "name": ["my-data-bucket"]
    },
    "object": {
      "key": [{
        "prefix": "data/in/"
      }]
    }
  }
}
```

**This rule triggers Lambda when:**
- Source: S3
- Event: Object Created (file uploaded)
- Bucket: `my-data-bucket`
- Path: Starts with `data/in/`

---

## 10. **Potential Improvements**

### 10a. Add Error Handling for Config Load

```python
def load_job_configurations(bucket_name):
    try:
        response = s3.get_object(Bucket=bucket_name, Key=CONFIG_KEY)
        job_configurations = json.loads(response["Body"].read())
    except s3.exceptions.NoSuchKey:
        raise Exception(f"Config file not found: s3://{bucket_name}/{CONFIG_KEY}")
    except json.JSONDecodeError as e:
        raise Exception(f"Invalid JSON in config file: {e}")

    if not isinstance(job_configurations, list):
        raise Exception("config.json must be a list of job definitions")

    return job_configurations
```

### 10b. Add Logging Throughout

```python
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event received: {json.dumps(event)}")
    
    # ... processing ...
    
    logger.info(f"Processing complete: {result}")
    return result
```

### 10c. Handle Inactive Job File

Currently, inactive job files stay in `data/in/`. Consider:

```python
if not matching_job.get("is_active"):
    # Option: Move to inactive folder
    destination_key = f"data/inactive/{file_name}"
    move_s3_object(bucket_name, object_key, destination_key)
    
    publish_notification(...)
```

### 10d. Add Validation for Required Config Fields

```python
def validate_job_config(job_config):
    required_fields = ["job_id", "job_name", "source_file_name", "target_table", "upsert_keys"]
    missing = [f for f in required_fields if f not in job_config]
    if missing:
        raise ValueError(f"Job config missing required fields: {missing}")
```

---

## Summary Table

| Component | Purpose |
|-----------|---------|
| `normalize()` | Standardize text for comparison (lowercase, trim) |
| `sanitize()` | Create safe AWS resource names |
| `publish_notification()` | Send SNS alerts (best-effort) |
| `move_s3_object()` | Move files within S3 |
| `start_state_machine_execution()` | Trigger Step Functions pipeline |
| `load_job_configurations()` | Load config.json from S3 |
| `find_matching_job()` | Match filename to job config |
| `lambda_handler()` | Main entry point - orchestrates all logic |

---

Would you like me to explain any specific part in more detail, or show how to enhance this Lambda function with additional features?