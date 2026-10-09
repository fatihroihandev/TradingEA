//+------------------------------------------------------------------+
//| Core/Types.mqh                                                   |
//| Enum dan struct dasar. Tidak boleh bergantung pada module lain.  |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_CORE_TYPES_MQH
#define TRADINGEA_CORE_TYPES_MQH

//--- Ukuran snapshot MarketContext.
//    Array berukuran tetap dipakai agar struct dapat disalin by value.
#define CTX_M15_BARS   180
#define CTX_H1_BARS     20

//+------------------------------------------------------------------+
//| Arah signal                                                      |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_DIRECTION
  {
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = 2
  };

//+------------------------------------------------------------------+
//| Regime H1                                                        |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
  {
   REGIME_SIDEWAYS = 0,
   REGIME_TRANSITION,
   REGIME_TREND_BULLISH,
   REGIME_TREND_BEARISH
  };

//+------------------------------------------------------------------+
//| Strategy                                                         |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
  {
   STRATEGY_NONE = 0,
   STRATEGY_RANGE,
   STRATEGY_BREAKOUT_RETEST,
   STRATEGY_TREND_PULLBACK
  };

//+------------------------------------------------------------------+
//| State EA                                                         |
//+------------------------------------------------------------------+
enum ENUM_EA_RUN_STATE
  {
   EA_RUNNING = 0,
   EA_DISABLED
  };

//+------------------------------------------------------------------+
//| State breakout                                                   |
//+------------------------------------------------------------------+
enum ENUM_BREAKOUT_STATE
  {
   BREAKOUT_IDLE = 0,
   BREAKOUT_WAITING_RETEST
  };

//+------------------------------------------------------------------+
//| Market structure M15                                             |
//+------------------------------------------------------------------+
enum ENUM_MARKET_STRUCTURE
  {
   STRUCTURE_NONE = 0,
   STRUCTURE_BULLISH,
   STRUCTURE_BEARISH
  };

//+------------------------------------------------------------------+
//| Level log                                                        |
//| Prefix EA_ dipakai agar tidak bentrok dengan ENUM_LOG_LEVELS     |
//| milik library standard (Trade.mqh).                              |
//+------------------------------------------------------------------+
enum ENUM_EA_LOG_LEVEL
  {
   EA_LOG_INFO = 0,
   EA_LOG_DEBUG,
   EA_LOG_WARNING,
   EA_LOG_ERROR,
   EA_LOG_TRADE
  };

//+------------------------------------------------------------------+
//| Kategori error (bagian 94)                                       |
//+------------------------------------------------------------------+
enum ENUM_EA_ERROR_TYPE
  {
   ERROR_NONE = 0,
   ERROR_DATA,
   ERROR_CALCULATION,
   ERROR_VALIDATION,
   ERROR_EXECUTION,
   ERROR_STATE
  };

//+------------------------------------------------------------------+
//| Swing point hasil confirmed pivot                                |
//+------------------------------------------------------------------+
struct SSwingPoint
  {
   bool              valid;
   double            price;
   int               shift;      // shift pada seri M15
   datetime          time;

   void Reset()
     {
      valid = false;
      price = 0.0;
      shift = -1;
      time  = 0;
     }
  };

//+------------------------------------------------------------------+
//| Data range M15 (dihitung dari shift 2..RangeLookback+1)          |
//+------------------------------------------------------------------+
struct SRangeData
  {
   bool              valid;
   double            high;
   double            low;
   double            size;
   double            mid;
   double            position;           // 0 = di low, 1 = di high
   int               upperInteractions;
   int               lowerInteractions;

   void Reset()
     {
      valid             = false;
      high              = 0.0;
      low               = 0.0;
      size              = 0.0;
      mid               = 0.0;
      position          = 0.0;
      upperInteractions = 0;
      lowerInteractions = 0;
     }
  };

//+------------------------------------------------------------------+
//| Spesifikasi symbol broker (bagian 71)                            |
//+------------------------------------------------------------------+
struct SSymbolSpec
  {
   bool              valid;
   string            symbol;
   int               digits;
   double            point;
   double            tickSize;
   double            tickValue;
   double            volumeMin;
   double            volumeMax;
   double            volumeStep;
   int               stopsLevel;
   int               freezeLevel;

   void Reset()
     {
      valid       = false;
      symbol      = "";
      digits      = 0;
      point       = 0.0;
      tickSize    = 0.0;
      tickValue   = 0.0;
      volumeMin   = 0.0;
      volumeMax   = 0.0;
      volumeStep  = 0.0;
      stopsLevel  = 0;
      freezeLevel = 0;
     }
  };

#endif // TRADINGEA_CORE_TYPES_MQH
//+------------------------------------------------------------------+
