import { useEffect, useMemo, useState } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import { useLanguage } from "@/context/LanguageContext.jsx";

function InfoRow({ label, value }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-slate-400">{label}</span>
      <span className="font-medium">{value ?? "—"}</span>
    </div>
  );
}

function RecentTable({ items, language = "ru" }) {
  const isRu = language === "ru";
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-surface-2/80 text-slate-300">
          <tr className="[&>th]:px-3 [&>th]:py-2">
            <th className="text-left">{isRu ? "Дата" : "Date"}</th>
            <th className="text-left">{isRu ? "Лига" : "League"}</th>
            <th className="text-left">{isRu ? "Соперник" : "Opponent"}</th>
            <th className="text-center">{isRu ? "Мин" : "Min"}</th>
            <th className="text-center">{isRu ? "Г" : "G"}</th>
            <th className="text-center">{isRu ? "П" : "A"}</th>
            <th className="text-center">{isRu ? "ЖК" : "YC"}</th>
            <th className="text-center">{isRu ? "КК" : "RC"}</th>
            <th className="text-center">{isRu ? "Рейт" : "Rate"}</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r, i) => (
            <tr key={i} className="border-t border-glass hover:bg-surface-2/60">
              <td className="px-3 py-2">{r.date}</td>
              <td className="px-3 py-2">{r.league} {r.season}</td>
              <td className="px-3 py-2">{r.side === "H" ? "vs " : "@ "}{r.opponent}</td>
              <td className="px-3 py-2 text-center">{r.minutes ?? "—"}</td>
              <td className="px-3 py-2 text-center">{r.goals ?? 0}</td>
              <td className="px-3 py-2 text-center">{r.assists ?? 0}</td>
              <td className="px-3 py-2 text-center">{r.cards_yellow ?? 0}</td>
              <td className="px-3 py-2 text-center">{r.cards_red ?? 0}</td>
              <td className="px-3 py-2 text-center">{r.rating?.toFixed ? r.rating.toFixed(2) : (r.rating ?? "—")}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function CareerTable({ items, language = "ru" }) {
  const isRu = language === "ru";
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-surface-2/80 text-slate-300">
          <tr className="[&>th]:px-3 [&>th]:py-2">
            <th className="text-left">{isRu ? "Сезон" : "Season"}</th>
            <th className="text-left">{isRu ? "Клуб" : "Club"}</th>
            <th className="text-center">{isRu ? "И" : "Apps"}</th>
            <th className="text-center">{isRu ? "Мин" : "Min"}</th>
            <th className="text-center">{isRu ? "Г" : "G"}</th>
            <th className="text-center">{isRu ? "П" : "A"}</th>
            <th className="text-center">{isRu ? "ЖК" : "YC"}</th>
            <th className="text-center">{isRu ? "КК" : "RC"}</th>
            <th className="text-center">{isRu ? "Рейт" : "Rate"}</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r, i) => (
            <tr key={i} className="border-t border-glass hover:bg-surface-2/60">
              <td className="px-3 py-2">{r.season}</td>
              <td className="px-3 py-2">{r.team}</td>
              <td className="px-3 py-2 text-center">{r.apps}</td>
              <td className="px-3 py-2 text-center">{r.minutes}</td>
              <td className="px-3 py-2 text-center">{r.goals}</td>
              <td className="px-3 py-2 text-center">{r.assists}</td>
              <td className="px-3 py-2 text-center">{r.yellow}</td>
              <td className="px-3 py-2 text-center">{r.red}</td>
              <td className="px-3 py-2 text-center">{r.rating?.toFixed ? r.rating.toFixed(2) : r.rating}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function PlayerPage() {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const { id } = useParams();
  const [search] = useSearchParams();
  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2026";

  const [ov, setOv] = useState(null);
  const [recent, setRecent] = useState([]);
  const [career, setCareer] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(()=> {
    let c=false;
    (async ()=>{
      setLoading(true);
      try {
        const [o, r, k] = await Promise.all([
          fetch(`/api/player/overview?player_id=${id}`).then(x=>x.json()),
          fetch(`/api/player/recent?player_id=${id}&limit=12`).then(x=>x.json()),
          fetch(`/api/player/career?player_id=${id}`).then(x=>x.json()),
        ]);
        if (!c) { setOv(o || null); setRecent(Array.isArray(r)? r: []); setCareer(Array.isArray(k)? k: []); }
      } finally { if (!c) setLoading(false); }
    })();
    return ()=>{ c=true };
  }, [id]);

  const fullName = ov?.player || (isRu ? "Игрок" : "Player");
  const photo = `/player_photos/${id}.png`;

  return (
    <div className="type-page text-slate-200">
      {/* Карточка игрока */}
      <Card className="panel">
        <CardContent className="p-4">
          <div className="flex items-center gap-4">
            <img
              src={photo}
              onError={(e)=>{ e.currentTarget.onerror=null; e.currentTarget.src="/player_photos/default.png"; }}
              alt=""
              className="h-16 w-16 rounded-2xl object-cover"
            />
            <div className="min-w-0 flex-1 type-title-block">
              <div className="type-section-title truncate">{fullName}</div>
              <div className="type-subtitle truncate">
                {ov?.last_team || "—"} · {ov?.last_league || ""} {ov?.last_season || ""}
              </div>
            </div>
            {/* справа — базовые поля (если появятся age/position — подставятся) */}
            <div className="w-64 hidden sm:block">
              <InfoRow label={isRu ? "Возраст" : "Age"} value={ov?.age} />
              <InfoRow label={isRu ? "Позиция" : "Position"} value={ov?.position} />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Последние игры */}
      <Card className="panel">
        <CardContent className="type-section p-4">
          <div className="type-card-title">{isRu ? "Последние игры" : "Recent matches"}</div>
          <div className="type-caption">
            {isRu ? "Последние матчи игрока: минуты, голы, ассисты и рейтинг." : "Player recent matches: minutes, goals, assists, and rating."}
          </div>
          {recent.length ? <RecentTable items={recent} language={language} /> : <div className="text-sm text-slate-400">{isRu ? "Нет данных." : "No data."}</div>}
        </CardContent>
      </Card>

      {/* Карьера */}
      <Card className="panel">
        <CardContent className="type-section p-4">
          <div className="type-card-title">{isRu ? "Карьера (по сезонам и клубам)" : "Career (by seasons and clubs)"}</div>
          <div className="type-caption">
            {isRu ? "Итоговые значения по сезону: игры, минуты, результативность." : "Season totals: appearances, minutes, and production."}
          </div>
          {career.length ? <CareerTable items={career} language={language} /> : <div className="text-sm text-slate-400">{isRu ? "Нет данных." : "No data."}</div>}
        </CardContent>
      </Card>

      {loading && <div className="text-sm text-slate-400">{isRu ? "Загрузка…" : "Loading…"}</div>}
    </div>
  );
}
