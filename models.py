from sqlalchemy import Column, Integer, String, DateTime, Float, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from database_local import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True)
    password = Column(String(255))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    zones = relationship("Zone", back_populates="user")

class Zone(Base):
    __tablename__ = "zones"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), index=True)
    email = Column(String(255), ForeignKey("users.email"))
    longitude = Column(Float)
    latitude = Column(Float)
    user = relationship("User", back_populates="zones")

class ImportFile(Base):
    __tablename__ = "import_files"
    id = Column(Integer, primary_key=True, index=True)
    filename = Column(String(255), unique=True, index=True)  # Ajout de (255)
    import_date = Column(DateTime, default=datetime.utcnow)
    clients = relationship("Client", back_populates="import_file", cascade="all, delete-orphan")

class Client(Base):
    __tablename__ = "clients"
    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(Integer, index=True)  # id dans CSV
    nom = Column(String(100))  # Ajout de (100) — tu peux ajuster
    prenom = Column(String(100))
    telephone = Column(String(20))
    reseaux_social = Column(String(100))
    latitude = Column(Float)
    longitude = Column(Float)
    import_file_id = Column(Integer, ForeignKey("import_files.id"))
    import_file = relationship("ImportFile", back_populates="clients")
