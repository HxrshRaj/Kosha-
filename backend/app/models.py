import datetime as dt
import enum

from sqlalchemy import Date, DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


class TransactionType(str, enum.Enum):
    income = "income"
    expense = "expense"


class Category(Base):
    __tablename__ = "categories"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    type: Mapped[TransactionType] = mapped_column(Enum(TransactionType), nullable=False)
    color: Mapped[str] = mapped_column(String(9), default="#6C63FF")
    icon: Mapped[str] = mapped_column(String(32), default="category")
    monthly_budget: Mapped[float | None] = mapped_column(Float, nullable=True)

    transactions: Mapped[list["Transaction"]] = relationship(
        back_populates="category", cascade="all, delete-orphan"
    )


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    type: Mapped[TransactionType] = mapped_column(Enum(TransactionType), nullable=False)
    note: Mapped[str | None] = mapped_column(String(256), nullable=True)
    date: Mapped[dt.date] = mapped_column(Date, nullable=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime, default=dt.datetime.utcnow)
    updated_at: Mapped[dt.datetime] = mapped_column(
        DateTime, default=dt.datetime.utcnow, onupdate=dt.datetime.utcnow
    )

    category_id: Mapped[int] = mapped_column(ForeignKey("categories.id"), nullable=False)
    category: Mapped["Category"] = relationship(back_populates="transactions")

    # Client-generated id lets an offline-created transaction keep a stable
    # identity across the sync round trip (see docs on the Flutter sync layer).
    client_id: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True, index=True)
