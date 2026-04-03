#!/usr/bin/env python3
"""
Скрипт для переименования логотипов команд
"""

import os
import re

def rename_team_logos():
    """Переименовывает файлы логотипов команд"""
    logos_dir = "public/icons/team_logos"
    
    if not os.path.exists(logos_dir):
        print(f"Директория {logos_dir} не найдена")
        return
    
    for filename in os.listdir(logos_dir):
        if filename.endswith('.png'):
            # Логика переименования
            new_name = filename.lower().replace(' ', '_')
            old_path = os.path.join(logos_dir, filename)
            new_path = os.path.join(logos_dir, new_name)
            
            if old_path != new_path:
                os.rename(old_path, new_path)
                print(f"Переименован: {filename} -> {new_name}")

if __name__ == "__main__":
    rename_team_logos()
