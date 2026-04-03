export default function InsightsPanel({ teams = [] }) {
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
          title: "Неэффективная реализация",
          text: `${topXg.team} создаёт больше всех xG (${Number(topXg.xg).toFixed(2)}), но ${topFinishing.team} реализует моменты эффективнее.`,
        }
      : null,
    topShots
      ? {
          icon: "⚡",
          title: "Лидер по ударам",
          text: Number.isFinite(shotsPerMatch)
            ? `${topShots.team} наносит больше всех ударов — ${shotsPerMatch.toFixed(1)} за матч.`
            : `${topShots.team} наносит больше всех ударов в лиге.`,
        }
      : null,
    topConceded
      ? {
          icon: "🛡️",
          title: "Проблемы в обороне",
          text: Number.isFinite(concededShots)
            ? `${topConceded.team} допускает больше всего ударов (${concededShots.toFixed(1)}).`
            : `${topConceded.team} допускает больше всего ударов по воротам.`,
        }
      : null,
  ].filter(Boolean);

  return (
    <div className="rounded-[14px] border border-white/10 bg-[#121826] p-5 shadow-[0_0_18px_rgba(124,140,255,0.12)]">
      <div className="text-sm font-semibold text-white mb-3">EdgeScore Инсайты</div>
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
        {!topXg && !topShots && !topConceded && !topFinishing && <div>Недостаточно данных</div>}
      </div>
    </div>
  );
}
