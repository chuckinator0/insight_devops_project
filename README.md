# Larrieu_IaC_CM_project
Infrastructure as Code and Configuration Management Project

## Introduction

Over time, the world of software development has moved from code on one local machine to an app hosted on one big server, and now to many services interacting on many servers in complex cloud architectures. To manage this progression, tools like Terraform have been developed to bring up the servers and connect them to each other based on the needs of the application, and tools like Chef have been developed to make sure that those servers get the right software installed with the right configuration automatically. Before tools like these, system administrators had to do all of this manually, which was slow, error prone, and impossible to scale to the distributed systems that exist in production today.

This guide will help you build a Virtual Private Cloud in Amazon Web Services with Terraform and configure a Kafka cluster using Chef.

## Using Terraform to Initialize a Virtual Private Cloud in AWS

The code in `./terraform_practice/` creates a VPC with subnets, internet gateway, NAT gateway, security groups, elastic IP's, and several EC2 instances. See resource (1) for more information about the anatomy of a VPC. Terraform spins up EC2 instances that would later be configured to be kafka and spark streaming clusters and S3 bucket.

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

Once you get the nodes from your kafka cluster bootstrapped, you can now use Chef to configure those nodes. Now is the time to talk about how Chef works. The idea is that the chef workstation holds "cookbooks" that contain "recipes", which are Ruby scripts that go through the logic of configuring a resource (for example, automatically downloading, installing, and changing the settings of Kafka). One major challenge I faced was building on existing cookbooks that have been used in production (kafka-cluster and zookeeper-cluster cookbooks developed by Bloomberg).  For more on that journey, see `journal.md`. For the basic anatomy of a cookbook, see my cookbook `./chef_practice/insight-kafka-cluster`. This is technically a "wrapper cookbook", which is a cookbook that customizes cookbooks already available. There are many community cookbooks available at the Chef Supermarket, listed at resource (7).

The insight-kafka-cluster cookbook has `recipes` and `attributes`. Recipes are the basic building blocks. Recipes are scripts written in Ruby that contain the logic for configuring a system. For example, the download URL for a specific piece of software may depend on the operating system of the current node. In Ruby, it would be possible to write `if else` statements to address this. Attributes are used to set various values for the variables that are used, like version number, the number of partitions that Kafka will use, the ports that zookeeper will use to communicate across the cluster, etc. Cookbooks can build on each other and be reused in many contexts, which makes them versatile, but can also lead to dependency sprawl. Chef handles this with a special file called a Berksfile.

Note that `./chef_practice/insight-kafka-cluster/metadata.rb` declares dependencies on the two underlying cookbooks `zookeeper-cluster` and `kafka-cluster`. Also note that in `./chef_practice/insight-kafka-cluster/recipes/default.rb` contains these lines:

```ruby
...
include_recipe 'zookeeper-cluster::default'
...
include_recipe 'kafka-cluster::default'
```

So, the dependencies are in the recipe and the metadata, and the Berksfile is used to look at those dependencies in the metadata and recursively install all the contingent cookbooks all the way down. If you secure copy `scp` the three cookbooks (insight-kafka-cluster, kafka-cluster, and zookeeper-cluster) into the chef workstation at `~/chef-repo/cookbooks`, change directory into the `insight-kafka-cluster` cookbook, and run the command `berks install` and `berks upload`, it should recursively install all contingent cookbooks and upload them to the chef server.

Now that the cookbooks are uploaded, it is important for zookeeper to get a list of the IP addresses of all the instances in the cluster. The recipe `recipes/default.rb` mentions a varable called `bag`. Chef uses "data bags" to store sensitive information on the chef server. From the chef workstation, the command `knife data bag create <name of bag> <name of item>` will create a data bag. I did `knife data bag create zoo_bag zookeeper` and made the json for my kafka node host names:

```json
{
  "id": "zookeeper",
  "_default": [
    "10.0.0.5",
    "10.0.0.14",
    "10.0.0.25"
  ] 
} 
```

In Chef, you can set different chef environments on your chef server like "development", "production," or in this case, "\_default". This is the environment that is set by default by the chef server.

The cookbooks are in place, and the zoo_bag is populated with the IP's. All that is left to do is apply the command `sudo chef-client` on each node in the kafka cluster. Then, zookeeper and kafka are configured for master-worker communication. The `attributes` directory of each cookbook is a place where you can set the values for the various settings that the cookbook configures. Setting these attributes in the wrapper cookbook, insight-kafka-cluster, will override the cookbooks underneath it.


## Tao Hong's Smart Money Tracker

I included previous Insight Data Engineering Fellow [Tao Hong's data pipeline](https://github.com/hongtao510/SmartMoneyTracker) to toy around with. It's possible to simulate his financial data from his description of the schema in his scripts. There is a missing config file that takes the following form (taken from his project):

```python
class Config:
	# bootstrap_servers_address = ['52.37.84.255:9092', '52.11.105.41:9092', '54.70.27.179:9092']
	bootstrap_servers_address = 'localhost:9092'
	bootstrap_servers_ipaddress = '52.41.88.112:9092'
	kafka_topic = 'th-topic'	# kafka topic
	ss_interval = 10 			# Sparkstreaming interval
	cass_cluster_IP = ['35.155.197.36', '54.186.193.198', '34.212.250.239']
	
	# Use environment variables
	S3_KEY = "XXXXX"
	S3_SECRET = "XXXXX"
	S3_REGION = "us-west-2"
	
	# Updated S3 bucket name is chuck-financial-data
	S3_BUCKET = "chuck-financial-data"
	
	num_record_streamed = 2000000000000000000  			# number of records streamed from s3
	intraday_fname = "intraday_subset_sort_quote.csv"  	# streaming filename on s3
	eod_fname = "eod_summary_withoutzeros.csv"  		# endofday filename on s3, benchmark
```

## Background Resources
1. [AWS VPC infrastructure overview](https://start.jcolemorrison.com/aws-vpc-core-concepts-analogy-guide/#the-vpc)
2. [Comprehensive guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca)
3. [Terraform example from Insight](https://github.com/InsightDataScience/aws-ops-insight/tree/master/terraform)
4. [Terraform modules for AWS](https://github.com/terraform-aws-modules)
5. [Chef Server + Workstation tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-chef-12-configuration-management-system-on-ubuntu-14-04-servers#prerequisites-and-goals)
6. [ssh tutorial](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys)
7. [Chef Supermarket of Community Cookbooks](https://supermarket.chef.io)
