terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}

###############  Wordpress VPC    #################
resource "aws_vpc" "wordpress_vpc" {
  cidr_block = var.vpc_cider_block

  tags = {
    Name = "wordpress_vpc"
  }
}

########  Wordpress Subnets    ##########
resource "aws_subnet" "wordpress_pub_sub_1" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = var.pub_sub_1
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_pub_sub_1"
  }
}

resource "aws_subnet" "wordpress_pub_sub_2" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = var.pub_sub_2
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_pub_sub_2"
  }
}

resource "aws_subnet" "wordpress_pub_sub_3" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = var.pub_sub_3
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_pub_sub_3"
  }
}

resource "aws_subnet" "wordpress_priv_sub_1" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = var.priv_sub_1
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_priv_sub_1"
  }
}

resource "aws_subnet" "wordpress_priv_sub_2" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = var.priv_sub_2
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_priv_sub_2"
  }
}

resource "aws_subnet" "wordpress_priv_sub_3" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = var.priv_sub_3
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "wordpress_priv_sub_3"
  }
}

##############   Wordpress-ec2 security group with port 80, 443 , 22 open   ###############
resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress_sg"
  description = "Security group for wordpress-ec2"
  vpc_id      = aws_vpc.wordpress_vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "wordpress_sg"
  }
}

#####################  RDS SG ###################################
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.wordpress_vpc.id

  tags = {
    Name = "rds-sg"
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "nat_eip" {

}

############## Nat gw ####################
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.wordpress_pub_sub_1.id
}

############## IGW  #######################
resource "aws_internet_gateway" "wordpress_igw" {
  vpc_id = aws_vpc.wordpress_vpc.id

  tags = {
    Name = "wordpress_igw"
  }
}

########### Wordpress rt ######################
resource "aws_route_table" "wordpress_rt" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress_igw.id
  }
  tags = {
    Name = "wordpress_rt"
  }
}

########## Private rt ###################
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "wordpress_rt"
  }
}

########### Subnet association ########################
resource "aws_route_table_association" "tf-rt-ass-a" {
  subnet_id      = aws_subnet.wordpress_pub_sub_1.id
  route_table_id = aws_route_table.wordpress_rt.id
}

resource "aws_route_table_association" "tf-rt-ass-b" {
  subnet_id      = aws_subnet.wordpress_priv_sub_1.id
  route_table_id = aws_route_table.private_rt.id
}

########   SSH key   ####################
resource "aws_key_pair" "ssh_key" {
  key_name   = var.key_name
  public_key = file("~/.ssh/ssh_key.pub")
}

###############   Create wordpress ec2   ##################
resource "aws_instance" "wordpress_ec2" {
  ami                         = var.linux_2_image_id
  instance_type               = var.ec2_type
  vpc_security_group_ids      = [aws_security_group.wordpress_sg.id]
  key_name                    = aws_key_pair.ssh_key.id
  subnet_id                   = aws_subnet.wordpress_pub_sub_1.id
  user_data                   = file("script.tpl")
  associate_public_ip_address = true


  tags = {
    Name = "wordpress_ec2"
  }
}

############ Db subnet group  #############
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db subnet group"
  subnet_ids = [aws_subnet.wordpress_priv_sub_1.id, aws_subnet.wordpress_priv_sub_2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

################ Create RDS DB Instance  ####################
resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  storage_type         = var.storage_type
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  identifier           = var.identifier
  username             = var.username
  password             = var.password
  parameter_group_name = var.parameter_group_name

  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

