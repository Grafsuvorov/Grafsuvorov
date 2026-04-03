import httpx
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from api.core.config import settings
from typing import Optional
import logging
import os

logger = logging.getLogger(__name__)

class SMTPEmailService:
    """Универсальный SMTP сервис для отправки email"""

    def __init__(self):
        self.smtp_server = settings.SMTP_SERVER or "smtp.yandex.ru"
        self.smtp_port = settings.SMTP_PORT or 587
        self.username = settings.SMTP_LOGIN or settings.FROM_EMAIL
        self.password = settings.SMTP_PASS or os.getenv("YANDEX_APP_PASSWORD", "")
        self.from_email = settings.FROM_EMAIL or self.username
        self.from_header = f"EdgeScore <{self.from_email}>" if self.from_email else self.username
        self.use_ssl = int(self.smtp_port) == 465

    async def send_verification_email(self, email: str, username: str, verification_token: str) -> bool:
        """Отправляет email для верификации"""
        subject = "Подтвердите email — EdgeScore"

        # Создаем ссылку на веб-страницу верификации
        verification_url = f"{settings.FRONTEND_URL}/verify?token={verification_token}"

        html_body = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #e5e7eb; background: #0b0f1a; }}
                .container {{ max-width: 620px; margin: 0 auto; padding: 24px; }}
                .card {{ background: #111827; border-radius: 14px; overflow: hidden; border: 1px solid #1f2937; }}
                .header {{ padding: 22px 24px; background: radial-gradient(circle at 20% 0%, #1f2937 0%, #0f172a 60%); }}
                .brand {{ font-weight: 700; letter-spacing: 0.2em; font-size: 12px; text-transform: uppercase; color: #94a3b8; }}
                .title {{ font-size: 22px; font-weight: 600; color: #f8fafc; margin: 6px 0 0; }}
                .content {{ padding: 24px; background: #0f172a; }}
                .button {{ display: inline-block; background: #22c55e; color: #0b0f1a; padding: 12px 28px; text-decoration: none; border-radius: 999px; font-weight: 600; margin: 18px 0; }}
                .muted {{ color: #94a3b8; font-size: 13px; }}
                .code {{ background: #0b1220; color: #e2e8f0; padding: 10px 12px; border-radius: 8px; word-break: break-all; border: 1px solid #1f2937; }}
                .footer {{ text-align: center; margin-top: 24px; color: #64748b; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="card">
                  <div class="header">
                    <div class="brand">EdgeScore</div>
                    <div class="title">Подтвердите адрес email</div>
                  </div>
                  <div class="content">
                    <p>Привет, <strong>{username}</strong>!</p>
                    <p>Спасибо за регистрацию в EdgeScore. Чтобы активировать аккаунт, подтвердите email.</p>
                    <p style="text-align: center;">
                        <a href="{verification_url}" class="button">Подтвердить email</a>
                    </p>
                    <p class="muted">Если кнопка не работает, откройте ссылку вручную:</p>
                    <p class="code"><a href="{verification_url}" style="color:#e2e8f0;">{verification_url}</a></p>
                    <p class="muted"><strong>Важно:</strong> ссылка действует 24 часа.</p>
                    <p class="muted">Если вы не регистрировались в EdgeScore, просто проигнорируйте это письмо.</p>
                  </div>
                </div>
                <div class="footer">
                    <p>© 2026 EdgeScore. Все права защищены.</p>
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

            subject = "Сброс пароля — EdgeScore"
            html_body = f"""
            <html>
            <body>
                <h2>Привет, {username}!</h2>
                <p>Вы запросили сброс пароля в EdgeScore. Перейдите по ссылке:</p>
                <p><a href="{reset_url}">Сбросить пароль</a></p>
                <p>Если ссылка не работает, скопируйте и вставьте в браузер:</p>
                <p>{reset_url}</p>
                <p>Если вы не запрашивали сброс пароля, просто проигнорируйте это письмо.</p>
                <p>Команда EdgeScore</p>
            </body>
            </html>
            """

            return await self._send_email(email, subject, html_body)

        except Exception as e:
            logger.error(f"Error sending password reset email: {e}")
            return False

    async def _send_email(self, email: str, subject: str, html_body: str) -> bool:
        """Отправляет email через SMTP"""
        try:
            if not self.password:
                logger.warning("SMTP password not configured")
                return False

            logger.info(f"Attempting to send email to {email} via SMTP")
            logger.info(f"Using SMTP server: {self.smtp_server}:{self.smtp_port}")
            logger.info(f"Using username: {self.username}")

            # Создаем сообщение
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = self.from_header
            msg['To'] = email
            if self.from_email:
                msg['Reply-To'] = self.from_email

            # Добавляем HTML часть
            html_part = MIMEText(html_body, 'html')
            msg.attach(html_part)

            # Отправляем email через SMTP
            smtp_cls = smtplib.SMTP_SSL if self.use_ssl else smtplib.SMTP
            with smtp_cls(self.smtp_server, self.smtp_port) as server:
                if not self.use_ssl:
                    server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)

            logger.info(f"Email sent successfully via SMTP to {email}")
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

# backward-compatible alias for old imports
YandexSMTPEmailService = SMTPEmailService

# Создаем основной экземпляр сервиса
email_service = SMTPEmailService()
