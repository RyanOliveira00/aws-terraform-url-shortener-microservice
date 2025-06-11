# variables.tf - Definição das variáveis do Terraform
# Este arquivo será preenchido na Etapa 3 com as variáveis de configuração 

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "url-shortener"
}

variable "environment" {
  description = "Ambiente de deployment"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS para deploy"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block para a VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks para sub-redes públicas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks para sub-redes privadas"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "api_service_cpu" {
  description = "CPU para o API service (em unidades ECS)"
  type        = number
  default     = 256
}

variable "api_service_memory" {
  description = "Memória para o API service (em MB)"
  type        = number
  default     = 512
}

variable "processing_service_cpu" {
  description = "CPU para o Processing service (em unidades ECS)"
  type        = number
  default     = 256
}

variable "processing_service_memory" {
  description = "Memória para o Processing service (em MB)"
  type        = number
  default     = 512
} 