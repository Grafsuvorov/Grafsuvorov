import clsx from "clsx";

export function BrandMark({ size = "md", className = "" }) {
  const sizeClass =
    size === "sm" ? "h-10 w-10 rounded-2xl" : size === "lg" ? "h-14 w-14 rounded-[20px]" : "h-11 w-11 rounded-2xl";
  const barWidth = size === "lg" ? "w-2" : "w-1.5";

  return (
    <div
      className={clsx(
        "flex items-center justify-center border border-white/12 bg-[linear-gradient(180deg,rgba(255,255,255,0.06)_0%,rgba(255,255,255,0.02)_100%)] shadow-[0_12px_34px_rgba(0,0,0,0.32)]",
        sizeClass,
        className
      )}
      aria-hidden="true"
    >
      <div className="flex items-end gap-1">
        <span className={clsx("rounded-full bg-white/72", barWidth, size === "lg" ? "h-4" : "h-3")} />
        <span className={clsx("rounded-full bg-violet-300/90", barWidth, size === "lg" ? "h-6" : "h-5")} />
        <span className={clsx("rounded-full bg-white/48", barWidth, size === "lg" ? "h-5" : "h-4")} />
      </div>
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
