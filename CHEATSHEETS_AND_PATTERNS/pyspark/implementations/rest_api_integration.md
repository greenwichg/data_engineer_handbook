I'll provide a comprehensive solution for integrating REST API data into PySpark pipelines efficiently.

## Problem Understanding

**Challenge:** You need to enrich Spark DataFrame records with data from external REST APIs, but:
- APIs have rate limits
- Network calls are slow
- Individual row-by-row calls don't scale
- Need error handling and retries
- Must handle large datasets efficiently

**Solution Strategy:**
1. Batch API calls to reduce requests
2. Use parallel processing with proper throttling
3. Cache responses to avoid redundant calls
4. Implement retry logic for failures
5. Handle partial failures gracefully

## Solution 1: Basic Approach (Small Datasets)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, col
from pyspark.sql.types import StringType, StructType, StructField
import requests
import json

spark = SparkSession.builder \
    .appName("APIIntegration") \
    .getOrCreate()

# ==========================================
# BASIC APPROACH: UDF for Single API Calls
# ==========================================

def call_api(customer_id):
    """
    Call external API for single customer
    Simple but NOT efficient for large datasets
    """
    try:
        response = requests.get(
            f"https://api.example.com/customers/{customer_id}",
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            return json.dumps(data)
        else:
            return None
            
    except Exception as e:
        print(f"Error calling API for {customer_id}: {e}")
        return None

# Create UDF
call_api_udf = udf(call_api, StringType())

# Sample data
data = [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie")
]

df = spark.createDataFrame(data, ["customer_id", "name"])

# Enrich with API data
enriched_df = df.withColumn(
    "api_data",
    call_api_udf(col("customer_id"))
)

enriched_df.show(truncate=False)

# ⚠️ Problem: This calls API once per row - VERY SLOW for large datasets!
```

## Solution 2: Batch API Calls (Efficient for Large Datasets)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import pandas_udf, col
from pyspark.sql.types import StringType
import pandas as pd
import requests
from typing import Iterator
import time

# ==========================================
# EFFICIENT APPROACH: Pandas UDF with Batching
# ==========================================

@pandas_udf(StringType())
def batch_api_call(customer_ids: pd.Series) -> pd.Series:
    """
    Call API in batches - MUCH more efficient!
    Processes multiple rows at once
    """
    
    results = []
    
    # Process in smaller batches to respect rate limits
    batch_size = 100
    
    for i in range(0, len(customer_ids), batch_size):
        batch = customer_ids[i:i + batch_size].tolist()
        
        try:
            # Batch API call (if API supports it)
            response = requests.post(
                "https://api.example.com/customers/batch",
                json={"ids": batch},
                timeout=30
            )
            
            if response.status_code == 200:
                batch_results = response.json()
                results.extend(batch_results)
            else:
                # Return None for failed batch
                results.extend([None] * len(batch))
                
        except Exception as e:
            print(f"Batch API error: {e}")
            results.extend([None] * len(batch))
        
        # Rate limiting - sleep between batches
        time.sleep(0.1)
    
    return pd.Series(results)

# Apply batched API calls
enriched_df = df.withColumn(
    "api_data",
    batch_api_call(col("customer_id"))
)

enriched_df.show()
```

## Solution 3: Production-Ready Implementation

```python
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import pandas_udf, col, struct, lit
from pyspark.sql.types import *
import pandas as pd
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import time
import logging
from typing import List, Dict, Optional
import hashlib

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==========================================
# PRODUCTION-READY API CLIENT
# ==========================================

class APIClient:
    """
    Robust API client with retry logic, caching, and rate limiting
    """
    
    def __init__(
        self, 
        base_url: str,
        api_key: str = None,
        rate_limit_per_second: int = 10,
        max_retries: int = 3
    ):
        self.base_url = base_url
        self.api_key = api_key
        self.rate_limit_per_second = rate_limit_per_second
        self.last_call_time = 0
        self.cache = {}
        
        # Configure session with retry logic
        self.session = requests.Session()
        retry_strategy = Retry(
            total=max_retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def _rate_limit(self):
        """Implement rate limiting"""
        current_time = time.time()
        time_since_last_call = current_time - self.last_call_time
        min_interval = 1.0 / self.rate_limit_per_second
        
        if time_since_last_call < min_interval:
            sleep_time = min_interval - time_since_last_call
            time.sleep(sleep_time)
        
        self.last_call_time = time.time()
    
    def _get_cache_key(self, endpoint: str, params: Dict) -> str:
        """Generate cache key"""
        key_string = f"{endpoint}_{str(sorted(params.items()))}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def call_api(
        self, 
        endpoint: str, 
        method: str = "GET",
        params: Dict = None,
        use_cache: bool = True
    ) -> Optional[Dict]:
        """
        Call API with caching and rate limiting
        """
        
        # Check cache
        if use_cache:
            cache_key = self._get_cache_key(endpoint, params or {})
            if cache_key in self.cache:
                logger.debug(f"Cache hit for {endpoint}")
                return self.cache[cache_key]
        
        # Rate limiting
        self._rate_limit()
        
        # Prepare request
        url = f"{self.base_url}/{endpoint}"
        headers = {}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        
        try:
            if method == "GET":
                response = self.session.get(
                    url, 
                    params=params, 
                    headers=headers,
                    timeout=10
                )
            elif method == "POST":
                response = self.session.post(
                    url,
                    json=params,
                    headers=headers,
                    timeout=30
                )
            
            response.raise_for_status()
            result = response.json()
            
            # Cache successful response
            if use_cache:
                self.cache[cache_key] = result
            
            return result
            
        except requests.exceptions.RequestException as e:
            logger.error(f"API call failed: {e}")
            return None
    
    def batch_call(
        self,
        ids: List,
        endpoint_template: str,
        batch_size: int = 100
    ) -> List[Optional[Dict]]:
        """
        Make batched API calls
        """
        results = []
        
        for i in range(0, len(ids), batch_size):
            batch = ids[i:i + batch_size]
            
            # If API supports batch endpoint
            batch_result = self.call_api(
                "batch",
                method="POST",
                params={"ids": batch, "endpoint": endpoint_template}
            )
            
            if batch_result:
                results.extend(batch_result.get("results", [None] * len(batch)))
            else:
                # Fallback: individual calls
                for id_val in batch:
                    result = self.call_api(
                        endpoint_template.format(id=id_val),
                        method="GET"
                    )
                    results.append(result)
        
        return results

# ==========================================
# SPARK INTEGRATION
# ==========================================

class APIDataEnricher:
    """
    Enrich Spark DataFrame with REST API data
    """
    
    def __init__(
        self, 
        spark: SparkSession,
        api_client: APIClient
    ):
        self.spark = spark
        self.api_client = api_client
    
    def enrich_with_api(
        self,
        df: DataFrame,
        id_column: str,
        endpoint_template: str,
        result_schema: StructType,
        batch_size: int = 100
    ) -> DataFrame:
        """
        Enrich DataFrame with API data
        
        Args:
            df: Input DataFrame
            id_column: Column containing IDs for API lookup
            endpoint_template: API endpoint template (e.g., "customers/{id}")
            result_schema: Schema for API response
            batch_size: Number of records per API batch
        """
        
        # Create Pandas UDF for batched API calls
        @pandas_udf(result_schema)
        def fetch_api_data(ids: pd.Series) -> pd.DataFrame:
            """
            Pandas UDF to fetch data from API in batches
            """
            # Convert to list
            id_list = ids.tolist()
            
            # Call API in batches
            results = self.api_client.batch_call(
                id_list,
                endpoint_template,
                batch_size=batch_size
            )
            
            # Convert results to DataFrame
            result_df = pd.DataFrame(results)
            
            # Ensure schema matches
            for field in result_schema.fields:
                if field.name not in result_df.columns:
                    result_df[field.name] = None
            
            return result_df[result_schema.fieldNames()]
        
        # Apply UDF
        enriched_df = df.withColumn(
            "api_response",
            fetch_api_data(col(id_column))
        )
        
        # Flatten struct if needed
        for field in result_schema.fields:
            enriched_df = enriched_df.withColumn(
                f"api_{field.name}",
                col(f"api_response.{field.name}")
            )
        
        return enriched_df.drop("api_response")

# ==========================================
# USAGE EXAMPLE
# ==========================================

# Initialize Spark
spark = SparkSession.builder \
    .appName("APIIntegrationProduction") \
    .config("spark.sql.execution.arrow.pyspark.enabled", "true") \
    .getOrCreate()

# Sample data
data = [(i, f"customer_{i}") for i in range(1, 1001)]
df = spark.createDataFrame(data, ["customer_id", "name"])

# Define API response schema
api_schema = StructType([
    StructField("customer_score", IntegerType(), True),
    StructField("customer_tier", StringType(), True),
    StructField("lifetime_value", DoubleType(), True)
])

# Initialize API client
api_client = APIClient(
    base_url="https://api.example.com",
    api_key="your_api_key",
    rate_limit_per_second=10,
    max_retries=3
)

# Initialize enricher
enricher = APIDataEnricher(spark, api_client)

# Enrich data
logger.info("Starting API enrichment...")
enriched_df = enricher.enrich_with_api(
    df=df,
    id_column="customer_id",
    endpoint_template="customers/{id}",
    result_schema=api_schema,
    batch_size=100
)

logger.info("Enrichment complete!")
enriched_df.show(10)

# Save enriched data
enriched_df.write \
    .mode("overwrite") \
    .parquet("output/enriched_customers")
```

## Solution 4: Async API Calls (Maximum Performance)

```python
import asyncio
import aiohttp
from typing import List, Dict
import pandas as pd
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import StringType

# ==========================================
# ASYNC API CLIENT (Fastest Option)
# ==========================================

class AsyncAPIClient:
    """
    Asynchronous API client for maximum throughput
    """
    
    def __init__(
        self,
        base_url: str,
        api_key: str = None,
        concurrent_requests: int = 10
    ):
        self.base_url = base_url
        self.api_key = api_key
        self.concurrent_requests = concurrent_requests
        self.semaphore = asyncio.Semaphore(concurrent_requests)
    
    async def fetch_one(
        self,
        session: aiohttp.ClientSession,
        customer_id: int
    ) -> Dict:
        """
        Fetch data for one customer
        """
        async with self.semaphore:  # Limit concurrent requests
            try:
                url = f"{self.base_url}/customers/{customer_id}"
                headers = {}
                if self.api_key:
                    headers["Authorization"] = f"Bearer {self.api_key}"
                
                async with session.get(url, headers=headers) as response:
                    if response.status == 200:
                        return await response.json()
                    else:
                        return None
                        
            except Exception as e:
                logger.error(f"Error fetching {customer_id}: {e}")
                return None
    
    async def fetch_batch(
        self,
        customer_ids: List[int]
    ) -> List[Dict]:
        """
        Fetch data for multiple customers concurrently
        """
        async with aiohttp.ClientSession() as session:
            tasks = [
                self.fetch_one(session, cid)
                for cid in customer_ids
            ]
            results = await asyncio.gather(*tasks)
            return results
    
    def fetch_batch_sync(self, customer_ids: List[int]) -> List[Dict]:
        """
        Synchronous wrapper for async batch fetch
        """
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            results = loop.run_until_complete(
                self.fetch_batch(customer_ids)
            )
            return results
        finally:
            loop.close()

# ==========================================
# PANDAS UDF WITH ASYNC CLIENT
# ==========================================

# Initialize async client (outside UDF)
async_client = AsyncAPIClient(
    base_url="https://api.example.com",
    api_key="your_api_key",
    concurrent_requests=20
)

@pandas_udf(StringType())
def async_api_call(customer_ids: pd.Series) -> pd.Series:
    """
    Pandas UDF using async API calls
    """
    import json
    
    # Convert to list
    id_list = customer_ids.tolist()
    
    # Fetch concurrently
    results = async_client.fetch_batch_sync(id_list)
    
    # Convert to JSON strings
    json_results = [
        json.dumps(r) if r else None
        for r in results
    ]
    
    return pd.Series(json_results)

# Apply async enrichment
enriched_async_df = df.withColumn(
    "api_data",
    async_api_call(col("customer_id"))
)
```

## Solution 5: Handling API Pagination

```python
def fetch_paginated_api(base_url: str, endpoint: str) -> pd.DataFrame:
    """
    Fetch all pages from paginated API
    """
    all_results = []
    page = 1
    
    while True:
        try:
            response = requests.get(
                f"{base_url}/{endpoint}",
                params={"page": page, "per_page": 100},
                timeout=30
            )
            
            if response.status_code != 200:
                break
            
            data = response.json()
            results = data.get("results", [])
            
            if not results:
                break
            
            all_results.extend(results)
            
            # Check if more pages
            if not data.get("has_more", False):
                break
            
            page += 1
            time.sleep(0.1)  # Rate limiting
            
        except Exception as e:
            logger.error(f"Pagination error: {e}")
            break
    
    return pd.DataFrame(all_results)

# Use in Spark
reference_data_pd = fetch_paginated_api(
    "https://api.example.com",
    "product_catalog"
)

reference_data_spark = spark.createDataFrame(reference_data_pd)

# Join with main DataFrame
enriched_df = df.join(
    reference_data_spark,
    df.product_id == reference_data_spark.id,
    "left"
)
```

## Solution 6: Caching Strategy for Repeated Lookups

```python
from functools import lru_cache
import pickle

class CachedAPIClient:
    """
    API client with persistent caching
    """
    
    def __init__(self, base_url: str, cache_file: str = "api_cache.pkl"):
        self.base_url = base_url
        self.cache_file = cache_file
        self.cache = self._load_cache()
    
    def _load_cache(self) -> Dict:
        """Load cache from disk"""
        try:
            with open(self.cache_file, 'rb') as f:
                return pickle.load(f)
        except FileNotFoundError:
            return {}
    
    def _save_cache(self):
        """Save cache to disk"""
        with open(self.cache_file, 'wb') as f:
            pickle.dump(self.cache, f)
    
    def get_customer_data(self, customer_id: int) -> Dict:
        """Get customer data with caching"""
        
        # Check cache
        if customer_id in self.cache:
            return self.cache[customer_id]
        
        # Call API
        response = requests.get(
            f"{self.base_url}/customers/{customer_id}",
            timeout=10
        )
        
        if response.status_code == 200:
            data = response.json()
            self.cache[customer_id] = data
            self._save_cache()
            return data
        
        return None
```

## Complete Production Example:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import pandas as pd
import logging
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==========================================
# COMPLETE PRODUCTION PIPELINE
# ==========================================

class ProductionAPIEnricher:
    """
    Production-grade API enrichment for PySpark
    """
    
    def __init__(self, config: Dict):
        self.config = config
        self.session = self._create_session()
    
    def _create_session(self) -> requests.Session:
        """Create requests session with retry logic"""
        session = requests.Session()
        retry = Retry(
            total=3,
            backoff_factor=0.5,
            status_forcelist=[429, 500, 502, 503, 504]
        )
        adapter = HTTPAdapter(max_retries=retry)
        session.mount('http://', adapter)
        session.mount('https://', adapter)
        return session
    
    def enrich_dataframe(
        self,
        df: DataFrame,
        id_col: str,
        api_config: Dict
    ) -> DataFrame:
        """
        Main enrichment method
        """
        logger.info(f"Starting enrichment for {df.count()} records")
        
        # Define Pandas UDF
        @pandas_udf(api_config['response_schema'])
        def call_api_batch(ids: pd.Series) -> pd.DataFrame:
            results = []
            
            for batch_start in range(0, len(ids), api_config['batch_size']):
                batch_end = min(batch_start + api_config['batch_size'], len(ids))
                batch_ids = ids[batch_start:batch_end].tolist()
                
                try:
                    # API call
                    response = self.session.post(
                        api_config['endpoint'],
                        json={'ids': batch_ids},
                        headers={'Authorization': f"Bearer {api_config['api_key']}"},
                        timeout=30
                    )
                    
                    if response.status_code == 200:
                        batch_results = response.json()
                        results.extend(batch_results)
                    else:
                        # Handle failure
                        results.extend([None] * len(batch_ids))
                    
                except Exception as e:
                    logger.error(f"Batch error: {e}")
                    results.extend([None] * len(batch_ids))
                
                # Rate limiting
                time.sleep(api_config.get('sleep_seconds', 0.1))
            
            return pd.DataFrame(results)
        
        # Apply enrichment
        enriched = df.withColumn(
            'api_data',
            call_api_batch(col(id_col))
        )
        
        # Flatten API response
        for field in api_config['response_schema'].fields:
            enriched = enriched.withColumn(
                field.name,
                col(f'api_data.{field.name}')
            )
        
        return enriched.drop('api_data')

# Usage
spark = SparkSession.builder.appName("APIEnrichment").getOrCreate()

# Input data
df = spark.read.parquet("input/customers")

# API configuration
api_config = {
    'endpoint': 'https://api.example.com/batch',
    'api_key': 'your_key',
    'batch_size': 100,
    'sleep_seconds': 0.1,
    'response_schema': StructType([
        StructField('score', IntegerType()),
        StructField('tier', StringType()),
        StructField('ltv', DoubleType())
    ])
}

# Enrich
enricher = ProductionAPIEnricher({'api_key': 'your_key'})
result = enricher.enrich_dataframe(df, 'customer_id', api_config)

result.write.mode("overwrite").parquet("output/enriched")
```

## Key Takeaways:

**Efficiency Strategies:**
1. ✅ **Batch API calls** - Reduce number of requests
2. ✅ **Pandas UDF** - Process multiple rows at once
3. ✅ **Rate limiting** - Respect API limits
4. ✅ **Caching** - Avoid redundant calls
5. ✅ **Async calls** - Maximum throughput
6. ✅ **Retry logic** - Handle failures gracefully

**Best Practices:**
- Use Pandas UDF over regular UDF (10-100x faster)
- Implement exponential backoff for retries
- Cache frequently accessed data
- Monitor API quota usage
- Log failures for debugging
- Consider cost of API calls

**Production Considerations:**
- Handle partial failures
- Implement circuit breakers
- Monitor API performance
- Set appropriate timeouts
- Use connection pooling
- Track API costs

Does this comprehensive solution help you design an efficient REST API integration for your PySpark pipeline?