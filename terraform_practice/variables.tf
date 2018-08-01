/* 

Terraform file to define which variables are used

This is NOT where you set the variables. Instead, they should be 
set at the command line, with .tfvars files, or with environment variables

 */

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-west-2"
}

variable "keypair_name" {
  description = "The name of your pre-made key-pair in Amazon (e.g. david-IAM-keypair )" 
} 

variable "fellow_name" {
  description = "The name that will be tagged on your resources."
}

# amazon machine images
variable "amis" {
  type = "map"
  default = {
    "us-east-1" = "ami-0e32dc18"
    "us-west-2" = "ami-833e60fb" # from Bastian: ubuntu machine image with username ubuntu
  }
}

variable "cluster_name" {
  description = "The name for your instances in your cluster" 
  default   = "cluster"
}

