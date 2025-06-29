import psycopg2
from psycopg2 import sql, OperationalError

def create_database():
    try:
        # Connexion à PostgreSQL (à la base 'postgres' pour gérer les autres BDD)
        connection = psycopg2.connect(
            dbname='abmsalesdatabase',
            user='abmsalesdatabase',
            password='rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN',
            host='dpg-d1g0cmali9vc73a392lg-a.oregon-postgres.render.com',
            port='5432'
        )
        connection.autocommit = True
        cursor = connection.cursor()

        # Vérifie si la base 'abmsalesdatabase' existe
        cursor.execute("SELECT 1 FROM pg_catalog.pg_database WHERE datname = 'abmsalesdatabase'")
        exists = cursor.fetchone()

        if not exists:
            cursor.execute('CREATE DATABASE abmsalesdatabase')
            print("Base de données 'abmsalesdatabase' créée")
        else:
            print("Base de données 'abmsalesdatabase' déjà existante")

        connection.close()
        print("Connexion PostgreSQL fermée")

    except OperationalError as e:
        print(f"Erreur lors de la connexion à PostgreSQL: {e}")

if __name__ == "__main__":
    create_database()
