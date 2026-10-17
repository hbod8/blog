variable "aws_region" {
  description = "AWS region for the S3 bucket and Route 53 resources"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Domain name for the static site (e.g. example.com). A Route 53 zone will be created for this domain."
  type        = string
}
