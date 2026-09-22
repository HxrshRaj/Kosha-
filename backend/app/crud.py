from sqlalchemy import extract, func
from sqlalchemy.orm import Session

from . import models, schemas


# ---- Categories ----

def list_categories(db: Session) -> list[models.Category]:
    return db.query(models.Category).order_by(models.Category.name).all()


def get_category(db: Session, category_id: int) -> models.Category | None:
    return db.get(models.Category, category_id)


def create_category(db: Session, payload: schemas.CategoryCreate) -> models.Category:
    category = models.Category(**payload.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


def update_category(
    db: Session, category: models.Category, payload: schemas.CategoryUpdate
) -> models.Category:
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(category, field, value)
    db.commit()
    db.refresh(category)
    return category


def delete_category(db: Session, category: models.Category) -> None:
    db.delete(category)
    db.commit()


# ---- Transactions ----

def list_transactions(
    db: Session,
    month: str | None = None,
    category_id: int | None = None,
    type_: models.TransactionType | None = None,
    limit: int = 200,
    offset: int = 0,
) -> list[models.Transaction]:
    query = db.query(models.Transaction)
    if month:
        year, mon = _parse_month(month)
        query = query.filter(
            extract("year", models.Transaction.date) == year,
            extract("month", models.Transaction.date) == mon,
        )
    if category_id is not None:
        query = query.filter(models.Transaction.category_id == category_id)
    if type_ is not None:
        query = query.filter(models.Transaction.type == type_)
    return (
        query.order_by(models.Transaction.date.desc(), models.Transaction.id.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )


def get_transaction(db: Session, transaction_id: int) -> models.Transaction | None:
    return db.get(models.Transaction, transaction_id)


def get_transaction_by_client_id(db: Session, client_id: str) -> models.Transaction | None:
    return (
        db.query(models.Transaction)
        .filter(models.Transaction.client_id == client_id)
        .first()
    )


def create_transaction(
    db: Session, payload: schemas.TransactionCreate
) -> models.Transaction:
    transaction = models.Transaction(**payload.model_dump())
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    return transaction


def update_transaction(
    db: Session, transaction: models.Transaction, payload: schemas.TransactionUpdate
) -> models.Transaction:
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(transaction, field, value)
    db.commit()
    db.refresh(transaction)
    return transaction


def delete_transaction(db: Session, transaction: models.Transaction) -> None:
    db.delete(transaction)
    db.commit()


# ---- Summary / analytics ----

def _parse_month(month: str) -> tuple[int, int]:
    year_str, mon_str = month.split("-")
    return int(year_str), int(mon_str)


def monthly_summary(db: Session, month: str) -> schemas.MonthlySummary:
    year, mon = _parse_month(month)

    totals = (
        db.query(models.Transaction.type, func.sum(models.Transaction.amount))
        .filter(
            extract("year", models.Transaction.date) == year,
            extract("month", models.Transaction.date) == mon,
        )
        .group_by(models.Transaction.type)
        .all()
    )
    total_income = next((t for ty, t in totals if ty == models.TransactionType.income), 0.0) or 0.0
    total_expense = next((t for ty, t in totals if ty == models.TransactionType.expense), 0.0) or 0.0

    by_category_rows = (
        db.query(
            models.Category.id,
            models.Category.name,
            models.Category.color,
            models.Category.icon,
            models.Category.monthly_budget,
            func.sum(models.Transaction.amount).label("total"),
        )
        .join(models.Transaction, models.Transaction.category_id == models.Category.id)
        .filter(
            extract("year", models.Transaction.date) == year,
            extract("month", models.Transaction.date) == mon,
            models.Transaction.type == models.TransactionType.expense,
        )
        .group_by(models.Category.id)
        .order_by(func.sum(models.Transaction.amount).desc())
        .all()
    )

    by_category = [
        schemas.CategorySpend(
            category_id=row.id,
            category_name=row.name,
            color=row.color,
            icon=row.icon,
            total=float(row.total),
            budget=row.monthly_budget,
        )
        for row in by_category_rows
    ]

    return schemas.MonthlySummary(
        month=month,
        total_income=float(total_income),
        total_expense=float(total_expense),
        net=float(total_income) - float(total_expense),
        by_category=by_category,
    )


def yearly_summary(db: Session, year: int) -> schemas.YearlySummary:
    rows = (
        db.query(
            extract("month", models.Transaction.date).label("mon"),
            models.Transaction.type,
            func.sum(models.Transaction.amount),
        )
        .filter(extract("year", models.Transaction.date) == year)
        .group_by("mon", models.Transaction.type)
        .all()
    )

    by_month: dict[int, dict[str, float]] = {
        m: {"income": 0.0, "expense": 0.0} for m in range(1, 13)
    }
    for mon, ty, total in rows:
        key = "income" if ty == models.TransactionType.income else "expense"
        by_month[int(mon)][key] = float(total or 0.0)

    months = [
        schemas.MonthPoint(
            month=f"{year}-{m:02d}",
            total_income=by_month[m]["income"],
            total_expense=by_month[m]["expense"],
        )
        for m in range(1, 13)
    ]
    return schemas.YearlySummary(year=year, months=months)
