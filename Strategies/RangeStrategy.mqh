//+------------------------------------------------------------------+
//| Strategies/RangeStrategy.mqh                                     |
//| Mean reversion di dalam range (bagian 23-32).                    |
//|                                                                  |
//| Aktif hanya pada REGIME_SIDEWAYS.                                |
//| Signal candle = shift 1. Range sudah dihitung MarketStructure    |
//| dari shift 2..(1 + RangeLookback) sehingga signal candle tidak   |
//| ikut membentuk batas range.                                      |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_STRATEGIES_RANGESTRATEGY_MQH
#define TRADINGEA_STRATEGIES_RANGESTRATEGY_MQH

#include "IStrategy.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CRangeStrategy                                                   |
//+------------------------------------------------------------------+
class CRangeStrategy : public IStrategy
  {
private:
   //+---------------------------------------------------------------+
   //| Bullish rejection candle (bagian 28-29)                        |
   //+---------------------------------------------------------------+
   bool              IsBullishRejection(const SMarketContext &ctx, const double tolerance) const
     {
      double body = ctx.Body(1);

      //--- body nol: rejection dianggap tidak valid (bagian 28)
      if(body <= 0.0)
         return(false);

      if(!ctx.IsBullishCandle(1))
         return(false);

      if(ctx.LowerWick(1) < body * m_config.rejectionWickBody)
         return(false);

      if(ctx.m15Low[1] > ctx.range.low + tolerance)
         return(false);

      if(ctx.m15Close[1] <= ctx.range.low)
         return(false);

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Bearish rejection candle (bagian 28, 30)                       |
   //+---------------------------------------------------------------+
   bool              IsBearishRejection(const SMarketContext &ctx, const double tolerance) const
     {
      double body = ctx.Body(1);

      if(body <= 0.0)
         return(false);

      if(!ctx.IsBearishCandle(1))
         return(false);

      if(ctx.UpperWick(1) < body * m_config.rejectionWickBody)
         return(false);

      if(ctx.m15High[1] < ctx.range.high - tolerance)
         return(false);

      if(ctx.m15Close[1] >= ctx.range.high)
         return(false);

      return(true);
     }

public:
                     CRangeStrategy(void) { m_module = "RangeStrategy"; }

   virtual ENUM_STRATEGY_TYPE Type(void) const { return(STRATEGY_RANGE); }

   //+---------------------------------------------------------------+
   //| Evaluate                                                       |
   //+---------------------------------------------------------------+
   virtual bool      Evaluate(const SMarketContext &ctx, STradeSignal &signal)
     {
      signal.Reset();

      if(ctx.regime != REGIME_SIDEWAYS)
        {
         CLogger::NoSignal(m_module, "RegimeNotSideways");
         return(false);
        }

      if(!ctx.range.valid)
        {
         CLogger::NoSignal(m_module, "RangeInvalid");
         return(false);
        }

      double atr       = ctx.SignalATR();
      double tolerance = atr * m_config.interactionATR;
      double buffer    = atr * m_config.slBufferATR;

      //--- BUY: harga di zona bawah range + bullish rejection (bagian 31)
      if(ctx.range.position <= m_config.rangeZonePercent)
        {
         if(!IsBullishRejection(ctx, tolerance))
           {
            CLogger::NoSignal(m_module, "NoBullishRejection");
            return(false);
           }

         signal.strategy         = STRATEGY_RANGE;
         signal.direction        = SIGNAL_BUY;
         signal.signalTime       = ctx.SignalTime();
         signal.entryPrice       = ctx.ask;
         signal.stopLoss         = ctx.range.low - buffer;
         signal.takeProfit       = ctx.range.high;        // TP2
         signal.hasPartialTarget = true;
         signal.takeProfit1      = ctx.range.mid;         // TP1
         signal.reason           = StringFormat("RangeBuy pos=%.3f low=%.5f high=%.5f",
                                                ctx.range.position,
                                                ctx.range.low, ctx.range.high);
         signal.valid            = true;

         return(true);
        }

      //--- SELL: harga di zona atas range + bearish rejection (bagian 32)
      if(ctx.range.position >= (1.0 - m_config.rangeZonePercent))
        {
         if(!IsBearishRejection(ctx, tolerance))
           {
            CLogger::NoSignal(m_module, "NoBearishRejection");
            return(false);
           }

         signal.strategy         = STRATEGY_RANGE;
         signal.direction        = SIGNAL_SELL;
         signal.signalTime       = ctx.SignalTime();
         signal.entryPrice       = ctx.bid;
         signal.stopLoss         = ctx.range.high + buffer;
         signal.takeProfit       = ctx.range.low;         // TP2
         signal.hasPartialTarget = true;
         signal.takeProfit1      = ctx.range.mid;         // TP1
         signal.reason           = StringFormat("RangeSell pos=%.3f low=%.5f high=%.5f",
                                                ctx.range.position,
                                                ctx.range.low, ctx.range.high);
         signal.valid            = true;

         return(true);
        }

      CLogger::NoSignal(m_module,
                        StringFormat("PriceNotInEntryZone pos=%.3f", ctx.range.position));
      return(false);
     }
  };

#endif // TRADINGEA_STRATEGIES_RANGESTRATEGY_MQH
//+------------------------------------------------------------------+
