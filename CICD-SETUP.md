# 🚀 Configuração do CI/CD com GitHub Actions

## 📋 **Visão Geral**

Este projeto implementa um **pipeline completo de CI/CD** usando GitHub Actions que automatiza:
- ✅ **Testes e validações** de código
- 🐳 **Build de imagens Docker** (arquitetura AMD64)
- 📦 **Push para Amazon ECR**
- 🚀 **Deploy automático no ECS**
- 🧪 **Testes de integração**

## 🔧 **Configuração Inicial**

### 1. **Configurar Secrets no GitHub**

Vá em **Settings > Secrets and variables > Actions** e adicione:

```bash
AWS_ACCESS_KEY_ID      # Sua AWS Access Key
AWS_SECRET_ACCESS_KEY  # Sua AWS Secret Key
```

> ⚠️ **Importante**: Use credenciais com permissões mínimas necessárias!

### 2. **Permissões IAM Necessárias**

Crie uma **política IAM** com as seguintes permissões:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecs:UpdateService",
                "ecs:DescribeServices",
                "ecs:DescribeClusters",
                "ecs:DescribeTaskDefinition"
            ],
            "Resource": "*"
        }
    ]
}
```

### 3. **Configurar Backend do Terraform**

Se usando backend remoto, configure as variáveis:

```bash
# No GitHub Secrets
TF_BACKEND_BUCKET=seu-bucket-terraform
TF_BACKEND_KEY=url-shortener/terraform.tfstate
TF_BACKEND_REGION=us-east-1
```

## 🔄 **Workflows Disponíveis**

### 📁 **`.github/workflows/deploy.yml`**
**Workflow principal** - Executa em push para `main`/`master`:

```yaml
Jobs Executados:
1. 🧪 test                # Testes e validações
2. 🐳 build-and-push      # Build e push para ECR
3. 🚀 deploy              # Deploy no ECS
4. 🧪 integration-tests   # Testes pós-deploy
5. 📢 notify              # Notificações
```

### 📁 **`.github/workflows/pr-validation.yml`**
**Validação de PRs** - Executa em Pull Requests:

```yaml
Jobs Executados:
1. 🧪 validation     # Qualidade de código e builds
2. 🔒 security       # Análise de segurança
3. 📦 dependencies   # Verificação de dependências
```

## 🚀 **Como Usar**

### **Deploy Automático**
```bash
# Fazer push para main/master
git add .
git commit -m "feat: nova funcionalidade"
git push origin main

# ✅ Pipeline executa automaticamente
```

### **Deploy Manual**
```bash
# No GitHub: Actions > Deploy to AWS ECS > Run workflow
```

### **Validação de PR**
```bash
# Abrir Pull Request
gh pr create --title "Nova feature" --body "Descrição"

# ✅ Validações executam automaticamente
```

## 📊 **Monitoramento**

### **GitHub Actions**
- **Actions tab**: Acompanhe execuções em tempo real
- **Job summaries**: Relatórios detalhados de cada execução
- **Artifacts**: Logs e relatórios gerados

### **AWS CloudWatch**
- **ECS Service Events**: Status dos deployments
- **Application Logs**: Logs das aplicações
- **CloudWatch Insights**: Consultas avançadas

## 🎯 **Vantagens do CI/CD**

### ✅ **Resolução Automática de Problemas**
- **Arquitetura**: GitHub runners são Linux AMD64 (compatível com ECS)
- **Consistência**: Ambiente padronizado para todos os builds
- **Velocidade**: Pipeline paralelo e otimizado

### 🔒 **Segurança e Qualidade**
- **Análise de código**: Linting automático
- **Testes**: Validações antes do deploy
- **Rollback**: Fácil reversão em caso de problemas

### 📈 **Produtividade**
- **Deploy em minutos**: Processo totalmente automatizado
- **Testes automáticos**: Validação contínua
- **Feedback imediato**: Notificações de status

## 🐛 **Troubleshooting**

### **1. Falha na Autenticação AWS**
```bash
Error: The security token included in the request is invalid
```
**Solução**: Verificar se `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` estão corretos

### **2. Falha no Push para ECR**
```bash
Error: denied: User is not authorized
```
**Solução**: Verificar permissões IAM para ECR

### **3. Timeout no Deploy ECS**
```bash
Error: Timeout waiting for service to become stable
```
**Solução**: Verificar logs do ECS e recursos disponíveis

### **4. Falha nos Testes de Integração**
```bash
Error: Health check failed
```
**Solução**: Verificar se o ALB e target groups estão configurados

## 📝 **Logs Úteis**

### **GitHub Actions Logs**
```bash
# Ver logs específicos
https://github.com/SEU_USUARIO/REPO/actions/runs/RUN_ID
```

### **AWS ECS Logs**
```bash
# CloudWatch Logs
aws logs describe-log-groups --region us-east-1
aws logs get-log-events --log-group-name /ecs/url-shortener-dev-api-service
```

### **ECR Repository**
```bash
# Listar imagens
aws ecr describe-images --repository-name url-shortener-dev-api-service
```

## 🔄 **Rollback Manual**

Se necessário, faça rollback manual:

```bash
# 1. Identificar versão anterior
aws ecs describe-services --cluster url-shortener-dev-cluster --services url-shortener-dev-api-service

# 2. Atualizar para versão anterior
aws ecs update-service --cluster url-shortener-dev-cluster --service url-shortener-dev-api-service --task-definition url-shortener-dev-api-service:VERSAO_ANTERIOR
```

## 📚 **Próximos Passos**

1. **🧪 Adicionar testes unitários** nos serviços
2. **🌍 Configurar ambientes** (dev/staging/prod)
3. **📊 Implementar métricas** customizadas
4. **🔔 Configurar alertas** no Slack/Teams
5. **📈 Blue/Green deployment** para zero downtime

---

## 📞 **Suporte**

Para dúvidas ou problemas:
1. Verificar logs do GitHub Actions
2. Consultar documentação AWS
3. Revisar este guia

**🎉 Agora você tem um pipeline CI/CD completo e automatizado!** 