import React, { Suspense } from "react";
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
          "w-full max-w-4xl p-6 relative overflow-y-auto max-h-[90vh]"
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
        <div className="flex justify-between items-center">
          <div className="flex flex-col items-center">
            <TeamLogoLink teamId={match.home_team_id} className="block">
              <SafeImg
                src={`/icons/team_logos/${match.home_team_id}.png`}
                fallback="team"
                className="h-14 w-14"
              />
            </TeamLogoLink>
            <div className="mt-2 text-white font-semibold text-sm">
              {match.home_team}
            </div>
          </div>

          <div className="text-center">
            <div className="text-xs text-slate-400 uppercase tracking-wide mb-1">
              {isRu ? "Счёт" : "Score"}
            </div>
            <div className="text-white text-3xl font-bold">
              {match.score || "—"}
            </div>
          </div>

          <div className="flex flex-col items-center">
            <TeamLogoLink teamId={match.away_team_id} className="block">
              <SafeImg
                src={`/icons/team_logos/${match.away_team_id}.png`}
                fallback="team"
                className="h-14 w-14"
              />
            </TeamLogoLink>
            <div className="mt-2 text-white font-semibold text-sm">
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
