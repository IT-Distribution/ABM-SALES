from sqlalchemy.orm import Session
from sqlalchemy import func
from models import ImportFile, Client, User, Zone
from schemas import ImportFileCreate, ClientCreate, UserCreate, ZoneCreate
from passlib.context import CryptContext
from typing import List, Optional

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_user_by_email(db: Session, email: str):
    return db.query(User).filter(User.email == email).first()

def create_user(db: Session, user: UserCreate):
    hashed_password = pwd_context.hash(user.password)
    db_user = User(email=user.email, password=hashed_password, is_active=True)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def verify_password(plain_password: str, hashed_password: str):
    return pwd_context.verify(plain_password, hashed_password)

def authenticate_user(db: Session, email: str, password: str):
    print(f"Tentative d'authentification pour l'email: {email}")
    user = get_user_by_email(db, email)
    if not user:
        print(f"Utilisateur non trouvé: {email}")
        return False
    if not verify_password(password, user.password):
        print(f"Mot de passe incorrect pour l'utilisateur: {email}")
        return False
    if not user.is_active:
        print(f"Utilisateur {email} inactif.")
        return False
    print(f"Authentification réussie pour l'utilisateur: {email}")
    return user

def get_users(db: Session, skip: int = 0, limit: int = 100):
    return db.query(User).offset(skip).limit(limit).all()

def create_import_file(db: Session, filename: str):
    db_import = ImportFile(filename=filename)
    db.add(db_import)
    db.commit()
    db.refresh(db_import)
    return db_import

def create_clients(db: Session, clients: list[ClientCreate], import_file_id: int):
    db_clients = []
    for c in clients:
        client = Client(
            client_id=c.client_id,
            nom=c.nom,
            prenom=c.prenom,
            telephone=c.telephone,
            reseaux_social=c.reseaux_social,
            latitude=c.latitude,
            longitude=c.longitude,
            import_file_id=import_file_id
        )
        db.add(client)
        db_clients.append(client)
    db.commit()
    return db_clients

def get_import_files(db: Session):
    import_files = db.query(ImportFile).all()
    for import_file in import_files:
        import_file.client_count = len(import_file.clients)
    return import_files

def delete_import_file(db: Session, import_file_id: int):
    import_file = db.query(ImportFile).filter(ImportFile.id == import_file_id).first()
    if import_file:
        db.delete(import_file)
        db.commit()
        return True
    return False

def get_total_clients_for_imports(db: Session, import_ids: list[int]) -> int:
    total_clients = 0
    for import_id in import_ids:
        import_file = db.query(ImportFile).filter(ImportFile.id == import_id).first()
        if import_file:
            total_clients += len(import_file.clients)
    return total_clients

def get_clients_for_imports(db: Session, import_ids: list[int]):
    """
    Récupère tous les clients associés aux imports spécifiés
    """
    clients = []
    for import_id in import_ids:
        import_file = db.query(ImportFile).filter(ImportFile.id == import_id).first()
        if import_file and import_file.clients:
            clients.extend(import_file.clients)
    return clients

# Fonctions pour la gestion des zones
def create_zone(db: Session, zone: ZoneCreate):
    db_zone = Zone(
        name=zone.name,
        email=zone.email,
        longitude=zone.longitude,
        latitude=zone.latitude
    )
    db.add(db_zone)
    db.commit()
    db.refresh(db_zone)
    return db_zone

def get_zone(db: Session, zone_id: int):
    return db.query(Zone).filter(Zone.id == zone_id).first()

def get_zones(db: Session, skip: int = 0, limit: int = 100):
    return db.query(Zone).offset(skip).limit(limit).all()

def get_zones_by_email(db: Session, email: str):
    return db.query(Zone).filter(Zone.email == email).all()

def update_zone(db: Session, zone_id: int, zone: ZoneCreate):
    db_zone = get_zone(db, zone_id)
    if db_zone:
        for key, value in zone.dict().items():
            setattr(db_zone, key, value)
        db.commit()
        db.refresh(db_zone)
    return db_zone

def delete_zone(db: Session, zone_id: int):
    db_zone = get_zone(db, zone_id)
    if db_zone:
        db.delete(db_zone)
        db.commit()
        return True
    return False

def delete_zones_by_name_and_email(db: Session, zone_name: str, salesperson_email: str):
    db.query(Zone).filter(
        Zone.name == zone_name,
        Zone.email == salesperson_email
    ).delete(synchronize_session=False)
    db.commit()

def delete_all_zones(db: Session):
    db.query(Zone).delete()
    db.commit()
