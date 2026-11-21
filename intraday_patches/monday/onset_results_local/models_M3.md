# M3 SECTOR NEXT 1-5 DAYS - walk-forward results (2026-11-21)

Rows: 23842 sector-days (21 NSE sector indices, 2022-02-09 to 2026-11-13), decided at the close. abs_h = sector higher after h sessions; rel_h = sector beats NIFTY over h sessions. PASS rule as M1. Rows of one day are linked (and 3/5-day windows overlap), so p-values are optimistic; the by-year results matter more.

FII sector flow: NSDL's free fortnightly FPI sector file - the local copy (intraday/data/fpisec.json) covers Nov 2024 onward only, so the '+fpi' variant has one unseen year (2026).

PASS also needs (trader rule 9) its UP calls and its DOWN calls each right more often than chance (the share of up / down outcomes); p is day-clustered (each day counts once).

| variant | target | n | model | unseen acc | base rate | Brier vs base | p (day) | years beaten | UP calls right / chance | DOWN calls right / chance | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| main | abs_1 | 23842 | gbt | 53.5% (n 19402) | 53.6% | 0.2492 vs 0.2490 | 0.7728 | 0/4 | 0.5359 (n 19344) / 0.5362 | 0.3793 (n 58) / 0.4638 | **no edge** |
| main | abs_3 | 23842 | gbt | 54.5% (n 19402) | 54.5% | 0.2493 vs 0.2491 | 1.0000 | 0/4 | 0.5454 (n 19402) / 0.5454 | None (n 0) / 0.4546 | **no edge** |
| main | abs_5 | 23842 | gbt | 55.1% (n 19402) | 55.1% | 0.2483 vs 0.2487 | 1.0000 | 0/4 | 0.5512 (n 19402) / 0.5512 | None (n 0) / 0.4488 | **no edge** |
| main | rel_1 | 23842 | gbt | 50.4% (n 19402) | 49.6% | 0.2503 vs 0.2503 | 0.0595 | 2/4 | 0.5105 (n 11134) / 0.5085 | 0.4942 (n 8268) / 0.4915 | **no edge** |
| main | rel_3 | 23842 | lr | 49.6% (n 19402) | 49.6% | 0.2508 vs 0.2503 | 0.3475 | 1/4 | 0.5055 (n 14468) / 0.5124 | 0.4674 (n 4934) / 0.4876 | **no edge** |
| main | rel_5 | 23842 | lr | 49.9% (n 19402) | 51.5% | 0.2509 vs 0.2501 | 0.9973 | 1/4 | 0.5087 (n 14895) / 0.5147 | 0.4655 (n 4507) / 0.4853 | **no edge** |
| fpi | abs_1 | 9024 | gbt | 51.5% (n 4085) | 51.4% | 0.2508 vs 0.2498 | 0.4607 | 1/1 | 0.5147 (n 3942) / 0.5138 | 0.5105 (n 143) / 0.4862 | **no edge** |
| fpi | abs_3 | 9024 | lr | 50.0% (n 4085) | 50.0% | 0.2571 vs 0.2502 | 1.0000 | 0/1 | 0.5001 (n 4085) / 0.5001 | None (n 0) / 0.4999 | **no edge** |
| fpi | abs_5 | 9024 | lr | 48.7% (n 4085) | 48.7% | 0.2637 vs 0.2512 | 1.0000 | 0/1 | 0.4874 (n 4085) / 0.4874 | None (n 0) / 0.5126 | **no edge** |
| fpi | rel_1 | 9024 | gbt | 49.7% (n 4085) | 48.5% | 0.2502 vs 0.2504 | 0.1330 | 1/1 | 0.5246 (n 995) / 0.5153 | 0.4877 (n 3090) / 0.4847 | **no edge** |
| fpi | rel_3 | 9024 | lr | 47.3% (n 4085) | 47.3% | 0.2502 vs 0.2511 | 0.5278 | 0/1 | 0.4947 (n 95) / 0.5271 | 0.4722 (n 3990) / 0.4729 | **no edge** |
| fpi | rel_5 | 9024 | gbt | 49.7% (n 4085) | 47.0% | 0.2503 vs 0.2509 | 0.0792 | 1/1 | 0.521 (n 2672) / 0.53 | 0.4529 (n 1413) / 0.47 | **no edge** |

## By unseen year (chosen model) + top inputs

**main abs_1** (gbt): 2023 n4920 55.6% vs 55.6% · 2024 n4980 55.5% vs 55.5% · 2025 n4987 51.8% vs 51.8% · 2026 n4515 51.0% vs 51.3%  
top inputs: nifty_ret5, vix_chg5, mkt_breadth, vix, nifty_rsi, dow

**main abs_3** (gbt): 2023 n4920 60.8% vs 60.8% · 2024 n4980 56.1% vs 56.1% · 2025 n4987 51.1% vs 51.1% · 2026 n4515 49.8% vs 49.8%  
top inputs: vix_chg5, vix, nifty_rsi, mkt_breadth, nifty_ret5, ret1

**main abs_5** (gbt): 2023 n4920 62.4% vs 62.4% · 2024 n4980 56.8% vs 56.8% · 2025 n4987 52.4% vs 52.4% · 2026 n4515 48.3% vs 48.3%  
top inputs: vix, nifty_rsi, nifty_ret5, vix_chg5, mkt_breadth, rs5

**main rel_1** (gbt): 2023 n4920 47.5% vs 47.5% · 2024 n4980 50.6% vs 50.6% · 2025 n4987 51.7% vs 49.0% · 2026 n4515 51.6% vs 51.4%  
top inputs: ret1, nifty_ret5, vix_chg5, mkt_breadth, vix, nifty_rsi

**main rel_3** (lr): 2023 n4920 46.7% vs 46.7% · 2024 n4980 51.1% vs 51.1% · 2025 n4987 48.5% vs 48.4% · 2026 n4515 52.4% vs 52.4%  
top inputs: ret20(+), rs5(-), ret5(+), rs20(-), nifty_rsi(-), nifty_ret5(-)

**main rel_5** (lr): 2023 n4920 47.7% vs 54.2% · 2024 n4980 50.4% vs 50.4% · 2025 n4987 49.1% vs 48.9% · 2026 n4515 52.5% vs 52.5%  
top inputs: ret20(+), nifty_rsi(-), rs20(-), breadth_chg5(+), breadth(-), ret5(-)

**fpi abs_1** (gbt): 2026 n4085 51.5% vs 51.4%  
top inputs: vix, mkt_breadth, nifty_ret5, nifty_rsi, vix_chg5, dow

**fpi abs_3** (lr): 2026 n4085 50.0% vs 50.0%  
top inputs: ret20(+), rs20(-), mkt_breadth(-), rs5(-), vix(+), ret5(+)

**fpi abs_5** (lr): 2026 n4085 48.7% vs 48.7%  
top inputs: rs20(-), mkt_breadth(-), dist20(+), ret20(+), vix(+), rsi14(-)

**fpi rel_1** (gbt): 2026 n4085 49.7% vs 48.5%  
top inputs: vix_chg5, mkt_breadth, ret1, vix, nifty_ret5, breadth_chg5

**fpi rel_3** (lr): 2026 n4085 47.3% vs 47.3%  
top inputs: nifty_rsi(-), ret20(+), rs20(-), mkt_breadth(+), breadth(+), rsi14(+)

**fpi rel_5** (gbt): 2026 n4085 49.7% vs 47.0%  
top inputs: vix, mkt_breadth, fpi_run, breadth_chg5, vix_chg5, fpi_rank

Breadth members per sector (F&O shares): AUTO 16, BANK 18, CAPITAL_MKT 58, CHEMICALS 7, COMMODITIES 19, CONSR_DURBL 10, CPSE 0, ENERGY 17, FIN_SERVICE 58, FMCG 14, HEALTHCARE 16, INFRA 33, IT 13, MEDIA 0, METAL 10, OIL_AND_GAS 9, PHARMA 16, PSE 0, PSU_BANK 7, PVT_BANK 18, REALTY 6
