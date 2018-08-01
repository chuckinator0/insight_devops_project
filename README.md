# Larrieu_IaC_CM_project
Infrastructure as Code and Configuration Management Project

## Project Idea
I'd like to develop a system for automatic recovery given a server failure. My focus is on what happens after a server fails. The goal is to use infrastructure as code and configuration management to automatically recover from server failure. To do this, I will need use a pipeline that focuses on processing data that is rapidly streaming in. I have decided to build on an [existing pipeline](https://github.com/hongtao510/SmartMoneyTracker) developed by Hong Tao that analyzes unusual activity in options trading.

## Purpose and Common Uses
Failure is a fact of life. According to the book "Designing Data Intensive Applications," human error in configuration is a leading cause of outages. The more of the configuration process that can be automated, the more resilient a system will be in response to failure. Automatic recovery is a part of a strategy to maximize reliability, ultimately saving .

## Technologies
+ Honeycomb--monitor the system to tell that it has failed
+ Chef or Puppet for configuration management
+ Terraform--initialize the infrastructure of the system and deploy docker images. The immutable nature helps to version control infrastructure, so failures caused by infrastructure changes can be rolled back to known, functioning infrastructures.
+ Chaos Monkey--cause failures on purpose
+ Some kind of logging technology: send logs of failed server to storage for later analysis (?)

## Proposed Architecture
The underlying data pipeline from Hong Tao is Kafka->Spark Streaming->Cassandra->Flask. I don't need the Flask part that creates a visualization website. Chaos Monkey may be useful in causing random failures. Honeycomb will allow me to monitor that the system has failed. Terraform and Ansible will help to restart and reconfigure failed servers automatically.

## Ballpark Data Metrics
This pipeline should provide a large throughput, perhaps greater than 1000 writes per second. This number could spike dramatically in order to cause a failure in the streaming engine.

## Questions
+ How can I get Hong Tao's data from S3?
