# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       = "${module.vpc.vpc_id}"
}

# Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = ["${module.vpc.private_subnets}"]
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = ["${module.vpc.public_subnets}"]
}

output "master_ips" {
  value = [
  "kafka-master public ip: ${aws_instance.kafka-master.public_ip}",
  "kafka-master private ip: ${aws_instance.kafka-master.private_ip}",
  "spark-master public ip: ${aws_instance.spark-master.public_ip}",
  "spark-master private ip: ${aws_instance.spark-master.private_ip}"
  ]
}

output "kafka_workers_ips" {
  value = [
  "kafka-worker public ips: ${join(",", aws_instance.kafka-workers.*.public_ip)}",
  "kafka-worker private ips: ${join(",", aws_instance.kafka-workers.*.private_ip)}"
  ]
}

output "spark_workers_ips" {
  value = [
  "spark-workers public ips: ${join(",", aws_instance.spark-workers.*.public_ip)}",
  "spark-workers private ips: ${join(",", aws_instance.spark-workers.*.private_ip)}"
  ]
}

# Output public IP addresses
output "other_ips" {
  value = [ 
  "chef server public: ${aws_instance.chef-test.public_ip}",
  "chef server private: ${aws_instance.chef-test.private_ip}",
  "chef workstation public: ${aws_instance.chef-workstation.public_ip}",
  "chef workstation private: ${aws_instance.chef-workstation.private_ip}",
  "cassandra public: ${aws_instance.cassandra.public_ip}",
  "cassandra private: ${aws_instance.cassandra.private_ip}"
  ]
}