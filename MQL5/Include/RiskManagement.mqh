//+------------------------------------------------------------------+
//| RiskManagement.mqh                                              |
//| Library for daily drawdown check & lot size calc.    |
//+------------------------------------------------------------------+
#ifndef __RISKMANAGEMENT_MQH__
#define __RISKMANAGEMENT_MQH__

//+------------------------------------------------------------------+
//| CheckDailyDrawdown                                              |
//| Return false if daily drawdown limit exceeded                   |
//+------------------------------------------------------------------+
bool CheckDailyDrawdown(double limitPercent, double currentDailyLoss)
{
   if(currentDailyLoss >= limitPercent)
      return false;
   return true;
}

//+------------------------------------------------------------------+
//| CalculatePositionSize                                           |
//| Definitive risk-based formula.                                  |
//+------------------------------------------------------------------+
double CalculatePositionSize(double riskPercent, double stopLossPrice, double entryPrice, string symbol)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICKVALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICKSIZE);
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double slDistancePoints = MathAbs(entryPrice - stopLossPrice) / point;
   if(slDistancePoints < 1) slDistancePoints = 1; // avoid zero or extremely tight SL

   // Very direct approach: 
   // For every 1 point, we lose 'tickValue' for each lot, 
   // so risk = (slDistancePoints * tickValue * lots)
   // Adjust if needed.
   double lots = riskAmount / (slDistancePoints * tickValue);
   // Round to symbol lot step
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
