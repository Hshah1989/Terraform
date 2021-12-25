# configure the aws environment and region
provider "aws" {
  region = "us-east-1"
  access_key = "AKIAS66PEWG3IDN3JWFH"
  secret_key = "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"
}

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
      Name = "production"
  }
}

# create a IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
  }

# create a route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block    = "::/0"
    gateway_id         = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

#create a subnet
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "prod-subnet"
    }
}

# associate route table with the subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# create a security group for only the protocols that you need
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

# allows tcp traffic from anywhere 
  ingress {
    description      = "HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    ingress {
    description      = "HTTP traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    ingress {
    description      = "SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# set up a NIC with an IP in the subnet created
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# create a elastic IP so everyone can access
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
  }

# create a Ubuntu server and intsall apache

resource "aws_instance" "web-server-instance" {
  ami = "ami-0e472ba40eb589f49"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key-terraform"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Merry Christmas everyone! > /var/www/html/index.html'
              EOF
    tags = {
        Name = "web-server"
    }
}