import psycopg2
from psycopg2 import sql, OperationalError

def create_database():
    try:
        # Connexion à PostgreSQL (sans spécifier de base de données)
        connection = psycopg2.connect(
            dbname='abmsalesdatabase',
            user='abmsalesdatabase',
            password='rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN',
            host='dpg-d1g0cmali9vc73a392lg-a'
        )
        connection.autocommit = True
        cursor = connection.cursor()
        # Créer la base de données si elle n'existe pas
        cursor.execute("SELECT 1 FROM pg_catalog.pg_database WHERE datname = 'amc'")
        exists = cursor.fetchone()
        if not exists:
            cursor.execute('CREATE DATABASE amc')
            print("Base de données 'amc' créée")
        else:
            print("Base de données 'amc' déjà existante")
        connection.close()
        print("Connexion PostgreSQL fermée")
    except OperationalError as e:
        print(f"Erreur lors de la connexion à PostgreSQL: {e}")

if __name__ == "__main__":
    create_database()
