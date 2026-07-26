import clsx from "clsx";

export default function MatchRoundSection({
  group,
  index,
  language,
  humanRoundLabel,
  matchesCountLabel,
  renderMatchCard,
}) {
  return (
    <section className={clsx("glass-card p-3.5 sm:p-5", index > 0 && "mt-2")}>
      <div
        className={clsx(
          "mb-3 flex flex-wrap items-center justify-between gap-2 sm:mb-4 sm:gap-3",
          index > 0 && "border-t border-white/6 pt-4 sm:pt-5"
        )}
      >
        <div className="text-[12px] uppercase tracking-[0.14em] text-white/60 sm:text-[13px] sm:tracking-[0.15em]">
          {humanRoundLabel(group.label, language)}
        </div>
        <span className="rounded-full border border-white/8 bg-white/[0.04] px-2.5 py-1 text-[10px] text-white/60 sm:px-3 sm:text-[11px]">
          {group.items.length} {matchesCountLabel}
        </span>
      </div>

      <div className="bg-transparent space-y-3">
        {group.items.map(renderMatchCard)}
      </div>
    </section>
  );
}
