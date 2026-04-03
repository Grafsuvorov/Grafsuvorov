# features/totals_features.py

import pandas as pd

from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.team_stats_form import build_team_stats_form
from features.team_potential import build_team_potential_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.calendar import build_calendar_features

TOTALS_FEATURE_BUILDERS = [
    build_elo_features,
    build_form_xg_features,
    build_team_stats_form,
    build_team_potential_features,
    build_h2h_features,
    build_h2h_recent_features,
    build_league_context_features,
    build_calendar_features,
]


def build_totals_feature_list(schedule, match_stats, mode="train"):
    sched = schedule.copy()
    if "date_utc" in sched.columns and pd.api.types.is_datetime64tz_dtype(sched["date_utc"]):
        sched["date_utc"] = sched["date_utc"].dt.tz_localize(None)

    feats = []
    for builder in TOTALS_FEATURE_BUILDERS:
        if builder is build_elo_features:
            feats.append(builder(sched, mode=mode))
        elif builder in (build_form_xg_features, build_team_stats_form):
            feats.append(builder(sched, match_stats, window=5))
        elif builder is build_team_potential_features:
            feats.append(builder(sched))
        elif builder in (build_h2h_features,):
            feats.append(builder(sched, mode=mode))
        elif builder in (build_h2h_recent_features,):
            feats.append(builder(sched, window=5))
        elif builder is build_league_context_features:
            feats.append(builder(sched, window=60))
        elif builder is build_calendar_features:
            feats.append(builder(sched))
        else:
            raise RuntimeError(f"Unknown totals feature builder: {builder}")
    return feats
