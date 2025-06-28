from fastapi import FastAPI, UploadFile, File, Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials, OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import pandas as pd
from database import SessionLocal, engine, Base
import crud, models, schemas
import logging
from datetime import datetime, timedelta
from jose import JWTError, jwt
from typing import Optional, List
import requests
import json

# Configuration des logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

Base.metadata.create_all(bind=engine)

app = FastAPI()

# Ajouter le support CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permet toutes les origines
    allow_credentials=True,
    allow_methods=["*"],  # Permet toutes les méthodes
    allow_headers=["*"],  # Permet tous les headers
)

# Configuration JWT
SECRET_KEY = "ADIL & TRIBAK & IT_DATA_ANALYSIS"  # À changer en production
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# TomTom API Key (should be in a config file or environment variable in production)
TOMTOM_API_KEY = "De8uDhsXRucjZ9ERWjV7PVGf6H3cApG8"

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")
security = HTTPBasic()

# Simple admin credentials (à sécuriser plus tard)
ADMIN_EMAIL = "Abm2025@gmail.com"
ADMIN_PASSWORD = "Abm2025@2026"

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_admin(credentials: HTTPBasicCredentials = Depends(security)):
    correct_email = credentials.username == ADMIN_EMAIL
    correct_password = credentials.password == ADMIN_PASSWORD
    if not (correct_email and correct_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect email or password")
    return credentials.username

@app.post("/register", response_model=schemas.User)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    return crud.create_user(db=db, user=user)

@app.post("/login", response_model=schemas.Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    logger.info(f"Tentative de connexion pour l'utilisateur: {form_data.username}")
    user = crud.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        logger.error(f"Échec de l'authentification pour l'utilisateur: {form_data.username}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    logger.info(f"Connexion réussie pour l'utilisateur: {form_data.username}")
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/admin/users/", response_model=list[schemas.User])
def read_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), admin: str = Depends(verify_admin)):
    users = crud.get_users(db, skip=skip, limit=limit)
    return users

@app.post("/upload-csv/")
async def upload_csv(file: UploadFile = File(...), db: Session = Depends(get_db), admin: str = Depends(verify_admin)):
    logger.info(f"Début de l'import du fichier: {file.filename}")
    # lire le CSV en mémoire
    contents = await file.read()
    df = pd.read_csv(pd.io.common.BytesIO(contents))
    
    # vérifier colonnes
    expected_cols = ['id', 'nom', 'prenom', 'telephone', 'reseaux_social', 'latitude', 'longitude']
    missing_cols = [col for col in expected_cols if col not in df.columns]
    if missing_cols:
        logger.error(f"Colonnes manquantes: {missing_cols}")
        raise HTTPException(status_code=400, detail=f"Colonnes manquantes: {missing_cols}")
    
    # Sélectionner uniquement les colonnes attendues (ignorer les colonnes supplémentaires)
    df = df[expected_cols]
    
    # créer import
    import_file = crud.create_import_file(db, filename=file.filename)
    logger.info(f"Fichier importé créé avec ID: {import_file.id}")
    
    # créer clients
    clients = []
    for _, row in df.iterrows():
        try:
            clients.append(schemas.ClientCreate(
                client_id=int(row['id']),
                nom=row['nom'],
                prenom=row['prenom'],
                telephone=row['telephone'],
                reseaux_social=row['reseaux_social'],
                latitude=float(row['latitude']),
                longitude=float(row['longitude']),
            ))
        except Exception as e:
            logger.error(f"Erreur lors de la création d'un client: {e}, ligne: {row}")
            continue
    
    crud.create_clients(db, clients, import_file.id)
    logger.info(f"Nombre de clients importés: {len(clients)}")
    
    return {"message": f"Fichier {file.filename} importé avec succès.", "import_id": import_file.id}

@app.get("/imports/", response_model=list[schemas.ImportFile])
def list_imports(db: Session = Depends(get_db), admin: str = Depends(verify_admin)):
    logger.info("Récupération de la liste des imports")
    imports = crud.get_import_files(db)
    logger.info(f"Nombre d'imports récupérés: {len(imports)}")
    return imports

@app.delete("/imports/{import_id}")
def delete_import(import_id: int, db: Session = Depends(get_db), admin: str = Depends(verify_admin)):
    if crud.delete_import_file(db, import_id):
        return {"message": "Import supprimé avec succès."}
    raise HTTPException(status_code=404, detail="Import non trouvé")

@app.post("/total-clients/")
def get_total_clients(import_ids: list[int], db: Session = Depends(get_db), admin: str = Depends(verify_admin)):
    total = crud.get_total_clients_for_imports(db, import_ids)
    return {"total_clients": total}

@app.post("/clients-coordinates/")
def get_clients_coordinates(import_ids: list[int], db: Session = Depends(get_db), admin: str = Depends(verify_admin)):
    """
    Récupère les coordonnées (latitude, longitude) de tous les clients des imports sélectionnés
    """
    logger.info(f"Récupération des coordonnées des clients pour les imports: {import_ids}")
    clients = crud.get_clients_for_imports(db, import_ids)
    
    # Extraire uniquement les informations nécessaires pour la carte
    coordinates = []
    for client in clients:
        coordinates.append({
            "id": client.client_id,
            "nom": client.nom,
            "prenom": client.prenom,
            "latitude": client.latitude,
            "longitude": client.longitude
        })
    
    logger.info(f"Nombre de coordonnées de clients récupérées: {len(coordinates)}")
    return {"coordinates": coordinates}

@app.post("/zones/", response_model=list[schemas.Zone])
def create_zone_assignments(
    zones_data: list[schemas.ZoneCreate],
    db: Session = Depends(get_db),
    admin: str = Depends(verify_admin)
):
    logger.info(f"Réception de {len(zones_data)} clients pour affectation de zones.")
    
    # Supprimer les anciennes entrées pour ces zones/vendeurs spécifiques
    if zones_data:
        # Supposons que toutes les entrées dans la liste appartiennent à la même zone et au même vendeur
        # C'est une simplification basée sur le flux actuel où une seule zone est validée à la fois côté frontend.
        # Si plusieurs zones ou vendeurs différents peuvent être validés en une seule requête, cette logique doit être ajustée.
        zone_name = zones_data[0].name # ex: "Zone 1"
        assigned_user_email = zones_data[0].email
        logger.info(f"Suppression des anciennes affectations pour la zone '{zone_name}' et le vendeur '{assigned_user_email}'")
        crud.delete_zones_by_name_and_email(db, zone_name, assigned_user_email)

    created_zones = []
    for zone_data in zones_data:
        db_zone = crud.create_zone(db=db, zone=zone_data)
        created_zones.append(db_zone)
    logger.info(f"Clients de zones enregistrés avec succès.")
    return created_zones

@app.get("/zones/", response_model=list[schemas.Zone])
def read_zones(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    zones = crud.get_zones(db, skip=skip, limit=limit)
    return zones

@app.get("/zones/{zone_id}", response_model=schemas.Zone)
def read_zone(zone_id: int, db: Session = Depends(get_db)):
    db_zone = crud.get_zone(db, zone_id=zone_id)
    if db_zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")
    return db_zone

@app.get("/zones/user/{email}", response_model=list[schemas.Zone])
def read_user_zones(email: str, db: Session = Depends(get_db)):
    zones = crud.get_zones_by_email(db, email=email)
    return zones

@app.put("/zones/{zone_id}", response_model=schemas.Zone)
def update_zone(zone_id: int, zone: schemas.ZoneCreate, db: Session = Depends(get_db)):
    db_zone = crud.update_zone(db, zone_id=zone_id, zone=zone)
    if db_zone is None:
        raise HTTPException(status_code=404, detail="Zone not found")
    return db_zone

@app.delete("/zones/{zone_id}")
def delete_zone(zone_id: int, db: Session = Depends(get_db)):
    success = crud.delete_zone(db, zone_id=zone_id)
    if not success:
        raise HTTPException(status_code=404, detail="Zone not found")
    return {"message": "Zone deleted successfully"}

@app.post("/calculate-best-route/", response_model=schemas.RouteResponse)
async def calculate_best_route(
    points: List[schemas.LatLngPoint],
    db: Session = Depends(get_db),
    current_user_email: str = Depends(oauth2_scheme)
):
    logger.info(f"Calcul de la meilleure route pour l'utilisateur {current_user_email} avec {len(points)} points.")

    if len(points) < 2:
        raise HTTPException(status_code=400, detail="Au moins deux points sont nécessaires pour calculer une route.")

    try:
        # Convertir les points en format pour l'API TomTom
        points_str = ':'.join([f"{p.latitude},{p.longitude}" for p in points])

        # Construire l'URL pour l'API de routage TomTom
        tomtom_url = f"https://api.tomtom.com/routing/1/calculateRoute/{points_str}/json"
        params = {
            'key': TOMTOM_API_KEY,
            'traffic': 'true',
            'travelMode': 'car',
            'routeType': 'fastest',
            'departAt': datetime.utcnow().isoformat() + 'Z', # ISO 8601 format with Z for UTC
            'computeBestOrder': 'true', # This will reorder points for an optimized route
            'routeRepresentation': 'polyline',
            'instructionsType': 'text',
            'language': 'fr-FR',
        }

        logger.info(f"Appel TomTom URL: {tomtom_url} avec params: {params}")
        response = requests.get(tomtom_url, params=params)
        response.raise_for_status() # Lève une exception pour les codes d'état HTTP d'erreur

        data = response.json()
        logger.info(f"Réponse brute de TomTom: {json.dumps(data, indent=2)}")

        if data.get('routes') and len(data['routes']) > 0:
            route = data['routes'][0]
            polyline_points = []
            for leg in route.get('legs', []):
                for point in leg.get('points', []):
                    polyline_points.append(schemas.LatLngPoint(
                        latitude=point['latitude'],
                        longitude=point['longitude']
                    ))
            logger.info(f"Route calculée avec {len(polyline_points)} points.")
            
            # Extraire la distance et la durée
            distance_meters = route['summary']['lengthInMeters']
            travel_time_seconds = route['summary']['travelTimeInSeconds']

            # Formater la durée en heures et minutes
            hours = travel_time_seconds // 3600
            minutes = (travel_time_seconds % 3600) // 60
            duration_str = f"{hours}h {minutes}min" if hours > 0 else f"{minutes}min"

            return schemas.RouteResponse(
                route_points=polyline_points,
                distance_km=round(distance_meters / 1000, 1),
                duration_str=duration_str
            )
        else:
            logger.warning("Aucune route trouvée dans la réponse de TomTom.")
            raise HTTPException(status_code=404, detail="Aucune route trouvée pour les points donnés.")

    except requests.exceptions.RequestException as e:
        logger.error(f"Erreur lors de l'appel à l'API TomTom: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur de service de routage: {e}")
    except Exception as e:
        logger.error(f"Erreur inattendue lors du calcul de la route: {e}")
        raise HTTPException(status_code=500, detail=f"Erreur interne du serveur: {e}")

@app.delete("/zones/")
def delete_all_zones_endpoint(db: Session = Depends(get_db)):
    crud.delete_all_zones(db)
    return {"message": "All zones deleted successfully"}
