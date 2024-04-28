terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "sme_vpc" {
  cidr_block = "10.0.0.0/24"
}

# create Subnets
resource "aws_subnet" "subnet_public_2a" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2a"
    cidr_block = "10.0.0.0/26"
}

resource "aws_subnet" "subnet_private_2a" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2a"
    cidr_block = "10.0.0.64/26"
}

resource "aws_subnet" "subnet_public_2b" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2b"
    cidr_block = "10.0.0.128/26"
}

resource "aws_subnet" "subnet_private_2b" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2b"
    cidr_block = "10.0.0.192/26"
}

resource "aws_security_group" "subnet_sg_public_1a" {
  vpc_id = aws_subnet.subnet_public_1a.vpc_id

  ingress {
    cidr_blocks = [aws_subnet.subnet_public_1a.cidr_block]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
}

resource "aws_security_group" "subnet_sg_private_1a" {
  vpc_id = aws_subnet.subnet_public_1a.vpc_id

  ingress {
    cidr_blocks = [aws_subnet.subnet_public_1a.cidr_block]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
}

resource "aws_security_group" "subnet_sg_private" {
  vpc_id = aws_subnet.subnet_public_1a.vpc_id

  ingress {
    cidr_blocks = [aws_subnet.subnet_public_1a.cidr_block]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }
}

# create Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.sme_vpc.id
}

# create route table for public subnets
resource "aws_route_table" "rtb_igw" {
  vpc_id =  aws_vpc.sme_vpc.id
  # request coming from any IP should redirect to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW
  }
  # any request within VPC 
  route {
    cidr_block = "10.0.0.0/24"
    gateway_id = "local"
  }

  tags = {
    Name = "rtb_igw"
  }
}

# route table association
resource "aws_route_table_association" "rtb_association_igw_2a" {
    route_table_id = aws_route_table.rtb_igw.id
    subnet_id = aws_subnet.subnet_public_2a.id
}

resource "aws_route_table_association" "rtb_association_igw_2b" {
    route_table_id = aws_route_table.rtb_igw.id
    subnet_id = aws_subnet.subnet_public_2b.id
}

resource "aws_route_table_association" "rtb_association_nat_2a" {
    route_table_id = aws_route_table.rtb_igw.id
    subnet_id = aws_subnet.subnet_private_2a.id
}

resource "aws_route_table_association" "rtb_association_nat_2b" {
    route_table_id = aws_route_table.rtb_igw.id
    subnet_id = aws_subnet.subnet_private_2b.id
}
# ----------------------end route table association--------------------#

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.foo.id
  route_table_id = aws_route_table.bar.id
}

# create route table for private subnets
resource "aws_route_table" "rtb_nat" {
  vpc_id = aws_vpc.sme_vpc.id
}

# create route table association for private subnets
resource "aws_route_table_association" "route_table_association_private" {
    route_table_id = aws_route_table.private_route_table.id
}

# create route table association for public subnets
resource "aws_route_table_association" "route_table_association_public" {
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_elastic_ip" {
   
}

#create NAT in public subnet 
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.example.id
  subnet_id     = aws_subnet.example.id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.example]
}
