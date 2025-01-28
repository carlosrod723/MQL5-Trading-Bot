# test_inference.py
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model
from sklearn.preprocessing import StandardScaler

def main():
    # 1) Load the same model
    model = load_model("python/models/lstm_model.h5")  # or your path

    # 2) Load the test slice from training
    df_test = pd.read_csv("training_phase_test_slice.csv")
    # This CSV has columns col_0, col_1, ..., col_(n-1), plus model_pred, actual_y

    # 3) Extract just the feature columns
    # Assume col_0 ... col_(n-1) are the scaled features
    feature_cols = [c for c in df_test.columns if c.startswith("col_")]
    X_test_slice = df_test[feature_cols].values

    # (Assuming your model expects shape=(samples, features) or (samples, timesteps, features))
    # e.g. if your LSTM has shape=(None, 1, features):
    X_test_slice = X_test_slice.reshape((X_test_slice.shape[0], 1, X_test_slice.shape[1]))

    # 4) Predict with the model
    preds_inference_phase = model.predict(X_test_slice)

    # 5) Compare with the stored predictions from training_phase_test_slice.csv
    df_test["model_pred_inference_phase"] = preds_inference_phase.reshape(-1)

    # 6) Print or save the result
    df_test.to_csv("test_inference_results.csv", index=False)
    print(df_test[["model_pred","model_pred_inference_phase","actual_y"]])

if __name__ == "__main__":
    main()
