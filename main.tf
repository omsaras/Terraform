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
  region = "ap-southeast-2"
  # if mac/linux, profile is located at ~/.aws/config and ~/.aws/credentials
  # if windows then C:/users/{user}/.aws/config
  profile = "TerraformProfile"
}

locals {
  common_tags={
    Environment = "Dev"
    Team = "Terraform"
  }
}

variable "ami_machine_ubuntu" {
  type = string
  default = "ami-076fe60835f136dc9"
  description = "Linux distribution - Ubuntu"
}

variable "master_machine_type" {
  type = string
  default = "t2.medium"
  description = "Master node: please refer to bla bla for min requirement"
  validation {
    condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
  }
}

# Create EC2 instance
resource "aws_instance" "master_node" {
  ami = var.ami_machine_ubuntu
  instance_type = "t2.medium"
  subnet_id = aws_subnet.subnet_public_2a.id
  associate_public_ip_address = true
  
  tags = merge(local.common_tags, {
    Name="k8s_master_node"
  }) 
}

resource "aws_instance" "workers_node" {
  count = 2
  ami = var.ami_machine_ubuntu
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet_public_2a.id
  associate_public_ip_address = true
  tags = merge(local.common_tags, {
    "Name"="k8s_worker_node_${count.index}"
  })
}

# Create security group for master node
# resource "aws_security_group" "sg_master_node" {
#   name        = "open_port_master"
#   description = "Allow required ports to be opened for kubernetes resources for inter communication"
#   vpc_id      = aws_vpc.sme_vpc.id

#   tags = {
#     Name = "master_node_port"
#   }
# }

# resource "aws_vpc_security_group_ingress_rule" "allow_master_ipv4" {
#   security_group_id = aws_security_group.allow_tls.id
#   cidr_ipv4         = aws_vpc.main.cidr_block
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }

# Create a VPC
resource "aws_vpc" "sme_vpc" {
  cidr_block = "10.0.0.0/24"

  tags = {
    "Name" = "sme_vpc"
  }
}

# create Subnets
resource "aws_subnet" "subnet_public_2a" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2a"
    cidr_block = "10.0.0.0/26"
    map_public_ip_on_launch = true

    tags = {
        "Name" = "subnet_public_2a"
        "Environment" = "dev"
    }
}

resource "aws_subnet" "subnet_private_2a" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2a"
    cidr_block = "10.0.0.64/26"

    tags = {
        "Name" = "subnet_private_2a"
        "Environment" = "dev"
    }
}

resource "aws_subnet" "subnet_public_2b" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2b"
    cidr_block = "10.0.0.128/26"
    map_public_ip_on_launch = true

    tags = {
        "Name" = "subnet_public_2b"
        "Environment" = "dev"
    }
}

resource "aws_subnet" "subnet_private_2b" {
    vpc_id = aws_vpc.sme_vpc.id
    availability_zone = "ap-southeast-2b"
    cidr_block = "10.0.0.192/26"

    tags = {
        "Name" = "subnet_private_2b"
        "Environment" = "dev"
    }
}

# create Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.sme_vpc.id

  tags = {
    "Name" = "IGW"
    "Environment" = "Dev"
  }
}

# create route table for public subnets
resource "aws_route_table" "rtb_igw" {
  vpc_id =  aws_vpc.sme_vpc.id
  # request coming from any IP should redirect to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    "Name" = "rtb_igw"
    "Environment" = "Dev"
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
    route_table_id = aws_route_table.rtb_nat.id
    subnet_id = aws_subnet.subnet_private_2a.id
}

resource "aws_route_table_association" "rtb_association_nat_2b" {
    route_table_id = aws_route_table.rtb_nat.id
    subnet_id = aws_subnet.subnet_private_2b.id
}
# ----------------------end route table association--------------------#

# create route table for private subnets
resource "aws_route_table" "rtb_nat" {
  vpc_id = aws_vpc.sme_vpc.id

  tags = {
    "Name" = "rtb_nat"
    "Environment" = "Dev"
  }
}

# create elastic IP to assign to NAT gateway 
# for private subnet in 2a availability zone
resource "aws_eip" "elastic_ip_nat_2a" {
   domain = "vpc"

   tags = {
     "Name" = "elastic_ip_nat_2a"
   }
}

# create elastic IP to assign to NAT gateway 
# for private subnet in 2b availability zone
resource "aws_eip" "elastic_ip_nat_2b" {
   domain = "vpc"

   tags = {
     "Name" = "elastic_ip_nat_2b"
   }
}

#create NAT in public subnet 
resource "aws_nat_gateway" "nat_2a" {
  allocation_id = aws_eip.elastic_ip_nat_2a.id
  subnet_id     = aws_subnet.subnet_private_2a.id

  tags = {
    "Name" = "nat_2a"
    "Environment" = "Dev"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.IGW]
}


#create NAT in public subnet 
resource "aws_nat_gateway" "nat_2b" {
  allocation_id = aws_eip.elastic_ip_nat_2b.id
  subnet_id     = aws_subnet.subnet_private_2b.id

  tags = {
    "Name" = "nat_2b"
    "Environment" = "Dev"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.IGW]
}