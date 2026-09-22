from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import models
from .database import Base, SessionLocal, engine
from .routers import categories, summary, transactions

Base.metadata.create_all(bind=engine)


@asynccontextmanager
async def lifespan(app: FastAPI):
    seed_default_categories()
    yield


app = FastAPI(
    title="Kosha API",
    description="Personal finance tracker REST API — transactions, categories, and spending analytics.",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transactions.router)
app.include_router(categories.router)
app.include_router(summary.router)


DEFAULT_CATEGORIES = [
    {"name": "Food & Dining", "type": models.TransactionType.expense, "color": "#FF6B6B", "icon": "restaurant", "monthly_budget": 8000},
    {"name": "Transport", "type": models.TransactionType.expense, "color": "#4D96FF", "icon": "directions_car", "monthly_budget": 3000},
    {"name": "Shopping", "type": models.TransactionType.expense, "color": "#F7B733", "icon": "shopping_bag", "monthly_budget": 5000},
    {"name": "Bills & Utilities", "type": models.TransactionType.expense, "color": "#6C63FF", "icon": "receipt_long", "monthly_budget": 6000},
    {"name": "Entertainment", "type": models.TransactionType.expense, "color": "#00C2A8", "icon": "movie", "monthly_budget": 2000},
    {"name": "Health", "type": models.TransactionType.expense, "color": "#FF8FB1", "icon": "favorite", "monthly_budget": 2500},
    {"name": "Salary", "type": models.TransactionType.income, "color": "#2ECC71", "icon": "payments", "monthly_budget": None},
    {"name": "Freelance", "type": models.TransactionType.income, "color": "#27AE60", "icon": "work", "monthly_budget": None},
    {"name": "Other", "type": models.TransactionType.expense, "color": "#A0A0A0", "icon": "more_horiz", "monthly_budget": None},
]


def seed_default_categories() -> None:
    db = SessionLocal()
    try:
        if db.query(models.Category).count() == 0:
            for payload in DEFAULT_CATEGORIES:
                db.add(models.Category(**payload))
            db.commit()
    finally:
        db.close()


@app.get("/health", tags=["meta"])
def health():
    return {"status": "ok"}
