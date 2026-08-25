#!/usr/bin/env python3
"""
main.py
Retail Inventory Management: Demand Forecasting + EOQ/Reorder-Point Optimization
Author: Deepanraj A - Data Analyst
"""

import argparse
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
import joblib
import warnings
warnings.filterwarnings('ignore')


def load_data(filepath):
    """Load retail sales data. Expected columns: date, product_id, price, promotion, sales"""
    try:
        df = pd.read_csv(filepath)
        print(f"Loaded {len(df)} records from {filepath}")
        return df
    except FileNotFoundError:
        print(f"File {filepath} not found. Generating sample data...")
        rng = np.random.default_rng(42)
        n_products = 20
        n_days = 365
        dates = pd.date_range('2025-01-01', periods=n_days)

        rows = []
        for product_id in range(1, n_products + 1):
            base_demand = rng.uniform(20, 200)
            price = rng.uniform(5, 80)
            for date in dates:
                month = date.month
                seasonality = 1 + 0.25 * np.sin(2 * np.pi * month / 12)
                weekend = 1.3 if date.dayofweek >= 5 else 1.0
                promotion = 1 if rng.random() < 0.08 else 0
                promo_lift = 1.6 if promotion else 1.0
                noise = rng.normal(1, 0.15)
                sales = max(0, base_demand * seasonality * weekend * promo_lift * noise)
                rows.append({
                    'date': date, 'product_id': product_id, 'price': round(price, 2),
                    'promotion': promotion, 'sales': round(sales)
                })
        return pd.DataFrame(rows)


def preprocess(df):
    """Feature engineering for demand prediction"""
    df = df.copy()
    df['date'] = pd.to_datetime(df['date'])
    df['month'] = df['date'].dt.month
    df['day_of_week'] = df['date'].dt.dayofweek
    df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
    return df


def train_demand_model(X_train, y_train):
    model = RandomForestRegressor(n_estimators=200, max_depth=10, random_state=42)
    model.fit(X_train, y_train)
    return model


def calculate_inventory_optimization(df, lead_time_days=7, service_level_z=1.65, ordering_cost=50, holding_cost_pct=0.2):
    """
    Classic inventory optimization per product:
    - Reorder point = (avg daily demand x lead time) + safety stock
    - Safety stock = z-score(service level) x std-dev of daily demand x sqrt(lead time)
    - Economic Order Quantity (EOQ) = sqrt(2 x annual demand x ordering cost / (holding cost per unit))
    """
    results = []
    for product_id, group in df.groupby('product_id'):
        daily_demand = group.groupby(group['date'].dt.date)['sales'].sum()
        avg_daily_demand = daily_demand.mean()
        std_daily_demand = daily_demand.std()
        annual_demand = avg_daily_demand * 365
        avg_price = group['price'].mean()
        holding_cost_per_unit = avg_price * holding_cost_pct

        safety_stock = service_level_z * std_daily_demand * np.sqrt(lead_time_days)
        reorder_point = (avg_daily_demand * lead_time_days) + safety_stock
        eoq = np.sqrt((2 * annual_demand * ordering_cost) / max(holding_cost_per_unit, 0.01))

        results.append({
            'product_id': product_id,
            'avg_daily_demand': round(avg_daily_demand, 1),
            'annual_demand': round(annual_demand),
            'safety_stock': round(safety_stock),
            'reorder_point': round(reorder_point),
            'eoq': round(eoq),
            'holding_cost_per_unit': round(holding_cost_per_unit, 2),
        })

    return pd.DataFrame(results)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', default='data/sales.csv')
    parser.add_argument('--output', default='inventory_demand_model.pkl')
    args = parser.parse_args()

    print("Retail Inventory Management")
    print("=" * 60)

    df = load_data(args.data)
    df = preprocess(df)

    # --- Demand forecasting ---
    feature_cols = ['month', 'day_of_week', 'is_weekend', 'price', 'promotion', 'product_id']
    X = df[feature_cols]
    y = df['sales']

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    print("\n=== Demand Forecasting Model ===")
    model = train_demand_model(X_train, y_train)
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    r2 = r2_score(y_test, y_pred)
    mape = np.mean(np.abs((y_test - y_pred) / np.maximum(y_test, 1))) * 100

    print(f"RMSE: {rmse:.2f} units")
    print(f"MAPE: {mape:.1f}%")
    print(f"R2 Score: {r2:.4f}")

    # --- Inventory optimization ---
    print("\n=== Inventory Optimization (EOQ + Reorder Points) ===")
    optimization = calculate_inventory_optimization(df)
    print(optimization.head(10).to_string(index=False))

    total_annual_demand = optimization['annual_demand'].sum()
    avg_safety_stock_days = (optimization['safety_stock'] / optimization['avg_daily_demand']).mean()
    print(f"\nTotal annual demand across {len(optimization)} products: {total_annual_demand:,.0f} units")
    print(f"Average safety stock buffer: {avg_safety_stock_days:.1f} days of demand")

    joblib.dump(model, args.output)
    print(f"\nDemand model saved to {args.output}")

    print("\n" + "=" * 60)
    print(f"Demand forecast: R2={r2:.3f}, MAPE={mape:.1f}%")
    print(f"Inventory optimization: {len(optimization)} products, reorder points and EOQ calculated")


if __name__ == '__main__':
    main()
