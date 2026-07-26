import clsx from "clsx";

import SegmentedTabs from "@/components/ui/SegmentedTabs";

export default function MatchOverviewAnalytics({
  title,
  analyticsPending,
  analyticsLoadingLabel,
  keyLine,
  outcomeLabel,
  outcomeText,
  totalLabel,
  totalText,
  recommendation,
  marketTab,
  onMarketTabChange,
  outcomeTabLabel,
  totalTabLabel,
  modelVsMarket,
  implied,
  modelLabel,
  marketLabel,
  totalMarketRows,
  noTotalMarketData,
  positiveGapHint,
}) {
  return (
    <div className="w-full min-w-0 overflow-hidden rounded-2xl border border-white/5 bg-gradient-to-br from-[#141824] to-[#0f1320] p-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.06),_0_12px_35px_rgba(0,0,0,0.35)] space-y-6 sm:p-8">
      <div className="flex min-w-0 items-start justify-between gap-4">
        <div className="min-w-0 break-words text-[17px] font-semibold tracking-[0.03em] text-white sm:text-[18px] sm:tracking-[0.04em]">
          {title}
        </div>
      </div>

      {analyticsPending ? (
        <div className="text-[13px] text-white/60">{analyticsLoadingLabel}</div>
      ) : (
        <>
          <div className="grid w-full min-w-0 gap-6 md:grid-cols-[1fr]">
            <div className="relative min-w-0 pl-4 sm:pl-5">
              <div className="absolute left-0 top-1 bottom-1 w-[3px] rounded-full bg-white/30 shadow-[0_0_10px_rgba(255,255,255,0.08)]" />
              <div className="w-full min-w-0">
                <div className="mb-4 break-words text-[18px] font-semibold leading-snug text-white sm:text-[20px]">
                  {keyLine}
                </div>
                <div className="mb-2 text-[12px] uppercase tracking-[0.12em] text-white/60">
                  {outcomeLabel}
                </div>
                <div className="mb-4 break-words text-[14px] leading-relaxed text-white/75">
                  {outcomeText}
                </div>
                <div className="mb-2 text-[12px] uppercase tracking-[0.12em] text-white/60">
                  {totalLabel}
                </div>
                <div className="mb-4 break-words text-[14px] leading-relaxed text-white/75">
                  {totalText}
                </div>
                <div className="break-words text-[14px] font-medium text-white/90 sm:text-[15px]">
                  {recommendation}
                </div>
              </div>
            </div>
          </div>

          <div className="min-w-0 overflow-hidden rounded-xl border border-white/10 bg-white/4 p-4">
            <SegmentedTabs
              className="mb-3 min-w-0 overflow-hidden"
              size="xs"
              items={[
                { key: "outcome", label: outcomeTabLabel },
                { key: "total", label: totalTabLabel },
              ]}
              value={marketTab}
              onChange={onMarketTabChange}
              listClassName="min-w-0 gap-3 sm:gap-4"
              buttonClassName="min-w-0 max-w-full truncate"
              activeClassName="text-white"
              inactiveClassName="text-white/50"
            />

            {marketTab === "outcome" && (
              <div className="min-w-0 text-[12px] text-white/80">
                {modelVsMarket.map((row, idx) => {
                  const modelPct = row.model != null ? row.model * 100 : null;
                  const bookPct = implied(row.odds);
                  const diff =
                    modelPct != null && bookPct != null
                      ? modelPct - bookPct
                      : null;
                  const diffLabel =
                    diff == null ? "—" : `${diff > 0 ? "+" : ""}${Math.round(diff)}%`;

                  return (
                    <div key={row.label} className={clsx("py-3", idx > 0 && "border-t border-white/10")}>
                      <div className="mb-2 flex min-w-0 items-center justify-between gap-3">
                        <div className="flex min-w-0 items-center gap-3">
                          <span className="truncate text-white/85">{row.label}</span>
                        </div>
                        <span className={clsx("shrink-0 text-[12px] font-semibold tabular-nums", diff != null && diff > 0 ? "text-emerald-300" : "text-white/70")}>
                          {diffLabel}
                        </span>
                      </div>
                      <div className="space-y-2">
                        <div>
                          <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                            <span className="truncate">{modelLabel}</span>
                            <span className="shrink-0 tabular-nums font-semibold">{modelPct != null ? `${Math.round(modelPct)}%` : "—"}</span>
                          </div>
                          <div className="h-[5px] overflow-hidden rounded-full bg-white/6">
                            <div
                              className="h-full rounded-full bg-gradient-to-r from-violet-500/70 to-violet-400/35"
                              style={{ width: `${modelPct ?? 0}%` }}
                            />
                          </div>
                        </div>
                        <div>
                          <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                            <span className="truncate">{marketLabel}</span>
                            <span className="shrink-0 tabular-nums font-semibold">{bookPct != null ? `${Math.round(bookPct)}%` : "—"}</span>
                          </div>
                          <div className="h-[5px] overflow-hidden rounded-full bg-white/6">
                            <div
                              className="h-full rounded-full bg-white/25 shadow-[0_0_10px_rgba(255,255,255,0.08)]"
                              style={{ width: `${bookPct ?? 0}%` }}
                            />
                          </div>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {marketTab === "total" && (
              totalMarketRows?.length ? (
                <div className="min-w-0 text-[12px] text-white/80">
                  {totalMarketRows.map((row, idx) => {
                    const modelPct = row.model != null ? row.model * 100 : null;
                    const bookPct = implied(row.odds);
                    const diff =
                      modelPct != null && bookPct != null
                        ? modelPct - bookPct
                        : null;
                    const diffLabel =
                      diff == null ? "—" : `${diff > 0 ? "+" : ""}${Math.round(diff)}%`;

                    return (
                      <div key={`tot-${row.label}`} className={clsx("py-3", idx > 0 && "border-t border-white/10")}>
                        <div className="mb-2 flex min-w-0 items-center justify-between gap-3">
                          <div className="flex min-w-0 items-center gap-3">
                            <span className="truncate text-white/85">{row.label}</span>
                          </div>
                          <span className={clsx("shrink-0 text-[12px] font-semibold tabular-nums", diff != null && diff > 0 ? "text-emerald-300" : "text-white/70")}>
                            {diffLabel}
                          </span>
                        </div>
                        <div className="space-y-2">
                          <div>
                            <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                              <span className="truncate">{modelLabel}</span>
                              <span className="shrink-0 tabular-nums font-semibold">{modelPct != null ? `${Math.round(modelPct)}%` : "—"}</span>
                            </div>
                            <div className="h-[5px] overflow-hidden rounded-full bg-white/6">
                              <div
                                className="h-full rounded-full bg-gradient-to-r from-violet-500/70 to-violet-400/35"
                                style={{ width: `${modelPct ?? 0}%` }}
                              />
                            </div>
                          </div>
                          <div>
                            <div className="mb-1 flex items-center justify-between gap-3 text-[11px] text-white/70">
                              <span className="truncate">{marketLabel}</span>
                              <span className="shrink-0 tabular-nums font-semibold">{bookPct != null ? `${Math.round(bookPct)}%` : "—"}</span>
                            </div>
                            <div className="h-[5px] overflow-hidden rounded-full bg-white/6">
                              <div
                                className="h-full rounded-full bg-white/25 shadow-[0_0_10px_rgba(255,255,255,0.08)]"
                                style={{ width: `${bookPct ?? 0}%` }}
                              />
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              ) : (
                <div className="text-[12px] text-white/50">{noTotalMarketData}</div>
              )
            )}

            <div className="pt-2 text-[11px] text-white/55">{positiveGapHint}</div>
          </div>
        </>
      )}
    </div>
  );
}
