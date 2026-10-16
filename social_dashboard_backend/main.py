from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import httpx
import os
import asyncio

app = FastAPI(title="Social Dashboard API", version="1.0")

# Modèle de données pour structurer la réponse JSON
class SocialStats(BaseModel):
    facebook: str
    youtube: str
    tiktok: str
    instagram: str

# Fonctions simulées pour les appels API (à remplacer par tes vraies requêtes)
async def fetch_youtube_stats():
    # Exemple de vraie logique :
    # api_key = os.getenv("YOUTUBE_API_KEY")
    # async with httpx.AsyncClient() as client:
    #     response = await client.get(f"https://www.googleapis.com/youtube/v3/channels?part=statistics&id=TON_ID&key={api_key}")
    #     return response.json()['items'][0]['statistics']['subscriberCount']
    
    await asyncio.sleep(0.5) # Simule le temps d'attente du réseau
    return "5.4K"

async def fetch_meta_stats():
    # Meta Graph API gère souvent Facebook et Instagram avec le même token
    await asyncio.sleep(0.5)
    return {"facebook": "12K", "instagram": "8.5K"}

async def fetch_tiktok_stats():
    await asyncio.sleep(0.5)
    return "10K"

@app.get("/api/social-stats", response_model=SocialStats)
async def get_social_stats():
    """
    Récupère de manière asynchrone les statistiques de tous les réseaux.
    """
    try:
        # asyncio.gather permet de lancer toutes les requêtes API en même temps 
        # plutôt que les unes après les autres, ce qui rend ton endpoint super rapide !
        yt_task = fetch_youtube_stats()
        meta_task = fetch_meta_stats()
        tk_task = fetch_tiktok_stats()

        # On attend que toutes les API répondent
        yt_res, meta_res, tk_res = await asyncio.gather(yt_task, meta_task, tk_task)

        # TO-DO : C'est ici que tu pourras insérer ces résultats dans une table 
        # Supabase (ex: 'followers_history') pour garder une trace journalière.

        return SocialStats(
            facebook=meta_res["facebook"],
            youtube=yt_res,
            tiktok=tk_res,
            instagram=meta_res["instagram"]
        )

    except Exception as e:
        # Renvoie une erreur propre si l'une des API échoue
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des données : {str(e)}")

# Point de vérification simple
@app.get("/")
def read_root():
    return {"message": "Social Dashboard API est en ligne"}