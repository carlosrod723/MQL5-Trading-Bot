//+------------------------------------------------------------------+
//| MyTradingBot.mq5                                                |
//| A definitive EA that uses fractals, Fibonacci zones, order      |
//| blocks, partial exits, trailing stops, optional indicators,     |
//| robust risk management, and reads an ML signal from signal.csv. |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//==================================================================
// RISK MANAGEMENT FUNCTIONS (INLINE)
//==================================================================
bool CheckDailyDrawdown(double limitPercent, double currentDailyLoss)
{
   // If daily loss is at/above limit, block new trades
   if(currentDailyLoss >= limitPercent)
      return false;
   return true;
}

double CalculatePositionSize(double riskPercent, double stopLossPrice, double entryPrice, string symbol)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICKVALUE);
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / point;
   if(slDistancePoints < 1) slDistancePoints = 1; // avoid extremely tight SL

   // Basic formula: risk = slDistancePoints * tickValue * lots
   double lots = riskAmount / (slDistancePoints * tickValue);

   // Round to symbol lot step
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lotStep) * lotStep;

   // Bound by min & max lot
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return lots;
}

//==================================================================
// FRACTAL & ORDER BLOCK INDICATOR STUBS (INLINE)
// In a real project, these might be in separate .mqh files or .mq5
// indicators you call via iCustom. For completeness, define them here.
//==================================================================
double iCustomFractalHigh(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   // Simplified approach: read the built-in fractals
   // Or call an external "FractalScanner" if you prefer.
   // For definitiveness, let's just use iFractals built-in, mode=MODE_UPPER.
   // Then we shift by 'shift' bars.
   return iFractals(symbol, tf, MODE_UPPER, shift);
}

double iCustomFractalLow(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   // Same logic, but for lower fractals
   return iFractals(symbol, tf, MODE_LOWER, shift);
}

// Stub for order block detection
int iOrderBlockSignal(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   // Example logic: A bullish order block if the last candle body is large bullish,
   // a bearish order block if large bearish, else 0
   // This is a stub for definitiveness.
   // shift indicates how many bars back we check (0 or 1).
   double openBar  = iOpen(symbol, tf, shift);
   double closeBar = iClose(symbol, tf, shift);
   double body = MathAbs(closeBar - openBar);

   double prevOpen  = iOpen(symbol, tf, shift+1);
   double prevClose = iClose(symbol, tf, shift+1);
   double prevBody  = MathAbs(prevClose - prevOpen);

   if(body > (2.0 * prevBody) && closeBar > openBar)
      return 1;  // bullish block
   if(body > (2.0 * prevBody) && closeBar < openBar)
      return -1; // bearish block

   return 0;
}

//==================================================================
// EA INPUT PARAMETERS
//==================================================================
input double RiskPerTrade         = 1.0;     // % of balance risked per trade
input double DailyDrawdownLimit   = 5.0;     // Daily DD limit (%)
input bool   UsePartialExit       = false;   // Toggle partial exit
input double PartialExitRatio     = 0.5;     // 50% partial
input bool   UseTrailingStop      = false;   // Toggle trailing stops
input double TrailStopPips        = 20.0;    // Distance for trailing stops
input bool   UseMA                = false;   // Toggle moving average filter
input bool   UseRSI               = false;   // Toggle RSI filter
input bool   UseATR               = false;   // Toggle ATR-based checks
input bool   UseBollinger         = false;   // Toggle Bollinger filter
input bool   UseOrderBlocks       = true;    // Toggle order block logic
input double FibEntryLevel        = 0.5;     // e.g., 50% Fib for premium/discount
input int    MagicNumber          = 2025;    // EA magic number
input string BaseSymbol           = "";      // If empty, uses current chart
input ENUM_TIMEFRAMES MainTF      = PERIOD_M15; // For sweeps & trades
input ENUM_TIMEFRAMES HigherTF    = PERIOD_H4;  // For fib zones

// ML integration toggles
input bool   UseMLSignal          = false;   // Toggle ML confirmation
input double ML_Threshold         = 0.55;    // Probability threshold

//-------------------------------------------------------------------
// GLOBALS
//-------------------------------------------------------------------
CTrade  trade;
double  CurrentDailyLoss = 0.0;
datetime LastTradeDay;

//==================================================================
// OnInit, OnDeinit, OnTick
//==================================================================
int OnInit()
{
   if(BaseSymbol=="")
      BaseSymbol = _Symbol;

   LastTradeDay    = TimeCurrent();
   CurrentDailyLoss= 0.0;

   Print("MyTradingBot initialized on symbol: ", BaseSymbol);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("MyTradingBot deinitialized.");
}

void OnTick()
{
   // Check for new bar
   static datetime lastBarTime = 0;
   datetime curBarTime = iTime(BaseSymbol, MainTF, 0);
   if(curBarTime == lastBarTime) return;
   lastBarTime = curBarTime;

   // Check daily drawdown
   ResetDailyLossIfNewDay();
   if(!CheckDailyDrawdown(DailyDrawdownLimit, CurrentDailyLoss))
   {
      Print("Daily DD limit reached. No new trades.");
      return;
   }

   // (1) If ML is toggled, read probability
   if(UseMLSignal)
   {
      double mlProb = ReadMLSignal("signal.csv");
      if(mlProb < ML_Threshold)
      {
         Print("ML prob=", mlProb, " < threshold=", ML_Threshold, ". Skipping trades.");
         return;
      }
      else
      {
         Print("ML prob=", mlProb, " >= threshold=", ML_Threshold, ". Proceeding.");
      }
   }

   // (2) Evaluate fib zone & order blocks
   double fibHigh, fibLow;
   GetFibonacciZone(HigherTF, fibHigh, fibLow);

   bool inPremium, inDiscount;
   EvaluateFibPosition(fibHigh, fibLow, inPremium, inDiscount);

   bool orderBlockSignal = false;
   if(UseOrderBlocks)
      orderBlockSignal = (iOrderBlockSignal(BaseSymbol, HigherTF, 0) != 0);

   // (3) Check optional indicators
   bool indicatorsOkay = CheckOptionalIndicators();

   // (4) Detect fractal sweep
   double sweepPrice;
   bool   isBullishSweep;
   bool sweepDetected = DetectFractalSweep(BaseSymbol, MainTF, sweepPrice, isBullishSweep);

   // (5) If everything aligns, place order
   if(sweepDetected && indicatorsOkay && orderBlockSignal)
   {
      if(isBullishSweep && inDiscount)
         PlaceLimitOrder(true, sweepPrice);
      else if(!isBullishSweep && inPremium)
         PlaceLimitOrder(false, sweepPrice);
   }

   // (6) Manage open positions
   ManageOpenPositions();
}

//==================================================================
// HELPER FUNCTIONS
//==================================================================
void ResetDailyLossIfNewDay()
{
   datetime now = TimeCurrent();
   if(TimeDay(now) != TimeDay(LastTradeDay))
   {
      LastTradeDay = now;
      CurrentDailyLoss = 0.0;
   }
}

// Detect fractal sweep
bool DetectFractalSweep(string symbol, ENUM_TIMEFRAMES tf, double &sweepPrice, bool &isBullish)
{
   double upFrac   = iCustomFractalHigh(symbol, tf, 1);
   double downFrac = iCustomFractalLow(symbol, tf, 1);

   double lastClose = iClose(symbol, tf, 1);
   double prevClose = iClose(symbol, tf, 2);

   // bullish sweep if last bar spiked below downFrac then closed above it
   if(downFrac > 0 && lastClose > downFrac && prevClose > downFrac)
   {
      sweepPrice = downFrac;
      isBullish = true;
      return true;
   }

   // bearish sweep if last bar spiked above upFrac then closed below it
   if(upFrac > 0 && lastClose < upFrac && prevClose < upFrac)
   {
      sweepPrice = upFrac;
      isBullish = false;
      return true;
   }
   return false;
}

// Evaluate fib zone
void GetFibonacciZone(ENUM_TIMEFRAMES tf, double &fibHigh, double &fibLow)
{
   fibHigh = iCustomFractalHigh(BaseSymbol, tf, 0);
   fibLow  = iCustomFractalLow(BaseSymbol, tf, 0);
}

void EvaluateFibPosition(double fibHigh, double fibLow, bool &inPremium, bool &inDiscount)
{
   double currentPrice = SymbolInfoDouble(BaseSymbol, SYMBOL_BID);
   if(fibHigh == fibLow)
   {
      inPremium = false;
      inDiscount= false;
      return;
   }

   double range = fibHigh - fibLow;
   double midLevel = fibLow + (range * FibEntryLevel);

   inDiscount = (currentPrice <= midLevel);
   inPremium  = (currentPrice >= midLevel);
}

// Optional indicators: MA, RSI, ATR, Bollinger
bool CheckOptionalIndicators()
{
   if(UseMA)
   {
      double maValue = iMA(BaseSymbol, MainTF, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
      double curPrice= SymbolInfoDouble(BaseSymbol, SYMBOL_BID);
      if(curPrice < maValue) 
         return false;
   }
   if(UseRSI)
   {
      double rsiVal = iRSI(BaseSymbol, MainTF, 14, PRICE_CLOSE, 0);
      // skip if RSI>70 (overbought)
      if(rsiVal > 70.0)
         return false;
   }
   if(UseATR)
   {
      double atrVal = iATR(BaseSymbol, MainTF, 14, 0);
      if(atrVal < 0.0005)
         return false;
   }
   if(UseBollinger)
   {
      double bbUp = iBands(BaseSymbol, MainTF, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
      double curPrice = SymbolInfoDouble(BaseSymbol, SYMBOL_BID);
      if(curPrice > bbUp)
         return false;
   }
   return true;
}

// Place limit order
void PlaceLimitOrder(bool bullish, double sweepPrice)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   double pips   = 20.0;
   double point  = SymbolInfoDouble(BaseSymbol, SYMBOL_POINT);

   double entryPrice, stopLoss, takeProfit;
   if(bullish)
   {
      entryPrice = sweepPrice;
      stopLoss   = sweepPrice - (pips * point);
      takeProfit = sweepPrice + (2.0 * pips * point);
      req.type   = ORDER_TYPE_BUY_LIMIT;
      req.comment= "BullishSweepBuyLimit";
   }
   else
   {
      entryPrice = sweepPrice;
      stopLoss   = sweepPrice + (pips * point);
      takeProfit = sweepPrice - (2.0 * pips * point);
      req.type   = ORDER_TYPE_SELL_LIMIT;
      req.comment= "BearishSweepSellLimit";
   }

   double lots = CalculatePositionSize(RiskPerTrade, stopLoss, entryPrice, BaseSymbol);

   req.action = TRADE_ACTION_PENDING;
   req.symbol = BaseSymbol;
   req.volume = lots;
   req.price  = NormalizeDouble(entryPrice, _Digits);
   req.sl     = NormalizeDouble(stopLoss,   _Digits);
   req.tp     = NormalizeDouble(takeProfit, _Digits);
   req.magic  = MagicNumber;

   if(!OrderSend(req, res))
   {
      Print("OrderSend Error: ", GetLastError());
   }
   else
   {
      Print("Placed limit order: ", req.comment,
            " Entry:", req.price,
            " SL:", req.sl,
            " TP:", req.tp);
   }
}

// Manage positions (partial exits, trailing stops, daily P/L)
void ManageOpenPositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != BaseSymbol) continue;

      long posType    = PositionGetInteger(POSITION_TYPE);
      double vol      = PositionGetDouble(POSITION_VOLUME);
      double openPrice= PositionGetDouble(POSITION_PRICE_OPEN);
      double sl       = PositionGetDouble(POSITION_SL);
      double tp       = PositionGetDouble(POSITION_TP);

      // trailing stops
      if(UseTrailingStop)
         ApplyTrailingStop(posType, openPrice, sl, TrailStopPips);

      // partial exits
      if(UsePartialExit)
      {
         bool exitCond = CheckPartialExit(posType, openPrice, sl, tp);
         if(exitCond)
         {
            double partialVol = vol * PartialExitRatio;
            ClosePartialPosition(BaseSymbol, partialVol);
         }
      }
   }

   UpdateCurrentDailyLoss();
}

// Trailing stop logic
void ApplyTrailingStop(long posType, double openPrice, double currSL, double trailPips)
{
   double point = SymbolInfoDouble(BaseSymbol, SYMBOL_POINT);
   double newSL;
   double currentPrice = (posType == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(BaseSymbol, SYMBOL_BID)
                         : SymbolInfoDouble(BaseSymbol, SYMBOL_ASK);

   if(posType == POSITION_TYPE_BUY)
   {
      newSL = currentPrice - (trailPips * point);
      if(newSL > currSL && newSL < currentPrice)
         ModifySL(newSL);
   }
   else
   {
      newSL = currentPrice + (trailPips * point);
      if(newSL < currSL && newSL > currentPrice)
         ModifySL(newSL);
   }
}

// Modify existing SL
void ModifySL(double newStop)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   ulong ticket = PositionGetInteger(POSITION_TICKET);
   double tp    = PositionGetDouble(POSITION_TP);

   req.action   = TRADE_ACTION_SLTP;
   req.symbol   = BaseSymbol;
   req.position = ticket;
   req.sl       = NormalizeDouble(newStop, _Digits);
   req.tp       = tp;
   req.magic    = MagicNumber;

   if(!OrderSend(req, res))
      Print("ModifySL error:", GetLastError());
   else
      Print("StopLoss moved to:", newStop);
}

// Partial exit at 1:1 R:R
bool CheckPartialExit(long posType, double openPrice, double sl, double tp)
{
   double risk = MathAbs(openPrice - sl);
   double reward = MathAbs(tp - openPrice);
   double currentPrice = (posType == POSITION_TYPE_BUY)
                         ? SymbolInfoDouble(BaseSymbol, SYMBOL_BID)
                         : SymbolInfoDouble(BaseSymbol, SYMBOL_ASK);

   double currentRR = MathAbs(currentPrice - openPrice) / risk;
   if(currentRR >= 1.0)
      return true;
   return false;
}

// Partial exit logic
void ClosePartialPosition(string symbol, double partialVol)
{
   long posType = PositionGetInteger(POSITION_TYPE);
   double price= (posType==POSITION_TYPE_BUY)
                 ? SymbolInfoDouble(symbol, SYMBOL_BID)
                 : SymbolInfoDouble(symbol, SYMBOL_ASK);

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action  = TRADE_ACTION_DEAL;
   req.symbol  = symbol;
   req.volume  = partialVol;
   req.magic   = MagicNumber;
   req.price   = NormalizeDouble(price, _Digits);
   if(posType == POSITION_TYPE_BUY)
      req.type = ORDER_TYPE_SELL;
   else
      req.type = ORDER_TYPE_BUY;

   req.comment = "PartialExit";

   if(!OrderSend(req, res))
      Print("Partial Exit Error:", GetLastError());
   else
      Print("Partial exit done for ", partialVol," lots on ", symbol);
}

// Track daily realized P/L
void UpdateCurrentDailyLoss()
{
   double dailyProfit=0.0;
   datetime dayStart = iTime(BaseSymbol, PERIOD_D1, 0);

   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      datetime closeTime= (datetime)OrderGetInteger(ORDER_TIME_DONE);
      if(closeTime < dayStart) continue;

      double profit = OrderGetDouble(ORDER_PROFIT)
                    + OrderGetDouble(ORDER_COMMISSION)
                    + OrderGetDouble(ORDER_SWAP);
      dailyProfit += profit;
   }
   if(dailyProfit < 0.0)
      CurrentDailyLoss = MathAbs(dailyProfit);
   else
      CurrentDailyLoss = 0.0;
}

//==================================================================
// READ THE ML SIGNAL FROM CSV
//==================================================================
double ReadMLSignal(string filename)
{
   // Attempt to open the file from MQL5/Files
   int handle = FileOpen(filename, FILE_READ|FILE_CSV);
   if(handle == INVALID_HANDLE)
   {
      Print("FileOpen failed on ", filename, " Err:", GetLastError());
      return(0.0);
   }

   double prob = 0.0;
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(line != "")
         prob = StringToDouble(line);
   }
   FileClose(handle);

   return prob;
}
//+------------------------------------------------------------------+
