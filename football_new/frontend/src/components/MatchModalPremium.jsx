import React, { Suspense } from "react";
import { CalendarDays, Sparkles } from "lucide-react";
import clsx from "clsx";
import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";
import { useLanguage } from "@/context/LanguageContext.jsx";
const MatchStatsBlockV3 = React.lazy(() => import("@/components/MatchStatsBlockV3"));

export default function MatchModalPremium({ match, onClose }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  if (!match) return null;

  return (
    <div
      className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className={clsx(
          "surface-toolbar shadow-[0_0_50px_rgba(0,0,0,0.65)]",
          "w-full max-w-4xl p-5 sm:p-6 relative overflow-y-auto max-h-[90vh]"
        )}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close button */}
        <button
          className="surface-button absolute top-3 right-3 h-8 w-8 justify-center px-0 text-slate-300"
          onClick={onClose}
        >
          ✕
        </button>

        {/* TEAMS */}
        <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-3 py-1.5 text-[10px] uppercase tracking-[0.18em] text-white/66">
          <Sparkles className="h-3.5 w-3.5 text-violet-200" />
          Match snapshot
        </div>

        <div className="flex items-center justify-between gap-4">
          <div className="flex min-w-0 flex-1 flex-col items-center">
            <TeamLogoLink teamId={match.home_team_id} className="block">
              <SafeImg
                src={`/icons/team_logos/${match.home_team_id}.png`}
                fallback="team"
                className="h-12 w-12 sm:h-14 sm:w-14"
              />
            </TeamLogoLink>
            <div className="mt-2 truncate text-center text-sm font-semibold text-white">
              {match.home_team}
            </div>
          </div>

          <div className="min-w-[96px] text-center sm:min-w-[120px]">
            <div className="text-xs text-slate-400 uppercase tracking-wide mb-1">
              {isRu ? "Счёт" : "Score"}
            </div>
            <div className="text-white text-3xl font-bold">
              {match.score || "—"}
            </div>
            <div className="mt-2 inline-flex items-center gap-1 rounded-full border border-white/8 bg-white/[0.04] px-2.5 py-1 text-[10px] text-white/55">
              <CalendarDays className="h-3 w-3" />
              {match.date || match.datetime || "—"}
            </div>
          </div>

          <div className="flex min-w-0 flex-1 flex-col items-center">
            <TeamLogoLink teamId={match.away_team_id} className="block">
              <SafeImg
                src={`/icons/team_logos/${match.away_team_id}.png`}
                fallback="team"
                className="h-12 w-12 sm:h-14 sm:w-14"
              />
            </TeamLogoLink>
            <div className="mt-2 truncate text-center text-sm font-semibold text-white">
              {match.away_team}
            </div>
          </div>
        </div>

        <div className="mt-6 h-px bg-gradient-to-r from-transparent via-slate-600/30 to-transparent" />

        {/* STATS */}
        <div className="mt-6">
          <Suspense fallback={<div className="surface-loading">{isRu ? "Загружаем…" : "Loading…"}</div>}>
            <MatchStatsBlockV3 stats={match} />
          </Suspense>
        </div>
      </div>
    </div>
  );
}
