#!/bin/bash
sudo yum update -y
sudo yum install -y java-17-amazon-corretto-devel 
sudo yum install -y tomcat
sudo systemctl start tomcat
sudo systemctl enable tomcat
