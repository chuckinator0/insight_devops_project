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
