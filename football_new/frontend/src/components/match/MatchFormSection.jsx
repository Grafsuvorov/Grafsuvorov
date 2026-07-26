import MatchInsightsPanelFull from "@/components/MatchInsightsPanelFull";

export default function MatchFormSection({
  wrapClassName,
  panelClassName,
  loading,
  loadingLabel,
  pack,
  homeTeam,
  awayTeam,
  onOpenMatchModal,
}) {
  return (
    <div className={wrapClassName}>
      {loading && (
        <div className={`${panelClassName} text-sm text-slate-400`}>{loadingLabel}</div>
      )}
      {!loading && (
        <div className={panelClassName}>
          <MatchInsightsPanelFull
            pack={pack}
            home={homeTeam}
            away={awayTeam}
            variant="flat"
            hideAvgs
            onOpenMatchModal={onOpenMatchModal}
          />
        </div>
      )}
    </div>
  );
}
