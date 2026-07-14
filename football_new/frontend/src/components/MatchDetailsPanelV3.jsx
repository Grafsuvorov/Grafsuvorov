import { useEffect, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import TeamLogoLink from "@/components/TeamLogoLink";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* ===================== BADGES ===================== */

function StrengthBadge({ strength }) {
  const map = {
    none:   { text: "нет сигнала", cls: "bg-surface-2/70 text-slate-300 border border-glass" },
    weak:   { text: "слабый",      cls: "bg-amber-500/15 text-amber-200 border border-amber-400/30" },
    medium: { text: "средний",     cls: "bg-amber-500/25 text-amber-100 border border-amber-400/40" },
    strong: { text: "сильный",     cls: "bg-emerald-500/20 text-emerald-100 border border-emerald-400/40" },
  };
  const cfg = map[strength || "none"];
  return (
    <span className={`px-2 py-0.5 rounded-md text-xs font-medium ${cfg.cls}`}>
      {cfg.text}
    </span>
  );
}

/* ===================== HELPERS ===================== */

const pct = (v) => (v == null ? "—" : `${(Number(v) * 100).toFixed(1)}%`);
const odd = (v) => (v == null ? "—" : Number(v).toFixed(2));
const toNum = (v) => (v == null || v === "" || Number.isNaN(Number(v)) ? null : Number(v));

const labelOutcome = (ph, pd, pa) => {
  const arr = [
    ["П1", ph],
    ["Х",  pd],
    ["П2", pa],
  ].filter(([,p]) => p != null);
  if (!arr.length) return "—";
  return arr.reduce((a,b) => (b[1] > a[1] ? b : a))[0];
};

const labelTotal25 = (pOver) => (pOver == null ? "—" : pOver >= 0.5 ? "Больше 2.5" : "Меньше 2.5");

const toStrength = (v) => {
  const s = String(v || "").trim().toLowerCase();
  return ["weak","medium","strong"].includes(s) ? s : "none";
};

/* ===================== MAP PREDICTION ===================== */

function mapSchedulePrediction(m) {
  if (!m) return null;
  const p_home = toNum(m.p_home);
  const p_draw = toNum(m.p_draw);
  const p_away = toNum(m.p_away);
  const p_over = toNum(m.p_over25);
  const p_under = toNum(m.p_under25);

  const hasAny =
    p_home != null || p_draw != null || p_away != null ||
    toNum(m.avg_odds_home) != null ||
    toNum(m.avg_odds_draw) != null ||
    toNum(m.avg_odds_away) != null ||
    p_over != null || p_under != null;

  if (!hasAny) return null;

  return {
    outcome_p1: p_home,
    outcome_x:  p_draw,
    outcome_p2: p_away,
    total_o25:  p_over,
    total_u25:  p_under,

    outcome_label: labelOutcome(p_home, p_draw, p_away),
    total_label:   labelTotal25(p_over),

    signal_strength: toStrength(m.bet_rating),
    rec_reason: m.rec_reason || "—",
    signal_market: m.signal_market || null,
    signal_value: toNum(m.signal_value),

    avg_odds_home: toNum(m.avg_odds_home),
    avg_odds_draw: toNum(m.avg_odds_draw),
    avg_odds_away: toNum(m.avg_odds_away),
    avg_odds_over25: toNum(m.avg_odds_over25),
    avg_odds_under25: toNum(m.avg_odds_under25),
    n_bookmakers: m.n_bookmakers != null ? Number(m.n_bookmakers) : null,
  };
}

/* ===================== MAIN COMPONENT ===================== */

export default function MatchDetailsPanelV3({ match }) {
  const { language } = useLanguage();
  const [details, setDetails] = useState(null);
  const [loadingDetails, setLoadingDetails] = useState(false);

  const [prediction, setPrediction] = useState(null);
  const [loadingPrediction, setLoadingPrediction] = useState(false);

  /* --------- fetch details ---------- */
  useEffect(() => {
    if (!match || !match.date) return;
    const ac = new AbortController();

    (async () => {
      try {
        setLoadingDetails(true);
        const query =
          `home_team=${encodeURIComponent(match.home_team)}&` +
          `away_team=${encodeURIComponent(match.away_team)}&` +
          `date=${match.date}`;
        const res = await fetch(
          `/api/team-statistics-v3?${query}`,
          { signal: ac.signal }
        );
        const data = await res.json();
        setDetails(data);
      } catch {}
      finally {
        setLoadingDetails(false);
      }
    })();

    setPrediction(null);
    return () => ac.abort();
  }, [match]);

  const getPrediction = () => {
    setLoadingPrediction(true);
    setTimeout(() => {
      setPrediction(mapSchedulePrediction(match));
      setLoadingPrediction(false);
    }, 150);
  };

  /* --------- LOGO ---------- */

  const renderTeamLogo = (id) => {
    const src = id ? `/icons/team_logos/${id}.png` : "/icons/team_logos/default.png";
    return (
      <TeamLogoLink teamId={id} className="block">
        <img
          src={src}
          className="w-6 h-6 object-contain rounded-md bg-surface-2 border border-glass p-0.5"
          onError={(e) => {
            e.currentTarget.onerror = null;
            e.currentTarget.src = "/icons/team_logos/default.png";
          }}
        />
      </TeamLogoLink>
    );
  };

  /* --------- AVERAGE CARD ---------- */

  const renderAvgCard = (teamType, title) => {
    const a = details?.team_statistics || {};
    return (
      <div className="rounded-xl border border-glass bg-surface-2 p-4 shadow-sm">
        <div className="font-semibold text-slate-200 mb-2">{title}</div>

        <div className="grid grid-cols-2 gap-y-1 text-xs text-slate-300">
          <div>xG</div>
          <div className="font-semibold">{a[`${teamType}_avg_xg`] ?? "—"}</div>

          <div>Удары</div>
          <div className="font-semibold">{a[`${teamType}_avg_shots`] ?? "—"}</div>

          <div>В створ</div>
          <div className="font-semibold">{a[`${teamType}_avg_shots_on_target`] ?? "—"}</div>

          <div>Владение</div>
          <div className="font-semibold">
            {a[`${teamType}_avg_possession`] != null
              ? `${a[`${teamType}_avg_possession`]}%`
              : "—"}
          </div>

          <div>Передачи</div>
          <div className="font-semibold">
            {a[`${teamType}_avg_passes_completed`] ?? "—"} /
            {a[`${teamType}_avg_pass_accuracy`] != null
              ? `${a[`${teamType}_avg_pass_accuracy`]}%`
              : "—"}
          </div>

          <div>Отборы</div>
          <div className="font-semibold">{a[`${teamType}_avg_tackles`] ?? "—"}</div>
        </div>
      </div>
    );
  };

  /* ===================== RENDER ===================== */

  if (!match) return null;

  return (
    <Card className="mt-4 shadow-lg border-glass bg-surface-1/80 text-slate-100">
      <CardContent className="space-y-6 p-5">

        {/* HEADER */}
        <div className="flex flex-wrap justify-between items-start gap-4">
          <div className="flex items-center gap-3 text-lg font-bold">
            {renderTeamLogo(match.home_team_id)}
            <span>{match.home_team}</span>
            <span>—</span>
            {renderTeamLogo(match.away_team_id)}
            <span>{match.away_team}</span>

            <span className="text-sm text-slate-400 ml-2">
              {match.date}
            </span>
          </div>

          {/* ==== Prediction block ==== */}
          {prediction ? (
            <div className="rounded-xl border border-glass bg-surface-2 shadow-sm p-4 text-sm min-w-[320px] space-y-4">

              {/* Исход */}
              <div>
                <div className="font-semibold text-slate-200">Исход</div>
                <div className="flex justify-between text-xs mt-1">
                  <div>П1: <b>{pct(prediction.outcome_p1)}</b></div>
                  <div>Х:  <b>{pct(prediction.outcome_x)}</b></div>
                  <div>П2: <b>{pct(prediction.outcome_p2)}</b></div>
                </div>
                <div className="mt-1 font-semibold text-rose-300">
                  Прогноз: {prediction.outcome_label}
                </div>
              </div>

              {/* Total */}
              <div>
                <div className="font-semibold text-slate-200">Тотал 2.5</div>
                <div className="flex justify-between text-xs mt-1">
                  <div>Меньше: <b>{pct(prediction.total_u25)}</b></div>
                  <div>Больше: <b>{pct(prediction.total_o25)}</b></div>
                </div>
                <div className="mt-1 font-semibold text-sky-300">
                  Прогноз: {prediction.total_label}
                </div>
              </div>

              {/* Recommendation */}
              <div className="border-t border-glass pt-2 text-xs">
                <div className="flex justify-between items-center">
                  <span className="font-semibold text-slate-200">Рекомендация</span>
                  <StrengthBadge strength={prediction.signal_strength} />
                </div>
                <div className="mt-1 text-slate-300">{prediction.rec_reason}</div>
                {prediction.signal_value != null && (
                  <div className="mt-1 text-slate-400">
                    {language === "ru" ? "value" : "value"}: <b>{prediction.signal_value.toFixed(3)}</b>
                    {prediction.signal_market ? (
                      <> • {language === "ru" ? "рынок" : "market"}: <b>{prediction.signal_market}</b></>
                    ) : null}
                  </div>
                )}
              </div>

              {/* Odds */}
              <div className="border-t border-glass pt-2 text-xs">
                <div className="font-semibold text-slate-200 mb-1">
                  {language === "ru" ? "Средние коэффициенты" : "Average odds"}
                </div>
                <div className="grid grid-cols-3 gap-y-1">
                  <div>K1: <b>{odd(prediction.avg_odds_home)}</b></div>
                  <div>KX: <b>{odd(prediction.avg_odds_draw)}</b></div>
                  <div>K2: <b>{odd(prediction.avg_odds_away)}</b></div>

                  <div>ТБ 2.5: <b>{odd(prediction.avg_odds_over25)}</b></div>
                  <div>ТМ 2.5: <b>{odd(prediction.avg_odds_under25)}</b></div>

                  <div className="col-span-3 text-right text-slate-400">
                    {language === "ru" ? "bookmakers" : "bookmakers"}: <b>{prediction.n_bookmakers ?? "—"}</b>
                  </div>
                </div>
              </div>

            </div>
          ) : (
            <Button
              variant="outline"
              size="sm"
              onClick={getPrediction}
              disabled={loadingPrediction}
            >
              {loadingPrediction ? (language === "ru" ? "Загрузка…" : "Loading…") : (language === "ru" ? "Получить прогноз" : "Get prediction")}
            </Button>
          )}
        </div>

        {/* AVERAGES */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {loadingDetails ? (
            <div className="text-xs text-slate-400">{language === "ru" ? "Загружаем статистику…" : "Loading stats…"}</div>
          ) : (
            <>
              {renderAvgCard("home", match.home_team)}
              {renderAvgCard("away", match.away_team)}
            </>
          )}
        </div>

        {/* LAST MATCHES — HOME */}
        <div>
          <div className="font-semibold mb-1 text-slate-200">
            {match.home_team}: {language === "ru" ? "последние матчи" : "last matches"}
          </div>

          <div className="space-y-1">
            {details?.last_5_matches_home?.map((m, idx) => (
              <div key={idx} className="flex justify-between items-center border-b border-white/5 py-1 text-xs">
                <div className="w-1/3 flex items-center gap-2">
                  {renderTeamLogo(m.home_team_id)}
                </div>
                <div className="w-1/3 text-center font-medium text-slate-200">
                  {m.score}
                </div>
                <div className="w-1/3 flex items-center gap-2 justify-end">
                  {renderTeamLogo(m.away_team_id)}
                </div>
              </div>
            )) || <div className="text-slate-500">—</div>}
          </div>
        </div>

        <hr />

        {/* LAST MATCHES — AWAY */}
        <div>
          <div className="font-semibold mb-1 text-slate-200">
            {match.away_team}: {language === "ru" ? "последние матчи" : "last matches"}
          </div>

          <div className="space-y-1">
            {details?.last_5_matches_away?.map((m, idx) => (
              <div key={idx} className="flex justify-between items-center border-b border-white/5 py-1 text-xs">
                <div className="w-1/3 flex items-center gap-2">
                  {renderTeamLogo(m.home_team_id)}
                </div>
                <div className="w-1/3 text-center font-medium text-slate-200">
                  {m.score}
                </div>
                <div className="w-1/3 flex items-center gap-2 justify-end">
                  {renderTeamLogo(m.away_team_id)}
                </div>
              </div>
            )) || <div className="text-slate-500">—</div>}
          </div>
        </div>

        <hr />

        {/* HEAD-TO-HEAD */}
        <div>
          <div className="font-semibold mb-1 text-slate-200">Личные встречи</div>

          <div className="space-y-1">
            {details?.head_to_head?.map((m, idx) => (
              <div key={idx} className="flex justify-between items-center border-b border-white/5 py-1 text-xs">
                <div className="w-1/3 flex items-center gap-2">
                  {renderTeamLogo(m.home_team_id)}
                </div>
                <div className="w-1/3 text-center font-medium text-slate-200">
                  {m.score}
                </div>
                <div className="w-1/3 flex items-center gap-2 justify-end">
                  {renderTeamLogo(m.away_team_id)}
                </div>
              </div>
            )) || <div className="text-slate-500">—</div>}
          </div>
        </div>

      </CardContent>
    </Card>
  );
}
