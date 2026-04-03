import clsx from "clsx";

const DEFAULT_ITEMS = [];

export default function SegmentedTabs({
  items = DEFAULT_ITEMS,
  value,
  onChange,
  className,
  listClassName,
  buttonClassName,
  size = "sm",
  activeClassName,
  inactiveClassName,
  underline = true,
  onItemClick,
}) {
  const sizeClass =
    size === "xs"
      ? "pb-1 text-xs"
      : size === "md"
      ? "pb-2 text-sm sm:text-base"
      : "pb-1 text-sm";

  return (
    <div className={className}>
      <div className={clsx("flex flex-wrap gap-5", listClassName)}>
        {items.map((item) => {
          const isActive = value === item.key;
          return (
            <button
              key={item.key}
              type="button"
              onClick={() => {
                onChange?.(item.key);
                onItemClick?.(item.key, item);
              }}
              className={clsx(
                "relative font-semibold transition-colors",
                sizeClass,
                isActive
                  ? "text-[#b18cff] [text-shadow:0_0_12px_rgba(168,85,247,0.4)]"
                  : "text-white/60 hover:text-white/85",
                activeClassName && isActive && activeClassName,
                inactiveClassName && !isActive && inactiveClassName,
                buttonClassName
              )}
            >
              {item.label}
              {underline && isActive ? (
                <span className="pointer-events-none absolute inset-x-0 -bottom-[2px] h-[2px] rounded-full bg-[linear-gradient(90deg,transparent,rgba(168,85,247,0.8),transparent)] shadow-[0_0_10px_rgba(168,85,247,0.35)]" />
              ) : null}
            </button>
          );
        })}
      </div>
    </div>
  );
}
