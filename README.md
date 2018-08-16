# Larrieu_IaC_CM_project
Infrastructure as Code and Configuration Management Project

## Introduction

Over time, the world of software development has moved from code on one local machine to an app hosted on one big server, and now to many services interacting on many servers in complex cloud architectures. To manage this progression, tools like Terraform have been developed to bring up the servers and connect them to each other based on the needs of the application, and tools like Chef have been developed to make sure that those servers get the right software installed with the right configuration automatically. Before tools like these, system administrators had to do all of this manually, which was slow, error prone, and impossible to scale to the distributed systems that exist in production today.

This guide will help you build a Virtual Private Cloud in Amazon Web Services with Terraform and configure a Kafka cluster using Chef.

## Using Terraform to Initialize a Virtual Private Cloud in AWS

The code in `/terraform_practice/` creates a VPC with subnets, internet gateway, NAT gateway, security groups, elastic IP's, and several EC2 instances. See resource (1) for more information about the anatomy of a VPC. Terraform spins up EC2 instances that would later be configured to be kafka and spark streaming clusters and S3 bucket.

The `variables.tf` file initiates the variables that will be used. Some examples of variables would be the AWS region (us-west-2 in this case), the keypair required to authenticate into the VPC, and AMI ID's. An AMI Amazon Machine Image) is a pre-baked image of a machine. The AMI used in this project initializes an EC2 instance with the Ubuntu 16.04 operating system. This file merely initializes the vaiables and possibly give some default values, but the values of the variables themselves are declared in `terraform.tfvars`. As a security measure, you should declare your AWS credentials as environment variables in your bash profile of your local machine, and never ever put those credentials on the internet or hard coded in files.

The `outputs.tf` file indicates what variables will be printed upon running the Terraform code.

The `main.tf` contains the code that will provision all the resources (the VPC, the EC2 instances, S3, etc.). As a best practice, it is suggested to separate out each piece of the architecture into different directories and call them into this `main.tf` using modules. See [this github repo](https://github.com/moosahmed/Stateful_Symphony/tree/master/terraform) for an example of how write Terraform modularly.

Resource (4) gives a treasure trove of official Terraform modules for working with AWS. I sourced these modules to set up my VPC and security groups, although it is good to define custom security groups yourself to learn how they work.

You'll also notice template files which are sourced in `main.tf`. Terraform has a great feature called `user_data` that can run bash scripts automatically when spinning up a machine. This can be used to automate many lighter configuration tasks. See `spark_template.tpl` for a good example of a script that automatically installs spark on a machine.

## Configuring Chef Server

The bash scripts `chef_server_template.tpl` and `chef_workstation_template.tpl` are my attempts to automate the process of following the chef setup guide I've listed as background resource (5). There are some values that are specific to your own setup, but you can use these scripts and the tutorial in resource (5) as a guide. The chef server is set up first, and then the chef workstation. The step where credentials are securely copied with the `scp` command from the server to the workstation may not work as advertised without forwarding your ssh credentials with ssh-agent. See resource (6) for more information on ssh fundamentals, including ssh-agent.

To bootstrap nodes to machine as a chef client, I had to make sure I was in the `/chef-repo` on the chef workstation and use the command

```knife bootstrap <insert node IP address> -N <insert node name> -x <username of node> --sudo```

The `-N` option declares the name of the new chef client. The `-x` option is used to specify the username to ssh to, which in this case is "ubuntu". The `--sudo` option enables sudo privileges so the client can get bootstrapped (which means it's now under the control of the chef server). This seems to be a manual process for each node, but it would be nice to leverage Terraform to send this command through ssh to the chef workstation whenever a node comes online.

## Using Chef to configure Zookeeper+Kafka

Once you get the nodes from your kafka cluster bootstrapped, you can now use Chef to configure those nodes. Now is the time to talk about how Chef works. The idea is that the chef workstation holds "cookbooks" that contain "recipes", which are Ruby scripts that go through the logic of configuring a resource (for example, automatically downloading, installing, and changing the settings of Kafka)

## Background Resources
1. [AWS VPC infrastructure overview](https://start.jcolemorrison.com/aws-vpc-core-concepts-analogy-guide/#the-vpc)
2. [Comprehensive guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca)
3. [Terraform example from Insight](https://github.com/InsightDataScience/aws-ops-insight/tree/master/terraform)
4. [Terraform modules for AWS](https://github.com/terraform-aws-modules)
5. [Chef Server + Workstation tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-chef-12-configuration-management-system-on-ubuntu-14-04-servers#prerequisites-and-goals)
6. [ssh tutorial](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys)
