from database import Base, engine
import models
import psycopg2
from psycopg2 import sql, OperationalError
import requests
import json

def init_database():
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

def register_user(email, password):
    url = "http://localhost:8000/register"
    headers = {"Content-Type": "application/json"}
    payload = {
        "email": email,
        "password": password
    }
    try:
        response = requests.post(url, headers=headers, data=json.dumps(payload))
        response.raise_for_status() # Lève une exception pour les codes d'erreur HTTP (4xx ou 5xx)
        print(f"Utilisateur {email} enregistré avec succès.")
        return response.json()
    except requests.exceptions.HTTPError as e:
        print(f"Erreur HTTP lors de l'enregistrement de {email}: {e}")
        print(f"Réponse du serveur: {e.response.text}")
    except requests.exceptions.ConnectionError as e:
        print(f"Erreur de connexion lors de l'enregistrement de {email}: {e}")
        print("Assurez-vous que le backend FastAPI est en cours d'exécution à l'adresse spécifiée.")
    except Exception as e:
        print(f"Une erreur inattendue est survenue lors de l'enregistrement de {email}: {e}")

if __name__ == "__main__":
    init_database()
    print("Début de l'importation des utilisateurs...")
    # Liste de vos utilisateurs existants (email et mot de passe en texte clair)
    # REMPLACEZ CES EXEMPLES PAR VOS VRAIS UTILISATEURS
    EXISTING_USERS = [
        {"email": "mohamed@gmail.com", "password": "Tribak@2025"},
        {"email": "Adil@gmail.com", "password": "Ghafir@2025"},
        {"email": "Chaimae@gmail.com", "password": "Chaimae@2025"}, # Ajoutez votre utilisateur existant ici
    ]
    for user_data in EXISTING_USERS:
        register_user(user_data["email"], user_data["password"])
    print("Importation des utilisateurs terminée.")
