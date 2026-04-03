import React from "react";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";

function logoSrc(teamId, name) {
  if (teamId) return `/icons/team_logos/${teamId}.png`;
  return teamLogoMap[name] || "/icons/team_logos/default.png";
}

function logoFallback(teamId, name) {
  if (teamId) return `https://media.api-sports.io/football/teams/${teamId}.png`;
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

const scoreParts = (m) => {
  const gh = m?.home_goals ?? m?.home_score;
  const ga = m?.away_goals ?? m?.away_score;
  if (Number.isFinite(Number(gh)) && Number.isFinite(Number(ga))) {
    return { home: Number(gh), away: Number(ga) };
  }
  if (typeof m?.score === "string" && /[-:]/.test(m.score)) {
    const [a, b] = m.score.replace("-", ":").split(":");
    const ha = Number(a);
    const aa = Number(b);
    if (Number.isFinite(ha) && Number.isFinite(aa)) {
      return { home: ha, away: aa };
    }
  }
  return null;
};

export default function H2HBlock({
  h2h = [],
  onGoTeam,
  onOpenMatch,
  variant = "default",
}) {
  const list = Array.isArray(h2h) ? h2h : [];
  const isSoft = variant === "soft";
  const isTable = variant === "table";

  return (
    <div
      className={[
        isTable
          ? "space-y-2"
          : isSoft
          ? "space-y-3"
          : "rounded-3xl border border-violet-500/20 bg-slate-950/90 px-4 py-4 shadow-[0_18px_55px_rgba(0,0,0,0.5)] space-y-4",
      ].join(" ")}
    >
      {/* HEADER */}
      <div>
        <div className="text-[10px] text-white/45 uppercase tracking-[0.16em]">
          Личные встречи
        </div>
        <div className="text-[11px] text-white/55">
          Последние {list.length || 0} матчей между командами.
        </div>
      </div>

      {/* EMPTY */}
      {!list.length && (
        <div className="text-[11px] text-white/55">
          У команд пока нет официальных личных встреч в базе.
        </div>
      )}

      {/* LIST */}
      {list.length > 0 && (
        <div
          className={
            isTable
              ? "divide-y divide-white/[0.08]"
              : isSoft
              ? "divide-y divide-white/[0.06]"
              : "space-y-2"
          }
        >
          {list.map((m, idx) => (
            <div
              key={m.fixture_id || `${m.date}-${idx}`}
              onClick={() => onOpenMatch?.(m)}
              className={[
                isTable
                  ? "grid grid-cols-[64px,1fr,70px,1fr] gap-3 py-2.5 min-h-[40px] items-center"
                  : "flex items-center gap-3 py-2",
                "transition text-white/70",
                isTable
                  ? "hover:bg-white/[0.015]"
                  : isSoft
                  ? "hover:bg-white/[0.02]"
                  : "px-3 rounded-xl hover:bg-white/[0.04]",
                onOpenMatch ? "cursor-pointer" : "",
              ].join(" ")}
            >
              {/* DATE */}
              <div className="text-[11px] text-white/45 tabular-nums">
                {toDDMM(m.date)}
              </div>

              {/* HOME */}
              <div className="flex items-center gap-2 min-w-0">
                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onGoTeam?.(m.home_team_id);
                  }}
                  className={
                    isTable
                      ? "h-6 w-6 flex items-center justify-center opacity-85 hover:opacity-100"
                      : "h-6 w-6 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden"
                  }
                >
                  <SafeImg
                    src={logoSrc(m.home_team_id, m.home_team)}
                    alt={m.home_team}
                    className={isTable ? "h-5 w-5 object-contain" : "h-5 w-5 object-contain"}
                    fallbackSrc={logoFallback(m.home_team_id, m.home_team)}
                  />
                </button>

                <span className="truncate text-[13px] text-white/55">
                  {m.home_team || "—"}
                </span>
              </div>

              {/* SCORE */}
              <div className="flex items-center justify-center">
                {(() => {
                  const s = scoreParts(m);
                  if (!s) {
                    return (
                      <span className="inline-flex min-w-[56px] justify-center text-[13px] font-semibold text-white/60 tabular-nums">
                        {fmtScore(m)}
                      </span>
                    );
                  }
                  const winner =
                    s.home > s.away ? "home" : s.away > s.home ? "away" : "draw";
                  const homeCls =
                    winner === "home"
                      ? "text-white/85 font-semibold"
                      : winner === "draw"
                        ? "text-white/60"
                        : "text-white/40";
                  const awayCls =
                    winner === "away"
                      ? "text-white/85 font-semibold"
                      : winner === "draw"
                        ? "text-white/60"
                        : "text-white/40";
                  return (
                    <span className="inline-flex min-w-[56px] justify-center text-[13px] tabular-nums">
                      <span className={homeCls}>{s.home}</span>
                      <span className="text-white/45 px-1">:</span>
                      <span className={awayCls}>{s.away}</span>
                    </span>
                  );
                })()}
              </div>

              {/* AWAY */}
              <div className="flex items-center justify-end gap-2 min-w-0">
                <span className="truncate text-[13px] text-white/55 text-right">
                  {m.away_team || "—"}
                </span>

                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    onGoTeam?.(m.away_team_id);
                  }}
                  className={
                    isTable
                      ? "h-6 w-6 flex items-center justify-center opacity-85 hover:opacity-100"
                      : "h-6 w-6 rounded-full bg-white/5 border border-white/10 flex items-center justify-center overflow-hidden"
                  }
                >
                  <SafeImg
                    src={logoSrc(m.away_team_id, m.away_team)}
                    alt={m.away_team}
                    className={isTable ? "h-5 w-5 object-contain" : "h-5 w-5 object-contain"}
                    fallbackSrc={logoFallback(m.away_team_id, m.away_team)}
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
