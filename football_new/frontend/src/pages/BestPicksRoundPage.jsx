// src/pages/BestPicksRoundPage.jsx
// 2025-only. Для каждого матча: ДВЕ ставки (Исход + Тотал 2.5) + объяснения.
// EdgeScore Premium Dark (v5): более чистый, премиальный UI без легенды и статуса "зашло/не зашло".
// Акцент на аккуратных карточках, ровных логотипах и мягком glow.

import React, { useEffect, useMemo, useRef, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";
import {
  LEAGUE_ID_BY_NAME,
  decideOutcomeTier,
  decideTotalsTierByEv,
} from "@/lib/policyDecision";
import { buildPolicyNarrative } from "@/lib/policyNarrative";

/* ====== метка сборки для дебага ====== */
const BUILD_TAG = "BestPicks 2025 v5.0 EdgeScore Premium Dark";
if (typeof window !== "undefined") {
  try {
    console.info("[BUILD]", BUILD_TAG);
  } catch (e) {}
}

/* ================== Константы ================== */
const FIXED_SEASON = "2025";
const USE_INSIGHTS = true;
const INCLUDE_NO_BET = false;

const API_ROUTES = {
  matches: "/api/matches_v3",
  upcoming: "/api/matches_v3",
  bestPicks: "/api/best-picks",
  insightsBatch: "/api/fixture-insights",
  insightSingle: "/api/match-insight",
};

const TOP_LEAGUES = [
  "Premier League",
  "La Liga",
  "Bundesliga",
  "Serie A",
  "Ligue 1",
  "Eredivisie",
];

const TTL_MATCHES = 10 * 60 * 1000;
const TTL_UPCOMING = 2 * 60 * 1000;
const TTL_BESTPICKS = 2 * 60 * 1000;
const TTL_INSIGHTS = 5 * 60 * 1000;

const PAGE_SIZE = 24;
const PAGE_STEP = 24;

/* ================== Утилиты ================== */
function isNil(x) {
  return x === undefined || x === null;
}
function valOr(x, d) {
  return isNil(x) ? d : x;
}
function isNum(x) {
  return typeof x === "number" && isFinite(x);
}
function toNum(x) {
  const v = Number(x);
  return isFinite(v) ? v : null;
}
function toInt(x) {
  const v = Number(x);
  return isFinite(v) ? Math.trunc(v) : null;
}
function firstDefined() {
  for (var i = 0; i < arguments.length; i++) {
    var v = arguments[i];
    if (v !== undefined && v !== null) return v;
  }
  return null;
}
function normalizeRound(x) {
  return String(isNil(x) ? "" : x).trim();
}
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
  const pp = Number(p),
    oo = Number(odds);
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
  return function (a, b) {
    const va = a ? a[key] : undefined;
    const vb = b ? b[key] : undefined;
    if (va === vb) return 0;
    const r = va > vb ? 1 : -1;
    return dir === "asc" ? r : -r;
  };
}
function roundSortKey(r) {
  if (!r) return 0;
  const m = String(r).match(/(\d+)/);
  return m ? Number(m[1]) : 0;
}
function prettyRound(r) {
  return !r || r === "Unknown" ? "Все раунды" : r;
}

/* ================== Сезон 2025 ================== */
function seasonRange2025() {
  const y = 2025;
  return { from: y + "-07-01", to: y + 1 + "-06-30" };
}

// 'DD.MM HH:MM' → 'YYYY-MM-DD HH:MM' (ISO пропускаем)
function parseScheduleISO(datetimeDMHM, seasonStr) {
  if (!datetimeDMHM) return "";
  var s = String(datetimeDMHM);
  if (s.indexOf("-") >= 0) return s;
  const parts = s.split(" ");
  if (parts.length < 2) return "";
  const dm = parts[0].split(".");
  const hm = parts[1];
  if (dm.length < 2) return "";
  const dd = ("" + dm[0]).padStart(2, "0");
  const mm = ("" + dm[1]).padStart(2, "0");
  const yyyy = String(seasonStr || "2025");
  return yyyy + "-" + mm + "-" + dd + " " + hm;
}

/* ================== Лого ================== */
const LEAGUE_LOGO_FILE = {
  "Premier League": "Premier_League.png",
  "La Liga": "La_Liga.png",
  Bundesliga: "Bundesliga.png",
  "Serie A": "Serie_A.png",
  "Ligue 1": "Ligue_1.png",
  Eredivisie: "Eredivisie.png",
};
function leagueLogoSrc(name) {
  return "/icons/" + (LEAGUE_LOGO_FILE[name] || "");
}

// базовая картинка (используем только для лиг)
function Img(props) {
  const size = valOr(props.size, 22);
  return (
    <img
      src={props.src}
      alt={props.alt}
      width={size}
      height={size}
      className={props.className}
      onError={function (e) {
        e.currentTarget.style.display = "none";
      }}
      onClick={props.onClick}
      title={props.title}
    />
  );
}

// аккуратное отображение логотипов команд — как в Календаре
const teamLogoPath = (id) => (id ? `/icons/team_logos/${id}.png` : null);
const fallbackTeam = (name) =>
  (teamLogoMap && teamLogoMap[name]) || "/icons/team_logos/default.png";

function TeamLogo({ teamId, teamName, league, onOpenTeam }) {
  const src = teamLogoPath(teamId) || fallbackTeam(teamName);

  function handleClick(e) {
    if (!teamId) return;
    if (e.metaKey || e.ctrlKey) {
      window.open(
        "/team/" +
          teamId +
          "?league=" +
          encodeURIComponent(league || "") +
          "&season=" +
          FIXED_SEASON,
        "_blank"
      );
      return;
    }
    if (onOpenTeam) onOpenTeam(teamId);
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      className="flex items-center justify-center rounded-full
                 w-7 h-7 sm:w-8 sm:h-8
                 bg-white/[0.04] ring-1 ring-white/10
                 shadow-[0_6px_18px_rgba(0,0,0,0.35)]
                 hover:ring-white/20 transition"
      title={teamName || "Команда"}
    >
      <SafeImg
        src={src}
        alt={teamName}
        className="w-5 h-5 sm:w-6 sm:h-6 object-contain"
      />
    </button>
  );
}

/* ================== UI ================== */

function Pill(props) {
  var color = valOr(props.color, "gray");
  var palette = {
    gray:
      "bg-surface-3/80 text-slate-200 ring-1 ring-slate-700/70 shadow-inner",
    amber:
      "bg-amber-400/15 text-amber-100 ring-1 ring-amber-400/50 shadow-inner",
    green:
      "bg-emerald-400/15 text-emerald-100 ring-1 ring-emerald-400/60 shadow-inner",
    blue:
      "bg-sky-400/15 text-sky-100 ring-1 ring-sky-400/60 shadow-inner",
    rose:
      "bg-rose-400/15 text-rose-100 ring-1 ring-rose-400/60 shadow-inner",
    indigo:
      "bg-indigo-400/15 text-indigo-100 ring-1 ring-indigo-400/60 shadow-inner",
    fuchsia:
      "bg-fuchsia-400/15 text-fuchsia-100 ring-1 ring-fuchsia-400/60 shadow-inner",
    pink:
      "bg-pink-400/15 text-pink-100 ring-1 ring-pink-400/60 shadow-inner",
  };
  return (
    <span
      className={
        "inline-flex items-center px-3 py-1 rounded-full text-[11px] font-semibold " +
        (palette[color] || palette.gray) +
        " " +
        (props.className || "")
      }
    >
      {props.children}
    </span>
  );
}
function Dot(props) {
  return (
    <span
      className={
        "inline-block w-2 h-2 rounded-full " +
        (props.className || "bg-slate-400")
      }
    ></span>
  );
}
function EVPill(props) {
  var e = Number(valOr(props.ev, 0));
  var tone = "gray";
  if (e >= 0.15) tone = "green";
  else if (e >= 0.05) tone = "amber";
  return <Pill color={tone}>EV {fmtPct(e)}</Pill>;
}

/* ================== Лимиты по лигам ================== */
function leagueFrontTuning(leagueName) {
  const L = String(leagueName || "").toLowerCase();
  var base = {
    oddsHardCapAbs: 9.0,
    oddsMax1x2: 7.0,
    oddsMaxDraw: 6.0,
    minPDraw: 0.28,
    drawCloseGap: 0.06,
  };
  if (L.indexOf("bundes") >= 0)
    return {
      oddsHardCapAbs: 8.5,
      oddsMax1x2: 6.5,
      oddsMaxDraw: 5.75,
      minPDraw: 0.3,
      drawCloseGap: 0.055,
    };
  if (
    L.indexOf("la liga") >= 0 ||
    L.indexOf("laliga") >= 0 ||
    L.indexOf("primera") >= 0
  )
    return {
      oddsHardCapAbs: 8.5,
      oddsMax1x2: 6.5,
      oddsMaxDraw: 5.75,
      minPDraw: 0.29,
      drawCloseGap: 0.06,
    };
  return base;
}

/* ================== Helpers ================== */
function extractPAH(offers) {
  var pH = null,
    pA = null,
    pD = null,
    odH = null,
    odA = null,
    odD = null;
  (offers || []).forEach(function (o) {
    if (o.market === "1X2") {
      if (o.outcome === "home") {
        pH = o.p;
        odH = o.odds;
      }
      if (o.outcome === "away") {
        pA = o.p;
        odA = o.odds;
      }
      if (o.outcome === "draw") {
        pD = o.p;
        odD = o.odds;
      }
    }
  });
  return { pH: pH, pA: pA, pD: pD, odH: odH, odA: odA, odD: odD };
}

function assessRec(rec, leagueName) {
  if (!rec) return { status: "skip", reasons: ["нет ставки"], tier: "NO BET" };
  if (rec.saved && rec.tier) {
    const savedTier = String(rec.tier).toUpperCase();
    if (savedTier === "A") return { status: "hot", reasons: [], tier: "A" };
    if (savedTier === "B") return { status: "ok", reasons: [], tier: "B" };
  }
  var leagueId = LEAGUE_ID_BY_NAME[leagueName] || null;
  var p = Number(rec.p);
  var odds = Number(rec.odds);
  var ev = isNum(rec.ev) ? rec.ev : calcEV(p, odds);
  var tier =
    rec.market === "1X2"
      ? decideOutcomeTier(ev, odds, leagueId, String(rec.outcome || "").toLowerCase())
      : decideTotalsTierByEv(ev, odds);

  if (tier === "A") return { status: "hot", reasons: [], tier: "A" };
  if (tier === "B") return { status: "ok", reasons: [], tier: "B" };
  return { status: "skip", reasons: ["ниже порога policy"], tier: "NO BET" };
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
    var ww = Number(any.w || 0),
      dd = Number(any.d || 0),
      ll = Number(any.l || 0);
    return { w: ww, d: dd, l: ll, txt: ww + "-" + dd + "-" + ll };
  }
  return null;
}

/* return {ins, triad} */
function normalizePayload(payload) {
  if (!payload) return { ins: null, triad: null };
  if (payload.insights) {
    var tri = null;
    if (payload.probs_1x2 || payload.odds_1x2) {
      tri = {
        pH: payload.probs_1x2 ? payload.probs_1x2.home : null,
        pD: payload.probs_1x2 ? payload.probs_1x2.draw : null,
        pA: payload.probs_1x2 ? payload.probs_1x2.away : null,
        odH: payload.odds_1x2 ? payload.odds_1x2.home : null,
        odD: payload.odds_1x2 ? payload.odds_1x2.draw : null,
        odA: payload.odds_1x2 ? payload.odds_1x2.away : null,
      };
    }
    return { ins: payload.insights, triad: tri };
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
        odA: payload.odds_1x2 ? payload.odds_1x2.away : null,
      };
    }
    return { ins: payload.insights || null, triad: tri2 };
  }
  if (payload.metrics && payload.metrics.form) {
    var h = payload.metrics.form.home || {};
    var a = payload.metrics.form.away || {};
    var h2h = payload.metrics.h2h || {};
    var players = payload.players || { home: [], away: [] };
    var gfH = isNum(h.gf) ? h.gf : null,
      gaH = isNum(h.ga) ? h.ga : null,
      gfA = isNum(a.gf) ? a.gf : null,
      gaA = isNum(a.ga) ? a.ga : null;
    var insOld = {
      home: {
        name: payload.home_team,
        form: { w: h.w || 0, d: h.d || 0, l: h.l || 0 },
        gf_last5: gfH,
        ga_last5: gaH,
      },
      away: {
        name: payload.away_team,
        form: { w: a.w || 0, d: a.d || 0, l: a.l || 0 },
        gf_last5: gfA,
        ga_last5: gaA,
      },
      totals: {
        avg_goals_last10: isNum(gfH) && isNum(gfA) ? gfH + gfA : null,
        under25_rate_last10: null,
      },
      h2h: {
        home_wins: h2h.w || 0,
        draws: h2h.d || 0,
        away_wins: h2h.l || 0,
      },
      top_scorers: {
        home: (players.home || []).map(function (p) {
          return { name: p.name, g_last5: p.g || 0 };
        }),
        away: (players.away || []).map(function (p) {
          return { name: p.name, g_last5: p.g || 0 };
        }),
      },
    };
    return { ins: insOld, triad: null };
  }
  return { ins: null, triad: null };
}

/* ================== Объяснения ================== */
var LABELS = {
  outcome: { home: "П1", away: "П2", draw: "Х" },
  ou: { over: "ТБ 2.5", under: "ТМ 2.5" },
};

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
      if (isNum(hf) && isNum(af) && hf <= 1.2 && af <= 1.2)
        parts.push(
          "Низкая продуктивность атаки: хозяева " +
            hf.toFixed(1) +
            " г/м, гости " +
            af.toFixed(1) +
            " г/м (5)."
        );
      if (isNum(hg) && isNum(ag) && hg <= 1.0 && ag <= 1.0)
        parts.push(
          "Надёжная оборона: пропускают " +
            hg.toFixed(1) +
            " и " +
            ag.toFixed(1) +
            " г/м."
        );
      if (isNum(avg10) && isNum(uRate))
        parts.push(
          "Средняя результативность " +
            avg10.toFixed(1) +
            " г/м за 10; U2.5=" +
            Math.round(uRate * 100) +
            "%."
        );
    } else {
      if (isNum(hf) && hf >= 1.5)
        parts.push("Хозяева много создают: " + hf.toFixed(1) + " г/м.");
      if (isNum(af) && af >= 1.5)
        parts.push("Гости опасны: " + af.toFixed(1) + " г/м.");
      if (isNum(hg) && hg >= 1.3)
        parts.push(
          "Хозяева позволяют: " + hg.toFixed(1) + " г/м пропущенных."
        );
      if (isNum(ag) && ag >= 1.3)
        parts.push(
          "Гости позволяют: " + ag.toFixed(1) + " г/м пропущенных."
        );
      if (isNum(avg10))
        parts.push(
          "Средняя результативность около " +
            avg10.toFixed(1) +
            " г/м — предпосылки к «верху»."
        );
    }
  }
  if (parts.length === 0 && offers && offers.length) {
    var ou = offers.filter(function (o) {
      return o.market === "OU25";
    });
    var over = null,
      under = null;
    for (var i = 0; i < ou.length; i++) {
      if (String(ou[i].outcome).toLowerCase() === "over") over = ou[i];
      if (String(ou[i].outcome).toLowerCase() === "under") under = ou[i];
    }
    var pick = choice === "under" ? under : over;
    if (pick && pick.p != null && pick.odds != null) {
      var imp = impliedFromOdds(pick.odds);
      var edge = !isNil(pick.p) && !isNil(imp) ? pick.p - imp : null;
      parts.push(
        "Модель склоняется к " +
          LABELS.ou[choice] +
          ": p " +
          fmtPct(pick.p, 0) +
          ", имплайд " +
          fmtPct(imp, 0) +
          (edge != null ? ", запас " + fmtPct(edge, 1) + "." : ".")
      );
    } else {
      parts.push(
        "Профиль матча указывает на " +
          (choice === "under" ? "низ" : "верх") +
          " по тоталу 2.5."
      );
    }
  }
  return parts.join(" ");
}

function explainOutcome(ins, side, tri) {
  var parts = [];
  if (tri && (!isNil(tri.pH) || !isNil(tri.pD) || !isNil(tri.pA))) {
    parts.push(
      "Рынок: П1 " +
        fmtPct(tri.pH, 0) +
        " | Х " +
        fmtPct(tri.pD, 0) +
        " | П2 " +
        fmtPct(tri.pA, 0) +
        "."
    );
  }
  if (ins) {
    var hForm = formLabel(
      valOr(ins.home && (ins.home.form_last5 || ins.home.form), null)
    );
    var aForm = formLabel(
      valOr(ins.away && (ins.away.form_last5 || ins.away.form), null)
    );
    var hf = valOr(ins.home && ins.home.gf_last5, null);
    var af = valOr(ins.away && ins.away.gf_last5, null);
    var hg = valOr(ins.home && ins.home.ga_last5, null);
    var ag = valOr(ins.away && ins.away.ga_last5, null);
    var h2h = ins.h2h || {};
    var homePts = hForm ? hForm.w * 3 + hForm.d : 0;
    var awayPts = aForm ? aForm.w * 3 + aForm.d : 0;

    if (side === "home") {
      if (homePts - awayPts >= 4)
        parts.push(
          "Форма лучше: " +
            (hForm ? hForm.txt : "-") +
            " против " +
            (aForm ? aForm.txt : "-") +
            " (посл. 5)."
        );
      if (isNum(hf) && hf >= 1.5)
        parts.push("Хозяева забивают: " + hf.toFixed(1) + " г/м.");
      if (isNum(ag) && ag >= 1.3)
        parts.push("Гости позволяют: " + ag.toFixed(1) + " г/м проп.");
    } else if (side === "away") {
      if (awayPts - homePts >= 4)
        parts.push(
          "Гости в лучшей форме: " +
            (aForm ? aForm.txt : "-") +
            " против " +
            (hForm ? hForm.txt : "-") +
            " (посл. 5)."
        );
      if (isNum(af) && af >= 1.5)
        parts.push("Гости остры в атаке: " + af.toFixed(1) + " г/м.");
      if (isNum(hg) && hg >= 1.3)
        parts.push("Хозяева уязвимы: " + hg.toFixed(1) + " г/м проп.");
    } else {
      parts.push("Матч близкий по силам — шансы сопоставимы.");
    }
    if (
      valOr(h2h.home_wins, 0) +
        valOr(h2h.away_wins, 0) +
        valOr(h2h.draws, 0) >
      0
    ) {
      parts.push(
        "Очные: " +
          valOr(h2h.home_wins, 0) +
          "-" +
          valOr(h2h.draws, 0) +
          "-" +
          valOr(h2h.away_wins, 0) +
          " со стороны хозяев."
      );
    }
  }
  return parts.join(" ");
}

/* ================== Прунинг офферов ================== */
function frontPruneOffers(offers, leagueName) {
  var lt = leagueFrontTuning(leagueName);
  if (!offers || !offers.length) return [];
  var out = [];
  for (var i = 0; i < offers.length; i++) {
    var o = offers[i];
    if (o.market === "OU25") {
      var ev = !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds);
      if (o.p === undefined || o.p === null) continue;
      out.push(
        Object.assign({}, o, {
          ev: ev,
        })
      );
      continue;
    }
    if (o.market === "1X2") {
      var odds = Number(o.odds || 0);
      if (odds >= lt.oddsHardCapAbs) continue;
      out.push(
        Object.assign({}, o, {
          ev: !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds),
        })
      );
    }
  }
  return out.sort(function (a, b) {
    var msA = !isNil(a.model_score) ? a.model_score : -1;
    var msB = !isNil(b.model_score) ? b.model_score : -1;
    if (msA !== msB) return msB - msA;
    var evA = !isNil(a.ev) ? a.ev : -1;
    var evB = !isNil(b.ev) ? b.ev : -1;
    return evB - evA;
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
function chooseTotals(offers, ins, fixture) {
  var ou = (offers || [])
    .filter(function (o) {
      return o.market === "OU25";
    })
    .map(function (o) {
      return Object.assign({}, o, {
        ev: !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds),
      });
    });

  if (fixture) {
    if (!isNil(fixture.p_over25)) {
      ou.push({
        market: "OU25",
        outcome: "over",
        p: fixture.p_over25,
        odds: fixture.avg_odds_over25,
        ev: !isNil(fixture.ev_over)
          ? fixture.ev_over
          : calcEV(fixture.p_over25, fixture.avg_odds_over25),
        _source: "fixture",
      });
    }
    if (!isNil(fixture.p_under25)) {
      ou.push({
        market: "OU25",
        outcome: "under",
        p: fixture.p_under25,
        odds: fixture.avg_odds_under25,
        ev: !isNil(fixture.ev_under)
          ? fixture.ev_under
          : calcEV(fixture.p_under25, fixture.avg_odds_under25),
        _source: "fixture",
      });
    }
  }

  if (ou.length) {
    var under =
      ou
        .filter(function (o) {
          return String(o.outcome).toLowerCase() === "under";
        })
        .sort(function (a, b) {
          return valOr(b.ev, -999) - valOr(a.ev, -999);
        })[0] || null;
    var over =
      ou
        .filter(function (o) {
          return String(o.outcome).toLowerCase() === "over";
        })
        .sort(function (a, b) {
          return valOr(b.ev, -999) - valOr(a.ev, -999);
        })[0] || null;

    var pref = preferUnderByInsights(ins || null);
    var best = null;

    if (pref === true && under && isNum(under.ev) && under.ev > 0) best = under;
    if (pref === false && over && isNum(over.ev) && over.ev > 0) best = over;
    if (!best) {
      best =
        ou
          .slice()
          .sort(function (a, b) {
            return valOr(b.ev, -999) - valOr(a.ev, -999);
          })[0] || null;
    }

    if (best) {
      var outKey = String(best.outcome).toLowerCase();
      return {
        market: "OU25",
        outcome: outKey,
        label: LABELS.ou[outKey] || "Тотал 2.5",
        p: valOr(best.p, null),
        odds: valOr(best.odds, null),
        ev: isNum(best.ev)
          ? best.ev
          : !isNil(best.p) && !isNil(best.odds)
          ? calcEV(best.p, best.odds)
          : null,
        _mode: !isNil(best.odds) ? "market" : "model",
        text: explainTotals(ins || null, outKey, offers),
      };
    }
  }

  var pref2 = preferUnderByInsights(ins || null);
  var out2 = pref2 === false ? "over" : "under";
  var pGuess = pref2 === null ? 0.52 : 0.55;
  return {
    market: "OU25",
    outcome: out2,
    label: LABELS.ou[out2],
    p: pGuess,
    odds: null,
    ev: null,
    _mode: "model",
    text: explainTotals(ins || null, out2, offers),
  };
}

function chooseOutcome(offers, leagueName, ins, triad) {
  var lt = leagueFrontTuning(leagueName);
  var oneX2 = (offers || [])
    .filter(function (o) {
      return o.market === "1X2";
    })
    .map(function (o) {
      return Object.assign({}, o, {
        ev: !isNil(o.ev) ? o.ev : calcEV(o.p, o.odds),
      });
    });

  var tri = triad || extractPAH(oneX2);
  var pH = tri ? tri.pH : null,
    pA = tri ? tri.pA : null,
    pD = tri ? tri.pD : null;
  var odH = tri ? tri.odH : null,
    odA = tri ? tri.odA : null,
    odD = tri ? tri.odD : null;

  var gapClose = 0.07;
  var allowDrawMarket =
    isNum(pH) &&
    isNum(pA) &&
    Math.abs(pH - pA) <= lt.drawCloseGap &&
    isNum(pD) &&
    pD >= lt.minPDraw &&
    isNum(odD) &&
    odD <= lt.oddsMaxDraw;

  var bestHome = null,
    bestAway = null,
    bestDraw = null;
  for (var i = 0; i < oneX2.length; i++) {
    var o = oneX2[i];
    if (o.outcome === "home") {
      if (!bestHome || valOr(o.ev, -1) > valOr(bestHome.ev, -1)) bestHome = o;
    }
    if (o.outcome === "away") {
      if (!bestAway || valOr(o.ev, -1) > valOr(bestAway.ev, -1)) bestAway = o;
    }
    if (o.outcome === "draw") {
      if (!bestDraw || valOr(o.ev, -1) > valOr(bestDraw.ev, -1)) bestDraw = o;
    }
  }

  if (isNum(pH) && isNum(pA) && Math.abs(pH - pA) <= gapClose) {
    var evH = !isNil(pH) && !isNil(odH)
      ? calcEV(pH, odH)
      : valOr(bestHome && bestHome.ev, null);
    var evA = !isNil(pA) && !isNil(odA)
      ? calcEV(pA, odA)
      : valOr(bestAway && bestAway.ev, null);
    var evD = !isNil(pD) && !isNil(odD)
      ? calcEV(pD, odD)
      : valOr(bestDraw && bestDraw.ev, null);

    var side = null,
      sideEV = null;
    if (isNum(evH) || isNum(evA)) {
      if (valOr(evH, -999) >= valOr(evA, -999)) {
        side = "home";
        sideEV = evH;
      } else {
        side = "away";
        sideEV = evA;
      }
    }
    if (
      allowDrawMarket &&
      isNum(evD) &&
      isNum(sideEV) &&
      evD >= sideEV + 0.06
    ) {
      return {
        market: "1X2",
        outcome: "draw",
        label: LABELS.outcome.draw,
        p: pD,
        odds: odD,
        ev: evD,
        _mode: "market",
        text: explainOutcome(ins || null, "draw", tri),
      };
    }
    if (side && isNum(sideEV) && sideEV > 0) {
      var oddsSide = side === "home" ? odH : odA;
      var pSide = side === "home" ? pH : pA;
      return {
        market: "1X2",
        outcome: side,
        label: LABELS.outcome[side],
        p: pSide,
        odds: oddsSide,
        ev: sideEV,
        _mode: "market",
        text: explainOutcome(ins || null, side, tri),
      };
    }
    var sideProb = pH >= pA ? "home" : "away";
    var oddsProb = sideProb === "home" ? odH : odA;
    var pProb = sideProb === "home" ? pH : pA;
    var evProb = calcEV(pProb, oddsProb);
    return {
      market: "1X2",
      outcome: sideProb,
      label: LABELS.outcome[sideProb],
      p: pProb,
      odds: oddsProb,
      ev: evProb,
      _mode: "market",
      text: explainOutcome(ins || null, sideProb, tri),
    };
  }

  var pGap = isNum(pH) && isNum(pA) ? Math.abs(pH - pA) : null;
  var effMin = (function () {
    var core = 0.52;
    if (!isNum(pGap)) return core;
    if (pGap >= 0.1) return Math.max(0.48, core - 0.04);
    if (pGap >= 0.06) return Math.max(0.5, core - 0.02);
    return core;
  })();

  var sideFinal = null;
  if (isNum(pH) && isNum(pA)) {
    var top = pH >= pA ? "home" : "away";
    var pTop = top === "home" ? pH : pA;
    if (pTop >= effMin) sideFinal = top;
  }
  if (!sideFinal && isNum(pH) && isNum(pA))
    sideFinal = pH >= pA ? "home" : "away";

  if (sideFinal) {
    var oddsF = sideFinal === "home" ? odH : odA;
    var pF = sideFinal === "home" ? pH : pA;
    var evF = calcEV(pF, oddsF);
    return {
      market: "1X2",
      outcome: sideFinal,
      label: LABELS.outcome[sideFinal],
      p: pF,
      odds: oddsF,
      ev: evF,
      _mode: "market",
      text: explainOutcome(ins || null, sideFinal, tri),
    };
  }

  var pGuess = 0.5;
  var sideModel = "draw";
  if (isNum(pH) && isNum(pA)) {
    sideModel = Math.max(pH, pA) >= 0.53 ? (pH >= pA ? "home" : "away") : "draw";
    pGuess = sideModel === "draw" ? valOr(pD, 0.3) : Math.max(pH, pA);
  }
  return {
    market: "1X2",
    outcome: sideModel,
    label: LABELS.outcome[sideModel],
    p: clamp01(pGuess),
    odds: null,
    ev: null,
    _mode: "model",
    text: explainOutcome(ins || null, sideModel, tri),
  };
}

/* ================== Простая таблица рекомендаций (опционально) ================== */
function CompactPicksTable(props) {
  var data = props.data || [];
  if (!data.length)
    return (
      <div className="text-slate-300/80">
        Нет рекомендаций по фильтру.
      </div>
    );
  return (
    <div className="glass-card overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-surface-3/90 border-b border-slate-800">
          <tr className="text-left text-slate-200/90">
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
          {data.map(function (p) {
            var k = kellyFraction(p.p, p.odds) || 0;
            return (
              <tr
                key={p.fixture_id + "-" + p.market + "-" + p.outcome}
                className="border-t border-slate-800/70 text-slate-200"
              >
                <td className="px-3 py-2 whitespace-nowrap">
                  {p.home_team}{" "}
                  <span className="text-slate-500">vs</span>{" "}
                  {p.away_team}
                </td>
                <td className="px-3 py-2 text-slate-400">
                  {p.league}
                </td>
                <td className="px-3 py-2">
                  <Pill color="gray">{p.label}</Pill>
                </td>
                <td className="px-3 py-2 font-mono">
                  {fmtPct(p.p, 0)}
                </td>
                <td className="px-3 py-2 font-mono">
                  {fmtNum(p.odds, 2)}
                </td>
                <td className="px-3 py-2 font-mono">
                  {fmtPct(p.ev, 1)}
                </td>
                <td className="px-3 py-2 font-mono">
                  {fmtPct(k, 1)}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ================== КЭШ и загрузка ================== */
const memCache = new Map();
function getLS(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch (e) {
    return null;
  }
}
function setLS(key, val) {
  try {
    localStorage.setItem(key, JSON.stringify(val));
  } catch (e) {}
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
  memCache.set(url, { t: now, v: v });
  setLS("cache:" + url, { t: now, v: v });
  return v;
}

/* ================== Оверлей команды (iframe) ================== */
function TeamOverlayIframe(props) {
  const iframeRef = useRef(null);
  const [ready, setReady] = useState(false);

  var url =
    "/team/" +
    String(props.teamId) +
    "?league=" +
    encodeURIComponent(props.league || "") +
    "&season=" +
    FIXED_SEASON +
    "&embed=1&noHeader=1";

  useEffect(
    function () {
      if (props.visible) setReady(false);
    },
    [props.visible, props.teamId, props.league]
  );

  function stripChrome() {
    try {
      var el = iframeRef.current;
      if (!el) return;
      var doc =
        el.contentDocument ||
        (el.contentWindow && el.contentWindow.document);
      if (!doc) return;

      var selectors = [
        ".sticky.top-0",
        'div[class*="sticky"][class*="top-0"]',
        "header",
        "[data-app-header]",
        ".league-tabs-header",
        ".bg-gradient-to-r.from-rose-100.to-rose-200",
        ".site-header",
        ".app-header",
      ];
      for (var i = 0; i < selectors.length; i++) {
        var list = doc.querySelectorAll(selectors[i]);
        for (var j = 0; j < list.length; j++) {
          list[j].style.display = "none";
        }
      }
      var padders = doc.querySelectorAll(
        '[class*="pt-14"],[class*="pt-16"],[class*="mt-14"],[class*="mt-16"]'
      );
      for (var k = 0; k < padders.length; k++) {
        padders[k].style.paddingTop = "0px";
        padders[k].style.marginTop = "0px";
      }
      if (doc.body) {
        doc.body.style.overflow = "auto";
      }
    } catch (e) {}
  }

  function afterLoad() {
    stripChrome();
    var tries = 0;
    var timer = setInterval(function () {
      stripChrome();
      tries++;
      if (tries >= 10) {
        clearInterval(timer);
        setTimeout(function () {
          setReady(true);
        }, 80);
      }
    }, 80);
  }

  useEffect(
    function () {
      function onKey(e) {
        if (e.key === "Escape" && props.visible) {
          if (props.onClose) props.onClose();
        }
      }
      document.addEventListener("keydown", onKey);
      return function () {
        document.removeEventListener("keydown", onKey);
      };
    },
    [props.visible, props.onClose]
  );

  if (!props.visible) return null;

  return (
    <div className="fixed inset-0 z-[100]" role="dialog" aria-modal="true">
      <div
        className="absolute inset-0 bg-black/50"
        onClick={props.onClose}
      ></div>
      <div className="absolute left-1/2 top-6 -translate-x-1/2 w-[min(1200px,96vw)] h-[min(88vh,900px)] rounded-3xl bg-surface-2 shadow-2xl overflow-hidden border border-glass">
        <div className="h-10 flex items-center justify-between border-b border-glass px-3 bg-gradient-to-r from-violet-600 to-fuchsia-500 text-slate-50">
          <div className="text-sm font-semibold">Страница команды</div>
          <button
            onClick={props.onClose}
            className="h-7 w-7 rounded-full bg-white/10 hover:bg-white/20 grid place-items-center"
          >
            ✕
          </button>
        </div>

        <div className="relative w-full h-[calc(100%-40px)]">
          <iframe
            key={props.teamId}
            ref={iframeRef}
            title="Team"
            src={url}
            className={
              "absolute inset-0 w-full h-full transition-opacity duration-150 " +
              (ready ? "opacity-100" : "opacity-0")
            }
            onLoad={afterLoad}
          />
          {!ready && (
            <div className="absolute inset-0 bg-surface-1 grid place-items-center">
              <div className="animate-pulse text-slate-400 text-sm">
                Загрузка страницы команды…
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

/* ================== Двойная карточка матча (EdgeScore стиль) ================== */
function DualCard(props) {
  const [expanded, setExpanded] = useState(false);
  var fixture = props.fixture;
  var offers = props.offers || [];
  var ins = props.ins || null;
  var tri = props.triad || null;
  var kellyCoef = props.kellyCoef || 0.25;
  var includeNoBet = props.includeNoBet !== false;
  var onOpenTeam = props.onOpenTeam || function () {};

  var decisionProfile = fixture.decision_profile || "";
  var leagueId =
    isNum(fixture.league_id) ? Number(fixture.league_id) : LEAGUE_ID_BY_NAME[fixture.league] || null;
  var decisionTagsRaw = Array.isArray(fixture.decision_tags)
    ? fixture.decision_tags
    : [];
  var decisionTags = decisionTagsRaw.map(function (t) {
    return String(t || "");
  });
  var decisionTagsLc = decisionTags.map(function (t) {
    return t.toLowerCase();
  });
  function hasDecisionTag(tag) {
    if (!tag) return false;
    return decisionTagsLc.indexOf(String(tag).toLowerCase()) >= 0;
  }
  var decisionCloseFlag = !!fixture.decision_close_flag;
  var decisionDrawSwitch = !!fixture.decision_draw_switch;
  var decisionTotalSwitch = !!fixture.decision_total_switch;

  var outcome = chooseOutcome(offers, fixture.league, ins, tri);
  var total = chooseTotals(offers, ins, fixture);
  var outcomeVerdict = assessRec(outcome, fixture.league);
  var totalVerdict = assessRec(total, fixture.league);
  if (!includeNoBet && outcomeVerdict.tier === "NO BET" && totalVerdict.tier === "NO BET") {
    return null;
  }

  function TriadLine() {
    if (!tri) return null;
    var hasProb =
      !isNil(tri.pH) || !isNil(tri.pD) || !isNil(tri.pA);
    var hasOdds =
      !isNil(tri.odH) || !isNil(tri.odD) || !isNil(tri.odA);
    if (!hasProb && !hasOdds) return null;
    return (
      <div className="text-[11px] text-slate-400 mt-1 space-y-0.5">
        {hasProb ? (
          <div>
            Вероятности: П1 {fmtPct(tri.pH, 0)} · Х{" "}
            {fmtPct(tri.pD, 0)} · П2 {fmtPct(tri.pA, 0)}
          </div>
        ) : null}
        {hasOdds ? (
          <div>
            Кэфы: П1 {fmtNum(tri.odH, 2)} · Х{" "}
            {fmtNum(tri.odD, 2)} · П2 {fmtNum(tri.odA, 2)}
          </div>
        ) : null}
      </div>
    );
  }

  function Row(p) {
    var rec = p.rec;
    if (!rec) return null;
    var policyTier =
      rec.market === "1X2"
        ? decideOutcomeTier(
            rec.ev,
            rec.odds,
            leagueId,
            String(rec.outcome || "").toLowerCase()
          )
        : decideTotalsTierByEv(rec.ev, rec.odds);
    var policyText = buildPolicyNarrative({
      market: rec.market === "1X2" ? "1X2" : "TOTAL",
      tier: policyTier,
      pickLabel: rec.label,
      prob: rec.p,
      odds: rec.odds,
      ev: rec.ev,
      home: fixture.home_team,
      away: fixture.away_team,
    });
    var kFull = kellyFraction(rec.p, rec.odds) || 0;
    var kRec = Math.max(0, kFull * kellyCoef);
    var verdict = rec.market === "1X2" ? outcomeVerdict : totalVerdict;
    var decisionHot = false;
    if (p.title === "Исход") {
      if (decisionDrawSwitch || hasDecisionTag("draw switch")) {
        decisionHot = true;
      } else if (decisionCloseFlag && hasDecisionTag("close flagged")) {
        decisionHot = true;
      }
    } else if (p.title === "Тотал 2.5") {
      if (decisionTotalSwitch || hasDecisionTag("total switch")) {
        decisionHot = true;
      }
    }
    var isHot = decisionHot || verdict.status === "hot";
    if (!includeNoBet && verdict.status === "skip") return null;

    return (
      <div className="px-1 py-1 space-y-1">
        <div className="flex flex-wrap items-center gap-2 text-xs sm:text-[13px] font-medium text-slate-50">
          <span className="text-slate-300/90">{p.title}:</span>
          <span className="text-white/90 font-semibold">{rec.label}</span>
          <span className="text-slate-300">
            p {fmtPct(rec.p, 0)} · odds {fmtNum(rec.odds, 2)} · EV{" "}
            <span
              className={
                isNum(rec.ev)
                  ? rec.ev > 0.01
                    ? "text-emerald-300"
                    : rec.ev < -0.01
                    ? "text-rose-300"
                    : "text-white/80"
                  : "text-white/60"
              }
            >
              {isNum(rec.ev) ? fmtPct(rec.ev, 1) : "—"}
            </span>
          </span>
          <span className="flex-1" />
          {verdict.status === "skip" ? (
            <span className="rounded-full border border-rose-400/30 px-2 py-0.5 text-[11px] text-rose-300/90">
              Пропустить
            </span>
          ) : verdict.status === "ok" ? (
            <span className="rounded-full border border-white/15 px-2 py-0.5 text-[11px] text-white/70">
              Наблюдать
            </span>
          ) : (
            <span className="rounded-full border border-emerald-400/35 px-2 py-0.5 text-[11px] text-emerald-300/90">
              Рекомендуется
            </span>
          )}
          {isHot ? (
            <span className="rounded-full border border-white/10 px-2 py-0.5 text-[11px] text-white/60">
              Hot
            </span>
          ) : null}
        </div>
        {p.title === "Исход" ? <TriadLine /> : null}
        {(policyText || rec.text) ? (
          <div className="text-sm leading-relaxed text-slate-200/90">
            {policyText || rec.text}
          </div>
        ) : null}
        {verdict.status === "skip" && verdict.reasons.length ? (
          <div className="text-[12px] text-slate-400">
            Причина: {verdict.reasons.join(", ")}.
          </div>
        ) : null}
      </div>
    );
  }

  function Facts() {
    var lines = [];
    if (ins) {
      var hForm = formLabel(
        valOr(ins.home && (ins.home.form_last5 || ins.home.form), null)
      );
      var aForm = formLabel(
        valOr(ins.away && (ins.away.form_last5 || ins.away.form), null)
      );
      if (hForm) lines.push("Хозяева: серия " + hForm.txt + ".");
      if (aForm) lines.push("Гости: серия " + aForm.txt + ".");
      var hf = valOr(ins.home && ins.home.gf_last5, null);
      var af = valOr(ins.away && ins.away.gf_last5, null);
      var hg = valOr(ins.home && ins.home.ga_last5, null);
      var ag = valOr(ins.away && ins.away.ga_last5, null);
      if (isNum(hf) && isNum(hg))
        lines.push(
          "Хозяева: " +
            hf.toFixed(1) +
            " заб / " +
            hg.toFixed(1) +
            " проп. (5)."
        );
      if (isNum(af) && isNum(ag))
        lines.push(
          "Гости: " +
            af.toFixed(1) +
            " заб / " +
            ag.toFixed(1) +
            " проп. (5)."
        );
      var avg10 = ins.totals ? ins.totals.avg_goals_last10 : null;
      if (isNum(avg10))
        lines.push(
          "Средняя результативность ≈ " +
            avg10.toFixed(1) +
            " г/м."
        );
    } else if (tri) {
      lines.push(
        "Шансы по рынку: П1 " +
          fmtPct(tri.pH, 0) +
          ", Х " +
          fmtPct(tri.pD, 0) +
          ", П2 " +
          fmtPct(tri.pA, 0) +
          "."
      );
    }
    var visible = lines.slice(0, 4);
    if (!visible.length) return null;
    return (
      <div className="px-1 py-1 text-sm text-slate-200">


       <div className="font-semibold text-slate-50 mb-1.5">
          Факты по форме
        </div>
        <ul className="list-disc pl-5 space-y-1.5">
          {visible.map(function (t, i) {
            return <li key={i}>{t}</li>;
          })}
        </ul>
      </div>
    );
  }

  function TeamTitle(props) {
    var name = props.name || "";
    var extra =
      String(name).length > 26
        ? " text-[15px] leading-tight"
        : "";
    return (
      <div
        className={
          "font-semibold text-slate-50 whitespace-normal break-words" +
          extra
        }
      >
        {name}
      </div>
    );
  }

  return (
    <div className="glass-card overflow-hidden">
      <div className="p-4 sm:p-5">
        {/* шапка матча */}
        <div className="flex items-center justify-between gap-2 sm:gap-4">
          <div className="flex items-center gap-3 min-w-0">
            <TeamLogo
              teamId={fixture.home_team_id}
              teamName={fixture.home_team}
              league={fixture.league}
              onOpenTeam={onOpenTeam}
            />
            <TeamTitle name={fixture.home_team} />
          </div>
          <span className="text-slate-500 select-none text-xs sm:text-sm">
            vs
          </span>
          <div className="flex items-center gap-3 min-w-0 justify-end">
            <TeamTitle name={fixture.away_team} />
            <TeamLogo
              teamId={fixture.away_team_id}
              teamName={fixture.away_team}
              league={fixture.league}
              onOpenTeam={onOpenTeam}
            />
          </div>
        </div>

        {/* дата / лига / раунд */}
        <div className="mt-2 text-[11px] sm:text-xs text-slate-400 flex items-center gap-3 flex-wrap">
          <span>
            {fixture.date}
            {fixture.round ? " • " + fixture.round : ""}
            {fixture.league ? " • " + fixture.league : ""}
          </span>
        </div>

        {/* Лучший выбор модели — премиальный CTA */}
        {(function () {
          const cand = [outcome, total]
            .filter(Boolean)
            .map(function (rec) {
              return { rec: rec, verdict: assessRec(rec, fixture.league) };
            });
          const viable = cand.filter(function (c) {
            return c.verdict.status !== "skip" && isNum(c.rec.ev);
          });
          let best = null;
          if (viable.length) {
            best = viable
              .slice()
              .sort(function (a, b) {
                return valOr(b.rec.ev, -999) - valOr(a.rec.ev, -999);
              })[0];
          }

          if (!best) {
            var reasons = [];
            cand.forEach(function (c) {
              (c.verdict.reasons || []).forEach(function (r) {
                if (reasons.indexOf(r) < 0) reasons.push(r);
              });
            });
            return (
              <div className="mt-4 mb-3 border-l border-white/12 pl-3.5 py-1">
                <div className="text-sm font-semibold text-white/80 flex items-center gap-2">
                  Матч рекомендуется пропустить
                </div>
                <div className="mt-1 text-[13px] text-slate-300/85">
                  {reasons.length
                    ? "Причины: " + reasons.join(", ") + "."
                    : "Модель не видит достаточного преимущества по линии рынка."}
                </div>
              </div>
            );
          }
          const tone =
            best.rec.ev > 0.01
              ? "text-emerald-300"
              : best.rec.ev < -0.01
              ? "text-rose-300"
              : "text-slate-300";

          return (
            <div className="mt-4 mb-3 border-l border-white/12 pl-3.5 py-1">
              <div className="flex items-center gap-2 text-sm font-semibold text-white/85">
                Лучший выбор модели:
                <span className="text-white">{best.rec.label}</span>
              </div>

              <div className="mt-1 text-[13px] flex flex-wrap gap-4 text-slate-300">
                {isNum(best.rec.p) && (
                  <span>
                    Вероятность:{" "}
                    <span className="text-slate-50">
                      {fmtPct(best.rec.p, 0)}
                    </span>
                  </span>
                )}
                {isNum(best.rec.odds) && (
                  <span>
                    Кэф:{" "}
                    <span className="text-slate-50">
                      {fmtNum(best.rec.odds, 2)}
                    </span>
                  </span>
                )}
                {isNum(best.rec.ev) && (
                  <span className={tone}>EV: {fmtPct(best.rec.ev, 1)}</span>
                )}
                <span className="text-slate-300">
                  Сигнал:{" "}
                  {best.verdict.status === "hot"
                    ? "сильный"
                    : best.verdict.status === "ok"
                    ? "умеренный"
                    : "наблюдать"}
                </span>
              </div>

              {best.rec.text && (
                <div className="mt-1 text-sm text-slate-300/90 leading-relaxed">
                  {best.rec.text}
                </div>
              )}
            </div>
          );
        })()}

        {/* содержимое */}
        <div className="mt-4">
          <button
            type="button"
            onClick={function () {
              setExpanded(function (v) {
                return !v;
              });
            }}
            className="inline-flex items-center gap-2 px-0 py-0 text-sm text-white/60 transition hover:text-white"
          >
            <span>{expanded ? "Скрыть детали" : "Раскрыть детали"}</span>
            <span className={expanded ? "rotate-180 transition-transform" : "transition-transform"}>⌄</span>
          </button>
        </div>

        {expanded ? (
          <div className="mt-4 space-y-5">
            <div className="py-1">
              <Row title="Исход" rec={outcome} compact />
            </div>
            <div className="py-1">
              <Row title="Тотал 2.5" rec={total} compact />
            </div>
            <div className="py-1">
              <Facts compact />
            </div>
          </div>
        ) : null}

      </div>
    </div>
  );
}

/* ================== Страница ================== */
export default function BestPicksRoundPage() {
  const navigate = useNavigate();
  const [sp] = useSearchParams();

  const [league, setLeague] = useState(sp.get("league") || "All");
  const [round, setRound] = useState("");
  const [kellyCoef, setKellyCoef] = useState(0.25);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [matches, setMatches] = useState([]);
  const [upcoming, setUpcoming] = useState([]);
  const [fixturesRaw, setFixturesRaw] = useState([]);
  const [insightsMap, setInsightsMap] = useState(new Map());

  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);
  const loadMoreRef = useRef(null);

  const [teamOverlay, setTeamOverlay] = useState({
    visible: false,
    teamId: null,
  });

  const range = seasonRange2025();
  const from = range.from,
    to = range.to;

  // Sync league from URL (sidebar changes)
  useEffect(
    function () {
      var l = sp.get("league") || "All";
      if (l !== league) setLeague(l);
    },
    [sp, league]
  );

  // URL-синхронизация
  useEffect(
    function () {
      const params = new URLSearchParams();
      params.set("season", FIXED_SEASON);
      if (league) params.set("league", league);
      navigate("/best-picks?" + params.toString(), { replace: true });
    },
    [league, navigate]
  );

  // Основная загрузка
  useEffect(function () {
    async function fetchAll() {
      setLoading(true);
      setError("");
      try {
        var qs1 = new URLSearchParams({
          from_date: from,
          to_date: to,
          season: FIXED_SEASON,
        });
        var data1 = await fetchJSONCached(
          API_ROUTES.matches + "?" + qs1.toString(),
          TTL_MATCHES
        );
        var matchesList = Array.isArray(data1) ? data1 : [];
        setMatches(matchesList);

        var upPromises = TOP_LEAGUES.map(function (L) {
          var qsU = new URLSearchParams({
            league: L,
            season: FIXED_SEASON,
          });
          return fetchJSONCached(
            API_ROUTES.upcoming + "?" + qsU.toString(),
            TTL_UPCOMING
          ).then(function (arr) {
            return (arr || [])
              .filter(function (x) {
                return (
                  x &&
                  (x.p_home != null ||
                    x.p_over25 != null ||
                    x.signal_market != null)
                );
              })
              .map(function (x) {
                return {
                  fixture_id: x.fixture_id,
                  date:
                    parseScheduleISO(x.datetime, x.season) ||
                    x.datetime,
                  league: x.league,
                  season: x.season,
                  round: x.round_label,
                  home_team: x.home_team,
                  away_team: x.away_team,
                  home_team_id: x.home_team_id,
                  away_team_id: x.away_team_id,
                  p_home: x.p_home,
                  p_draw: x.p_draw,
                  p_away: x.p_away,
                  avg_odds_home: x.avg_odds_home,
                  avg_odds_draw: x.avg_odds_draw,
                  avg_odds_away: x.avg_odds_away,
                  p_over25: x.p_over25,
                  p_under25: x.p_under25,
                  avg_odds_over25: x.avg_odds_over25,
                  avg_odds_under25: x.avg_odds_under25,
                  ev_over: x.ev_over,
                  ev_under: x.ev_under,
                  decision_total: x.decision_total,
                  home_goals: toInt(
                    firstDefined(
                      x.home_goals,
                      x.goals_home,
                      x.ft_home,
                      x.score_home
                    )
                  ),
                  away_goals: toInt(
                    firstDefined(
                      x.away_goals,
                      x.goals_away,
                      x.ft_away,
                      x.score_away
                    )
                  ),
                  score:
                    x.score && typeof x.score === "object"
                      ? x.score
                      : null,
                  status: x.status || x.status_short || "",
                };
              });
          });
        });
        var upAll = await Promise.all(upPromises);
        var upcomingList = [].concat.apply([], upAll);
        setUpcoming(upcomingList);

        var qs2 = new URLSearchParams({
          from_date: from,
          to_date: to,
          include_nobet: "false",
          trust_single_book: "true",
          top_n: "80",
          limit_pairs_each: "8",
          limit_triples_each: "8",
          return_fixtures: "true",
        });
        var data2 = await fetchJSONCached(
          API_ROUTES.bestPicks + "?" + qs2.toString(),
          TTL_BESTPICKS
        );
        setFixturesRaw(valOr(data2 && data2.fixtures, []));
        setInsightsMap(new Map());
        setVisibleCount(PAGE_SIZE);
      } catch (e) {
        setError(e.message || String(e));
      } finally {
        setLoading(false);
      }
    }
    fetchAll();
  }, [from, to]);

  // офферы по фикстуре
  const offersByFixture = useMemo(
    function () {
      var m = new Map();
      (fixturesRaw || []).forEach(function (f) {
        m.set(
          f.fixture_id,
          frontPruneOffers(f.offers || [], f.league)
        );
      });
      return m;
    },
    [fixturesRaw]
  );

  const decisionMetaByFixture = useMemo(
    function () {
      var m = new Map();
      (fixturesRaw || []).forEach(function (f) {
        m.set(f.fixture_id, {
          bet_decision_notes: f.bet_decision_notes || "",
          decision_profile: f.decision_profile || "",
          decision_tags: Array.isArray(f.decision_tags)
            ? f.decision_tags
            : [],
          decision_close_flag: !!f.decision_close_flag,
          decision_draw_switch: !!f.decision_draw_switch,
          decision_total_switch: !!f.decision_total_switch,
          best_bet_type: f.best_bet_type,
          best_bet_outcome: f.best_bet_outcome,
          best_bet_ev: f.best_bet_ev,
          best_bet_odds: f.best_bet_odds,
          bet_reason: f.bet_reason,
        });
      });
      return m;
    },
    [fixturesRaw]
  );

  function triadFromFixture(f) {
    var hasP =
      !isNil(f.p_home) ||
      !isNil(f.p_draw) ||
      !isNil(f.p_away);
    var hasO =
      !isNil(f.avg_odds_home) ||
      !isNil(f.avg_odds_draw) ||
      !isNil(f.avg_odds_away);
    if (!hasP && !hasO) return null;
    return {
      pH: f.p_home,
      pD: f.p_draw,
      pA: f.p_away,
      odH: f.avg_odds_home,
      odD: f.avg_odds_draw,
      odA: f.avg_odds_away,
    };
  }

  const fixturesAll = useMemo(
    function () {
      var rows = (matches || []).concat(upcoming || []);
      var seen = new Set();
      var uniq = [];
      for (var i = 0; i < rows.length; i++) {
        var f = rows[i];
        if (!seen.has(f.fixture_id)) {
          seen.add(f.fixture_id);
          uniq.push(f);
        }
      }

      // canonical names by team_id (prefer matches list for consistency with calendar)
      var nameById = new Map();
      (matches || []).forEach(function (m) {
        if (m && m.home_team_id && m.home_team && !nameById.has(m.home_team_id)) {
          nameById.set(m.home_team_id, m.home_team);
        }
        if (m && m.away_team_id && m.away_team && !nameById.has(m.away_team_id)) {
          nameById.set(m.away_team_id, m.away_team);
        }
      });
      (upcoming || []).forEach(function (m) {
        if (m && m.home_team_id && m.home_team && !nameById.has(m.home_team_id)) {
          nameById.set(m.home_team_id, m.home_team);
        }
        if (m && m.away_team_id && m.away_team && !nameById.has(m.away_team_id)) {
          nameById.set(m.away_team_id, m.away_team);
        }
      });

      return uniq.map(function (f) {
        var bundle =
          insightsMap.get(f.fixture_id) || {
            ins: null,
            triad: null,
          };
        var tri = bundle.triad || triadFromFixture(f);
        var meta =
          decisionMetaByFixture.get(f.fixture_id) || {};

        var homeName =
          f && f.home_team_id && nameById.has(f.home_team_id)
            ? nameById.get(f.home_team_id)
            : f.home_team;
        var awayName =
          f && f.away_team_id && nameById.has(f.away_team_id)
            ? nameById.get(f.away_team_id)
            : f.away_team;

        return Object.assign({}, f, meta, {
          home_team: homeName,
          away_team: awayName,
          _insights: bundle.ins,
          _triad: tri,
        });
      });
    },
    [matches, upcoming, insightsMap, decisionMetaByFixture]
  );

  const leagues = useMemo(
    function () {
      var s = new Set();
      fixturesAll.forEach(function (m) {
        if (m && m.league) s.add(m.league);
      });
      var arr = Array.from(s).sort();
      arr.unshift("All");
      return arr;
    },
    [fixturesAll]
  );

  const rounds = useMemo(
    function () {
      if (league === "All") return [];
      var s = new Set();
      fixturesAll.forEach(function (m) {
        if (m.league === league && !isNil(m.round))
          s.add(normalizeRound(m.round));
      });
      return Array.from(s).sort(function (a, b) {
        return roundSortKey(a) - roundSortKey(b);
      });
    },
    [league, fixturesAll]
  );

  const roundOptions = useMemo(
    function () {
      if (league === "All" || rounds.length <= 7) return rounds;
      var anchor = round && rounds.indexOf(round) >= 0 ? round : pickDefaultRound(fixturesAll, league);
      var idx = Math.max(0, rounds.indexOf(anchor));
      var start = Math.max(0, idx - 2);
      var end = Math.min(rounds.length, idx + 3);
      if (end - start < 5) {
        start = Math.max(0, end - 5);
      }
      return rounds.slice(start, end);
    },
    [league, rounds, round, fixturesAll]
  );

  function pickDefaultRound(list, leagueName) {
    var items = list
      .filter(function (f) {
        return leagueName === "All" ? false : f.league === leagueName;
      })
      .filter(function (f) {
        return f.round && f.date;
      });
    if (!items.length) return "";
    var now = Date.now();
    var withDate = items
      .map(function (f) {
        var ts = Date.parse(f.date);
        return Number.isFinite(ts) ? { f: f, ts: ts } : null;
      })
      .filter(Boolean);
    if (!withDate.length) return normalizeRound(items[0].round);
    var future = withDate.filter(function (x) {
      return x.ts >= now;
    });
    if (future.length) {
      future.sort(function (a, b) {
        return a.ts - b.ts;
      });
      return normalizeRound(future[0].f.round);
    }
    withDate.sort(function (a, b) {
      return b.ts - a.ts;
    });
    return normalizeRound(withDate[0].f.round);
  }

  useEffect(
    function () {
      if (league === "All") {
        setRound("");
        return;
      }
      if (!round || rounds.indexOf(round) === -1) {
        var def = pickDefaultRound(fixturesAll, league);
        setRound(def || "");
      }
    },
    [league, rounds, fixturesAll, round]
  );

  const selectedFixtures = useMemo(
    function () {
      var base = fixturesAll
        .filter(function (f) {
          return league === "All" ? true : f.league === league;
        })
        .filter(function (f) {
          return round
            ? normalizeRound(f.round) === round
            : true;
        })
        .sort(by("date", "asc"));
      var filtered = base.filter(function (f) {
        var offers = offersByFixture.get(f.fixture_id) || [];
        var has1x2 = offers.some(function (o) {
          return o.market === "1X2";
        });
        var hasOU = offers.some(function (o) {
          return o.market === "OU25";
        });
        var hasFixtureTotals =
          !isNil(f.p_over25) || !isNil(f.p_under25);
        return has1x2 || hasOU || !!f._triad || hasFixtureTotals;
      });
      if (INCLUDE_NO_BET) return filtered;
      return filtered.filter(function (f) {
        var offers = offersByFixture.get(f.fixture_id) || [];
        var outRec = chooseOutcome(
          offers,
          f.league,
          f._insights || null,
          f._triad || null
        );
        var totRec = chooseTotals(
          offers,
          f._insights || null,
          f
        );
        var outTier = assessRec(outRec, f.league).tier;
        var totTier = assessRec(totRec, f.league).tier;
        return outTier !== "NO BET" || totTier !== "NO BET";
      });
    },
    [fixturesAll, league, round, offersByFixture]
  );

  useEffect(
    function () {
      var el = loadMoreRef.current;
      if (!el) return;
      var io = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (e) {
            if (e.isIntersecting) {
              setVisibleCount(function (v) {
                return Math.min(
                  v + PAGE_STEP,
                  selectedFixtures.length
                );
              });
            }
          });
        },
        { rootMargin: "600px 0px" }
      );
      io.observe(el);
      return function () {
        io.disconnect();
      };
    },
    [selectedFixtures.length]
  );

  useEffect(
    function () {
      if (!USE_INSIGHTS) return;
      var need = [];
      var limit = Math.min(
        visibleCount,
        selectedFixtures.length
      );
      for (var i = 0; i < limit; i++) {
        var f = selectedFixtures[i];
        if (f && !insightsMap.has(f.fixture_id)) {
          need.push(f.fixture_id);
        }
      }
      if (!need.length) return;
      var ids = need.slice(0, 60);
      var url =
        API_ROUTES.insightsBatch +
        "?fixture_ids=" +
        ids.join(",");
      var cancelled = false;
      (async function () {
        try {
          var raw = await fetchJSONCached(url, TTL_INSIGHTS);
          var next = new Map(insightsMap);
          Object.keys(raw || {}).forEach(function (k) {
            var parsed = normalizePayload(raw[k]);
            next.set(Number(k), parsed);
          });
          if (!cancelled) setInsightsMap(next);
        } catch (e) {}
      })();
      return function () {
        cancelled = true;
      };
    },
    [selectedFixtures, visibleCount, insightsMap]
  );

  /* ================== Рендер ================== */
  return (
    <div className="min-h-screen text-slate-50">
      <div className="type-page w-full px-4 py-8 space-y-8">
        {/* шапка страницы */}
        <div className="glass-card px-6 py-5 flex items-start justify-between gap-4 flex-wrap">
          <div className="type-title-block">
            <div className="inline-flex items-center gap-2 px-0 py-0 text-[10px] uppercase tracking-[0.18em] text-white/45">
              EdgeScore Premium
            </div>
            <h1 className="type-page-title">
              Подборки ставок · сезон {FIXED_SEASON}
            </h1>
            <div className="type-subtitle">
              {league === "All" ? "Все лиги" : league}
            </div>
            <p className="type-body max-w-2xl">
              Две рекомендации по матчам: исход и тотал 2.5 с пояснениями модели.
            </p>
          </div>
        </div>

        {/* фильтры (раунд + Kelly) */}
        <div className="px-2 md:px-4 flex items-center gap-4 flex-wrap">
          <div className="flex items-center gap-2">
            <span className="text-[11px] text-slate-400 uppercase tracking-wide">
              Раунд
            </span>
            <select
              value={round}
              onChange={function (e) {
                setRound(e.target.value);
              }}
              className="rounded-xl border border-white/10 bg-white/[0.04] px-3 py-1.5 text-xs text-slate-100 disabled:opacity-40"
              disabled={league === "All"}
            >
              <option value="">Ближайший</option>
              {league !== "All" && rounds.length === 0 ? (
                <option value="" disabled>
                  — нет раундов —
                </option>
              ) : null}
              {league !== "All" &&
                roundOptions.map(function (r) {
                  return (
                    <option key={r} value={r}>
                      {r}
                    </option>
                  );
                })}
            </select>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] text-slate-400 uppercase tracking-wide">
              Kelly ×
            </span>
            <input
              type="range"
              min={0.1}
              max={0.5}
              step={0.05}
              value={kellyCoef}
              onChange={function (e) {
                setKellyCoef(Number(e.target.value));
              }}
              className="w-36 accent-slate-300"
            />
            <div className="w-10 text-right text-xs font-mono text-slate-100">
              {Math.round(kellyCoef * 100)}%
            </div>
          </div>
        </div>

        {loading ? (
          <div className="text-slate-300/90 mb-4">
            Загружаем премиальные подборки…
          </div>
        ) : null}
        {error ? (
          <div className="text-rose-400 mb-4">
            Ошибка: {error}
          </div>
        ) : null}

        {!loading && !error && (
          <>
            {league !== "All" && (
              <div className="px-2 md:px-4 flex items-center justify-between mb-3 gap-3 flex-wrap">
                <h2 className="text-sm sm:text-base font-semibold text-slate-100 flex items-center gap-2">
                  {leagueLogoSrc(league) ? (
                    <Img
                      src={leagueLogoSrc(league)}
                      alt={league}
                      size={20}
                      className="rounded-full bg-surface-3 border border-slate-700/70"
                    />
                  ) : null}
                  <span>
                    {league} — {prettyRound(round)}
                  </span>
                </h2>
                <div className="text-xs text-slate-500">
                  Матчей: {selectedFixtures.length}
                </div>
              </div>
            )}

            {/* широкие карточки (2 в ряд) */}
            <div className="px-2 md:px-4 grid grid-cols-1 xl:grid-cols-2 gap-5 mb-10">
              {selectedFixtures
                .slice(0, visibleCount)
                .map(function (f) {
                  return (
                    <DualCard
                      key={f.fixture_id}
                      fixture={f}
                      offers={valOr(
                        offersByFixture.get(f.fixture_id),
                        []
                      )}
                      ins={f._insights}
                      triad={f._triad}
                      includeNoBet={INCLUDE_NO_BET}
                      kellyCoef={kellyCoef}
                      onOpenTeam={function (teamId) {
                        if (!teamId) return;
                        navigate(
                          "/team/" +
                            teamId +
                            "?league=" +
                            encodeURIComponent(f.league || "") +
                            "&season=" +
                            FIXED_SEASON
                        );
                      }}
                    />
                  );
                })}
            </div>

            <div ref={loadMoreRef}></div>

            {league === "All" && !selectedFixtures.length ? (
              <div className="text-slate-300/80">
                Нет матчей с доступным прогнозом.
              </div>
            ) : null}
          </>
        )}
      </div>

      {/* всплывающая страница команды */}
      <TeamOverlayIframe
        visible={teamOverlay.visible}
        teamId={teamOverlay.teamId}
        league={teamOverlay.league || league}
        onClose={function () {
          setTeamOverlay({ visible: false, teamId: null });
        }}
      />
    </div>
  );
}
