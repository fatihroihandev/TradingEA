# TradingEA v2.0 — Catatan Implementasi

Implementasi MQL5 dari technical specification "Extensible Multi-Strategy Trading EA".

## Pemasangan

Salin folder `TradingEA` ke `MQL5/Experts/` pada data folder terminal, lalu compile `TradingEA.mq5` di MetaEditor. Seluruh `.mqh` di-include dengan path relatif sehingga folder dapat dipindah tanpa mengubah kode.

```
MQL5/Experts/TradingEA/
├── TradingEA.mq5
├── Core/      Types, Config, MarketContext, TradeSignal, EAState
├── Market/    MarketData, IndicatorManager, RegimeEngine, MarketStructure
├── Strategies/ IStrategy, StrategyEngine, Range, Breakout, TrendPullback
├── Risk/      RiskEngine, Guardian
├── Trading/   PortfolioManager, TradeExecutor, PositionManager
└── Utils/     PriceUtils, VolumeUtils, TimeUtils, Logger
```

Pasang pada chart dengan timeframe apa pun — EA membaca H1 dan M15 secara eksplisit lewat `CopyRates`, tidak bergantung pada timeframe chart.

## Status Definition of Done (bagian 112)

| Item | Status | Letak |
|---|---|---|
| Indicator handle lifecycle | ✔ | `IndicatorManager::Init` / `Release`, dipanggil dari `OnInit` / `OnDeinit` |
| Semua signal memakai closed candle | ✔ | seluruh strategy hanya membaca shift ≥ 1 |
| Tidak ada lookahead | ✔ | shift 0 tidak pernah dipakai untuk keputusan |
| Pivot hanya confirmed pivot | ✔ | `MarketStructure::IsSwingHigh/Low`, mulai shift `1 + SwingRight` |
| Regime deterministic | ✔ | `RegimeEngine::Update` |
| Range deterministic | ✔ | `MarketStructure::UpdateRange`, shift 2..(1+Lookback) |
| Breakout / Retest / Expiry deterministic | ✔ | `BreakoutStrategy` |
| Pullback deterministic | ✔ | `TrendPullbackStrategy` |
| TradeSignal standard | ✔ | `Core/TradeSignal.mqh` |
| Strategy tidak melakukan order | ✔ | `CTrade` hanya di-include oleh `TradeExecutor` |
| RiskEngine menghitung volume | ✔ | `RiskEngine::Calculate` |
| Guardian melakukan entry validation | ✔ | `Guardian::AllowNewEntry` + `ValidateSignal` |
| TradeExecutor satu-satunya eksekutor | ✔ | `TradeExecutor` |
| PositionManager mengelola posisi | ✔ | `PositionManager::Manage` |
| Magic + Symbol filtering | ✔ | `PortfolioManager::IsOwned` |
| Broker specification validation | ✔ | `MarketData::Init` |
| Stop level validation | ✔ | `PriceUtils::StopsAreValid` |
| Volume normalization | ✔ | `VolumeUtils::NormalizeDown` (selalu ke bawah) |
| Price normalization | ✔ | `PriceUtils::Normalize` |
| Daily loss / Drawdown / Spread / Session | ✔ | `Guardian` |
| Partial close + Break-even Range | ✔ | `PositionManager::ManageRange` |
| State recovery | ✔ sebagian | lihat catatan di bawah |
| Error + debug logging | ✔ | `Logger` |
| Backtest reproducible | belum diverifikasi | perlu dijalankan di Strategy Tester |

## Keputusan yang perlu Anda ketahui

Beberapa titik dalam spesifikasi menyisakan ruang tafsir. Berikut yang saya pilih dan alasannya — periksa apakah sesuai maksud Anda.

**RangeData dihitung oleh `MarketStructure`, bukan oleh strategy.** Bagian 8 menempatkan RangeData di dalam MarketContext, tetapi bagian 9 tidak menyebut pemiliknya. Range dipakai oleh dua strategy (Range dan Breakout), jadi dihitung satu kali agar keduanya melihat angka identik.

**Penghitungan interaksi range.** Spesifikasi menyebut "satu candle hanya dihitung satu kali". Implementasi menghitung per sisi: satu candle dapat menambah `upperInteractions` dan `lowerInteractions` sekaligus bila rentangnya menyentuh kedua batas. Bila maksud Anda satu candle hanya boleh dihitung pada satu sisi saja, ini perlu diubah.

**Stop loss Trend Pullback.** Bagian 57 melarang fallback sembarang. Yang dipakai sebagai `PullbackSwingLow` adalah confirmed swing low terakhir yang terbentuk **setelah** swing high acuan (`latestSwingLow.shift < latestSwingHigh.shift`). Bila tidak ada, strategy mengembalikan NO SIGNAL.

**Expiry retest.** Dihitung sebagai jarak bar antara candle breakout dan signal candle (`breakoutShift - 1`). Setup dibuang bila melebihi `MaxRetestBars`.

**Candle breakout tidak boleh menjadi candle retest.** Flag `m_armedThisBar` mencegah setup yang baru dibuat langsung dievaluasi sebagai retest pada candle yang sama.

**State recovery breakout.** Global Variable menyimpan anchor (`direction`, `level`, `barTime`), lalu setiap M15 bar baru anchor itu dicocokkan dengan history (`BreakoutShift`). Bila candle breakout tidak ditemukan di history, state direset — jadi Global Variable tidak pernah dipercaya sendirian. Bagian 85 menyarankan rekonstruksi murni dari history; pendekatan di sini adalah gabungan, karena rekonstruksi murni memerlukan pengulangan deteksi breakout atas seluruh history yang mahal dan tidak selalu menghasilkan state yang sama.

**Posisi yang diadopsi setelah restart kehilangan TP1.** `PositionManager::AdoptExisting` tidak dapat merekonstruksi mid-range dari posisi yang sudah terbuka, jadi posisi hasil adopsi dikelola dengan TP tunggal yang sudah terpasang di broker. Ini dicatat sebagai WARNING di log.

**Risk per trade dibatasi dua lapis.** `RiskEngine::Calculate` memakai `min(RiskPerTrade, MaxRiskPerTrade)`, dan `Validate` menghitung ulang actual risk setelah normalisasi volume lalu menolak bila melewati batas.

## Yang belum dikerjakan

**Kode ini belum pernah dikompilasi maupun di-backtest.** Saya tidak memiliki MetaEditor di lingkungan ini. Harap compile dulu dan laporkan error yang muncul — kemungkinan besar yang muncul adalah masalah sintaks kecil, bukan logika.

Setelah compile bersih, urutan pengujian yang saya sarankan mengikuti bagian 113:

1. Jalankan dengan `DebugMode = true` pada Strategy Tester mode "Every tick based on real ticks", satu bulan data, dan baca log — pastikan regime, range, dan alasan NO_SIGNAL masuk akal sebelum melihat profit.
2. Uji `RiskEngine` secara terpisah dengan skenario bagian 100 (equity 10000, risk 0.5% → riskAmount 50) pada symbol dengan `VolumeStep` berbeda.
3. Uji tiap strategy satu per satu dengan menonaktifkan sementara routing strategy lain di `StrategyEngine::Select`.
4. Baru setelah itu lakukan optimasi dengan urutan bagian 104.

Fitur yang memang dikecualikan pada v2.0 (bagian 105) — trailing stop, M5, news filter, grid, averaging, multiple position, dynamic risk — tidak ada di kode ini. Bollinger M15 dibuat handle-nya sesuai bagian 13 tetapi tidak dipakai.

## Menambahkan strategy baru

1. Buat `Strategies/NamaStrategy.mqh` yang mewarisi `IStrategy`.
2. Implement `Type()` dan `Evaluate()`; `UpdateState()` hanya bila strategy punya state machine.
3. Include di `StrategyEngine.mqh`, tambahkan instance di `Init()` dan routing di `Select()`.

Core — `RiskEngine`, `Guardian`, `TradeExecutor`, `PositionManager` — tidak perlu disentuh.
