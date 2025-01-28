//+------------------------------------------------------------------+
//| FractalScanner.mq5                                              |
//| Indicator to get fractal values at each bar.   |
//| Provides iCustomFractalHigh/Low for EA usage.                    |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2

double upBuffer[];
double downBuffer[];

#define FRAC_RANGE 2 // Checking 2 bars to left/right

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexStyle(0, DRAW_ARROW);
   SetIndexStyle(1, DRAW_ARROW);
   IndicatorShortName("FractalScanner");
   SetIndexBuffer(0, upBuffer);
   SetIndexBuffer(1, downBuffer);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double& price[])
{
   if(rates_total < (FRAC_RANGE*2+1)) return(0);

   int start = prev_calculated-1;
   if(start < FRAC_RANGE) start = FRAC_RANGE;

   for(int i = start; i < rates_total-FRAC_RANGE; i++)
   {
      double val = price[i];
      bool isUpFractal = true;
      bool isDownFractal = true;
      for(int j=1; j<=FRAC_RANGE; j++)
      {
         if(price[i] <= price[i+j] || price[i] <= price[i-j])
            isUpFractal = false;
         if(price[i] >= price[i+j] || price[i] >= price[i-j])
            isDownFractal = false;
      }
      if(isUpFractal)
      {
         upBuffer[i] = price[i];
      }
      else
      {
         upBuffer[i] = 0.0;
      }
      if(isDownFractal)
      {
         downBuffer[i] = price[i];
      }
      else
      {
         downBuffer[i] = 0.0;
      }
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Exposed iCustom calls in EA might do something like:            |
//| double iCustomFractalHigh(...,shift) => get upBuffer[shift]     |
//| double iCustomFractalLow(...,shift)  => get downBuffer[shift]   |
//+------------------------------------------------------------------+
