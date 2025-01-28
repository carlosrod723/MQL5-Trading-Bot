# MQL5-Bot

This repository contains a **MetaTrader 5 (MQL5) Expert Advisor** that implements a multi-timeframe trading strategy using **fractals**, **Fibonacci zones**, **order blocks**, and optional indicators (MA, RSI, ATR, Bollinger). It also includes **Python** scripts for **data export**, **preprocessing**, **machine learning** training, **live prediction**, and consistency testing.

---

## Table of Contents

1. [Overview](#overview)  
2. [Project Structure](#project-structure)  
3. [Installation & Requirements](#installation--requirements)  
4. [Usage - MQL5 Expert Advisor](#usage---mql5-expert-advisor)  
   - [Placing Files in MT5](#placing-files-in-mt5)  
   - [Expert Advisor Inputs](#expert-advisor-inputs)  
   - [Backtesting & Optimization](#backtesting--optimization)  
5. [Usage - Data Export & Machine Learning](#usage---data-export--machine-learning)  
   - [Exporting Data (`DataExporter.mq5`)](#exporting-data-dataexportermq5)  
   - [Python Preprocessing (`preprocess.py`)](#python-data-preprocessing-preprocesspy)  
   - [Training the Model (`train.py`)](#training-the-model-trainpy)  
   - [Live Prediction (`live_prediction.py`)](#live-prediction-live_predictionpy)  
6. [ML Integration with the EA](#ml-integration-with-the-ea)  
7. [Testing & Consistency Scripts](#testing--consistency-scripts)  
8. [Future Development](#future-development)  
9. [Troubleshooting & Common Issues](#troubleshooting--common-issues)  
10. [License & Disclaimer](#license--disclaimer)  
11. [Contact](#contact)

---

## Overview

This bot automates a **multi-timeframe** trading strategy by:

- **H4 Timeframes**: Determining premium/discount zones (via Fibonacci) and identifying **order blocks** for higher-level trend context.  
- **15M Timeframes**: Detecting **fractal-based liquidity sweeps** and placing **limit orders** after these sweeps.  
- **Risk Management**: Enforces **daily drawdown limits**, calculates **per-trade risk**, offers **partial exits** and **trailing stops**.  
- **Optional Indicators**: MA, RSI, ATR, and Bollinger can be toggled on/off to filter entries.  
- **Machine Learning**: A **file-based** bridging approach allows the EA to read **ML signals** (probability) from a CSV. If enabled, the EA only trades when the ML probability exceeds a user-set threshold.

---

## Project Structure

```plaintext
MQL5-Bot/
├── LICENSE
├── MQL5
│   ├── Experts
│   │   └── MyTradingBot.mq5            # Core Expert Advisor
│   ├── Include
│   │   └── RiskManagement.mqh          # Shared risk & lot-size functions
│   ├── Indicators
│   │   ├── FractalScanner.mq5          # Optional fractal indicator
│   │   └── OrderBlock.mq5              # Optional order block indicator
│   └── Scripts
│       └── DataExporter.mq5            # Exports OHLC data to CSV
├── README.md                           # This file
├── python
│   ├── data_processing
│   │   ├── preprocess.py               # Cleans & preprocesses CSV data
│   │   └── merged_data.csv             # Example dataset after merging
│   ├── live_prediction.py              # Real-time ML inference script
│   └── models
│       ├── lstm_model.h5               # Trained LSTM model
│       └── train.py                    # Script to train an ML model
├── requirements.txt                    # Python dependencies
└── tests
    ├── test_train.py                   # Generates a test slice during training
    ├── test_inference.py               # Checks inference consistency
    └── backtest_results                # Place backtest reports here
```

## Installation & Requirements

This project requires the following software and setup:

**1. MetaTrader 5 Terminal:**

*   Download and install the MetaTrader 5 (MT5) trading platform from either the official [MetaQuotes website](https://www.metatrader5.com/en/download) or from your preferred broker.
*   Ensure you have a demo or live trading account set up with your broker.
*   Verify that you can successfully log in to your account within the MT5 terminal.

**2. MQL5 Compiler:**

*   The MetaEditor, which is included with the MT5 terminal, is used to compile `.mq5` files (MQL5 source code) into executable `.ex5` files.
*   No separate installation is required. You can access the MetaEditor from within the MT5 terminal (usually by pressing F4 or going to "Tools" -> "MetaQuotes Language Editor").

**3. Python Environment (for Machine Learning):**

*   If you intend to utilize the machine learning features of this project (e.g., training and using the LSTM model), you need to install **Python 3.8 or higher**.
*   Once Python is installed, set up a virtual environment and install the required Python packages by running the following command in your terminal from the root directory of this project:

    ```bash
    pip install -r requirements.txt
    ```

    This command will install packages such as `pandas`, `numpy`, `tensorflow`, and other dependencies listed in the `requirements.txt` file.

## Usage - MQL5 Expert Advisor

### Placing Files in MT5

To use the `MyTradingBot` Expert Advisor (EA), you need to place the provided MQL5 files into the correct folders within your MetaTrader 5 data directory. Here's how:

1.  **Open the Data Folder:**
    *   In your MetaTrader 5 terminal, go to `File` -> `Open Data Folder`. This will open the directory where MT5 stores its data.

2.  **Place the files as follows:**

    *   **Expert Advisor:**
        *   `MyTradingBot.mq5` -> `MQL5/Experts/`
    *   **Indicators:**
        *   `FractalScanner.mq5` -> `MQL5/Indicators/`
        *   `OrderBlock.mq5` -> `MQL5/Indicators/`
    *   **Include:**
        *   `RiskManagement.mqh` -> `MQL5/Include/`
    *   **Scripts:**
        *   `DataExporter.mq5` -> `MQL5/Scripts/`
        *   `DataExporterIndicators.mq5` -> `MQL5/Scripts/`

3.  **Refresh or Restart:**
    *   After placing the files, either right-click on "Expert Advisors" in the MT5 Navigator panel and select "Refresh", or restart the MetaTrader 5 terminal. This will make the new files appear in the Navigator.

### Expert Advisor Inputs

To configure `MyTradingBot`, attach it to a chart (e.g., EURUSD M15) and adjust the input parameters:

1.  **Attaching the EA:**
    *   Drag and drop `MyTradingBot` from the Navigator panel onto a chart of the desired symbol and timeframe.

2.  **Input Parameters:**
    *   A window will pop up with various tabs. Go to the "Inputs" tab to see the following configurable parameters:

        *   **`RiskPerTrade (%)`:** The percentage of your account balance to risk on each trade.
        *   **`DailyDrawdownLimit (%)`:** If the daily loss exceeds this percentage, the EA will not open any new trades for the rest of the day.
        *   **`UsePartialExit`:** ( `true`/`false` ) Enables or disables partial position closing.
        *   **`PartialExitRatio`:** If `UsePartialExit` is `true`, this determines the fraction of the position to close when the partial exit condition is met.
        *   **`UseTrailingStop`:** ( `true`/`false` ) Enables or disables trailing stops.
        *   **`TrailStopPips`:** If `UseTrailingStop` is `true`, this sets the trailing stop distance in pips.
        *   **`UseMA`, `UseRSI`, `UseATR`, `UseBollinger`:** ( `true`/`false` ) These parameters toggle the use of additional filter indicators (Moving Average, RSI, ATR, Bollinger Bands).
        *   **`UseOrderBlocks`:** ( `true`/`false` ) If `true`, order block signals from the `OrderBlock` indicator must align with the trade direction for a trade to be placed.
        *   **`FibEntryLevel`:** (e.g., 0.5) This sets the Fibonacci level used to determine premium/discount zones. A value of 0.5 represents the 50% retracement level.
        *   **`MagicNumber`:** A unique integer identifier used by the EA to manage its trades. Make sure this number is different for each EA you run on the same account.

### Backtesting & Optimization

To evaluate the performance of `MyTradingBot` and find optimal input parameters, use the MetaTrader 5 Strategy Tester:

1.  **Open the Strategy Tester:**
    *   In MT5, go to `View` -> `Strategy Tester` (or press `Ctrl+R`).

2.  **Configure the Test:**
    *   **Expert Advisor:** Select `MyTradingBot` from the list of Expert Advisors.
    *   **Symbol:** Choose the trading instrument (e.g., EURUSD).
    *   **Timeframe:** Select the chart timeframe (e.g., M15, H4).
    *   **Date Range:** Specify the historical period you want to test on.
    *   **Inputs:** Click the "Inputs" tab and adjust the parameters you want to test or optimize.
    *   **Optimization:** If you want to optimize parameters, select the type of optimization (e.g., "Slow complete algorithm", "Fast genetic based algorithm") and define the optimization criteria.

3.  **Run the Test:**
    *   Click the "Start" button to begin the backtest or optimization.

4.  **Analyze Results:**
    *   **Journal Tab:** Monitor the Strategy Tester's progress and any error messages in the "Journal" tab.
    *   **Results Tab:** After the test is complete, the "Results" tab will show a list of trades executed during the backtest.
    *   **Graph Tab:** Visualize the backtest results on a chart in the "Graph" tab.
    *   **Optimization Results Tab:** If you ran an optimization, this tab will display the results for each parameter combination tested.

5.  **Save Reports:**
    *   You can save detailed backtest reports by right-clicking in the "Results" or "Optimization Results" tab and selecting "Save as Report". These reports can be saved to the `tests/backtest_results` directory.

## Usage - Data Export & Machine Learning

This section describes how to export data from MetaTrader 5, preprocess it using Python, train a machine-learning model, and use the model's predictions in the `MyTradingBot` Expert Advisor.

### 1. Exporting Data from MetaTrader 5

The `DataExporter.mq5` script is used to export historical data from MetaTrader 5 to a CSV file.

**Steps:**

1.  **Locate the Script:** In the MetaTrader 5 Navigator panel, expand the "Scripts" section.
2.  **Drag and Drop:** Drag and drop the `DataExporter.mq5` script onto a chart of the symbol you want to export data from.
3.  **Set Parameters:** A window will pop up allowing you to configure the script's parameters:
    *   **`ExportSymbol`:** The symbol to export data for (e.g., "EURUSD"). If left empty, it defaults to the chart's symbol.
    *   **`TF`:** The timeframe of the data to export (e.g., `PERIOD_M15`, `PERIOD_H4`).
    *   **`BarsToExport`:** The number of historical bars to export.
    *   **Other parameters:** Adjust other parameters as needed, such as the filename and delimiter.
4.  **Run the Script:** Click "OK" to run the script.
5.  **Output File:** The script will create a CSV file (e.g., `mt5_export.csv`) in the `MQL5/Files/` directory within your MetaTrader 5 data folder.
6.  **Copy the File (Optional):** If you intend to use this data for preprocessing, merging, or training the machine learning model in Python, copy the exported CSV file from `MQL5/Files/` to the `python/data_processing/` directory.

### 2. Python Data Preprocessing

The `preprocess.py` script (located in `python/data_processing/`) is used to clean and prepare the exported data for machine learning.

**Example Usage:**

1.  **Navigate to the Directory:** Open your terminal and navigate to the `python/data_processing/` directory:

    ```bash
    cd python/data_processing
    ```

2.  **Run the Script:** Execute the `preprocess.py` script with the appropriate command-line arguments:

    ```bash
    python preprocess_merge.py --input_h4_csv <path_to_h4_data> --input_m15_csv <path_to_m15_data> --output_csv merged_data.csv
    ```
    
    ```bash
    python preprocess_merge_indicators.py --input_csv merged_data.csv --output_csv indicator_export.csv
    ```

    *   **`--input_h4_csv`:** The path to your H4 CSV file.
    *   **`--input_m15_csv`:** The path to your M15 CSV file.
    *   **`--output_csv`:**  The desired path and filename for the output CSV file (e.g., `cleaned_data.csv`).

**Functionality:**

*   The example usage showcases a function `clean_and_prepare`. You should replace this with the actual functions in your `preprocess.py` script.
*   Typically, a preprocessing script would:
    *   Verify that the CSV has the expected columns.
    *   Sort the data chronologically by the timestamp column.
    *   Add engineered features (e.g., log returns, technical indicators).
    *   Handle missing data (if any).
    *   Save the cleaned data to a new CSV file (e.g., `cleaned_data.csv`).
*   **Customization:** You can modify `preprocess.py` to include any additional data transformations or feature engineering steps that are relevant to your trading strategy.

### 3. Training the Machine Learning Model

The `train.py` script (located in `python/models/`) trains a Long Short-Term Memory (LSTM) neural network using the preprocessed data.

**Steps:**

1.  **Navigate to the Directory:** In your terminal, navigate to the `python/models/` directory:

    ```bash
    cd python/models
    ```

2.  **Run the Script:** Execute the `train.py` script:

    ```bash
    python train.py
    ```

**Functionality:**

*   The script reads the cleaned data (e.g., `cleaned_data.csv` or `merged_data.csv`).
*   It creates features and a target variable for the LSTM model based on the data.
*   It trains a simple LSTM model using TensorFlow/Keras.
*   It saves the trained model to a file named `lstm_model.h5` (or a similar name based on model versioning in your script).

**Customization:**

*   You can adjust hyperparameters of the LSTM model within `train.py`, such as:
    *   Number of epochs
    *   Batch size
    *   Number of hidden layers and units in the LSTM
    *   Learning rate of the optimizer

### 4. Live Prediction with the Model

The `live_prediction.py` script loads the trained LSTM model and uses it to generate predictions on new, incoming data.

**Steps:**

1.  **Navigate to the Directory:** In your terminal, navigate to the `python` directory:
    ```bash
    cd python
    ```
2.  **Run the Script:** Execute the `live_prediction.py` script:
    ```bash
    python live_prediction.py
    ```

**Functionality:**

*   Loads the trained LSTM model from the `lstm_model.h5` file.
*   Reads the latest data row(s) from a specified CSV file (e.g., a file that is continuously updated with live market data).
*   Uses the loaded model to make a prediction (e.g., the probability of an upward price movement).
*   Writes the prediction to a file named `signal.csv` in the `MQL5/Files/` directory of your MetaTrader 5 data folder.

**Integration with `MyTradingBot`:**

*   If the `UseMLSignal` parameter is set to `true` in `MyTradingBot`, the EA will read the `signal.csv` file on each new bar.
*   If the probability in `signal.csv` is below the `ML_Threshold`, the EA will skip placing new trades.

**Important Notes:**

*   **Data Synchronization:** Ensure that the data used for live prediction is consistent with the data used for training the model (same features, preprocessing steps, etc.).
*   **Real-time Data:** For live trading, you'll need a mechanism to continuously update the CSV file that `live_prediction.py` reads from with real-time market data. This might involve a separate script or a custom solution within MetaTrader 5.
*   **Error Handling:** Consider adding robust error handling to both `live_prediction.py` and `MyTradingBot` to gracefully handle situations like missing files, invalid data, or model loading errors.

## ML Integration with the EA

The `MyTradingBot` Expert Advisor can integrate with a machine learning model (specifically, the LSTM model trained in `train.py`) to filter trade signals.

**Functionality:**

*   When the `UseMLSignal` input parameter in `MyTradingBot` is set to `true`:
    1.  On each new bar (within the `OnTick()` function), the EA attempts to open and read a file named `signal.csv` located in the `MQL5/Files/` directory of your MetaTrader 5 data folder.
    2.  It expects this file to contain a single numerical value representing the probability of an upward price movement (as predicted by your machine learning model).
    3.  If the probability found in `signal.csv` is less than the `ML_Threshold` input parameter, the EA will skip placing any new trades for that bar.
    4.  If the probability is greater than or equal to `ML_Threshold`, the EA will proceed with its regular trading logic (fractal analysis, order block checks, etc.).

**Generating the Signal:**

*   The `live_prediction.py` script is responsible for generating the probability value written to `signal.csv`.
*   It loads the trained LSTM model (typically from `lstm_model.h5`).
*   It reads the latest market data from a specified CSV file.
*   It uses the loaded model to make a prediction.
*   It writes the prediction (a single probability value) to `signal.csv`.

**File-Based Communication:**

*   This integration uses a simple file-based approach for communication between the Python script (`live_prediction.py`) and the MQL5 EA (`MyTradingBot`).
*   **Important:** Both the Python script and the EA must be running on the same machine, or they must have access to the same shared folder where `signal.csv` is located.

## Testing & Consistency Scripts

To ensure that your machine learning model is being used correctly in the live trading environment, two additional testing scripts are provided:

*   **`test_train.py`:**
    *   This script either trains a new model or loads an existing one (e.g., `lstm_model.h5`).
    *   It selects a small portion of data from the end of your training dataset (a "test slice").
    *   It uses the model to make predictions on this test slice.
    *   It saves these predictions to a file named `training_phase_test_slice.csv` in the `python/data_processing` directory.

*   **`test_inference.py`:**
    *   This script loads the same trained model.
    *   It reads the data from `training_phase_test_slice.csv` (the same data used by `test_train.py`).
    *   It uses the loaded model to make predictions on this data.
    *   It compares these new predictions to the predictions saved by `test_train.py`.

**Purpose of the Tests:**

*   These scripts help you verify that the predictions generated by your model during training are **identical** to the predictions generated when the model is loaded and used for inference (as in `live_prediction.py`).
*   This confirms that data scaling, column order, and other preprocessing steps are applied consistently in both the training and inference phases, preventing any discrepancies that could lead to unexpected behavior in live trading.

## Future Development

Here are some potential areas for future development and improvement:

*   **Shift Target:** Instead of predicting a simple up/down movement on the next bar, you could modify the target variable to:
    *   Predict price movement several bars into the future (e.g., 3-5 bars ahead).
    *   Require a certain minimum price movement (in pips) to classify a bar as a "1" (positive example).

*   **Additional Indicators:** Incorporate more technical indicators into your dataset and model, such as:
    *   RSI (Relative Strength Index)
    *   MACD (Moving Average Convergence Divergence)
    *   Bollinger Bands
    *   Stochastic Oscillator
    *   Any other indicators relevant to your trading strategy.

*   **Hyperparameter Tuning:** Experiment with different hyperparameters for your LSTM model:
    *   Increase the number of LSTM units or add more layers.
    *   Use advanced callbacks during training (e.g., learning rate scheduling, model checkpoints).
    *   Explore different optimization algorithms.

*   **Socket Integration:** For real-time predictions on every tick (rather than on each new bar), consider using a socket-based communication mechanism between your Python script and the MQL5 EA. This would eliminate the overhead of file I/O but requires more advanced programming.

## Troubleshooting & Common Issues

**1. EA Not Trading:**

*   **AutoTrading Disabled:** Make sure that the "AutoTrading" button in the MetaTrader 5 toolbar is enabled (green).
*   **Daily Drawdown Limit:** If the `DailyDrawdownLimit` has been reached, the EA will not open new trades for the rest of the day.
*   **`UseMLSignal` and `ML_Threshold`:** If `UseMLSignal` is `true` and the probability in `signal.csv` is consistently below `ML_Threshold`, the EA will not place trades. Check the output of `live_prediction.py` and adjust `ML_Threshold` if necessary.

**2. "No Data Found" in Python Scripts:**

*   **Missing or Incorrect File Paths:** Ensure that the CSV files (`mt5_export.csv`, `merged_data.csv`, or others) are in the correct locations and that you are passing the correct file paths to your Python scripts.
*   **Missing Columns:** Verify that your CSV files have the required columns (e.g., `Close15m`, `Vol15m`, or any other columns used as features by your model).

**3. Indicator Errors in MQL5:**

*   **Missing Indicator Files:** Make sure that the `FractalScanner.mq5` and `OrderBlock.mq5` indicator files are compiled and located in the `MQL5/Indicators/` directory.
*   **`iCustom` Errors:** If you see an error like "iCustom invalid handle", double-check the filenames and parameters you are passing to the `iCustom()` function in your EA code. Verify that the indicators are compiled and that you are using the correct indicator names and buffer numbers.

**4. Model or `signal.csv` Not Found:**

*   **Incorrect Paths:** On Windows, the path to the `MQL5/Files/` directory might vary depending on your MetaTrader 5 installation. Check the actual data folder location by going to `File` -> `Open Data Folder` in MT5.
*   **Synchronization:** Ensure that `live_prediction.py` is writing `signal.csv` to the *exact same* `MQL5/Files/` directory that `MyTradingBot` is reading from.

## License & Disclaimer

*   **License:** Refer to the `LICENSE` file in the project's root directory for details on usage, distribution, and modification rights.
*   **Disclaimer:** This software is provided for educational or research purposes only. Trading involves substantial risk of loss and is not suitable for all investors. Past performance is not indicative of future results. Always thoroughly test any trading system on a demo account before using it with real funds.

## Contact

*   **Developer:** Carlos Rodriguez
*   **Email:** carlos.rodriguezacosta@gmail.com
*   **Support:** For assistance, please open an issue on the project's repository (if applicable) or contact the developer directly via email.