terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.42.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = lower(format("%s-%s-tfstate", var.project_name, var.environment))
}

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
  acl    = "private"

  tags = merge(var.tags, {
    Name        = local.bucket_name
    Environment = var.environment
  })
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state."
  value       = aws_s3_bucket.state.bucket
}

variable "aws_region" {
  description = "AWS region where the state bucket and lock table will be created."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Short project name used to create unique resource names."
  type        = string
  default     = "marketing-webapp-project"
}

variable "environment" {
  description = "Deployment environment used in resource names."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to the state bucket and lock table."
  type        = map(string)
  default = {
    Terraform = "true"
  }
}
