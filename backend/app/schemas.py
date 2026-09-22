import datetime as dt

from pydantic import BaseModel, ConfigDict, Field

from .models import TransactionType


class CategoryBase(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    type: TransactionType
    color: str = Field(default="#6C63FF", max_length=9)
    icon: str = Field(default="category", max_length=32)
    monthly_budget: float | None = None


class CategoryCreate(CategoryBase):
    pass


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=64)
    type: TransactionType | None = None
    color: str | None = None
    icon: str | None = None
    monthly_budget: float | None = None


class CategoryOut(CategoryBase):
    model_config = ConfigDict(from_attributes=True)
    id: int


class TransactionBase(BaseModel):
    amount: float = Field(gt=0)
    type: TransactionType
    category_id: int
    note: str | None = Field(default=None, max_length=256)
    date: dt.date
    client_id: str | None = None


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    amount: float | None = Field(default=None, gt=0)
    type: TransactionType | None = None
    category_id: int | None = None
    note: str | None = None
    date: dt.date | None = None


class TransactionOut(TransactionBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: dt.datetime
    updated_at: dt.datetime
    category: CategoryOut


class CategorySpend(BaseModel):
    category_id: int
    category_name: str
    color: str
    icon: str
    total: float
    budget: float | None = None


class MonthlySummary(BaseModel):
    month: str  # "YYYY-MM"
    total_income: float
    total_expense: float
    net: float
    by_category: list[CategorySpend]


class MonthPoint(BaseModel):
    month: str
    total_income: float
    total_expense: float


class YearlySummary(BaseModel):
    year: int
    months: list[MonthPoint]
