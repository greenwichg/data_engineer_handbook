# PySpark Implementation: Spark on Kubernetes

## Problem Statement

Running Spark on **Kubernetes (K8s)** is an increasingly popular alternative to YARN, offering better **resource isolation, containerization, and cloud-native deployment**. Interviewers ask about this to test knowledge of modern Spark deployment patterns, especially in cloud environments.

---

## Method 1: spark-submit on Kubernetes

```bash
# Basic spark-submit targeting a K8s cluster
spark-submit \
    --master k8s://https://<k8s-api-server>:443 \
    --deploy-mode cluster \
    --name my-pyspark-job \
    --conf spark.kubernetes.container.image=my-registry/spark:3.5.0 \
    --conf spark.executor.instances=4 \
    --conf spark.executor.memory=4g \
    --conf spark.executor.cores=2 \
    --conf spark.driver.memory=2g \
    --conf spark.driver.cores=1 \
    --conf spark.kubernetes.namespace=spark-jobs \
    --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
    local:///opt/spark/jobs/my_etl_job.py
```

### Key Differences from YARN

```
YARN:                           Kubernetes:
- --master yarn                 - --master k8s://https://...
- Node managers run executors   - Executor pods are created dynamically
- Static cluster sizing         - Elastic pod scaling
- Hadoop ecosystem native       - Cloud-native, container-based
- Resource queues               - K8s namespaces & resource quotas
```

---

## Method 2: Core Configuration for K8s

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("SparkOnK8s") \
    .master("k8s://https://kubernetes.default.svc:443") \
    .config("spark.kubernetes.container.image", "my-registry/spark:3.5.0") \
    .config("spark.kubernetes.namespace", "spark-jobs") \
    .config("spark.kubernetes.authenticate.driver.serviceAccountName", "spark") \
    \
    .config("spark.executor.instances", "4") \
    .config("spark.executor.memory", "4g") \
    .config("spark.executor.cores", "2") \
    .config("spark.driver.memory", "2g") \
    .config("spark.driver.cores", "1") \
    \
    .config("spark.kubernetes.executor.request.cores", "2") \
    .config("spark.kubernetes.executor.limit.cores", "2") \
    .config("spark.kubernetes.executor.request.memory", "4g") \
    .config("spark.kubernetes.executor.limit.memory", "5g") \
    \
    .config("spark.kubernetes.file.upload.path", "s3a://my-bucket/spark-uploads") \
    .getOrCreate()
```

---

## Method 3: Dynamic Allocation on K8s

```python
spark = SparkSession.builder \
    .appName("DynamicAllocationK8s") \
    .config("spark.dynamicAllocation.enabled", "true") \
    .config("spark.dynamicAllocation.minExecutors", "2") \
    .config("spark.dynamicAllocation.maxExecutors", "20") \
    .config("spark.dynamicAllocation.initialExecutors", "4") \
    .config("spark.dynamicAllocation.executorIdleTimeout", "60s") \
    .config("spark.dynamicAllocation.schedulerBacklogTimeout", "1s") \
    \
    .config("spark.dynamicAllocation.shuffleTracking.enabled", "true") \
    .getOrCreate()

# With dynamic allocation:
# - Spark starts with 4 executors
# - Scales up to 20 if tasks are queued
# - Scales down to 2 if executors are idle for 60s
# - shuffleTracking replaces the external shuffle service on K8s
```

---

## Method 4: Pod Templates (Advanced Sizing)

```yaml
# executor-pod-template.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: spark-executor
spec:
  containers:
  - name: spark-executor
    resources:
      requests:
        memory: "4Gi"
        cpu: "2"
      limits:
        memory: "5Gi"
        cpu: "2"
    volumeMounts:
    - name: spark-local-dir
      mountPath: /tmp/spark-local
  volumes:
  - name: spark-local-dir
    emptyDir:
      sizeLimit: "10Gi"
  nodeSelector:
    node-type: compute-optimized
  tolerations:
  - key: "spark-workload"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

```python
# Reference pod templates in Spark config
spark = SparkSession.builder \
    .config("spark.kubernetes.executor.podTemplateFile", "/path/to/executor-pod-template.yaml") \
    .config("spark.kubernetes.driver.podTemplateFile", "/path/to/driver-pod-template.yaml") \
    .getOrCreate()
```

---

## Method 5: Cloud Storage Integration

```python
# AWS S3
spark = SparkSession.builder \
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem") \
    .config("spark.hadoop.fs.s3a.aws.credentials.provider",
            "com.amazonaws.auth.WebIdentityTokenCredentialsProvider") \
    .getOrCreate()

df = spark.read.parquet("s3a://my-bucket/data/")

# Azure ADLS Gen2
spark = SparkSession.builder \
    .config("spark.hadoop.fs.azure.account.auth.type", "OAuth") \
    .config("spark.hadoop.fs.azure.account.oauth.provider.type",
            "org.apache.hadoop.fs.azurebfs.oauth2.ManagedIdentityTokenProvider") \
    .getOrCreate()

df = spark.read.parquet("abfss://container@storage.dfs.core.windows.net/data/")

# GCS
spark = SparkSession.builder \
    .config("spark.hadoop.fs.gs.impl", "com.google.cloud.hadoop.fs.gcs.GoogleHadoopFileSystem") \
    .config("spark.hadoop.fs.gs.auth.type", "APPLICATION_DEFAULT") \
    .getOrCreate()

df = spark.read.parquet("gs://my-bucket/data/")
```

---

## K8s vs YARN Comparison

| Feature | YARN | Kubernetes |
|---------|------|------------|
| Resource model | Containers (vCores + MB) | Pods (CPU + Memory) |
| Scheduling | YARN queues | K8s namespaces + quotas |
| Isolation | Process-level | Container-level |
| Image management | Shared classpath | Docker images |
| Scaling | Static cluster | Elastic pod creation |
| Multi-tenancy | Queue-based | Namespace-based |
| Ecosystem | Hadoop-native | Cloud-native |
| Shuffle service | External shuffle service | Shuffle tracking (Spark 3.0+) |
| GPU support | Limited | Native K8s device plugins |
| Cost | Fixed cluster | Pay-per-pod (with autoscaler) |

---

## Key Takeaways

## Interview Tips

1. **Know why K8s over YARN**: containerization, elastic scaling, cloud-native, better isolation
2. **Pod templates** give fine-grained control over executor resources, node placement, and volumes
3. **Dynamic allocation on K8s** uses shuffle tracking instead of external shuffle service
4. **Container images**: you package Spark + dependencies into Docker images — reproducible deployments
5. **Cost advantage**: K8s autoscaler can spin up/down nodes, so you only pay for what you use
6. **Common gotcha**: K8s memory limits must account for JVM overhead + off-heap — set limits ~20% higher than requests
7. **Spark Operator** (spark-on-k8s-operator) is the production-grade way to manage Spark jobs on K8s
