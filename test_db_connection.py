import psycopg2
from psycopg2 import OperationalError
import sys

def test_postgres_connection():
    try:
        # Connexion à PostgreSQL Render
        connection = psycopg2.connect(
            dbname='abmsalesdatabase',
            user='abmsalesdatabase',
            password='rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN',
            host='dpg-d1g0cmali9vc7a392lg-a',
            port=5432
        )
        connection.autocommit = True
        print("✅ Connexion à PostgreSQL réussie!")
        cursor = connection.cursor()
        # Vérifier si la base de données existe (inutile ici car Render gère déjà la base)
        cursor.execute("SELECT datname FROM pg_database")
        databases = cursor.fetchall()
        db_exists = False
        print("\nBases de données disponibles:")
        for db in databases:
            print(f"- {db[0]}")
            if db[0] == 'abmsalesdatabase':
                db_exists = True
        if db_exists:
            print("\n✅ La base de données 'abmsalesdatabase' existe!")
            # Se connecter à la base de données (déjà fait)
            # Vérifier les tables
            cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
            tables = cursor.fetchall()
            if not tables:
                print("❌ Aucune table n'existe dans la base de données 'abmsalesdatabase'!")
            else:
                print("\nTables dans la base de données 'abmsalesdatabase':")
                for table in tables:
                    print(f"- {table[0]}")
        else:
            print("❌ La base de données 'abmsalesdatabase' n'existe pas!")
        connection.close()
    except OperationalError as e:
        print(f"❌ Erreur lors de la connexion à PostgreSQL: {e}")
        sys.exit(1)

if __name__ == "__main__":
    test_postgres_connection()
