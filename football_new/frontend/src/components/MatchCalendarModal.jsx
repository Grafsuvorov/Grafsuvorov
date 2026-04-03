import React, { useEffect, useState } from "react";
import SafeImg from "@/components/SafeImg";
import TeamLogoLink from "@/components/TeamLogoLink";

import TeamAvgBlock from "@/components/ui/TeamAvgBlock";
import H2HBlock from "@/components/ui/H2HBlock";
import LastMatchesBlock from "@/components/ui/LastMatchesBlock";

export default function MatchCalendarModal({ match, onClose, onOpenFull }) {
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
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />

      {/* modal */}
      <div className="relative rounded-2xl border border-glass bg-surface-1/95 shadow-2xl w-[min(900px,95vw)] max-h-[90vh] overflow-y-auto">

        {/* HEADER */}
        <div className="p-4 border-b border-glass bg-gradient-to-r from-rose-600/90 to-rose-500/80 text-white flex justify-between items-center">
          <div className="flex items-center gap-3">
            <TeamLogoLink teamId={homeId} className="block">
              <SafeImg src={`/icons/team_logos/${homeId}.png`} className="h-8 w-8" />
            </TeamLogoLink>
            <span className="text-lg font-semibold">{match.home_team}</span>

            <span className="text-xl font-bold mx-2">—</span>

            <span className="text-lg font-semibold">{match.away_team}</span>
            <TeamLogoLink teamId={awayId} className="block">
              <SafeImg src={`/icons/team_logos/${awayId}.png`} className="h-8 w-8" />
            </TeamLogoLink>
          </div>

          <button
            onClick={onClose}
            className="h-8 w-8 bg-white/10 hover:bg-white/20 rounded-full grid place-items-center"
          >
            ✕
          </button>
        </div>

        {/* DATE */}
        <div className="px-4 pt-3 pb-2 text-sm text-slate-400">
          {match.datetime || match.date}
        </div>

        {/* CONTENT */}
        {loading ? (
          <div className="p-4 text-slate-400">Загружаем…</div>
        ) : !pack ? (
          <div className="p-4 text-rose-300">Ошибка загрузки</div>
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
                className="w-full py-2 rounded-xl bg-primary/90 text-white font-semibold hover:bg-primary transition"
              >
                Полная статистика матча
              </button>
            </div>

          </div>
        )}

      </div>
    </div>
  );
}
