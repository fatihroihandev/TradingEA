//+------------------------------------------------------------------+
//| Core/TradeSignal.mqh                                             |
//| Kontrak signal bagian 7.                                         |
//|                                                                  |
//| Strategy mengisi : strategy, direction, signalTime, entryPrice,  |
//|                    stopLoss, takeProfit, reason, valid           |
//| RiskEngine mengisi: riskPercent, riskAmount, volume              |
//|                                                                  |
//| takeProfit1 adalah target position-management opsional dan hanya |
//| dipakai oleh RangeStrategy (bagian 31-32, 80).                   |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_CORE_TRADESIGNAL_MQH
#define TRADINGEA_CORE_TRADESIGNAL_MQH

#include "Types.mqh"

//+------------------------------------------------------------------+
//| STradeSignal                                                     |
//+------------------------------------------------------------------+
struct STradeSignal
  {
   //--- diisi strategy
   bool                    valid;
   ENUM_STRATEGY_TYPE      strategy;
   ENUM_SIGNAL_DIRECTION   direction;
   datetime                signalTime;
   double                  entryPrice;
   double                  stopLoss;
   double                  takeProfit;
   string                  reason;

   //--- target parsial opsional (hanya Range)
   bool                    hasPartialTarget;
   double                  takeProfit1;

   //--- diisi RiskEngine
   double                  riskPercent;
   double                  riskAmount;
   double                  volume;

   void Reset()
     {
      valid            = false;
      strategy         = STRATEGY_NONE;
      direction        = SIGNAL_NONE;
      signalTime       = 0;
      entryPrice       = 0.0;
      stopLoss         = 0.0;
      takeProfit       = 0.0;
      reason           = "";

      hasPartialTarget = false;
      takeProfit1      = 0.0;

      riskPercent      = 0.0;
      riskAmount       = 0.0;
      volume           = 0.0;
     }

   //--- jarak risk dalam satuan harga
   double RiskDistance() const
     {
      return(MathAbs(entryPrice - stopLoss));
     }

   string DirectionText() const
     {
      if(direction == SIGNAL_BUY)  return("BUY");
      if(direction == SIGNAL_SELL) return("SELL");
      return("NONE");
     }

   string StrategyText() const
     {
      switch(strategy)
        {
         case STRATEGY_RANGE:            return("RANGE");
         case STRATEGY_BREAKOUT_RETEST:  return("BREAKOUT_RETEST");
         case STRATEGY_TREND_PULLBACK:   return("TREND_PULLBACK");
        }
      return("NONE");
     }

   string ToLogString() const
     {
      return(StringFormat("Strategy=%s Direction=%s Entry=%.5f SL=%.5f TP=%.5f Volume=%.2f Risk=%.2f",
                          StrategyText(), DirectionText(),
                          entryPrice, stopLoss, takeProfit,
                          volume, riskAmount));
     }
  };

#endif // TRADINGEA_CORE_TRADESIGNAL_MQH
//+------------------------------------------------------------------+
