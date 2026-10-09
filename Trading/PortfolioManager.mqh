//+------------------------------------------------------------------+
//| Trading/PortfolioManager.mqh                                     |
//| Kepemilikan posisi (bagian 64-66).                               |
//|                                                                  |
//| EA hanya mengenali posisi yang memenuhi KEDUA syarat:            |
//|   Symbol == configured symbol                                    |
//|   Magic  == EA MagicNumber                                       |
//|                                                                  |
//| Posisi manual atau milik EA lain tidak dihitung dan tidak boleh  |
//| disentuh.                                                        |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_TRADING_PORTFOLIOMANAGER_MQH
#define TRADINGEA_TRADING_PORTFOLIOMANAGER_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CPortfolioManager                                                |
//+------------------------------------------------------------------+
class CPortfolioManager
  {
private:
   string            m_module;
   string            m_symbol;
   long              m_magic;

public:
                     CPortfolioManager(void)
     {
      m_module = "PortfolioManager";
      m_symbol = "";
      m_magic  = 0;
     }

   void              Init(const string symbol, const long magic)
     {
      m_symbol = symbol;
      m_magic  = magic;
     }

   //+---------------------------------------------------------------+
   //| Apakah posisi pada index tersebut milik EA ini                 |
   //+---------------------------------------------------------------+
   bool              IsOwned(const ulong ticket) const
     {
      if(!PositionSelectByTicket(ticket))
         return(false);

      if(PositionGetString(POSITION_SYMBOL) != m_symbol)
         return(false);

      if(PositionGetInteger(POSITION_MAGIC) != m_magic)
         return(false);

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Jumlah posisi milik EA yang sedang terbuka                     |
   //+---------------------------------------------------------------+
   int               CountOpenPositions(void) const
     {
      int count = 0;
      int total = PositionsTotal();

      for(int i = 0; i < total; i++)
        {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         if(IsOwned(ticket))
            count++;
        }

      return(count);
     }

   //+---------------------------------------------------------------+
   //| Ticket posisi milik EA pada urutan ke-n.                       |
   //| return 0 bila tidak ada.                                       |
   //+---------------------------------------------------------------+
   ulong             GetPositionTicket(const int index = 0) const
     {
      int found = 0;
      int total = PositionsTotal();

      for(int i = 0; i < total; i++)
        {
         ulong ticket = PositionGetTicket(i);

         if(ticket == 0)
            continue;

         if(!IsOwned(ticket))
            continue;

         if(found == index)
            return(ticket);

         found++;
        }

      return(0);
     }

   bool              HasOpenPosition(void) const
     {
      return(CountOpenPositions() > 0);
     }

   string            Symbol(void) const { return(m_symbol); }
   long              Magic(void)  const { return(m_magic);  }
  };

#endif // TRADINGEA_TRADING_PORTFOLIOMANAGER_MQH
//+------------------------------------------------------------------+
