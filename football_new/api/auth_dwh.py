from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import Optional
import logging

from api.dwh_database import (
    get_dwh_db, create_dwh_users_table, get_user_by_email, get_user_by_username,
    create_user_in_dwh, update_user_verification_in_dwh,
    get_user_by_verification_token
)
from api.schemas.auth import (
    UserRegister, UserLogin, UserResponse, Token, 
    VerificationRequest, PasswordResetRequest, 
    PasswordResetConfirm, MessageResponse
)
from api.core.security import (
    verify_password, get_password_hash, create_access_token, 
    verify_token, generate_verification_token, generate_reset_token
)
from api.services.email import YandexSMTPEmailService

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Создаем роутер для DWH
router = APIRouter(
    prefix="/auth-dwh", 
    tags=["Аутентификация"],
    responses={404: {"description": "Not found"}}
)

# Схема безопасности
security = HTTPBearer()

# Создаем экземпляр email сервиса
email_service = YandexSMTPEmailService()

def get_current_user_dwh(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_dwh_db)
) -> dict:
    """Получает текущего пользователя по JWT токену из DWH"""
    token = credentials.credentials
    email = verify_token(token)
    if email is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = get_user_by_email(email)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user

@router.post("/register", response_model=MessageResponse)
async def register_dwh(user_data: UserRegister, db: Session = Depends(get_dwh_db)):
    """Регистрация нового пользователя в DWH"""
    try:
        # Создаем таблицу users в DWH если её нет
        create_dwh_users_table()
        
        # Проверяем, существует ли пользователь с таким email
        existing_user = get_user_by_email(user_data.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Проверяем, существует ли пользователь с таким username
        existing_username = get_user_by_username(user_data.username)
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already registered"
            )
        
        # Создаем токен верификации
        verification_token = generate_verification_token()
        verification_expires = datetime.now(timezone.utc) + timedelta(hours=24)
        
        # Создаем нового пользователя в DWH
        hashed_password = get_password_hash(user_data.password)
        user_data_dict = {
            "email": user_data.email,
            "username": user_data.username,
            "hashed_password": hashed_password,
            "is_verified": False,
            "verification_token": verification_token,
            "verification_token_expires": verification_expires
        }
        
        user_id = create_user_in_dwh(user_data_dict)
        
        # Отправляем email для верификации
        email_sent = await email_service.send_verification_email(
            user_data.email, user_data.username, verification_token
        )
        
        if not email_sent:
            logger.warning(f"Failed to send verification email to {user_data.email}")
        
        return MessageResponse(
            message="Registration successful in DWH. Please check your email to verify your account."
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Registration error in DWH: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.post("/login", response_model=Token)
async def login_dwh(user_data: UserLogin, db: Session = Depends(get_dwh_db)):
    """Вход пользователя в систему из DWH"""
    try:
        # Ищем пользователя по email в DWH
        user = get_user_by_email(user_data.email)
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
        
        return Token(
            access_token=access_token,
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
        logger.error(f"Login error in DWH: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.post("/verify", response_model=MessageResponse)
async def verify_email_dwh(verification: VerificationRequest, db: Session = Depends(get_dwh_db)):
    """Верификация email пользователя в DWH"""
    try:
        # Ищем пользователя по токену верификации в DWH
        user = get_user_by_verification_token(verification.token)
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid or expired verification token"
            )
        
        logger.info(f"Found user for verification: {user.email}")
        
        # Обновляем статус верификации в DWH
        success = update_user_verification_in_dwh(user.email, True)
        
        if not success:
            logger.error(f"Failed to update verification status for {user.email}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Failed to verify user"
            )
        
        logger.info(f"Successfully verified user {user.email}")
        return MessageResponse(message="Email verified successfully in DWH. You can now log in.")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Verification error in DWH: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error"
        )

@router.get("/me", response_model=UserResponse)
async def get_current_user_info_dwh(current_user: dict = Depends(get_current_user_dwh)):
    """Получение информации о текущем пользователе из DWH"""
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        username=current_user.username,
        is_verified=current_user.is_verified,
        created_at=current_user.created_at
    )
