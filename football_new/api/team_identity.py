import re
import unicodedata


_TEAM_TOKEN_DROP = {
    "fc",
    "cf",
    "ac",
    "as",
    "sc",
    "sv",
    "ssc",
    "rc",
    "fk",
    "club",
    "vfl",
    "vfb",
    "fsv",
    "tsg",
    "eintracht",
    "stade",
    "real",
}

_TEAM_ALIAS_REPLACEMENTS = (
    (r"\bm gladbach\b", "monchengladbach"),
    (r"\bst pauli\b", "sankt pauli"),
    (r"\bparis sg\b", "paris saint germain"),
    (r"\b1 fc koln\b", "cologne"),
    (r"\bfc koln\b", "cologne"),
    (r"\bkoln\b", "cologne"),
    (r"\bmainz 05\b", "mainz"),
    (r"\bfsv mainz 05\b", "mainz"),
    (r"\b1899 hoffenheim\b", "hoffenheim"),
    (r"\brasenballsport leipzig\b", "rb leipzig"),
    (r"\brb leipzig\b", "leipzig"),
    (r"\bbayer 04 leverkusen\b", "bayer leverkusen"),
    (r"\bfc heidenheim\b", "heidenheim"),
    (r"\bhellas verona\b", "verona"),
    (r"\bparma calcio 1913\b", "parma"),
    (r"\bas roma\b", "roma"),
    (r"\bstade brestois 29\b", "brest"),
    (r"\breal oviedo\b", "oviedo"),
)


def _ascii_fold(value: str) -> str:
    if not value:
        return ""
    return (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
    )


def normalize_team_identity(value: str) -> str:
    folded = _ascii_fold(value).lower()
    folded = folded.replace("&", " and ")
    folded = re.sub(r"[^a-z0-9]+", " ", folded)
    folded = re.sub(r"\s+", " ", folded).strip()
    for pattern, replacement in _TEAM_ALIAS_REPLACEMENTS:
        folded = re.sub(pattern, replacement, folded)
    folded = re.sub(r"\b\d{1,4}\b", " ", folded)
    folded = re.sub(r"\s+", " ", folded).strip()
    parts = [part for part in folded.split() if part not in _TEAM_TOKEN_DROP]
    return " ".join(parts)


def merge_team_rows(rows):
    grouped = {}
    order = []
    metric_keys = {
        key
        for row in rows
        for key, value in row.items()
        if key not in {"team", "team_id", "priority_source", "league_name", "league_id"} and value is not None
    }
    for row in rows:
        team_name = row.get("team")
        team_key = normalize_team_identity(team_name)
        if not team_key:
            team_key = str(row.get("team_id") or team_name or len(order))
        if team_key not in grouped:
            grouped[team_key] = dict(row)
            grouped[team_key]["_team_key"] = team_key
            order.append(team_key)
            continue

        merged = grouped[team_key]
        current_team = merged.get("team") or ""
        candidate_team = row.get("team") or ""
        current_is_api = bool(merged.get("team_id"))
        candidate_is_api = bool(row.get("team_id"))

        if (candidate_is_api and not current_is_api) or (
            candidate_is_api == current_is_api and len(candidate_team) > len(current_team)
        ):
            merged["team"] = candidate_team or current_team
            if row.get("team_id") is not None:
                merged["team_id"] = row.get("team_id")

        if merged.get("league_name") is None and row.get("league_name") is not None:
            merged["league_name"] = row.get("league_name")
        if merged.get("league_id") is None and row.get("league_id") is not None:
            merged["league_id"] = row.get("league_id")

        current_source = str(merged.get("priority_source") or "")
        candidate_source = str(row.get("priority_source") or "")
        prefer_candidate = candidate_source == "understat" and current_source != "understat"

        for key in metric_keys:
            cur = merged.get(key)
            val = row.get(key)
            if val is None:
                continue
            if cur is None or prefer_candidate:
                merged[key] = val

    result = []
    for key in order:
        row = grouped[key]
        row.pop("_team_key", None)
        result.append(row)
    return result


def merge_named_groups(rows, name_key="team", items_key="last_matches"):
    grouped = {}
    order = []
    for row in rows:
        raw_name = row.get(name_key)
        norm = normalize_team_identity(raw_name)
        if norm not in grouped:
            grouped[norm] = dict(row)
            order.append(norm)
            continue
        merged = grouped[norm]
        if len(str(row.get(name_key) or "")) > len(str(merged.get(name_key) or "")):
            merged[name_key] = row.get(name_key)
        if items_key in row and items_key in merged:
            merged[items_key] = sorted(
                [*(merged.get(items_key) or []), *(row.get(items_key) or [])],
                key=lambda item: (item.get("date") or "", item.get("opponent") or ""),
                reverse=True,
            )
    return [grouped[key] for key in order]
