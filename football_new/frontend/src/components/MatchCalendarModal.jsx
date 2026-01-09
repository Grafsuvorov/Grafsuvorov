import React, { useEffect, useState } from "react";
import SafeImg from "@/components/SafeImg";

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
      <div className="relative bg-white rounded-2xl shadow-2xl w-[min(900px,95vw)] max-h-[90vh] overflow-y-auto">

        {/* HEADER */}
        <div className="p-4 border-b bg-gradient-to-r from-rose-600 to-rose-500 text-white flex justify-between items-center">
          <div className="flex items-center gap-3">
            <SafeImg src={`/icons/team_logos/${homeId}.png`} className="h-8 w-8" />
            <span className="text-lg font-semibold">{match.home_team}</span>

            <span className="text-xl font-bold mx-2">—</span>

            <span className="text-lg font-semibold">{match.away_team}</span>
            <SafeImg src={`/icons/team_logos/${awayId}.png`} className="h-8 w-8" />
          </div>

          <button
            onClick={onClose}
            className="h-8 w-8 bg-white/20 hover:bg-white/30 rounded-full grid place-items-center"
          >
            ✕
          </button>
        </div>

        {/* DATE */}
        <div className="px-4 pt-3 pb-2 text-sm text-gray-600">
          {match.datetime || match.date}
        </div>

        {/* CONTENT */}
        {loading ? (
          <div className="p-4 text-gray-500">Загружаем…</div>
        ) : !pack ? (
          <div className="p-4 text-red-500">Ошибка загрузки</div>
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
                className="w-full py-2 rounded-xl bg-rose-600 text-white font-semibold hover:bg-rose-700 transition"
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
