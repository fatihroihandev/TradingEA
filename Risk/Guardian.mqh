//+------------------------------------------------------------------+
//| Risk/Guardian.mqh                                                |
//| Gate sebelum RiskEngine dan eksekusi (bagian 63-70).             |
//|                                                                  |
//| Guardian menjawab satu pertanyaan: "apakah kita BOLEH trade?"    |
//| Guardian tidak menghitung volume dan tidak mengirim order.       |
//|                                                                  |
//| Seluruh check harus PASS. Satu kegagalan menolak entry.          |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_RISK_GUARDIAN_MQH
#define TRADINGEA_RISK_GUARDIAN_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext.mqh"
#include "../Core/TradeSignal.mqh"
#include "../Core/EAState.mqh"
#include "../Trading/PortfolioManager.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/PriceUtils.mqh"
#include "../Utils/TimeUtils.mqh"

//+------------------------------------------------------------------+
//| CGuardian                                                        |
//+------------------------------------------------------------------+
class CGuardian
  {
private:
   string             m_module;
   CConfig           *m_config;
   CEAState          *m_state;
   CPortfolioManager *m_portfolio;

   //+---------------------------------------------------------------+
   //| Daily loss limit (bagian 69)                                   |
   //| Existing position TIDAK dipaksa close, hanya entry baru        |
   //| yang dihentikan sampai hari berikutnya.                        |
   //+---------------------------------------------------------------+
   bool              CheckDailyLoss(void)
     {
      double baseline = m_state.StartOfDayEquity();

      if(baseline <= 0.0)
         return(true);

      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      double lossPct = (baseline - equity) / baseline * 100.0;

      if(lossPct >= m_config.dailyLossLimit)
        {
         m_state.DisableEntriesToday(StringFormat("DailyLoss=%.2f%%", lossPct));
         return(false);
        }

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Max drawdown dari peak equity (bagian 70)                      |
   //| Reset bersifat manual, karena itu EA di-DISABLED, bukan        |
   //| sekadar menonaktifkan entry harian.                            |
   //+---------------------------------------------------------------+
   bool              CheckDrawdown(void)
     {
      double peak = m_state.PeakEquity();

      if(peak <= 0.0)
         return(true);

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double ddPct  = (peak - equity) / peak * 100.0;

      if(ddPct >= m_config.maxDrawdown)
        {
         m_state.Disable(StringFormat("MaxDrawdown=%.2f%%", ddPct));
         return(false);
        }

      return(true);
     }

public:
                     CGuardian(void)
     {
      m_module    = "Guardian";
      m_config    = NULL;
      m_state     = NULL;
      m_portfolio = NULL;
     }

   void              Init(CConfig *config, CEAState *state, CPortfolioManager *portfolio)
     {
      m_config    = config;
      m_state     = state;
      m_portfolio = portfolio;
     }

   //+---------------------------------------------------------------+
   //| Gate pertama: boleh mencari entry baru?                        |
   //| Dipanggil SEBELUM strategy dievaluasi, untuk menghemat         |
   //| perhitungan yang hasilnya pasti tidak dipakai.                 |
   //+---------------------------------------------------------------+
   bool              AllowNewEntry(const SMarketContext &ctx)
     {
      //--- 1. trading diizinkan terminal dan account
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        { CLogger::Reject(m_module, "TerminalTradeNotAllowed"); return(false); }

      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
        { CLogger::Reject(m_module, "ExpertTradeNotAllowed"); return(false); }

      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
        { CLogger::Reject(m_module, "AccountTradeNotAllowed"); return(false); }

      if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
        { CLogger::Reject(m_module, "AccountExpertTradeNotAllowed"); return(false); }

      //--- 2. state EA
      if(!m_state.IsRunning())
        { CLogger::Reject(m_module, "EADisabled"); return(false); }

      //--- 3. drawdown dan daily loss
      if(!CheckDrawdown())
        { CLogger::Reject(m_module, "MaxDrawdownReached"); return(false); }

      if(m_state.EntriesDisabledToday())
        { CLogger::Reject(m_module, "DailyLossLimitReached"); return(false); }

      if(!CheckDailyLoss())
        { CLogger::Reject(m_module, "DailyLossLimitReached"); return(false); }

      //--- 4. batas jumlah posisi (bagian 64)
      int open = m_portfolio.CountOpenPositions();

      if(open >= m_config.maxTotalOpenPositions)
        {
         CLogger::Reject(m_module,
                         StringFormat("MaxOpenPositionsReached open=%d max=%d",
                                      open, m_config.maxTotalOpenPositions));
         return(false);
        }

      //--- 5. spread (bagian 67)
      if(ctx.spreadPoints > m_config.maxSpreadPoints)
        {
         CLogger::Reject(m_module,
                         StringFormat("SpreadTooHigh spread=%.1f max=%d",
                                      ctx.spreadPoints, m_config.maxSpreadPoints));
         return(false);
        }

      //--- 6. sesi (bagian 68), memakai broker server time
      if(m_config.useSessionFilter)
        {
         if(!CTimeUtils::InSession(ctx.serverTime,
                                   m_config.sessionStartHour,
                                   m_config.sessionEndHour))
           {
            CLogger::Reject(m_module, "OutsideSession");
            return(false);
           }
        }

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Gate kedua: validasi isi signal.                               |
   //| Dipanggil setelah strategy menghasilkan kandidat.              |
   //+---------------------------------------------------------------+
   bool              ValidateSignal(const STradeSignal &signal, const SMarketContext &ctx)
     {
      if(!signal.valid)
        { CLogger::Reject(m_module, "SignalNotValid"); return(false); }

      if(signal.direction == SIGNAL_NONE)
        { CLogger::Reject(m_module, "DirectionNone"); return(false); }

      if(signal.strategy == STRATEGY_NONE)
        { CLogger::Reject(m_module, "StrategyNone"); return(false); }

      //--- symbol harus sama dengan yang dikelola EA (bagian 65)
      if(ctx.symbol != m_portfolio.Symbol())
        { CLogger::Reject(m_module, "SymbolMismatch"); return(false); }

      //--- harga wajib terisi
      if(signal.entryPrice <= 0.0)
        { CLogger::Reject(m_module, "EntryPriceInvalid"); return(false); }

      if(signal.stopLoss <= 0.0)
        { CLogger::Reject(m_module, "StopLossMissing"); return(false); }

      if(signal.takeProfit <= 0.0)
        { CLogger::Reject(m_module, "TakeProfitMissing"); return(false); }

      //--- arah SL dan TP
      if(signal.direction == SIGNAL_BUY)
        {
         if(signal.stopLoss >= signal.entryPrice)
           { CLogger::Reject(m_module, "BuyStopLossAboveEntry"); return(false); }

         if(signal.takeProfit <= signal.entryPrice)
           { CLogger::Reject(m_module, "BuyTakeProfitBelowEntry"); return(false); }
        }
      else
        {
         if(signal.stopLoss <= signal.entryPrice)
           { CLogger::Reject(m_module, "SellStopLossBelowEntry"); return(false); }

         if(signal.takeProfit >= signal.entryPrice)
           { CLogger::Reject(m_module, "SellTakeProfitAboveEntry"); return(false); }
        }

      //--- signal harus berasal dari candle closed terakhir
      if(signal.signalTime != ctx.m15Time[1])
        { CLogger::Reject(m_module, "SignalTimeNotSignalCandle"); return(false); }

      return(true);
     }
  };

#endif // TRADINGEA_RISK_GUARDIAN_MQH
//+------------------------------------------------------------------+
