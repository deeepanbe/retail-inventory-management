#!/usr/bin/env python3
"""
main.py
Retail Inventory Management ML Pipeline
Author: Deepanraj A
"""

import argparse
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error, r2_score
import joblib
import warnings
warnings.filterwarnings('ignore')

def load_data(filepath):
    """Load retail sales data"""
    df = pd.read_csv(filepath)
    print(f"Loaded {len(df)} records")
    return df

def preprocess(df):
    """Feature engineering for inventory prediction"""
    df['month'] = pd.to_datetime(df['date']).dt.month
    df['day_of_week'] = pd.to_datetime(df['date']).dt.dayofweek
    df['is_weekend'] = (df['day_of_week'] >= 5).astype(int)
    return df

def train_model(X_train, y_train):
    """Train Random Forest model"""
    model = RandomForestRegressor(n_estimators=200, random_state=42)
    model.fit(X_train, y_train)
    return model

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--data', default='data/sales.csv')
    parser.add_argument('--output', default='models/inventory_model.pkl')
    args = parser.parse_args()
    
    # Load and preprocess
    df = load_data(args.data)
    df = preprocess(df)
    
    # Prepare features
    feature_cols = ['month', 'day_of_week', 'is_weekend', 'price', 'promotion']
    X = df[feature_cols]
    y = df['sales']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Train
    print("Training model...")
    model = train_model(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))
    r2 = r2_score(y_test, y_pred)
    
    print(f"RMSE: {rmse:.2f}")
    print(f"R2 Score: {r2:.4f}")
    
    # Save model
    joblib.dump(model, args.output)
    print(f"Model saved to {args.output}")

if __name__ == '__main__':
    main()
