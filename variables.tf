variable "region" {
  type        = string
  description = "The AWS region where resources will be created."
  default     = "us-east-1"
}

variable "profile" {
  type        = string
  description = "Define the profile"
  default     = "dev"
}
variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "tags" {
  type        = map(string)
  description = "Key-value pairs for tagging resources."
  default = {
    Project     = "MyProject"
    Environment = "Dev"
  }
}

variable "vpc_tag" {
  type    = string
  default = "VPC Demo"
}

variable "availabilityzones_names" {
  type        = list(string)
  description = "list the availability aones in which the resources should be created"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnets_cidrs" {
  type        = list(string)
  description = "list the subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}


variable "private_subnets_cidrs" {
  type        = list(string)
  description = "list the subnet CIDRs"
  default     = ["10.0.3.0/24", "10.0.5.0/24"]
}


variable "public_subnet_tag" {
  type    = string
  default = "Public Subnet"
}


variable "internet_gateway" {
  type    = string
  default = "Internet Gateway"
}

variable "public_route_table" {
  type    = string
  default = "Public route table"
}


variable "private_subnet_tag" {
  type    = string
  default = "Private Subnet"
}
variable "destination_cidr_block" {
  type    = string
  default = "0.0.0.0/0"
}

variable "private_route_table_tag" {
  type    = string
  default = "AWS Private route Table"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "aws_security_group_tag" {
  type    = string
  default = "application_security_group"
}

variable "custom_ami" {
  type    = string
  default = "value"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "web_app_instance_tag" {
  type    = string
  default = "web_app_instance"
}

variable "application_security_group" {
  type    = string
  default = "application-security-group"
}
variable "aws_security_group_description" {
  type    = string
  default = "Security group decription"
}

variable "volume_size" {
  type    = number
  default = 25
}

variable "volume_type" {
  type    = string
  default = "gp2"
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "db_password" {
  type    = string
  default = "value"
}
variable "PACKER_DB_USERNAME" {
  type    = string
  default = "username"
}

variable "PACKER_DB_PASSWORD" {
  type    = string
  default = "passwrod"
}

variable "aws_access_key" {
  type    = string
  default = "value"
}

variable "aws_secret_key" {
  type    = string
  default = "value"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "db_username" {
  type    = string
  default = "root"
}

variable "db_name" {
  type    = string
  default = "csye6225"
}

variable "app_user" {
  type    = string
  default = "app_user"
}

variable "app_grp" {
  type    = string
  default = "value"
}
variable "zone_id" {
  type    = string
  default = "default"
}
variable "domain_name" {
  type    = string
  default = "praveenkumarvijayakumar.me"
}

variable "db_secret_name" {
  type    = string
  default = "my-db-name"
}

variable "demo_certificate_arn" {
  type    = string
  default = "value"
}
variable "dev_zone_id" {
  type    = string
  default = "value"
}
variable "dev_domain_name" {
  type    = string
  default = "dev.praveenkumarvijayakumar.me"
}
variable "current_zone_id" {
  type    = string
  default = "value"
}
