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

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
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
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
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
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_kms.key_id
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

resource "aws_secretsmanager_secret" "db_secret" {
  name        = var.db_secret_name
  description = "DB credentials"
  kms_key_id  = aws_kms_key.secrets_kms.key_id
}

resource "aws_secretsmanager_secret_version" "db_secret_value" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    DB_USERNAME                = var.db_username
    DB_PASSWORD                = random_password.db_password.result
    DB_HOST                    = aws_db_instance.mysql_db.endpoint
    DB_NAME                    = var.db_name
    SPRING_DATASOURCE_USERNAME = var.db_username
    SPRING_DATASOURCE_PASSWORD = random_password.db_password.result
  })
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
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds_kms.arn
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  parameter_group_name   = aws_db_parameter_group.mysql_param_group.name
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name = "csye6225-mysql-instance"
  }
}

resource "aws_launch_template" "web_app_lt" {
  name          = "webapp-lt-aws-v1"
  image_id      = var.custom_ami
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }
  lifecycle {
    create_before_destroy = true
  }
  network_interfaces {
    security_groups             = [aws_security_group.application_security_group.id]
    associate_public_ip_address = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 10
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_kms.arn
      delete_on_termination = true
      volume_type           = "gp2"
    }
  }


  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee -a /var/log/user_data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -e

echo "[BOOTSTRAP] Updating packages & installing jq/unzip"
apt-get update -y
apt-get install -y jq unzip curl

echo "[BOOTSTRAP] Installing AWS CLI v2 manually"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo "[BOOTSTRAP] Verifying AWS CLI install"
aws --version || { echo "[ERROR] AWS CLI install failed"; exit 1; }

REGION="${var.aws_region}"
SECRET_NAME="${var.db_secret_name}"

echo "[INFO] Fetching DB secret from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --region "$REGION" \
  --secret-id "$SECRET_NAME" \
  --query SecretString \
  --output text 2>/tmp/aws_error.log) || {
    echo "[ERROR] Failed to fetch secret:"
    cat /tmp/aws_error.log
    exit 1
}

echo "[INFO] Creating /etc/myapp directory..."
mkdir -p /etc/myapp

echo "[INFO] Writing secret to env file..."
echo "$SECRET_JSON" | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' \
  > /etc/myapp/myapp.env

echo "[INFO] Adding static config to env file..."
cat <<EOT >> /etc/myapp/myapp.env
AWS_REGION=$REGION
AWS_S3_BUCKET_NAME=${aws_s3_bucket.s3bucket.bucket}
EOT

chmod 600 /etc/myapp/myapp.env

echo "[INFO] Contents of env file:"
cat /etc/myapp/myapp.env

echo "Installing CloudWatch"
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s
    
echo "[INFO] Restarting app service..."
systemctl daemon-reexec
systemctl restart myapp.service || echo "[WARN] myapp.service failed to start"
EOF
  )
  depends_on = [
    aws_kms_key.ec2_kms,
    aws_iam_instance_profile.ec2_instance_profile,
    aws_kms_key.rds_kms,
    aws_kms_key.secrets_kms,
    aws_kms_key.s3_kms,
    aws_db_instance.mysql_db
  ]

}

resource "aws_autoscaling_group" "web_app_asg" {
  name                      = "webapp-autoscaling-group"
  desired_capacity          = 3
  max_size                  = 5
  min_size                  = 3
  health_check_type         = "EC2"
  health_check_grace_period = 600
  vpc_zone_identifier       = aws_subnet.public[*].id
  launch_template {
    id      = aws_launch_template.web_app_lt.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.web_app_tg.arn]

  tag {
    key                 = "Name"
    value               = "web_app_instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                    = "scale_up_policy"
  scaling_adjustment      = 1
  adjustment_type         = "ChangeInCapacity"
  cooldown                = 60
  autoscaling_group_name  = aws_autoscaling_group.web_app_asg.name
  policy_type             = "SimpleScaling"
  metric_aggregation_type = "Average"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                    = "scale_down_policy"
  scaling_adjustment      = -1
  adjustment_type         = "ChangeInCapacity"
  cooldown                = 60
  autoscaling_group_name  = aws_autoscaling_group.web_app_asg.name
  policy_type             = "SimpleScaling"
  metric_aggregation_type = "Average"
}
resource "aws_lb" "web_alb" {
  name               = "webapp-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "web_app_tg" {
  name        = "webapp-target-group"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }
}

# resource "aws_lb_listener" "web_app_http" {
#   load_balancer_arn = aws_lb.web_alb.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.web_app_tg.arn
#   }
# }
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP and HTTPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "scale-up-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 12
  alarm_description   = "Trigger ASG scale up"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_app_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "scale-down-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 8
  alarm_description   = "Trigger ASG scale down"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_app_asg.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_route53_record" "dev_record" {
  zone_id = var.current_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.web_alb.dns_name
    zone_id                = aws_lb.web_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_listener" "web_app_https_demo" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.demo_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_app_tg.arn
  }
}


