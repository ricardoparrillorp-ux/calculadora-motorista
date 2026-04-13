@echo off
cd /d "%~dp0"
echo Instalando dependencias...
pip install -r requirements.txt
echo.
echo Iniciando servidor na porta 8000...
echo Acesse: http://localhost:8000
echo.
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
