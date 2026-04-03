# api/api_management.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
import secrets
import string

from api.database import get_db
from api.core.api_auth import require_admin_api
from api.models import APIClient, APIRole, APIUsage

router = APIRouter(
    prefix="/admin/api",
    tags=["Управление API"],
    responses={404: {"description": "Not found"}}
)

def generate_api_key() -> str:
    """Генерирует случайный API ключ"""
    return ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))

@router.post("/clients", 
    summary="Создать API клиента",
    description="Создать нового API клиента (только для админов)"
)
def create_api_client(
    name: str = Query(..., description="Название клиента"),
    email: str = Query(..., description="Email клиента"),
    role: APIRole = Query(APIRole.USER, description="Роль клиента"),
    quota_monthly: int = Query(1000, description="Месячная квота"),
    db: Session = Depends(get_db),
    admin: APIClient = Depends(require_admin_api)
):
    """Создать нового API клиента"""
    try:
        api_key = generate_api_key()
        
        # Проверяем, что ключ уникален
        while db.query(APIClient).filter(APIClient.api_key == api_key).first():
            api_key = generate_api_key()
        
        client = APIClient(
            name=name,
            email=email,
            api_key=api_key,
            role=role,
            quota_monthly=quota_monthly
        )
        
        db.add(client)
        db.commit()
        db.refresh(client)
        
        return {
            "client_id": client.id,
            "name": client.name,
            "email": client.email,
            "api_key": client.api_key,
            "role": client.role,
            "quota_monthly": client.quota_monthly,
            "message": "API client created successfully"
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/clients",
    summary="Список API клиентов",
    description="Получить список всех API клиентов (только для админов)"
)
def list_api_clients(
    skip: int = Query(0, description="Пропустить записей"),
    limit: int = Query(100, description="Лимит записей"),
    db: Session = Depends(get_db),
    admin: APIClient = Depends(require_admin_api)
):
    """Получить список API клиентов"""
    clients = db.query(APIClient).offset(skip).limit(limit).all()
    
    return {
        "clients": [
            {
                "id": client.id,
                "name": client.name,
                "email": client.email,
                "role": client.role,
                "quota_monthly": client.quota_monthly,
                "used_current_month": client.used_current_month,
                "is_active": client.is_active,
                "last_used": client.last_used,
                "created_at": client.created_at
            }
            for client in clients
        ],
        "total": len(clients)
    }

@router.get("/usage",
    summary="Статистика использования API",
    description="Получить статистику использования API (только для админов)"
)
def get_api_usage_stats(
    days: int = Query(7, description="Количество дней для статистики"),
    db: Session = Depends(get_db),
    admin: APIClient = Depends(require_admin_api)
):
    """Получить статистику использования API"""
    from datetime import datetime, timedelta
    
    start_date = datetime.utcnow() - timedelta(days=days)
    
    # Общая статистика
    total_requests = db.query(APIUsage).filter(
        APIUsage.created_at >= start_date
    ).count()
    
    # Статистика по клиентам
    client_stats = db.query(
        APIUsage.api_client_id,
        APIClient.name,
        APIClient.role
    ).join(
        APIClient, APIUsage.api_client_id == APIClient.id
    ).filter(
        APIUsage.created_at >= start_date
    ).group_by(
        APIUsage.api_client_id, APIClient.name, APIClient.role
    ).all()
    
    # Статистика по эндпоинтам
    endpoint_stats = db.query(
        APIUsage.endpoint,
        APIUsage.method
    ).filter(
        APIUsage.created_at >= start_date
    ).group_by(
        APIUsage.endpoint, APIUsage.method
    ).all()
    
    return {
        "period_days": days,
        "total_requests": total_requests,
        "client_stats": [
            {
                "client_id": stat.api_client_id,
                "name": stat.name,
                "role": stat.role,
                "requests": db.query(APIUsage).filter(
                    APIUsage.api_client_id == stat.api_client_id,
                    APIUsage.created_at >= start_date
                ).count()
            }
            for stat in client_stats
        ],
        "endpoint_stats": [
            {
                "endpoint": stat.endpoint,
                "method": stat.method,
                "requests": db.query(APIUsage).filter(
                    APIUsage.endpoint == stat.endpoint,
                    APIUsage.method == stat.method,
                    APIUsage.created_at >= start_date
                ).count()
            }
            for stat in endpoint_stats
        ]
    }

@router.put("/clients/{client_id}/quota",
    summary="Изменить квоту клиента",
    description="Изменить месячную квоту API клиента (только для админов)"
)
def update_client_quota(
    client_id: int,
    new_quota: int = Query(..., description="Новая месячная квота"),
    db: Session = Depends(get_db),
    admin: APIClient = Depends(require_admin_api)
):
    """Изменить квоту API клиента"""
    client = db.query(APIClient).filter(APIClient.id == client_id).first()
    
    if not client:
        raise HTTPException(status_code=404, detail="API client not found")
    
    client.quota_monthly = new_quota
    db.commit()
    
    return {
        "client_id": client.id,
        "name": client.name,
        "new_quota": client.quota_monthly,
        "message": "Quota updated successfully"
    }

@router.put("/clients/{client_id}/status",
    summary="Изменить статус клиента",
    description="Активировать/деактивировать API клиента (только для админов)"
)
def update_client_status(
    client_id: int,
    is_active: bool = Query(..., description="Активен ли клиент"),
    db: Session = Depends(get_db),
    admin: APIClient = Depends(require_admin_api)
):
    """Изменить статус API клиента"""
    client = db.query(APIClient).filter(APIClient.id == client_id).first()
    
    if not client:
        raise HTTPException(status_code=404, detail="API client not found")
    
    client.is_active = is_active
    db.commit()
    
    return {
        "client_id": client.id,
        "name": client.name,
        "is_active": client.is_active,
        "message": f"Client {'activated' if is_active else 'deactivated'} successfully"
    }
