# python/models/train.py

import os
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam
from sklearn.preprocessing import StandardScaler
from tensorflow.keras.callbacks import EarlyStopping

def train_lstm_model(input_csv: str, version: int = 1) -> None:
    output_model = f"python/models/lstm_model_v{version}.h5"

    df = pd.read_csv(input_csv)
    df["Target"] = (df["Close15m"].shift(-1) > df["Close15m"]).astype(int)
    df.dropna(subset=["Target"], inplace=True)

    # Example: use more columns
    features = [
        "LogReturn15m",
        "LogReturn4h",
        "Vol15m",
        "Vol4h",
        "Spread15m",
        "Spread4h"
    ]
    # drop missing columns if not in df
    features = [f for f in features if f in df.columns]

    X = df[features].values
    y = df["Target"].values

    # Scale data
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # Time-based split
    total_len = len(X_scaled)
    train_len = int(total_len * 0.7)
    val_len   = int(total_len * 0.85)

    X_train, y_train = X_scaled[:train_len], y[:train_len]
    X_val,   y_val   = X_scaled[train_len:val_len], y[train_len:val_len]
    X_test,  y_test  = X_scaled[val_len:],          y[val_len:]

    # Reshape
    num_features = len(features)
    X_train = X_train.reshape((X_train.shape[0], 1, num_features))
    X_val   = X_val.reshape((X_val.shape[0],     1, num_features))
    X_test  = X_test.reshape((X_test.shape[0],   1, num_features))

    # LSTM model
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

    print("Starting training...")
    history = model.fit(
        X_train, y_train,
        epochs=50,
        batch_size=32,
        validation_data=(X_val, y_val),
        callbacks=[early_stop],
        verbose=1
    )

    # Evaluate final on test set
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print(f"Test accuracy: {accuracy:.4f}")

    os.makedirs(os.path.dirname(output_model), exist_ok=True)
    model.save(output_model)
    print(f"LSTM model trained & saved to {output_model}")

# Run the model
if __name__ == "__main__":
    train_lstm_model("python/data_processing/merged_data.csv", version=2)
