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

## Conclusion

You should now have a good understanding of:
- The Databricks architecture
- Where resources live (Databricks subscription vs. your subscription)
- The distinction between Control Plane and Compute Plane
- Classic vs. Serverless compute models
- The role of the Managed Resource Group

---

*End of lesson*