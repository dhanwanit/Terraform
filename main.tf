terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  
}
# Creating VPC
resource "aws_vpc" "terraform_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-vpc"
  }
}

# Creating IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "Prod-ig1"
  }
}

# Creating Route Table

resource "aws_route_table" "Prod-route1" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# Creating a subnet
resource "aws_subnet" "Prod-subnet1" {
    vpc_id = aws_vpc.terraform_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-northeast-1a"
  
}

#Assosiate Route table to subnet

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Prod-subnet1.id
  route_table_id = aws_route_table.Prod-route1.id
}

# Create a security Group

resource "aws_security_group" "allow_http" {
  name        = "allow Web traffic"
  description = "Allow http ssh inbound traffic"
  vpc_id      = aws_vpc.terraform_vpc.id

    ingress {
    description      = "Http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
 
  }


  tags = {
    Name = "Allow_web"
  }
}

resource "aws_security_group_rule" "public_in_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_http.id
}
resource "aws_security_group_rule" "public_in_Https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_http.id
}

#Network Interface
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.Prod-subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_http.id]
}
# Elastic ip creation
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}
# Lanuch Instance
resource "aws_instance" "Web" {
  ami = "ami-088da9557aae42f39"
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-1a"
  key_name = "AwsDevops"
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.test.id

  }
  user_data = <<EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get upgrade -y
                sudo apt-get install apache2 -y
                sudo systemctl enable apache2 --now
                sudo bash -c "echo Your First IAC Web sever > /var/www/html/index.html"
                EOF
  tags = {
    "Name" = "Prod-Ec2"
  }
}