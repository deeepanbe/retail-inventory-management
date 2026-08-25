# Retail Inventory Management — Demand Forecasting + EOQ Optimization

![Python](https://img.shields.io/badge/Python-3.9%2B-blue)
![scikit-learn](https://img.shields.io/badge/scikit--learn-RandomForest-orange)
![SQL](https://img.shields.io/badge/SQL-MySQL%2FPostgreSQL-4479A1)

Two connected pieces: a Random Forest demand forecaster, and classic inventory optimization math (Economic Order Quantity, reorder points, safety stock) applied per product — plus a standalone SQL file with 14 inventory-analysis queries (stock levels, reorder alerts, ABC classification-style logic).

**This is a self-contained demo, not a deployed production system.** It generates a year of synthetic daily sales for 20 products (with seasonality, weekend lift, and occasional promotions) if no `data/sales.csv` is present, so it's runnable without a private dataset.

## Run it yourself

```bash
pip install -r requirements.txt
python main.py
```

## What it does

1. Loads (or generates) daily sales by product, with price and promotion flags
2. Trains a Random Forest to forecast daily demand
3. For each product, calculates:
   - **Safety stock** (buffer for demand variability, using a 95% service level z-score)
   - **Reorder point** (average demand over lead time + safety stock)
   - **Economic Order Quantity** (the order size that minimizes total ordering + holding cost)
4. `inventory_queries.sql` — 14 standalone SQL queries for inventory-level reporting (current stock vs. reorder level, low-stock flags, and related inventory analysis) against a MySQL/PostgreSQL-style schema

## Actual output (reproducible — run it and you'll get this)

**Demand forecast: R² = 0.893, MAPE = 13.4%** on held-out data (20 synthetic products, 1 year of daily sales).

Sample optimization output (first 3 of 20 products):

| Product | Avg Daily Demand | Annual Demand | Safety Stock | Reorder Point | EOQ |
|---|---|---|---|---|---|
| 1 | 181.3 | 66,170 | 239 | 1,508 | 934 |
| 2 | 22.7 | 8,298 | 30 | 189 | 310 |
| 3 | 150.9 | 55,079 | 195 | 1,252 | 1,768 |

**Being upfront about scope:** the SQL file assumes a schema this repo doesn't include sample data for, so it's a query reference rather than something you can run end-to-end here without your own inventory database. There's no Power BI file in this repo — a previous version of this README described one that was never actually added.

## Stack

Python, pandas, NumPy, scikit-learn (RandomForestRegressor), joblib. SQL (MySQL/PostgreSQL-compatible).

## Author

[Deepanraj Arumugam](https://deeepanbe.github.io) — Data Analyst / BI Developer
