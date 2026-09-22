from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import crud, models, schemas
from ..database import get_db

router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("", response_model=list[schemas.TransactionOut])
def list_transactions(
    month: str | None = Query(default=None, description="YYYY-MM"),
    category_id: int | None = None,
    type: models.TransactionType | None = None,
    limit: int = Query(default=200, le=1000),
    offset: int = 0,
    db: Session = Depends(get_db),
):
    return crud.list_transactions(db, month, category_id, type, limit, offset)


@router.post("", response_model=schemas.TransactionOut, status_code=201)
def create_transaction(payload: schemas.TransactionCreate, db: Session = Depends(get_db)):
    if crud.get_category(db, payload.category_id) is None:
        raise HTTPException(status_code=422, detail="category_id does not exist")
    if payload.client_id:
        existing = crud.get_transaction_by_client_id(db, payload.client_id)
        if existing is not None:
            return existing
    try:
        return crud.create_transaction(db, payload)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Duplicate client_id")


@router.post("/bulk", response_model=list[schemas.TransactionOut], status_code=201)
def bulk_create_transactions(
    payloads: list[schemas.TransactionCreate], db: Session = Depends(get_db)
):
    """Insert many transactions in one round trip.

    Used by the Flutter app's offline sync (queued while offline) and CSV
    import (parsed on a background isolate) so hundreds of rows don't mean
    hundreds of HTTP requests. Idempotent per client_id: a row whose
    client_id already exists is returned as-is instead of duplicated.
    """
    results: list[models.Transaction] = []
    for payload in payloads:
        if crud.get_category(db, payload.category_id) is None:
            raise HTTPException(
                status_code=422, detail=f"category_id {payload.category_id} does not exist"
            )
        existing = (
            crud.get_transaction_by_client_id(db, payload.client_id)
            if payload.client_id
            else None
        )
        results.append(existing if existing is not None else crud.create_transaction(db, payload))
    return results


@router.get("/{transaction_id}", response_model=schemas.TransactionOut)
def get_transaction(transaction_id: int, db: Session = Depends(get_db)):
    transaction = crud.get_transaction(db, transaction_id)
    if transaction is None:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@router.put("/{transaction_id}", response_model=schemas.TransactionOut)
def update_transaction(
    transaction_id: int, payload: schemas.TransactionUpdate, db: Session = Depends(get_db)
):
    transaction = crud.get_transaction(db, transaction_id)
    if transaction is None:
        raise HTTPException(status_code=404, detail="Transaction not found")
    if payload.category_id is not None and crud.get_category(db, payload.category_id) is None:
        raise HTTPException(status_code=422, detail="category_id does not exist")
    return crud.update_transaction(db, transaction, payload)


@router.delete("/{transaction_id}", status_code=204)
def delete_transaction(transaction_id: int, db: Session = Depends(get_db)):
    transaction = crud.get_transaction(db, transaction_id)
    if transaction is None:
        raise HTTPException(status_code=404, detail="Transaction not found")
    crud.delete_transaction(db, transaction)
