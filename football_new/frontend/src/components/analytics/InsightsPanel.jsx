import { useLanguage } from "@/context/LanguageContext.jsx";

export default function InsightsPanel({ teams = [] }) {
  const { language } = useLanguage();
  const isRu = language === "ru";
  const sortedByXg = [...teams].sort((a, b) => Number(b.xg || 0) - Number(a.xg || 0));
  const sortedByShots = [...teams].sort((a, b) => Number(b.shots || 0) - Number(a.shots || 0));
  const sortedByConceded = [...teams].sort((a, b) => Number(b.shots_conceded || 0) - Number(a.shots_conceded || 0));
  const byFinishing = [...teams]
    .filter((t) => Number(t.xg || 0) > 0)
    .sort((a, b) => Number(b.goals || 0) / Number(b.xg || 1) - Number(a.goals || 0) / Number(a.xg || 1));

  const topXg = sortedByXg[0];
  const topShots = sortedByShots[0];
  const topConceded = sortedByConceded[0];
  const topFinishing = byFinishing[0];
  const shotsPerMatch = Number(topShots?.shots);
  const concededShots = Number(topConceded?.shots_conceded);

  const insightRows = [
    topXg && topFinishing
      ? {
          icon: "❗",
          title: isRu ? "Неэффективная реализация" : "Inefficient finishing",
          text: isRu
            ? `${topXg.team} создаёт больше всех xG (${Number(topXg.xg).toFixed(2)}), но ${topFinishing.team} реализует моменты эффективнее.`
            : `${topXg.team} creates the most xG (${Number(topXg.xg).toFixed(2)}), but ${topFinishing.team} finishes chances more efficiently.`,
        }
      : null,
    topShots
      ? {
          icon: "⚡",
          title: isRu ? "Лидер по ударам" : "Shot leader",
          text: Number.isFinite(shotsPerMatch)
            ? isRu
              ? `${topShots.team} наносит больше всех ударов — ${shotsPerMatch.toFixed(1)} за матч.`
              : `${topShots.team} takes the most shots with ${shotsPerMatch.toFixed(1)} per match.`
            : isRu
              ? `${topShots.team} наносит больше всех ударов в лиге.`
              : `${topShots.team} takes the most shots in the league.`,
        }
      : null,
    topConceded
      ? {
          icon: "🛡️",
          title: isRu ? "Проблемы в обороне" : "Defensive issues",
          text: Number.isFinite(concededShots)
            ? isRu
              ? `${topConceded.team} допускает больше всего ударов (${concededShots.toFixed(1)}).`
              : `${topConceded.team} allows the most shots (${concededShots.toFixed(1)}).`
            : isRu
              ? `${topConceded.team} допускает больше всего ударов по воротам.`
              : `${topConceded.team} allows the most shots on goal.`,
        }
      : null,
  ].filter(Boolean);

  return (
    <div className="glass-card p-5">
      <div className="text-sm font-semibold text-white mb-3">{isRu ? "EdgeScore Инсайты" : "EdgeScore Insights"}</div>
      <div className="space-y-3 text-sm text-white/80 leading-relaxed">
        {insightRows.map((item) => (
          <div key={item.title} className="rounded-xl border border-white/10 bg-white/[0.02] px-3 py-2">
            <div className="flex items-center gap-2 text-white">
              <span>{item.icon}</span>
              <span className="font-semibold">{item.title}</span>
            </div>
            <div className="mt-1 text-white/75">
              {item.text}
            </div>
          </div>
        ))}
        {!topXg && !topShots && !topConceded && !topFinishing && <div className="surface-empty">{isRu ? "Недостаточно данных" : "Not enough data"}</div>}
      </div>
    </div>
  );
}
