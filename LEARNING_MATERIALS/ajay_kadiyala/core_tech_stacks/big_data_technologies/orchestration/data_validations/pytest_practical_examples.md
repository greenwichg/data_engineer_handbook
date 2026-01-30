# Pytest Practical Examples - Run These Now!

This file contains runnable pytest examples you can practice with immediately.

## Setup

```bash
# Install pytest
pip install pytest pytest-mock pandas

# Create directory structure
mkdir -p tests
touch tests/__init__.py
```

---

## Example 1: Basic Data Validation Tests

Create `tests/test_basics.py`:

```python
"""
Basic pytest examples for data validation

Run: pytest tests/test_basics.py -v
"""

import pytest
import pandas as pd

# Simple functions to test
def is_valid_sale_amount(amount):
    """Check if sale amount is valid"""
    return amount > 0 and amount < 1000000

def calculate_discount(price, discount_percent):
    """Calculate discounted price"""
    if discount_percent < 0 or discount_percent > 100:
        raise ValueError("Discount must be between 0 and 100")
    return price * (1 - discount_percent / 100)

def remove_duplicates(data):
    """Remove duplicate sale IDs"""
    return data.drop_duplicates(subset=['sale_id'], keep='first')

# Test cases
class TestBasicValidation:
    """Basic validation tests"""
    
    def test_valid_amount_positive(self):
        """Test valid positive amount"""
        assert is_valid_sale_amount(100.0) is True
    
    def test_valid_amount_zero(self):
        """Test that zero is invalid"""
        assert is_valid_sale_amount(0) is False
    
    def test_valid_amount_negative(self):
        """Test that negative is invalid"""
        assert is_valid_sale_amount(-10) is False
    
    def test_valid_amount_too_large(self):
        """Test that very large amounts are invalid"""
        assert is_valid_sale_amount(2000000) is False
    
    def test_calculate_discount_normal(self):
        """Test normal discount calculation"""
        result = calculate_discount(100, 10)
        assert result == 90.0
    
    def test_calculate_discount_zero(self):
        """Test zero discount"""
        result = calculate_discount(100, 0)
        assert result == 100.0
    
    def test_calculate_discount_invalid_negative(self):
        """Test that negative discount raises error"""
        with pytest.raises(ValueError) as exc_info:
            calculate_discount(100, -10)
        assert "between 0 and 100" in str(exc_info.value)
    
    def test_calculate_discount_invalid_over_100(self):
        """Test that discount over 100% raises error"""
        with pytest.raises(ValueError):
            calculate_discount(100, 150)
    
    def test_remove_duplicates(self):
        """Test duplicate removal"""
        data = pd.DataFrame({
            'sale_id': [1, 2, 2, 3],
            'amount': [100, 200, 250, 300]
        })
        
        result = remove_duplicates(data)
        
        assert len(result) == 3
        assert result['sale_id'].is_unique
        # First occurrence kept
        assert result[result['sale_id'] == 2]['amount'].values[0] == 200


class TestParametrized:
    """Examples using parametrize"""
    
    @pytest.mark.parametrize("amount,expected", [
        (100, True),
        (0, False),
        (-50, False),
        (999999, True),
        (1000000, False),
    ])
    def test_valid_amount_parametrized(self, amount, expected):
        """Test multiple amounts with parametrize"""
        assert is_valid_sale_amount(amount) == expected
    
    @pytest.mark.parametrize("price,discount,expected", [
        (100, 10, 90.0),
        (100, 0, 100.0),
        (100, 50, 50.0),
        (200, 25, 150.0),
    ])
    def test_discount_calculation(self, price, discount, expected):
        """Test discount with multiple scenarios"""
        result = calculate_discount(price, discount)
        assert result == expected


class TestWithFixtures:
    """Examples using fixtures"""
    
    @pytest.fixture
    def sample_sales_data(self):
        """Fixture providing sample data"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3, 4, 5],
            'amount': [100.0, 200.0, 150.0, 300.0, 175.0],
            'customer_id': ['C001', 'C002', 'C003', 'C004', 'C005']
        })
    
    @pytest.fixture
    def data_with_nulls(self):
        """Fixture with NULL values"""
        return pd.DataFrame({
            'sale_id': [1, 2, None, 4],
            'amount': [100, None, 150, 200]
        })
    
    def test_fixture_usage(self, sample_sales_data):
        """Test using fixture"""
        assert len(sample_sales_data) == 5
        assert 'sale_id' in sample_sales_data.columns
    
    def test_null_detection(self, data_with_nulls):
        """Test NULL detection"""
        null_count = data_with_nulls['sale_id'].isnull().sum()
        assert null_count == 1
    
    def test_multiple_fixtures(self, sample_sales_data, data_with_nulls):
        """Test using multiple fixtures"""
        # Clean data has no NULLs
        assert sample_sales_data['sale_id'].isnull().sum() == 0
        
        # Dirty data has NULLs
        assert data_with_nulls['sale_id'].isnull().sum() > 0


if __name__ == '__main__':
    # Run tests when file is executed directly
    pytest.main([__file__, '-v'])
```

---

## Example 2: Data Transformation Tests

Create `tests/test_transformations.py`:

```python
"""
Test data transformations

Run: pytest tests/test_transformations.py -v
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime

# Transformation functions
def standardize_date(df):
    """Convert date column to datetime"""
    df = df.copy()
    df['date'] = pd.to_datetime(df['date'])
    return df

def add_calculated_fields(df):
    """Add calculated fields"""
    df = df.copy()
    df['discount_amount'] = df['discount_amount'].fillna(0)
    df['net_amount'] = df['total_amount'] - df['discount_amount']
    df['profit_margin'] = (df['net_amount'] / df['total_amount'] * 100).round(2)
    return df

def filter_valid_records(df):
    """Filter out invalid records"""
    df = df.copy()
    df = df[df['quantity'] > 0]
    df = df[df['price'] > 0]
    df = df[df['total_amount'] > 0]
    return df

def categorize_sales(df):
    """Categorize sales by amount"""
    df = df.copy()
    
    def categorize(amount):
        if amount < 100:
            return 'Small'
        elif amount < 500:
            return 'Medium'
        else:
            return 'Large'
    
    df['category'] = df['total_amount'].apply(categorize)
    return df


class TestTransformations:
    """Test data transformation functions"""
    
    @pytest.fixture
    def raw_sales_data(self):
        """Raw sales data needing transformation"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3],
            'date': ['2024-01-15', '2024-01-16', '2024-01-17'],
            'total_amount': [100.0, 200.0, 50.0],
            'discount_amount': [10.0, None, 5.0],
            'quantity': [2, 3, 1],
            'price': [45.0, 66.67, 45.0]
        })
    
    @pytest.fixture
    def invalid_data(self):
        """Data with invalid records"""
        return pd.DataFrame({
            'sale_id': [1, 2, 3, 4],
            'quantity': [2, 0, -1, 3],  # 0 and negative invalid
            'price': [10.0, 20.0, 15.0, -5.0],  # Negative invalid
            'total_amount': [20.0, 0.0, -15.0, 15.0]
        })
    
    def test_standardize_date(self, raw_sales_data):
        """Test date standardization"""
        result = standardize_date(raw_sales_data)
        
        assert pd.api.types.is_datetime64_any_dtype(result['date'])
        assert result['date'].iloc[0] == pd.Timestamp('2024-01-15')
    
    def test_add_calculated_fields(self, raw_sales_data):
        """Test calculated field addition"""
        result = add_calculated_fields(raw_sales_data)
        
        # Check NULL filling
        assert result['discount_amount'].isnull().sum() == 0
        
        # Check calculations
        assert 'net_amount' in result.columns
        assert 'profit_margin' in result.columns
        
        # Verify first row
        assert result.loc[0, 'net_amount'] == 90.0  # 100 - 10
        assert result.loc[0, 'profit_margin'] == 90.0  # 90/100 * 100
    
    def test_filter_valid_records(self, invalid_data):
        """Test invalid record filtering"""
        result = filter_valid_records(invalid_data)
        
        # Only first record should pass
        assert len(result) == 1
        assert result.iloc[0]['sale_id'] == 1
        
        # All filtered records should be valid
        assert all(result['quantity'] > 0)
        assert all(result['price'] > 0)
        assert all(result['total_amount'] > 0)
    
    def test_categorize_sales(self):
        """Test sales categorization"""
        data = pd.DataFrame({
            'sale_id': [1, 2, 3],
            'total_amount': [50.0, 250.0, 1000.0]
        })
        
        result = categorize_sales(data)
        
        assert result.loc[0, 'category'] == 'Small'   # < 100
        assert result.loc[1, 'category'] == 'Medium'  # 100-500
        assert result.loc[2, 'category'] == 'Large'   # > 500
    
    def test_transformation_pipeline(self, raw_sales_data):
        """Test complete transformation pipeline"""
        result = raw_sales_data.copy()
        
        # Apply transformations
        result = standardize_date(result)
        result = add_calculated_fields(result)
        result = filter_valid_records(result)
        result = categorize_sales(result)
        
        # Verify end state
        assert pd.api.types.is_datetime64_any_dtype(result['date'])
        assert 'net_amount' in result.columns
        assert 'category' in result.columns
        assert len(result) == 3  # All valid
    
    @pytest.mark.parametrize("amount,expected_category", [
        (50, 'Small'),
        (99, 'Small'),
        (100, 'Medium'),
        (499, 'Medium'),
        (500, 'Large'),
        (1000, 'Large'),
    ])
    def test_categorization_boundaries(self, amount, expected_category):
        """Test category boundaries"""
        data = pd.DataFrame({'total_amount': [amount]})
        result = categorize_sales(data)
        assert result['category'].iloc[0] == expected_category


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
```

---

## Example 3: Mocking External Dependencies

Create `tests/test_mocking.py`:

```python
"""
Examples of mocking external dependencies

Run: pytest tests/test_mocking.py -v
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
import pandas as pd

# Functions that use external dependencies
def fetch_sales_from_db(connection, date):
    """Fetch sales from database"""
    cursor = connection.cursor()
    query = f"SELECT * FROM sales WHERE date = '{date}'"
    cursor.execute(query)
    results = cursor.fetchall()
    cursor.close()
    return results

def upload_to_s3(s3_client, bucket, key, data):
    """Upload data to S3"""
    response = s3_client.put_object(
        Bucket=bucket,
        Key=key,
        Body=data
    )
    return response['ResponseMetadata']['HTTPStatusCode'] == 200

def call_external_api(url):
    """Call external API"""
    import requests
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return response.json()


class TestMocking:
    """Test with mocked dependencies"""
    
    def test_mock_database_connection(self):
        """Test with mocked database"""
        # Create mock connection and cursor
        mock_connection = Mock()
        mock_cursor = Mock()
        
        # Setup mock behavior
        mock_cursor.fetchall.return_value = [
            (1, '2024-01-15', 100.0),
            (2, '2024-01-15', 200.0)
        ]
        
        mock_connection.cursor.return_value = mock_cursor
        
        # Test function
        results = fetch_sales_from_db(mock_connection, '2024-01-15')
        
        # Verify
        assert len(results) == 2
        assert results[0][0] == 1
        
        # Verify mock was called correctly
        mock_connection.cursor.assert_called_once()
        mock_cursor.execute.assert_called_once()
        mock_cursor.close.assert_called_once()
    
    def test_mock_s3_upload(self):
        """Test with mocked S3 client"""
        # Create mock S3 client
        mock_s3 = Mock()
        
        # Setup mock response
        mock_s3.put_object.return_value = {
            'ResponseMetadata': {
                'HTTPStatusCode': 200
            }
        }
        
        # Test function
        result = upload_to_s3(
            mock_s3,
            bucket='test-bucket',
            key='data/sales.csv',
            data='sale_id,amount\n1,100\n2,200'
        )
        
        # Verify
        assert result is True
        
        # Verify S3 was called correctly
        mock_s3.put_object.assert_called_once()
        call_args = mock_s3.put_object.call_args
        assert call_args.kwargs['Bucket'] == 'test-bucket'
        assert call_args.kwargs['Key'] == 'data/sales.csv'
    
    @patch('requests.get')
    def test_mock_api_call_success(self, mock_get):
        """Test API call with successful response"""
        # Setup mock response
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            'data': [1, 2, 3],
            'status': 'success'
        }
        mock_response.raise_for_status = Mock()  # No exception
        
        mock_get.return_value = mock_response
        
        # Test function
        result = call_external_api('https://api.example.com/data')
        
        # Verify
        assert result['status'] == 'success'
        assert len(result['data']) == 3
        
        # Verify API was called
        mock_get.assert_called_once_with(
            'https://api.example.com/data',
            timeout=30
        )
    
    @patch('requests.get')
    def test_mock_api_call_failure(self, mock_get):
        """Test API call with failure"""
        # Setup mock to raise exception
        import requests
        mock_get.side_effect = requests.exceptions.Timeout("Connection timeout")
        
        # Test function raises exception
        with pytest.raises(requests.exceptions.Timeout):
            call_external_api('https://api.example.com/data')
    
    def test_mock_with_side_effect(self):
        """Test mock with different responses on multiple calls"""
        mock_func = Mock()
        
        # Different responses on each call
        mock_func.side_effect = [
            {'count': 100},
            {'count': 200},
            {'count': 300}
        ]
        
        # Call three times
        assert mock_func()['count'] == 100
        assert mock_func()['count'] == 200
        assert mock_func()['count'] == 300
        
        # Verify call count
        assert mock_func.call_count == 3


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
```

---

## Example 4: Testing with Pandas DataFrames

Create `tests/test_pandas_operations.py`:

```python
"""
Test pandas DataFrame operations

Run: pytest tests/test_pandas_operations.py -v
"""

import pytest
import pandas as pd
import numpy as np

class TestPandasOperations:
    """Test pandas-specific operations"""
    
    @pytest.fixture
    def sample_df(self):
        """Sample DataFrame"""
        return pd.DataFrame({
            'id': [1, 2, 3, 4, 5],
            'value': [10.0, 20.0, 30.0, 40.0, 50.0],
            'category': ['A', 'B', 'A', 'B', 'A']
        })
    
    def test_dataframe_shape(self, sample_df):
        """Test DataFrame shape"""
        assert sample_df.shape == (5, 3)
        assert len(sample_df) == 5
        assert len(sample_df.columns) == 3
    
    def test_column_names(self, sample_df):
        """Test column names"""
        expected_columns = ['id', 'value', 'category']
        assert list(sample_df.columns) == expected_columns
    
    def test_data_types(self, sample_df):
        """Test data types"""
        assert sample_df['id'].dtype == np.int64
        assert sample_df['value'].dtype == np.float64
        assert sample_df['category'].dtype == object
    
    def test_groupby_operation(self, sample_df):
        """Test groupby aggregation"""
        result = sample_df.groupby('category')['value'].sum()
        
        assert result['A'] == 90.0  # 10 + 30 + 50
        assert result['B'] == 60.0  # 20 + 40
    
    def test_filter_operation(self, sample_df):
        """Test filtering"""
        result = sample_df[sample_df['value'] > 25]
        
        assert len(result) == 3
        assert all(result['value'] > 25)
    
    def test_dataframe_equality(self, sample_df):
        """Test DataFrame equality"""
        # Create identical DataFrame
        expected = pd.DataFrame({
            'id': [1, 2, 3, 4, 5],
            'value': [10.0, 20.0, 30.0, 40.0, 50.0],
            'category': ['A', 'B', 'A', 'B', 'A']
        })
        
        # Use pandas testing utility
        pd.testing.assert_frame_equal(sample_df, expected)
    
    def test_null_handling(self):
        """Test NULL value handling"""
        df = pd.DataFrame({
            'id': [1, 2, 3],
            'value': [10.0, None, 30.0]
        })
        
        # Check for NULLs
        assert df['value'].isnull().sum() == 1
        
        # Fill NULLs
        df_filled = df.fillna({'value': 0})
        assert df_filled['value'].isnull().sum() == 0
    
    def test_merge_operation(self):
        """Test DataFrame merge"""
        df1 = pd.DataFrame({
            'id': [1, 2, 3],
            'value': [10, 20, 30]
        })
        
        df2 = pd.DataFrame({
            'id': [1, 2, 4],
            'category': ['A', 'B', 'C']
        })
        
        result = pd.merge(df1, df2, on='id', how='inner')
        
        # Should only have matching IDs (1, 2)
        assert len(result) == 2
        assert list(result['id']) == [1, 2]
    
    def test_duplicate_detection(self):
        """Test duplicate detection"""
        df = pd.DataFrame({
            'id': [1, 2, 2, 3],
            'value': [10, 20, 20, 30]
        })
        
        # Check for duplicates
        assert df.duplicated().sum() == 1
        assert df['id'].duplicated().sum() == 1
        
        # Remove duplicates
        df_unique = df.drop_duplicates(subset=['id'])
        assert len(df_unique) == 3
        assert df_unique['id'].is_unique


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
```

---

## Running the Tests

```bash
# Run all tests
pytest tests/ -v

# Run specific file
pytest tests/test_basics.py -v

# Run specific test
pytest tests/test_basics.py::TestBasicValidation::test_valid_amount_positive -v

# Run with output (print statements)
pytest tests/ -v -s

# Run with coverage
pytest tests/ --cov=. --cov-report=html

# Run only fast tests (skip slow ones)
pytest tests/ -v -m "not slow"

# Stop on first failure
pytest tests/ -x

# Run in parallel (4 workers)
pytest tests/ -n 4

# Show test durations
pytest tests/ --durations=10
```

---

## Expected Output

When you run `pytest tests/ -v`, you should see something like:

```
============================= test session starts ==============================
tests/test_basics.py::TestBasicValidation::test_valid_amount_positive PASSED
tests/test_basics.py::TestBasicValidation::test_valid_amount_zero PASSED
tests/test_basics.py::TestBasicValidation::test_valid_amount_negative PASSED
tests/test_basics.py::TestBasicValidation::test_calculate_discount_normal PASSED
tests/test_basics.py::TestParametrized::test_valid_amount_parametrized[100-True] PASSED
tests/test_basics.py::TestParametrized::test_valid_amount_parametrized[0-False] PASSED
...
tests/test_transformations.py::TestTransformations::test_standardize_date PASSED
tests/test_transformations.py::TestTransformations::test_add_calculated_fields PASSED
...
tests/test_mocking.py::TestMocking::test_mock_database_connection PASSED
tests/test_mocking.py::TestMocking::test_mock_s3_upload PASSED
...

============================== 30 passed in 2.34s ===============================
```

---

## Practice Exercises

Try writing tests for these scenarios:

### Exercise 1: Test a merge function
```python
def merge_regional_data(region1_df, region2_df):
    """Merge data from two regions"""
    # Your implementation here
    pass

# Write tests for:
# - Normal merge with overlapping IDs
# - Merge with no overlapping IDs
# - Merge with empty DataFrames
```

### Exercise 2: Test a validation function
```python
def validate_sales_data(df):
    """Validate sales data returns list of errors"""
    # Your implementation here
    pass

# Write tests for:
# - Valid data returns empty error list
# - Invalid data returns appropriate errors
# - NULL values detected
# - Duplicate IDs detected
```

### Exercise 3: Test with fixtures
```python
# Create fixtures for:
# - Clean sales data
# - Data with various quality issues
# - Empty DataFrame
# Then write tests using these fixtures
```

---

## Common Pytest Commands Cheat Sheet

```bash
# Running tests
pytest                              # Run all tests
pytest tests/                       # Run all tests in directory
pytest tests/test_basics.py         # Run specific file
pytest tests/test_basics.py::test_name  # Run specific test
pytest -k "transform"               # Run tests matching pattern

# Output control
pytest -v                           # Verbose output
pytest -vv                          # Very verbose
pytest -s                           # Show print statements
pytest -q                           # Quiet mode

# Stopping
pytest -x                           # Stop on first failure
pytest --maxfail=2                  # Stop after 2 failures

# Coverage
pytest --cov=src                    # Show coverage
pytest --cov=src --cov-report=html  # Generate HTML report

# Performance
pytest -n 4                         # Run with 4 CPUs
pytest --durations=10               # Show 10 slowest tests

# Markers
pytest -m integration               # Run only integration tests
pytest -m "not slow"                # Skip slow tests

# Debugging
pytest --pdb                        # Drop into debugger on failure
pytest --lf                         # Run last failed tests
pytest --ff                         # Run failures first

# Help
pytest --help                       # Show all options
pytest --markers                    # Show available markers
```

---

## Next Steps

1. **Run these examples**: Copy the code and run `pytest tests/ -v`
2. **Modify them**: Change values, add assertions, break things intentionally
3. **Write your own**: Test your retail sales ETL functions
4. **Practice explaining**: Talk through what each test does

**You're now ready to discuss pytest in interviews! 🚀**
