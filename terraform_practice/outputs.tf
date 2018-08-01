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


output "instance_ips" {
  value = [
  # 'name' + ' ' + 'ip address'
  "${aws_instance.kafka-test.tags.Name} ${aws_instance.kafka-test.public_ip}",
  "${aws_instance.chef-server.tags.Name} ${aws_instance.chef-server.public_ip}",
  "${aws_instance.chef-workstation.tags.Name} ${aws_instance.chef-workstation.public_ip}"
  ]
}