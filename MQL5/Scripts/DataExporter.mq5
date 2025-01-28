//+------------------------------------------------------------------+
//| DataExporter.mq5                                                |
//| Script: Exports OHLC data to CSV.                     |
//+------------------------------------------------------------------+
#property script_show_inputs
#property version "1.00"

input string ExportSymbol   = "";
input ENUM_TIMEFRAMES TF    = PERIOD_M15;
input int    BarsToExport   = 1000;
input string FileName       = "mt5_export.csv";

int OnStart()
{
   string symbol = (ExportSymbol=="") ? _Symbol : ExportSymbol;
   ResetLastError();

   int totalBars = Bars(symbol, TF);
   if(totalBars < BarsToExport) BarsToExport = totalBars;

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   if(!CopyRates(symbol, TF, 0, BarsToExport, rates))
   {
      Print("CopyRates failed: ", GetLastError());
      return -1;
   }

   // Create CSV file in MQL5/Files/
   string path = FileName;
   int handle = FileOpen(path, FILE_WRITE|FILE_CSV);
   if(handle==INVALID_HANDLE)
   {
      Print("FileOpen failed: ", GetLastError());
      return -1;
   }

   // Write header
   FileWrite(handle, "Time", "Open", "High", "Low", "Close", "Volume");

   // Write data
   for(int i=ArraySize(rates)-1; i>=0; i--)
   {
      FileWrite(handle,
                TimeToString(rates[i].time, TIME_DATE|TIME_SECONDS),
                DoubleToString(rates[i].open, _Digits),
                DoubleToString(rates[i].high, _Digits),
                DoubleToString(rates[i].low,  _Digits),
                DoubleToString(rates[i].close,_Digits),
                (long)rates[i].tick_volume
                );
   }
   FileClose(handle);
   Print("Exported ", BarsToExport, " bars to ", path);
   return 0;
}