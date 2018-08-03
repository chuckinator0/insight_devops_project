Cerner Kafka
============

[![Cookbook Version](https://img.shields.io/cookbook/v/cerner_kafka.svg)](https://community.opscode.com/cookbooks/cerner_kafka)
[![Build Status](https://travis-ci.org/cerner/cerner_kafka.svg?branch=master)](https://travis-ci.org/cerner/cerner_kafka)

A Chef cookbook to install [Apache's Kafka](http://kafka.apache.org/).

A recipe to install the [KafkaOffsetMonitor](https://github.com/quantifind/KafkaOffsetMonitor) application is
also included.

View the [Change Log](CHANGELOG.md) to see what has changed.

Getting Started
---------------

To get setup you need to do the following,

Provide a value for `node["kafka"]["zookeepers"]` with an array of zookeeper host
names (i.e. `['zk1.domain.com', 'zk2.domain.com', 'zk3.domain.com']`).

With the defaults and the default recipe this will install and run a 0.9.0.0 Kafka
broker using Kafka's defaults.

What this will setup
--------------------

This will install Kafka at `node["kafka"]["install_dir"]`. In order to handle
upgrades appropriately we use symbolic links and land the real installations elsewhere.

The true installations will land,

    /opt (configurable with node["kafka"]["base_dir"])
    | - kafka_0.9.0.0
    | | - config
    | | - bin
    | | - kafka_0.9.0.0.jar
    | | - ...

While we provide a symbolic link to the convenient location,

    /opt/kafka (configurable with node["kafka"]["install_dir"])
    | - config
    | - bin
    | - kafka_0.9.0.0.jar
    | - ...

It will also create/setup an init service which can be used to start/stop/restart kafka,

    service kafka [start|stop|restart|status]

We also link kafka's log directory to `/var/log/kafka` to make it easier to find kafka's logs.

Usage
-----

Here are some common deployment options and tips

### Deploying Kafka 0.8

This cookbook can be used to install/deploy Kafka 0.8.X but some additional configuration
is required. In addition to setting the `node["kafka"]["zookeepers"]` attribute
you will also need to set the `node["kafka"]["brokers"]` attribute with an array
of Kafka broker host names.

You will also need to tweak `node["kafka"]["version"]` to the version that will
be used and possibly `node["kafka"]["scala_version"]` as well which defaults to `2.11`.

### Kafka brokers and zookeepers attributes

The attributes,

 * `node["kafka"]["brokers"]`
 * `node["kafka"]["zookeepers"]`

Actually map to 'server.properties' settings,

 * `node["kafka"]["server.properties"]["broker.id"]` : The id of broker running on the server
 * `node["kafka"]["server.properties"]["zookeeper.connect"]` : The Kafka configuration used to connect to Zookeeper

We do this mapping for you when you provide the `node["kafka"]["brokers"]` and `node["kafka"]["zookeepers"]`
attributes.

You can choose to provide the `server.properties` attribute instead of
`node["kafka"]["brokers"]` or `node["kafka"]["zookeepers"]`.

To map `node["kafka"]["brokers"]` to `node["kafka"]["server.properties"]["broker.id"]` correctly
all Chef nodes running the kafka recipe (and are part of the same Kafka cluster) must have the same list of
`node["kafka"]["brokers"]` and all broker hostnames must be in the same order. We determine the
`node["kafka"]["server.properties"]["broker.id"]` by using the index of Chef node's fqdn/hostname/ip in the
list as the `node["kafka"]["server.properties"]["broker.id"]`.

Additionally if you want to use a Zookeeper chroot with your kafka installation you can provide it by setting
`node["kafka"]["zookeeper_chroot"]`.

Using `node["kafka"]["brokers"]`, `node["kafka"]["zookeepers"]` and `node["kafka"]["zookeeper_chroot"]` attributes are
the recommended way to setup your kafka cluster in Chef.

### Updating from 1.X and 2.X of the Cookbook

There were some non-passive changes made during the upgrade to the 2.X version of
the cookbook. Specifically,

 * Removed a number of default kafka configs ([See here](https://github.com/cerner/cerner_kafka/commit/b5a382bd8f57af71d1fdaac693a5394d1c6e9ff2))
 * Updated defaults to install Kafka 0.9.0.0 (Scala 2.11)

Make sure to make the appropriate attribute changes if needed. Otherwise the
cookbook should work just as it did before.

Additionally in Kafka 0.9 broker's can be auto assigned broker ids. The cookbook
supports this feature. Make sure to keep the broker ids for existing nodes otherwise
they may drop their data.

### How to specify where to download kafka from and which version to install

This cookbook supports Kafka version `0.8.1.1` and above. The default attributes currently will install version `0.9.0.0` from
'https://archive.apache.org/dist/kafka'. This is configured using a number of different attributes in order to make it easier for you.

NOTE: If you are upgrading from `0.8.X` to `0.9.X` there are some [additional steps](http://kafka.apache.org/documentation.html#upgrade_9) to handle a rolling upgrade.

There are basically two ways to configure these settings. The first way is via 3 different attributes,

 * `node["kafka"]["scala_version"]` : The scala version number associated with the kafka installation (default="2.11")
 * `node["kafka"]["version"]` : The version number associated with the kafka installation (default="0.9.0.0")
 * `node["kafka"]["download_url"]` : The base url used to download Kafka (default="https://archive.apache.org/dist/kafka")

With these 3 attributes we build the full url of the form
`#{node["kafka"]["download_url"]}/#{node["kafka"]["version"]}/kafka_#{node["kafka"]["scala_version"]}-#{node["kafka"]["version"]}.tgz`.

This makes it easy to specify just a single change while still maintaining the rest of the URL.

The other option is to just provide the full URL itself,

 * `node["kafka"]["binary_url"]` : The full url used to download Kafka

 **NOTE** : If you specify the `node["kafka"]["binary_url"]` a valid and up to date `node["kafka"]["version"]` must also be provided as this is what we use to determine
 if a new version of kafka is specified.

### Configuring java for the server/broker

Currently the cookbook defaults to use the same [java settings](https://kafka.apache.org/documentation.html#java) that Linkedin recommends.

Kafka uses different environment variables to configure the java settings for the server/broker,

 * `KAFKA_JMX_OPTS` : The JMX settings (default="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false  -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=$JMX_PORT")
 * `JMX_PORT` : The port to run Kafka's JMX on (default=9999)
 * `KAFKA_LOG4J_OPTS` : The log4j settings (default="-Dlog4j.configuration=file:$base_dir/../config/log4j.properties")
 * `KAFKA_HEAP_OPTS` : The options used to control Kafka's Heap (default="-Xmx4G -Xms4G")
 * `KAFKA_JVM_PERFORMANCE_OPTS` : The options used to control JVM performance settings (default="-XX:PermSize=48m -XX:MaxPermSize=48m -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35")
 * `KAFKA_GC_LOG_OPTS` : The options used to control GC logs (default="-Xloggc:$LOG_DIR/$GC_LOG_FILE_NAME -verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps")
 * `KAFKA_OPTS` : Used for any generic JVM settings (default="" if `node["kafka"]["kerberos"]["enable"]`=`false`, or "-Djava.security.auth.login.config=`node["kafka"]["install_dir"]`/config/jaas.conf" if `node["kafka"]["kerberos"]["enable"]`=`true`)

You can customize these environment variables (as well as any environment variable for the kafka user) using the
attribute,

 * `node["kafka"]["env_vars"]` : A hash of environment variable names to their values to be set for the kafka user

### Enabling Kerberos authentication

The cookbook supports enabling [Kerberos authentication for the broker](http://kafka.apache.org/090/documentation.html#security_sasl) by setting `node["kafka"]["kerberos"]["enable"]` to `true`.

When enabled, two additional attributes are required,

* `node["kafka"]["kerberos"]["keytab"]` - the Kerberos keytab file location
* `node["kafka"]["kerberos"]["realm"]` - the Kerberos realm (or `node["kafka"]["kerberos"]["principal"]` to use a custom Kerberos user principal)

The principal creation and keytab deployment are prerequisites not handled by this cookbook.

ZooKeeper client authentication can additionally be enabled by setting `node["kafka"]["kerberos"]["enable_zk"]` to `true`.

Custom Krb5LoginModule options can be set using the `node["kafka"]["kerberos"]["krb5_properties"]` attribute hash for Kafka,
or `node["kafka"]["kerberos"]["zk_krb5_properties"]` for ZooKeeper (see attributes file for defaults).

The cookbook supports setting up both Kafka brokers and KafkaOffsetMonitor for kerberos.

Note that enabling Kerberos for a Kafka broker does not automatically set any
configuration into `server.properties`. The following properties should be evaluated
for relevance and configured separately as needed.

* `listeners`
* `sasl.enabled.mechanisms`
* `sasl.kerberos.kinit.cmd`
* `sasl.kerberos.min.time.before.relogin`
* `sasl.kerberos.principal.to.local.rules`
* `sasl.kerberos.service.name`
* `sasl.kerberos.ticket.renew.jitter`
* `sasl.kerberos.ticket.renew.window.factor`
* `sasl.mechanism.inter.broker.protocol`
* `security.inter.broker.protocol`

### Dynamically Assigned Broker IDs

In Kafka 0.9 or higher a broker ID can be dynamically assigned using zookeeper. Kafka  
likes to use these IDs in its log messages so its helpful to have something to
translate. Previously the broker ids were provided as Chef attributes either setting
it manually `node['kafka']['server.properties']['broker.id']` or using the
`node['kafka']['brokers']` property which would set the broker id property.

We've added in logic to fetch the broker id from the meta file if the broker id
is not provided by either of those methods so its possible to translate broker
ids to host names using Chef. The broker id will be available in the
`node['kafka']['broker_id']` attribute.

Consumer Offset Monitor
-----------------------

The `kafka::offset_monitor` recipe will install the Kafka Consumer Offset Monitor application, which provides a
web UI for monitoring various aspects of your Kafka cluster, including consumer processing lag.

This recipe shares several attributes with the default recipe:

 * `node["kafka"]["zookeepers"]` (required)
 * `node["kafka"]["user"]`
 * `node["kafka"]["group"]`
 * `node["kafka"]["base_dir"]`
 * `node["kafka"]["log_dir"]`

The offset monitor application is installed to `node["kafka"]["offset_monitor"]["install_dir"]`
(defaults to `node["kafka]["base_dir"]/KafkaOffsetMonitor`). The application download URL is controlled by
the `node["kafka"]["offset_monitor"]["url"]` attribute.

The offset monitor maintains an SQLite database comparing the latest Kafka broker offset for each
topic partition to the latest offset persisted in Zookeeper for each consumer group. The database file
(`node["kafka"]["offset_monitor"]["db_name"]`.db) is written to the kafka user's home directory. The monitoring
refresh interval and retention period are configurable by the attributes `node["kafka"]["offset_monitor"]["refresh"]`
and `node["kafka"]["offset_monitor"]["retain"]` using `scala.concurrent.duration.Duration` syntax (for example
"60.seconds" or "30.days").

The offset monitor web application listens on port 8080 by default. The port is configurable by setting the
`node["kafka"]["offset_monitor"]["port"]` attribute in the event that a conflicting service is already using port
8080.

This recipe is not included by the default recipe. It can be added to any or all of the Kafka broker nodes,
or a separate node or VM. Each instance of the offset monitor will collect an identical complete data set
for the entire Kafka cluster regardless of where it is installed, other than minor variances due to refresh interval
asynchronicities.

This recipe creates a service which can be used to start/stop/restart the offset monitor java process,

    service kafka-offset-monitor [start|stop|restart|status]

Log files are written to `kafka-offset-monitor.log` in `node["kafka"]["log_dir"]` (defaults to /var/log/kafka).

Attributes
----------

 * `node["kafka"]["brokers"]` : An array of the list of brokers in the Kafka cluster. This should even include the node running the recipe. (default=[])
 * `node["kafka"]["zookeepers"]` : An array of the list of Zookeepers that Kafka uses. (default=[])
 * `node["kafka"]["zookeeper_chroot"]` : A string representing the Zookeeper chroot to use for Kafka. (default=nil)
 * `node["kafka"]["user"]` : The name of the user used to run Kafka (default="kafka")
 * `node["kafka"]["group"]` : The name of the group the user running Kafka is associated with (default="kafka")
 * `node["kafka"]["openFileLimit"]` : The open file limit for the user running the Kafka service (default=32768)
 * `node["kafka"]["maxProcesses"]` : The max processes allowed for the user running the Kafka service (default=1024)
 * `node["kafka"]["scala_version"]` : The scala version number associated with the kafka installation (default="2.9.2")
 * `node["kafka"]["version"]` : The version number associated with the kafka installation (default="0.8.1.1")
 * `node["kafka"]["download_url"]` : The base url used to download Kafka. Uses this and `node["kafka"]["scala_version"]` as well as `node["kafka"]["version"]` to build the full url. (default="https://archive.apache.org/dist/kafka")
 * `node["kafka"]["binary_url"]` : The full url used to download Kafka. (default=`#{node["kafka"]["download_url"]}/#{node["kafka"]["version"]}/kafka_#{node["kafka"]["scala_version"]}-#{node["kafka"]["version"]}.tgz`)
 * `node["kafka"]["base_dir"]` : This is the directory that contains the current installation as well as every other installation (default="/opt")
 * `node["kafka"]["install_dir"]` : This is the directory of the current installation (default=`node["kafka"]["base_dir"]`/kafka)
 * `node["kafka"]["log_dir"]` : The directory of the log files for Kafka. Not Kafka's message/log data but debug logs from the server. (default="/var/log/kafka")
 * `node["kafka"]["broker_id"]` : The Kafka's broker id. This is generated by the cookbook
 * `node["kafka"]["shutdown_timeout"]` : The init.d script shutdown timeout in seconds. Adjust as needed based on cluster size (in terms of partitions) and required shutdown time. This attribute has been DEPRECATED. Use `node["kafka"]["init"]["shutdown_timeout"]` instead. (default=30)
 * `node["kafka"]["init"]["shutdown_timeout"]` : The init.d script shutdown timeout in seconds. Adjust as needed based on cluster size (in terms of partitions) and required shutdown time. (default=`node["kafka"]["shutdown_timeout"]`)
 * `node["kafka"]["init"]["sleep_between_restart"]` : How long if any the init script should sleep (in seconds) after stop and before start (default=0)
 * `node["kafka"]["init"]["kafka_main"]` : The name of the Kafka process to look for in the init script (default=`kafka.Kafka`)
 * `node["kafka"]["init"]["stop_sleep_time"]` : How long we should sleep for (in seconds) during stop before checking if Kafka has stopped yet (default=5)
 * `node["kafka"]["env_vars"]` : A hash of environment variable names to their values to be set for the kafka user. This can be used to customize the server memory settings. (default={})
 * `node["kafka"]["lib_jars"]` : A list of URLs to install a jar in `#{node["kafka"]["install_dir"]}/libs`. (default=[])
 * `node["kafka"]["server.properties"][*]` : A key/value that will be set in server's properties file. Used to customize the broker configuration. (default=`{}` See [Kafka doc](http://kafka.apache.org/documentation.html#brokerconfigs) for Kafka defaults)
 * `node["kafka"]["log4j.properties"][*]` : A key/value that will be set in the server's log4j.properties file. (for defaults see attributes file)
 * `node["kafka"]["offset_monitor"]["url"]` The download url for the offset monitor (default = "https://github.com/quantifind/KafkaOffsetMonitor/releases/download/v0.2.0/KafkaOffsetMonitor-assembly-0.2.0.jar")
 * `node["kafka"]["offset_monitor"]["install_dir"]` : The installation directory for the offset monitor (default = `node["kafka]["base_dir"]`/KafkaOffsetMonitor)
 * `node["kafka"]["offset_monitor"]["main_class"]` : The main class for the offset monitor (default = "com.quantifind.kafka.offsetapp.OffsetGetterWeb")
 * `node["kafka"]["offset_monitor"]["port"]` = The port used by the offset monitor web application (default = 8080)
 * `node["kafka"]["offset_monitor"]["refresh"]` : How often the offset monitor refreshes and stores a point in the DB, in `value`.`unit` format (default = "15.minutes")
 * `node["kafka"]["offset_monitor"]["retain"]` : How long the offset monitoring data is kept in the DB, in `value`.`unit` format (default = "7.days")
 * `node["kafka"]["offset_monitor"]["db_name"]` : The base file name for the offset monitoring database file written into the kafka user's home directory (default = "offset_monitor")
 * `node["kafka"]["offset_monitor"]["java_options"]` : A Hash representing the java options to be used with the offset monitor. All key/values will be combined together as `key + value`. (See attributes file for defaults)
 * `node["kafka"]["offset_monitor"]["include_log4j_jar"]` : A boolean indicating if we should include the log4j jar in the offset monitor's classpath (default=`true`)
 * `node["kafka"]["offset_monitor"]["log4j.properties"]` : Hash of log4j settings for the offset monitor (See attributes file for defaults)
 * `node["kafka"]["offset_monitor"]["options"]` : A hash of options to be supplied to command to run offset monitor (see attributes file for defaults)
 * `node["kafka"]["service"]["stdout"]` : The file to keep std output of kafka init service (default = "/dev/null")
 * `node["kafka"]["service"]["stderr"]` : The file to keep std error of kafka init service (default = "/dev/null")
 * `node["kafka"]["kerberos"]["enable"]` A boolean indicating if Kerberos authentication should be enabled (default = false)
 * `node["kafka"]["kerberos"]["enable_zk"]` : A boolean indicating if ZooKeeper client authentication should also be enabled, only applies if `node["kafka"]["kerberos"]["enable"]` = `true` (default = false)
 * `node["kafka"]["kerberos"]["keytab"]` : the Kerberos keytab file location (default = nil)
 * `node["kafka"]["kerberos"]["realm"]` : the Kerberos realm (default = nil)
 * `node["kafka"]["kerberos"]["principal"]` : the Kerberos user principal (default=`node["kafka"]["user"]`/`node["fqdn"]`@`node["kafka"]["kerberos"]["realm"]`)
 * `node["kafka"]["kerberos"]["krb5_properties"]` : A hash of options for the Krb5LoginModule for Kafka (see attributes file for defaults)
 * `node["kafka"]["kerberos"]["zk_krb5_properties"]` : A hash of options for the Krb5LoginModule for ZooKeeper (see attributes file for defaults)

Testing
-------

We have provided some simple integration tests for testing the cookbook.

### How to run tests

To run the tests for this cookbook you must install [ChefDK](https://downloads.chef.io/chef-dk/).

The unit tests are written with [rspec](http://rspec.info/) and [chefspec](https://github.com/sethvargo/chefspec).
They can be run with `rspec`.

The lint testing uses [Foodcritic](http://www.foodcritic.io/) and can be run with `foodcritic . -f any`.

The integration tests are written with [test-kitchen](http://kitchen.ci/) and [serverspec](http://serverspec.org/).
They can be run with `kitchen test`.

Contributing
------------

This project is licensed under the Apache License, Version 2.0.

When contributing to the project please add your name to the CONTRIBUTORS.txt file. Adding your name to the CONTRIBUTORS.txt file
signifies agreement to all rights and reservations provided by the License.

To contribute to the project execute a pull request through github. The pull request will be reviewed by the community and merged
by the project committers. Please attempt to conform to the test, code conventions, and code formatting standards if any
are specified by the project before submitting a pull request.

Releases
--------

Releases should happen regularly after most changes. Feel free to request a release by logging an issue.

Committers
----------

For information related to being a committer check [here](COMMITTERS.md).

LICENSE
-------

Copyright 2013 Cerner Innovation, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0) Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
