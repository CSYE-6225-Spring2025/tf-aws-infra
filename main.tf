provider "aws" {
  region  = var.region
  profile = var.profile
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = var.vpc_tag
  }
}


resource "aws_subnet" "public" {
  count                   = length(var.availabilityzones_names)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidrs[count.index]
  availability_zone       = var.availabilityzones_names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_tag-${count.index}"
  }
}


resource "aws_subnet" "private" {
  count             = length(var.availabilityzones_names)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidrs[count.index]
  availability_zone = var.availabilityzones_names[count.index]
  tags = {
    Name = "private_subnet_tag-${count.index}"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.internet_gateway
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = var.public_route_table
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}


resource "aws_route_table_association" "public" {
  count          = length(var.availabilityzones_names)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = var.private_route_table_tag
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.availabilityzones_names)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}


resource "aws_security_group" "application_security_group" {
  vpc_id      = aws_vpc.main.id
  name        = var.application_security_group
  description = var.aws_security_group_description

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
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
    Name = var.aws_security_group_tag
  }
}



resource "aws_s3_bucket" "s3bucket" {
  bucket        = uuid()
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3bucket_encryption" {
  bucket = aws_s3_bucket.s3bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "s3bucket" {
  bucket = aws_s3_bucket.s3bucket.id


  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}




resource "aws_db_parameter_group" "mysql_param_group" {
  name        = "mysql-custom-parameter-group"
  family      = "mysql8.0"
  description = "Custom parameter group for MySQL 8.0"

  parameter {
    name  = "max_connections"
    value = "200"
  }

  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }

  tags = {
    Name = "mysql-param-group"
  }
}



resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-private-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "rds-private-subnet-group"
  }
}


resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Security group for RDS instances"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.application_security_group.id]
    description     = "Allow DB access from application security group"
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "db-security-group"
  }
}


resource "aws_db_instance" "mysql_db" {
  identifier             = "csye6225"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  multi_az               = false
  publicly_accessible    = false
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  parameter_group_name   = aws_db_parameter_group.mysql_param_group.name
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name = "csye6225-mysql-instance"
  }
}

resource "aws_instance" "web_app" {
  ami                         = var.custom_ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.application_security_group.id]
  associate_public_ip_address = true
  user_data                   = <<EOF
#!/bin/bash
sudo mkdir -p /etc/myapp
echo "DB_HOST=${aws_db_instance.mysql_db.endpoint}" | sudo tee -a /etc/myapp/myapp.env
echo "DB_NAME=${aws_db_instance.mysql_db.db_name}" | sudo tee -a /etc/myapp/myapp.env
echo "DB_USER=${aws_db_instance.mysql_db.username}" | sudo tee -a /etc/myapp/myapp.env
echo "SPRING_DATASOURCE_USERNAME=${aws_db_instance.mysql_db.username}" | sudo tee -a /etc/myapp/myapp.env
echo "SPRING_DATASOURCE_PASSWORD=${var.db_password}" | sudo tee -a /etc/myapp/myapp.env
echo "DB_PASSWORD=${var.db_password}" | sudo tee -a /etc/myapp/myapp.env
echo "AWS_ACCESS_KEY=${var.aws_access_key}" | sudo tee -a /etc/myapp/myapp.env
echo "AWS_SECRET_KEY=${var.aws_secret_key}" | sudo tee -a /etc/myapp/myapp.env
echo "AWS_REGION=${var.aws_region}" | sudo tee -a /etc/myapp/myapp.env
echo "AWS_S3_BUCKET_NAME=${aws_s3_bucket.s3bucket.bucket}" | sudo tee -a /etc/myapp/myapp.env
sudo chmod 600 /etc/myapp/myapp.env
cd /opt
EOF


  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = true
  }

  disable_api_termination = false

  tags = {
    Name = var.web_app_instance_tag
  }
}
