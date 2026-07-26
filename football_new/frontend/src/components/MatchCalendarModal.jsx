import React, { useEffect, useState } from "react";
import { CalendarDays, ChevronRight, Sparkles } from "lucide-react";
import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";
import { useLanguage } from "@/context/LanguageContext.jsx";

import TeamAvgBlock from "@/components/ui/TeamAvgBlock";
import H2HBlock from "@/components/ui/H2HBlock";
import LastMatchesBlock from "@/components/ui/LastMatchesBlock";

export default function MatchCalendarModal({ match, onClose, onOpenFull }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const [pack, setPack] = useState(null);
  const [loading, setLoading] = useState(true);

  const homeId = match.home_team_id;
  const awayId = match.away_team_id;

  // ============================
  // LOAD MATCH DETAILS
  // ============================
  useEffect(() => {
    async function load() {
      try {
        setLoading(true);
        if (!match.fixture_id) return;

        const rsp = await fetch(`/api/match-details?fixture_id=${match.fixture_id}`);
        const data = await rsp.json();
        setPack(data);
      } catch (e) {
        console.error("MatchCalendarModal load error:", e);
      } finally {
        setLoading(false);
      }
    }

    load();
  }, [match.fixture_id]);

  return (
    <div className="fixed inset-0 z-[200] flex items-center justify-center">
      {/* overlay */}
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={onClose} />

      {/* modal */}
      <div className="surface-toolbar relative w-[min(900px,95vw)] max-h-[90vh] overflow-y-auto shadow-[0_32px_80px_rgba(0,0,0,0.55)]">

        {/* HEADER */}
        <div className="flex items-start justify-between gap-4 border-b border-white/10 bg-[linear-gradient(135deg,rgba(124,58,237,0.24),rgba(14,165,233,0.14),rgba(255,255,255,0.03))] p-4 text-white sm:p-5">
          <div className="min-w-0">
            <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.06] px-3 py-1.5 text-[10px] uppercase tracking-[0.18em] text-white/66">
              <Sparkles className="h-3.5 w-3.5 text-violet-200" />
              Match preview
            </div>
            <div className="flex items-center gap-3">
              <TeamLogoLink teamId={homeId} className="block">
                <SafeImg src={`/icons/team_logos/${homeId}.png`} className="h-8 w-8" />
              </TeamLogoLink>
              <span className="truncate text-base font-semibold sm:text-lg">{match.home_team}</span>
              <span className="text-lg font-bold text-white/50 sm:text-xl">—</span>
              <span className="truncate text-base font-semibold sm:text-lg">{match.away_team}</span>
              <TeamLogoLink teamId={awayId} className="block">
                <SafeImg src={`/icons/team_logos/${awayId}.png`} className="h-8 w-8" />
              </TeamLogoLink>
            </div>
            <div className="mt-3 inline-flex items-center gap-2 rounded-full border border-white/8 bg-white/[0.04] px-3 py-1.5 text-[11px] text-white/62">
              <CalendarDays className="h-3.5 w-3.5" />
              {match.datetime || match.date}
            </div>
          </div>

          <button
            onClick={onClose}
            className="surface-button h-8 w-8 shrink-0 justify-center px-0 text-white"
          >
            ✕
          </button>
        </div>

        {/* CONTENT */}
        {loading ? (
          <div className="surface-loading m-4">{isRu ? "Загружаем…" : "Loading…"}</div>
        ) : !pack ? (
          <div className="surface-error m-4">{isRu ? "Ошибка загрузки" : "Loading error"}</div>
        ) : (
          <div className="p-4 space-y-6">

            {/* AVERAGES */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <TeamAvgBlock
                team={match.home_team}
                logoId={homeId}
                avg={pack.homeAvg}
              />
              <TeamAvgBlock
                team={match.away_team}
                logoId={awayId}
                avg={pack.awayAvg}
              />
            </div>

            {/* H2H */}
            <H2HBlock h2h={pack.h2h} />

            {/* LAST MATCHES HOME */}
            <LastMatchesBlock
              title={`Последние матчи — ${match.home_team}`}
              matches={pack.homeLast}
            />

            {/* LAST MATCHES AWAY */}
            <LastMatchesBlock
              title={`Последние матчи — ${match.away_team}`}
              matches={pack.awayLast}
            />

            {/* BUTTON TO OPEN FULL MATCH PAGE */}
            <div className="pt-2">
              <button
                onClick={onOpenFull}
                className="surface-button-emphasis w-full rounded-2xl px-4 py-3"
              >
                {isRu ? "Полная статистика матча" : "Full match stats"}
                <ChevronRight className="h-4 w-4" />
              </button>
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
