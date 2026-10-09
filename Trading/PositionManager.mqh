//+------------------------------------------------------------------+
//| Trading/PositionManager.mqh                                      |
//| Pengelolaan posisi yang SUDAH ada (bagian 79-83).                |
//|                                                                  |
//| PositionManager TIDAK mencari entry baru.                        |
//|                                                                  |
//| Range          : 50% TP1 (mid range), sisanya TP2, setelah TP1   |
//|                  SL dipindah ke harga entry aktual (buffer 0).   |
//| Breakout       : 100% ke TP 2R, tanpa BE, partial, maupun trail. |
//| Trend Pullback : 100% ke TP 2R, tanpa BE, partial, maupun trail. |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_TRADING_POSITIONMANAGER_MQH
#define TRADINGEA_TRADING_POSITIONMANAGER_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/TradeSignal.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/PriceUtils.mqh"
#include "../Utils/VolumeUtils.mqh"
#include "PortfolioManager.mqh"
#include "TradeExecutor.mqh"

//+------------------------------------------------------------------+
//| CPositionManager                                                 |
//+------------------------------------------------------------------+
class CPositionManager
  {
private:
   string             m_module;
   CConfig           *m_config;
   CPortfolioManager *m_portfolio;
   CTradeExecutor    *m_executor;
   SSymbolSpec        m_spec;

   //--- pelacakan posisi yang dikelola
   ulong              m_ticket;
   ENUM_STRATEGY_TYPE m_strategy;
   bool               m_hasPartialTarget;
   double             m_takeProfit1;
   bool               m_partialDone;
   bool               m_breakEvenDone;

   //--- rencana pengelolaan untuk order yang baru dikirim namun
   //    posisinya belum terlihat di terminal
   bool               m_hasPending;
   datetime           m_pendingSince;
   STradeSignal       m_pendingSignal;

   void              ClearTracking(void)
     {
      m_ticket           = 0;
      m_strategy         = STRATEGY_NONE;
      m_hasPartialTarget = false;
      m_takeProfit1      = 0.0;
      m_partialDone      = false;
      m_breakEvenDone    = false;
     }

   void              ClearPending(void)
     {
      m_hasPending   = false;
      m_pendingSince = 0;
      m_pendingSignal.Reset();
     }

   //+---------------------------------------------------------------+
   //| Strategy dari komentar posisi. Dipakai hanya saat adopsi       |
   //| posisi lama setelah restart.                                   |
   //+---------------------------------------------------------------+
   ENUM_STRATEGY_TYPE StrategyFromComment(const string comment) const
     {
      if(StringFind(comment, "RANGE") >= 0)            return(STRATEGY_RANGE);
      if(StringFind(comment, "BREAKOUT_RETEST") >= 0)  return(STRATEGY_BREAKOUT_RETEST);
      if(StringFind(comment, "TREND_PULLBACK") >= 0)   return(STRATEGY_TREND_PULLBACK);
      return(STRATEGY_NONE);
     }

   //+---------------------------------------------------------------+
   //| Modifikasi SL aman terhadap freeze level (bagian 74).          |
   //| Bila tidak valid: dicatat, tidak dipaksa.                      |
   //+---------------------------------------------------------------+
   bool              SafeModifyStopLoss(const ulong ticket,
                                        const double newStopLoss,
                                        const double takeProfit,
                                        const double currentPrice)
     {
      double freeze = CPriceUtils::FreezeDistance(m_spec);

      if(freeze > 0.0 && MathAbs(currentPrice - newStopLoss) < freeze)
        {
         CLogger::Warning(m_module,
                          StringFormat("Modifikasi SL dilewati, berada di dalam freeze level. ticket=%I64u",
                                       ticket));
         return(false);
        }

      double stops = CPriceUtils::MinStopDistance(m_spec);

      if(stops > 0.0 && MathAbs(currentPrice - newStopLoss) < stops)
        {
         CLogger::Warning(m_module,
                          StringFormat("Modifikasi SL dilewati, lebih dekat dari stops level. ticket=%I64u",
                                       ticket));
         return(false);
        }

      return(m_executor.ModifyPosition(ticket,
                                       CPriceUtils::Normalize(newStopLoss, m_spec),
                                       takeProfit));
     }

   //+---------------------------------------------------------------+
   //| Manajemen khusus Range: partial close di TP1 lalu break-even.  |
   //+---------------------------------------------------------------+
   void              ManageRange(const ulong ticket)
     {
      if(!m_hasPartialTarget || m_partialDone)
        {
         //--- partial sudah selesai, tinggal memastikan break-even
         ApplyBreakEven(ticket);
         return;
        }

      long   type       = PositionGetInteger(POSITION_TYPE);
      double volume     = PositionGetDouble(POSITION_VOLUME);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      MqlTick tick;
      if(!SymbolInfoTick(m_portfolio.Symbol(), tick))
         return;

      //--- apakah TP1 sudah tersentuh
      bool reached = false;

      if(type == POSITION_TYPE_BUY)
         reached = (tick.bid >= m_takeProfit1);
      else
         if(type == POSITION_TYPE_SELL)
            reached = (tick.ask <= m_takeProfit1);

      if(!reached)
         return;

      //--- hitung volume parsial (bagian 81)
      double partial = CVolumeUtils::NormalizeDown(volume * 0.5, m_spec);

      if(partial < m_spec.volumeMin || partial <= 0.0)
        {
         //--- 50% tidak dapat direalisasikan pada symbol ini.
         //    Posisi dibiarkan berjalan dengan satu TP yang valid.
         CLogger::Warning(m_module,
                          StringFormat("Partial close tidak memungkinkan. volume=%.4f min=%.4f. Posisi memakai TP tunggal.",
                                       partial, m_spec.volumeMin));
         m_hasPartialTarget = false;
         m_partialDone      = true;
         return;
        }

      //--- sisa setelah partial juga harus valid
      double remaining = CVolumeUtils::NormalizeDown(volume - partial, m_spec);

      if(remaining < m_spec.volumeMin || remaining <= 0.0)
        {
         CLogger::Warning(m_module,
                          "Sisa volume setelah partial di bawah minimum. Partial dibatalkan.");
         m_hasPartialTarget = false;
         m_partialDone      = true;
         return;
        }

      if(!m_executor.ClosePartial(ticket, partial))
         return;   // dicoba lagi pada tick berikutnya

      m_partialDone = true;

      CLogger::Trade(m_module,
                     StringFormat("TP1 tercapai. Partial %.4f lot ditutup, sisa %.4f lot.",
                                  partial, remaining));

      //--- break-even pada harga entry aktual, buffer 0 (bagian 80)
      ApplyBreakEvenPrice(ticket, entryPrice);
     }

   //+---------------------------------------------------------------+
   //| Break-even setelah partial, dipanggil ulang bila sebelumnya    |
   //| gagal (mis. tertahan freeze level).                            |
   //+---------------------------------------------------------------+
   void              ApplyBreakEven(const ulong ticket)
     {
      if(m_breakEvenDone)
         return;

      if(!m_partialDone)
         return;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      ApplyBreakEvenPrice(ticket, entryPrice);
     }

   void              ApplyBreakEvenPrice(const ulong ticket, const double entryPrice)
     {
      if(m_breakEvenDone)
         return;

      long   type       = PositionGetInteger(POSITION_TYPE);
      double currentSL  = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      //--- SL sudah berada pada atau lebih baik dari entry
      if(type == POSITION_TYPE_BUY && currentSL >= entryPrice)
        { m_breakEvenDone = true; return; }

      if(type == POSITION_TYPE_SELL && currentSL > 0.0 && currentSL <= entryPrice)
        { m_breakEvenDone = true; return; }

      MqlTick tick;
      if(!SymbolInfoTick(m_portfolio.Symbol(), tick))
         return;

      double currentPrice = (type == POSITION_TYPE_BUY) ? tick.bid : tick.ask;

      if(SafeModifyStopLoss(ticket, entryPrice, takeProfit, currentPrice))
        {
         m_breakEvenDone = true;
         CLogger::Trade(m_module,
                        StringFormat("Break-even diterapkan. ticket=%I64u SL=%.5f",
                                     ticket, entryPrice));
        }
     }

public:
                     CPositionManager(void)
     {
      m_module    = "PositionManager";
      m_config    = NULL;
      m_portfolio = NULL;
      m_executor  = NULL;
      m_spec.Reset();
      ClearTracking();
      ClearPending();
     }

   void              Init(CConfig *config,
                          CPortfolioManager *portfolio,
                          CTradeExecutor *executor,
                          const SSymbolSpec &spec)
     {
      m_config    = config;
      m_portfolio = portfolio;
      m_executor  = executor;
      m_spec      = spec;

      ClearTracking();
      ClearPending();
     }

   //+---------------------------------------------------------------+
   //| Simpan rencana pengelolaan ketika order sudah terkirim namun   |
   //| posisinya belum terlihat di terminal.                          |
   //|                                                                |
   //| Tanpa ini, posisi Range yang muncul terlambat akan diadopsi    |
   //| sebagai posisi tanpa TP1 dan partial close-nya hilang.         |
   //+---------------------------------------------------------------+
   void              RegisterPending(const STradeSignal &signal)
     {
      m_hasPending    = true;
      m_pendingSince  = TimeCurrent();
      m_pendingSignal = signal;

      CLogger::Info(m_module,
                    StringFormat("Rencana pengelolaan disimpan sementara. strategy=%s TP1=%.5f",
                                 signal.StrategyText(), signal.takeProfit1));
     }

   //+---------------------------------------------------------------+
   //| Daftarkan posisi yang baru dibuka beserta rencana              |
   //| pengelolaannya.                                                |
   //+---------------------------------------------------------------+
   void              Register(const ulong ticket, const STradeSignal &signal)
     {
      m_ticket           = ticket;
      m_strategy         = signal.strategy;
      m_hasPartialTarget = signal.hasPartialTarget;
      m_takeProfit1      = signal.takeProfit1;
      m_partialDone      = false;
      m_breakEvenDone    = false;

      ClearPending();

      CLogger::Info(m_module,
                    StringFormat("Posisi dilacak. ticket=%I64u strategy=%s TP1=%.5f",
                                 ticket, signal.StrategyText(), m_takeProfit1));
     }

   //+---------------------------------------------------------------+
   //| Adopsi posisi yang sudah ada saat EA start (bagian 86).        |
   //|                                                                |
   //| TP1 tidak dapat direkonstruksi dari posisi, karena itu posisi  |
   //| hasil adopsi dikelola dengan TP tunggal yang sudah terpasang.  |
   //+---------------------------------------------------------------+
   void              AdoptExisting(void)
     {
      ClearTracking();

      ulong ticket = m_portfolio.GetPositionTicket(0);

      if(ticket == 0)
        {
         CLogger::Info(m_module, "Tidak ada posisi milik EA saat start");
         return;
        }

      if(!PositionSelectByTicket(ticket))
         return;

      string comment = PositionGetString(POSITION_COMMENT);

      m_ticket           = ticket;
      m_strategy         = StrategyFromComment(comment);
      m_hasPartialTarget = false;
      m_takeProfit1      = 0.0;
      m_partialDone      = true;    // tidak ada partial untuk posisi adopsi
      m_breakEvenDone    = true;

      CLogger::Warning(m_module,
                       StringFormat("Posisi lama diadopsi. ticket=%I64u comment=%s. Dikelola dengan TP tunggal yang sudah terpasang.",
                                    ticket, comment));
     }

   //+---------------------------------------------------------------+
   //| Dipanggil setiap tick (bagian 79).                             |
   //+---------------------------------------------------------------+
   void              Manage(void)
     {
      if(m_ticket == 0)
        {
         //--- tidak ada yang dilacak, cek apakah muncul posisi milik EA
         ulong ticket = m_portfolio.GetPositionTicket(0);

         if(ticket != 0)
           {
            if(m_hasPending)
               Register(ticket, m_pendingSignal);   // rencana asli dipakai
            else
               AdoptExisting();                     // posisi lama / tak dikenal

            return;
           }

         //--- rencana yang tidak pernah menjadi posisi tidak boleh
         //    menempel selamanya
         if(m_hasPending && (TimeCurrent() - m_pendingSince) > 60)
           {
            CLogger::Warning(m_module, "Rencana pengelolaan kedaluwarsa tanpa posisi. Dibuang.");
            ClearPending();
           }

         return;
        }

      //--- deteksi posisi tertutup
      if(!PositionSelectByTicket(m_ticket) || !m_portfolio.IsOwned(m_ticket))
        {
         CLogger::Info(m_module,
                       StringFormat("Posisi ditutup atau tidak lagi milik EA. ticket=%I64u", m_ticket));
         ClearTracking();
         return;
        }

      //--- Breakout dan Trend Pullback tidak memerlukan pengelolaan
      //    (bagian 82, 83)
      if(m_strategy != STRATEGY_RANGE)
         return;

      ManageRange(m_ticket);
     }

   ulong             TrackedTicket(void) const { return(m_ticket); }
  };

#endif // TRADINGEA_TRADING_POSITIONMANAGER_MQH
//+------------------------------------------------------------------+
