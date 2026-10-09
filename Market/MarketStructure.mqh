//+------------------------------------------------------------------+
//| Market/MarketStructure.mqh                                       |
//| Pemilik confirmed swing dan struktur HH/HL/LH/LL                 |
//| (bagian 9, 44, 47-49).                                           |
//|                                                                  |
//| Module ini juga menghitung SRangeData (bagian 24-27) karena data |
//| tersebut adalah fakta market yang dipakai oleh dua strategy      |
//| sekaligus (Range dan Breakout). Strategy tidak menghitungnya     |
//| sendiri agar keduanya melihat angka yang sama persis.            |
//|                                                                  |
//| NON-REPAINTING: pivot hanya dianggap confirmed setelah           |
//| SwingRight candle sesudahnya selesai close. Karena shift 1       |
//| adalah candle closed terakhir, pivot paling baru yang boleh      |
//| dipakai berada pada shift (1 + SwingRight).                      |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_MARKET_MARKETSTRUCTURE_MQH
#define TRADINGEA_MARKET_MARKETSTRUCTURE_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| CMarketStructure                                                 |
//+------------------------------------------------------------------+
class CMarketStructure
  {
private:
   string            m_module;
   CConfig          *m_config;

   //+---------------------------------------------------------------+
   //| Pivot low pada shift tertentu.                                 |
   //| Kiri  = bar lebih tua  = shift lebih besar                     |
   //| Kanan = bar lebih baru = shift lebih kecil                     |
   //+---------------------------------------------------------------+
   bool              IsSwingLow(const SMarketContext &ctx, const int shift) const
     {
      int left  = m_config.swingLeft;
      int right = m_config.swingRight;

      if(shift - right < 1)              return(false);  // belum confirmed
      if(shift + left >= CTX_M15_BARS)   return(false);  // data tidak cukup

      double pivot = ctx.m15Low[shift];

      for(int k = 1; k <= left; k++)
         if(pivot >= ctx.m15Low[shift + k])
            return(false);

      for(int k = 1; k <= right; k++)
         if(pivot >= ctx.m15Low[shift - k])
            return(false);

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Pivot high pada shift tertentu                                 |
   //+---------------------------------------------------------------+
   bool              IsSwingHigh(const SMarketContext &ctx, const int shift) const
     {
      int left  = m_config.swingLeft;
      int right = m_config.swingRight;

      if(shift - right < 1)              return(false);
      if(shift + left >= CTX_M15_BARS)   return(false);

      double pivot = ctx.m15High[shift];

      for(int k = 1; k <= left; k++)
         if(pivot <= ctx.m15High[shift + k])
            return(false);

      for(int k = 1; k <= right; k++)
         if(pivot <= ctx.m15High[shift - k])
            return(false);

      return(true);
     }

public:
                     CMarketStructure(void) { m_module = "MarketStructure"; m_config = NULL; }

   void              Init(CConfig *config) { m_config = config; }

   //+---------------------------------------------------------------+
   //| Cari dua confirmed swing high dan dua confirmed swing low      |
   //| terbaru, lalu tentukan struktur M15.                           |
   //+---------------------------------------------------------------+
   bool              Update(SMarketContext &ctx) const
     {
      if(m_config == NULL)
        {
         CLogger::Error(m_module, "Config belum di-set");
         return(false);
        }

      ctx.latestSwingHigh.Reset();
      ctx.previousSwingHigh.Reset();
      ctx.latestSwingLow.Reset();
      ctx.previousSwingLow.Reset();
      ctx.structure = STRUCTURE_NONE;

      //--- shift paling baru yang pivotnya sudah confirmed
      int startShift = 1 + m_config.swingRight;
      int maxShift   = CTX_M15_BARS - m_config.swingLeft - 1;

      int foundHigh = 0;
      int foundLow  = 0;

      for(int shift = startShift; shift <= maxShift; shift++)
        {
         if(foundHigh < 2 && IsSwingHigh(ctx, shift))
           {
            if(foundHigh == 0)
              {
               ctx.latestSwingHigh.valid = true;
               ctx.latestSwingHigh.price = ctx.m15High[shift];
               ctx.latestSwingHigh.shift = shift;
               ctx.latestSwingHigh.time  = ctx.m15Time[shift];
              }
            else
              {
               ctx.previousSwingHigh.valid = true;
               ctx.previousSwingHigh.price = ctx.m15High[shift];
               ctx.previousSwingHigh.shift = shift;
               ctx.previousSwingHigh.time  = ctx.m15Time[shift];
              }

            foundHigh++;
           }

         if(foundLow < 2 && IsSwingLow(ctx, shift))
           {
            if(foundLow == 0)
              {
               ctx.latestSwingLow.valid = true;
               ctx.latestSwingLow.price = ctx.m15Low[shift];
               ctx.latestSwingLow.shift = shift;
               ctx.latestSwingLow.time  = ctx.m15Time[shift];
              }
            else
              {
               ctx.previousSwingLow.valid = true;
               ctx.previousSwingLow.price = ctx.m15Low[shift];
               ctx.previousSwingLow.shift = shift;
               ctx.previousSwingLow.time  = ctx.m15Time[shift];
              }

            foundLow++;
           }

         if(foundHigh >= 2 && foundLow >= 2)
            break;
        }

      //--- struktur hanya dinilai bila keempat swing tersedia
      if(ctx.latestSwingHigh.valid && ctx.previousSwingHigh.valid &&
         ctx.latestSwingLow.valid  && ctx.previousSwingLow.valid)
        {
         bool hh = ctx.latestSwingHigh.price > ctx.previousSwingHigh.price;
         bool hl = ctx.latestSwingLow.price  > ctx.previousSwingLow.price;
         bool lh = ctx.latestSwingHigh.price < ctx.previousSwingHigh.price;
         bool ll = ctx.latestSwingLow.price  < ctx.previousSwingLow.price;

         if(hh && hl)
            ctx.structure = STRUCTURE_BULLISH;
         else
            if(lh && ll)
               ctx.structure = STRUCTURE_BEARISH;
        }

      CLogger::Debug(m_module,
                     StringFormat("Structure=%s SwingHigh=%.5f/%.5f SwingLow=%.5f/%.5f",
                                  StructureToString(ctx.structure),
                                  ctx.latestSwingHigh.price, ctx.previousSwingHigh.price,
                                  ctx.latestSwingLow.price,  ctx.previousSwingLow.price));

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Hitung SRangeData (bagian 24-27).                              |
   //|                                                                |
   //| Range dibentuk dari shift 2 sampai shift (1 + RangeLookback).  |
   //| Signal candle (shift 1) TIDAK ikut membentuk range.            |
   //+---------------------------------------------------------------+
   bool              UpdateRange(SMarketContext &ctx) const
     {
      ctx.range.Reset();

      if(m_config == NULL)
         return(false);

      int first = 2;
      int last  = 1 + m_config.rangeLookback;

      if(last >= CTX_M15_BARS)
        {
         CLogger::Error(m_module, "RangeLookback melebihi ukuran MarketContext");
         return(false);
        }

      double high = ctx.m15High[first];
      double low  = ctx.m15Low[first];

      for(int shift = first; shift <= last; shift++)
        {
         if(ctx.m15High[shift] > high) high = ctx.m15High[shift];
         if(ctx.m15Low[shift]  < low)  low  = ctx.m15Low[shift];
        }

      double size = high - low;
      double atr  = ctx.m15ATR[1];

      ctx.range.high = high;
      ctx.range.low  = low;
      ctx.range.size = size;
      ctx.range.mid  = low + (size / 2.0);

      if(size <= 0.0 || atr <= 0.0)
         return(true);   // range tetap invalid, bukan error data

      //--- ukuran range harus proporsional terhadap ATR (bagian 25)
      bool sizeValid = (size >= atr * m_config.minRangeATR) &&
                       (size <= atr * m_config.maxRangeATR);

      //--- interaksi dengan kedua batas (bagian 26)
      double tolerance = atr * m_config.interactionATR;

      for(int shift = first; shift <= last; shift++)
        {
         //--- satu candle dihitung paling banyak satu kali per sisi
         if(ctx.m15High[shift] >= high - tolerance)
            ctx.range.upperInteractions++;

         if(ctx.m15Low[shift] <= low + tolerance)
            ctx.range.lowerInteractions++;
        }

      bool interactionValid = (ctx.range.upperInteractions >= 2) &&
                              (ctx.range.lowerInteractions >= 2);

      //--- posisi harga signal candle di dalam range (bagian 27)
      ctx.range.position = (ctx.m15Close[1] - low) / size;

      ctx.range.valid = sizeValid && interactionValid;

      CLogger::Debug(m_module,
                     StringFormat("Range valid=%s high=%.5f low=%.5f size=%.5f pos=%.3f up=%d low=%d",
                                  (ctx.range.valid ? "true" : "false"),
                                  high, low, size, ctx.range.position,
                                  ctx.range.upperInteractions,
                                  ctx.range.lowerInteractions));

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Lowest low pada rentang shift [fromShift .. toShift]           |
   //+---------------------------------------------------------------+
   static double     LowestLow(const SMarketContext &ctx, const int fromShift, const int toShift)
     {
      int a = MathMin(fromShift, toShift);
      int b = MathMax(fromShift, toShift);

      if(a < 1) a = 1;
      if(b >= CTX_M15_BARS) b = CTX_M15_BARS - 1;

      double result = ctx.m15Low[a];

      for(int shift = a; shift <= b; shift++)
         if(ctx.m15Low[shift] < result)
            result = ctx.m15Low[shift];

      return(result);
     }

   //+---------------------------------------------------------------+
   //| Highest high pada rentang shift [fromShift .. toShift]         |
   //+---------------------------------------------------------------+
   static double     HighestHigh(const SMarketContext &ctx, const int fromShift, const int toShift)
     {
      int a = MathMin(fromShift, toShift);
      int b = MathMax(fromShift, toShift);

      if(a < 1) a = 1;
      if(b >= CTX_M15_BARS) b = CTX_M15_BARS - 1;

      double result = ctx.m15High[a];

      for(int shift = a; shift <= b; shift++)
         if(ctx.m15High[shift] > result)
            result = ctx.m15High[shift];

      return(result);
     }

   //+---------------------------------------------------------------+
   //| Shift dari lowest low pada sebuah rentang                      |
   //+---------------------------------------------------------------+
   static int        LowestLowShift(const SMarketContext &ctx, const int fromShift, const int toShift)
     {
      int a = MathMin(fromShift, toShift);
      int b = MathMax(fromShift, toShift);

      if(a < 1) a = 1;
      if(b >= CTX_M15_BARS) b = CTX_M15_BARS - 1;

      int    bestShift = a;
      double best      = ctx.m15Low[a];

      for(int shift = a; shift <= b; shift++)
         if(ctx.m15Low[shift] < best)
           {
            best      = ctx.m15Low[shift];
            bestShift = shift;
           }

      return(bestShift);
     }

   //+---------------------------------------------------------------+
   //| Shift dari highest high pada sebuah rentang                    |
   //+---------------------------------------------------------------+
   static int        HighestHighShift(const SMarketContext &ctx, const int fromShift, const int toShift)
     {
      int a = MathMin(fromShift, toShift);
      int b = MathMax(fromShift, toShift);

      if(a < 1) a = 1;
      if(b >= CTX_M15_BARS) b = CTX_M15_BARS - 1;

      int    bestShift = a;
      double best      = ctx.m15High[a];

      for(int shift = a; shift <= b; shift++)
         if(ctx.m15High[shift] > best)
           {
            best      = ctx.m15High[shift];
            bestShift = shift;
           }

      return(bestShift);
     }

   static string     StructureToString(const ENUM_MARKET_STRUCTURE structure)
     {
      switch(structure)
        {
         case STRUCTURE_BULLISH: return("BULLISH");
         case STRUCTURE_BEARISH: return("BEARISH");
        }
      return("NONE");
     }
  };

#endif // TRADINGEA_MARKET_MARKETSTRUCTURE_MQH
//+------------------------------------------------------------------+
