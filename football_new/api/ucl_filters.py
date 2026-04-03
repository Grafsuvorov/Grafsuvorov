UCL_LEAGUE_STAGE_SQL = "(s.round ILIKE 'League Stage -%%')"
UCL_PLAYOFF_STAGE_SQL = "(s.round IN ('Round of 16', 'Quarter-finals', 'Semi-finals', 'Final'))"
UCL_ALL_STAGE_SQL = f"({UCL_LEAGUE_STAGE_SQL} OR {UCL_PLAYOFF_STAGE_SQL})"


def ucl_stage_condition_sql(stage_param: str = ":ucl_stage", alias: str = "s") -> str:
    league_sql = UCL_LEAGUE_STAGE_SQL.replace("s.", f"{alias}.")
    playoff_sql = UCL_PLAYOFF_STAGE_SQL.replace("s.", f"{alias}.")
    all_sql = UCL_ALL_STAGE_SQL.replace("s.", f"{alias}.")
    return f"""
      (
        ({stage_param} = 'league' AND {league_sql})
        OR ({stage_param} = 'playoff' AND {playoff_sql})
        OR ({stage_param} = 'all' AND {all_sql})
      )
    """


def schedule_round_filter_sql(league_param: str = ":league", stage_param: str = ":ucl_stage", alias: str = "s") -> str:
    return f"""
      AND (
        {league_param} <> 'UEFA Champions League'
        OR {ucl_stage_condition_sql(stage_param=stage_param, alias=alias)}
      )
    """
