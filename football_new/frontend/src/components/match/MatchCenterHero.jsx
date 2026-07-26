import clsx from "clsx";
import {
  ArrowLeft,
  Bookmark,
  CalendarDays,
  MapPin,
  Radio,
  Trophy,
} from "lucide-react";

import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";

export default function MatchCenterHero({
  league,
  season,
  match,
  matchLive,
  statusText,
  statusToneClass,
  homeGoals,
  awayGoals,
  homeWin,
  awayWin,
  headerMeta,
  isFavoriteMatch,
  labels,
  onBack,
  onToggleFavorite,
  teamLogo,
  teamLogoFallback,
}) {
  return (
    <>
      <div className="flex items-center">
        <div className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:flex-wrap sm:items-center sm:gap-3">
          <button
            type="button"
            onClick={onBack}
            className="surface-button h-9 w-full text-[12px] sm:h-10 sm:w-auto"
          >
            <ArrowLeft className="h-4 w-4" />
            {labels.back}
          </button>
          <button
            type="button"
            onClick={onToggleFavorite}
            className={clsx(
              "surface-button h-9 w-full text-[12px] sm:h-10 sm:w-auto",
              isFavoriteMatch && "surface-button-active"
            )}
          >
            <Bookmark className="h-4 w-4" />
            {isFavoriteMatch ? labels.saved : labels.save}
          </button>
        </div>
      </div>

      <section className="text-slate-50">
        <div className="surface-hero min-w-0 overflow-hidden p-4 sm:p-6 md:p-8">
          <div className="mb-4 flex flex-wrap items-center gap-2">
            <div className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1.5 text-[10px] uppercase tracking-[0.16em] text-white/60 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
              <Trophy className="h-3.5 w-3.5 text-violet-200" />
              {league} · {season}
            </div>
            {match?.round ? (
              <div className="inline-flex items-center rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1.5 text-[10px] uppercase tracking-[0.16em] text-white/52 sm:px-3 sm:text-[11px] sm:tracking-[0.18em]">
                {match.round}
              </div>
            ) : null}
            {statusText ? (
              <div className={clsx("inline-flex items-center gap-2 rounded-full border px-2.5 py-1.5 text-[10px] font-medium uppercase tracking-[0.14em] sm:px-3 sm:text-[11px] sm:tracking-[0.16em]", statusToneClass)}>
                {matchLive ? <Radio className="h-3.5 w-3.5" /> : <CalendarDays className="h-3.5 w-3.5" />}
                {statusText}
              </div>
            ) : null}
          </div>

          <div className="mx-auto mt-4 grid w-full min-w-0 grid-cols-[minmax(0,1fr)_72px_minmax(0,1fr)] items-center justify-center gap-1.5 sm:mt-6 sm:grid-cols-[180px_150px_180px] sm:gap-4 lg:grid-cols-[220px_180px_220px] lg:gap-5">
            <div className="min-w-0 justify-self-stretch flex flex-col items-center gap-1.5 sm:w-[180px] sm:justify-self-end sm:gap-2 lg:w-[220px]">
              <TeamLogoLink teamId={match?.home_team_id} className="block">
                <SafeImg
                  src={teamLogo(match?.home_team, match?.home_team_id)}
                  fallbackSrc={teamLogoFallback(match?.home_team_id)}
                  className="h-9 w-9 translate-y-[2px] rounded-2xl border border-glass bg-surface-2/80 object-contain drop-shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition-transform duration-200 hover:scale-[1.03] sm:h-16 sm:w-16 lg:h-[80px] lg:w-[80px]"
                />
              </TeamLogoLink>
              <div className="w-full min-w-0 truncate px-0.5 text-center text-[10px] font-medium tracking-[0.02em] text-white/95 sm:w-[140px] sm:px-1 sm:text-[16px] lg:w-[160px] lg:text-[18px]">
                {match?.home_team || "—"}
              </div>
            </div>

            <div className="flex items-center justify-center">
              <div className="whitespace-nowrap text-center text-[24px] font-medium leading-none tracking-[0.03em] tabular-nums drop-shadow-[0_0_24px_rgba(140,110,255,0.22)] sm:text-[54px] lg:text-[68px]">
                <span className={clsx(homeWin ? "text-white/95" : awayWin ? "text-white/60" : "text-white/95")}>
                  {homeGoals ?? "—"}
                </span>
                <span className="mx-1 text-white/70 sm:mx-2">–</span>
                <span className={clsx(awayWin ? "text-white/95" : homeWin ? "text-white/60" : "text-white/95")}>
                  {awayGoals ?? "—"}
                </span>
              </div>
            </div>

            <div className="min-w-0 justify-self-stretch flex flex-col items-center gap-1.5 sm:w-[180px] sm:justify-self-start sm:gap-2 lg:w-[220px]">
              <TeamLogoLink teamId={match?.away_team_id} className="block">
                <SafeImg
                  src={teamLogo(match?.away_team, match?.away_team_id)}
                  fallbackSrc={teamLogoFallback(match?.away_team_id)}
                  className="h-9 w-9 translate-y-[2px] rounded-2xl border border-glass bg-surface-2/80 object-contain drop-shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition-transform duration-200 hover:scale-[1.03] sm:h-16 sm:w-16 lg:h-[80px] lg:w-[80px]"
                />
              </TeamLogoLink>
              <div className="w-full min-w-0 truncate px-0.5 text-center text-[10px] font-medium tracking-[0.02em] text-white/95 sm:w-[140px] sm:px-1 sm:text-[16px] lg:w-[160px] lg:text-[18px]">
                {match?.away_team || "—"}
              </div>
            </div>
          </div>

          <div className="mt-2 text-center">
            <div className="flex flex-wrap items-center justify-center gap-2 text-[12px] leading-tight text-white/58">
              {headerMeta.map((item) => (
                <span key={item} className="rounded-full border border-white/8 bg-white/[0.03] px-2.5 py-1">
                  {item}
                </span>
              ))}
            </div>
            {match?.venue ? (
              <div className="mt-3 inline-flex items-center gap-2 rounded-full border border-white/8 bg-white/[0.03] px-3 py-1.5 text-[11px] leading-tight text-white/48">
                <MapPin className="h-3.5 w-3.5" />
                {match.venue}
              </div>
            ) : null}
          </div>
        </div>
      </section>
    </>
  );
}
