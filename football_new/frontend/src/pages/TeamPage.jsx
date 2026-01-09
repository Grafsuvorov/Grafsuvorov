import { useEffect, useState } from "react";
import { useParams, useSearchParams } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";
import TeamTrends from "@/components/TeamTrends";

export default function TeamPage() {
  const { id } = useParams();              // team_id (стабильный хэш на бэке)
  const [search] = useSearchParams();
  const league = search.get("league") || "Premier League";
  const season = search.get("season") || "2025";

  const [ov, setOv] = useState(null);
  const [roll, setRoll] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(()=> {
    let c=false;
    (async ()=>{
      setLoading(true);
      const base = new URLSearchParams({ league, season });
      const [o, r] = await Promise.all([
        fetch(`http://localhost:8001/api/team/overview?team_id=${id}&${base}`).then(x=>x.json()),
        fetch(`http://localhost:8001/api/team/rolling?team_id=${id}&${base}&window=10`).then(x=>x.json())
      ]);
      if (!c) { setOv(o || null); setRoll(Array.isArray(r)? r : []); setLoading(false); }
    })();
    return ()=>{c=true};
  }, [id, league, season]);

  return (
    <div className="space-y-3">
      <div className="text-lg font-semibold">
        Команда — {ov?.team || "…"} ({league} {season})
      </div>

      <Card>
        <CardContent className="p-3">
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-3">
            {["xg","xga","shots","possession","tempo"].map((k)=>(
              <div key={k} className="rounded-lg border border-gray-200 p-3">
                <div className="text-[12px] text-gray-500">{k.toUpperCase()}</div>
                <div className="text-xl font-semibold">{ov?.[k]?.toFixed ? ov[k].toFixed(2) : (ov?.[k] ?? "—")}</div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

      <TeamTrends data={roll} metrics={["xg","xga","shots","possession"]} height={220} />

      {loading && <div className="text-sm text-gray-500">Загрузка…</div>}
    </div>
  );
}
