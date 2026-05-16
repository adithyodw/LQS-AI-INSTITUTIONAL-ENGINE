# Changelog

All notable changes to the LQS-AI Institutional Engine are documented in this file.

---

## [5.0] — 2026-05-16 (Production Release)

### 🎉 Major Features Added

#### AI Decision Layer (NEW)
- 7-feature online logistic regression model
- Shannon entropy market structure quality filter
- Trains incrementally from every closed trade (online learning)
- Confidence scoring system (0-100%)
- Risk multiplier scaling based on confidence

#### External AI Vision Support (NEW)
- Multi-provider support: Claude, GPT-4o, Gemini, DeepSeek, xAI Grok
- Chart screenshot analysis (3-timeframe configuration)
- Base64 encoding and WebRequest integration
- Optional confidence-based trade gating
- Configurable API timeout and rate limiting

#### Flexible Lot Sizing System (REDESIGNED)
- **5 sizing modes**: Auto Low (0.01/$1k), Auto Medium (0.02/$1k), Auto High (0.03/$1k), Fixed, Kelly
- Auto modes use direct equity formula (immune to Kelly multiplier stacking)
- Soft scaling in HVOL regimes (-25% scaling)
- Consecutive loss scaling (-25% per 3+ losses)
- AI confidence-based risk multiplier

#### JSON Trade Journal (NEW)
- Append-mode JSONL format for post-trade analysis
- Captures module scores, AI confidence, regime, P&L, entry/exit times
- Python-ready for ML training and backtesting analysis

#### Robust Position Management Fixes
- **Broker Stops/Freeze-level aware** SL modification gate
- Clamps trailing SL to safe distance (never attempts invalid modifies)
- Detects broker constraints automatically
- Eliminates "Modification failed due to order or position being close to market" errors

### 🐛 Bug Fixes

- Fixed "Lot = 0 / trade skipped" on small accounts — NormLot safety floor ensures minimum lot
- Fixed "Modification failed" errors on SL trailing — broker constraint detection and clamping
- Fixed SL expansion explosion — added InpSLMaxATR hard cap (4.5x ATR default)
- Fixed multiplier stacking — auto lot modes independent of Kelly math

### 🏗️ Architecture Changes

- Integrated CLqsAPIHandler class (~800 lines) for vision API abstraction
- Modular provider support (detects provider from API key format)
- Refactored KellyLot() function to dispatcher pattern (cleaner lot mode logic)
- Enhanced ManageOpenTrade() with broker-level safety gates
- Updated ExecuteEntry() with stops level validation

### 🎯 Validation & Compliance

- ✅ MQL5 Market validation: PASSED (48-trade backtest, EURUSD H1)
- ✅ Non-ASCII character purge: input groups converted to Latin characters only
- ✅ All trade operation errors resolved
- ✅ Institutional audit trail via JSON journal

### 📊 Institutional Branding

- Updated header with institutional attribution
- Author: adithyodw | Tol Langit Quantitative Research
- Profile link: https://www.mql5.com/en/users/adithyodw
- Version: 5.00
- Build: 2026-05-05

---

## [4.0] — Earlier (LQS Institutional Flow Engine)

### Core Modules (v4.0, Unchanged in v5.0)
- **Module A: Liquidity Sweep** — Swing high/low extremes, retracement zones
- **Module B: Order Flow** — Cumulative delta, absorption zones, volume imbalance
- **Module C: AMD Wyckoff** — Accumulation/distribution detection, spring/upthrust, manipulation
- **Module D: Anchored VWAP** — Multi-timeframe volume-weighted averages (Asian, London, NY, Weekly, Daily, Swing)
- **Module E: Volume Profile** — POC, HVN/LVN clusters, range profiles

### Risk Management (v4.0, Enhanced in v5.0)
- Bayesian Kelly criterion (single mode in v4, now one of 5 in v5)
- Entropy-based market structure filter
- Stale trade auto-exit
- Drawdown tracking and daily loss limits
- Breakeven automation + profit lock-in

### Session & Time Filtering
- Asian session (configurable hours)
- London session crossover
- New York session open
- Weekend/holiday protection

---

## [3.0] — Market Release

Initial public release on MQL5 Market as "LQS Institutional Flow Engine v3.0"

---

## Future Roadmap (Planned)

- [ ] **v5.1**: Dashboard real-time update performance optimization
- [ ] **v6.0**: Multi-timeframe entry confirmation (confirm on H4 before H1 entry)
- [ ] **v6.0**: Liquidity analysis visualization (on-chart heatmap)
- [ ] **v6.1**: Equity curve prediction (Fourier analysis)
- [ ] **v7.0**: Ensemble model combining all 4 modules into single Bayesian net

---

## Installation Notes

### From v4.0 to v5.0
- No input parameter deletions (backward compatible)
- New inputs: InpLotMode (default: LOT_AUTO_LOW), AI Vision group, JSON journal toggle
- Recompile required (architecture changes in ManageOpenTrade)
- Backtest results may differ (AI learning, new lot modes, better SL management)

---

## Support

- **Live Signals**: [MQL5](https://www.mql5.com/en/signals/1083101), [Myfxbook](https://www.myfxbook.com/members/adithyodw/tol-langit-v10/8671765), [SignalStart](https://icmarkets.signalstart.com/analysis/tol-langit-v10/232541), [ZuluTrade](https://www.zulutrade.com/trader/417743/trading)
- **Portfolio Dashboard**: [Tol Langit ETF](https://tol-langit-etf.vercel.app/)
- **Issues**: GitHub Issues (this repository)

---

**Date Format**: YYYY-MM-DD  
**Semantic Versioning**: MAJOR.MINOR.PATCH  
**Status**: v5.0 Production Ready ✅
