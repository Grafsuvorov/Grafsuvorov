// src/components/MatchInsightsPanelFull.jsx
import React from "react";
import clsx from "clsx";
import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* ================================
   ЛОГО — как в TeamPage
================================ */
const teamLogoPath = (id) => (id ? `/icons/team_logos/${id}.png` : null);
const fallbackTeam = (name) =>
  teamLogoMap[name] || "/icons/team_logos/default.png";
const logoSafe = (id, name) => teamLogoPath(id) || fallbackTeam(name);
const logoFallback = (id, name) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : fallbackTeam(name);

/* ================================
   Сокращение названий
================================ */
function shortName(name) {
  if (!name) return "";
  let s = String(name)
    .replace(/football|club|fc|cf|sc|ac|bk|fk/gi, "")
    .trim();

  const parts = s.split(/\s+/);

  const longKeep = [
    "Chelsea",
    "Arsenal",
    "Barcelona",
    "Liverpool",
    "Leverkusen",
    "Bayern",
    "Juventus",
    "Tottenham",
    "Newcastle",
  ];
  for (const key of longKeep) {
    if (s.toLowerCase().includes(key.toLowerCase())) return key;
  }

  if (parts.length >= 2) {
    return parts[0].slice(0, 3) + ". " + parts[1];
  }
  return parts[0];
}

/* ================================
   Короткая дата
================================ */
function formatShortDate(d, language = "ru") {
  if (!d) return "";
  try {
    return new Date(d).toLocaleDateString(language === "ru" ? "ru-RU" : "en-GB", {
      day: "2-digit",
      month: "2-digit",
    });
  } catch {
    return d;
  }
}

/* ================================
   Главное окно
================================ */
export default function MatchInsightsPanelFull({
  pack,
  home,
  away,
  teamId,
  onOpenMatchModal, // теперь используем как в TeamPage
  variant = "default",
  hideAvgs = false,
}) {
  const { language } = useLanguage();
  if (!pack) return null;
  const mt = language === "ru"
    ? {
        avg: "Средние показатели (последние 10 матчей)",
        h2h: "Личные встречи (H2H, посл. 5)",
        form: "Форма (последние 5)",
        last5Matches: "Последние 5 (матчи)",
        last5: "Последние 5",
        noH2H: "Нет данных по H2H.",
        shots: "Удары",
        shotsOn: "В створ",
        corners: "Угловые",
        possession: "Владение",
      }
    : {
        avg: "Average metrics (last 10 matches)",
        h2h: "Head-to-head (last 5)",
        form: "Form (last 5)",
        last5Matches: "Last 5 matches",
        last5: "Last 5",
        noH2H: "No H2H data available.",
        shots: "Shots",
        shotsOn: "Shots on target",
        corners: "Corners",
        possession: "Possession",
      };

  const h2h = pack.h2h || [];
  const homeLast = pack.homeLast || [];
  const awayLast = pack.awayLast || [];
  const homeAvg = pack.homeAvg || {};
  const awayAvg = pack.awayAvg || {};
  const isFlat = variant === "flat";

  return (
    <div className="w-full min-w-0 flex flex-col gap-6 sm:gap-8">

      {/* ============================
          СРЕДНИЕ ПОКАЗАТЕЛИ
      ============================ */}
      {!hideAvgs && (
        <Section title={mt.avg} variant={variant}>
          <div className="grid grid-cols-1 gap-6 px-0 sm:gap-8 sm:px-2 md:grid-cols-2 md:gap-12 md:px-4">
            <TeamAvgBlock team={home} avg={homeAvg} />
            <TeamAvgBlock team={away} avg={awayAvg} />
          </div>
        </Section>
      )}

      {/* ============================
          H2H
      ============================ */}
      <Section title={mt.h2h} variant={variant}>
        {isFlat ? (
          <H2HList rows={h2h.slice(0, 5)} onOpenMatchModal={onOpenMatchModal} />
        ) : (
          <ListMatches
            rows={h2h}
            teamId={teamId}
            onOpenMatchModal={onOpenMatchModal}
          />
        )}
      </Section>

      {isFlat && (
        <Section title={mt.form} variant={variant}>
          <FormCompare
            homeTeam={home}
            awayTeam={away}
            homeRows={homeLast}
            awayRows={awayLast}
          />
        </Section>
      )}

      {isFlat && (
        <Section title={mt.last5Matches} variant={variant}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="min-w-0">
              <div className="mb-2 truncate text-[12px] text-white/60">{home}</div>
              <FlatList rows={homeLast} onOpenMatchModal={onOpenMatchModal} />
            </div>
            <div className="min-w-0">
              <div className="mb-2 truncate text-[12px] text-white/60">{away}</div>
              <FlatList rows={awayLast} onOpenMatchModal={onOpenMatchModal} />
            </div>
          </div>
        </Section>
      )}

      {!isFlat ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <Section title={`${mt.last5} • ${home || ""}`} variant={variant}>
            <ListMatches
              rows={homeLast}
              teamId={teamId}
              onOpenMatchModal={onOpenMatchModal}
            />
          </Section>

          <Section title={`${mt.last5} • ${away || ""}`} variant={variant}>
            <ListMatches
              rows={awayLast}
              teamId={teamId}
              onOpenMatchModal={onOpenMatchModal}
            />
          </Section>
        </div>
      ) : null}
    </div>
  );
}

/* ================================
   UI wrappers
================================ */

function Section({ title, children, variant = "default" }) {
  const isFlat = variant === "flat";
  return (
    <div
      className={
        isFlat
          ? "w-full p-0"
          : "w-full overflow-hidden rounded-xl border border-glass bg-surface-1/90 p-4 shadow-sm sm:p-6"
      }
    >
      <h3 className={isFlat ? "mb-2.5 break-words text-[13px] font-semibold text-white/85 sm:mb-3" : "mb-3 break-words text-[14px] font-semibold text-slate-100 sm:mb-4 sm:text-[16px]"}>
        {title}
      </h3>
      {children}
    </div>
  );
}

/* ================================
   CLICKABLE MATCH ROW
   (ПОЛНОСТЬЮ РАБОЧИЙ)
================================ */
function ClickableRow({ match, teamId, onOpenMatchModal }) {
  const { language } = useLanguage();
  const leftTeam = shortName(match.home_team);
  const rightTeam = shortName(match.away_team);

  const leftLogo = logoSafe(match.home_team_id, match.home_team);
  const rightLogo = logoSafe(match.away_team_id, match.away_team);

  return (
    <div
      onClick={() => onOpenMatchModal(match.fixture_id, match)}
      className="grid min-w-0 grid-cols-[minmax(0,1fr)_56px_minmax(0,1fr)] items-center gap-1 rounded-lg px-1.5 py-2.5 transition hover:bg-white/5 sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] sm:gap-3 sm:px-2 sm:py-3"
    >
      <div className="flex min-w-0 items-center gap-1.5 sm:gap-2">
        <TeamLogoLink teamId={match.home_team_id} stopPropagation className="block">
          <SafeImg src={leftLogo} className="h-4 w-4 sm:h-6 sm:w-6" alt="" fallbackSrc={logoFallback(match.home_team_id, match.home_team)} />
        </TeamLogoLink>
        <span className="truncate text-[11px] text-slate-200 sm:text-sm">{leftTeam}</span>
      </div>

      <div className="min-w-0 flex flex-col items-center text-center">
        <span className="text-[12px] font-semibold text-slate-100 sm:text-[15px]">{match.score}</span>
        <span className="truncate text-[10px] text-slate-400 sm:text-xs">
          {formatShortDate(match.date, language)}
        </span>
      </div>

      <div className="flex min-w-0 items-center justify-end gap-1.5 sm:gap-2">
        <span className="truncate text-right text-[11px] text-slate-200 sm:text-sm">{rightTeam}</span>
        <TeamLogoLink teamId={match.away_team_id} stopPropagation className="block">
          <SafeImg src={rightLogo} className="h-4 w-4 sm:h-6 sm:w-6" alt="" fallbackSrc={logoFallback(match.away_team_id, match.away_team)} />
        </TeamLogoLink>
      </div>
    </div>
  );
}


/* ================================
   LIST OF MATCHES (H2H + LAST5)
================================ */
function ListMatches({ rows, teamId, onOpenMatchModal }) {
  return (
    <div className="flex flex-col divide-y divide-glass">
      {rows.map((m) => (
        <ClickableRow
          key={m.fixture_id}
          match={m}
          teamId={teamId}
          onOpenMatchModal={onOpenMatchModal}
        />
      ))}
    </div>
  );
}

function H2HRow({ match }) {
  const { language } = useLanguage();
  const leftLogo = logoSafe(match.home_team_id, match.home_team);
  const rightLogo = logoSafe(match.away_team_id, match.away_team);
  return (
    <div className="flex min-w-0 flex-col items-center gap-2 text-white/85">
      <div className="flex min-w-0 items-center justify-center gap-2 sm:gap-3">
        <TeamLogoLink teamId={match.home_team_id} stopPropagation className="block">
            <SafeImg src={leftLogo} className="h-6 w-6 sm:h-7 sm:w-7" alt="" fallbackSrc={logoFallback(match.home_team_id, match.home_team)} />
        </TeamLogoLink>
        <span className="min-w-0 truncate text-[14px] font-semibold tabular-nums sm:text-[16px]">{match.score || "—"}</span>
        <TeamLogoLink teamId={match.away_team_id} stopPropagation className="block">
            <SafeImg src={rightLogo} className="h-6 w-6 sm:h-7 sm:w-7" alt="" fallbackSrc={logoFallback(match.away_team_id, match.away_team)} />
        </TeamLogoLink>
      </div>
      <div className="text-[12px] text-white/45">{formatShortDate(match.date, language)}</div>
    </div>
  );
}

function H2HList({ rows, onOpenMatchModal }) {
  const { language } = useLanguage();
  if (!rows?.length) {
    return <div className="text-[12px] text-white/50">{language === "ru" ? "Нет данных по H2H." : "No H2H data available."}</div>;
  }
  return (
    <div className="flex flex-col divide-y divide-white/6">
      {rows.map((m) => (
        <button
          key={m.fixture_id}
          type="button"
          onClick={() => onOpenMatchModal?.(m.fixture_id, m)}
          className={clsx(
            "grid min-w-0 grid-cols-[minmax(0,1fr)_56px_minmax(0,1fr)] items-center gap-1 py-2.5 text-left text-[11px] text-white/85 transition-colors sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] sm:gap-3 sm:text-[13px]",
            onOpenMatchModal ? "hover:bg-white/[0.04]" : ""
          )}
        >
          <div className="flex min-w-0 items-center gap-1.5 sm:gap-2">
          <TeamLogoLink teamId={m.home_team_id} stopPropagation className="block">
            <SafeImg src={logoSafe(m.home_team_id, m.home_team)} className="h-4 w-4 sm:h-5 sm:w-5" alt="" fallbackSrc={logoFallback(m.home_team_id, m.home_team)} />
          </TeamLogoLink>
            <span className="truncate">{shortName(m.home_team)}</span>
          </div>
          <div className="min-w-0 flex flex-col items-center">
            <span className="text-white/90 tabular-nums">{m.score || "—"}</span>
            <span className="truncate text-[11px] text-white/45">{formatShortDate(m.date, language)}</span>
          </div>
          <div className="flex min-w-0 items-center justify-end gap-1.5 sm:gap-2">
            <span className="truncate text-right">{shortName(m.away_team)}</span>
          <TeamLogoLink teamId={m.away_team_id} stopPropagation className="block">
            <SafeImg src={logoSafe(m.away_team_id, m.away_team)} className="h-4 w-4 sm:h-5 sm:w-5" alt="" fallbackSrc={logoFallback(m.away_team_id, m.away_team)} />
          </TeamLogoLink>
          </div>
        </button>
      ))}
    </div>
  );
}

function FlatList({ rows, onOpenMatchModal }) {
  const { language } = useLanguage();
  return (
    <div className="flex flex-col divide-y divide-white/6">
      {rows.map((m) => {
        const clickable = typeof onOpenMatchModal === "function";
        return (
          <button
            key={m.fixture_id}
            type="button"
            onClick={() => clickable && onOpenMatchModal(m.fixture_id, m)}
            className={clsx(
              "grid min-w-0 grid-cols-[minmax(0,1fr)_56px_minmax(0,1fr)] items-center gap-1 py-2.5 text-[11px] sm:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] sm:gap-3 sm:py-3 sm:text-[13px]",
              "text-white/85 transition-colors",
              clickable ? "hover:bg-white/[0.04]" : ""
            )}
          >
            <div className="flex min-w-0 items-center gap-1.5 sm:gap-2">
              <TeamLogoLink teamId={m.home_team_id} stopPropagation className="block">
                <SafeImg src={logoSafe(m.home_team_id, m.home_team)} className="h-4 w-4 sm:h-5 sm:w-5" alt="" fallbackSrc={logoFallback(m.home_team_id, m.home_team)} />
              </TeamLogoLink>
              <span className="truncate">{shortName(m.home_team)}</span>
            </div>
            <span className="min-w-0 truncate text-center text-white/90 tabular-nums">{m.score || "—"}</span>
            <div className="flex min-w-0 items-center justify-end gap-1.5 sm:gap-2">
              <span className="truncate text-right">{shortName(m.away_team)}</span>
              <TeamLogoLink teamId={m.away_team_id} stopPropagation className="block">
                <SafeImg src={logoSafe(m.away_team_id, m.away_team)} className="h-4 w-4 sm:h-5 sm:w-5" alt="" fallbackSrc={logoFallback(m.away_team_id, m.away_team)} />
              </TeamLogoLink>
            </div>
          </button>
        );
      })}
    </div>
  );
}

function FormRow({ rows, teamName }) {
  const results = rows
    .map((m) => {
      const hg = Number(m.home_goals);
      const ag = Number(m.away_goals);
      if (!Number.isFinite(hg) || !Number.isFinite(ag)) return null;
      const isHome = String(m.home_team) === String(teamName);
      const gf = isHome ? hg : ag;
      const ga = isHome ? ag : hg;
      if (gf > ga) return "W";
      if (gf < ga) return "L";
      return "D";
    })
    .filter(Boolean);

  return (
    <div className="flex flex-wrap items-center gap-1.5 sm:gap-2">
      {results.map((r, i) => (
        <span
          key={`${teamName}-${i}-${r}`}
          className={
            r === "W"
              ? "inline-flex h-6 w-6 items-center justify-center rounded-full bg-emerald-500/90 text-[11px] font-semibold text-white shadow-[0_0_10px_rgba(16,185,129,0.35)] sm:h-7 sm:w-7 sm:text-[12px]"
              : r === "L"
              ? "inline-flex h-6 w-6 items-center justify-center rounded-full bg-rose-500/90 text-[11px] font-semibold text-white sm:h-7 sm:w-7 sm:text-[12px]"
              : "inline-flex h-6 w-6 items-center justify-center rounded-full bg-amber-400/90 text-[11px] font-semibold text-slate-950 sm:h-7 sm:w-7 sm:text-[12px]"
          }
        >
          {r}
        </span>
      ))}
    </div>
  );
}

function FormCompare({ homeTeam, awayTeam, homeRows, awayRows }) {
  const resolveTeamId = (rows, name) => {
    if (!rows?.length || !name) return null;
    for (const m of rows) {
      if (String(m.home_team) === String(name)) return m.home_team_id || null;
      if (String(m.away_team) === String(name)) return m.away_team_id || null;
    }
    return null;
  };
  const homeId = resolveTeamId(homeRows, homeTeam);
  const awayId = resolveTeamId(awayRows, awayTeam);
  const homeLogo = logoSafe(homeId, homeTeam);
  const awayLogo = logoSafe(awayId, awayTeam);
  return (
    <div className="grid min-w-0 grid-cols-1 gap-3 md:grid-cols-2 md:gap-6">
      <div className="min-w-0 space-y-2">
        <div className="flex min-w-0 items-center gap-2">
          <TeamLogoLink teamId={homeId} stopPropagation className="block">
            <SafeImg src={homeLogo} className="w-5 h-5" alt="" fallbackSrc={logoFallback(homeId, homeTeam)} />
          </TeamLogoLink>
          <span className="text-[13px] text-white/70 truncate">{homeTeam}</span>
        </div>
        <FormRow rows={homeRows} teamName={homeTeam} />
      </div>
      <div className="min-w-0 space-y-2 md:items-end md:text-right">
        <div className="flex min-w-0 items-center gap-2 md:justify-end">
          <span className="text-[13px] text-white/70 truncate">{awayTeam}</span>
          <TeamLogoLink teamId={awayId} stopPropagation className="block">
            <SafeImg src={awayLogo} className="w-5 h-5" alt="" fallbackSrc={logoFallback(awayId, awayTeam)} />
          </TeamLogoLink>
        </div>
        <div className="md:flex md:justify-end">
          <FormRow rows={awayRows} teamName={awayTeam} />
        </div>
      </div>
    </div>
  );
}

/* ================================
   Средние показатели
================================ */
function TeamAvgBlock({ team, avg }) {
  const { language } = useLanguage();
  const metrics = [
    ["xG", avg.xg],
    [language === "ru" ? "Удары" : "Shots", avg.shots],
    [language === "ru" ? "В створ" : "Shots on target", avg.shots_on],
    [language === "ru" ? "Угловые" : "Corners", avg.corners],
    [language === "ru" ? "Владение" : "Possession", avg.possession],
  ];

  return (
    <div className="flex min-w-0 flex-col gap-3 sm:gap-4">
      <h4 className="truncate font-semibold text-slate-200">{team}</h4>

      <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2 sm:gap-4">
        {metrics.map(([label, v]) => (
          <div
            key={label}
            className="flex min-w-0 flex-col items-center overflow-hidden rounded-lg border border-glass bg-surface-2 px-3 py-3 sm:p-4"
          >
            <span className="truncate text-center text-xs text-slate-400">{label}</span>
            <span className="text-base font-semibold text-slate-100 sm:text-lg">
              {v == null ? "—" : Number(v).toFixed(2)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
