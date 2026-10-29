import datetime as dt
import re

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from .. import crud, observability, schemas
from ..database import get_db

router = APIRouter(prefix="/summary", tags=["summary"])

MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


@router.get("", response_model=schemas.MonthlySummary)
def monthly_summary(
    month: str = Query(default_factory=lambda: dt.date.today().strftime("%Y-%m")),
    db: Session = Depends(get_db),
):
    if not MONTH_RE.match(month):
        raise HTTPException(status_code=422, detail="month must be formatted YYYY-MM")
    key = ("month", month)
    cached = observability.cache.get(key)
    if cached is not None:
        return cached
    result = crud.monthly_summary(db, month)
    observability.cache.set(key, result)
    return result


@router.get("/yearly", response_model=schemas.YearlySummary)
def yearly_summary(
    year: int = Query(default_factory=lambda: dt.date.today().year),
    db: Session = Depends(get_db),
):
    key = ("year", year)
    cached = observability.cache.get(key)
    if cached is not None:
        return cached
    result = crud.yearly_summary(db, year)
    observability.cache.set(key, result)
    return result
