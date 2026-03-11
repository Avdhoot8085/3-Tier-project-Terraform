
provider "aws" {
  region = var.region_name
}

# create a VPC.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  tags = {
    Name = "my-vpc"
  }
}
# create a public subnet.
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_cidr
 availability_zone = var.availability
  map_public_ip_on_launch = true

  tags = {
    Name = "my-subnet-1"
  }
}

# create a private subnet.
resource "aws_subnet" "subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_cidr

  tags = {
    Name = "my-subnet-2"
  }
}

# create a Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-IG"
  }
}

# Create a Route table
resource "aws_route_table" "route" {
    vpc_id = aws_vpc.main.id
    tags = {
    Name = "my-route_table"
  }
  
}
# Route table is route
resource "aws_route" "public_route" {
    route_table_id = aws_route_table.route.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id 
}

# Route table is association to subnet.
resource "aws_route_table_association" "associate" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route.id
}

# create a security group.
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Tomcat Access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}
resource "aws_eip" "lb" {
  instance = aws_instance.jume.id
  domain   = "vpc"
}
resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.subnet_1.id

  tags = {
    Name = "gw NAT"
  }
  depends_on = [aws_internet_gateway.gw.id]
}

# Create a Jume server
resource "aws_instance" "jume" {
    ami = var.jume_server_ami
    instance_type =var.jume_server_instance_type
    subnet_id = aws_subnet.subnet_1.id
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    key_name = var.jume_server_key
    tags = {
    Name = "Jume_server"
  }
  user_data = <<-EOF
              #!/bin/bash
              curl -o https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz
              tar -xzvf apache-tomcat-9.0.115.tar.gz -C /opt
              cd /opt/apache-tomcat-9.0.115/bin
              yum install java -y
              ./catalina.sh start
              cd /opt/apache-tomcat-9.0.115/webapps
              curl -o https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war
              mv student.war /opt/apache-tomcat-9.0.115/webapps
              EOF
}

# Create a application server.
resource "aws_instance" "application_server" {
    ami = var.application_server-ami
    instance_type = var.application_server_instance_type
    subnet_id = aws_subnet.subnet_2.id
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    key_name = var.application_server_key
    tags = {
    Name = "Application_server"
  }
  
}