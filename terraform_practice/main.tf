/* 

Main configuration file for Terraform

Terraform configuration files are written in the HashiCorp Congiuration Language (HCL).
For more information on HCL syntax, visit: 

https://www.terraform.io/docs/configuration/syntax.html

 */

# Specify that we're using AWS, using the aws_region variable
provider "aws" {
  region   = "${var.aws_region}"
  version  = "~> 1.14"
}

# Read the availability zones for the current region
data "aws_availability_zones" "all" {}

/* 

Configuration to make a VPC

For more details and options on the AWS vpc module, visit:
https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.30.0

 */

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.30.0"

  name = "${var.fellow_name}-vpc"

  cidr             = "10.0.0.0/26"
  azs              = ["${data.aws_availability_zones.all.names}"]
  public_subnets   = ["10.0.0.0/28"] # IP's 10.0.0.0 through 10.0.0.15, 16 total
  private_subnets   = ["10.0.0.16/28"] # IP's 10.0.0.16 through 10.0.0.31, 16 total

  enable_dns_support   = true
  enable_dns_hostnames = true

# NAT gateway to connect from private subnet to public
  enable_nat_gateway = true 
  single_nat_gateway = true

  enable_s3_endpoint = true

  tags = {
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
  }
} 

# Security Group sub-module for the SSH protocol
module "open-ssh-sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "1.20.0"

  vpc_id      = "${module.vpc.vpc_id}"
  name        = "ssh-open-sg"
  description = "Security group for SSH, open from/to all IPs"
  
  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
  }
}

# Provision S3 bucket
resource "aws_s3_bucket" "chuck-financial-data" {
  bucket = "chuck-financial-data"
  acl    = "private"

  tags {
    Name        = "Financial data"
    Environment = "Dev"
  }
}

# Provision kafka server
resource "aws_instance" "kafka-test" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.keypair_name}"
  count = 1

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}","${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name = "kafka-test"
  }
}

# Provision chef server
resource "aws_instance" "chef-test" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.medium"
  key_name = "${var.keypair_name}"
  count = 1

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}", "${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name = "chef-test"
  }
}

# Provision chef workstation
resource "aws_instance" "chef-workstation" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.keypair_name}"
  count = 1

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}", "${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name = "chef-workstation"
  }
}




