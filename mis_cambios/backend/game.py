import os
import re
from uuid import UUID

from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from supabase import create_client

load_dotenv()

router = APIRouter(tags=["Puntajes y valoraciones"])


def cliente_supabase():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")

    if not url or not key:
        raise RuntimeError("Falta configurar Supabase en .env")

    return create_client(url, key)


def validar_minijuego(minijuego: str) -> str:
    nombre = minijuego.strip().lower()

    if nombre not in {"take", "draw", "test_your_might"}:
        raise HTTPException(
            status_code=400,
            detail="El identificador del minijuego no es válido.",
        )

    return nombre


class NuevoPuntaje(BaseModel):
    id_partida: UUID
    minijuego: str = Field(min_length=1, max_length=50)
    nombre_jugador: str = Field(min_length=1, max_length=30)
    puntaje_final: int = Field(ge=0)
    jugador_numero: int = Field(ge=1, le=2)


class NuevaValoracion(BaseModel):
    id_partida: UUID
    minijuego: str = Field(min_length=1, max_length=50)
    jugador_numero: int = Field(ge=1, le=2)
    puntuacion: int = Field(ge=1, le=5)


@router.post("/puntajes", status_code=201)
def guardar_puntaje(datos: NuevoPuntaje):
    minijuego = validar_minijuego(datos.minijuego)
    nombre = datos.nombre_jugador.strip()

    if not nombre:
        raise HTTPException(
            status_code=400,
            detail="Debes ingresar un nombre para guardar el puntaje.",
        )

    try:
        db = cliente_supabase()

        resultado = (
            db.table("partidas")
            .insert({
                "id_partida": str(datos.id_partida),
                "minijuego": minijuego,
                "nombre_jugador": nombre,
                "puntaje_final": datos.puntaje_final,
                "jugador_numero": datos.jugador_numero,
            })
            .execute()
        )

        if not resultado.data:
            raise RuntimeError("Supabase no devolvió el puntaje guardado.")

        return {
            "mensaje": "Puntaje guardado correctamente.",
            "partida": resultado.data[0],
        }

    except HTTPException:
        raise
    except Exception as error:
        print(f"Error guardando puntaje: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=503,
            detail="No se pudo guardar el puntaje.",
        )


@router.get("/ranking/{minijuego}")
def obtener_ranking(minijuego: str):
    minijuego = validar_minijuego(minijuego)

    try:
        db = cliente_supabase()

        orden_ascendente = minijuego == "draw"

        resultado = (
            db.table("partidas")
            .select(
                "id_partida,jugador_numero,nombre_jugador,"
                "puntaje_final,fecha"
            )
            .eq("minijuego", minijuego)
            .order("puntaje_final", desc=not orden_ascendente)
            .order("fecha", desc=False)
            .limit(100)
            .execute()
        )

        ranking = [
            {
                "posicion": posicion,
                "id_partida": partida["id_partida"],
                "jugador_numero": partida["jugador_numero"],
                "nombre_jugador": partida["nombre_jugador"],
                "puntaje_final": partida["puntaje_final"],
                "fecha": partida["fecha"],
            }
            for posicion, partida in enumerate(resultado.data, start=1)
        ]

        return {
            "minijuego": minijuego,
            "ranking": ranking,
        }

    except Exception as error:
        print(f"Error consultando ranking: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=503,
            detail="No se pudo consultar el ranking.",
        )


@router.post("/valoraciones", status_code=201)
def crear_valoracion(datos: NuevaValoracion):
    minijuego = validar_minijuego(datos.minijuego)

    try:
        db = cliente_supabase()

        resultado = (
            db.table("valoraciones")
            .insert({
                "id_partida": str(datos.id_partida),
                "minijuego": minijuego,
                "jugador_numero": datos.jugador_numero,
                "puntuacion": datos.puntuacion,
            })
            .execute()
        )

        if not resultado.data:
            raise RuntimeError("Supabase no devolvió la valoración guardada.")

        return {
            "mensaje": "Valoración guardada correctamente.",
            "valoracion": resultado.data[0],
        }

    except Exception as error:
        if "23505" in str(error):
            raise HTTPException(
                status_code=409,
                detail="Este jugador ya valoró esta partida.",
            )

        print(f"Error guardando valoración: {type(error).__name__}: {error}")
        raise HTTPException(
            status_code=503,
            detail="No se pudo guardar la valoración.",
        )


@router.get("/valoraciones/resumen/{minijuego}")
def resumen_valoraciones(minijuego: str):
    minijuego = validar_minijuego(minijuego)

    try:
        db = cliente_supabase()

        resultado = (
            db.table("valoraciones")
            .select("puntuacion")
            .eq("minijuego", minijuego)
            .execute()
        )

        puntuaciones = [fila["puntuacion"] for fila in resultado.data]
        cantidad = len(puntuaciones)
        promedio = (
            round(sum(puntuaciones) / cantidad, 2)
            if cantidad > 0
            else None
        )

        return {
            "minijuego": minijuego,
            "cantidad": cantidad,
            "promedio": promedio,
        }

    except Exception as error:
        print(
            f"Error consultando valoraciones: "
            f"{type(error).__name__}: {error}"
        )
        raise HTTPException(
            status_code=503,
            detail="No se pudieron consultar las valoraciones.",
        )
