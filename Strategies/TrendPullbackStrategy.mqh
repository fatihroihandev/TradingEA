//+------------------------------------------------------------------+
//| Strategies/TrendPullbackStrategy.mqh                             |
//| Pullback mengikuti arah trend H1 (bagian 50-58).                 |
//|                                                                  |
//| Aktif pada REGIME_TREND_BULLISH (BUY) dan                        |
//| REGIME_TREND_BEARISH (SELL).                                     |
//|                                                                  |
//| Bagian 57: bila structural swing untuk stop loss tidak tersedia, |
//| strategy mengembalikan NO SIGNAL. Tidak ada fallback sembarang.  |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_STRATEGIES_TRENDPULLBACKSTRATEGY_MQH
#define TRADINGEA_STRATEGIES_TRENDPULLBACKSTRATEGY_MQH

#include "IStrategy.mqh"
#include "../Market/MarketStructure.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CTrendPullbackStrategy                                           |
//+------------------------------------------------------------------+
class CTrendPullbackStrategy : public IStrategy
  {
private:
   //+---------------------------------------------------------------+
   //| Zona EMA50 untuk BUY (bagian 53)                               |
   //+---------------------------------------------------------------+
   bool              InBuyPullbackZone(const SMarketContext &ctx) const
     {
      double ema = ctx.m15EMA50[1];
      double tol = ctx.SignalATR() * m_config.pullbackZoneATR;

      //--- menyentuh EMA lalu close di atasnya
      if(ctx.m15Low[1] <= ema && ctx.m15Close[1] >= ema)
         return(true);

      //--- atau cukup dekat dengan EMA
      if(MathAbs(ctx.m15Low[1] - ema) <= tol)
         return(true);

      return(false);
     }

   //+---------------------------------------------------------------+
   //| Zona EMA50 untuk SELL (bagian 54)                              |
   //+---------------------------------------------------------------+
   bool              InSellPullbackZone(const SMarketContext &ctx) const
     {
      double ema = ctx.m15EMA50[1];
      double tol = ctx.SignalATR() * m_config.pullbackZoneATR;

      if(ctx.m15High[1] >= ema && ctx.m15Close[1] <= ema)
         return(true);

      if(MathAbs(ctx.m15High[1] - ema) <= tol)
         return(true);

      return(false);
     }

   //+---------------------------------------------------------------+
   //| Evaluasi sisi BUY                                              |
   //+---------------------------------------------------------------+
   bool              EvaluateBuy(const SMarketContext &ctx, STradeSignal &signal)
     {
      if(ctx.structure != STRUCTURE_BULLISH)
        {
         CLogger::NoSignal(m_module, "StructureNotBullish");
         return(false);
        }

      if(!ctx.latestSwingHigh.valid)
        {
         CLogger::NoSignal(m_module, "NoConfirmedSwingHigh");
         return(false);
        }

      //--- pullback terjadi SETELAH swing high terakhir
      int fromShift = 1;
      int toShift   = ctx.latestSwingHigh.shift - 1;

      if(toShift < fromShift)
        {
         CLogger::NoSignal(m_module, "PullbackNotStartedYet");
         return(false);
        }

      double relevantLow  = CMarketStructure::LowestLow(ctx, fromShift, toShift);
      double pullbackMove = ctx.latestSwingHigh.price - relevantLow;
      double minMove      = ctx.SignalATR() * m_config.pullbackMinATR;

      if(pullbackMove < minMove)
        {
         CLogger::NoSignal(m_module,
                           StringFormat("PullbackTooShallow move=%.5f min=%.5f",
                                        pullbackMove, minMove));
         return(false);
        }

      if(!InBuyPullbackZone(ctx))
        {
         CLogger::NoSignal(m_module, "NotInEMA50Zone");
         return(false);
        }

      //--- konfirmasi candle (bagian 55)
      if(!ctx.IsBullishCandle(1))
        {
         CLogger::NoSignal(m_module, "NoBullishConfirmation");
         return(false);
        }

      if(ctx.m15Close[1] <= ctx.m15High[2])
        {
         CLogger::NoSignal(m_module, "CloseNotAbovePreviousHigh");
         return(false);
        }

      //--- stop loss harus structural (bagian 57)
      //    swing low yang dipakai harus terbentuk SETELAH swing high
      if(!ctx.latestSwingLow.valid ||
         ctx.latestSwingLow.shift >= ctx.latestSwingHigh.shift)
        {
         CLogger::NoSignal(m_module, "NoPullbackSwingLow");
         return(false);
        }

      double entry  = ctx.ask;
      double buffer = ctx.SignalATR() * m_config.slBufferATR;
      double sl     = ctx.latestSwingLow.price - buffer;

      if(sl >= entry)
        {
         CLogger::NoSignal(m_module, "StopLossAboveEntry");
         return(false);
        }

      double riskDistance = entry - sl;
      double tp           = entry + riskDistance * m_config.rewardRatio;

      signal.strategy         = STRATEGY_TREND_PULLBACK;
      signal.direction        = SIGNAL_BUY;
      signal.signalTime       = ctx.SignalTime();
      signal.entryPrice       = entry;
      signal.stopLoss         = sl;
      signal.takeProfit       = tp;
      signal.hasPartialTarget = false;
      signal.takeProfit1      = 0.0;
      signal.reason           = StringFormat("TrendPullbackBuy move=%.5f swingLow=%.5f",
                                             pullbackMove, ctx.latestSwingLow.price);
      signal.valid            = true;

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Evaluasi sisi SELL                                             |
   //+---------------------------------------------------------------+
   bool              EvaluateSell(const SMarketContext &ctx, STradeSignal &signal)
     {
      if(ctx.structure != STRUCTURE_BEARISH)
        {
         CLogger::NoSignal(m_module, "StructureNotBearish");
         return(false);
        }

      if(!ctx.latestSwingLow.valid)
        {
         CLogger::NoSignal(m_module, "NoConfirmedSwingLow");
         return(false);
        }

      int fromShift = 1;
      int toShift   = ctx.latestSwingLow.shift - 1;

      if(toShift < fromShift)
        {
         CLogger::NoSignal(m_module, "PullbackNotStartedYet");
         return(false);
        }

      double relevantHigh = CMarketStructure::HighestHigh(ctx, fromShift, toShift);
      double pullbackMove = relevantHigh - ctx.latestSwingLow.price;
      double minMove      = ctx.SignalATR() * m_config.pullbackMinATR;

      if(pullbackMove < minMove)
        {
         CLogger::NoSignal(m_module,
                           StringFormat("PullbackTooShallow move=%.5f min=%.5f",
                                        pullbackMove, minMove));
         return(false);
        }

      if(!InSellPullbackZone(ctx))
        {
         CLogger::NoSignal(m_module, "NotInEMA50Zone");
         return(false);
        }

      if(!ctx.IsBearishCandle(1))
        {
         CLogger::NoSignal(m_module, "NoBearishConfirmation");
         return(false);
        }

      if(ctx.m15Close[1] >= ctx.m15Low[2])
        {
         CLogger::NoSignal(m_module, "CloseNotBelowPreviousLow");
         return(false);
        }

      if(!ctx.latestSwingHigh.valid ||
         ctx.latestSwingHigh.shift >= ctx.latestSwingLow.shift)
        {
         CLogger::NoSignal(m_module, "NoPullbackSwingHigh");
         return(false);
        }

      double entry  = ctx.bid;
      double buffer = ctx.SignalATR() * m_config.slBufferATR;
      double sl     = ctx.latestSwingHigh.price + buffer;

      if(sl <= entry)
        {
         CLogger::NoSignal(m_module, "StopLossBelowEntry");
         return(false);
        }

      double riskDistance = sl - entry;
      double tp           = entry - riskDistance * m_config.rewardRatio;

      signal.strategy         = STRATEGY_TREND_PULLBACK;
      signal.direction        = SIGNAL_SELL;
      signal.signalTime       = ctx.SignalTime();
      signal.entryPrice       = entry;
      signal.stopLoss         = sl;
      signal.takeProfit       = tp;
      signal.hasPartialTarget = false;
      signal.takeProfit1      = 0.0;
      signal.reason           = StringFormat("TrendPullbackSell move=%.5f swingHigh=%.5f",
                                             pullbackMove, ctx.latestSwingHigh.price);
      signal.valid            = true;

      return(true);
     }

public:
                     CTrendPullbackStrategy(void) { m_module = "TrendPullbackStrategy"; }

   virtual ENUM_STRATEGY_TYPE Type(void) const { return(STRATEGY_TREND_PULLBACK); }

   //+---------------------------------------------------------------+
   //| Evaluate                                                       |
   //+---------------------------------------------------------------+
   virtual bool      Evaluate(const SMarketContext &ctx, STradeSignal &signal)
     {
      signal.Reset();

      if(ctx.regime == REGIME_TREND_BULLISH)
         return(EvaluateBuy(ctx, signal));

      if(ctx.regime == REGIME_TREND_BEARISH)
         return(EvaluateSell(ctx, signal));

      CLogger::NoSignal(m_module, "RegimeNotTrending");
      return(false);
     }
  };

#endif // TRADINGEA_STRATEGIES_TRENDPULLBACKSTRATEGY_MQH
//+------------------------------------------------------------------+
