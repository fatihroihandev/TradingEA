//+------------------------------------------------------------------+
//| Strategies/StrategyEngine.mqh                                    |
//| Routing strategy berdasarkan regime (bagian 21, 89, 90).         |
//|                                                                  |
//| StrategyEngine TIDAK melakukan eksekusi dan TIDAK menghitung     |
//| volume. Tugasnya hanya memilih satu strategy dan mengembalikan   |
//| kandidat TradeSignal.                                            |
//|                                                                  |
//| Menambahkan strategy baru (bagian 106):                          |
//|   1. buat file di Strategies/ yang mewarisi IStrategy            |
//|   2. include di sini                                             |
//|   3. tambahkan instance pada Init() dan routing pada Select()    |
//| Core tidak perlu diubah.                                         |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_STRATEGIES_STRATEGYENGINE_MQH
#define TRADINGEA_STRATEGIES_STRATEGYENGINE_MQH

#include "IStrategy.mqh"
#include "RangeStrategy.mqh"
#include "BreakoutStrategy.mqh"
#include "TrendPullbackStrategy.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CStrategyEngine                                                  |
//+------------------------------------------------------------------+
class CStrategyEngine
  {
private:
   string                     m_module;
   CConfig                   *m_config;
   CEAState                  *m_state;

   CRangeStrategy             m_range;
   CBreakoutStrategy          m_breakout;
   CTrendPullbackStrategy     m_pullback;

   //--- daftar seluruh strategy untuk pemanggilan UpdateState()
   IStrategy                 *m_all[3];
   int                        m_count;

public:
                     CStrategyEngine(void)
     {
      m_module = "StrategyEngine";
      m_config = NULL;
      m_state  = NULL;
      m_count  = 0;
     }

   //+---------------------------------------------------------------+
   //| Init                                                           |
   //+---------------------------------------------------------------+
   void              Init(CConfig *config, CEAState *state)
     {
      m_config = config;
      m_state  = state;

      m_range.Init(config, state);
      m_breakout.Init(config, state);
      m_pullback.Init(config, state);

      m_count = 0;
      m_all[m_count++] = GetPointer(m_range);
      m_all[m_count++] = GetPointer(m_breakout);
      m_all[m_count++] = GetPointer(m_pullback);

      CLogger::Info(m_module, StringFormat("%d strategy terdaftar", m_count));
     }

   //+---------------------------------------------------------------+
   //| Perbarui state seluruh strategy.                               |
   //|                                                                |
   //| Dipanggil pada setiap M15 bar baru SEBELUM Guardian, agar      |
   //| state machine (mis. expiry breakout) tetap maju walaupun EA    |
   //| sedang tidak diizinkan membuka entry.                          |
   //+---------------------------------------------------------------+
   void              UpdateStates(const SMarketContext &ctx)
     {
      for(int i = 0; i < m_count; i++)
         m_all[i].UpdateState(ctx);
     }

   //+---------------------------------------------------------------+
   //| Pilih strategy sesuai regime.                                  |
   //| return NULL bila tidak ada strategy untuk regime tersebut.     |
   //+---------------------------------------------------------------+
   IStrategy        *Select(const ENUM_MARKET_REGIME regime)
     {
      switch(regime)
        {
         case REGIME_SIDEWAYS:
            return(GetPointer(m_range));

         case REGIME_TRANSITION:
            return(GetPointer(m_breakout));

         case REGIME_TREND_BULLISH:
         case REGIME_TREND_BEARISH:
            return(GetPointer(m_pullback));
        }

      return(NULL);
     }

   //+---------------------------------------------------------------+
   //| Cari kandidat signal.                                          |
   //|                                                                |
   //| Bagian 90: maksimum satu kandidat per candle M15. Karena       |
   //| hanya satu strategy aktif per regime, tidak terjadi collision. |
   //+---------------------------------------------------------------+
   bool              FindSignal(const SMarketContext &ctx, STradeSignal &signal)
     {
      signal.Reset();

      IStrategy *strategy = Select(ctx.regime);

      if(strategy == NULL)
        {
         CLogger::Debug(m_module, "Tidak ada strategy untuk regime ini");
         return(false);
        }

      if(!strategy.Evaluate(ctx, signal))
         return(false);

      if(!signal.valid)
         return(false);

      CLogger::Info(m_module, "[SIGNAL] " + signal.ToLogString() + " Reason=" + signal.reason);
      return(true);
     }
  };

#endif // TRADINGEA_STRATEGIES_STRATEGYENGINE_MQH
//+------------------------------------------------------------------+
