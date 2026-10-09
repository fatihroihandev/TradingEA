//+------------------------------------------------------------------+
//| Core/EAState.mqh                                                 |
//| Runtime state EA: status jalan, baseline risiko harian, peak     |
//| equity, dan state breakout yang harus bertahan setelah restart   |
//| (bagian 69, 70, 85, 86).                                         |
//|                                                                  |
//| Persistence memakai Global Variables of Terminal. Nilai hanya    |
//| dipakai sebagai fallback - BreakoutStrategy tetap mencoba        |
//| rekonstruksi dari market history terlebih dahulu (bagian 85).    |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_CORE_EASTATE_MQH
#define TRADINGEA_CORE_EASTATE_MQH

#include "Types.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/TimeUtils.mqh"

//+------------------------------------------------------------------+
//| CEAState                                                         |
//+------------------------------------------------------------------+
class CEAState
  {
private:
   string            m_module;
   string            m_prefix;          // prefix global variable

   ENUM_EA_RUN_STATE m_runState;
   bool              m_entriesDisabledToday;

   datetime          m_currentDate;
   double            m_startOfDayEquity;
   double            m_peakEquity;

   //--- state breakout
   ENUM_BREAKOUT_STATE   m_breakoutState;
   ENUM_SIGNAL_DIRECTION m_breakoutDirection;
   double                m_breakoutLevel;
   datetime              m_breakoutBarTime;

   string            GvName(const string key) const
     {
      return(m_prefix + key);
     }

public:
                     CEAState(void)
     {
      m_module               = "EAState";
      m_prefix               = "";
      m_runState             = EA_RUNNING;
      m_entriesDisabledToday = false;
      m_currentDate          = 0;
      m_startOfDayEquity     = 0.0;
      m_peakEquity           = 0.0;
      m_breakoutState        = BREAKOUT_IDLE;
      m_breakoutDirection    = SIGNAL_NONE;
      m_breakoutLevel        = 0.0;
      m_breakoutBarTime      = 0;
     }

   //+---------------------------------------------------------------+
   //| Inisialisasi. Dipanggil sekali pada OnInit().                  |
   //+---------------------------------------------------------------+
   void              Init(const string symbol, const long magic)
     {
      m_prefix = StringFormat("TradingEA_%s_%I64d_", symbol, magic);

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      m_currentDate      = CTimeUtils::DateOf(TimeCurrent());
      m_startOfDayEquity = equity;
      m_peakEquity       = equity;
      m_runState         = EA_RUNNING;
      m_entriesDisabledToday = false;

      LoadPersistedState();

      CLogger::Info(m_module,
                    StringFormat("Init equity=%.2f peak=%.2f date=%s",
                                 equity, m_peakEquity,
                                 TimeToString(m_currentDate, TIME_DATE)));
     }

   //+---------------------------------------------------------------+
   //| Dipanggil setiap tick. Rollover harian dan peak equity.        |
   //+---------------------------------------------------------------+
   void              UpdateRuntime(void)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      //--- rollover hari baru (broker server date)
      datetime today = CTimeUtils::DateOf(TimeCurrent());

      if(today != m_currentDate)
        {
         m_currentDate          = today;
         m_startOfDayEquity     = equity;
         m_entriesDisabledToday = false;

         CLogger::Info(m_module,
                       StringFormat("Hari baru. Baseline equity=%.2f", equity));
        }

      //--- peak equity hanya naik
      if(equity > m_peakEquity)
         m_peakEquity = equity;
     }

   //+---------------------------------------------------------------+
   //| Accessor state EA                                              |
   //+---------------------------------------------------------------+
   ENUM_EA_RUN_STATE RunState(void)  const { return(m_runState); }
   bool              IsRunning(void) const { return(m_runState == EA_RUNNING); }

   void              Disable(const string reason)
     {
      if(m_runState == EA_DISABLED)
         return;

      m_runState = EA_DISABLED;
      CLogger::Warning(m_module, "EA DISABLED. Reason=" + reason);
     }

   bool              EntriesDisabledToday(void) const { return(m_entriesDisabledToday); }

   void              DisableEntriesToday(const string reason)
     {
      if(m_entriesDisabledToday)
         return;

      m_entriesDisabledToday = true;
      CLogger::Warning(m_module, "Entry baru dinonaktifkan hari ini. Reason=" + reason);
     }

   double            StartOfDayEquity(void) const { return(m_startOfDayEquity); }
   double            PeakEquity(void)       const { return(m_peakEquity);       }

   //+---------------------------------------------------------------+
   //| Accessor state breakout.                                       |
   //| Hanya BreakoutStrategy yang memanggil setter (bagian 38).      |
   //+---------------------------------------------------------------+
   ENUM_BREAKOUT_STATE   BreakoutState(void)     const { return(m_breakoutState);     }
   ENUM_SIGNAL_DIRECTION BreakoutDirection(void) const { return(m_breakoutDirection); }
   double                BreakoutLevel(void)     const { return(m_breakoutLevel);     }
   datetime              BreakoutBarTime(void)   const { return(m_breakoutBarTime);   }

   void              SetBreakoutWaiting(const ENUM_SIGNAL_DIRECTION direction,
                                        const double level,
                                        const datetime barTime)
     {
      m_breakoutState     = BREAKOUT_WAITING_RETEST;
      m_breakoutDirection = direction;
      m_breakoutLevel     = level;
      m_breakoutBarTime   = barTime;

      PersistBreakoutState();
     }

   void              ClearBreakout(void)
     {
      m_breakoutState     = BREAKOUT_IDLE;
      m_breakoutDirection = SIGNAL_NONE;
      m_breakoutLevel     = 0.0;
      m_breakoutBarTime   = 0;

      PersistBreakoutState();
     }

   //+---------------------------------------------------------------+
   //| Persistence                                                    |
   //+---------------------------------------------------------------+
   void              PersistBreakoutState(void)
     {
      GlobalVariableSet(GvName("bo_state"),     (double)m_breakoutState);
      GlobalVariableSet(GvName("bo_direction"), (double)m_breakoutDirection);
      GlobalVariableSet(GvName("bo_level"),     m_breakoutLevel);
      GlobalVariableSet(GvName("bo_bartime"),   (double)m_breakoutBarTime);
     }

   void              LoadPersistedState(void)
     {
      if(!GlobalVariableCheck(GvName("bo_state")))
         return;

      int    state     = (int)GlobalVariableGet(GvName("bo_state"));
      int    direction = (int)GlobalVariableGet(GvName("bo_direction"));
      double level     = GlobalVariableGet(GvName("bo_level"));
      datetime barTime = (datetime)GlobalVariableGet(GvName("bo_bartime"));

      if(state != BREAKOUT_WAITING_RETEST || level <= 0.0 || barTime <= 0)
        {
         ClearBreakout();
         return;
        }

      m_breakoutState     = BREAKOUT_WAITING_RETEST;
      m_breakoutDirection = (ENUM_SIGNAL_DIRECTION)direction;
      m_breakoutLevel     = level;
      m_breakoutBarTime   = barTime;

      CLogger::Info(m_module,
                    StringFormat("Breakout state dipulihkan. Direction=%d Level=%.5f BarTime=%s",
                                 direction, level,
                                 TimeToString(barTime, TIME_DATE | TIME_MINUTES)));
     }
  };

#endif // TRADINGEA_CORE_EASTATE_MQH
//+------------------------------------------------------------------+
