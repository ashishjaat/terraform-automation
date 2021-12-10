provider "aws" {
  region = "us-east-2"
  access_key = "XXXXXXXXXXXXXX"
  secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

resource "aws_vpc" "mySingaporeVPC" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prodVPC"
  }
}

resource "aws_internet_gateway" "mySingaporeIG" { 
  vpc_id     = aws_vpc.mySingaporeVPC.id
  tags = {
    Name = "SingaporeIG"
  }
}

resource "aws_route_table" "singaporeVPCRouteTable" {
  vpc_id = aws_vpc.mySingaporeVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mySingaporeIG.id
  } 

  tags = {
    Name = "Singapore VPC Route Table"
  }
}

resource "aws_subnet" "singaporevpcsubnet-1" {
  vpc_id     = aws_vpc.mySingaporeVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "singapore-vpc-subnet"
  }
}

resource "aws_route_table_association" "subnetroutetableassociation" {
  subnet_id      = aws_subnet.singaporevpcsubnet-1.id
  route_table_id = aws_route_table.singaporeVPCRouteTable.id
}

resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow Web traffic"
  vpc_id      = aws_vpc.mySingaporeVPC.id

  ingress {
    description      = "HTTPS Traffic from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]    
  }

   ingress {
    description      = "HTTP Traffic from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]    
  }

   ingress {
    description      = "SSH Traffic from VPC"
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
    Name = "Allow Web Traffic"
  }
}

resource "aws_network_interface" "webservernic" {
  subnet_id       = aws_subnet.singaporevpcsubnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]  
}

resource "aws_eip" "elasticIP" {
  vpc                       = true
  network_interface         = aws_network_interface.webservernic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.mySingaporeIG]
}


resource "aws_instance" "webserver" {
  ami           = "ami-002068ed284fb165b"
  instance_type = "t2.micro"
  availability_zone = "us-east-2a"
  key_name = "ec2_aws"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.webservernic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo my very first web server > /var/www//html/index.html'
                EOF

  tags = {
    Name = "Web Server"
  }
}
