#!/bin/bash

sudo yum update -y
sudo amazon-linux-extras install nginx1.12 -y

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/cert.key -out /etc/nginx/cert.crt -subj '/C=IE/ST=Dublin/L=Dublin/CN=example.com'

sudo aws s3 cp s3://es-cognito-poc-bucket/nginx.conf /etc/nginx/nginx.conf

systemctl restart nginx
