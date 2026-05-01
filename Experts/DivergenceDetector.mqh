//+------------------------------------------------------------------+
//|                                         DivergenceDetector.mqh   |
//|                     RSI-based Hidden & Regular Divergence Logic   |
//+------------------------------------------------------------------+
#ifndef DIVERGENCE_DETECTOR_MQH
#define DIVERGENCE_DETECTOR_MQH

class CDivergenceDetector
{
private:
   int m_rsiPeriod;
   int m_lookback;
   int m_pivotBars;
   int m_rsiHandles[];  // cached per-symbol/tf

   // Find swing highs/lows in price and RSI
   bool FindPivotLow(const double &arr[], int start, int barsLeft, int barsRight, int &idx);
   bool FindPivotHigh(const double &arr[], int start, int barsLeft, int barsRight, int &idx);

public:
   void Init(int rsiPeriod, int lookback, int pivotBars);
   void Deinit();
   bool DetectHiddenDivergence(string symbol, ENUM_TIMEFRAMES tf, int direction);
   bool DetectRegularDivergence(string symbol, ENUM_TIMEFRAMES tf, int direction);
};

//+------------------------------------------------------------------+
void CDivergenceDetector::Init(int rsiPeriod, int lookback, int pivotBars)
{
   m_rsiPeriod = rsiPeriod;
   m_lookback  = lookback;
   m_pivotBars = pivotBars;
}

//+------------------------------------------------------------------+
void CDivergenceDetector::Deinit()
{
   // Handles released by main EA
}

//+------------------------------------------------------------------+
bool CDivergenceDetector::FindPivotLow(const double &arr[], int start, int barsLeft, int barsRight, int &idx)
{
   int size = ArraySize(arr);
   for(int i = start + barsRight; i < size - barsLeft; i++)
   {
      bool isPivot = true;
      for(int j = 1; j <= barsLeft; j++)
         if(arr[i] >= arr[i+j]) { isPivot = false; break; }
      if(!isPivot) continue;
      for(int j = 1; j <= barsRight; j++)
         if(arr[i] >= arr[i-j]) { isPivot = false; break; }
      if(isPivot) { idx = i; return true; }
   }
   return false;
}

//+------------------------------------------------------------------+
bool CDivergenceDetector::FindPivotHigh(const double &arr[], int start, int barsLeft, int barsRight, int &idx)
{
   int size = ArraySize(arr);
   for(int i = start + barsRight; i < size - barsLeft; i++)
   {
      bool isPivot = true;
      for(int j = 1; j <= barsLeft; j++)
         if(arr[i] <= arr[i+j]) { isPivot = false; break; }
      if(!isPivot) continue;
      for(int j = 1; j <= barsRight; j++)
         if(arr[i] <= arr[i-j]) { isPivot = false; break; }
      if(isPivot) { idx = i; return true; }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Hidden Divergence Detection                                       |
//| Hidden Bullish: Price makes Higher Low, RSI makes Lower Low       |
//| Hidden Bearish: Price makes Lower High, RSI makes Higher High     |
//+------------------------------------------------------------------+
bool CDivergenceDetector::DetectHiddenDivergence(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   int rsiHandle = iRSI(symbol, tf, m_rsiPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE) return false;

   double rsi[], close[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(close, true);

   int needed = m_lookback + m_pivotBars + 5;
   if(CopyBuffer(rsiHandle, 0, 0, needed, rsi) < needed) { IndicatorRelease(rsiHandle); return false; }
   if(CopyClose(symbol, tf, 0, needed, close) < needed) { IndicatorRelease(rsiHandle); return false; }

   IndicatorRelease(rsiHandle);

   if(direction == 1) // Hidden Bullish: price HL, RSI LL
   {
      int pricePivot1 = -1, pricePivot2 = -1;
      int rsiPivot1 = -1, rsiPivot2 = -1;

      if(!FindPivotLow(close, 1, m_pivotBars, m_pivotBars, pricePivot1)) return false;
      if(!FindPivotLow(close, pricePivot1 + 1, m_pivotBars, m_pivotBars, pricePivot2)) return false;
      if(!FindPivotLow(rsi, 1, m_pivotBars, m_pivotBars, rsiPivot1)) return false;
      if(!FindPivotLow(rsi, rsiPivot1 + 1, m_pivotBars, m_pivotBars, rsiPivot2)) return false;

      // Price: Higher Low (recent > older means recent pivot1 > pivot2)
      // RSI: Lower Low (recent < older means rsiPivot1 < rsiPivot2)
      if(close[pricePivot1] > close[pricePivot2] && rsi[rsiPivot1] < rsi[rsiPivot2])
      {
         Print(StringFormat("Hidden Bullish Div: Price HL [%.5f > %.5f], RSI LL [%.2f < %.2f]",
               close[pricePivot1], close[pricePivot2], rsi[rsiPivot1], rsi[rsiPivot2]));
         return true;
      }
   }
   else if(direction == -1) // Hidden Bearish: price LH, RSI HH
   {
      int pricePivot1 = -1, pricePivot2 = -1;
      int rsiPivot1 = -1, rsiPivot2 = -1;

      if(!FindPivotHigh(close, 1, m_pivotBars, m_pivotBars, pricePivot1)) return false;
      if(!FindPivotHigh(close, pricePivot1 + 1, m_pivotBars, m_pivotBars, pricePivot2)) return false;
      if(!FindPivotHigh(rsi, 1, m_pivotBars, m_pivotBars, rsiPivot1)) return false;
      if(!FindPivotHigh(rsi, rsiPivot1 + 1, m_pivotBars, m_pivotBars, rsiPivot2)) return false;

      // Price: Lower High (recent < older)
      // RSI: Higher High (recent > older)
      if(close[pricePivot1] < close[pricePivot2] && rsi[rsiPivot1] > rsi[rsiPivot2])
      {
         Print(StringFormat("Hidden Bearish Div: Price LH [%.5f < %.5f], RSI HH [%.2f > %.2f]",
               close[pricePivot1], close[pricePivot2], rsi[rsiPivot1], rsi[rsiPivot2]));
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Regular Divergence Detection                                      |
//| Regular Bullish: Price makes Lower Low, RSI makes Higher Low      |
//| Regular Bearish: Price makes Higher High, RSI makes Lower High    |
//+------------------------------------------------------------------+
bool CDivergenceDetector::DetectRegularDivergence(string symbol, ENUM_TIMEFRAMES tf, int direction)
{
   int rsiHandle = iRSI(symbol, tf, m_rsiPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE) return false;

   double rsi[], close[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(close, true);

   int needed = m_lookback + m_pivotBars + 5;
   if(CopyBuffer(rsiHandle, 0, 0, needed, rsi) < needed) { IndicatorRelease(rsiHandle); return false; }
   if(CopyClose(symbol, tf, 0, needed, close) < needed) { IndicatorRelease(rsiHandle); return false; }

   IndicatorRelease(rsiHandle);

   if(direction == 1) // Regular Bullish: price LL, RSI HL
   {
      int pricePivot1 = -1, pricePivot2 = -1;
      int rsiPivot1 = -1, rsiPivot2 = -1;

      if(!FindPivotLow(close, 1, m_pivotBars, m_pivotBars, pricePivot1)) return false;
      if(!FindPivotLow(close, pricePivot1 + 1, m_pivotBars, m_pivotBars, pricePivot2)) return false;
      if(!FindPivotLow(rsi, 1, m_pivotBars, m_pivotBars, rsiPivot1)) return false;
      if(!FindPivotLow(rsi, rsiPivot1 + 1, m_pivotBars, m_pivotBars, rsiPivot2)) return false;

      // Price: Lower Low (recent < older)
      // RSI: Higher Low (recent > older)
      if(close[pricePivot1] < close[pricePivot2] && rsi[rsiPivot1] > rsi[rsiPivot2])
      {
         Print(StringFormat("Regular Bullish Div: Price LL [%.5f < %.5f], RSI HL [%.2f > %.2f]",
               close[pricePivot1], close[pricePivot2], rsi[rsiPivot1], rsi[rsiPivot2]));
         return true;
      }
   }
   else if(direction == -1) // Regular Bearish: price HH, RSI LH
   {
      int pricePivot1 = -1, pricePivot2 = -1;
      int rsiPivot1 = -1, rsiPivot2 = -1;

      if(!FindPivotHigh(close, 1, m_pivotBars, m_pivotBars, pricePivot1)) return false;
      if(!FindPivotHigh(close, pricePivot1 + 1, m_pivotBars, m_pivotBars, pricePivot2)) return false;
      if(!FindPivotHigh(rsi, 1, m_pivotBars, m_pivotBars, rsiPivot1)) return false;
      if(!FindPivotHigh(rsi, rsiPivot1 + 1, m_pivotBars, m_pivotBars, rsiPivot2)) return false;

      // Price: Higher High (recent > older)
      // RSI: Lower High (recent < older)
      if(close[pricePivot1] > close[pricePivot2] && rsi[rsiPivot1] < rsi[rsiPivot2])
      {
         Print(StringFormat("Regular Bearish Div: Price HH [%.5f > %.5f], RSI LH [%.2f < %.2f]",
               close[pricePivot1], close[pricePivot2], rsi[rsiPivot1], rsi[rsiPivot2]));
         return true;
      }
   }

   return false;
}

#endif
