"""Generate a large synthetic transaction CSV for the Flutter app's
CSV-import feature (see docs/threading.md). Not used by the backend itself.

Usage: python generate_sample_csv.py [row_count] [output_path]
"""
import csv
import random
import sys
from datetime import date, timedelta

MERCHANTS = [
    ("Zomato order", "Food & Dining"),
    ("Swiggy order", "Food & Dining"),
    ("Local cafe", "Food & Dining"),
    ("Uber ride", "Transport"),
    ("Ola cab", "Transport"),
    ("Petrol pump", "Transport"),
    ("Metro card recharge", "Transport"),
    ("Amazon purchase", "Shopping"),
    ("Flipkart order", "Shopping"),
    ("Myntra order", "Shopping"),
    ("Electricity bill", "Bills & Utilities"),
    ("Mobile recharge", "Bills & Utilities"),
    ("Broadband bill", "Bills & Utilities"),
    ("Netflix subscription", "Entertainment"),
    ("Movie tickets", "Entertainment"),
    ("Spotify subscription", "Entertainment"),
    ("Pharmacy purchase", "Health"),
    ("Doctor consultation", "Health"),
    ("Gym membership", "Health"),
    ("Monthly salary", "Salary"),
    ("Freelance payment", "Freelance"),
    ("Misc expense", "Other"),
]

INCOME_LABELS = {"Salary", "Freelance"}


def main() -> None:
    row_count = int(sys.argv[1]) if len(sys.argv) > 1 else 50000
    out_path = sys.argv[2] if len(sys.argv) > 2 else "sample_transactions.csv"

    start = date(2023, 1, 1)
    span_days = (date(2026, 9, 22) - start).days

    with open(out_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["date", "description", "amount"])
        for _ in range(row_count):
            merchant, category = random.choice(MERCHANTS)
            d = start + timedelta(days=random.randint(0, span_days))
            is_income = category in INCOME_LABELS
            amount = round(random.uniform(15000, 60000), 2) if is_income else round(random.uniform(30, 6000), 2)
            # Deliberately messy real-world formatting the categorizer must
            # normalize: mixed case, extra whitespace, trailing txn ids.
            desc = f"  {merchant.upper()} #{random.randint(100000, 999999)}  "
            writer.writerow([d.isoformat(), desc, amount])

    print(f"Wrote {row_count} rows to {out_path}")


if __name__ == "__main__":
    main()
