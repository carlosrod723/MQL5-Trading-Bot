//+------------------------------------------------------------------+
//| RiskManagement.mqh                                              |
//| Library for daily drawdown check & lot size calculation in MQL5 |
//+------------------------------------------------------------------+
#ifndef __RISKMANAGEMENT_MQH__
#define __RISKMANAGEMENT_MQH__

//+------------------------------------------------------------------+
//| CheckDailyDrawdown                                              |
//| Return false if daily drawdown limit is exceeded                |
//+------------------------------------------------------------------+
bool CheckDailyDrawdown(double limitPercent, double currentDailyLoss)
{
   // If daily loss is >= the limit, block new trades
   if(currentDailyLoss >= limitPercent)
      return false;
   return true;
}

//+------------------------------------------------------------------+
//| CalculatePositionSize                                           |
//| Definitive risk-based formula in MQL5                           |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, double stopLossPrice, double entryPrice, string symbol)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);

   // In MQL5, the correct enum is SYMBOL_TRADE_TICK_VALUE
   double tickValue  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

   // Distance in points
   double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / point;
   if(slDistancePoints < 1) 
      slDistancePoints = 1; // avoid extremely tight SL

   // Basic formula: risk = slDistancePoints * tickValue * lots
   double lots = riskAmount / (slDistancePoints * tickValue);

   // Round to the symbol lot step
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lotStep) * lotStep;

   // Ensure min & max lot constraints
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return lots;
}

#endif
