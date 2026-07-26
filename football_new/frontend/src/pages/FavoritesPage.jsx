import { useEffect, useMemo, useState, useCallback } from "react";
import { useSearchParams } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import { useLanguage } from "@/context/LanguageContext.jsx";

const FALLBACK_SVG = {
  player:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80' viewBox='0 0 80 80'>
         <rect width='100%' height='100%' fill='#f3f4f6'/>
         <circle cx='40' cy='28' r='16' fill='#d1d5db'/>
         <rect x='14' y='50' width='52' height='18' rx='9' fill='#e5e7eb'/>
       </svg>`
    ),
  team:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
         <rect width='100%' height='100%' fill='#f3f4f6'/>
         <path d='M20 4l12 6v8c0 8-6 14-12 18C14 32 8 26 8 18V10l12-6z' fill='#d1d5db'/>
       </svg>`
    ),
  league:
    "data:image/svg+xml;utf8," +
    encodeURIComponent(
      `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
         <rect width='100%' height='100%' fill='#f3f4f6'/>
         <path d='M10 8h20v8c0 6-4 10-10 12C14 26 10 22 10 16V8z' fill='#d1d5db'/>
         <rect x='14' y='28' width='12' height='4' rx='2' fill='#e5e7eb'/>
       </svg>`
    ),
};

const SafeImg = ({ src, alt = "", className = "", fallback = "team", ...rest }) => {
  const onErr = (e) => {
    e.currentTarget.onerror = null;
    e.currentTarget.src = FALLBACK_SVG[fallback] || FALLBACK_SVG.team;
  };
  return <img src={src} alt={alt} className={className} onError={onErr} loading="lazy" decoding="async" draggable={false} {...rest} />;
};

const teamLogo = (id) => `/icons/team_logos/${id}.png`;
const playerPhoto = (id) => `/icons/player_photos/${id}.png`;

const FAVORITES_COPY = {
  date: { ru: "Дата", en: "Date" },
  league: { ru: "Лига", en: "League" },
  match: { ru: "Матч", en: "Match" },
  mins: { ru: "Мин", en: "Min" },
  goals: { ru: "Г", en: "G" },
  assists: { ru: "П", en: "A" },
  yellow: { ru: "ЖК", en: "YC" },
  red: { ru: "КК", en: "RC" },
  rating: { ru: "Рейт", en: "Rate" },
  apps: { ru: "И", en: "Apps" },
  club: { ru: "Клуб", en: "Club" },
};

const loadWatch = () => {
  try { return JSON.parse(localStorage.getItem("watch_players") || "[]"); } catch { return []; }
};
const saveWatch = (arr) => {
  try { localStorage.setItem("watch_players", JSON.stringify(arr.slice(0, 200))); } catch {}
};

function PlayerModal({ playerId, onClose }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const [ov, setOv] = useState(null);
  const [recent, setRecent] = useState([]);
  const [career, setCareer] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!playerId) return;
    let cancel = false;
    (async () => {
      setLoading(true);
      try {
        const [o, r, k] = await Promise.all([
          fetch(`/api/player/overview?player_id=${playerId}`).then((x) => x.json()),
          fetch(`/api/player/recent?player_id=${playerId}&limit=10`).then((x) => x.json()),
          fetch(`/api/player/career?player_id=${playerId}`).then((x) => x.json()),
        ]);
        if (!cancel) {
          setOv(o || null);
          setRecent(Array.isArray(r) ? r : []);
          setCareer(Array.isArray(k) ? k : []);
        }
      } finally {
        if (!cancel) setLoading(false);
      }
    })();
    return () => { cancel = true; };
  }, [playerId]);

  useEffect(() => {
    if (!playerId) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e) => e.key === "Escape" && onClose?.();
    window.addEventListener("keydown", onKey);
    return () => { document.body.style.overflow = prev; window.removeEventListener("keydown", onKey); };
  }, [playerId, onClose]);

  return (
    <div className="fixed inset-0 z-[100]">
      <div className="absolute inset-0 bg-black/60" onClick={onClose} />
      <div className="surface-toolbar absolute left-1/2 top-10 -translate-x-1/2 w-[min(960px,96vw)] overflow-hidden shadow-2xl">
        <div className="relative bg-gradient-to-r from-rose-600 via-rose-500 to-rose-400 text-white p-4">
          <button onClick={onClose} className="surface-button absolute right-3 top-3 h-8 w-8 justify-center px-0 text-white">×</button>
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 rounded-xl bg-surface-2 p-1 overflow-hidden grid place-items-center border border-glass">
              <SafeImg src={playerPhoto(playerId)} className="h-14 w-14 rounded-lg object-cover" alt="" fallback="player" />
            </div>
            <div className="min-w-0">
              <div className="text-xl font-bold truncate">{ov?.player || (language === "ru" ? "Игрок" : "Player")}</div>
              <div className="text-sm opacity-90 truncate inline-flex items-center gap-2">
                {ov?.last_team_id && <SafeImg src={teamLogo(ov.last_team_id)} className="w-4 h-4 object-contain" alt="" fallback="team" />}
                <span>{ov?.last_team || "—"}</span>
                {ov?.last_league && <span>· {ov.last_league} {ov?.last_season || ""}</span>}
              </div>
            </div>
          </div>
        </div>

        <div className="p-4 space-y-4">
          {loading ? <div className="glass-card h-40 animate-pulse" /> : (
            <>
              <div className="rounded-xl border border-glass overflow-hidden">
                <div className="px-3 py-2 bg-surface-2 border-b border-glass text-sm font-semibold text-slate-100">
                  {language === "ru" ? "Последние игры" : "Recent matches"}
                </div>
                <div className="px-3 py-1.5 text-xs text-slate-400 bg-surface-1/70 border-b border-glass">
                  {language === "ru" ? "Последние матчи игрока: минуты, голы, ассисты и рейтинг." : "Player recent matches: minutes, goals, assists and rating."}
                </div>
                <div className="overflow-x-auto">
                  <table className="min-w-full text-sm">
                    <thead className="bg-surface-2/80 text-slate-300">
                      <tr className="[&>th]:px-3 [&>th]:py-2">
                        <th className="text-left">{isRu ? FAVORITES_COPY.date.ru : FAVORITES_COPY.date.en}</th>
                        <th className="text-left">{isRu ? FAVORITES_COPY.league.ru : FAVORITES_COPY.league.en}</th>
                        <th className="text-left">{isRu ? FAVORITES_COPY.match.ru : FAVORITES_COPY.match.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.mins.ru : FAVORITES_COPY.mins.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.goals.ru : FAVORITES_COPY.goals.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.assists.ru : FAVORITES_COPY.assists.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.yellow.ru : FAVORITES_COPY.yellow.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.red.ru : FAVORITES_COPY.red.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.rating.ru : FAVORITES_COPY.rating.en}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {recent.map((r, i) => (
                        <tr key={i} className="border-t border-glass hover:bg-white/5">
                          <td className="px-3 py-2">{r.date}</td>
                          <td className="px-3 py-2">{r.league} {r.season}</td>
                          <td className="px-3 py-2">
                            <span className="inline-flex items-center gap-2">
                              <SafeImg src={teamLogo(r.team_id)} className="w-5 h-5 object-contain" alt="" fallback="team" />
                              <span className="font-medium">{r.team_name}</span>
                              <span className="text-slate-500">{isRu ? "vs" : "vs"}</span>
                              <SafeImg src={teamLogo(r.opponent_team_id)} className="w-5 h-5 object-contain" alt="" fallback="team" />
                              <span>{r.opponent}</span>
                            </span>
                          </td>
                          <td className="px-3 py-2 text-center">{r.minutes ?? "—"}</td>
                          <td className="px-3 py-2 text-center">{r.goals ?? 0}</td>
                          <td className="px-3 py-2 text-center">{r.assists ?? 0}</td>
                          <td className="px-3 py-2 text-center">{r.cards_yellow ?? 0}</td>
                          <td className="px-3 py-2 text-center">{r.cards_red ?? 0}</td>
                          <td className="px-3 py-2 text-center">{r.rating?.toFixed ? r.rating.toFixed(2) : r.rating ?? "—"}</td>
                        </tr>
                      ))}
                      {recent.length === 0 && <tr><td className="px-3 py-4 text-center" colSpan={9}><div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div></td></tr>}
                    </tbody>
                  </table>
                </div>
              </div>

              <div className="rounded-xl border border-glass overflow-hidden">
                  <div className="px-3 py-2 bg-surface-2 border-b border-glass text-sm font-semibold text-slate-100">{language === "ru" ? "Карьера" : "Career"}</div>
                <div className="px-3 py-1.5 text-xs text-slate-400 bg-surface-1/70 border-b border-glass">
                  {language === "ru" ? "Итоги по сезонам: игры, минуты, результативность." : "Season totals: apps, minutes and production."}
                </div>
                <div className="overflow-x-auto">
                  <table className="min-w-full text-sm">
                    <thead className="bg-surface-2/80 text-slate-300">
                      <tr className="[&>th]:px-3 [&>th]:py-2">
                        <th className="text-left">{language === "ru" ? "Сезон" : "Season"}</th>
                        <th className="text-left">{isRu ? FAVORITES_COPY.club.ru : FAVORITES_COPY.club.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.apps.ru : FAVORITES_COPY.apps.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.mins.ru : FAVORITES_COPY.mins.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.goals.ru : FAVORITES_COPY.goals.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.assists.ru : FAVORITES_COPY.assists.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.yellow.ru : FAVORITES_COPY.yellow.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.red.ru : FAVORITES_COPY.red.en}</th>
                        <th className="text-center">{isRu ? FAVORITES_COPY.rating.ru : FAVORITES_COPY.rating.en}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {career.map((r, i) => (
                        <tr key={i} className="border-t border-glass hover:bg-white/5">
                          <td className="px-3 py-2">{r.season}</td>
                          <td className="px-3 py-2"><span className="inline-flex items-center gap-2"><SafeImg src={teamLogo(r.team_id)} className="w-5 h-5 object-contain" alt="" fallback="team" />{r.team}</span></td>
                          <td className="px-3 py-2 text-center">{r.apps}</td>
                          <td className="px-3 py-2 text-center">{r.minutes}</td>
                          <td className="px-3 py-2 text-center">{r.goals}</td>
                          <td className="px-3 py-2 text-center">{r.assists}</td>
                          <td className="px-3 py-2 text-center">{r.yellow}</td>
                          <td className="px-3 py-2 text-center">{r.red}</td>
                          <td className="px-3 py-2 text-center">{r.rating?.toFixed ? r.rating.toFixed(2) : r.rating}</td>
                        </tr>
                      ))}
                      {career.length === 0 && <tr><td className="px-3 py-4 text-center" colSpan={9}><div className="surface-empty">{language === "ru" ? "Нет данных" : "No data"}</div></td></tr>}
                    </tbody>
                  </table>
                </div>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default function FavoritesPage() {
  const { language } = useLanguage();
  const [searchParams] = useSearchParams();
  const [league, setLeague] = useState(searchParams.get("league") || "Premier League");
  const [season, setSeason] = useState(searchParams.get("season") || "2025");

  const [ids, setIds] = useState(() => loadWatch());
  const [rows, setRows] = useState([]);
  const [openId, setOpenId] = useState(null);

  useEffect(() => {
    let cancel = false;
    (async () => {
      try {
        const data = await Promise.all(
          ids.map(async (id) => {
            const o = await fetch(`/api/player/overview?player_id=${id}`).then((r) => r.json());
            return { player_id: id, player: o?.player || `ID ${id}`, last_team: o?.last_team, last_team_id: o?.last_team_id, last_league: o?.last_league, last_season: o?.last_season };
          })
        );
        if (!cancel) setRows(data);
      } catch {
        if (!cancel) setRows([]);
      }
    })();
    return () => { cancel = true; };
  }, [ids]);

  const remove = useCallback((id) => {
    setIds((prev) => {
      const next = prev.filter((x) => x !== id);
      saveWatch(next);
      return next;
    });
  }, []);

  return (
    <div className="p-4 space-y-4 max-w-5xl mx-auto text-slate-200">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-bold text-slate-100">{language === "ru" ? "Избранное" : "Favorites"}</h1>
        {ids.length > 0 && (
          <button
            onClick={() => { saveWatch([]); setIds([]); }}
            className="h-9 px-3 rounded-lg border border-glass bg-surface-2 hover:bg-surface-1/70 text-sm"
          >
            {language === "ru" ? "Очистить всё" : "Clear all"}
          </button>
        )}
      </div>

      <Card className="panel">
        <CardContent className="p-0">
          <div className="divide-y">
            {rows.map((p) => (
              <div key={p.player_id} className="p-3 flex items-center gap-3">
                <button onClick={() => setOpenId(p.player_id)} className="flex items-center gap-3 text-left hover:opacity-90">
                  <SafeImg src={playerPhoto(p.player_id)} className="w-10 h-10 rounded-full object-cover border" alt="" fallback="player" />
                  <div className="min-w-0">
                    <div className="font-semibold truncate text-slate-100">{p.player}</div>
                    <div className="text-xs text-slate-400 truncate inline-flex items-center gap-2">
                      {p.last_team_id && <SafeImg src={teamLogo(p.last_team_id)} className="w-4 h-4 object-contain" alt="" fallback="team" />}
                      <span>{p.last_team || "—"}</span>
                      {p.last_league && <span>· {p.last_league} {p.last_season || ""}</span>}
                    </div>
                  </div>
                </button>
                <div className="ml-auto">
                  <button onClick={() => remove(p.player_id)} className="h-8 px-3 rounded-md border border-glass bg-surface-2 hover:bg-surface-1/70 text-sm">{language === "ru" ? "Убрать" : "Remove"}</button>
                </div>
              </div>
            ))}
            {rows.length === 0 && (
              <div className="p-6 text-center text-slate-400">{language === "ru" ? "Список пуст. Добавляйте игроков из таблиц звездочкой." : "The list is empty. Add players from tables using the star."}</div>
            )}
          </div>
        </CardContent>
      </Card>

      {openId && <PlayerModal playerId={openId} onClose={() => setOpenId(null)} />}
    </div>
  );
}
