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

I wrote a bash script to configure the chef server:
```
# Download chef 12 for ubuntu 16.04
wget https://packages.chef.io/files/stable/chef-server/12.17.33/ubuntu/16.04/chef-server-core_12.17.33-1_amd64.deb
# Install
sudo dpkg -i chef-server-core_*.deb
# Reconfigure for local infrastructure
sudo chef-server-ctl reconfigure
# Create admin user and put key in admin.pem
chef-server-ctl user-create admin admin admin charleslarrieu@mfala.org examplepass -f admin.pem
# Create an organization and make a validator key
sudo chef-server-ctl org-create insight "Chuck Insight Project" --association_user admin -f insight-validator.pem
```
i wrote a bash script to configure chef workstation (after ssh'ing into the workstation):
```
# Install git, clone chef-repo, and start version control
sudo apt-get update
sudo apt-get install git
git clone https://github.com/chef/chef-repo.git
git config --global user.name "chuck"
git config --global user.email "charleslarrieu@mfala.org"
# Add .chef to gitignore and commit
echo ".chef" >> ~/chef-repo/.gitignore
cd ~/chef-repo
git add .
git commit -m "Excluding the ./.chef directory from version control"
# Download and install chef dev kit for ubutu 16.04
wget https://packages.chef.io/files/stable/chefdk/3.1.0/ubuntu/16.04/chefdk_3.1.0-1_amd64.deb
sudo dpkg -i chefdk_*.deb
# Use chef's version of ruby
echo 'eval "$(chef shell-init bash)"' >> ~/.bash_profile
source ~/.bash_profile
# Make a hidden directory to store keys from chef server
mkdir ~/chef-repo/.chef
# Copy keys using secure ssh copy
scp ubuntu@10.0.0.20:~/admin.pem /home/ubuntu/chef-repo/.chef/
scp ubuntu@10.0.0.20:~/insight-validator.pem /home/ubuntu/chef-repo/.chef/
# Edit knife.rb file in ~/chef-repo/.chef directory
cat<<-EOF > ~/chef-repo/.chef/knife.rb
#!/bin/bash
current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "admin"
client_key               "#{current_dir}/admin.pem"
validation_client_name   "insight-validator"
validation_key           "#{current_dir}/insight-validator.pem"
chef_server_url          "https://ip-10-0-0-20.us-west-2.compute.internal/organizations/insight"
syntax_check_cache_path  "#{ENV['HOME']}/.chef/syntaxcache"
cookbook_path            ["#{current_dir}/../cookbooks"]
EOF
# Fetch ssl validation from chef server
knife ssl fetch
knife client list
```

+ Some names:
  + username, first name, last name: admin
  + admin.pem, insight-validator.pem
  + email: my mfa email
  + organization short name: insight
  + organization long name: "Chuck Insight Project"

  There was a slight wrinkle during the workstation setup. when using the command `knife.rb` file and using the `knife client list` command, I had to specify the chef server IP address `ip-10-0-0-20.us-west-2.compute.internal` rather than just `10.0.0.20`.

To bootstrap the kafka-test machine as a chef client, I had to make sure I was in the /chef-repo and use the command

```knife bootstrap 10.0.0.5 -N kafka-master -x ubuntu --sudo```

The 10.0.0.5 is the private IP of my kafka-master instance. The `-N` option specifies that "kafka-master" is going to be the name of the new chef client. The `-x` option is used to specify the username to ssh to. The `--sudo` option enables sudo privileges so the client can get bootstrapped (which means it's now under the control of the chef server). For now, this seems to be a manual process for each node.

I'm now on to [the next part](https://www.digitalocean.com/community/tutorials/how-to-create-simple-chef-cookbooks-to-manage-infrastructure-on-ubuntu) of the guide to create a chef cookbook to configure my kafka-test node.

It looks like `knife cookbook create <cookbook_name>` doesn't work anymore. We have to use

`chef generate cookbook <cookbook_name>`

instead. It also looks like the command needs to be done from `~/chef-repo/cookbooks` rather than `~/chef-repo` like it says in the guide.

I'm currently stuck at the point where I am running the command `sudo chef-client` from within the `kafka-test` node. It turns out that it takes a lot to configre a kafka cluster with chef. I found [this github repo](https://github.com/mthssdrbrg/kafka-cookbook?files=1) that has a pretty clear layout for the recipes, attributes, etc for configuring kafka. It also has an explanation for using custom logic to do a rolling restart of kafka servers so they don't all fail at the same time. This could definitely be helpful for my project.

I'm going to try to use the `default.rb` attribute from the kafka cookbook I found. It seems to install and configure kafka v1.0.0 using scala 12.12 rather than 12.11. But I just want to see what happens when I try to use it to configure a kafka node.

After a lot of failures, I think I understand the dependencies. I need to use all the directories in the cookbook: attributes, libraries, recipes, spec, templates, test. Putting these into the kafka cookbook on the chef workstation, uploading the cookbook to the chef server, and implementing that cookbook in kafka-test didn't result in any errors, but I don't think the configuration is correct. In kafka-test, there is a file `/etc/init.d/kafka` now. Oh..here's something:

```
Recipe: kafka::_install
  * remote_file[/var/chef/cache/kafka_2.12-1.0.0.tgz] action create (skipped due to not_if)
  * ruby_block[kafka-validate-download] action nothing (skipped due to action :nothing)
  * execute[kafka-install] action run (skipped due to not_if)
  * link[/opt/kafka] action create (up to date)

```

So it looks like the step of actually installing kafka was skipped due to `not_if`, whatever that means. Looking into `_install.rb`, the `not_if` clause is `not_if { kafka_installed? }`, so I think this just means kafka is already installed. However, `grep -r "kafka" \usr` didn't return anything to indicate that kafka has been installed (assuming it would be installed there?), so ultimately this didn't work. In the code of `_install.rb`, it seems there is a path to the `.tgz` file you need to install kafka, but in my case, I'd need to be downloading that `tgz` from a download link from the kafka site. I found another kafka cookcook in [this github repo](https://github.com/cerner/cerner_kafka) whose documentation seems much clearer at first glance. I think the first repo was addressing a particular technical issue in a particular setup, whereas this repo seems to be aimed at someone like me trying to set things up for the first time. In the meantime, I think I might as well use terraform to set up an infrastructure that makes sense for my pipeline rather than keep messing with this test setup. Then I can look into this new kafka cookbook and hope to get things up and running. I have changed all the references of kafka versions to `1.0.2` to match my pipeline specs (although technically my pipeline is supposed to be version 1.0.0, the kafka website only has a download link for 1.0.2, so I'm going with that version and will flag this as a possible source of error later.). There was a lot of repitition in making this change, so this code could use a goo refactoring where these variable settings can be configured in just one place and automatically filled in elsewhere in the cookbook.

I have chef nodes bootstrapped in the new infrastructure: kafka-master, kafka-worker1, and kafka-worker2. I got an error trying to upload this new cookbook:

```
ERROR: Cookbook cerner_kafka depends on cookbooks which are not currently
ERROR: being uploaded and cannot be found on the server.
ERROR: The missing cookbook(s) are: 'java' version '>= 0.0.0', 'ulimit' version '>= 0.0.0', 'logrotate' version '>= 0.0.0'
```

Using `grep`, I found where ulimit, java, and logrotate are mentioned in the repository. Ubuntu 16.04 appears to come with java dev kit 8, so I don't think I even need that java recipe. I'm going to try commenting out the "include recipe: java" part. I'll pass on ulimit and logrotate as well and see what happens. Ulimit seems to mean "user limit" and logrotate seems to be doing something on a daily time interval. After commenting out these references, I could successfully upload the cookbook to the chef-server. Running, however, gives the error

```
Unable to run kafka::default unable to determine broker ID
/var/chef/cache/cookbooks/cerner_kafka/libraries/config_helper.rb:41:in `set_broker_id'
```
So the broker ID isn't being set correctly. I now put in the public dns id's into `cerner_kafka-master/spec/config_helper_spec.rb` instead of `'broker1'` etc. Reuploading the cookbook, I'm still getting the same error. The error in assigning broker ID's seems to be happening with the `CernerKafkaHelper` function in `cerner_kafka-master/spec/config_helper_spec.rb`. I found several places where `zoo1:2184` and other "zoo<1,2,3>"" are referenced. It seems that these are actually supposed to be changed to the particular public dns of my instances. The documentation doesn't explain this clearly, and also requires a LOT of repetition in changing these.

I found another [github repo](https://github.com/Webtrends/kafka) for a kafka cookbook. This one is even simpler than the previous one, so it might be the resource to get me over this hurdle. It requires a "java" cookbook and a "runit" cookbook. The runit cookbook seems to be an [official cookbook](https://github.com/chef-cookbooks/runit), and I will again ignore the java recipe since my instances already have java installed.


# Terraform Help

+ [VPC module documentation](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.30.0)
+ [AWS security group module documentation](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/1.9.0)
+ [AWS security group submodules](https://github.com/terraform-aws-modules/terraform-aws-security-group/tree/master/modules)
+ The machine image I am using is `ami-833e60fb`, which is an Ubuntu 16.04 image with username `ubuntu`.
+ [A nice blogpost series to get started](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca)

I plan to look more into the modules to make sure that each service has sensible security groups.

# Pipeline Details

I talked with Tao, who developed the pipeline I'm building on, and he gave me some configuration details for his infrastructure:
+ He gave me a config.py file that has some configuration information for kafka and spark
+ 3 kafka servers, 4 spark streaming servers, 1 cassandra db, 1 flask front end web server
+ Requirements:
  + kafka version 1.0.0
  + Sparkstreaming version 2.2.1 Using Scala version 2.11.8
  + cassandra 3.11.2
  + pyspark, cassandra-driver "and one kafka-spark connector "(sorry I forgot which one I used...)"
  + kafka 40 partitions and 2 replications

  # Misc Questions

  + How can I use a bash script when ssh'ing through multiple machines?
  + How do I automate "knife bootstrap" to multiple nodes simultaneously? A less manual way would be to craft a bash script that iterates through `knife bootstrap <IPs of kafka nodes> -N kafka-<number of kafka node> -x ubuntu --sudo` for each node
