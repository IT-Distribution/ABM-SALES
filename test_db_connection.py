import mysql.connector
from mysql.connector import Error
import sys
import psycopg2
from psycopg2 import OperationalError

def test_mysql_connection():
    try:
        # Tenter une connexion à MySQL sans spécifier de base de données
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password=""  # Laissez vide si aucun mot de passe
        )
        
        if connection.is_connected():
            print("✅ Connexion à MySQL réussie!")
            
            # Vérifier si la base de données 'amc' existe
            cursor = connection.cursor()
            cursor.execute("SHOW DATABASES")
            databases = cursor.fetchall()
            
            db_exists = False
            print("\nBases de données disponibles:")
            for db in databases:
                print(f"- {db[0]}")
                if db[0] == 'amc':
                    db_exists = True
            
            if db_exists:
                print("\n✅ La base de données 'amc' existe!")
                
                # Se connecter à la base de données 'amc'
                connection.close()
                connection = mysql.connector.connect(
                    host="localhost",
                    user="root",
                    password="",
                    database="amc"
                )
                
                if connection.is_connected():
                    cursor = connection.cursor()
                    
                    # Vérifier les tables
                    cursor.execute("SHOW TABLES")
                    tables = cursor.fetchall()
                    
                    if not tables:
                        print("❌ Aucune table n'existe dans la base de données 'amc'!")
                        print("➡️ Exécutez 'python init_db.py' pour créer les tables.")
                    else:
                        print("\nTables dans la base de données 'amc':")
                        for table in tables:
                            print(f"- {table[0]}")
                        
                        # Vérifier le contenu des tables
                        for table_name in ['import_files', 'clients']:
                            cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
                            count = cursor.fetchone()[0]
                            print(f"\nNombre d'enregistrements dans {table_name}: {count}")
            else:
                print("❌ La base de données 'amc' n'existe pas!")
                print("➡️ Exécutez 'python init_db.py' pour créer la base de données et les tables.")
            
            connection.close()
            
    except Error as e:
        print(f"❌ Erreur lors de la connexion à MySQL: {e}")
        if "Can't connect to MySQL server" in str(e):
            print("\n➡️ Assurez-vous que le serveur MySQL est installé et en cours d'exécution.")
            print("   - Sur Windows, vérifiez que le service MySQL est démarré dans les services Windows.")
            print("   - Vous pouvez installer MySQL depuis: https://dev.mysql.com/downloads/installer/")
        elif "Access denied" in str(e):
            print("\n➡️ Problème d'authentification MySQL. Vérifiez votre nom d'utilisateur et mot de passe.")
            print("   - Le script essaie de se connecter avec l'utilisateur 'root' sans mot de passe.")
            print("   - Si vous avez défini un mot de passe pour 'root', modifiez le script.")
        
        sys.exit(1)

def test_postgres_connection():
    try:
        # Tenter une connexion à PostgreSQL sans spécifier de base de données
        connection = psycopg2.connect(
            dbname='postgres',
            user='postgres',
            password='password',
            host='localhost'
        )
        connection.autocommit = True
        print("✅ Connexion à PostgreSQL réussie!")
        cursor = connection.cursor()
        # Vérifier si la base de données 'amc' existe
        cursor.execute("SELECT datname FROM pg_database")
        databases = cursor.fetchall()
        db_exists = False
        print("\nBases de données disponibles:")
        for db in databases:
            print(f"- {db[0]}")
            if db[0] == 'amc':
                db_exists = True
        if db_exists:
            print("\n✅ La base de données 'amc' existe!")
            # Se connecter à la base de données 'amc'
            connection.close()
            connection = psycopg2.connect(
                dbname='amc',
                user='postgres',
                password='password',
                host='localhost'
            )
            cursor = connection.cursor()
            # Vérifier les tables
            cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
            tables = cursor.fetchall()
            if not tables:
                print("❌ Aucune table n'existe dans la base de données 'amc'!")
                print("➡️ Exécutez 'python init_db.py' pour créer les tables.")
            else:
                print("\nTables dans la base de données 'amc':")
                for table in tables:
                    print(f"- {table[0]}")
                # Vérifier le contenu des tables
                for table_name in ['import_files', 'clients']:
                    try:
                        cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
                        count = cursor.fetchone()[0]
                        print(f"\nNombre d'enregistrements dans {table_name}: {count}")
                    except Exception as e:
                        print(f"Erreur lors de la lecture de la table {table_name}: {e}")
        else:
            print("❌ La base de données 'amc' n'existe pas!")
            print("➡️ Exécutez 'python init_db.py' pour créer la base de données et les tables.")
        connection.close()
    except OperationalError as e:
        print(f"❌ Erreur lors de la connexion à PostgreSQL: {e}")
        sys.exit(1)

if __name__ == "__main__":
    test_postgres_connection()
