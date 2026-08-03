// src/pages/PlayerPage.jsx
import { useEffect, useState, useMemo } from "react";
import { useParams, useSearchParams, useNavigate } from "react-router-dom";
import clsx from "clsx";
import { Card, CardContent } from "@/components/ui/card";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";
import { loadFavorites, saveFavorites } from "@/lib/favoritesStorage.js";
import { useLanguage } from "@/context/LanguageContext.jsx";

/* =====================================================================
   UTIL: LOGO RESOLVER
===================================================================== */
function getLogo(name, id) {
  if (id) return `/icons/team_logos/${id}.png`;
  if (name && teamLogoMap[name]) return teamLogoMap[name];
  return "/icons/team_logos/default.png";
}

/* =====================================================================
   SMALL INFO ROW
===================================================================== */
function InfoRow({ label, value }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-slate-400">{label}</span>
      <span className="font-medium text-slate-50">{value ?? "—"}</span>
    </div>
  );
}

/* =====================================================================
   FORM GRAPH — Dynamic based on rating history (variant #3)
===================================================================== */
function FormGraph({ recent, language = "ru" }) {
  const isRu = language === "ru";
  // берём рейтинги (не null)
  const ratings = recent
    .map((m) => (typeof m.rating === "number" ? m.rating : null))
    .filter((x) => x !== null);

  if (!ratings.length)
    return (
      <div className="text-slate-500 text-xs mt-1">
        {isRu ? "Нет данных формы" : "No form data"}
      </div>
    );

  // берём последние 6, если их больше
  const arr = ratings.slice(-6);

  const max = Math.max(...arr);
  const min = Math.min(...arr);

  // нормализуем под визуальные столбики
  const norm = arr.map((v) => {
    if (max === min) return 0.5;
    return (v - min) / (max - min);
  });

  return (
    <div className="mt-2">
      <div className="text-[11px] text-slate-500 mb-1">
        {isRu ? "Форма (последние матчи)" : "Form (recent matches)"}
      </div>
      <div className="flex items-end gap-1 h-12">
      {norm.map((v, i) => (
        <div
          key={i}
          style={{ height: `${20 + v * 25}px` }}
          className="
            w-2
            rounded-md
            bg-gradient-to-t from-violet-600/35 to-cyan-400/60
            shadow-[0_0_12px_rgba(120,120,255,0.35)]
          "
        />
      ))}
      </div>
    </div>
  );
}

/* =====================================================================
   MATCH ROW (Soft Glow Score + Violet Pulse Style)
===================================================================== */
/* =====================================================================
   MATCH ROW — STEKLYANNAYA PREMIUM CAPSULE (Variant A)
===================================================================== */
/* =====================================================================
   MATCH ROW — LIGHT PREMIUM (No Capsule)
===================================================================== */
function MatchRow({ r, onOpen }) {
  const isHome = r.side === "H";

  // команды по логике матча (дом/гость)
  const homeTeam = isHome ? r.team_name : r.opponent;
  const awayTeam = isHome ? r.opponent : r.team_name;

  const homeLogo = getLogo(
    homeTeam,
    isHome ? r.team_id : r.opponent_team_id
  );
  const awayLogo = getLogo(
    awayTeam,
    isHome ? r.opponent_team_id : r.team_id
  );

  // счёт
  const score =
    r.home_score != null && r.away_score != null
      ? `${r.home_score}:${r.away_score}`
      : "—";

  const ratingColor = r.rating >= 8.5 ? "#c4b5fd" : "#9ca3af";
  const ratingBold = r.rating >= 8.5;

  return (
    <tr
      className={clsx(
        "group border-t border-white/10 transition",
        onOpen ? "hover:bg-white/5 cursor-pointer" : "hover:bg-white/5"
      )}
      onClick={onOpen}
    >

      {/* DATE */}
      <td className="px-4 py-3 text-slate-300 text-sm whitespace-nowrap w-[110px]">
        {r.date}
      </td>

      {/* MATCH */}
      <td className="px-4 py-3">
        <div className="flex items-center justify-center gap-6">

          {/* HOME TEAM */}
          <div className="flex items-center gap-2 w-40 truncate">
            <SafeImg
              src={homeLogo}
              className="h-6 w-6 rounded-full bg-white/10 ring-1 ring-white/10 object-contain"
            />
            <span className="text-white text-sm truncate">{homeTeam}</span>
          </div>

          {/* SCORE */}
          <div className="min-w-[52px] text-center text-sm font-semibold text-white/90 tabular-nums">
            {score}
          </div>

          {/* AWAY TEAM */}
          <div className="flex items-center gap-2 w-40 truncate justify-end">
            <span className="text-white text-sm truncate text-right">
              {awayTeam}
            </span>
            <SafeImg
              src={awayLogo}
              className="h-6 w-6 rounded-full bg-white/10 ring-1 ring-white/10 object-contain"
            />
          </div>

        </div>
      </td>

      {/* STATS */}
      <td className="px-4 py-3 text-center text-slate-200 text-sm w-[60px]">
        {r.minutes}
      </td>
      <td className="px-4 py-3 text-center text-slate-200 text-sm w-[50px]">
        {r.goals}
      </td>
      <td className="px-4 py-3 text-center text-slate-200 text-sm w-[50px]">
        {r.assists}
      </td>
      <td className="px-4 py-3 text-center text-slate-200 text-sm w-[50px]">
        {r.cards_yellow}
      </td>
      <td className="px-4 py-3 text-center text-slate-200 text-sm w-[50px]">
        {r.cards_red}
      </td>

      {/* RATING */}
      <td
        className={`px-4 py-3 text-center text-sm w-[60px] tabular-nums ${ratingBold ? "font-semibold" : "font-normal"}`}
        style={{ color: ratingColor }}
      >
        {r.rating?.toFixed ? r.rating.toFixed(2) : r.rating ?? "—"}
      </td>
    </tr>
  );
}






/* =====================================================================
   RECENT TABLE
===================================================================== */
function RecentTable({ items, onOpenMatch, language = "ru" }) {
  const isRu = language === "ru";
  return (
    <div className="table-surface rounded-2xl overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-white/5 text-white/45 text-[11px] uppercase tracking-[0.18em]">
            <th className="px-3 py-2 text-left w-[110px]">{isRu ? "Дата" : "Date"}</th>
            <th className="px-3 py-2 text-left w-[360px]">{isRu ? "Матч" : "Match"}</th>
            <th className="px-3 py-2 text-center w-[60px]">{isRu ? "Мин" : "Min"}</th>
            <th className="px-3 py-2 text-center w-[50px]">{isRu ? "Г" : "G"}</th>
            <th className="px-3 py-2 text-center w-[50px]">{isRu ? "П" : "A"}</th>
            <th className="px-3 py-2 text-center w-[50px]">{isRu ? "ЖК" : "YC"}</th>
            <th className="px-3 py-2 text-center w-[50px]">{isRu ? "КК" : "RC"}</th>
            <th className="px-3 py-2 text-center w-[60px]">{isRu ? "Рейт" : "Rate"}</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r, i) => (
            <MatchRow
              r={r}
              key={i}
              onOpen={onOpenMatch ? () => onOpenMatch(r) : undefined}
            />
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* =====================================================================
   CAREER TABLE
===================================================================== */
function CareerTable({ items, language = "ru" }) {
  const isRu = language === "ru";
  return (
    <div className="table-surface rounded-2xl overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-white/5 text-white/45 text-[11px] uppercase tracking-[0.18em]">
            <th className="px-3 py-2 text-left">{isRu ? "Сезон" : "Season"}</th>
            <th className="px-3 py-2 text-left">{isRu ? "Клуб" : "Club"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "И" : "Apps"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "Мин" : "Min"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "Г" : "G"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "П" : "A"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "ЖК" : "YC"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "КК" : "RC"}</th>
            <th className="px-3 py-2 text-center">{isRu ? "Рейт" : "Rate"}</th>
          </tr>
        </thead>

        <tbody>
          {items.map((r, i) => (
            <tr
              key={i}
              className="border-t border-white/10 hover:bg-white/5 transition"
            >
              <td className="px-3 py-2 text-slate-200">{r.season}</td>
              <td className="px-3 py-2 text-slate-200">{r.team}</td>
              <td className="px-3 py-2 text-center text-slate-200">{r.apps}</td>
              <td className="px-3 py-2 text-center text-slate-200">{r.minutes}</td>
              <td className="px-3 py-2 text-center text-slate-200">{r.goals}</td>
              <td className="px-3 py-2 text-center text-slate-200">{r.assists}</td>
              <td className="px-3 py-2 text-center text-slate-200">{r.yellow}</td>
              <td className="px-3 py-2 text-center text-slate-200">{r.red}</td>
              <td className="px-3 py-2 text-center text-violet-200 font-semibold">
                {r.rating == null || r.rating === ""
                  ? "—"
                  : r.rating?.toFixed
                  ? r.rating.toFixed(2)
                  : r.rating}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* =====================================================================
   MAIN PAGE
===================================================================== */
export default function PlayerPage() {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const { id } = useParams();
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const API = "/api";

  const [overview, setOverview] = useState(null);
  const [recent, setRecent] = useState([]);
  const [career, setCareer] = useState([]);
  const [loading, setLoading] = useState(true);
  const [isFav, setIsFav] = useState(false);
  const favKey = "favorites_players";
  const emitFavUpdate = () => {
    try {
      window.dispatchEvent(new CustomEvent("favorites:update"));
    } catch {}
  };

  useEffect(() => {
    let cancelled = false;

    (async () => {
      setLoading(true);
      try {
        const [o, r, c] = await Promise.all([
          fetch(`${API}/player/overview?player_id=${id}`).then((x) => x.json()),
          fetch(`${API}/player/recent?player_id=${id}&limit=20`).then((x) =>
            x.json()
          ),
          fetch(`${API}/player/career?player_id=${id}`).then((x) => x.json()),
        ]);

        if (!cancelled) {
          setOverview(o || null);
          setRecent(Array.isArray(r) ? r : []);
          setCareer(Array.isArray(c) ? c : []);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [id]);

  useEffect(() => {
    try {
      const list = loadFavorites(favKey);
      setIsFav(list.some((x) => Number(x.id) === Number(id)));
    } catch {}
  }, [id]);

  const toggleFavorite = () => {
    let nextIsFav = !isFav;
    try {
      const list = loadFavorites(favKey);
      const exists = list.some((x) => Number(x.id) === Number(id));
      const next = exists
        ? list.filter((x) => Number(x.id) !== Number(id))
        : [
            ...list,
            {
              id: Number(id),
              name: overview?.player || "Игрок",
              team: overview?.last_team || "",
              league: overview?.last_league || search.get("league") || "Premier League",
              season: overview?.last_season || search.get("season") || "2026",
            },
          ];
      saveFavorites(favKey, next);
      const refreshed = loadFavorites(favKey);
      nextIsFav = refreshed.some((x) => Number(x.id) === Number(id));
    } catch {}
    setIsFav(nextIsFav);
    emitFavUpdate();
  };

  const fullName = overview?.player || "Игрок";
  const ageFromDate = (val) => {
    if (!val) return null;
    const d = new Date(val);
    if (Number.isNaN(+d)) return null;
    const now = new Date();
    let age = now.getFullYear() - d.getFullYear();
    const m = now.getMonth() - d.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < d.getDate())) age -= 1;
    return age > 0 ? age : null;
  };
  const showLowDataNote = !loading && recent.length < 3;

  return (
    <div className="w-full px-4 py-8 space-y-8">

      {/* HEADER */}
      <div>
        <div className="panel rounded-3xl p-6 md:p-8">
          <div className="flex items-start justify-between gap-6">
            <div className="flex items-start gap-5 min-w-0">
            {/* PHOTO */}
            <div className="relative shrink-0">
              <div
                className="
                  absolute inset-0
                  rounded-2xl
                  bg-gradient-to-br from-violet-600/20 to-white/5
                  blur-xl opacity-50
                "
              />
              <SafeImg
                src={`/icons/player_photos/${id}.png`}
                className="relative z-10 h-24 w-24 md:h-28 md:w-28 rounded-2xl object-cover shadow-xl ring-1 ring-white/20 bg-white/10"
                fallback="/icons/player_photos/default.png"
              />
            </div>

            {/* MAIN INFO */}
            <div className="min-w-0 flex-1 space-y-2">
              <div className="text-[11px] uppercase tracking-[0.18em] text-muted">
                {isRu ? "Профиль игрока" : "Player profile"}
              </div>
              <div className="flex flex-wrap items-start gap-3">
                <div className="text-2xl sm:text-3xl font-semibold leading-tight text-white truncate">
                  {fullName}
                </div>
                <button
                  onClick={toggleFavorite}
                  className={`inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-[11px] font-semibold transition whitespace-nowrap ${
                    isFav
                      ? "border-white/25 text-white bg-white/10"
                      : "border-white/15 text-slate-300 hover:border-white/30 hover:text-white"
                  }`}
                  title={isFav ? (isRu ? "Убрать из избранного" : "Remove from favorites") : (isRu ? "Добавить в избранное" : "Add to favorites")}
                >
                  <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden="true">
                    <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 6 3.99 4 6.5 4c1.54 0 3.04.74 4 1.9C11.46 4.74 12.96 4 14.5 4 17.01 4 19 6 19 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
                  </svg>
                  {isFav ? (isRu ? "В избранном" : "Saved") : (isRu ? "В избранное" : "Save")}
                </button>
              </div>
              <div className="text-sm text-slate-400 whitespace-normal break-words">
                {overview?.last_team || "—"} · {overview?.last_league || "—"} ·{" "}
                {isRu ? "Сезон" : "Season"} {overview?.last_season || "—"}
              </div>
              <div className="text-xs text-slate-500 whitespace-normal break-words">
                {(() => {
                  const pos =
                    overview?.position ||
                    overview?.player_position ||
                    overview?.pos ||
                    "—";
                  const ageRaw =
                    overview?.age ||
                    overview?.player_age ||
                    overview?.age_years ||
                    ageFromDate(
                      overview?.birth_date ||
                        overview?.birthdate ||
                        overview?.dob
                    ) ||
                    null;
                  const age =
                    ageRaw == null || ageRaw === "—"
                      ? "—"
                      : `${ageRaw}`;
                  return isRu ? `Возраст: ${age} · Позиция: ${pos}` : `Age: ${age} · Position: ${pos}`;
                })()}
              </div>
              {showLowDataNote && (
                <div className="text-xs text-slate-500">
                  {isRu ? "Недостаточно матчей для устойчивых выводов. Используй данные как ориентир." : "Not enough matches for stable conclusions. Use the data as a guide."}
                </div>
              )}
              <FormGraph recent={recent} language={language} />
            </div>
            </div>

            <div className="hidden md:flex flex-col items-end gap-2 shrink-0" />
          </div>
        </div>
      </div>

      {/* RECENT MATCHES */}
      <Card className="panel rounded-3xl">
        <CardContent className="p-6">
          <div className="text-lg font-semibold mb-1 text-white">{isRu ? "Последние игры" : "Recent matches"}</div>
          <div className="text-xs text-slate-400 mb-3">
            {isRu ? "Последние матчи игрока: минуты, результативность и рейтинг." : "Player recent matches: minutes, production, and rating."}
          </div>
          {recent.length ? (
            <RecentTable
              items={recent}
              language={language}
              onOpenMatch={(r) => {
                if (!r?.fixture_id) return;
                const league =
                  r.league ||
                  r.league_name ||
                  overview?.last_league ||
                  search.get("league") ||
                  "Premier League";
                const season =
                  r.season ||
                  r.season_year ||
                  overview?.last_season ||
                  search.get("season") ||
                  "2026";
                navigate(
                  `/match/${r.fixture_id}?league=${encodeURIComponent(
                    league
                  )}&season=${season}`
                );
              }}
            />
          ) : (
            <div className="text-slate-400">{isRu ? "Нет данных." : "No data."}</div>
          )}
        </CardContent>
      </Card>

      {/* CAREER */}
      <Card className="panel rounded-3xl">
        <CardContent className="p-6">
          <div className="text-lg font-semibold mb-1 text-white">
            {isRu ? "Карьера (по сезонам и клубам)" : "Career (by seasons and clubs)"}
          </div>
          <div className="text-xs text-slate-400 mb-3">
            {isRu ? "Итоги по сезонам: игры, минуты, голы, ассисты и дисциплина." : "Season totals: appearances, minutes, goals, assists, and discipline."}
          </div>
          {career.length ? (
            <CareerTable items={career} language={language} />
          ) : (
            <div className="text-slate-400">{isRu ? "Нет данных." : "No data."}</div>
          )}
        </CardContent>
      </Card>

      {loading && <div className="text-slate-400">{isRu ? "Загрузка…" : "Loading…"}</div>}
    </div>
  );
}
