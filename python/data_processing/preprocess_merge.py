# python/data_processing/preprocess_merge.py

"""
preprocess_merge.py
Merges 4H and 15M data for the same symbol (e.g. GBPUSD).
Output: a single CSV with columns from both timeframes.
"""

import pandas as pd
import numpy as np
import os

def load_and_preprocess(csv_file: str, timeframe_label: str) -> pd.DataFrame:
    """
    Loads and preprocesses a CSV file containing OHLC data.
    
    Parameters:
        csv_file (str): Path to the CSV file.
        timeframe_label (str): A string label to append to the renamed columns 
                               (e.g., "15m" or "4h").
                               
    Returns:
        pd.DataFrame: Preprocessed DataFrame with a new 'Time' column, renamed 
                      OHLC and volume columns, and a log return column.
    """
    if not os.path.isfile(csv_file):
        raise FileNotFoundError(f"{csv_file} not found.")
    
    df = pd.read_csv(csv_file)
    required_cols = ["DATE", "TIME", "OPEN", "HIGH", "LOW", "CLOSE", "TICKVOL"]
    for col in required_cols:
        if col not in df.columns:
            raise ValueError(f"Missing {col} in {csv_file}.")

    # Create a unified Time column
    df["Time"] = pd.to_datetime(df["DATE"] + " " + df["TIME"], format="%Y.%m.%d %H:%M:%S")
    
    # Rename columns to include the timeframe label
    rename_dict = {
        "OPEN": f"Open{timeframe_label}",
        "HIGH": f"High{timeframe_label}",
        "LOW":  f"Low{timeframe_label}",
        "CLOSE": f"Close{timeframe_label}",
        "TICKVOL": f"Vol{timeframe_label}"
    }
    df.rename(columns=rename_dict, inplace=True)
    
    # Drop columns that are no longer needed (ignore errors if a column doesn't exist)
    df.drop(["DATE", "TIME", "SPREAD"], axis=1, inplace=True, errors='ignore')
    
    # Sort and reset the index by Time
    df.sort_values("Time", inplace=True)
    df.reset_index(drop=True, inplace=True)
    
    # Calculate log returns and replace infinite values with 0
    log_return_col = f"LogReturn{timeframe_label}"
    df[log_return_col] = np.log(df[f"Close{timeframe_label}"] / df[f"Close{timeframe_label}"].shift(1))
    df[log_return_col].replace([np.inf, -np.inf], 0, inplace=True)
    df.dropna(subset=[log_return_col], inplace=True)
    
    return df

def merge_timeframes(
    csv_15m: str,
    csv_4h: str,
    output_csv: str = "merged_data.csv"
):
    """
    Merges 15-minute and 4-hour data into a single CSV file.
    
    Reads the 15M and 4H CSV files (each containing DATE, TIME, OPEN, HIGH, LOW, 
    CLOSE, TICKVOL, SPREAD), creates a 'Time' column in both, renames columns 
    to include the timeframe (e.g. Close15m, Close4h), resamples the 4H data to 
    15-minute intervals using forward-fill, merges the datasets using an asof 
    merge (backward direction), and finally adds log return columns.
    
    The merged DataFrame is saved as CSV to the specified output file.
    """
    # Process 15-minute data
    df_15m = load_and_preprocess(csv_15m, "15m")
    
    # Process 4-hour data
    df_4h = load_and_preprocess(csv_4h, "4h")
    
    # Resample 4H data to 15-minute frequency using forward fill
    df_4h.set_index("Time", inplace=True)
    df_4h_15m = df_4h.resample("15min").ffill().reset_index()
    
    # Ensure both DataFrames are sorted by Time
    df_15m.sort_values("Time", inplace=True)
    df_4h_15m.sort_values("Time", inplace=True)
    
    # Merge the data using an asof merge; each 15m bar gets the last known 4H data
    merged = pd.merge_asof(
        df_15m, df_4h_15m,
        on="Time",
        direction="backward"
    )
    
    # Drop any rows that may have NaN values (often due to early timestamps)
    merged.dropna(inplace=True)
    
    # Save the merged DataFrame to CSV
    merged.to_csv(output_csv, index=False)
    print(f"Merged data saved to {output_csv} with {len(merged)} rows.")

if __name__ == "__main__":
    # Example usage:
    path_15m = "../../data/GBPUSD_M15_JAN2021_JAN2023.csv"
    path_4h  = "../../data/GBPUSD_H4_JAN2021_JAN2023.csv"
    merge_timeframes(path_15m, path_4h, "merged_data.csv")
