//+------------------------------------------------------------------+
//| Utils/VolumeUtils.mqh                                            |
//| Normalisasi volume terhadap symbol specification.                |
//| Pembulatan selalu KE BAWAH agar actual risk tidak melebihi       |
//| configured risk (bagian 60).                                     |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_UTILS_VOLUMEUTILS_MQH
#define TRADINGEA_UTILS_VOLUMEUTILS_MQH

#include "../Core/Types.mqh"

//+------------------------------------------------------------------+
//| CVolumeUtils                                                     |
//+------------------------------------------------------------------+
class CVolumeUtils
  {
public:
   //+---------------------------------------------------------------+
   //| Jumlah desimal yang tersirat dari volume step.                 |
   //+---------------------------------------------------------------+
   static int        StepDigits(const double step)
     {
      if(step <= 0.0)
         return(2);

      int digits = 0;
      double value = step;

      while(value < 1.0 && digits < 8)
        {
         value *= 10.0;
         digits++;
        }

      return(digits);
     }

   //+---------------------------------------------------------------+
   //| Pembulatan volume ke bawah mengikuti volume step.              |
   //+---------------------------------------------------------------+
   static double     NormalizeDown(const double volume, const SSymbolSpec &spec)
     {
      if(!spec.valid || spec.volumeStep <= 0.0)
         return(0.0);

      if(volume <= 0.0)
         return(0.0);

      //--- toleransi kecil agar nilai seperti 0.0299999 akibat
      //    pembulatan floating point tidak turun satu step
      double steps = MathFloor((volume / spec.volumeStep) + 1e-8);
      double result = steps * spec.volumeStep;

      return(NormalizeDouble(result, StepDigits(spec.volumeStep)));
     }

   //+---------------------------------------------------------------+
   //| Validasi volume terhadap batas broker (bagian 61).             |
   //| Volume di bawah minimum DITOLAK, tidak dinaikkan paksa.        |
   //+---------------------------------------------------------------+
   static bool       Validate(double &volume, const SSymbolSpec &spec, string &reason)
     {
      reason = "";

      if(!spec.valid)
        { reason = "SymbolSpecInvalid"; return(false); }

      if(volume <= 0.0)
        { reason = "VolumeZero"; return(false); }

      if(volume > spec.volumeMax)
        {
         //--- dibatasi ke maksimum broker, lalu dinormalisasi ulang
         volume = NormalizeDown(spec.volumeMax, spec);
        }

      if(volume < spec.volumeMin)
        { reason = "VolumeBelowMinimum"; return(false); }

      return(true);
     }
  };

#endif // TRADINGEA_UTILS_VOLUMEUTILS_MQH
//+------------------------------------------------------------------+
