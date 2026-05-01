//+------------------------------------------------------------------+
//|                                               DivergenceEA.mq5   |
//|                        Multi-TF Divergence + EMA Confirmation EA  |
//+------------------------------------------------------------------+
#property copyright "DivergenceEA"
#property link      ""
#property version   "1.00"

#include "DivergenceDetector.mqh"
#include "TradeManager.mqh"
#include "PanelUI.mqh"

//--- Enums
enum ENUM_LOT_MODE { LOT_FIXED, LOT_RISK_PERCENT };

//--- Input: Trade Direction
input group "=== PRIMARY TREND FILTER ==="
input ENUM_TIMEFRAMES InpDailyTF       = PERIOD_D1;    // Daily Timeframe
input ENUM_TIMEFRAMES InpH4TF          = PERIOD_H4;    // 4-Hour Timeframe

input group "=== ENTRY TIMEFRAME ==="
input ENUM_TIMEFRAMES InpEntryTF       = PERIOD_M15;   // Entry Timeframe

input group "=== EMA SETTINGS ==="
input int             InpFastEMA       = 9;            // Fast EMA Period
input int             InpSlowEMA       = 50;           // Slow EMA Period

input group "=== DIVERGENCE SETTINGS ==="
input int             InpRSI_Period    = 14;           // RSI Period
input int             InpDivLookback   = 30;           // Divergence Lookback Bars
input int             InpPivotBars     = 5;            // Pivot Detection Bars

input group "=== MACD FILTER (OPTIONAL) ==="
input bool            InpUseMACD       = false;        // Enable MACD Filter
input int             InpMACDFast      = 12;           // MACD Fast Period
input int             InpMACDSlow      = 26;           // MACD Slow Period
input int             InpMACDSignal    = 9;            // MACD Signal Period

input group "=== RISK MANAGEMENT ==="
input double          InpStopLoss      = 50.0;         // Stop Loss (points)
input double          InpTakeProfit    = 100.0;        // Take Profit (points)
input ENUM_LOT_MODE   InpLotMode       = LOT_FIXED;    // Lot Mode
input double          InpLotSize       = 0.01;         // Fixed Lot Size
input double          InpRiskPercent   = 1.0;          // Risk % per Trade

input group "=== TRAILING & BREAKEVEN ==="
input bool            InpUseTrailing   = false;        // Enable Trailing Stop
input double          InpTrailingStart = 30.0;         // Trailing Start (points)
input double          InpTrailingStep  = 10.0;         // Trailing Step (points)
input bool            InpUseBreakeven  = false;        // Enable Breakeven
input double          InpBE_Trigger    = 30.0;         // BE Trigger (points)
input double          InpBE_Offset     = 5.0;          // BE Offset (points)

input group "=== TRADE CONTROL ==="
input int             InpMagicNumber   = 123456;       // Magic Number
input int             InpMaxSpread     = 30;           // Max Spread (points)
input string          InpComment       = "DivEA";      // Order Comment

//--- Global handles
int g_emaFastHandle, g_emaSlowHandle, g_rsiEntry, g_macdHandle;

//--- Modules
CDivergenceDetector g_divDetector;
CTradeManager       g_tradeMgr;
CPanelUI            g_panel;

//--- State
datetime g_lastSignalBar = 0;
string   g_lastStatus    = "Initializing...";
int      g_lastDirection  = 0; // 1=buy, -1=sell, 0=none

//+------------------------------------------------------------------+
int OnInit()
{
   // Entry TF indicators
   g_emaFastHandle = iMA(_Symbol, InpEntryTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle = iMA(_Symbol, InpEntryTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiEntry      = iRSI(_Symbol, InpEntryTF, InpRSI_Period, PRICE_CLOSE);

   if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE || g_rsiEntry == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create entry TF indicator handles");
      return INIT_FAILED;
   }

   // MACD
   if(InpUseMACD)
   {
      g_macdHandle = iMACD(_Symbol, InpEntryTF, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
      if(g_macdHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create MACD handle");
         return INIT_FAILED;
      }
   }

   // Initialize modules
   g_divDetector.Init(InpRSI_Period, InpDivLookback, InpPivotBars);
   g_tradeMgr.Init(InpMagicNumber, InpComment, InpMaxSpread);
   g_panel.Create("DivEA_Panel", 20, 30);

   Print("DivergenceEA initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);
   if(g_rsiEntry != INVALID_HANDLE)      IndicatorRelease(g_rsiEntry);
   if(InpUseMACD && g_macdHandle != INVALID_HANDLE) IndicatorRelease(g_macdHandle);

   g_divDetector.Deinit();
   g_panel.Destroy();
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Only process on new bar of entry timeframe
   static datetime lastBar = 0;
   datetime curBar = iTime(_Symbol, InpEntryTF, 0);
   if(curBar == lastBar) 
   {
      // Still manage open positions every tick
      if(InpUseTrailing || InpUseBreakeven)
         g_tradeMgr.ManagePositions(InpUseTrailing, InpTrailingStart, InpTrailingStep,
                                     InpUseBreakeven, InpBE_Trigger, InpBE_Offset);
      return;
   }
   lastBar = curBar;

   // Update panel
   g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());

   //--- STEP 1: Primary Trend Filter (Daily + H4)
   int dailyDir = GetCandleDirection(InpDailyTF, 1);
   int h4Dir    = GetCandleDirection(InpH4TF, 1);

   if(dailyDir == 0 || h4Dir == 0 || dailyDir != h4Dir)
   {
      g_lastStatus = "No trend alignment (D1/H4)";
      g_lastDirection = 0;
      g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
      return;
   }

   int trendDir = dailyDir; // 1=bullish, -1=bearish
   g_lastDirection = trendDir;

   //--- STEP 2: Check if already have open position
   if(g_tradeMgr.HasOpenPosition())
   {
      g_lastStatus = "Position open - managing";
      g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
      return;
   }

   //--- STEP 3: One trade per signal candle
   if(curBar == g_lastSignalBar)
   {
      return;
   }

   //--- STEP 4: Get EMA values on entry TF
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   if(CopyBuffer(g_emaFastHandle, 0, 0, 3, emaFast) < 3) return;
   if(CopyBuffer(g_emaSlowHandle, 0, 0, 3, emaSlow) < 3) return;

   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, InpEntryTF, 0, 3, close) < 3) return;

   //--- STEP 5: EMA 50 trend direction filter
   bool emaFilter = false;
   if(trendDir == 1 && close[1] > emaSlow[1])  emaFilter = true;  // BUY: price above 50 EMA
   if(trendDir == -1 && close[1] < emaSlow[1]) emaFilter = true;  // SELL: price below 50 EMA

   if(!emaFilter)
   {
      g_lastStatus = "EMA50 filter not met";
      g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
      return;
   }

   //--- STEP 6: Price pullback to 9 EMA
   bool pullback = false;
   if(trendDir == 1)
   {
      // For BUY: price touched or came close to EMA9 from above
      double low[];
      ArraySetAsSeries(low, true);
      if(CopyLow(_Symbol, InpEntryTF, 0, 3, low) < 3) return;
      if(low[1] <= emaFast[1] * 1.001 && close[1] >= emaFast[1])
         pullback = true;
   }
   else
   {
      // For SELL: price touched or came close to EMA9 from below
      double high[];
      ArraySetAsSeries(high, true);
      if(CopyHigh(_Symbol, InpEntryTF, 0, 3, high) < 3) return;
      if(high[1] >= emaFast[1] * 0.999 && close[1] <= emaFast[1])
         pullback = true;
   }

   if(!pullback)
   {
      g_lastStatus = StringFormat("Waiting EMA9 pullback (%s)", trendDir==1?"BUY":"SELL");
      g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
      return;
   }

   //--- STEP 7: Hidden Divergence Check (trend continuation)
   bool hiddenDiv = g_divDetector.DetectHiddenDivergence(_Symbol, InpEntryTF, trendDir);

   //--- STEP 8: Regular Divergence at S/R (reversal - check lower TFs)
   // Regular divergence is checked but only valid at S/R
   // For simplicity, we check regular div on entry TF as additional confirmation
   bool regularDiv = g_divDetector.DetectRegularDivergence(_Symbol, InpEntryTF, trendDir);

   bool divSignal = hiddenDiv || regularDiv;

   if(!divSignal)
   {
      g_lastStatus = "No divergence signal";
      g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
      return;
   }

   //--- STEP 9: MACD Filter (optional)
   if(InpUseMACD)
   {
      double macdHist[];
      ArraySetAsSeries(macdHist, true);
      if(CopyBuffer(g_macdHandle, 2, 0, 3, macdHist) < 3) return;

      if(trendDir == 1 && macdHist[1] <= 0)
      {
         g_lastStatus = "MACD filter: histogram below zero";
         g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
         return;
      }
      if(trendDir == -1 && macdHist[1] >= 0)
      {
         g_lastStatus = "MACD filter: histogram above zero";
         g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
         return;
      }
   }

   //--- STEP 10: Spread check
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpread)
   {
      g_lastStatus = StringFormat("Spread too high: %ld", spread);
      g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
      return;
   }

   //--- STEP 11: Calculate lot size
   double lotSize = InpLotSize;
   if(InpLotMode == LOT_RISK_PERCENT)
      lotSize = g_tradeMgr.CalcLotByRisk(InpRiskPercent, InpStopLoss);

   //--- STEP 12: Execute trade
   string divType = hiddenDiv ? "Hidden" : "Regular";
   bool result = false;

   if(trendDir == 1)
      result = g_tradeMgr.OpenBuy(lotSize, InpStopLoss, InpTakeProfit, divType);
   else
      result = g_tradeMgr.OpenSell(lotSize, InpStopLoss, InpTakeProfit, divType);

   if(result)
   {
      g_lastSignalBar = curBar;
      g_lastStatus = StringFormat("%s %s executed", divType, trendDir==1?"BUY":"SELL");
      Print(g_lastStatus);
   }
   else
   {
      g_lastStatus = "Trade execution failed";
   }

   g_panel.Update(g_lastStatus, g_lastDirection, g_tradeMgr.OpenPositionCount());
}

//+------------------------------------------------------------------+
//| Get candle direction: 1=bullish, -1=bearish, 0=doji/invalid      |
//+------------------------------------------------------------------+
int GetCandleDirection(ENUM_TIMEFRAMES tf, int shift)
{
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   if(CopyOpen(_Symbol, tf, 0, shift+1, open) < shift+1) return 0;
   if(CopyClose(_Symbol, tf, 0, shift+1, close) < shift+1) return 0;

   if(close[shift] > open[shift]) return 1;   // Bullish
   if(close[shift] < open[shift]) return -1;  // Bearish
   return 0;
}
//+------------------------------------------------------------------+
