provider "aws" {
 region     = var.region
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name   = "nginx-vpc"
  cidr   = "172.31.0.0/16"

  azs             = var.azs
  private_subnets = ["172.31.1.0/24", "172.31.2.0/24"]
  public_subnets  = ["172.31.101.0/24", "172.31.102.0/24"]

  enable_ipv6 = true

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"

  name = "elb-example"

  subnets         = ["module.vpc.private_subnets[0]", "module.vpc.private_subnets[1]"]
  security_groups = [aws_security_group.Terraform_Nginx.id]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
    {
      instance_port     = "80"
      instance_protocol = "http"
      lb_port           = "80"
      lb_protocol       = "http"
    },
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  access_logs = {
    bucket = "my-access-logs-bucket"
  }

  // ELB attachments
  number_of_instances = 2
  instances           = ["aws_instance.ubuntu_nginx_1.id", "aws_instance.ubuntu_nginx_2.id"]

  tags = {
    Owner       = "Alex Keilin"
  }
}

resource "aws_instance" "ubuntu_nginx_1" {
    ami                    = "ami-0502e817a62226e03"
    instance_type          = "t2.micro"
    subnet_id = module.vpc.private_subnets[0]
    vpc_security_group_ids = [aws_security_group.Terraform_Nginx.id]
    user_data = <<EOF
#!/bin/bash
sudo apt-get -y update
sudo apt-get -y install nginx
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
sudo apt-get -y update
sudo apt-get -y install nginx
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
