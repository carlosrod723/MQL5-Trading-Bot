//+------------------------------------------------------------------+
//| MyTradingBot.mq5                                                 |
//| A fully monitored MQL5 EA implementing NFT, FT, SFT and CT setups  |
//| with logic, visual labels and detailed logging.       |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "2.00"
#property strict
#property indicator_plots 0

#include <Trade\Trade.mqh>
CTrade  trade;

//==================================================================
// Input Parameters
//==================================================================
input double RiskPerTrade       = 1.0;         // % risk per trade
input double DailyDrawdownLimit = 5.0;         // Daily loss limit (%)
input bool   UsePartialExit     = false;
input double PartialExitRatio   = 0.5;
input bool   UseTrailingStop    = false;
input double TrailStopPips      = 20.0;
input bool   UseMA              = false;
input bool   UseRSI             = false;
input bool   UseATR             = false;
input bool   UseBollinger       = false;
input bool   UseOrderBlocks     = true;
input double FibEntryLevel      = 0.5;
input int    MagicNumber        = 2025;
input string BaseSymbolParam    = "";
input ENUM_TIMEFRAMES MainTF    = PERIOD_M15;
input ENUM_TIMEFRAMES HigherTF  = PERIOD_H4;
input bool   UseMLSignal        = false;
input double ML_Threshold       = 0.55;

//==================================================================
// Global Variables
//==================================================================
double  CurrentDailyLoss = 0.0;
datetime LastTradeDay;
string  baseSymbolUsed;
int     botState = 0;  // For monitoring bot state

// Global flags for Fibonacci zone (set by EvaluateFibPosition)
bool inPremium = false;
bool inDiscount = false;

//==================================================================
// Color/Style Definitions for Drawing
//==================================================================
#define FRACTAL_UP_COLOR   clrLime
#define FRACTAL_DOWN_COLOR clrRed
#define ORDERBLOCK_COLOR   clrBlue         
#define FIB_HIGH_COLOR     clrBlue
#define FIB_LOW_COLOR      clrRed
#define SWEEP_COLOR        clrYellow

//==================================================================
// Initialization / Deinitialization
//==================================================================
int OnInit()
  {
   // Clear any existing drawings
   ClearAllDrawings();

   // Set symbol: use parameter if provided
   if(BaseSymbolParam=="")
      baseSymbolUsed = _Symbol;
   else
      baseSymbolUsed = BaseSymbolParam;

   LastTradeDay     = TimeCurrent();
   CurrentDailyLoss = 0.0;
   trade.SetExpertMagicNumber(MagicNumber);

   Print("=== BOT INITIALIZATION ===");
   Print("Symbol: ", baseSymbolUsed);
   Print("Magic Number: ", MagicNumber);
   Print("Main Timeframe: ", EnumToString(MainTF));
   Print("Higher Timeframe: ", EnumToString(HigherTF));
   Print("Use ML Signal: ", UseMLSignal);
   Print("Risk Per Trade: ", RiskPerTrade);
   Print("Daily Drawdown Limit: ", DailyDrawdownLimit);
   Print("===========================");

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ClearAllDrawings();
   Print("=== BOT DEINITIALIZATION ===");
   Print("Reason: ", reason);
   Print("============================");
  }

//==================================================================
// Main Tick Function
//==================================================================
void OnTick()
  {
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(baseSymbolUsed, MainTF, 0);
   if(curBarTime == lastBarTime)
     {
      LogBotState("Same bar - skipping");
      return;
     }
   lastBarTime = curBarTime;

   ResetDailyLossIfNewDay();
   if(!CheckDailyDrawdown(DailyDrawdownLimit, CurrentDailyLoss))
     {
      LogBotState("Daily drawdown limit reached");
      return;
     }

   //--- Optional: ML signal check
   if(UseMLSignal)
     {
      LogBotState("Checking ML Signal");
      double mlProb = ReadMLSignal("signal.csv");
      Print("ML Probability: ", mlProb);
      if(mlProb < ML_Threshold)
        {
         LogBotState("ML Signal below threshold");
         return;
        }
     }

   //--- Draw Fibonacci zone (based on higher timeframe candle)
   double fibHigh, fibLow;
   GetFibonacciZone(HigherTF, fibHigh, fibLow);
   DrawFibLevels(fibHigh, fibLow);
   EvaluateFibPosition(fibHigh, fibLow, inPremium, inDiscount);
   Print("Fib Zone Position - Premium: ", inPremium, "  Discount: ", inDiscount);

   //--- Optional order block scan
   bool orderBlockSignal = false;
   if(UseOrderBlocks)
     {
      int obsig = iOrderBlockSignal(baseSymbolUsed, HigherTF, 0);
      if(obsig != 0)
        {
         orderBlockSignal = true;
         double high = iHigh(baseSymbolUsed, HigherTF, 0);
         double low  = iLow(baseSymbolUsed, HigherTF, 0);
         DrawOrderBlock(iTime(baseSymbolUsed, HigherTF, 0), high, low, (obsig > 0));
        }
     }

   //--- Optional indicators
   bool indicatorsOkay = CheckOptionalIndicators();

   //--- Strategy evaluation: try SFT > FT > NFT > CT
   bool tradePlaced = false;
   bool bullish;
   double entryPrice, stopLoss, takeProfit;
   string strategy = "";
   if(CheckSFTSetup(bullish, entryPrice, stopLoss, takeProfit))
     {
      strategy = "SFT";
      if(ValidateRiskReward(entryPrice, stopLoss, takeProfit, 2.0))
        {
         PlaceLimitOrder(bullish, entryPrice, stopLoss, takeProfit, strategy);
         tradePlaced = true;
        }
     }
   else if(CheckFTSetup(bullish, entryPrice, stopLoss, takeProfit))
     {
      strategy = "FT";
      if(ValidateRiskReward(entryPrice, stopLoss, takeProfit, 3.0))
        {
         PlaceLimitOrder(bullish, entryPrice, stopLoss, takeProfit, strategy);
         tradePlaced = true;
        }
     }
   else if(CheckNFTSetup(bullish, entryPrice, stopLoss, takeProfit))
     {
      strategy = "NFT";
      if(ValidateRiskReward(entryPrice, stopLoss, takeProfit, 3.0))
        {
         PlaceLimitOrder(bullish, entryPrice, stopLoss, takeProfit, strategy);
         tradePlaced = true;
        }
     }
   else if(CheckCTSetup(bullish, entryPrice, stopLoss, takeProfit))
     {
      strategy = "CT";
      if(ValidateRiskReward(entryPrice, stopLoss, takeProfit, 3.0))
        {
         PlaceLimitOrder(bullish, entryPrice, stopLoss, takeProfit, strategy);
         tradePlaced = true;
        }
     }
   else
     {
      LogBotState("No strategy conditions met");
     }

   ManageOpenPositions();
   LogMarketConditions();
  }

//==================================================================
// DRAWING FUNCTIONS
//==================================================================
void DrawFractal(datetime time, double price, bool isUp)
  {
   string objName = "Fractal_" + TimeToString(time);
   ObjectDelete(0, objName);
   ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
   if(isUp)
     {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 217);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, FRACTAL_UP_COLOR);
     }
   else
     {
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 218);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, FRACTAL_DOWN_COLOR);
     }
   Print("Drawing Fractal at ", TimeToString(time), " Price: ", price, " Type: ", (isUp ? "Up" : "Down"));
  }

void DrawFibLevels(double high, double low)
  {
   string objPrefix = "Fib_Level_";
   datetime time = TimeCurrent();
   ObjectDelete(0, objPrefix + "High");
   ObjectDelete(0, objPrefix + "Low");
   ObjectDelete(0, objPrefix + "Mid");
   ObjectCreate(0, objPrefix + "High", OBJ_HLINE, 0, time, high);
   ObjectCreate(0, objPrefix + "Low", OBJ_HLINE, 0, time, low);
   double midLevel = low + ((high - low) * FibEntryLevel);
   ObjectCreate(0, objPrefix + "Mid", OBJ_HLINE, 0, time, midLevel);
   ObjectSetInteger(0, objPrefix + "High", OBJPROP_COLOR, FIB_HIGH_COLOR);
   ObjectSetInteger(0, objPrefix + "Low", OBJPROP_COLOR, FIB_LOW_COLOR);
   ObjectSetInteger(0, objPrefix + "Mid", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, objPrefix + "Mid", OBJPROP_STYLE, STYLE_DOT);
   Print("Drawing Fib Levels - High: ", high, " Low: ", low, " Mid: ", midLevel);
  }

void DrawOrderBlock(datetime time, double high, double low, bool isBullish)
  {
   string objName = "OB_" + TimeToString(time);
   ObjectDelete(0, objName);
   // Draw a rectangle covering 4 bars of the main timeframe
   ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, high, time + PeriodSeconds(MainTF) * 4, low);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, ORDERBLOCK_COLOR);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   Print("Drawing OrderBlock at ", TimeToString(time), " High: ", high, " Low: ", low, " Type: ", (isBullish ? "Bullish" : "Bearish"));
  }

void DrawTradeLabel(string strategy, bool bullish, double price)
  {
   string label = "Trade_" + strategy + "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
   ObjectCreate(0, label, OBJ_TEXT, 0, TimeCurrent(), price);
   ObjectSetString(0, label, OBJPROP_TEXT, strategy);
   if(strategy == "CT")
      ObjectSetInteger(0, label, OBJPROP_COLOR, clrOrange);
   else if(bullish)
      ObjectSetInteger(0, label, OBJPROP_COLOR, clrGreen);
   else
      ObjectSetInteger(0, label, OBJPROP_COLOR, clrRed);
  }

void ClearAllDrawings()
  {
   ObjectsDeleteAll(0, "Fractal_");
   ObjectsDeleteAll(0, "Fib_Level_");
   ObjectsDeleteAll(0, "OB_");
   Print("Cleared all drawings");
  }

//==================================================================
// LOGGING FUNCTIONS
//==================================================================
void LogBotState(string state)
  {
   static string lastState = "";
   if(state != lastState)
     {
      Print("Bot State: ", state);
      lastState = state;
     }
  }

void LogMarketConditions()
  {
   Print("=== Market Conditions ===");
   Print("Symbol: ", baseSymbolUsed);
   Print("Current Price: ", SymbolInfoDouble(baseSymbolUsed, SYMBOL_BID));
   Print("Daily Loss: ", CurrentDailyLoss);
   Print("Last Trade Day: ", TimeToString(LastTradeDay));
   Print("=========================");
  }

//==================================================================
// DAILY DRAWDOWN & HISTORY FUNCTIONS
//==================================================================
void ResetDailyLossIfNewDay()
  {
   datetime now = TimeCurrent();
   MqlDateTime dtNow, dtLast;
   TimeToStruct(now, dtNow);
   TimeToStruct(LastTradeDay, dtLast);
   if(dtNow.day != dtLast.day)
     {
      Print("=== NEW TRADING DAY ===");
      Print("Previous Loss: ", CurrentDailyLoss);
      LastTradeDay = now;
      CurrentDailyLoss = 0.0;
      Print("Reset Daily Loss to 0");
      Print("=======================");
     }
  }

bool CheckDailyDrawdown(double limit, double currentLoss)
  {
   // Return true if loss is below limit
   return (currentLoss < limit);
  }

void UpdateCurrentDailyLoss()
  {
   datetime dayStart = iTime(baseSymbolUsed, PERIOD_D1, 0);
   Print("=== UPDATING DAILY P/L ===");
   Print("Day Start: ", TimeToString(dayStart));
   if(!HistorySelect(dayStart, TimeCurrent()))
     {
      Print("History Select Failed - Error: ", GetLastError());
      return;
     }
   double dailyProfit = 0.0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != baseSymbolUsed)
         continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber)
         continue;
      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(dealTime < dayStart)
         continue;
      double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double dealSwap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double dealCommission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      Print("Deal #", ticket, " Profit: ", dealProfit, " Swap: ", dealSwap, " Commission: ", dealCommission);
      dailyProfit += dealProfit + dealSwap + dealCommission;
     }
   Print("Total Daily Profit: ", dailyProfit);
   if(dailyProfit < 0.0)
      CurrentDailyLoss = MathAbs(dailyProfit);
   else
      CurrentDailyLoss = 0.0;
   Print("Current Daily Loss: ", CurrentDailyLoss);
   Print("=======================");
  }

//==================================================================
// ML SIGNAL READER
//==================================================================
double ReadMLSignal(string filename)
  {
   Print("=== READING ML SIGNAL ===");
   Print("File: ", filename);
   int handle = FileOpen(filename, FILE_READ | FILE_CSV);
   if(handle == INVALID_HANDLE)
     {
      Print("Failed to open ML signal file - Error: ", GetLastError());
      return 0.0;
     }
   double prob = 0.0;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(line != "")
        {
         prob = StringToDouble(line);
         Print("Read probability: ", prob);
        }
     }
   FileClose(handle);
   Print("Final ML Probability: ", prob);
   Print("=======================");
   return prob;
  }

//==================================================================
// OPTIONAL INDICATORS & ORDER BLOCK (Dummy Implementations)
//==================================================================
bool CheckOptionalIndicators()
  {
   return true;
  }

int iOrderBlockSignal(string symbol, ENUM_TIMEFRAMES tf, int shift)
  {
   // If the candle at index (shift+1) has a long wick,
   // return 1 for bullish or -1 for bearish order block.
   int index = shift + 1;
   double openC = iOpen(symbol, tf, index);
   double closeC = iClose(symbol, tf, index);
   double highC = iHigh(symbol, tf, index);
   double lowC  = iLow(symbol, tf, index);
   double body = MathAbs(openC - closeC);
   double upperWick = highC - MathMax(openC, closeC);
   double lowerWick = MathMin(openC, closeC) - lowC;
   if(closeC > openC && lowerWick > body)
      return 1;
   if(closeC < openC && upperWick > body)
      return -1;
   return 0;
  }

//==================================================================
// FIBONACCI ZONE & FIB POSITION FUNCTIONS
//==================================================================
void GetFibonacciZone(ENUM_TIMEFRAMES tf, double &fibHigh, double &fibLow)
  {
   // Use the last complete candle on the higher timeframe
   int shift = 1;
   fibHigh = iHigh(baseSymbolUsed, tf, shift);
   fibLow  = iLow(baseSymbolUsed, tf, shift);
  }

void EvaluateFibPosition(double fibHigh, double fibLow, bool &fibInPremium, bool &fibInDiscount)
  {
   double midLevel = fibLow + ((fibHigh - fibLow) * FibEntryLevel);
   double currentPrice = SymbolInfoDouble(baseSymbolUsed, SYMBOL_BID);
   if(currentPrice >= midLevel)
     {
      fibInPremium  = true;
      fibInDiscount = false;
     }
   else
     {
      fibInPremium  = false;
      fibInDiscount = true;
     }
  }

//==================================================================
// TRADE SETUPS: NFT, FT, SFT, CT
//==================================================================

//--- No Follow-Through (NFT) Setup
bool CheckNFTSetup(bool &bullish, double &entryPrice, double &stopLoss, double &takeProfit)
  {
   int index1 = 1; // last closed candle
   int index2 = 2; // previous candle
   double open1  = iOpen(baseSymbolUsed, MainTF, index1);
   double close1 = iClose(baseSymbolUsed, MainTF, index1);
   double high1  = iHigh(baseSymbolUsed, MainTF, index1);
   double low1   = iLow(baseSymbolUsed, MainTF, index1);

   double open2  = iOpen(baseSymbolUsed, MainTF, index2);
   double close2 = iClose(baseSymbolUsed, MainTF, index2);
   double high2  = iHigh(baseSymbolUsed, MainTF, index2);
   double low2   = iLow(baseSymbolUsed, MainTF, index2);

   double body2 = MathAbs(open2 - close2);
   double upperWick2 = high2 - MathMax(open2, close2);
   double lowerWick2 = MathMin(open2, close2) - low2;

   // For bullish NFT: previous candle is bearish with a long lower wick, followed by a bullish candle.
   if(open2 > close2 && lowerWick2 > body2)
     {
      if(close1 > open1)
        {
         bullish = true;
         entryPrice = close1;
         double buffer = GetStopLossBuffer(baseSymbolUsed, "NFT");
         stopLoss = low2 - buffer * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
         takeProfit = entryPrice + (entryPrice - stopLoss) * 3;
         if(!inDiscount) return false;
         if(!IsKillZone()) return false;
         return true;
        }
     }
   // For bearish NFT: previous candle is bullish with a long upper wick, followed by a bearish candle.
   if(open2 < close2 && upperWick2 > body2)
     {
      if(close1 < open1)
        {
         bullish = false;
         entryPrice = close1;
         double buffer = GetStopLossBuffer(baseSymbolUsed, "NFT");
         stopLoss = high2 + buffer * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
         takeProfit = entryPrice - (stopLoss - entryPrice) * 3;
         if(!inPremium) return false;
         if(!IsKillZone()) return false;
         return true;
        }
     }
   return false;
  }

//--- Follow-Through (FT) Setup
bool CheckFTSetup(bool &bullish, double &entryPrice, double &stopLoss, double &takeProfit)
  {
   int index1 = 1;
   int index2 = 2;
   double close1 = iClose(baseSymbolUsed, MainTF, index1);
   double close2 = iClose(baseSymbolUsed, MainTF, index2);
   // Define a previous range from candles 3 and 4
   double prevHigh = MathMax(iHigh(baseSymbolUsed, MainTF, 3), iHigh(baseSymbolUsed, MainTF, 4));
   double prevLow  = MathMin(iLow(baseSymbolUsed, MainTF, 3), iLow(baseSymbolUsed, MainTF, 4));
   // Bullish FT: both candles close above the previous high.
   if(close1 > prevHigh && close2 > prevHigh)
     {
      bullish = true;
      entryPrice = close1;
      double fractalLow = CustomFractalLow(baseSymbolUsed, MainTF, index2);
      if(fractalLow <= 0) fractalLow = iLow(baseSymbolUsed, MainTF, index2);
      stopLoss = fractalLow - GetStopLossBuffer(baseSymbolUsed, "FT") * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      takeProfit = entryPrice + (entryPrice - stopLoss) * 3;
      if(!inDiscount) return false;
      if(!IsKillZone()) return false;
      return true;
     }
   // Bearish FT: both candles close below the previous low.
   if(close1 < prevLow && close2 < prevLow)
     {
      bullish = false;
      entryPrice = close1;
      double fractalHigh = CustomFractalHigh(baseSymbolUsed, MainTF, index2);
      if(fractalHigh <= 0) fractalHigh = iHigh(baseSymbolUsed, MainTF, index2);
      stopLoss = fractalHigh + GetStopLossBuffer(baseSymbolUsed, "FT") * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      takeProfit = entryPrice - (stopLoss - entryPrice) * 3;
      if(!inPremium) return false;
      if(!IsKillZone()) return false;
      return true;
     }
   return false;
  }

//--- Strong Follow-Through (SFT) Setup
bool CheckSFTSetup(bool &bullish, double &entryPrice, double &stopLoss, double &takeProfit)
  {
   int index1 = 1;
   int index2 = 2;
   double open1  = iOpen(baseSymbolUsed, MainTF, index1);
   double close1 = iClose(baseSymbolUsed, MainTF, index1);
   double open2  = iOpen(baseSymbolUsed, MainTF, index2);
   double close2 = iClose(baseSymbolUsed, MainTF, index2);
   // Both candles must be in the same direction.
   if(close1 > open1 && close2 > open2)
     {
      bullish = true;
      double range1 = iHigh(baseSymbolUsed, MainTF, index1) - iLow(baseSymbolUsed, MainTF, index1);
      double range2 = iHigh(baseSymbolUsed, MainTF, index2) - iLow(baseSymbolUsed, MainTF, index2);
      double avgRange = 0;
      int cnt = 10;
      for(int i = 1; i <= cnt; i++)
         avgRange += (iHigh(baseSymbolUsed, MainTF, i) - iLow(baseSymbolUsed, MainTF, i));
      avgRange /= cnt;
      if(range1 < 1.5 * avgRange && range2 < 1.5 * avgRange) return false;
      // Confirm liquidity grab by checking a sweep in an older candle.
      double dummy;
      bool dummyBool;
      if(!DetectFractalSweep(baseSymbolUsed, MainTF, dummy, dummyBool)) return false;
      if(!IsKillZone()) return false;
      entryPrice = close1;
      double fractalLow = CustomFractalLow(baseSymbolUsed, MainTF, index2);
      if(fractalLow <= 0) fractalLow = iLow(baseSymbolUsed, MainTF, index2);
      double minStop = 10 * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      double calcStop = fractalLow - GetStopLossBuffer(baseSymbolUsed, "SFT") * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      stopLoss = ((entryPrice - calcStop) < minStop) ? entryPrice - minStop : calcStop;
      takeProfit = entryPrice + (entryPrice - stopLoss) * 2;
      return true;
     }
   if(close1 < open1 && close2 < open2)
     {
      bullish = false;
      double range1 = iHigh(baseSymbolUsed, MainTF, index1) - iLow(baseSymbolUsed, MainTF, index1);
      double range2 = iHigh(baseSymbolUsed, MainTF, index2) - iLow(baseSymbolUsed, MainTF, index2);
      double avgRange = 0;
      int cnt = 10;
      for(int i = 1; i <= cnt; i++)
         avgRange += (iHigh(baseSymbolUsed, MainTF, i) - iLow(baseSymbolUsed, MainTF, i));
      avgRange /= cnt;
      if(range1 < 1.5 * avgRange && range2 < 1.5 * avgRange) return false;
      double dummy;
      bool dummyBool;
      if(!DetectFractalSweep(baseSymbolUsed, MainTF, dummy, dummyBool)) return false;
      if(!IsKillZone()) return false;
      entryPrice = close1;
      double fractalHigh = CustomFractalHigh(baseSymbolUsed, MainTF, index2);
      if(fractalHigh <= 0) fractalHigh = iHigh(baseSymbolUsed, MainTF, index2);
      double minStop = 10 * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      double calcStop = fractalHigh + GetStopLossBuffer(baseSymbolUsed, "SFT") * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      stopLoss = ((calcStop - entryPrice) < minStop) ? entryPrice + minStop : calcStop;
      takeProfit = entryPrice - (stopLoss - entryPrice) * 2;
      return true;
     }
   return false;
  }

//--- Counter-Trend (CT) Setup
bool CheckCTSetup(bool &bullish, double &entryPrice, double &stopLoss, double &takeProfit)
  {
   int index1 = 1;
   int index2 = 2;
   double low1 = iLow(baseSymbolUsed, MainTF, index1);
   double low2 = iLow(baseSymbolUsed, MainTF, index2);
   if(inPremium && (low1 < low2))
     {
      bullish = false;
      entryPrice = iClose(baseSymbolUsed, MainTF, index1);
      double recentHigh = iHigh(baseSymbolUsed, MainTF, index1);
      stopLoss = recentHigh + GetStopLossBuffer(baseSymbolUsed, "CT") * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      takeProfit = entryPrice - (stopLoss - entryPrice) * 3;
      if(!IsKillZone()) return false;
      return true;
     }
   double high1 = iHigh(baseSymbolUsed, MainTF, index1);
   double high2 = iHigh(baseSymbolUsed, MainTF, index2);
   if(inDiscount && (high1 > high2))
     {
      bullish = true;
      entryPrice = iClose(baseSymbolUsed, MainTF, index1);
      double recentLow = iLow(baseSymbolUsed, MainTF, index1);
      stopLoss = recentLow - GetStopLossBuffer(baseSymbolUsed, "CT") * SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
      takeProfit = entryPrice + (entryPrice - stopLoss) * 3;
      if(!IsKillZone()) return false;
      return true;
     }
   return false;
  }

//==================================================================
// RISK/REWARD & TRADE ORDER FUNCTIONS
//==================================================================
bool ValidateRiskReward(double entry, double stopLoss, double takeProfit, double minRatio)
  {
   double risk = MathAbs(entry - stopLoss);
   double reward = MathAbs(takeProfit - entry);
   if(risk == 0) return false;
   double ratio = reward / risk;
   if(ratio < minRatio)
     {
      Print("Risk Reward Ratio insufficient: ", ratio, " (min required: ", minRatio, ")");
      return false;
     }
   return true;
  }

void PlaceLimitOrder(bool bullish, double entryPrice, double stopLoss, double takeProfit, string strategy)
  {
   Print("=== PLACING ", strategy, " LIMIT ORDER ===");
   double pointSize = SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
   ENUM_ORDER_TYPE orderType = bullish ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   string comment = strategy + (bullish ? "BuyLimit" : "SellLimit");
   double lots = CalculatePositionSize(RiskPerTrade, stopLoss, entryPrice, baseSymbolUsed);
   trade.SetDeviationInPoints(10);
   bool result = trade.OrderOpen(
      baseSymbolUsed, 
      orderType, 
      lots,
      NormalizeDouble(entryPrice, _Digits),
      NormalizeDouble(stopLoss, _Digits), 
      NormalizeDouble(takeProfit, _Digits), 
      comment
   );
   
   if(!result)
     {
      Print("Order FAILED - Error: ", GetLastError());
      Print("Error Description: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
     }
   else
     {
      Print("Order placed successfully with strategy ", strategy);
      Print("Ticket: ", trade.ResultOrder());
     }
   DrawTradeLabel(strategy, bullish, entryPrice);
  }

double CalculatePositionSize(double riskPercent, double stopLoss, double entryPrice, string symbol)
  {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double pointValue  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   // Approximate pip value (assumes 5-digit quotes)
   double pipValue = pointValue * 10;
   double riskPips = MathAbs(entryPrice - stopLoss) / SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(riskPips == 0) return 0;
   double lots = riskAmount / (riskPips * pipValue);
   return NormalizeDouble(lots, 2);
  }

bool ModifySL(double newSL)
  {
   // Modify SL on the first matching position
   if(PositionsTotal() <= 0) return false;
   ulong ticket = PositionGetTicket(0);
   if(!PositionSelectByTicket(ticket))
     {
      Print("Failed to select position for SL modification");
      return false;
     }
   bool res = trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
   if(!res)
      Print("Failed to modify SL - Error: ", GetLastError());
   return res;
  }

bool CheckPartialExit(long posType, double openPrice, double sl, double tp)
  {
   double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(baseSymbolUsed, SYMBOL_BID) : SymbolInfoDouble(baseSymbolUsed, SYMBOL_ASK);
   double pips = MathAbs(currentPrice - openPrice) / SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
   return (pips > 50);
  }

void ClosePartialPosition(string symbol, double volume)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetDouble(POSITION_VOLUME) >= volume)
           {
            if(!trade.PositionClosePartial(ticket, volume))
               Print("Partial close failed for ticket ", ticket);
            else
               Print("Partial close executed for ticket ", ticket);
           }
        }
     }
  }

//==================================================================
// TRADE MANAGEMENT
//==================================================================
void ManageOpenPositions()
  {
   Print("=== MANAGING POSITIONS ===");
   int totalPositions = PositionsTotal();
   Print("Total Open Positions: ", totalPositions);
   for(int i = totalPositions - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
        {
         Print("Failed to get ticket - Error: ", GetLastError());
         continue;
        }
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
           {
            Print("Skipping position - different magic number");
            continue;
           }
         if(PositionGetString(POSITION_SYMBOL) != baseSymbolUsed)
           {
            Print("Skipping position - different symbol");
            continue;
           }
         long posType = PositionGetInteger(POSITION_TYPE);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         Print("Managing Position #", ticket);
         Print("Type: ", EnumToString((ENUM_POSITION_TYPE)posType));
         Print("Volume: ", vol);
         Print("Open Price: ", openPrice);
         Print("Current SL: ", sl);
         Print("Current TP: ", tp);
         if(UseTrailingStop)
           {
            Print("Checking Trailing Stop...");
            ApplyTrailingStop(posType, openPrice, sl, TrailStopPips);
           }
         if(UsePartialExit)
           {
            Print("Checking Partial Exit...");
            bool exitCond = CheckPartialExit(posType, openPrice, sl, tp);
            if(exitCond)
              {
               double partialVol = vol * PartialExitRatio;
               Print("Partial Exit Condition Met - Closing ", partialVol, " lots");
               ClosePartialPosition(baseSymbolUsed, partialVol);
              }
           }
        }
     }
   UpdateCurrentDailyLoss();
   Print("Current Daily Loss: ", CurrentDailyLoss);
   Print("========================");
  }

void ApplyTrailingStop(long posType, double openPrice, double currSL, double trailPips)
  {
   double pointSize = SymbolInfoDouble(baseSymbolUsed, SYMBOL_POINT);
   double cPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(baseSymbolUsed, SYMBOL_BID) : SymbolInfoDouble(baseSymbolUsed, SYMBOL_ASK);
   Print("Trailing Stop Check: Current Price: ", cPrice, " Current SL: ", currSL, " Trail Points: ", trailPips);
   double newSL;
   if(posType == POSITION_TYPE_BUY)
     {
      newSL = cPrice - (trailPips * pointSize);
      if(newSL > currSL && newSL < cPrice)
        {
         Print("Moving Buy Stop Loss to: ", newSL);
         ModifySL(newSL);
        }
     }
   else
     {
      newSL = cPrice + (trailPips * pointSize);
      if(newSL < currSL && newSL > cPrice)
        {
         Print("Moving Sell Stop Loss to: ", newSL);
         ModifySL(newSL);
        }
     }
  }

//==================================================================
// UTILITY FUNCTIONS
//==================================================================

// Simple Kill Zone check: returns true if current hour is within London (8-10 GMT)
// or New York (13-15 GMT) sessions.
bool IsKillZone()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   if((dt.hour >= 8 && dt.hour < 10) || (dt.hour >= 13 && dt.hour < 15))
      return true;
   return false;
  }

// Returns stop loss buffer (in pips) based on symbol and strategy.
double GetStopLossBuffer(string symbol, string strategy)
  {
   if(StringFind(symbol, "EUR") != -1)
      return 2;
   if(StringFind(symbol, "GBP") != -1)
      return 3.5;
   if(StringFind(symbol, "USDCHF") != -1)
      return 2;
   return 2; // default
  }

// Basic fractal functions: a candle is a fractal high if its high is greater than
// the highs of the 2 candles before and after.
double CustomFractalHigh(string symbol, ENUM_TIMEFRAMES tf, int shift)
  {
   double currentHigh = iHigh(symbol, tf, shift);
   if(iHigh(symbol, tf, shift + 1) > currentHigh || iHigh(symbol, tf, shift + 2) > currentHigh ||
      iHigh(symbol, tf, shift - 1) > currentHigh || iHigh(symbol, tf, shift - 2) > currentHigh)
      return 0;
   return currentHigh;
  }

double CustomFractalLow(string symbol, ENUM_TIMEFRAMES tf, int shift)
  {
   double currentLow = iLow(symbol, tf, shift);
   if(iLow(symbol, tf, shift + 1) < currentLow || iLow(symbol, tf, shift + 2) < currentLow ||
      iLow(symbol, tf, shift - 1) < currentLow || iLow(symbol, tf, shift - 2) < currentLow)
      return 0;
   return currentLow;
  }

// Detect a simple fractal sweep. Returns true if either a bullish or bearish sweep is found.
bool DetectFractalSweep(string symbol, ENUM_TIMEFRAMES tf, double &sweepPrice, bool &isBullish)
  {
   double upFrac = CustomFractalHigh(symbol, tf, 1);
   double downFrac = CustomFractalLow(symbol, tf, 1);
   if(upFrac > 0)
      DrawFractal(iTime(symbol, tf, 1), upFrac, true);
   if(downFrac > 0)
      DrawFractal(iTime(symbol, tf, 1), downFrac, false);
   double lastClose = iClose(symbol, tf, 1);
   double prevClose = iClose(symbol, tf, 2);
   Print("Analyzing Sweep - UpFrac:", upFrac, " DownFrac:", downFrac,
         " LastClose:", lastClose, " PrevClose:", prevClose);
   if(downFrac > 0 && lastClose > downFrac && prevClose > downFrac)
     {
      sweepPrice = downFrac;
      isBullish = true;
      return true;
     }
   if(upFrac > 0 && lastClose < upFrac && prevClose < upFrac)
     {
      sweepPrice = upFrac;
      isBullish = false;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
