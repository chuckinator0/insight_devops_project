#
# Cookbook: insight-kafka-cluster
# License: Apache 2.0
#
default['zookeeper-cluster']['service']['version'] = '3.4.13'
# Using sha256 algorithm as indicated by the libartifact cookbook readme
# Update: libartifact doesn't handle checksums correctly, so I'm using the poise-archive instead. It simply
# downloads and installs from the download URL. This means it's important to verify the download outside of Chef.
default['zookeeper-cluster']['service']['binary_checksum'] = '91e9b0ba1c18a8d0395a1b5ff8e99ac59b0c19685f9597438f1f8efd6f650397'

# Changing the default kafka version, scala version, and download url.
default['kafka-cluster']['service']['version'] = '1.0.0'
default['kafka-cluster']['service']['scala_version'] = '2.11'
default['kafka-cluster']['service']['binary_url'] = "http://mirror.cc.columbia.edu/pub/software/apache/kafka/%{version}/kafka_%{scala_version}-%{version}.tgz"
