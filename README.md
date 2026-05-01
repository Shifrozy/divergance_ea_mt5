# Divergence EA for MetaTrader 5

A multi-timeframe Expert Advisor that combines **higher-timeframe trend filtering**, **RSI divergence detection** (hidden + regular), and **EMA pullback confirmation** for high-probability trade entries.

## Strategy Logic

1. **D1 + H4 Trend Alignment** — Only trades when both timeframes agree on direction
2. **EMA 50 Trend Filter** — Price must be above (BUY) or below (SELL) the 50 EMA on entry TF
3. **EMA 9 Pullback** — Waits for price to pull back to the 9 EMA before entry
4. **Divergence Confirmation** — Detects hidden divergence (continuation) or regular divergence (reversal) using RSI pivot analysis
5. **MACD Filter (Optional)** — Histogram must confirm momentum direction
6. **One Trade Per Signal Candle** — Prevents duplicate entries

## Files

| File | Description |
|------|-------------|
| `Experts/DivergenceEA.mq5` | Main EA entry point |
| `Experts/DivergenceDetector.mqh` | RSI-based divergence detection engine |
| `Experts/TradeManager.mqh` | Order execution + position management |
| `Experts/PanelUI.mqh` | On-chart status panel |

## Installation

1. Copy the `Experts/` folder contents to `MQL5/Experts/DivergenceEA/`
2. Open MetaEditor → Compile `DivergenceEA.mq5`
3. Attach to chart → Configure inputs → Enable AutoTrading

## Risk Management Features

- Fixed lot or risk-percentage sizing
- Adjustable Stop Loss / Take Profit
- Optional Trailing Stop
- Optional Breakeven
- Max spread filter
- Magic number for multi-EA setups