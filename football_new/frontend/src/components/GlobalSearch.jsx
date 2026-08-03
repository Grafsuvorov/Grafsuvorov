import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import clsx from "clsx";
import { useLanguage } from "@/context/LanguageContext.jsx";

const EMPTY = { players: [], teams: [], matches: [] };

export default function GlobalSearch({ league, season }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const navigate = useNavigate();
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [data, setData] = useState(EMPTY);
  const containerRef = useRef(null);
  const debounceRef = useRef(null);

  useEffect(() => {
    const handler = (e) => {
      if (!containerRef.current) return;
      if (!containerRef.current.contains(e.target)) {
        setOpen(false);
      }
    };
    window.addEventListener("mousedown", handler);
    return () => window.removeEventListener("mousedown", handler);
  }, []);

  useEffect(() => {
    if (!query.trim()) {
      setData(EMPTY);
      setLoading(false);
      return;
    }
    setLoading(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      const params = new URLSearchParams({
        q: query.trim(),
      });
      if (league) params.set("league", league);
      if (season) params.set("season", season);

      fetch(`/api/search?${params.toString()}`)
        .then((r) => r.json())
        .then((res) => {
          setData({
            players: Array.isArray(res?.players) ? res.players : [],
            teams: Array.isArray(res?.teams) ? res.teams : [],
            matches: Array.isArray(res?.matches) ? res.matches : [],
          });
        })
        .catch(() => setData(EMPTY))
        .finally(() => setLoading(false));
    }, 250);
    return () => debounceRef.current && clearTimeout(debounceRef.current);
  }, [query, league, season]);

  const hasAny =
    data.players.length || data.teams.length || data.matches.length;

  const onPickTeam = (team) => {
    if (!team?.team_id) return;
    navigate(
      `/team/${team.team_id}?league=${encodeURIComponent(
        league || "Premier League"
      )}&season=${season || "2026"}`
    );
    setOpen(false);
  };

  const onPickPlayer = (p) => {
    if (!p?.player_id) return;
    navigate(
      `/player/${p.player_id}?league=${encodeURIComponent(
        league || "Premier League"
      )}&season=${season || "2026"}`
    );
    setOpen(false);
  };

  const onPickMatch = (m) => {
    if (!m?.fixture_id) return;
    navigate(
      `/match/${m.fixture_id}?league=${encodeURIComponent(
        m.league || league || "Premier League"
      )}&season=${m.season || season || "2026"}`
    );
    setOpen(false);
  };

  return (
    <div ref={containerRef} className="relative w-full max-w-[520px]">
      <div className="surface-toolbar flex items-center gap-2 px-3 py-2">
        <span className="text-white/50 text-xs">⌕</span>
        <input
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          placeholder={isRu ? "Поиск игроков, команд..." : "Search players, teams..."}
          className="w-full bg-transparent text-sm text-white placeholder:text-white/40 focus:outline-none"
        />
        {loading && <span className="text-[11px] text-white/40">...</span>}
      </div>

      {open && (query.trim() || hasAny) && (
        <div className="surface-toolbar absolute z-50 mt-2 w-full rounded-[22px] shadow-[0_20px_40px_rgba(0,0,0,0.4)]">
          <div className="p-3 space-y-3">
            {!hasAny && !loading && (
              <div className="surface-empty px-1 py-3 text-xs">
                {isRu ? "Нет результатов" : "No results"}
              </div>
            )}

            {data.players.length > 0 && (
              <div className="space-y-1.5">
                <div className="text-[10px] uppercase tracking-[0.18em] text-white/45">
                  {isRu ? "Игроки" : "Players"}
                </div>
                <div className="space-y-1">
                  {data.players.map((p) => (
                    <button
                      key={`p-${p.player_id}`}
                      type="button"
                      onClick={() => onPickPlayer(p)}
                      className="w-full text-left px-2 py-2 rounded-xl hover:bg-white/5 transition"
                    >
                      <div className="text-sm text-white">{p.player}</div>
                      <div className="text-[11px] text-white/50">
                        {p.team || "—"}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {data.teams.length > 0 && (
              <div className="space-y-1.5">
                <div className="text-[10px] uppercase tracking-[0.18em] text-white/45">
                  {isRu ? "Команды" : "Teams"}
                </div>
                <div className="space-y-1">
                  {data.teams.map((t) => (
                    <button
                      key={`t-${t.team_id}-${t.team}`}
                      type="button"
                      onClick={() => onPickTeam(t)}
                      className="w-full text-left px-2 py-2 rounded-xl hover:bg-white/5 transition"
                    >
                      <div className="text-sm text-white">{t.team}</div>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {data.matches.length > 0 && (
              <div className="space-y-1.5">
                <div className="text-[10px] uppercase tracking-[0.18em] text-white/45">
                  {isRu ? "Матчи" : "Matches"}
                </div>
                <div className="space-y-1">
                  {data.matches.map((m) => (
                    <button
                      key={`m-${m.fixture_id}`}
                      type="button"
                      onClick={() => onPickMatch(m)}
                      className="w-full text-left px-2 py-2 rounded-xl hover:bg-white/5 transition"
                    >
                      <div className="text-sm text-white">
                        {m.home_team} — {m.away_team}
                      </div>
                      <div className="text-[11px] text-white/50">
                        {m.league} · {m.season}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
