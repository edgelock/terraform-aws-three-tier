# --- Terraform and AWS Provider Configuration ---
# This block configures the required version for the AWS provider and sets the
# default region for all resources created by this project.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Add the following two providers
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}