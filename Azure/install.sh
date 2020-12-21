#!/bin/bash
sudo apt-get update -y
sudo apt-fet install nginx -y
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h2>WebServer with IP: $myip</h2><br>Build by Terraform!" > /var/www/html/index.html
sudo service nginx start
chkconfig nginx on