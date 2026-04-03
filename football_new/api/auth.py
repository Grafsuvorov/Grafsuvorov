from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import Optional
import logging

from api.database import get_db
from api.dwh_database import (
    get_dwh_db, create_dwh_users_table, get_user_by_email, 
    create_user_in_dwh, update_user_verification_in_dwh,
    get_user_by_verification_token, update_user_refresh_token_in_dwh
)
from api.models.user import User
from api.schemas.auth import (
    UserRegister, UserLogin, UserResponse, Token, 
    VerificationRequest, PasswordResetRequest, 
    PasswordResetConfirm, MessageResponse
)
from api.core.security import (
    verify_password, get_password_hash, create_access_token,
    create_refresh_token, verify_access_token, verify_refresh_token,
    generate_verification_token, generate_reset_token
)
from api.core.config import settings
from api.services.email import YandexSMTPEmailService

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Создаем роутер
router = APIRouter(prefix="/auth", tags=["authentication"])

# Схема безопасности
security = HTTPBearer()

# Создаем экземпляр email сервиса
email_service = YandexSMTPEmailService()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """Получает текущего пользователя по JWT токену"""
    token = credentials.credentials
    email = verify_access_token(token)
    if email is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user

@router.post("/register", response_model=MessageResponse)
async def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """Регистрация нового пользователя"""
    try:
        if len(user_data.password.encode("utf-8")) > 72:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Password too long (max 72 bytes for bcrypt)"
            )
        # Проверяем, существует ли пользователь с таким email
        existing_user = db.query(User).filter(User.email == user_data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Проверяем, существует ли пользователь с таким username
        existing_username = db.query(User).filter(User.username == user_data.username).first()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken"
            )
        
        # Создаем токен верификации
        verification_token = generate_verification_token()
        verification_expires = datetime.now(timezone.utc) + timedelta(hours=24)
        
        # Создаем нового пользователя
        hashed_password = get_password_hash(user_data.password)
        new_user = User(
            email=user_data.email,
            username=user_data.username,
            hashed_password=hashed_password,
            verification_token=verification_token,
            verification_token_expires=verification_expires
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        # Отправляем email для верификации
        email_sent = await email_service.send_verification_email(
            user_data.email, user_data.username, verification_token
        )
        
        if not email_sent:
            logger.warning(f"Failed to send verification email to {user_data.email}")
        
        return MessageResponse(
            message="Registration successful. Please check your email to verify your account."
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error: {e}")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.post("/login", response_model=Token)
async def login(user_data: UserLogin, db: Session = Depends(get_db)):
    """Вход пользователя в систему"""
    try:
        # Ищем пользователя по email
        user = db.query(User).filter(User.email == user_data.email).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password"
            )
        
        # Проверяем пароль
        if not verify_password(user_data.password, user.hashed_password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password"
            )
        
        # Проверяем, верифицирован ли пользователь
        if not user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Please verify your email before logging in"
            )
        
        # Создаем JWT токен
        access_token = create_access_token(data={"sub": user.email})
        refresh_token = create_refresh_token(data={"sub": user.email})
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        update_user_refresh_token_in_dwh(user.email, refresh_token, refresh_expires)
        
        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserResponse(
                id=user.id,
                email=user.email,
                username=user.username,
                is_verified=user.is_verified,
                created_at=user.created_at
            )
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.post("/verify", response_model=MessageResponse)
async def verify_email(verification: VerificationRequest, db: Session = Depends(get_db)):
    """Верификация email пользователя"""
    try:
        # Ищем пользователя по токену верификации
        user = db.query(User).filter(
                    User.verification_token == verification.token,
        User.verification_token_expires > datetime.now(timezone.utc)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification token"
            )
        
        # Верифицируем пользователя
        user.is_verified = True
        user.verification_token = None
        user.verification_token_expires = None
        
        db.commit()
        
        return MessageResponse(message="Email verified successfully. You can now log in.")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Verification error: {e}")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(request: PasswordResetRequest, db: Session = Depends(get_db)):
    """Запрос на сброс пароля"""
    try:
        # Ищем пользователя по email
        user = db.query(User).filter(User.email == request.email).first()
        if not user:
            # Не раскрываем информацию о существовании пользователя
            return MessageResponse(
                message="If the email exists, a password reset link has been sent."
            )
        
        # Генерируем токен для сброса пароля
        reset_token = generate_reset_token()
        reset_expires = datetime.now(timezone.utc) + timedelta(hours=1)
        
        user.reset_password_token = reset_token
        user.reset_password_token_expires = reset_expires
        
        db.commit()
        
        # Отправляем email для сброса пароля
        email_sent = await email_service.send_password_reset_email(
            user.email, user.username, reset_token
        )
        
        if not email_sent:
            logger.warning(f"Failed to send password reset email to {user.email}")
        
        return MessageResponse(
            message="If the email exists, a password reset link has been sent."
        )
        
    except Exception as e:
        logger.error(f"Forgot password error: {e}")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(reset_data: PasswordResetConfirm, db: Session = Depends(get_db)):
    """Сброс пароля по токену"""
    try:
        # Ищем пользователя по токену сброса пароля
        user = db.query(User).filter(
                    User.reset_password_token == reset_data.token,
        User.reset_password_token_expires > datetime.now(timezone.utc)
        ).first()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired reset token"
            )
        
        # Обновляем пароль
        user.hashed_password = get_password_hash(reset_data.new_password)
        user.reset_password_token = None
        user.reset_password_token_expires = None
        
        db.commit()
        
        return MessageResponse(message="Password reset successfully.")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Reset password error: {e}")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Получение информации о текущем пользователе"""
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        username=current_user.username,
        is_verified=current_user.is_verified,
        created_at=current_user.created_at
    )

@router.post("/resend-verification", response_model=MessageResponse)
async def resend_verification(email: str, db: Session = Depends(get_db)):
    """Повторная отправка email для верификации"""
    try:
        # Ищем пользователя по email
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        if user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already verified"
            )
        
        # Генерируем новый токен верификации
        verification_token = generate_verification_token()
        verification_expires = datetime.now(timezone.utc) + timedelta(hours=24)
        
        user.verification_token = verification_token
        user.verification_token_expires = verification_expires
        
        db.commit()
        
        # Отправляем email для верификации
        email_sent = await email_service.send_verification_email(
            user.email, user.username, verification_token
        )
        
        if not email_sent:
            logger.warning(f"Failed to send verification email to {user.email}")
        
        return MessageResponse(
            message="Verification email sent successfully."
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Resend verification error: {e}")
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )
