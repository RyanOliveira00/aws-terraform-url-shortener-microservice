# outputs.tf - Outputs do Terraform
# Este arquivo será preenchido na Etapa 3 com os outputs da infraestrutura 

# VPC
output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = aws_vpc.main.cidr_block
}

# Sub-redes
output "public_subnet_ids" {
  description = "IDs das sub-redes públicas"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs das sub-redes privadas"
  value       = aws_subnet.private[*].id
}

# Load Balancer
output "load_balancer_dns" {
  description = "DNS do Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.main.arn
}

output "api_endpoint" {
  description = "Endpoint da API"
  value       = "http://${aws_lb.main.dns_name}"
}

# ECS
output "ecs_cluster_name" {
  description = "Nome do cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN do cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

# ECR
output "api_service_ecr_repository_url" {
  description = "URL do repositório ECR para API Service"
  value       = aws_ecr_repository.api_service.repository_url
}

output "processing_service_ecr_repository_url" {
  description = "URL do repositório ECR para Processing Service"
  value       = aws_ecr_repository.processing_service.repository_url
}

# SQS
output "sqs_queue_url" {
  description = "URL da fila SQS"
  value       = aws_sqs_queue.url_processing.url
}

output "sqs_queue_arn" {
  description = "ARN da fila SQS"
  value       = aws_sqs_queue.url_processing.arn
}

output "sqs_dlq_url" {
  description = "URL da Dead Letter Queue"
  value       = aws_sqs_queue.url_processing_dlq.url
}

# IAM
output "ecs_execution_role_arn" {
  description = "ARN da role de execução do ECS"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN da role de task do ECS"
  value       = aws_iam_role.ecs_task_role.arn
}

# Security Groups
output "alb_security_group_id" {
  description = "ID do Security Group do ALB"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID do Security Group do ECS"
  value       = aws_security_group.ecs_tasks.id
}

# CloudWatch
output "cloudwatch_log_group_name" {
  description = "Nome do grupo de logs do CloudWatch"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

# Informações gerais
output "aws_region" {
  description = "Região AWS utilizada"
  value       = var.aws_region
}

output "project_name" {
  description = "Nome do projeto"
  value       = var.project_name
}

output "environment" {
  description = "Ambiente de deployment"
  value       = var.environment
} 