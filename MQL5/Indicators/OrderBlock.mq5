//+------------------------------------------------------------------+
//| OrderBlock.mq5                                                  |
//| Indicator for detecting supply/demand zones.  |
//| iOrderBlockSignal() returns 1 for bullish zone, -1 for bearish.  |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1

double obBuffer[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, obBuffer);
   IndicatorShortName("OrderBlockDetector");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double& price[])
{
   // If the last candle is a large bullish candle
   // preceded by a small consolidation, mark a demand block = 1
   // If large bearish, mark supply block = -1
   // Otherwise 0. 

   int start = MathMax(prev_calculated-1, 1);
   for(int i=start; i<rates_total; i++)
   {
      double body = MathAbs( Close[i] - Open[i] );
      double priorBody = MathAbs( Close[i+1] - Open[i+1] );

      if(body > (priorBody * 2.0) && Close[i] > Open[i])
         obBuffer[i] = 1;    // bullish block
      else if(body > (priorBody * 2.0) && Close[i] < Open[i])
         obBuffer[i] = -1;   // bearish block
      else
         obBuffer[i] = 0;
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Exposed function for EA: iOrderBlockSignal(symbol,tf,shift)     |
//+------------------------------------------------------------------+
