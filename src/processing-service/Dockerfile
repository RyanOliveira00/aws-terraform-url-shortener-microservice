# Dockerfile para o Processing Service
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
    POLL_INTERVAL=5 \
    MAX_MESSAGES=10 \
    VISIBILITY_TIMEOUT=30

# Criação do usuário não-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Cópia das dependências instaladas
COPY --from=builder /root/.local /home/appuser/.local
RUN chown -R appuser:appuser /home/appuser/.local

# Diretório de trabalho
WORKDIR /app

# Cópia do código da aplicação
COPY --chown=appuser:appuser worker.py .

# Mudança para usuário não-root
USER appuser

# Health check para verificar se o processo está rodando
HEALTHCHECK --interval=60s --timeout=30s --start-period=10s --retries=3 \
    CMD pgrep -f "python.*worker.py" > /dev/null || exit 1

# Comando para iniciar o worker
CMD ["python", "worker.py"] 