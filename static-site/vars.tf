variable "aws_region" {}

variable "aws_secret_key" {}

variable "aws_access_key" {}

variable "domain_name" {
  description = "The full domain name e.g. example.com"
}

variable "owner" {
  description = "used only as a tag for managing multiple static sites and budgeting"
  default = "unknown"
}

variable "dns_ttl" {
  default = 300
}

variable "cloudfront_min_ttl" {
  default = 0
}

variable "cloudfront_default_ttl" {
  default = 3600
}

variable "cloudfront_max_ttl" {
  default = 86400
}

variable "cloudfront_price_class" {
  default = "PriceClass_All"
}

variable "include_www" {
  default = 1
}