# Author:: Bryan W. Berry (<bryan.berry@gmail.com>)
# Author:: Seth Chisamore (<schisamo@chef.io>)
# Author:: Joshua Timberman (<joshua@chef.io>)
#
# Cookbook:: java
# Recipe:: openjdk
#
# Copyright:: 2010-2015, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe 'java::notify'

unless node.recipe?('java::default')
  Chef::Log.warn('Using java::default instead is recommended.')

  # Even if this recipe is included by itself, a safety check is nice...
  [node['java']['openjdk_packages'], node['java']['java_home']].each do |v|
    include_recipe 'java::set_attributes_from_version' if v.nil? || v.empty?
  end
end

jdk = ChefCookbook::OpenJDK.new(node)

if platform_requires_license_acceptance?
  file '/opt/local/.dlj_license_accepted' do
    owner 'root'
    group 'root'
    mode '0400'
    action :create
    only_if { node['java']['accept_license_agreement'] }
  end
end

if node['platform'] == 'ubuntu'
  apt_repository 'openjdk-r-ppa' do
    uri 'ppa:openjdk-r'
    distribution node['lsb']['codename']
  end
end

package node['java']['openjdk_packages'] do
  version node['java']['openjdk_version'] if node['java']['openjdk_version']
  notifies :write, 'log[jdk-version-changed]', :immediately
end

java_alternatives 'set-java-alternatives' do
  java_location jdk.java_home
  default node['java']['set_default']
  priority jdk.alternatives_priority
  bin_cmds node['java']['jdk'][node['java']['jdk_version']]['bin_cmds']
  action :set
  only_if { platform_family?('debian', 'rhel', 'fedora', 'amazon') }
end

if node['java']['set_default'] && platform_family?('debian')
  include_recipe 'java::default_java_symlink'
end

# We must include this recipe AFTER updating the alternatives or else JAVA_HOME
# will not point to the correct java.
include_recipe 'java::set_java_home'
