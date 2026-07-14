import SegmentedTabs from "@/components/ui/SegmentedTabs";
import { useLanguage } from "@/context/LanguageContext.jsx";

const fmtNum = (v, d = 0) => (v == null ? "—" : Number(v).toFixed(d));
const toNumSafe = (v) => {
  if (v == null) return null;
  const s = String(v).replace("%", "").replace(",", ".").trim();
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
};

export const VenueFilterTabs = ({ value, onChange }) => {
  const { language } = useLanguage();
  const isRu = language === "ru";
  return (
    <SegmentedTabs
      size="sm"
      items={[
        { key: "all", label: isRu ? "Общая" : "Overall" },
        { key: "home", label: isRu ? "Дома" : "Home" },
        { key: "away", label: isRu ? "В гостях" : "Away" },
      ]}
      value={value}
      onChange={onChange}
      listClassName="gap-6"
      buttonClassName="tracking-wide"
      activeClassName="text-white"
    />
  );
};

export const AvgCompareRow = ({ label, left, right, isPercent = false, decimals = 1 }) => {
  const l = toNumSafe(left);
  const r = toNumSafe(right);
  if (l == null && r == null) return null;
  const total = Math.max(Math.abs(l || 0) + Math.abs(r || 0), 1);
  const minWidth = 8;
  const lw = l != null ? Math.max((Math.abs(l) / total) * 100, minWidth) : 0;
  const rw = r != null ? Math.max((Math.abs(r) / total) * 100, minWidth) : 0;
  const fmt = (v) =>
    v == null ? "—" : isPercent ? `${fmtNum(v, 0)}%` : fmtNum(v, decimals);

  return (
    <div className="flex items-center justify-between gap-3">
      <div className="w-[72px] text-[12px] text-white/85 tabular-nums text-left">{fmt(l)}</div>
      <div className="flex-1">
        <div className="text-[11px] text-white/45 text-center mb-1">{label}</div>
        <div className="relative h-[6px] rounded-full bg-white/10 overflow-hidden w-[85%] mx-auto">
          <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/12" />
          <div
            className="absolute right-1/2 top-0 h-full rounded-full bg-gradient-to-r from-[#8B5CF6] to-[#7C3AED] shadow-[0_0_8px_rgba(139,92,246,0.25)]"
            style={{ width: `${lw}%` }}
          />
          <div
            className="absolute left-1/2 top-0 h-full rounded-full bg-gradient-to-l from-sky-400/80 to-teal-400/70"
            style={{ width: `${rw}%` }}
          />
        </div>
      </div>
      <div className="w-[72px] text-[12px] text-white/85 tabular-nums text-right">{fmt(r)}</div>
    </div>
  );
};

export const CompactMetricRow = ({
  label,
  left,
  right,
  isPercent = false,
  accentSide = "left",
}) => {
  const l = toNumSafe(left);
  const r = toNumSafe(right);
  if (l == null && r == null) return null;
  const max = Math.max(Math.abs(l || 0), Math.abs(r || 0), 1);
  const minWidth = 12;
  const lw = l != null ? Math.max((Math.abs(l) / max) * 100, minWidth) : 0;
  const rw = r != null ? Math.max((Math.abs(r) / max) * 100, minWidth) : 0;
  const fmt = (v) =>
    v == null ? "—" : isPercent ? `${fmtNum(v, 0)}%` : fmtNum(v, 2);

  return (
    <div className="flex items-center justify-between gap-3">
      <div className="w-[80px] text-[13px] text-white/90 tabular-nums text-left">{fmt(l)}</div>
      <div className="flex-1">
        <div className="text-[11px] text-white/50 text-center mb-1">{label}</div>
        <div className="relative h-[4px] rounded-full bg-white/8 overflow-hidden w-[85%] mx-auto">
          <div className="absolute inset-y-0 left-1/2 w-px -translate-x-1/2 bg-white/15" />
          <div
            className="absolute right-1/2 top-0 h-full rounded-full transition-all duration-300 ease-out bg-gradient-to-r from-[#8B5CF6] to-[#7C3AED] shadow-[0_0_8px_rgba(139,92,246,0.35)]"
            style={{ width: `${lw}%` }}
          />
          <div
            className="absolute left-1/2 top-0 h-full rounded-full transition-all duration-300 ease-out bg-gradient-to-l from-sky-400/80 to-teal-400/70 shadow-[0_0_8px_rgba(56,189,248,0.22)]"
            style={{ width: `${rw}%` }}
          />
        </div>
      </div>
      <div className="w-[80px] text-[13px] text-white/90 tabular-nums text-right">{fmt(r)}</div>
    </div>
  );
};

export const Segmented = ({ value, onChange }) => {
  const { language } = useLanguage();
  const isRu = language === "ru";
  return (
    <SegmentedTabs
      className="mt-5"
      size="md"
      items={[
        { key: "stats", label: isRu ? "Статистика" : "Stats" },
        { key: "results", label: isRu ? "Результаты" : "Results" },
        { key: "schedule", label: isRu ? "Календарь" : "Schedule" },
      ]}
      value={value}
      onChange={onChange}
      listClassName="gap-x-4 gap-y-2 sm:gap-5"
      buttonClassName="text-[13px] sm:text-base"
    />
  );
};

const IconWrap = ({ children }) => (
  <span className="h-7 w-7 rounded-xl grid place-items-center bg-white/5 text-[#8B5CF6] border border-white/10">
    {children}
  </span>
);

export const KpiCard = ({ title, value, sub, icon, tooltip }) => (
  <div className="glass-card min-h-[144px] p-4">
    <div className="flex items-center gap-2 text-[11px] uppercase tracking-wide text-white/60">
      {icon ? <IconWrap>{icon}</IconWrap> : null}
      <span title={tooltip || title}>{title}</span>
    </div>
    <div className="mt-2 break-words text-[22px] font-semibold tracking-tight text-white transition-all duration-300 sm:text-[27px]">
      {value ?? "—"}
    </div>
    {sub ? (
      <div className="text-[11px] text-white/50 mt-1">{sub}</div>
    ) : null}
  </div>
);

export const PeriodSwitch = ({ value, onChange }) => {
  const { language } = useLanguage();
  const isRu = language === "ru";
  return (
    <div
      className="flex flex-wrap items-center gap-x-3 gap-y-2 text-[12px] text-white/60 sm:gap-6"
      title={isRu ? "5 / 10 / 15 — последние сыгранные матчи команды" : "5 / 10 / 15 — latest played team matches"}
    >
      {[
        { id: "season", label: isRu ? "Сезон" : "Season" },
        { id: "5", label: "5" },
        { id: "10", label: "10" },
        { id: "15", label: "15" },
      ].map((opt) => {
        const active = value === opt.id;
        return (
          <button
            key={opt.id}
            onClick={() => onChange(opt.id)}
            className={`rounded-full px-3 py-1.5 text-xs font-semibold tracking-wide transition-colors sm:text-sm ${
              active
                ? "bg-white/10 text-white shadow-[0_0_10px_rgba(139,92,246,0.18)]"
                : "text-white/60 hover:text-white/85"
            }`}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
};

export const RadarChart = ({ data }) => {
  const { language } = useLanguage();
  const isRu = language === "ru";
  if (!data) return null;
  const metrics = [
    { key: "xg", label: "xG", max: 3 },
    { key: "conceded", label: "xGA", max: 3 },
    { key: "shots", label: isRu ? "Удары" : "Shots", max: 20 },
    { key: "possession", label: isRu ? "Влад." : "Poss", max: 70, min: 30 },
    { key: "tempo", label: isRu ? "Темп" : "Tempo", max: 30 },
  ];
  const cx = 70;
  const cy = 70;
  const r = 52;
  const step = (Math.PI * 2) / metrics.length;
  const scale = (v, min, max) => {
    if (v == null) return 0.1;
    const lo = min ?? 0;
    const hi = max ?? 1;
    const t = (v - lo) / (hi - lo || 1);
    return Math.max(0.12, Math.min(1, t));
  };
  const points = metrics
    .map((m, i) => {
      const ang = -Math.PI / 2 + i * step;
      const val = scale(data[m.key], m.min, m.max);
      const x = cx + Math.cos(ang) * r * val;
      const y = cy + Math.sin(ang) * r * val;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  const rings = [0.35, 0.65, 1].map((k) => (
    <circle
      key={k}
      cx={cx}
      cy={cy}
      r={r * k}
      fill="none"
      stroke="rgba(255,255,255,0.08)"
      strokeWidth="1"
    />
  ));

  return (
    <svg
      viewBox="0 0 140 140"
      className="h-[120px] w-[120px] transition-opacity duration-300"
      title={isRu ? "Средние значения за выбранный период" : "Average values for the selected period"}
    >
      {rings}
      {metrics.map((m, i) => {
        const ang = -Math.PI / 2 + i * step;
        const x = cx + Math.cos(ang) * r;
        const y = cy + Math.sin(ang) * r;
        return (
          <g key={m.key}>
            <line x1={cx} y1={cy} x2={x} y2={y} stroke="rgba(255,255,255,0.08)" strokeWidth="1" />
            <text
              x={cx + Math.cos(ang) * (r + 14)}
              y={cy + Math.sin(ang) * (r + 14)}
              textAnchor="middle"
              dominantBaseline="central"
              fontSize="9"
              fill="rgba(255,255,255,0.5)"
            >
              {m.label}
            </text>
          </g>
        );
      })}
      <polygon
        points={points}
        fill="rgba(139,92,246,0.22)"
        stroke="rgba(139,92,246,0.9)"
        strokeWidth="2"
      />
    </svg>
  );
};
