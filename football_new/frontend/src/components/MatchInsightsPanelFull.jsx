// src/components/MatchInsightsPanelFull.jsx
import React from "react";
import clsx from "clsx";
import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";
import { teamLogoMap } from "@/constants/teamLogoMap";

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
function formatShortDate(d) {
  if (!d) return "";
  try {
    return new Date(d).toLocaleDateString("ru-RU", {
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
  if (!pack) return null;

  const h2h = pack.h2h || [];
  const homeLast = pack.homeLast || [];
  const awayLast = pack.awayLast || [];
  const homeAvg = pack.homeAvg || {};
  const awayAvg = pack.awayAvg || {};
  const isFlat = variant === "flat";

  return (
    <div className="w-full flex flex-col gap-8">

      {/* ============================
          СРЕДНИЕ ПОКАЗАТЕЛИ
      ============================ */}
      {!hideAvgs && (
        <Section title="Средние показатели (последние 10 матчей)" variant={variant}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12 px-4">
            <TeamAvgBlock team={home} avg={homeAvg} />
            <TeamAvgBlock team={away} avg={awayAvg} />
          </div>
        </Section>
      )}

      {/* ============================
          H2H
      ============================ */}
      <Section title="Личные встречи (H2H, посл. 5)" variant={variant}>
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
        <Section title="Форма (последние 5)" variant={variant}>
          <FormCompare
            homeTeam={home}
            awayTeam={away}
            homeRows={homeLast}
            awayRows={awayLast}
          />
        </Section>
      )}

      {isFlat && (
        <Section title="Последние 5 (матчи)" variant={variant}>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <div className="text-[12px] text-white/60 mb-2">{home}</div>
              <FlatList rows={homeLast} onOpenMatchModal={onOpenMatchModal} />
            </div>
            <div>
              <div className="text-[12px] text-white/60 mb-2">{away}</div>
              <FlatList rows={awayLast} onOpenMatchModal={onOpenMatchModal} />
            </div>
          </div>
        </Section>
      )}

      {!isFlat ? (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <Section title={`Последние 5 • ${home || ""}`} variant={variant}>
            <ListMatches
              rows={homeLast}
              teamId={teamId}
              onOpenMatchModal={onOpenMatchModal}
            />
          </Section>

          <Section title={`Последние 5 • ${away || ""}`} variant={variant}>
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
          : "w-full border border-glass rounded-xl bg-surface-1/90 p-6 shadow-sm"
      }
    >
      <h3 className={isFlat ? "text-[13px] font-semibold text-white/85 mb-3" : "font-semibold text-slate-100 mb-4"}>
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
  const leftTeam = shortName(match.home_team);
  const rightTeam = shortName(match.away_team);

  const leftLogo = logoSafe(match.home_team_id, match.home_team);
  const rightLogo = logoSafe(match.away_team_id, match.away_team);

  return (
    <div
      onClick={() => onOpenMatchModal(match.fixture_id, match)}

      className="flex items-center justify-between py-3 cursor-pointer hover:bg-white/5 transition px-2 rounded-lg"
    >
      {/* LEFT */}
      <div className="flex items-center gap-2 w-1/3">
        <TeamLogoLink teamId={match.home_team_id} stopPropagation className="block">
          <SafeImg src={leftLogo} className="w-6 h-6" alt="" fallbackSrc={logoFallback(match.home_team_id, match.home_team)} />
        </TeamLogoLink>
        <span className="text-sm text-slate-200 truncate">{leftTeam}</span>
      </div>

      {/* CENTER */}
      <div className="flex flex-col items-center w-1/3 text-center">
        <span className="font-semibold text-slate-100">{match.score}</span>
        <span className="text-xs text-slate-400">
          {formatShortDate(match.date)}
        </span>
      </div>

      {/* RIGHT */}
      <div className="flex items-center gap-2 justify-end w-1/3">
        <span className="text-sm text-slate-200 truncate">{rightTeam}</span>
        <TeamLogoLink teamId={match.away_team_id} stopPropagation className="block">
          <SafeImg src={rightLogo} className="w-6 h-6" alt="" fallbackSrc={logoFallback(match.away_team_id, match.away_team)} />
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
  const leftLogo = logoSafe(match.home_team_id, match.home_team);
  const rightLogo = logoSafe(match.away_team_id, match.away_team);
  return (
    <div className="flex flex-col items-center gap-2 text-white/85">
      <div className="flex items-center justify-center gap-3">
        <TeamLogoLink teamId={match.home_team_id} stopPropagation className="block">
            <SafeImg src={leftLogo} className="w-7 h-7" alt="" fallbackSrc={logoFallback(match.home_team_id, match.home_team)} />
        </TeamLogoLink>
        <span className="text-[16px] font-semibold tabular-nums">{match.score || "—"}</span>
        <TeamLogoLink teamId={match.away_team_id} stopPropagation className="block">
            <SafeImg src={rightLogo} className="w-7 h-7" alt="" fallbackSrc={logoFallback(match.away_team_id, match.away_team)} />
        </TeamLogoLink>
      </div>
      <div className="text-[12px] text-white/45">{formatShortDate(match.date)}</div>
    </div>
  );
}

function H2HList({ rows, onOpenMatchModal }) {
  if (!rows?.length) {
    return <div className="text-[12px] text-white/50">Нет данных по H2H.</div>;
  }
  return (
    <div className="flex flex-col divide-y divide-white/6">
      {rows.map((m) => (
        <button
          key={m.fixture_id}
          type="button"
          onClick={() => onOpenMatchModal?.(m.fixture_id, m)}
          className={clsx(
            "py-2.5 grid grid-cols-[1fr_auto_1fr] items-center gap-3 text-[13px] text-white/85 text-left transition-colors",
            onOpenMatchModal ? "hover:bg-white/[0.04]" : ""
          )}
        >
          <div className="flex items-center gap-2 min-w-0">
          <TeamLogoLink teamId={m.home_team_id} stopPropagation className="block">
            <SafeImg src={logoSafe(m.home_team_id, m.home_team)} className="w-5 h-5" alt="" fallbackSrc={logoFallback(m.home_team_id, m.home_team)} />
          </TeamLogoLink>
            <span className="truncate">{shortName(m.home_team)}</span>
          </div>
          <div className="flex flex-col items-center">
            <span className="text-white/90 tabular-nums">{m.score || "—"}</span>
            <span className="text-[11px] text-white/45">{formatShortDate(m.date)}</span>
          </div>
          <div className="flex items-center gap-2 min-w-0 justify-end">
            <span className="truncate text-right">{shortName(m.away_team)}</span>
          <TeamLogoLink teamId={m.away_team_id} stopPropagation className="block">
            <SafeImg src={logoSafe(m.away_team_id, m.away_team)} className="w-5 h-5" alt="" fallbackSrc={logoFallback(m.away_team_id, m.away_team)} />
          </TeamLogoLink>
          </div>
        </button>
      ))}
    </div>
  );
}

function FlatList({ rows, onOpenMatchModal }) {
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
              "py-3 grid grid-cols-[1fr_auto_1fr] items-center gap-3 text-[13px]",
              "text-white/85 transition-colors",
              clickable ? "hover:bg-white/[0.04]" : ""
            )}
          >
            <div className="flex items-center gap-2 min-w-0">
              <TeamLogoLink teamId={m.home_team_id} stopPropagation className="block">
                <SafeImg src={logoSafe(m.home_team_id, m.home_team)} className="w-5 h-5" alt="" fallbackSrc={logoFallback(m.home_team_id, m.home_team)} />
              </TeamLogoLink>
              <span className="truncate">{shortName(m.home_team)}</span>
            </div>
            <span className="text-white/90 tabular-nums">{m.score || "—"}</span>
            <div className="flex items-center gap-2 min-w-0 justify-end">
              <span className="truncate text-right">{shortName(m.away_team)}</span>
              <TeamLogoLink teamId={m.away_team_id} stopPropagation className="block">
                <SafeImg src={logoSafe(m.away_team_id, m.away_team)} className="w-5 h-5" alt="" fallbackSrc={logoFallback(m.away_team_id, m.away_team)} />
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
    <div className="flex items-center gap-2">
      {results.map((r, i) => (
        <span
          key={`${teamName}-${i}-${r}`}
          className={
            r === "W"
              ? "inline-flex h-7 w-7 items-center justify-center rounded-full bg-emerald-500/90 text-white text-[12px] font-semibold shadow-[0_0_10px_rgba(16,185,129,0.35)]"
              : r === "L"
              ? "inline-flex h-7 w-7 items-center justify-center rounded-full bg-rose-500/90 text-white text-[12px] font-semibold"
              : "inline-flex h-7 w-7 items-center justify-center rounded-full bg-amber-400/90 text-slate-950 text-[12px] font-semibold"
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
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <TeamLogoLink teamId={homeId} stopPropagation className="block">
            <SafeImg src={homeLogo} className="w-5 h-5" alt="" fallbackSrc={logoFallback(homeId, homeTeam)} />
          </TeamLogoLink>
          <span className="text-[13px] text-white/70 truncate">{homeTeam}</span>
        </div>
        <FormRow rows={homeRows} teamName={homeTeam} />
      </div>
      <div className="space-y-2 md:items-end md:text-right">
        <div className="flex items-center gap-2 md:justify-end">
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
  const metrics = [
    ["xG", avg.xg],
    ["Удары", avg.shots],
    ["В створ", avg.shots_on],
    ["Угловые", avg.corners],
    ["Владение", avg.possession],
  ];

  return (
    <div className="flex flex-col gap-4">
      <h4 className="font-semibold text-slate-200">{team}</h4>

      <div className="grid grid-cols-2 gap-4">
        {metrics.map(([label, v]) => (
          <div
            key={label}
            className="p-4 border border-glass rounded-lg bg-surface-2 flex flex-col items-center"
          >
            <span className="text-xs text-slate-400">{label}</span>
            <span className="text-lg font-semibold text-slate-100">
              {v == null ? "—" : Number(v).toFixed(2)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
