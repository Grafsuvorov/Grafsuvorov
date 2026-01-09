import httpx
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from api.core.config import settings
from typing import Optional
import logging
import os

logger = logging.getLogger(__name__)

class YandexSMTPEmailService:
    """Яндекс SMTP сервис для отправки email"""

    def __init__(self):
        self.smtp_server = "smtp.yandex.ru"
        self.smtp_port = 587
        self.username = settings.FROM_EMAIL
        self.password = os.getenv("YANDEX_APP_PASSWORD", "")

    async def send_verification_email(self, email: str, username: str, verification_token: str) -> bool:
        """Отправляет email для верификации"""
        subject = "Подтверждение регистрации - Football App"

        # Создаем ссылку на веб-страницу верификации
        verification_url = f"{settings.FRONTEND_URL}/verify?token={verification_token}"

        html_body = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; border-radius: 10px 10px 0 0; }}
                .content {{ background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }}
                .button {{ display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }}
                .footer {{ text-align: center; margin-top: 30px; color: #666; font-size: 0.9em; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>⚽ Football App</h1>
                    <h2>Подтверждение регистрации</h2>
                </div>
                <div class="content">
                    <p>Здравствуйте, <strong>{username}</strong>!</p>
                    
                    <p>Спасибо за регистрацию в Football App. Для завершения регистрации необходимо подтвердить ваш email адрес.</p>
                    
                    <p style="text-align: center;">
                        <a href="{verification_url}" class="button">Подтвердить Email</a>
                    </p>
                    
                    <p>Если кнопка не работает, скопируйте и вставьте следующую ссылку в браузер:</p>
                    <p style="word-break: break-all; background: #eee; padding: 10px; border-radius: 5px;">
                        <a href="{verification_url}">{verification_url}</a>
                    </p>
                    
                    <p><strong>Важно:</strong> Эта ссылка действительна в течение 24 часов.</p>
                    
                    <p>Если вы не регистрировались в Football App, просто проигнорируйте это письмо.</p>
                </div>
                <div class="footer">
                    <p>© 2024 Football App. Все права защищены.</p>
                </div>
            </div>
        </body>
        </html>
        """

        return await self._send_email(email, subject, html_body)

    async def send_password_reset_email(self, email: str, username: str, reset_token: str) -> bool:
        """Отправляет email для сброса пароля"""
        try:
            reset_url = f"{settings.FRONTEND_URL}/reset-password?token={reset_token}"

            subject = "Сброс пароля"
            html_body = f"""
            <html>
            <body>
                <h2>Здравствуйте, {username}!</h2>
                <p>Вы запросили сброс пароля. Для создания нового пароля перейдите по ссылке:</p>
                <p><a href="{reset_url}">Сбросить пароль</a></p>
                <p>Если ссылка не работает, скопируйте и вставьте в браузер:</p>
                <p>{reset_url}</p>
                <p>Если вы не запрашивали сброс пароля, проигнорируйте это письмо.</p>
                <p>С уважением,<br>Команда Football App</p>
            </body>
            </html>
            """

            return await self._send_email(email, subject, html_body)

        except Exception as e:
            logger.error(f"Error sending password reset email: {e}")
            return False

    async def _send_email(self, email: str, subject: str, html_body: str) -> bool:
        """Отправляет email через Яндекс SMTP"""
        try:
            if not self.password:
                logger.warning("Yandex app password not configured")
                return False

            logger.info(f"Attempting to send email to {email} via Yandex SMTP")
            logger.info(f"Using SMTP server: {self.smtp_server}:{self.smtp_port}")
            logger.info(f"Using username: {self.username}")

            # Создаем сообщение
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = self.username
            msg['To'] = email

            # Добавляем HTML часть
            html_part = MIMEText(html_body, 'html')
            msg.attach(html_part)

            # Отправляем email через SMTP
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()  # Включаем шифрование
                server.login(self.username, self.password)
                server.send_message(msg)

            logger.info(f"Email sent successfully via Yandex SMTP to {email}")
            return True

        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"SMTP Authentication failed: {e}")
            return False
        except smtplib.SMTPException as e:
            logger.error(f"SMTP error: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return False

# Создаем основной экземпляр сервиса
email_service = YandexSMTPEmailService()
