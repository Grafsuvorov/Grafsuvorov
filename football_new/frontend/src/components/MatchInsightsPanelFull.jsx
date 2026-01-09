// src/components/MatchInsightsPanelFull.jsx
import React from "react";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";

/* ================================
   ЛОГО — как в TeamPage
================================ */
const teamLogoPath = (id) => (id ? `/icons/team_logos/${id}.png` : null);
const fallbackTeam = (name) =>
  teamLogoMap[name] || "/icons/team_logos/default.png";
const logoSafe = (id, name) => teamLogoPath(id) || fallbackTeam(name);

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
}) {
  if (!pack) return null;

  const h2h = pack.h2h || [];
  const homeLast = pack.homeLast || [];
  const awayLast = pack.awayLast || [];
  const homeAvg = pack.homeAvg || {};
  const awayAvg = pack.awayAvg || {};

  return (
    <div className="w-full flex flex-col gap-8">

      {/* ============================
          СРЕДНИЕ ПОКАЗАТЕЛИ
      ============================ */}
      <Section title="Средние показатели (последние 10 матчей)">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-12 px-4">
          <TeamAvgBlock team={home} avg={homeAvg} />
          <TeamAvgBlock team={away} avg={awayAvg} />
        </div>
      </Section>

      {/* ============================
          H2H
      ============================ */}
      <Section title="Личные встречи (H2H)">
        <ListMatches
          rows={h2h}
          teamId={teamId}
          onOpenMatchModal={onOpenMatchModal}
        />
      </Section>

      {/* ============================
          Последние 5 матчей
      ============================ */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <Section title={`Последние 5 • ${home || ""}`}>
          <ListMatches
            rows={homeLast}
            teamId={teamId}
            onOpenMatchModal={onOpenMatchModal}
          />
        </Section>

        <Section title={`Последние 5 • ${away || ""}`}>
          <ListMatches
            rows={awayLast}
            teamId={teamId}
            onOpenMatchModal={onOpenMatchModal}
          />
        </Section>
      </div>
    </div>
  );
}

/* ================================
   UI wrappers
================================ */

function Section({ title, children }) {
  return (
    <div className="w-full border border-gray-200 rounded-xl bg-white p-6 shadow-sm">
      <h3 className="font-semibold text-gray-800 mb-4">{title}</h3>
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

      className="flex items-center justify-between py-3 cursor-pointer hover:bg-gray-50 transition px-2 rounded-lg"
    >
      {/* LEFT */}
      <div className="flex items-center gap-2 w-1/3">
        <SafeImg src={leftLogo} className="w-6 h-6" alt="" />
        <span className="text-sm text-gray-800 truncate">{leftTeam}</span>
      </div>

      {/* CENTER */}
      <div className="flex flex-col items-center w-1/3 text-center">
        <span className="font-semibold text-gray-900">{match.score}</span>
        <span className="text-xs text-gray-500">
          {formatShortDate(match.date)}
        </span>
      </div>

      {/* RIGHT */}
      <div className="flex items-center gap-2 justify-end w-1/3">
        <span className="text-sm text-gray-800 truncate">{rightTeam}</span>
        <SafeImg src={rightLogo} className="w-6 h-6" alt="" />
      </div>
    </div>
  );
}


/* ================================
   LIST OF MATCHES (H2H + LAST5)
================================ */
function ListMatches({ rows, teamId, onOpenMatchModal }) {
  return (
    <div className="flex flex-col divide-y divide-gray-200">
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
      <h4 className="font-semibold text-gray-700">{team}</h4>

      <div className="grid grid-cols-2 gap-4">
        {metrics.map(([label, v]) => (
          <div
            key={label}
            className="p-4 border border-gray-200 rounded-lg bg-gray-50 flex flex-col items-center"
          >
            <span className="text-xs text-gray-500">{label}</span>
            <span className="text-lg font-semibold">
              {v == null ? "—" : Number(v).toFixed(2)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
