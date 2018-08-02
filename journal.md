## Journal

This journal is my way of processing what I'm learning and archiving some steps that I might need in the future.

# Getting data into S3

I have a dropbox link to the data that will be used in the pipeline. Downloading the large file failed multiple times, and I got frustrated, so I figured out how to download the file into an EC2 instance and transfer the file to S3 storage.

First, ssh into the ec2 instance. Download the file directly to the EC2 instance using the download link:

```wget <download url>```

Install awscli (amazon's command line interface tool):

```sudo apt install awscli```

Then use the command 

```AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=xxxx aws s3 cp <file> s3://my-bucket/```

The ec2 instance doesn't have access to my local environment variables (I don't think...I would like clarification on how to pass these to the remote instance), so I had to put those in. The key commands here were:

```aws s3 cp <file> <bucket>```

# Setting up Chef server

I am following [this guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-chef-12-configuration-management-system-on-ubuntu-14-04-servers#prerequisites-and-goals) for setting up a chef server and a chef workstation. I realize I've been using my local machine as the chef workstation, but I want to use a remote ec2 instance to be the chef workstation. So I'll have a chef server and a chef workstation in AWS.
+ Should I make a bash script for doing these steps to configure a chef server so that it is easy to set up after a `terraform destroy`?
+ Some names:
  + username, first name, last name: admin
  + admin.pem, insight-validator.pem
  + email: my mfa email
  + organization short name: insight
  + organization long name: "Chuck Insight Project"

  There was a slight wrinkle during the workstation setup. when using the command `knife.rb` file and using the `knife client list` command, I had to specify the chef server IP address `ip-10-0-0-11.us-west-2.compute.internal` rather than just `10.0.0.11`.

To bootstrap the kafka-test machine as a chef client, I had to use the command

```knife bootstrap 10.0.0.13 -N kafka-test -x ubuntu --sudo```

The 10.0.0.13 is the private IP of my kafka-test instance. The `-N` option specifies that "kafka-test" is going to be the name of the new chef client. The `-x` option is used to specify the username to ssh to. The `--sudo` option enables sudo privileges so the client can get bootstrapped (which means it's now under the control of the chef server).

I'm now on to [the next part](https://www.digitalocean.com/community/tutorials/how-to-create-simple-chef-cookbooks-to-manage-infrastructure-on-ubuntu) of the guide to create a chef cookbook to configure my kafka-test node.

It looks like `knife cookbook create <cookbook_name>` doesn't work anymore. We have to use `chef generate cookbook <cookbook_name>` instead. It also looks like the command needs to be done from `~/chef-repo/cookbooks` rather than `~/chef-repo` like it says in the guide.

I'm currently stuck at the point where I am running the command `sudo chef-client` from within the `kafka-test` node. It turns out that it takes a lot to configre a kafka cluster with chef. I found [this github repo](https://github.com/mthssdrbrg/kafka-cookbook?files=1) that has a pretty clear layout for the recipes, attributes, etc for configuring kafka. It also has an explanation for using custom logic to do a rolling restart of kafka servers so they don't all fail at the same time. This could definitely be helpful for my project.

# Terraform Help

+ [VPC module documentation](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.30.0)
+ [AWS security group module documentation](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/1.9.0)
+ [AWS security group submodules](https://github.com/terraform-aws-modules/terraform-aws-security-group/tree/master/modules)
+ The machine image I am using is `ami-833e60fb`, which is an Ubuntu 16.04 image with username `ubuntu`.