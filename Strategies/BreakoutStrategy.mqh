//+------------------------------------------------------------------+
//| Strategies/BreakoutStrategy.mqh                                  |
//| Breakout + retest (bagian 33-46, 84-85).                         |
//|                                                                  |
//| Aktif hanya pada REGIME_TRANSITION.                              |
//|                                                                  |
//| State machine:                                                   |
//|   IDLE --valid breakout--> WAITING_RETEST                        |
//|   WAITING_RETEST --valid retest--> SIGNAL                        |
//|   WAITING_RETEST --failed--------> IDLE                          |
//|   WAITING_RETEST --expired-------> IDLE                          |
//|                                                                  |
//| Bagian 38: HANYA class ini yang boleh mengubah state breakout.   |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_STRATEGIES_BREAKOUTSTRATEGY_MQH
#define TRADINGEA_STRATEGIES_BREAKOUTSTRATEGY_MQH

#include "IStrategy.mqh"
#include "../Market/MarketStructure.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CBreakoutStrategy                                                |
//+------------------------------------------------------------------+
class CBreakoutStrategy : public IStrategy
  {
private:
   //--- true bila setup baru dibuat pada bar ini, sehingga retest
   //    tidak boleh dievaluasi pada candle yang sama
   bool              m_armedThisBar;

   //+---------------------------------------------------------------+
   //| ATR expansion (bagian 34)                                      |
   //|   ATR[1] > ATR[2]                                              |
   //|   ATR[1] >= rata-rata ATR[2..6]                                |
   //+---------------------------------------------------------------+
   bool              HasATRExpansion(const SMarketContext &ctx) const
     {
      if(ctx.m15ATR[1] <= ctx.m15ATR[2])
         return(false);

      double sum = 0.0;
      for(int shift = 2; shift <= 6; shift++)
         sum += ctx.m15ATR[shift];

      double average = sum / 5.0;

      return(ctx.m15ATR[1] >= average);
     }

   //+---------------------------------------------------------------+
   //| ADX expansion (bagian 35)                                      |
   //+---------------------------------------------------------------+
   bool              HasADXExpansion(const SMarketContext &ctx) const
     {
      if(ctx.m15ADX[1] <= ctx.m15ADX[2])
         return(false);

      return(ctx.m15ADX[1] >= m_config.breakoutADX);
     }

   //+---------------------------------------------------------------+
   //| Shift dari candle breakout pada seri M15 saat ini.             |
   //| return -1 bila tidak ditemukan (state tidak dapat dipercaya).  |
   //+---------------------------------------------------------------+
   int               BreakoutShift(const SMarketContext &ctx) const
     {
      datetime target = m_state.BreakoutBarTime();

      if(target <= 0)
         return(-1);

      for(int shift = 1; shift < CTX_M15_BARS; shift++)
         if(ctx.m15Time[shift] == target)
            return(shift);

      return(-1);
     }

   //+---------------------------------------------------------------+
   //| Deteksi breakout baru (bagian 36-37)                           |
   //+---------------------------------------------------------------+
   void              DetectBreakout(const SMarketContext &ctx)
     {
      if(!ctx.range.valid)
        {
         CLogger::NoSignal(m_module, "RangeInvalidForBreakout");
         return;
        }

      double atr      = ctx.SignalATR();
      double body     = ctx.Body(1);
      double minBody  = atr * m_config.breakoutBodyATR;

      if(body < minBody)
        {
         CLogger::NoSignal(m_module, "BreakoutBodyTooSmall");
         return;
        }

      if(!HasATRExpansion(ctx))
        {
         CLogger::NoSignal(m_module, "NoATRExpansion");
         return;
        }

      if(!HasADXExpansion(ctx))
        {
         CLogger::NoSignal(m_module, "NoADXExpansion");
         return;
        }

      //--- BUY breakout
      if(ctx.m15Close[1] > ctx.range.high && ctx.m15Close[1] > ctx.m15High[2])
        {
         m_state.SetBreakoutWaiting(SIGNAL_BUY, ctx.range.high, ctx.m15Time[1]);
         m_armedThisBar = true;

         CLogger::Info(m_module,
                       StringFormat("Breakout BUY terdeteksi. Level=%.5f BarTime=%s",
                                    ctx.range.high,
                                    TimeToString(ctx.m15Time[1], TIME_DATE | TIME_MINUTES)));
         return;
        }

      //--- SELL breakout
      if(ctx.m15Close[1] < ctx.range.low && ctx.m15Close[1] < ctx.m15Low[2])
        {
         m_state.SetBreakoutWaiting(SIGNAL_SELL, ctx.range.low, ctx.m15Time[1]);
         m_armedThisBar = true;

         CLogger::Info(m_module,
                       StringFormat("Breakout SELL terdeteksi. Level=%.5f BarTime=%s",
                                    ctx.range.low,
                                    TimeToString(ctx.m15Time[1], TIME_DATE | TIME_MINUTES)));
         return;
        }

      CLogger::NoSignal(m_module, "NoBreakoutClose");
     }

   //+---------------------------------------------------------------+
   //| Stop loss breakout (bagian 45)                                 |
   //+---------------------------------------------------------------+
   double            CalculateStopLoss(const SMarketContext &ctx,
                                       const ENUM_SIGNAL_DIRECTION direction) const
     {
      double buffer = ctx.SignalATR() * m_config.slBufferATR;
      double level  = m_state.BreakoutLevel();

      if(direction == SIGNAL_BUY)
        {
         if(ctx.latestSwingLow.valid)
            return(ctx.latestSwingLow.price - buffer);

         //--- fallback eksplisit, bukan angka sembarang
         return(level - buffer);
        }

      if(ctx.latestSwingHigh.valid)
         return(ctx.latestSwingHigh.price + buffer);

      return(level + buffer);
     }

public:
                     CBreakoutStrategy(void)
     {
      m_module       = "BreakoutStrategy";
      m_armedThisBar = false;
     }

   virtual ENUM_STRATEGY_TYPE Type(void) const { return(STRATEGY_BREAKOUT_RETEST); }

   //+---------------------------------------------------------------+
   //| UpdateState                                                    |
   //|                                                                |
   //| Dipanggil setiap M15 bar baru, SEBELUM Guardian dan Evaluate,  |
   //| agar expiry dan failed breakout tetap diproses walaupun EA     |
   //| sedang tidak diizinkan membuka entry baru.                     |
   //+---------------------------------------------------------------+
   virtual void      UpdateState(const SMarketContext &ctx)
     {
      m_armedThisBar = false;

      if(m_state.BreakoutState() == BREAKOUT_WAITING_RETEST)
        {
         int shift = BreakoutShift(ctx);

         //--- state tidak dapat direkonstruksi dari history
         if(shift < 0)
           {
            CLogger::Warning(m_module,
                             "Candle breakout tidak ditemukan pada history. State direset.");
            m_state.ClearBreakout();
            return;
           }

         //--- expiry (bagian 42): jarak bar dari candle breakout
         //    ke signal candle saat ini
         int barsElapsed = shift - 1;

         if(barsElapsed > m_config.maxRetestBars)
           {
            CLogger::Info(m_module,
                          StringFormat("Setup breakout kedaluwarsa setelah %d bar. State=IDLE",
                                       barsElapsed));
            m_state.ClearBreakout();
            return;
           }

         //--- failed breakout (bagian 41)
         double level = m_state.BreakoutLevel();
         ENUM_SIGNAL_DIRECTION direction = m_state.BreakoutDirection();

         bool failed = (direction == SIGNAL_BUY  && ctx.m15Close[1] < level) ||
                       (direction == SIGNAL_SELL && ctx.m15Close[1] > level);

         if(failed)
           {
            CLogger::Info(m_module, "Failed breakout. State=IDLE");
            m_state.ClearBreakout();
            return;
           }

         return;   // tetap menunggu retest
        }

      //--- IDLE: cari breakout baru, hanya pada regime TRANSITION
      if(ctx.regime == REGIME_TRANSITION)
         DetectBreakout(ctx);
     }

   //+---------------------------------------------------------------+
   //| Evaluate: retest + konfirmasi (bagian 39, 40, 43, 46)          |
   //+---------------------------------------------------------------+
   virtual bool      Evaluate(const SMarketContext &ctx, STradeSignal &signal)
     {
      signal.Reset();

      if(m_state.BreakoutState() != BREAKOUT_WAITING_RETEST)
        {
         CLogger::NoSignal(m_module, "NoWaitingSetup");
         return(false);
        }

      //--- candle breakout tidak boleh sekaligus menjadi candle retest
      if(m_armedThisBar)
        {
         CLogger::NoSignal(m_module, "BreakoutBarCannotBeRetestBar");
         return(false);
        }

      ENUM_SIGNAL_DIRECTION direction = m_state.BreakoutDirection();
      double level     = m_state.BreakoutLevel();
      double atr       = ctx.SignalATR();
      double tolerance = atr * m_config.retestATR;

      bool retestValid = false;
      bool confirmed   = false;

      if(direction == SIGNAL_BUY)
        {
         retestValid = (ctx.m15Low[1] <= level + tolerance) &&
                       (ctx.m15Close[1] >= level);
         confirmed   = retestValid && ctx.IsBullishCandle(1);
        }
      else
         if(direction == SIGNAL_SELL)
           {
            retestValid = (ctx.m15High[1] >= level - tolerance) &&
                          (ctx.m15Close[1] <= level);
            confirmed   = retestValid && ctx.IsBearishCandle(1);
           }

      if(!retestValid)
        {
         CLogger::NoSignal(m_module, "NoRetestTouch");
         return(false);
        }

      if(!confirmed)
        {
         CLogger::NoSignal(m_module, "NoRetestConfirmation");
         return(false);
        }

      //--- susun signal
      double entry = (direction == SIGNAL_BUY) ? ctx.ask : ctx.bid;
      double sl    = CalculateStopLoss(ctx, direction);

      double riskDistance = MathAbs(entry - sl);

      if(riskDistance <= 0.0)
        {
         CLogger::NoSignal(m_module, "RiskDistanceZero");
         return(false);
        }

      //--- SL harus berada di sisi yang benar
      if((direction == SIGNAL_BUY  && sl >= entry) ||
         (direction == SIGNAL_SELL && sl <= entry))
        {
         CLogger::NoSignal(m_module, "StopLossOnWrongSide");
         return(false);
        }

      double tp = (direction == SIGNAL_BUY)
                  ? entry + riskDistance * m_config.rewardRatio
                  : entry - riskDistance * m_config.rewardRatio;

      signal.strategy         = STRATEGY_BREAKOUT_RETEST;
      signal.direction        = direction;
      signal.signalTime       = ctx.SignalTime();
      signal.entryPrice       = entry;
      signal.stopLoss         = sl;
      signal.takeProfit       = tp;
      signal.hasPartialTarget = false;
      signal.takeProfit1      = 0.0;
      signal.reason           = StringFormat("BreakoutRetest level=%.5f tol=%.5f", level, tolerance);
      signal.valid            = true;

      //--- setup sudah dipakai, kembalikan ke IDLE
      m_state.ClearBreakout();

      return(true);
     }
  };

#endif // TRADINGEA_STRATEGIES_BREAKOUTSTRATEGY_MQH
//+------------------------------------------------------------------+
