# python/models/train.py

import os
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
from sklearn.preprocessing import StandardScaler
import joblib

def create_sequences(X, y, sequence_length):
    """
    Transforms the data into sequences of a given length.
    
    Each sequence is made of `sequence_length` consecutive rows from X,
    and the corresponding target is taken as the value immediately after the sequence.
    """
    Xs, ys = [], []
    for i in range(len(X) - sequence_length):
        Xs.append(X[i:i+sequence_length])
        ys.append(y[i+sequence_length])
    return np.array(Xs), np.array(ys)

def train_lstm_model(input_csv: str,
                     version: int = 1,
                     epochs: int = 50,
                     batch_size: int = 32,
                     sequence_length: int = 1) -> None:
    """
    Trains an LSTM model on the merged CSV data and saves the model and scaler.
    
    Parameters:
        input_csv (str): Path to the CSV file containing the merged data.
        version (int): Version number for naming output files.
        epochs (int): Maximum number of training epochs.
        batch_size (int): Batch size for training.
        sequence_length (int): Number of timesteps per sample. Use 1 to mimic single-bar inputs.
    """
    # Define output paths for model and scaler files
    output_model = f"python/models/lstm_model_v{version}.h5"
    scaler_path  = f"python/models/scaler_v{version}.pkl"

    # --- Load and preprocess data ---
    df = pd.read_csv(input_csv)
    # Create target: 1 if next bar's Close15m is higher than current bar's, else 0.
    df["Target"] = (df["Close15m"].shift(-1) > df["Close15m"]).astype(int)
    df.dropna(subset=["Target"], inplace=True)

    # Define feature columns (only keep those that exist)
    features = [
        "LogReturn15m",
        "LogReturn4h",
        "Vol15m",
        "Vol4h",
        "Spread15m",
        "Spread4h"
    ]
    features = [f for f in features if f in df.columns]
    if not features:
        raise ValueError("No valid features found in the dataset.")

    X = df[features].values
    y = df["Target"].values

    # --- Scale features ---
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    os.makedirs(os.path.dirname(scaler_path), exist_ok=True)
    joblib.dump(scaler, scaler_path)
    print(f"Scaler saved to {scaler_path}")

    # --- Create sequences if required ---
    if sequence_length > 1:
        X_seq, y_seq = create_sequences(X_scaled, y, sequence_length)
    else:
        # When sequence_length == 1, reshape to add a timestep dimension.
        X_seq = X_scaled.reshape((X_scaled.shape[0], 1, X_scaled.shape[1]))
        y_seq = y

    total_samples = len(X_seq)
    train_end = int(total_samples * 0.7)
    val_end   = int(total_samples * 0.85)

    X_train, y_train = X_seq[:train_end], y_seq[:train_end]
    X_val,   y_val   = X_seq[train_end:val_end], y_seq[train_end:val_end]
    X_test,  y_test  = X_seq[val_end:], y_seq[val_end:]

    # Print shapes for debugging
    print("Train shape:", X_train.shape, y_train.shape)
    print("Validation shape:", X_val.shape, y_val.shape)
    print("Test shape:", X_test.shape, y_test.shape)

    # --- Build the LSTM model ---
    num_features = len(features)
    # Determine input shape: if using sequences, shape is (sequence_length, num_features)
    input_shape = (sequence_length, num_features) if sequence_length > 1 else (1, num_features)

    model = Sequential()
    model.add(LSTM(64, return_sequences=True, input_shape=input_shape, activation='relu'))
    model.add(Dropout(0.2))
    model.add(LSTM(32, activation='relu'))
    model.add(Dropout(0.2))
    model.add(Dense(1, activation='sigmoid'))

    model.compile(
        optimizer=Adam(learning_rate=0.001),
        loss='binary_crossentropy',
        metrics=['accuracy']
    )

    # --- Define callbacks ---
    early_stop = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True)
    checkpoint_path = f"python/models/best_model_v{version}.h5"
    checkpoint = ModelCheckpoint(checkpoint_path, monitor='val_loss', save_best_only=True, verbose=1)

    print("Starting training...")
    history = model.fit(
        X_train, y_train,
        epochs=epochs,
        batch_size=batch_size,
        validation_data=(X_val, y_val),
        callbacks=[early_stop, checkpoint],
        verbose=1
    )

    # --- Evaluate on test set ---
    loss, accuracy = model.evaluate(X_test, y_test, verbose=0)
    print(f"Test accuracy: {accuracy:.4f}")

    # --- Save final model ---
    os.makedirs(os.path.dirname(output_model), exist_ok=True)
    model.save(output_model)
    print(f"LSTM model trained & saved to {output_model}")

if __name__ == "__main__":
    train_lstm_model("python/data_processing/merged_data.csv", version=2,
                     epochs=50, batch_size=32, sequence_length=1)
