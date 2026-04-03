export function Card({ children, className = "" }) {
  return (
    <div className={["panel text-white", className].join(" ")}>
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
