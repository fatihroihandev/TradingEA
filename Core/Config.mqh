//+------------------------------------------------------------------+
//| Core/Config.mqh                                                  |
//| Seluruh input parameter EA. Nilai default berasal dari           |
//| specification bagian 109.                                        |
//|                                                                  |
//| Aturan bagian 109: parameter hanya dibuat configurable bila      |
//| benar-benar mempunyai fungsi.                                    |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_CORE_CONFIG_MQH
#define TRADINGEA_CORE_CONFIG_MQH

#include "Types.mqh"

//--- === GENERAL ===
input group "=== GENERAL ==="
input long     InpMagicNumber            = 20260001;   // Magic number (unik per instance)
input double   InpRiskPerTrade           = 0.50;       // Risk per trade (%)
input int      InpMaxTotalOpenPositions  = 1;          // Maksimum posisi terbuka milik EA

//--- === REGIME ===
input group "=== REGIME ==="
input double   InpTrendADX               = 20.0;       // ADX minimum untuk trend
input double   InpSidewaysADX            = 18.0;       // ADX maksimum untuk sideways
input double   InpTrendSlopeThreshold    = 0.05;       // Ambang normalized slope
input int      InpSlopeLookback          = 3;          // Jarak bar perhitungan slope

//--- === RANGE ===
input group "=== RANGE ==="
input int      InpRangeLookback          = 20;         // Jumlah candle pembentuk range
input double   InpMinRangeATR            = 1.5;        // Ukuran range minimum (x ATR)
input double   InpMaxRangeATR            = 4.0;        // Ukuran range maksimum (x ATR)
input double   InpInteractionATR         = 0.20;       // Toleransi sentuhan batas range (x ATR)
input double   InpRangeZonePercent       = 0.20;       // Zona entry dari batas range
input double   InpRejectionWickBody      = 1.50;       // Rasio minimum wick terhadap body

//--- === BREAKOUT ===
input group "=== BREAKOUT ==="
input double   InpBreakoutBodyATR        = 0.50;       // Body minimum candle breakout (x ATR)
input double   InpBreakoutADX            = 20.0;       // ADX minimum saat breakout
input double   InpRetestATR              = 0.20;       // Toleransi retest (x ATR)
input int      InpMaxRetestBars          = 8;          // Batas usia setup menunggu retest

//--- === STRUCTURE ===
input group "=== STRUCTURE ==="
input int      InpSwingLeft              = 2;          // Candle kiri pembentuk pivot
input int      InpSwingRight             = 2;          // Candle kanan pembentuk pivot

//--- === PULLBACK ===
input group "=== PULLBACK ==="
input double   InpPullbackMinATR         = 0.30;       // Kedalaman pullback minimum (x ATR)
input double   InpPullbackZoneATR        = 0.30;       // Toleransi zona EMA50 (x ATR)

//--- === RISK ===
input group "=== RISK ==="
input double   InpMaxRiskPerTrade        = 0.50;       // Batas keras risk per trade (%)
input double   InpSLBufferATR            = 0.20;       // Buffer stop loss (x ATR)
input double   InpRewardRatio            = 2.0;        // Risk reward untuk Breakout dan Pullback

//--- === GUARDIAN ===
input group "=== GUARDIAN ==="
input int      InpMaxSpreadPoints        = 30;         // Spread maksimum (point)
input bool     InpUseSessionFilter       = false;      // Aktifkan filter sesi
input int      InpSessionStartHour       = 7;          // Jam mulai sesi (server time)
input int      InpSessionEndHour         = 20;         // Jam akhir sesi (server time)
input double   InpDailyLossLimit         = 2.0;        // Batas kerugian harian (%)
input double   InpMaxDrawdown            = 10.0;       // Batas drawdown dari peak equity (%)

//--- === DEBUG ===
input group "=== DEBUG ==="
input bool     InpDebugMode              = false;      // Tampilkan log level DEBUG

//+------------------------------------------------------------------+
//| CConfig                                                          |
//|                                                                  |
//| Salinan input yang sudah divalidasi. Seluruh module membaca      |
//| konfigurasi dari sini, bukan langsung dari variabel input,       |
//| sehingga nilai dapat dikoreksi di satu tempat saat OnInit().     |
//+------------------------------------------------------------------+
class CConfig
  {
public:
   //--- general
   long              magicNumber;
   double            riskPerTrade;
   int               maxTotalOpenPositions;

   //--- regime
   double            trendADX;
   double            sidewaysADX;
   double            trendSlopeThreshold;
   int               slopeLookback;

   //--- range
   int               rangeLookback;
   double            minRangeATR;
   double            maxRangeATR;
   double            interactionATR;
   double            rangeZonePercent;
   double            rejectionWickBody;

   //--- breakout
   double            breakoutBodyATR;
   double            breakoutADX;
   double            retestATR;
   int               maxRetestBars;

   //--- structure
   int               swingLeft;
   int               swingRight;

   //--- pullback
   double            pullbackMinATR;
   double            pullbackZoneATR;

   //--- risk
   double            maxRiskPerTrade;
   double            slBufferATR;
   double            rewardRatio;

   //--- guardian
   int               maxSpreadPoints;
   bool              useSessionFilter;
   int               sessionStartHour;
   int               sessionEndHour;
   double            dailyLossLimit;
   double            maxDrawdown;

   //--- debug
   bool              debugMode;

                     CConfig(void) { }

   //+---------------------------------------------------------------+
   //| Load dari input dan validasi. Mengembalikan false bila ada     |
   //| nilai yang membuat EA tidak dapat berjalan deterministik.      |
   //+---------------------------------------------------------------+
   bool              Load(string &error)
     {
      error = "";

      magicNumber           = InpMagicNumber;
      riskPerTrade          = InpRiskPerTrade;
      maxTotalOpenPositions = InpMaxTotalOpenPositions;

      trendADX              = InpTrendADX;
      sidewaysADX           = InpSidewaysADX;
      trendSlopeThreshold   = InpTrendSlopeThreshold;
      slopeLookback         = InpSlopeLookback;

      rangeLookback         = InpRangeLookback;
      minRangeATR           = InpMinRangeATR;
      maxRangeATR           = InpMaxRangeATR;
      interactionATR        = InpInteractionATR;
      rangeZonePercent      = InpRangeZonePercent;
      rejectionWickBody     = InpRejectionWickBody;

      breakoutBodyATR       = InpBreakoutBodyATR;
      breakoutADX           = InpBreakoutADX;
      retestATR             = InpRetestATR;
      maxRetestBars         = InpMaxRetestBars;

      swingLeft             = InpSwingLeft;
      swingRight            = InpSwingRight;

      pullbackMinATR        = InpPullbackMinATR;
      pullbackZoneATR       = InpPullbackZoneATR;

      maxRiskPerTrade       = InpMaxRiskPerTrade;
      slBufferATR           = InpSLBufferATR;
      rewardRatio           = InpRewardRatio;

      maxSpreadPoints       = InpMaxSpreadPoints;
      useSessionFilter      = InpUseSessionFilter;
      sessionStartHour      = InpSessionStartHour;
      sessionEndHour        = InpSessionEndHour;
      dailyLossLimit        = InpDailyLossLimit;
      maxDrawdown           = InpMaxDrawdown;

      debugMode             = InpDebugMode;

      //--- validasi
      if(magicNumber <= 0)
        { error = "MagicNumber harus lebih besar dari 0"; return(false); }

      if(riskPerTrade <= 0.0)
        { error = "RiskPerTrade harus lebih besar dari 0"; return(false); }

      if(maxRiskPerTrade <= 0.0)
        { error = "MaxRiskPerTrade harus lebih besar dari 0"; return(false); }

      //--- risk per trade tidak boleh melewati batas keras
      if(riskPerTrade > maxRiskPerTrade)
        {
         error = "RiskPerTrade melebihi MaxRiskPerTrade";
         return(false);
        }

      if(maxTotalOpenPositions < 1)
        { error = "MaxTotalOpenPositions minimal 1"; return(false); }

      if(rangeLookback < 5)
        { error = "RangeLookback minimal 5"; return(false); }

      if(minRangeATR <= 0.0 || maxRangeATR <= minRangeATR)
        { error = "MinRangeATR / MaxRangeATR tidak valid"; return(false); }

      if(rangeZonePercent <= 0.0 || rangeZonePercent >= 0.5)
        { error = "RangeZonePercent harus di antara 0 dan 0.5"; return(false); }

      if(slopeLookback < 1)
        { error = "SlopeLookback minimal 1"; return(false); }

      if(swingLeft < 1 || swingRight < 1)
        { error = "SwingLeft / SwingRight minimal 1"; return(false); }

      if(maxRetestBars < 1)
        { error = "MaxRetestBars minimal 1"; return(false); }

      if(rewardRatio <= 0.0)
        { error = "RewardRatio harus lebih besar dari 0"; return(false); }

      if(dailyLossLimit <= 0.0 || maxDrawdown <= 0.0)
        { error = "DailyLossLimit / MaxDrawdown harus lebih besar dari 0"; return(false); }

      if(useSessionFilter)
        {
         if(sessionStartHour < 0 || sessionStartHour > 23 ||
            sessionEndHour   < 0 || sessionEndHour   > 23)
           { error = "Jam sesi harus di antara 0 dan 23"; return(false); }
        }

      //--- kebutuhan bar untuk MarketContext
      int neededM15 = rangeLookback + 2 + swingLeft + swingRight + 20;
      if(neededM15 > CTX_M15_BARS)
        {
         error = "RangeLookback terlalu besar untuk ukuran MarketContext";
         return(false);
        }

      if(slopeLookback + 2 > CTX_H1_BARS)
        {
         error = "SlopeLookback terlalu besar untuk ukuran MarketContext";
         return(false);
        }

      return(true);
     }
  };

#endif // TRADINGEA_CORE_CONFIG_MQH
//+------------------------------------------------------------------+
