# PySpark Implementation: Bitwise Flag Operations

## Problem Statement

Use bitwise operations to encode and decode multiple boolean flags stored in a single integer column. This compact representation is common in systems programming, feature flags, permission systems, and game state tracking. Given a flags integer column, extract individual boolean properties, combine flags, and filter records by specific flag combinations. This is a common interview question that tests your understanding of low-level data representation and PySpark's bitwise functions.

### Sample Data

**User Feature Flags (bit positions):**
- Bit 0 (value 1): email_verified
- Bit 1 (value 2): phone_verified
- Bit 2 (value 4): premium_member
- Bit 3 (value 8): two_factor_enabled
- Bit 4 (value 16): newsletter_subscribed
- Bit 5 (value 32): beta_tester

**Users:**

| user_id | name    | flags |
|---------|---------|-------|
| 1       | Alice   | 7     |
| 2       | Bob     | 13    |
| 3       | Carol   | 3     |
| 4       | Dave    | 39    |
| 5       | Eve     | 0     |
| 6       | Frank   | 63    |

### Expected Output (Decoded)

| user_id | name  | flags | email_verified | phone_verified | premium_member | two_factor | newsletter | beta_tester |
|---------|-------|-------|----------------|----------------|----------------|------------|------------|-------------|
| 1       | Alice | 7     | true           | true           | true           | false      | false      | false       |
| 2       | Bob   | 13    | true           | false          | true           | true       | false      | false       |
| 3       | Carol | 3     | true           | true           | false          | false      | false      | false       |
| 4       | Dave  | 39    | true           | true           | true           | false      | false      | true        |
| 5       | Eve   | 0     | false          | false          | false          | false      | false      | false       |
| 6       | Frank | 63    | true           | true           | true           | true       | true       | true        |

---

## Method 1: DataFrame API with Bitwise Functions

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize Spark
spark = SparkSession.builder \
    .appName("Bitwise Flag Operations") \
    .master("local[*]") \
    .getOrCreate()

# --- Flag definitions ---
FLAGS = {
    "email_verified":      1,   # bit 0 = 2^0 = 1
    "phone_verified":      2,   # bit 1 = 2^1 = 2
    "premium_member":      4,   # bit 2 = 2^2 = 4
    "two_factor_enabled":  8,   # bit 3 = 2^3 = 8
    "newsletter_subscribed": 16, # bit 4 = 2^4 = 16
    "beta_tester":         32,  # bit 5 = 2^5 = 32
}

# --- Sample Data ---
# Alice: 7 = 1+2+4 (email, phone, premium)
# Bob: 13 = 1+4+8 (email, premium, 2fa)
# Carol: 3 = 1+2 (email, phone)
# Dave: 39 = 1+2+4+32 (email, phone, premium, beta)
# Eve: 0 = no flags
# Frank: 63 = 1+2+4+8+16+32 (all flags)

users_data = [
    (1, "Alice", 7),
    (2, "Bob", 13),
    (3, "Carol", 3),
    (4, "Dave", 39),
    (5, "Eve", 0),
    (6, "Frank", 63),
]

users_df = spark.createDataFrame(users_data, ["user_id", "name", "flags"])

# --- Decode: Extract individual flags using bitwise AND ---
decoded_df = users_df
for flag_name, flag_value in FLAGS.items():
    decoded_df = decoded_df.withColumn(
        flag_name,
        (F.col("flags").bitwiseAND(flag_value) > 0).cast("boolean")
    )

print("=== Decoded Flags ===")
decoded_df.show(truncate=False)

# --- Filter: Find users with specific flag combinations ---
# Users who are premium AND have email verified
premium_verified = users_df.filter(
    (F.col("flags").bitwiseAND(FLAGS["premium_member"]) > 0) &
    (F.col("flags").bitwiseAND(FLAGS["email_verified"]) > 0)
)

print("=== Premium + Email Verified Users ===")
premium_verified.show()

# Users who have EITHER phone_verified OR two_factor_enabled
phone_or_2fa_mask = FLAGS["phone_verified"] | FLAGS["two_factor_enabled"]  # 2 | 8 = 10
phone_or_2fa = users_df.filter(
    F.col("flags").bitwiseAND(phone_or_2fa_mask) > 0
)

print("=== Users with Phone Verified OR Two-Factor ===")
phone_or_2fa.show()

# Users with ALL flags set (check if flags AND mask == mask)
all_flags_mask = sum(FLAGS.values())  # 63
fully_enabled = users_df.filter(
    F.col("flags").bitwiseAND(all_flags_mask) == all_flags_mask
)

print(f"=== Users with ALL flags set (mask={all_flags_mask}) ===")
fully_enabled.show()

# --- Count active flags per user ---
count_expr = sum(
    F.when(F.col("flags").bitwiseAND(v) > 0, 1).otherwise(0)
    for v in FLAGS.values()
)

users_with_count = users_df.withColumn("active_flag_count", count_expr)

print("=== Active Flag Count ===")
users_with_count.show()

spark.stop()
```

## Method 2: Encoding Boolean Columns into a Flags Integer

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Bitwise Flags - Encoding") \
    .master("local[*]") \
    .getOrCreate()

# --- Data with individual boolean columns ---
users_data = [
    (1, "Alice", True, True, True, False, False, False),
    (2, "Bob", True, False, True, True, False, False),
    (3, "Carol", True, True, False, False, False, False),
    (4, "Dave", True, True, True, False, False, True),
    (5, "Eve", False, False, False, False, False, False),
    (6, "Frank", True, True, True, True, True, True),
]

users_df = spark.createDataFrame(
    users_data,
    ["user_id", "name", "email_verified", "phone_verified",
     "premium_member", "two_factor", "newsletter", "beta_tester"]
)

print("=== Original Boolean Columns ===")
users_df.show()

# --- Encode: Convert boolean columns to a single flags integer ---
flag_mapping = {
    "email_verified": 1,
    "phone_verified": 2,
    "premium_member": 4,
    "two_factor": 8,
    "newsletter": 16,
    "beta_tester": 32,
}

# Build the encoding expression
encode_expr = F.lit(0)
for col_name, bit_value in flag_mapping.items():
    encode_expr = encode_expr + F.when(F.col(col_name), bit_value).otherwise(0)

encoded_df = users_df.withColumn("flags", encode_expr)

print("=== Encoded as Flags Integer ===")
encoded_df.select("user_id", "name", "flags").show()

# --- Verify round-trip: decode back ---
for col_name, bit_value in flag_mapping.items():
    encoded_df = encoded_df.withColumn(
        f"{col_name}_decoded",
        (F.col("flags").bitwiseAND(bit_value) > 0).cast("boolean")
    )

print("=== Round-Trip Verification ===")
encoded_df.select(
    "user_id",
    "email_verified", "email_verified_decoded",
    "premium_member", "premium_member_decoded"
).show()

spark.stop()
```

## Method 3: SQL with Bitwise Operations and Flag Manipulation

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Bitwise Flags - SQL") \
    .master("local[*]") \
    .getOrCreate()

users_data = [
    (1, "Alice", 7), (2, "Bob", 13), (3, "Carol", 3),
    (4, "Dave", 39), (5, "Eve", 0), (6, "Frank", 63),
]

df = spark.createDataFrame(users_data, ["user_id", "name", "flags"])
df.createOrReplaceTempView("users")

# --- Decode flags in SQL ---
decoded = spark.sql("""
    SELECT
        user_id,
        name,
        flags,
        CONV(CAST(flags AS STRING), 10, 2) AS flags_binary,
        (flags & 1) > 0 AS email_verified,
        (flags & 2) > 0 AS phone_verified,
        (flags & 4) > 0 AS premium_member,
        (flags & 8) > 0 AS two_factor_enabled,
        (flags & 16) > 0 AS newsletter_subscribed,
        (flags & 32) > 0 AS beta_tester
    FROM users
""")

print("=== Decoded in SQL ===")
decoded.show(truncate=False)

# --- Set a flag (turn ON newsletter for all users) ---
updated = spark.sql("""
    SELECT
        user_id,
        name,
        flags AS old_flags,
        flags | 16 AS new_flags,
        CONV(CAST(flags AS STRING), 10, 2) AS old_binary,
        CONV(CAST(flags | 16 AS STRING), 10, 2) AS new_binary
    FROM users
""")

print("=== After Setting Newsletter Flag (OR 16) ===")
updated.show(truncate=False)

# --- Clear a flag (turn OFF premium for all users) ---
cleared = spark.sql("""
    SELECT
        user_id,
        name,
        flags AS old_flags,
        flags & ~4 AS new_flags,
        (flags & 4) > 0 AS was_premium,
        ((flags & ~4) & 4) > 0 AS is_premium_after
    FROM users
""")

print("=== After Clearing Premium Flag (AND NOT 4) ===")
cleared.show(truncate=False)

# --- Toggle a flag (XOR) ---
toggled = spark.sql("""
    SELECT
        user_id,
        name,
        flags AS old_flags,
        flags ^ 8 AS new_flags,
        (flags & 8) > 0 AS two_factor_before,
        ((flags ^ 8) & 8) > 0 AS two_factor_after
    FROM users
""")

print("=== After Toggling Two-Factor Flag (XOR 8) ===")
toggled.show(truncate=False)

# --- Aggregate: count users per flag ---
flag_counts = spark.sql("""
    SELECT
        SUM(CASE WHEN (flags & 1) > 0 THEN 1 ELSE 0 END) AS email_verified_count,
        SUM(CASE WHEN (flags & 2) > 0 THEN 1 ELSE 0 END) AS phone_verified_count,
        SUM(CASE WHEN (flags & 4) > 0 THEN 1 ELSE 0 END) AS premium_count,
        SUM(CASE WHEN (flags & 8) > 0 THEN 1 ELSE 0 END) AS two_factor_count,
        SUM(CASE WHEN (flags & 16) > 0 THEN 1 ELSE 0 END) AS newsletter_count,
        SUM(CASE WHEN (flags & 32) > 0 THEN 1 ELSE 0 END) AS beta_tester_count
    FROM users
""")

print("=== Flag Distribution ===")
flag_counts.show()

spark.stop()
```

## Key Concepts

- **Bitwise AND (`&`)**: Extract/check a flag. `flags & mask > 0` checks if the flag is set. `flags & mask == mask` checks if ALL flags in the mask are set.
- **Bitwise OR (`|`)**: Set a flag. `flags | mask` turns on the specified bits without affecting others.
- **Bitwise XOR (`^`)**: Toggle a flag. `flags ^ mask` flips the specified bits.
- **Bitwise NOT (`~`)**: Invert all bits. Combined with AND to clear a flag: `flags & ~mask` turns off the specified bits.
- **Encoding**: Convert N boolean columns to a single integer: `sum(2^i * bool_i)`. Saves storage and simplifies schema.
- **Decoding**: Extract the i-th flag: `(flags >> i) & 1` or equivalently `(flags & 2^i) > 0`.

## Interview Tips

- Explain why bitwise flags are used: **space efficiency** (1 integer vs N boolean columns), **atomic updates** (set multiple flags in one write), and **fast filtering** (single column index).
- The main trade-off is **readability**: flags integers are opaque without documentation. Always maintain a flag-to-bit mapping.
- Mention that this pattern is used in **Unix file permissions** (rwx = 7), **database feature flags**, and **game state**.
- In PySpark, `bitwiseAND`, `bitwiseOR`, `bitwiseXOR` are methods on Column. In SQL, use `&`, `|`, `^` operators.
- Discuss **bit capacity**: a 32-bit integer supports 32 flags; a 64-bit long supports 64 flags. For more, use arrays or strings.
- For **schema evolution**, adding new flags is easy (use a previously unused bit), but reusing or redefining bits requires careful migration.
