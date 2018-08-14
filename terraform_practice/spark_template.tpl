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
