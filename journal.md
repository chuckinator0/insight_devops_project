## Journal

This journal is my way of processing what I'm learning and archiving some steps that I might need in the future.

# Getting data into S3

I have a dropbox link to the data that will be used in the pipeline. Downloading the large file failed multiple times, and I got frustrated, so I figured out how to download the file into an EC2 instance and transfer the file to S3 storage.

First, ssh into the ec2 instance. Download the file directly to the EC2 instance using the download link:
``wget <download url>``
Install awscli (amazon's command line interface tool):
``sudo apt install awscli``
Then use the command 
``AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=xxxx aws s3 cp <file> s3://my-bucket/``
The ec2 instance doesn't have access to my local environment variables (I don't think...I would like clarification on how to pass these to the remote instance), so I had to put those in. The key commands here were:
``aws s3 cp <file> <bucket>``

# Setting up Chef server

I am following [this guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-chef-12-configuration-management-system-on-ubuntu-14-04-servers#prerequisites-and-goals) for setting up a chef server and a chef workstation. I realize I've been using my local machine as the chef workstation, but I want to use a remote ec2 instance to be the chef workstation. So I'll have a chef server and a chef workstation in AWS.

# Terraform Help

+ [VPC module documentation](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.30.0)
+ [AWS security group module documentation](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/1.9.0)
+[AWS security group submodules](https://github.com/terraform-aws-modules/terraform-aws-security-group/tree/master/modules)
+ The machine image I am using is `ami-833e60fb`, which is an Ubuntu 16.04 image with username `ubuntu`.