"""
╔══════════════════════════════════════════════════════════════════════════╗
║  TRADE PERFORMANCE MONITOR v2.0                                          ║
║  For Global Eye v23.7.0 — Trillionaire Edition                          ║
║  Owner: <redacted> | Generated: March 29, 2026                        ║
║                                                                          ║
║  WHAT IT DOES:                                                           ║
║  1. Reads trade_history_cumulative.json + order_audit.json               ║
║  2. Every Sunday 18:00 IST → Weekly Telegram Report                     ║
║  3. Every 1st of month 18:00 IST → Monthly Deep Analysis                ║
║  4. Detects patterns: best strategy, worst day, SL analysis             ║
║  5. Generates concrete improvement suggestions                           ║
║                                                                          ║
║  INTEGRATION:                                                            ║
║  Called from main loop: self._perf_monitor.check_and_run(hr, mn, wd)    ║
║  Needs: data_dir path, send_telegram function reference                  ║
║  ZERO external API calls. ZERO new scans. Pure analysis.                ║
╚══════════════════════════════════════════════════════════════════════════╝
"""

import os
import json
import logging
from datetime import datetime, timedelta
from collections import defaultdict

try:
    import pytz
    IST = pytz.timezone("Asia/Kolkata")
except Exception:
    IST = None

logger = logging.getLogger("GlobalEye")


def _now():
    return datetime.now(IST) if IST else datetime.now()


class TradePerformanceMonitor:
    """
    Self-learning performance tracker.
    Analyses real trades and generates actionable improvement feedback.
    """

    def __init__(self, data_dir, send_telegram_fn=None):
        self.data_dir = data_dir
        self._send_telegram = send_telegram_fn
        self.trade_history_file = os.path.join(data_dir, "trade_history_cumulative.json")
        self.order_audit_file = os.path.join(data_dir, "order_audit.json")
        self.feedback_file = os.path.join(data_dir, "performance_feedback.json")
        self._last_weekly_date = ""
        self._last_monthly_date = ""

    # ═══════════════════════════════════════════════════════════════
    #  DATA LOADING
    # ═══════════════════════════════════════════════════════════════

    def _load_trades(self):
        """Load all completed trades from cumulative history."""
        try:
            if os.path.exists(self.trade_history_file):
                with open(self.trade_history_file) as f:
                    data = json.load(f)
                    return data if isinstance(data, list) else []
        except Exception as e:
            logger.error(f"PerfMonitor: Error loading trades: {e}")
        return []

    def _load_audit(self):
        """Load order audit log."""
        try:
            if os.path.exists(self.order_audit_file):
                with open(self.order_audit_file) as f:
                    data = json.load(f)
                    return data if isinstance(data, list) else []
        except Exception:
            pass
        return []

    def _filter_period(self, trades, days):
        """Filter trades to last N days."""
        cutoff = (_now() - timedelta(days=days)).strftime("%Y-%m-%d")
        return [t for t in trades
                if t.get("exit_time", t.get("entry_time", ""))[:10] >= cutoff]

    # ═══════════════════════════════════════════════════════════════
    #  CORE METRICS
    # ═══════════════════════════════════════════════════════════════

    def _compute_metrics(self, trades):
        """Compute comprehensive performance metrics."""
        if not trades:
            return None

        wins = [t for t in trades if t.get("pnl", 0) > 0]
        losses = [t for t in trades if t.get("pnl", 0) <= 0]

        total_profit = sum(t.get("pnl", 0) for t in wins)
        total_loss = abs(sum(t.get("pnl", 0) for t in losses))

        win_rate = (len(wins) / len(trades) * 100) if trades else 0
        avg_win = (total_profit / len(wins)) if wins else 0
        avg_loss = (total_loss / len(losses)) if losses else 0
        profit_factor = (total_profit / total_loss) if total_loss > 0 else float('inf')
        expectancy = ((win_rate/100 * avg_win) - ((100-win_rate)/100 * avg_loss))

        # Best and worst trades
        best = max(trades, key=lambda t: t.get("pnl", 0)) if trades else None
        worst = min(trades, key=lambda t: t.get("pnl", 0)) if trades else None

        # Net P&L
        net_pnl = sum(t.get("pnl", 0) for t in trades)

        return {
            "total_trades": len(trades),
            "wins": len(wins),
            "losses": len(losses),
            "win_rate": round(win_rate, 1),
            "total_profit": round(total_profit, 2),
            "total_loss": round(total_loss, 2),
            "net_pnl": round(net_pnl, 2),
            "avg_win": round(avg_win, 2),
            "avg_loss": round(avg_loss, 2),
            "profit_factor": round(profit_factor, 2),
            "expectancy": round(expectancy, 2),
            "best_trade": best,
            "worst_trade": worst,
        }

    # ═══════════════════════════════════════════════════════════════
    #  STRATEGY BREAKDOWN
    # ═══════════════════════════════════════════════════════════════

    def _strategy_breakdown(self, trades):
        """Break down performance by trading strategy."""
        by_strategy = defaultdict(list)
        for t in trades:
            strat = t.get("strategy", t.get("type", "unknown"))
            by_strategy[strat].append(t)

        results = {}
        for strat, strat_trades in by_strategy.items():
            metrics = self._compute_metrics(strat_trades)
            if metrics:
                results[strat] = metrics
        return results

    # ═══════════════════════════════════════════════════════════════
    #  SOURCE BREAKDOWN (TECHNICAL vs FILING vs EVENT)
    # ═══════════════════════════════════════════════════════════════

    def _source_breakdown(self, trades):
        """Break down performance by signal source."""
        by_source = defaultdict(list)
        for t in trades:
            source = t.get("source", "TECHNICAL")
            # Normalize source names
            if "filing" in source.lower():
                source = "FILING"
            elif "event" in source.lower() or "news" in source.lower():
                source = "NEWS/EVENT"
            elif "promoter" in source.lower():
                source = "PROMOTER"
            else:
                source = "TECHNICAL"
            by_source[source].append(t)

        results = {}
        for source, source_trades in by_source.items():
            metrics = self._compute_metrics(source_trades)
            if metrics:
                results[source] = metrics
        return results

    # ═══════════════════════════════════════════════════════════════
    #  DAY-OF-WEEK ANALYSIS
    # ═══════════════════════════════════════════════════════════════

    def _day_analysis(self, trades):
        """Find which day of week is most profitable."""
        by_day = defaultdict(list)
        day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        for t in trades:
            entry_time = t.get("entry_time", "")
            if entry_time:
                try:
                    dt = datetime.strptime(entry_time[:10], "%Y-%m-%d")
                    by_day[day_names[dt.weekday()]].append(t)
                except Exception:
                    pass

        results = {}
        for day, day_trades in by_day.items():
            pnl = sum(t.get("pnl", 0) for t in day_trades)
            wins = sum(1 for t in day_trades if t.get("pnl", 0) > 0)
            wr = (wins / len(day_trades) * 100) if day_trades else 0
            results[day] = {"trades": len(day_trades), "pnl": round(pnl, 2), "win_rate": round(wr, 1)}
        return results

    # ═══════════════════════════════════════════════════════════════
    #  HOLD DURATION ANALYSIS
    # ═══════════════════════════════════════════════════════════════

    def _hold_duration_analysis(self, trades):
        """Analyse if shorter or longer holds are more profitable."""
        short_hold = []   # < 1 day
        medium_hold = []  # 1-5 days
        long_hold = []    # > 5 days

        for t in trades:
            entry = t.get("entry_time", "")
            exit_t = t.get("exit_time", "")
            if entry and exit_t:
                try:
                    d1 = datetime.strptime(entry[:10], "%Y-%m-%d")
                    d2 = datetime.strptime(exit_t[:10], "%Y-%m-%d")
                    days = (d2 - d1).days
                    if days < 1:
                        short_hold.append(t)
                    elif days <= 5:
                        medium_hold.append(t)
                    else:
                        long_hold.append(t)
                except Exception:
                    pass

        return {
            "intraday (<1d)": self._compute_metrics(short_hold) if short_hold else None,
            "swing (1-5d)": self._compute_metrics(medium_hold) if medium_hold else None,
            "position (>5d)": self._compute_metrics(long_hold) if long_hold else None,
        }

    # ═══════════════════════════════════════════════════════════════
    #  SL ANALYSIS
    # ═══════════════════════════════════════════════════════════════

    def _sl_analysis(self, trades):
        """Analyse stop-loss hits — are SLs too tight or too loose?"""
        sl_hits = [t for t in trades if t.get("exit_reason", "").lower() in
                   ["sl_hit", "stop_loss", "gtt_triggered", "smart_sl"]]
        
        if not sl_hits:
            return {"sl_hit_count": 0, "insight": "No SL exits detected yet."}

        # SL hits within 30 minutes of entry
        quick_sl = 0
        for t in sl_hits:
            entry = t.get("entry_time", "")
            exit_t = t.get("exit_time", "")
            if entry and exit_t:
                try:
                    t1 = datetime.strptime(entry[:19], "%Y-%m-%dT%H:%M:%S")
                    t2 = datetime.strptime(exit_t[:19], "%Y-%m-%dT%H:%M:%S")
                    if (t2 - t1).total_seconds() < 1800:
                        quick_sl += 1
                except Exception:
                    pass

        avg_sl_loss = abs(sum(t.get("pnl", 0) for t in sl_hits)) / len(sl_hits) if sl_hits else 0
        quick_pct = (quick_sl / len(sl_hits) * 100) if sl_hits else 0

        insight = ""
        if quick_pct > 40:
            insight = "SL may be too tight — 40%+ exits within 30 min. Consider widening by 0.3-0.5x ATR."
        elif quick_pct < 10 and avg_sl_loss > 500:
            insight = "SL may be too loose — avg loss per SL exit is high. Consider tightening."
        else:
            insight = "SL placement looks reasonable."

        return {
            "sl_hit_count": len(sl_hits),
            "quick_sl_pct": round(quick_pct, 1),
            "avg_sl_loss": round(avg_sl_loss, 2),
            "insight": insight,
        }

    # ═══════════════════════════════════════════════════════════════
    #  GENERATE IMPROVEMENT SUGGESTIONS
    # ═══════════════════════════════════════════════════════════════

    def _generate_suggestions(self, metrics, strat_bd, source_bd, day_bd, sl_info):
        """Generate concrete, actionable improvement suggestions."""
        suggestions = []

        if not metrics:
            return ["Not enough trades to generate suggestions. Need at least 5 completed trades."]

        # Win rate feedback
        if metrics["win_rate"] >= 60:
            suggestions.append(f"Win rate {metrics['win_rate']}% is excellent. Focus on increasing position size on high-conviction signals.")
        elif metrics["win_rate"] >= 45:
            suggestions.append(f"Win rate {metrics['win_rate']}% is decent. Tighten entry criteria — raise MIN_CONFIDENCE from 45 to 50.")
        else:
            suggestions.append(f"Win rate {metrics['win_rate']}% needs improvement. Consider raising DVM threshold by 5 points and adding ADX > 25 gate.")

        # Profit factor
        if metrics["profit_factor"] < 1.0:
            suggestions.append(f"Profit factor {metrics['profit_factor']}x is below breakeven. Avg win Rs.{metrics['avg_win']} vs avg loss Rs.{metrics['avg_loss']}. Let winners run longer or cut losses faster.")
        elif metrics["profit_factor"] > 2.0:
            suggestions.append(f"Profit factor {metrics['profit_factor']}x is strong. System is healthy — maintain current parameters.")

        # Strategy-specific
        if strat_bd:
            best_strat = max(strat_bd.items(), key=lambda x: x[1].get("net_pnl", 0))
            worst_strat = min(strat_bd.items(), key=lambda x: x[1].get("net_pnl", 0))
            if best_strat[1]["net_pnl"] > 0:
                suggestions.append(f"Best strategy: {best_strat[0]} (P&L: Rs.{best_strat[1]['net_pnl']}, WR: {best_strat[1]['win_rate']}%). Allocate more capital here.")
            if worst_strat[1]["net_pnl"] < 0:
                suggestions.append(f"Worst strategy: {worst_strat[0]} (P&L: Rs.{worst_strat[1]['net_pnl']}, WR: {worst_strat[1]['win_rate']}%). Review entry criteria or reduce allocation.")

        # Source-specific
        if source_bd:
            for source, sm in source_bd.items():
                if sm["win_rate"] > 65 and sm["total_trades"] >= 3:
                    suggestions.append(f"{source} signals win {sm['win_rate']}% — high quality source. Prioritize these signals in batch ranking.")
                elif sm["win_rate"] < 35 and sm["total_trades"] >= 3:
                    suggestions.append(f"{source} signals win only {sm['win_rate']}% — consider adding extra validation step or raising 3AI gate for this source.")

        # Day-of-week
        if day_bd:
            best_day = max(day_bd.items(), key=lambda x: x[1]["pnl"])
            worst_day = min(day_bd.items(), key=lambda x: x[1]["pnl"])
            if best_day[1]["pnl"] > 0 and best_day[1]["trades"] >= 2:
                suggestions.append(f"Best trading day: {best_day[0]} (P&L: Rs.{best_day[1]['pnl']}, WR: {best_day[1]['win_rate']}%). Scan more aggressively on {best_day[0]}.")
            if worst_day[1]["pnl"] < 0 and worst_day[1]["trades"] >= 2:
                suggestions.append(f"Worst trading day: {worst_day[0]} (P&L: Rs.{worst_day[1]['pnl']}). Consider reducing position size or skipping low-conviction trades on {worst_day[0]}.")

        # SL
        if sl_info.get("insight"):
            suggestions.append(f"SL Analysis: {sl_info['insight']}")

        return suggestions if suggestions else ["Insufficient data for pattern detection. Keep trading — patterns emerge after 20+ trades."]

    # ═══════════════════════════════════════════════════════════════
    #  WEEKLY REPORT (Sunday 18:00)
    # ═══════════════════════════════════════════════════════════════

    def _weekly_report(self):
        """Generate and send weekly performance report via Telegram."""
        all_trades = self._load_trades()
        week_trades = self._filter_period(all_trades, 7)
        month_trades = self._filter_period(all_trades, 30)

        # Compute all analyses
        week_metrics = self._compute_metrics(week_trades)
        month_metrics = self._compute_metrics(month_trades)
        all_metrics = self._compute_metrics(all_trades)
        strat_bd = self._strategy_breakdown(week_trades)
        source_bd = self._source_breakdown(week_trades)
        day_bd = self._day_analysis(month_trades)  # Use month for day analysis (more data)
        sl_info = self._sl_analysis(month_trades)
        suggestions = self._generate_suggestions(month_metrics or all_metrics, strat_bd, source_bd, day_bd, sl_info)

        # Build Telegram message
        msg_parts = []
        msg_parts.append("📊 WEEKLY PERFORMANCE REPORT")
        msg_parts.append(f"Week ending {_now().strftime('%d %b %Y')}")
        msg_parts.append("═" * 30)

        if week_metrics and week_metrics["total_trades"] > 0:
            m = week_metrics
            pnl_emoji = "🟢" if m["net_pnl"] >= 0 else "🔴"
            msg_parts.append(f"\n📈 THIS WEEK:")
            msg_parts.append(f"  Trades: {m['total_trades']} ({m['wins']}W / {m['losses']}L)")
            msg_parts.append(f"  Win Rate: {m['win_rate']}%")
            msg_parts.append(f"  {pnl_emoji} Net P&L: Rs.{m['net_pnl']:,.2f}")
            msg_parts.append(f"  Profit Factor: {m['profit_factor']}x")
            msg_parts.append(f"  Avg Win: Rs.{m['avg_win']:,.2f} | Avg Loss: Rs.{m['avg_loss']:,.2f}")
            if m["best_trade"]:
                msg_parts.append(f"  🏆 Best: {m['best_trade'].get('symbol','?')} Rs.{m['best_trade'].get('pnl',0):,.2f}")
            if m["worst_trade"]:
                msg_parts.append(f"  💀 Worst: {m['worst_trade'].get('symbol','?')} Rs.{m['worst_trade'].get('pnl',0):,.2f}")
        else:
            msg_parts.append("\n📈 THIS WEEK: No completed trades.")

        # Month summary
        if month_metrics and month_metrics["total_trades"] > 0:
            mm = month_metrics
            msg_parts.append(f"\n📅 LAST 30 DAYS:")
            msg_parts.append(f"  Trades: {mm['total_trades']} | WR: {mm['win_rate']}% | P&L: Rs.{mm['net_pnl']:,.2f}")

        # All-time
        if all_metrics and all_metrics["total_trades"] > 0:
            am = all_metrics
            msg_parts.append(f"\n🏦 ALL TIME ({am['total_trades']} trades):")
            msg_parts.append(f"  WR: {am['win_rate']}% | Net: Rs.{am['net_pnl']:,.2f} | PF: {am['profit_factor']}x")

        # Strategy breakdown (this week)
        if strat_bd:
            msg_parts.append(f"\n📊 BY STRATEGY (this week):")
            for strat, sm in sorted(strat_bd.items(), key=lambda x: x[1]["net_pnl"], reverse=True):
                emoji = "🟢" if sm["net_pnl"] >= 0 else "🔴"
                msg_parts.append(f"  {emoji} {strat}: {sm['total_trades']}T, WR {sm['win_rate']}%, Rs.{sm['net_pnl']:,.2f}")

        # Source breakdown
        if source_bd:
            msg_parts.append(f"\n📡 BY SOURCE (this week):")
            for src, sm in sorted(source_bd.items(), key=lambda x: x[1]["net_pnl"], reverse=True):
                emoji = "🟢" if sm["net_pnl"] >= 0 else "🔴"
                msg_parts.append(f"  {emoji} {src}: {sm['total_trades']}T, WR {sm['win_rate']}%")

        # SL analysis
        if sl_info.get("sl_hit_count", 0) > 0:
            msg_parts.append(f"\n🛡️ SL ANALYSIS (30d):")
            msg_parts.append(f"  SL hits: {sl_info['sl_hit_count']} | Quick (<30m): {sl_info.get('quick_sl_pct',0)}%")
            msg_parts.append(f"  {sl_info['insight']}")

        # Suggestions
        msg_parts.append(f"\n💡 IMPROVEMENT SUGGESTIONS:")
        for i, sug in enumerate(suggestions[:5], 1):
            msg_parts.append(f"  {i}. {sug}")

        msg_parts.append(f"\n⏰ Next report: {(_now() + timedelta(days=7)).strftime('%d %b %Y')} 18:00 IST")

        full_msg = "\n".join(msg_parts)

        # Send via Telegram
        if self._send_telegram:
            try:
                self._send_telegram(full_msg)
                logger.info("PerfMonitor: Weekly report sent")
            except Exception as e:
                logger.error(f"PerfMonitor: Failed to send weekly report: {e}")

        # Save feedback
        self._save_feedback(suggestions, "weekly")

        return full_msg

    # ═══════════════════════════════════════════════════════════════
    #  MONTHLY DEEP ANALYSIS (1st of month 18:00)
    # ═══════════════════════════════════════════════════════════════

    def _monthly_report(self):
        """Generate monthly deep analysis report."""
        all_trades = self._load_trades()
        month_trades = self._filter_period(all_trades, 30)

        month_metrics = self._compute_metrics(month_trades)
        all_metrics = self._compute_metrics(all_trades)
        strat_bd = self._strategy_breakdown(month_trades)
        source_bd = self._source_breakdown(month_trades)
        day_bd = self._day_analysis(month_trades)
        hold_bd = self._hold_duration_analysis(month_trades)
        sl_info = self._sl_analysis(month_trades)
        suggestions = self._generate_suggestions(month_metrics, strat_bd, source_bd, day_bd, sl_info)

        msg_parts = []
        msg_parts.append("📊 MONTHLY DEEP ANALYSIS")
        msg_parts.append(f"Month ending {_now().strftime('%d %b %Y')}")
        msg_parts.append("═" * 30)

        if month_metrics and month_metrics["total_trades"] > 0:
            m = month_metrics
            msg_parts.append(f"\n📈 MONTH SUMMARY:")
            msg_parts.append(f"  Total Trades: {m['total_trades']}")
            msg_parts.append(f"  Win Rate: {m['win_rate']}% ({m['wins']}W / {m['losses']}L)")
            msg_parts.append(f"  Net P&L: Rs.{m['net_pnl']:,.2f}")
            msg_parts.append(f"  Profit Factor: {m['profit_factor']}x")
            msg_parts.append(f"  Expectancy/Trade: Rs.{m['expectancy']:,.2f}")

        # Hold duration analysis
        if hold_bd:
            msg_parts.append(f"\n⏱️ HOLD DURATION ANALYSIS:")
            for period, hm in hold_bd.items():
                if hm and hm["total_trades"] > 0:
                    emoji = "🟢" if hm["net_pnl"] >= 0 else "🔴"
                    msg_parts.append(f"  {emoji} {period}: {hm['total_trades']}T, WR {hm['win_rate']}%, Rs.{hm['net_pnl']:,.2f}")

        # Day of week
        if day_bd:
            msg_parts.append(f"\n📅 DAY-OF-WEEK PERFORMANCE:")
            for day in ["Mon", "Tue", "Wed", "Thu", "Fri"]:
                if day in day_bd:
                    d = day_bd[day]
                    emoji = "🟢" if d["pnl"] >= 0 else "🔴"
                    msg_parts.append(f"  {emoji} {day}: {d['trades']}T, WR {d['win_rate']}%, Rs.{d['pnl']:,.2f}")

        # All-time tracking
        if all_metrics and all_metrics["total_trades"] > 0:
            msg_parts.append(f"\n🏦 ALL-TIME SCORECARD:")
            msg_parts.append(f"  Total trades: {all_metrics['total_trades']}")
            msg_parts.append(f"  Overall WR: {all_metrics['win_rate']}%")
            msg_parts.append(f"  Lifetime P&L: Rs.{all_metrics['net_pnl']:,.2f}")
            msg_parts.append(f"  Profit Factor: {all_metrics['profit_factor']}x")

        # Suggestions
        msg_parts.append(f"\n💡 MONTHLY RECOMMENDATIONS:")
        for i, sug in enumerate(suggestions[:7], 1):
            msg_parts.append(f"  {i}. {sug}")

        full_msg = "\n".join(msg_parts)

        if self._send_telegram:
            try:
                self._send_telegram(full_msg)
                logger.info("PerfMonitor: Monthly report sent")
            except Exception as e:
                logger.error(f"PerfMonitor: Failed to send monthly report: {e}")

        self._save_feedback(suggestions, "monthly")
        return full_msg

    # ═══════════════════════════════════════════════════════════════
    #  SAVE FEEDBACK FOR BOT LEARNING
    # ═══════════════════════════════════════════════════════════════

    def _save_feedback(self, suggestions, report_type):
        """Save feedback to file for future reference."""
        try:
            feedback = {}
            if os.path.exists(self.feedback_file):
                with open(self.feedback_file) as f:
                    feedback = json.load(f)
            
            key = f"{report_type}_{_now().strftime('%Y%m%d')}"
            feedback[key] = {
                "timestamp": _now().isoformat(),
                "type": report_type,
                "suggestions": suggestions,
            }

            # Keep only last 12 reports
            keys = sorted(feedback.keys())
            if len(keys) > 12:
                for old_key in keys[:-12]:
                    del feedback[old_key]

            with open(self.feedback_file, 'w') as f:
                json.dump(feedback, f, indent=2)
        except Exception as e:
            logger.error(f"PerfMonitor: Error saving feedback: {e}")

    # ═══════════════════════════════════════════════════════════════
    #  SCHEDULER — Called from main loop
    # ═══════════════════════════════════════════════════════════════

    def check_and_run(self, hour, minute, weekday):
        """
        Called from main loop every cycle.
        Triggers weekly report on Sunday 18:00 and monthly on 1st at 18:00.
        
        Args:
            hour: Current hour (0-23)
            minute: Current minute (0-59)
            weekday: Day of week (0=Mon, 6=Sun)
        """
        today = _now().strftime("%Y-%m-%d")

        # Weekly report — Sunday at 18:00
        if weekday == 6 and hour == 18 and minute < 5 and self._last_weekly_date != today:
            self._last_weekly_date = today
            try:
                self._weekly_report()
            except Exception as e:
                logger.error(f"PerfMonitor weekly report failed: {e}")

        # Monthly report — 1st of month at 18:00
        day_of_month = _now().day
        if day_of_month == 1 and hour == 18 and minute < 5 and self._last_monthly_date != today:
            self._last_monthly_date = today
            try:
                self._monthly_report()
            except Exception as e:
                logger.error(f"PerfMonitor monthly report failed: {e}")


# ═══════════════════════════════════════════════════════════════
#  STANDALONE TEST
# ═══════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import sys
    
    # Test with sample data
    data_dir = sys.argv[1] if len(sys.argv) > 1 else "/home/globalbot/data"
    
    monitor = TradePerformanceMonitor(
        data_dir=data_dir,
        send_telegram_fn=lambda msg: print(msg)
    )
    
    print("=" * 60)
    print("TRADE PERFORMANCE MONITOR v2.0 — TEST RUN")
    print("=" * 60)
    
    # Try weekly report
    report = monitor._weekly_report()
    if not report:
        print("No trades found. Creating sample test...")
        # Create sample for testing
        sample = [
            {"symbol": "RELIANCE", "entry_time": "2026-03-24T10:30:00", "exit_time": "2026-03-25T14:00:00",
             "entry_price": 1200, "exit_price": 1230, "qty": 5, "pnl": 150, "strategy": "swing",
             "source": "TECHNICAL", "exit_reason": "target_1"},
            {"symbol": "TCS", "entry_time": "2026-03-25T09:30:00", "exit_time": "2026-03-26T15:00:00",
             "entry_price": 3800, "exit_price": 3750, "qty": 2, "pnl": -100, "strategy": "swing",
             "source": "FILING", "exit_reason": "sl_hit"},
        ]
        import json
        os.makedirs(data_dir, exist_ok=True)
        with open(os.path.join(data_dir, "trade_history_cumulative.json"), 'w') as f:
            json.dump(sample, f)
        report = monitor._weekly_report()
    
    print("\nDone!")
