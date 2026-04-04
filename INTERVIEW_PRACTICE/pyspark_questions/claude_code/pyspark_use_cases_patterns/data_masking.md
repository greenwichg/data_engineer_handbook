# PySpark Implementation: Data Masking and Anonymization

## Problem Statement

Implement data masking and anonymization techniques for PII (Personally Identifiable Information) in PySpark. Given a dataset containing sensitive fields like emails, phone numbers, SSNs, and names, apply various masking strategies: hashing, partial masking, tokenization, and generalization. This is a common interview question at companies handling sensitive data (healthcare, fintech, GDPR-compliant organizations) and tests your understanding of data privacy engineering.

### Sample Data

| user_id | full_name     | email                | phone        | ssn         | salary | zip_code |
|---------|---------------|----------------------|--------------|-------------|--------|----------|
| 1       | Alice Johnson | alice@example.com    | 555-123-4567 | 123-45-6789 | 95000  | 10001    |
| 2       | Bob Smith     | bob.smith@corp.com   | 555-987-6543 | 987-65-4321 | 120000 | 90210    |
| 3       | Carol Davis   | carol.d@email.org    | 555-456-7890 | 456-78-9012 | 85000  | 30301    |
| 4       | Dave Wilson   | dave.w@company.net   | 555-321-0987 | 321-09-8765 | 150000 | 60601    |

### Expected Output

| user_id | full_name  | email_hashed                     | phone_masked | ssn_masked  | salary_range | zip_3 |
|---------|------------|----------------------------------|--------------|-------------|--------------|-------|
| 1       | A*** J***  | a]sha256hash[@example.com        | ***-***-4567 | ***-**-6789 | 90K-100K     | 100   |
| 2       | B*** S***  | b]sha256hash[@corp.com           | ***-***-6543 | ***-**-4321 | 120K-130K    | 902   |
| 3       | C*** D***  | c]sha256hash[@email.org          | ***-***-7890 | ***-**-9012 | 80K-90K      | 303   |
| 4       | D*** W***  | d]sha256hash[@company.net        | ***-***-0987 | ***-**-8765 | 150K-160K    | 606   |

---

## Method 1: Built-in Functions for Data Masking

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StringType

# Initialize Spark
spark = SparkSession.builder \
    .appName("Data Masking and Anonymization") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
data = [
    (1, "Alice Johnson", "alice@example.com", "555-123-4567", "123-45-6789", 95000, "10001"),
    (2, "Bob Smith", "bob.smith@corp.com", "555-987-6543", "987-65-4321", 120000, "90210"),
    (3, "Carol Davis", "carol.d@email.org", "555-456-7890", "456-78-9012", 85000, "30301"),
    (4, "Dave Wilson", "dave.w@company.net", "555-321-0987", "321-09-8765", 150000, "60601"),
]

df = spark.createDataFrame(
    data,
    ["user_id", "full_name", "email", "phone", "ssn", "salary", "zip_code"]
)

print("=== Original Data ===")
df.show(truncate=False)

# --- 1. Hash email (SHA-256) - deterministic pseudonymization ---
masked_df = df.withColumn(
    "email_hashed",
    F.sha2(F.col("email"), 256)
)

# --- 2. Partial email masking: keep first char and domain ---
masked_df = masked_df.withColumn(
    "email_masked",
    F.concat(
        F.substring("email", 1, 1),
        F.lit("***@"),
        F.substring_index("email", "@", -1)
    )
)

# --- 3. Phone masking: show only last 4 digits ---
masked_df = masked_df.withColumn(
    "phone_masked",
    F.regexp_replace("phone", r"^\d{3}-\d{3}", "***-***")
)

# --- 4. SSN masking: show only last 4 digits ---
masked_df = masked_df.withColumn(
    "ssn_masked",
    F.concat(F.lit("***-**-"), F.substring("ssn", 8, 4))
)

# --- 5. Name masking: first letter + asterisks ---
masked_df = masked_df.withColumn(
    "name_masked",
    F.concat(
        F.substring(F.split("full_name", " ")[0], 1, 1),
        F.lit("*** "),
        F.substring(F.split("full_name", " ")[1], 1, 1),
        F.lit("***")
    )
)

# --- 6. Salary generalization: bucket into ranges ---
masked_df = masked_df.withColumn(
    "salary_range",
    F.concat(
        (F.floor(F.col("salary") / 10000) * 10).cast("string"),
        F.lit("K-"),
        ((F.floor(F.col("salary") / 10000) + 1) * 10).cast("string"),
        F.lit("K")
    )
)

# --- 7. Zip code generalization: keep first 3 digits ---
masked_df = masked_df.withColumn(
    "zip_3",
    F.substring("zip_code", 1, 3)
)

# Show masked output
print("=== Masked Data ===")
masked_df.select(
    "user_id", "name_masked", "email_masked", "phone_masked",
    "ssn_masked", "salary_range", "zip_3"
).show(truncate=False)

print("=== Email Hashes (for deterministic matching) ===")
masked_df.select("user_id", "email_hashed").show(truncate=False)

spark.stop()
```

## Method 2: UDF-Based Tokenization and Advanced Masking

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StringType
import hashlib
import uuid

spark = SparkSession.builder \
    .appName("Data Masking - Tokenization") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
data = [
    (1, "Alice Johnson", "alice@example.com", "555-123-4567", "123-45-6789", 95000),
    (2, "Bob Smith", "bob.smith@corp.com", "555-987-6543", "987-65-4321", 120000),
    (3, "Carol Davis", "carol.d@email.org", "555-456-7890", "456-78-9012", 85000),
    (4, "Dave Wilson", "dave.w@company.net", "555-321-0987", "321-09-8765", 150000),
]

df = spark.createDataFrame(
    data,
    ["user_id", "full_name", "email", "phone", "ssn", "salary"]
)

# --- Tokenization UDF: Replace sensitive value with a consistent token ---
# Uses HMAC with a secret key for deterministic but irreversible tokenization
SECRET_KEY = "my-secret-salt-key-2024"

@F.udf(StringType())
def tokenize(value):
    """Create a deterministic token from a sensitive value using HMAC."""
    if value is None:
        return None
    import hmac
    token = hmac.new(
        SECRET_KEY.encode(),
        value.encode(),
        hashlib.sha256
    ).hexdigest()[:16]
    return f"TOK_{token}"

# --- Format-preserving masking UDF ---
@F.udf(StringType())
def mask_preserving_format(value, mask_char="*"):
    """Mask characters but preserve format (dashes, dots, @)."""
    if value is None:
        return None
    result = []
    visible_count = 0
    for i, ch in enumerate(reversed(value)):
        if ch in "-. @":
            result.append(ch)
        elif visible_count < 4:
            result.append(ch)
            visible_count += 1
        else:
            result.append(mask_char)
    return "".join(reversed(result))

# --- K-Anonymity: generalize age and zip for k-anonymity ---
@F.udf(StringType())
def generalize_number(value, bucket_size=10):
    """Generalize a number to a range for k-anonymity."""
    if value is None:
        return None
    val = int(value)
    lower = (val // bucket_size) * bucket_size
    upper = lower + bucket_size
    return f"{lower}-{upper}"

# Apply tokenization
tokenized_df = df \
    .withColumn("email_token", tokenize(F.col("email"))) \
    .withColumn("ssn_token", tokenize(F.col("ssn"))) \
    .withColumn("phone_format_masked", mask_preserving_format(F.col("phone")))

print("=== Tokenized Data ===")
tokenized_df.select(
    "user_id", "email_token", "ssn_token", "phone_format_masked"
).show(truncate=False)

# --- Data suppression: remove fields entirely based on sensitivity ---
# High sensitivity fields are dropped, medium are masked, low are kept
high_sensitivity = ["ssn"]
medium_sensitivity = ["email", "phone", "full_name"]
low_sensitivity = ["user_id", "salary"]

suppressed_df = df.drop(*high_sensitivity)
for col_name in medium_sensitivity:
    suppressed_df = suppressed_df.withColumn(
        col_name,
        F.sha2(F.col(col_name), 256)
    )

print("=== Suppressed/Hashed Data ===")
suppressed_df.show(truncate=False)

# --- Demonstrate consistency: same input always produces same token ---
print("=== Consistency Check ===")
test_data = [
    (1, "alice@example.com"),
    (2, "alice@example.com"),  # Same email, different record
    (3, "bob.smith@corp.com"),
]
test_df = spark.createDataFrame(test_data, ["id", "email"])
test_df.withColumn("token", tokenize("email")).show(truncate=False)

spark.stop()
```

## Method 3: Column-Level Masking Policy with SQL Views

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Data Masking - View-Based Policy") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
data = [
    (1, "Alice Johnson", "alice@example.com", "555-123-4567", 95000),
    (2, "Bob Smith", "bob.smith@corp.com", "555-987-6543", 120000),
    (3, "Carol Davis", "carol.d@email.org", "555-456-7890", 85000),
]

df = spark.createDataFrame(data, ["user_id", "full_name", "email", "phone", "salary"])
df.createOrReplaceTempView("raw_users")

# --- Create masked views for different access levels ---

# Level 1: Analysts (heavy masking)
spark.sql("""
    CREATE OR REPLACE TEMP VIEW users_analyst AS
    SELECT
        user_id,
        CONCAT(LEFT(full_name, 1), '***') AS full_name,
        CONCAT(LEFT(email, 1), '***@', SUBSTRING_INDEX(email, '@', -1)) AS email,
        CONCAT('***-***-', RIGHT(phone, 4)) AS phone,
        FLOOR(salary / 10000) * 10000 AS salary_bucket
    FROM raw_users
""")

# Level 2: Managers (partial masking)
spark.sql("""
    CREATE OR REPLACE TEMP VIEW users_manager AS
    SELECT
        user_id,
        full_name,
        CONCAT(LEFT(email, 3), '***@', SUBSTRING_INDEX(email, '@', -1)) AS email,
        CONCAT('***-', RIGHT(phone, 8)) AS phone,
        salary
    FROM raw_users
""")

# Level 3: Admin (no masking)
spark.sql("""
    CREATE OR REPLACE TEMP VIEW users_admin AS
    SELECT * FROM raw_users
""")

print("=== Analyst View ===")
spark.sql("SELECT * FROM users_analyst").show(truncate=False)

print("=== Manager View ===")
spark.sql("SELECT * FROM users_manager").show(truncate=False)

print("=== Admin View ===")
spark.sql("SELECT * FROM users_admin").show(truncate=False)

# --- Dynamic masking based on current user role ---
current_role = "analyst"  # Simulated role

role_view_map = {
    "analyst": "users_analyst",
    "manager": "users_manager",
    "admin": "users_admin",
}

view_name = role_view_map.get(current_role, "users_analyst")
print(f"=== View for role '{current_role}' ===")
spark.sql(f"SELECT * FROM {view_name}").show(truncate=False)

spark.stop()
```

## Key Concepts

- **Hashing (SHA-256)**: One-way transformation. Deterministic -- same input always gives same output. Good for joining masked datasets. Not reversible.
- **Tokenization**: Replace sensitive value with a surrogate token. Can be reversible (with a secure lookup) or irreversible (HMAC-based).
- **Partial Masking**: Show some characters (e.g., last 4 of SSN, first letter of name). Preserves partial utility while hiding full value.
- **Generalization**: Reduce precision (zip code 10001 to 100**, salary 95000 to 90K-100K). Supports k-anonymity.
- **Suppression**: Remove highly sensitive columns entirely.
- **Format-Preserving Masking**: Output has the same format as input (e.g., masked phone still looks like a phone number).

## Interview Tips

- Distinguish **anonymization** (irreversible, cannot re-identify) from **pseudonymization** (reversible with a key, still considered personal data under GDPR).
- Discuss **k-anonymity**: ensuring each record is indistinguishable from at least k-1 others on quasi-identifiers.
- Mention that hashing alone is not sufficient for short, low-entropy values (like SSNs) -- use **salted hashing** or HMAC.
- In production, use **column-level encryption** (e.g., AWS KMS, Azure Key Vault) rather than application-level masking.
- Delta Lake and Unity Catalog support **dynamic data masking** natively -- mention this for Databricks interviews.
- Always discuss the **trade-off between data utility and privacy**: over-masking makes data useless for analytics.
