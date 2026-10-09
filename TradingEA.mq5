//+------------------------------------------------------------------+
//| TradingEA.mq5                                                    |
//| Extensible Multi-Strategy Trading EA                             |
//|                                                                  |
//| Pipeline wajib untuk setiap entry (bagian 110):                  |
//|                                                                  |
//|   NEW M15 BAR -> MarketContext -> RegimeEngine -> StrategyEngine |
//|   -> TradeSignal -> Guardian -> RiskEngine -> Final Validation   |
//|   -> TradeExecutor -> CTrade -> Broker -> PositionManager        |
//|                                                                  |
//| Pemisahan tanggung jawab (bagian 111):                           |
//|   Strategy        : apa yang layak di-trade                      |
//|   Guardian        : apakah boleh trade                           |
//|   RiskEngine      : berapa besar boleh trade                     |
//|   TradeExecutor   : bagaimana order dikirim                      |
//|   PositionManager : bagaimana posisi berjalan dikelola           |
//+------------------------------------------------------------------+
#property copyright "Ifars"
#property version   "2.00"
#property strict
#property description "Multi-strategy EA: Range, Breakout Retest, Trend Pullback"

#include "Core/Types.mqh"
#include "Core/Config.mqh"
#include "Core/MarketContext.mqh"
#include "Core/TradeSignal.mqh"
#include "Core/EAState.mqh"

#include "Market/MarketData.mqh"
#include "Market/IndicatorManager.mqh"
#include "Market/RegimeEngine.mqh"
#include "Market/MarketStructure.mqh"

#include "Strategies/StrategyEngine.mqh"

#include "Risk/RiskEngine.mqh"
#include "Risk/Guardian.mqh"

#include "Trading/PortfolioManager.mqh"
#include "Trading/TradeExecutor.mqh"
#include "Trading/PositionManager.mqh"

#include "Utils/Logger.mqh"

//--- modul
CConfig            g_config;
CEAState           g_state;

CMarketData        g_marketData;
CIndicatorManager  g_indicators;
CRegimeEngine      g_regime;
CMarketStructure   g_structure;

CStrategyEngine    g_strategies;

CRiskEngine        g_risk;
CGuardian          g_guardian;

CPortfolioManager  g_portfolio;
CTradeExecutor     g_executor;
CPositionManager   g_positions;

//--- runtime
SMarketContext     g_context;
datetime           g_lastM15BarTime = 0;
bool               g_ready          = false;

const string       MODULE           = "Application";

//+------------------------------------------------------------------+
//| Apakah candle M15 baru sudah terbentuk                           |
//+------------------------------------------------------------------+
bool IsNewM15Bar(void)
  {
   datetime current = iTime(_Symbol, PERIOD_M15, 0);

   if(current == 0)
      return(false);

   if(current == g_lastM15BarTime)
      return(false);

   g_lastM15BarTime = current;
   return(true);
  }

//+------------------------------------------------------------------+
//| Bangun MarketContext untuk satu evaluation cycle.                |
//|                                                                  |
//| Mengembalikan false bila ada data yang tidak tersedia. EA tidak  |
//| memakai nilai default sebagai pengganti (bagian 14, 95).         |
//+------------------------------------------------------------------+
bool BuildMarketContext(void)
  {
   g_context.Reset();

   if(!g_marketData.Fill(g_context))
     {
      CLogger::Error(MODULE, "[DATA_ERROR] MarketData tidak lengkap");
      return(false);
     }

   if(!g_indicators.Fill(g_context))
     {
      CLogger::Error(MODULE, "[DATA_ERROR] Indicator tidak lengkap");
      return(false);
     }

   g_context.valid = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Proses satu candle M15 baru (bagian 88)                          |
//+------------------------------------------------------------------+
void ProcessNewM15Bar(void)
  {
   //--- 1. data
   if(!BuildMarketContext())
      return;

   //--- 2. analisa market
   if(!g_regime.Update(g_context))
      return;

   if(!g_structure.Update(g_context))
      return;

   if(!g_structure.UpdateRange(g_context))
      return;

   //--- 3. state machine strategy selalu maju, bahkan bila entry
   //       sedang tidak diizinkan
   g_strategies.UpdateStates(g_context);

   //--- 4. gate pertama
   if(!g_guardian.AllowNewEntry(g_context))
      return;

   //--- 5. cari kandidat signal
   STradeSignal signal;
   signal.Reset();

   if(!g_strategies.FindSignal(g_context, signal))
      return;

   //--- 6. gate kedua
   if(!g_guardian.ValidateSignal(signal, g_context))
      return;

   //--- 7. ukuran posisi
   if(!g_risk.Calculate(signal, g_context))
      return;

   if(!g_risk.Validate(signal, g_context))
      return;

   //--- 8. eksekusi
   ulong ticket = g_executor.Execute(signal, g_context);

   if(ticket == 0)
     {
      CLogger::Error(MODULE, "[EXECUTION_ERROR] Order tidak terkirim");
      return;
     }

   //--- 9. serahkan ke PositionManager
   ulong positionTicket = g_portfolio.GetPositionTicket(0);

   if(positionTicket != 0)
      g_positions.Register(positionTicket, signal);
   else
     {
      //--- posisi kadang baru terlihat satu tick kemudian. Rencana
      //    pengelolaan disimpan agar TP1 Range tidak hilang.
      g_positions.RegisterPending(signal);
     }
  }

//+------------------------------------------------------------------+
//| OnInit (bagian 86)                                               |
//+------------------------------------------------------------------+
int OnInit(void)
  {
   g_ready = false;

   //--- 1. konfigurasi
   string error = "";

   if(!g_config.Load(error))
     {
      Print("[Application][ERROR] Konfigurasi tidak valid: ", error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   CLogger::SetDebug(g_config.debugMode);
   CLogger::Info(MODULE, "Inisialisasi dimulai");

   //--- 2. symbol dan spesifikasi broker
   if(!g_marketData.Init(_Symbol))
     {
      CLogger::Error(MODULE, "Validasi symbol gagal");
      return(INIT_FAILED);
     }

   //--- 3. indicator handle
   if(!g_indicators.Init(_Symbol))
     {
      CLogger::Error(MODULE, "Pembuatan indicator handle gagal");
      return(INIT_FAILED);
     }

   //--- 4. modul analisa
   g_regime.Init(GetPointer(g_config));
   g_structure.Init(GetPointer(g_config));

   //--- 5. state
   g_state.Init(_Symbol, g_config.magicNumber);

   //--- 6. strategy
   g_strategies.Init(GetPointer(g_config), GetPointer(g_state));

   //--- 7. risk dan guardian
   g_portfolio.Init(_Symbol, g_config.magicNumber);
   g_risk.Init(GetPointer(g_config));
   g_guardian.Init(GetPointer(g_config), GetPointer(g_state), GetPointer(g_portfolio));

   //--- 8. eksekusi dan pengelolaan posisi
   g_executor.Init(GetPointer(g_config), _Symbol);
   g_positions.Init(GetPointer(g_config),
                    GetPointer(g_portfolio),
                    GetPointer(g_executor),
                    g_marketData.Spec());

   //--- 9. adopsi posisi yang sudah ada
   g_positions.AdoptExisting();

   //--- 10. rekonstruksi state strategy dari history.
   //        Dilakukan pada bar berikutnya melalui UpdateStates(),
   //        state hasil Global Variable dipakai sebagai titik awal.
   g_lastM15BarTime = iTime(_Symbol, PERIOD_M15, 0);

   g_ready = true;

   CLogger::Info(MODULE,
                 StringFormat("EA siap. Symbol=%s Magic=%I64d Risk=%.2f%% MaxPos=%d",
                              _Symbol, g_config.magicNumber,
                              g_config.riskPerTrade,
                              g_config.maxTotalOpenPositions));

   //--- EA tidak membuka posisi hanya karena OnInit
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_indicators.Release();
   CLogger::Info(MODULE, StringFormat("EA dihentikan. reason=%d", reason));
  }

//+------------------------------------------------------------------+
//| OnTick (bagian 87)                                               |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   if(!g_ready)
      return;

   //--- 1. state runtime: rollover harian dan peak equity
   g_state.UpdateRuntime();

   //--- 2. pengelolaan posisi berjalan setiap tick
   g_positions.Manage();

   //--- 3. strategy hanya dievaluasi pada candle M15 baru
   if(!IsNewM15Bar())
      return;

   ProcessNewM15Bar();
  }

//+------------------------------------------------------------------+
//| OnTradeTransaction                                               |
//| Dipakai hanya untuk logging hasil, bukan untuk mengambil         |
//| keputusan trading.                                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(trans.symbol != _Symbol)
      return;

   CLogger::Debug(MODULE,
                  StringFormat("Deal ditambahkan. deal=%I64u order=%I64u volume=%.4f price=%.5f",
                               trans.deal, trans.order, trans.volume, trans.price));
  }
//+------------------------------------------------------------------+
