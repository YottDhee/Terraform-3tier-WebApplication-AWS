terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region =var.aws_region
}

# Create a VPC in AWS region
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "3tier-TF-VPC"
  }
}

# Create the Subnets in VPC
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "TF-Public-Web-Subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "TF-Public-Web-Subnet-2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "TF-Private-App-Subnet"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "TF-Private-DB-Subnet"
  }
}

# Create the Internet Gateway in VPC
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "TF-IGW-web"
  }
}

# Allocate an Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  depends_on = [aws_internet_gateway.my_igw]

  tags = {
    Name = "NAT-EIP"
  }
}

# Create the NAT Gateway in a Public Subnet
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id

  tags = {
    Name = "My-NAT-Gateway"
  }

  depends_on = [aws_internet_gateway.my_igw]
}

# Create the Route Table and Associate for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
  tags = {
    Name = "TF-Public-RT"
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Create the Route Table and Associate for Private Subnets
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }
  tags = {
    Name = "TF-Private-RT"
  }
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Create the Security Groups for all tiers
resource "aws_security_group" "ext_alb_sg" {
  name        = "ext-alb-security-group"
  description = "Security group for External ALB"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "TF-ExternalALBSG"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-security-group"
  description = "Security group for webpage servers"
  vpc_id = aws_vpc.my_vpc.id

  # Allow HTTP (80) for public access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere (public access)
  }

  # Allow HTTP (5000) for traffic from External ALB
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.ext_alb_sg.id]  # Reference ALB security group
  }

  # Allow SSH (22) only from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["223.185.132.230/32"]  # Your public IP
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TF-WEBAPPSG"
  }
}

resource "aws_security_group" "int_alb_sg" {
  name        = "int-alb-security-group"
  description = "Security group for Internal ALB"
  vpc_id = aws_vpc.my_vpc.id

  # Allow HTTP traffic from NGINX (web tier)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id]  # Allow only from web tier
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TF-INTERNALALBSG"
  }
}

resource "aws_security_group" "app_sg" {
  name        = "app-security-group"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    security_groups = [aws_security_group.int_alb_sg.id]  # Allow only from ALB
  }

  ingress {
    from_port       = 4000
    to_port         = 4000
    protocol        = "tcp"
    cidr_blocks = ["223.185.132.230/32"]  # Allow only from ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "TF-APPSG"
  }
}

resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]  # Allow only from App Layer
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the AWS Instance for both Web and App tiers
resource "aws_instance" "Web" {
  ami             = "ami-08b5b3a93ed654d19"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.public_subnet_1.id
  security_groups = [aws_security_group.web_sg.id]  
  key_name        = var.key_name
  tags = {
    Name = "public-TF-Web"
  }
  user_data     =  <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
  EOF
}

resource "aws_instance" "App" {
  ami             = "ami-08b5b3a93ed654d19"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.private_subnet_1.id
  security_groups = [aws_security_group.app_sg.id]  
  key_name        = var.key_name
  tags = {
    Name = "private-TF-app"
  }
  user_data     =  <<-EOF
    #!/bin/bash
    sudo yum update -y
    curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
    yum install -y nodejs git
    mkdir /home/ec2-user/backendApp
    cd /home/ec2-user/backendApp
    sudo npm install
    sudo nohup node server.js > output.log 2>&1 &
  EOF
}

# Create the AWS Application LoadBalancers for both tiers
resource "aws_lb" "external_alb" {
  name               = "external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ext_alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  enable_deletion_protection = false
  tags = {
    Name = "TF-External-ALB"
  }
}

resource "aws_lb_target_group" "external_alb_tg" {
  name     = "external-alb-tg-${random_string.suffix.result}"  # Unique name
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = {
    Name = "TF-External-ALB-TG"
  }
}

resource "aws_lb_listener" "external_alb_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_alb_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "external_alb_attachment" {
  target_group_arn = aws_lb_target_group.external_alb_tg.arn
  target_id        = aws_instance.Web.id
  port             = 5000
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_lb" "internal_alb" {
  name               = "InternalALB"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.int_alb_sg.id]
  subnets            = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags = {
    Name = "TF-InternalALB"
  }
}

resource "aws_lb_target_group" "ILB_tg" {
  name     = "ILB-tg-${random_string.suffix.result}"  # Unique name to avoid conflicts
  port     = 4000
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path                = "/"  # Ensure your app responds here with 200 OK
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher             = "200"
  }
  tags = {
    Name = "TF-ILB-TargetGroup"
  }
}

resource "aws_lb_listener" "internal_alb_listener" {
  load_balancer_arn = aws_lb.internal_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ILB_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "ILB_target_attachment" {
  target_group_arn = aws_lb_target_group.ILB_tg.arn
  target_id        = aws_instance.App.id
  port             = 4000
}

# Add this if not already present in your config
resource "random_string" "suffix_int" {
  length  = 8
  special = false
  upper   = false
}

# Create the AWS RDS for DB tier
resource "aws_db_instance" "my_rds" {
  identifier             = "terraform-rds"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.35"  # Use a supported version
  instance_class         = "db.t2.micro"  
  username              = var.db_username
  password              = var.db_password
  publicly_accessible   = false
  skip_final_snapshot   = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name  = aws_db_subnet_group.my_subnet_group.name
}

resource "aws_db_subnet_group" "my_subnet_group" {
  name       = "my-subnet-group-1"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  tags = {
    Name = "Terraform-DB-Subnet-Grp1"
  }
}

data "aws_s3_bucket" "tf3tierbucket" {
  bucket = "tf3tierbucket"
}


resource "aws_s3_bucket_website_configuration" "tf3tierbucket_website" {
  bucket = data.aws_s3_bucket.tf3tierbucket.id

  index_document {
    suffix  = "index.html"
  }
}
