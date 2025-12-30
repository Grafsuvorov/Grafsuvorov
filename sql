@app.get("/__debug")
def debug():
    return {"file": __file__}

http://localhost:8000/__debug

taskkill /IM uvicorn.exe /F
taskkill /IM python.exe /F
2️⃣ Очисти кеши
bat
Копировать код
rmdir /s /q __pycache__
rmdir /s /q api\__pycache__
3️⃣ Запусти БЕЗ reload
bat
Копировать код
cd C:\Users\SuvorovND\GIT\table-dependency-viewer\api
python -m uvicorn main:app
4️⃣ Открой
bash
Копировать код
http://localhost:8000/api/orderbreaches
