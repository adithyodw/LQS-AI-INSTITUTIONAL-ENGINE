//+------------------------------------------------------------------+
//|                                                                  |
//|          ██╗      ██████╗ ███████╗                               |
//|          ██║     ██╔═══██╗██╔════╝                               |
//|          ██║     ██║   ██║███████╗                               |
//|          ██║     ██║▄▄ ██║╚════██║                               |
//|          ███████╗╚██████╔╝███████║                               |
//|          ╚══════╝ ╚══▀▀═╝ ╚══════╝                               |
//|                                                                  |
//|   LQS-AI  INSTITUTIONAL  ENGINE  ·  v5.0                        |
//|   ──────────────────────────────────────────────────────────     |
//|   Instrument  :  XAUUSD  (Gold Spot)  ·  H1 Primary             |
//|   Architecture:  3-Layer Modular  —  No Curve-Fit                |
//|                                                                  |
//|   [ MODULE 1 ]  LQS-AMD-VWAP v4.0                               |
//|                 Wyckoff Phase Engine · Volume Profile            |
//|                 Anchored VWAP · Order Flow Divergence            |
//|                                                                  |
//|   [ MODULE 2 ]  AI Decision Layer                                |
//|                 7-Feature Online Logistic Regression             |
//|                 Shannon Entropy · Bayesian Kelly Sizing          |
//|                 Local model — zero API / network dependency      |
//|                                                                  |
//|   [ MODULE 3 ]  JSON Data Interface                              |
//|                 Append-mode JSONL journal · Python-ready         |
//|                 In-house CLqsJson (no external libs)             |
//|                                                                  |
//|   ──────────────────────────────────────────────────────────     |
//|   IMPORTANT:  AI acts as DECISION FILTER + RISK MODULATOR.      |
//|               It never selects direction or opens trades.        |
//|   ──────────────────────────────────────────────────────────     |
//|                                                                  |
//|   Author   :  adithyodw                                         |
//|   Profile  :  https://www.mql5.com/en/users/adithyodw           |
//|   Firm     :  Tol Langit Quantitative Research                   |
//|   Build    :  2026.05.05  ·  MQL5 / MetaTrader 5                |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, adithyodw | Tol Langit Quantitative Research"
#property link        "https://www.mql5.com/en/users/adithyodw"
#property version     "5.00"
#property strict
#property description "LQS-AI v5.0 | XAUUSD H1 | AI-Filtered Institutional Flow Engine | by adithyodw"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>

//+------------------------------------------------------------------+
input group "=== SESSION & TIME ==="
input int    InpStartHour      = 1;
input int    InpEndHour        = 23;
input bool   InpUseAsianSess   = true;
input int    InpAsianStart     = 0;
input int    InpAsianEnd       = 8;
input int    InpLondonHour     = 7;
input int    InpNYHour         = 13;
input bool   InpNoWeekend      = true;
input int    InpTimerSecs      = 60;

input group "=== MODULE A: LIQUIDITY SWEEP ==="
input bool   InpUsePrevDayHL   = true;
input bool   InpUseRoundNums   = true;
input double InpRoundStep      = 50.0;
input int    InpSweepWickPct   = 10;
input double InpSweepRetracePct= 40.0;
input int    InpSweepConfBars  = 1;
input double InpSweepVolMult   = 1.0;
input int    InpLiqLookback    = 30;
input int    InpSweepMaxAge    = 20;
input double InpSweepDepthMin  = 0.0005;
input int    InpMultiSweepBars = 8;

input group "=== MODULE B: ORDER FLOW ==="
input int    InpDeltaLookback  = 40;
input double InpDivergThresh   = 8.0;
input int    InpAbsorbBars     = 3;
input double InpAbsorbVolMult  = 1.2;
input double InpAbsorbMaxMove  = 0.6;

input group "=== MODULE C: AMD WYCKOFF ==="
input int    InpAccumLookback  = 20;
input double InpAccumRangeRatio= 10.0;
input double InpSpringMult     = 0.5;
input double InpUpthrustMult   = 0.5;
input double InpManipVolMult   = 1.1;
input double InpCOPressMin     = 40.0;
input double InpVAPct          = 70.0;
input double InpADLPeriod      = 15.0;
input double InpPhaseDurMin    = 1.0;

input group "=== MODULE D: ANCHORED VWAP ==="
input bool   InpVWAP_Asian     = true;
input bool   InpVWAP_London    = true;
input bool   InpVWAP_NY        = true;
input bool   InpVWAP_Week      = true;
input bool   InpVWAP_Day       = true;
input bool   InpVWAP_Swing     = true;
input bool   InpVWAP_POC       = false;
input int    InpVWAP_MaxBars   = 300;
input double InpVWAP_ClsDist   = 1.5;
input int    InpVWAP_ClsMin    = 2;
input double InpVWAP_DevThresh = 1.5;
input double InpVWAP_LevelTol  = 1.0;
input int    InpVWAP_SlopeLen  = 8;

input group "=== MODULE E: VOLUME PROFILE ==="
input int    InpVP_Buckets     = 60;
input int    InpVP_RollingLen  = 40;
input double InpVP_HVN_Pct     = 70.0;
input double InpVP_LVN_Pct     = 30.0;
input int    InpVP_MaxHVN      = 5;
input int    InpVP_MaxLVN      = 5;
input double InpVP_POC_Tol     = 1.0;
input double InpVP_VAL_Tol     = 1.0;

input group "=== SIGNAL FUSION ==="
input double InpScoreEntry     = 45.0;
input int    InpMinModules     = 2;
input double InpModuleMinScore = 20.0;
input double InpWt_A           = 40.0;
input double InpWt_B           = 20.0;
input double InpWt_C           = 20.0;
input double InpWt_D           = 10.0;
input double InpWt_E           = 10.0;
input bool   InpAdaptWeights   = false;
input int    InpMLHistory      = 30;
input bool   InpUseTrendFilter = true;
input double InpEntropyThresh  = 0.15;

input group "=== MULTI-TIMEFRAME ==="
input bool   InpUseMTF         = false;
input int    InpEntryTF        = 2;
input int    InpHTF_Input      = 0;
input double InpMTFMult        = 1.1;

input group "=== MARKET REGIME ==="
input int    InpRegimeLB       = 40;
input double InpTrendADX       = 20.0;
input double InpStrongADX      = 35.0;
input double InpVolPctile      = 75.0;

input group "=== RISK MANAGEMENT - LOT SIZING ==="
// ─── Lot Mode ────────────────────────────────────────────────────────────────
// AUTO LOW    = 0.01 lot per $1,000 equity  (safest, suits small accounts)
// AUTO MEDIUM = 0.02 lot per $1,000 equity  (balanced)
// AUTO HIGH   = 0.03 lot per $1,000 equity  (aggressive)
// FIXED LOT   = always use InpFixedLot value (simplest for backtesting)
// KELLY       = Bayesian Kelly criterion (advanced, needs 15+ trades to calibrate)
enum ENUM_LOT_MODE { LOT_AUTO_LOW=0, LOT_AUTO_MED=1, LOT_AUTO_HIGH=2, LOT_FIXED=3, LOT_KELLY=4 };
input ENUM_LOT_MODE InpLotMode  = LOT_AUTO_LOW; // Lot Sizing Mode
input double InpFixedLot        = 0.01;          // Fixed Lot (only used when LOT_FIXED selected)
// ─── Kelly settings (only used when LOT_KELLY selected) ──────────────────────
input double InpKellyFrac      = 0.25;   // Kelly fraction (0.25 = quarter-Kelly, conservative)
input double InpRiskMax        = 3.0;    // Kelly max risk per trade (%)
input double InpRiskMin        = 1.0;    // Kelly min risk per trade (%)
input int    InpKellyMinTrades = 15;     // Trades before Kelly activates (uses InpRiskMin until then)
// ─── SL / TP ─────────────────────────────────────────────────────────────────
input double InpSL_ATR         = 2.0;   // Stop Loss distance (x ATR)
input double InpSLMaxATR       = 4.5;   // SL hard cap (x ATR) - prevents sweep explosion
input double InpTP1_ATR        = 1.5;   // TP1 distance (x ATR)
input double InpTP2_ATR        = 3.0;   // TP2 distance (x ATR)
input double InpTP3_ATR        = 5.0;   // TP3 distance (x ATR)
input double InpTP1_Pct        = 33.0;  // Close % at TP1
input double InpTP2_Pct        = 33.0;  // Close % at TP2
// ─── Daily / drawdown limits ─────────────────────────────────────────────────
input double InpDailyLossLim   = 5.0;   // Daily loss limit (% of equity)
input double InpDailyProfLock  = 10.0;  // Daily profit lock (% of equity)
input int    InpMaxOpen        = 1;     // Max simultaneous positions
input int    InpMaxDailyTrades = 5;     // Max trades per day
input double InpMaxSpread      = 200.0; // Max spread allowed (points)
input double InpSlippage       = 10.0;  // Max slippage (points)
input int    InpCooldownBars   = 3;     // Cooldown bars after a close
input double InpMaxDDPct       = 8.0;   // Max total drawdown (%)
input double InpRegimeRiskMult = 0.6;   // Risk multiplier in high-vol regime (Kelly only)
input int    InpStaleExitBars  = 12;    // Exit if no TP1 after N bars
input double InpConsecutiveLossScale = 0.5; // Risk scale after 3 consecutive losses (Kelly only)

input group "=== BREAKEVEN & TRAILING ==="
input bool   InpUseBE          = true;
input double InpBE_RMult       = 1.0;
input bool   InpUseTrail       = true;
input double InpTrailStart     = 2.0;
input double InpTrailATR       = 1.0;

input group "=== NEWS FILTER ==="
input bool   InpUseNews        = false;
input int    InpNewsBefore     = 30;
input int    InpNewsAfter      = 15;
input bool   InpNewsHighOnly   = true;
input bool   InpNewsUSD        = true;
input bool   InpNewsEUR        = false;
input int    InpNewsScan       = 10;

input group "=== AI DECISION LAYER ==="
input bool   InpUseAI            = true;     // Enable AI confidence filter
input bool   InpAIBlockOnLow     = true;     // Block trade entry if AI confidence below threshold
input double InpAIMinConf        = 55.0;     // Min AI confidence to allow trade (0-100)
input double InpAIBoostThresh    = 80.0;     // AI confidence above this = scale risk UP
input double InpAIBoostMult      = 1.25;     // Risk multiplier when above boost threshold
input double InpAIDampMult       = 0.80;     // Risk multiplier when AI conf < boost but >= min
input int    InpAILearnTrades    = 10;       // Min completed trades before AI is allowed to gate
input double InpAILearnRate      = 0.04;     // Online learning rate (gradient step)
input double InpAIInitWeight     = 0.143;    // Initial weight per feature (~1/7)
input bool   InpAIVerbose        = false;    // Verbose AI logging

input group "=== AI DATA INTERFACE (JSON JOURNAL) ==="
input bool   InpAIWriteJson      = false;    // Write JSON snapshots to file (MQL5/Files)
input string InpAIJsonFile       = "LQS_AI_Journal.jsonl"; // Append-mode journal file
input bool   InpAIJsonOnTick     = false;    // Write a market snapshot every bar (heavy)

input group "=== AI VISION - EXTERNAL API (Claude / GPT / Gemini / DeepSeek / xAI) ==="
input bool   InpUseAPIVision      = false;   // Enable AI Vision (requires API key + WebRequest allowed)
input string InpAPIKey            = "";       // API Key - sk-ant-... | sk-... | AI... | xai-...
input string InpProviderOverride  = "auto";  // Provider: auto | anthropic | openai | google | deepseek | xai
input int    InpMinAPIConf        = 65;       // Min AI Vision confidence to allow trade (0-100)
input int    InpAPITimeoutSec     = 30;       // WebRequest timeout (seconds)
input int    InpAPIScanSec        = 300;      // Min seconds between API calls (rate limiter)
input int    InpChartWidth        = 1920;     // Screenshot width (px)
input int    InpChartHeight       = 1080;     // Screenshot height (px)
input int    InpChartBars         = 200;      // Bars visible in screenshot

input group "=== VISUALIZATION ==="
input bool   InpShowDash       = true;
input bool   InpDrawLevels     = false;
input bool   InpDrawPhase      = false;
input bool   InpDrawVWAP       = false;
input bool   InpDrawVP         = false;
input int    InpDashX          = 12;
input int    InpDashY          = 18;
input int    InpDashW          = 332;
input color  InpClrBg          = clrMidnightBlue;
input color  InpClrHeader      = clrGold;
input color  InpClrBuy         = clrLimeGreen;
input color  InpClrSell        = clrOrangeRed;
input color  InpClrWarn        = clrYellow;
input color  InpClrData        = clrSilver;
input color  InpClrBorder      = clrSteelBlue;
input color  InpClrNeutral     = clrDimGray;
input color  InpClrLevel       = clrAqua;
input color  InpClrVWAP_As     = clrCyan;
input color  InpClrVWAP_Ln     = clrYellow;
input color  InpClrVWAP_NY     = clrOrangeRed;
input color  InpClrVWAP_Wk     = clrLimeGreen;
input color  InpClrVWAP_Dy     = clrSilver;
input color  InpClrVWAP_Sw     = clrPlum;
input color  InpClrPOC         = clrGold;
input color  InpClrVAH         = clrCornflowerBlue;
input color  InpClrHVN         = clrForestGreen;
input color  InpClrLVN         = clrFireBrick;
input color  InpClrPhase       = clrOrange;
input string InpFont           = "Courier New";

input group "=== SYSTEM ==="
input long   InpMagic          = 520500;
input string InpCmt            = "LQSAI5";
input bool   InpVerbose        = false;
input bool   InpOptimMode      = false;

//+------------------------------------------------------------------+
enum ENUM_AMD_PHASE  { AMD_UNDEFINED=0, AMD_ACCUMULATION=1, AMD_MANIPULATION=2,
                       AMD_DISTRIBUTION=3, AMD_MARKUP=4, AMD_MARKDOWN=5 };
enum ENUM_SWEEP_TYPE { SWEEP_NONE=0, SWEEP_HIGH=1, SWEEP_LOW=2 };
enum ENUM_DIRECTION  { DIR_NONE=0, DIR_LONG=1, DIR_SHORT=-1 };
enum ENUM_REGIME     { REGIME_STRONG=0, REGIME_WEAK=1, REGIME_RANGE=2, REGIME_HVOL=3 };
enum ENUM_EA_STATE   { ST_IDLE=0, ST_SWEEP=1, ST_OFR=2, ST_AMD=3,
                       ST_VWAP=4, ST_READY=5, ST_TRADE=6, ST_LOCK=7, ST_NEWS=8 };

#define VA_ASIAN  0
#define VA_LONDON 1
#define VA_NY     2
#define VA_WEEK   3
#define VA_DAY    4
#define VA_SWING  5
#define VA_POC_A  6
#define MAX_VA    7

#define AI_FEATS  7
#define AI_HIST   200

//+------------------------------------------------------------------+
struct SLiqLevel { double price; string label; datetime time; int dir; bool swept; bool active; };
struct SSweep
  { bool active; ENUM_SWEEP_TYPE type; double level,extreme,closeAfter,depthRatio;
    double reversalStr,volRatio,wickPct,deltaAtSweep,score;
    datetime sweepTime; int barsAgo; bool isMulti; int sweepCount; };
struct SOFR
  { double cumDelta,absorptionScore,buyPressure,sellPressure,pressureFast,pressureSlow;
    double ofImbalance,deltaMomentum,exhaustionScore,vwapDeltaDiff,score;
    bool bullDiv,bearDiv; datetime divTime; double divergencePct; };
struct SAMD
  { ENUM_AMD_PHASE phase,prevPhase; double confidence,co,cog,adl,rangeHigh,rangeLow,rangeMid;
    double coBull,coBear,manipScore,score; int duration;
    bool spring,upthrust,endManip,volClimax; ENUM_DIRECTION dir; datetime phaseStart; };
struct SVWAPState
  { bool active,priceAbove,rejection; datetime anchorTime; double value,upperSD1,lowerSD1;
    double upperSD2,lowerSD2,devSigma,slope,distATR; int touches; };
struct SVNode { double price,volume,pct; int bucket; };
struct SSignal
  { double total,sA,sB,sC,sD,sE,entry,sl,tp1,tp2,tp3,lot;
    bool valid; ENUM_DIRECTION dir; int modulesConf; string desc; datetime sigTime; };
struct STrade { bool wasWin; double rMult,score,sA,sB,sC,sD,sE; datetime time; };
struct SNews  { datetime evtTime; string country,name; int imp; bool blocking; };

// AI structs
struct SAIFeatures
  { double regimeAlign;     // direction matches regime bias
    double moduleAgreement; // ratio of confirmed modules
    double similarity;      // weighted historical similarity
    double volNormal;       // volatility normality (sweet-spot near median)
    double entropyQuality;  // market structure quality
    double vwapProx;        // proximity to VWAP cluster (mean reversion)
    double timeBias;        // session/hour historical bias
  };
struct SAIState
  { double confidence;          // 0..100
    double regimeScore;         // 0..100
    double volScore;            // 0..100
    double baseScore;           // unfiltered fused score copy
    double weights[AI_FEATS];   // online-learned weights
    double feats[AI_FEATS];     // last computed features
    ENUM_DIRECTION verdict;     // mirrors fusion direction (AI never picks dir)
    bool valid;                 // ready for use
    datetime stamp;             // last update time
    int trainedTrades;          // total trades observed
    double avgConf;             // running average of last N confs
  };
struct SAIPattern
  { double feats[AI_FEATS];
    double rMult;
    bool win;
    ENUM_DIRECTION dir;
    datetime t;
    bool used;
  };

//+------------------------------------------------------------------+
//| External AI Vision — provider + result structs                   |
//+------------------------------------------------------------------+
enum ENUM_LQS_PROVIDER
  { LQS_PROV_UNKNOWN   = 0, // Unknown / not set
    LQS_PROV_ANTHROPIC = 1, // Anthropic  (Claude)
    LQS_PROV_OPENAI    = 2, // OpenAI     (GPT-4o)
    LQS_PROV_GOOGLE    = 3, // Google     (Gemini)
    LQS_PROV_DEEPSEEK  = 4, // DeepSeek
    LQS_PROV_XAI       = 5  // xAI        (Grok)
  };

struct SAPIResult
  { ENUM_LQS_PROVIDER provider;
    string            modelName;
    int               confidence;  // 0-100 from AI
    ENUM_DIRECTION    direction;   // DIR_LONG / DIR_SHORT / DIR_NONE
    double            slPrice;     // AI-suggested SL (0 = use LQS SL)
    double            tpPrice;     // AI-suggested TP (0 = use LQS TP)
    string            reason;      // AI explanation text
    bool              valid;       // true after at least one successful call
    datetime          stamp;       // time of last successful call
    int               callsToday;
    string            lastStatus;
    void Reset()
      { confidence=0; direction=DIR_NONE; slPrice=0; tpPrice=0;
        reason=""; valid=false; lastStatus="Not called"; }
  };

//+------------------------------------------------------------------+
CTrade g_tr; CPositionInfo g_pos; CSymbolInfo g_sym;
int g_hATR,g_hADX,g_hATR_H,g_hVol,g_hVol_H,g_hEMA_F,g_hEMA_S;
ENUM_TIMEFRAMES g_tfE,g_tfH;
ENUM_EA_STATE g_state=ST_IDLE;
ENUM_REGIME   g_regime=REGIME_RANGE;

SSweep  g_sw;
SOFR    g_ofr;
SAMD    g_amd;
SSignal g_sig;

SVWAPState g_vaArr[MAX_VA];
double g_vwClusterPrice=0,g_vwClusterStrength=0,g_vwDevScore=0,g_vwAlignedDist=1e9,g_vwScore=0;
int    g_vwClusterCount=0,g_vwActiveCount=0;
bool   g_vwAlignedAtLevel=false;
double g_vwPV[MAX_VA],g_vwV[MAX_VA],g_vwPV2[MAX_VA];
int    g_vwBars[MAX_VA];
bool   g_vwOn[MAX_VA];
double g_vwPrevVals[MAX_VA];

#define BMAX 100
double g_bVol[BMAX];
double g_vpPOC=0,g_vpVAH=0,g_vpVAL=0,g_vpMigr=0,g_vpPrevPOC=0,g_vpTotalVol=0,g_vpVaWidth=0;
bool   g_vpPocNearSweep=false,g_vpVahNearSweep=false,g_vpLvnBeyond=false;
double g_vpAbsAtLvl=0,g_vpScore=0;
SVNode g_vpHVN[5],g_vpLVN[5];
int    g_vpHVNCount=0,g_vpLVNCount=0;

#define MAX_LIQ 40
SLiqLevel g_liq[MAX_LIQ];
int       g_liqN=0;

int    g_curDay=-1;
bool   g_locked=false;
double g_startEq=0.0;
int    g_tradesDay=0;
double g_dayPnL=0.0;
double g_dayRealizedPnL=0.0;
double g_asianH=-1e9,g_asianL=1e9;
bool   g_asianOK=false;
datetime g_asianDt=0;
double g_londonOp=0,g_nyOp=0,g_weekOp=0,g_dayOp=0;
datetime g_londonDt=0,g_nyDt=0,g_weekDt=0,g_dayDt=0;

#define DMAX 150
double g_dH[DMAX],g_pH[DMAX],g_vH[DMAX];
int    g_dIdx=0; bool g_dFull=false;
double g_barDelta=0;
int    g_barCnt=0;
datetime g_lastBarT=0;

#define NMAX 30
SNews    g_news[NMAX];
int      g_newsN=0;
datetime g_lastScan=0;
bool     g_newsBlk=false;
string   g_blkEvt="";
datetime g_blkTime=0;

#define TRMAX 120
STrade g_trHist[TRMAX];
int    g_trIdx=0,g_trN=0;
double g_kWR=0.5,g_kAW=2.0,g_kAL=1.0;
double g_wA=40,g_wB=20,g_wC=20,g_wD=10,g_wE=10;
int    g_consecLoss=0;

datetime g_lastTradeClose=0;
double g_peakEquity=0;
double g_dayPeakEquity=0;
ulong  g_ticket=0;
double g_opEntry=0,g_opSL=0,g_opTP1=0,g_opTP2=0,g_opTP3=0,g_opLot=0,g_opScore=0;
ENUM_DIRECTION g_opDir=DIR_NONE;
bool   g_tp1Hit=false,g_tp2Hit=false,g_beSet=false;
datetime g_opOpenTime=0;
double g_ATR=0,g_ADX=0;
double g_entropy=0;
bool   g_dashOK=false;
datetime g_lastDash=0;
bool   g_quiet=false;

// AI globals
SAIState   g_ai;
SAIPattern g_aiHist[AI_HIST];
int        g_aiN=0,g_aiIdx=0;
datetime   g_aiLastBar=0;
double     g_aiOpenFeats[AI_FEATS]; // snapshot at trade open for outcome learning
ENUM_DIRECTION g_aiOpenDir=DIR_NONE;
double     g_aiOpenConf=0;

// External AI Vision globals
SAPIResult g_apiVis;        // last API vision result
datetime   g_lastAPICall=0; // throttle: last time we called the API
bool       g_apiReady=false; // true after Init confirmed API key + provider OK

#define DPFX  "LQS5_"
#define DASH_H 1010
#define RY_H1   0
#define RY_H2  17
#define RY_ST  37
#define RY_SC  55
#define RY_A0  75
#define RY_AT  91
#define RY_AS 107
#define RY_B0 125
#define RY_BC 141
#define RY_BD 157
#define RY_BS 173
#define RY_C0 191
#define RY_CP 207
#define RY_CS 223
#define RY_CR 239
#define RY_D0 257
#define RY_DC 273
#define RY_DS 289
#define RY_E0 307
#define RY_EP 323
#define RY_ES 339
#define RY_N0 357
#define RY_ND 373
#define RY_NL 389
#define RY_NS 405
#define RY_NR 421
#define RY_SE 439
#define RY_SP 455
#define RY_MK 473
#define RY_MB 489
#define RY_MS 505
#define RY_KL 523
#define RY_WT 539
#define RY_VR 557
#define RY_V2 573
#define RY_AI0 591
#define RY_AI1 607
#define RY_AI2 623

//+------------------------------------------------------------------+
//| Lightweight in-house JSON writer (no external library required)  |
//| Supports flat key/value objects — sufficient for journal records |
//+------------------------------------------------------------------+
class CLqsJson
  {
private:
   string m_buf;
   bool   m_first;
   string Esc(const string s)
     { string r=s;
       StringReplace(r,"\\","\\\\");
       StringReplace(r,"\"","\\\"");
       StringReplace(r,"\n","\\n");
       StringReplace(r,"\r","\\r");
       StringReplace(r,"\t","\\t");
       return r; }
   void Comma() { if(!m_first) m_buf+=","; m_first=false; }
public:
   void Begin() { m_buf="{"; m_first=true; }
   void KStr(const string k,const string v)
     { Comma(); m_buf+="\""+Esc(k)+"\":\""+Esc(v)+"\""; }
   void KDbl(const string k,const double v,const int digits=6)
     { Comma(); m_buf+="\""+Esc(k)+"\":"+DoubleToString(v,digits); }
   void KInt(const string k,const long v)
     { Comma(); m_buf+="\""+Esc(k)+"\":"+IntegerToString(v); }
   void KBool(const string k,const bool v)
     { Comma(); m_buf+="\""+Esc(k)+"\":"+(v?"true":"false"); }
   void KArrDbl(const string k,const double &arr[],const int digits=4)
     { Comma(); m_buf+="\""+Esc(k)+"\":[";
       int n=ArraySize(arr);
       for(int i=0;i<n;i++){ if(i>0) m_buf+=","; m_buf+=DoubleToString(arr[i],digits); }
       m_buf+="]"; }
   string End() { return m_buf+"}"; }
  };

bool JournalAppend(const string line)
  { if(!InpAIWriteJson) return false;
    int h=FileOpen(InpAIJsonFile,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(h==INVALID_HANDLE) h=FileOpen(InpAIJsonFile,FILE_WRITE|FILE_TXT|FILE_ANSI);
    if(h==INVALID_HANDLE){ Print("[LQS5][JSON] open fail err=",GetLastError()); return false; }
    FileSeek(h,0,SEEK_END);
    FileWriteString(h,line+"\n");
    FileClose(h);
    return true; }

//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING DetectFillType()
  {long fm=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((fm&SYMBOL_FILLING_FOK)!=0) return ORDER_FILLING_FOK;
   if((fm&SYMBOL_FILLING_IOC)!=0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;}
//+------------------------------------------------------------------+
void VA_Reset(int idx,datetime t)
  { g_vwPV[idx]=0;g_vwV[idx]=0;g_vwPV2[idx]=0;g_vwBars[idx]=0;
    g_vwPrevVals[idx]=0;
    g_vaArr[idx].active=true;g_vaArr[idx].anchorTime=t;g_vaArr[idx].value=0;
    g_vaArr[idx].upperSD1=0;g_vaArr[idx].lowerSD1=0;
    g_vaArr[idx].upperSD2=0;g_vaArr[idx].lowerSD2=0;
    g_vaArr[idx].devSigma=0;g_vaArr[idx].slope=0;
    g_vaArr[idx].priceAbove=false;g_vaArr[idx].rejection=false;
    g_vaArr[idx].touches=0;g_vaArr[idx].distATR=0; }

//+=================================================================+
//|  EXTERNAL AI VISION — Full API Layer (Claude/GPT/Gemini/etc.)  |
//|  Ported from Prime Quantum AI v3.21 — adapted for LQS v5.0     |
//|  SETUP: Tools > Options > Expert Advisors > Allow WebRequest   |
//|  Add URLs: https://api.anthropic.com  https://api.openai.com   |
//|            https://generativelanguage.googleapis.com            |
//|            https://api.deepseek.com   https://api.x.ai          |
//+=================================================================+
#define LQS_URL_ANTHROPIC "https://api.anthropic.com/v1/messages"
#define LQS_URL_OPENAI    "https://api.openai.com/v1/chat/completions"
#define LQS_URL_GOOGLE    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
#define LQS_URL_DEEPSEEK  "https://api.deepseek.com/v1/chat/completions"
#define LQS_URL_XAI       "https://api.x.ai/v1/chat/completions"

#define LQS_MODEL_ANTHROPIC "claude-sonnet-4-20250514"
#define LQS_MODEL_OPENAI    "gpt-4o"
#define LQS_MODEL_GOOGLE    "gemini-2.0-flash"
#define LQS_MODEL_DEEPSEEK  "deepseek-chat"
#define LQS_MODEL_XAI       "grok-2-vision"

//--- Helper: timeframe name string
string API_TFName(ENUM_TIMEFRAMES tf)
  { switch(tf)
      { case PERIOD_M1:  return "M1";  case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15"; case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";  case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";  case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1"; default:         return "CURRENT"; } }

//--- Helper: pick 3 screenshot timeframes from entry TF
void API_GetScreenshotTFs(ENUM_TIMEFRAMES entryTF,
                          ENUM_TIMEFRAMES &tfE,
                          ENUM_TIMEFRAMES &tfM,
                          ENUM_TIMEFRAMES &tfH)
  { switch(entryTF)
      { case PERIOD_M1:  tfE=PERIOD_M1;  tfM=PERIOD_M15; tfH=PERIOD_H1;  break;
        case PERIOD_M5:  tfE=PERIOD_M5;  tfM=PERIOD_M30; tfH=PERIOD_H1;  break;
        case PERIOD_M15: tfE=PERIOD_M15; tfM=PERIOD_H1;  tfH=PERIOD_H4;  break;
        case PERIOD_M30: tfE=PERIOD_M30; tfM=PERIOD_H4;  tfH=PERIOD_D1;  break;
        case PERIOD_H1:  tfE=PERIOD_H1;  tfM=PERIOD_H4;  tfH=PERIOD_D1;  break;
        case PERIOD_H4:  tfE=PERIOD_H4;  tfM=PERIOD_D1;  tfH=PERIOD_W1;  break;
        case PERIOD_D1:  tfE=PERIOD_D1;  tfM=PERIOD_W1;  tfH=PERIOD_MN1; break;
        default:         tfE=PERIOD_H1;  tfM=PERIOD_H4;  tfH=PERIOD_D1;  break; } }

class CLqsAPIHandler
  {
private:
   string            m_apiKey;
   ENUM_LQS_PROVIDER m_provider;
   string            m_modelName;
   string            m_apiURL;
   int               m_timeoutSec;
   int               m_chartW, m_chartH, m_chartBars;
   int               m_callsToday;
   datetime          m_lastCallDay;

   //--- Detect provider from key prefix / override string
   ENUM_LQS_PROVIDER DetectProvider(const string key, const string over)
     { string sel=over; StringToLower(sel);
       if(sel=="anthropic") return LQS_PROV_ANTHROPIC;
       if(sel=="openai")    return LQS_PROV_OPENAI;
       if(sel=="google")    return LQS_PROV_GOOGLE;
       if(sel=="deepseek")  return LQS_PROV_DEEPSEEK;
       if(sel=="xai")       return LQS_PROV_XAI;
       if(StringFind(key,"sk-ant-")==0)              return LQS_PROV_ANTHROPIC;
       if(StringFind(key,"xai-")==0)                 return LQS_PROV_XAI;
       if(StringFind(key,"AI")==0)                   return LQS_PROV_GOOGLE;
       if(StringFind(key,"sk-proj-")==0||StringLen(key)>80) return LQS_PROV_OPENAI;
       if(StringFind(key,"sk-")==0)                  return LQS_PROV_OPENAI;
       return LQS_PROV_UNKNOWN; }

   //--- Escape JSON string
   string JEsc(const string s)
     { string r=s;
       StringReplace(r,"\\","\\\\"); StringReplace(r,"\"","\\\"");
       StringReplace(r,"\n","\\n");  StringReplace(r,"\r","\\r");
       StringReplace(r,"\t","\\t");
       return r; }

   //--- Read file and base64-encode it
   string FileToB64(const string fname)
     { int h=FileOpen(fname,FILE_READ|FILE_BIN);
       if(h==INVALID_HANDLE) return "";
       ulong sz=FileSize(h); if(sz==0){FileClose(h);return "";}
       uchar raw[]; ArrayResize(raw,(int)sz);
       uint got=FileReadArray(h,raw,0,(int)sz); FileClose(h);
       if(got!=(uint)sz) return "";
       uchar key[],enc[];
       if(CryptEncode(CRYPT_BASE64,raw,key,enc)<=0) return "";
       string b64=CharArrayToString(enc);
       StringReplace(b64,"\n",""); StringReplace(b64,"\r",""); StringReplace(b64," ","");
       return b64; }

   //--- Take a chart screenshot and save to MQL5/Files/
   bool TakeScreenshot(ENUM_TIMEFRAMES tf, const string fname)
     { long cid=ChartOpen(_Symbol,tf);
       if(cid<=0) return false;
       ChartSetInteger(cid,CHART_SHOW_GRID,false);
       ChartSetInteger(cid,CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE);
       ChartSetInteger(cid,CHART_MODE,CHART_CANDLES);
       ChartSetInteger(cid,CHART_COLOR_BACKGROUND,C'10,14,28');
       ChartSetInteger(cid,CHART_COLOR_FOREGROUND,clrWhite);
       ChartSetInteger(cid,CHART_COLOR_CANDLE_BULL,C'46,204,113');
       ChartSetInteger(cid,CHART_COLOR_CANDLE_BEAR,C'231,76,60');
       ChartSetInteger(cid,CHART_COLOR_CHART_UP,C'46,204,113');
       ChartSetInteger(cid,CHART_COLOR_CHART_DOWN,C'231,76,60');
       ChartSetInteger(cid,CHART_COLOR_GRID,C'30,35,55');
       ChartSetInteger(cid,CHART_AUTOSCROLL,true);
       ChartSetInteger(cid,CHART_WIDTH_IN_BARS,m_chartBars);
       ChartRedraw(cid);
       Sleep(2500);
       bool ok=ChartScreenShot(cid,fname,m_chartW,m_chartH,ALIGN_RIGHT);
       ChartClose(cid);
       return ok; }

   //--- Build provider-specific JSON payload
   string BuildPayload(const string b64E,const string b64M,const string b64H,
                       ENUM_DIRECTION lqsDir)
     { string dirStr=(lqsDir==DIR_LONG)?"BULLISH":"BEARISH";
       double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
       int    digs=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
       string uPrompt=StringFormat(
          "Symbol:%s Price:%s LQS pre-filter:%s. Chart1=%s(entry) Chart2=%s(mid) Chart3=%s(HTF). "
          "Confirm whether we should %s. Respond ONLY in JSON: "
          "{\"direction\":\"BUY\" or \"SELL\" or \"NONE\","
          "\"confidence\":0-100,"
          "\"sl\":exact_price_or_0,"
          "\"tp\":exact_price_or_0,"
          "\"reason\":\"max 120 chars\"}",
          _Symbol,DoubleToString(bid,digs),dirStr,
          API_TFName(_Period),API_TFName(PERIOD_H4),API_TFName(PERIOD_D1),
          (lqsDir==DIR_LONG)?"BUY":"SELL");
       string sysPrompt=
          "You are an expert gold/forex technical analyst integrated into an institutional trading robot. "
          "You receive 3 chart screenshots (entry TF, confirmation TF, HTF context). "
          "Analyse market structure, S/R zones, candlestick patterns, and trend bias. "
          "The pre-filter bias is already calculated by the robot — confirm or deny it. "
          "Confidence: 90-100=textbook setup, 70-89=good, 50-69=marginal, <50=skip. "
          "Respond ONLY with the JSON object — no extra text.";
       string j="";
       switch(m_provider)
         { case LQS_PROV_ANTHROPIC:
              j="{\"model\":\""+m_modelName+"\",\"max_tokens\":256,";
              j+="\"system\":\""+JEsc(sysPrompt)+"\",";
              j+="\"messages\":[{\"role\":\"user\",\"content\":[";
              j+="{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\""+b64E+"\"}},";
              j+="{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\""+b64M+"\"}},";
              j+="{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\""+b64H+"\"}},";
              j+="{\"type\":\"text\",\"text\":\""+JEsc(uPrompt)+"\"}]}]}";
              break;
           case LQS_PROV_OPENAI: case LQS_PROV_DEEPSEEK: case LQS_PROV_XAI:
              j="{\"model\":\""+m_modelName+"\",\"max_tokens\":256,";
              j+="\"messages\":[{\"role\":\"system\",\"content\":\""+JEsc(sysPrompt)+"\"},";
              j+="{\"role\":\"user\",\"content\":[";
              j+="{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64,"+b64E+"\"}},";
              j+="{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64,"+b64M+"\"}},";
              j+="{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64,"+b64H+"\"}},";
              j+="{\"type\":\"text\",\"text\":\""+JEsc(uPrompt)+"\"}]}]}";
              break;
           case LQS_PROV_GOOGLE:
              j="{\"contents\":[{\"parts\":[";
              j+="{\"inline_data\":{\"mime_type\":\"image/png\",\"data\":\""+b64E+"\"}},";
              j+="{\"inline_data\":{\"mime_type\":\"image/png\",\"data\":\""+b64M+"\"}},";
              j+="{\"inline_data\":{\"mime_type\":\"image/png\",\"data\":\""+b64H+"\"}},";
              j+="{\"text\":\""+JEsc(sysPrompt+" "+uPrompt)+"\"}]}]}";
              break;
           default: break; }
       return j; }

   //--- Build HTTP headers per provider
   string BuildHeaders()
     { string h="Content-Type: application/json\r\n";
       switch(m_provider)
         { case LQS_PROV_ANTHROPIC:
              h+="x-api-key: "+m_apiKey+"\r\n";
              h+="anthropic-version: 2023-06-01\r\n";
              break;
           case LQS_PROV_OPENAI: case LQS_PROV_DEEPSEEK: case LQS_PROV_XAI:
              h+="Authorization: Bearer "+m_apiKey+"\r\n";
              break;
           default: break; }
       return h; }

   //--- Full request URL (Google appends key as query param)
   string RequestURL()
     { if(m_provider==LQS_PROV_GOOGLE) return m_apiURL+"?key="+m_apiKey;
       return m_apiURL; }

   //--- Extract inner text from JSON "text": "..." field
   string ExtractText(const string resp)
     { int p=StringFind(resp,"\"text\":\""); if(p<0) return "";
       p+=8; string r=""; bool esc=false; int len=StringLen(resp);
       for(int i=p;i<len&&i<p+30000;i++)
         { ushort ch=StringGetCharacter(resp,i);
           if(esc){if(ch=='"') r+="\"";else if(ch=='\\') r+="\\";
                   else if(ch=='n') r+="\n"; else r+=CharToString((uchar)ch);
                   esc=false;}
           else{if(ch=='\\'){esc=true;continue;}if(ch=='"')break;
                r+=CharToString((uchar)ch);} }
       return r; }

   //--- Extract string value for a JSON key
   string ExtractStr(const string json,const string key)
     { string s="\""+key+"\":\""; int p=StringFind(json,s);
       if(p<0){s="\""+key+"\": \"";p=StringFind(json,s);}
       if(p<0) return "";
       p+=StringLen(s); string v=""; bool esc=false; int len=StringLen(json);
       for(int i=p;i<len;i++)
         { ushort ch=StringGetCharacter(json,i);
           if(esc){v+=CharToString((uchar)ch);esc=false;continue;}
           if(ch=='\\'){esc=true;continue;}
           if(ch=='"') break;
           v+=CharToString((uchar)ch); }
       return v; }

   //--- Extract int value for a JSON key
   int ExtractInt(const string json,const string key)
     { string s="\""+key+"\":"; int p=StringFind(json,s);
       if(p<0){s="\""+key+"\": ";p=StringFind(json,s);}
       if(p<0) return 0;
       p+=StringLen(s); int len=StringLen(json);
       while(p<len&&StringGetCharacter(json,p)==' ') p++;
       string d="";
       for(int i=p;i<len;i++)
         { ushort ch=StringGetCharacter(json,i);
           if(ch>='0'&&ch<='9') d+=CharToString((uchar)ch);
           else if(d!="") break; }
       return d==""?0:(int)StringToInteger(d); }

   //--- Extract double value for a JSON key
   double ExtractDbl(const string json,const string key)
     { string s="\""+key+"\":"; int p=StringFind(json,s);
       if(p<0){s="\""+key+"\": ";p=StringFind(json,s);}
       if(p<0) return 0;
       p+=StringLen(s); int len=StringLen(json);
       while(p<len&&StringGetCharacter(json,p)==' ') p++;
       string d="";
       for(int i=p;i<len;i++)
         { ushort ch=StringGetCharacter(json,i);
           if((ch>='0'&&ch<='9')||ch=='.'||ch=='-') d+=CharToString((uchar)ch);
           else if(d!="") break; }
       return d==""?0:StringToDouble(d); }

   //--- Parse raw HTTP body into SAPIResult
   bool ParseResponse(const string body, SAPIResult &res)
     { string txt="";
       switch(m_provider)
         { case LQS_PROV_ANTHROPIC: txt=ExtractText(body); break;
           case LQS_PROV_OPENAI: case LQS_PROV_DEEPSEEK: case LQS_PROV_XAI:
              { int cp=StringFind(body,"\"content\":\"");
                txt=(cp>=0)?ExtractText(StringSubstr(body,cp-6)):body; break; }
           case LQS_PROV_GOOGLE: txt=ExtractText(body); break;
           default: txt=body; break; }
       if(txt=="") txt=body;
       Print("[API Vision] Raw: ",StringSubstr(txt,0,300));
       string dirStr=ExtractStr(txt,"direction"); StringToUpper(dirStr);
       if(dirStr=="BUY")       res.direction=DIR_LONG;
       else if(dirStr=="SELL") res.direction=DIR_SHORT;
       else                    res.direction=DIR_NONE;
       res.confidence=ExtractInt(txt,"confidence");
       res.slPrice   =ExtractDbl(txt,"sl");
       res.tpPrice   =ExtractDbl(txt,"tp");
       res.reason    =ExtractStr(txt,"reason");
       if(res.confidence<=0||res.confidence>100) res.confidence=50;
       res.valid=true;
       return true; }

public:
   CLqsAPIHandler() : m_provider(LQS_PROV_UNKNOWN),m_timeoutSec(30),
                      m_chartW(1920),m_chartH(1080),m_chartBars(200),
                      m_callsToday(0),m_lastCallDay(0) {}

   //--- Initialise: detect provider, set URLs/models. Returns false if key empty/unknown.
   bool Init(const string apiKey, const string provOverride,
             int timeoutSec, int chartW, int chartH, int chartBars,
             SAPIResult &res)
     { m_apiKey=apiKey; m_timeoutSec=timeoutSec;
       m_chartW=chartW; m_chartH=chartH; m_chartBars=chartBars;
       if(m_apiKey==""){res.lastStatus="ERROR: API Key is empty";return false;}
       m_provider=DetectProvider(m_apiKey,provOverride);
       if(m_provider==LQS_PROV_UNKNOWN){res.lastStatus="ERROR: Cannot detect provider from key format";return false;}
       switch(m_provider)
         { case LQS_PROV_ANTHROPIC: m_modelName=LQS_MODEL_ANTHROPIC; m_apiURL=LQS_URL_ANTHROPIC; break;
           case LQS_PROV_OPENAI:    m_modelName=LQS_MODEL_OPENAI;    m_apiURL=LQS_URL_OPENAI;    break;
           case LQS_PROV_GOOGLE:    m_modelName=LQS_MODEL_GOOGLE;    m_apiURL=LQS_URL_GOOGLE;    break;
           case LQS_PROV_DEEPSEEK:  m_modelName=LQS_MODEL_DEEPSEEK;  m_apiURL=LQS_URL_DEEPSEEK;  break;
           case LQS_PROV_XAI:       m_modelName=LQS_MODEL_XAI;       m_apiURL=LQS_URL_XAI;       break;
           default: break; }
       res.provider  =m_provider;
       res.modelName =m_modelName;
       res.lastStatus=StringFormat("Ready — %s | Model: %s",EnumToString(m_provider),m_modelName);
       Print("[API Vision] Init OK — Provider:",EnumToString(m_provider)," Model:",m_modelName);
       return true; }

   //--- Main call: take 3 screenshots → base64 → POST → parse → fill SAPIResult
   bool Analyse(ENUM_DIRECTION lqsDir, SAPIResult &res)
     { res.Reset();
       res.provider =m_provider;
       res.modelName=m_modelName;

       // Daily call counter reset
       datetime today=iTime(_Symbol,PERIOD_D1,0);
       if(today>m_lastCallDay){m_callsToday=0;m_lastCallDay=today;}

       // Determine 3 screenshot timeframes
       ENUM_TIMEFRAMES tfE,tfM,tfH;
       API_GetScreenshotTFs(_Period,tfE,tfM,tfH);
       Print(StringFormat("[API Vision] Capturing %s/%s/%s...",
             API_TFName(tfE),API_TFName(tfM),API_TFName(tfH)));

       string pfx="LQS5_API_";
       string fE=pfx+API_TFName(tfE)+".png";
       string fM=pfx+API_TFName(tfM)+".png";
       string fH=pfx+API_TFName(tfH)+".png";

       if(!TakeScreenshot(tfE,fE)){res.lastStatus=API_TFName(tfE)+" screenshot failed";return false;}
       if(!TakeScreenshot(tfM,fM)){FileDelete(fE);res.lastStatus=API_TFName(tfM)+" screenshot failed";return false;}
       if(!TakeScreenshot(tfH,fH)){FileDelete(fE);FileDelete(fM);res.lastStatus=API_TFName(tfH)+" screenshot failed";return false;}

       res.lastStatus="Encoding images...";
       string b64E=FileToB64(fE), b64M=FileToB64(fM), b64H=FileToB64(fH);
       FileDelete(fE); FileDelete(fM); FileDelete(fH);

       if(b64E==""||b64M==""||b64H=="")
         {res.lastStatus="Base64 encoding failed";return false;}

       res.lastStatus=StringFormat("Calling %s...",EnumToString(m_provider));
       string payload=BuildPayload(b64E,b64M,b64H,lqsDir);
       if(payload==""){res.lastStatus="Payload build failed (unknown provider)";return false;}

       string headers=BuildHeaders();
       string url=RequestURL();
       uchar  postBytes[], respBytes[];
       string respHeaders;
       int copyLen=StringToCharArray(payload,postBytes,0,WHOLE_ARRAY,CP_UTF8)-1;
       if(copyLen>0) ArrayResize(postBytes,copyLen);

       int httpCode=WebRequest("POST",url,headers,m_timeoutSec*1000,postBytes,respBytes,respHeaders);
       if(httpCode==-1)
         { res.lastStatus=StringFormat("WebRequest failed (err %d) — did you add the URL in Tools>Options>Expert Advisors?",GetLastError());
           Print("[API Vision] ",res.lastStatus);
           return false; }

       string body=CharArrayToString(respBytes,0,WHOLE_ARRAY,CP_UTF8);
       if(httpCode!=200)
         { res.lastStatus=StringFormat("HTTP %d error",httpCode);
           Print("[API Vision] HTTP ",httpCode," body: ",StringSubstr(body,0,200));
           return false; }

       res.lastStatus="Parsing response...";
       if(!ParseResponse(body,res)){res.lastStatus="Parse failed";return false;}

       m_callsToday++;
       res.callsToday=m_callsToday;
       res.stamp=TimeCurrent();
       res.lastStatus=StringFormat("%s %d%% — %s",
          DirStr(res.direction),res.confidence,StringSubstr(res.reason,0,60));
       Print("[API Vision] Result: ",res.lastStatus);
       return true; }

   ENUM_LQS_PROVIDER GetProvider()   const { return m_provider; }
   string            GetModelName()  const { return m_modelName; }
   string            GetLastStatus() const { return m_apiURL; }
  };

CLqsAPIHandler g_apiHandler; // singleton instance

//--- Trigger an API vision call for the current LQS signal direction
//    Returns true if API agrees (direction match AND confidence >= InpMinAPIConf)
bool API_Vision_Call(ENUM_DIRECTION lqsDir)
  { if(!InpUseAPIVision || !g_apiReady) return true; // not enabled → pass through
    // Rate limiter: don't hammer the API
    if(TimeCurrent()-g_lastAPICall < InpAPIScanSec)
      { if(InpAIVerbose)
          Log(StringFormat("[API Vision] Rate limit: wait %ds",
              InpAPIScanSec-(int)(TimeCurrent()-g_lastAPICall)));
        return g_apiVis.valid; } // return cached result
    g_lastAPICall=TimeCurrent();
    bool ok=g_apiHandler.Analyse(lqsDir,g_apiVis);
    if(!ok)
      { Log("[API Vision] Call failed: "+g_apiVis.lastStatus);
        return true; } // fail-safe: don't block trade on API outage
    // Check confidence and direction agreement
    if(g_apiVis.confidence < InpMinAPIConf)
      { Log(StringFormat("[API Vision] Low conf %d%% < %d%% — blocked",
            g_apiVis.confidence,InpMinAPIConf));
        return false; }
    if(g_apiVis.direction!=DIR_NONE && g_apiVis.direction!=lqsDir)
      { Log(StringFormat("[API Vision] Direction conflict — LQS=%s API=%s — blocked",
            DirStr(lqsDir),DirStr(g_apiVis.direction)));
        return false; }
    Log(StringFormat("[API Vision] CONFIRMED %s conf:%d%% — %s",
        DirStr(g_apiVis.direction),g_apiVis.confidence,StringSubstr(g_apiVis.reason,0,80)));
    return true; }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!g_sym.Name(_Symbol)) return INIT_FAILED;
   g_tr.SetExpertMagicNumber(InpMagic);
   g_tr.SetDeviationInPoints((ulong)InpSlippage);
   g_tr.SetTypeFilling(DetectFillType());
   g_tr.SetAsyncMode(false);
   g_tfE=(InpEntryTF==0)?PERIOD_M15:(InpEntryTF==1)?PERIOD_M30:PERIOD_H1;
   g_tfH=(InpHTF_Input==0)?PERIOD_H4:(InpHTF_Input==1)?PERIOD_D1:PERIOD_W1;
   g_hATR  =iATR(_Symbol,_Period,14);
   g_hADX  =iADX(_Symbol,_Period,14);
   g_hATR_H=iATR(_Symbol,g_tfH,14);
   g_hEMA_F=iMA(_Symbol,_Period,50,0,MODE_EMA,PRICE_CLOSE);
   g_hEMA_S=iMA(_Symbol,_Period,200,0,MODE_EMA,PRICE_CLOSE);
   g_hVol  =iVolumes(_Symbol,_Period,VOLUME_TICK);
   g_hVol_H=iVolumes(_Symbol,g_tfH,VOLUME_TICK);
   if(g_hATR==INVALID_HANDLE||g_hADX==INVALID_HANDLE||g_hVol==INVALID_HANDLE||
      g_hVol_H==INVALID_HANDLE||g_hEMA_F==INVALID_HANDLE||g_hEMA_S==INVALID_HANDLE)
     { Print("[LQS5 INIT FAIL] Indicator handle error"); return INIT_FAILED; }
   ArrayInitialize(g_dH,0);ArrayInitialize(g_pH,0);ArrayInitialize(g_vH,0);
   ArrayInitialize(g_bVol,0);ArrayInitialize(g_vwPV,0);ArrayInitialize(g_vwV,0);
   ArrayInitialize(g_vwPV2,0);ArrayInitialize(g_vwBars,0);ArrayInitialize(g_vwPrevVals,0);
   for(int i=0;i<MAX_VA;i++){g_vwOn[i]=false;VA_Reset(i,0);g_vaArr[i].active=false;}
   for(int i=0;i<5;i++)
     {g_vpHVN[i].price=0;g_vpHVN[i].volume=0;g_vpHVN[i].pct=0;g_vpHVN[i].bucket=0;
      g_vpLVN[i].price=0;g_vpLVN[i].volume=0;g_vpLVN[i].pct=0;g_vpLVN[i].bucket=0;}
   ResetSweepState();
   g_ofr.cumDelta=0;g_ofr.score=0;g_ofr.bullDiv=false;g_ofr.bearDiv=false;
   g_ofr.pressureFast=0.5;g_ofr.pressureSlow=0.5;g_ofr.ofImbalance=1;
   g_amd.phase=AMD_UNDEFINED;g_amd.dir=DIR_NONE;g_amd.score=0;g_amd.duration=0;
   g_sig.valid=false;g_sig.dir=DIR_NONE;g_sig.total=0;
   g_wA=InpWt_A;g_wB=InpWt_B;g_wC=InpWt_C;g_wD=InpWt_D;g_wE=InpWt_E;
   g_peakEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayPeakEquity=g_peakEquity;
   g_quiet = (bool)MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE);
   AI_Init();
   // Init external API Vision layer
   g_apiVis.Reset();
   if(InpUseAPIVision)
     { if((bool)MQLInfoInteger(MQL_TESTER))
         Print("[API Vision] WARNING: WebRequest does not work in Strategy Tester — API Vision disabled for backtest");
       else
         { g_apiReady=g_apiHandler.Init(InpAPIKey,InpProviderOverride,
                                        InpAPITimeoutSec,InpChartWidth,InpChartHeight,InpChartBars,
                                        g_apiVis);
           if(!g_apiReady)
             Print("[API Vision] Init FAILED: ",g_apiVis.lastStatus,
                   " | Check API key and Tools>Options>Expert Advisors>Allow WebRequest"); } }
   EventSetTimer(InpTimerSecs);
   if(InpShowDash&&!InpOptimMode) DashCreate();
   Log(StringFormat("v5.0 INIT OK | %s %s | HTF:%s | Magic:%d | LocalAI:%s | APIVision:%s (%s)",
       _Symbol,EnumToString(_Period),EnumToString(g_tfH),(int)InpMagic,
       InpUseAI?"ON":"OFF",
       InpUseAPIVision?(g_apiReady?"READY":"FAILED"):"OFF",
       g_apiReady?g_apiVis.modelName:"N/A"));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  { EventKillTimer();
    if(InpShowDash&&!InpOptimMode) DashDelete();
    ObjectsDeleteAll(0,DPFX);
    IndicatorRelease(g_hATR);IndicatorRelease(g_hADX);IndicatorRelease(g_hATR_H);
    IndicatorRelease(g_hEMA_F);IndicatorRelease(g_hEMA_S);
    IndicatorRelease(g_hVol);IndicatorRelease(g_hVol_H); }

void OnTimer()
  { if(InpUseNews&&TimeCurrent()-g_lastScan>InpNewsScan*60) ScanNewsCalendar(); }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
  { if(trans.type==TRADE_TRANSACTION_DEAL_ADD&&trans.symbol==_Symbol)
      if(HistoryDealSelect(trans.deal))
        if((long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)==InpMagic&&
           (long)HistoryDealGetInteger(trans.deal,DEAL_ENTRY)==DEAL_ENTRY_OUT)
           OnOurTradeClosed(trans.deal); }

void OnTrade()
  {if(g_ticket!=0&&!PositionExistsMagic()){Log("Closed externally.");ResetOpenTradeVars();}}

void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp)
  {if(id==CHARTEVENT_CHART_CHANGE&&InpShowDash&&!InpOptimMode) DashRefresh();}

double OnTester()
  { double tr=TesterStatistics(STAT_TRADES),pf=TesterStatistics(STAT_PROFIT_FACTOR);
    double sh=TesterStatistics(STAT_SHARPE_RATIO),dd=TesterStatistics(STAT_EQUITY_DD_RELATIVE);
    double profit=TesterStatistics(STAT_PROFIT),maxDD=TesterStatistics(STAT_BALANCE_DD);
    if(tr<15||pf<1.0) return 0.0;
    double rf=(maxDD>0)?profit/maxDD:0.0;
    double ddP=MathMax(1.0,dd/15.0);
    double trNorm=MathMin(MathSqrt(tr)/MathSqrt(200.0),1.5);
    double score=MathMax(0.0,(sh*pf*trNorm*MathMin(rf,5.0))/(ddP*ddP));
    double avgWin=TesterStatistics(STAT_GROSS_PROFIT)/(TesterStatistics(STAT_PROFIT_TRADES)+0.001);
    double avgLoss=MathAbs(TesterStatistics(STAT_GROSS_LOSS))/(TesterStatistics(STAT_LOSS_TRADES)+0.001);
    if(avgLoss>0&&avgWin/avgLoss<0.8) score*=0.5;
    return score; }

//+------------------------------------------------------------------+
//|                        MAIN TICK                                 |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(!g_sym.RefreshRates()) return;
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);

   // T1 — Daily reset
   if(dt.day_of_year!=g_curDay)
     { g_curDay=dt.day_of_year; g_locked=false;
       g_startEq=AccountInfoDouble(ACCOUNT_EQUITY);
       g_dayPeakEquity=g_startEq;
       g_peakEquity=MathMax(g_peakEquity,g_startEq);
       g_tradesDay=0; g_dayPnL=0.0; g_dayRealizedPnL=0.0;
       g_asianOK=false; g_asianH=-1e9; g_asianL=1e9;
       if(!PositionExistsMagic()){g_tp1Hit=false;g_tp2Hit=false;g_beSet=false;}
       ResetSweepState();
       double opArr[]; if(CopyOpen(_Symbol,PERIOD_D1,0,1,opArr)>=1)
         {g_dayOp=opArr[0];g_dayDt=iTime(_Symbol,PERIOD_D1,0);}
       if(InpVWAP_Day&&g_dayDt>0) VA_Reset(VA_DAY,g_dayDt);
       Log(StringFormat("Day reset: eq=%.2f peakEq=%.2f",g_startEq,g_peakEquity)); }

   // T2 — Tick delta
   UpdateTickDelta();

   // T3 — Bar change block
   datetime curBar=iTime(_Symbol,_Period,0);
   bool barChanged=(curBar!=g_lastBarT);
   if(barChanged)
     { g_lastBarT=curBar; g_barCnt++;
       CommitBarDelta();
       UpdateAsianSession(dt);
       DetectSessionOpens(dt);
       double atrB[1];
       double adxB[1];
       if(CopyBuffer(g_hATR,0,0,1,atrB)>=1) g_ATR=atrB[0];
       if(CopyBuffer(g_hADX,0,0,1,adxB)>=1) g_ADX=adxB[0];
       if(g_ATR>=_Point) g_regime=ClassifyRegime(g_ADX,g_ATR);
       g_entropy=ComputeEntropy(20);
       RebuildLiqLevels();
       RefreshVWAPAnchors();
       UpdateAllVWAPs();
       RunModuleA();
       RunModuleB();
       RunModuleC();
       UpdateVWAPSlopes();
       RunModuleE();
       if(InpVerbose)
          Log(StringFormat("Bar#%d liqN:%d asianOK:%s dayOp:%.2f entropy:%.3f",
              g_barCnt,g_liqN,B2S(g_asianOK),g_dayOp,g_entropy)); }

   if(g_ATR<_Point) return;

   // T6 — Fusion (per tick for entry timing)
   ComputeVWAPValues();
   FuseSignals();

   // AI — refresh once per bar (cached for the rest of ticks)
   if(InpUseAI && barChanged)
     { AI_BarUpdate();
       if(InpAIWriteJson && InpAIJsonOnTick) AI_LogSnapshot("BAR"); }

   // T7 — State & dashboard
   g_state=ResolveState();
   if(InpShowDash&&!InpOptimMode) DashRefresh();

   // T8 — Circuit breaker
   if(!g_locked)
     { double curEq=AccountInfoDouble(ACCOUNT_EQUITY);
       if(curEq>g_peakEquity) g_peakEquity=curEq;
       if(curEq>g_dayPeakEquity) g_dayPeakEquity=curEq;
       if(g_dayPeakEquity>0&&InpMaxDDPct>0)
         { double ddPct=((g_dayPeakEquity-curEq)/g_dayPeakEquity)*100.0;
           if(ddPct>=InpMaxDDPct){Warn(StringFormat("Daily DD %.1f%% >= %.1f%%",ddPct,InpMaxDDPct));CloseAll();g_locked=true;return;} }
       if(g_startEq>0.0)
         { double pct=((curEq-g_startEq)/g_startEq)*100.0;
           g_dayPnL=pct;
           if(pct>=InpDailyProfLock){Warn("Profit lock");CloseAll();g_locked=true;return;}
           if(pct<=-InpDailyLossLim){Warn("Loss limit"); CloseAll();g_locked=true;return;} } }
   if(g_state==ST_LOCK||g_state==ST_NEWS) return;

   // T9 — Manage / enter
   if(PositionExistsMagic()){ManageOpenTrade();return;}
   if(g_ticket!=0) ResetOpenTradeVars();
   if(g_state!=ST_READY||!PassGates(dt)) return;
   ExecuteEntry();
  }

//+------------------------------------------------------------------+
ENUM_EA_STATE ResolveState()
  { if(g_locked)              return ST_LOCK;
    if(g_newsBlk)             return ST_NEWS;
    if(PositionExistsMagic()) return ST_TRADE;
    if(g_sig.valid)           return ST_READY;
    if(g_sw.active&&g_sw.score>=20&&g_ofr.score>=20) return ST_OFR;
    if(g_sw.active&&g_sw.score>=20) return ST_SWEEP;
    return ST_IDLE; }

bool PassGates(const MqlDateTime &dt)
  { if(dt.hour<InpStartHour||dt.hour>InpEndHour) return false;
    if(InpNoWeekend&&(dt.day_of_week==0||dt.day_of_week==6)) return false;
    if((g_sym.Ask()-g_sym.Bid())/_Point>InpMaxSpread) return false;
    if(g_tradesDay>=InpMaxDailyTrades) return false;
    if(CountOurPositions()>=InpMaxOpen) return false;
    if(g_sig.dir==DIR_NONE) return false;
    if(InpCooldownBars>0&&g_lastTradeClose>0)
      {int bsc=iBarShift(_Symbol,_Period,g_lastTradeClose);if(bsc>=0&&bsc<InpCooldownBars)return false;}
    if(InpEntropyThresh>0&&g_entropy>0&&g_entropy<InpEntropyThresh) return false;
    // Gate 1 — Local AI (logistic regression, trains on trade outcomes)
    if(InpUseAI && InpAIBlockOnLow && g_ai.valid && g_ai.trainedTrades>=InpAILearnTrades)
      { if(g_ai.confidence < InpAIMinConf)
          { if(InpAIVerbose) Log(StringFormat("[AI-Local] Block: conf %.1f < min %.1f",g_ai.confidence,InpAIMinConf));
            return false; } }
    // Gate 2 — External AI Vision (Claude/GPT/Gemini/DeepSeek/xAI — screenshots → API → confirm)
    if(InpUseAPIVision && g_apiReady)
      { if(!API_Vision_Call(g_sig.dir)) return false; }
    return true; }

//+=================================================================+
//| Shannon Entropy — measures market structure vs random walk      |
//+=================================================================+
double ComputeEntropy(int lb)
  { double C[];
    if(CopyClose(_Symbol,_Period,1,lb,C)<lb) return 0.5;
    ArraySetAsSeries(C,true);
    int up=0,dn=0,fl=0;
    for(int i=0;i<lb-1;i++)
      { double d=C[i]-C[i+1];
        if(d>_Point) up++;
        else if(d<-_Point) dn++;
        else fl++; }
    int total=up+dn+fl; if(total<=0) return 0.5;
    double pU=(double)up/total,pD=(double)dn/total,pF=(double)fl/total;
    double ent=0;
    if(pU>0) ent-=pU*MathLog(pU)/MathLog(3.0);
    if(pD>0) ent-=pD*MathLog(pD)/MathLog(3.0);
    if(pF>0) ent-=pF*MathLog(pF)/MathLog(3.0);
    int runs=1;
    for(int i=0;i<lb-2;i++)
      { double d1=C[i]-C[i+1],d2=C[i+1]-C[i+2];
        if((d1>0&&d2<=0)||(d1<0&&d2>=0)||(d1==0&&d2!=0)) runs++; }
    double expectedRuns=(2.0*(up+fl)*(dn+fl))/(double)total+1.0;
    double runRatio=(expectedRuns>0)?(double)runs/expectedRuns:1.0;
    double structure=(1.0-ent)*0.5+MathAbs(1.0-runRatio)*0.5;
    return MathMax(0.0,MathMin(1.0,structure)); }

//+=================================================================+
//|           MODULE A — LIQUIDITY SWEEP                            |
//+=================================================================+
void RunModuleA()
  { if(g_sw.active){g_sw.barsAgo++;if(g_sw.barsAgo>InpSweepMaxAge)ResetSweepState();}
    for(int i=0;i<g_liqN;i++)
      { if(!g_liq[i].active||g_liq[i].swept) continue;
        SSweep ev=EvalSweep(g_liq[i]);
        if(ev.active&&ev.score>g_sw.score){g_sw=ev;g_liq[i].swept=true;g_sw.deltaAtSweep=g_ofr.cumDelta;
          if(InpVerbose)Log(StringFormat("SWEEP %s lvl:%.2f sc:%.0f",g_liq[i].label,g_liq[i].price,ev.score));} }
    DetectMultiSweep(); }

SSweep EvalSweep(const SLiqLevel &lvl)
  { SSweep ev;
    ev.active=false;ev.type=SWEEP_NONE;ev.level=0;ev.extreme=0;ev.closeAfter=0;
    ev.depthRatio=0;ev.reversalStr=0;ev.volRatio=0;ev.wickPct=0;
    ev.deltaAtSweep=0;ev.sweepTime=0;ev.barsAgo=0;ev.isMulti=false;ev.sweepCount=0;ev.score=0;

    int nb=MathMax(InpSweepConfBars+2,3);
    double H[],L[],O[],C[],V[];
    if(CopyHigh (_Symbol,_Period,1,nb,H)<nb) return ev;
    if(CopyLow  (_Symbol,_Period,1,nb,L)<nb) return ev;
    if(CopyOpen (_Symbol,_Period,1,nb,O)<nb) return ev;
    if(CopyClose(_Symbol,_Period,1,nb,C)<nb) return ev;
    bool hv=(CopyBuffer(g_hVol,0,1,nb,V)>=nb);
    ArraySetAsSeries(H,true);ArraySetAsSeries(L,true);
    ArraySetAsSeries(O,true);ArraySetAsSeries(C,true);
    if(hv) ArraySetAsSeries(V,true);

    double avgV=0;
    if(hv){for(int i=0;i<nb;i++)avgV+=V[i];avgV/=nb;}else avgV=1.0;

    if(lvl.dir==1)
      { if(H[0]<=lvl.price) return ev;
        double rng=H[0]-L[0];if(rng<_Point*2) return ev;
        double wkUp=H[0]-MathMax(O[0],C[0]);
        double wkPct=(wkUp/rng)*100.0;
        if(wkPct<InpSweepWickPct) return ev;
        double vR=(avgV>0)?(hv?V[0]:1.0)/avgV:1.0;
        if(vR<InpSweepVolMult) return ev;
        double dR=(lvl.price>0)?(H[0]-lvl.price)/lvl.price:0;
        if(dR<InpSweepDepthMin) return ev;
        double revStr=(rng>0)?((H[0]-C[0])/rng)*100.0:0;
        if(revStr<InpSweepRetracePct) return ev;
        double confBonus=0;
        if(nb>=2&&C[0]<O[0]&&C[0]<C[1]) confBonus=8.0;
        double sc=MathMin(wkPct*0.35,35.0)+MathMin((vR-1.0)*12,24.0)
                 +MathMin(revStr*0.25,25.0)+MathMin(dR/0.001*0.5,10.0)+6.0+confBonus;
        ev.active=true;ev.type=SWEEP_HIGH;ev.level=lvl.price;ev.extreme=H[0];
        ev.closeAfter=C[0];ev.depthRatio=dR;ev.reversalStr=revStr;
        ev.volRatio=vR;ev.wickPct=wkPct;ev.sweepTime=iTime(_Symbol,_Period,1);
        ev.score=MathMin(sc,100.0); }
    else
      { if(L[0]>=lvl.price) return ev;
        double rng=H[0]-L[0];if(rng<_Point*2) return ev;
        double wkDn=MathMin(O[0],C[0])-L[0];
        double wkPct=(wkDn/rng)*100.0;
        if(wkPct<InpSweepWickPct) return ev;
        double vR=(avgV>0)?(hv?V[0]:1.0)/avgV:1.0;
        if(vR<InpSweepVolMult) return ev;
        double dR=(lvl.price>0)?(lvl.price-L[0])/lvl.price:0;
        if(dR<InpSweepDepthMin) return ev;
        double revStr=(rng>0)?((C[0]-L[0])/rng)*100.0:0;
        if(revStr<InpSweepRetracePct) return ev;
        double confBonus=0;
        if(nb>=2&&C[0]>O[0]&&C[0]>C[1]) confBonus=8.0;
        double sc=MathMin(wkPct*0.35,35.0)+MathMin((vR-1.0)*12,24.0)
                 +MathMin(revStr*0.25,25.0)+MathMin(dR/0.001*0.5,10.0)+6.0+confBonus;
        ev.active=true;ev.type=SWEEP_LOW;ev.level=lvl.price;ev.extreme=L[0];
        ev.closeAfter=C[0];ev.depthRatio=dR;ev.reversalStr=revStr;
        ev.volRatio=vR;ev.wickPct=wkPct;ev.sweepTime=iTime(_Symbol,_Period,1);
        ev.score=MathMin(sc,100.0); }
    return ev; }

void DetectMultiSweep()
  { if(!g_sw.active) return;
    int cnt=0; datetime since=iTime(_Symbol,_Period,InpMultiSweepBars);
    for(int i=0;i<g_liqN;i++) if(g_liq[i].swept&&g_liq[i].time>=since) cnt++;
    if(cnt>=2){g_sw.isMulti=true;g_sw.sweepCount=cnt;g_sw.score=MathMin(g_sw.score+10,100);} }

void RebuildLiqLevels()
  { g_liqN=0;
    if(InpUsePrevDayHL)
      { double dH[],dL[];
        if(CopyHigh(_Symbol,PERIOD_D1,1,2,dH)>=2&&CopyLow(_Symbol,PERIOD_D1,1,2,dL)>=2)
          {ArraySetAsSeries(dH,true);ArraySetAsSeries(dL,true);
           AddLiq(dH[0],"PDH", 1,iTime(_Symbol,PERIOD_D1,1));
           AddLiq(dL[0],"PDL",-1,iTime(_Symbol,PERIOD_D1,1));} }
    if(InpUseAsianSess&&g_asianOK)
      {if(g_asianH>-1e8)AddLiq(g_asianH,"ASH", 1,g_asianDt);
       if(g_asianL< 1e8)AddLiq(g_asianL,"ASL",-1,g_asianDt);}
    if(g_dayOp>0){AddLiq(g_dayOp,"DO",1,g_dayDt);AddLiq(g_dayOp,"DO",-1,g_dayDt);}
    if(g_londonOp>0)AddLiq(g_londonOp,"LO",1,g_londonDt);
    if(g_nyOp>0)    AddLiq(g_nyOp,"NYO",1,g_nyDt);
    double swH[],swL[];
    if(CopyHigh(_Symbol,_Period,1,InpLiqLookback,swH)>=InpLiqLookback&&
       CopyLow (_Symbol,_Period,1,InpLiqLookback,swL)>=InpLiqLookback)
      { ArraySetAsSeries(swH,true); ArraySetAsSeries(swL,true);
        for(int i=2;i<InpLiqLookback-2;i++)
          { if(swH[i]>swH[i-1]&&swH[i]>swH[i-2]&&swH[i]>swH[i+1]&&swH[i]>swH[i+2])
               AddLiq(swH[i],"SWH", 1,iTime(_Symbol,_Period,i+1));
            if(swL[i]<swL[i-1]&&swL[i]<swL[i-2]&&swL[i]<swL[i+1]&&swL[i]<swL[i+2])
               AddLiq(swL[i],"SWL",-1,iTime(_Symbol,_Period,i+1)); } }
    if(InpUseRoundNums)
      { double cur=g_sym.Bid(),step=InpRoundStep,base=MathFloor(cur/step)*step;
        for(double r=base-step*3;r<=base+step*4;r+=step)
          {if(r<=0)continue;AddLiq(r,"RND",(r>cur?1:-1),TimeCurrent());} }
    if(InpVerbose)Log(StringFormat("Levels rebuilt: %d",g_liqN)); }

void AddLiq(double price,string lbl,int dir,datetime t)
  { if(g_liqN>=MAX_LIQ||price<=0) return;
    for(int i=0;i<g_liqN;i++)
      if(g_liq[i].dir==dir&&MathAbs(g_liq[i].price-price)<g_ATR*0.5) return;
    g_liq[g_liqN].price=price;g_liq[g_liqN].label=lbl;
    g_liq[g_liqN].time=t;g_liq[g_liqN].dir=dir;
    g_liq[g_liqN].swept=false;g_liq[g_liqN].active=true;
    g_liqN++;
    if(InpDrawLevels&&!InpOptimMode)
       DLine(DPFX+"LV"+lbl+IntegerToString(g_liqN),price,InpClrLevel,STYLE_DOT,1,lbl); }

void UpdateAsianSession(const MqlDateTime &dt)
  { bool inAs=(dt.hour>=InpAsianStart&&dt.hour<InpAsianEnd);
    double H[],L[];
    if(CopyHigh(_Symbol,_Period,0,1,H)<1||CopyLow(_Symbol,_Period,0,1,L)<1) return;
    if(inAs){if(H[0]>g_asianH)g_asianH=H[0];if(L[0]<g_asianL)g_asianL=L[0];}
    else if(!g_asianOK&&dt.hour>=InpAsianEnd)
      {g_asianOK=true;g_asianDt=TimeCurrent();if(InpVWAP_Asian)VA_Reset(VA_ASIAN,g_asianDt);} }

void DetectSessionOpens(const MqlDateTime &dt)
  { double op[];
    if(dt.hour==InpLondonHour&&dt.min==0&&g_londonDt!=iTime(_Symbol,PERIOD_H1,0))
      {if(CopyOpen(_Symbol,PERIOD_H1,0,1,op)>=1)
        {g_londonOp=op[0];g_londonDt=iTime(_Symbol,PERIOD_H1,0);
         if(InpVWAP_London)VA_Reset(VA_LONDON,g_londonDt);}}
    if(dt.hour==InpNYHour&&dt.min==0&&g_nyDt!=iTime(_Symbol,PERIOD_H1,0))
      {if(CopyOpen(_Symbol,PERIOD_H1,0,1,op)>=1)
        {g_nyOp=op[0];g_nyDt=iTime(_Symbol,PERIOD_H1,0);
         if(InpVWAP_NY)VA_Reset(VA_NY,g_nyDt);}}
    if(dt.day_of_week==1&&dt.hour==0&&dt.min==0&&g_weekDt!=iTime(_Symbol,PERIOD_D1,0))
      {if(CopyOpen(_Symbol,PERIOD_W1,0,1,op)>=1)
        {g_weekOp=op[0];g_weekDt=iTime(_Symbol,PERIOD_W1,0);
         if(InpVWAP_Week)VA_Reset(VA_WEEK,g_weekDt);}} }

void ResetSweepState()
  { g_sw.active=false;g_sw.type=SWEEP_NONE;g_sw.level=0;g_sw.extreme=0;
    g_sw.closeAfter=0;g_sw.depthRatio=0;g_sw.reversalStr=0;g_sw.volRatio=0;
    g_sw.wickPct=0;g_sw.deltaAtSweep=0;g_sw.sweepTime=0;g_sw.barsAgo=0;
    g_sw.isMulti=false;g_sw.sweepCount=0;g_sw.score=0; }

//+=================================================================+
//| MODULE B — ORDER FLOW                                           |
//+=================================================================+
void UpdateTickDelta()
  { double curB=g_sym.Bid(),curA=g_sym.Ask();
    double mid=(curB+curA)/2.0;
    static double s_lastMid=0;
    if(s_lastMid==0){s_lastMid=mid;return;}
    double mv=mid-s_lastMid;
    double spd=curA-curB; if(spd<_Point) spd=_Point;
    double w=_Point/spd;
    if(mv>_Point*0.5) g_barDelta+=w;
    else if(mv<-_Point*0.5) g_barDelta-=w;
    s_lastMid=mid; }

void CommitBarDelta()
  { double cls[],vol[];
    if(CopyClose(_Symbol,_Period,1,1,cls)<1) return;
    bool hv=(CopyBuffer(g_hVol,0,1,1,vol)>=1);
    int idx=g_dIdx%DMAX;
    g_dH[idx]=g_barDelta;g_pH[idx]=cls[0];g_vH[idx]=hv?vol[0]:0.0;
    g_dIdx++;if(g_dIdx>=DMAX)g_dFull=true;g_barDelta=0.0; }

void RunModuleB()
  {
   int nb=InpDeltaLookback;
   double H[],L[],C[],V[];
   if(CopyHigh (_Symbol,_Period,1,nb,H)<nb){g_ofr.score=0;return;}
   if(CopyLow  (_Symbol,_Period,1,nb,L)<nb){g_ofr.score=0;return;}
   if(CopyClose(_Symbol,_Period,1,nb,C)<nb){g_ofr.score=0;return;}
   bool hv=(CopyBuffer(g_hVol,0,1,nb,V)>=nb);
   ArraySetAsSeries(H,true);ArraySetAsSeries(L,true);ArraySetAsSeries(C,true);
   if(hv) ArraySetAsSeries(V,true);

   double avgV=0;
   for(int i=0;i<nb;i++) avgV+=hv?V[i]:1.0;
   avgV/=nb;

   double synDelta=0,buyP=0,sellP=0;
   for(int i=0;i<nb;i++)
     { double rng=H[i]-L[i];if(rng<_Point)continue;
       double bv=hv?V[i]:1.0;
       double bias=(C[i]-L[i])/rng;
       double d=(bias-0.5)*2.0*bv;
       synDelta+=d;
       if(d>0)buyP+=d;else sellP+=MathAbs(d); }
   g_ofr.cumDelta=synDelta;
   double tot=buyP+sellP;
   g_ofr.pressureSlow=(tot>0)?buyP/tot:0.5;
   double fBuy=0,fSell=0;int fLen=MathMin(8,nb);
   for(int i=0;i<fLen;i++)
     {double rng2=H[i]-L[i];if(rng2<_Point)continue;
      double bv2=hv?V[i]:1.0,d2=((C[i]-L[i])/rng2-0.5)*2.0*bv2;
      if(d2>0)fBuy+=d2;else fSell+=MathAbs(d2);}
   double fTot=fBuy+fSell;
   g_ofr.pressureFast=(fTot>0)?fBuy/fTot:0.5;
   g_ofr.ofImbalance=(sellP>0.001)?buyP/sellP:1.0;
   g_ofr.deltaMomentum=synDelta/nb;

   double halfDelta1=0,halfDelta2=0;
   int halfLen=nb/2;
   for(int i=0;i<halfLen;i++)
     {double rng=H[i]-L[i];if(rng<_Point)continue;
      double bv=hv?V[i]:1.0;halfDelta1+=(((C[i]-L[i])/rng)-0.5)*2.0*bv;}
   for(int i=halfLen;i<nb;i++)
     {double rng=H[i]-L[i];if(rng<_Point)continue;
      double bv=hv?V[i]:1.0;halfDelta2+=(((C[i]-L[i])/rng)-0.5)*2.0*bv;}
   double accel=(halfLen>0)?((halfDelta1-halfDelta2)/halfLen):0;

   int half=MathMin(8,nb/2);
   double earlyD=0,lateD=0,earlyP=-1e9,lateP=-1e9,earlyPL=1e9,latePL=1e9;
   for(int i=0;i<half;i++)
     { double rng=H[i]-L[i];if(rng<_Point)continue;
       double bv=hv?V[i]:1.0;
       lateD+=(((C[i]-L[i])/rng)-0.5)*2.0*bv;
       if(H[i]>lateP)lateP=H[i];if(L[i]<latePL)latePL=L[i]; }
   for(int i=half;i<half*2&&i<nb;i++)
     { double rng=H[i]-L[i];if(rng<_Point)continue;
       double bv=hv?V[i]:1.0;
       earlyD+=(((C[i]-L[i])/rng)-0.5)*2.0*bv;
       if(H[i]>earlyP)earlyP=H[i];if(L[i]<earlyPL)earlyPL=L[i]; }
   g_ofr.bullDiv=(latePL<earlyPL-_Point&&lateD>earlyD+MathAbs(earlyD)*InpDivergThresh/100.0);
   g_ofr.bearDiv=(lateP>earlyP+_Point&&lateD<earlyD-MathAbs(earlyD)*InpDivergThresh/100.0);

   double absScore=0;
   for(int i=0;i<MathMin(InpAbsorbBars,nb);i++)
     { double rng=H[i]-L[i];double bv=hv?V[i]:1.0;
       double vr=(avgV>0)?bv/avgV:0;
       if(vr>=InpAbsorbVolMult&&rng/(g_ATR+_Point)<=InpAbsorbMaxMove)
          absScore+=100.0/InpAbsorbBars; }
   g_ofr.absorptionScore=MathMin(absScore,100.0);

   double qDelta1=0,qDeltaN=0;
   int qtr=MathMax(1,nb/4);
   for(int i=0;i<qtr;i++){double rng=H[i]-L[i];if(rng<_Point)continue;
      double bv=hv?V[i]:1.0;qDeltaN+=(((C[i]-L[i])/rng)-0.5)*2.0*bv;}
   for(int i=nb-qtr;i<nb;i++){double rng=H[i]-L[i];if(rng<_Point)continue;
      double bv=hv?V[i]:1.0;qDelta1+=(((C[i]-L[i])/rng)-0.5)*2.0*bv;}
   if((qDelta1>0&&qDeltaN<0)||(qDelta1<0&&qDeltaN>0))
     { double flipMag=MathAbs(qDelta1)+MathAbs(qDeltaN);
       g_ofr.exhaustionScore=MathMin(40.0+flipMag*5.0,95.0); }
   else g_ofr.exhaustionScore=15.0;

   if(g_vwOn[VA_DAY]&&g_vaArr[VA_DAY].active&&g_vaArr[VA_DAY].value>0)
      g_ofr.vwapDeltaDiff=g_sym.Bid()-g_vaArr[VA_DAY].value;

   double divBonus=(g_ofr.bullDiv||g_ofr.bearDiv)?35.0:0.0;
   double absBonus=g_ofr.absorptionScore*0.25;
   double exhBonus=g_ofr.exhaustionScore*0.20;
   double imbBonus=MathMin(MathMax(g_ofr.ofImbalance-1.0,0)*15.0,20.0);
   double momBonus=(MathAbs(g_ofr.deltaMomentum)>0)?MathMin(MathAbs(g_ofr.deltaMomentum)*3.0,10.0):0;
   double accelBonus=MathMin(MathAbs(accel)*8.0,15.0);
   g_ofr.score=MathMin(divBonus+absBonus+exhBonus+imbBonus+momBonus+accelBonus,100.0);

   if(InpVerbose)
      Log(StringFormat("OFR sc:%.0f bullDiv:%s bearDiv:%s abs:%.0f imb:%.2f accel:%.2f",
          g_ofr.score,B2S(g_ofr.bullDiv),B2S(g_ofr.bearDiv),g_ofr.absorptionScore,g_ofr.ofImbalance,accel));
  }

//+=================================================================+
//|           MODULE C — AMD WYCKOFF                                |
//+=================================================================+
void RunModuleC()
  { int nb=InpAccumLookback+5;
    double H[],L[],C[],V[],atrHB[];
    ArrayResize(atrHB,1);
    if(CopyHigh (_Symbol,g_tfH,1,nb,H)<nb) return;
    if(CopyLow  (_Symbol,g_tfH,1,nb,L)<nb) return;
    if(CopyClose(_Symbol,g_tfH,1,nb,C)<nb) return;
    if(CopyBuffer(g_hATR_H,0,1,1,atrHB)<1) return;
    double hatr=atrHB[0];if(hatr<_Point) return;
    ArraySetAsSeries(H,true);ArraySetAsSeries(L,true);ArraySetAsSeries(C,true);
    bool hv=(CopyBuffer(g_hVol_H,0,1,nb,V)>=nb);
    if(hv)ArraySetAsSeries(V,true);
    double avgVol=0;
    if(hv){for(int i=0;i<nb;i++)avgVol+=V[i];avgVol/=nb;}else avgVol=1.0;
    double rH=-1e9,rL=1e9;
    for(int i=0;i<InpAccumLookback;i++){if(H[i]>rH)rH=H[i];if(L[i]<rL)rL=L[i];}
    g_amd.rangeHigh=rH;g_amd.rangeLow=rL;g_amd.rangeMid=(rH+rL)/2.0;
    double rngR=(hatr>0)?(rH-rL)/hatr:999.0;
    int adlP=MathMin((int)InpADLPeriod,nb);
    double adl=0;
    for(int i=0;i<adlP;i++)
      {double rng=H[i]-L[i];if(rng<_Point)continue;
       adl+=((C[i]-L[i])-(H[i]-C[i]))/rng*(hv?V[i]:1.0);}
    g_amd.adl=adl;
    g_amd.spring=false;g_amd.upthrust=false;
    for(int i=1;i<MathMin(nb-1,15);i++)
      {if(L[i]<rL-hatr*InpSpringMult*0.3&&C[i]>rL)g_amd.spring=true;
       if(H[i]>rH+hatr*InpUpthrustMult*0.3&&C[i]<rH)g_amd.upthrust=true;}
    g_amd.volClimax=false;
    if(hv)for(int i=0;i<5&&i<nb;i++)
       if(V[i]/(avgVol+0.001)>=InpManipVolMult*1.3){g_amd.volClimax=true;break;}
    double coBull=0,coBear=0;
    for(int i=0;i<InpAccumLookback&&i<nb;i++)
      {double rng=H[i]-L[i];if(rng<_Point)continue;
       double bias=(C[i]-L[i])/rng,vr=hv?V[i]/(avgVol+0.001):1.0;
       if(bias>0.55)coBull+=vr*bias;if(bias<0.45)coBear+=vr*(1.0-bias);}
    double coT=coBull+coBear;
    g_amd.coBull=(coT>0)?MathMin(coBull/coT*100,100):50;
    g_amd.coBear=(coT>0)?MathMin(coBear/coT*100,100):50;
    g_amd.co=(g_amd.coBull+g_amd.coBear)/2.0;
    double sumWP=0,sumW=0;
    for(int i=0;i<InpAccumLookback&&i<nb;i++)
      {double w=hv?V[i]:1.0;sumWP+=C[i]*w;sumW+=w;}
    g_amd.cog=(sumW>0)?sumWP/sumW:0.0;
    bool mBull=false,mBear=false;double bestVR=0;
    for(int i=0;i<MathMin(10,nb);i++)
      {double vr=hv?V[i]/(avgVol+0.001):1.0;
       if(vr>=InpManipVolMult)
         {if(L[i]<rL)mBull=true;if(H[i]>rH)mBear=true;if(vr>bestVR)bestVR=vr;}}
    double mSc=0;
    if(mBull||mBear){mSc+=40;if(bestVR>=InpManipVolMult)mSc+=20;
       if(g_sw.active)mSc+=25;if(g_amd.spring||g_amd.upthrust)mSc+=15;}
    g_amd.manipScore=MathMin(mSc,100.0);
    ENUM_AMD_PHASE np=AMD_UNDEFINED;
    if(g_amd.manipScore>=40.0)np=AMD_MANIPULATION;
    else if(rngR<=InpAccumRangeRatio&&g_amd.coBull>InpCOPressMin)np=AMD_ACCUMULATION;
    else if(g_amd.coBull>60&&C[0]>g_amd.rangeMid)np=AMD_MARKUP;
    else if(g_amd.coBear>60&&C[0]<g_amd.rangeMid)np=AMD_MARKDOWN;
    g_amd.prevPhase=g_amd.phase;
    if(np!=g_amd.phase)
      {if(g_amd.duration<(int)InpPhaseDurMin)g_amd.duration++;
       else{g_amd.phase=np;g_amd.duration=0;g_amd.phaseStart=TimeCurrent();}}
    else g_amd.duration++;
    g_amd.endManip=false;
    if(g_amd.phase==AMD_MANIPULATION)
      {bool oRev=(mBull&&g_ofr.bullDiv)||(mBear&&g_ofr.bearDiv)||g_ofr.absorptionScore>=40;
       g_amd.endManip=oRev&&g_sw.active;}
    if(mBull&&g_amd.spring)g_amd.dir=DIR_LONG;
    else if(mBear&&g_amd.upthrust)g_amd.dir=DIR_SHORT;
    else if(g_amd.coBull>g_amd.coBear+5)g_amd.dir=DIR_LONG;
    else if(g_amd.coBear>g_amd.coBull+5)g_amd.dir=DIR_SHORT;
    else g_amd.dir=DIR_NONE;
    double conf=0;
    if(g_amd.phase==AMD_MANIPULATION)conf+=50;
    else if(g_amd.phase==AMD_ACCUMULATION)conf+=30;
    else if(g_amd.phase==AMD_MARKUP||g_amd.phase==AMD_MARKDOWN)conf+=25;
    if(g_amd.endManip)conf+=25;
    if(g_amd.spring||g_amd.upthrust)conf+=15;
    if(g_sw.active)conf+=10;
    g_amd.confidence=MathMin(conf,100.0);g_amd.score=g_amd.confidence;
    if(InpVerbose)
       Log(StringFormat("AMD phase:%s dir:%s sc:%.0f endManip:%s",
           PhaseStr(g_amd.phase),DirStr(g_amd.dir),g_amd.score,B2S(g_amd.endManip)));
    if(InpDrawPhase&&!InpOptimMode)
       DText(DPFX+"PH",PhaseStr(g_amd.phase),iTime(_Symbol,_Period,0),g_amd.rangeMid,InpClrPhase,9); }

//+=================================================================+
//|           MODULE D — ANCHORED VWAP                              |
//+=================================================================+
void RefreshVWAPAnchors()
  { g_vwOn[VA_ASIAN] =InpVWAP_Asian &&g_asianOK;
    g_vwOn[VA_LONDON]=InpVWAP_London&&(g_londonOp>0);
    g_vwOn[VA_NY]    =InpVWAP_NY    &&(g_nyOp>0);
    g_vwOn[VA_WEEK]  =InpVWAP_Week  &&(g_weekOp>0);
    g_vwOn[VA_DAY]   =InpVWAP_Day   &&(g_dayOp>0);
    g_vwOn[VA_SWING] =InpVWAP_Swing;
    g_vwOn[VA_POC_A] =InpVWAP_POC   &&(g_vpPOC>0);
    if(InpVWAP_Swing)
      { double swH[],swL[];
        if(CopyHigh(_Symbol,_Period,1,InpLiqLookback,swH)>=InpLiqLookback&&
           CopyLow (_Symbol,_Period,1,InpLiqLookback,swL)>=InpLiqLookback)
          { ArraySetAsSeries(swH,true);ArraySetAsSeries(swL,true);
            datetime newestSw=0;
            for(int i=3;i<10&&i<InpLiqLookback-3;i++)
              { bool isH=(swH[i]>swH[i-1]&&swH[i]>swH[i+1]);
                bool isL=(swL[i]<swL[i-1]&&swL[i]<swL[i+1]);
                datetime st=iTime(_Symbol,_Period,i+1);
                if((isH||isL)&&st>newestSw) newestSw=st; }
            if(newestSw>0&&newestSw>g_vaArr[VA_SWING].anchorTime)
               VA_Reset(VA_SWING,newestSw); } } }

void UpdateAllVWAPs()
  { double H[],L[],C[],V[];
    if(CopyHigh (_Symbol,_Period,1,1,H)<1) return;
    if(CopyLow  (_Symbol,_Period,1,1,L)<1) return;
    if(CopyClose(_Symbol,_Period,1,1,C)<1) return;
    bool hv=(CopyBuffer(g_hVol,0,1,1,V)>=1);
    double bp=(H[0]+L[0]+C[0])/3.0,bv=hv?V[0]:1.0;
    for(int i=0;i<MAX_VA;i++)
      {if(!g_vwOn[i]||!g_vaArr[i].active||g_vwBars[i]>=InpVWAP_MaxBars)continue;
       g_vwPV[i]+=bp*bv;g_vwV[i]+=bv;g_vwPV2[i]+=bp*bp*bv;g_vwBars[i]++;} }

void UpdateVWAPSlopes()
  { for(int i=0;i<MAX_VA;i++)
      { if(!g_vwOn[i]||!g_vaArr[i].active||g_vwV[i]<=0) continue;
        double curVal=g_vwPV[i]/g_vwV[i];
        if(g_vwPrevVals[i]>0&&g_vwBars[i]>=InpVWAP_SlopeLen)
          { g_vaArr[i].slope=(g_ATR>0)?(curVal-g_vwPrevVals[i])/g_ATR:0; }
        g_vwPrevVals[i]=curVal; } }

void ComputeVWAPValues()
  { double curP=g_sym.Bid();
    g_vwActiveCount=0;
    double vwapVals[MAX_VA]; ArrayInitialize(vwapVals,0.0);
    for(int i=0;i<MAX_VA;i++)
      { if(!g_vwOn[i]||!g_vaArr[i].active||g_vwV[i]<=0)continue;
        double vwap=g_vwPV[i]/g_vwV[i];
        double var=(g_vwPV2[i]/g_vwV[i])-vwap*vwap;
        double sigma=(var>0)?MathSqrt(var):g_ATR;
        vwapVals[i]=vwap;
        g_vaArr[i].value=vwap;
        g_vaArr[i].upperSD1=vwap+sigma;g_vaArr[i].lowerSD1=vwap-sigma;
        g_vaArr[i].upperSD2=vwap+2*sigma;g_vaArr[i].lowerSD2=vwap-2*sigma;
        g_vaArr[i].devSigma=(sigma>0)?(curP-vwap)/sigma:0;
        g_vaArr[i].priceAbove=(curP>vwap);
        g_vaArr[i].distATR=(g_ATR>0)?MathAbs(curP-vwap)/g_ATR:0;
        g_vaArr[i].rejection=(MathAbs(g_vaArr[i].devSigma)>=InpVWAP_DevThresh);
        g_vwActiveCount++; }
    int bestCluster=0;double bestClP=0;
    for(int i=0;i<MAX_VA;i++)
      {if(!g_vwOn[i]||vwapVals[i]==0)continue;
       int cnt=1;double sumP=vwapVals[i];
       for(int j=i+1;j<MAX_VA;j++)
         {if(!g_vwOn[j]||vwapVals[j]==0)continue;
          if(MathAbs(vwapVals[i]-vwapVals[j])<g_ATR*InpVWAP_ClsDist){cnt++;sumP+=vwapVals[j];}}
       if(cnt>bestCluster){bestCluster=cnt;bestClP=sumP/cnt;}}
    g_vwClusterCount=bestCluster;
    g_vwClusterPrice=bestCluster>=InpVWAP_ClsMin?bestClP:0;
    g_vwClusterStrength=bestCluster>=InpVWAP_ClsMin?MathMin(bestCluster/(double)MAX_VA*100+50,100):0;
    double devSum=0;int devCnt=0;
    for(int i=0;i<MAX_VA;i++)
      {if(!g_vwOn[i]||!g_vaArr[i].active||g_vaArr[i].value==0)continue;
       devSum+=MathAbs(g_vaArr[i].devSigma);devCnt++;}
    g_vwDevScore=(devCnt>0)?MathMin(devSum/devCnt/InpVWAP_DevThresh*100,100):0;
    g_vwAlignedAtLevel=false;g_vwAlignedDist=1e9;
    if(g_sw.active)
      for(int i=0;i<MAX_VA;i++)
        {if(!g_vwOn[i]||!g_vaArr[i].active||g_vaArr[i].value==0)continue;
         double d=MathAbs(g_vaArr[i].value-g_sw.level);
         if(d<g_vwAlignedDist)g_vwAlignedDist=d;
         if(d<g_ATR*InpVWAP_LevelTol)g_vwAlignedAtLevel=true;}
    int slopeUp=0,slopeDn=0;
    for(int i=0;i<MAX_VA;i++)
      {if(!g_vwOn[i]||!g_vaArr[i].active)continue;
       if(g_vaArr[i].slope>0.01)slopeUp++;
       else if(g_vaArr[i].slope<-0.01)slopeDn++;}
    double slopeBonus=0;
    if(slopeUp>=3||slopeDn>=3) slopeBonus=15.0;
    else if(slopeUp>=2||slopeDn>=2) slopeBonus=8.0;
    double vs=0;
    if(g_vwAlignedAtLevel)vs+=35;
    if(g_vwClusterCount>=InpVWAP_ClsMin)vs+=25;
    if(g_vwDevScore>=50)vs+=20;
    vs+=slopeBonus;
    g_vwScore=MathMin(vs,100.0);
    if(InpDrawVWAP&&!InpOptimMode)DrawAllVWAPLines(); }

void DrawAllVWAPLines()
  { color cols[MAX_VA]={InpClrVWAP_As,InpClrVWAP_Ln,InpClrVWAP_NY,
                        InpClrVWAP_Wk,InpClrVWAP_Dy,InpClrVWAP_Sw,InpClrVWAP_Dy};
    string sfx[MAX_VA]={"AS","LN","NY","WK","DY","SW","PC"};
    for(int i=0;i<MAX_VA;i++)
      {if(!g_vwOn[i]||!g_vaArr[i].active||g_vaArr[i].value==0)continue;
       DLine(DPFX+"VW"+sfx[i],g_vaArr[i].value,cols[i],STYLE_SOLID,1,"VWAP "+sfx[i]);
       DLine(DPFX+"VU1"+sfx[i],g_vaArr[i].upperSD1,cols[i],STYLE_DOT,1,"");
       DLine(DPFX+"VL1"+sfx[i],g_vaArr[i].lowerSD1,cols[i],STYLE_DOT,1,"");} }

//+=================================================================+
//|           MODULE E — VOLUME PROFILE                             |
//+=================================================================+
void RunModuleE(){BuildVolumeProfile(InpVP_RollingLen);ComputeVPMetrics();}

void BuildVolumeProfile(int lb)
  { double H[],L[],V[];
    if(CopyHigh(_Symbol,_Period,1,lb,H)<lb)return;
    if(CopyLow (_Symbol,_Period,1,lb,L)<lb)return;
    bool hv=(CopyBuffer(g_hVol,0,1,lb,V)>=lb);
    double pMin=1e9,pMax=-1e9;
    for(int i=0;i<lb;i++){if(L[i]<pMin)pMin=L[i];if(H[i]>pMax)pMax=H[i];}
    double rng=pMax-pMin;if(rng<_Point)return;
    int bkt=MathMin(InpVP_Buckets,BMAX);
    double bSize=rng/bkt;
    ArrayInitialize(g_bVol,0.0);
    double total=0;
    for(int i=0;i<lb;i++)
      {int b=(int)MathFloor(((H[i]+L[i])/2.0-pMin)/bSize);
       b=MathMax(0,MathMin(b,bkt-1));
       double bv=hv?V[i]:1.0;g_bVol[b]+=bv;total+=bv;}
    g_vpTotalVol=total;
    int pocIdx=0;double pocVol=0;
    for(int i=0;i<bkt;i++)if(g_bVol[i]>pocVol){pocVol=g_bVol[i];pocIdx=i;}
    g_vpPOC=pMin+(pocIdx+0.5)*bSize;
    double vaT=total*(InpVAPct/100.0),vaVol=pocVol;int vaL=pocIdx,vaH=pocIdx;
    while(vaVol<vaT&&(vaL>0||vaH<bkt-1))
      {double aL=(vaL>0)?g_bVol[vaL-1]:0,aH=(vaH<bkt-1)?g_bVol[vaH+1]:0;
       if(aL>=aH&&vaL>0){vaL--;vaVol+=aL;}else if(vaH<bkt-1){vaH++;vaVol+=aH;}
       else if(vaL>0){vaL--;vaVol+=aL;}else break;}
    g_vpVAH=pMin+(vaH+1.0)*bSize;g_vpVAL=pMin+vaL*bSize;g_vpVaWidth=g_vpVAH-g_vpVAL;
    if(g_vpPrevPOC>0)g_vpMigr=(g_vpPOC>g_vpPrevPOC)?1.0:(g_vpPOC<g_vpPrevPOC)?-1.0:0.0;
    g_vpPrevPOC=g_vpPOC;
    double maxV=-1e9;
    for(int i=0;i<bkt;i++)if(g_bVol[i]>maxV)maxV=g_bVol[i];
    double hvnThr=(maxV>0)?maxV*(InpVP_HVN_Pct/100.0):0;
    double lvnThr=(maxV>0)?maxV*(InpVP_LVN_Pct/100.0):0;
    g_vpHVNCount=0;g_vpLVNCount=0;
    for(int i=0;i<bkt&&g_vpHVNCount<InpVP_MaxHVN;i++)
      if(g_bVol[i]>=hvnThr)
        {g_vpHVN[g_vpHVNCount].price=pMin+(i+0.5)*bSize;
         g_vpHVN[g_vpHVNCount].volume=g_bVol[i];
         g_vpHVN[g_vpHVNCount].pct=(total>0)?g_bVol[i]/total*100:0;
         g_vpHVN[g_vpHVNCount].bucket=i;g_vpHVNCount++;}
    for(int i=0;i<bkt&&g_vpLVNCount<InpVP_MaxLVN;i++)
      if(g_bVol[i]>0&&g_bVol[i]<=lvnThr)
        {g_vpLVN[g_vpLVNCount].price=pMin+(i+0.5)*bSize;
         g_vpLVN[g_vpLVNCount].volume=g_bVol[i];
         g_vpLVN[g_vpLVNCount].pct=(total>0)?g_bVol[i]/total*100:0;
         g_vpLVN[g_vpLVNCount].bucket=i;g_vpLVNCount++;} }

void ComputeVPMetrics()
  { if(InpDrawVP&&!InpOptimMode)DrawVPLevels();
    if(!g_sw.active){g_vpScore=0.0;return;}
    double slvl=g_sw.level;
    g_vpPocNearSweep=(MathAbs(g_vpPOC-slvl)<g_ATR*InpVP_POC_Tol);
    g_vpVahNearSweep=(MathAbs(g_vpVAH-slvl)<g_ATR*InpVP_VAL_Tol||
                      MathAbs(g_vpVAL-slvl)<g_ATR*InpVP_VAL_Tol);
    g_vpLvnBeyond=false;
    for(int i=0;i<g_vpLVNCount;i++)
      {double ld=g_vpLVN[i].price-slvl;
       if(g_sw.type==SWEEP_HIGH&&ld>0&&ld<g_ATR*4)  {g_vpLvnBeyond=true;break;}
       if(g_sw.type==SWEEP_LOW&&ld<0&&MathAbs(ld)<g_ATR*4){g_vpLvnBeyond=true;break;}}
    g_vpAbsAtLvl=0;
    for(int i=0;i<g_vpHVNCount;i++)
       if(MathAbs(g_vpHVN[i].price-slvl)<g_ATR*1.5)g_vpAbsAtLvl+=g_vpHVN[i].pct;
    double sc=0;
    if(g_vpVahNearSweep)sc+=30;if(g_vpPocNearSweep)sc+=25;
    if(g_vpLvnBeyond)sc+=20;if(g_vpAbsAtLvl>3)sc+=15;
    double curP=g_sym.Bid();
    if(MathAbs(curP-g_vpVAH)<g_ATR*0.5||MathAbs(curP-g_vpVAL)<g_ATR*0.5) sc+=10;
    g_vpScore=MathMin(sc,100.0); }

void DrawVPLevels()
  { DLine(DPFX+"POC",g_vpPOC,InpClrPOC,STYLE_SOLID,2,"POC");
    DLine(DPFX+"VAH",g_vpVAH,InpClrVAH,STYLE_DOT,1,"VAH");
    DLine(DPFX+"VAL",g_vpVAL,InpClrVAH,STYLE_DOT,1,"VAL");
    for(int i=0;i<g_vpHVNCount;i++)
       DLine(DPFX+"HVN"+IntegerToString(i),g_vpHVN[i].price,InpClrHVN,STYLE_DASH,1,"HVN");
    for(int i=0;i<g_vpLVNCount;i++)
       DLine(DPFX+"LVN"+IntegerToString(i),g_vpLVN[i].price,InpClrLVN,STYLE_DASH,1,"LVN"); }

//+=================================================================+
//|           SIGNAL FUSION                                          |
//+=================================================================+
void FuseSignals()
  { g_sig.total=0;g_sig.sA=0;g_sig.sB=0;g_sig.sC=0;g_sig.sD=0;g_sig.sE=0;
    g_sig.valid=false;g_sig.dir=DIR_NONE;g_sig.modulesConf=0;

    double sA=g_sw.active?g_sw.score:0.0;
    double sB=g_ofr.score;
    double sC=g_amd.score;
    double sD=g_vwScore;
    double sE=g_vpScore;

    bool okA=(sA>=InpModuleMinScore&&g_sw.active);
    bool okB=(sB>=InpModuleMinScore);
    bool okC=(sC>=InpModuleMinScore&&g_amd.phase!=AMD_UNDEFINED);
    bool okD=(sD>=InpModuleMinScore);
    bool okE=(sE>=InpModuleMinScore);

    ENUM_DIRECTION dA=DIR_NONE,dB=DIR_NONE,dC=g_amd.dir,dD=DIR_NONE,dE=DIR_NONE;
    if(okA) dA=(g_sw.type==SWEEP_LOW)?DIR_LONG:DIR_SHORT;
    if(okB)
      { if(g_ofr.bullDiv||(g_ofr.pressureFast>0.55&&g_ofr.cumDelta>0))dB=DIR_LONG;
        else if(g_ofr.bearDiv||(g_ofr.pressureFast<0.45&&g_ofr.cumDelta<0))dB=DIR_SHORT;
        else dB=dA; }
    if(okD)
      { double sigma=g_vaArr[VA_DAY].active?g_vaArr[VA_DAY].devSigma:0;
        if(sigma<-1.0) dD=DIR_LONG;
        else if(sigma>1.0) dD=DIR_SHORT;
        else {
          int sUp=0,sDn=0;
          for(int v=0;v<MAX_VA;v++)
            {if(!g_vwOn[v]||!g_vaArr[v].active)continue;
             if(g_vaArr[v].slope>0.01)sUp++;else if(g_vaArr[v].slope<-0.01)sDn++;}
          if(sUp>sDn+1) dD=DIR_LONG;
          else if(sDn>sUp+1) dD=DIR_SHORT;
          else dD=(!g_vaArr[VA_DAY].active||!g_vaArr[VA_DAY].priceAbove)?DIR_LONG:DIR_SHORT;
        }
        int abvC=0,blwC=0;
        for(int v=0;v<MAX_VA;v++)
          {if(!g_vwOn[v]||!g_vaArr[v].active||g_vaArr[v].value==0)continue;
           if(g_sym.Bid()>g_vaArr[v].value)abvC++;else blwC++;}
        if(abvC>blwC+2) dD=DIR_LONG;
        if(blwC>abvC+2) dD=DIR_SHORT; }
    if(okE) dE=(g_vpMigr>0)?DIR_LONG:(g_vpMigr<0)?DIR_SHORT:dA;

    double wA=g_wA,wB=g_wB,wC=g_wC,wD=g_wD,wE=g_wE;
    switch(g_regime)
      {case REGIME_STRONG:wC*=1.2;wA*=1.1;break;
       case REGIME_HVOL:  wA*=1.4;wB*=1.2;break;
       case REGIME_RANGE: wB*=1.2;wD*=1.2;wE*=1.1;break;
       default:break;}
    double wT=wA+wB+wC+wD+wE;if(wT<=0)return;
    wA=wA/wT*100;wB=wB/wT*100;wC=wC/wT*100;wD=wD/wT*100;wE=wE/wT*100;

    double raw=0;
    raw+=sA*(wA/100.0);raw+=sB*(wB/100.0);raw+=sC*(wC/100.0);
    raw+=sD*(wD/100.0);raw+=sE*(wE/100.0);
    if(InpUseMTF&&dA!=DIR_NONE&&dC!=DIR_NONE&&dA==dC)raw=MathMin(raw*InpMTFMult,100.0);

    int lv=0,sv=0;
    if(dA==DIR_LONG)lv++;if(dA==DIR_SHORT)sv++;
    if(dB==DIR_LONG)lv++;if(dB==DIR_SHORT)sv++;
    if(dC==DIR_LONG)lv++;if(dC==DIR_SHORT)sv++;
    if(dD==DIR_LONG)lv++;if(dD==DIR_SHORT)sv++;
    if(dE==DIR_LONG)lv++;if(dE==DIR_SHORT)sv++;
    ENUM_DIRECTION cons=DIR_NONE;
    if(lv>sv&&lv>=2)cons=DIR_LONG;
    if(sv>lv&&sv>=2)cons=DIR_SHORT;

    int conf=(int)okA+(int)okB+(int)okC+(int)okD+(int)okE;

    bool trendOK=true;
    if(InpUseTrendFilter)
      { double emaF[1],emaS[1];
        if(CopyBuffer(g_hEMA_F,0,0,1,emaF)>=1&&CopyBuffer(g_hEMA_S,0,0,1,emaS)>=1)
          { if(cons==DIR_LONG&&emaF[0]<emaS[0])trendOK=false;
            if(cons==DIR_SHORT&&emaF[0]>emaS[0])trendOK=false; } }

    int conflicts=0;
    if(dA!=DIR_NONE&&dB!=DIR_NONE&&dA!=dB) conflicts++;
    if(dA!=DIR_NONE&&dC!=DIR_NONE&&dA!=dC) conflicts++;
    if(dB!=DIR_NONE&&dC!=DIR_NONE&&dB!=dC) conflicts++;
    if(conflicts>=2) raw*=0.75;

    bool valid=(raw>=InpScoreEntry)&&(cons!=DIR_NONE)&&
               (conf>=InpMinModules)&&okA&&trendOK;

    g_sig.total=raw;g_sig.sA=sA;g_sig.sB=sB;g_sig.sC=sC;g_sig.sD=sD;g_sig.sE=sE;
    g_sig.valid=valid;g_sig.dir=cons;g_sig.modulesConf=conf;g_sig.sigTime=TimeCurrent();
    g_sig.desc=StringFormat("A:%.0f B:%.0f C:%.0f D:%.0f E:%.0f ok:%d%d%d%d%d votes L%d S%d cfx:%d",
                sA,sB,sC,sD,sE,(int)okA,(int)okB,(int)okC,(int)okD,(int)okE,lv,sv,conflicts);
    if(InpVerbose)
       Log(StringFormat("FUSE raw:%.1f cons:%s conf:%d valid:%s ent:%.3f | %s",
           raw,DirStr(cons),conf,B2S(valid),g_entropy,g_sig.desc));
    if(valid)BuildTradeLevels(); }

void BuildTradeLevels()
  { double atr=g_ATR;if(atr<_Point)return;
    ENUM_DIRECTION dir=g_sig.dir;
    double entry=(dir==DIR_LONG)?g_sym.Ask():g_sym.Bid();
    double slDist=atr*InpSL_ATR;
    double sl=(g_sw.active)?
      ((dir==DIR_LONG)?MathMin(g_sw.extreme,entry)-slDist:MathMax(g_sw.extreme,entry)+slDist):
      ((dir==DIR_LONG)?entry-slDist:entry+slDist);
    for(int i=0;i<g_vpHVNCount;i++)
      {double hvn=g_vpHVN[i].price;
       if(dir==DIR_LONG&&hvn<entry&&hvn<sl)sl=hvn-atr*0.3;
       if(dir==DIR_SHORT&&hvn>entry&&hvn>sl)sl=hvn+atr*0.3;}
    double minSLDist=atr*1.0;
    if(MathAbs(entry-sl)<minSLDist)
      sl=(dir==DIR_LONG)?entry-minSLDist:entry+minSLDist;
    // Hard cap: prevent sweep/HVN from pushing SL unreasonably wide
    double maxSLDist=atr*InpSLMaxATR;
    if(MathAbs(entry-sl)>maxSLDist)
      sl=(dir==DIR_LONG)?entry-maxSLDist:entry+maxSLDist;
    g_sig.sl  =g_sym.NormalizePrice(sl);
    double actualSLDist=MathAbs(entry-sl);
    double tp1Dist=MathMax(atr*InpTP1_ATR,actualSLDist);
    g_sig.tp1 =g_sym.NormalizePrice((dir==DIR_LONG)?entry+tp1Dist:entry-tp1Dist);
    g_sig.tp2 =g_sym.NormalizePrice((dir==DIR_LONG)?entry+atr*InpTP2_ATR:entry-atr*InpTP2_ATR);
    g_sig.tp3 =g_sym.NormalizePrice((dir==DIR_LONG)?entry+atr*InpTP3_ATR:entry-atr*InpTP3_ATR);
    g_sig.entry=entry;g_sig.lot=KellyLot(entry,sl);
    Log(StringFormat("[SIGNAL] %s Score:%.1f (%d/5) lot:%.2f entry:%.2f sl:%.2f tp1:%.2f",
        DirStr(dir),g_sig.total,g_sig.modulesConf,g_sig.lot,entry,sl,g_sig.tp1)); }

//+=================================================================+
//| LOT SIZING — 5 modes: AutoLow / AutoMed / AutoHigh / Fixed / Kelly |
//+=================================================================+
// Main lot calculation — called from BuildTradeLevels
double KellyLot(double entry,double sl)
  { double eq  =AccountInfoDouble(ACCOUNT_EQUITY);
    double mn  =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
    double lot  =mn; // safe fallback

    // ── AUTO-LOT modes ────────────────────────────────────────────
    // Formula: equity ÷ 1000 × lotPer1k
    // Examples (LOW, $10,000 balance): 10 × 0.01 = 0.10 lots
    //          (MED, $10,000 balance): 10 × 0.02 = 0.20 lots
    //         (HIGH, $10,000 balance): 10 × 0.03 = 0.30 lots
    if(InpLotMode==LOT_AUTO_LOW || InpLotMode==LOT_AUTO_MED || InpLotMode==LOT_AUTO_HIGH)
      { double perK=(InpLotMode==LOT_AUTO_LOW)?0.01:(InpLotMode==LOT_AUTO_MED)?0.02:0.03;
        lot=(eq/1000.0)*perK;
        // Optional: soft-scale down in high-vol regime or after consecutive losses
        // (kept mild so it NEVER drops to zero — unlike Kelly)
        if(g_regime==REGIME_HVOL)  lot*=0.75;
        if(g_consecLoss>=3)        lot*=0.75;
        if(InpUseAI && g_ai.valid && g_ai.trainedTrades>=InpAILearnTrades)
          lot*=AI_RiskMultiplier();
        lot=NormLot(lot);
        Log(StringFormat("[LOT] AutoLot %s: eq=%.0f perK=%.2f → %.2f lots",
            (InpLotMode==LOT_AUTO_LOW)?"LOW":(InpLotMode==LOT_AUTO_MED)?"MED":"HIGH",
            eq,perK,lot));
        return lot; }

    // ── FIXED LOT ─────────────────────────────────────────────────
    if(InpLotMode==LOT_FIXED)
      { lot=NormLot(InpFixedLot);
        Log(StringFormat("[LOT] Fixed: %.2f lots",lot));
        return lot; }

    // ── KELLY (advanced — needs 15+ trade history) ────────────────
    // If SL is too tight skip (safety guard)
    double sld=MathAbs(entry-sl);
    if(sld<_Point*5)
      { Log("[LOT] Kelly: SL distance < 5 points — using min lot");
        return NormLot(mn); }
    UpdateKelly();
    double kelly;
    if(g_trN<InpKellyMinTrades)
      { kelly=InpRiskMin/100.0;
        Log(StringFormat("[LOT] Kelly warming up (%d/%d trades) — using min risk %.1f%%",
            g_trN,InpKellyMinTrades,InpRiskMin)); }
    else
      { double b=(g_kAL>0)?g_kAW/g_kAL:2.0;
        double p=MathMax(0.1,MathMin(0.9,g_kWR)),q=1-p;
        kelly=(b>0)?((b*p-q)/b):0.25;
        kelly=MathMax(InpRiskMin/100.0,MathMin(InpRiskMax/100.0,kelly*InpKellyFrac)); }
    if(g_regime==REGIME_HVOL)   kelly*=InpRegimeRiskMult;
    if(g_consecLoss>=3&&InpConsecutiveLossScale>0) kelly*=InpConsecutiveLossScale;
    if(InpUseAI && g_ai.valid && g_ai.trainedTrades>=InpAILearnTrades)
      kelly*=AI_RiskMultiplier();
    // Safety floor: never let Kelly go below 0.1% (prevents multiplier stack wiping lot)
    kelly=MathMax(0.001,kelly);
    double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
    double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
    if(tv<=0||ts<=0)
      { Log("[LOT] Kelly: tick value/size = 0 — using min lot");
        return NormLot(mn); }
    lot=(eq*kelly)/((sld/ts)*tv);
    double minEq=(mn*(sld/ts)*tv)/kelly;
    Log(StringFormat("[LOT] Kelly: eq=%.0f kelly=%.2f%% sld=%.2f → %.4f lots (need $%.0f min)",
        eq,kelly*100,sld,lot,minEq));
    // If Kelly still produces sub-minimum, fall back to min lot with a warning
    if(lot<mn)
      { Log(StringFormat("[LOT] Kelly sub-min → using min lot %.2f | Increase balance to ~$%.0f for proper sizing",
            mn,minEq));
        return NormLot(mn); }
    return NormLot(lot); }

void UpdateKelly()
  { int n=MathMin(g_trN,InpMLHistory);if(n<3)return;
    int wins=0;double sw=0,sl=0;
    for(int i=0;i<n;i++)
      {int idx=(g_trIdx-n+i+TRMAX*2)%TRMAX;
       if(g_trHist[idx].wasWin){wins++;sw+=g_trHist[idx].rMult;}else sl+=g_trHist[idx].rMult;}
    g_kWR=(n>0)?(double)wins/n:0.5;
    g_kAW=(wins>0)?sw/wins:2.0;
    g_kAL=(n-wins>0)?sl/(n-wins):1.0; }

void UpdateAdaptiveWeights()
  { if(!InpAdaptWeights)return;
    int n=MathMin(g_trN,InpMLHistory);if(n<5)return;
    double cA=0,cB=0,cC=0,cD=0,cE=0;
    for(int i=0;i<n;i++)
      {int idx=(g_trIdx-n+i+TRMAX*2)%TRMAX;
       double sign=g_trHist[idx].wasWin?1.0:-1.0;
       cA+=sign*g_trHist[idx].sA/100.0;cB+=sign*g_trHist[idx].sB/100.0;
       cC+=sign*g_trHist[idx].sC/100.0;cD+=sign*g_trHist[idx].sD/100.0;
       cE+=sign*g_trHist[idx].sE/100.0;}
    cA/=n;cB/=n;cC/=n;cD/=n;cE/=n;double lr=0.05;
    g_wA=MathMax(5,MathMin(60,g_wA*(1.0+lr*cA)));
    g_wB=MathMax(5,MathMin(60,g_wB*(1.0+lr*cB)));
    g_wC=MathMax(5,MathMin(60,g_wC*(1.0+lr*cC)));
    g_wD=MathMax(5,MathMin(60,g_wD*(1.0+lr*cD)));
    g_wE=MathMax(5,MathMin(60,g_wE*(1.0+lr*cE))); }

void RecordTrade(bool win,double rMult)
  { int idx=g_trIdx%TRMAX;
    g_trHist[idx].wasWin=win;g_trHist[idx].rMult=rMult;g_trHist[idx].score=g_opScore;
    g_trHist[idx].sA=g_sw.score;g_trHist[idx].sB=g_ofr.score;
    g_trHist[idx].sC=g_amd.score;g_trHist[idx].sD=g_vwScore;
    g_trHist[idx].sE=g_vpScore;g_trHist[idx].time=TimeCurrent();
    g_trIdx++;g_trN=MathMin(g_trN+1,TRMAX);
    if(win) g_consecLoss=0; else g_consecLoss++;
    UpdateAdaptiveWeights(); }

//+=================================================================+
//|           EXECUTION & MANAGEMENT                                |
//+=================================================================+
void ExecuteEntry()
  { if(g_sig.lot<=0)
      { double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
        Log(StringFormat("[EXEC] Lot=%.5f is zero/negative — forcing min lot %.2f",g_sig.lot,mn));
        g_sig.lot=mn; }  // force to minimum rather than skip entirely

    // Margin validation: reduce lot if account lacks free margin
    double requiredMargin=g_sym.Ask()*g_sig.lot*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE)/SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
    double freeMgn=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(requiredMargin>freeMgn&&freeMgn>0)
      { double maxLot=NormLot((freeMgn*0.95)/((g_sym.Ask()*SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE))/SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)));
        double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
        if(maxLot>=minLot)
          { Log(StringFormat("[EXEC] Insufficient margin (%.2f<%2f) — reducing lot from %.3f to %.3f",
              freeMgn,requiredMargin,g_sig.lot,maxLot));
            g_sig.lot=maxLot; }
        else
          { Log(StringFormat("[EXEC] Insufficient margin even for min lot (%.2f needed) — SKIPPING",requiredMargin));
            return; } }

    double stopLvl=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
    if(MathAbs(g_sig.entry-g_sig.sl)<stopLvl)
      {Log(StringFormat("SL too close: %.1f < %.1f pts",MathAbs(g_sig.entry-g_sig.sl)/_Point,stopLvl/_Point));return;}
    ENUM_ORDER_TYPE ot=(g_sig.dir==DIR_LONG)?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
    string cmt=StringFormat("%s|%.0f|%s|ai%.0f|vis%d",
       InpCmt,g_sig.total,DirStr(g_sig.dir),g_ai.confidence,
       (InpUseAPIVision&&g_apiVis.valid)?g_apiVis.confidence:0);
    bool ok=false;
    for(int attempt=0;attempt<3;attempt++)
      { g_sym.RefreshRates();
        double ep=(g_sig.dir==DIR_LONG)?g_sym.Ask():g_sym.Bid();
        ok=g_tr.PositionOpen(_Symbol,ot,g_sig.lot,ep,g_sig.sl,g_sig.tp3,cmt);
        if(ok)
          {g_ticket=g_tr.ResultOrder();g_opEntry=ep;g_opSL=g_sig.sl;
           g_opTP1=g_sig.tp1;g_opTP2=g_sig.tp2;g_opTP3=g_sig.tp3;
           g_opLot=g_sig.lot;g_opDir=g_sig.dir;g_opScore=g_sig.total;
           g_opOpenTime=TimeCurrent();
           g_tp1Hit=false;g_tp2Hit=false;g_beSet=false;g_tradesDay++;
           // Snapshot AI features at entry — used later for online learning
           if(InpUseAI)
             { for(int k=0;k<AI_FEATS;k++) g_aiOpenFeats[k]=g_ai.feats[k];
               g_aiOpenDir=g_sig.dir; g_aiOpenConf=g_ai.confidence; }
           if(InpAIWriteJson) AI_LogTrade("OPEN",0,0);
           ResetSweepState();g_sig.valid=false;g_sig.dir=DIR_NONE;
           Log(StringFormat("[TRADE OPEN] %s lot:%.2f E:%.2f SL:%.2f TP1:%.2f TP3:%.2f aiConf:%.1f",
               DirStr(g_opDir),g_opLot,g_opEntry,g_opSL,g_opTP1,g_opTP3,g_aiOpenConf));
           break;}
        uint rc=g_tr.ResultRetcode();
        if(rc==TRADE_RETCODE_REQUOTE||rc==TRADE_RETCODE_PRICE_CHANGED||rc==TRADE_RETCODE_PRICE_OFF)
          {Log(StringFormat("Retry %d/3: code %d",attempt+1,rc));Sleep(200);continue;}
        LogErr(StringFormat("PositionOpen FAIL:%d %s",rc,g_tr.ResultRetcodeDescription()));
        break; } }

void ManageOpenTrade()
  { for(int i=PositionsTotal()-1;i>=0;i--)
      {if(!g_pos.SelectByIndex(i))continue;
       if(g_pos.Magic()!=InpMagic||g_pos.Symbol()!=_Symbol)continue;
       bool   ib=(g_pos.PositionType()==POSITION_TYPE_BUY);
       double opx=g_pos.PriceOpen(),csl=g_pos.StopLoss(),ctp=g_pos.TakeProfit();
       double cur=ib?g_sym.Bid():g_sym.Ask(),sld=MathAbs(opx-csl),nsl=csl;

       if(InpStaleExitBars>0&&!g_tp1Hit&&g_opOpenTime>0)
         { int barsSinceOpen=iBarShift(_Symbol,_Period,g_opOpenTime);
           if(barsSinceOpen>=InpStaleExitBars)
             { Log(StringFormat("[STALE EXIT] %d bars, no TP1",barsSinceOpen));
               g_tr.PositionClose(g_pos.Ticket());return; } }

       if(!g_tp1Hit&&InpTP1_Pct>0)
         {bool hit=(ib&&cur>=g_opTP1)||(!ib&&cur<=g_opTP1);
          if(hit){double cl=NormLot(g_opLot*(InpTP1_Pct/100.0));
            if(cl>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
              if(g_tr.PositionClosePartial(g_pos.Ticket(),cl))g_tp1Hit=true;}}
       if(g_tp1Hit&&!g_tp2Hit&&InpTP2_Pct>0)
         {bool hit=(ib&&cur>=g_opTP2)||(!ib&&cur<=g_opTP2);
          if(hit){double cl=NormLot(g_opLot*(InpTP2_Pct/100.0));
            if(cl>=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN))
              if(g_tr.PositionClosePartial(g_pos.Ticket(),cl))g_tp2Hit=true;}}
       if(InpUseBE&&!g_beSet&&sld>0)
         {double beTr=opx+(ib?1:-1)*sld*InpBE_RMult;
          if((ib&&cur>=beTr)||(!ib&&cur<=beTr)){nsl=opx+(ib?1:-1)*_Point*2;g_beSet=true;}}
       if(InpUseTrail&&g_beSet&&sld>0)
         {double trT=opx+(ib?1:-1)*sld*InpTrailStart;
          bool trA=(ib&&cur>=trT)||(!ib&&cur<=trT);
          if(trA){double trSL=g_sym.NormalizePrice(ib?cur-g_ATR*InpTrailATR:cur+g_ATR*InpTrailATR);
            if(ib&&trSL>nsl) nsl=trSL;
            if(!ib&&trSL<nsl&&nsl>0) nsl=trSL;}}
       if(g_vwClusterCount>=InpVWAP_ClsMin&&g_vwClusterPrice>0&&g_beSet)
         {bool cx=(ib&&cur<g_vwClusterPrice)||(!ib&&cur>g_vwClusterPrice);
          if(cx){double vs2=g_sym.NormalizePrice(ib?cur-g_ATR*0.5:cur+g_ATR*0.5);
            if(ib&&vs2>nsl) nsl=vs2;
            if(!ib&&vs2<nsl&&nsl>0) nsl=vs2;}}

       // Safety gate before modification — broker Stops/Freeze level aware.
       // The "close to market" rejection is caused by the broker's
       // SYMBOL_TRADE_STOPS_LEVEL / SYMBOL_TRADE_FREEZE_LEVEL constraints.
       if(nsl!=csl&&nsl!=0.0)
         {
          long   stopsLvl =(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
          long   freezeLvl=(long)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
          double bid=g_sym.Bid(),ask=g_sym.Ask(),spread=ask-bid;
          double brokerBuf=(double)MathMax(stopsLvl,freezeLvl)*_Point;
          // Buffer = strictest of: broker level, 4x spread, 0.4 ATR.
          double safeBuf  =MathMax(brokerBuf,MathMax(spread*4.0,g_ATR*0.4));
          if(safeBuf<30*_Point) safeBuf=30*_Point;   // absolute floor

          // Clamp candidate SL to a broker-safe distance from current price
          if(ib) nsl=MathMin(nsl,bid-safeBuf);       // BUY  SL must sit below Bid
          else   nsl=MathMax(nsl,ask+safeBuf);       // SELL SL must sit above Ask
          nsl=g_sym.NormalizePrice(nsl);

          // SL must keep a safe gap from TP, and must be a genuine improvement
          bool slTpOK  =(ctp<=0)||(ib?(nsl<ctp-safeBuf):(nsl>ctp+safeBuf));
          bool improves=(ib?(nsl>csl):(csl<=0||nsl<csl));
          // Freeze level: cannot modify while existing SL/TP is inside freeze band
          bool freezeOK=true;
          if(freezeLvl>0)
            { double frz=(double)freezeLvl*_Point;
              if(ib){ if(csl>0&&bid-csl<frz) freezeOK=false;
                      if(ctp>0&&ctp-bid<frz) freezeOK=false; }
              else  { if(csl>0&&csl-ask<frz) freezeOK=false;
                      if(ctp>0&&ask-ctp<frz) freezeOK=false; } }

          if(slTpOK&&improves&&freezeOK&&MathAbs(nsl-csl)>=_Point)
             g_tr.PositionModify(g_pos.Ticket(),nsl,ctp);
          else if(InpVerbose)
             Log(StringFormat("[MODIFY SKIPPED] slTpOK=%s impr=%s frzOK=%s nsl=%.5f csl=%.5f bid=%.5f ask=%.5f buf=%.0fpt",
                 B2S(slTpOK),B2S(improves),B2S(freezeOK),nsl,csl,bid,ask,safeBuf/_Point));
         }
    } }

void OnOurTradeClosed(ulong dealTicket)
  { if(!HistoryDealSelect(dealTicket))return;
    double profit=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
    double sld=MathAbs(g_opEntry-g_opSL);
    double rMult=(sld>0&&g_opLot>0)?profit/(sld*g_opLot):0.0;
    g_dayRealizedPnL+=profit;
    bool win=(profit>0);
    RecordTrade(win,MathAbs(rMult));
    // AI online learning — uses features captured at entry
    if(InpUseAI && g_aiOpenDir!=DIR_NONE)
      { AI_RecordOutcome(win,MathAbs(rMult));
        if(InpAIWriteJson) AI_LogTrade("CLOSE",profit,rMult); }
    g_lastTradeClose=TimeCurrent();
    Log(StringFormat("[CLOSED] %s P/L:$%.2f R:%.2f consLoss:%d",DirStr(g_opDir),profit,rMult,g_consecLoss));
    ResetOpenTradeVars(); }

void ResetOpenTradeVars()
  {g_ticket=0;g_opDir=DIR_NONE;g_opEntry=0;g_opSL=0;g_opLot=0;
   g_opOpenTime=0;g_tp1Hit=false;g_tp2Hit=false;g_beSet=false;
   g_aiOpenDir=DIR_NONE;g_aiOpenConf=0;}

//+=================================================================+
ENUM_REGIME ClassifyRegime(double adx,double atr)
  { double buf[];ArrayResize(buf,InpRegimeLB);ArraySetAsSeries(buf,true);
    double pct=50.0;
    if(CopyBuffer(g_hATR,0,1,InpRegimeLB,buf)>=InpRegimeLB)
      {int below=0;for(int i=0;i<InpRegimeLB;i++)if(buf[i]<atr)below++;
       pct=(double)below/InpRegimeLB*100.0;}
    if(pct>=InpVolPctile)return REGIME_HVOL;
    if(adx>=InpStrongADX)return REGIME_STRONG;
    if(adx>=InpTrendADX) return REGIME_WEAK;
    return REGIME_RANGE; }

void ScanNewsCalendar()
  { g_lastScan=TimeCurrent();g_newsN=0;g_newsBlk=false;g_blkEvt="";
    if(!InpUseNews)return;
    datetime dtF=TimeCurrent()-6*3600,dtT=TimeCurrent()+24*3600;
    MqlCalendarValue all[];
    if(InpNewsUSD){MqlCalendarValue v[];int n=CalendarValueHistory(v,dtF,dtT,"USD",NULL);
      if(n>0){int s=ArraySize(all);ArrayResize(all,s+n);for(int i=0;i<n;i++)all[s+i]=v[i];}}
    if(InpNewsEUR){MqlCalendarValue v[];int n=CalendarValueHistory(v,dtF,dtT,"EUR",NULL);
      if(n>0){int s=ArraySize(all);ArrayResize(all,s+n);for(int i=0;i<n;i++)all[s+i]=v[i];}}
    datetime now=TimeCurrent();
    for(int i=0;i<ArraySize(all)&&g_newsN<NMAX;i++)
      {MqlCalendarEvent evt;if(!CalendarEventById(all[i].event_id,evt))continue;
       int imp=(int)evt.importance;
       if(InpNewsHighOnly&&imp<CALENDAR_IMPORTANCE_HIGH)continue;
       if(!InpNewsHighOnly&&imp<CALENDAR_IMPORTANCE_MODERATE)continue;
       MqlCalendarCountry c;CalendarCountryById(evt.country_id,c);
       g_news[g_newsN].evtTime=all[i].time;g_news[g_newsN].country=c.currency;
       g_news[g_newsN].name=evt.name;g_news[g_newsN].imp=imp;g_news[g_newsN].blocking=false;
       long sTo=(long)all[i].time-(long)now,sSn=(long)now-(long)all[i].time;
       if((sTo>=0&&sTo<=(long)InpNewsBefore*60)||(sSn>=0&&sSn<=(long)InpNewsAfter*60))
         {g_news[g_newsN].blocking=true;
          if(!g_newsBlk){g_newsBlk=true;g_blkEvt=evt.name;g_blkTime=all[i].time;}}
       g_newsN++;} }

bool PositionExistsMagic()
  {for(int i=PositionsTotal()-1;i>=0;i--)
     if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagic&&g_pos.Symbol()==_Symbol)return true;
   return false;}
int CountOurPositions()
  {int cnt=0;for(int i=PositionsTotal()-1;i>=0;i--)
     if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagic&&g_pos.Symbol()==_Symbol)cnt++;
   return cnt;}
void CloseAll()
  {for(int i=PositionsTotal()-1;i>=0;i--)
     if(g_pos.SelectByIndex(i)&&g_pos.Magic()==InpMagic&&g_pos.Symbol()==_Symbol)g_tr.PositionClose(g_pos.Ticket());}
double NormLot(double lot)
  { double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
    double mn  =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
    double mx  =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
    double vl  =SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
    if(vl>0) mx=MathMin(mx,vl);
    if(step>0) lot=MathFloor(lot/step)*step;
    if(lot<mn) lot=mn;   // floor to minimum — NEVER return 0 from normalization
    return MathMin(lot,mx); }
string B2S(bool b)              {return b?"Y":"N";}
string DirStr(ENUM_DIRECTION d) {return d==DIR_LONG?"LONG":d==DIR_SHORT?"SHORT":"NONE";}
string PhaseStr(ENUM_AMD_PHASE p)
  {switch(p){case AMD_ACCUMULATION:return"ACCUM";case AMD_MANIPULATION:return"MANIP";
   case AMD_DISTRIBUTION:return"DIST";case AMD_MARKUP:return"MARKUP";
   case AMD_MARKDOWN:return"MKDN";default:return"UNDEF";}}
string RgmStr(ENUM_REGIME r)
  {switch(r){case REGIME_STRONG:return"STRONG";case REGIME_WEAK:return"WEAK";
   case REGIME_HVOL:return"HVOL";default:return"RANGE";}}
string MB(double v,double mx,int w)
  {if(mx<=0)return"[.............]";
   int f=MathMax(0,MathMin((int)MathRound(MathMin(v/mx,1.0)*w),w));
   string b="[";for(int i=0;i<w;i++)b+=(i<f)?"|":".";return b+"]";}
void Log(string m)
  { if(g_quiet) return;
    PrintFormat("[LQS5] %s | %s",TimeToString(TimeCurrent(),TIME_SECONDS),m); }
void Verbose(string m)
  { if(g_quiet) return;
    if(InpVerbose)PrintFormat("[LQS5][V] %s",m); }
void Warn(string m)
  { if(g_quiet) return;
    PrintFormat("[LQS5][W] %s",m); }
void LogErr(string m)
  { PrintFormat("[LQS5][ERR] %s | err:%d",m,GetLastError()); }

//+=================================================================+
//|           AI DECISION LAYER                                      |
//|                                                                  |
//| WHAT IT IS (no buzzwords):                                       |
//|   In-process online logistic-style classifier. 7 features         |
//|   describing the current setup are blended via learned weights   |
//|   and a logistic squash to produce confidence in [0,100].        |
//|   Online learning: after each trade, weights are updated with    |
//|   one gradient step toward the realised win/loss outcome.        |
//|                                                                  |
//| WHAT IT IS NOT:                                                  |
//|   Not a neural net. Not random. Not an external API call.        |
//|   Not a direction generator — fusion picks the side, AI decides  |
//|   whether to trust it and how much risk to allocate.             |
//+=================================================================+
void AI_Init()
  { for(int i=0;i<AI_FEATS;i++) g_ai.weights[i]=InpAIInitWeight;
    for(int i=0;i<AI_FEATS;i++) g_ai.feats[i]=0.5;
    g_ai.confidence=0; g_ai.regimeScore=0; g_ai.volScore=0; g_ai.baseScore=0;
    g_ai.verdict=DIR_NONE; g_ai.valid=false; g_ai.stamp=0;
    g_ai.trainedTrades=0; g_ai.avgConf=0;
    for(int i=0;i<AI_HIST;i++){ g_aiHist[i].used=false; g_aiHist[i].rMult=0; g_aiHist[i].win=false; }
    g_aiN=0; g_aiIdx=0;
    for(int i=0;i<AI_FEATS;i++) g_aiOpenFeats[i]=0;
    g_aiOpenDir=DIR_NONE; g_aiOpenConf=0;
    if(InpAIVerbose) Log("[AI] init: 7-feature classifier, online-learning enabled"); }

double Sigmoid01(double x)
  { // Map to [0,1] — input typically in [-3,3] for sensible output
    return 1.0/(1.0+MathExp(-x)); }

double Clip01(double v) { return MathMax(0.0,MathMin(1.0,v)); }

void AI_ComputeFeatures()
  {
   // Feature 1: regime alignment with proposed direction
   double regAlign=0.5;
   if(g_sig.dir!=DIR_NONE)
     { switch(g_regime)
         { case REGIME_STRONG: regAlign=(g_sig.dir==DIR_LONG && g_amd.coBull>g_amd.coBear) ||
                                        (g_sig.dir==DIR_SHORT && g_amd.coBear>g_amd.coBull) ? 0.85 : 0.45; break;
           case REGIME_WEAK:   regAlign=0.65; break;
           case REGIME_RANGE:  regAlign=0.55; break;
           case REGIME_HVOL:   regAlign=0.40; break; } }
   g_ai.feats[0]=Clip01(regAlign);

   // Feature 2: module agreement ratio (how many of 5 modules confirmed)
   g_ai.feats[1]=Clip01(g_sig.modulesConf/5.0);

   // Feature 3: similarity to past winners — kNN-lite cosine match
   g_ai.feats[2]=Clip01(AI_HistorySimilarity());

   // Feature 4: volatility normality — sweet spot near median
   double atrPct=50.0;
   double abuf[]; ArraySetAsSeries(abuf,true);
   if(CopyBuffer(g_hATR,0,1,InpRegimeLB,abuf)>=InpRegimeLB && g_ATR>0)
     { int below=0;
       for(int i=0;i<InpRegimeLB;i++) if(abuf[i]<g_ATR) below++;
       atrPct=(double)below/InpRegimeLB*100.0; }
   // Sweet spot: 35..70 percentile = good. Outside = risky.
   double volNorm=1.0-MathAbs(atrPct-52.5)/52.5;
   g_ai.feats[3]=Clip01(volNorm);

   // Feature 5: entropy quality (higher structure score = better)
   g_ai.feats[4]=Clip01(g_entropy);

   // Feature 6: VWAP proximity — for mean reversion signals, closer is better
   double vwapProx=0.5;
   if(g_vwOn[VA_DAY] && g_vaArr[VA_DAY].active && g_vaArr[VA_DAY].value>0 && g_ATR>0)
     { double dATR=MathAbs(g_sym.Bid()-g_vaArr[VA_DAY].value)/g_ATR;
       // Best edge is 0.5..2.0 ATR from VWAP (not glued, not blown out)
       if(dATR<0.3) vwapProx=0.45;
       else if(dATR<2.0) vwapProx=0.85-((dATR-0.3)/1.7)*0.20;
       else vwapProx=MathMax(0.30,0.65-(dATR-2.0)*0.10); }
   g_ai.feats[5]=Clip01(vwapProx);

   // Feature 7: session/time bias — London + NY overlap historically best for XAU
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   double timeBias=0.5;
   if(dt.hour>=InpLondonHour && dt.hour<InpNYHour) timeBias=0.70;        // London open
   else if(dt.hour>=InpNYHour && dt.hour<InpNYHour+4) timeBias=0.85;     // London/NY overlap
   else if(dt.hour>=InpNYHour+4 && dt.hour<InpNYHour+7) timeBias=0.65;   // NY only
   else if(dt.hour>=InpAsianStart && dt.hour<InpAsianEnd) timeBias=0.40; // Asian
   else timeBias=0.45;
   g_ai.feats[6]=Clip01(timeBias);
  }

double AI_HistorySimilarity()
  { // Cosine-style similarity to past WINNING trades only
    if(g_aiN<5) return 0.5; // not enough history yet → neutral
    double bestSim=0; int matches=0;
    // Use the in-progress feature snapshot (g_ai.feats already partially filled,
    // but call this BEFORE assigning feats[2] so we use the prior bar's vector).
    double cur[AI_FEATS];
    for(int i=0;i<AI_FEATS;i++) cur[i]=g_ai.feats[i];
    int n=MathMin(g_aiN,AI_HIST);
    double sumSim=0;
    for(int i=0;i<n;i++)
      { if(!g_aiHist[i].used) continue;
        if(!g_aiHist[i].win) continue;
        double dot=0,na=0,nb=0;
        for(int k=0;k<AI_FEATS;k++)
          { dot+=cur[k]*g_aiHist[i].feats[k];
            na+=cur[k]*cur[k];
            nb+=g_aiHist[i].feats[k]*g_aiHist[i].feats[k]; }
        if(na<=0||nb<=0) continue;
        double sim=dot/(MathSqrt(na)*MathSqrt(nb));
        if(sim>bestSim) bestSim=sim;
        sumSim+=sim; matches++; }
    if(matches==0) return 0.45;
    double avg=sumSim/matches;
    // Blend best and average (60/40) so a single match doesn't dominate
    return MathMax(0.0,MathMin(1.0,bestSim*0.6+avg*0.4)); }

void AI_BarUpdate()
  {
   if(g_lastBarT==g_aiLastBar) return; // only once per bar
   g_aiLastBar=g_lastBarT;

   AI_ComputeFeatures();

   // Linear combination → logistic squash
   double z=-1.0; // baseline bias to be conservative
   for(int i=0;i<AI_FEATS;i++) z+=g_ai.weights[i]*(g_ai.feats[i]-0.5)*2.0; // center features
   double conf01=Sigmoid01(z*2.0); // scale up for sharper response
   g_ai.confidence=conf01*100.0;
   g_ai.baseScore=g_sig.total;
   g_ai.verdict=g_sig.dir;
   g_ai.valid=true;
   g_ai.stamp=TimeCurrent();

   // Running average
   if(g_ai.avgConf<=0) g_ai.avgConf=g_ai.confidence;
   else g_ai.avgConf=g_ai.avgConf*0.9+g_ai.confidence*0.1;

   // Auxiliary scores (for dashboard & journaling)
   g_ai.regimeScore=g_ai.feats[0]*100.0;
   g_ai.volScore=g_ai.feats[3]*100.0;

   if(InpAIVerbose)
     Log(StringFormat("[AI] conf:%.1f reg:%.0f mod:%.0f sim:%.0f vol:%.0f ent:%.0f vw:%.0f tm:%.0f",
         g_ai.confidence,g_ai.feats[0]*100,g_ai.feats[1]*100,g_ai.feats[2]*100,
         g_ai.feats[3]*100,g_ai.feats[4]*100,g_ai.feats[5]*100,g_ai.feats[6]*100));
  }

double AI_RiskMultiplier()
  { // Scale risk based on AI confidence band
    if(!g_ai.valid) return 1.0;
    if(g_ai.confidence>=InpAIBoostThresh) return InpAIBoostMult; // boost
    if(g_ai.confidence>=InpAIMinConf)     return InpAIDampMult;  // dampen but allow
    return 0.5; // very low confidence — hard cap if somehow allowed
  }

void AI_RecordOutcome(bool win,double rMult)
  { // Store the snapshot taken at trade open
    int idx=g_aiIdx%AI_HIST;
    for(int k=0;k<AI_FEATS;k++) g_aiHist[idx].feats[k]=g_aiOpenFeats[k];
    g_aiHist[idx].win=win;
    g_aiHist[idx].rMult=rMult;
    g_aiHist[idx].dir=g_aiOpenDir;
    g_aiHist[idx].t=TimeCurrent();
    g_aiHist[idx].used=true;
    g_aiIdx++; if(g_aiN<AI_HIST) g_aiN++;
    g_ai.trainedTrades++;

    // Online gradient update — predicted vs actual (target = 1 win, 0 loss)
    // pred = sigmoid of linear combo on the snapshot features
    double z=-1.0;
    for(int k=0;k<AI_FEATS;k++) z+=g_ai.weights[k]*(g_aiOpenFeats[k]-0.5)*2.0;
    double pred=Sigmoid01(z*2.0);
    double target=(win?1.0:0.0);
    double err=target-pred;
    // Weight more by trade R: a +3R win teaches more than a +0.2R scrape
    double mag=MathMin(MathAbs(rMult),5.0)+0.5;
    double lr=InpAILearnRate*mag;
    for(int k=0;k<AI_FEATS;k++)
      { double grad=err*(g_aiOpenFeats[k]-0.5)*2.0;
        g_ai.weights[k]+=lr*grad;
        // Clamp weights to prevent runaway
        g_ai.weights[k]=MathMax(-1.5,MathMin(1.5,g_ai.weights[k])); }
    if(InpAIVerbose)
      Log(StringFormat("[AI] learn: win=%s pred=%.2f err=%.2f w=[%.2f %.2f %.2f %.2f %.2f %.2f %.2f]",
          B2S(win),pred,err,g_ai.weights[0],g_ai.weights[1],g_ai.weights[2],
          g_ai.weights[3],g_ai.weights[4],g_ai.weights[5],g_ai.weights[6]));
  }

//+=================================================================+
//| AI / JSON Journal Writers                                        |
//+=================================================================+
void AI_LogSnapshot(string evt)
  { if(!InpAIWriteJson) return;
    CLqsJson j; j.Begin();
    j.KStr("event",evt);
    j.KInt("ts",(long)TimeCurrent());
    j.KStr("symbol",_Symbol);
    j.KStr("tf",EnumToString(_Period));
    j.KDbl("bid",g_sym.Bid(),2);
    j.KDbl("ask",g_sym.Ask(),2);
    j.KDbl("atr",g_ATR,5);
    j.KDbl("adx",g_ADX,2);
    j.KStr("regime",RgmStr(g_regime));
    j.KDbl("entropy",g_entropy,4);
    j.KDbl("score",g_sig.total,2);
    j.KStr("dir",DirStr(g_sig.dir));
    j.KInt("modsConf",g_sig.modulesConf);
    j.KDbl("sA",g_sw.score,1); j.KDbl("sB",g_ofr.score,1);
    j.KDbl("sC",g_amd.score,1); j.KDbl("sD",g_vwScore,1);
    j.KDbl("sE",g_vpScore,1);
    j.KDbl("aiConf",g_ai.confidence,2);
    j.KDbl("aiReg",g_ai.regimeScore,2);
    j.KDbl("aiVol",g_ai.volScore,2);
    double tmpFeats[AI_FEATS], tmpWeights[AI_FEATS];
    for(int i=0;i<AI_FEATS;i++){ tmpFeats[i]=g_ai.feats[i]; tmpWeights[i]=g_ai.weights[i]; }
    j.KArrDbl("aiFeats",tmpFeats,4);
    j.KArrDbl("aiWeights",tmpWeights,4);
    j.KInt("aiTrained",g_ai.trainedTrades);
    JournalAppend(j.End()); }

void AI_LogTrade(string evt,double profit,double rMult)
  { if(!InpAIWriteJson) return;
    CLqsJson j; j.Begin();
    j.KStr("event",evt);
    j.KInt("ts",(long)TimeCurrent());
    j.KStr("symbol",_Symbol);
    j.KInt("ticket",(long)g_ticket);
    j.KStr("dir",DirStr(g_opDir));
    j.KDbl("lot",g_opLot,2);
    j.KDbl("entry",g_opEntry,5);
    j.KDbl("sl",g_opSL,5);
    j.KDbl("tp1",g_opTP1,5);
    j.KDbl("tp2",g_opTP2,5);
    j.KDbl("tp3",g_opTP3,5);
    j.KDbl("score",g_opScore,2);
    j.KDbl("aiConfAtOpen",g_aiOpenConf,2);
    double tmpOpenFeats[AI_FEATS];
    for(int i=0;i<AI_FEATS;i++) tmpOpenFeats[i]=g_aiOpenFeats[i];
    j.KArrDbl("aiFeatsAtOpen",tmpOpenFeats,4);
    if(StringCompare(evt,"CLOSE")==0)
      { j.KDbl("profit",profit,2);
        j.KDbl("rMult",rMult,3); }
    JournalAppend(j.End()); }

//+=================================================================+
//|           DASHBOARD                                             |
//+=================================================================+
void DashCreate()
  {if(!InpShowDash||InpOptimMode)return;
   DRect(DPFX+"BG",InpDashX-4,InpDashY-4,InpDashW+8,DASH_H,InpClrBg,InpClrBorder,2);
   g_dashOK=true;ChartRedraw(0);}

void DashUpdate()
  {if(!InpShowDash||!g_dashOK||InpOptimMode)return;
   datetime now=TimeCurrent();
   double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double pnlU=eq-g_startEq,pnlP=(g_startEq>0)?pnlU/g_startEq*100:0;
   double spd=(g_sym.Ask()-g_sym.Bid())/_Point;
   DL("H1"," LQS-AI v5.0  |  5-Module + AI Decision Layer",InpClrHeader,9,RY_H1);
   DL("H2",StringFormat(" %s %s  |  %s  |  %s",_Symbol,EnumToString(_Period),
       TimeToString(now,TIME_SECONDS),RgmStr(g_regime)),InpClrNeutral,8,RY_H2);
   string st="";color sc2=InpClrNeutral;
   switch(g_state)
     {case ST_IDLE: st=" [.] IDLE";sc2=InpClrNeutral;break;
      case ST_SWEEP:st=" [A] SWEEP";sc2=InpClrWarn;break;
      case ST_OFR:  st=" [AB] SWEEP+OFR";sc2=InpClrWarn;break;
      case ST_READY:st=StringFormat(" [*] ENTRY READY  %.0f",g_sig.total);sc2=InpClrBuy;break;
      case ST_TRADE:st=" [T] IN TRADE";sc2=InpClrBuy;break;
      case ST_LOCK: st=" [X] LOCKED";sc2=InpClrSell;break;
      case ST_NEWS: st=" [!] NEWS";sc2=InpClrWarn;break;
      default:st=" [.]";sc2=InpClrNeutral;}
   DL("ST",st,sc2,8,RY_ST);
   DL("SC",StringFormat(" Score:%s %.1f/100  Min:%.0f  Mods:%d/5  Dir:%s",
       MB(g_sig.total,100,12),g_sig.total,InpScoreEntry,g_sig.modulesConf,DirStr(g_sig.dir)),
       g_sig.total>=InpScoreEntry?InpClrBuy:InpClrNeutral,8,RY_SC);
   DL("A0"," -- MODULE A: SWEEP -------------------------",InpClrHeader,8,RY_A0);
   DL("AT",StringFormat(" LiqLvls:%d  Sw:%s lvl:%.2f sc:%.0f Age:%db",
       g_liqN,g_sw.active?((g_sw.type==SWEEP_LOW)?"LOW>BUY":"HIGH>SELL"):"None",
       g_sw.active?g_sw.level:0.0,g_sw.score,g_sw.barsAgo),
       g_sw.active?(g_sw.type==SWEEP_LOW?InpClrBuy:InpClrSell):InpClrNeutral,8,RY_AT);
   DL("AS",StringFormat(" Score:%s %.0f  Wk:%.0f%%  Vol:%.1fx  Rev:%.0f%%",
       MB(g_sw.score,100,10),g_sw.score,g_sw.wickPct,g_sw.volRatio,g_sw.reversalStr),
       g_sw.score>=InpModuleMinScore?InpClrBuy:InpClrNeutral,8,RY_AS);
   DL("B0"," -- MODULE B: ORDER FLOW ---------------------",InpClrHeader,8,RY_B0);
   DL("BC",StringFormat(" Delta:%+.0f  PF:%.0f%%  Imb:%.2f  Abs:%.0f",
       g_ofr.cumDelta,g_ofr.pressureFast*100,g_ofr.ofImbalance,g_ofr.absorptionScore),
       g_ofr.cumDelta>0?InpClrBuy:InpClrSell,8,RY_BC);
   DL("BD",StringFormat(" BullDiv:%s  BearDiv:%s  Exhaust:%.0f",
       B2S(g_ofr.bullDiv),B2S(g_ofr.bearDiv),g_ofr.exhaustionScore),
       (g_ofr.bullDiv||g_ofr.bearDiv)?InpClrWarn:InpClrNeutral,8,RY_BD);
   DL("BS",StringFormat(" Score:%s %.0f",MB(g_ofr.score,100,10),g_ofr.score),
       g_ofr.score>=InpModuleMinScore?InpClrBuy:InpClrNeutral,8,RY_BS);
   DL("C0"," -- MODULE C: AMD WYCKOFF --------------------",InpClrHeader,8,RY_C0);
   DL("CP",StringFormat(" Phase:%s  Dir:%s  EndM:%s  Dur:%d",
       PhaseStr(g_amd.phase),DirStr(g_amd.dir),B2S(g_amd.endManip),g_amd.duration),
       g_amd.phase==AMD_MANIPULATION?InpClrWarn:InpClrNeutral,8,RY_CP);
   DL("CS",StringFormat(" Bull:%.0f%%  Bear:%.0f%%  Spr:%s  UPT:%s  VC:%s",
       g_amd.coBull,g_amd.coBear,B2S(g_amd.spring),B2S(g_amd.upthrust),B2S(g_amd.volClimax)),InpClrData,8,RY_CS);
   DL("CR",StringFormat(" Score:%s %.0f",MB(g_amd.score,100,10),g_amd.score),
       g_amd.score>=InpModuleMinScore?InpClrBuy:InpClrNeutral,8,RY_CR);
   DL("D0"," -- MODULE D: VWAP ---------------------------",InpClrHeader,8,RY_D0);
   DL("DC",StringFormat(" Active:%d  Cluster:%d@%.0f  Aligned:%s",
       g_vwActiveCount,g_vwClusterCount,g_vwClusterPrice,B2S(g_vwAlignedAtLevel)),InpClrData,8,RY_DC);
   DL("DS",StringFormat(" Score:%s %.0f  DayVWAP:%.2f  Slope:%.3f",MB(g_vwScore,100,10),g_vwScore,
       (g_vwOn[VA_DAY]&&g_vaArr[VA_DAY].active)?g_vaArr[VA_DAY].value:0.0,
       (g_vwOn[VA_DAY]&&g_vaArr[VA_DAY].active)?g_vaArr[VA_DAY].slope:0.0),
       g_vwScore>=InpModuleMinScore?InpClrBuy:InpClrNeutral,8,RY_DS);
   DL("E0"," -- MODULE E: VOL PROFILE --------------------",InpClrHeader,8,RY_E0);
   DL("EP",StringFormat(" POC:%.2f  VAH:%.2f  VAL:%.2f  Migr:%s",
       g_vpPOC,g_vpVAH,g_vpVAL,g_vpMigr>0?"+UP":g_vpMigr<0?"-DN":"FLAT"),
       g_vpMigr>0?InpClrBuy:g_vpMigr<0?InpClrSell:InpClrNeutral,8,RY_EP);
   DL("ES",StringFormat(" Score:%s %.0f  POC@Sw:%s  LVN>:%s",
       MB(g_vpScore,100,10),g_vpScore,B2S(g_vpPocNearSweep),B2S(g_vpLvnBeyond)),
       g_vpScore>=InpModuleMinScore?InpClrBuy:InpClrNeutral,8,RY_ES);
   DL("N0"," -- NEXT TRADE -------------------------------",InpClrHeader,8,RY_N0);
   if(g_sig.valid&&g_sig.lot>0)
     {color dc=(g_sig.dir==DIR_LONG)?InpClrBuy:InpClrSell;
      DL("ND",StringFormat(" Dir:%s  Score:%.1f  Mods:%d/5",DirStr(g_sig.dir),g_sig.total,g_sig.modulesConf),dc,8,RY_ND);
      DL("NL",StringFormat(" Lot:%.2f  E:%.2f  SL:%.2f",g_sig.lot,g_sig.entry,g_sig.sl),InpClrData,8,RY_NL);
      DL("NS",StringFormat(" TP1:%.2f  TP2:%.2f  TP3:%.2f",g_sig.tp1,g_sig.tp2,g_sig.tp3),InpClrBuy,8,RY_NS);
      double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double rsk=(ts>0&&tv>0)?g_sig.lot*(MathAbs(g_sig.entry-g_sig.sl)/ts)*tv:0;
      DL("NR",StringFormat(" Risk:$%.2f  R:R %.1f:1  Kelly:%.0f%%",rsk,InpTP3_ATR/InpSL_ATR,InpKellyFrac*100),InpClrData,8,RY_NR);}
   else
     {DL("ND",StringFormat(" Waiting: score<%.0f or no sweep (liq:%d)",InpScoreEntry,g_liqN),InpClrNeutral,8,RY_ND);
      DL("NL",StringFormat(" Modules ok: A:%s B:%s C:%s D:%s E:%s",
          B2S(g_sw.active&&g_sw.score>=InpModuleMinScore),B2S(g_ofr.score>=InpModuleMinScore),
          B2S(g_amd.score>=InpModuleMinScore),B2S(g_vwScore>=InpModuleMinScore),
          B2S(g_vpScore>=InpModuleMinScore)),InpClrNeutral,8,RY_NL);
      DL("NS",StringFormat(" %s",StringLen(g_sig.desc)>0?g_sig.desc:"No fusion yet"),InpClrNeutral,7,RY_NS);
      DL("NR","",InpClrNeutral,8,RY_NR);}
   DL("SE"," -- SESSION ----------------------------------",InpClrHeader,8,RY_SE);
   color pc2=(pnlU>=0)?InpClrBuy:InpClrSell;
   DL("SP",StringFormat(" P/L:%s$%.2f(%s%.2f%%)  Bal:$%.0f  Trades:%d/%d  Bars:%d",
       pnlU>=0?"+":"",pnlU,pnlU>=0?"+":"",pnlP,bal,g_tradesDay,InpMaxDailyTrades,g_barCnt),pc2,8,RY_SP);
   DL("MK"," -- MARKET -----------------------------------",InpClrHeader,8,RY_MK);
   DL("MB",StringFormat(" Bid:%.2f  Spd:%.0f/%.0f  ATR:%.2f  ADX:%.1f",
       g_sym.Bid(),spd,InpMaxSpread,g_ATR,g_ADX),(spd>InpMaxSpread*0.8)?InpClrWarn:InpClrData,8,RY_MB);
   DL("MS",StringFormat(" Asia:H%.0f L%.0f  Lon:%.0f  NY:%.0f  dayOp:%.0f",
       g_asianH>-1e8?g_asianH:0,g_asianL<1e8?g_asianL:0,g_londonOp,g_nyOp,g_dayOp),InpClrData,8,RY_MS);
   DL("KL",StringFormat(" Kelly WR:%.0f%%  AW:%.1fR  AL:%.1fR  Wts:A%.0f B%.0f C%.0f D%.0f E%.0f",
       g_kWR*100,g_kAW,g_kAL,g_wA,g_wB,g_wC,g_wD,g_wE),InpClrNeutral,7,RY_KL);
   DL("WT",StringFormat(" v5.0 Magic:%d  %s %s",(int)InpMagic,_Symbol,EnumToString(_Period)),InpClrNeutral,7,RY_WT);
   DL("VR",StringFormat(" Entropy:%.2f  ConsLoss:%d  Regime:%s  RealPnL:$%.2f",
       g_entropy,g_consecLoss,RgmStr(g_regime),g_dayRealizedPnL),
       g_consecLoss>=3?InpClrWarn:InpClrNeutral,7,RY_VR);
   DL("V2",StringFormat(" DayPeak:$%.0f  DDfromPeak:%.1f%%  StaleExit:%db",
       g_dayPeakEquity,g_dayPeakEquity>0?((g_dayPeakEquity-eq)/g_dayPeakEquity)*100:0,InpStaleExitBars),
       InpClrNeutral,7,RY_V2);
   // AI rows
   color aiCol=InpClrNeutral;
   if(g_ai.valid)
     { if(g_ai.confidence>=InpAIBoostThresh) aiCol=InpClrBuy;
       else if(g_ai.confidence<InpAIMinConf) aiCol=InpClrSell;
       else aiCol=InpClrWarn; }
   DL("AI0"," -- AI DECISION LAYER ------------------------",InpClrHeader,8,RY_AI0);
   DL("AI1",StringFormat(" Conf:%s %.1f  Min:%.0f  Boost:%.0f  Trained:%d %s",
       MB(g_ai.confidence,100,10),g_ai.confidence,InpAIMinConf,InpAIBoostThresh,g_ai.trainedTrades,
       (InpUseAI?(g_ai.trainedTrades<InpAILearnTrades?"(warmup)":"(active)"):"(off)")),aiCol,7,RY_AI1);
   DL("AI2",StringFormat(" Reg:%.0f Mod:%.0f Sim:%.0f Vol:%.0f Ent:%.0f Vw:%.0f Tm:%.0f",
       g_ai.feats[0]*100,g_ai.feats[1]*100,g_ai.feats[2]*100,g_ai.feats[3]*100,
       g_ai.feats[4]*100,g_ai.feats[5]*100,g_ai.feats[6]*100),InpClrData,7,RY_AI2);
   ChartRedraw(0);g_lastDash=now;}

void DashRefresh()
  {if(!InpShowDash||!g_dashOK||InpOptimMode)return;
   if(TimeCurrent()==g_lastDash)return;DashUpdate();}
void DashDelete()
  {if(g_dashOK){ObjectsDeleteAll(0,DPFX);g_dashOK=false;ChartRedraw(0);}}

void DRect(string nm,int x,int y,int w,int h,color bg,color bdr,int bw)
  {if(ObjectFind(0,nm)<0){ObjectCreate(0,nm,OBJ_RECTANGLE_LABEL,0,0,0);
     ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
     ObjectSetInteger(0,nm,OBJPROP_BACK,true);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);}
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nm,OBJPROP_XSIZE,w);ObjectSetInteger(0,nm,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,nm,OBJPROP_BGCOLOR,bg);ObjectSetInteger(0,nm,OBJPROP_COLOR,bdr);
   ObjectSetInteger(0,nm,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,nm,OBJPROP_WIDTH,bw);}
void DL(string sfx,string txt,color clr,int fs,int yr)
  {string nm=DPFX+sfx;
   if(ObjectFind(0,nm)<0){ObjectCreate(0,nm,OBJ_LABEL,0,0,0);
     ObjectSetInteger(0,nm,OBJPROP_CORNER,CORNER_LEFT_UPPER);
     ObjectSetInteger(0,nm,OBJPROP_BACK,false);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
     ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,InpDashX+5);
     ObjectSetString(0,nm,OBJPROP_FONT,InpFont);}
   ObjectSetString(0,nm,OBJPROP_TEXT,txt);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fs);ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,InpDashY+yr);}
void DLine(string nm,double px,color clr,ENUM_LINE_STYLE sty,int lw,string lbl)
  {if(ObjectFind(0,nm)<0)ObjectCreate(0,nm,OBJ_HLINE,0,0,px);
   ObjectSetDouble(0,nm,OBJPROP_PRICE,px);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_STYLE,sty);ObjectSetInteger(0,nm,OBJPROP_WIDTH,lw);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);ObjectSetString(0,nm,OBJPROP_TEXT,lbl);}
void DArrow(string nm,datetime t,double px,int code,color clr,int sz)
  {if(ObjectFind(0,nm)<0)ObjectCreate(0,nm,OBJ_ARROW,0,t,px);
   ObjectSetDouble(0,nm,OBJPROP_PRICE,px);ObjectSetInteger(0,nm,OBJPROP_TIME,t);
   ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,code);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,sz);ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);}
void DText(string nm,string txt,datetime t,double px,color clr,int fs)
  {if(ObjectFind(0,nm)<0)ObjectCreate(0,nm,OBJ_TEXT,0,t,px);
   ObjectSetDouble(0,nm,OBJPROP_PRICE,px);ObjectSetInteger(0,nm,OBJPROP_TIME,t);
   ObjectSetString(0,nm,OBJPROP_TEXT,txt);ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,fs);ObjectSetString(0,nm,OBJPROP_FONT,InpFont);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);}
//+------------------------------------------------------------------+
//| END LQS-AI v5.0                                                  |
//+------------------------------------------------------------------+
