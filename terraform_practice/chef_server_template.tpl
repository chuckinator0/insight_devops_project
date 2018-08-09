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
