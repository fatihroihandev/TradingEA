//+------------------------------------------------------------------+
//| Market/IndicatorManager.mqh                                      |
//| Pemilik seluruh indicator handle (bagian 9, 13, 14, 97).         |
//|                                                                  |
//| Handle dibuat sekali pada Init() dan dilepas pada Release().     |
//| Jika CopyBuffer gagal, EA TIDAK memakai 0 sebagai pengganti -    |
//| Fill() mengembalikan false dan cycle dibatalkan.                 |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_MARKET_INDICATORMANAGER_MQH
#define TRADINGEA_MARKET_INDICATORMANAGER_MQH

#include "../Core/Types.mqh"
#include "../Core/MarketContext.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CIndicatorManager                                                |
//+------------------------------------------------------------------+
class CIndicatorManager
  {
private:
   string            m_module;
   string            m_symbol;

   //--- H1
   int               m_hH1EMA50;
   int               m_hH1EMA200;
   int               m_hH1ADX;
   int               m_hH1ATR;

   //--- M15
   int               m_hM15EMA50;
   int               m_hM15ADX;
   int               m_hM15ATR;
   int               m_hM15BB;      // tersedia, tidak dipakai pada v2.0

   double            m_buffer[];

   bool              CreateHandle(int &handle, const int created, const string name)
     {
      handle = created;

      if(handle == INVALID_HANDLE)
        {
         CLogger::Error(m_module, "Gagal membuat handle indicator: " + name);
         return(false);
        }

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Salin buffer indicator ke array context.                       |
   //| Memakai jumlah bar sesuai ukuran snapshot.                     |
   //+---------------------------------------------------------------+
   bool              CopyInto(const int handle,
                              const int bufferIndex,
                              const int count,
                              double &target[],
                              const string name)
     {
      if(handle == INVALID_HANDLE)
        {
         CLogger::Error(m_module, "Handle tidak valid: " + name);
         return(false);
        }

      if(ArraySize(m_buffer) < count)
         ArrayResize(m_buffer, count);

      ArraySetAsSeries(m_buffer, true);

      int copied = CopyBuffer(handle, bufferIndex, 0, count, m_buffer);

      if(copied < count)
        {
         CLogger::Error(m_module,
                        StringFormat("CopyBuffer %s tidak cukup. diminta=%d diterima=%d",
                                     name, count, copied));
         return(false);
        }

      for(int i = 0; i < count; i++)
        {
         //--- nilai tidak boleh berupa data kosong
         if(!MathIsValidNumber(m_buffer[i]))
           {
            CLogger::Error(m_module, "Nilai indicator tidak valid pada " + name);
            return(false);
           }

         target[i] = m_buffer[i];
        }

      return(true);
     }

public:
                     CIndicatorManager(void)
     {
      m_module    = "IndicatorManager";
      m_symbol    = "";
      m_hH1EMA50  = INVALID_HANDLE;
      m_hH1EMA200 = INVALID_HANDLE;
      m_hH1ADX    = INVALID_HANDLE;
      m_hH1ATR    = INVALID_HANDLE;
      m_hM15EMA50 = INVALID_HANDLE;
      m_hM15ADX   = INVALID_HANDLE;
      m_hM15ATR   = INVALID_HANDLE;
      m_hM15BB    = INVALID_HANDLE;
     }

   //+---------------------------------------------------------------+
   //| Buat seluruh handle. Dipanggil sekali pada OnInit().           |
   //+---------------------------------------------------------------+
   bool              Init(const string symbol)
     {
      m_symbol = symbol;

      ArrayResize(m_buffer, CTX_M15_BARS);
      ArraySetAsSeries(m_buffer, true);

      //--- H1: EMA50, EMA200, ADX14, ATR14
      if(!CreateHandle(m_hH1EMA50,
                       iMA(m_symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE),
                       "H1 EMA50"))
         return(false);

      if(!CreateHandle(m_hH1EMA200,
                       iMA(m_symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE),
                       "H1 EMA200"))
         return(false);

      if(!CreateHandle(m_hH1ADX,
                       iADX(m_symbol, PERIOD_H1, 14),
                       "H1 ADX14"))
         return(false);

      if(!CreateHandle(m_hH1ATR,
                       iATR(m_symbol, PERIOD_H1, 14),
                       "H1 ATR14"))
         return(false);

      //--- M15: EMA50, ADX14, ATR14, Bollinger 20/2
      if(!CreateHandle(m_hM15EMA50,
                       iMA(m_symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE),
                       "M15 EMA50"))
         return(false);

      if(!CreateHandle(m_hM15ADX,
                       iADX(m_symbol, PERIOD_M15, 14),
                       "M15 ADX14"))
         return(false);

      if(!CreateHandle(m_hM15ATR,
                       iATR(m_symbol, PERIOD_M15, 14),
                       "M15 ATR14"))
         return(false);

      //--- Bollinger disiapkan sesuai bagian 13 namun tidak dipakai v2.0
      if(!CreateHandle(m_hM15BB,
                       iBands(m_symbol, PERIOD_M15, 20, 0, 2.0, PRICE_CLOSE),
                       "M15 Bollinger 20/2"))
         return(false);

      CLogger::Info(m_module, "Seluruh indicator handle berhasil dibuat");
      return(true);
     }

   //+---------------------------------------------------------------+
   //| Lepas seluruh handle. Dipanggil pada OnDeinit().               |
   //+---------------------------------------------------------------+
   void              Release(void)
     {
      if(m_hH1EMA50  != INVALID_HANDLE) { IndicatorRelease(m_hH1EMA50);  m_hH1EMA50  = INVALID_HANDLE; }
      if(m_hH1EMA200 != INVALID_HANDLE) { IndicatorRelease(m_hH1EMA200); m_hH1EMA200 = INVALID_HANDLE; }
      if(m_hH1ADX    != INVALID_HANDLE) { IndicatorRelease(m_hH1ADX);    m_hH1ADX    = INVALID_HANDLE; }
      if(m_hH1ATR    != INVALID_HANDLE) { IndicatorRelease(m_hH1ATR);    m_hH1ATR    = INVALID_HANDLE; }
      if(m_hM15EMA50 != INVALID_HANDLE) { IndicatorRelease(m_hM15EMA50); m_hM15EMA50 = INVALID_HANDLE; }
      if(m_hM15ADX   != INVALID_HANDLE) { IndicatorRelease(m_hM15ADX);   m_hM15ADX   = INVALID_HANDLE; }
      if(m_hM15ATR   != INVALID_HANDLE) { IndicatorRelease(m_hM15ATR);   m_hM15ATR   = INVALID_HANDLE; }
      if(m_hM15BB    != INVALID_HANDLE) { IndicatorRelease(m_hM15BB);    m_hM15BB    = INVALID_HANDLE; }

      CLogger::Info(m_module, "Seluruh indicator handle dilepas");
     }

   //+---------------------------------------------------------------+
   //| Isi bagian indicator pada MarketContext.                       |
   //+---------------------------------------------------------------+
   bool              Fill(SMarketContext &ctx)
     {
      //--- H1
      if(!CopyInto(m_hH1EMA50,  0, CTX_H1_BARS, ctx.h1EMA50,  "H1 EMA50"))  return(false);
      if(!CopyInto(m_hH1EMA200, 0, CTX_H1_BARS, ctx.h1EMA200, "H1 EMA200")) return(false);
      if(!CopyInto(m_hH1ADX,    0, CTX_H1_BARS, ctx.h1ADX,    "H1 ADX14"))  return(false);
      if(!CopyInto(m_hH1ATR,    0, CTX_H1_BARS, ctx.h1ATR,    "H1 ATR14"))  return(false);

      //--- M15
      if(!CopyInto(m_hM15EMA50, 0, CTX_M15_BARS, ctx.m15EMA50, "M15 EMA50")) return(false);
      if(!CopyInto(m_hM15ADX,   0, CTX_M15_BARS, ctx.m15ADX,   "M15 ADX14")) return(false);
      if(!CopyInto(m_hM15ATR,   0, CTX_M15_BARS, ctx.m15ATR,   "M15 ATR14")) return(false);

      //--- ATR tidak boleh nol, seluruh toleransi strategy memakainya
      if(ctx.m15ATR[1] <= 0.0 || ctx.h1ATR[1] <= 0.0)
        {
         CLogger::Error(m_module, "ATR bernilai nol pada signal candle");
         return(false);
        }

      return(true);
     }
  };

#endif // TRADINGEA_MARKET_INDICATORMANAGER_MQH
//+------------------------------------------------------------------+
