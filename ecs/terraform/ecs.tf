##############################################
# CloudWatch Logs (both containers log here)
##############################################
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = { Project = "aws-to-gcp-migration-demo" }
}

##############################################
# ECS Cluster (Fargate only — no EC2 capacity
# to manage, closest analog to Cloud Run/GKE
# Autopilot's "no node management" model)
##############################################
resource "aws_ecs_cluster" "this" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "disabled" # flip to "enabled" for production observability (small extra cost)
  }

  tags = {
    Project  = "aws-to-gcp-migration-demo"
    Workload = var.project_name
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

##############################################
# Security groups
# ALB: public 80 only. Service: only from ALB.
##############################################
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Public ALB security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "aws-to-gcp-migration-demo" }
}

resource "aws_security_group" "service" {
  name        = "${var.project_name}-service-sg"
  description = "ECS Fargate task security group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "From ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All egress (public image pull, S3 API, CloudWatch Logs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "aws-to-gcp-migration-demo" }
}

##############################################
# Application Load Balancer
##############################################
resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false # easy teardown for a demo

  tags = { Project = "aws-to-gcp-migration-demo" }
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip" # required for awsvpc network mode (Fargate)

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = { Project = "aws-to-gcp-migration-demo" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

##############################################
# Task definition
#
# No custom Docker image build/push is required
# (mirrors the Lambda demo's "no build" style).
# Two containers share an ephemeral, task-scoped
# volume:
#   1. fetch-content (non-essential, runs first):
#      public AWS CLI image, downloads index.html
#      from S3 using the task role's credentials.
#   2. web (essential, starts after fetch-content
#      completes via dependsOn/condition=SUCCESS):
#      unmodified public nginx image, serves the
#      fetched file.
#
# This is the standard, documented ECS sidecar
# pattern and avoids relying on package managers
# (apk/apt) being available inside the web image.
##############################################
resource "aws_ecs_task_definition" "this" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  volume {
    name = "content"
  }

  container_definitions = jsonencode([
    {
      name      = "fetch-content"
      image     = var.fetch_content_image
      essential = false
      command   = ["s3", "cp", "s3://${aws_s3_bucket.content.id}/index.html", "/var/www/html/index.html"]

      environment = [
        { name = "AWS_DEFAULT_REGION", value = var.aws_region }
      ]

      mountPoints = [
        { sourceVolume = "content", containerPath = "/var/www/html", readOnly = false }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "fetch"
        }
      }
    },
    {
      name      = "web"
      image     = var.container_image
      essential = true

      dependsOn = [
        { containerName = "fetch-content", condition = "SUCCESS" }
      ]

      portMappings = [
        { containerPort = var.container_port, protocol = "tcp" }
      ]

      mountPoints = [
        { sourceVolume = "content", containerPath = "/usr/share/nginx/html", readOnly = false }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])

  tags = { Project = "aws-to-gcp-migration-demo" }
}

##############################################
# ECS Service
##############################################
resource "aws_ecs_service" "this" {
  name                              = var.project_name
  cluster                           = aws_ecs_cluster.this.id
  task_definition                   = aws_ecs_task_definition.this.arn
  desired_count                     = var.desired_count
  launch_type                       = "FARGATE"
  platform_version                  = "LATEST"
  health_check_grace_period_seconds = 30 # gives the fetch-content sidecar time to run

  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = true # no NAT Gateway in this demo VPC
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "web"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = { Project = "aws-to-gcp-migration-demo" }
}
