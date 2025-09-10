# --- Variable Definitions ---
# These variables define the network address ranges (CIDR blocks) for our
# VPC and subnets, making them easy to change in one place.

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for the private database subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}