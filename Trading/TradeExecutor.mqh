//+------------------------------------------------------------------+
//| Trading/TradeExecutor.mqh                                        |
//| SATU-SATUNYA module yang mengirim order (bagian 75-78).          |
//|                                                                  |
//| Strategy, Guardian, dan RiskEngine tidak boleh menyentuh CTrade. |
//|                                                                  |
//| Retry maksimum 1 kali dan hanya untuk error yang bersifat        |
//| sementara. Tidak ada infinite retry.                             |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_TRADING_TRADEEXECUTOR_MQH
#define TRADINGEA_TRADING_TRADEEXECUTOR_MQH

#include <Trade/Trade.mqh>

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext.mqh"
#include "../Core/TradeSignal.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/PriceUtils.mqh"

//+------------------------------------------------------------------+
//| CTradeExecutor                                                   |
//+------------------------------------------------------------------+
class CTradeExecutor
  {
private:
   string            m_module;
   CConfig          *m_config;
   CTrade            m_trade;
   string            m_symbol;

   //+---------------------------------------------------------------+
   //| Apakah retcode layak dicoba ulang satu kali.                   |
   //+---------------------------------------------------------------+
   bool              IsRecoverable(const uint retcode) const
     {
      switch(retcode)
        {
         case TRADE_RETCODE_REQUOTE:
         case TRADE_RETCODE_PRICE_CHANGED:
         case TRADE_RETCODE_PRICE_OFF:
         case TRADE_RETCODE_TIMEOUT:
         case TRADE_RETCODE_CONNECTION:
            return(true);
        }

      return(false);
     }

   //+---------------------------------------------------------------+
   //| Log kegagalan dengan seluruh konteks (bagian 78)               |
   //+---------------------------------------------------------------+
   void              LogFailure(const STradeSignal &signal, const string stage)
     {
      CLogger::Error(m_module,
                     StringFormat("%s GAGAL retcode=%u desc=%s symbol=%s dir=%s vol=%.4f SL=%.5f TP=%.5f",
                                  stage,
                                  m_trade.ResultRetcode(),
                                  m_trade.ResultRetcodeDescription(),
                                  m_symbol,
                                  signal.DirectionText(),
                                  signal.volume,
                                  signal.stopLoss,
                                  signal.takeProfit));
     }

   //+---------------------------------------------------------------+
   //| Kirim satu order pasar.                                        |
   //+---------------------------------------------------------------+
   bool              SendOrder(const STradeSignal &signal, const SMarketContext &ctx)
     {
      //--- harga eksekusi dibaca ulang dari market saat pengiriman
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
        {
         CLogger::Error(m_module, "SymbolInfoTick gagal saat eksekusi");
         return(false);
        }

      double price = (signal.direction == SIGNAL_BUY) ? tick.ask : tick.bid;
      price = CPriceUtils::Normalize(price, ctx.spec);

      if(signal.direction == SIGNAL_BUY)
         return(m_trade.Buy(signal.volume, m_symbol, price,
                            signal.stopLoss, signal.takeProfit,
                            signal.StrategyText()));

      return(m_trade.Sell(signal.volume, m_symbol, price,
                          signal.stopLoss, signal.takeProfit,
                          signal.StrategyText()));
     }

public:
                     CTradeExecutor(void) { m_module = "TradeExecutor"; m_config = NULL; m_symbol = ""; }

   void              Init(CConfig *config, const string symbol)
     {
      m_config = config;
      m_symbol = symbol;

      m_trade.SetExpertMagicNumber(config.magicNumber);
      m_trade.SetMarginMode();
      m_trade.SetTypeFillingBySymbol(symbol);
      m_trade.SetDeviationInPoints(10);
      m_trade.LogLevel(LOG_LEVEL_NO);   // logging ditangani CLogger
     }

   //+---------------------------------------------------------------+
   //| Eksekusi signal.                                               |
   //| Mengembalikan ticket posisi, atau 0 bila gagal.                |
   //+---------------------------------------------------------------+
   ulong             Execute(const STradeSignal &signal, const SMarketContext &ctx)
     {
      CLogger::Trade(m_module, "Mengirim order. " + signal.ToLogString());

      bool ok = SendOrder(signal, ctx);

      if(!ok)
        {
         LogFailure(signal, "Eksekusi");

         //--- maksimum satu retry, hanya untuk error sementara
         if(!IsRecoverable(m_trade.ResultRetcode()))
            return(0);

         CLogger::Warning(m_module, "Retry eksekusi satu kali");

         ok = SendOrder(signal, ctx);

         if(!ok)
           {
            LogFailure(signal, "Retry eksekusi");
            return(0);
           }
        }

      uint retcode = m_trade.ResultRetcode();

      if(retcode != TRADE_RETCODE_DONE &&
         retcode != TRADE_RETCODE_PLACED &&
         retcode != TRADE_RETCODE_DONE_PARTIAL)
        {
         LogFailure(signal, "Retcode tidak sukses");
         return(0);
        }

      ulong  deal       = m_trade.ResultDeal();
      ulong  order      = m_trade.ResultOrder();
      double dealPrice  = m_trade.ResultPrice();
      double dealVolume = m_trade.ResultVolume();

      CLogger::Trade(m_module,
                     StringFormat("Order terkirim. order=%I64u deal=%I64u price=%.5f volume=%.4f",
                                  order, deal, dealPrice, dealVolume));

      return(order);
     }

   //+---------------------------------------------------------------+
   //| Modifikasi SL/TP posisi yang sudah ada.                        |
   //| Dipakai PositionManager untuk break-even.                      |
   //+---------------------------------------------------------------+
   bool              ModifyPosition(const ulong ticket,
                                    const double stopLoss,
                                    const double takeProfit)
     {
      if(!m_trade.PositionModify(ticket, stopLoss, takeProfit))
        {
         CLogger::Error(m_module,
                        StringFormat("PositionModify gagal ticket=%I64u retcode=%u desc=%s SL=%.5f TP=%.5f",
                                     ticket,
                                     m_trade.ResultRetcode(),
                                     m_trade.ResultRetcodeDescription(),
                                     stopLoss, takeProfit));
         return(false);
        }

      CLogger::Trade(m_module,
                     StringFormat("Posisi dimodifikasi ticket=%I64u SL=%.5f TP=%.5f",
                                  ticket, stopLoss, takeProfit));
      return(true);
     }

   //+---------------------------------------------------------------+
   //| Partial close.                                                 |
   //+---------------------------------------------------------------+
   bool              ClosePartial(const ulong ticket, const double volume)
     {
      if(!m_trade.PositionClosePartial(ticket, volume))
        {
         CLogger::Error(m_module,
                        StringFormat("PositionClosePartial gagal ticket=%I64u volume=%.4f retcode=%u desc=%s",
                                     ticket, volume,
                                     m_trade.ResultRetcode(),
                                     m_trade.ResultRetcodeDescription()));
         return(false);
        }

      CLogger::Trade(m_module,
                     StringFormat("Partial close ticket=%I64u volume=%.4f", ticket, volume));
      return(true);
     }
  };

#endif // TRADINGEA_TRADING_TRADEEXECUTOR_MQH
//+------------------------------------------------------------------+
