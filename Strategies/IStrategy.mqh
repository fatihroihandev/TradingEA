//+------------------------------------------------------------------+
//| Strategies/IStrategy.mqh                                         |
//| Contract strategy (bagian 22).                                   |
//|                                                                  |
//| Strategy HANYA menghasilkan TradeSignal. Strategy DILARANG:      |
//|   - memanggil CTrade                                             |
//|   - menghitung volume                                            |
//|   - mengakses CopyRates / CopyBuffer                             |
//|   - mengubah state milik strategy lain                           |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_STRATEGIES_ISTRATEGY_MQH
#define TRADINGEA_STRATEGIES_ISTRATEGY_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext.mqh"
#include "../Core/TradeSignal.mqh"
#include "../Core/EAState.mqh"

//+------------------------------------------------------------------+
//| IStrategy                                                        |
//+------------------------------------------------------------------+
class IStrategy
  {
protected:
   string            m_module;
   CConfig          *m_config;
   CEAState         *m_state;

public:
                     IStrategy(void) { m_module = "Strategy"; m_config = NULL; m_state = NULL; }
   virtual          ~IStrategy(void) { }

   virtual void      Init(CConfig *config, CEAState *state)
     {
      m_config = config;
      m_state  = state;
     }

   string            Name(void) const { return(m_module); }

   //+---------------------------------------------------------------+
   //| Tipe strategy yang diwakili instance ini                       |
   //+---------------------------------------------------------------+
   virtual ENUM_STRATEGY_TYPE Type(void) const = NULL;

   //+---------------------------------------------------------------+
   //| Perbarui state internal strategy pada setiap M15 bar baru.     |
   //| Dipanggil SEBELUM Evaluate() dan tetap dipanggil walaupun      |
   //| Guardian menolak entry, agar state machine tidak tertinggal.   |
   //+---------------------------------------------------------------+
   virtual void      UpdateState(const SMarketContext &ctx) { }

   //+---------------------------------------------------------------+
   //| Evaluasi setup.                                                |
   //| return true  : signal kandidat terisi pada parameter signal    |
   //| return false : tidak ada signal                                |
   //+---------------------------------------------------------------+
   virtual bool      Evaluate(const SMarketContext &ctx, STradeSignal &signal) = NULL;
  };

#endif // TRADINGEA_STRATEGIES_ISTRATEGY_MQH
//+------------------------------------------------------------------+
