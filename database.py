from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# URL de connexion à PostgreSQL (Render)
SQLALCHEMY_DATABASE_URL = (
    "postgresql+psycopg2://abmsalesdatabase:"
    "rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN"
    "@dpg-d1g0cmali9vc73a392lg-a.oregon-postgres.render.com:5432/"
    "abmsalesdatabase"
)

# Création du moteur SQLAlchemy
engine = create_engine(SQLALCHEMY_DATABASE_URL)

# Session locale pour les interactions avec la BDD
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

# Base pour les modèles ORM
Base = declarative_base()
