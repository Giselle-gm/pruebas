
import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from supabase import create_client, Client

from game import router as game_router

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

app = FastAPI(
    title="Backend del videojuego",
    description="Servidor de puntajes y valoraciones por minijuego",
    version="2.0.0",
)

app.include_router(game_router)


def obtener_cliente_supabase() -> Client:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise RuntimeError(
            "Falta configurar SUPABASE_URL o SUPABASE_KEY en .env"
        )

    return create_client(SUPABASE_URL, SUPABASE_KEY)


@app.get("/")
def inicio():
    return {"mensaje": "Backend del videojuego funcionando"}


@app.get("/health-db")
def comprobar_base_datos():
    try:
        cliente = obtener_cliente_supabase()

        # Comprueba las tablas del sistema nuevo.
        cliente.table("partidas").select("id").limit(1).execute()
        cliente.table("valoraciones").select("id").limit(1).execute()

        return {
            "estado": "conectado",
            "base_datos": "disponible",
            "tablas": ["partidas", "valoraciones"],
            "metodo": "HTTPS",
        }

    except Exception as error:
        print(f"Error de Supabase: {type(error).__name__}: {error}")

        raise HTTPException(
            status_code=503,
            detail="No se pudo consultar la base de datos",
        )
