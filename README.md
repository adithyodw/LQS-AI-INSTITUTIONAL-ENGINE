# LQS-AI Institutional Engine v5.0

**Institutional-grade algorithmic trading engine for XAUUSD (Gold) with AI decision filtering and multi-provider Vision API integration.**

> An advanced Expert Advisor (EA) combining proven Wyckoff market microstructure analysis with real-time AI decision support, designed for professional traders and algo-trading operations.

---

## 🎯 Overview

**LQS-AI v5.0** is a production-ready MetaTrader 5 Expert Advisor that operates across 4 independent analytical modules plus an integrated AI decision layer:

| Module | Purpose | Status |
|--------|---------|--------|
| **A: Liquidity Sweep** | Identifies institutional liquidation levels | ✅ Proven |
| **B: Order Flow** | Tracks cumulative delta and absorption zones | ✅ Proven |
| **C: AMD Wyckoff** | Detects accumulation/distribution phases | ✅ Proven |
| **D: Anchored VWAP** | Multi-timeframe volume-weighted averages | ✅ Proven |
| **E: AI Decision Layer** | Online logistic regression + market entropy filter | ✨ New in v5 |

---

## ✨ What's New in v5.0

### 🤖 AI Decision Layer
- **7-feature online logistic regression** trained from live trade outcomes
- **Shannon entropy** market structure quality filter
- **Online learning**: weights update on every closed trade — no data science required
- Acts as a **decision filter + risk modulator**, never selects direction independently

### 🔮 External AI Vision (Optional)
- Multi-timeframe chart screenshots analyzed by Claude, GPT-4o, Gemini, DeepSeek, or xAI Grok
- Acts as a **second confirmation gate** before trade execution
- Fully optional (disabled by default) — works offline without Vision enabled
- Configurable confidence threshold (0-100%)

### 📊 Flexible Lot Sizing (5 modes)
- **Auto Low**: 0.01 lot per $1,000 equity (safest)
- **Auto Medium**: 0.02 lot per $1,000 equity (balanced)
- **Auto High**: 0.03 lot per $1,000 equity (aggressive)
- **Fixed Lot**: constant position size
- **Bayesian Kelly**: dynamically sized from win rate + risk/reward history

Includes soft scaling for high-volatility regimes and consecutive losses.

### 📁 JSON Trade Journal
- Append-mode JSONL export for post-trade analysis
- Python-ready for ML model training, backtesting analysis, or risk audit
- Captures all trade context: modules' scores, AI confidence, entry/exit times, P&L, regime

### 🛡️ Robust SL/TP Management
- **Broker Stops/Freeze-level aware** modification gate — never attempts invalid SL updates
- **Smart trailing stop** that adapts to volatility and VWAP confluence
- Breakeven automation with optional profit lock-in

---

## 📈 Live Trading Performance

### TOL LANGIT V10 (Flagship Strategy)
**Live signal distribution across multiple platforms:**

- **[MQL5 Signal](https://www.mql5.com/en/signals/1083101)** — Live copy-trading available
- **[Myfxbook](https://www.myfxbook.com/members/adithyodw/tol-langit-v10/8671765)** — Full performance metrics
- **[SignalStart](https://icmarkets.signalstart.com/analysis/tol-langit-v10/232541)** — IC Markets integration
- **[ZuluTrade](https://www.zulutrade.com/trader/417743/trading)** — Multi-instrument copy trading

### TOL LANGIT ETF GOLD (Conservative Gold Strategy)
- **[MQL5 Signal](https://www.mql5.com/en/signals/2360336)** — XAUUSD H1 specialist
- **[SignalStart](https://icmarkets.signalstart.com/analysis/tol-langit-etf-gold/288423)** — IC Markets certified
- **[Myfxbook](https://www.myfxbook.com/members/adithyodw/tol-langit-etf-gold/12042787)** — Verified live trading

### Portfolio Dashboard
**[Visit Tol Langit ETF Portfolio](https://tol-langit-etf.vercel.app/)** — Real-time performance dashboard, risk metrics, drawdown analysis.

---

## 🔧 Technical Specifications

### Requirements
- **Platform**: MetaTrader 5 (Windows/Mac)
- **Instrument**: XAUUSD (Gold Spot)
- **Timeframe**: H1 (1-hour)
- **Account Type**: Netting (default), Hedging (supported)
- **Broker**: Any FX broker with MT5 (tested: IC Markets, FxPro, Dukascopy)

### Configuration

#### Core Trading
- **Session filters**: Asian, London, New York sessions (configurable)
- **Maximum open trades**: 1 (single-position discipline)
- **Risk per trade**: 1-3% (configurable, regime-aware)
- **Stale trade auto-exit**: 8+ bars without TP1 hit → closes position

#### AI Features
```
InpUseAI                = true    // Enable AI decision filter
InpAIBoostThresh        = 75      // High-confidence boost threshold
InpAIBoostMult          = 1.3     // Risk multiplier when AI is very confident
InpAIDampMult           = 0.8     // Risk dampen when AI confidence is marginal
InpAILearnTrades        = 15      // Minimum trades before AI learning activates
```

#### AI Vision (Optional)
```
InpUseAPIVision         = false   // Disabled by default
InpProviderOverride     = "auto"  // auto | anthropic | openai | google | deepseek | xai
InpMinAPIConf           = 65      // Min confidence (0-100) to allow trade
InpAPITimeoutSec        = 30      // WebRequest timeout
InpChartWidth/Height    = 1920/1080 // Screenshot resolution
```

#### Lot Sizing
```
InpLotMode              = LOT_AUTO_LOW  // AUTO_LOW | AUTO_MED | AUTO_HIGH | FIXED | KELLY
InpFixedLot             = 0.01          // Used only if LOT_FIXED selected
InpKellyFrac            = 0.25          // Quarter-Kelly (conservative)
InpRiskMin              = 1.0%          // Kelly floor risk
InpRiskMax              = 3.0%          // Kelly ceiling risk
```

---

## 📥 Installation

1. **Download** `LQS_AI_Integrated.ex5` from this repository
2. **Place in**: `C:\Users\[YourUser]\AppData\Roaming\MetaQuotes\Terminal\[TerminalID]\MQL5\Experts\`
3. **Restart MetaTrader 5** (or refresh Expert Advisors)
4. **Open XAUUSD H1 chart** → drag EA from Navigator → set desired inputs
5. **Enable autotrade** in the EA properties dialog
6. **Monitor** via the dashboard or Myfxbook/MQL5 signal

### Optional: AI Vision Setup
If you want to enable AI Vision for additional confirmation:
1. Obtain an API key from [Anthropic Claude](https://console.anthropic.com/), [OpenAI](https://platform.openai.com), or [Google Gemini](https://ai.google.dev/)
2. Paste the key in `InpAPIKey` input
3. Set `InpUseAPIVision = true`
4. In MetaEditor: Tools → Options → Expert Advisors → enable WebRequest for the API endpoint URL

---

## 🧪 Backtest Results (XAUUSD H1, Feb 2022 – Dec 2024)

**v5.0 Validation Test** (48 trades, EURUSD H1 netting mode)
- ✅ No trade slippage errors
- ✅ No "Lot = 0" skips
- ✅ No "Modification failed" errors
- ✅ Broker Stops/Freeze-level compliant
- ✅ MQL5 Market validation: **PASSED**

---

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────┐
│              SIGNAL FUSION ENGINE                    │
├─────────────────────────────────────────────────────┤
│ Module A: Liquidity Sweep (SwingHigh extremes)      │
│ Module B: Order Flow (delta + absorption)            │
│ Module C: AMD Wyckoff (accumulation/distribution)    │
│ Module D: Anchored VWAP (multi-timeframe)            │
│ Module E: Volume Profile (POC + HVN/LVN)             │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│          SIGNAL SCORING & WEIGHTING                  │
│  (Adaptive weights learn from trade outcomes)        │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│           AI DECISION FILTER (v5 NEW)                │
│  7-feature logistic regression + entropy test        │
│  - Shannon entropy quality gate                      │
│  - Confidence scoring (0-100%)                       │
│  - Online learning from closed trades                │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│        AI VISION CONFIRMATION (OPTIONAL)             │
│  Claude / GPT-4o / Gemini chart analysis             │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│            ENTRY + LOT SIZING                        │
│  - 5-mode lot dispatcher                             │
│  - Bayesian Kelly criterion                          │
│  - Risk scaling for volatility regimes               │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│       TRADE MANAGEMENT & JOURNALING                  │
│  - Breakeven automation                              │
│  - Smart SL trailing (volatility-aware)              │
│  - Partial profit-taking (TP1/TP2/TP3)               │
│  - JSON journal export                               │
└─────────────────────────────────────────────────────┘
```

---

## 📋 Input Groups Reference

**SESSION & TIME** — Trading hours, Asian/London/NY session filters
**MODULE A–E** — Individual module sensitivity & phase detection parameters
**SIGNAL FUSION** — Module weight calibration (can adapt automatically)
**MARKET REGIME** — High volatility scaling, entropy thresholds
**RISK MANAGEMENT** — Lot mode, Kelly settings, daily limits
**BREAKEVEN & TRAILING** — BE activation, trail start %, ATR scaling
**AI DECISION LAYER** — Confidence thresholds, learning rates, risk multipliers
**AI VISION** — Provider selection, screenshot resolution, API timeout
**AI DATA INTERFACE** — JSON journal filename & export toggle
**VISUALIZATION** — Dashboard display options, verbose logging

---

## 🔐 Security & Compliance

- ✅ **No hardcoded secrets** — API keys stored in input parameters only
- ✅ **No DLL imports** — Pure MQL5, portable across brokers
- ✅ **MQL5 Market validated** — Passes all automated security checks
- ✅ **Institutional audit trail** — Full JSON trade journal for compliance
- ✅ **Broker-agnostic** — Works with any FX broker MT5 terminal
- ✅ **Offline-capable** — All core modules work without internet; Vision optional

---

## 📞 Support & Resources

- **Author**: [adithyodw](https://www.mql5.com/en/users/adithyodw)  
- **Organization**: Tol Langit Quantitative Research
- **Live Signals**: See links above (MQL5, Myfxbook, SignalStart, ZuluTrade)
- **Issues & Feedback**: GitHub Issues (this repository)

---

## 📜 License

**Copyright © 2026, adithyodw | Tol Langit Quantitative Research**

All rights reserved. This Expert Advisor is provided as-is for educational and live trading purposes. Use at your own risk. Past performance does not guarantee future results.

---

## 🚀 Quick Start Checklist

- [ ] Download `LQS_AI_Integrated.ex5`
- [ ] Place in MetaTrader 5 `Experts` folder
- [ ] Restart MT5
- [ ] Open XAUUSD H1 chart
- [ ] Drag EA onto chart
- [ ] Configure lot mode (recommend AUTO_LOW for first run)
- [ ] Enable autotrade ✅
- [ ] Monitor on [Myfxbook](https://www.myfxbook.com/members/adithyodw) or [MQL5 Signal](https://www.mql5.com/en/signals/1083101)

---

**Version**: 5.0  
**Build Date**: 2026-05-16  
**Status**: Production Ready ✅  
**Validation**: MQL5 Market PASSED ✅
