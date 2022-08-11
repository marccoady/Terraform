#-----Setting up providers

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

provider "aws" {
  region = "us-east-1"
}

#-------Create VPC for ECS

resource "aws_vpc" "project_ecs" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"


  tags = {
    Name = "Project ECS"
  }
}

#--------Create Private subnets for ECS

resource "aws_subnet" "private_east_a" {
  vpc_id     = aws_vpc.project_ecs.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private East A"
  }
}

resource "aws_subnet" "private_east_b" {
  vpc_id     = aws_vpc.project_ecs.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private East B"
  }
}

#-----Create ECS cluster

resource "aws_ecs_cluster" "cluster" {
  name = "ecs_centos7-cluster"

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
}


module "ecs-fargate" {
  source  = "umotif-public/ecs-fargate/aws"
  version = "~> 6.1.0"

  name_prefix        = "ecs-fargate-centos7"
  vpc_id             = aws_vpc.project_ecs.id
  private_subnet_ids = [aws_subnet.private_east_a.id, aws_subnet.private_east_b.id]

  cluster_id = aws_ecs_cluster.cluster.id

  task_container_image   = "centos7"
  task_definition_cpu    = 256
  task_definition_memory = 512

  task_container_port             = 80
  task_container_assign_public_ip = true

  load_balanced = false

   target_groups = [
    {
      target_group_name = "tg-fargate-example"
      container_port    = 80
    }
  ]

  health_check = {
    port = "traffic-port"
    path = "/"
  }

  tags = {
    Environment = "test"
    Project     = "Test"
  }
}