#
# Cookbook:: first_cookbook
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.
file "#{ENV['HOME']}/amazon/chef_practice/test.txt" do
  content 'This file was created by Chef!'
end
