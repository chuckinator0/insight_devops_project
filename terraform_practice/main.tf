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
  public_subnets   = ["10.0.0.0/27"] # IP's 10.0.0.0 through 10.0.0.31, 32 total
  private_subnets   = ["10.0.0.32/27"] # IP's 10.0.0.32 through 10.0.0.63, 32 total

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

# Provision kafka master
resource "aws_instance" "kafka-master" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "m4.large"
  key_name = "${var.keypair_name}"

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}","${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true
  count                       = 1

  tags {
    Name        = "kafka-master"
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
    Cluster     = "kafka"
    ClusterRole = "master"
  }
}

# Provision kafka workers
resource "aws_instance" "kafka-workers" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "m4.large"
  key_name = "${var.keypair_name}"
  count = 2

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}","${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name        = "kafka-worker-${count.index}"
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
    Cluster     = "kafka"
    ClusterRole = "worker"
  }
}

# Provision spark-streaming master
resource "aws_instance" "spark-master" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "m4.large"
  key_name = "${var.keypair_name}"

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}","${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true
  count                       = 1

  tags {
    Name        = "spark-master"
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
    Cluster     = "spark"
    ClusterRole = "master"
  }
}

# Initial configuration bash script for chef server
data "template_file" "spark_template" {
  template = "${file("spark_template.tpl")}"
}

# Provision spark-streaming workers
resource "aws_instance" "spark-workers" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "m4.large"
  key_name = "${var.keypair_name}"
  count = 3
  user_data = "${data.template_file.spark_template.rendered}"

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}","${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name        = "spark-worker-${count.index}"
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
    Cluster     = "spark"
    ClusterRole = "worker"
  }
}

# Provision cassandra database
resource "aws_instance" "cassandra" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "m4.large"
  key_name = "${var.keypair_name}"

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}","${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true
  count                       = 1

  tags {
    Name        = "cassandra"
    Owner       = "${var.fellow_name}"
    Environment = "dev"
    Terraform   = "true"
  }
}

# Initial configuration bash script for chef server
data "template_file" "chef_server_template" {
  template = "${file("chef_server_template.tpl")}"
}

# Provision chef server
resource "aws_instance" "chef-test" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.medium"
  key_name = "${var.keypair_name}"
  count = 1
  # Using the user_data feature will destroy currently running chef server, so it's commented out for now
  #user_data = "${data.template_file.chef_server_template.rendered}"

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}", "${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name = "chef-server"
  }
}

# Initial configuration bash script for chef workstation
data "template_file" "chef_workstation_template" {
  template = "${file("chef_workstation_template.tpl")}"
}

# Provision chef workstation
resource "aws_instance" "chef-workstation" {
  ami = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.keypair_name}"
  count = 1
  # I don't yet know how to get ssh authentication to work during the secure copy scp part of the script
  #user_data = "${data.template_file.chef_workstation_template.rendered}"
  depends_on = ["aws_instance.chef-test"]

  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}", "${module.open-ssh-sg.this_security_group_id}"]
  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags {
    Name = "chef-workstation"
  }
}

# Configuration for an Elastic IP to add to nodes
resource "aws_eip" "elastic_ips_for_instances" {
  vpc       = true
  instance  = "${element(concat(aws_instance.kafka-master.*.id, aws_instance.kafka-workers.*.id, aws_instance.spark-master.*.id, aws_instance.spark-workers.*.id), count.index)}"
  count     = "${aws_instance.kafka-master.count + aws_instance.kafka-workers.count + aws_instance.spark-master.count + aws_instance.spark-workers.count}"
}


