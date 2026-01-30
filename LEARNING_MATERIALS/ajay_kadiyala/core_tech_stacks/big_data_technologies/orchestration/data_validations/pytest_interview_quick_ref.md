# Pytest Interview Quick Reference Card

**Print this and review 30 minutes before your pytest interview!**

---

## 1-Minute Pytest Explanation

"Pytest is Python's most popular testing framework. It's simple, powerful, and perfect for testing data pipelines. I use it to test data transformations, validate data quality, test Airflow DAGs, and ensure my ETL pipelines work correctly."

---

## Core Concepts (Memorize These!)

### Basic Test Structure
```python
def test_function_name():  # Must start with test_
    # Arrange (setup)
    data = create_test_data()
    
    # Act (execute)
    result = transform(data)
    
    # Assert (verify)
    assert result == expected_value
```

### Assertions
```python
assert value == expected          # Equality
assert value != other             # Inequality
assert value > 0                  # Comparison
assert value in list              # Membership
assert isinstance(value, int)     # Type check
assert value is None              # None check

# Exception testing
with pytest.raises(ValueError):
    function_that_should_fail()
```

### Fixtures (Reusable Setup)
```python
@pytest.fixture
def sample_data():
    return pd.DataFrame({'id': [1, 2, 3]})

def test_with_fixture(sample_data):
    assert len(sample_data) == 3
```

### Parametrize (Multiple Test Cases)
```python
@pytest.mark.parametrize("input,expected", [
    (1, 2),
    (2, 4),
    (3, 6),
])
def test_double(input, expected):
    assert input * 2 == expected
```

### Mocking (Fake Dependencies)
```python
@patch('module.function')
def test_with_mock(mock_func):
    mock_func.return_value = 'fake_data'
    result = my_function()
    assert result == 'fake_data'
```

---

## Interview Questions & Answers

### Q1: "What is pytest?"
**Answer:** "Pytest is Python's most popular testing framework—simple, powerful, and ideal for data engineering. It uses plain assert statements, has great fixtures for reusable test data, and supports mocking for external dependencies. In my retail sales pipeline, I use it to test data transformations, validate data quality, and test Airflow DAGs."

### Q2: "What's a fixture?"
**Answer:** "A fixture provides reusable test data or setup. Instead of recreating the same test data in every test, I create it once as a fixture:
```python
@pytest.fixture
def sample_sales_data():
    return pd.DataFrame({'sale_id': [1,2,3], 'amount': [100,200,150]})
```
Each test gets a fresh copy. I also use fixture scopes—function scope for fresh data per test, session scope for expensive resources like database connections."

### Q3: "How do you test DataFrames?"
**Answer:** "I use pandas' built-in testing utilities:
```python
def test_transformation(sample_data):
    result = transform(sample_data)
    
    # Check shape
    assert len(result) == 5
    
    # Check columns
    assert 'new_column' in result.columns
    
    # Exact equality
    pd.testing.assert_frame_equal(result, expected_df)
    
    # Check values
    assert result['amount'].sum() == 1000
```"

### Q4: "What's mocking?"
**Answer:** "Mocking replaces real external dependencies (APIs, databases) with fake objects for testing. In my pipeline, I mock:
- **PostgreSQL connections**: Don't hit real database in tests
- **S3 uploads**: Don't actually upload to AWS
- **API calls**: Don't make real HTTP requests

Example:
```python
@patch('boto3.client')
def test_s3_upload(mock_s3):
    mock_s3.return_value.put_object.return_value = {'status': 200}
    result = upload_to_s3(data)
    assert result is True
```
Tests run fast, reliable, and don't require external services."

### Q5: "Unit vs Integration tests?"
**Answer:**

| Aspect | Unit Test | Integration Test |
|--------|-----------|------------------|
| Scope | Single function | Multiple components |
| Dependencies | Mocked | Real |
| Speed | Fast (milliseconds) | Slow (seconds) |
| When | Every commit | Before deploy |
| Example | Test transform logic | Test DB → S3 → Snowflake |

**My approach:**
```python
# Unit test (fast, mocked)
@patch('PostgresHook')
def test_extract_function(mock_hook):
    mock_hook.return_value.get_records.return_value = test_data
    result = extract()
    assert result['count'] == 1000

# Integration test (slow, real)
@pytest.mark.integration
def test_end_to_end(test_database):
    extract_to_db(test_database)
    result = query_db(test_database)
    assert len(result) == 1000
```
Run unit tests on every commit, integration tests before deploy."

### Q6: "How do you test Airflow DAGs?"
**Answer:** "I test DAGs at three levels:

**1. Structure (configuration)**
```python
def test_dag_structure(dagbag):
    dag = dagbag.get_dag('my_dag')
    assert dag.catchup is False
    assert dag.schedule_interval == '0 6 * * *'
```

**2. Dependencies (task flow)**
```python
def test_dependencies(dagbag):
    dag = dagbag.get_dag('my_dag')
    transform = dag.get_task('transform')
    assert 'extract' in transform.upstream_task_ids
```

**3. Logic (task functions)**
```python
@patch('dags.my_dag.PostgresHook')
def test_extract_task(mock_hook, mock_context):
    mock_hook.return_value.get_records.return_value = [(1,'A',100)]
    result = extract_function(**mock_context)
    assert result['status'] == 'success'
```"

### Q7: "How do you test data quality?"
**Answer:** "I write parametrized tests for multiple scenarios:
```python
@pytest.mark.parametrize('min_rows,should_pass', [
    (100, True),   # 1000 records >= 100 ✓
    (2000, False)  # 1000 records < 2000 ✗
])
def test_min_records(data, min_rows, should_pass):
    checker = DataQualityChecker()
    result = checker.check_min_rows(data, min_rows)
    assert result['passed'] == should_pass
```
Also test NULL detection, duplicate detection, value ranges, and business rules."

---

## Common Commands

```bash
# Run tests
pytest                    # All tests
pytest -v                 # Verbose
pytest tests/test_file.py # Specific file
pytest -k "transform"     # Matching pattern

# Control output
pytest -s                 # Show prints
pytest -x                 # Stop on first failure
pytest -vv                # Very verbose

# Coverage
pytest --cov=src          # Show coverage
pytest --cov-report=html  # HTML report

# Markers
pytest -m integration     # Run marked tests
pytest -m "not slow"      # Skip marked tests

# Performance  
pytest -n 4               # 4 parallel workers
pytest --durations=10     # Show slowest tests
```

---

## Code Patterns to Know

### Pattern 1: Testing Exceptions
```python
def test_raises_error():
    with pytest.raises(ValueError) as exc:
        invalid_function()
    assert "error message" in str(exc.value)
```

### Pattern 2: Fixture with Cleanup
```python
@pytest.fixture
def temp_file():
    file = create_file()
    yield file
    os.remove(file)  # Cleanup
```

### Pattern 3: Multiple Assertions
```python
def test_multiple_checks(sample_data):
    assert len(sample_data) == 5
    assert 'id' in sample_data.columns
    assert sample_data['amount'].sum() == 1000
```

### Pattern 4: Mocking Return Value
```python
@patch('module.api_call')
def test_api(mock_api):
    mock_api.return_value = {'data': [1,2,3]}
    result = my_function()
    assert len(result) == 3
```

### Pattern 5: Fixture Scope
```python
@pytest.fixture(scope='session')  # Once per session
def db_connection():
    return create_connection()

@pytest.fixture(scope='function')  # Fresh each test
def test_data():
    return create_data()
```

---

## Your Project Examples

### Example 1: Data Transformation Test
"In my retail sales pipeline:
```python
def test_remove_duplicates():
    data = pd.DataFrame({
        'sale_id': [1, 2, 2, 3],  # Duplicate 2
        'amount': [100, 200, 250, 300]
    })
    
    result = transformer.remove_duplicates(data)
    
    assert len(result) == 3  # 4 - 1 duplicate
    assert result['sale_id'].is_unique
    # First occurrence kept
    assert result[result['sale_id']==2]['amount'].values[0] == 200
```"

### Example 2: Data Quality Test
"For data validation:
```python
@pytest.mark.parametrize('column,min,max,passes', [
    ('amount', 0, 500, True),
    ('amount', 200, 500, False),  # Some out of range
])
def test_value_range(checker, data, column, min, max, passes):
    result = checker.check_value_range(data, column, min, max)
    assert result['passed'] == passes
```"

### Example 3: DAG Test
"For my Airflow DAG:
```python
def test_dag_configuration(dagbag):
    dag = dagbag.get_dag('retail_sales_etl')
    assert dag.schedule_interval == '0 6 * * *'
    assert dag.catchup is False
    assert dag.max_active_runs == 1

@patch('dags.retail_sales_etl.PostgresHook')
def test_extract_task(mock_hook):
    mock_hook.return_value.get_records.return_value = test_data
    result = extract_from_region(region='us_east')
    assert result['record_count'] == len(test_data)
```"

---

## Best Practices (Say These!)

✅ **DO:**
- "I use descriptive test names: `test_remove_duplicates_keeps_first_occurrence`"
- "I use fixtures for reusable test data"
- "I mock external dependencies so tests are fast and reliable"
- "I use parametrize to test multiple scenarios efficiently"
- "I separate unit tests (fast) from integration tests (slow)"
- "I test both success and failure cases"
- "I use `pd.testing.assert_frame_equal` for DataFrame equality"

❌ **DON'T SAY:**
- "I test implementation details" (test behavior, not internal code)
- "My tests depend on each other" (tests should be independent)
- "I don't clean up test data" (always cleanup)
- "I test against production database" (use test database)
- "I skip testing error cases" (test failures too!)

---

## Pytest vs Other Frameworks

| Feature | Pytest | Unittest | Nose |
|---------|--------|----------|------|
| Syntax | `assert x == y` | `self.assertEqual(x,y)` | Similar to pytest |
| Setup | Fixtures | setUp() method | Fixtures |
| Parametrize | Built-in | Manual loops | Plugin |
| Popularity | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ (deprecated) |

"I prefer pytest because it's simple (plain assert), powerful (great fixtures), and has a huge ecosystem of plugins."

---

## Troubleshooting

### Tests not discovered?
- File must be `test_*.py` or `*_test.py`
- Function must start with `test_`
- Class must start with `Test`

### Fixture not found?
- Define in same file or `conftest.py`
- Check spelling exactly matches

### Mock not working?
- Patch where it's USED, not where it's defined
- `@patch('my_module.function')` not `@patch('original_module.function')`

---

## 30-Second Prep Check

Before interview, can you:
- [ ] Explain what pytest is
- [ ] Write a basic test with assert
- [ ] Create and use a fixture
- [ ] Mock an external dependency
- [ ] Use parametrize for multiple cases
- [ ] Test for exceptions
- [ ] Differentiate unit vs integration tests
- [ ] Explain how you tested your pipeline

---

## Sample Interview Answer Template

**For ANY pytest question:**

1. **Definition** (1 sentence)
2. **Why it's useful** (benefit)
3. **Your project example** (specific code)
4. **Best practice** (pro tip)

**Example:**
"[Concept] is [definition]. I use it because [benefit]. In my retail sales pipeline, [specific example code]. The key is to [best practice]."

---

## Final Tips

**During Interview:**
- Speak while coding: "I'll create a fixture for test data..."
- Explain your thinking: "I'm mocking the database because..."
- Ask clarifying questions: "Should I test both success and failure cases?"
- Be honest: "I haven't used that plugin, but I'd approach it like..."

**Things That Impress:**
- ✓ "I separate unit and integration tests with markers"
- ✓ "I use fixtures with different scopes for efficiency"
- ✓ "I mock external dependencies so tests are fast"
- ✓ "I test both happy path and edge cases"
- ✓ "I use parametrize to reduce code duplication"

**Red Flags to Avoid:**
- ✗ "I test in production"
- ✗ "I don't test error cases"
- ✗ "My tests take 30 minutes to run"
- ✗ "Tests break when I change internal code"

---

**You've got this! 🚀**

Remember: Pytest is just a tool to verify your code works. Focus on:
1. What you're testing (behavior)
2. Why you're testing it (prevent bugs)
3. How you make tests reliable (mocking, fixtures)

**Good luck with your interview!**
