// src/lib/matchInsights.js
const API_BASE = "";
const matchesWindowCache = new Map();
const matchesWindowInFlight = new Map();
const packCache = new Map();

const toNum = (v) => {
  if (v == null || v === "") return null;
  const s = typeof v === "string" ? v.replace("%", "").trim() : v;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
};

async function fetchJsonSafe(url) {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`HTTP ${r.status}`);
  const txt = await r.text();
  try {
    return JSON.parse(txt);
  } catch {
    const fixed = txt
      .replace(/\bNaN\b/g, "null")
      .replace(/\b-?Infinity\b/g, "null");
    return JSON.parse(fixed);
  }
}

const seasonDateRange = (seasonStr, def = new Date().getFullYear(), yearsBack = 1) => {
  const y = Number(seasonStr) || Number(def);
  const back = Number.isFinite(Number(yearsBack)) ? Number(yearsBack) : 1;
  return { from: `${y - Math.max(0, back - 1)}-07-01`, to: `${y + 1}-06-30` };
};

const normalizeScore = (m) => {
  if (m?.score) return m.score;
  const hg = m?.home_goals;
  const ag = m?.away_goals;
  return hg == null || ag == null ? null : `${hg}-${ag}`;
};

const normalizeMatch = (m) => ({
  fixture_id: m.fixture_id,
  date: m.date,
  home_team: m.home_team,
  away_team: m.away_team,
  home_team_id: m.home_team_id,
  away_team_id: m.away_team_id,
  home_goals: m.home_goals,
  away_goals: m.away_goals,
  score: normalizeScore(m),
});

const sortByDateDesc = (a, b) => {
  const da = new Date(a.date || a.datetime || 0);
  const db = new Date(b.date || b.datetime || 0);
  return db - da;
};

const createWindowKey = ({ league, season, from, to }) =>
  [league || "", season || "", from || "", to || ""].join("::");

const createPackKey = ({ fixtureId, league, season }) =>
  [fixtureId || "", league || "", season || ""].join("::");

function avgStats(teamId, matches, limit = 10) {
  const picks = matches
    .filter((m) => Number(m.home_team_id) === Number(teamId) || Number(m.away_team_id) === Number(teamId))
    .sort(sortByDateDesc)
    .slice(0, limit);

  const acc = { xg: [], xga: [], shots: [], shots_on: [], corners: [], possession: [] };

  for (const m of picks) {
    const isHome = Number(m.home_team_id) === Number(teamId);
    const prefix = isHome ? "home" : "away";
    const xg = toNum(m[`${prefix}_expected_goals`]);
    const xga = toNum(m[`${isHome ? "away" : "home"}_expected_goals`]);
    const shots = toNum(m[`${prefix}_total_shots`]);
    const shotsOn = toNum(m[`${prefix}_shots_on_goal`]);
    const corners = toNum(m[`${prefix}_corners`]);
    const possession = toNum(m[`${prefix}_possession`]);

    if (xg != null) acc.xg.push(xg);
    if (xga != null) acc.xga.push(xga);
    if (shots != null) acc.shots.push(shots);
    if (shotsOn != null) acc.shots_on.push(shotsOn);
    if (corners != null) acc.corners.push(corners);
    if (possession != null) acc.possession.push(possession);
  }

  const avg = (arr) => (arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : null);

  return {
    xg: avg(acc.xg),
    xga: avg(acc.xga),
    shots: avg(acc.shots),
    shots_on: avg(acc.shots_on),
    corners: avg(acc.corners),
    possession: avg(acc.possession),
    xg_diff: avg(acc.xg) != null && avg(acc.xga) != null ? avg(acc.xg) - avg(acc.xga) : null,
  };
}

export async function buildMatchPack({ match, league }) {
  if (!match?.fixture_id) return null;

  const season = match.season;
  const packKey = createPackKey({
    fixtureId: match.fixture_id,
    league,
    season,
  });
  if (packCache.has(packKey)) return packCache.get(packKey);

  // Двух сезонов обычно достаточно для формы/личных встреч и это заметно
  // уменьшает объём данных против широкого исторического окна.
  const { from, to } = seasonDateRange(season, new Date().getFullYear(), 2);
  const matchDate = match.date || to;
  const endDate = matchDate || to;
  const windowKey = createWindowKey({
    league,
    season,
    from,
    to: endDate,
  });

  let data;
  if (matchesWindowCache.has(windowKey)) {
    data = matchesWindowCache.get(windowKey);
  } else if (matchesWindowInFlight.has(windowKey)) {
    data = await matchesWindowInFlight.get(windowKey);
  } else {
    const url =
      `${API_BASE}/api/matches_v3?league=${encodeURIComponent(league || "")}` +
      (season ? `&season=${encodeURIComponent(season)}` : "") +
      `&from_date=${from}&to_date=${endDate}`;
    const request = fetchJsonSafe(url)
      .then((result) => {
        matchesWindowCache.set(windowKey, result);
        return result;
      })
      .finally(() => {
        matchesWindowInFlight.delete(windowKey);
      });
    matchesWindowInFlight.set(windowKey, request);
    data = await request;
  }

  const list = Array.isArray(data) ? data : data ? [data] : [];

  const cutoff = match.date ? new Date(match.date) : null;
  const played = list.filter((m) => m.home_goals != null && m.away_goals != null);
  const beforeMatch = cutoff
    ? played.filter((m) => new Date(m.date || m.datetime || 0) < cutoff)
    : played;

  const homeId = match.home_team_id;
  const awayId = match.away_team_id;

  const homeLast = beforeMatch
    .filter((m) => Number(m.home_team_id) === Number(homeId) || Number(m.away_team_id) === Number(homeId))
    .sort(sortByDateDesc)
    .slice(0, 5)
    .map(normalizeMatch);

  const awayLast = beforeMatch
    .filter((m) => Number(m.home_team_id) === Number(awayId) || Number(m.away_team_id) === Number(awayId))
    .sort(sortByDateDesc)
    .slice(0, 5)
    .map(normalizeMatch);

  const h2h = beforeMatch
    .filter(
      (m) =>
        (Number(m.home_team_id) === Number(homeId) && Number(m.away_team_id) === Number(awayId)) ||
        (Number(m.home_team_id) === Number(awayId) && Number(m.away_team_id) === Number(homeId))
    )
    .sort(sortByDateDesc)
    .slice(0, 5)
    .map(normalizeMatch);

  const result = {
    h2h,
    homeLast,
    awayLast,
    homeAvg: avgStats(homeId, beforeMatch, 10),
    awayAvg: avgStats(awayId, beforeMatch, 10),
  };
  packCache.set(packKey, result);
  return result;
}
