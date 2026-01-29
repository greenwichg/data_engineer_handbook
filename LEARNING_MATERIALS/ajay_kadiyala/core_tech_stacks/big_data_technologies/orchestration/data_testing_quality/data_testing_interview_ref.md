# Data Testing & Quality - Interview Quick Reference

**Print this and review 30 minutes before your interview!**

---

## 1-Minute Explanation

"Data quality testing ensures pipelines produce accurate, complete, and consistent data. I use frameworks like Great Expectations for automated validation, generate synthetic test data for edge cases, implement boundary testing for value ranges, and regression testing to catch unexpected changes. This prevents bad data from reaching production and builds trust in our data systems."

---

## Core Concepts (Memorize!)

### Data Quality Dimensions
```python
# 6 Dimensions of Data Quality
Completeness  → No missing values
Accuracy      → Values are correct
Consistency   → Same across systems
Validity      → Meets constraints
Timeliness    → Up-to-date
Uniqueness    → No duplicates
```

### Validation Types
```python
# Schema
assert df.columns == expected_columns

# Completeness
assert df['id'].isnull().sum() == 0

# Uniqueness
assert df['id'].is_unique

# Range
assert df['amount'].between(0, 1000000).all()

# Set membership
assert df['region'].isin(valid_regions).all()

# Freshness
assert (now() - df['date'].max()).days <= 1
```

---

## Interview Questions & Answers

### Q1: "What is Great Expectations?"

**Answer:**
"Great Expectations is an open-source data validation framework that lets you define expectations about your data declaratively.

**Example:**
```python
import great_expectations as ge

df = ge.from_pandas(sales_df)

# Define expectations
df.expect_column_values_to_not_be_null('sale_id')
df.expect_column_values_to_be_unique('sale_id')
df.expect_column_values_to_be_between('amount', 0, 1000000)

# Validate
results = df.validate()
```

**Why I use it:**
- Self-documenting (expectations are readable)
- Generates data quality reports automatically
- Integrates with Airflow, Spark, SQL
- Tracks validation history

**In my pipeline:** I validate sales data before loading to Snowflake. If validation fails, pipeline stops and alerts team."

---

### Q2: "How do you generate test data?"

**Answer:**
"I use multiple approaches:

**1. Faker for realistic data:**
```python
from faker import Faker
fake = Faker()

data = {
    'customer_name': fake.name(),
    'email': fake.email(),
    'amount': fake.pyfloat(min_value=0, max_value=1000)
}
```

**2. Custom generators for business logic:**
```python
def generate_sales(n_records):
    # Apply business rules
    quantity = random.randint(1, 10)
    price = get_realistic_price(category)
    total = quantity * price * (1 - discount_rate)
    return data
```

**3. Edge cases manually:**
```python
edge_cases = [
    {'amount': 0},      # Minimum
    {'amount': -1},     # Invalid
    {'amount': None},   # NULL
    {'id': 1, 'id': 1}  # Duplicate
]
```

**Benefits:** No PII exposure, reproducible tests, control distributions, test rare scenarios."

---

### Q3: "What is boundary testing?"

**Answer:**
"Boundary testing tests edge cases where bugs are most likely:

| Boundary Type | Example |
|---------------|---------|
| **Min/Max** | amount=0, amount=999999 |
| **NULL** | customer_id=None |
| **Zero** | quantity=0 |
| **Empty** | Empty DataFrame |
| **Duplicates** | sale_id=[1,1,2] |

**Example:**
```python
@pytest.mark.parametrize('amount,valid', [
    (-1, False),     # Below minimum
    (0, True),       # Minimum boundary
    (1000000, True), # Maximum boundary
    (1000001, False) # Above maximum
])
def test_amount_boundaries(amount, valid):
    result = validate_amount(amount)
    assert result == valid
```

**In production:** Found a bug where zero quantities crashed calculation. Boundary test caught it before deploy."

---

### Q4: "What is regression testing for data?"

**Answer:**
"Regression testing ensures pipeline changes don't break existing functionality.

**Approaches:**

**1. Schema regression:**
```python
# Save expected schema
expected_schema = ['id', 'amount', 'date']
assert list(df.columns) == expected_schema
```

**2. Statistical regression:**
```python
# Compare with baseline
assert abs(df['amount'].mean() - baseline_mean) / baseline_mean < 0.05
```

**3. Snapshot testing:**
```python
# Compare with known good output
current_output = transform(input_data)
assert current_output.equals(expected_output)
```

**Real example:** After code change, mean amount shifted from $150 to $1500 (10x!). Regression test caught it—was using cents instead of dollars."

---

### Q5: "How do you integrate validation in Airflow?"

**Answer:**
"I add validation as a separate task between extract and load:

```python
extract >> validate >> load

def validate_sales(**context):
    ti = context['task_instance']
    data_path = ti.xcom_pull(task_ids='extract')
    
    # Run Great Expectations
    results = context_ge.run_checkpoint(
        checkpoint_name='sales_checkpoint',
        batch_request={'path': data_path}
    )
    
    if not results['success']:
        # Fail pipeline
        raise ValueError('Data quality checks failed')
    
    return results
```

**Benefits:**
- Fail fast (stop before loading bad data)
- Track validation history
- Alert team on failures
- Document data quality SLAs"

---

### Q6: "What are common data quality issues you test for?"

**Answer:**
"I test for 7 common issues:

| Issue | Check | Example |
|-------|-------|---------|
| **Missing values** | NULL count | customer_id IS NULL |
| **Duplicates** | Uniqueness | Multiple sale_id=123 |
| **Out of range** | Min/max | amount=-100 |
| **Invalid values** | Set membership | region='INVALID' |
| **Wrong type** | Type check | age='twenty' |
| **Stale data** | Freshness | max_date < yesterday |
| **Business logic** | Custom rules | total != qty * price |

**Example validation:**
```python
# Completeness
assert df['customer_id'].notnull().all()

# Uniqueness
assert df['sale_id'].is_unique

# Range
assert df['amount'].between(0, 1000000).all()

# Set membership
assert df['region'].isin(['US', 'EU']).all()

# Freshness
assert (now - df['date'].max()).days <= 1
```"

---

### Q7: "How do you handle validation failures?"

**Answer:**
"Multi-tiered approach:

**1. Fail pipeline (critical issues):**
```python
if validation_failed:
    raise ValueError('Critical: NULL primary keys')
```

**2. Quarantine bad records (non-critical):**
```python
good_records = df[df['amount'] > 0]
bad_records = df[df['amount'] <= 0]

# Save bad records for investigation
bad_records.to_csv('quarantine/bad_data.csv')

# Continue with good records
load_to_warehouse(good_records)
```

**3. Alert and continue (warnings):**
```python
if null_rate > threshold:
    send_slack_alert('High NULL rate detected')
    # But continue pipeline
```

**Real example:** Payment processing had 0.1% invalid amounts. Instead of failing entire batch, we quarantine invalid records, alert team, process valid records, and manual team reviews quarantined data."

---

## Testing Strategies Comparison

| Strategy | When to Use | Example |
|----------|-------------|---------|
| **Unit tests** | Individual functions | `test_transform_removes_duplicates()` |
| **Integration tests** | Full pipeline | `test_extract_transform_load()` |
| **Boundary tests** | Edge cases | `test_amount_at_zero()` |
| **Regression tests** | Prevent breakage | `test_schema_unchanged()` |
| **Validation** | Production data | Great Expectations checkpoint |

---

## Great Expectations Cheat Sheet

```python
import great_expectations as ge

# Load data
df = ge.from_pandas(df)

# Common expectations
df.expect_column_to_exist('sale_id')
df.expect_column_values_to_not_be_null('sale_id')
df.expect_column_values_to_be_unique('sale_id')
df.expect_column_values_to_be_between('amount', 0, 1000000)
df.expect_column_values_to_be_in_set('region', ['US', 'EU'])
df.expect_column_values_to_match_regex('email', r'.*@.*')
df.expect_table_row_count_to_be_between(min_value=100)

# Validate
results = df.validate()
if not results['success']:
    raise ValueError('Validation failed')
```

---

## Synthetic Data Patterns

```python
# 1. Faker - Realistic data
from faker import Faker
fake = Faker()
name = fake.name()
email = fake.email()

# 2. Random - Distributions
import random
amount = random.uniform(10, 1000)
quantity = random.randint(1, 10)

# 3. Numpy - Statistical
import numpy as np
amounts = np.random.lognormal(5, 1, 1000)  # Log-normal

# 4. Edge cases
edge_cases = [
    {'amount': 0},       # Minimum
    {'amount': None},    # NULL
    {'amount': -1},      # Invalid
    {'id': 1, 'id': 1}   # Duplicate
]
```

---

## Pytest Fixtures for Data Testing

```python
import pytest
import pandas as pd

@pytest.fixture
def valid_sales_data():
    """Clean test data"""
    return pd.DataFrame({
        'sale_id': [1, 2, 3],
        'amount': [100, 200, 150]
    })

@pytest.fixture
def sales_with_nulls():
    """Data with NULLs"""
    return pd.DataFrame({
        'sale_id': [1, None, 3],
        'amount': [100, 200, None]
    })

@pytest.fixture
def sales_with_duplicates():
    """Data with duplicates"""
    return pd.DataFrame({
        'sale_id': [1, 2, 2],
        'amount': [100, 200, 150]
    })

# Use in tests
def test_validator(valid_sales_data):
    results = validate(valid_sales_data)
    assert results['passed']
```

---

## Your Project Example

"In my retail sales ETL pipeline:

**Validation strategy:**
```python
# 1. Schema validation
assert df.columns == ['sale_id', 'customer_id', 'amount', ...]

# 2. Completeness
assert df['sale_id'].notnull().all()

# 3. Uniqueness
assert df['sale_id'].is_unique

# 4. Range validation
assert df['amount'].between(0, 1000000).all()

# 5. Region validation
assert df['region'].isin(['US-EAST', 'US-WEST', ...]).all()

# 6. Freshness
assert (datetime.now() - df['date'].max()).days <= 1

# 7. Business logic
assert (df['total'] >= df['subtotal'] - df['discount']).all()
```

**Integration with Airflow:**
```
extract_us_east ─┐
extract_us_west ─┼─→ consolidate → validate → load_snowflake
extract_europe ──┘                     ↓
                                   (fail if invalid)
```

**Result:** Zero bad data incidents in 6 months, 99.9% data quality SLA."

---

## Things That Impress Interviewers

✅ "I use Great Expectations for production data validation"

✅ "I generate synthetic test data with Faker to avoid PII exposure"

✅ "I implement boundary tests for edge cases like NULL, zero, duplicates"

✅ "I use snapshot testing to prevent regression"

✅ "I fail pipelines fast when critical validation fails"

✅ "I quarantine bad records instead of failing entire batches"

✅ "I track data quality metrics over time"

---

## Things to Avoid Saying

❌ "I assume data is always correct"

❌ "I only test happy path"

❌ "I don't test with production-like data"

❌ "I don't have automated data validation"

❌ "I test in production"

❌ "I let bad data through and fix it later"

---

## Common Validation Patterns

```python
# Pattern 1: Fail fast
if critical_validation_failed:
    raise ValueError('Stop pipeline')

# Pattern 2: Quarantine
good_data = df[is_valid]
bad_data = df[~is_valid]
save_to_quarantine(bad_data)
continue_with(good_data)

# Pattern 3: Alert and continue
if warning_threshold_exceeded:
    send_alert('Data quality degraded')
    # Continue pipeline

# Pattern 4: Sample validation
if len(df) > 1_000_000:
    sample = df.sample(n=10_000)
    validate(sample)  # Faster
```

---

## 30-Second Prep Check

Before interview, can you:

- [ ] Explain Great Expectations
- [ ] Describe how to generate test data
- [ ] Explain boundary testing with examples
- [ ] Describe regression testing for data
- [ ] Show validation integration in Airflow
- [ ] List 5+ common data quality issues
- [ ] Explain how you handle validation failures
- [ ] Give examples from your project

---

## Sample Interview Exchange

**Interviewer:** "How do you ensure data quality in your pipelines?"

**You:** "I use a multi-layered approach:

**1. Automated validation** with Great Expectations:
```python
df.expect_column_values_to_not_be_null('sale_id')
df.expect_column_values_to_be_unique('sale_id')
df.expect_column_values_to_be_between('amount', 0, 1000000)
```

**2. Integrated in Airflow:**
```
extract >> validate >> load
```
Validation task runs Great Expectations checkpoint. If fails, pipeline stops before loading bad data to warehouse.

**3. Comprehensive test coverage:**
- Unit tests for transform logic
- Boundary tests for edge cases (NULL, zero, duplicates)
- Regression tests to prevent changes breaking output
- Integration tests for full pipeline

**4. Synthetic test data** with Faker:
- No PII exposure
- Test edge cases
- Reproducible tests

**Example impact:** Caught schema change that would have broken downstream dashboards. Validation failed in staging, fixed before production.

**Metrics:** 99.9% data quality SLA, zero critical incidents in 6 months, <0.1% bad data quarantine rate."

---

## Quick Wins

**Before interview:**
1. Review Great Expectations basics
2. Know your project's validation strategy
3. Prepare 2-3 data quality issue examples
4. Practice explaining synthetic data generation
5. Understand boundary vs regression testing

**During interview:**
- Be specific about your approach
- Give concrete code examples
- Mention impact/metrics
- Acknowledge trade-offs
- Show you test in production-like environments

---

## Final Tips

**Talk about:**
- Prevention over detection
- Fail fast strategies
- Automated vs manual testing
- Production monitoring
- Continuous improvement

**Emphasize:**
- Data quality SLAs
- Zero bad data incidents
- Catching issues before production
- Building trust in data

**Avoid:**
- Testing only happy path
- Assuming data is always correct
- Manual validation only
- No production monitoring

---

**You're ready! 🚀**

Remember: Interviewers want to see you:
1. **Understand** data quality dimensions
2. **Use** frameworks like Great Expectations
3. **Generate** realistic test data
4. **Test** boundaries and edge cases
5. **Prevent** regressions
6. **Integrate** validation in pipelines

**Good luck with your interview!**
