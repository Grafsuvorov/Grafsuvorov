import { useMemo, useState, useEffect } from "react";
import { Card, CardContent } from "@/components/ui/card";

const FALLBACK_LEAGUE = 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect width="24" height="24" rx="6" fill="%23f3f4f6"/><path d="M6 7h12v3l-2 2-4 6-4-6-2-2V7z" fill="%23e11d48"/></svg>';
const missingCache = new Set();
function useImageWithFallback(src, fallback) {
  const [current, setCurrent] = useState(missingCache.has(src) ? fallback : src);
  useEffect(() => { setCurrent(missingCache.has(src) ? fallback : src); }, [src, fallback]);
  const onError = () => { missingCache.add(src); setCurrent(fallback); };
  return [current, onError];
}

function LeagueIcon({ name }) {
  const safeName = typeof name === "string" ? name.trim() : "";
  const path = useMemo(() => {
    if (!safeName) return FALLBACK_LEAGUE;
    return `/icons/${safeName.replace(/\s/g, "_")}.png`;
  }, [safeName]);
  const [resolved, handleError] = useImageWithFallback(path, FALLBACK_LEAGUE);
  return (
    <img
      src={resolved}
      className="h-5 w-5 object-contain"
      onError={handleError}
      alt={safeName || "league"}
      loading="lazy"
      decoding="async"
    />
  );
}

export default function RecentLeaguesCard({ items = [], onPick, activeName }) {
  const last5 = items.slice(0, 5);

  const handleCatalogClick = () => {
    window.dispatchEvent(new Event("open-league-catalog"));
  };

  return (
    <Card className="min-h-[220px] shadow-sm border border-white/6 bg-gradient-to-b from-white/[0.03] via-white/[0.015] to-white/[0.008] text-slate-100">
      <CardContent className="p-4">
        <div className="mb-3 flex items-center justify-between text-sm font-semibold text-slate-200">
          <span>Недавние лиги</span>
         <button
            type="button"
            onClick={handleCatalogClick}
            className="inline-flex items-center gap-1 rounded-full border border-glass bg-surface-1/70 px-2.5 py-1 text-[11px] font-medium text-slate-300 transition hover:bg-surface-2 hover:text-white focus:outline-none focus-visible:ring-2 focus-visible:ring-rose-300 focus-visible:ring-offset-0"
          >
            <span>Каталог</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              className="h-3.5 w-3.5"
              aria-hidden="true"
            >
              <path d="M7.05 4.55a.75.75 0 0 1 1.06.02l4.25 4.45a.75.75 0 0 1 0 1.04l-4.25 4.45a.75.75 0 1 1-1.08-1.04L11.1 10 7.03 5.59a.75.75 0 0 1 .02-1.04z" />
            </svg>
          </button>
        </div>
        <p className="mb-3 text-xs text-slate-400">500+ турниров и соревнований</p>
        {last5.length ? (
          <ul className="space-y-1">
            {last5.map((name) => {
              const isActive = name === activeName;
              return (
                <li key={name}>
                  <button
                    type="button"
                    onMouseDown={(e) => e.preventDefault()}
                    onClick={() => onPick?.(name)}
                    className={[
                      "flex w-full items-center gap-2 rounded-md px-2 py-1 text-left text-slate-200 transition",
                      isActive
                        ? "bg-rose-500/15 text-rose-200 ring-1 ring-rose-400/40"
                        : "bg-surface-1/60 hover:bg-slate-800/85 hover:shadow-[inset_0_0_20px_rgba(0,0,0,0.35)] active:bg-surface-2",
                      "focus:outline-none focus-visible:ring-2 focus-visible:ring-rose-300 focus-visible:ring-offset-0",
                    ].join(" ")}
                    aria-current={isActive ? "true" : "false"}
                  >
                    <LeagueIcon name={name} />
                    <span className="truncate">{name}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        ) : (
          <div className="text-sm text-slate-400">Список пуст.</div>
        )}
      </CardContent>
    </Card>
  );
}
