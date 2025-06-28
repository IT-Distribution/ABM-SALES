@echo off
echo Installation des dépendances pour le backend...
pip install fastapi uvicorn sqlalchemy pymysql mysql-connector-python pandas
echo Installation terminée.
pause
