//+------------------------------------------------------------------+
//| FractalScanner.mq5                                               |
//| MQL5 indicator that detects basic fractals with         |
//| configurable parameters for range and display.                   |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.01"
#property strict

//--- Indicator settings
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

//--- User Inputs
input int   FractalRange  = 2;      // Number of bars to the left/right to check for fractal confirmation
input int   UpArrowCode   = 233;    // Arrow code for up fractals (customizable)
input int   DownArrowCode = 234;    // Arrow code for down fractals (customizable)
input color UpColor       = clrLime;  // Color for up fractal arrows
input color DownColor     = clrRed;   // Color for down fractal arrows

//--- Indicator buffers
double upBuffer[];
double downBuffer[];

//+------------------------------------------------------------------+
//| OnInit()                                                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Configure plot 0 for up fractals
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, UpColor);      // Use PLOT_LINE_COLOR in MQL5
   PlotIndexSetInteger(0, PLOT_ARROW, UpArrowCode);

   //--- Configure plot 1 for down fractals
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_ARROW);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, DownColor);
   PlotIndexSetInteger(1, PLOT_ARROW, DownArrowCode);

   //--- Bind our arrays to indicator buffers
   SetIndexBuffer(0, upBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, downBuffer, INDICATOR_DATA);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnCalculate() - called whenever the indicator is recalculated    |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   // Need at least FractalRange*2+1 bars to form a fractal
   if(rates_total < (FractalRange * 2 + 1))
      return(0);

   // Start from prev_calculated-1 to recheck the boundary bar
   int start = prev_calculated - 1;
   if(start < FractalRange)
      start = FractalRange;

   // Loop through bars and detect fractals
   for(int i = start; i < rates_total - FractalRange; i++)
     {
      double val = price[i];
      bool isUpFractal = true;
      bool isDownFractal = true;

      // Check FractalRange bars on both sides
      for(int j = 1; j <= FractalRange; j++)
        {
         // For an up fractal: current bar must be greater than both adjacent bars.
         if(val <= price[i + j] || val <= price[i - j])
            isUpFractal = false;
         // For a down fractal: current bar must be less than both adjacent bars.
         if(val >= price[i + j] || val >= price[i - j])
            isDownFractal = false;
        }

      // Store the value if a fractal condition is met; otherwise, store 0.
      upBuffer[i]   = isUpFractal   ? val : 0.0;
      downBuffer[i] = isDownFractal ? val : 0.0;
     }

   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Usage in EA:                                                   |
//|   double upVal   = iCustom(_Symbol, PERIOD_CURRENT,              |
//|                             "FractalScanner", 0, shift);        |
//|   double downVal = iCustom(_Symbol, PERIOD_CURRENT,              |
//|                             "FractalScanner", 1, shift);        |
//+------------------------------------------------------------------+
