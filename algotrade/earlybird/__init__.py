"""Early Bird — option-flow scanner that flags F&O names before big moves.

Alert-only: it never places orders. It watches option chains for the
footprints that tend to precede large moves, sends Telegram alerts, and logs
every signal so its hit rate can be judged on evidence before any capital
follows it.
"""

from .detector import DetectorConfig, detect
from .scanner import EarlyBird

__all__ = ["DetectorConfig", "detect", "EarlyBird"]
