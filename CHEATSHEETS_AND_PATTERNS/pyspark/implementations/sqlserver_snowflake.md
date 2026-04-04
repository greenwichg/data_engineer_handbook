I'll provide a comprehensive solution for orchestrating a PySpark-based ETL job that extracts from SQL Server and loads into Snowflake.

## Problem Understanding

**ETL Flow:**
```
SQL Server (Source) → PySpark (Transform) → Snowflake (Destination)
```

**Challenges:**
- Different connection types (JDBC vs Snowflake connector)
- Data type mapping between platforms
- Handling large datasets efficiently
- Incremental vs full loads
- Error handling and recovery
- Scheduling and monitoring

## Solution 1: Basic ETL Pipeline

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ==========================================
# INITIALIZE SPARK WITH REQUIRED CONNECTORS
# ==========================================

spark = SparkSession.builder \
    .appName("SQLServer_to_Snowflake_ETL") \
    .config("spark.jars.packages", 
            "com.microsoft.sqlserver:mssql-jdbc:9.4.0.jre8,"
            "net.snowflake:spark-snowflake_2.12:2.11.0-spark_3.3") \
    .config("spark.sql.legacy.timeParserPolicy", "LEGACY") \
    .getOrCreate()

# ==========================================
# CONFIGURATION
# ==========================================

# SQL Server configuration
sql_server_config = {
    "url": "jdbc:sqlserver://your-server.database.windows.net:1433",
    "database": "your_database",
    "user": "your_username",
    "password": "your_password",
    "driver": "com.microsoft.sqlserver.jdbc.SQLServerDriver"
}

# Snowflake configuration
snowflake_config = {
    "sfURL": "your_account.snowflakecomputing.com",
    "sfUser": "your_username",
    "sfPassword": "your_password",
    "sfDatabase": "your_database",
    "sfSchema": "your_schema",
    "sfWarehouse": "your_warehouse",
    "sfRole": "your_role"
}

# ==========================================
# EXTRACT: Read from SQL Server
# ==========================================

logger.info("Extracting data from SQL Server...")

# Method 1: Read entire table
df_extract = spark.read \
    .format("jdbc") \
    .option("url", f"{sql_server_config['url']};databaseName={sql_server_config['database']}") \
    .option("dbtable", "dbo.sales_transactions") \
    .option("user", sql_server_config["user"]) \
    .option("password", sql_server_config["password"]) \
    .option("driver", sql_server_config["driver"]) \
    .load()

logger.info(f"Extracted {df_extract.count()} records from SQL Server")

# ==========================================
# TRANSFORM: Business Logic
# ==========================================

logger.info("Transforming data...")

df_transformed = df_extract \
    .filter(col("amount") > 0) \
    .withColumn("load_timestamp", current_timestamp()) \
    .withColumn("year", year(col("transaction_date"))) \
    .withColumn("month", month(col("transaction_date"))) \
    .withColumn("amount_usd", col("amount") * col("exchange_rate"))

logger.info(f"Transformed to {df_transformed.count()} records")

# ==========================================
# LOAD: Write to Snowflake
# ==========================================

logger.info("Loading data to Snowflake...")

df_transformed.write \
    .format("snowflake") \
    .options(**snowflake_config) \
    .option("dbtable", "sales_transactions_processed") \
    .mode("overwrite") \
    .save()

logger.info("ETL completed successfully!")

spark.stop()
```

## Solution 2: Production-Ready ETL with Incremental Loads

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime, timedelta
import logging
from typing import Dict, Optional

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ==========================================
# ETL PIPELINE CLASS
# ==========================================

class SQLServerToSnowflakeETL:
    """
    Production-grade ETL pipeline from SQL Server to Snowflake
    """
    
    def __init__(self, spark: SparkSession, config: Dict):
        self.spark = spark
        self.config = config
        self.metrics = {
            'records_extracted': 0,
            'records_transformed': 0,
            'records_loaded': 0,
            'start_time': None,
            'end_time': None
        }
    
    def extract_from_sql_server(
        self,
        table_name: str,
        incremental_column: str = None,
        last_value: str = None,
        partition_column: str = None
    ):
        """
        Extract data from SQL Server with incremental load support
        
        Args:
            table_name: SQL Server table name
            incremental_column: Column for incremental extraction (e.g., modified_date)
            last_value: Last extracted value for incremental load
            partition_column: Column to use for parallel extraction
        """
        logger.info(f"Extracting from SQL Server table: {table_name}")
        
        sql_config = self.config['sql_server']
        
        # Build query for incremental load
        if incremental_column and last_value:
            query = f"""
                (SELECT * FROM {table_name} 
                 WHERE {incremental_column} > '{last_value}') as incremental_data
            """
            logger.info(f"Incremental load: {incremental_column} > {last_value}")
        else:
            query = f"(SELECT * FROM {table_name}) as full_data"
            logger.info("Full load")
        
        # Read with partitioning for better performance
        read_options = {
            "url": f"{sql_config['url']};databaseName={sql_config['database']}",
            "dbtable": query,
            "user": sql_config["user"],
            "password": sql_config["password"],
            "driver": sql_config["driver"]
        }
        
        # Add partitioning for large tables
        if partition_column:
            read_options.update({
                "partitionColumn": partition_column,
                "lowerBound": "1",
                "upperBound": "1000000",
                "numPartitions": "10"
            })
        
        df = self.spark.read.format("jdbc").options(**read_options).load()
        
        self.metrics['records_extracted'] = df.count()
        logger.info(f"Extracted {self.metrics['records_extracted']} records")
        
        return df
    
    def transform(self, df):
        """
        Apply business transformations
        """
        logger.info("Applying transformations...")
        
        # Add audit columns
        df_transformed = df \
            .withColumn("etl_load_timestamp", current_timestamp()) \
            .withColumn("etl_job_id", lit(self.config.get('job_id', 'unknown'))) \
            .withColumn("etl_source", lit("SQL_SERVER"))
        
        # Data quality checks
        df_transformed = df_transformed.filter(col("id").isNotNull())
        
        # Business transformations (customize as needed)
        if "transaction_date" in df.columns:
            df_transformed = df_transformed \
                .withColumn("year", year(col("transaction_date"))) \
                .withColumn("month", month(col("transaction_date"))) \
                .withColumn("quarter", quarter(col("transaction_date")))
        
        # Type conversions
        for col_name, col_type in df.dtypes:
            if col_type == 'string' and col_name.endswith('_amount'):
                df_transformed = df_transformed.withColumn(
                    col_name,
                    col(col_name).cast('decimal(18,2)')
                )
        
        self.metrics['records_transformed'] = df_transformed.count()
        logger.info(f"Transformed {self.metrics['records_transformed']} records")
        
        return df_transformed
    
    def load_to_snowflake(
        self,
        df,
        table_name: str,
        mode: str = "append"
    ):
        """
        Load data to Snowflake
        
        Args:
            df: DataFrame to load
            table_name: Target Snowflake table
            mode: Write mode (append, overwrite, merge)
        """
        logger.info(f"Loading to Snowflake table: {table_name}")
        
        sf_config = self.config['snowflake']
        
        # Write options
        write_options = {
            "sfURL": sf_config['url'],
            "sfUser": sf_config['user'],
            "sfPassword": sf_config['password'],
            "sfDatabase": sf_config['database'],
            "sfSchema": sf_config['schema'],
            "sfWarehouse": sf_config['warehouse'],
            "dbtable": table_name
        }
        
        # Add optional configurations
        if 'role' in sf_config:
            write_options['sfRole'] = sf_config['role']
        
        # Optimize for large writes
        df.write \
            .format("snowflake") \
            .options(**write_options) \
            .option("truncate_table", "off") \
            .option("usestagingtable", "on") \
            .mode(mode) \
            .save()
        
        self.metrics['records_loaded'] = df.count()
        logger.info(f"Loaded {self.metrics['records_loaded']} records")
    
    def get_last_load_value(self, table_name: str, column_name: str) -> Optional[str]:
        """
        Get the last loaded value for incremental processing
        """
        try:
            sf_config = self.config['snowflake']
            
            query = f"""
                (SELECT MAX({column_name}) as max_value 
                 FROM {table_name}) as last_value
            """
            
            df = self.spark.read \
                .format("snowflake") \
                .options(**{
                    "sfURL": sf_config['url'],
                    "sfUser": sf_config['user'],
                    "sfPassword": sf_config['password'],
                    "sfDatabase": sf_config['database'],
                    "sfSchema": sf_config['schema'],
                    "sfWarehouse": sf_config['warehouse'],
                    "dbtable": query
                }) \
                .load()
            
            max_value = df.collect()[0]['max_value']
            logger.info(f"Last loaded value: {max_value}")
            return str(max_value) if max_value else None
            
        except Exception as e:
            logger.warning(f"Could not retrieve last load value: {e}")
            return None
    
    def run_incremental_etl(
        self,
        source_table: str,
        target_table: str,
        incremental_column: str,
        partition_column: str = None
    ):
        """
        Run incremental ETL pipeline
        """
        self.metrics['start_time'] = datetime.now()
        logger.info(f"Starting incremental ETL: {source_table} -> {target_table}")
        
        try:
            # Get last loaded value
            last_value = self.get_last_load_value(target_table, incremental_column)
            
            # Extract
            df_extracted = self.extract_from_sql_server(
                table_name=source_table,
                incremental_column=incremental_column,
                last_value=last_value,
                partition_column=partition_column
            )
            
            if df_extracted.count() == 0:
                logger.info("No new records to process")
                return
            
            # Transform
            df_transformed = self.transform(df_extracted)
            
            # Load
            self.load_to_snowflake(
                df=df_transformed,
                table_name=target_table,
                mode="append"
            )
            
            self.metrics['end_time'] = datetime.now()
            self._log_metrics()
            
            logger.info("ETL completed successfully!")
            
        except Exception as e:
            logger.error(f"ETL failed: {e}")
            raise
    
    def _log_metrics(self):
        """Log ETL metrics"""
        duration = (self.metrics['end_time'] - self.metrics['start_time']).total_seconds()
        
        logger.info("="*60)
        logger.info("ETL METRICS")
        logger.info("="*60)
        logger.info(f"Records Extracted: {self.metrics['records_extracted']:,}")
        logger.info(f"Records Transformed: {self.metrics['records_transformed']:,}")
        logger.info(f"Records Loaded: {self.metrics['records_loaded']:,}")
        logger.info(f"Duration: {duration:.2f} seconds")
        logger.info(f"Throughput: {self.metrics['records_loaded']/duration:.2f} records/sec")
        logger.info("="*60)

# ==========================================
# USAGE EXAMPLE
# ==========================================

# Initialize Spark
spark = SparkSession.builder \
    .appName("SQLServer_to_Snowflake") \
    .config("spark.jars.packages",
            "com.microsoft.sqlserver:mssql-jdbc:9.4.0.jre8,"
            "net.snowflake:spark-snowflake_2.12:2.11.0-spark_3.3") \
    .getOrCreate()

# Configuration
config = {
    'job_id': 'etl_job_001',
    'sql_server': {
        'url': 'jdbc:sqlserver://your-server.database.windows.net:1433',
        'database': 'sales_db',
        'user': 'etl_user',
        'password': 'secure_password',
        'driver': 'com.microsoft.sqlserver.jdbc.SQLServerDriver'
    },
    'snowflake': {
        'url': 'your_account.snowflakecomputing.com',
        'user': 'etl_user',
        'password': 'secure_password',
        'database': 'ANALYTICS_DB',
        'schema': 'PUBLIC',
        'warehouse': 'ETL_WH',
        'role': 'ETL_ROLE'
    }
}

# Initialize ETL
etl = SQLServerToSnowflakeETL(spark, config)

# Run incremental ETL
etl.run_incremental_etl(
    source_table='dbo.sales_transactions',
    target_table='SALES_TRANSACTIONS',
    incremental_column='modified_date',
    partition_column='transaction_id'
)

spark.stop()
```

## Solution 3: Airflow Orchestration

```python
# ==========================================
# AIRFLOW DAG FOR ETL ORCHESTRATION
# ==========================================

from airflow import DAG
from airflow.providers.apache.spark.operators.spark_submit import SparkSubmitOperator
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

# Default arguments
default_args = {
    'owner': 'data_engineering',
    'depends_on_past': False,
    'email': ['alerts@company.com'],
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
}

# Define DAG
dag = DAG(
    'sqlserver_to_snowflake_etl',
    default_args=default_args,
    description='ETL from SQL Server to Snowflake',
    schedule_interval='0 2 * * *',  # Run daily at 2 AM
    start_date=days_ago(1),
    catchup=False,
    tags=['etl', 'sqlserver', 'snowflake'],
)

# ==========================================
# TASK 1: Pre-ETL Validation
# ==========================================

def validate_source_data(**context):
    """
    Validate source data before ETL
    """
    from pyspark.sql import SparkSession
    
    spark = SparkSession.builder.appName("Validation").getOrCreate()
    
    # Check SQL Server connectivity
    try:
        df = spark.read \
            .format("jdbc") \
            .option("url", "jdbc:sqlserver://your-server:1433") \
            .option("dbtable", "(SELECT COUNT(*) as cnt FROM dbo.sales_transactions) as test") \
            .option("user", "user") \
            .option("password", "pass") \
            .load()
        
        count = df.collect()[0]['cnt']
        logger.info(f"Source table has {count} records")
        
        if count == 0:
            raise ValueError("Source table is empty!")
            
    except Exception as e:
        logger.error(f"Validation failed: {e}")
        raise
    finally:
        spark.stop()

validation_task = PythonOperator(
    task_id='validate_source_data',
    python_callable=validate_source_data,
    dag=dag,
)

# ==========================================
# TASK 2: Run Spark ETL Job
# ==========================================

etl_task = SparkSubmitOperator(
    task_id='run_etl_job',
    application='/path/to/etl_job.py',  # Your PySpark script
    name='sqlserver_to_snowflake_etl',
    conn_id='spark_default',
    conf={
        'spark.jars.packages': 
            'com.microsoft.sqlserver:mssql-jdbc:9.4.0.jre8,'
            'net.snowflake:spark-snowflake_2.12:2.11.0-spark_3.3',
        'spark.executor.memory': '4g',
        'spark.driver.memory': '2g',
        'spark.executor.cores': '2',
        'spark.executor.instances': '4'
    },
    application_args=[
        '--source-table', 'dbo.sales_transactions',
        '--target-table', 'SALES_TRANSACTIONS',
        '--incremental-column', 'modified_date',
        '--mode', 'incremental'
    ],
    dag=dag,
)

# ==========================================
# TASK 3: Post-ETL Validation
# ==========================================

def validate_target_data(**context):
    """
    Validate data in Snowflake after ETL
    """
    from pyspark.sql import SparkSession
    
    spark = SparkSession.builder.appName("PostValidation").getOrCreate()
    
    try:
        # Check Snowflake data
        df = spark.read \
            .format("snowflake") \
            .options(**{
                "sfURL": "account.snowflakecomputing.com",
                "sfUser": "user",
                "sfPassword": "pass",
                "sfDatabase": "ANALYTICS_DB",
                "sfSchema": "PUBLIC",
                "sfWarehouse": "ETL_WH",
                "dbtable": "(SELECT COUNT(*) as cnt, MAX(etl_load_timestamp) as last_load FROM SALES_TRANSACTIONS) as validation"
            }) \
            .load()
        
        result = df.collect()[0]
        logger.info(f"Target table has {result['cnt']} records")
        logger.info(f"Last load: {result['last_load']}")
        
    except Exception as e:
        logger.error(f"Post-validation failed: {e}")
        raise
    finally:
        spark.stop()

post_validation_task = PythonOperator(
    task_id='validate_target_data',
    python_callable=validate_target_data,
    dag=dag,
)

# ==========================================
# TASK 4: Send Success Notification
# ==========================================

def send_success_notification(**context):
    """
    Send notification on successful completion
    """
    # Implement your notification logic (email, Slack, etc.)
    logger.info("ETL completed successfully!")
    print("Sending success notification...")

notification_task = PythonOperator(
    task_id='send_notification',
    python_callable=send_success_notification,
    dag=dag,
)

# ==========================================
# DEFINE TASK DEPENDENCIES
# ==========================================

validation_task >> etl_task >> post_validation_task >> notification_task
```

## Solution 4: Error Handling and Recovery

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.utils import AnalysisException
import logging
from typing import Dict, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

# ==========================================
# ETL WITH ROBUST ERROR HANDLING
# ==========================================

class RobustETL:
    """
    ETL with comprehensive error handling and recovery
    """
    
    def __init__(self, spark: SparkSession, config: Dict):
        self.spark = spark
        self.config = config
        self.error_records = []
    
    def safe_extract(self, table_name: str):
        """
        Extract with error handling and retries
        """
        max_retries = 3
        retry_count = 0
        
        while retry_count < max_retries:
            try:
                logger.info(f"Extraction attempt {retry_count + 1}/{max_retries}")
                
                df = self.spark.read \
                    .format("jdbc") \
                    .options(**self._get_sql_server_options(table_name)) \
                    .load()
                
                logger.info(f"Successfully extracted {df.count()} records")
                return df
                
            except Exception as e:
                retry_count += 1
                logger.error(f"Extraction failed (attempt {retry_count}): {e}")
                
                if retry_count >= max_retries:
                    self._log_error("EXTRACT", str(e), table_name)
                    raise
                
                import time
                time.sleep(5 * retry_count)  # Exponential backoff
    
    def safe_transform(self, df):
        """
        Transform with error handling for bad records
        """
        try:
            # Separate good and bad records
            df_with_validation = df.withColumn(
                "is_valid",
                when(
                    (col("id").isNotNull()) &
                    (col("amount") > 0) &
                    (col("transaction_date").isNotNull()),
                    True
                ).otherwise(False)
            )
            
            # Count bad records
            bad_count = df_with_validation.filter(col("is_valid") == False).count()
            
            if bad_count > 0:
                logger.warning(f"Found {bad_count} invalid records")
                
                # Save bad records for review
                bad_records = df_with_validation.filter(col("is_valid") == False)
                self._quarantine_bad_records(bad_records)
            
            # Process only good records
            df_good = df_with_validation.filter(col("is_valid") == True).drop("is_valid")
            
            # Apply transformations
            df_transformed = df_good \
                .withColumn("etl_timestamp", current_timestamp()) \
                .withColumn("year", year(col("transaction_date")))
            
            return df_transformed
            
        except Exception as e:
            self._log_error("TRANSFORM", str(e))
            raise
    
    def safe_load(self, df, table_name: str):
        """
        Load with error handling and partial success support
        """
        try:
            # Attempt full load
            df.write \
                .format("snowflake") \
                .options(**self._get_snowflake_options(table_name)) \
                .mode("append") \
                .save()
            
            logger.info(f"Successfully loaded {df.count()} records")
            
        except Exception as e:
            logger.error(f"Load failed: {e}")
            
            # Attempt to load in smaller batches
            logger.info("Attempting batch load...")
            self._batch_load(df, table_name)
    
    def _batch_load(self, df, table_name: str, batch_size: int = 10000):
        """
        Load data in batches for better error recovery
        """
        total_rows = df.count()
        df_cached = df.cache()
        
        # Add row number for batching
        df_numbered = df_cached.withColumn(
            "batch_num",
            (monotonically_increasing_id() / batch_size).cast("int")
        )
        
        batches = df_numbered.select("batch_num").distinct().collect()
        
        for batch in batches:
            batch_num = batch['batch_num']
            logger.info(f"Loading batch {batch_num + 1}/{len(batches)}")
            
            try:
                batch_df = df_numbered.filter(col("batch_num") == batch_num).drop("batch_num")
                
                batch_df.write \
                    .format("snowflake") \
                    .options(**self._get_snowflake_options(table_name)) \
                    .mode("append") \
                    .save()
                
                logger.info(f"Batch {batch_num + 1} loaded successfully")
                
            except Exception as e:
                logger.error(f"Batch {batch_num + 1} failed: {e}")
                self._log_error("LOAD_BATCH", str(e), f"batch_{batch_num}")
        
        df_cached.unpersist()
    
    def _quarantine_bad_records(self, bad_df):
        """
        Save bad records for manual review
        """
        quarantine_path = f"/quarantine/{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        bad_df.withColumn("quarantine_timestamp", current_timestamp()) \
            .write \
            .mode("append") \
            .parquet(quarantine_path)
        
        logger.warning(f"Bad records quarantined to: {quarantine_path}")
    
    def _log_error(self, stage: str, error: str, details: str = ""):
        """
        Log errors for monitoring
        """
        error_record = {
            'timestamp': datetime.now(),
            'stage': stage,
            'error': error,
            'details': details
        }
        self.error_records.append(error_record)
        
        # Could also write to error table or monitoring system
        logger.error(f"Error in {stage}: {error}")
    
    def _get_sql_server_options(self, table_name: str) -> Dict:
        """Get SQL Server connection options"""
        config = self.config['sql_server']
        return {
            "url": f"{config['url']};databaseName={config['database']}",
            "dbtable": table_name,
            "user": config['user'],
            "password": config['password'],
            "driver": config['driver']
        }
    
    def _get_snowflake_options(self, table_name: str) -> Dict:
        """Get Snowflake connection options"""
        config = self.config['snowflake']
        return {
            "sfURL": config['url'],
            "sfUser": config['user'],
            "sfPassword": config['password'],
            "sfDatabase": config['database'],
            "sfSchema": config['schema'],
            "sfWarehouse": config['warehouse'],
            "dbtable": table_name
        }

# Usage
config = {
    'sql_server': {...},
    'snowflake': {...}
}

etl = RobustETL(spark, config)

try:
    df = etl.safe_extract('dbo.sales_transactions')
    df_transformed = etl.safe_transform(df)
    etl.safe_load(df_transformed, 'SALES_TRANSACTIONS')
except Exception as e:
    logger.error(f"ETL failed: {e}")
    # Handle failure (alert, retry, etc.)
```

## Solution 5: Performance Optimized ETL

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
import logging

logger = logging.getLogger(__name__)

# ==========================================
# PERFORMANCE-OPTIMIZED CONFIGURATION
# ==========================================

spark = SparkSession.builder \
    .appName("Optimized_ETL") \
    .config("spark.jars.packages",
            "com.microsoft.sqlserver:mssql-jdbc:9.4.0.jre8,"
            "net.snowflake:spark-snowflake_2.12:2.11.0-spark_3.3") \
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.default.parallelism", "200") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.executor.memory", "8g") \
    .config("spark.driver.memory", "4g") \
    .config("spark.executor.cores", "4") \
    .config("spark.memory.fraction", "0.8") \
    .getOrCreate()

# ==========================================
# OPTIMIZED EXTRACT
# ==========================================

def optimized_extract(table_name: str, partition_column: str = "id"):
    """
    Extract with parallel partitioning for better performance
    """
    
    # First, get the range of partition column
    range_query = f"""
        (SELECT MIN({partition_column}) as min_val, 
                MAX({partition_column}) as max_val 
         FROM {table_name}) as ranges
    """
    
    range_df = spark.read \
        .format("jdbc") \
        .option("url", "jdbc:sqlserver://...") \
        .option("dbtable", range_query) \
        .option("user", "user") \
        .option("password", "pass") \
        .load()
    
    min_val, max_val = range_df.collect()[0]
    
    logger.info(f"Partition range: {min_val} to {max_val}")
    
    # Read with partitioning for parallel extraction
    df = spark.read \
        .format("jdbc") \
        .option("url", "jdbc:sqlserver://...") \
        .option("dbtable", table_name) \
        .option("user", "user") \
        .option("password", "pass") \
        .option("partitionColumn", partition_column) \
        .option("lowerBound", str(min_val)) \
        .option("upperBound", str(max_val)) \
        .option("numPartitions", "20") \
        .option("fetchsize", "10000") \
        .load()
    
    return df

# ==========================================
# OPTIMIZED LOAD
# ==========================================

def optimized_load(df, table_name: str):
    """
    Load with optimizations for Snowflake
    """
    
    # Repartition for optimal file sizes
    # Target: 100-250 MB per file
    df_repartitioned = df.repartition(20)
    
    # Write with optimizations
    df_repartitioned.write \
        .format("snowflake") \
        .options(**{
            "sfURL": "account.snowflakecomputing.com",
            "sfUser": "user",
            "sfPassword": "pass",
            "sfDatabase": "DB",
            "sfSchema": "SCHEMA",
            "sfWarehouse": "ETL_WH",
            "dbtable": table_name,
            "usestagingtable": "on",  # Use staging for better performance
            "purge": "true"  # Clean up staging files
        }) \
        .mode("append") \
        .save()

# ==========================================
# COMPLETE OPTIMIZED PIPELINE
# ==========================================

logger.info("Starting optimized ETL...")

# Extract with partitioning
df_extracted = optimized_extract("dbo.large_table", partition_column="id")

# Transform (with caching for reuse)
df_transformed = df_extracted \
    .filter(col("status") == "active") \
    .withColumn("load_date", current_date()) \
    .cache()

logger.info(f"Records to load: {df_transformed.count()}")

# Load optimized
optimized_load(df_transformed, "LARGE_TABLE")

df_transformed.unpersist()

logger.info("ETL completed!")
```

## Solution 6: Complete End-to-End Example

```python
#!/usr/bin/env python3
"""
Complete ETL Pipeline: SQL Server to Snowflake
Run with: spark-submit --packages <packages> etl_pipeline.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime
import argparse
import logging
import sys

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(f'etl_{datetime.now().strftime("%Y%m%d")}.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def main(args):
    """
    Main ETL function
    """
    
    # Initialize Spark
    logger.info("Initializing Spark session...")
    spark = SparkSession.builder \
        .appName("SQLServer_to_Snowflake_ETL") \
        .config("spark.jars.packages",
                "com.microsoft.sqlserver:mssql-jdbc:9.4.0.jre8,"
                "net.snowflake:spark-snowflake_2.12:2.11.0-spark_3.3") \
        .getOrCreate()
    
    try:
        # ==========================================
        # EXTRACT
        # ==========================================
        logger.info(f"Extracting from SQL Server table: {args.source_table}")
        
        df = spark.read \
            .format("jdbc") \
            .option("url", f"{args.sql_server_url};databaseName={args.sql_server_db}") \
            .option("dbtable", args.source_table) \
            .option("user", args.sql_server_user) \
            .option("password", args.sql_server_password) \
            .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
            .load()
        
        record_count = df.count()
        logger.info(f"Extracted {record_count} records")
        
        if record_count == 0:
            logger.warning("No records to process!")
            return
        
        # ==========================================
        # TRANSFORM
        # ==========================================
        logger.info("Transforming data...")
        
        df_transformed = df \
            .filter(col("id").isNotNull()) \
            .withColumn("etl_load_timestamp", current_timestamp()) \
            .withColumn("etl_job_name", lit(args.job_name))
        
        transformed_count = df_transformed.count()
        logger.info(f"Transformed {transformed_count} records")
        
        # ==========================================
        # LOAD
        # ==========================================
        logger.info(f"Loading to Snowflake table: {args.target_table}")
        
        df_transformed.write \
            .format("snowflake") \
            .options(**{
                "sfURL": args.snowflake_url,
                "sfUser": args.snowflake_user,
                "sfPassword": args.snowflake_password,
                "sfDatabase": args.snowflake_db,
                "sfSchema": args.snowflake_schema,
                "sfWarehouse": args.snowflake_warehouse,
                "dbtable": args.target_table
            }) \
            .mode(args.load_mode) \
            .save()
        
        logger.info(f"Successfully loaded {transformed_count} records")
        logger.info("ETL completed successfully!")
        
    except Exception as e:
        logger.error(f"ETL failed: {e}", exc_info=True)
        raise
        
    finally:
        spark.stop()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='SQL Server to Snowflake ETL')
    
    # Job parameters
    parser.add_argument('--job-name', required=True, help='ETL job name')
    parser.add_argument('--load-mode', default='append', choices=['append', 'overwrite'])
    
    # SQL Server parameters
    parser.add_argument('--sql-server-url', required=True)
    parser.add_argument('--sql-server-db', required=True)
    parser.add_argument('--sql-server-user', required=True)
    parser.add_argument('--sql-server-password', required=True)
    parser.add_argument('--source-table', required=True)
    
    # Snowflake parameters
    parser.add_argument('--snowflake-url', required=True)
    parser.add_argument('--snowflake-user', required=True)
    parser.add_argument('--snowflake-password', required=True)
    parser.add_argument('--snowflake-db', required=True)
    parser.add_argument('--snowflake-schema', required=True)
    parser.add_argument('--snowflake-warehouse', required=True)
    parser.add_argument('--target-table', required=True)
    
    args = parser.parse_args()
    main(args)
```

## Key Takeaways:

**Architecture:**
1. ✅ **Extract**: JDBC connector for SQL Server
2. ✅ **Transform**: PySpark transformations
3. ✅ **Load**: Snowflake Spark connector
4. ✅ **Orchestrate**: Airflow/scheduled jobs

**Best Practices:**
- Use incremental loads for efficiency
- Implement parallel extraction with partitioning
- Add comprehensive error handling
- Log metrics and errors
- Cache intermediate results
- Use staging tables in Snowflake

**Performance Optimization:**
- Partition reads from SQL Server
- Repartition before writing to Snowflake
- Use appropriate Spark configurations
- Enable adaptive query execution
- Optimize file sizes (128-256 MB)

**Production Considerations:**
- Secrets management (not hardcoded)
- Monitoring and alerting
- Data quality validation
- Retry logic with backoff
- Quarantine bad records
- Audit logging
- Cost optimization

This comprehensive solution provides multiple approaches from basic to production-ready implementations for orchestrating PySpark ETL from SQL Server to Snowflake!