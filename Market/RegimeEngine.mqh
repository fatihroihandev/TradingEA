//+------------------------------------------------------------------+
//| Market/RegimeEngine.mqh                                          |
//| Pemilik regime H1 (bagian 9, 15-20).                             |
//|                                                                  |
//| Seluruh perhitungan memakai candle H1 yang sudah closed.         |
//| Priority: TREND -> SIDEWAYS -> TRANSITION.                       |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_MARKET_REGIMEENGINE_MQH
#define TRADINGEA_MARKET_REGIMEENGINE_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CRegimeEngine                                                    |
//+------------------------------------------------------------------+
class CRegimeEngine
  {
private:
   string            m_module;
   CConfig          *m_config;

public:
                     CRegimeEngine(void) { m_module = "RegimeEngine"; m_config = NULL; }

   void              Init(CConfig *config) { m_config = config; }

   //+---------------------------------------------------------------+
   //| Normalized slope (bagian 16)                                   |
   //|                                                                |
   //|   EMA50Slope      = EMA50[1] - EMA50[1 + SlopeLookback]        |
   //|   NormalizedSlope = EMA50Slope / ATR14[1]                      |
   //|                                                                |
   //| Dengan SlopeLookback = 3 maka pembandingnya adalah EMA50[4],   |
   //| sesuai formula pada spesifikasi.                               |
   //+---------------------------------------------------------------+
   double            CalculateNormalizedSlope(const SMarketContext &ctx) const
     {
      int far = 1 + m_config.slopeLookback;

      if(far >= CTX_H1_BARS)
         return(0.0);

      double atr = ctx.h1ATR[1];
      if(atr <= 0.0)
         return(0.0);

      double slope = ctx.h1EMA50[1] - ctx.h1EMA50[far];

      return(slope / atr);
     }

   //+---------------------------------------------------------------+
   //| Tentukan regime dan tulis hasilnya ke context.                 |
   //+---------------------------------------------------------------+
   bool              Update(SMarketContext &ctx) const
     {
      if(m_config == NULL)
        {
         CLogger::Error(m_module, "Config belum di-set");
         return(false);
        }

      double slope = CalculateNormalizedSlope(ctx);
      ctx.h1NormalizedSlope = slope;

      double close  = ctx.h1Close[1];
      double ema50  = ctx.h1EMA50[1];
      double ema200 = ctx.h1EMA200[1];
      double adx    = ctx.h1ADX[1];

      //--- 1. TREND BULLISH (bagian 17)
      bool bullish =
         (close  > ema200) &&
         (ema50  > ema200) &&
         (slope >= m_config.trendSlopeThreshold) &&
         (adx   >= m_config.trendADX);

      //--- 2. TREND BEARISH (bagian 18)
      bool bearish =
         (close  < ema200) &&
         (ema50  < ema200) &&
         (slope <= -m_config.trendSlopeThreshold) &&
         (adx   >= m_config.trendADX);

      if(bullish)
         ctx.regime = REGIME_TREND_BULLISH;
      else
         if(bearish)
            ctx.regime = REGIME_TREND_BEARISH;
         else
           {
            //--- 3. SIDEWAYS (bagian 19)
            bool sideways =
               (adx < m_config.sidewaysADX) &&
               (MathAbs(slope) < m_config.trendSlopeThreshold);

            //--- 4. sisanya TRANSITION (bagian 20)
            ctx.regime = sideways ? REGIME_SIDEWAYS : REGIME_TRANSITION;
           }

      CLogger::Debug(m_module,
                     StringFormat("Regime=%s ADX=%.2f Slope=%.4f Close=%.5f EMA50=%.5f EMA200=%.5f",
                                  RegimeToString(ctx.regime), adx, slope,
                                  close, ema50, ema200));

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Helper teks untuk logging                                      |
   //+---------------------------------------------------------------+
   static string     RegimeToString(const ENUM_MARKET_REGIME regime)
     {
      switch(regime)
        {
         case REGIME_SIDEWAYS:       return("SIDEWAYS");
         case REGIME_TRANSITION:     return("TRANSITION");
         case REGIME_TREND_BULLISH:  return("TREND_BULLISH");
         case REGIME_TREND_BEARISH:  return("TREND_BEARISH");
        }
      return("UNKNOWN");
     }
  };

#endif // TRADINGEA_MARKET_REGIMEENGINE_MQH
//+------------------------------------------------------------------+
