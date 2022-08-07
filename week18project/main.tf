
#designating provider for, which is of course AWS 

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

# Configure default region
provider "aws" {
  region  = "us-east-1"
}


#------Networking

#Create VPC

resource "aws_vpc" "project_tf" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"


  tags = {
    Name = "Project TF"
  }
}


#Internet Gateway

resource "aws_internet_gateway" "project_tf_igw" {
  vpc_id = aws_vpc.project_tf.id

  tags = {
    Name = "Project TF - Internet Gateway"
  }
}

#Two Public Subnets one in US East 1 and one in US East 2

resource "aws_subnet" "public_east_a" {
  vpc_id     = aws_vpc.project_tf.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public East A"
  }
}

resource "aws_subnet" "public_east_b" {
  vpc_id     = aws_vpc.project_tf.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public East B"
  }
}


#-----Two Private Subnets one in US East 1 and one in US East 2

resource "aws_subnet" "private_east_a" {
  vpc_id     = aws_vpc.project_tf.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private East A"
  }
}

resource "aws_subnet" "private_east_b" {
  vpc_id     = aws_vpc.project_tf.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private East B"
  }
}


#-------------Routing tables 

#-----Default Table 

resource "aws_default_route_table" "project_tf_default" {
  default_route_table_id = aws_vpc.project_tf.default_route_table_id
}

#-----Public

resource "aws_route_table" "public_project_tf_route_table" {
    vpc_id = aws_vpc.project_tf.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.project_tf_igw.id
      
    }

    tags = {
        Name = "Project TF Public Route"
    }
}

resource "aws_route_table_association" "public_route_a" {
    subnet_id = aws_subnet.public_east_a.id
    route_table_id = aws_route_table.public_project_tf_route_table.id
}

resource "aws_route_table_association" "public_route_b" {
    subnet_id = aws_subnet.public_east_b.id
    route_table_id = aws_route_table.public_project_tf_route_table.id
}


#-----Private

resource "aws_route_table" "private_project_tf_route_table" {
  vpc_id = aws_vpc.project_tf.id

  tags = {
    Name = "Project TF"
  }
}

resource "aws_route_table_association" "private_route_a" {
    subnet_id = aws_subnet.private_east_a.id
    route_table_id = aws_route_table.private_project_tf_route_table.id
}

resource "aws_route_table_association" "private_route_b" {
    subnet_id = aws_subnet.private_east_b.id
    route_table_id = aws_route_table.private_project_tf_route_table.id
}

#-------Security Groups

#-LB SG

resource "aws_security_group" "public_alb_sg" {
  name = "http_access_alb"
  description = "Terraform created SG to Allow HTTP traffic from alb"
  vpc_id = aws_vpc.project_tf.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 
 tags = {
    Name = "Project_TF_ALB_SG"
  }
}

#-Web SG

resource "aws_security_group" "public_web_sg" {
  name = "http_access"
  description = "Terraform created SG to Allow HTTP traffic"
  vpc_id = aws_vpc.project_tf.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 
 tags = {
    Name = "Project_TF_WEB_SG"
  }
}

#-DB SG 

resource "aws_security_group" "internal_db_sg" {
  name        = "DB_Access"
  description = "Allow inbound traffic to db"
  vpc_id      = aws_vpc.project_tf.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.public_web_sg.id] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols 
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "internal_db_sg"
  }
}



#-------Load Balancer Setup


# Create Load Balancer

resource "aws_lb" "project_tf_alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb_sg.id]
  subnets            = [aws_subnet.public_east_a.id, aws_subnet.public_east_b.id]
}

# Create target group
resource "aws_lb_target_group" "project_tf_tg" {
  name     = "project-tf-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.project_tf.id

  depends_on = [aws_vpc.project_tf]
}

# Create attachments
resource "aws_lb_target_group_attachment" "tg_tf_1" {
  target_group_arn = aws_lb_target_group.project_tf_tg.arn
  target_id        = aws_instance.server1.id
  port             = 80

  depends_on = [aws_instance.server1]
}

resource "aws_lb_target_group_attachment" "tg_tf_2" {
  target_group_arn = aws_lb_target_group.project_tf_tg.arn
  target_id        = aws_instance.server2.id
  port             = 80

  depends_on = [aws_instance.server2]
}

# Create a listener
resource "aws_lb_listener" "listener_4lb" {
  load_balancer_arn = aws_lb.project_tf_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.project_tf_tg.arn
  }
}


#-------Instances

resource "aws_instance" "server1" {
  ami           = "ami-090fa75af13c156b4"
  instance_type = "t2.micro"
  key_name          = "ProjectKeyPair"
  availability_zone = "us-east-1a"
  vpc_security_group_ids      = [aws_security_group.public_web_sg.id]
  subnet_id                   = aws_subnet.public_east_a.id
  associate_public_ip_address = true
  user_data = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h2>This is Server 1!</h2></body></html>" > /var/www/html/index.html
        EOF

  tags = {
    Name = "server1_instance"
  }
}
resource "aws_instance" "server2" {
  ami           = "ami-090fa75af13c156b4"
  instance_type = "t2.micro"
  key_name          = "ProjectKeyPair"
  availability_zone = "us-east-1b"
  vpc_security_group_ids      = [aws_security_group.public_web_sg.id]
  subnet_id                   = aws_subnet.public_east_b.id
  associate_public_ip_address = true
  user_data = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h2>This is Server2!</h2></body></html>" > /var/www/html/index.html
        EOF

  tags = {
    Name = "server2_instance"
  }
}




#-------Database

resource "aws_db_instance" "project_tf" {
  allocated_storage      = 8
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  db_name                = "project_tf_db"
  db_subnet_group_name   = aws_db_subnet_group.project_tf.name
  username               = "Pats"
  password               = "patriots2022"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.internal_db_sg.id]
}

resource "aws_db_subnet_group" "project_tf" {
  name       = "project_tf"
  subnet_ids = [aws_subnet.private_east_a.id, aws_subnet.private_east_b.id]

  tags = {
    Name = "My DB SN group"
  }
}


#------Outputs

output "PublicIP1" {
  description = "Public IP of Server1"
  value       = aws_instance.server1.public_ip
}
output "PublicIP2" {
  description = "Public IP of Server2"
  value       = aws_instance.server2.public_ip
}

output "ALB_DNS" {
  description = "The ALBs DNS"
  value       = aws_lb.project_tf_alb.dns_name

}





