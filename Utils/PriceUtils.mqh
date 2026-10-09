//+------------------------------------------------------------------+
//| Utils/PriceUtils.mqh                                             |
//| Normalisasi harga terhadap symbol specification (bagian 72-73).  |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_UTILS_PRICEUTILS_MQH
#define TRADINGEA_UTILS_PRICEUTILS_MQH

#include "../Core/Types.mqh"

//+------------------------------------------------------------------+
//| CPriceUtils                                                      |
//+------------------------------------------------------------------+
class CPriceUtils
  {
public:
   //+---------------------------------------------------------------+
   //| Normalisasi harga ke kelipatan tick size lalu ke digits.       |
   //| Tidak memakai asumsi 5 digit / 0.00001 point.                  |
   //+---------------------------------------------------------------+
   static double     Normalize(const double price, const SSymbolSpec &spec)
     {
      if(!spec.valid || spec.tickSize <= 0.0)
         return(price);

      double steps  = MathRound(price / spec.tickSize);
      double result = steps * spec.tickSize;

      return(NormalizeDouble(result, spec.digits));
     }

   //+---------------------------------------------------------------+
   //| Jarak harga dalam point.                                       |
   //+---------------------------------------------------------------+
   static double     ToPoints(const double distance, const SSymbolSpec &spec)
     {
      if(!spec.valid || spec.point <= 0.0)
         return(0.0);

      return(MathAbs(distance) / spec.point);
     }

   //+---------------------------------------------------------------+
   //| Jarak minimum SL/TP dari harga, dalam satuan harga.            |
   //+---------------------------------------------------------------+
   static double     MinStopDistance(const SSymbolSpec &spec)
     {
      if(!spec.valid)
         return(0.0);

      return(spec.stopsLevel * spec.point);
     }

   static double     FreezeDistance(const SSymbolSpec &spec)
     {
      if(!spec.valid)
         return(0.0);

      return(spec.freezeLevel * spec.point);
     }

   //+---------------------------------------------------------------+
   //| Validasi jarak SL dan TP terhadap stops level broker.          |
   //| EA tidak menggeser SL/TP agar diterima broker - hanya menolak. |
   //+---------------------------------------------------------------+
   static bool       StopsAreValid(const ENUM_SIGNAL_DIRECTION direction,
                                   const double entry,
                                   const double sl,
                                   const double tp,
                                   const SSymbolSpec &spec,
                                   string &reason)
     {
      reason = "";

      if(!spec.valid)
        { reason = "SymbolSpecInvalid"; return(false); }

      if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
        { reason = "PriceNotPositive"; return(false); }

      //--- arah SL dan TP harus benar
      if(direction == SIGNAL_BUY)
        {
         if(sl >= entry) { reason = "BuyStopLossAboveEntry";   return(false); }
         if(tp <= entry) { reason = "BuyTakeProfitBelowEntry"; return(false); }
        }
      else
         if(direction == SIGNAL_SELL)
           {
            if(sl <= entry) { reason = "SellStopLossBelowEntry";  return(false); }
            if(tp >= entry) { reason = "SellTakeProfitAboveEntry"; return(false); }
           }
         else
           {
            reason = "DirectionNone";
            return(false);
           }

      //--- jarak minimum broker
      double minDistance = MinStopDistance(spec);

      if(minDistance > 0.0)
        {
         if(MathAbs(entry - sl) < minDistance)
           { reason = "StopLossTooCloseToStopsLevel"; return(false); }

         if(MathAbs(tp - entry) < minDistance)
           { reason = "TakeProfitTooCloseToStopsLevel"; return(false); }
        }

      return(true);
     }
  };

#endif // TRADINGEA_UTILS_PRICEUTILS_MQH
//+------------------------------------------------------------------+
