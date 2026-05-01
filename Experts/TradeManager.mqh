//+------------------------------------------------------------------+
//|                                              TradeManager.mqh    |
//|                    Position Management, Lot Calc, Trailing, BE   |
//+------------------------------------------------------------------+
#ifndef TRADE_MANAGER_MQH
#define TRADE_MANAGER_MQH

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

class CTradeManager
{
private:
   CTrade         m_trade;
   CPositionInfo  m_position;
   int            m_magic;
   string         m_comment;
   int            m_maxSpread;

public:
   void  Init(int magic, string comment, int maxSpread);
   bool  HasOpenPosition();
   int   OpenPositionCount();
   bool  OpenBuy(double lots, double slPoints, double tpPoints, string divType);
   bool  OpenSell(double lots, double slPoints, double tpPoints, string divType);
   double CalcLotByRisk(double riskPercent, double slPoints);
   void  ManagePositions(bool trailing, double trailStart, double trailStep,
                         bool breakeven, double beTrigger, double beOffset);
};

//+------------------------------------------------------------------+
void CTradeManager::Init(int magic, string comment, int maxSpread)
{
   m_magic     = magic;
   m_comment   = comment;
   m_maxSpread = maxSpread;
   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
}

//+------------------------------------------------------------------+
bool CTradeManager::HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
int CTradeManager::OpenPositionCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == m_magic)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
bool CTradeManager::OpenBuy(double lots, double slPoints, double tpPoints, string divType)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double sl = NormalizeDouble(ask - slPoints * point, digits);
   double tp = NormalizeDouble(ask + tpPoints * point, digits);

   string comment = StringFormat("%s_%s_BUY", m_comment, divType);

   if(m_trade.Buy(lots, _Symbol, ask, sl, tp, comment))
   {
      Print(StringFormat("BUY opened: %.2f lots @ %.5f | SL: %.5f | TP: %.5f | %s", lots, ask, sl, tp, divType));
      return true;
   }
   else
   {
      Print(StringFormat("BUY failed: %d - %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
      return false;
   }
}

//+------------------------------------------------------------------+
bool CTradeManager::OpenSell(double lots, double slPoints, double tpPoints, string divType)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double sl = NormalizeDouble(bid + slPoints * point, digits);
   double tp = NormalizeDouble(bid - tpPoints * point, digits);

   string comment = StringFormat("%s_%s_SELL", m_comment, divType);

   if(m_trade.Sell(lots, _Symbol, bid, sl, tp, comment))
   {
      Print(StringFormat("SELL opened: %.2f lots @ %.5f | SL: %.5f | TP: %.5f | %s", lots, bid, sl, tp, divType));
      return true;
   }
   else
   {
      Print(StringFormat("SELL failed: %d - %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()));
      return false;
   }
}

//+------------------------------------------------------------------+
double CTradeManager::CalcLotByRisk(double riskPercent, double slPoints)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * riskPercent / 100.0;
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickValue == 0 || tickSize == 0 || slPoints == 0) return 0.01;

   double slValue = slPoints * point;
   double lots = riskAmount / ((slValue / tickSize) * tickValue);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = NormalizeDouble(lots, 2);

   return lots;
}

//+------------------------------------------------------------------+
void CTradeManager::ManagePositions(bool trailing, double trailStart, double trailStep,
                                     bool breakeven, double beTrigger, double beOffset)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol || m_position.Magic() != m_magic) continue;

      double openPrice = m_position.PriceOpen();
      double currentSL = m_position.StopLoss();

      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double pipsProfit = (bid - openPrice) / point;

         // Breakeven
         if(breakeven && pipsProfit >= beTrigger)
         {
            double newSL = NormalizeDouble(openPrice + beOffset * point, digits);
            if(currentSL < newSL)
               m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
         }

         // Trailing stop
         if(trailing && pipsProfit >= trailStart)
         {
            double newSL = NormalizeDouble(bid - trailStep * point, digits);
            if(newSL > currentSL)
               m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
         }
      }
      else if(m_position.PositionType() == POSITION_TYPE_SELL)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double pipsProfit = (openPrice - ask) / point;

         // Breakeven
         if(breakeven && pipsProfit >= beTrigger)
         {
            double newSL = NormalizeDouble(openPrice - beOffset * point, digits);
            if(currentSL > newSL || currentSL == 0)
               m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
         }

         // Trailing stop
         if(trailing && pipsProfit >= trailStart)
         {
            double newSL = NormalizeDouble(ask + trailStep * point, digits);
            if(newSL < currentSL || currentSL == 0)
               m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
         }
      }
   }
}

#endif
