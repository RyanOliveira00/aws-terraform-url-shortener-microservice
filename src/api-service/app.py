#!/usr/bin/env python3
"""
API Service - Microsserviço para encurtamento de URLs
Responsável por receber requisições HTTP e enviar mensagens para SQS
"""

import os
import json
import uuid
import logging
from datetime import datetime
from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Inicialização da aplicação Flask
app = Flask(__name__)

# Configurações AWS
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
AWS_REGION = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')

# Cliente SQS
sqs_client = boto3.client('sqs', region_name=AWS_REGION)

class URLShortenerAPI:
    """Classe principal para o serviço de encurtamento de URLs"""
    
    def __init__(self):
        self.base_url = "https://short.ly/"  # URL base fictícia
    
    def generate_short_code(self):
        """Gera um código único para a URL encurtada"""
        return str(uuid.uuid4())[:8]
    
    def send_to_queue(self, message_data):
        """Envia mensagem para a fila SQS"""
        try:
            message_body = json.dumps(message_data)
            
            response = sqs_client.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=message_body,
                MessageAttributes={
                    'MessageType': {
                        'StringValue': 'URL_PROCESSING',
                        'DataType': 'String'
                    },
                    'Timestamp': {
                        'StringValue': datetime.utcnow().isoformat(),
                        'DataType': 'String'
                    }
                }
            )
            
            logger.info(f"Mensagem enviada para SQS: {response['MessageId']}")
            return response['MessageId']
            
        except ClientError as e:
            logger.error(f"Erro ao enviar mensagem para SQS: {e}")
            raise
        except Exception as e:
            logger.error(f"Erro inesperado: {e}")
            raise

# Instância do serviço
url_service = URLShortenerAPI()

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de health check para ALB"""
    return jsonify({
        'status': 'healthy',
        'service': 'api-service',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '1.0.0'
    }), 200

@app.route('/shorten', methods=['POST'])
def shorten_url():
    """Endpoint principal para encurtar URLs"""
    try:
        # Validação do payload
        if not request.is_json:
            return jsonify({
                'error': 'Content-Type deve ser application/json'
            }), 400
        
        data = request.get_json()
        
        if not data or 'url' not in data:
            return jsonify({
                'error': 'Campo "url" é obrigatório'
            }), 400
        
        original_url = data['url']
        
        # Validação básica da URL
        if not original_url.startswith(('http://', 'https://')):
            return jsonify({
                'error': 'URL deve começar com http:// ou https://'
            }), 400
        
        # Geração do código único
        short_code = url_service.generate_short_code()
        short_url = f"{url_service.base_url}{short_code}"
        
        # Preparação da mensagem para SQS
        message_data = {
            'request_id': str(uuid.uuid4()),
            'short_code': short_code,
            'original_url': original_url,
            'short_url': short_url,
            'created_at': datetime.utcnow().isoformat(),
            'user_agent': request.headers.get('User-Agent', 'Unknown'),
            'ip_address': request.remote_addr
        }
        
        # Envio para fila SQS
        message_id = url_service.send_to_queue(message_data)
        
        logger.info(f"URL processada: {original_url} -> {short_url}")
        
        # Resposta de sucesso
        return jsonify({
            'success': True,
            'data': {
                'original_url': original_url,
                'short_url': short_url,
                'short_code': short_code,
                'message_id': message_id,
                'created_at': message_data['created_at']
            }
        }), 201
        
    except ClientError as e:
        logger.error(f"Erro AWS: {e}")
        return jsonify({
            'error': 'Erro interno do serviço',
            'details': 'Falha na comunicação com SQS'
        }), 502
        
    except Exception as e:
        logger.error(f"Erro não tratado: {e}")
        return jsonify({
            'error': 'Erro interno do servidor'
        }), 500

@app.route('/stats', methods=['GET'])
def get_stats():
    """Endpoint para estatísticas básicas do serviço"""
    return jsonify({
        'service': 'api-service',
        'version': '1.0.0',
        'sqs_queue_configured': bool(SQS_QUEUE_URL),
        'aws_region': AWS_REGION,
        'timestamp': datetime.utcnow().isoformat()
    }), 200

@app.route('/', methods=['GET'])
def root():
    """Endpoint raiz com informações da API"""
    return jsonify({
        'service': 'URL Shortener API',
        'version': '1.0.0',
        'endpoints': {
            'POST /shorten': 'Encurtar uma URL',
            'GET /health': 'Health check',
            'GET /stats': 'Estatísticas do serviço',
            'GET /': 'Esta página'
        },
        'example': {
            'request': {
                'method': 'POST',
                'url': '/shorten',
                'body': {
                    'url': 'https://www.example.com/very/long/url'
                }
            },
            'response': {
                'success': True,
                'data': {
                    'original_url': 'https://www.example.com/very/long/url',
                    'short_url': 'https://short.ly/abc12345',
                    'short_code': 'abc12345'
                }
            }
        }
    }), 200

@app.errorhandler(404)
def not_found(error):
    """Handler para recursos não encontrados"""
    return jsonify({
        'error': 'Endpoint não encontrado',
        'available_endpoints': ['/shorten', '/health', '/stats', '/']
    }), 404

@app.errorhandler(405)
def method_not_allowed(error):
    """Handler para métodos não permitidos"""
    return jsonify({
        'error': 'Método não permitido para este endpoint'
    }), 405

if __name__ == '__main__':
    # Validação de configurações necessárias
    if not SQS_QUEUE_URL:
        logger.error("Variável de ambiente SQS_QUEUE_URL não configurada!")
        exit(1)
    
    logger.info(f"Iniciando API Service na porta 8080")
    logger.info(f"SQS Queue URL: {SQS_QUEUE_URL}")
    logger.info(f"AWS Region: {AWS_REGION}")
    
    # Executar a aplicação
    app.run(host='0.0.0.0', port=8080, debug=False) 