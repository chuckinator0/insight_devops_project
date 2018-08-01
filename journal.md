## Journal

This journal is my way of processing what I'm learning and archiving some steps that I might need in the future.

# Getting data into S3

I have a dropbox link to the data that will be used in the pipeline. Downloading the large file failed multiple times, and I got frustrated, so I figured out how to download the file into an EC2 instance and transfer the file to S3 storage.

First, ssh into the ec2 instance. Download the file directly to the EC2 instance using the download link:
``wget <download url>``
Install awscli (amazon's command line interface tool):
``sudo apt install awscli``
Then use the command 
``AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=xxxx aws s3 cp <file> s3://my-bucket/``
The ec2 instance doesn't have access to my local environment variables (I don't think...I would like clarification on how to pass these to the remote instance), so I had to put those in. The key commands here were:
``aws s3 cp <file> <bucket>``

# 