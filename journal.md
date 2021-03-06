# Journal -- A Winding Road

This journal is my way of processing what I'm learning and archiving some steps that I might need in the future.

## Getting data into S3

I have a dropbox link to the data that will be used in the pipeline. Downloading the large file failed multiple times, and I got frustrated, so I figured out how to download the file into an EC2 instance and transfer the file to S3 storage.

First, ssh into the ec2 instance. Download the file directly to the EC2 instance using the download link:

```wget <download url>```

Install awscli (amazon's command line interface tool):

```sudo apt install awscli```

Then use the command 

```AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=xxxx aws s3 cp <file> s3://my-bucket/```

The ec2 instance doesn't have access to my local environment variables (I don't think...I would like clarification on how to pass these to the remote instance), so I had to put those in. The important commands here were:

```aws s3 cp <file> <bucket>```

I also found [this github](https://github.com/surma/s3put) that explains the `s3put` command, which may be of use as well.

## Setting up Chef server

I am following [this guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-chef-12-configuration-management-system-on-ubuntu-14-04-servers#prerequisites-and-goals) for setting up a chef server and a chef workstation. I realize I've been using my local machine as the chef workstation, but I want to use a remote ec2 instance to be the chef workstation. So I'll have a chef server and a chef workstation in AWS.

I wrote a bash script to configure the chef server:
```
#!/bin/bash

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
I wrote a bash script to configure chef workstation (after ssh'ing into the workstation):
```
#!/bin/bash

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

I'm not sure the secure copy `scp` will actually work without setting up `SSH-agent`, so this script might not work as is. The chef server might have to have some manual input.

+ Some names:
  + username, first name, last name: admin
  + admin.pem, insight-validator.pem
  + email: my mfa email
  + organization short name: insight
  + organization long name: "Chuck Insight Project"

There was a slight wrinkle during the workstation setup. when using the command `knife.rb` file and using the `knife client list` command, I had to specify the chef server hostname `ip-10-0-0-20.us-west-2.compute.internal` rather than just the IP address `10.0.0.20`.

To bootstrap the kafka-test machine as a chef client, I had to make sure I was in the /chef-repo and use the command

```knife bootstrap 10.0.0.5 -N kafka-master -x ubuntu --sudo```

The 10.0.0.5 is the private IP of my kafka-master instance. The `-N` option specifies that "kafka-master" is going to be the name of the new chef client. The `-x` option is used to specify the username to ssh to. The `--sudo` option enables sudo privileges so the client can get bootstrapped (which means it's now under the control of the chef server). For now, this seems to be a manual process for each node.

I'm now on to [the next part](https://www.digitalocean.com/community/tutorials/how-to-create-simple-chef-cookbooks-to-manage-infrastructure-on-ubuntu) of the guide to create a chef cookbook to configure my kafka-test node.

It looks like `knife cookbook create <cookbook_name>` doesn't work anymore. We have to use

`chef generate cookbook <cookbook_name>`

instead. It also looks like the command needs to be done from `~/chef-repo/cookbooks` rather than `~/chef-repo` like it says in the guide.

## Using Chef to configure Kafka

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

I found another [github repo](https://github.com/Webtrends/kafka) for a kafka cookbook. This one is even simpler than the previous one, so it might be the resource to get me over this hurdle. It requires a "java" cookbook and a "runit" cookbook. The runit cookbook seems to be an [official Chef cookbook](https://github.com/chef-cookbooks/runit), as is the official Chef java cookbook [here](https://supermarket.chef.io/cookbooks/java).

I had to hardcode kafka's download URL into this new kafka cookbook, and it seems kafka requires a checksum to validate downloads. I used the url `http://apache.cs.utah.edu/kafka/1.0.0/kafka_2.11-1.0.0.tgz` for downloading kafka 1.0.0, and running the command `md5 kafka_2.11-1.0.0.tar` to get the checksum for this file. I set the partitions to 40, but I don't know how to set replicators to 2.

More errors uploading these cookbooks. For example:

```
ubuntu@ip-10-0-0-18:~/chef-repo/cookbooks$ knife cookbook upload -a
ERROR: Chef::Exceptions::MetadataNotValid: Cookbook loaded at path(s) [/home/ubuntu/chef-repo/cookbooks/kafka] has invalid metadata: The `name' attribute is required in cookbook metadata
```
I added a line `name = "kafka"` to the top of the metadata.rb file akin to what is in the cerner_kafka cookbook that didn't have this problem. The java cookbook also apparently depends on other cookbooks: `The missing cookbook(s) are: 'windows' version '>= 0.0.0', 'homebrew' version '>= 0.0.0'` and the runit cookbook depends on: `'packagecloud' version '>= 0.0.0', 'yum-epel' version '>= 0.0.0'`. I'm getting the feeling like I'm just going to be hunting for cookbook dependencies ad nauseum at this point. According to the runit cookbook readme, those dependencies are only for rhel, which I think has to do with Red Hat linux. For the java cookbook, I definitely don't need windows. Checking the java cookbook, the homebrew cookbook it depends on doesn't in turn depend on any other cookbooks, so I could add it without further trouble. However, I shouldn't need homebrew here either. I grep'd "include_recipe 'windows'" which pointed me to the file `jce.rb`, where there is an `if` statement that says if the OS is windows, then include the windows recipe. This should be skipped, yet for some reason windows is listed as a required cookbook. I am now reading [chef docs about Berkshelf](https://docs.chef.io/berkshelf.html). Apparently berkshelf.lock files are used to automatically download cookbooks that are depended upon. What is frustrating is that these cookbooks don't appear to actually need these other cookbooks, which seems like bloated configuration to me. I suppose the easiest way to approach this would be to comment out the `depends` statements in the metadata.rb files in the different cookbooks. Java has a metadata.json file that is a LOT of text, though. Maybe I will comment out the dependency on the java cookbook altogether for now because my AMI's do have java installed already. Trying it out! It didn't work, so I double checked my assumption that I already have java installed. Turns out I don't. D'oh. So I do need to include this java cookbook and figure out this java dependency business.

I'm going to try to use the command `knife cookbook site download java` and `knife cookbook site install java` to get this java cookbook (found these commands in the chef supermarket website). YAY! It installs all the cookbook dependencies too! I can use this in the future with other cookbooks from the chef marketplace. For now, I'm going to just try to install java on the kafka-master node using this java cookbook. I got an error from line 52 of `cookbooks/java/recipes/openjdk`:

```
Error executing action `install` on resource 'apt_package[openjdk-6-jdk, openjdk-6-jre-headless]'
No candidate version available for openjdk-6-jdk, openjdk-6-jre-headless
```

I'm going to go into the attributes/default.rb to change the default to java 8 since the readme for the cookbook indicated that java 6 and 7 cannot be automatically installed at this time. YAY! I was able to install java on the kafka-master node!

I'm going to clear out these cookbooks that haven't worked out and try the method of using knife to install the zookeeper and kafka-cluster cookbooks and their dependencies in one go like I did with java. [Here is the official zookeeper-cluster cookbook](https://supermarket.chef.io/cookbooks/zookeeper-cluster#knife) and [here is the official kafka-cluster cookbook.](https://supermarket.chef.io/cookbooks/kafka-cluster#readme) I'm reading about [wrapper cookbooks](https://blog.chef.io/2017/02/14/writing-wrapper-cookbooks/), which are cookbooks that are used to modify off-the-shelf cookbooks from the chef supermarket. Basically, you add `depends` statements in the metadata.rb and `include recipe` statements in recipes/default.rb. You can then overwrite the attributes from the cookbook you're wrapping by putting your own attributes in atributes/defualt.rb of the wrapper cookbook. I will make sure to do this later to get the right version of kafka that Tao used in his pipeline. The zookeeper-cluster cookbook recommends using a wrapper cookbook to configure your particular zookeeper setup (e.g. the hostnames of your nodes). These would be stored in a "data bag", which you can create with knife using `knife data bag create <name of bag> <name of item>`. This creates a json file. I did `knife data bag create zoo_bag zookeeper` and made the json for my kafka node host names:

```json
{
  "id": "zookeeper",
  "development": [
    "ip-10-0-0-5.us-west-2.compute.internal",
    "ip-10-0-0-14.us-west-2.compute.internal",
    "ip-10-0-0-25.us-west-2.compute.internal"
  ] 
} 
```
It seems like this data bag exists on the chef server, not on the chef workstation, so it's confusing that there is an empty directory /chef-repo/data_bags.

I'm now following the wrapper cookbook guide to make a wrapper for the zookeeper cookbook. This means creating a recipes/default.rb file with:

```ruby
bag = data_bag_item('zoo_bag', 'zookeeper')[node.chef_environment]
node.default['zookeeper-cluster']['zoo_bag']['development'] = node['ip-10-0-0-5.us-west-2.compute.internal','ip-10-0-0-14.us-west-2.compute.internal','ip-10-0-0-25.us-west-2.compute.internal']
node.default['zookeeper-cluster']['zoo_bag']['ensemble'] = bag
include_recipe zookeeper-cluser::default
```

and adding `depends zookeeper-cluster` in metadata.rb. I'm not 100% sure right now if I put in those hostnames correctly since the example was just `node['fqdn']` where fdnq is supposed to match the hostnames exactly. The kafka-cluster cookbook suggests that all I need to do at this point is add the following to my wrapper cookbook recipes/default.rb :

```ruby
node.default['kafka-cluster']['config']['properties']['broker.id'] = node['ipaddress'].rpartition('.').last
node.default['kafka-cluster']['config']['properties']['zookeeper.connect'] = bag['ensemble'].map { |m| "#{m}:2181"}.join(',').concat('/kafka')
include_recipe 'kafka-cluster::default'
```

I'm not 100% sure right now if 'ipaddress' is computed by the kafka-cluster cookbook from the zookeeper-cluster cookbook or if I have to put that ip in by hand. The reason I'm confused about it is that `rpartition('.').last` seems to be taking the last place value of the ip adress and using it as a broker id, which indicates that 'ipaddress' should be a single ip address, not an array of all the addresses in the cluster.

Odd aside trying to knife install the kafka-cluster cookbook--It depends on a deprecated libartifact cookbook whose tar file I had to rename to libartifact.tar.gz instead of libartifact-1.3.5.tar.gz in order to install. Dependencies in chef supermarket cookbooks seem to be a structural pain in how these things work. I'd love to learn how to update cookbooks to use alternatives to deprecated dependencies. Anyway, I was able to install the kafka-cluster cookbook.

Back to my confusion about how to set up this wrapper cookbook for zookeeper-cluster and kafka-cluster. I actually think I might be wrong about recipes/default.rb. I think it should be:

```ruby
bag = data_bag_item('zoo_bag', 'zookeeper')[node.chef_environment]
node.default['zookeeper-cluster']['config']['instance_name'] = node['ip-10-0-0-5.us-west-2.compute.internal','ip-10-0-0-14.us-west-2.compute.internal','ip-10-0-0-25.us-west-2.compute.internal']
node.default['zookeeper-cluster']['config']['ensemble'] = bag
include_recipe zookeeper-cluser::default
```
The 'config' and 'instance_name' are computed within the zookeeper-cluster default recipe. I thought those corresponded to the data bag, but the data bag is dealt with in the first line. I'm still not sure whether the instance name should be a list. I'm going to try using lists in those lines like so:

```ruby
node.default['zookeeper-cluster']['config']['instance_name'] = node['ip-10-0-0-5.us-west-2.compute.internal','ip-10-0-0-14.us-west-2.compute.internal','ip-10-0-0-25.us-west-2.compute.internal']
...
node.default['kafka-cluster']['config']['properties']['broker.id'] = node['10.0.0.5','10.0.0.14','10.0.0.25'].rpartition('.').last
```
It doesn't make a whole lot of sense because of how `.rpartition()` works, and there doesn't seem to be code in the zookeeper-cluster cookbook to tell a node what IP address it has. It just doesn't make sense. Another option would be to repeat each of these lines for each of the IP addresses, but that also doesn't really make sense to me. It can't be hardcoded because each node is pulling the cookbook, but it can't be iterative.

Ok, Bastian pointed me towards [this doc](https://docs.chef.io/ohai.html) about Ohai, which is a set of functions that grab system info from the current node. that means the correct syntax for this wrapper recipe would be:

```ruby
bag = data_bag_item('zoo_bag', 'zookeeper')[node.chef_environment]
node.default['zookeeper-cluster']['config']['instance_name'] = node['hostname']
node.default['zookeeper-cluster']['config']['ensemble'] = bag
include_recipe 'zookeeper-cluser::default'

node.default['kafka-cluster']['config']['properties']['broker.id'] = node['ipaddress'].rpartition('.').last
node.default['kafka-cluster']['config']['properties']['zookeeper.connect'] = bag['ensemble'].map { |m| "#{m}:2181"}.join(',').concat('/kafka')
include_recipe 'kafka-cluster::default'
```

The `node['hostname']` is a built in function to retrieve the hostname of the current node (which matches the hostnames I defined in the data bag item). The `node['ipaddress']` is likewise a built in function to grab the ip address of the current node. I had thought these were placeholders, but they are actually built-in tools.

Alright, now I'm having this trouble with `knife cookbook site install kafka-cluster`. It says it depends on a deprecated cookbook called libartifact and there's an error. I was able to force an install of libartifact, but I still can't install kafka-cluster cookbook. When I try to download and install libartifact directly, I have to change the tar file name from `libartifact-1.3.5.tar.gz` to `libartifact.tar.gz` first. But then when I try to install the kafka-cluster cookbook, it removes the libartifact cookbook and gives the same error:

```
WARNING: DEPRECATION: This cookbook has been deprecated. It has been replaced by poise-archive.
WARNING: Use --force to force download deprecated cookbook.
Removing pre-existing version.
Uncompressing libartifact version 1.3.5.
ERROR: Archive::Error: Failed to open '/home/ubuntu/chef-repo/cookbooks/libartifact.tar.gz'
```

I think maybe there's some basic bug about what the expected name of the .tar file should be? Ok, so I'm going to use the `tar -xzf kafka-cluster-1.3.3.tar.gz` to unzip kafka, go into the metadata and change the dependency on libartifact to poise-archive 1.5.0 instead. Then, I need to create a Berksfile inside the kafka-cluster cookbook:

```
source 'https://supermarket.chef.io'
metadata
```

The command `berks install` should then install all the dependencies. I have to do this because the `knife cookbook site install` would install from the supermarket, whereas `berks isntall` will install based on my local kafka-cluster cookbook which now doesn't depend on libartifact. We can also do `berks upload` to upload these cookbooks to the chef server. Let's see if this works...

Ok, it worked for kafka-cluster, but I need to do the same with zookeeper-cluster. Alright, was able to knife upload all cookbooks, although I got a warning that homebrew is "frozen" so it won't be uploaded. Don't care about homebrew.

Ok, now to edit my kafka nodes to run my wrapper cookbook `insight-kafka-cluster`, which depends on the zookeeper-cluster and kafka-cluster cookbooks using `knife edit node <node name>` (oops, I needed to get back to the chef-repo/ directory to run that command). I edited each of the nodes. Again, I'm not sure how I would automate this part. I think these node profiles exist on the chef server, so perhaps to automate I could send a command to the chef server directly that overwrites these files with the proper contents? There are details there to figure out. Nodes are edited. All that is required is to run `sudo chef-client`.

Well, I'm getting this error when running sudo chef-client:

```undefined method `[]' for nil:NilClass```

It traces back to this line from insight-kafka-cluster/recipes/default.rb :

```
node.default['kafka-cluster']['config']['properties']['zookeeper.connect'] = bag['ensemble'].map { |m| "#{m}:2181"}.join(',').concat('/kafka')
```

So, one of these [''] pieces is returning nil. The line above it has most of the same parameters except ['zookeeper.connect'] and bag['ensemble'], so one of these is wrong. I cannot find ['zookeeper.connect'] in the attributes  folder of the kafka-cluster cookbook (or anywhere but the README), so that is probably the thing that's collapsing to nil. It is just weird because this seems like a clear oversight that someone would have mentioned. Ok, I'll try setting a defualt attribute for zookeeper.connect in my wrapper cookbook called insight-kafka-cluster. My understanding is that I just need to add the line

```
node.default['kafka-cluster']['config']['properties']['zookeeper.connect'] = "{dummy:string}"
```

to attributes/default.rb to initialize the variable, and then the recipe will override this default. The reason why I think this is because `default['kafka-cluster']['config']['properties']['broker.id'] = 1` is in kafka-cluster/attributes/default.rb, and 1 is just a dummy integer that will get overridden with the last place value of the ip address in the recipe.

Ok, that didn't work. I'm still getting the same [] nil error. That might indicate that something is wrong with the `bag['ensemble']` part. Wait...now I'm noticing when I search the kafka-cluster github for "zookeeper.connect" [here](https://github.com/bloomberg/kafka-cookbook/search?q=zookeeper.connect&unscoped_q=zookeeper.connect), there is a test environment with the line:

```
node.default['kafka-cluster']['config']['zookeeper_connect'] = 'localhost:2181/kafka'
```

Notice here that the syntax is ['zookeeper_connect'], not ['zookeeper.connect']. I will make this edit to the recipe in insight-kafka-cluster and see what happens. Darn, same nil [] error as before. Kevin helped me think of the following idea: The `.map` function might be expecting IP addresses rather than hostnames, but my data bag is given in terms of hostnames. I'm going to try using ip addresses in the data bag and update node['hostname'] to node['ipaddress'].

Ohhhh oof. Dumb. I think the issue might be a few lines above the trouble line with bag['ensemble']:

```
node.default['zookeeper-cluster']['config']['ensemble'] = bag
```

Notice that the right side just says bag, not bag['ensemble']? I think that's my huckleberry. It needs to be

```
node.default['zookeeper-cluster']['config']['ensemble'] = bag['ensemble']
```

The call to bag['ensemble'] results in a nil []. This means I need to go back and change the data bag back to the hostnames like before and fix this bag['ensemble'] line.

Ok, that didn't work. Now there's an error on that line I just edited. Now I'm wondering whether this all has to do with `bag = data_bag_item('zoo_bag', 'zookeeper')[node.chef_environment]`. In data_bag_item('zoo_bag','zookeeper'), there is a single environment called "development", and I'm wondering now whether that environment is not being used and the resulting list of hostnames is reading as empty. I'm reading about chef environments and I dont think I defined any environments along the way, so there should just be the `_default` environment. I understand in real life there would be dev, prod, and other environments, but for now, I'm just going to change the zoo_bag item to use the `_default` enviroment.

AHA! Different error this time:

```
no implicit conversion of String into Integer
>> node.default['zookeeper-cluster']['config']['ensemble'] = bag['ensemble']
```

I think this means my data bag is being read, but there is this type error where it's expecting an integer but getting a string. I'll change back to ip addresses in the data bag item? Nope. Maybe the ip addresses shouldn't be strings? Nope, it wouldnt even let me save the zoo_bag item in that condition.

Siobahn helped me big time. She helped me reason that the object `bag` is an array of strings (my cluster's ip addresses), and so `bag['ensemble']` doesn't actually make sense. You can't find the item in the list at the index "ensemble". This codebase has proven to be REALLY difficult to work with, but I'm glad I've been able to stick with it and fix these issues. The corrected code is:

```ruby
bag = data_bag_item('config', 'zookeeper-cluster')[node.chef_environment]
node.default['zookeeper-cluster']['config']['instance_name'] = node['ipaddress']
node.default['zookeeper-cluster']['config']['ensemble'] = bag
include_recipe 'zookeeper-cluster::default'

node.default['kafka-cluster']['config']['properties']['broker.id'] = node['ipaddress'].rpartition('.').last
node.default['kafka-cluster']['config']['properties']['zookeeper.connect'] = bag.map { |m| "#{m}:2181"}.join(',').concat('/kafka')
include_recipe 'kafka-cluster::default'
```

Uploading this the chef-server and running it in a node results in a different error, which is good because this new error is completely unrelated:

```
Chef::Exceptions::RecipeNotFound
  --------------------------------
could not find recipe apply for cookbook sysctl
```

I know how to solve cookbook dependency issues using the Berksfile! The good news is that I got the code coordinating zookeeper and kafka to work. I had to use  `berks install` inside chef-repo/cookbooks/insight-kafka-cluster. Same error...seems to do with the line `include_recipe 'sysctl::apply'` in the cookbooks/kafka-cluster. According to [this github issue](https://github.com/bloomberg/chef-bach/pull/1118), I can comment out or delete the line `include_recipe 'sysctl::apply'` since the `depends` statement in the metadata is sufficient. Alright, running `sudo chef-client` on my kafka-master node was able to do some things! There were a couple of novel errors, though.

```
    NoMethodError
    -------------
    undefined method `libartifact_file' for #<ZookeeperClusterCookbook::Provider::ZookeeperService:0x00000000053fd2c0>
```

Well, earlier I had the issue with the libartifact cookbook. It was labeled as deprecated, refused to install, and it was suggested to use the pose-archive cookbook instead. So, I added that library back in and used `berks install` and also `knife cookbook upload -a --force` to get it added to the zookeeper-cluster cook and uploaded to the chef server. Ok, now that's working, but we have a different issue:

```
        Error executing action `create_if_missing` on resource 'remote_file[http://mirror.cc.columbia.edu/pub/software/apache/zookeeper/zookeeper-3.5.0-alpha/zookeeper-3.5.0-alpha.tar.gz]'
        ================================================================================
        
        Net::HTTPServerException
        ------------------------
        404 "Not Found"
```

Alright, no big deal. The download mirror from columbia.edu is showing a 404 not found, so that's just a bad link. Very odd that the version is 3.5.0 since 3.5+ versions appear to still be in beta. Version 3.4.13 seems to be the latest stable release. I will go ahead and make an attributes directory and a default.rb there in my wrapper cookbook and set the following defaults:

```
default['zookeeper-cluster']['service']['version'] = '3.4.13'
default['zookeeper-cluster']['service']['binary_checksum'] = 'c380eb03049998280895078d570cb944'
```

I got the md5 checksum from [here](https://apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz.md5). Setting these in the default attributes of my wrapper cookbook should override what's in the zookeeper-cluster cookbook. That's kind of the beauty of wrapper cookbooks. I don't have to dig into the underlying cookbooks. I just have to adjust what I need to adjust.

Ok cool, I just got a checksum mismatch, which means the url was good but maybe it's not using md5 checksum to verify the download. I'll use the sha1 checksum `a989b527f3f990d471e6d47ee410e57d8be7620b` from [here](https://apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz.sha1). Hmm, checksum still didn't work. Well, downloading the file from apache and from this mirror on my laptop and running `shasum` on each of them, I do get the same checksum `a69f459f36da3760a2bbcc52e7bb29b08c5ce350` for both of them, so I'm going to go with this value next. I'm not sure this will work since the error says 

```
        Chef::Exceptions::ChecksumMismatch
        ----------------------------------
        Checksum on resource (a989b5) does not match checksum on content (7ced79)
```

This indicates the checksum on the content starts with 7ced79. But, I have to try the checksum calculated directly from apache. Yeah, as expected, it didn't work. This is confusing because I literally downloaded the file from apache and from the mirror and calculated their sha1 checksums and they matched. Is the download actually getting fooled by an attacker? Highly doubtful. Also, why does the calculated checksum on the apache download https://apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz not match the checksum they have posted https://apache.org/dist/zookeeper/zookeeper-3.4.13/zookeeper-3.4.13.tar.gz.sha1 ? These are some shenanigans. I'm just going to try a different mirror locally and see if I'm getting the same issue. I'm trying the mirror from [university of utah](http://apache.cs.utah.edu/zookeeper/zookeeper-3.4.13/) and getting exactly the same checksum `a69f459f36da3760a2bbcc52e7bb29b08c5ce350`. This [libartifact cookbook readme](https://github.com/johnbellone/libartifact-cookbook/blob/744e4804f96d4e649d6eac0f0ad281a9fea66006/README.md) indicates that the sha256 algorithm is being used to calculate the checksum. That algorithm gives '91e9b0ba1c18a8d0395a1b5ff8e99ac59b0c19685f9597438f1f8efd6f650397', which still doesn't contain 7ced79, but I'll try it anyway and then put this down for the weekend. Yep, same error. Putting this down for now and I'll see what Bastian says on Monday.

I'm going to replace the libartifact code in zookeeper-cluster/libraries/zookeeper_service.rb:

```ruby
libartifact_file "zookeeper-#{new_resource.version}" do
artifact_name 'zookeeper'
artifact_version new_resource.version
install_path new_resource.install_path
remote_url new_resource.binary_url % { version: new_resource.version }
remote_checksum new_resource.binary_checksum
only_if { new_resource.install_method == 'binary' }
end
```
with this code from poise-archive that downloads and unpacks packages:
```ruby
poise_archive new_resource.binary_url % { version: new_resource.version } do
destination new_resource.install_path
end
```

This should get around the checksum. Checksum is not mentioned in the repo other than here and a default attribute in /attributes/defaults.rb. This does make this slightly less secure, but I've verified manually that the checksum from the columbia site matches other mirrors and apache itself, so I'm going to go ahead with it. Progress! Zookeeper appears to have successfully installed. Kafka-cluster, on the other hand is still using this deprecated libartifact checksum business. I just need to make the same change to kafka-cluster/libraries/kafka-service.rb and double check that the download url is good.

It looks like the [github](https://github.com/bloomberg/kafka-cookbook) for the kafka-cluster-cookbook is slightly updated from the [chef supermarket version I pulled](https://supermarket.chef.io/cookbooks/kafka-cluster#knife), so I need to add the scala version as an attribute in kafka-cluster/libraries/kafka-service.rb:

```ruby
      # @!attribute scala_version
      # @return [String]
      attribute(:scala_version, kind_of: String, required: true)
...
      def current_path
        ::File.join(install_path, 'kafka', 'current', "kafka_#{scala_version}-#{version}")
      end
```

This might be a lesson to me that the associated github repo of a supermarket recipe will tend to be more up to date and better documented than the chef supermarket version. I'm getting a key error now that the key{scala_version}. It looks like the default scala version needs also to be set in kafka-cluster/attributes/default.rb:

```ruby
default['kafka-cluster']['service']['scala_version'] = '2.11'
```

I'm still getting the same key error, but I don't yet understand why. I grep'd "scala_version", and it's showing up in all the correct places. I'm wondering now that the URL requires 2 inputs, `scala_version` and `version`, maybe I need the pose_archive function to be:

```ruby
poise_archive new_resource.binary_url % { scala_version: new_resource.scala_version }% { version: new_resource.version } do
destination new_resource.install_path
end
```
New error that sheds some light! Now the error is that it can't find key{ version }. This could be something to do with string formatting in Ruby. I'm not sure why I thought that would work. The string formatting is the same as python (although `.format{}` is the more pythonic way to do that). It should be:

```ruby
poise_archive new_resource.binary_url % { scala_version: new_resource.scala_version ,  version: new_resource.version } do
            destination new_resource.install_path
end
```

The reason I assumed it didn't work like this is that the kafka-cluster github didn't actually update this part, event though they added scala_version. I had assumed that they had tested and confirmed that it worked.

WOOHOO! successfully ran `sudo chef-client` to install zookeeper and kafka on all my nodes!! I requested a high-5 from Long and he obliged!

The next step is to get spark streaming and cassandra configured using chef.

After talking with Siobhan, I realize I need to put in a replication factor of 2 and the number of partitions to 40 to the attributes from kafka-cluster/libraries/kafka_topic.rb:

```ruby
default['kafka-cluster']['config']['properties']['num.partitions'] = 40
default['kafka-cluster']['topic']['replication_factor'] = 2
```

I tried this, but I'm not sure if this actually set the replication factor correctly. I checked `/srv/bin` in my node and found `kafka-topics.sh`, but it didn't have explicit flags for repplication factor:

```
exec $(dirname $0)/kafka-run-class.sh kafka.admin.TopicCommand "$@"
```

The `kafka-run-class.sh` file also doesn't mention replication. Look closer at /kafka-cluster/libraries/kafka_topic.rb:

```
# Builds shell command for managing Kafka topics.
# @param type [String]
# @return [String]
    def command(type)
      ['kafka-topics.sh', "--#{type}"].tap do |c|
        c << ['--topic', topic_name]
        c << ['--zookeeper', [zookeeper].compact.join(',')]
        c << ['--partitions', partitions] if partitions
        if type.to_s == 'create'
          c << ['--replication-factor', replication_factor] if replication_factor
        end
      end.flatten.join(' ')
    end
```

This appears to put the `--replication-factor` flag into a command on the fly. I didn't get a syntax error with `default['kafka-cluster']['topic']['replication_factor'] = 2`, so I think this code should take the replication factor into account when actually running a topic. It's just difficult to understand because chef shows the changed number of partitions but does not show change of replication factor when running `chef-client`.

To see if `default['kafka-cluster']['topic']['replication_factor'] = 2` is actually valid, I changed `replication_factor` to `blahblahblah` and was expecting an error running chef-client. I didn't get an error, so I'm not certain `default['kafka-cluster']['topic']['replication_factor'] = 2` actually sets the replication factor. Apache recommends a replication factor of 2 to 3 for fault tolernce, so I'm going to go ahead and go into /kafka-cluster/libraries/kafka_topic.rb and change the default attribute for replication factor there:

```
      # Change default replication factor to 2
      attribute(:replication_factor, kind_of: Integer, default: 2)
```

For the demo, I can start with some fresh instances, add all the nodes to the chef server, and then ssh into one and do `whereis kafka` and `whereis zookeeper` and show the contents of zoo.properties.

## Spark Streaming Cluster

Spark seems to have a nice built-in standalone manager for managing clusters, which I'm reading about in [this documentation](https://spark.apache.org/docs/latest/spark-standalone.html). I can put a short script in the user_data of Terraform to update, install pyspark, and set the master node for the spark streaming cluster. I whipped up a simple script to update and install pyspark and cassandra-river on spark instances:

```
#!/bin/bash

# update spark instance
sudo apt-get update        # Fetches the list of available updates
sudo apt-get upgrade       # Strictly upgrades the current packages
sudo apt-get dist-upgrade  # Installs updates (new ones)

# update pip
sudo pip install --upgrade pip

# install pyspark
sudo pip install pyspark

# install cassanda-driver for connecting to cassandra database
sudo pip install cassandra-driver
```

After speaking with Cheuk, I learned that orchestrating spark is much more complicated than installing pyspark. I misread the spark download page. I thought installing pyspark would also download spark itself, but spark is separate. It also requires hadoop, and cluster management. Other fellows have done all of this with Insight's in-house configuration tool called Pegasus. I decided to ask around and learn something other than Chef, so I asked Cheuk how he configured his spark cluster. Cheuk borrowed some scripts from the Pegasus source code and shared them with me. First, I would have to [adapt this script](https://github.com/cheuklau/insight_devops_airaware/blob/master/devops/multi_with_asg/packer/scripts/download-and-install-spark.sh) to set up the workers, followed by the master node (the workers need to come first so that the master can find them later). Then, I need to adapt this [terrafrom script](https://github.com/cheuklau/insight_devops_airaware/blob/master/devops/multi_with_asg/terraform/instance.tf) to launch them. There is more nuance to explore in the terraform code he showed me, but it's also probably a good option to explore this spark standalone mode to create the master-worker relationships as well. For now, I need to plant a flag in the ground with my work with Chef and prepare my presentation and rework my README.


## Terraform Help

+ [VPC module documentation](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/1.30.0)
+ [AWS security group module documentation](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/1.9.0)
+ [AWS security group submodules](https://github.com/terraform-aws-modules/terraform-aws-security-group/tree/master/modules)
+ [Nice repository of AWS terraform modules](https://github.com/terraform-aws-modules)
+ The machine image I am using is `ami-833e60fb`, which is an Ubuntu 16.04 image with username `ubuntu`.
+ [A nice blogpost series to get started](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca)
+ [A good starting point from Insight]()

I plan to look more into the modules to make sure that each service has sensible security groups.

I just added the bash scripts for setting up the chef server and workstation. I set the workstation to depend on the initialization of the chef server. This should automatically set up the chef server and workstation as opposed to when I did everything manually in the first setup. I'm not sure if the ssh secure copy `scp` will work yet.

## Pipeline Details

I talked with Tao, who developed the pipeline I'm building on, and he gave me some configuration details for his infrastructure:
+ He gave me a config.py file that has some configuration information for kafka and spark
+ 3 kafka servers, 4 spark streaming servers, 1 cassandra db, 1 flask front end web server
+ Requirements:
  + kafka version 1.0.0
  + Sparkstreaming version 2.2.1 Using Scala version 2.11.8
  + cassandra 3.11.2
  + pyspark, cassandra-driver "and one kafka-spark connector "(sorry I forgot which one I used...)"
  + kafka 40 partitions and 2 replications

## Misc Questions and thoughts

+ How can I use a bash script when ssh'ing through multiple machines?
+ How do I automate "knife bootstrap" to multiple nodes simultaneously? A less manual way would be to craft a bash script that iterates through `knife bootstrap <IPs of kafka nodes> -N kafka-<number of kafka node> -x ubuntu --sudo` for each node. Perhaps I can have them each ssh this command to the chef workstation with terraform's user_data function, so when each comes online, it sends its own IP in the knife command.
+ If I have time later, I need to make Terraform more modular and look more into the aws security group module to open specific ports on specific services.
+ ~~If I have time later, I can automate the chef server and chef workstation setup in Terraform~~ Done!
+ Maybe for automatically bootstrapping the nodes to the chef server, I can have each instance (kafka,spark, cassandra, and flask if I decide to include flask) depend on the chef workstation instance in terraform, and then have it send the knife bootstrap command to the chef workstation when they come online.
+ How does Chef fit in to the "golden AMI" best practice?
+ When defining the `zoo_bag` data bag for zookeeper, is there a way to generate this data bag from terraform outputs and put it on the chef server instead of manually declaring the IP addresses of the zookeeper cluster?

## Changing Gears: Learning about Kubernetes Container Management and Orchestration

I decided that I want to round out my understanding of distributed systems deployment by diving deeper into docker and learning about how kubernetes manages containerized applications on a distributed architechture. I am starting fresh from [kubernetes documentation](https://kubernetes.io/docs/tutorials/kubernetes-basics/deploy-app/deploy-intro/). I know a little about docker from my work on the [insight systems puzzle](https://github.com/chuckinator0/systems-puzzle-master), so I'm going to build on that and think about how kubernetes might deploy a docker application in a distributed environment.

### Clusters and Deployments

Kubernetes Clusters: Kubernetes groups computers together into a cluster. There is a "master" that controlls and coordinates the cluster, and "worker nodes" that run applications. Each worker node is a virtual machine or physical computer. This tutorial uses Minikube as a lightweight kubernetes implementation that sets up a single virtual machine that runs a cluster with a single node.

Create a Deployment: Kubernetes uses the command `kubectl` ("kube control") to deploy a containerized application on a cluster. Once a deployment is created, the kubernetes master schedules the application instances on nodes in the cluster. Then, the Kubernetes Deployment Controller monitors those instances continuously. If a node is deleted or fails, a new node is brought up automatically. In this way, the system heals itself during hardware failure or maintenance. Here are some commands:

+ Run `kubectl get nodes` to see a list of the nodes in the cluster.
+ Run `kubectl run <deployment name> --image=<full url to image hosted on dockerhub> --port=<port>` to deploy a cluster.
  + Example: `kubectl run kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1 --port=8080`
+ Run `kubectl get deployments` to see your deployed clusters.

Pods inside kubernetes are running on a private, separate network from the underlying infrastructure. Pods are visible to other pods and services inside the same cluster, but not outside that network. The `kubectl` command is an API endpoint to communinicate with our application. The `kubectl proxy` command in a different terminal creates a proxy that forwards communications into the cluster's private network.

Each pod is a collection of one or more containers along with some shared resources, like "Volumes", networking with a unique cluster IP address, and container information like image version and exposed ports. Containers in a pod share an IP address and port space (important!).

Nodes are machines that run pods. Each node runs kubectl to interact with the master node, as well as a docker (or similar) runtime that can pull the docker image, unpack the containers, and run the application.

Here are some common troubleshooting commands with kubectl:
+ `kubectl get` - lists resources
+ `kubectl describe` - show detailed info about a resource
+ `kubectl logs <pod name > <container name>` - prints the logs from a container in a pod
+ `kubectl exec <pod name> < -c container name> <command>` - run commands on a container in a pod

To interact with a pod, this tutorial suggests storing the pod name as an environmental variable:

```bash
export POD_NAME=$(kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
```

Then, we can open a proxy into the node's internal network by running `kubectl proxy` in a different terminal session (or maybe there's a way to run it as a background process? But then, you'd have to remember to manually close it?). This should give the message:

```
Starting to serve on 127.0.0.1:8001
```

Note that even though a node is a single machine or virtual machine, it still has in internal network of pods as far as kubernetes is concerned. That's one hard thing to wrap your mind around at first. Kubernetes has its own network overlay on top of the physical network. Anyway, we can now access the pod through the proxy, for example with `curl`:

```bash
curl http://localhost:8001/api/v1/namespaces/default/pods/$POD_NAME/proxy/
```

The URL here is the route to the API of the pod.

To open a bash session inside a container in a pod, we can use `kubectl exec -ti $POD_NAME bash`. The `-i` option means "--stdin=false: Pass stdin to the container" and the `-t` option means "--tty=false: Stdin is a TTY". What this basically means is that we are starting a bash session inside the container and it is not connected to the bash session we were using outside the container (from what I gather from googling).

### Kubernetes Services

The next section is about kubernetes' "services". A service is basically a way to connect kubernetes' internal network to the network in which is lives. For example, if you have all your machines in a virtual private cloud (VPC), those machines will have IP addresses, but kubernetes has its own, separate, internal IP addresses for those nodes. Services allow things outside of kubernetes to see inside and interact with the pods. Pods on different nodes can be connected together by the same service, and you can expose that service to something outside of the kubernetes cluster. The service is basically a go-between (API) so you can communicate with pods inside of the cluster from outside of the cluster. In the example, we use the command

```bash
kubectl expose deployment/kubernetes-bootcamp --type="NodePort" --port 8080
```

To create a service that exposes the `kubernetes-bootcamp` deployment on port 8080. The command `kubectl describe services/kubernetes-bootcamp` gives a lot of useful information about the service. In this case, it shows that the NodePort is 30194, so the kubernetes-bootcamp service is exposing 30194 to the world outside the cluster while reaching in through port 8080 inside the cluster. We can now communicate with the pod through the service with `curl $NODE_IP:30194`, where `$NODE_IP` is the IP address of the node itself (outside of the cluster). If you destroy the service, you won't be able to reach that pod's output outside of the cluster, but you can still use `kubectl exec -ti $POD_NAME curl localhost:8080` to see the output from inside the cluster with `kubectl`.

### Scaling with Replicas

The next part is about scaling and balancing a deployment. This command makes replicas of your deployment:

```bash
kubectl scale deployments/kubernetes-bootcamp --replicas=4
```

This deployment is only one pod, so this makes 4 replicas of the deployment. You can check by using the command `kubectl get pods` or `kubectl get pods -o wide` if you want more information like IP addresses of the pods. You can also use the command `kubectl describe deployments/<name of deployment>` to get detailed information about the entire deployment.

Now that the deployment has been replicated, we can check that kubernetes is load balancing across the replicas. The command `kubectl describe services/<name of deployment>` shows us the exposed IP and port of the service. Setting the port as an environmental variable, we have

```bash
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -o go-template='{{(index .spec.ports 0).nodePort}}')
```

And then we can repeatedly make requests using `curl $(minikube ip):$NODE_PORT` and see that the requests are being balanced across the different replicas.

We can scale down the replicas now with `kubectl scale deployments/kubernetes-bootcamp --replicas=2`. There are more advanced features that enable autoscaling using health checks (i.e. increase replicas up to a max number if CPU utilization is greater than x%, and decrease replicas down to a minimum number if CPU drops below y% ), but this tutorial hasn't gotten there yet.

### Rolling Updates

The last section is about doing rolling updates, which is nice because you can make updates without taking anything offline. The app is still available the whole time. In particular, rolling updates allow these actions:
+ promote an application from one environment to another with container image updates
+ rollback to previous versions
+ continuous integration and delivery of applications with zero downtime

The first part of the tutorial module had us use this command to update to a new version of the `kubernetes-bootcamp` app:

```bash
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=jocatalin/kubernetes-bootcamp:v2
```

The `set image` command sets the image of the containers in our pods to version 2. Kubernetes then does a rollout that takes down all of v1 pods and puts up v2 pods without interrupting service.

Next, we can use `kubectl describe services/kubernetes-bootcamp` to see the service that allows us to communicate with the cluster. This command shows us the nodePort so we can reach into the cluster and communicate with the pods. We again export a variable we will call NODE_PORT:

```bash
export NODE_PORT=$(kubectl get services/kubernetes-bootcamp -o go-template='{{(index .spec.ports 0).nodePort}}')
```

And then we can `curl` from the exposed port with `curl $(minikube ip):$NODE_PORT` to see the http output from the app. This output tells us that the pods are on version 2, and by running the command multiple times, we verify that kubernetes is load balancing among the various pods in the replica set. The command `kubectl rollout status deployments/kubernetes-bootcamp` tells us that the rollout of the new version was successful.

Ok, now to practice rolling back from an update. Let's say we update to so-called v10 by using a new container image:

```bash
kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=gcr.io/google-samples/kubernetes-bootcamp:v10
```

This time, the pods aren't responding correctly. Using `kubectl get deployments`, we see there are only 3 pods available. When we `kubectl get pods`, we see the message "ImagePullBackoff" on two of the pods. For more insights, we use `kubectl describe pods`. We see that the failing pods are encountering an error pulling the image. We see an error message in the event log:

```
Failed to pull image "gcr.io/google-samples/kubernetes-bootcamp:v10": rpc error: code = Unknown desc = unauthorized: authentication required
```

In this case, the error occured because there is no v10 in the container repository we're pulling from. We can roll back with:

```bash
kubectl rollout undo deployments/kubernetes-bootcamp deployment.apps "kubernetes-bootcamp"
```

This `rollout undo` will revert us back to the last known stable version, which was v2. We can check the versions of the images by describing the pods and then searching for 'image' with `grep`: `kubectl describe pods | grep -i image`. Indeed, there are 4 running pods all on version 2.











