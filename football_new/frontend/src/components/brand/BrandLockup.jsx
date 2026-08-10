import clsx from "clsx";

export function BrandMark({ size = "md", className = "" }) {
  const sizeClass =
    size === "sm" ? "h-10 w-10 rounded-2xl" : size === "lg" ? "h-14 w-14 rounded-[20px]" : "h-11 w-11 rounded-2xl";

  return (
    <div
      className={clsx("shrink-0 shadow-[0_14px_34px_rgba(0,0,0,0.34)]", sizeClass, className)}
      aria-hidden="true"
    >
      <svg viewBox="0 0 64 64" fill="none" className="h-full w-full">
        <defs>
          <linearGradient id="brand-mark-bg" x1="8" y1="6" x2="56" y2="58" gradientUnits="userSpaceOnUse">
            <stop stopColor="#21143C" />
            <stop offset="1" stopColor="#0B1220" />
          </linearGradient>
          <linearGradient id="brand-mark-accent" x1="16" y1="14" x2="48" y2="50" gradientUnits="userSpaceOnUse">
            <stop stopColor="#E9D5FF" />
            <stop offset="1" stopColor="#8B5CF6" />
          </linearGradient>
          <linearGradient id="brand-mark-line" x1="16" y1="43" x2="50" y2="28" gradientUnits="userSpaceOnUse">
            <stop stopColor="#67E8F9" />
            <stop offset="1" stopColor="#A5F3FC" />
          </linearGradient>
        </defs>

        <rect x="4" y="4" width="56" height="56" rx="18" fill="url(#brand-mark-bg)" />
        <rect x="4.5" y="4.5" width="55" height="55" rx="17.5" stroke="#FFFFFF" strokeOpacity=".14" />

        <path
          d="M19 14h25c1.66 0 3 1.34 3 3v4.4c0 1.66-1.34 3-3 3H28v5.6h14c1.66 0 3 1.34 3 3v4c0 1.66-1.34 3-3 3H28v6h16c1.66 0 3 1.34 3 3v4.4c0 1.66-1.34 3-3 3H19c-1.66 0-3-1.34-3-3V17c0-1.66 1.34-3 3-3Z"
          fill="url(#brand-mark-accent)"
        />

        <path
          d="M16 44c5-2.3 10.5-2.4 16-.6c4.5 1.5 9 1.2 14.6-3.7"
          stroke="url(#brand-mark-line)"
          strokeWidth="3.2"
          strokeLinecap="round"
        />
        <circle cx="16" cy="44" r="3.1" fill="#67E8F9" />
        <circle cx="32" cy="43.8" r="3.1" fill="#C084FC" />
        <circle cx="46.6" cy="39.4" r="3.1" fill="#67E8F9" />
      </svg>
    </div>
  );
}

export function BrandText({
  compact = false,
  align = "left",
  title = "EdgeScore",
  subtitle = "Football analytics",
  className = "",
}) {
  return (
    <div className={clsx("min-w-0", align === "center" && "text-center", className)}>
      <div className="truncate text-[10px] font-medium uppercase tracking-[0.28em] text-white/42">
        {title}
      </div>
      <div
        className={clsx(
          "truncate font-semibold tracking-[-0.02em] text-white",
          compact ? "pt-1 text-[13px]" : "text-[16px]"
        )}
      >
        {subtitle}
      </div>
    </div>
  );
}

export default function BrandLockup({
  size = "md",
  compact = false,
  align = "left",
  subtitle = "Football analytics",
  className = "",
  textClassName = "",
}) {
  return (
    <div className={clsx("inline-flex items-center gap-3 text-white", className)}>
      <BrandMark size={size} />
      <BrandText
        compact={compact}
        align={align}
        subtitle={subtitle}
        className={textClassName}
      />
    </div>
  );
}
