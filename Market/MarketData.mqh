//+------------------------------------------------------------------+
//| Market/MarketData.mqh                                            |
//| Pemilik data OHLC, time, bid, ask, spread, dan symbol spec       |
//| (bagian 9, 71).                                                  |
//|                                                                  |
//| Hanya menyalin jumlah bar minimum yang dibutuhkan (bagian 96).   |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_MARKET_MARKETDATA_MQH
#define TRADINGEA_MARKET_MARKETDATA_MQH

#include "../Core/Types.mqh"
#include "../Core/MarketContext.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CMarketData                                                      |
//+------------------------------------------------------------------+
class CMarketData
  {
private:
   string            m_module;
   string            m_symbol;
   SSymbolSpec       m_spec;

   MqlRates          m_ratesM15[];
   MqlRates          m_ratesH1[];

public:
                     CMarketData(void)
     {
      m_module = "MarketData";
      m_symbol = "";
      m_spec.Reset();
     }

   //+---------------------------------------------------------------+
   //| Baca dan validasi spesifikasi symbol broker.                   |
   //| EA tidak boleh hardcode digit, point, maupun volume step.      |
   //+---------------------------------------------------------------+
   bool              Init(const string symbol)
     {
      m_symbol = symbol;
      m_spec.Reset();

      if(!SymbolSelect(m_symbol, true))
        {
         CLogger::Error(m_module, "Symbol tidak tersedia: " + m_symbol);
         return(false);
        }

      m_spec.symbol      = m_symbol;
      m_spec.digits      = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_spec.point       = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_spec.tickSize    = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_spec.tickValue   = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      m_spec.volumeMin   = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      m_spec.volumeMax   = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      m_spec.volumeStep  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      m_spec.stopsLevel  = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      m_spec.freezeLevel = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);

      //--- seluruh nilai inti harus masuk akal, tidak boleh diganti default
      if(m_spec.point      <= 0.0 ||
         m_spec.tickSize   <= 0.0 ||
         m_spec.tickValue  <= 0.0 ||
         m_spec.volumeMin  <= 0.0 ||
         m_spec.volumeMax  <= 0.0 ||
         m_spec.volumeStep <= 0.0 ||
         m_spec.digits     <= 0)
        {
         CLogger::Error(m_module,
                        StringFormat("Symbol specification tidak valid. point=%.10f tickSize=%.10f tickValue=%.5f volMin=%.4f volMax=%.4f volStep=%.4f digits=%d",
                                     m_spec.point, m_spec.tickSize, m_spec.tickValue,
                                     m_spec.volumeMin, m_spec.volumeMax,
                                     m_spec.volumeStep, m_spec.digits));
         return(false);
        }

      if(m_spec.volumeMin > m_spec.volumeMax)
        {
         CLogger::Error(m_module, "VolumeMin lebih besar dari VolumeMax");
         return(false);
        }

      m_spec.valid = true;

      CLogger::Info(m_module,
                    StringFormat("Spec OK digits=%d point=%.10f tickSize=%.10f tickValue=%.5f volStep=%.4f stops=%d freeze=%d",
                                 m_spec.digits, m_spec.point, m_spec.tickSize,
                                 m_spec.tickValue, m_spec.volumeStep,
                                 m_spec.stopsLevel, m_spec.freezeLevel));

      ArraySetAsSeries(m_ratesM15, true);
      ArraySetAsSeries(m_ratesH1,  true);

      return(true);
     }

   const SSymbolSpec Spec(void) const { return(m_spec); }

   //+---------------------------------------------------------------+
   //| Isi bagian harga dan OHLC pada MarketContext.                  |
   //| Mengembalikan false bila data tidak cukup (bagian 95).         |
   //+---------------------------------------------------------------+
   bool              Fill(SMarketContext &ctx)
     {
      ctx.symbol = m_symbol;
      ctx.spec   = m_spec;
      ctx.serverTime = TimeCurrent();

      //--- harga live
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
        {
         CLogger::Error(m_module, "SymbolInfoTick gagal");
         return(false);
        }

      if(tick.bid <= 0.0 || tick.ask <= 0.0)
        {
         CLogger::Error(m_module, "Bid/Ask tidak valid");
         return(false);
        }

      ctx.bid = tick.bid;
      ctx.ask = tick.ask;
      ctx.spreadPoints = (tick.ask - tick.bid) / m_spec.point;

      //--- M15
      int copiedM15 = CopyRates(m_symbol, PERIOD_M15, 0, CTX_M15_BARS, m_ratesM15);
      if(copiedM15 < CTX_M15_BARS)
        {
         CLogger::Error(m_module,
                        StringFormat("CopyRates M15 tidak cukup. diminta=%d diterima=%d",
                                     CTX_M15_BARS, copiedM15));
         return(false);
        }

      for(int i = 0; i < CTX_M15_BARS; i++)
        {
         ctx.m15Time[i]  = m_ratesM15[i].time;
         ctx.m15Open[i]  = m_ratesM15[i].open;
         ctx.m15High[i]  = m_ratesM15[i].high;
         ctx.m15Low[i]   = m_ratesM15[i].low;
         ctx.m15Close[i] = m_ratesM15[i].close;
        }

      //--- H1
      int copiedH1 = CopyRates(m_symbol, PERIOD_H1, 0, CTX_H1_BARS, m_ratesH1);
      if(copiedH1 < CTX_H1_BARS)
        {
         CLogger::Error(m_module,
                        StringFormat("CopyRates H1 tidak cukup. diminta=%d diterima=%d",
                                     CTX_H1_BARS, copiedH1));
         return(false);
        }

      for(int i = 0; i < CTX_H1_BARS; i++)
         ctx.h1Close[i] = m_ratesH1[i].close;

      return(true);
     }
  };

#endif // TRADINGEA_MARKET_MARKETDATA_MQH
//+------------------------------------------------------------------+
