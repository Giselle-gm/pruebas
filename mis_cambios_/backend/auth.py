
import os
import re
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError, VerificationError
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from supabase import create_client

load_dotenv()

router = APIRouter(prefix="/auth", tags=["Autenticación"])
password_hasher = PasswordHasher()

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_ALGORITHM = "HS256"
TOKEN_MINUTES = 60


class Credenciales(BaseModel):
    nombre_usuario: str = Field(min_length=3, max_length=24)
    password: str = Field(min_length=8, max_length=128)


def cliente_supabase():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")

    if not url or not key:
        raise RuntimeError("Falta configurar Supabase en .env")

    return create_client(url, key)


def validar_nombre(nombre: str) -> str:
    nombre = nombre.strip()

    if not re.fullmatch(r"[A-Za-z0-9_]{3,24}", nombre):
        raise HTTPException(
            status_code=400,
            detail=(
                "El nombre debe tener entre 3 y 24 caracteres "
                "y usar solo letras sin tilde, números o guion bajo."
            ),
        )

    return nombre


def crear_token(usuario_id: str) -> str:
    if not JWT_SECRET:
        raise RuntimeError("Falta configurar JWT_SECRET en .env")

    ahora = datetime.now(timezone.utc)

    payload = {
        "sub": usuario_id,
        "iat": ahora,
        "exp": ahora + timedelta(minutes=TOKEN_MINUTES),
    }

    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


@router.post("/registro", status_code=201)
def registrar(datos: Credenciales):
    nombre = validar_nombre(datos.nombre_usuario)
    db = cliente_supabase()

    try:
        # Comprobación amigable; el índice único en PostgreSQL
        # sigue siendo la protección definitiva ante duplicados.
        existente = (
            db.table("usuarios")
            .select("id")
            .ilike("nombre_usuario", nombre)
            .limit(1)
            .execute()
        )

        if existente.data:
            raise HTTPException(
                status_code=409,
                detail="Ese nombre de usuario ya está registrado.",
            )

        password_hash = password_hasher.hash(datos.password)

        resultado = (
            db.table("usuarios")
            .insert({
                "nombre_usuario": nombre,
                "password_hash": password_hash,
            })
            .execute()
        )

        if not resultado.data:
            raise RuntimeError("No se pudo crear el usuario")

        usuario = resultado.data[0]

        return {
            "mensaje": "Cuenta creada correctamente",
            "usuario": {
                "id": usuario["id"],
                "nombre_usuario": usuario["nombre_usuario"],
            },
            "token": crear_token(usuario["id"]),
            "tipo_token": "bearer",
            "expira_en_segundos": TOKEN_MINUTES * 60,
        }

    except HTTPException:
        raise
    except Exception as error:
        print(f"Error de registro: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=503,
            detail="No se pudo completar el registro.",
        )


@router.post("/login")
def iniciar_sesion(datos: Credenciales):
    nombre = validar_nombre(datos.nombre_usuario)
    db = cliente_supabase()

    try:
        resultado = (
            db.table("usuarios")
            .select("id,nombre_usuario,password_hash")
            .ilike("nombre_usuario", nombre)
            .limit(1)
            .execute()
        )

        if not resultado.data:
            raise HTTPException(
                status_code=401,
                detail="Nombre de usuario o contraseña incorrectos.",
            )

        usuario = resultado.data[0]

        try:
            password_hasher.verify(
                usuario["password_hash"],
                datos.password,
            )
        except (VerifyMismatchError, VerificationError):
            raise HTTPException(
                status_code=401,
                detail="Nombre de usuario o contraseña incorrectos.",
            )

        return {
            "mensaje": "Sesión iniciada correctamente",
            "usuario": {
                "id": usuario["id"],
                "nombre_usuario": usuario["nombre_usuario"],
            },
            "token": crear_token(usuario["id"]),
            "tipo_token": "bearer",
            "expira_en_segundos": TOKEN_MINUTES * 60,
        }

    except HTTPException:
        raise
    except Exception as error:
        print(f"Error de inicio de sesión: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=503,
            detail="No se pudo iniciar sesión.",
        )
