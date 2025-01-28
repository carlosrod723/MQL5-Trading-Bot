"""
test_train.py
-------------
This script trains (or loads) the LSTM model, then creates a small "test slice"
of data to verify that the live code produces the same predictions.

It will:
1) Load & preprocess your dataset as usual
2) Train (or load) the model
3) Generate predictions for a final set of rows (test slice)
4) Save them to "training_phase_test_slice.csv"

Afterwards, run your test_inference.py on that CSV to confirm matching predictions.
"""

import os
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam
from sklearn.preprocessing import StandardScaler
from tensorflow.keras.callbacks import EarlyStopping

def train_and_save_test_slice(input_csv: str, out_model_path: str = "python/models/lstm_model.h5"):
    # 1) Load and preprocess data
    df = pd.read_csv(input_csv)
    df["Target"] = (df["Close15m"].shift(-1) > df["Close15m"]).astype(int)
    df.dropna(subset=["Target"], inplace=True)

    features = [
        "LogReturn15m",
        "LogReturn4h",
        "Vol15m",
        "Vol4h",
        "Spread15m",
        "Spread4h"
    ]
    features = [f for f in features if f in df.columns]

    X = df[features].values
    y = df["Target"].values

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # Simple time-based split
    total_len = len(X_scaled)
    train_len = int(total_len * 0.8)
    X_train, y_train = X_scaled[:train_len], y[:train_len]
    X_test,  y_test  = X_scaled[train_len:], y[train_len:]

    # Reshape for LSTM => (samples, timesteps=1, features)
    num_features = len(features)
    X_train_reshaped = X_train.reshape((X_train.shape[0], 1, num_features))
    X_test_reshaped  = X_test.reshape((X_test.shape[0],  1, num_features))

    # 2) Build & train LSTM model (basic example)
    model = Sequential()
    model.add(LSTM(64, return_sequences=True, input_shape=(1, num_features), activation='relu'))
    model.add(Dropout(0.2))
    model.add(LSTM(32, activation='relu'))
    model.add(Dropout(0.2))
    model.add(Dense(1, activation='sigmoid'))

    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='binary_crossentropy',
        metrics=['accuracy']
    )

    early_stop = EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True)

    print("Starting training in test_train.py ...")
    model.fit(
        X_train_reshaped, y_train,
        epochs=10,  
        batch_size=32,
        validation_split=0.2,
        callbacks=[early_stop],
        verbose=1
    )

    # Evaluate on test set
    loss, accuracy = model.evaluate(X_test_reshaped, y_test, verbose=0)
    print(f"Test accuracy: {accuracy:.4f}")

    # 3) Save model
    os.makedirs(os.path.dirname(out_model_path), exist_ok=True)
    model.save(out_model_path)
    print(f"Model saved to {out_model_path}")

    # 4) Create a test slice from the *final* portion of your scaled data
    slice_size = 5  # e.g. last 5 samples
    slice_start = len(X_scaled) - slice_size
    if slice_start < 0:
        print("Not enough data for a test slice. Exiting.")
        return

    X_slice = X_scaled[slice_start:]
    y_slice = y[slice_start:]

    # Predict on that slice (using the model)
    X_slice_reshaped = X_slice.reshape((X_slice.shape[0], 1, num_features))
    preds_slice = model.predict(X_slice_reshaped)

    # Build a DataFrame with columns col_0..col_(n-1)
    slice_df = pd.DataFrame(X_slice, columns=[f"col_{i}" for i in range(num_features)])
    slice_df["model_pred"] = preds_slice.reshape(-1)
    slice_df["actual_y"]   = y_slice

    # Save to CSV
    slice_df.to_csv("training_phase_test_slice.csv", index=False)
    print("Wrote training_phase_test_slice.csv with model predictions for final slice.")


if __name__ == "__main__":
    input_csv_path = "python/data_processing/merged_data.csv"
    train_and_save_test_slice(input_csv_path)
