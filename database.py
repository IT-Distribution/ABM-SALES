from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

SQLALCHEMY_DATABASE_URL = "postgresql+psycopg2://abmsalesdatabase:rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN@dpg-d1g0cmali9vc73a392lg-a/abmsalesdatabase"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()
