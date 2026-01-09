import { useEffect, useMemo, useState } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";

function InfoRow({ label, value }) {
  return (
    <div className="flex items-center justify-between text-sm">
      <span className="text-gray-500">{label}</span>
      <span className="font-medium">{value ?? "—"}</span>
    </div>
  );
}

function RecentTable({ items }) {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-gray-50 text-gray-600">
          <tr className="[&>th]:px-3 [&>th]:py-2">
            <th className="text-left">Дата</th>
            <th className="text-left">Лига</th>
            <th className="text-left">Соперник</th>
            <th className="text-center">Мин</th>
            <th className="text-center">Г</th>
            <th className="text-center">П</th>
            <th className="text-center">ЖК</th>
            <th className="text-center">КК</th>
            <th className="text-center">Рейт</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r, i) => (
            <tr key={i} className="border-t hover:bg-gray-50/60">
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

function CareerTable({ items }) {
  return (
    <div className="overflow-x-auto">
      <table className="min-w-full text-sm">
        <thead className="bg-gray-50 text-gray-600">
          <tr className="[&>th]:px-3 [&>th]:py-2">
            <th className="text-left">Сезон</th>
            <th className="text-left">Клуб</th>
            <th className="text-center">И</th>
            <th className="text-center">Мин</th>
            <th className="text-center">Г</th>
            <th className="text-center">П</th>
            <th className="text-center">ЖК</th>
            <th className="text-center">КК</th>
            <th className="text-center">Рейт</th>
          </tr>
        </thead>
        <tbody>
          {items.map((r, i) => (
            <tr key={i} className="border-t hover:bg-gray-50/60">
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
  const { id } = useParams();
  const [search] = useSearchParams();
  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2025";

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
          fetch(`http://localhost:8001/api/player/overview?player_id=${id}`).then(x=>x.json()),
          fetch(`http://localhost:8001/api/player/recent?player_id=${id}&limit=12`).then(x=>x.json()),
          fetch(`http://localhost:8001/api/player/career?player_id=${id}`).then(x=>x.json()),
        ]);
        if (!c) { setOv(o || null); setRecent(Array.isArray(r)? r: []); setCareer(Array.isArray(k)? k: []); }
      } finally { if (!c) setLoading(false); }
    })();
    return ()=>{ c=true };
  }, [id]);

  const fullName = ov?.player || "Игрок";
  const photo = `/player_photos/${id}.png`;

  return (
    <div className="space-y-3">
      {/* Карточка игрока */}
      <Card>
        <CardContent className="p-4">
          <div className="flex items-center gap-4">
            <img
              src={photo}
              onError={(e)=>{ e.currentTarget.onerror=null; e.currentTarget.src="/player_photos/default.png"; }}
              alt=""
              className="h-16 w-16 rounded-2xl object-cover"
            />
            <div className="min-w-0 flex-1">
              <div className="text-xl font-semibold truncate">{fullName}</div>
              <div className="text-sm text-gray-600 truncate">
                {ov?.last_team || "—"} · {ov?.last_league || ""} {ov?.last_season || ""}
              </div>
            </div>
            {/* справа — базовые поля (если появятся age/position — подставятся) */}
            <div className="w-64 hidden sm:block">
              <InfoRow label="Возраст" value={ov?.age} />
              <InfoRow label="Позиция" value={ov?.position} />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Последние игры */}
      <Card>
        <CardContent className="p-3">
          <div className="text-sm font-semibold mb-2">Последние игры</div>
          {recent.length ? <RecentTable items={recent} /> : <div className="text-sm text-gray-500">Нет данных.</div>}
        </CardContent>
      </Card>

      {/* Карьера */}
      <Card>
        <CardContent className="p-3">
          <div className="text-sm font-semibold mb-2">Карьера (по сезонам и клубам)</div>
          {career.length ? <CareerTable items={career} /> : <div className="text-sm text-gray-500">Нет данных.</div>}
        </CardContent>
      </Card>

      {loading && <div className="text-sm text-gray-500">Загрузка…</div>}
    </div>
  );
}
