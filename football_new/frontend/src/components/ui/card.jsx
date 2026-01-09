// src/components/ui/card.jsx

export function Card({ children, className = "" }) {
  return (
    <div
      className={[
        "border border-white/10",
        "rounded-3xl",
        "bg-slate-950/70",          // тёмный полупрозрачный фон
        "backdrop-blur-xl",
        "shadow-[0_18px_55px_rgba(0,0,0,0.75)]",
        "text-white",
        className
      ].join(" ")}
    >
      {children}
    </div>
  );
}

export function CardContent({ children, className = "" }) {
  return (
    <div className={["p-4 sm:p-5", className].join(" ")}>
      {children}
    </div>
  );
}
