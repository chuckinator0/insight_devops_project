#
# Cookbook:: insight-zookeeper-cluster
# Recipe:: default
#
# Apache 2.0 License
bag = data_bag_item('zoo_bag', 'zookeeper')[node.chef_environment]
node.default['zookeeper-cluster']['config']['instance_name'] = node['ipaddress']
node.default['zookeeper-cluster']['config']['ensemble'] = bag
include_recipe 'zookeeper-cluster::default'

node.default['kafka-cluster']['config']['properties']['broker.id'] = node['ipaddress'].rpartition('.').last
node.default['kafka-cluster']['config']['properties']['zookeeper.connect'] = bag.map { |m| "#{m}:2181"}.join(',').concat('/kafka')
include_recipe 'kafka-cluster::default'
