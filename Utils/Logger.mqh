//+------------------------------------------------------------------+
//| Utils/Logger.mqh                                                 |
//| Logging contract bagian 91-93.                                   |
//| Format: [TIME][MODULE][LEVEL] message                            |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_UTILS_LOGGER_MQH
#define TRADINGEA_UTILS_LOGGER_MQH

#include "../Core/Types.mqh"

//+------------------------------------------------------------------+
//| CLogger                                                          |
//| Seluruh method static agar dapat dipanggil dari module mana pun  |
//| tanpa membawa dependency instance.                               |
//+------------------------------------------------------------------+
class CLogger
  {
private:
   static bool       s_debugEnabled;

   static string     LevelToString(const ENUM_EA_LOG_LEVEL level)
     {
      switch(level)
        {
         case EA_LOG_INFO:    return("INFO");
         case EA_LOG_DEBUG:   return("DEBUG");
         case EA_LOG_WARNING: return("WARNING");
         case EA_LOG_ERROR:   return("ERROR");
         case EA_LOG_TRADE:   return("TRADE");
        }
      return("INFO");
     }

   static void       Write(const ENUM_EA_LOG_LEVEL level,
                           const string moduleName,
                           const string message)
     {
      //--- DEBUG hanya ditampilkan bila diaktifkan
      if(level == EA_LOG_DEBUG && !s_debugEnabled)
         return;

      PrintFormat("[%s][%s][%s] %s",
                  TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
                  moduleName,
                  LevelToString(level),
                  message);
     }

public:
   static void       SetDebug(const bool enabled) { s_debugEnabled = enabled; }
   static bool       IsDebug(void)                { return(s_debugEnabled);   }

   static void       Info(const string moduleName, const string message)
     { Write(EA_LOG_INFO, moduleName, message); }

   static void       Debug(const string moduleName, const string message)
     { Write(EA_LOG_DEBUG, moduleName, message); }

   static void       Warning(const string moduleName, const string message)
     { Write(EA_LOG_WARNING, moduleName, message); }

   static void       Error(const string moduleName, const string message)
     { Write(EA_LOG_ERROR, moduleName, message); }

   static void       Trade(const string moduleName, const string message)
     { Write(EA_LOG_TRADE, moduleName, message); }

   //+---------------------------------------------------------------+
   //| Rejection log bagian 93                                        |
   //+---------------------------------------------------------------+
   static void       Reject(const string moduleName, const string reason)
     { Write(EA_LOG_INFO, moduleName, "[REJECT] Reason=" + reason); }

   static void       NoSignal(const string moduleName, const string reason)
     { Write(EA_LOG_DEBUG, moduleName, "[NO_SIGNAL] Reason=" + reason); }
  };

bool CLogger::s_debugEnabled = false;

#endif // TRADINGEA_UTILS_LOGGER_MQH
//+------------------------------------------------------------------+
