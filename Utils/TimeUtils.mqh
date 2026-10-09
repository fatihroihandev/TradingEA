//+------------------------------------------------------------------+
//| Utils/TimeUtils.mqh                                              |
//| Seluruh perhitungan waktu memakai broker server time             |
//| (bagian 68-69).                                                  |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_UTILS_TIMEUTILS_MQH
#define TRADINGEA_UTILS_TIMEUTILS_MQH

//+------------------------------------------------------------------+
//| CTimeUtils                                                       |
//+------------------------------------------------------------------+
class CTimeUtils
  {
public:
   //+---------------------------------------------------------------+
   //| Tanggal (tanpa jam) dari sebuah waktu server.                  |
   //+---------------------------------------------------------------+
   static datetime   DateOf(const datetime t)
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);

      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;

      return(StructToTime(dt));
     }

   static int        HourOf(const datetime t)
     {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      return(dt.hour);
     }

   //+---------------------------------------------------------------+
   //| Apakah jam server berada dalam sesi yang dikonfigurasi.        |
   //| Sesi yang melewati tengah malam (start > end) didukung.        |
   //+---------------------------------------------------------------+
   static bool       InSession(const datetime serverTime,
                               const int startHour,
                               const int endHour)
     {
      int hour = HourOf(serverTime);

      if(startHour == endHour)
         return(true);

      if(startHour < endHour)
         return(hour >= startHour && hour < endHour);

      //--- sesi melewati tengah malam
      return(hour >= startHour || hour < endHour);
     }
  };

#endif // TRADINGEA_UTILS_TIMEUTILS_MQH
//+------------------------------------------------------------------+
