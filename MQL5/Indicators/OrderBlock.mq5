//+------------------------------------------------------------------+
//| OrderBlock.mq5                                                   |
//| Updated MQL5 indicator for detecting supply/demand zones         |
//| Writes 1 for bullish block, -1 for bearish, else 0 in obBuffer[].  |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property strict

//--- User Inputs
input double Multiplier          = 2.0;   // Multiplier for candle body comparison (current vs. next candle)
input bool   UseAdditionalFilter = true;  // Use an extra filter based on recent average candle body size?
input int    AvgPeriod           = 10;    // Number of bars for average body size calculation
input double MinRangeFactor      = 1.5;   // Current candle body must exceed (average body * this factor)

//--- Global buffer for order block signals
double obBuffer[];

//+------------------------------------------------------------------+
//| OnInit()                                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Optionally, you can set the indicator's short name here.
   // IndicatorShortName("OrderBlockDetector (Updated MQL5)");
   
   // Bind obBuffer[] to buffer 0 as indicator data.
   SetIndexBuffer(0, obBuffer, INDICATOR_DATA);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnCalculate()                                                    |
//| Processes each bar to determine if an order block condition is     |
//| met. Returns 1.0 for bullish blocks, -1.0 for bearish blocks, and     |
//| 0.0 otherwise.                                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // Ensure there are enough bars for average calculation and for a "next" candle
   if(rates_total < AvgPeriod + 2)
      return(0);
      
   // Re-calculate starting index to handle boundary changes
   int start = MathMax(prev_calculated - 1, 1);
   
   // Loop through each bar from 'start' to the last bar
   for(int i = start; i < rates_total; i++)
     {
      // Calculate the current candle's body size
      double currentBody = MathAbs(close[i] - open[i]);
      
      // Calculate the average body size over the previous AvgPeriod bars (if enabled)
      double avgBody = 0.0;
      if(UseAdditionalFilter)
        {
         int count = 0;
         for(int j = i - AvgPeriod; j < i && j >= 0; j++)
           {
            avgBody += MathAbs(close[j] - open[j]);
            count++;
           }
         if(count > 0)
            avgBody /= count;
        }
      
      // Get the next candle's body size (if available)
      double nextBody = 0.0;
      if(i + 1 < rates_total)
         nextBody = MathAbs(close[i + 1] - open[i + 1]);
      
      // Initialize signal to 0 (no order block)
      double signal = 0.0;
      
      // Only check if the next candle exists and its body is nonzero
      if(nextBody > 0)
        {
         // Primary condition: current candle's body must be larger than next candle's body times Multiplier
         bool conditionPrimary = (currentBody > (nextBody * Multiplier));
         
         // Additional filter: current candle's body must exceed the average body * MinRangeFactor (if enabled)
         bool conditionAdditional = true;
         if(UseAdditionalFilter)
            conditionAdditional = (currentBody > (avgBody * MinRangeFactor));
         
         // If both conditions are met, assign a bullish (1.0) or bearish (-1.0) signal
         if(conditionPrimary && conditionAdditional)
           {
            if(close[i] > open[i])
               signal = 1.0;   // Bullish order block (demand zone)
            else if(close[i] < open[i])
               signal = -1.0;  // Bearish order block (supply zone)
           }
        }
      
      // Store the calculated signal in the buffer for bar i
      obBuffer[i] = signal;
     }
   
   // Return the total number of bars processed
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Usage in EA:                                                   |
//|   double obValue = iCustom(_Symbol, PERIOD_CURRENT,              |
//|                            "OrderBlock", 0, shift);             |
//|   // obValue returns -1, 0, or 1 depending on the detected block   |
//+------------------------------------------------------------------+
