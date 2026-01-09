import { lazy, Suspense, useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { Card, CardContent } from "@/components/ui/card";

const MatchModalLazy = lazy(() =>
  import("@/pages/MatchSchedulePage").then((mod) => ({ default: mod.MatchModal }))
);

const MONTHS_RU = ["янв","фев","мар","апр","мая","июн","июл","авг","сент","окт","ноя","дек"];
const FALLBACK =
  'data:image/svg+xml;utf8,' +
  encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#eee"/></svg>`);

const fmtDate = (iso) => {
  if (!iso) return "—";
  const d = new Date(iso);
  return `${String(d.getDate()).padStart(2,"0")} ${MONTHS_RU[d.getMonth()]} · ${String(d.getHours()).padStart(2,"0")}:${String(d.getMinutes()).padStart(2,"0")}`;
};

function useImg(src) {
  const [s, setS] = useState(src);
  return [s, () => setS(FALLBACK)];
}

function Logo({ id, alt }) {
  const [src, err] = useImg(`/icons/team_logos/${id}.png`);
  return (
    <img
      src={src}
      onError={err}
      alt={alt}
      className="w-7 h-7 rounded-full object-contain bg-white/5 border border-white/10 p-1"
    />
  );
}

function MatchRow({ m, onOpen }) {
  return (
    <button
      onClick={() => onOpen(m)}
      className="w-full flex items-center justify-between px-4 py-3 rounded-2xl
                 bg-slate-900/60 border border-white/10 hover:bg-slate-800/50
                 transition shadow-[0_0_30px_rgba(0,0,0,0.45)]"
    >
      <div className="flex items-center gap-2 min-w-0">
        <Logo id={m.home_team_id} alt={m.home_team} />
        <span className="truncate text-white/90 text-[14px]">{m.home_team}</span>
      </div>

      <span className="text-white/30 text-[12px] font-light">vs</span>

      <div className="flex items-center gap-2 min-w-0 justify-end">
        <span className="truncate text-white/90 text-[14px] text-right">
          {m.away_team}
        </span>
        <Logo id={m.away_team_id} alt={m.away_team} />
      </div>

      <div className="ml-4 px-3 py-1 rounded-full bg-violet-500/15
                      border border-violet-500/30 text-violet-200
                      text-[12px] tabular-nums shadow-inner">
        {fmtDate(m.kickoff)}
      </div>
    </button>
  );
}

export default function TopEloMatchesCard({ league, leagueId, season, top = 3 }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalMatch, setModalMatch] = useState(null);

  const open = (m) => setModalMatch(m);
  const close = () => setModalMatch(null);

  useEffect(() => {
    let dead = false;

    (async () => {
      setLoading(true);
      try {
        const qs = new URLSearchParams({ top, seasons_back: "2", min_cnt: "3" });
        leagueId ? qs.set("league_id", leagueId) : qs.set("league", league);

        const r = await fetch(`http://localhost:8001/api/matchday/elo?${qs}`);
        const data = await r.json();

        if (!dead) setRows(Array.isArray(data) ? data : []);
      } catch {
        if (!dead) setRows([]);
      } finally {
        if (!dead) setLoading(false);
      }
    })();

    return () => {
      dead = true;
    };
  }, [league, leagueId, top]);

  return (
    <Card className="border border-white/10 bg-slate-950/70 backdrop-blur-xl rounded-3xl shadow-[0_18px_55px_rgba(0,0,0,0.7)]">
      <CardContent className="p-5 space-y-4">

        <div>
          <div className="text-[11px] uppercase tracking-[0.18em] text-white/40">
            Матчи тура по Elo
          </div>
          <div className="text-sm text-white/85">
            Игры с наибольшим уровнем силы по рейтингу EdgeScore Elo.
          </div>
        </div>

        {loading ? (
          <div className="space-y-3">
            {[...Array(top)].map((_, i) => (
              <div key={i} className="h-[70px] bg-white/5 rounded-2xl animate-pulse"></div>
            ))}
          </div>
        ) : (
          <div className="space-y-3">
            {rows.map((m) => (
              <MatchRow key={m.fixture_id} m={m} onOpen={open} />
            ))}
          </div>
        )}

        {modalMatch &&
          createPortal(
            <Suspense fallback={null}>
              <MatchModalLazy
                initialMatch={modalMatch}
                league={league}
                season={season}
                onClose={close}
                onGoTeam={() => {}}
              />
            </Suspense>,
            document.body
          )}
      </CardContent>
    </Card>
  );
}
