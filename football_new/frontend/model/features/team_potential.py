import numpy as np
import pandas as pd


def _num(df: pd.DataFrame, col: str) -> pd.Series:
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index, dtype=float)
    return pd.to_numeric(df[col], errors="coerce")


def _safe_div(num: pd.Series, den: pd.Series) -> pd.Series:
    den = pd.to_numeric(den, errors="coerce").replace(0, np.nan)
    return pd.to_numeric(num, errors="coerce") / den


def _first_available(df: pd.DataFrame, cols: list[str]) -> pd.Series:
    out = pd.Series(np.nan, index=df.index, dtype=float)
    for col in cols:
        if col in df.columns:
            out = out.fillna(_num(df, col))
    return out


def _mean_available(df: pd.DataFrame, cols: list[str]) -> pd.Series:
    present = [col for col in cols if col in df.columns]
    if not present:
        return pd.Series(np.nan, index=df.index, dtype=float)
    return pd.concat([_num(df, col) for col in present], axis=1).mean(axis=1)


def build_team_potential_features(schedule: pd.DataFrame) -> pd.DataFrame:
    """
    Pre-match team potential layer built from already lagged schedule features.

    Goals:
    - attack potential
    - defensive resistance / vulnerability
    - chance quality and territorial pressure
    - matchup edges (attack vs opponent defense)
    - likely match openness / control balance
    """

    df = schedule.copy()
    out = pd.DataFrame({"fixture_id": df["fixture_id"]})

    for side in ("home", "away"):
        opp = "away" if side == "home" else "home"

        xg_attack = _mean_available(
            df,
            [
                f"{side}_stat_expected_goals_ma_short",
                f"{side}_stat_expected_goals_ma_long",
                f"{side}_us_xg_all_5",
                f"{side}_us_npxg_all_5",
                f"{side}_avg_goals_for",
            ],
        )
        xg_defense = _mean_available(
            df,
            [
                f"{side}_us_xga_all_5",
                f"{side}_us_npxga_all_5",
                f"{side}_avg_goals_against",
            ],
        )
        box_pressure = _mean_available(
            df,
            [
                f"{side}_stat_shots_insidebox_ma_short",
                f"{side}_stat_shots_insidebox_ma_long",
                f"{side}_us_deep_all_5",
            ],
        )
        creation_pressure = _mean_available(
            df,
            [
                f"{side}_stat_shots_on_goal_ma_short",
                f"{side}_stat_shots_on_goal_ma_long",
                f"{side}_stat_dangerous_attacks_ma_short",
                f"{side}_stat_dangerous_attacks_ma_long",
            ],
        )
        control = _mean_available(
            df,
            [
                f"{side}_stat_possession_ma_short",
                f"{side}_stat_possession_ma_long",
                f"{side}_stat_passes_percentage_ma_long",
                f"{side}_stat_attacks_ma_long",
            ],
        )
        defense_pressure = _mean_available(
            df,
            [
                f"{side}_us_deep_allowed_all_5",
                f"{side}_us_xga_all_5",
                f"{side}_us_npxga_all_5",
                f"{side}_avg_goals_against",
            ],
        )

        shots = _mean_available(
            df,
            [
                f"{side}_stat_total_shots_ma_short",
                f"{side}_stat_total_shots_ma_long",
            ],
        )
        shots_ib = _mean_available(
            df,
            [
                f"{side}_stat_shots_insidebox_ma_short",
                f"{side}_stat_shots_insidebox_ma_long",
            ],
        )
        sog = _mean_available(
            df,
            [
                f"{side}_stat_shots_on_goal_ma_short",
                f"{side}_stat_shots_on_goal_ma_long",
            ],
        )
        deep = _first_available(df, [f"{side}_us_deep_all_5", f"{side}_us_deep_all_10"])
        xg_src = _first_available(df, [f"{side}_us_npxg_all_5", f"{side}_us_xg_all_5", f"{side}_stat_expected_goals_ma_long"])
        xga_src = _first_available(df, [f"{side}_us_npxga_all_5", f"{side}_us_xga_all_5", f"{side}_avg_goals_against"])
        deep_allowed = _first_available(df, [f"{side}_us_deep_allowed_all_5", f"{side}_us_deep_allowed_all_10"])

        box_share = _safe_div(shots_ib, shots)
        sog_share = _safe_div(sog, shots)
        xg_per_shot = _safe_div(xg_src, shots)
        xg_per_deep = _safe_div(xg_src, deep)
        xga_per_deep_allowed = _safe_div(xga_src, deep_allowed)

        if f"{side}_us_goal_minus_npxg_all_5" in df.columns:
            finish_edge = _num(df, f"{side}_us_goal_minus_npxg_all_5")
        else:
            finish_edge = _safe_div(_num(df, f"{side}_avg_goals_for"), xg_src) - 1.0

        if f"{side}_us_goal_against_minus_npxga_all_5" in df.columns:
            concede_edge = _num(df, f"{side}_us_goal_against_minus_npxga_all_5")
        else:
            concede_edge = _safe_div(_num(df, f"{side}_avg_goals_against"), xga_src) - 1.0

        trend_attack = _mean_available(
            df,
            [
                f"{side}_us_npxg_all_3",
                f"{side}_us_xg_all_3",
            ],
        ) - _mean_available(
            df,
            [
                f"{side}_us_npxg_all_10",
                f"{side}_us_xg_all_10",
            ],
        )
        trend_defense = _mean_available(
            df,
            [
                f"{side}_us_npxga_all_10",
                f"{side}_us_xga_all_10",
            ],
        ) - _mean_available(
            df,
            [
                f"{side}_us_npxga_all_3",
                f"{side}_us_xga_all_3",
            ],
        )

        out[f"tp_{side}_attack_xg"] = xg_attack
        out[f"tp_{side}_attack_pressure"] = creation_pressure
        out[f"tp_{side}_attack_box_pressure"] = box_pressure
        out[f"tp_{side}_attack_control"] = control
        out[f"tp_{side}_attack_box_share"] = box_share
        out[f"tp_{side}_attack_sog_share"] = sog_share
        out[f"tp_{side}_attack_xg_per_shot"] = xg_per_shot
        out[f"tp_{side}_attack_xg_per_deep"] = xg_per_deep
        out[f"tp_{side}_attack_finish_edge"] = finish_edge
        out[f"tp_{side}_attack_trend"] = trend_attack

        out[f"tp_{side}_defense_xga"] = xg_defense
        out[f"tp_{side}_defense_pressure"] = defense_pressure
        out[f"tp_{side}_defense_xga_per_deep_allowed"] = xga_per_deep_allowed
        out[f"tp_{side}_defense_concede_edge"] = concede_edge
        out[f"tp_{side}_defense_trend"] = trend_defense
        out[f"tp_{side}_defense_resistance"] = -xg_defense

        out[f"tp_{side}_balance_score"] = (
            pd.to_numeric(xg_attack, errors="coerce")
            - pd.to_numeric(xg_defense, errors="coerce")
        )
        out[f"tp_{side}_control_to_quality"] = pd.to_numeric(control, errors="coerce") * pd.to_numeric(xg_per_shot, errors="coerce")

        opp_defense = _mean_available(
            df,
            [
                f"{opp}_us_xga_all_5",
                f"{opp}_us_npxga_all_5",
                f"{opp}_avg_goals_against",
            ],
        )
        opp_deep_allowed = _first_available(df, [f"{opp}_us_deep_allowed_all_5", f"{opp}_us_deep_allowed_all_10"])
        opp_def_quality = _safe_div(opp_defense, opp_deep_allowed)

        out[f"tp_{side}_matchup_attack_vs_defense"] = pd.to_numeric(xg_attack, errors="coerce") - pd.to_numeric(opp_defense, errors="coerce")
        out[f"tp_{side}_matchup_pressure_vs_defense"] = pd.to_numeric(box_pressure, errors="coerce") - pd.to_numeric(opp_deep_allowed, errors="coerce")
        out[f"tp_{side}_matchup_quality_vs_defense"] = pd.to_numeric(xg_per_deep, errors="coerce") - pd.to_numeric(opp_def_quality, errors="coerce")
        out[f"tp_{side}_matchup_finish_vs_concede"] = pd.to_numeric(finish_edge, errors="coerce") - pd.to_numeric(
            _first_available(df, [f"{opp}_us_goal_against_minus_npxga_all_5"]), errors="coerce"
        )

    diff_pairs = {
        "tp_attack_xg_diff": ("tp_home_attack_xg", "tp_away_attack_xg"),
        "tp_attack_pressure_diff": ("tp_home_attack_pressure", "tp_away_attack_pressure"),
        "tp_attack_box_share_diff": ("tp_home_attack_box_share", "tp_away_attack_box_share"),
        "tp_attack_quality_diff": ("tp_home_attack_xg_per_shot", "tp_away_attack_xg_per_shot"),
        "tp_control_diff": ("tp_home_attack_control", "tp_away_attack_control"),
        "tp_finish_edge_diff": ("tp_home_attack_finish_edge", "tp_away_attack_finish_edge"),
        "tp_defense_xga_diff": ("tp_away_defense_xga", "tp_home_defense_xga"),
        "tp_defense_resistance_diff": ("tp_home_defense_resistance", "tp_away_defense_resistance"),
        "tp_defense_concede_edge_diff": ("tp_away_defense_concede_edge", "tp_home_defense_concede_edge"),
        "tp_balance_score_diff": ("tp_home_balance_score", "tp_away_balance_score"),
        "tp_matchup_attack_diff": ("tp_home_matchup_attack_vs_defense", "tp_away_matchup_attack_vs_defense"),
        "tp_matchup_pressure_diff": ("tp_home_matchup_pressure_vs_defense", "tp_away_matchup_pressure_vs_defense"),
        "tp_matchup_quality_diff": ("tp_home_matchup_quality_vs_defense", "tp_away_matchup_quality_vs_defense"),
        "tp_matchup_finish_diff": ("tp_home_matchup_finish_vs_concede", "tp_away_matchup_finish_vs_concede"),
        "tp_attack_trend_diff": ("tp_home_attack_trend", "tp_away_attack_trend"),
        "tp_defense_trend_diff": ("tp_home_defense_trend", "tp_away_defense_trend"),
    }
    for out_col, (left, right) in diff_pairs.items():
        out[out_col] = pd.to_numeric(out[left], errors="coerce") - pd.to_numeric(out[right], errors="coerce")

    out["tp_match_tempo_sum"] = _mean_available(
        out,
        ["tp_home_attack_pressure", "tp_away_attack_pressure", "tp_home_attack_box_pressure", "tp_away_attack_box_pressure"],
    )
    out["tp_match_openness"] = (
        pd.to_numeric(out["tp_home_matchup_attack_vs_defense"], errors="coerce")
        + pd.to_numeric(out["tp_away_matchup_attack_vs_defense"], errors="coerce")
    )
    out["tp_match_balance_abs"] = pd.to_numeric(out["tp_balance_score_diff"], errors="coerce").abs()
    out["tp_match_control_balance_abs"] = pd.to_numeric(out["tp_control_diff"], errors="coerce").abs()
    out["tp_match_quality_edge_abs"] = pd.to_numeric(out["tp_matchup_quality_diff"], errors="coerce").abs()

    return out
