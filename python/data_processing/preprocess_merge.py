# python/data_processing/preprocess_merge.py

"""
preprocess_merge.py
Merges 4H and 15M data for the same symbol (e.g. GBPUSD).
Output: a single CSV with columns from both timeframes.
"""

import pandas as pd
import numpy as np
import os

def merge_timeframes(
    csv_15m: str,
    csv_4h: str,
    output_csv: str = "merged_data.csv"
):
    """
    Reads the 15M and 4H CSV files, each with DATE,TIME,OPEN,HIGH,LOW,CLOSE,TICKVOL,SPREAD.
    - Creates a Time column in both.
    - Renames to Close15m, Close4h, etc.
    - Resamples 4H to 15-minute intervals with forward-fill.
    - Merges them so each 15m bar has the corresponding 4H data.
    - Adds LogReturn15m and LogReturn4h.
    - Saves merged CSV to output_csv.
    """

    if not os.path.isfile(csv_15m):
        raise FileNotFoundError(f"{csv_15m} not found.")
    if not os.path.isfile(csv_4h):
        raise FileNotFoundError(f"{csv_4h} not found.")

    # --- Read 15m data
    df_15m = pd.read_csv(csv_15m)
    for col in ["DATE", "TIME", "OPEN", "HIGH", "LOW", "CLOSE", "TICKVOL"]:
        if col not in df_15m.columns:
            raise ValueError(f"Missing {col} in 15m CSV.")

    df_15m["Time"] = pd.to_datetime(df_15m["DATE"] + " " + df_15m["TIME"], format="%Y.%m.%d %H:%M:%S")
    df_15m.rename(columns={
        "OPEN": "Open15m",
        "HIGH": "High15m",
        "LOW":  "Low15m",
        "CLOSE":"Close15m",
        "TICKVOL": "Vol15m"
    }, inplace=True)
    df_15m.drop(["DATE","TIME","SPREAD"], axis=1, inplace=True, errors='ignore')
    df_15m.sort_values("Time", inplace=True)
    df_15m.reset_index(drop=True, inplace=True)

    # Add LogReturn15m
    df_15m["LogReturn15m"] = np.log(df_15m["Close15m"] / df_15m["Close15m"].shift(1)).replace([np.inf,-np.inf], 0)
    df_15m.dropna(subset=["LogReturn15m"], inplace=True)

    # --- Read 4H data
    df_4h = pd.read_csv(csv_4h)
    for col in ["DATE", "TIME", "OPEN", "HIGH", "LOW", "CLOSE", "TICKVOL"]:
        if col not in df_4h.columns:
            raise ValueError(f"Missing {col} in 4H CSV.")

    df_4h["Time"] = pd.to_datetime(df_4h["DATE"] + " " + df_4h["TIME"], format="%Y.%m.%d %H:%M:%S")
    df_4h.rename(columns={
        "OPEN": "Open4h",
        "HIGH": "High4h",
        "LOW":  "Low4h",
        "CLOSE":"Close4h",
        "TICKVOL": "Vol4h"
    }, inplace=True)
    df_4h.drop(["DATE","TIME","SPREAD"], axis=1, inplace=True, errors='ignore')
    df_4h.sort_values("Time", inplace=True)
    df_4h.reset_index(drop=True, inplace=True)

    # Add LogReturn4h
    df_4h["LogReturn4h"] = np.log(df_4h["Close4h"] / df_4h["Close4h"].shift(1)).replace([np.inf,-np.inf], 0)
    df_4h.dropna(subset=["LogReturn4h"], inplace=True)

    # Convert 4H data to a 15m frequency with forward fill
    df_4h.set_index("Time", inplace=True)
    df_4h_15m = df_4h.resample("15min").ffill().reset_index()

    # --- Merge (asof-merge or normal merge on 'Time')
    # Forward-fill approach. Each 15m bar gets the last known 4H data
    # by matching times "backward".
    df_15m.sort_values("Time", inplace=True)
    df_4h_15m.sort_values("Time", inplace=True)

    # We can do asof merge to ensure we don't skip partial times
    merged = pd.merge_asof(
        df_15m, df_4h_15m,
        on="Time",
        direction="backward"
    )

    # Drop any rows that might have NaN due to early timestamps
    merged.dropna(inplace=True)

    merged.to_csv(output_csv, index=False)
    print(f"Merged data saved to {output_csv} with {len(merged)} rows.")

if __name__ == "__main__":
    # Example usage:
    path_15m = "../../data/GBPUSD_M15_JAN2021_JAN2023.csv"
    path_4h  = "../../data/GBPUSD_H4_JAN2021_JAN2023.csv"
    merge_timeframes(path_15m, path_4h, "merged_data.csv")
