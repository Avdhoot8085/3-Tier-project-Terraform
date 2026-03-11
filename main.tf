
provider "aws" {
  region = var.region_name
}

# create a VPC.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "my-vpc"
  }
}
# create a public subnet.
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_cidr
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "my-subnet-1"
  }
}

# create a private subnet.
resource "aws_subnet" "subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_cidr
  availability_zone = "ap-south-1a"

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
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
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
resource "aws_eip" "eip" {
  domain   = "vpc"
  tags = {
    Name = "my-eip"
  }
}
resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet_1.id
  tags = {
    Name = "gw NAT"
  }
  depends_on = [aws_internet_gateway.gw]
}


# Create a Jume server
resource "aws_instance" "jume" {
    ami = var.jume_server_ami
    instance_type =var.jume_server_instance_type
    subnet_id = aws_subnet.subnet_1.id
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    key_name = var.jume_server_key
    tags = {
    Name = "web_server"
  }
 user_data = <<-EOF
    #!/bin/bash
    yum install java -y
    curl -O https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz
    tar -xzvf apache-tomcat-9.0.115.tar.gz -C /opt
    /opt/apache-tomcat-9.0.115/bin/./catalina.sh start
    cd /opt/apache-tomcat-9.0.115/webapps/
    curl -O https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war
    FILE="/opt/tomcat/conf/context.xml"
    sed -i '$i <Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource" maxTotal="500" maxIdle="30" maxWaitMillis="1000" username="arya" password="Aryakadam47" driverClassName="com.mysql.jdbc.Driver" url="jdbc:mysql://${aws_db_instance.mydb.endpoint}:3306/studentapp?useUnicode=yes&characterEncoding=utf8"/>' $FILE
    /opt/apache-tomcat-9.0.115/bin/./catalina.sh stop
    /opt/apache-tomcat-9.0.115/bin/./catalina.sh start
    
    EOF
}

# create a RDS database instance.
resource "aws_db_instance" "mydb" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t4g.micro"
  username             = "admin"
  password             = "admin123"
  db_subnet_group_name = aws_subnet.subnet_2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
}
resource "aws_db_subnet_group" "db_subnet" {
  name       = "main"
  # vpc_id      = aws_vpc.main.id
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  

  tags = {
    Name = "DB subnet group"
  }
}

# Create a database server.
resource "aws_instance" "application_server" {
    ami = var.application_server_ami
    instance_type = var.application_server_instance_type
    subnet_id =aws_db_subnet_group.db_subnet.id
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    key_name = var.application_server_key
    tags = {
    Name = "DB-server"
  }
  user_data = <<-EOF
              #!/bin/bash
              yum install mariadb105* -y
              systemctl start mariadb.service
              systemctl enable mariadb.service
              mysql -h ${aws_db_instance.mydb.endpoint} -u admin -padmin123
              create database studentapp;
              use studentapp;
              CREATE TABLE if not exists students(student_id INT NOT NULL AUTO_INCREMENT,
	            student_name VARCHAR(100) NOT NULL,
              student_addr VARCHAR(100) NOT NULL,
  	          student_age VARCHAR(3) NOT NULL,
	            student_qual VARCHAR(20) NOT NULL,
	            student_percent VARCHAR(10) NOT NULL,
  	          student_year_passed VARCHAR(10) NOT NULL,
	            PRIMARY KEY (student_id)
	            );


              EOF
}