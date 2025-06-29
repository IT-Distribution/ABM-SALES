from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr

class UserCreate(UserBase):
    password: str

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None

class LatLngPoint(BaseModel):
    latitude: float
    longitude: float

class ClientBase(BaseModel):
    client_id: int
    nom: str
    prenom: str
    telephone: str
    reseaux_social: str
    latitude: float
    longitude: float

class ClientCreate(ClientBase):
    pass

class Client(ClientBase):
    id: int
    class Config:
        from_attributes = True

class ImportFileBase(BaseModel):
    filename: str

class ImportFileCreate(ImportFileBase):
    pass

class ImportFile(ImportFileBase):
    id: int
    import_date: datetime
    clients: List[Client] = []
    client_count: int = 0
    class Config:
        from_attributes = True

class ZoneBase(BaseModel):
    name: str
    email: str
    longitude: float
    latitude: float

class ZoneCreate(ZoneBase):
    pass

class Zone(ZoneBase):
    id: int

    class Config:
        from_attributes = True

class UserWithZones(User):
    zones: List[Zone] = []

    class Config:
        from_attributes = True

class RouteResponse(BaseModel):
    route_points: List[LatLngPoint]
    distance_km: float
    duration_str: str
