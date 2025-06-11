#!/bin/bash

# Script de Deploy Local (Fallback) para URL Shortener
# Uso: ./deploy.sh [ambiente]
# Exemplo: ./deploy.sh dev

set -e

# Configurações
PROJECT_NAME="url-shortener"
ENVIRONMENT="${1:-dev}"
AWS_REGION="us-east-1"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    commands=("docker" "aws" "terraform")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd não está instalado ou não está no PATH"
        fi
    done
    
    success "Todas as dependências estão instaladas"
}

# Verificar autenticação AWS
check_aws_auth() {
    log "Verificando autenticação AWS..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        error "Não autenticado na AWS. Configure suas credenciais com 'aws configure'"
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    success "Autenticado na AWS como Account ID: $account_id"
}

# Fazer build das imagens Docker
build_images() {
    log "Fazendo build das imagens Docker..."
    
    # API Service
    log "Building API Service..."
    cd src/api-service
    docker build -t $PROJECT_NAME-api-service:latest .
    docker build -t $PROJECT_NAME-api-service:local-$(date +%Y%m%d-%H%M%S) .
    cd ../..
    
    # Processing Service
    log "Building Processing Service..."
    cd src/processing-service
    docker build -t $PROJECT_NAME-processing-service:latest .
    docker build -t $PROJECT_NAME-processing-service:local-$(date +%Y%m%d-%H%M%S) .
    cd ../..
    
    success "Build das imagens concluído"
}

# Obter URLs dos repositórios ECR
get_ecr_repositories() {
    log "Obtendo URLs dos repositórios ECR..."
    
    cd iac
    terraform init > /dev/null 2>&1
    
    API_ECR_URI=$(terraform output -raw api_service_ecr_repository_url 2>/dev/null)
    PROCESSING_ECR_URI=$(terraform output -raw processing_service_ecr_repository_url 2>/dev/null)
    
    if [[ -z "$API_ECR_URI" || -z "$PROCESSING_ECR_URI" ]]; then
        error "Não foi possível obter URLs dos repositórios ECR. Certifique-se de que a infraestrutura foi provisionada."
    fi
    
    success "URLs dos repositórios ECR obtidas"
    cd ..
}

# Login no ECR
ecr_login() {
    log "Fazendo login no Amazon ECR..."
    
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $(echo $API_ECR_URI | cut -d'/' -f1)
    
    success "Login no ECR realizado"
}

# Push das imagens para ECR
push_images() {
    log "Enviando imagens para ECR..."
    
    # API Service
    log "Pushing API Service..."
    docker tag $PROJECT_NAME-api-service:latest $API_ECR_URI:latest
    docker tag $PROJECT_NAME-api-service:latest $API_ECR_URI:local-$(date +%Y%m%d-%H%M%S)
    docker push $API_ECR_URI:latest
    docker push $API_ECR_URI:local-$(date +%Y%m%d-%H%M%S)
    
    # Processing Service
    log "Pushing Processing Service..."
    docker tag $PROJECT_NAME-processing-service:latest $PROCESSING_ECR_URI:latest
    docker tag $PROJECT_NAME-processing-service:latest $PROCESSING_ECR_URI:local-$(date +%Y%m%d-%H%M%S)
    docker push $PROCESSING_ECR_URI:latest
    docker push $PROCESSING_ECR_URI:local-$(date +%Y%m%d-%H%M%S)
    
    success "Push das imagens concluído"
}

# Atualizar serviços ECS
update_ecs_services() {
    log "Atualizando serviços ECS..."
    
    # Obter nome do cluster
    cd iac
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null)
    cd ..
    
    if [[ -z "$ECS_CLUSTER" ]]; then
        error "Não foi possível obter nome do cluster ECS"
    fi
    
    # Atualizar API Service
    log "Atualizando API Service..."
    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service "${PROJECT_NAME}-${ENVIRONMENT}-api-service" \
        --force-new-deployment \
        --region $AWS_REGION > /dev/null
    
    # Atualizar Processing Service
    log "Atualizando Processing Service..."
    aws ecs update-service \
        --cluster $ECS_CLUSTER \
        --service "${PROJECT_NAME}-${ENVIRONMENT}-processing-service" \
        --force-new-deployment \
        --region $AWS_REGION > /dev/null
    
    success "Serviços ECS atualizados"
    
    # Aguardar estabilização
    log "Aguardando estabilização dos serviços..."
    
    log "Aguardando API Service..."
    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER \
        --services "${PROJECT_NAME}-${ENVIRONMENT}-api-service" \
        --region $AWS_REGION
    
    log "Aguardando Processing Service..."
    aws ecs wait services-stable \
        --cluster $ECS_CLUSTER \
        --services "${PROJECT_NAME}-${ENVIRONMENT}-processing-service" \
        --region $AWS_REGION
    
    success "Serviços estabilizados"
}

# Testar deployment
test_deployment() {
    log "Testando deployment..."
    
    # Obter endpoint da API
    cd iac
    API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null)
    cd ..
    
    if [[ -z "$API_ENDPOINT" ]]; then
        warning "Não foi possível obter endpoint da API"
        return
    fi
    
    # Teste de health check
    log "Testando health check..."
    for i in {1..30}; do
        if curl -sf "$API_ENDPOINT/health" > /dev/null 2>&1; then
            success "Health check passou"
            break
        fi
        log "Tentativa $i/30 - aguardando API..."
        sleep 10
    done
    
    # Teste de encurtamento de URL
    log "Testando encurtamento de URL..."
    response=$(curl -s -X POST "$API_ENDPOINT/shorten" \
        -H "Content-Type: application/json" \
        -d '{"url": "https://example.com"}' || echo "")
    
    if echo "$response" | grep -q '"success": *true' 2>/dev/null; then
        success "Teste de encurtamento passou"
    else
        warning "Teste de encurtamento falhou"
    fi
    
    log "Endpoint da API: $API_ENDPOINT"
}

# Função principal
main() {
    echo -e "${BLUE}"
    echo "🚀 Deploy Script para URL Shortener"
    echo "====================================="
    echo -e "${NC}"
    
    warning "⚠️ ATENÇÃO: Use preferencialmente o GitHub Actions para deploy!"
    warning "Este script é um fallback para deploy local."
    echo ""
    
    check_dependencies
    check_aws_auth
    build_images
    get_ecr_repositories
    ecr_login
    push_images
    update_ecs_services
    test_deployment
    
    echo ""
    success "🎉 Deploy concluído com sucesso!"
    echo -e "${YELLOW}💡 Próxima vez, use: git push origin main (GitHub Actions)${NC}"
}

# Executar função principal
main "$@" 