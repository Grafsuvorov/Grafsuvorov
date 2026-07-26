import clsx from "clsx";
import { ArrowRight } from "lucide-react";

import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";

export default function MatchRowCompact({
  match,
  highlight,
  onOpen,
  extractGoals,
  scoreStyleBySemantics,
  getMatchStateBadge,
  safeDateFormat,
  teamLogo,
  teamLogoFallback,
}) {
  const { home, away } = extractGoals(match);
  const semanticScoreClass = scoreStyleBySemantics(home, away);
  const homeWin = home != null && away != null && home > away;
  const awayWin = home != null && away != null && away > home;
  const badge = getMatchStateBadge(match);

  return (
    <button
      type="button"
      onClick={() => {
        onOpen?.();
      }}
      className={clsx(
        "group relative grid w-full cursor-pointer grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] items-center gap-2 rounded-[24px] border border-white/[0.05] px-3 py-3 text-left transition-all duration-200 ease-in-out sm:gap-4 sm:px-4 sm:py-3.5",
        "bg-[linear-gradient(180deg,rgba(255,255,255,0.04),rgba(255,255,255,0.015))] shadow-[0_14px_34px_rgba(0,0,0,0.2)] hover:border-white/[0.09] hover:bg-white/[0.045]"
      )}
    >
      {highlight && (
        <span className="pointer-events-none absolute left-0 top-2 bottom-2 w-[3px] rounded-full bg-[linear-gradient(180deg,#8b5cf6,#6d28d9)] shadow-[0_0_10px_rgba(123,92,255,0.35)]" />
      )}

      <div className="flex min-w-0 items-center gap-2 sm:gap-3">
        <TeamLogoLink teamId={match.home_team_id} stopPropagation className="block">
          <SafeImg
            src={teamLogo(match.home_team, match.home_team_id)}
            className="h-8 w-8 rounded-xl bg-surface-2 object-contain sm:h-9 sm:w-9"
            fallbackSrc={teamLogoFallback(match.home_team_id)}
          />
        </TeamLogoLink>
        <div className="min-w-0 text-left">
          <div className={clsx("truncate text-[13px] text-white sm:text-sm", homeWin ? "font-semibold" : "font-medium")}>
            {match.home_team}
          </div>
          <div className="truncate pt-0.5 text-[10px] text-muted sm:text-[11px]">
            {badge ? (
              <span className="inline-flex items-center gap-2">
                <span className={`inline-flex h-5 items-center rounded-full border px-2 text-[9px] font-semibold uppercase tracking-[0.12em] ${badge.pillClass}`}>
                  {badge.label}
                </span>
                {badge.sublabel ? (
                  <span className={`tabular-nums ${badge.sublabelClass}`}>{badge.sublabel}</span>
                ) : null}
              </span>
            ) : (
              <>
                {safeDateFormat(match.date)} {match.venue ? `· ${match.venue}` : ""}
              </>
            )}
          </div>
        </div>
      </div>

      <div className="flex w-[82px] items-center justify-center text-center sm:w-[94px]">
        <div
          className={clsx(
            "flex items-center justify-center text-[18px] font-semibold tracking-[0.01em] text-white tabular-nums leading-none sm:text-[20px]",
            semanticScoreClass
          )}
        >
          {home == null || away == null ? (
            "—"
          ) : (
            <>
              <span className={homeWin ? "text-white" : awayWin ? "text-white/40" : "text-white"}>
                {home}
              </span>
              <span className="px-1.5 text-white/38">:</span>
              <span className={awayWin ? "text-white" : homeWin ? "text-white/40" : "text-white"}>
                {away}
              </span>
            </>
          )}
        </div>
      </div>

      <div className="flex min-w-0 items-center justify-end gap-2 sm:gap-3">
        <div className="min-w-0 text-right">
          <div className={clsx("truncate text-[13px] text-white sm:text-sm", awayWin ? "font-semibold" : "font-medium")}>
            {match.away_team}
          </div>
          <div className="truncate pt-0.5 text-[10px] text-white/38 sm:text-[11px]">
            {safeDateFormat(match.date)}
          </div>
        </div>
        <TeamLogoLink teamId={match.away_team_id} stopPropagation className="block">
          <SafeImg
            src={teamLogo(match.away_team, match.away_team_id)}
            className="h-8 w-8 rounded-xl bg-surface-2 object-contain sm:h-9 sm:w-9"
            fallbackSrc={teamLogoFallback(match.away_team_id)}
          />
        </TeamLogoLink>
      </div>

      <span className="pointer-events-none absolute right-3 top-3 inline-flex items-center gap-1 text-[10px] uppercase tracking-[0.16em] text-white/0 transition group-hover:text-white/46">
        Open
        <ArrowRight className="h-3 w-3" />
      </span>
    </button>
  );
}
