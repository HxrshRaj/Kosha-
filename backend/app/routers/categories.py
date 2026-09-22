from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .. import crud, schemas
from ..database import get_db

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[schemas.CategoryOut])
def list_categories(db: Session = Depends(get_db)):
    return crud.list_categories(db)


@router.post("", response_model=schemas.CategoryOut, status_code=201)
def create_category(payload: schemas.CategoryCreate, db: Session = Depends(get_db)):
    try:
        return crud.create_category(db, payload)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Category name already exists")


@router.put("/{category_id}", response_model=schemas.CategoryOut)
def update_category(
    category_id: int, payload: schemas.CategoryUpdate, db: Session = Depends(get_db)
):
    category = crud.get_category(db, category_id)
    if category is None:
        raise HTTPException(status_code=404, detail="Category not found")
    try:
        return crud.update_category(db, category, payload)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Category name already exists")


@router.delete("/{category_id}", status_code=204)
def delete_category(category_id: int, db: Session = Depends(get_db)):
    category = crud.get_category(db, category_id)
    if category is None:
        raise HTTPException(status_code=404, detail="Category not found")
    if category.transactions:
        raise HTTPException(
            status_code=409,
            detail="Category has transactions; reassign or delete them first",
        )
    crud.delete_category(db, category)
