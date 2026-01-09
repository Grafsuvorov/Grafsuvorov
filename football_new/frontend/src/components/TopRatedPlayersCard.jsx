import { useEffect, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";

/**
 * Топ-игроки по рейтингу для выбранных league/season
 */
export default function TopRatedPlayersCard({ league, season, limit = 3 }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      try {
        const url = `http://localhost:8001/api/top-rated?league=${encodeURIComponent(
          league
        )}&season=${season}&limit=${limit}`;

        const res = await fetch(url);
        const data = await res.json();

        if (!cancelled) {
          setRows(Array.isArray(data) ? data : []);
        }
      } catch (e) {
        console.error("TopRatedPlayersCard fetch error:", e);
        if (!cancelled) setRows([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [league, season, limit]);

  return (
    <Card className="rounded-3xl border border-white/10 bg-slate-950/75 backdrop-blur-2xl shadow-[0_18px_55px_rgba(0,0,0,0.75)]">
      <CardContent className="p-4 space-y-4">
        {/* HEADER */}
        <div className="flex items-center justify-between">
          <div>
            <div className="text-[11px] uppercase tracking-[0.18em] text-white/40">
              Топ игроки · {season}
            </div>
          </div>

          <span className="inline-flex items-center rounded-full border border-white/15 bg-white/5 px-2 py-0.5 text-[10px] font-medium text-white/70 uppercase tracking-wide">
            рейтинг
          </span>
        </div>

        {/* LIST */}
        {loading ? (
          <ul className="space-y-3">
            {[...Array(limit)].map((_, i) => (
              <li
                key={i}
                className="flex items-center gap-3 opacity-60 animate-pulse"
              >
                <div className="h-9 w-9 rounded-full bg-white/10" />
                <div className="flex-1 space-y-2">
                  <div className="h-3 w-24 bg-white/10 rounded" />
                  <div className="h-3 w-20 bg-white/5 rounded" />
                </div>
                <div className="h-5 w-10 bg-white/10 rounded" />
              </li>
            ))}
          </ul>
        ) : rows.length ? (
          <ul className="space-y-3">
            {rows.slice(0, limit).map((p, idx) => (
              <li
                key={p.player_id ?? idx}
                className="flex items-center gap-3 rounded-xl px-2 py-2 transition hover:bg-white/5"
              >
                <img
                  src={`/icons/player_photos/${p.player_id}.png`}
                  alt={p.player_name}
                  className="h-9 w-9 rounded-full object-cover border border-white/10 shadow-sm"
                  onError={(e) =>
                    (e.currentTarget.src = "/icons/player_photos/default.png")
                  }
                />

                {/* NAME + CLUB */}
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] font-medium text-white/90 leading-5">
                    {p.player_name ?? "—"}
                  </div>
                  <div className="truncate text-[11px] text-white/45 leading-4">
                    {p.team_name ?? "—"}
                  </div>
                </div>

                {/* RATING */}
                <span className="ml-auto shrink-0 rounded-lg border border-white/10 bg-white/[0.06] px-3 py-1 text-[12px] font-semibold tabular-nums text-white/85 shadow-sm">
                  {p.rating != null ? Number(p.rating).toFixed(2) : "—"}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <div className="text-[13px] text-white/60">
            Нет данных для этой лиги.
          </div>
        )}
      </CardContent>
    </Card>
  );
}
