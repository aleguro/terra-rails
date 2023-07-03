variable environment  {
  description = "value"
  default = "development"
}

variable availability_zones  { 
  default = ["us-west-2a", "us-west-2b"]
}

variable vpc_cidr { 
  default = "10.0.0.0/16"
}

variable public_subnets_cidr { 
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable ami {
 description = "value"  
 default =  ""
}

variable certificate_arn {
  description = "value"  
  default = ""
}

variable ecr_repository_url {
   description = "value"  
   default = ""
}

variable aws_access_key {
  description = "value"  
  default =  ""
}

variable "aws_access_secret" {
  description = "value"  
  default = ""
}

variable "rails_secret" {
  description = "value" 
  default = ""
}

variable "rails_env" {
  description = "value"
  default = "development" 
}

variable "key_name" {
  description = "value" 
  default = ""
}

variable "smtp_user" {
  default = ""
}

variable "smtp_password" {
  default = ""
}

variable "instance_type" {
   default = "t2.medium"
}

variable "admin_rails_secret" {
  default =  "" 
}

variable "admin_secret_key_base"  { 
  default = "" 
}

variable "zone_id" { 
  default = ""
}

variable "environment_prefix" {
  default = "dev" 
}

variable "web_hook" {
  default = ""
}

variable "github_token" {
  default = ""
}