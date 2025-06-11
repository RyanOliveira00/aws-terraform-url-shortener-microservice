#!/usr/bin/env python3
"""
Processing Service - Worker para processamento de URLs
Responsável por consumir mensagens da fila SQS e processar URLs encurtadas
"""

import os
import json
import time
import logging
import signal
import sys
from datetime import datetime
from typing import Dict, Any
import boto3
from botocore.exceptions import ClientError

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configurações AWS
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
AWS_REGION = os.environ.get('AWS_DEFAULT_REGION', 'us-east-1')

# Configurações do worker
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '5'))  # segundos
MAX_MESSAGES = int(os.environ.get('MAX_MESSAGES', '10'))
VISIBILITY_TIMEOUT = int(os.environ.get('VISIBILITY_TIMEOUT', '30'))

# Cliente SQS
sqs_client = boto3.client('sqs', region_name=AWS_REGION)

class URLProcessor:
    """Classe responsável pelo processamento de URLs"""
    
    def __init__(self):
        self.processed_count = 0
        self.error_count = 0
        self.start_time = datetime.utcnow()
        self.running = True
    
    def process_url_message(self, message_data: Dict[str, Any]) -> bool:
        """
        Processa uma mensagem de URL
        
        Args:
            message_data: Dados da mensagem contendo informações da URL
            
        Returns:
            bool: True se processado com sucesso, False caso contrário
        """
        try:
            # Extração dos dados da mensagem
            request_id = message_data.get('request_id')
            short_code = message_data.get('short_code')
            original_url = message_data.get('original_url')
            short_url = message_data.get('short_url')
            created_at = message_data.get('created_at')
            
            logger.info(f"Processando URL - Request ID: {request_id}")
            logger.info(f"Original: {original_url} -> Short: {short_url}")
            
            # Simulação de validação da URL original
            if not self._validate_url(original_url):
                logger.warning(f"URL inválida detectada: {original_url}")
                return False
            
            # Simulação de salvamento no banco de dados
            database_record = {
                'short_code': short_code,
                'original_url': original_url,
                'short_url': short_url,
                'created_at': created_at,
                'processed_at': datetime.utcnow().isoformat(),
                'status': 'active',
                'click_count': 0
            }
            
            # Simula tempo de processamento (ex: salvamento em banco)
            time.sleep(0.5)
            
            # Log do "salvamento" (em produção seria uma operação de banco real)
            logger.info(f"URL salva no banco: {short_code} -> {original_url}")
            
            # Simulação de indexação para busca (opcional)
            self._index_url_for_search(database_record)
            
            # Simulação de notificações (opcional)
            self._send_analytics_event(database_record)
            
            self.processed_count += 1
            logger.info(f"Processamento concluído - Request ID: {request_id}")
            
            return True
            
        except Exception as e:
            logger.error(f"Erro no processamento da URL: {e}")
            self.error_count += 1
            return False
    
    def _validate_url(self, url: str) -> bool:
        """Valida se a URL é acessível"""
        try:
            # Simulação de validação (em produção faria uma requisição HTTP)
            if not url or len(url) < 10:
                return False
            
            # Lista de domínios bloqueados (exemplo)
            blocked_domains = ['malware.com', 'spam.site']
            for domain in blocked_domains:
                if domain in url:
                    logger.warning(f"URL bloqueada por conter domínio suspeito: {domain}")
                    return False
            
            return True
            
        except Exception as e:
            logger.error(f"Erro na validação da URL: {e}")
            return False
    
    def _index_url_for_search(self, record: Dict[str, Any]):
        """Simula indexação da URL para sistema de busca"""
        try:
            # Em produção, enviaria para Elasticsearch, OpenSearch, etc.
            logger.debug(f"URL indexada para busca: {record['short_code']}")
        except Exception as e:
            logger.warning(f"Erro na indexação: {e}")
    
    def _send_analytics_event(self, record: Dict[str, Any]):
        """Simula envio de evento para sistema de analytics"""
        try:
            # Em produção, enviaria para CloudWatch, DataDog, etc.
            analytics_event = {
                'event_type': 'url_created',
                'short_code': record['short_code'],
                'timestamp': record['processed_at']
            }
            logger.debug(f"Evento de analytics enviado: {analytics_event}")
        except Exception as e:
            logger.warning(f"Erro no envio de analytics: {e}")
    
    def get_stats(self) -> Dict[str, Any]:
        """Retorna estatísticas do processamento"""
        uptime = datetime.utcnow() - self.start_time
        return {
            'processed_count': self.processed_count,
            'error_count': self.error_count,
            'uptime_seconds': uptime.total_seconds(),
            'success_rate': (
                self.processed_count / (self.processed_count + self.error_count) * 100
                if (self.processed_count + self.error_count) > 0 else 0
            )
        }

class SQSWorker:
    """Worker principal que consome mensagens do SQS"""
    
    def __init__(self):
        self.processor = URLProcessor()
        self.running = True
        
        # Configuração de handlers para sinais do sistema
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handler para sinais de terminação"""
        logger.info(f"Sinal {signum} recebido. Finalizando worker graciosamente...")
        self.running = False
        self.processor.running = False
    
    def poll_messages(self):
        """Polling principal de mensagens do SQS"""
        logger.info("Iniciando polling de mensagens...")
        
        while self.running:
            try:
                # Recebimento de mensagens do SQS
                response = sqs_client.receive_message(
                    QueueUrl=SQS_QUEUE_URL,
                    MaxNumberOfMessages=MAX_MESSAGES,
                    WaitTimeSeconds=20,  # Long polling
                    VisibilityTimeoutSeconds=VISIBILITY_TIMEOUT,
                    MessageAttributeNames=['All']
                )
                
                messages = response.get('Messages', [])
                
                if not messages:
                    logger.debug("Nenhuma mensagem recebida, continuando polling...")
                    continue
                
                logger.info(f"Recebidas {len(messages)} mensagens para processamento")
                
                # Processamento de cada mensagem
                for message in messages:
                    if not self.running:
                        break
                    
                    self._process_message(message)
                
                # Log de estatísticas a cada ciclo
                stats = self.processor.get_stats()
                logger.info(f"Stats: {stats['processed_count']} processadas, "
                           f"{stats['error_count']} erros, "
                           f"{stats['success_rate']:.1f}% sucesso")
                
            except ClientError as e:
                logger.error(f"Erro AWS no polling: {e}")
                time.sleep(POLL_INTERVAL)
                
            except Exception as e:
                logger.error(f"Erro não tratado no polling: {e}")
                time.sleep(POLL_INTERVAL)
        
        logger.info("Worker finalizado.")
    
    def _process_message(self, message: Dict[str, Any]):
        """Processa uma mensagem individual"""
        try:
            message_body = message['Body']
            receipt_handle = message['ReceiptHandle']
            
            # Parse do JSON da mensagem
            message_data = json.loads(message_body)
            
            # Log da mensagem recebida
            logger.info(f"Processando mensagem: {message.get('MessageId', 'unknown')}")
            
            # Processamento da URL
            success = self.processor.process_url_message(message_data)
            
            if success:
                # Remoção da mensagem da fila após processamento bem-sucedido
                sqs_client.delete_message(
                    QueueUrl=SQS_QUEUE_URL,
                    ReceiptHandle=receipt_handle
                )
                logger.info("Mensagem processada e removida da fila")
            else:
                logger.warning("Falha no processamento - mensagem retornará à fila")
                
        except json.JSONDecodeError as e:
            logger.error(f"Erro no parse JSON da mensagem: {e}")
            # Remove mensagem malformada
            try:
                sqs_client.delete_message(
                    QueueUrl=SQS_QUEUE_URL,
                    ReceiptHandle=message['ReceiptHandle']
                )
                logger.info("Mensagem malformada removida da fila")
            except Exception:
                pass
                
        except Exception as e:
            logger.error(f"Erro no processamento da mensagem: {e}")

def main():
    """Função principal do worker"""
    logger.info("=== URL Processing Service ===")
    logger.info(f"Version: 1.0.0")
    logger.info(f"SQS Queue: {SQS_QUEUE_URL}")
    logger.info(f"AWS Region: {AWS_REGION}")
    logger.info(f"Poll Interval: {POLL_INTERVAL}s")
    logger.info(f"Max Messages: {MAX_MESSAGES}")
    
    # Validação de configurações
    if not SQS_QUEUE_URL:
        logger.error("Variável de ambiente SQS_QUEUE_URL não configurada!")
        sys.exit(1)
    
    # Teste de conectividade com SQS
    try:
        sqs_client.get_queue_attributes(
            QueueUrl=SQS_QUEUE_URL,
            AttributeNames=['QueueArn']
        )
        logger.info("Conectividade com SQS verificada com sucesso")
    except Exception as e:
        logger.error(f"Falha na conectividade com SQS: {e}")
        sys.exit(1)
    
    # Inicialização e execução do worker
    worker = SQSWorker()
    
    try:
        logger.info("Worker iniciado. Pressione Ctrl+C para parar.")
        worker.poll_messages()
    except KeyboardInterrupt:
        logger.info("Interrupção do usuário detectada")
    except Exception as e:
        logger.error(f"Erro fatal no worker: {e}")
        sys.exit(1)
    finally:
        # Log final de estatísticas
        final_stats = worker.processor.get_stats()
        logger.info(f"Estatísticas finais: {final_stats}")
        logger.info("Worker finalizado com sucesso")

if __name__ == '__main__':
    main() 