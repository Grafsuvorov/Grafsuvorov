#!/usr/bin/env python3
"""
Скрипт для запуска сервера Football ML API на порту 8001
"""

import os
import sys
import subprocess
import time

def start_server():
    """Запускает сервер на порту 8001"""
    print("🚀 Запуск Football ML API сервера...")
    
    # Проверяем, что мы в правильной директории
    if not os.path.exists("api/main.py"):
        print("❌ Ошибка: api/main.py не найден. Запустите скрипт из корневой папки проекта.")
        return
    
    # Активируем виртуальное окружение
    venv_activate = os.path.join("venv", "Scripts", "Activate.ps1")
    if os.path.exists(venv_activate):
        print("✅ Виртуальное окружение найдено")
    else:
        print("❌ Виртуальное окружение не найдено. Создайте его командой: python -m venv venv")
        return
    
    # Команда для запуска сервера - исправляем путь к модулю
    cmd = [
        "python", "-m", "uvicorn", 
        "api.main:app",  # Исправляем путь к модулю
        "--reload", 
        "--host", "0.0.0.0", 
        "--port", "8001"
    ]
    
    print(f"📡 Запуск команды: {' '.join(cmd)}")
    print("🌐 Сервер будет доступен по адресу: http://localhost:8001")
    print("📚 API документация: http://localhost:8001/docs")
    print("🔌 Для остановки нажмите Ctrl+C")
    print("-" * 50)
    
    try:
        # Запускаем сервер из корневой папки
        subprocess.run(cmd, check=True)
        
    except KeyboardInterrupt:
        print("\n🛑 Сервер остановлен пользователем")
    except subprocess.CalledProcessError as e:
        print(f"❌ Ошибка запуска сервера: {e}")
    except Exception as e:
        print(f"❌ Неожиданная ошибка: {e}")

if __name__ == "__main__":
    start_server()

