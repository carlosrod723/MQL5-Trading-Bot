"""
live_prediction.py
------------------
Loads a trained LSTM model (e.g., 'lstm_model_v2.h5'), reads the latest row from
'merged_data.csv' (or another data feed), computes a bullish probability, and writes it to
'MQL5/Files/signal.csv' for MyTradingBot.mq5 to read.
"""

import os
import sys
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model
import joblib

def main():
    # Set the version number (should match your training version)
    version = 2

    # Paths (ensure these match your directory structure)
    model_path  = f"python/models/lstm_model_v{version}.h5"      
    scaler_path = f"python/models/scaler_v{version}.pkl"
    data_path   = "python/data_processing/merged_data.csv"
    out_path    = "MQL5/Files/signal.csv"             

    # 1) Load the LSTM model
    if not os.path.isfile(model_path):
        print(f"Model file not found: {model_path}")
        sys.exit(1)
    model = load_model(model_path)
    print("Model loaded.")

    # 2) Load the pre-fitted scaler
    if os.path.isfile(scaler_path):
        scaler = joblib.load(scaler_path)
        print(f"Scaler loaded from {scaler_path}")
    else:
        print(f"Scaler file not found: {scaler_path}. Cannot scale data properly.")
        sys.exit(1)

    # 3) Load dataset and obtain the latest row
    if not os.path.isfile(data_path):
        print(f"Data file not found: {data_path}")
        sys.exit(1)
    df = pd.read_csv(data_path)

    # Define the feature columns
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
    if df.empty:
        print("No valid rows left in merged_data.csv after dropping NaNs.")
        sys.exit(1)

    # Extract features and scale them using the pre-fitted scaler
    X = df[features].values
    X_scaled = scaler.transform(X)

    # Predict on the last row
    latest = X_scaled[-1]  # shape (num_features,)
    # Reshape to add timestep dimension (shape: (1, 1, num_features))
    latest = latest.reshape((1, 1, len(features)))

    # 4) Predict using the model
    prob_array = model.predict(latest)
    prob = prob_array[0][0]  # extract the single probability value
    print(f"Predicted probability (bullish) = {prob:.4f}")

    # 5) Write the probability signal to 'signal.csv'
    try:
        with open(out_path, "w") as f:
            f.write(f"{prob:.6f}\n")
        print(f"Wrote signal {prob:.6f} to {out_path}")
    except Exception as e:
        print(f"Error writing {out_path}: {e}")

if __name__ == "__main__":
    main()
