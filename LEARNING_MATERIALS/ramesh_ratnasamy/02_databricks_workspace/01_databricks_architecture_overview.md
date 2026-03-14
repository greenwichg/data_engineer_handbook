# Databricks Architecture: A Comprehensive Guide

## Introduction

Welcome back. Now that we've set up our Databricks service, I want to walk you through the high-level architecture of Databricks.

### Why Understanding Architecture Matters

As a developer, you might not need to know every detail about how it works behind the scenes, but having an understanding of its architecture will definitely help you understand:
- Where your data is stored
- Where your compute resources are located

**Note**: This is also a key area tested in both the **Data Engineer Associate** and **Professional certifications**.

---

## The Two Main Components

The Databricks architecture is divided into two main parts:

1. **Control Plane**
2. **Compute Plane**

---

## Control Plane

The Control Plane handles all the **backend services** required for the Databricks platform.

### Key Components:

#### 1. Databricks Web User Interface
Where users interact with Databricks through a browser-based interface.

#### 2. Cluster Manager
Responsible for:
- Managing compute resources
- Provisioning resources when users create clusters
- Scaling clusters up and down

#### 3. Unity Catalog
Provides:
- Data governance
- Access management
- Permissions management for your data

#### 4. Storage for Queries and Workspace Data
Used for storing workspace-related metadata such as:
- Notebooks
- Job run details
- Other workspace metadata

---

## Compute Plane

The Compute Plane is where your **data processing takes place**.

Databricks supports two types of compute:

### 1. Classic Compute

**How it works:**
- Databricks provisions clusters directly within the **customer's cloud subscription** (your subscription)
- Compute resources (virtual machines) are deployed and managed within **your cloud account**

### 2. Serverless Compute

**Background:**
- Recent addition to Databricks (introduced in 2023)

**How it works:**
- Runs on the **Databricks subscription** (not your subscription)
- Databricks allocates resources from its pool of pre-allocated virtual machines

**Advantages:**
- Significantly reduces cluster startup time compared to classic compute
- Leverages pre-allocated VMs within the Databricks subscription

---

## Workspace Cloud Storage

When you create a Databricks workspace, a **default workspace cloud storage** is automatically set up in your cloud subscription.

### Storage by Cloud Provider:

| Cloud Provider | Storage Service |
|----------------|----------------|
| **Azure** | Azure Data Lake Storage Gen2 |
| **AWS** | S3 Bucket |
| **GCP** | Google Cloud Storage |

### What is it Used For?

Workspace storage stores:
- System data (notebook revisions, job run details, Spark logs)
- Temporary data you want to work with

**⚠️ Important Warning:**
This storage is **tied to the workspace** and will be **deleted when the workspace itself is deleted**.

---

## Architecture Summary: Resource Location

Let's summarize the architecture by locating the resources in the subscription they belong to:

### Resources in Databricks Subscription:

#### Control Plane
- Handles essential tasks:
  - User interface
  - Compute orchestration through the Cluster Manager

#### Serverless Compute
- Provisioned within the Databricks subscription
- Uses pre-allocated VMs
- Speeds up start time

### Resources in Your Subscription:

#### Classic Compute Plane
- Provisioned directly within your cloud subscription when requested

#### Workspace Cloud Storage
- Located in your subscription
- Holds system and temporary data

### Data Access:

Through either compute type (classic or serverless), you can:
- Access and process data stored in the cloud
- Access on-premises applications

---

## Practical View: Azure Portal Walkthrough

### Navigating to Your Databricks Service

Let's look at the resources already created when we set up the Databricks workspace, so you can relate them to the architecture explained above.

**As shown in the diagram:**
- Both the classic compute and workspace cloud storage are created in **your subscription**
- We haven't created a cluster yet, but we can see the cloud storage

### Steps to View Resources:

1. Navigate to the Azure Portal
2. Go to your Databricks service (e.g., "da-course-dws")
3. Note the resource group where it was created (e.g., "d-org")

### The Managed Resource Group

**Important Concept:**

When you create a Databricks service, Databricks also creates another resource group called the **Managed Resource Group**.

**What is it?**
- Contains resources that Databricks creates to support the Databricks service
- All resources still live in the **customer subscription** (your subscription)
- **Not the same as the Control Plane** - not in Databricks subscription
- Databricks manages these resources on your behalf

### Resources in the Managed Resource Group:

#### 1. Storage Account
The workspace storage account discussed in the architecture diagram.

#### 2. Azure Managed Identity
Required for service authentication and authorization.

#### 3. Unity Catalog Access Connector
- Present if your workspace is enabled with Unity Catalog
- Workspaces created in the last year automatically have Unity Catalog enabled
- Don't worry if you don't see it - some workspaces aren't enabled with Unity Catalog

#### 4. Network Security Group
Provides network-level security.

#### 5. Virtual Network
Houses all your resources for network isolation.

### Key Takeaways:

1. **Managed Resource Group** is where:
   - Your storage account lives
   - All virtual machines required for clusters will be created
   - Classic compute cluster VMs are created

2. **Resource Location**:
   - Everything in the Managed Resource Group exists within the **customer subscription** (your subscription)
   - Example: "Azure Subscription 1"

3. **Classic vs. Serverless Difference**:
   - **Classic Compute**: VMs created in your subscription (Managed Resource Group)
   - **Serverless Compute**: VMs and resources created within the **Databricks subscription**

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DATABRICKS SUBSCRIPTION                              │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         CONTROL PLANE                                 │  │
│  │                                                                       │  │
│  │  ┌──────────────┐  ┌─────────────────┐  ┌────────────────────────┐   │  │
│  │  │  Web UI       │  │ Cluster Manager │  │   Unity Catalog        │   │  │
│  │  │  (Browser)    │  │ (Provisioning,  │  │   (Governance,         │   │  │
│  │  │              │  │  Scaling)        │  │    Access Control)     │   │  │
│  │  └──────────────┘  └─────────────────┘  └────────────────────────┘   │  │
│  │                                                                       │  │
│  │  ┌──────────────────────────────────────────────────────────────┐     │  │
│  │  │  Workspace Metadata Storage (Notebooks, Jobs, Spark Logs)    │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    SERVERLESS COMPUTE PLANE                            │  │
│  │         (Pre-allocated VMs, fast startup, managed by Databricks)      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘

                            │ Accesses data in │
                            ▼                  ▼

┌─────────────────────────────────────────────────────────────────────────────┐
│                        CUSTOMER SUBSCRIPTION                                │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    CLASSIC COMPUTE PLANE                               │  │
│  │         (VMs provisioned on-demand in your cloud account)             │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │               MANAGED RESOURCE GROUP                                   │  │
│  │                                                                       │  │
│  │  ┌────────────────┐  ┌──────────────┐  ┌─────────────────────────┐   │  │
│  │  │ Storage Account│  │  Managed      │  │  Network Security Group │   │  │
│  │  │ (Workspace     │  │  Identity     │  │  + Virtual Network      │   │  │
│  │  │  Cloud Storage)│  │              │  │                         │   │  │
│  │  └────────────────┘  └──────────────┘  └─────────────────────────┘   │  │
│  │                                                                       │  │
│  │  ┌──────────────────────────────────────────────────────────────┐     │  │
│  │  │  Unity Catalog Access Connector (if UC enabled)              │     │  │
│  │  └──────────────────────────────────────────────────────────────┘     │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │          EXTERNAL DATA (ADLS Gen2 / S3 / GCS)                         │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## CONCEPT GAP: Control Plane Security and Data Residency

Understanding where data resides is critical for compliance and security:

- **Data at rest**: Customer data always stays in the **customer subscription**. The control plane in the Databricks subscription stores only metadata (notebook revisions, job configurations, audit logs), never customer business data.
- **Data in transit**: Communication between the control plane and compute plane is encrypted via TLS 1.2+. The secure cluster connectivity (SCC) feature ensures that clusters initiate all connections outbound to the control plane, meaning no inbound ports need to be opened on the customer network.
- **Customer-Managed Keys (CMK)**: Enterprise customers can encrypt workspace notebooks and control plane metadata using their own encryption keys (Azure Key Vault or AWS KMS).
- **Private Link / PrivateLink**: For heightened security, Databricks supports Azure Private Link and AWS PrivateLink to ensure traffic between control plane and compute plane never traverses the public internet.
- **Compliance**: The architecture is designed to satisfy SOC 2 Type II, HIPAA, FedRAMP, and PCI DSS requirements depending on cloud and configuration.

---

## CONCEPT GAP: Unity Catalog Architecture

Unity Catalog is Databricks' unified governance layer. Key details for exam prep:

- **Three-level namespace**: `catalog.schema.table` (replaces the legacy `database.table` pattern from Hive Metastore).
- **Metastore**: The top-level container for Unity Catalog. One metastore can be shared across multiple workspaces in the same cloud region.
- **Data objects hierarchy**:

```
┌──────────────────────────────────────────┐
│              METASTORE                    │
│  ┌────────────────────────────────────┐  │
│  │           CATALOG                   │  │
│  │  ┌──────────────────────────────┐  │  │
│  │  │          SCHEMA               │  │  │
│  │  │  ┌────────┐  ┌────────────┐  │  │  │
│  │  │  │ TABLE  │  │   VIEW     │  │  │  │
│  │  │  └────────┘  └────────────┘  │  │  │
│  │  │  ┌────────┐  ┌────────────┐  │  │  │
│  │  │  │FUNCTION│  │   VOLUME   │  │  │  │
│  │  │  └────────┘  └────────────┘  │  │  │
│  │  └──────────────────────────────┘  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

- **Centralized access control**: Permissions are managed centrally using GRANT/REVOKE SQL syntax and apply across all workspaces attached to the metastore.
- **Data lineage**: Unity Catalog automatically captures column-level lineage for tables and views.
- **Delta Sharing**: Enables secure data sharing across organizations without data copying, built on open protocols.

---

## CONCEPT GAP: Classic vs. Serverless Compute Decision Matrix

| Factor | Classic Compute | Serverless Compute |
|--------|----------------|-------------------|
| **Startup time** | 5-10 minutes | Seconds |
| **Cost control** | Full VM-level control | Pay per DBU, Databricks manages infra |
| **Custom libraries** | Init scripts, custom Docker | Limited customization |
| **Network isolation** | Full VNet/VPC injection | Shared Databricks network |
| **Compliance needs** | Better for strict compliance | Improving, but less control |
| **Spot/preemptible VMs** | Supported | Not applicable |
| **Scala support** | Full support | Limited (preview) |
| **Best for** | Production ETL, strict security | Interactive queries, SQL warehouses |

---

## Conclusion

You should now have a good understanding of:
- The Databricks architecture
- Where resources live (Databricks subscription vs. your subscription)
- The distinction between Control Plane and Compute Plane
- Classic vs. Serverless compute models
- The role of the Managed Resource Group

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What are the two main components of the Databricks architecture?
**A:** The two main components are the **Control Plane** and the **Compute Plane**. The Control Plane runs in the Databricks subscription and handles backend services like the Web UI, Cluster Manager, Unity Catalog, and workspace metadata storage. The Compute Plane is where data processing occurs and can be either Classic (running in the customer's cloud subscription) or Serverless (running in the Databricks subscription).

### Q2: Where does customer data reside in the Databricks architecture?
**A:** Customer data always resides in the **customer's cloud subscription**, never in the Databricks subscription. The workspace cloud storage (ADLS Gen2 on Azure, S3 on AWS, GCS on GCP) is created in the customer's subscription. The control plane only stores metadata such as notebook revisions and job run details, not customer business data.

### Q3: What is the Managed Resource Group and what resources does it contain?
**A:** The Managed Resource Group is an additional resource group created automatically when a Databricks workspace is provisioned. It exists in the **customer's subscription** (not in the Databricks subscription) and contains resources managed by Databricks on the customer's behalf: a Storage Account (workspace storage), Azure Managed Identity, Unity Catalog Access Connector (if UC enabled), Network Security Group, and Virtual Network. Cluster VMs for classic compute are also created here.

### Q4: What is the difference between Classic Compute and Serverless Compute?
**A:** Classic Compute provisions VMs in the customer's cloud subscription, giving full control over configuration (runtime, node types, count, size). Serverless Compute uses pre-allocated VMs in the Databricks subscription, offering near-instant startup times and automatic scaling via AI models. Classic is better for strict compliance and custom configurations; Serverless is better for fast startup and reduced administrative overhead.

### Q5: What happens to workspace cloud storage when a workspace is deleted?
**A:** The workspace cloud storage is **tied to the workspace** and is **deleted when the workspace is deleted**. This is critical to understand: any data stored in the default workspace storage will be permanently lost. For persistent data, organizations should use external storage (like a separate ADLS Gen2 account or S3 bucket) that is independent of the workspace lifecycle.

### Q6: How does Databricks ensure security between the Control Plane and Compute Plane?
**A:** Databricks uses multiple security layers: all communication is encrypted with TLS 1.2+, Secure Cluster Connectivity (SCC) ensures clusters initiate outbound-only connections so no inbound ports need to be opened, Private Link support keeps traffic off the public internet, and Customer-Managed Keys (CMK) allow customers to encrypt control plane metadata with their own encryption keys. Network Security Groups and VNet injection provide additional network isolation for classic compute.

### Q7: What is Unity Catalog and what role does it play in the architecture?
**A:** Unity Catalog is the unified governance solution in Databricks that provides centralized data governance, access management, and permissions management across all data assets. It uses a three-level namespace (catalog.schema.table), supports centralized access control with GRANT/REVOKE SQL, captures automatic column-level data lineage, and enables secure cross-organization data sharing via Delta Sharing. One metastore can be shared across multiple workspaces in the same region.

### Q8: In an Azure deployment, how can you identify which resources belong to Databricks vs. your own workloads?
**A:** In Azure, Databricks creates a separate **Managed Resource Group** distinct from the resource group where you deployed the Databricks service. The Managed Resource Group contains Databricks-managed resources (storage account, managed identity, NSG, VNet, and UC access connector), while your own resource group contains the Databricks workspace resource itself. Both resource groups exist within the customer's Azure subscription, but the Managed Resource Group is administered by Databricks.

---

*End of lesson*