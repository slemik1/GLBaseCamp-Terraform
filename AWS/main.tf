provider "aws" {
 region     = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name   = "nginx-vpc"
  cidr   = "10.0.0.0/16"

  azs             = var.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_ipv6 = true

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "ubuntu_nginx_1" {
    ami                    = "ami-0502e817a62226e03"
    instance_type          = "t2.micro"
    subnet_id = module.vpc.private_subnets[0]
    vpc_security_group_ids = [aws_security_group.Terraform_Nginx.id]
    user_data = <<EOF
#!/bin/bash
sudo apt-get update -y
sudo apt-fet install nginx -y
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h2>WebServer with IP: $myip</h2><br>Build by Terraform!" > /var/www/html/index.html
sudo service nginx start
chkconfig nginx on
EOF

    tags = {
        Name     = "AWS_Ubuntu_Nginx_1"
        Owner    = "Alex Keilin"
        Prodject = "Terraform_Nginx"
    }
}

resource "aws_instance" "ubuntu_nginx_2" {
    ami           = "ami-0502e817a62226e03"
    instance_type = "t2.micro"
    subnet_id = module.vpc.private_subnets[1]
    vpc_security_group_ids = [aws_security_group.Terraform_Nginx.id]
    user_data = <<EOF
#!/bin/bash
sudo apt-get update -y
sudo apt-fet install nginx -y
myip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
echo "<h2>WebServer with IP: $myip</h2><br>Build by Terraform!" > /var/www/html/index.html
sudo service nginx start
chkconfig nginx on
EOF

    tags = {
        Name     = "AWS_Ubuntu_Nginx_2"
        Owner    = "Alex Keilin"
        Prodject = "Terraform_Nginx"
    }
}

resource "aws_security_group" "Terraform_Nginx" {
  name        = "Terraform_Nginx_Security_groop"
  description = "security groop from nginx"

  ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}