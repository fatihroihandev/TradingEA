//+------------------------------------------------------------------+
//| Risk/RiskEngine.mqh                                              |
//| Satu-satunya module yang menentukan volume (bagian 59-62, 71-73).|
//|                                                                  |
//| Prinsip: actual risk TIDAK BOLEH melebihi configured risk.       |
//| Karena itu volume selalu dibulatkan KE BAWAH, dan bila hasilnya  |
//| di bawah volume minimum broker maka signal DITOLAK - bukan       |
//| dinaikkan ke minimum.                                            |
//+------------------------------------------------------------------+
#ifndef TRADINGEA_RISK_RISKENGINE_MQH
#define TRADINGEA_RISK_RISKENGINE_MQH

#include "../Core/Types.mqh"
#include "../Core/Config.mqh"
#include "../Core/MarketContext.mqh"
#include "../Core/TradeSignal.mqh"
#include "../Utils/Logger.mqh"
#include "../Utils/PriceUtils.mqh"
#include "../Utils/VolumeUtils.mqh"

//+------------------------------------------------------------------+
//| CRiskEngine                                                      |
//+------------------------------------------------------------------+
class CRiskEngine
  {
private:
   string            m_module;
   CConfig          *m_config;

public:
                     CRiskEngine(void) { m_module = "RiskEngine"; m_config = NULL; }

   void              Init(CConfig *config) { m_config = config; }

   //+---------------------------------------------------------------+
   //| Risiko uang untuk satu lot pada jarak harga tertentu.          |
   //|                                                                |
   //|   RiskPerLot = PriceDistance / TickSize * TickValue            |
   //|                                                                |
   //| Nilai broker dibaca apa adanya, tanpa asumsi 5 digit.          |
   //+---------------------------------------------------------------+
   double            RiskPerLot(const double priceDistance, const SSymbolSpec &spec) const
     {
      if(!spec.valid || spec.tickSize <= 0.0 || spec.tickValue <= 0.0)
         return(0.0);

      if(priceDistance <= 0.0)
         return(0.0);

      return((priceDistance / spec.tickSize) * spec.tickValue);
     }

   //+---------------------------------------------------------------+
   //| Hitung riskPercent, riskAmount, dan volume pada signal.        |
   //+---------------------------------------------------------------+
   bool              Calculate(STradeSignal &signal, const SMarketContext &ctx)
     {
      if(m_config == NULL)
        {
         CLogger::Error(m_module, "Config belum di-set");
         return(false);
        }

      //--- normalisasi harga sebelum apa pun dihitung (bagian 72)
      signal.entryPrice = CPriceUtils::Normalize(signal.entryPrice, ctx.spec);
      signal.stopLoss   = CPriceUtils::Normalize(signal.stopLoss,   ctx.spec);
      signal.takeProfit = CPriceUtils::Normalize(signal.takeProfit, ctx.spec);

      if(signal.hasPartialTarget)
         signal.takeProfit1 = CPriceUtils::Normalize(signal.takeProfit1, ctx.spec);

      double priceDistance = signal.RiskDistance();

      if(priceDistance <= 0.0)
        {
         CLogger::Reject(m_module, "RiskDistanceZeroAfterNormalization");
         return(false);
        }

      //--- risk berbasis EQUITY, bukan balance (bagian 62)
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      if(equity <= 0.0)
        {
         CLogger::Reject(m_module, "EquityNotPositive");
         return(false);
        }

      double riskPercent = MathMin(m_config.riskPerTrade, m_config.maxRiskPerTrade);
      double riskAmount  = equity * (riskPercent / 100.0);

      if(riskAmount <= 0.0)
        {
         CLogger::Reject(m_module, "RiskAmountZero");
         return(false);
        }

      double riskPerLot = RiskPerLot(priceDistance, ctx.spec);

      if(riskPerLot <= 0.0)
        {
         CLogger::Reject(m_module, "RiskPerLotZero");
         return(false);
        }

      double rawVolume = riskAmount / riskPerLot;

      //--- pembulatan KE BAWAH (bagian 60)
      double volume = CVolumeUtils::NormalizeDown(rawVolume, ctx.spec);

      signal.riskPercent = riskPercent;
      signal.riskAmount  = riskAmount;
      signal.volume      = volume;

      CLogger::Debug(m_module,
                     StringFormat("Equity=%.2f Risk%%=%.2f RiskAmount=%.2f Distance=%.5f RiskPerLot=%.2f RawVol=%.4f Vol=%.4f",
                                  equity, riskPercent, riskAmount,
                                  priceDistance, riskPerLot, rawVolume, volume));

      return(true);
     }

   //+---------------------------------------------------------------+
   //| Validasi akhir sebelum eksekusi (bagian 61, 73).               |
   //+---------------------------------------------------------------+
   bool              Validate(STradeSignal &signal, const SMarketContext &ctx)
     {
      string reason = "";

      //--- volume terhadap batas broker
      double volume = signal.volume;

      if(!CVolumeUtils::Validate(volume, ctx.spec, reason))
        {
         CLogger::Reject(m_module, reason);
         return(false);
        }

      signal.volume = volume;

      //--- actual risk setelah normalisasi harus tetap di bawah batas
      double riskPerLot = RiskPerLot(signal.RiskDistance(), ctx.spec);
      double actualRisk = riskPerLot * signal.volume;
      double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
      double maxRisk    = equity * (m_config.maxRiskPerTrade / 100.0);

      if(actualRisk > maxRisk)
        {
         CLogger::Reject(m_module,
                         StringFormat("ActualRiskExceedsMax actual=%.2f max=%.2f",
                                      actualRisk, maxRisk));
         return(false);
        }

      //--- jarak SL/TP terhadap stops level broker
      if(!CPriceUtils::StopsAreValid(signal.direction,
                                     signal.entryPrice,
                                     signal.stopLoss,
                                     signal.takeProfit,
                                     ctx.spec,
                                     reason))
        {
         CLogger::Reject(m_module, reason);
         return(false);
        }

      //--- target parsial, bila ada, harus searah dan belum tercapai
      if(signal.hasPartialTarget)
        {
         bool badPartial =
            (signal.direction == SIGNAL_BUY  && signal.takeProfit1 <= signal.entryPrice) ||
            (signal.direction == SIGNAL_SELL && signal.takeProfit1 >= signal.entryPrice);

         if(badPartial)
           {
            //--- TP1 tidak dapat dipakai, posisi dikelola dengan satu TP saja
            CLogger::Warning(m_module, "TakeProfit1 tidak valid, partial target dinonaktifkan");
            signal.hasPartialTarget = false;
            signal.takeProfit1      = 0.0;
           }
        }

      CLogger::Debug(m_module,
                     StringFormat("Validasi OK volume=%.4f actualRisk=%.2f maxRisk=%.2f",
                                  signal.volume, actualRisk, maxRisk));

      return(true);
     }
  };

#endif // TRADINGEA_RISK_RISKENGINE_MQH
//+------------------------------------------------------------------+
