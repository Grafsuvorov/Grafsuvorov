// src/pages/PlayerPage.jsx
import { useEffect, useState, useMemo } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import SafeImg from "@/components/SafeImg";
import { teamLogoMap } from "@/constants/teamLogoMap";

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
function FormGraph({ recent }) {
  // берём рейтинги (не null)
  const ratings = recent
    .map((m) => (typeof m.rating === "number" ? m.rating : null))
    .filter((x) => x !== null);

  if (!ratings.length)
    return (
      <div className="text-slate-500 text-xs mt-1">
        Нет данных формы
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
    <div className="flex items-end gap-1 h-12 mt-2">
      {norm.map((v, i) => (
        <div
          key={i}
          style={{ height: `${20 + v * 25}px` }}
          className="
            w-2
            rounded-md
            bg-gradient-to-t from-fuchsia-600/30 to-violet-400/70
            shadow-[0_0_12px_rgba(180,80,255,0.45)]
          "
        />
      ))}
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
function MatchRow({ r }) {
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

  const ratingColor =
    r.rating >= 8 ? "#d8b4fe" :
    r.rating >= 7 ? "#c084fc" :
    r.rating >= 6 ? "#a78bfa" : "#818cf8";

  return (
    <tr className="group border-t border-white/10 hover:bg-white/5 transition">

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
          <div
            className="
              min-w-[52px]
              flex items-center justify-center
              px-2 py-1
              rounded-lg
              bg-gradient-to-b from-violet-500/30 to-fuchsia-500/20
              text-white font-semibold text-sm
              shadow-[0_0_10px_rgba(160,120,255,0.35)]
              tabular-nums
            "
          >
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
        className="px-4 py-3 text-center text-sm font-semibold w-[60px] tabular-nums"
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
function RecentTable({ items }) {
  return (
    <div className="table-surface rounded-2xl overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-white/5 text-slate-400 text-xs uppercase">
            <th className="px-3 py-2 text-left w-[110px]">Дата</th>
            <th className="px-3 py-2 text-left w-[360px]">Матч</th>
            <th className="px-3 py-2 text-center w-[60px]">Мин</th>
            <th className="px-3 py-2 text-center w-[50px]">Г</th>
            <th className="px-3 py-2 text-center w-[50px]">П</th>
            <th className="px-3 py-2 text-center w-[50px]">ЖК</th>
            <th className="px-3 py-2 text-center w-[50px]">КК</th>
            <th className="px-3 py-2 text-center w-[60px]">Рейт</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r, i) => (
            <MatchRow r={r} key={i} />
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* =====================================================================
   CAREER TABLE
===================================================================== */
function CareerTable({ items }) {
  return (
    <div className="table-surface rounded-2xl overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="bg-white/5 text-slate-400 text-xs uppercase">
            <th className="px-3 py-2 text-left">Сезон</th>
            <th className="px-3 py-2 text-left">Клуб</th>
            <th className="px-3 py-2 text-center">И</th>
            <th className="px-3 py-2 text-center">Мин</th>
            <th className="px-3 py-2 text-center">Г</th>
            <th className="px-3 py-2 text-center">П</th>
            <th className="px-3 py-2 text-center">ЖК</th>
            <th className="px-3 py-2 text-center">КК</th>
            <th className="px-3 py-2 text-center">Рейт</th>
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
              <td className="px-3 py-2 text-center text-fuchsia-200 font-semibold">
                {r.rating?.toFixed ? r.rating.toFixed(2) : r.rating}
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
  const { id } = useParams();
  const [search] = useSearchParams();
  const API = "http://localhost:8001/api";

  const [overview, setOverview] = useState(null);
  const [recent, setRecent] = useState([]);
  const [career, setCareer] = useState([]);
  const [loading, setLoading] = useState(true);

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

  const fullName = overview?.player || "Игрок";

  return (
    <div className="space-y-6">

      {/* HEADER */}
      <Card className="panel rounded-3xl shadow-[0_18px_60px_rgba(0,0,0,0.7)]">
        <CardContent className="p-6 flex items-center gap-6">

          {/* PHOTO */}
          <div className="relative">
            <div
              className="
                absolute inset-0
                rounded-2xl
                bg-gradient-to-br from-violet-600/20 to-fuchsia-500/10
                blur-xl opacity-70
              "
            />
            <SafeImg
              src={`/icons/player_photos/${id}.png`}
              className="relative z-10 h-28 w-28 rounded-2xl object-cover shadow-xl ring-1 ring-white/20 bg-white/10"
              fallback="/icons/player_photos/default.png"
            />
          </div>

          {/* MAIN INFO */}
          <div className="flex-1 min-w-0">
            <div className="text-2xl font-semibold truncate text-white">
              {fullName}
            </div>

            <div className="text-slate-400 text-sm truncate">
              {overview?.last_team || "—"} · {overview?.last_league || ""}{" "}
              {overview?.last_season || ""}
            </div>

            {/* FORM GRAPH */}
            <FormGraph recent={recent} />
          </div>

          {/* EXTRA INFO */}
          <div className="hidden sm:block w-48 space-y-2">
            <InfoRow label="Возраст" value={overview?.age} />
            <InfoRow label="Позиция" value={overview?.position} />
          </div>
        </CardContent>
      </Card>

      {/* RECENT MATCHES */}
      <Card className="panel rounded-3xl">
        <CardContent className="p-6">
          <div className="text-lg font-semibold mb-3 text-white">Последние игры</div>
          {recent.length ? (
            <RecentTable items={recent} />
          ) : (
            <div className="text-slate-400">Нет данных.</div>
          )}
        </CardContent>
      </Card>

      {/* CAREER */}
      <Card className="panel rounded-3xl">
        <CardContent className="p-6">
          <div className="text-lg font-semibold mb-3 text-white">
            Карьера (по сезонам и клубам)
          </div>
          {career.length ? (
            <CareerTable items={career} />
          ) : (
            <div className="text-slate-400">Нет данных.</div>
          )}
        </CardContent>
      </Card>

      {loading && <div className="text-slate-400">Загрузка…</div>}
    </div>
  );
}
