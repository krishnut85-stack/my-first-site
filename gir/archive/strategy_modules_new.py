"""
GLOBAL EYE v23.7.0 — STRATEGY MODULES (SCAN ENRICHMENT ARCHITECTURE)
══════════════════════════════════════════════════════════════════════════════
7 Strategy Modules that ENRICH scan results — NOT generate separate trades.

Every trade goes through the same 12-step pipeline:
  1. Signal Detection (DVM>=72, MACD bullish, Vol>=1.5x)
  2. 3-Agent AI Voting (2/3 approve)
  3. Technical Recheck (7/8 factors)
  4. Confidence Check (>=42%)
  5. Market Regime Filter
  6. Confirmation Candle (green after red OR bounce +0.3%)
  7. Position Sizing (Kelly, min Rs.15K)
  8. Buy Order at confirmed LTP
  9. GTT Placement (SL 0.9%, Target +4%)
  10. Monitoring (trailing SL every 10 min)
  11. Partial Exit (50% at T1, SL to breakeven)
  12. Final Exit (remaining 50% at T2 or trailing SL)

Strategy modules INFLUENCE the pipeline by:
  - Adding flags to scan results (news_boost, fii_tailwind, etc.)
  - Adjusting DVM thresholds for specific stocks (+-5 pts)
  - Boosting rank_score in batch ranking (+5 to +15 pts)
  - Adjusting global position size multiplier

Strategy modules NEVER:
  - Generate trade signals directly
  - Bypass 3AI voting
  - Skip confirmation candle
  - Inject into _event_trade_queue or _swing_candidates
"""

import logging
import time
import threading
from datetime import datetime, timedelta

logger = logging.getLogger("GlobalEye")


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 1: NEWS-TO-SCAN ENRICHMENT
# ══════════════════════════════════════════════════════════════════════════════

class NewsToScanEnricher:
    HEADLINE_STOCK_MAP = {
        # ══════════════════════════════════════════════════════════════
        # NIFTY 50 (50 stocks — highest priority, most traded)
        # ══════════════════════════════════════════════════════════════
        "reliance industries": "RELIANCE", "reliance": "RELIANCE", "ril ": "RELIANCE", "mukesh ambani": "RELIANCE",
        "jio ": "RELIANCE", "jio financial": "JIOFIN", "jio finance": "JIOFIN",
        "tata consultancy": "TCS", "tcs ": "TCS",
        "hdfc bank": "HDFCBANK", "hdfcbank": "HDFCBANK",
        "infosys": "INFY", "infy ": "INFY",
        "icici bank": "ICICIBANK",
        "hindustan unilever": "HINDUNILVR", "hul ": "HINDUNILVR",
        "itc ": "ITC", "itc limited": "ITC",
        "state bank": "SBIN", "sbi ": "SBIN",
        "bharti airtel": "BHARTIARTL", "airtel": "BHARTIARTL",
        "kotak mahindra bank": "KOTAKBANK", "kotak bank": "KOTAKBANK", "kotak": "KOTAKBANK",
        "larsen & toubro": "LT", "larsen and toubro": "LT", "l&t ": "LT",
        "axis bank": "AXISBANK",
        "asian paints": "ASIANPAINT",
        "maruti suzuki": "MARUTI", "maruti": "MARUTI",
        "sun pharma": "SUNPHARMA", "sun pharmaceutical": "SUNPHARMA",
        "titan company": "TITAN", "titan ": "TITAN",
        "bajaj finance": "BAJFINANCE", "bajfinance": "BAJFINANCE",
        "wipro": "WIPRO",
        "nestle india": "NESTLEIND", "nestle": "NESTLEIND",
        "ultratech cement": "ULTRACEMCO", "ultratech": "ULTRACEMCO",
        "power grid": "POWERGRID", "powergrid": "POWERGRID",
        "ntpc ": "NTPC", "ntpc limited": "NTPC",
        "tech mahindra": "TECHM",
        "hcl tech": "HCLTECH", "hcltech": "HCLTECH", "hcl technologies": "HCLTECH",
        "jsw steel": "JSWSTEEL",
        "tata steel": "TATASTEEL",
        "grasim": "GRASIM", "grasim industries": "GRASIM",
        "cipla": "CIPLA",
        "dr reddy": "DRREDDY", "dr. reddy": "DRREDDY", "dr reddys": "DRREDDY",
        "divis lab": "DIVISLAB", "divi's lab": "DIVISLAB",
        "bajaj finserv": "BAJAJFINSV",
        "bpcl": "BPCL", "bharat petroleum": "BPCL",
        "coal india": "COALINDIA",
        "ongc": "ONGC", "oil and natural gas": "ONGC",
        "mahindra & mahindra": "M&M", "mahindra and mahindra": "M&M", "m&m ": "M&M",
        "adani enterprises": "ADANIENT", "adanient": "ADANIENT",
        "adani ports": "ADANIPORTS",
        "apollo hospitals": "APOLLOHOSP", "apollo hospital": "APOLLOHOSP",
        "tata consumer": "TATACONSUM",
        "britannia": "BRITANNIA",
        "hero motocorp": "HEROMOTOCO", "hero moto": "HEROMOTOCO",
        "eicher motors": "EICHERMOT", "eicher": "EICHERMOT",
        "hindalco": "HINDALCO",
        "indusind bank": "INDUSINDBK", "indusind": "INDUSINDBK",
        "bajaj auto": "BAJAJ-AUTO",
        "sbi life": "SBILIFE",
        "hdfc life": "HDFCLIFE",
        "tata motors": "TATAMOTORS",
    
        # ══════════════════════════════════════════════════════════════
        # NIFTY NEXT 50 (additional 50 stocks)
        # ══════════════════════════════════════════════════════════════
        "adani green": "ADANIGREEN", "adani green energy": "ADANIGREEN",
        "adani power": "ADANIPOWER",
        "adani total gas": "ATGL",
        "ambuja cement": "AMBUJACEM", "ambuja": "AMBUJACEM",
        "avenue supermarts": "DMART", "dmart": "DMART",
        "bank of baroda": "BANKBARODA",
        "bharat electronics": "BEL", "bel ": "BEL",
        "bosch": "BOSCH",
        "canara bank": "CANBK",
        "cholamandalam": "CHOLAFIN", "chola finance": "CHOLAFIN",
        "colgate": "COLPAL", "colgate palmolive": "COLPAL",
        "dabur": "DABUR", "dabur india": "DABUR",
        "dlf ": "DLF",
        "godrej consumer": "GODREJCP", "godrej": "GODREJCP",
        "godrej properties": "GODREJPROP",
        "havells": "HAVELLS",
        "hindustan aeronautics": "HAL", "hal ": "HAL",
        "icici prudential": "ICICIPRULI",
        "icici lombard": "ICICIGI",
        "indian oil": "IOC", "iocl": "IOC",
        "indigo": "INDIGO", "interglobe": "INDIGO", "interglobe aviation": "INDIGO",
        "info edge": "NAUKRI", "naukri": "NAUKRI",
        "lici": "LICI", "lic ": "LICI", "life insurance corporation": "LICI",
        "marico": "MARICO",
        "pidilite": "PIDILITIND", "pidilite industries": "PIDILITIND",
        "punjab national bank": "PNB", "pnb ": "PNB",
        "sbi card": "SBICARD",
        "shriram finance": "SHRIRAMFIN", "shriram": "SHRIRAMFIN",
        "siemens india": "SIEMENS", "siemens": "SIEMENS",
        "tata power": "TATAPOWER",
        "trent ": "TRENT", "trent limited": "TRENT",
        "vedanta": "VEDL", "vedl ": "VEDL",
        "zomato": "ZOMATO",
        "zydus life": "ZYDUSLIFE", "zydus": "ZYDUSLIFE",
    
        # ══════════════════════════════════════════════════════════════
        # BANKING & NBFC (40+ stocks)
        # ══════════════════════════════════════════════════════════════
        "federal bank": "FEDERALBNK",
        "idfc first": "IDFCFIRSTB", "idfc first bank": "IDFCFIRSTB",
        "bandhan bank": "BANDHANBNK",
        "rbl bank": "RBLBANK",
        "indian bank": "INDIANB",
        "union bank": "UNIONBANK",
        "bank of india": "BANKINDIA",
        "central bank": "CENTRALBK",
        "uco bank": "UCOBANK",
        "karur vysya": "KARURVYSYA",
        "city union bank": "CUB",
        "south indian bank": "SOUTHBANK",
        "dcb bank": "DCBBANK",
        "csb bank": "CSBBANK",
        "ujjivan small finance": "UJJIVANSFB",
        "equitas small finance": "EQUITASBNK",
        "au small finance": "AUBANK", "au bank": "AUBANK",
        "muthoot finance": "MUTHOOTFIN", "muthoot": "MUTHOOTFIN",
        "manappuram": "MANAPPURAM",
        "poonawalla fincorp": "POONAWALLA",
        "bajaj housing": "BAJAJHFL",
        "can fin homes": "CANFINHOME",
        "lic housing": "LICHSGFIN",
        "pnb housing": "PNBHOUSING",
        "hdfc amc": "HDFCAMC",
        "nippon life": "NAM-INDIA",
        "angel one": "ANGELONE",
        "360 one": "360ONE",
        "cams": "CAMS",
        "cdsl": "CDSL",
        "mcx ": "MCX",
        "bse ": "BSE",
    
        # ══════════════════════════════════════════════════════════════
        # IT & TECHNOLOGY (35+ stocks)
        # ══════════════════════════════════════════════════════════════
        "lt mindtree": "LTIM", "ltimindtree": "LTIM", "l&t mindtree": "LTIM",
        "persistent systems": "PERSISTENT", "persistent": "PERSISTENT",
        "coforge": "COFORGE",
        "mphasis": "MPHASIS",
        "tata elxsi": "TATAELXSI",
        "kpit tech": "KPITTECH", "kpit": "KPITTECH",
        "cyient": "CYIENT",
        "zensar": "ZENSARTECH",
        "birlasoft": "BSOFT",
        "mastek": "MASTEK",
        "sonata software": "SONATSOFTW",
        "happiest minds": "HAPPSTMNDS",
        "tata tech": "TATATECH", "tata technologies": "TATATECH",
        "firstsource": "FSL",
        "eclerx": "ECLERX",
        "oracle financial": "OFSS",
        "newgen software": "NEWGEN",
        "intellect design": "INTELLECT",
        "latent view": "LATENTVIEW",
        "route mobile": "ROUTE",
        "paytm": "PAYTM", "one97": "PAYTM",
        "nykaa": "NYKAA", "fsn e-commerce": "NYKAA",
        "policybazaar": "POLICYBZR", "pb fintech": "POLICYBZR",
        "cartrade": "CARTRADE",
        "mapmy india": "MAPMYINDIA",
        "easy trip": "EASEMYTRIP",
        "ixigo": "IXIGO",
    
        # ══════════════════════════════════════════════════════════════
        # PHARMA & HEALTHCARE (40+ stocks)
        # ══════════════════════════════════════════════════════════════
        "lupin": "LUPIN",
        "aurobindo pharma": "AUROPHARMA", "aurobindo": "AUROPHARMA",
        "torrent pharma": "TORNTPHARM", "torrent pharmaceutical": "TORNTPHARM",
        "alkem lab": "ALKEM", "alkem": "ALKEM",
        "biocon": "BIOCON",
        "mankind pharma": "MANKIND",
        "ipca lab": "IPCALAB", "ipca": "IPCALAB",
        "glenmark": "GLENMARK",
        "abbott india": "ABBOTINDIA", "abbott": "ABBOTINDIA",
        "pfizer india": "PFIZER", "pfizer": "PFIZER",
        "sanofi india": "SANOFI",
        "natco pharma": "NATCOPHARM", "natco": "NATCOPHARM",
        "laurus labs": "LAURUSLABS", "laurus": "LAURUSLABS",
        "granules india": "GRANULES",
        "aarti drugs": "AARTIDRUGS",
        "ajanta pharma": "AJANTPHARM",
        "eris lifesciences": "ERIS",
        "gland pharma": "GLAND",
        "medplus": "MEDPLUS",
        "metropolis healthcare": "METROPOLIS", "metropolis": "METROPOLIS",
        "dr lal path": "LALPATHLAB", "lal pathlabs": "LALPATHLAB",
        "thyrocare": "THYROCARE",
        "max healthcare": "MAXHEALTH", "max health": "MAXHEALTH",
        "fortis healthcare": "FORTIS", "fortis": "FORTIS",
        "narayana health": "NH",
        "global health": "MEDANTA", "medanta": "MEDANTA",
        "aster dm": "ASTERDM",
        "syngene": "SYNGENE",
        "divi's": "DIVISLAB",
        "piramal pharma": "PPLPHARMA",
    
        # ══════════════════════════════════════════════════════════════
        # AUTO & AUTO ANCILLARY (35+ stocks)
        # ══════════════════════════════════════════════════════════════
        "tvs motor": "TVSMOTOR",
        "ashok leyland": "ASHOKLEY",
        "escorts kubota": "ESCORTS",
        "force motors": "FORCEMOT",
        "tata motors dvr": "TATAMTRDVR",
        "motherson": "MOTHERSON", "samvardhana motherson": "MOTHERSON",
        "bharat forge": "BHARATFORG",
        "endurance tech": "ENDURANCE",
        "sundram fasteners": "SUNDRMFAST",
        "tube investments": "TIINDIA",
        "uno minda": "UNOMINDA",
        "mrf ": "MRF",
        "apollo tyres": "APOLLOTYRE",
        "ceat ": "CEAT",
        "balkrishna industries": "BALKRISIND", "bkt ": "BALKRISIND",
        "exide": "EXIDEIND",
        "amara raja": "AMARAJABAT",
        "sona blw": "SONACOMS", "sona comstar": "SONACOMS",
        "samkrg pistons": "SAMKRG",
        "craftsman auto": "CRAFTSMAN",
        "ola electric": "OLAELEC",
    
        # ══════════════════════════════════════════════════════════════
        # METALS & MINING (20+ stocks)
        # ══════════════════════════════════════════════════════════════
        "tata steel long": "TATASTLLP",
        "sail ": "SAIL", "steel authority": "SAIL",
        "nmdc ": "NMDC",
        "hindustan zinc": "HINDZINC",
        "national aluminium": "NATIONALUM", "nalco": "NATIONALUM",
        "hindustan copper": "HINDCOPPER",
        "ratnamani metals": "RATNAMANI",
        "jindal steel": "JINDALSTEL", "jspl": "JINDALSTEL",
        "jsw energy": "JSWENERGY",
        "welspun corp": "WELCORP",
        "apl apollo": "APLAPOLLO",
        "mishra dhatu": "MIDHANI",
    
        # ══════════════════════════════════════════════════════════════
        # OIL, GAS & ENERGY (25+ stocks)
        # ══════════════════════════════════════════════════════════════
        "oil india": "OIL",
        "gail ": "GAIL", "gail india": "GAIL",
        "petronet lng": "PETRONET",
        "indraprastha gas": "IGL",
        "mahanagar gas": "MGL",
        "gujarat gas": "GUJGASLTD",
        "gujarat state petronet": "GSPL",
        "hpcl": "HINDPETRO", "hindustan petroleum": "HINDPETRO",
        "ioc ": "IOC",
        "castrol": "CASTROLIND",
        "aegis logistics": "AEGISLOG",
        "adani total": "ATGL",
        "nhpc": "NHPC",
        "sjvn": "SJVN",
        "torrent power": "TORNTPOWER",
        "cesc ": "CESC",
        "tata power": "TATAPOWER",
        "adani energy solutions": "ADANIENSOL",
        "pfc ": "PFC", "power finance": "PFC",
        "rec ": "RECLTD", "rec limited": "RECLTD",
        "ireda": "IREDA", "indian renewable energy": "IREDA",
    
        # ══════════════════════════════════════════════════════════════
        # FMCG & CONSUMER (30+ stocks)
        # ══════════════════════════════════════════════════════════════
        "varun beverages": "VBL",
        "jubilant foodworks": "JUBLFOOD", "domino's india": "JUBLFOOD",
        "united spirits": "UNITDSPR",
        "united breweries": "UBL",
        "radico khaitan": "RADICO",
        "emami": "EMAMILTD",
        "godrej consumer products": "GODREJCP",
        "procter & gamble": "PGHH",
        "gillette india": "GILLETTE",
        "tata consumer products": "TATACONSUM",
        "bikaji foods": "BIKAJI",
        "devyani international": "DEVYANI",
        "sapphire foods": "SAPPHIRE",
        "westlife": "WESTLIFE", "westlife foodworld": "WESTLIFE",
        "metro brands": "METROBRAND",
        "bata india": "BATAINDIA", "bata ": "BATAINDIA",
        "relaxo footwears": "RELAXO",
        "campus activewear": "CAMPUS",
        "page industries": "PAGEIND",
        "arvind fashions": "ARVINDFASN",
        "raymond": "RAYMOND",
        "aditya birla fashion": "ABFRL",
        "shoppers stop": "SHOPERSTOP",
        "v-mart": "VMART",
        "go fashion": "GOCOLORS",
    
        # ══════════════════════════════════════════════════════════════
        # CAPITAL GOODS & ENGINEERING (35+ stocks)
        # ══════════════════════════════════════════════════════════════
        "abb india": "ABB",
        "bhel ": "BHEL", "bharat heavy electricals": "BHEL",
        "cummins india": "CUMMINSIND", "cummins": "CUMMINSIND",
        "thermax": "THERMAX",
        "honeywell": "HONAUT",
        "rites": "RITES",
        "ircon": "IRCON",
        "rail vikas": "RVNL", "rvnl": "RVNL",
        "irfc": "IRFC", "indian railway finance": "IRFC",
        "irctc": "IRCTC",
        "concor": "CONCOR", "container corporation": "CONCOR",
        "beml ": "BEML",
        "cochin shipyard": "COCHINSHIP",
        "garden reach": "GRSE",
        "mazagon dock": "MAZDOCK",
        "data patterns": "DATAPATTNS",
        "kaynes technology": "KAYNES",
        "dixon technologies": "DIXON", "dixon": "DIXON",
        "polycab": "POLYCAB",
        "finolex cables": "FINCABLES",
        "kei industries": "KEI",
        "cg power": "CGPOWER",
        "suzlon": "SUZLON",
        "inox wind": "INOXWIND",
        "va tech wabag": "WABAG",
        "kalpataru projects": "KPIL",
        "pnc infratech": "PNCINFRA",
        "knr construction": "KNRCON",
        "hg infra": "HGINFRA",
        "jupiter wagons": "JWL",
    
        # ══════════════════════════════════════════════════════════════
        # CEMENT & BUILDING MATERIALS (15+ stocks)
        # ══════════════════════════════════════════════════════════════
        "shree cement": "SHREECEM",
        "acc ": "ACC", "acc cement": "ACC",
        "dalmia bharat": "DALBHARAT",
        "ramco cements": "RAMCOCEM",
        "jk cement": "JKCEMENT",
        "birla corporation": "BIRLACORPN",
        "nuvoco vistas": "NUVOCO",
        "india cements": "INDIACEM",
        "jk lakshmi": "JKLAKSHMI",
        "star cement": "STARCEMENT",
        "orient cement": "ORIENTCEM",
        "heidelberg cement": "HEIDELBERG",
    
        # ══════════════════════════════════════════════════════════════
        # REAL ESTATE (15+ stocks)
        # ══════════════════════════════════════════════════════════════
        "oberoi realty": "OBEROIRLTY",
        "prestige estates": "PRESTIGE",
        "brigade enterprises": "BRIGADE",
        "sobha": "SOBHA",
        "lodha": "LODHA", "macrotech developers": "LODHA",
        "phoenix mills": "PHOENIXLTD",
        "sunteck realty": "SUNTECK",
        "mahindra lifespace": "MAHLIFE",
        "raymond realty": "RAYMOND",
        "signature global": "SIGNATUREG",
    
        # ══════════════════════════════════════════════════════════════
        # CHEMICALS & SPECIALITY (25+ stocks)
        # ══════════════════════════════════════════════════════════════
        "pidilite": "PIDILITIND",
        "srf ": "SRF",
        "aarti industries": "AARTIIND",
        "clean science": "CLEAN",
        "deepak nitrite": "DEEPAKNTR",
        "navin fluorine": "NAVINFLUOR",
        "pi industries": "PIIND",
        "upl ": "UPL",
        "bayer cropscience": "BAYERCROP",
        "rallis india": "RALLIS",
        "coromandel international": "COROMANDEL", "coromandel": "COROMANDEL",
        "chambal fertilizers": "CHAMBLFERT",
        "deepak fertilizers": "DEEPAKFERT",
        "gujarat fluorochemicals": "FLUOROCHEM",
        "solar industries": "SOLARINDS",
        "fine organic": "FINEORG",
        "galaxy surfactants": "GALAXYSURF",
        "vinati organics": "VINATIORGA",
        "alkyl amines": "ALKYLAMINE",
        "balaji amines": "BALAMINES",
        "tata chemicals": "TATACHEM",
    
        # ══════════════════════════════════════════════════════════════
        # INSURANCE & FINANCIAL SERVICES (15+ stocks)
        # ══════════════════════════════════════════════════════════════
        "general insurance": "GICRE",
        "new india assurance": "NIACL",
        "star health": "STARHEALTH",
        "max financial": "MFSL",
        "aditya birla capital": "ABCAPITAL",
        "bajaj holdings": "BAJAJHLDNG",
        "iifl finance": "IIFL",
        "jm financial": "JMFINANCIL",
        "motilal oswal": "MOTILALOFS",
        "five star business": "FIVESTAR",
        "creditaccess grameen": "CREDITACC",
        "fusion micro": "FUSION",
    
        # ══════════════════════════════════════════════════════════════
        # TELECOM & MEDIA (10+ stocks)
        # ══════════════════════════════════════════════════════════════
        "vodafone idea": "IDEA", "vi ": "IDEA",
        "tata communications": "TATACOMM",
        "indus towers": "INDUSTOWER",
        "sterlite tech": "STLTECH",
        "tejas networks": "TEJASNET",
        "zen technologies": "ZENTEC",
        "pvr inox": "PVRINOX",
        "zee entertainment": "ZEEL",
        "tv18 broadcast": "TV18BRDCST",
        "network18": "NETWORK18",
        "sun tv": "SUNTV",
        "saregama": "SAREGAMA",
        "tips industries": "TIPSINDLTD",
    
        # ══════════════════════════════════════════════════════════════
        # TEXTILES & MISC (15+ stocks)
        # ══════════════════════════════════════════════════════════════
        "bls international": "BLS",
        "happiest minds": "HAPPSTMNDS",
        "tata elxsi": "TATAELXSI",
        "grindwell norton": "GRINDWELL",
        "3m india": "3MINDIA",
        "whirlpool india": "WHIRLPOOL",
        "crompton greaves": "CROMPTON",
        "voltas": "VOLTAS",
        "blue star": "BLUESTARCO",
        "amber enterprises": "AMBER",
        "maharashtra scooters": "MAHSCOOTER",
        "balkrishna": "BALKRISIND",
        "supreme industries": "SUPREMEIND",
        "astral ": "ASTRAL",
        "prince pipes": "PRINCEPIPE",
        "finolex industries": "FINPIPE",
    
        # ══════════════════════════════════════════════════════════════
        # DEFENCE & AEROSPACE (10+ stocks)
        # ══════════════════════════════════════════════════════════════
        "bharat dynamics": "BDL",
        "paras defence": "PARAS",
        "ideaforge": "IDEAFORGE",
        "astra microwave": "ASTRAMICRO",
        "solar industries": "SOLARINDS",
        "premier explosives": "PREMEXPLN",
        "mishra dhatu": "MIDHANI",
        "bharat electronics": "BEL",
        "hindustan aeronautics": "HAL",
        "cochin shipyard": "COCHINSHIP",
        "garden reach shipbuilders": "GRSE",
        "mazagon dock": "MAZDOCK",
    
        # ══════════════════════════════════════════════════════════════
        # LOGISTICS & TRANSPORT (10+ stocks)
        # ══════════════════════════════════════════════════════════════
        "delhivery": "DELHIVERY",
        "blue dart": "BLUEDART",
        "transport corporation": "TCI",
        "allcargo logistics": "ALLCARGO",
        "gateway distriparks": "GDL",
        "mahindra logistics": "MAHLOG",
        "vtl ": "VTRANSPRESS",
    
        # ══════════════════════════════════════════════════════════════
        # ADANI GROUP (all listed entities)
        # ══════════════════════════════════════════════════════════════
        "adani wilmar": "AWL",
        "adani transmission": "ADANIENSOL",
        "ambuja cements adani": "AMBUJACEM",
        "acc adani": "ACC",
        "ndtv adani": "NDTV",
        "adani": "ADANIENT",  # fallback — catches general "adani" news
    
        # ══════════════════════════════════════════════════════════════
        # TATA GROUP (all major entities)
        # ══════════════════════════════════════════════════════════════
        "tata steel": "TATASTEEL",
        "tata motors": "TATAMOTORS",
        "tata power": "TATAPOWER",
        "tata chemicals": "TATACHEM",
        "tata consumer": "TATACONSUM",
        "tata communications": "TATACOMM",
        "tata elxsi": "TATAELXSI",
        "tata technologies": "TATATECH",
        "indian hotels": "INDHOTEL", "taj hotels": "INDHOTEL",
        "trent ": "TRENT", "westside": "TRENT", "zudio": "TRENT",
        "voltas": "VOLTAS",
        "tata investment": "TATAINVEST",
        "nelco": "NELCO",
        "tata teleservices": "TATACOMM",
    
        # ══════════════════════════════════════════════════════════════
        # RECENT IPO / NEW LISTINGS (20+ stocks)
        # ══════════════════════════════════════════════════════════════
        "swiggy": "SWIGGY",
        "hyundai india": "HYUNDAI", "hyundai motor india": "HYUNDAI",
        "afcons infrastructure": "AFCONS",
        "ntpc green": "NTPCGREEN",
        "sagility india": "SAGILITY",
        "waaree energies": "WAAREEENER",
        "bajaj housing finance": "BAJAJHFL",
        "ola electric": "OLAELEC",
        "firstcry": "FIRSTCRY", "brainbees": "FIRSTCRY",
        "unicommerce": "UNICOMMERCE",
        "ixigo": "IXIGO",
        "tbo tek": "TBOTEK",
        "juniper hotels": "JUNIPER",
        "awfis": "AWFIS",
        "indegene": "INDGN",
    
        # ══════════════════════════════════════════════════════════════
        # ADDITIONAL HIGH-IMPACT MID/SMALL CAPS (30+ stocks)
        # ══════════════════════════════════════════════════════════════
        "irb infra": "IRB",
        "gmr airports": "GMRAIRPORT", "gmr infra": "GMRAIRPORT",
        "new delhi airport": "GMRAIRPORT",
        "hindustan zinc": "HINDZINC",
        "vedanta": "VEDL",
        "spicejet": "SPICEJET",
        "jet airways": "JETAIRWAYS",
        "yes bank": "YESBANK",
        "idbi bank": "IDBI",
        "indian energy exchange": "IEX",
        "multi commodity exchange": "MCX",
        "computer age management": "CAMS",
        "central depository": "CDSL",
        "mtar tech": "MTARTECH",
        "triveni turbine": "TRITURBINE",
        "carborundum universal": "CARBORUNIV",
        "schaeffler india": "SCHAEFFLER",
        "skf india": "SKFINDIA",
        "timken india": "TIMKEN",
        "elgi equipments": "ELGIEQUIP",
        "greenpanel": "GREENPANEL",
        "century plyboards": "CENTURYPLY",
        "somany ceramics": "SOMANYCERA",
        "kajaria ceramics": "KAJARIACER",
        "cera sanitaryware": "CERA",
        "sapphire foods": "SAPPHIRE",
        "restaurant brands asia": "RBA",
        "kalyan jewellers": "KALYANKJIL",
        "senco gold": "SENCO",
        "titan": "TITAN",
        "pn gadgil": "PNGADGIL",
        "manba finance": "MANBA",
        "hatsun agro": "HATSUN",
        "heritage foods": "HERITGFOOD",
        "ccl products": "CCL",
    }
    BULLISH_KW = {
        "profit growth": 15, "revenue growth": 12, "order win": 15,
        "contract win": 15, "fda approval": 15, "buyback": 12,
        "bulk deal": 10, "block deal": 10, "promoter buying": 15,
        "record profit": 15, "upgrade": 10, "target raised": 10,
        "beat estimate": 12, "expansion": 8, "margin expansion": 10,
        "debt free": 10, "strong result": 10,
    }
    _processed = set()
    _stock_flags = {}
    _lock = threading.Lock()

    @classmethod
    def reset_daily(cls):
        with cls._lock:
            cls._processed.clear(); cls._stock_flags.clear()

    @classmethod
    def process_alerts(cls, news_alerts):
        with cls._lock:
            cls._stock_flags.clear()
        for alert in news_alerts:
            _h = hash(alert.get("title", "")[:80])
            with cls._lock:
                if _h in cls._processed: continue
                cls._processed.add(_h)
            text = f"{alert.get('title','')} {alert.get('summary','')}".lower()
            stocks = [sym for pat, sym in cls.HEADLINE_STOCK_MAP.items() if pat in text]
            if not stocks: continue
            best_boost, best_kw = 0, ""
            for kw, b in cls.BULLISH_KW.items():
                if kw in text and b > best_boost: best_boost, best_kw = b, kw
            if best_boost < 5: continue
            for sym in dict.fromkeys(stocks).keys():  # dedup preserving order
                with cls._lock:
                    if best_boost > cls._stock_flags.get(sym, {}).get("news_boost", 0):
                        cls._stock_flags[sym] = {"news_boost": best_boost, "news_source": best_kw}
        if cls._stock_flags:
            logger.info(f"NEWS ENRICHMENT: {len(cls._stock_flags)} stocks flagged")

    @classmethod
    def get_flags(cls, symbol):
        with cls._lock:
            return cls._stock_flags.get(symbol, {})


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 2: FII/DII FLOW TRACKER
# ══════════════════════════════════════════════════════════════════════════════

class FIIDIIFlowTracker:
    FII_FAVORITES = {
        "HDFCBANK", "ICICIBANK", "INFY", "TCS", "RELIANCE", "BHARTIARTL",
        "ITC", "BAJFINANCE", "KOTAKBANK", "AXISBANK", "SBIN", "LT",
        "HCLTECH", "WIPRO", "TECHM", "TITAN", "MARUTI", "SUNPHARMA",
        "ULTRACEMCO", "NESTLEIND",
    }
    _flow_history = []
    _lock = threading.Lock()

    @classmethod
    def reset_daily(cls):
        with cls._lock: cls._flow_history = cls._flow_history[-10:]

    @classmethod
    def record_flow(cls, fii_net_cr, dii_net_cr, date_str=None):
        if not date_str: date_str = datetime.now().strftime("%Y-%m-%d")
        with cls._lock:
            ex = [f for f in cls._flow_history if f["date"] == date_str]
            if ex: ex[0].update(fii_net=fii_net_cr, dii_net=dii_net_cr)
            else: cls._flow_history.append({"date": date_str, "fii_net": fii_net_cr, "dii_net": dii_net_cr})
            cls._flow_history = cls._flow_history[-15:]

    @classmethod
    def get_bias(cls):
        with cls._lock:
            if len(cls._flow_history) < 3: return "NEUTRAL", 1.0, False
            recent = cls._flow_history[-3:]
        fii = sum(f["fii_net"] for f in recent)
        dii = sum(f["dii_net"] for f in recent)
        if fii > 5000: return "FII_BULLISH", 1.1, True
        if fii < -5000 and dii > 3000: return "CONTRARIAN", 1.0, True
        if fii < -3000 and dii < -1000: return "BOTH_SELLING", 0.7, False
        if fii < -5000: return "FII_BEARISH", 0.8, False
        return "NEUTRAL", 1.0, False

    @classmethod
    def is_fii_favorite(cls, symbol): return symbol in cls.FII_FAVORITES

    @classmethod
    def summary(cls):
        b, m, _ = cls.get_bias(); return f"FII/DII: {b} Size={m:.0%}"


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 3: GLOBAL CUES PRE-MARKET
# ══════════════════════════════════════════════════════════════════════════════

class GlobalCuesPreMarket:
    SECTOR_STOCKS = {
        "IT": ["TCS","INFY","WIPRO","HCLTECH","TECHM","LTIM","MPHASIS","COFORGE","PERSISTENT"],
        "PHARMA": ["SUNPHARMA","DRREDDY","CIPLA","LUPIN","AUROPHARMA"],
        "DEFENSIVE": ["HINDUNILVR","NESTLEIND","BRITANNIA","ITC","DABUR","MARICO","COLPAL"],
        "METALS": ["TATASTEEL","JSWSTEEL","HINDALCO","VEDL","SAIL","NMDC"],
        "AUTO": ["TATAMOTORS","MARUTI","M&M","BAJAJ-AUTO"],
    }
    _dvm_adj = {}; _bias = "NEUTRAL"; _size = 1.0; _date = ""

    @classmethod
    def reset_daily(cls):
        cls._dvm_adj = {}; cls._bias = "NEUTRAL"; cls._size = 1.0; cls._date = ""

    @classmethod
    def compute_bias(cls, macro_data):
        today = datetime.now().strftime("%Y-%m-%d")
        if cls._date == today: return
        adj = {}; bias = "NEUTRAL"; size = 1.0
        sp = 0
        for k in ["sp500","^GSPC","SPY"]:
            d = macro_data.get(k, {})
            if isinstance(d, dict): sp = d.get("pct", 0); break
        usvix = 0
        d = macro_data.get("usvix", {})
        if isinstance(d, dict): usvix = d.get("price", 0)

        if sp > 1.0:
            for s in cls.SECTOR_STOCKS["IT"] + cls.SECTOR_STOCKS["PHARMA"]:
                adj[s] = adj.get(s, 0) - 5
            bias = "BULLISH"; size = 1.1
        elif sp < -1.5:
            for s in cls.SECTOR_STOCKS["DEFENSIVE"]: adj[s] = adj.get(s, 0) - 3
            for s in cls.SECTOR_STOCKS["IT"] + cls.SECTOR_STOCKS["AUTO"]: adj[s] = adj.get(s, 0) + 5
            bias = "DEFENSIVE"; size = 0.85
        if usvix > 25:
            bias = "DEFENSIVE"; size = min(size, 0.7)
            for stocks in cls.SECTOR_STOCKS.values():
                for s in stocks: adj[s] = adj.get(s, 0) + 10
        cls._dvm_adj = adj; cls._bias = bias; cls._size = size; cls._date = today
        if adj: logger.info(f"GLOBAL CUES: {bias} Size={size:.0%} {len(adj)} adjusted")

    @classmethod
    def get_dvm_adjustment(cls, symbol): return cls._dvm_adj.get(symbol, 0)

    @classmethod
    def get_bias(cls): return cls._bias, cls._size

    @classmethod
    def summary(cls): return f"Global: {cls._bias} Size={cls._size:.0%}"


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 4: COMMODITY CORRELATION
# ══════════════════════════════════════════════════════════════════════════════

class CommodityCorrelation:
    CORR = {
        "gold_up":    {"bull": ["MUTHOOTFIN","MANAPPURAM","TITAN","SENCO"], "bear": []},
        "gold_down":  {"bull": [], "bear": ["MUTHOOTFIN","MANAPPURAM"]},
        "oil_up":     {"bull": ["ONGC","OIL"], "bear": ["INDIGO","ASIANPAINT","BPCL","IOC"]},
        "oil_down":   {"bull": ["BPCL","IOC","INDIGO","ASIANPAINT","MRF"], "bear": ["ONGC","OIL"]},
        "copper_up":  {"bull": ["HINDALCO","VEDL"], "bear": ["POLYCAB","HAVELLS"]},
        "copper_down":{"bull": ["POLYCAB","HAVELLS","KEI"], "bear": ["HINDALCO","VEDL"]},
    }
    _flags = {}

    @classmethod
    def reset_daily(cls): cls._flags = {}

    @classmethod
    def analyze(cls, macro_data):
        cls._flags = {}
        for comm, (key, up_t, dn_t) in [("gold","gold",1.0,-1.5),("crude","crude",2.0,-2.0),("copper","copper",2.0,-2.0)]:
            pct = 0
            for k in [key, f"{key.upper()}=F"]:
                d = macro_data.get(k, {})
                if isinstance(d, dict) and "pct" in d: pct = d["pct"]; break
            if pct == 0: continue
            tag = f"{comm}_up" if pct >= up_t else (f"{comm}_down" if pct <= dn_t else None)
            if not tag or tag not in cls.CORR: continue
            for s in cls.CORR[tag]["bull"]: cls._flags[s] = {"tailwind": True, "headwind": False, "comm": comm}
            for s in cls.CORR[tag]["bear"]: cls._flags[s] = {"tailwind": False, "headwind": True, "comm": comm}
        if cls._flags: logger.info(f"COMMODITY: {len(cls._flags)} stocks flagged")

    @classmethod
    def get_flags(cls, symbol): return cls._flags.get(symbol, {})


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 5: VOLUME BREAKOUT DETECTOR
# ══════════════════════════════════════════════════════════════════════════════

class VolumeBreakoutDetector:
    _daily = set()

    @classmethod
    def reset_daily(cls): cls._daily.clear()

    @classmethod
    def check(cls, r):
        sym = r.get("symbol", ""); vol = r.get("vol_surge", 1)
        dvm = r.get("dvm_score", 0); price = r.get("price", 0)
        high = r.get("high", 0); atr = r.get("atr", 0); low = r.get("low", 0)
        if vol < 2.5 or dvm < 65 or price < 20: return 0
        if high > 0 and (high - price) / high * 100 > 1.5: return 0
        day_range = high - low if high > 0 and low > 0 else 0
        if atr > 0 and day_range < 1.5 * atr: return 0
        if "Bearish" in r.get("trend", ""): return 0
        if sym in cls._daily: return 0
        cls._daily.add(sym)
        w52 = r.get("week_52_high", 0); is_52w = w52 > 0 and price >= w52 * 0.98
        boost = 10 + (5 if is_52w else 0)
        logger.info(f"VOL BREAKOUT [{sym}]: {vol:.1f}x DVM={dvm:.0f}{' 52W' if is_52w else ''}")
        return boost


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 6: GEOPOLITICAL PLAYBOOK
# ══════════════════════════════════════════════════════════════════════════════

class GeopoliticalPlaybook:
    EVENTS = {
        "india_pak_deescalation": {
            "triggers": ["india pakistan peace","ceasefire","cross border trade","kartarpur",
                         "visa agreement","de-escalation","bilateral talks india pakistan"],
            "bull": ["BLS","TCIEXPRESS","IRCTC","EASEMYTRIP","ULTRACEMCO","AMBUJA","ADANIPORTS"],
            "bear": ["HAL","BEL"],
        },
        "india_pak_escalation": {
            "triggers": ["india pakistan tension","loc firing","surgical strike","airstrike",
                         "border clash","terror attack india"],
            "bull": ["HAL","BEL","BHARATFORGE","BDL","MAZAGONDOCK"], "bear": [],
        },
        "india_china_tension": {
            "triggers": ["india china border","lac standoff","china app ban","ladakh standoff"],
            "bull": ["HAL","BEL","DIXON","AMBER","KAYNES"], "bear": [],
        },
        "mideast_tension": {
            "triggers": ["iran attack","red sea attack","strait of hormuz","middle east war","houthi"],
            "bull": ["ONGC","OIL","MUTHOOTFIN","TITAN"], "bear": ["INDIGO","BPCL","ASIANPAINT"],
        },
        "mideast_deescalation": {
            "triggers": ["ceasefire middle east","iran deal","red sea safe"],
            "bull": ["INDIGO","BPCL","ASIANPAINT"], "bear": ["ONGC"],
        },
        "global_recession": {
            "triggers": ["global recession","us recession","banking crisis"],
            "bull": ["HINDUNILVR","NESTLEIND","ITC","SUNPHARMA","CIPLA"],
            "bear": ["TATAMOTORS","MARUTI","DLF","BAJFINANCE"],
        },
    }
    _flags = {}; _triggered = set()

    @classmethod
    def reset_daily(cls): cls._flags = {}; cls._triggered.clear()

    @classmethod
    def scan_headlines(cls, news_alerts):
        cls._flags = {}
        headlines = [a.get("title","").lower() for a in news_alerts]
        headlines += [a.get("summary","").lower() for a in news_alerts if a.get("summary")]
        for ename, ev in cls.EVENTS.items():
            if ename in cls._triggered: continue
            for trig in ev["triggers"]:
                if any(trig in h for h in headlines):
                    cls._triggered.add(ename)
                    for s in ev["bull"]: cls._flags[s] = {"geo_boost": 10, "geo_event": ename}
                    for s in ev["bear"]: cls._flags[s] = {"geo_boost": -10, "geo_event": ename}
                    logger.info(f"GEOPOLITICAL: {ename} — {len(ev['bull'])} bull {len(ev['bear'])} bear")
                    break

    @classmethod
    def get_flags(cls, symbol): return cls._flags.get(symbol, {})


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 7: EARNINGS MOMENTUM ENRICHER
# ══════════════════════════════════════════════════════════════════════════════

class EarningsMomentumEnricher:
    BEAT_KW = ["profit growth","revenue growth","beat estimate","record profit",
               "record revenue","margin expansion","strong result","above consensus"]
    MISS_KW = ["profit decline","revenue decline","below estimate","weak result",
               "disappointing","margin contraction"]
    _flags = {}; _processed = set()

    @classmethod
    def reset_daily(cls): cls._flags = {}; cls._processed.clear()

    @classmethod
    def process_filings(cls, filings):
        cls._flags = {}
        for f in filings:
            sym = f.get("symbol",""); fid = f"{sym}:{f.get('ts','')[:10]}"
            if fid in cls._processed: continue
            cls._processed.add(fid)
            text = f"{f.get('subject','')} {' '.join(f.get('keywords',[]))}".lower()
            if not any(k in text for k in ["quarterly result","financial result","profit after tax","net profit","ebitda"]):
                continue
            if any(k in text for k in cls.BEAT_KW):
                cls._flags[sym] = {"earnings_beat": True, "earnings_boost": 12}
                logger.info(f"EARNINGS BEAT [{sym}]")
            elif any(k in text for k in cls.MISS_KW):
                cls._flags[sym] = {"earnings_miss": True, "earnings_boost": -10}

    @classmethod
    def get_flags(cls, symbol): return cls._flags.get(symbol, {})


# ══════════════════════════════════════════════════════════════════════════════
#  MASTER ORCHESTRATOR — SCAN ENRICHMENT
# ══════════════════════════════════════════════════════════════════════════════

class StrategyModulesOrchestrator:
    """
    Enriches scan results. Does NOT generate trades.
    
    Usage:
        modules.run_premarket(macro_data)          # 07:00
        size_mult = modules.enrich_scans(scans,..) # before for-loop
        # In batch ranking: r["strategy_rank_boost"] boosts rank_score
    """

    def __init__(self, send_telegram_fn=None):
        self._send_telegram = send_telegram_fn or (lambda *a, **kw: None)
        logger.info("Strategy Modules v23.7.0 (scan enrichment mode)")

    def reset_daily(self):
        NewsToScanEnricher.reset_daily()
        FIIDIIFlowTracker.reset_daily()
        GlobalCuesPreMarket.reset_daily()
        CommodityCorrelation.reset_daily()
        VolumeBreakoutDetector.reset_daily()
        GeopoliticalPlaybook.reset_daily()
        EarningsMomentumEnricher.reset_daily()
        logger.info("Strategy Modules: daily reset")

    def run_premarket(self, macro_data):
        try: GlobalCuesPreMarket.compute_bias(macro_data)
        except Exception as e: logger.debug(f"GlobalCues: {e}")
        try: CommodityCorrelation.analyze(macro_data)
        except Exception as e: logger.debug(f"Commodity: {e}")

    def record_fii_dii(self, fii_net_cr, dii_net_cr, date_str=None):
        FIIDIIFlowTracker.record_flow(fii_net_cr, dii_net_cr, date_str)

    def enrich_scans(self, scans, filings=None, news_alerts=None, macro_data=None):
        """Enrich scan results. Returns global_size_multiplier."""
        if news_alerts:
            try: NewsToScanEnricher.process_alerts(news_alerts)
            except: pass
            try: GeopoliticalPlaybook.scan_headlines(news_alerts)
            except: pass
        if filings:
            try: EarningsMomentumEnricher.process_filings(filings)
            except: pass
        if macro_data:
            try: CommodityCorrelation.analyze(macro_data)
            except: pass

        fii_bias, fii_mult, fii_tail = FIIDIIFlowTracker.get_bias()
        g_bias, g_mult = GlobalCuesPreMarket.get_bias()
        size_mult = round(fii_mult * g_mult, 4)

        enriched = 0
        for r in scans:
            sym = r.get("symbol", "")
            boost = 0; dvm_adj = 0; flags = []

            news = NewsToScanEnricher.get_flags(sym)
            if news:
                boost += news.get("news_boost", 0)
                flags.append(f"NEWS:{news.get('news_source','')}")

            if fii_tail and FIIDIIFlowTracker.is_fii_favorite(sym):
                boost += 8; flags.append(f"FII:{fii_bias}")

            gc = GlobalCuesPreMarket.get_dvm_adjustment(sym)
            if gc: dvm_adj += gc; flags.append(f"GLOBAL:{gc:+d}")

            comm = CommodityCorrelation.get_flags(sym)
            if comm.get("tailwind"): boost += 8; dvm_adj -= 3; flags.append(f"COMM_TAIL:{comm.get('comm','')}")
            elif comm.get("headwind"): boost -= 5; dvm_adj += 5; flags.append(f"COMM_HEAD:{comm.get('comm','')}")

            vb = VolumeBreakoutDetector.check(r)
            if vb > 0: boost += vb; flags.append(f"VOL_BRK:{vb}")

            geo = GeopoliticalPlaybook.get_flags(sym)
            if geo:
                boost += geo.get("geo_boost", 0)
                flags.append(f"GEO:{geo.get('geo_event','')}")

            earn = EarningsMomentumEnricher.get_flags(sym)
            if earn:
                boost += earn.get("earnings_boost", 0)
                flags.append("EARN_BEAT" if earn.get("earnings_beat") else "EARN_MISS")

            r["strategy_rank_boost"] = boost
            r["strategy_dvm_adj"] = dvm_adj
            r["strategy_flags"] = flags
            r["strategy_size_mult"] = size_mult
            if flags: enriched += 1

        if enriched:
            logger.info(f"ENRICHED: {enriched}/{len(scans)} | FII={fii_bias} Global={g_bias} Size={size_mult:.0%}")
        return size_mult

    def summary(self):
        return "\n  ".join([
            "Strategy Modules v23.7.0 (Scan Enrichment)",
            FIIDIIFlowTracker.summary(), GlobalCuesPreMarket.summary(),
            f"Geopolitical: {len(GeopoliticalPlaybook._triggered)} events",
        ])
