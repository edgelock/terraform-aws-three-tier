# Deploying a 3-Tier Architecture on AWS with Terraform

This project provides the Terraform code to deploy a scalable and secure 3-tier web application architecture on Amazon Web Services (AWS). It includes a public-facing web tier, a private application tier, and an isolated database tier.

Terraform is used to manage our infrastructure as code, which makes the setup process automated, repeatable, and easy to understand.

---

## Architecture Overview

![Architecture Diagram 1](./1.png)

This project will create the following resources in your AWS account:

### Networking
- A **VPC** to provide an isolated network environment.  
- **Public subnets** for resources that need internet access, like our web servers and load balancer.  
- **Private subnets** to securely host our backend database, shielding it from direct internet traffic.  
- An **Internet Gateway** and **Route Tables** to manage traffic flow to and from the internet.  

### Compute (Web Tier)
- An **Application Load Balancer (ALB)** to distribute incoming web traffic across multiple servers.  
- Two **EC2 instances** (virtual servers) that act as our web servers, automatically configured with a basic Apache web page.  

### Database (Data Tier)
- An **RDS MySQL instance** in the private subnets for secure, managed data storage.  

### Security
- **Security Groups** that act as virtual firewalls to control traffic between the tiers (e.g., allowing the web tier to talk to the database tier but blocking public access to the database).  

![Architecture Diagram 2](./2.png)

---

## Prerequisites

Before you begin, make sure you have the following:

- An **AWS account**.  
- The **AWS CLI** installed and configured with your credentials (access key and secret key). You can configure it by running:  

```bash
aws configure
```

- **Terraform** installed on your local machine.  

---

## Project Structure 📁

The code has been organized into logical files to make it easy to manage:

- `main.tf`: Contains the core resource definitions for our infrastructure (VPC, instances, load balancer, etc.).  
- `providers.tf`: Configures the AWS provider that Terraform uses to interact with your account.  
- `variables.tf`: Defines input variables, making it simple to customize settings like network ranges.  
- `data.sh`: A simple shell script used to set up the Apache web server on our EC2 instances upon launch.  

---

## How to Deploy 🚀

Follow these steps to deploy the architecture:

### Step 1: Clone the Repository
```bash
git clone <your-repository-url>
cd <repository-directory>
```

### Step 2: Initialize Terraform
```bash
terraform init
```
This downloads the necessary AWS provider plugin that allows Terraform to communicate with AWS.

### Step 3: Review the Execution Plan
```bash
terraform plan
```
This command shows you all the resources that Terraform will create, modify, or destroy. It’s a great way to double-check everything before making any changes to your cloud environment.

### Step 4: Apply the Configuration
```bash
terraform apply
```
Terraform will ask for your confirmation before proceeding. Type `yes` to approve.  

This process will take a few minutes as AWS provisions all the resources.

---

## Verify Your Deployment ✅

Once the `apply` command is complete, you should see an output similar to this:

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

load_balancer_dns = "external-application-lb-1669197604.us-east-1.elb.amazonaws.com"
```

### Testing the Load Balancer
1. Copy the `load_balancer_dns` value from the output.  
2. Paste it into your web browser.  
3. You should see a **"Hello World"** message served by one of your EC2 instances.  
4. Refresh the page multiple times — the **Application Load Balancer** will alternate requests between the two EC2 instances, allowing you to observe load balancing in action.  

---

## Cleaning Up 🧹

When you're finished, you can destroy all the created resources to avoid incurring further costs. Run the following command and type `yes` to confirm:

```bash
terraform destroy
```
