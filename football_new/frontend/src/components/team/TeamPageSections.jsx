import clsx from "clsx";
import MatchInsightsPanelFull from "@/components/MatchInsightsPanelFull";
import { useLanguage } from "@/context/LanguageContext.jsx";
import {
  AvgCompareRow,
  CompactMetricRow,
  KpiCard,
  PeriodSwitch,
  RadarChart,
  VenueFilterTabs,
} from "@/components/team/TeamPageWidgets.jsx";

const toNumSafe = (v) => {
  if (v == null) return null;
  const s = String(v).replace("%", "").replace(",", ".").trim();
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
};

const fmtNum = (v, d = 0) => (v == null ? "—" : Number(v).toFixed(d));

const FALLBACK_SVG =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
       <rect width='100%' height='100%' fill='#020617'/>
       <path d='M20 4l12 6v8c0 8-6 14-12 18C14 32 8 26 8 18V10l12-6z' fill='#0f172a'/>
     </svg>`
  );

const SafeImg = ({ src, alt = "", className = "", fallbackSrc = "" }) => {
  const onErr = (e) => {
    if (fallbackSrc && e.currentTarget.dataset.fallbackTried !== "1") {
      e.currentTarget.dataset.fallbackTried = "1";
      e.currentTarget.src = fallbackSrc;
      return;
    }
    e.currentTarget.onerror = null;
    e.currentTarget.srcset = "";
    e.currentTarget.src = FALLBACK_SVG;
  };
  return (
    <img
      src={src}
      alt={alt}
      className={className}
      onError={onErr}
      data-fallback-tried="0"
      loading="lazy"
      decoding="async"
      draggable={false}
    />
  );
};

const LogoBadge = ({ src, fallbackSrc, name, size = 24, imgSize = null }) => (
  <span
    className="inline-flex items-center justify-center rounded-md border border-glass bg-surface-2/80 shadow-sm"
    style={{ width: size, height: size }}
  >
    <SafeImg
      src={src}
      alt={name || ""}
      fallbackSrc={fallbackSrc}
      className="object-contain"
      style={{
        width: imgSize != null ? imgSize : Math.max(14, Math.round(size * 0.65)),
        height: imgSize != null ? imgSize : Math.max(14, Math.round(size * 0.65)),
      }}
    />
  </span>
);

const ForecastHero = ({ match, locked = false, onUpgrade, blurBody = false }) => {
  const { language } = useLanguage();
  const isRu = language === "ru";
  if (!match) return null;
  const p1 = toNumSafe(match.p_home);
  const px = toNumSafe(match.p_draw);
  const p2 = toNumSafe(match.p_away);
  const pov = toNumSafe(match.p_over25);
  const pun = toNumSafe(match.p_under25);
  const hasOutcome = [p1, px, p2].some((v) => v != null);
  const hasTotal = [pov, pun].some((v) => v != null);

  if (!hasOutcome && !hasTotal && !match.rec_decision) {
    return <div className="text-sm text-white/60">{isRu ? "Нет данных по прогнозу модели." : "No model forecast data."}</div>;
  }

  const toPct = (v) => (v == null ? "—" : `${Math.round(v * 100)}%`);
  const outcomes = [
    { label: isRu ? "П1" : "1", p: p1 },
    { label: isRu ? "Х" : "X", p: px },
    { label: isRu ? "П2" : "2", p: p2 },
  ].filter((o) => o.p != null);
  const top = outcomes.length ? outcomes.reduce((a, b) => (a.p >= b.p ? a : b)) : null;

  const strength = match.signal_strength || "none";
  const strengthLabel =
    strength === "strong"
      ? isRu ? "Сильный сигнал" : "Strong signal"
      : strength === "medium"
      ? isRu ? "Средний сигнал" : "Medium signal"
      : strength === "weak"
      ? isRu ? "Слабый сигнал" : "Weak signal"
      : isRu ? "Сигнала нет" : "No signal";

  const isBet = match.rec_decision === "BET";
  const decision = isBet ? (isRu ? "Ставка" : "Bet") : (isRu ? "Пропуск" : "Skip");
  const pickLabel = match.signal_pick || (top ? top.label : null);

  const verdictLine =
    top?.label === "П1"
      ? isRu ? "Модель видит умеренное преимущество хозяев." : "The model sees a moderate edge for the home side."
      : top?.label === "П2"
      ? isRu ? "Модель видит умеренное преимущество гостей." : "The model sees a moderate edge for the away side."
      : top?.label === "Х"
      ? isRu ? "Модель видит сценарий равной игры." : "The model sees an even-game scenario."
      : null;

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2 text-[11px] text-white/60">
          <span className="uppercase tracking-[0.18em] text-white/50">
            {locked ? `🔒 ${isRu ? "Прогноз модели" : "Model forecast"}` : isRu ? "Прогноз модели" : "Model forecast"}
          </span>
          <span className="text-white/55">• {strengthLabel}</span>
          <span className="text-white/55">• {decision}</span>
        </div>
      </div>

      {locked ? (
        <div className="surface-hero relative overflow-hidden px-5 py-5">
          <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top_left,rgba(168,85,247,0.12),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(59,130,246,0.08),transparent_26%)]" />
          <div className="relative z-10 flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div className="space-y-2">
              <div className="text-[11px] font-semibold uppercase tracking-[0.24em] text-white/45">
                EdgeScore Premium
              </div>
              <div className="text-[22px] font-semibold tracking-tight text-white">
                {isRu ? "Открой прогноз модели и полный разбор матча" : "Unlock the model forecast and full match breakdown"}
              </div>
              <div className="max-w-[720px] text-sm leading-relaxed text-white/68">
                {isRu ? "Подписка открывает итоговый сигнал, вероятности 1X2 и тоталов, сценарий игры и расширенную аналитику по форме команд." : "The subscription unlocks the final signal, 1X2 and totals probabilities, game scenario and extended team-form analytics."}
              </div>
            </div>
            <button
              type="button"
              onClick={onUpgrade}
              className="inline-flex min-h-11 items-center justify-center rounded-2xl border border-white/12 bg-[#0d111b]/96 px-5 py-3 text-sm font-semibold text-white shadow-[0_16px_35px_rgba(0,0,0,0.34),inset_0_1px_0_rgba(255,255,255,0.12)] transition hover:bg-[#121827] hover:shadow-[0_20px_45px_rgba(0,0,0,0.42),inset_0_1px_0_rgba(255,255,255,0.16)]"
            >
              {isRu ? "Оформить подписку" : "Get subscription"}
            </button>
          </div>
        </div>
      ) : null}

      {!locked ? (
        <div className={blurBody ? "pointer-events-none select-none blur-md opacity-10" : ""}>
          {isBet && pickLabel && (
            <div className="text-[30px] font-semibold text-white drop-shadow-[0_0_18px_rgba(139,92,246,0.25)]">
              {pickLabel} — {top ? toPct(top.p) : "—"}
            </div>
          )}
          {!isBet && <div className="text-[24px] font-semibold text-white/90">{isRu ? "Пропуск" : "Skip"}</div>}
          {verdictLine && <div className="text-[12px] text-white/65">{verdictLine}</div>}
          {hasOutcome && (
            <div className="flex flex-wrap gap-4 text-[12px] text-white/70">
              <span>П1 {toPct(p1)}</span>
              <span>Х {toPct(px)}</span>
              <span>П2 {toPct(p2)}</span>
            </div>
          )}
          {hasTotal && (
            <div className="flex flex-wrap gap-4 text-[12px] text-white/70">
              <span>{isRu ? "ТБ" : "Over"} 2.5 {toPct(pov)}</span>
              <span>{isRu ? "ТМ" : "Under"} 2.5 {toPct(pun)}</span>
            </div>
          )}
          {!isBet && hasOutcome && (
            <div className="text-[11px] text-white/55 mt-1">
              {isRu ? "Наиболее вероятный исход" : "Most likely outcome"}: {(isRu ? "П1" : "1")} {toPct(p1)} / {(isRu ? "Х" : "X")} {toPct(px)} / {(isRu ? "П2" : "2")} {toPct(p2)}
            </div>
          )}
          {!isBet && (
            <div className="text-[12px] text-white/55 mt-1">
              {isRu ? "Разницы по форме и xG недостаточно, линия близка к справедливой — лучше пропустить." : "The difference in form and xG is too small, the line looks close to fair value, so it is better to skip."}
            </div>
          )}
        </div>
      ) : null}
    </div>
  );
};

export function TeamResultsSection({
  recentResults,
  resultFilter,
  setResultFilter,
  formSummary,
  loadingR,
  results,
  filteredResults,
  expandedResultId,
  expandedResultData,
  teamId,
  titleTeamName,
  handleToggleResult,
  logoSrc,
  logoFallbackSrc,
  toDDMM,
  resultForTeam,
}) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  return (
    <section className="w-full space-y-6 mc-fade">
      {recentResults.length > 0 && (
        <div className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div className="text-[14px] font-semibold text-white">{isRu ? "Форма" : "Form"}</div>
            <div className="text-[12px] text-white/50">
              {isRu ? "последние 5 матчей" : "last 5 matches"}
              {resultFilter === "home" ? (isRu ? " · дома" : " · home") : resultFilter === "away" ? (isRu ? " · в гостях" : " · away") : ""}
            </div>
          </div>
          <VenueFilterTabs value={resultFilter} onChange={setResultFilter} />
          <div className="glass-card p-6">
            <div className="mt-4 flex items-center gap-2">
              {formSummary.results.map((r, i) => (
                <span
                  key={`form-${i}`}
                  className={clsx(
                    "inline-flex h-7 w-7 items-center justify-center rounded-full text-[12px] font-semibold",
                    r === "W"
                      ? "bg-emerald-500 text-white"
                      : r === "L"
                      ? "bg-rose-500 text-white"
                      : "bg-amber-400/90 text-slate-950"
                  )}
                >
                  {r === "W" ? "W" : r === "L" ? "L" : "D"}
                </span>
              ))}
            </div>
            <div className="mt-4 flex flex-wrap gap-4 text-[13px] text-white/80">
              <span>xG {formSummary.xg != null ? fmtNum(formSummary.xg, 1) : "—"}</span>
              <span>{isRu ? "Удары" : "Shots"} {formSummary.shots != null ? fmtNum(formSummary.shots, 1) : "—"}</span>
              <span>{isRu ? "Влад." : "Poss"} {formSummary.poss != null ? `${fmtNum(formSummary.poss, 0)}%` : "—"}</span>
              <span>xGA {formSummary.xga != null ? fmtNum(formSummary.xga, 1) : "—"}</span>
              <span>GD {Number.isFinite(formSummary.gd) ? formSummary.gd : "—"}</span>
            </div>
          </div>
        </div>
      )}

      {loadingR && <div className="glass-card h-28 animate-pulse" />}

      {!loadingR && results.length === 0 && (
        <div className="surface-empty p-6">
          {isRu ? "Нет сыгранных матчей." : "No played matches."}
        </div>
      )}

      {!loadingR &&
        filteredResults.map((m, idx) => {
          const isExpanded = expandedResultId === m.fixture_id;
          const sideHome = m.side === "H";
          const leftId = sideHome ? teamId : m.opponent_id;
          const rightId = sideHome ? m.opponent_id : teamId;
          const leftName = sideHome ? titleTeamName : m.opponent_name;
          const rightName = sideHome ? m.opponent_name : titleTeamName;
          const teamIsLeft = leftName === titleTeamName;
          const leftGoals =
            m.team_goals != null && m.opp_goals != null
              ? sideHome
                ? m.team_goals
                : m.opp_goals
              : null;
          const rightGoals =
            m.team_goals != null && m.opp_goals != null
              ? sideHome
                ? m.opp_goals
                : m.team_goals
              : null;
          const score =
            leftGoals != null && rightGoals != null ? `${leftGoals}–${rightGoals}` : "—";

          const getPair = (keysLeft, keysRight, source = m) => {
            let a = null;
            let b = null;
            for (let i = 0; i < keysLeft.length; i += 1) {
              const v = toNumSafe(source[keysLeft[i]]);
              if (v != null) {
                a = v;
                break;
              }
            }
            for (let j = 0; j < keysRight.length; j += 1) {
              const v = toNumSafe(source[keysRight[j]]);
              if (v != null) {
                b = v;
                break;
              }
            }
            return a != null && b != null ? [a, b] : null;
          };

          const xgPair = getPair(
            ["xg", "xg_for", "team_xg", "xg_home", "home_xg"],
            ["xg_opp", "xg_against", "opp_xg", "xg_away", "away_xg"]
          );
          const matchStats = expandedResultData[m.fixture_id]?.match || m;
          const possPair = getPair(
            ["possession", "possession_for", "team_possession", "poss_home", "home_possession"],
            ["possession_opp", "possession_against", "opp_possession", "poss_away", "away_possession"],
            matchStats
          );
          const shotsPair = getPair(
            ["shots", "shots_for", "team_shots", "shots_home", "home_shots"],
            ["shots_opp", "shots_against", "opp_shots", "shots_away", "away_shots"],
            matchStats
          );
          const onTargetPair = getPair(
            ["shots_on_goal", "shots_on_target", "shots_on", "sot_home", "home_shots_on_goal"],
            ["shots_on_goal_opp", "shots_on_target_opp", "sot_away", "away_shots_on_goal"],
            matchStats
          );

          const res = resultForTeam(
            {
              home_team_id: sideHome ? teamId : m.opponent_id,
              away_team_id: sideHome ? m.opponent_id : teamId,
              home_goals: sideHome ? m.team_goals : m.opp_goals,
              away_goals: sideHome ? m.opp_goals : m.team_goals,
            },
            teamId
          );

          const matchForOverlay = {
            fixture_id: m.fixture_id,
            date: m.date,
            datetime: m.datetime,
            home_team_id: sideHome ? teamId : m.opponent_id,
            away_team_id: sideHome ? m.opponent_id : teamId,
            home_team: sideHome ? titleTeamName : m.opponent_name,
            away_team: sideHome ? m.opponent_name : titleTeamName,
            home_goals: sideHome ? m.team_goals : m.opp_goals,
            away_goals: sideHome ? m.opp_goals : m.team_goals,
            score,
          };
          const seed = {
            side: sideHome ? "H" : "A",
            team_name: sideHome ? titleTeamName : m.opponent_name,
            team_id: sideHome ? teamId : m.opponent_id,
            opponent_name: sideHome ? m.opponent_name : titleTeamName,
            opponent_id: sideHome ? m.opponent_id : teamId,
            team_goals: sideHome ? m.team_goals : m.opp_goals,
            opp_goals: sideHome ? m.opp_goals : m.team_goals,
            date: m.date,
          };

          return (
            <div
              key={m.fixture_id || `${m.home_team_id}-${m.away_team_id}-${idx}`}
              className={clsx(
                "glass-card relative overflow-hidden transition-all duration-200",
                isExpanded && "bg-[rgba(255,255,255,0.06)] shadow-[0_16px_40px_rgba(0,0,0,0.22)]"
              )}
            >
              {res && (
                <span
                  className={clsx(
                    "pointer-events-none absolute left-0 top-2 bottom-2 w-[3px] rounded-full shadow-[0_0_10px_rgba(139,92,246,0.35)]",
                    res === "W" ? "bg-emerald-400/80" : res === "L" ? "bg-rose-400/70" : "bg-amber-400/80"
                  )}
                />
              )}
              <button
                type="button"
                onClick={() => handleToggleResult(matchForOverlay, seed)}
                className={clsx(
                  "w-full px-3 py-3 sm:px-5 sm:py-4 transition-all duration-200 ease-in-out",
                  "bg-transparent hover:bg-[rgba(255,255,255,0.04)]",
                  "grid grid-cols-[minmax(0,1fr)_72px_minmax(0,1fr)] gap-2 sm:grid-cols-[1fr_110px_1fr] sm:items-center sm:gap-4"
                )}
              >
                <div className="flex min-w-0 items-center gap-2 sm:gap-3">
                  <LogoBadge
                    src={logoSrc(leftId, leftName)}
                    fallbackSrc={logoFallbackSrc(leftId, leftName)}
                    name={leftName}
                    size={24}
                    imgSize={16}
                  />
                  <div className="min-w-0 text-left">
                    <div className={clsx("truncate text-[13px] text-white sm:text-sm", leftName === titleTeamName ? "font-semibold" : "font-medium")}>
                      {leftName}
                    </div>
                    <div className="truncate text-[10px] text-muted sm:text-[11px]">
                      {toDDMM(m.date)} {m.venue ? `· ${m.venue}` : ""}
                    </div>
                  </div>
                </div>

                <div className="flex min-w-0 flex-col items-center justify-center text-center">
                  <div className="flex items-center justify-center whitespace-nowrap text-[19px] font-semibold leading-none tracking-[-0.3px] tabular-nums sm:text-[22px]">
                    <span className={clsx("inline-block min-w-[1ch]", leftGoals === rightGoals ? "text-white" : leftGoals > rightGoals ? "text-white" : "text-white/60")}>
                      {leftGoals ?? "—"}
                    </span>
                    <span className="mx-1 text-white/70">–</span>
                    <span className={clsx("inline-block min-w-[1ch]", leftGoals === rightGoals ? "text-white" : rightGoals > leftGoals ? "text-white" : "text-white/60")}>
                      {rightGoals ?? "—"}
                    </span>
                  </div>
                </div>

                <div className="flex min-w-0 items-center justify-end gap-2 sm:gap-3">
                  <div className="text-right min-w-0">
                    <div className={clsx("truncate text-[13px] text-white sm:text-sm", rightName === titleTeamName ? "font-semibold" : "font-medium")}>
                      {rightName}
                    </div>
                    <div className="truncate text-[10px] text-muted sm:text-[11px]">{m.status || ""}</div>
                  </div>
                  <LogoBadge
                    src={logoSrc(rightId, rightName)}
                    fallbackSrc={logoFallbackSrc(rightId, rightName)}
                    name={rightName}
                    size={24}
                    imgSize={16}
                  />
                </div>
              </button>

              {expandedResultId === m.fixture_id && (
                <div className="border-t border-white/10 bg-gradient-to-r from-white/[0.03] to-white/[0.01] px-5 py-5">
                  {expandedResultData[m.fixture_id]?.loading && (
                    <div className="surface-loading">{isRu ? "Загружаем статистику…" : "Loading stats…"}</div>
                  )}
                  {expandedResultData[m.fixture_id]?.error && (
                    <div className="surface-error">{isRu ? "Ошибка" : "Error"}: {expandedResultData[m.fixture_id]?.error}</div>
                  )}
                  {!expandedResultData[m.fixture_id]?.loading &&
                    !expandedResultData[m.fixture_id]?.error &&
                    (() => {
                      const mapPair = (pair) =>
                        pair ? (teamIsLeft ? [pair[0], pair[1]] : [pair[1], pair[0]]) : [null, null];
                      const [posL, posR] = mapPair(possPair);
                      const [xgL, xgR] = mapPair(xgPair);
                      const [shotsL, shotsR] = mapPair(shotsPair);
                      const [sotL, sotR] = mapPair(onTargetPair);
                      const hasAny = posL != null || xgL != null || shotsL != null || sotL != null;
                      return hasAny ? (
                        <div className="w-full space-y-3">
                          <CompactMetricRow label={isRu ? "Владение" : "Possession"} left={posL} right={posR} isPercent accentSide={teamIsLeft ? "left" : "right"} />
                          <CompactMetricRow label="xG" left={xgL} right={xgR} accentSide={teamIsLeft ? "left" : "right"} />
                          <CompactMetricRow label={isRu ? "Удары" : "Shots"} left={shotsL} right={shotsR} accentSide={teamIsLeft ? "left" : "right"} />
                          <CompactMetricRow label={isRu ? "В створ" : "On target"} left={sotL} right={sotR} accentSide={teamIsLeft ? "left" : "right"} />
                        </div>
                      ) : (
                        <div className="surface-empty">{isRu ? "Нет данных по метрикам матча." : "No match metric data."}</div>
                      );
                    })()}
                </div>
              )}
            </div>
          );
        })}
    </section>
  );
}

export function TeamStatsSection({
  loadingO,
  overview,
  showLowDataNote,
  period,
  setPeriod,
  periodStats,
  periodLabel,
  selectedRank,
  fmtNumLocal = fmtNum,
}) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  if (loadingO) {
    return (
      <section className="w-full space-y-6 mc-fade">
        <div className="glass-card h-28 animate-pulse" />
        <div className="glass-card h-40 animate-pulse" />
      </section>
    );
  }

  if (!overview) {
    return (
      <section className="w-full space-y-6 mc-fade">
        <div className="surface-empty p-6">
          {isRu ? "Нет данных по сводке." : "No summary data."}
        </div>
      </section>
    );
  }

  return (
    <section className="w-full space-y-6 mc-fade">
      {showLowDataNote && (
        <div className="surface-empty p-4">
          {isRu ? "Недостаточно матчей для устойчивых выводов. Используй данные как ориентир, а не сигнал." : "Not enough matches for stable conclusions. Use the data as a guide, not as a signal."}
        </div>
      )}

      <div className="flex items-center justify-between gap-3">
        <div className="flex items-center gap-2 text-[13px] font-medium text-white/85">
          <span className="inline-block h-3 w-[3px] rounded-full bg-[#8B5CF6]" />
          {isRu ? "Статистика команды" : "Team stats"}
        </div>
        <div className="flex items-center gap-2 pr-1">
          <span className="text-[12px] text-white/50">{isRu ? "Период:" : "Period:"}</span>
          <PeriodSwitch value={period} onChange={setPeriod} />
        </div>
      </div>

      <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <KpiCard
          title={isRu ? "Матчей" : "Matches"}
          value={periodStats.matches ?? "—"}
          tooltip={isRu ? `Сыгранные матчи ${periodLabel}` : `Played matches ${periodLabel}`}
          icon={
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor">
              <path d="M7 3h10a2 2 0 0 1 2 2v3H5V5a2 2 0 0 1 2-2zm-2 8h14v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6zm4 1v6h2v-6H9zm4 0v6h2v-6h-2z" />
            </svg>
          }
        />
        <KpiCard
          title={isRu ? "Очки / Место" : "Points / Rank"}
          value={periodStats.points != null ? `${periodStats.points}` : "—"}
          tooltip={isRu ? `Очки ${periodLabel} (место по таблице сезона)` : `Points ${periodLabel} (rank in season table)`}
          sub={selectedRank != null ? `${isRu ? "Ранг" : "Rank"}: ${selectedRank}` : undefined}
          icon={
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor">
              <path d="M12 2l2.39 4.84 5.34.78-3.86 3.76.91 5.32L12 14.77 6.22 16.7l.91-5.32L3.27 7.62l5.34-.78L12 2z" />
            </svg>
          }
        />
        <KpiCard
          title="В-Н-П"
          value={`${periodStats.wins ?? 0}-${periodStats.draws ?? 0}-${periodStats.losses ?? 0}`}
          tooltip={isRu ? `Победы/ничьи/поражения ${periodLabel}` : `Wins/draws/losses ${periodLabel}`}
          sub={isRu ? "Распределение результатов" : "Result distribution"}
          icon={
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor">
              <path d="M3 3h18v4H3zM3 10h18v4H3zM3 17h18v4H3z" />
            </svg>
          }
        />
        <KpiCard
          title={isRu ? "Голы (за / проп.)" : "Goals (for / against)"}
          value={`${periodStats.goalsFor ?? 0} / ${periodStats.goalsAgainst ?? 0}`}
          tooltip={isRu ? `Голы ${periodLabel}` : `Goals ${periodLabel}`}
          sub={
            periodStats.goalsFor != null && periodStats.goalsAgainst != null
              ? `${isRu ? "Разница" : "Difference"}: ${periodStats.goalsFor - periodStats.goalsAgainst}`
              : undefined
          }
          icon={
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor">
              <path d="M12 5a7 7 0 100 14 7 7 0 000-14zm-1 10l-3-3 1.41-1.41L11 11.17l3.59-3.58L16 9l-5 6z" />
            </svg>
          }
        />
      </div>

      <div className="glass-card p-6">
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <KpiCard
            title={isRu ? "Голы за игру" : "Goals per match"}
            value={fmtNumLocal(periodStats.goalsPer, 2)}
            tooltip={isRu ? `Средние голы за матч ${periodLabel}` : `Average goals per match ${periodLabel}`}
          />
          <KpiCard
            title={isRu ? "Пропускает за игру" : "Conceded per match"}
            value={fmtNumLocal(periodStats.concededPer, 2)}
            tooltip={isRu ? `Средние пропущенные за матч ${periodLabel}` : `Average goals conceded per match ${periodLabel}`}
          />
          <KpiCard
            title="xG за игру"
            value={fmtNumLocal(periodStats.xgPer, 2)}
            tooltip={isRu ? `Ожидаемые голы за матч ${periodLabel}` : `Expected goals per match ${periodLabel}`}
          />
          <KpiCard
            title="xGA за игру"
            value={fmtNumLocal(periodStats.xgaPer, 2)}
            tooltip={isRu ? `Ожидаемые пропущенные за матч ${periodLabel}` : `Expected goals conceded per match ${periodLabel}`}
          />
          <KpiCard
            title={isRu ? "Удары (сред.)" : "Shots (avg.)"}
            value={fmtNumLocal(periodStats.shotsAvg, 1)}
            tooltip={isRu ? `Средние удары за матч ${periodLabel}` : `Average shots per match ${periodLabel}`}
          />
          <KpiCard
            title={isRu ? "Владение (сред.)" : "Possession (avg.)"}
            value={
              periodStats.possessionAvg != null
                ? `${fmtNumLocal(periodStats.possessionAvg, 1)}%`
                : "—"
            }
            tooltip={isRu ? `Среднее владение мячом ${periodLabel}` : `Average possession ${periodLabel}`}
          />
          <KpiCard
            title={isRu ? "Темп (уд./игру)" : "Tempo (shots/game)"}
            value={fmtNumLocal(periodStats.tempoAvg, 1)}
            tooltip={isRu ? `Темп атак ${periodLabel}` : `Attacking tempo ${periodLabel}`}
          />
        </div>
        <div className="mt-4 flex items-center justify-between">
          <div className="flex items-center gap-2 text-[12px] text-white/55">
            <span className="inline-block h-2 w-2 rounded-full bg-[#8B5CF6]" />
            {isRu ? "Форма за выбранный период" : "Form for selected period"}
          </div>
          <RadarChart
            key={period}
            data={{
              xg: periodStats.xgPer,
              conceded: periodStats.concededPer,
              shots: periodStats.shotsAvg,
              possession: periodStats.possessionAvg,
              tempo: periodStats.tempoAvg,
            }}
          />
        </div>
      </div>
    </section>
  );
}

export function TeamScheduleSection({
  loadingS,
  groupedSchedule,
  expandedScheduleId,
  expandedScheduleData,
  handleToggleSchedule,
  parseMatchDate,
  toDDMM,
  formatHHMM,
  hasSubscription,
  openSubscription,
  openMatchInResults,
  logoSrc,
  logoFallbackSrc,
  teamId,
}) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  return (
    <section className="w-full space-y-6 mc-fade">
      {loadingS && <div className="glass-card h-24 animate-pulse" />}

      {!loadingS && groupedSchedule.length === 0 && (
        <div className="surface-empty p-6">
          {isRu ? "Нет будущих матчей." : "No upcoming matches."}
        </div>
      )}

      {!loadingS &&
        groupedSchedule.map(([week, matches]) => (
          <div key={week} className="space-y-2">
            <div className="text-xs uppercase tracking-[0.24em] text-white/35 mt-2 mb-2">
              {isRu ? "Тур" : "Round"} {week}
            </div>
            {matches.map((m, idx) => {
              const leftId = m.home_team_id;
              const rightId = m.away_team_id;
              const leftName = m.home_team;
              const rightName = m.away_team;
              const matchDate = parseMatchDate(m);
              const dateLabel = toDDMM(m.datetime || m.date);
              const timeLabel = matchDate ? formatHHMM(matchDate) : "";
              const centerLine = timeLabel ? `${dateLabel} · ${timeLabel}` : dateLabel;
              const roundLabel =
                m.round_label != null
                  ? `${isRu ? "Тур" : "Round"} ${String(m.round_label).replace(/\D/g, "")}`
                  : week != null && week !== "—"
                  ? `${isRu ? "Тур" : "Round"} ${String(week).replace(/\D/g, "")}`
                  : null;

              const isExpanded = expandedScheduleId === m.fixture_id;
              const pack = expandedScheduleData[m.fixture_id];

              return (
                <div
                  key={m.fixture_id || `${m.home_team_id}-${m.away_team_id}-${idx}`}
                  className={clsx(
                    "glass-card group relative overflow-hidden transition-all duration-200",
                    "hover:bg-[rgba(255,255,255,0.05)]",
                    isExpanded && "bg-[rgba(255,255,255,0.06)] shadow-[0_16px_40px_rgba(0,0,0,0.22)]"
                  )}
                >
                  <span
                    className={clsx(
                      "pointer-events-none absolute left-0 top-3 bottom-3 w-[3px] rounded-full",
                      isExpanded ? "bg-violet-400/80" : "bg-white/10"
                    )}
                  />
                  <button
                    type="button"
                    onClick={() => handleToggleSchedule(m)}
                    className="w-full cursor-pointer px-3 py-3 text-left sm:px-5 sm:py-4"
                  >
                    <div className="grid grid-cols-[minmax(0,1fr)_88px_minmax(0,1fr)] items-center gap-2 sm:grid-cols-[1fr_auto_1fr_auto] sm:gap-4">
                      <div className="flex min-h-[48px] min-w-0 items-center gap-2 sm:min-h-[56px] sm:gap-3">
                        <LogoBadge src={logoSrc(leftId, leftName)} fallbackSrc={logoFallbackSrc(leftId, leftName)} name={leftName} size={24} imgSize={16} />
                        <span className="truncate text-[13px] font-medium text-white sm:text-[15px]">{leftName}</span>
                      </div>

                      <div className="flex min-w-0 flex-col items-center gap-1 px-1">
                        <span className="text-center text-[11px] text-white/80 tabular-nums sm:text-[13px]">{centerLine}</span>
                        {roundLabel && <span className="text-center text-[10px] text-white/45 sm:text-[11px]">{roundLabel}</span>}
                      </div>

                      <div className="flex min-h-[48px] min-w-0 items-center justify-end gap-2 sm:min-h-[56px] sm:gap-3">
                        <span className="truncate text-right text-[13px] font-medium text-white sm:text-[15px]">{rightName}</span>
                        <LogoBadge src={logoSrc(rightId, rightName)} fallbackSrc={logoFallbackSrc(rightId, rightName)} name={rightName} size={24} imgSize={16} />
                      </div>

                      <div
                        className={clsx(
                          "hidden text-white/40 transition-transform duration-200 group-hover:text-white/70 sm:block",
                          isExpanded && "rotate-180 text-white/70"
                        )}
                        aria-hidden="true"
                      >
                        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor">
                          <path d="M7 10l5 5 5-5H7z" />
                        </svg>
                      </div>
                    </div>
                  </button>

                  <div
                    className={clsx(
                      "overflow-hidden transition-all duration-200 ease-in-out",
                      isExpanded ? "max-h-[2000px] opacity-100" : "max-h-0 opacity-0"
                    )}
                  >
                    <div className="px-4 pb-4 pt-1 md:px-5">
                      {pack?.loading && <div className="surface-loading">{isRu ? "Загружаем…" : "Loading…"}</div>}
                      {pack?.error && <div className="surface-error">{isRu ? "Ошибка" : "Error"}: {pack.error}</div>}
                      {!pack?.loading && !pack?.error && (
                        <div className="space-y-4">
                          {hasSubscription ? (
                            <ForecastHero match={m} />
                          ) : (
                            <ForecastHero match={m} locked blurBody onUpgrade={openSubscription} />
                          )}

                          <div className="glass-card px-4 py-4">
                            <div className="text-[11px] uppercase tracking-[0.18em] text-white/50">
                              {isRu ? "Средние показатели (посл. 10)" : "Average metrics (last 10)"}
                            </div>
                            <div className="mt-2 flex items-center justify-between text-[11px] text-white/45">
                              <span>{m.home_team}</span>
                              <span>{m.away_team}</span>
                            </div>
                            <div className="mt-3 space-y-3">
                              <AvgCompareRow label="xG" left={pack?.homeAvg?.xg} right={pack?.awayAvg?.xg} />
                              <AvgCompareRow label={isRu ? "Удары" : "Shots"} left={pack?.homeAvg?.shots} right={pack?.awayAvg?.shots} />
                              <AvgCompareRow
                                label={isRu ? "Владение" : "Possession"}
                                left={pack?.homeAvg?.possession}
                                right={pack?.awayAvg?.possession}
                                isPercent
                              />
                            </div>
                          </div>

                          <div className="glass-card px-4 py-4">
                            <MatchInsightsPanelFull
                              pack={pack}
                              teamId={teamId}
                              home={m.home_team}
                              away={m.away_team}
                              onOpenMatchModal={(fixtureId) => openMatchInResults(fixtureId)}
                              variant="flat"
                              hideAvgs
                            />
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        ))}
    </section>
  );
}
