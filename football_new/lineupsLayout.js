// src/lib/lineupsLayout.js
// Позиция вратаря (в % от размеров площадки)
export const GK_POS = { homeX: 6.5, awayX: 93.5, y: 52 };

/* ========================= разметка/геометрия ========================= */

export function parseFormation(str) {
  if (!str) return null;
  const arr = String(str)
    .trim()
    .split(/[-–—\s]+/)
    .map((n) => Number(n))
    .filter((n) => Number.isFinite(n) && n >= 0);
  return arr.length ? arr : null;
}

export function tagFor(lines) {
  const key = lines.join("-");
  if (key === "4-2-3-1") return "4231";
  if (key === "4-3-3") return "433";
  if (key === "4-4-2") return "442";
  if (key === "3-4-3") return "343";
  if (key === "3-5-2") return "352";
  if (key === "5-3-2") return "532";
  if (key === "4-1-4-1") return "4141";
  if (key === "4-5-1") return "451";
  return "other";
}

const halfRange = { home: { from: 6, to: 48 }, away: { from: 52, to: 94 } };

export function laneXsFromFractions(fracs, side) {
  const rH = halfRange.home, rA = halfRange.away;
  if (side === "home") return fracs.map((f) => rH.from + f * (rH.to - rH.from));
  return fracs.map((f) => rA.to - f * (rA.to - rA.from));
}

export function xFractionsPreset(lines, side) {
  const tag = tagFor(lines);
  const even = (n) => Array.from({ length: n }, (_, i) => (i + 1) / (n + 1));
  switch (tag) {
    case "4231": return laneXsFromFractions([0.2, 0.42, 0.68, 0.88], side);
    case "433":  return laneXsFromFractions([0.22, 0.55, 0.88], side);
    case "442":  return laneXsFromFractions([0.22, 0.58, 0.88], side);
    case "343":  return laneXsFromFractions([0.18, 0.48, 0.78], side);
    case "352":  return laneXsFromFractions([0.2, 0.52, 0.86], side);
    case "532":  return laneXsFromFractions([0.16, 0.46, 0.84], side);
    case "4141": return laneXsFromFractions([0.2, 0.36, 0.68, 0.88], side);
    case "451":  return laneXsFromFractions([0.2, 0.6, 0.9], side);
    default:     return laneXsFromFractions(even(lines.length), side);
  }
}

export function yCenterBias(i, lines, side, tag) {
  const base = [0, 2.2, -2.2, 1.6, -1.6];
  let b = base[i] ?? 0;
  if (side === "away") b = -b;
  if (tag === "4231") {
    if (i === 1) b = side === "home" ? 1.2 : -1.2;
    if (i === 2) b = side === "home" ? -1.8 : 1.8;
  }
  return b;
}

export function yRangeForLine(i, nInLine, lines, tag) {
  const WIDE = [12, 88], MID = [20, 80], NAR = [36, 64], VERY_NAR = [44, 56], STRIKERS = [42, 58];
  if (i === 0) {
    if (nInLine === 4) return WIDE;
    if (nInLine === 5) return [10, 90];
    if (nInLine === 3) return [24, 76];
    return MID;
  }
  if (tag === "4231") {
    if (i === 1 && nInLine === 2) return VERY_NAR;
    if (i === 2 && nInLine === 3) return [24, 76];
  }
  if (tag === "433") {
    if (i === 1 && nInLine === 3) return NAR;
    if (i === 2 && nInLine === 3) return WIDE;
  }
  if (tag === "442") {
    if (i === 1 && nInLine === 4) return MID;
    if (i === 2 && nInLine === 2) return STRIKERS;
  }
  if (tag === "343") {
    if (i === 1 && nInLine === 4) return MID;
    if (i === 2 && nInLine === 3) return [22, 78];
  }
  if (tag === "352") {
    if (i === 1 && nInLine === 5) return MID;
    if (i === 2 && nInLine === 2) return STRIKERS;
  }
  if (tag === "4141") {
    if (i === 1 && nInLine === 1) return VERY_NAR;
    if (i === 2 && nInLine === 4) return [24, 76];
  }
  if (tag === "451") {
    if (i === 1 && nInLine === 5) return [24, 76];
  }
  return MID;
}

export function spreadYIn(top, bottom, n, biasCenter = 0) {
  if (n <= 1) return [Math.max(6, Math.min(94, (top + bottom) / 2 + biasCenter))];
  const minStep = 8;
  let t = top, b = bottom;
  let span = b - t, step = span / (n - 1);
  if (step < minStep) {
    const extra = (minStep * (n - 1) - span) / 2;
    t = Math.max(8, t - extra); b = Math.min(92, b + extra);
    span = b - t; step = span / (n - 1);
  }
  const ys = Array.from({ length: n }, (_, i) => t + i * step);
  if (n % 2 === 1) {
    const mid = (n - 1) / 2;
    ys[mid] = Math.max(6, Math.min(94, ys[mid] + biasCenter));
  }
  return ys;
}

export function addCollisionOffsets(list) {
  const Rpx = 10;
  for (let i = 0; i < list.length; i++) {
    for (let j = i + 1; j < list.length; j++) {
      const a = list[i], b = list[j];
      if (Math.abs(a.x - b.x) < 1.2 && Math.abs(a.y - b.y) < 2.0) {
        const ang = (Math.PI / 2.5) * (j - i);
        const dx = Math.cos(ang) * Rpx, dy = Math.sin(ang) * Rpx;
        a._dx = (a._dx || 0) - dx; a._dy = (a._dy || 0) - dy;
        b._dx = (b._dx || 0) + dx; b._dy = (b._dy || 0) + dy;
      }
    }
  }
  return list;
}

export function groupRole(p) {
  const raw = (p?.position || p?.pos || p?.role || p?.type || "").toString().toUpperCase();
  if (/^G|GK|GOAL/.test(raw) || raw === "G") return "G";
  if (/CB|LB|RB|DF|DEF/.test(raw)) return "D";
  if (/DM|CM|AM|MF|MID/.test(raw)) return "M";
  if (/FW|ST|CF|ATT|FOR/.test(raw)) return "F";
  const num = Number(p?.number);
  if (Number.isFinite(num)) {
    if (num === 1) return "G";
    if (num >= 2 && num <= 6) return "D";
    if (num >= 7 && num <= 11) return "F";
  }
  return "M";
}

export function autoLayout(formation, players, side = "home") {
  const lines = parseFormation(formation) || [4, 3, 3];
  const tag = tagFor(lines);
  const laneXs = xFractionsPreset(lines, side);
  const G = players.filter((p) => groupRole(p) === "G");
  const D = players.filter((p) => groupRole(p) === "D");
  const M = players.filter((p) => groupRole(p) === "M");
  const F = players.filter((p) => groupRole(p) === "F");
  const gk = (G[0] ? [G[0]] : []).map((p) => ({ ...p, x: side === "home" ? GK_POS.homeX : GK_POS.awayX, y: GK_POS.y }));
  const buckets = [D, M, F, []];
  const placed = [];
  for (let i = 0; i < lines.length; i++) {
    const need = lines[i];
    let take = buckets[i] && buckets[i].length ? buckets[i] : [...D, ...M, ...F].filter((q) => !placed.includes(q));
    take = take.slice(0, need);
    const [top, bottom] = yRangeForLine(i, take.length, lines, tag);
    const bias = yCenterBias(i, lines, side, tag);
    const ys = spreadYIn(top, bottom, take.length, bias);
    const xBase = laneXs[Math.min(i, laneXs.length - 1)];
    take.forEach((p, j) => placed.push({ ...p, x: xBase, y: ys[j] }));
  }
  return addCollisionOffsets([...gk, ...placed]);
}

export function layoutFromGrid(players = [], side = "home", formation = "") {
  if (!players.length) return [];
  const parsed = players
    .map((p) => {
      const m = String(p?.grid || "").match(/^(\d+):(\d+)$/);
      if (!m) return null;
      return { p, col: Number(m[1]), row: Number(m[2]) };
    })
    .filter(Boolean);
  if (!parsed.length) return [];
  const colsSorted = Array.from(new Set(parsed.map((x) => x.col))).sort((a, b) => a - b);
  const fromFormation = parseFormation(formation);
  const lines = fromFormation && fromFormation.length === colsSorted.length
    ? fromFormation
    : colsSorted.map((c) => parsed.filter((x) => x.col === c).length);
  const tag = tagFor(lines);
  const laneXs = laneXsFromFractions(colsSorted.map((_, i) => (i + 1) / (colsSorted.length + 1)), side);
  const out = [];
  colsSorted.forEach((c, laneIdxFromGoal) => {
    const group = parsed.filter((x) => x.col === c).sort((a, b) => a.row - b.row);
    const [top, bottom] = yRangeForLine(laneIdxFromGoal, group.length, lines, tag);
    const bias = yCenterBias(laneIdxFromGoal, lines, side, tag);
    const ys = spreadYIn(top, bottom, group.length, bias);
    const xBase = laneXs[laneIdxFromGoal];
    group.forEach((g, i) => out.push({ ...g.p, x: xBase, y: ys[i] }));
  });
  const gkIdx = out.findIndex((q) => groupRole(q) === "G");
  if (gkIdx >= 0) out[gkIdx] = { ...out[gkIdx], x: side === "home" ? GK_POS.homeX : GK_POS.awayX, y: GK_POS.y };
  return addCollisionOffsets(out);
}

/* ========================= нормализация и meta ========================= */

export function normalizeLineups(rawIn, match) {
  const rows = rawIn?.lineups;
  if (!Array.isArray(rows) || rows.length === 0) return null;

  const byTeam = new Map();
  for (const r of rows) {
    if (!byTeam.has(r.team_id)) {
      byTeam.set(r.team_id, {
        team_id: r.team_id,
        team_name: r.team_name,
        formation: r.formation || "",
        starters: [],
        bench: [],
      });
    }
    const bucket = byTeam.get(r.team_id);
    if (!bucket.formation && r.formation) bucket.formation = r.formation;

    const player = {
      player_id: r.player_id,
      name: r.player_name || "",
      player_name: r.player_name || "",
      number: r.number,
      position: r.position,
      grid: r.grid || r.player_grid || null,
      minutes: r.minutes,
      goals: r.goals,
      assists: r.assists,
      cards_yellow: r.cards_yellow,
      cards_red: r.cards_red,
      rating: r.rating != null ? Number(r.rating) : null,
      is_starting: !!r.is_starting,
    };
    (r.is_starting ? bucket.starters : bucket.bench).push(player);
  }

  const teams = Array.from(byTeam.values());
  let home = match?.home_team_id && byTeam.get(match.home_team_id);
  let away = match?.away_team_id && byTeam.get(match.away_team_id);
  if (!home) home = teams[0] || { starters: [], bench: [] };
  if (!away) away = teams[1] || { starters: [], bench: [] };

  return { home, away, events: rawIn?.events || [] };
}

export function buildMetaMaps(events = []) {
  const teamMap = new Map();
  const ensure = (teamId, playerId) => {
    if (!teamMap.has(teamId)) teamMap.set(teamId, new Map());
    const inner = teamMap.get(teamId);
    if (!inner.has(playerId)) inner.set(playerId, { goals: 0, assists: 0, yellow: 0, red: 0, subInMin: null, subOutMin: null });
    return inner.get(playerId);
  };
  for (const e of events) {
    const teamId = e.team_id;
    const t = (e.type || "").toString().toLowerCase();
    const detail = (e.detail || "").toString().toLowerCase();
    if (t.includes("goal")) {
      if (e.player_id) ensure(teamId, e.player_id).goals += 1;
      if (e.assist_id) ensure(teamId, e.assist_id).assists += 1;
    } else if (t.includes("card")) {
      const m = ensure(teamId, e.player_id);
      if (detail.includes("red")) m.red += 1;
      else m.yellow += 1;
    } else if (t.includes("subst") || t.includes("substit")) {
      if (e.player_id) {
        const mIn = ensure(teamId, e.player_id);
        if (mIn.subInMin == null) mIn.subInMin = e.minute ?? e.elapsed ?? null;
      }
      if (e.assist_id) {
        const mOut = ensure(teamId, e.assist_id);
        if (mOut.subOutMin == null) mOut.subOutMin = e.minute ?? e.elapsed ?? null;
      }
    }
  }
  return teamMap;
}
