import sys, datetime
sys.path.insert(0, "/home/globalbot/hunter")
import market_calendar as mc
ist = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=5, minutes=30))).date()
sys.exit(0 if mc.is_trading_day(ist) else 1)
