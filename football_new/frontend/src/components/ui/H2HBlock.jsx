import React from "react";
import { teamLogoMap } from "@/constants/teamLogoMap";

function logoSrc(teamId, name) {
  if (teamId) return `/icons/team_logos/${teamId}.png`;
  return teamLogoMap[name] || "/icons/team_logos/default.png";
}

const toDDMM = (val) => {
  if (!val) return "";
  const s = String(val);
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (m) return `${m[3]}.${m[2]}`;
  if (/^\d{2}\.\d{2}/.test(s)) return s.slice(0, 5);
  return s;
};

const fmtScore = (m) => {
  const gh = m?.home_goals ?? m?.home_score;
  const ga = m?.away_goals ?? m?.away_score;
  if (gh != null && ga != null && gh !== "" && ga !== "") {
    return `${gh}:${ga}`;
  }
  if (typeof m?.score === "string" && /[-:]/.test(m.score)) {
    return m.score.replace("-", ":");
  }
  return "—";
};

export default function H2HBlock({ h2h = [], onGoTeam }) {
  const list = Array.isArray(h2h) ? h2h : [];

  return (
    <div className="rounded-3xl border border-violet-500/20 bg-slate-950/90 px-4 py-4 space-y-4 shadow-[0_18px_55px_rgba(0,0,0,0.5)]">
      {/* HEADER */}
      <div>
        <div className="text-[10px] uppercase tracking-[0.22em] text-white/40">
          Личные встречи
        </div>
        <div className="text-sm text-white/80">
          Последние {list.length || 0} матчей между командами.
        </div>
      </div>

      {/* EMPTY */}
      {!list.length && (
        <div className="text-[13px] text-white/55">
          У команд пока нет официальных личных встреч в базе.
        </div>
      )}

      {/* LIST */}
      {list.length > 0 && (
        <div className="space-y-2">
          {list.map((m, idx) => (
            <div
              key={m.fixture_id || `${m.date}-${idx}`}
              className="flex items-center gap-3 px-3 py-2.5 rounded-xl transition
                         hover:bg-violet-600/10 hover:shadow-[0_0_12px_rgba(139,92,246,0.3)]"
            >
              {/* DATE */}
              <div className="w-[60px] text-[11px] text-white/60 tabular-nums">
                {toDDMM(m.date)}
              </div>

              {/* HOME */}
              <div className="flex flex-1 items-center gap-2 min-w-0">
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onGoTeam?.(m.home_team_id);
                  }}
                  className="h-6 w-6 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden"
                >
                  <img
                    src={logoSrc(m.home_team_id, m.home_team)}
                    alt={m.home_team}
                    className="h-5 w-5 object-contain"
                  />
                </button>

                <span className="truncate text-[13px] text-white/90">
                  {m.home_team || "—"}
                </span>
              </div>

              {/* SCORE */}
              <div className="w-[70px] flex items-center justify-center">
                <span className="inline-flex min-w-[56px] justify-center px-2 py-1 rounded-full
                                bg-violet-500/20 border border-violet-400/40
                                text-[13px] font-semibold text-white tabular-nums
                                shadow-[0_0_10px_rgba(139,92,246,0.35)]">
                  {fmtScore(m)}
                </span>
              </div>

              {/* AWAY */}
              <div className="flex flex-1 items-center justify-end gap-2 min-w-0">
                <span className="truncate text-[13px] text-white/90 text-right">
                  {m.away_team || "—"}
                </span>

                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onGoTeam?.(m.away_team_id);
                  }}
                  className="h-6 w-6 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden"
                >
                  <img
                    src={logoSrc(m.away_team_id, m.away_team)}
                    alt={m.away_team}
                    className="h-5 w-5 object-contain"
                  />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
