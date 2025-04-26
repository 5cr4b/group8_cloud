from fastapi import FastAPI
from .api import api_router
from .db.init_db import init_db

app = FastAPI()
app.include_router(api_router)

@app.on_event("startup")
async def startup_event():
    init_db()
