import { useEffect, useMemo, useState } from "react";
import { useSearchParams, useNavigate } from "react-router-dom";
import { Card, CardContent } from "@/components/ui/card";

/* ========== helpers ========== */
const leagueLogo = (name) => (name ? `/icons/${String(name).replace(/\s/g, "_")}.png` : "/icons/default_league.png");
const teamLogo   = (id)   => (id ? `/icons/team_logos/${id}.png` : "/icons/default_league.png");

const FALLBACK_SVG =
  "data:image/svg+xml;utf8," +
  encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='40' height='40' viewBox='0 0 40 40'>
       <rect width='100%' height='100%' fill='#f3f4f6'/>
       <circle cx='20' cy='16' r='10' fill='#d1d5db'/>
       <rect x='8' y='28' width='24' height='6' rx='3' fill='#e5e7eb'/>
     </svg>`
  );

function SafeImg({ src, alt = "", className = "" }) {
  const onErr = (e) => { e.currentTarget.onerror = null; e.currentTarget.src = FALLBACK_SVG; };
  return <img src={src} alt={alt} className={className} onError={onErr} loading="lazy" decoding="async" draggable={false} />;
}

function TeamBadge({ id, name, align = "left" }) {
  const badge = (
    <span className="h-12 w-12 rounded-xl grid place-items-center overflow-hidden bg-white border border-gray-200">
      <SafeImg src={teamLogo(id)} alt={name} className="h-9 w-9 object-contain" />
    </span>
  );
  return (
    <div className={`flex items-center gap-2 min-w-0 ${align === "right" ? "justify-end" : ""}`}>
      {align === "left" && badge}
      <span className={`truncate font-semibold ${align === "right" ? "text-right" : ""}`}>{name || "—"}</span>
      {align === "right" && badge}
    </div>
  );
}

function CompareRow({ label, a, b, fmt = (v) => (v == null ? "—" : Number(v).toFixed(2)) }) {
  const av = Number.isFinite(Number(a)) ? Number(a) : 0;
  const bv = Number.isFinite(Number(b)) ? Number(b) : 0;
  const max = Math.max(av, bv, 0.0001);
  const wa = Math.round((av / max) * 100);
  const wb = Math.round((bv / max) * 100);
  return (
    <div className="grid grid-cols-12 items-center gap-2">
      <div className="col-span-3 text-xs text-gray-500">{label}</div>
      <div className="col-span-4">
        <div className="text-[11px] text-gray-600">{fmt(a)}</div>
        <div className="h-1.5 rounded-full bg-gray-100">
          <div className="h-1.5 rounded-full bg-emerald-500/90" style={{ width: `${wa}%` }} />
        </div>
      </div>
      <div className="col-span-1 text-center text-[11px] text-gray-400">—</div>
      <div className="col-span-4">
        <div className="text-[11px] text-gray-600 text-right">{fmt(b)}</div>
        <div className="h-1.5 rounded-full bg-gray-100 relative">
          <div className="h-1.5 rounded-full bg-rose-500/90 absolute right-0" style={{ width: `${wb}%` }} />
        </div>
      </div>
    </div>
  );
}

/* ======= модалка выбора команд — центр, тот же стиль ======= */
function PickTeamsModal({ league, season, teams, aId, bId, onPick, onClose }) {
  const [q, setQ] = useState("");
  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKey = (e) => e.key === "Escape" && onClose?.();
    window.addEventListener("keydown", onKey);
    return () => { document.body.style.overflow = prev; window.removeEventListener("keydown", onKey); };
  }, [onClose]);

  const filtered = useMemo(() => {
    const s = q.toLowerCase().trim();
    return !s ? teams : teams.filter(t => t.team.toLowerCase().includes(s));
  }, [q, teams]);

  const overlayStyle = {
    background: `linear-gradient(115deg, rgba(225,29,72,0.40), rgba(225,29,72,0.18))`,
  };

  return (
    <div className="fixed inset-0 z-[100]">
      <div className="absolute inset-0 backdrop-blur-[2px]" style={overlayStyle} onClick={onClose} />
      <div className="absolute left-1/2 top-16 -translate-x-1/2 w-[min(920px,96vw)] rounded-2xl border border-rose-100 bg-white/95 shadow-2xl">
        <button
          onClick={onClose}
          className="absolute -right-3 -top-3 h-9 w-9 rounded-full bg-white border border-gray-200 shadow grid place-items-center hover:bg-gray-50"
          aria-label="Закрыть"
          title="Закрыть"
        >×</button>

        <div className="px-4 py-3 border-b bg-white/95 rounded-t-2xl">
          <div className="text-sm text-gray-800">Выберите две команды · {league} {season}</div>
          <div className="mt-2">
            <input
              value={q}
              onChange={(e)=>setQ(e.target.value)}
              placeholder="Найти команду…"
              className="w-full h-10 rounded-lg border border-gray-300 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-gray-200"
            />
          </div>
        </div>

        <div className="p-4 grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2 max-h-[65vh] overflow-auto">
          {filtered.map((t) => {
            const selected = t.team_id===aId || t.team_id===bId;
            return (
              <button
                key={t.team_id}
                onClick={() => onPick(t)} // автозакрытие после второй
                className={`flex items-center gap-3 rounded-lg border p-2 text-left hover:shadow-sm transition ${selected ? "border-black" : "border-gray-200"}`}
                title={t.team}
              >
                <span className="h-9 w-9 rounded-full grid place-items-center overflow-hidden bg-white border border-gray-200">
                  <SafeImg src={teamLogo(t.team_id)} alt={t.team} className="h-6 w-6 object-contain" />
                </span>
                <span className="text-sm font-medium truncate">{t.team}</span>
              </button>
            );
          })}
          {!filtered.length && <div className="col-span-full text-sm text-gray-500">Ничего не найдено.</div>}
        </div>
      </div>
    </div>
  );
}

/* ========== PAGE ========== */
export default function CompareTeamsPage() {
  const navigate = useNavigate();
  const [sp, setSp] = useSearchParams();
  const league = sp.get("league") || "Premier League";
  const season = sp.get("season") || "2025";
  const qpA = sp.get("teamA") || sp.get("home") || "";
  const qpB = sp.get("teamB") || sp.get("away") || "";

  const [teams, setTeams] = useState([]);
  const [aId, setAId] = useState(null);
  const [bId, setBId] = useState(null);
  const [aOverview, setAOverview] = useState(null);
  const [bOverview, setBOverview] = useState(null);
  const [openPick, setOpenPick] = useState(false);

  const goTable = () => navigate(`/table?league=${encodeURIComponent(league)}&season=${season}`);

  useEffect(() => {
    const onKey = (e) => { if (e.key === "Escape" && !openPick) goTable(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [openPick]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    let c = false;
    (async () => {
      try {
        const qs = new URLSearchParams({ league, season });
        const r = await fetch(`http://localhost:8001/api/league/teams?${qs.toString()}`);
        const items = (await r.json()) || [];
        if (c) return;
        const valid = items.filter((x) => x?.team_id != null && x?.team);
        setTeams(valid);

        const findByName = (nm) => valid.find((x) => x.team.toLowerCase() === nm?.toLowerCase())?.team_id;
        const a = qpA ? findByName(qpA) : valid[0]?.team_id ?? null;
        const b = qpB ? findByName(qpB) : valid[1]?.team_id ?? null;
        setAId(a);
        setBId(b);
      } catch { if (!c) setTeams([]); }
    })();
    return () => { c = true; };
  }, [league, season]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    let c = false;
    async function load(id, setOverview) {
      if (!id) return;
      try {
        const base = new URLSearchParams({ league, season });
        const o = await fetch(`http://localhost:8001/api/team/overview?team_id=${id}&${base}`).then((x) => x.json());
        if (!c) setOverview(o || null);
      } catch { if (!c) setOverview(null); }
    }
    load(aId, setAOverview);
    load(bId, setBOverview);
    return () => { c = true; };
  }, [aId, bId, league, season]);

  const teamA = useMemo(() => teams.find((t) => t.team_id === aId) || null, [teams, aId]);
  const teamB = useMemo(() => teams.find((t) => t.team_id === bId) || null, [teams, bId]);

  const handlePick = (t) => {
    if (!aId || (aId && bId)) { setAId(t.team_id); setBId(null); }
    else if (!bId && t.team_id !== aId) { setBId(t.team_id); setOpenPick(false); }
  };

  useEffect(() => {
    const params = new URLSearchParams(sp);
    if (teamA) params.set("teamA", teamA.team);
    if (teamB) params.set("teamB", teamB.team);
    params.set("league", league);
    params.set("season", season);
    setSp(params, { replace: true });
  }, [teamA, teamB, league, season]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="space-y-3">
      {/* плавающий крестик «к таблице» */}
      <button
        onClick={goTable}
        className="fixed right-4 top-4 z-40 h-9 w-9 rounded-full bg-white border border-gray-200 shadow hover:bg-gray-50"
        title="Назад к таблице"
        aria-label="Назад к таблице"
      >
        ×
      </button>

      {/* верхняя полоса */}
      <Card>
        <CardContent className="p-3">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <span className="h-9 w-9 rounded-lg bg-white border border-gray-200 grid place-items-center overflow-hidden">
                <SafeImg src={leagueLogo(league)} alt={league} className="h-7 w-7 object-contain" />
              </span>
              <div className="text-sm font-semibold">{league} {season}</div>
            </div>
            <button onClick={() => setOpenPick(true)} className="h-8 px-3 rounded-lg border border-gray-300 text-sm bg-white hover:bg-gray-50">
              Выбрать команды
            </button>
          </div>

          <div className="mt-3 grid grid-cols-1 sm:grid-cols-[1fr,36px,1fr] items-center gap-3">
            <TeamBadge id={teamA?.team_id} name={teamA?.team} />
            <div className="text-center text-sm text-gray-400">—</div>
            <TeamBadge id={teamB?.team_id} name={teamB?.team} align="right" />
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-3">
          <div className="grid gap-3">
            <CompareRow label="xG"                a={aOverview?.xg}         b={bOverview?.xg} />
            <CompareRow label="xGA (допущ.)"      a={aOverview?.xga}        b={bOverview?.xga} />
            <CompareRow label="Удары"             a={aOverview?.shots}      b={bOverview?.shots} />
            <CompareRow label="Владение %"        a={aOverview?.possession} b={bOverview?.possession}
              fmt={(v)=> (v==null? "—" : `${Number(v).toFixed(1)}%`)} />
            <CompareRow label="Темп (уд./игру)"   a={aOverview?.tempo}      b={bOverview?.tempo} />
          </div>
        </CardContent>
      </Card>

      {openPick && (
        <PickTeamsModal
          league={league}
          season={season}
          teams={teams}
          aId={aId}
          bId={bId}
          onPick={handlePick}
          onClose={() => setOpenPick(false)}
        />
      )}
    </div>
  );
}
