import LineupsTab from "@/components/LineupsTab";

export default function MatchLineupsSection({
  wrapClassName,
  panelClassName,
  error,
  loading,
  loadingLabel,
  lineupsData,
  match,
  emptyLabel,
  onPlayerOpen,
}) {
  return (
    <div className={wrapClassName}>
      {error ? (
        <div className={`${panelClassName} text-sm text-white/60`}>{error}</div>
      ) : loading ? (
        <div className={`${panelClassName} text-sm text-white/60`}>{loadingLabel}</div>
      ) : lineupsData ? (
        <div className="w-full">
          <LineupsTab
            data={lineupsData}
            loading={loading}
            match={match}
            onPlayer={onPlayerOpen}
          />
        </div>
      ) : (
        <div className={`${panelClassName} text-sm text-white/60`}>{emptyLabel}</div>
      )}
    </div>
  );
}
