# Dockerfile para o API Service
# Multi-stage build para otimizar o tamanho da imagem

# Stage 1: Build
FROM python:3.11-slim as builder

# Configurações para otimização
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalação de dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Criação do usuário não-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Diretório de trabalho
WORKDIR /app

# Cópia e instalação das dependências
COPY requirements.txt .
RUN pip install --user --no-warn-script-location -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

# Configurações
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/home/appuser/.local/bin:$PATH" \
    FLASK_APP=app.py \
    FLASK_ENV=production

# Criação do usuário não-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Cópia das dependências instaladas
COPY --from=builder /root/.local /home/appuser/.local
RUN chown -R appuser:appuser /home/appuser/.local

# Diretório de trabalho
WORKDIR /app

# Cópia do código da aplicação
COPY --chown=appuser:appuser app.py .

# Mudança para usuário não-root
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health', timeout=5)"

# Exposição da porta
EXPOSE 8080

# Comando para iniciar a aplicação
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--threads", "4", "--timeout", "60", "--keep-alive", "5", "--max-requests", "1000", "--max-requests-jitter", "100", "app:app"] 