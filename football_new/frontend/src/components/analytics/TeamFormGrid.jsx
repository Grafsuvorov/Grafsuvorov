import { LineChart, Line, ResponsiveContainer, Tooltip } from "recharts";
import { useLanguage } from "@/context/LanguageContext.jsx";

const logoByTeamId = (id) =>
  id ? `https://media.api-sports.io/football/teams/${id}.png` : "/icons/default_league.png";

const formatDate = (val, language) => {
  if (!val) return "—";
  const d = new Date(val);
  if (Number.isNaN(d.getTime())) return String(val);
  return d.toLocaleDateString(language === "ru" ? "ru-RU" : "en-GB");
};

function TrendTooltip({ active, payload }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  if (!active || !payload?.length) return null;
  const p = payload[0].payload;
  return (
    <div className="rounded-[10px] border border-white/10 bg-[rgba(15,23,42,0.96)] px-3 py-2.5 text-[12px] text-white shadow-[0_10px_30px_rgba(0,0,0,0.5)]">
      <div className="mb-1 text-sm font-semibold text-white">{p.team || (isRu ? "Команда" : "Team")}</div>
      <div>{isRu ? "Дата" : "Date"}: {formatDate(p.date, language)}</div>
      <div>xG: {p.xg != null ? Number(p.xg).toFixed(2) : "—"}</div>
      <div>{isRu ? "Соперник" : "Opponent"}: {p.opponent || "—"}</div>
    </div>
  );
}

export default function TeamFormGrid({ trends = [], teams = [], trendWindow = 10, highlightedTeam = null, onTeamHover = null }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const items = trends.slice(0, 8);
  const teamIdByName = new Map((teams || []).map((t) => [t.team, t.team_id]));
  const trendColor = (series) => {
    const arr = (series || []).slice(-trendWindow).map((m) => Number(m?.xg)).filter(Number.isFinite);
    if (arr.length < 2) return "#7c8cff";
    const delta = arr[arr.length - 1] - arr[0];
    if (delta > 0.15) return "#22c55e";
    if (delta < -0.15) return "#ef4444";
    return "#7c8cff";
  };

  return (
    <div className="glass-card p-6">
      <div className="mb-4 text-base font-semibold text-white">{isRu ? "Форма команд" : "Team form"}</div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {items.map((t) => (
          <div
            key={t.team}
            className={`flex items-center gap-4 rounded-2xl px-3 py-3 ${highlightedTeam === t.team ? "bg-white/[0.05]" : "bg-white/[0.02]"}`}
            onMouseEnter={() => onTeamHover?.(t.team)}
            onMouseLeave={() => onTeamHover?.(null)}
          >
            <div className="w-[156px] flex items-center gap-3 text-sm text-white/75 truncate">
              <img
                src={logoByTeamId(teamIdByName.get(t.team))}
                alt={t.team}
                className="h-5 w-5 object-contain"
              />
              <span className="truncate">{t.team}</span>
            </div>
            <div className="flex-1 h-[64px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart
                  data={(t.last_matches || []).slice(-trendWindow).map((m) => ({
                    ...m,
                    team: t.team,
                  }))}
                >
                  <Tooltip content={<TrendTooltip />} />
                  <Line type="monotone" dataKey="xg" stroke={trendColor(t.last_matches)} strokeWidth={2.5} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        ))}
        {items.length === 0 && (
          <div className="surface-empty">{isRu ? "Недостаточно данных" : "Not enough data"}</div>
        )}
      </div>
    </div>
  );
}
