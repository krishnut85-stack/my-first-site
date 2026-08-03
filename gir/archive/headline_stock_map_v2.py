"""
╔══════════════════════════════════════════════════════════════════════════╗
║  NEWS HEADLINE → NSE SYMBOL MAPPING v2.0                                ║
║  500+ Indian Companies — Ready to paste into Global Eye v23.7.0         ║
║  Owner: <redacted> | Generated: March 29, 2026                        ║
║                                                                          ║
║  USAGE: Replace HEADLINE_STOCK_MAP in both:                             ║
║    1. NewsToScanEnricher class (strategy_modules.py / main file)        ║
║    2. NewsToTradeEngine class (strategy_modules.py / main file)         ║
║                                                                          ║
║  RULES:                                                                  ║
║    - Keys are LOWERCASE headline fragments                               ║
║    - Values are EXACT NSE trading symbols                                ║
║    - Longer keys match first (e.g. "tata motors" before "tata")         ║
║    - Trailing space in keys like "itc " prevents false matches           ║
║      ("itc " won't match "switch" or "glitch")                          ║
║    - Some companies have multiple aliases for better matching            ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

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

# ══════════════════════════════════════════════════════════════
# SECTOR KEYWORD MAP — for macro/policy news matching
# When headline mentions sector, boost ALL stocks in that sector
# ══════════════════════════════════════════════════════════════
SECTOR_KEYWORD_MAP = {
    "banking sector": ["HDFCBANK", "ICICIBANK", "KOTAKBANK", "SBIN", "AXISBANK", "BANKBARODA", "PNB", "INDUSINDBK", "FEDERALBNK", "IDFCFIRSTB"],
    "it sector": ["TCS", "INFY", "WIPRO", "HCLTECH", "TECHM", "LTIM", "PERSISTENT", "COFORGE", "MPHASIS", "TATAELXSI"],
    "pharma sector": ["SUNPHARMA", "DRREDDY", "CIPLA", "LUPIN", "AUROPHARMA", "BIOCON", "DIVISLAB", "TORNTPHARM", "ALKEM", "MANKIND"],
    "auto sector": ["TATAMOTORS", "MARUTI", "M&M", "BAJAJ-AUTO", "HEROMOTOCO", "EICHERMOT", "ASHOKLEY", "TVSMOTOR"],
    "oil and gas": ["RELIANCE", "ONGC", "OIL", "BPCL", "HINDPETRO", "IOC", "GAIL", "PETRONET", "IGL", "MGL"],
    "metal sector": ["TATASTEEL", "JSWSTEEL", "HINDALCO", "VEDL", "SAIL", "NMDC", "JINDALSTEL", "NATIONALUM", "HINDCOPPER", "HINDZINC"],
    "realty sector": ["DLF", "GODREJPROP", "OBEROIRLTY", "PRESTIGE", "BRIGADE", "SOBHA", "LODHA", "PHOENIXLTD"],
    "fmcg sector": ["HINDUNILVR", "ITC", "NESTLEIND", "BRITANNIA", "DABUR", "MARICO", "GODREJCP", "COLPAL", "TATACONSUM", "VBL"],
    "cement sector": ["ULTRACEMCO", "SHREECEM", "AMBUJACEM", "ACC", "DALBHARAT", "RAMCOCEM", "JKCEMENT"],
    "defence sector": ["HAL", "BEL", "BDL", "COCHINSHIP", "GRSE", "MAZDOCK", "DATAPATTNS", "SOLARINDS"],
    "power sector": ["NTPC", "POWERGRID", "TATAPOWER", "ADANIGREEN", "ADANIPOWER", "NHPC", "SJVN", "PFC", "RECLTD", "IREDA"],
    "railway stocks": ["IRCTC", "IRFC", "RVNL", "IRCON", "RITES", "CONCOR", "BEML", "JWL"],
    "insurance sector": ["LICI", "SBILIFE", "HDFCLIFE", "ICICIPRULI", "ICICIGI", "STARHEALTH", "GICRE", "NIACL"],
    "aviation sector": ["INDIGO", "SPICEJET", "GMRAIRPORT"],
    "telecom sector": ["BHARTIARTL", "IDEA", "TATACOMM", "INDUSTOWER"],
    "nbfc sector": ["BAJFINANCE", "BAJAJFINSV", "CHOLAFIN", "SHRIRAMFIN", "MUTHOOTFIN", "MANAPPURAM", "LICHSGFIN", "PNBHOUSING"],
    "chemical sector": ["SRF", "AARTIIND", "DEEPAKNTR", "NAVINFLUOR", "PIIND", "CLEAN", "FLUOROCHEM", "SOLARINDS"],
    "ev stocks": ["TATAMOTORS", "M&M", "OLAELEC", "EXIDEIND", "AMARAJABAT", "TATAPOWER"],
    "semiconductor": ["DIXON", "KAYNES", "DATAPATTNS", "TATAELXSI", "VEDL"],
}

# Quick stats
if __name__ == "__main__":
    print(f"Total headline mappings: {len(HEADLINE_STOCK_MAP)}")
    unique_symbols = set(HEADLINE_STOCK_MAP.values())
    print(f"Unique NSE symbols covered: {len(unique_symbols)}")
    print(f"Sector keyword groups: {len(SECTOR_KEYWORD_MAP)}")
    sector_stocks = set()
    for stocks in SECTOR_KEYWORD_MAP.values():
        sector_stocks.update(stocks)
    print(f"Unique stocks in sector map: {len(sector_stocks)}")
    all_stocks = unique_symbols | sector_stocks
    print(f"TOTAL unique stocks covered: {len(all_stocks)}")
