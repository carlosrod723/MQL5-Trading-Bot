//+------------------------------------------------------------------+
//| DataExporter.mq5                                                 |
//| Updated MQL5 Script to export OHLC data to CSV in MQL5/Files       |
//| Version: 1.10                                                    |
//+------------------------------------------------------------------+
#property script_show_inputs
#property version   "1.10"
#property strict

//--- If FILE_APPEND is not defined, define it (its standard value is 0x8000)
#ifndef FILE_APPEND
   #define FILE_APPEND 0x8000
#endif

//--- User Inputs
input string         ExportSymbol   = "";              // If blank, uses _Symbol
input ENUM_TIMEFRAMES TF             = PERIOD_M15;      // Timeframe to export
input int            BarsToExport   = 1000;            // Maximum number of bars to export
input string         FileName       = "mt5_export.csv";  // CSV filename in MQL5/Files folder
input bool           AppendFile     = false;           // If true, appends to an existing file instead of overwriting
enum OrderExport { OLDEST_FIRST, NEWEST_FIRST };
input OrderExport    ExportOrder    = OLDEST_FIRST;    // Order of exported data

//+------------------------------------------------------------------+
//| OnStart()                                                        |
//+------------------------------------------------------------------+
int OnStart()
{
   // Determine symbol to export: if ExportSymbol is empty, use the current chart symbol.
   string symbol = (ExportSymbol == "") ? _Symbol : ExportSymbol;
   
   // Get the total number of available bars for the symbol on the specified timeframe.
   int totalBars = Bars(symbol, TF);
   if(totalBars < 1)
   {
      Print("No bars found for symbol/timeframe: ", symbol, " / ", (int)TF);
      return -1;
   }
   
   // Use a local variable for the effective number of bars to export (inputs are constant)
   int exportBars = BarsToExport;
   if(totalBars < exportBars)
      exportBars = totalBars;
   
   // Prepare rates array and set as series (newest at index 0).
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Copy the OHLC data from the chart.
   if(!CopyRates(symbol, TF, 0, exportBars, rates))
   {
      Print("CopyRates failed, error: ", GetLastError());
      return -1;
   }
   
   // Determine the file open mode:
   // - FILE_WRITE|FILE_CSV creates a new file (overwriting any existing file)
   // - FILE_WRITE|FILE_CSV|FILE_APPEND appends to the file if it exists.
   int fileMode = (AppendFile ? (FILE_WRITE | FILE_CSV | FILE_APPEND) : (FILE_WRITE | FILE_CSV));
   
   // Open the CSV file in the MQL5/Files folder.
   int handle = FileOpen(FileName, fileMode);
   if(handle == INVALID_HANDLE)
   {
      Print("FileOpen failed: ", GetLastError());
      return -1;
   }
   
   // If we are not appending, write the CSV header.
   if(!AppendFile)
      FileWrite(handle, "Time", "Open", "High", "Low", "Close", "Volume");
   
   // Determine the total number of bars copied.
   int ratesCount = ArraySize(rates);
   
   // Export the data in the chosen order.
   if(ExportOrder == OLDEST_FIRST)
   {
      // Loop from the oldest (last index) to the newest (index 0).
      for(int i = ratesCount - 1; i >= 0; i--)
      {
         // Format the time string as "YYYY.MM.DD HH:MM:SS"
         string timeStr = TimeToString(rates[i].time, TIME_DATE | TIME_SECONDS);
         FileWrite(handle,
                   timeStr,
                   DoubleToString(rates[i].open, _Digits),
                   DoubleToString(rates[i].high, _Digits),
                   DoubleToString(rates[i].low, _Digits),
                   DoubleToString(rates[i].close, _Digits),
                   (long)rates[i].tick_volume
                  );
      }
   }
   else // NEWEST_FIRST
   {
      // Loop from the newest (index 0) to the oldest.
      for(int i = 0; i < ratesCount; i++)
      {
         string timeStr = TimeToString(rates[i].time, TIME_DATE | TIME_SECONDS);
         FileWrite(handle,
                   timeStr,
                   DoubleToString(rates[i].open, _Digits),
                   DoubleToString(rates[i].high, _Digits),
                   DoubleToString(rates[i].low, _Digits),
                   DoubleToString(rates[i].close, _Digits),
                   (long)rates[i].tick_volume
                  );
      }
   }
   
   FileClose(handle);
   
   Print("Exported ", exportBars, " bars for symbol ", symbol,
         " (TF=", (int)TF, ") to ", FileName);
   return(0);
}
