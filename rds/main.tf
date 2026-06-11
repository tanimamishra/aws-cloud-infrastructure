provider "aws" {
  region = "ap-south-1"
}

data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = [
    data.terraform_remote_state.vpc.outputs.private_subnet_1_id,
    data.terraform_remote_state.vpc.outputs.private_subnet_2_id
  ]

  tags = {
    Name = "main-db-subnet-group"
  }
}

resource "aws_db_instance" "main" {
  identifier           = "main-database"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "appdb"
  username             = "admin"
  password             = "Admin12345!"
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [
    data.terraform_remote_state.vpc.outputs.rds_sg_id
  ]
  skip_final_snapshot  = true
  multi_az             = false

  tags = {
    Name = "main-database"
  }
}