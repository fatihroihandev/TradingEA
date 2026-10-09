//+------------------------------------------------------------------+
//| Core/MarketContext.mqh                                           |
//| Snapshot data market untuk satu evaluation cycle (bagian 8).     |
//|                                                                  |
//| Strategy HANYA boleh membaca data dari struct ini. Strategy      |
//| tidak boleh memanggil CopyRates / CopyBuffer sendiri.            |
//|                                                                  |
//| Konvensi index: seluruh array adalah time series.                |
//|   index 0 = candle berjalan (belum close)                        |
//|   index 1 = candle closed terakhir  -> signal candle             |
//|   index 2 = candle closed sebelumnya                             |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_CORE_MARKETCONTEXT_MQH
#define TRADINGEA_CORE_MARKETCONTEXT_MQH

#include "Types.mqh"

//+------------------------------------------------------------------+
//| SMarketContext                                                   |
//+------------------------------------------------------------------+
struct SMarketContext
  {
   //--- status
   bool                    valid;
   string                  symbol;
   datetime                serverTime;

   //--- harga live
   double                  bid;
   double                  ask;
   double                  spreadPoints;

   //--- spesifikasi broker
   SSymbolSpec             spec;

   //--- H1
   double                  h1Close[CTX_H1_BARS];
   double                  h1EMA50[CTX_H1_BARS];
   double                  h1EMA200[CTX_H1_BARS];
   double                  h1ADX[CTX_H1_BARS];
   double                  h1ATR[CTX_H1_BARS];
   double                  h1NormalizedSlope;

   //--- M15
   datetime                m15Time[CTX_M15_BARS];
   double                  m15Open[CTX_M15_BARS];
   double                  m15High[CTX_M15_BARS];
   double                  m15Low[CTX_M15_BARS];
   double                  m15Close[CTX_M15_BARS];
   double                  m15EMA50[CTX_M15_BARS];
   double                  m15ADX[CTX_M15_BARS];
   double                  m15ATR[CTX_M15_BARS];

   //--- hasil analisa
   ENUM_MARKET_REGIME      regime;
   ENUM_MARKET_STRUCTURE   structure;

   SSwingPoint             latestSwingHigh;
   SSwingPoint             previousSwingHigh;
   SSwingPoint             latestSwingLow;
   SSwingPoint             previousSwingLow;

   SRangeData              range;

   //+---------------------------------------------------------------+
   //| Reset seluruh isi snapshot                                     |
   //+---------------------------------------------------------------+
   void Reset()
     {
      valid             = false;
      symbol            = "";
      serverTime        = 0;
      bid               = 0.0;
      ask               = 0.0;
      spreadPoints      = 0.0;
      h1NormalizedSlope = 0.0;

      spec.Reset();

      for(int i = 0; i < CTX_H1_BARS; i++)
        {
         h1Close[i]  = 0.0;
         h1EMA50[i]  = 0.0;
         h1EMA200[i] = 0.0;
         h1ADX[i]    = 0.0;
         h1ATR[i]    = 0.0;
        }

      for(int i = 0; i < CTX_M15_BARS; i++)
        {
         m15Time[i]  = 0;
         m15Open[i]  = 0.0;
         m15High[i]  = 0.0;
         m15Low[i]   = 0.0;
         m15Close[i] = 0.0;
         m15EMA50[i] = 0.0;
         m15ADX[i]   = 0.0;
         m15ATR[i]   = 0.0;
        }

      regime    = REGIME_TRANSITION;
      structure = STRUCTURE_NONE;

      latestSwingHigh.Reset();
      previousSwingHigh.Reset();
      latestSwingLow.Reset();
      previousSwingLow.Reset();

      range.Reset();
     }

   //+---------------------------------------------------------------+
   //| Shortcut yang sering dipakai strategy                          |
   //+---------------------------------------------------------------+
   double SignalATR() const { return(m15ATR[1]); }
   datetime SignalTime() const { return(m15Time[1]); }

   double Body(const int shift) const
     {
      return(MathAbs(m15Close[shift] - m15Open[shift]));
     }

   double UpperWick(const int shift) const
     {
      return(m15High[shift] - MathMax(m15Open[shift], m15Close[shift]));
     }

   double LowerWick(const int shift) const
     {
      return(MathMin(m15Open[shift], m15Close[shift]) - m15Low[shift]);
     }

   bool IsBullishCandle(const int shift) const
     {
      return(m15Close[shift] > m15Open[shift]);
     }

   bool IsBearishCandle(const int shift) const
     {
      return(m15Close[shift] < m15Open[shift]);
     }
  };

#endif // TRADINGEA_CORE_MARKETCONTEXT_MQH
//+------------------------------------------------------------------+
