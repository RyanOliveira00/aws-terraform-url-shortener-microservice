# main.tf - Arquivo principal do Terraform para provisionamento da infraestrutura AWS
# Este arquivo será preenchido na Etapa 3 com a definição dos recursos da AWS 

# Configuração do Provider AWS
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources para obter AZs disponíveis
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source para obter a conta AWS atual
data "aws_caller_identity" "current" {}

# Data source para obter região atual
data "aws_region" "current" {}

# =============================================================================
# VPC e Networking
# =============================================================================

# VPC Principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Internet Gateway para acesso à internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Sub-redes públicas (para Load Balancer)
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Public"
  }
}

# Sub-redes privadas (para ECS Tasks)
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "Private"
  }
}

# Elastic IPs para NAT Gateways
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)

  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-eip-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways para acesso à internet das sub-redes privadas
resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table para sub-redes públicas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associação das sub-redes públicas com a route table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Tables para sub-redes privadas
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-private-rt-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associação das sub-redes privadas com suas route tables
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# =============================================================================
# Security Groups
# =============================================================================

# Security Group para Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
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

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Group para ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-${var.environment}-ecs-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-sg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# Application Load Balancer
# =============================================================================

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Target Group para API Service
resource "aws_lb_target_group" "api_service" {
  name        = "${var.project_name}-${var.environment}-api-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-tg"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Listener para ALB
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_service.arn
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# SQS Queue
# =============================================================================

# Fila SQS para comunicação entre microsserviços
resource "aws_sqs_queue" "url_processing" {
  name                      = "${var.project_name}-${var.environment}-url-processing"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 1209600  # 14 dias
  receive_wait_time_seconds = 20       # Long polling

  # Dead Letter Queue após 3 tentativas
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.url_processing_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-url-processing"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Dead Letter Queue
resource "aws_sqs_queue" "url_processing_dlq" {
  name                      = "${var.project_name}-${var.environment}-url-processing-dlq"
  message_retention_seconds = 1209600  # 14 dias

  tags = {
    Name        = "${var.project_name}-${var.environment}-url-processing-dlq"
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# IAM Roles e Policies
# =============================================================================

# Role de execução para ECS Tasks
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-execution-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attachment da policy gerenciada para ECS execution
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Role de task para acesso ao SQS
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Policy para acesso ao SQS
resource "aws_iam_role_policy" "sqs_access" {
  name = "${var.project_name}-${var.environment}-sqs-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.url_processing.arn,
          aws_sqs_queue.url_processing_dlq.arn
        ]
      }
    ]
  })
}

# =============================================================================
# ECR Repositories
# =============================================================================

# ECR Repository para API Service
resource "aws_ecr_repository" "api_service" {
  name                 = "${var.project_name}/${var.environment}/api-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECR Repository para Processing Service
resource "aws_ecr_repository" "processing_service" {
  name                 = "${var.project_name}/${var.environment}/processing-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-processing-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

# =============================================================================
# ECS Cluster e Services
# =============================================================================

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cluster"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Task Definition para API Service
resource "aws_ecs_task_definition" "api_service" {
  family                   = "${var.project_name}-${var.environment}-api-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_service_cpu
  memory                   = var.api_service_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api-service"
      image = "${aws_ecr_repository.api_service.repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.url_processing.url
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "api-service"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-service-task"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Task Definition para Processing Service
resource "aws_ecs_task_definition" "processing_service" {
  family                   = "${var.project_name}-${var.environment}-processing-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.processing_service_cpu
  memory                   = var.processing_service_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "processing-service"
      image = "${aws_ecr_repository.processing_service.repository_url}:latest"

      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.url_processing.url
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "processing-service"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-processing-service-task"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS Service para API Service
resource "aws_ecs_service" "api_service" {
  name            = "${var.project_name}-${var.environment}-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_service.arn
    container_name   = "api-service"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.main]

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-service"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ECS Service para Processing Service
resource "aws_ecs_service" "processing_service" {
  name            = "${var.project_name}-${var.environment}-processing-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.processing_service.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-processing-service"
    Environment = var.environment
    Project     = var.project_name
  }
} 