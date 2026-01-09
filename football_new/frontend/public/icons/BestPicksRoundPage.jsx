// src/pages/BestPicksRoundPage.jsx
// 2025-only. Для каждого матча: ДВЕ ставки (Исход + Тотал 2.5) + объяснения.
// Без современного синтаксиса (никаких ?., ??).

import React, { useEffect, useMemo, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { HOME_URL } from "../routes/home";

/* ================== Константы ================== */
const FIXED_SEASON = "2025";
const USE_INSIGHTS = true;

// NEW: топ-лиги для расписания (апкаминг)
const TOP_LEAGUES = ["Premier League", "La Liga", "Bundesliga", "Serie A", "Ligue 1", "Eredivisie"];

// NEW: TTL кэша (мс)
const TTL_MATCHES = 10 * 60 * 1000;
const TTL_UPCOMING = 2 * 60 * 1000;
const TTL_BESTPICKS = 2 * 60 * 1000;
const TTL_INSIGHTS = 5 * 60 * 1000;

/* ================== Утилиты ================== */
function isNil(x) { return x === undefined || x === null; }
function valOr(x, d) { return isNil(x) ? d : x; }
function isNum(x) { return typeof x === "number" && isFinite(x); }
function toNum(x){ const v=Number(x); return isFinite(v) ? v : null; }
function normalizeRound(x) { return String(isNil(x) ? "" : x).trim(); }

function fmtPct(x, d) {
  if (isNil(x)) return "—";
  const v = Number(x);
  if (!isFinite(v)) return "—";
  return (v * 100).toFixed(valOr(d, 1)) + "%";
}
function fmtNum(x, d) {
  if (isNil(x)) return "—";
  const v = Number(x);
  if (!isFinite(v)) return "—";
  return v.toFixed(valOr(d, 2));
}
function clamp01(v) {
  const n = Number(v);
  if (!isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}
function impliedFromOdds(odds) {
  const o = Number(odds);
  return o > 0 ? 1 / o : null;
}
function calcEV(p, odds) {
  if (isNil(p) || isNil(odds)) return null;
  const pp = Number(p), oo = Number(odds);
  if (!isFinite(pp) || !isFinite(oo)) return null;
  return pp * oo - 1;
}
function kellyFraction(p, odds) {
  if (isNil(p) || isNil(odds)) return null;
  const b = Number(odds) - 1;
  if (b <= 0) return null;
  const q = 1 - Number(p);
  return (b * Number(p) - q) / b;
}
function by(key, dir) {
  return function(a, b) {
    const va = a ? a[key] : undefined;
    const vb = b ? b[key] : undefined;
    if (va === vb) return 0;
    const res = va > vb ? 1 : -1;
    return dir === "asc" ? res : -res;
  };
}
function roundSortKey(r) {
  if (!r) return 0;
  const m = String(r).match(/(\d+)/);
  return m ? Number(m[1]) : 0;
}
function prettyRound(r) { return !r || r === "Unknown" ? "Раунд не указан" : r; }

/* ================== Сезон 2025 ================== */
function seasonRange2025() {
  const y = 2025;
  return { from: y + "-07-01", to: (y + 1) + "-06-30" };
}

// NEW: парсинг 'DD.MM HH:MM' → 'YYYY-MM-DD HH:MM' для сортировки
function parseScheduleISO(datetimeDMHM, seasonStr) {
  if (!datetimeDMHM) return "";
  const parts = String(datetimeDMHM).split(" ");
  if (parts.length < 2) return "";
  const dm = parts[0].split(".");
  const hm = parts[1];
  if (dm.length < 2) return "";
  const dd = dm[0].padStart(2, "0");
  const mm = dm[1].padStart(2, "0");
  const yyyy = String(seasonStr || "2025");
  return `${yyyy}-${mm}-${dd} ${hm}`;
}

/* ================== Логотипы ================== */
const LEAGUE_LOGO_FILE = {
  "Premier League": "Premier_League.png",
  "La Liga": "La_Liga.png",
  "Bundesliga": "Bundesliga.png",
  "Serie A": "Serie_A.png",
  "Ligue 1": "Ligue_1.png",
  "Eredivisie": "",
};
function leagueLogoSrc(name) { return "/icons/" + (LEAGUE_LOGO_FILE[name] || ""); }
function teamLogoSrc(id) { return id ? ("/icons/team_logos/" + id + ".png") : ""; }
function Img(props) {
  const size = valOr(props.size, 22);
  return (
    <img
      src={props.src}
      alt={props.alt}
      width={size}
      height={size}
      className={props.className}
      onError={function(e){ e.currentTarget.style.display = "none"; }}
    />
  );
}

/* ================== UI ================== */
function Badge(props) {
  const color = valOr(props.color, "gray");
  const palette = {
    green: "bg-green-100 text-green-700",
    amber: "bg-amber-100 text-amber-700",
    gray: "bg-gray-100 text-gray-700",
    blue: "bg-blue-100 text-blue-700",
    violet: "bg-violet-100 text-violet-700",
    red: "bg-rose-100 text-rose-700",
    fuchsia: "bg-fuchsia-100 text-fuchsia-700",
    sky: "bg-sky-100 text-sky-700",
    indigo: "bg-indigo-100 text-indigo-700",
  };
  return (
    <span className={"inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium " + (palette[color] || palette.gray) + " " + (props.className || "")}>
      {props.children}
    </span>
  );
}
function EVBadge(props) {
  const e = Number(valOr(props.ev, 0));
  var color = "gray";
  if (e >= 0.15) color = "green";
  else if (e >= 0.05) color = "amber";
  return <Badge color={color}>EV {fmtPct(e)}</Badge>;
}

/* ================== Лимиты по лигам ================== */
function leagueFrontTuning(leagueName) {
  const L = String(leagueName || "").toLowerCase();
  var base = {
    oddsHardCapAbs: 9.0,
    oddsMax1x2: 7.0,
    oddsMaxDraw: 6.0,
    minPDraw: 0.28,
    drawCloseGap: 0.06
  };
  if (L.indexOf("bundes") >= 0) return { oddsHardCapAbs: 8.5, oddsMax1x2: 6.5, oddsMaxDraw: 5.75, minPDraw: 0.30, drawCloseGap: 0.055 };
  if (L.indexOf("la liga") >= 0 || L.indexOf("laliga") >= 0 || L.indexOf("primera") >= 0)
    return { oddsHardCapAbs: 8.5, oddsMax1x2: 6.5, oddsMaxDraw: 5.75, minPDraw: 0.29, drawCloseGap: 0.06 };
  return base;
}

/* ================== Helpers ================== */
function extractPAH(offers) {
  var pH = null, pA = null, pD = null, odH = null, odA = null, odD = null;
  (offers || []).forEach(function(o) {
    if (o.market === "1X2") {
      if (o.outcome === "home") { pH = o.p; odH = o.odds; }
      if (o.outcome === "away") { pA = o.p; odA = o.odds; }
      if (o.outcome === "draw") { pD = o.p; odD = o.odds; }
    }
  });
  return { pH: pH, pA: pA, pD: pD, odH: odH, odA: odA, odD: odD };
}

/* ================== Инсайты: нормализация ================== */
function formLabel(any) {
  if (!any) return null;
  if (typeof any === "string") {
    var w = (any.match(/W/g) || []).length;
    var d = (any.match(/D/g) || []).length;
    var l = (any.match(/L/g) || []).length;
    return { w: w, d: d, l: l, txt: w + "-" + d + "-" + l };
  }
  if (typeof any === "object") {
    var ww = Number(any.w || 0), dd = Number(any.d || 0), ll = Number(any.l || 0);
    return { w: ww, d: dd, l: ll, txt: ww + "-" + dd + "-" + ll };
  }
  return null;
}

/* return {ins, triad} */
function normalizePayload(payload) {
  if (!payload) return { ins: null, triad: null };

  if (payload.insights) {
    var ins = payload.insights;
    var tri = null;
    if (payload.probs_1x2 || payload.odds_1x2) {
      tri = {
        pH: payload.probs_1x2 ? payload.probs_1x2.home : null,
        pD: payload.probs_1x2 ? payload.probs_1x2.draw : null,
        pA: payload.probs_1x2 ? payload.probs_1x2.away : null,
        odH: payload.odds_1x2 ? payload.odds_1x2.home : null,
        odD: payload.odds_1x2 ? payload.odds_1x2.draw : null,
        odA: payload.odds_1x2 ? payload.odds_1x2.away : null
      };
    }
    return { ins: ins, triad: tri };
  }

  if (payload.recommendations || payload.narrative || payload.insights) {
    var tri2 = null;
    if (payload.probs_1x2 || payload.odds_1x2) {
      tri2 = {
        pH: payload.probs_1x2 ? payload.probs_1x2.home : null,
        pD: payload.probs_1x2 ? payload.probs_1x2.draw : null,
        pA: payload.probs_1x2 ? payload.probs_1x2.away : null,
        odH: payload.odds_1x2 ? payload.odds_1x2.home : null,
        odD: payload.odds_1x2 ? payload.odds_1x2.draw : null,
        odA: payload.odds_1x2 ? payload.odds_1x2.away : null
      };
    }
    return { ins: payload.insights || null, triad: tri2 };
  }

  if (payload.metrics && payload.metrics.form) {
    var h = payload.metrics.form.home || {};
    var a = payload.metrics.form.away || {};
    var h2h = payload.metrics.h2h || {};
    var players = payload.players || { home: [], away: [] };

    var gfH = isNum(h.gf) ? h.gf : null;
    var gaH = isNum(h.ga) ? h.ga : null;
    var gfA = isNum(a.gf) ? a.gf : null;
    var gaA = isNum(a.ga) ? a.ga : null;

    var insOld = {
      home: { name: payload.home_team, form: { w: h.w || 0, d: h.d || 0, l: h.l || 0 }, gf_last5: gfH, ga_last5: gaH },
      away: { name: payload.away_team, form: { w: a.w || 0, d: a.d || 0, l: a.l || 0 }, gf_last5: gfA, ga_last5: gaA },
      totals: { avg_goals_last10: isNum(gfH) && isNum(gfA) ? (gfH + gfA) : null, under25_rate_last10: null },
      h2h: { home_wins: h2h.w || 0, draws: h2h.d || 0, away_wins: h2h.l || 0 },
      top_scorers: {
        home: (players.home || []).map(function(p){ return { name: p.name, g_last5: p.g || 0 }; }),
        away: (players.away || []).map(function(p){ return { name: p.name, g_last5: p.g || 0 }; })
      }
    };
    return { ins: insOld, triad: null };
  }

  return { ins: null, triad: null };
}

/* ================== Объяснения ================== */
var LABELS = { outcome: { home: "П1", away: "П2", draw: "Х" }, ou: { over: "ТБ 2.5", under: "ТМ 2.5" } };

function explainTotals(ins, choice, offers) {
  var parts = [];
  if (ins) {
    var hf = valOr(ins.home && ins.home.gf_last5, null);
    var af = valOr(ins.away && ins.away.gf_last5, null);
    var hg = valOr(ins.home && ins.home.ga_last5, null);
    var ag = valOr(ins.away && ins.away.ga_last5, null);
    var avg10 = ins.totals ? ins.totals.avg_goals_last10 : null;
    var uRate = ins.totals ? ins.totals.under25_rate_last10 : null;

    if (choice === "under") {
      if (isNum(hf) && isNum(af) && hf <= 1.2 && af <= 1.2) parts.push("Низкая продуктивность атаки: хозяева " + hf.toFixed(1) + " г/м, гости " + af.toFixed(1) + " г/м (5).");
      if (isNum(hg) && isNum(ag) && hg <= 1.0 && ag <= 1.0) parts.push("Надёжная оборона: пропускают " + hg.toFixed(1) + " и " + ag.toFixed(1) + " г/м.");
      if (isNum(avg10) && isNum(uRate)) parts.push("Средняя результативность " + avg10.toFixed(1) + " г/м за 10; U2.5=" + Math.round(uRate * 100) + "%.");
    } else {
      if (isNum(hf) && hf >= 1.5) parts.push("Хозяева много создают: " + hf.toFixed(1) + " г/м.");
      if (isNum(af) && af >= 1.5) parts.push("Гости опасны: " + af.toFixed(1) + " г/м.");
      if (isNum(hg) && hg >= 1.3) parts.push("Хозяева позволяют: " + hg.toFixed(1) + " г/м пропущенных.");
      if (isNum(ag) && ag >= 1.3) parts.push("Гости позволяют: " + ag.toFixed(1) + " г/м пропущенных.");
      if (isNum(avg10)) parts.push("Средняя результативность около " + avg10.toFixed(1) + " г/м — предпосылки к «верху».");
    }
  }
  if (parts.length === 0 && offers && offers.length) {
    var ou = offers.filter(function(o){ return o.market === "OU25"; });
    var over = null, under = null;
    for (var i=0;i<ou.length;i++){
      if (String(ou[i].outcome).toLowerCase() === "over") over = ou[i];
      if (String(ou[i].outcome).toLowerCase() === "under") under = ou[i];
    }
    var pick = choice === "under" ? under : over;
    if (pick && pick.p != null && pick.odds != null) {
      var imp = impliedFromOdds(pick.odds);
      var edge = (!isNil(pick.p) && !isNil(imp)) ? (pick.p - imp) : null;
      parts.push("Модель склоняется к " + LABELS.ou[choice] + ": p " + fmtPct(pick.p, 0) + ", имплайд " + fmtPct(imp, 0) + (edge != null ? (", запас " + fmtPct(edge, 1) + ".") : "."));
    } else {
      parts.push("Профиль матча указывает на " + (choice === "under" ? "низ" : "верх") + " по тоталу 2.5.");
    }
  }
  return parts.join(" ");
}

function explainOutcome(ins, side, tri) {
  var parts = [];
  if (tri && (!isNil(tri.pH) || !isNil(tri.pD) || !isNil(tri.pA))) {
    parts.push("Рынок: П1 " + fmtPct(tri.pH, 0) + " | Х " + fmtPct(tri.pD, 0) + " | П2 " + fmtPct(tri.pA, 0) + ".");
  }
  if (ins) {
    var hForm = formLabel(valOr((ins.home && (ins.home.form_last5 || ins.home.form)), null));
    var aForm = formLabel(valOr((ins.away && (ins.away.form_last5 || ins.away.form)), null));
    var hf = valOr(ins.home && ins.home.gf_last5, null);
    var af = valOr(ins.away && ins.away.gf_last5, null);
    var hg = valOr(ins.home && ins.home.ga_last5, null);
    var ag = valOr(ins.away && ins.away.ga_last5, null);
    var h2h = ins.h2h || {};

    var homePts = hForm ? (hForm.w * 3 + hForm.d) : 0;
    var awayPts = aForm ? (aForm.w * 3 + aForm.d) : 0;

    if (side === "home") {
      if (homePts - awayPts >= 4) parts.push("Форма лучше: " + (hForm ? hForm.txt : "-") + " против " + (aForm ? aForm.txt : "-") + " (посл. 5).");
      if (isNum(hf) && hf >= 1.5) parts.push("Хозяева забивают: " + hf.toFixed(1) + " г/м.");
      if (isNum(ag) && ag >= 1.3) parts.push("Гости позволяют: " + ag.toFixed(1) + " г/м проп.");
    } else if (side === "away") {
      if (awayPts - homePts >= 4) parts.push("Гости в лучшей форме: " + (aForm ? aForm.txt : "-") + " против " + (hForm ? hForm.txt : "-") + " (посл. 5).");
      if (isNum(af) && af >= 1.5) parts.push("Гости остры в атаке: " + af.toFixed(1) + " г/м.");
      if (isNum(hg) && hg >= 1.3) parts.push("Хозяева уязвимы: " + hg.toFixed(1) + " г/м проп.");
    } else {
      parts.push("Матч близкий по силам — шансы сопоставимы.");
    }
    if ((valOr(h2h.home_wins,0) + valOr(h2h.away_wins,0) + valOr(h2h.draws,0)) > 0) {
      parts.push("Очные: " + valOr(h2h.home_wins,0) + "-" + valOr(h2h.draws,0) + "-" + valOr(h2h.away_wins,0) + " со стороны хозяев.");
    }
  }
  return parts.join(" ");
}

/* ================== Прунинг офферов ================== */
function frontPruneOffers(offers, leagueName) {
  var lt = leagueFrontTuning(leagueName);
  if (!offers || !offers.length) return [];
  var out = [];
  for (var i=0;i<offers.length;i++) {
    var o = offers[i];
    if (o.market === "OU25") {
      var ev = !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds);
      if (isNil(o.p)) continue;
      out.push(Object.assign({}, o, { ev: ev }));
      continue;
    }
    if (o.market === "1X2") {
      var odds = Number(o.odds || 0);
      if (odds >= lt.oddsHardCapAbs) continue;
      out.push(Object.assign({}, o, { ev: !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds) }));
    }
  }
  return out.sort(function(a,b){
    var msA = valOr(a.model_score, -1), msB = valOr(b.model_score, -1);
    if (msA !== msB) return msB - msA;
    return valOr(b.ev, -1) - valOr(a.ev, -1);
  });
}

/* ================== Предпочтение по тоталам ================== */
function preferUnderByInsights(ins) {
  if (!ins || !ins.totals) return null;
  var avg = Number(valOr(ins.totals.avg_goals_last10, NaN));
  var uRate = Number(valOr(ins.totals.under25_rate_last10, NaN));
  if (isFinite(avg) && isFinite(uRate)) {
    if (avg <= 2.4 && uRate >= 0.55) return true;
    if (avg >= 2.7 && uRate <= 0.45) return false;
  }
  var hf = valOr(ins && ins.home && ins.home.gf_last5, null);
  var af = valOr(ins && ins.away && ins.away.gf_last5, null);
  var hg = valOr(ins && ins.home && ins.home.ga_last5, null);
  var ag = valOr(ins && ins.away && ins.away.ga_last5, null);
  if (isNum(hf) && isNum(af) && isNum(hg) && isNum(ag)) {
    if ((hf <= 1.2 && af <= 1.2) || (hg <= 0.9 && ag <= 0.9)) return true;
    if (hf >= 1.6 || af >= 1.6 || hg >= 1.3 || ag >= 1.3) return false;
  }
  return null;
}

/* ================== Выбор ставок ================== */
function chooseTotals(offers, ins) {
  var ou = (offers || []).filter(function(o){ return o.market === "OU25"; }).map(function(o){
    return Object.assign({}, o, { ev: !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds) });
  });

  if (ou.length) {
    var under = ou.filter(function(o){ return String(o.outcome).toLowerCase() === "under"; }).sort(function(a,b){ return valOr(b.ev,-1) - valOr(a.ev,-1); })[0] || null;
    var over  = ou.filter(function(o){ return String(o.outcome).toLowerCase() === "over"; }).sort(function(a,b){ return valOr(b.ev,-1) - valOr(a.ev,-1); })[0] || null;
    var pref = preferUnderByInsights(ins || null);
    var best = null;
    if (pref === true && under && valOr(under.ev,-1) > 0) best = under;
    else if (pref === false && over && valOr(over.ev,-1) > 0) best = over;
    else {
      var listPos = ou.filter(function(o){ return valOr(o.ev,-1) > 0; }).sort(function(a,b){ return valOr(b.ev,-1) - valOr(a.ev,-1); });
      best = listPos[0] || under || over || null;
    }
    if (best) {
      var out = String(best.outcome).toLowerCase();
      return {
        market: "OU25",
        outcome: out,
        label: LABELS.ou[out] || "Тотал 2.5",
        p: valOr(best.p, null),
        odds: valOr(best.odds, null),
        ev: valOr(best.ev, calcEV(best.p, best.odds)),
        _mode: !isNil(best.odds) ? "market" : "model",
        text: explainTotals(ins || null, out, offers)
      };
    }
  }
  var pref2 = preferUnderByInsights(ins || null);
  var out2 = (pref2 === false ? "over" : "under");
  var pGuess = (pref2 === null ? 0.52 : 0.55);
  return { market: "OU25", outcome: out2, label: LABELS.ou[out2], p: pGuess, odds: null, ev: null, _mode: "model", text: explainTotals(ins || null, out2, offers) };
}

/* — Анти-доминирование ничьей + «близость» 7% — */
function chooseOutcome(offers, leagueName, ins, triad) {
  var lt = leagueFrontTuning(leagueName);
  var oneX2 = (offers || []).filter(function(o){ return o.market === "1X2"; }).map(function(o){
    return Object.assign({}, o, { ev: !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds) });
  });

  var tri = triad || extractPAH(oneX2);

  var pH = tri ? tri.pH : null, pA = tri ? tri.pA : null, pD = tri ? tri.pD : null;
  var odH = tri ? tri.odH : null, odA = tri ? tri.odA : null, odD = tri ? tri.odD : null;

  var gapClose = 0.07;

  var allowDrawMarket = (isNum(pH) && isNum(pA) && Math.abs(pH - pA) <= lt.drawCloseGap &&
                         isNum(pD) && pD >= lt.minPDraw && isNum(odD) && odD <= lt.oddsMaxDraw);

  var bestHome = null, bestAway = null, bestDraw = null;
  for (var i=0;i<oneX2.length;i++){
    var o = oneX2[i];
    if (o.outcome === "home") { if (!bestHome || valOr(o.ev,-1) > valOr(bestHome.ev,-1)) bestHome = o; }
    if (o.outcome === "away") { if (!bestAway || valOr(o.ev,-1) > valOr(bestAway.ev,-1)) bestAway = o; }
    if (o.outcome === "draw") { if (!bestDraw || valOr(o.ev,-1) > valOr(bestDraw.ev,-1)) bestDraw = o; }
  }

  if (isNum(pH) && isNum(pA) && Math.abs(pH - pA) <= gapClose) {
    var evH = !isNil(pH) && !isNil(odH) ? calcEV(pH, odH) : valOr(bestHome && bestHome.ev, null);
    var evA = !isNil(pA) && !isNil(odA) ? calcEV(pA, odA) : valOr(bestAway && bestAway.ev, null);
    var evD = !isNil(pD) && !isNil(odD) ? calcEV(pD, odD) : valOr(bestDraw && bestDraw.ev, null);

    var side = null, sideEV = null;
    if (isNum(evH) || isNum(evA)) {
      if (valOr(evH, -999) >= valOr(evA, -999)) { side = "home"; sideEV = evH; } else { side = "away"; sideEV = evA; }
    }

    if (allowDrawMarket && isNum(evD) && isNum(sideEV) && (evD >= sideEV + 0.06)) {
      return { market: "1X2", outcome: "draw", label: LABELS.outcome.draw, p: pD, odds: odD, ev: evD, _mode: "market", text: explainOutcome(ins || null, "draw", tri) };
    }

    if (side && isNum(sideEV) && sideEV > 0) {
      var oddsSide = side === "home" ? odH : odA;
      var pSide = side === "home" ? pH : pA;
      return { market: "1X2", outcome: side, label: LABELS.outcome[side], p: pSide, odds: oddsSide, ev: sideEV, _mode: "market", text: explainOutcome(ins || null, side, tri) };
    }
    var sideProb = (pH >= pA) ? "home" : "away";
    var oddsProb = sideProb === "home" ? odH : odA;
    var pProb = sideProb === "home" ? pH : pA;
    var evProb = calcEV(pProb, oddsProb);
    return { market: "1X2", outcome: sideProb, label: LABELS.outcome[sideProb], p: pProb, odds: oddsProb, ev: evProb, _mode: "market", text: explainOutcome(ins || null, sideProb, tri) };
  }

  var pGap = (isNum(pH) && isNum(pA)) ? Math.abs(pH - pA) : null;
  var effMin = (function(){
    var core = 0.52;
    if (!isNum(pGap)) return core;
    if (pGap >= 0.10) return Math.max(0.48, core - 0.04);
    if (pGap >= 0.06) return Math.max(0.50, core - 0.02);
    return core;
  })();

  var sideFinal = null;
  if (isNum(pH) && isNum(pA)) {
    var top = (pH >= pA) ? "home" : "away";
    var pTop = top === "home" ? pH : pA;
    if (pTop >= effMin) sideFinal = top;
  }
  if (!sideFinal && isNum(pH) && isNum(pA)) {
    sideFinal = (pH >= pA) ? "home" : "away";
  }

  if (sideFinal) {
    var oddsF = sideFinal === "home" ? odH : odA;
    var pF = sideFinal === "home" ? pH : pA;
    var evF = calcEV(pF, oddsF);
    return { market: "1X2", outcome: sideFinal, label: LABELS.outcome[sideFinal], p: pF, odds: oddsF, ev: evF, _mode: "market", text: explainOutcome(ins || null, sideFinal, tri) };
  }

  var pGuess = 0.50;
  var sideModel = "draw";
  if (isNum(pH) && isNum(pA)) {
    sideModel = (Math.max(pH, pA) >= 0.53) ? ((pH >= pA) ? "home" : "away") : "draw";
    pGuess = sideModel === "draw" ? valOr(pD, 0.30) : Math.max(pH, pA);
  }
  return { market: "1X2", outcome: sideModel, label: LABELS.outcome[sideModel], p: clamp01(pGuess), odds: null, ev: null, _mode: "model", text: explainOutcome(ins || null, sideModel, tri) };
}

/* ================== РЕЗУЛЬТАТЫ/ПОДСВЕТКА ================== */

/* универсальное чтение голов из фикстуры */
function getGoals(f, side) {
  var keys = side === "home"
    ? ["home_goals","goals_home","home_score","score_home","ft_home","home_fulltime"]
    : ["away_goals","goals_away","away_score","score_away","ft_away","away_fulltime"];
  for (var i=0;i<keys.length;i++){
    var k = keys[i];
    if (!isNil(f[k])) {
      var v = toNum(f[k]);
      if (v !== null) return v;
    }
  }
  if (f.score && typeof f.score === "object") {
    var v2 = side === "home" ? f.score.home : f.score.away;
    v2 = toNum(v2);
    if (v2 !== null) return v2;
  }
  return null;
}
function finishedFixture(f) {
  var hg = getGoals(f,"home");
  var ag = getGoals(f,"away");
  return hg !== null && ag !== null;
}
function actualOutcomeTag(f) {
  if (!finishedFixture(f)) return null;
  var hg = getGoals(f,"home");
  var ag = getGoals(f,"away");
  if (hg > ag) return "home";
  if (hg < ag) return "away";
  return "draw";
}
function modelPredFromTriad(tri) {
  if (!tri) return null;
  var bestKey = null, bestVal = -1;
  var map = { home: tri.pH, draw: tri.pD, away: tri.pA };
  Object.keys(map).forEach(function(k){
    var v = map[k];
    v = toNum(v);
    if (v !== null && v > bestVal) { bestVal = v; bestKey = k; }
  });
  return bestKey;
}
function totalHit(f, recTotal) {
  if (!finishedFixture(f) || !recTotal) return null;
  var hg = getGoals(f,"home");
  var ag = getGoals(f,"away");
  var sum = hg + ag;
  if (recTotal.outcome === "under") return sum < 3 ? true : false;
  if (recTotal.outcome === "over")  return sum >= 3 ? true : false;
  return null;
}
function outcomeHit(f, outcomeTag) {
  if (!finishedFixture(f) || !outcomeTag) return null;
  return actualOutcomeTag(f) === outcomeTag;
}

function cardTheme(fixture, recOutcome, recTotal, triad) {
  if (!finishedFixture(fixture)) {
    return { stripe: "", ring: "", label: "", key: "upcoming" };
  }
  var ht = totalHit(fixture, recTotal) === true;
  var hm = outcomeHit(fixture, modelPredFromTriad(triad)) === true;
  var hr = outcomeHit(fixture, recOutcome ? recOutcome.outcome : null) === true;

  var k = "none";
  if (!ht && !hm && !hr) k = "fail";
  else if (ht && hm && hr) k = "all";
  else if (ht && hm && !hr) k = "tot_model";
  else if (ht && !hm && hr) k = "tot_reco";
  else if (!ht && hm && hr) k = "model_reco";
  else if (ht && !hm && !hr) k = "only_tot";
  else if (!ht && hm && !hr) k = "only_model";
  else if (!ht && !hm && hr) k = "only_reco";

  var map = {
    fail:       { stripe: "bg-rose-400",   ring: "ring-2 ring-rose-300 ring-offset-1 ring-offset-white",    label: "Ничего не зашло" },
    only_tot:   { stripe: "bg-amber-400",  ring: "ring-2 ring-amber-300 ring-offset-1 ring-offset-white",   label: "Зашёл тотал" },
    only_model: { stripe: "bg-blue-400",   ring: "ring-2 ring-blue-300 ring-offset-1 ring-offset-white",    label: "Зашёл исход (модель)" },
    only_reco:  { stripe: "bg-fuchsia-400",ring: "ring-2 ring-fuchsia-300 ring-offset-1 ring-offset-white", label: "Зашёл исход (реком.)" },
    tot_model:  { stripe: "bg-sky-400",    ring: "ring-2 ring-sky-300 ring-offset-1 ring-offset-white",     label: "Зашли тотал + модель" },
    tot_reco:   { stripe: "bg-indigo-400", ring: "ring-2 ring-indigo-300 ring-offset-1 ring-offset-white",  label: "Зашли тотал + рекоменд." },
    model_reco: { stripe: "bg-violet-400", ring: "ring-2 ring-violet-300 ring-offset-1 ring-offset-white",  label: "Зашли модель + рекоменд." },
    all:        { stripe: "bg-emerald-500",ring: "ring-2 ring-emerald-400 ring-offset-1 ring-offset-white", label: "Все зашло" },
    none:       { stripe: "", ring: "", label: "" }
  };
  var theme = map[k] || map.none;
  theme.key = k;
  return theme;
}

function ColorLegend() {
  var item = function(colorClass, text){ return (
    <div className="flex items-center gap-2">
      <span className={"inline-block w-3 h-3 rounded " + colorClass}></span>
      <span className="text-xs text-gray-700">{text}</span>
    </div>
  );};
  return (
    <div className="flex flex-wrap gap-3 rounded-xl border bg-white p-3">
      {item("bg-emerald-500", "Все зашло")}
      {item("bg-sky-400", "Тотал + модель")}
      {item("bg-indigo-400", "Тотал + рекоменд.")}
      {item("bg-violet-400", "Модель + рекоменд.")}
      {item("bg-amber-400", "Только тотал")}
      {item("bg-blue-400", "Только модель")}
      {item("bg-fuchsia-400", "Только рекоменд.")}
      {item("bg-rose-400", "Ничего не зашло")}
    </div>
  );
}

/* ================== Двойная карточка матча ================== */
function DualCard(props) {
  var fixture = props.fixture;
  var offers = props.offers || [];
  var ins = props.ins || null;
  var tri = props.triad || null;
  var kellyCoef = props.kellyCoef || 0.25;

  var outcome = chooseOutcome(offers, fixture.league, ins, tri);
  var total = chooseTotals(offers, ins);

  var theme = cardTheme(fixture, outcome, total, tri);

  function TriadLine() {
    if (!tri) return null;
    var hasProb = !isNil(tri.pH) || !isNil(tri.pD) || !isNil(tri.pA);
    var hasOdds = !isNil(tri.odH) || !isNil(tri.odD) || !isNil(tri.odA);
    if (!hasProb && !hasOdds) return null;
    return (
      <div className="text-xs text-gray-600 mt-1">
        {hasProb ? <div>Вероятности: П1 {fmtPct(tri.pH,0)} · Х {fmtPct(tri.pD,0)} · П2 {fmtPct(tri.pA,0)}</div> : null}
        {hasOdds ? <div>Коэффициенты: П1 {fmtNum(tri.odH,2)} · Х {fmtNum(tri.odD,2)} · П2 {fmtNum(tri.odA,2)}</div> : null}
      </div>
    );
  }

  function Row(p) {
    var rec = p.rec;
    if (!rec) return null;
    var kFull = kellyFraction(rec.p, rec.odds) || 0;
    var kRec = Math.max(0, kFull * kellyCoef);
    var tone = p.tone === "sky" ? "bg-sky-50 text-sky-900/90" : "bg-indigo-50 text-indigo-900/90";
    return (
      <div className={"rounded-xl " + tone + " p-3"}>
        <div className="flex flex-wrap items-center gap-2 text-sm font-semibold">
          <span>{p.title}:</span>
          <Badge color="blue">{rec.label}</Badge>
          <span>p {fmtPct(rec.p, 0)}</span>
          <span>odds {fmtNum(rec.odds, 2)}</span>
          <EVBadge ev={rec.ev} />
          <span className="text-xs text-gray-600">Kelly {fmtPct(kFull, 1)} → рек. {fmtPct(kRec, 1)}</span>
          {rec._mode === "model" ? <Badge color="gray" className="ml-1">по модели</Badge> : null}
        </div>
        {p.title === "Исход" ? <TriadLine /> : null}
        {rec.text ? <div className="mt-1 text-sm leading-relaxed">{rec.text}</div> : null}
      </div>
    );
  }

  function Facts() {
    var lines = [];
    if (ins) {
      var hForm = formLabel(valOr((ins.home && (ins.home.form_last5 || ins.home.form)), null));
      var aForm = formLabel(valOr((ins.away && (ins.away.form_last5 || ins.away.form)), null));
      if (hForm) lines.push("Хозяева: серия " + hForm.txt + ".");
      if (aForm) lines.push("Гости: серия " + aForm.txt + ".");
      var hf = valOr(ins.home && ins.home.gf_last5, null);
      var af = valOr(ins.away && ins.away.gf_last5, null);
      var hg = valOr(ins.home && ins.home.ga_last5, null);
      var ag = valOr(ins.away && ins.away.ga_last5, null);
      if (isNum(hf) && isNum(hg)) lines.push("Хозяева: " + hf.toFixed(1) + " заб / " + hg.toFixed(1) + " проп. за матч (5).");
      if (isNum(af) && isNum(ag)) lines.push("Гости: " + af.toFixed(1) + " заб / " + ag.toFixed(1) + " проп. за матч (5).");
      var avg10 = ins.totals ? ins.totals.avg_goals_last10 : null;
      if (isNum(avg10)) lines.push("Средняя результативность ≈ " + avg10.toFixed(1) + " г/м.");
    } else if (tri) {
      lines.push("Шансы по рынку: П1 " + fmtPct(tri.pH,0) + ", Х " + fmtPct(tri.pD,0) + ", П2 " + fmtPct(tri.pA,0) + ".");
    }
    var visible = lines.slice(0, 4);
    return (
      <div className="rounded-xl bg-gray-50 p-3 text-sm text-gray-700">
        <div className="font-medium text-gray-900 mb-1">Факты по форме:</div>
        <ul className="list-disc pl-5 space-y-1">
          {visible.map(function(t,i){ return <li key={i}>{t}</li>; })}
        </ul>
      </div>
    );
  }

  var cardRing = theme.ring ? " " + theme.ring : "";
  return (
    <div className={"rounded-2xl border bg-white shadow-sm hover:shadow-md transition-shadow overflow-hidden" + cardRing}>
      {theme.stripe ? <div className={"h-1.5 w-full " + theme.stripe}></div> : null}

      <div className="px-4 py-2 bg-gradient-to-r from-slate-50 to-white border-b text-xs text-gray-500 flex items-center justify-between">
        <span>Дата: {fixture.date}</span>
        {theme.label ? <span className="text-[11px] text-gray-600">{theme.label}</span> : null}
      </div>

      <div className="p-4 flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Img src={teamLogoSrc(fixture.home_team_id)} alt={fixture.home_team} size={28} className="rounded" />
            <div className="text-base md:text-lg font-semibold text-gray-900">{fixture.home_team}</div>
          </div>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-gray-400">vs</span>
          <div className="flex items-center gap-2">
            <div className="text-base md:text-lg font-semibold text-gray-900 text-right">{fixture.away_team}</div>
            <Img src={teamLogoSrc(fixture.away_team_id)} alt={fixture.away_team} size={28} className="rounded" />
          </div>
        </div>

        <Row title="Исход" rec={outcome} tone="indigo" />
        <Row title="Тотал" rec={total} tone="sky" />
        <Facts />
      </div>
    </div>
  );
}

/* ================== Рекомендации (карточка/таблица) ================== */
function PickCard(props) {
  var p = props.pick;
  var kFull = kellyFraction(p.p, p.odds) || 0;
  var kRec = Math.max(0, kFull * (props.kellyCoef || 0.25));
  return (
    <div className="rounded-2xl border bg-white shadow-sm hover:shadow-md transition-shadow overflow-hidden">
      <div className="flex items-center justify-between px-4 py-2 bg-gradient-to-r from-slate-50 to-white border-b">
        <div />
        <div className="flex items-center gap-2">
          {!isNil(p.ev) ? <EVBadge ev={p.ev} /> : null}
          <Badge color="blue">{p.label}</Badge>
        </div>
      </div>
      <div className="p-4 flex flex-col gap-3">
        <div className="text-xs text-gray-500">Дата: {p.date}</div>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Img src={teamLogoSrc(p.home_team_id)} alt={p.home_team} size={28} className="rounded" />
            <div className="text-base md:text-lg font-semibold text-gray-900">{p.home_team}</div>
          </div>
          <span className="text-gray-400">vs</span>
          <div className="flex items-center gap-2">
            <div className="text-base md:text-lg font-semibold text-gray-900 text-right">{p.away_team}</div>
            <Img src={teamLogoSrc(p.away_team_id)} alt={p.away_team} size={28} className="rounded" />
          </div>
        </div>
        <div className="grid grid-cols-4 gap-3 text-sm">
          <div className="rounded-xl bg-gray-50 p-3"><div className="text-gray-500">Ставка</div><div className="font-semibold"><Badge color="blue">{p.label}</Badge></div></div>
          <div className="rounded-xl bg-gray-50 p-3"><div className="text-gray-500">p</div><div className="font-semibold">{fmtPct(p.p, 0)}</div></div>
          <div className="rounded-xl bg-gray-50 p-3"><div className="text-gray-500">odds</div><div className="font-semibold">{fmtNum(p.odds, 2)}</div></div>
          <div className="rounded-xl bg-gray-50 p-3"><div className="text-gray-500">EV</div><div className="font-semibold">{fmtPct(p.ev, 1)}</div></div>
        </div>
        <div className="grid grid-cols-2 gap-3 text-sm">
          <div className="rounded-xl bg-gray-50 p-3"><div className="text-gray-500">Kelly (full)</div><div className="font-semibold">{fmtPct(kFull, 1)}</div></div>
          <div className="rounded-xl bg-gray-50 p-3"><div className="text-gray-500">Реком. доля</div><div className="font-semibold">{fmtPct(kRec, 1)}</div></div>
        </div>
      </div>
    </div>
  );
}

function CompactPicksTable(props) {
  var data = props.data || [];
  if (!data.length) return <div className="text-gray-500">Нет рекомендаций.</div>;
  return (
    <div className="overflow-x-auto rounded-2xl border bg-white">
      <table className="min-w-full text-sm">
        <thead className="bg-gray-50">
          <tr className="text-left text-gray-600">
            <th className="px-3 py-2">Матч</th>
            <th className="px-3 py-2">Лига</th>
            <th className="px-3 py-2">Ставка</th>
            <th className="px-3 py-2">p</th>
            <th className="px-3 py-2">odds</th>
            <th className="px-3 py-2">EV</th>
            <th className="px-3 py-2">Kelly</th>
          </tr>
        </thead>
        <tbody>
          {data.map(function(p){
            var k = kellyFraction(p.p, p.odds) || 0;
            return (
              <tr key={p.fixture_id + "-" + p.market + "-" + p.outcome} className="border-t">
                <td className="px-3 py-2 whitespace-nowrap">{p.home_team} <span className="text-gray-400">vs</span> {p.away_team}</td>
                <td className="px-3 py-2">{p.league}</td>
                <td className="px-3 py-2"><Badge color="blue">{p.label}</Badge></td>
                <td className="px-3 py-2 font-mono">{fmtPct(p.p, 0)}</td>
                <td className="px-3 py-2 font-mono">{fmtNum(p.odds, 2)}</td>
                <td className="px-3 py-2 font-mono">{fmtPct(p.ev, 1)}</td>
                <td className="px-3 py-2 font-mono">{fmtPct(k, 1)}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ================== КЭШ (NEW) ================== */
const memCache = new Map();
function getLS(key) {
  try { return JSON.parse(localStorage.getItem(key) || "null"); } catch(e){ return null; }
}
function setLS(key, val) {
  try { localStorage.setItem(key, JSON.stringify(val)); } catch(e){}
}
async function fetchJSONCached(url, ttlMs) {
  const now = Date.now();
  const mem = memCache.get(url);
  if (mem && now - mem.t < ttlMs) return mem.v;

  const ls = getLS("cache:" + url);
  if (ls && now - ls.t < ttlMs) {
    memCache.set(url, { t: ls.t, v: ls.v });
    return ls.v;
  }

  const r = await fetch(url);
  if (!r.ok) throw new Error(url + ": " + r.status);
  const v = await r.json();
  memCache.set(url, { t: now, v });
  setLS("cache:" + url, { t: now, v });
  return v;
}

/* ================== Страница ================== */
export default function BestPicksRoundPage() {
  const navigate = useNavigate();
  const [sp] = useSearchParams();

  const [league, setLeague] = useState(sp.get("league") || "All");
  const [round, setRound] = useState(""); // "" = Все

  const [dataset, setDataset] = useState("all"); // "all" | "recommended"
  const [view, setView] = useState("cards");

  const [includeNobet, setIncludeNobet] = useState(false);
  const [trustSingleBook, setTrustSingleBook] = useState(true);
  const [kellyCoef, setKellyCoef] = useState(0.25);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [matches, setMatches] = useState([]);
  const [upcoming, setUpcoming] = useState([]); // NEW: апкаминг с прогнозом
  const [fixturesRaw, setFixturesRaw] = useState([]);
  const [picksRaw, setPicksRaw] = useState([]);
  const [insightsMap, setInsightsMap] = useState(new Map()); // id -> {ins, triad}

  const range = seasonRange2025();
  const from = range.from, to = range.to;

  useEffect(function(){
    async function fetchAll() {
      setLoading(true);
      setError("");
      try {
        // matches_v3 (сыгранные) — с кэшем
        const qs1 = new URLSearchParams({ from_date: from, to_date: to, season: FIXED_SEASON });
        const data1 = await fetchJSONCached("http://localhost:8001/api/matches_v3?" + qs1.toString(), TTL_MATCHES);
        const matchesList = Array.isArray(data1) ? data1 : [];
        setMatches(matchesList);

        // NEW: upcoming по топ-лигам — только где уже есть прогноз
        const upPromises = TOP_LEAGUES.map(function(L){
          const qsU = new URLSearchParams({ league: L, season: FIXED_SEASON });
          return fetchJSONCached("http://localhost:8001/api/matches_v3?" + qsU.toString(), TTL_UPCOMING)
            .then(function(arr){
              return (arr || []).filter(function(x){
                return (x && (x.p_home != null || x.p_over25 != null || x.signal_market != null));
              }).map(function(x){
                return {
                  fixture_id: x.fixture_id,
                  date: parseScheduleISO(x.datetime, x.season) || x.datetime,
                  league: x.league,
                  season: x.season,
                  round: x.round_label,
                  home_team: x.home_team,
                  away_team: x.away_team,
                  home_team_id: x.home_team_id,
                  away_team_id: x.away_team_id,
                  // тройка вероятностей — пригодится как фоллбек, если инсайт не придёт
                  p_home: x.p_home, p_draw: x.p_draw, p_away: x.p_away,
                  avg_odds_home: x.avg_odds_home, avg_odds_draw: x.avg_odds_draw, avg_odds_away: x.avg_odds_away
                };
              });
            });
        });
        const upAll = await Promise.all(upPromises);
        const upcomingList = [].concat.apply([], upAll);
        setUpcoming(upcomingList);

        // best-picks (офферы/фичи) — с кэшем
        const qs2 = new URLSearchParams({
          from_date: from,
          to_date: to,
          include_nobet: String(includeNobet),
          trust_single_book: String(trustSingleBook),
          top_n: "80",
          limit_pairs_each: "8",
          limit_triples_each: "8",
          return_fixtures: "true",
        });
        const data2 = await fetchJSONCached("http://localhost:8001/api/best-picks?" + qs2.toString(), TTL_BESTPICKS);
        setPicksRaw(valOr(data2 && data2.picks, []));
        setFixturesRaw(valOr(data2 && data2.fixtures, []));

        // инсайты по всем ID (сыгранные + апкаминг) — с кэшем
        var ids = matchesList.map(function(m){ return m.fixture_id; })
          .concat(upcomingList.map(function(m){ return m.fixture_id; }));
        ids = Array.from(new Set(ids));
        var map = new Map();

        if (USE_INSIGHTS && ids.length) {
          try {
            const raw = await fetchJSONCached("http://localhost:8001/api/fixture-insights?fixture_ids=" + ids.join(","), TTL_INSIGHTS);
            Object.keys(raw || {}).forEach(function(k){
              var parsed = normalizePayload(raw[k]);
              map.set(Number(k), parsed);
            });
          } catch(e) { /* ignore */ }

          // доп. фоллбек через /api/match-insight — только для тех, кого нет
          var missing = ids.filter(function(id){ return !map.has(id); });
          if (missing.length) {
            const promises = missing.map(function(id){ return fetch("http://localhost:8001/api/match-insight?fixture_id=" + id); });
            const results = await Promise.allSettled(promises);
            for (var i=0;i<results.length;i++){
              var rr = results[i];
              if (rr.status === "fulfilled" && rr.value && rr.value.ok) {
                try {
                  const payload = await rr.value.json();
                  map.set(missing[i], normalizePayload(payload));
                } catch(e) { /* ignore */ }
              }
            }
          }
        }
        setInsightsMap(map);
      } catch(e) {
        setError(e.message || String(e));
      } finally {
        setLoading(false);
      }
    }
    fetchAll();
  }, [from, to, includeNobet, trustSingleBook]);

  const offersByFixture = useMemo(function(){
    var m = new Map();
    (fixturesRaw || []).forEach(function(f){
      m.set(f.fixture_id, frontPruneOffers(f.offers || [], f.league));
    });
    return m;
  }, [fixturesRaw]);

  // NEW: фоллбек-триада из самой фикстуры (если инсайт не принёс triad)
  function triadFromFixture(f) {
    var hasP = !isNil(f.p_home) || !isNil(f.p_draw) || !isNil(f.p_away);
    var hasO = !isNil(f.avg_odds_home) || !isNil(f.avg_odds_draw) || !isNil(f.avg_odds_away);
    if (!hasP && !hasO) return null;
    return {
      pH: f.p_home, pD: f.p_draw, pA: f.p_away,
      odH: f.avg_odds_home, odD: f.avg_odds_draw, odA: f.avg_odds_away
    };
  }

  // ВСЕ фикстуры: сыгранные + будущие, плюс приклеиваем инсайты/триаду
  const fixturesAll = useMemo(function(){
    var rows = (matches || []).concat(upcoming || []);
    return rows.map(function(f){
      var bundle = insightsMap.get(f.fixture_id) || { ins: null, triad: null };
      var tri = bundle.triad || triadFromFixture(f);
      return Object.assign({}, f, { _insights: bundle.ins, _triad: tri });
    });
  }, [matches, upcoming, insightsMap]);

  /* ====== Лиги/раунды ====== */
  const leagues = useMemo(function(){
    var s = new Set();
    fixturesAll.forEach(function(m){ if (m && m.league) s.add(m.league); });
    var arr = Array.from(s).sort();
    arr.unshift("All");
    return arr;
  }, [fixturesAll]);

  const rounds = useMemo(function(){
    if (league === "All") return [];
    var s = new Set();
    fixturesAll.forEach(function(m){
      if (m.league === league && !isNil(m.round)) s.add(normalizeRound(m.round));
    });
    return Array.from(s).sort(function(a,b){ return roundSortKey(a) - roundSortKey(b); });
  }, [league, fixturesAll]);

  useEffect(function(){
    if (league === "All") setRound("");
    else {
      if (round && rounds.indexOf(round) === -1) setRound("");
    }
  }, [league, rounds]);

  // выбранные фикстуры + фильтр по нормализованному round
  const selectedFixtures = useMemo(function(){
    var base = fixturesAll
      .filter(function(f){ return league === "All" ? true : f.league === league; })
      .filter(function(f){ return round ? normalizeRound(f.round) === round : true; })
      .sort(by("date", "asc"));

    return base.filter(function(f){
      var offers = offersByFixture.get(f.fixture_id) || [];
      var has1x2 = offers.some(function(o){ return o.market === "1X2"; });
      var hasOU  = offers.some(function(o){ return o.market === "OU25"; });
      return has1x2 || hasOU || !!f._triad;
    });
  }, [fixturesAll, league, round, offersByFixture]);

  /* ================== UI ================== */
  return (
    <div className="mx-auto max-w-7xl p-4">
      {/* back */}
      <div className="mb-3">
        <button onClick={function(){ navigate(HOME_URL); }} className="inline-flex items-center gap-2 text-sm text-gray-700 hover:text-black" title="На главную">
          <span>←</span> <span>На главную</span>
        </button>
      </div>

      {/* hero */}
      <div className="rounded-3xl bg-gradient-to-r from-slate-900 via-indigo-900 to-sky-900 text-white p-6 mb-4 shadow-md">
        <h1 className="text-2xl font-bold mb-2">Подборки по раундам — сезон 2025</h1>
        <p className="text-slate-200">На каждый матч — две ставки: исход и тотал 2.5. Пояснения: форма, голы, H2H и триада рыночных шансов (П1/Х/П2).</p>
      </div>

      {/* legend */}
      <div className="mb-6">
        <ColorLegend />
      </div>

      {/* filters */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-3 mb-3">
        <div className="flex flex-col">
          <label className="text-xs text-gray-500 mb-1">Сезон</label>
          <input value={FIXED_SEASON} className="rounded-xl border px-3 py-2 bg-gray-50 text-gray-600" disabled />
        </div>
        <div className="flex flex-col">
          <label className="text-xs text-gray-500 mb-1">Лига</label>
          <select value={league} onChange={function(e){ setLeague(e.target.value); }} className="rounded-xl border px-3 py-2">
            {leagues.map(function(l){ return <option key={l} value={l}>{l}</option>; })}
          </select>
        </div>
        <div className="flex flex-col">
          <label className="text-xs text-gray-500 mb-1">Раунд</label>
          <select
            value={round}
            onChange={function(e){ setRound(e.target.value); }}
            className="rounded-xl border px-3 py-2"
            disabled={league === "All"}
          >
            <option value="">Все</option>
            {league !== "All" && rounds.length === 0 ? <option value="" disabled>— нет раундов —</option> : null}
            {league !== "All" && rounds.map(function(r){ return <option key={r} value={r}>{r}</option>; })}
          </select>
        </div>
        <div className="flex flex-col">
          <label className="text-xs text-gray-500 mb-1">Данные</label>
          <div className="flex gap-2">
            <button className={"px-3 py-2 rounded-xl border " + (dataset === "all" ? "bg-black text-white" : "bg-white text-gray-700")} onClick={function(){ setDataset("all"); setView("cards"); }}>
              Все матчи (карточки)
            </button>
            <button className={"px-3 py-2 rounded-xl border " + (dataset === "recommended" ? "bg-black text-white" : "bg-white text-gray-700")} onClick={function(){ setDataset("recommended"); }}>
              Рекомендации
            </button>
          </div>
        </div>
        <div className="flex items-end gap-2">
          <span className="text-xs text-gray-500 mr-2">Kelly ×</span>
          <input type="range" min={0.1} max={0.5} step={0.05} value={kellyCoef} onChange={function(e){ setKellyCoef(Number(e.target.value)); }} className="w-full" />
          <div className="w-14 text-right text-sm font-mono">{Math.round(kellyCoef * 100)}%</div>
        </div>
      </div>

      {/* secondary */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-3 mb-6">
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input type="checkbox" checked={includeNobet} onChange={function(e){ setIncludeNobet(e.target.checked); }} />
            Включать nobet (для выдачи рекомендаций)
          </label>
        </div>
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input type="checkbox" checked={trustSingleBook} onChange={function(e){ setTrustSingleBook(e.target.checked); }} />
            Доверять 1 бук-ру
          </label>
        </div>
        <div className="flex items-center gap-3 text-sm text-gray-500">
          <span>Карточки строятся для матчей с рынками 1X2/Тотал 2.5 или с триадой вероятностей из бэкенда.</span>
        </div>
      </div>

      {loading ? <div className="text-gray-600">Загружаем…</div> : null}
      {error ? <div className="text-red-600">Ошибка: {error}</div> : null}

      {/* ВСЕ МАТЧИ: двойные карточки */}
      {dataset === "all" && !loading && !error && (
        <>
          {league !== "All" && (
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-xl font-semibold text-gray-900 flex items-center gap-2">
                <Img src={leagueLogoSrc(league)} alt={league} size={24} />
                <span>{league} — {round ? prettyRound(round) : "Все раунды"}</span>
              </h2>
              <div className="text-sm text-gray-500">Матчей: {selectedFixtures.length}</div>
            </div>
          )}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 mb-8">
            {selectedFixtures.map(function(f){
              return (
                <DualCard
                  key={f.fixture_id}
                  fixture={f}
                  offers={valOr(offersByFixture.get(f.fixture_id), [])}
                  ins={f._insights}
                  triad={f._triad}
                  kellyCoef={kellyCoef}
                />
              );
            })}
          </div>
          {league === "All" && !selectedFixtures.length ? <div className="text-gray-500">Нет матчей с доступным прогнозом.</div> : null}
        </>
      )}

      {/* РЕКОМЕНДАЦИИ */}
      {dataset === "recommended" && league !== "All" && !loading && !error && (
        <>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-xl font-semibold text-gray-900 flex items-center gap-2">
              <Img src={leagueLogoSrc(league)} alt={league} size={24} />
              <span>{league} — {round || "Все"}</span>
            </h2>
          </div>

          {view === "cards" ? (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 mb-8">
              {(picksRaw || [])
                .filter(function(p){ return p.league === league && (round ? normalizeRound(p.round) === round : true); })
                .map(function(p){
                  var f = (matches || []).find(function(m){ return m.fixture_id === p.fixture_id; }) || {};
                  return <PickCard key={p.fixture_id + "-" + p.market + "-" + p.outcome} pick={Object.assign({}, p, f)} kellyCoef={kellyCoef} />;
                })}
            </div>
          ) : (
            <div className="mb-8">
              <CompactPicksTable
                data={(picksRaw || [])
                  .filter(function(p){ return p.league === league && (round ? normalizeRound(p.round) === round : true); })
                  .map(function(p){
                    var f = (matches || []).find(function(m){ return m.fixture_id === p.fixture_id; }) || {};
                    return Object.assign({}, p, f);
                  })}
              />
            </div>
          )}
        </>
      )}

      {dataset === "recommended" && league === "All" && !loading && !error ? (
        <div className="text-gray-500">Выбери конкретную лигу для просмотра рекомендаций.</div>
      ) : null}
    </div>
  );
}
