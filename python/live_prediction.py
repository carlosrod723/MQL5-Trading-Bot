"""
live_prediction.py
------------------
Loads a trained LSTM model (e.g., 'lstm_model.h5'), reads the latest row(s) from
'merged_data.csv' or another data feed, computes a probability, and writes it to
'MQL5/Files/signal.csv' for MyTradingBot.mq5 to read.
No placeholders, fully definitive.
"""

import os
import sys
import time
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model
from sklearn.preprocessing import StandardScaler

def main():
    # Paths
    model_path = "python/models/lstm_model.h5"      
    data_path  = "python/data_processing/merged_data.csv"
    out_path   = "MQL5/Files/signal.csv"             

    # 1) Load the LSTM model
    if not os.path.isfile(model_path):
        print(f"Model file not found: {model_path}")
        sys.exit(1)
    model = load_model(model_path)
    print("Model loaded.")

    # 2) Load dataset, get latest row
    if not os.path.isfile(data_path):
        print(f"Data file not found: {data_path}")
        sys.exit(1)

    df = pd.read_csv(data_path)
    # Features
    features = [
        "LogReturn15m",
        "LogReturn4h",
        "Vol15m",
        "Vol4h",
        "Spread15m",
        "Spread4h"
    ]

    # Drop any rows with missing feature data
    df.dropna(subset=features, inplace=True)
    if len(df) < 1:
        print("No valid rows left in merged_data.csv after dropping NaNs.")
        sys.exit(1)

    # Scale the features
    X = df[features].values
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # Predict on the last row
    latest = X_scaled[-1]  # shape (num_features,)
    latest = latest.reshape((1, 1, len(features)))

    # 3) Predict
    prob_array = model.predict(latest)
    prob = prob_array[0][0]  # single probability
    print(f"Predicted probability (bullish) = {prob:.4f}")

    # 4) Write signal to 'signal.csv'
    # MQL5 EA must read from the same path: 'MQL5/Files/signal.csv'
    try:
        # Overwrite the file each time with the new probability
        with open(out_path, "w") as f:
            f.write(f"{prob:.6f}\n")
        print(f"Wrote signal {prob:.6f} to {out_path}")
    except Exception as e:
        print(f"Error writing {out_path}: {e}")

if __name__ == "__main__":
    main()
