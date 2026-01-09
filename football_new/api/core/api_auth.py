# api/core/api_auth.py
from fastapi import HTTPException, Depends, Request, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from typing import Optional
import json
import ipaddress
from datetime import datetime, timedelta

from api.database import get_db
from api.models import User, APIClient, APIRole, APIUsage
from api.core.security import verify_token

security = HTTPBearer(auto_error=False)

def get_client_ip(request: Request) -> str:
    """Получает IP адрес клиента"""
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    return request.client.host

def is_from_your_website(request: Request) -> bool:
    """Проверяет, идет ли запрос с вашего сайта"""
    origin = request.headers.get("origin")
    referer = request.headers.get("referer")
    
    allowed_origins = [
        "https://your-website.com",
        "https://www.your-website.com", 
        "http://localhost:3000",  # Для разработки
        "http://localhost:3001"   # Для разработки
    ]
    
    if origin and origin in allowed_origins:
        return True
    
    if referer:
        for allowed in allowed_origins:
            if referer.startswith(allowed):
                return True
    
    return False

def is_ip_whitelisted(client_ip: str, api_client: APIClient) -> bool:
    """Проверяет, разрешен ли IP для API клиента"""
    if not api_client.ip_whitelist:
        return True  # Если нет ограничений по IP
    
    try:
        allowed_ips = json.loads(api_client.ip_whitelist)
        client_ip_obj = ipaddress.ip_address(client_ip)
        
        for allowed_ip in allowed_ips:
            if "/" in allowed_ip:  # CIDR блок
                if client_ip_obj in ipaddress.ip_network(allowed_ip):
                    return True
            else:  # Одиночный IP
                if str(client_ip_obj) == allowed_ip:
                    return True
    except (json.JSONDecodeError, ValueError):
        pass
    
    return False

def check_api_quota(api_client: APIClient, db: Session) -> bool:
    """Проверяет, не превышена ли квота API"""
    if api_client.quota_monthly == -1:  # Безлимит
        return True
    
    # Проверяем, нужно ли сбросить квоту
    now = datetime.utcnow()
    if not api_client.quota_reset_date or now >= api_client.quota_reset_date:
        # Сбрасываем квоту
        api_client.used_current_month = 0
        api_client.quota_reset_date = now + timedelta(days=30)
        db.commit()
    
    return api_client.used_current_month < api_client.quota_monthly

def increment_api_usage(api_client: APIClient, db: Session):
    """Увеличивает счетчик использования API"""
    api_client.used_current_month += 1
    api_client.last_used = datetime.utcnow()
    db.commit()

def log_api_usage(
    api_client: Optional[APIClient],
    request: Request,
    endpoint: str,
    method: str,
    status_code: int,
    response_time_ms: int,
    db: Session
):
    """Логирует использование API"""
    usage = APIUsage(
        api_client_id=api_client.id if api_client else None,
        endpoint=endpoint,
        method=method,
        ip_address=get_client_ip(request),
        response_status=status_code,
        response_time_ms=response_time_ms
    )
    db.add(usage)
    db.commit()

# Зависимости для проверки доступа

def require_website_access(request: Request):
    """Требует, чтобы запрос шел с вашего сайта"""
    if not is_from_your_website(request):
        raise HTTPException(
            status_code=403,
            detail="This endpoint is only accessible through the website"
        )

def get_current_user_from_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """Получает пользователя сайта из JWT токена"""
    if not credentials:
        return None
    
    try:
        payload = verify_token(credentials.credentials)
        user_id = payload.get("user_id")
        if not user_id:
            return None
        
        user = db.query(User).filter(User.id == user_id).first()
        return user
    except:
        return None

def get_api_client_from_key(
    x_api_key: Optional[str] = Header(None),
    db: Session = Depends(get_db)
) -> Optional[APIClient]:
    """Получает API клиента из API ключа"""
    if not x_api_key:
        return None
    
    api_client = db.query(APIClient).filter(
        APIClient.api_key == x_api_key,
        APIClient.is_active == True
    ).first()
    
    return api_client

def require_user_auth(
    current_user: Optional[User] = Depends(get_current_user_from_token)
) -> User:
    """Требует авторизации пользователя сайта"""
    if not current_user:
        raise HTTPException(
            status_code=401,
            detail="Authentication required. Please login to your account."
        )
    return current_user

def require_api_access(
    request: Request,
    api_client: Optional[APIClient] = Depends(get_api_client_from_key),
    db: Session = Depends(get_db)
) -> APIClient:
    """Требует API ключ для доступа"""
    if not api_client:
        raise HTTPException(
            status_code=401,
            detail="API key required. Provide X-API-Key header."
        )
    
    # Проверяем IP для бизнес-клиентов
    if api_client.role == APIRole.BUSINESS.value and not is_ip_whitelisted(get_client_ip(request), api_client):
        raise HTTPException(
            status_code=403,
            detail="IP address not whitelisted for business access"
        )
    
    # Проверяем квоту
    if not check_api_quota(api_client, db):
        raise HTTPException(
            status_code=429,
            detail="API quota exceeded. Please upgrade your plan."
        )
    
    # Увеличиваем счетчик использования
    increment_api_usage(api_client, db)
    
    return api_client

def require_premium_api(api_client: APIClient = Depends(require_api_access)) -> APIClient:
    """Требует премиум API доступ"""
    if api_client.role not in [APIRole.PREMIUM.value, APIRole.BUSINESS.value, APIRole.ADMIN.value]:
        raise HTTPException(
            status_code=403,
            detail="Premium API access required"
        )
    return api_client

def require_business_api(api_client: APIClient = Depends(require_api_access)) -> APIClient:
    """Требует бизнес API доступ"""
    if api_client.role not in [APIRole.BUSINESS.value, APIRole.ADMIN.value]:
        raise HTTPException(
            status_code=403,
            detail="Business API access required"
        )
    return api_client

def require_admin_api(api_client: APIClient = Depends(require_api_access)) -> APIClient:
    """Требует админ API доступ"""
    if api_client.role != APIRole.ADMIN.value:
        raise HTTPException(
            status_code=403,
            detail="Admin API access required"
        )
    return api_client
