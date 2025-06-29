@echo off
echo Installation des dépendances pour le backend...
pip install fastapi uvicorn sqlalchemy psycopg2-binary pandas
echo Installation terminée.
pause
