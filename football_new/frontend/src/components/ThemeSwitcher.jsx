// SAFE version: no global theme switching
// Theme button works visually but does NOT modify <html> or global theme classes

import { useState } from "react";

export default function ThemeSwitcher() {
  // локальное состояние кнопки — изоляция, ничего глобально не меняем
  const [isPink, setIsPink] = useState(false);

  const toggle = () => {
    setIsPink((v) => !v);
  };

  return (
    <button
      onClick={toggle}
      className={[
        "inline-flex items-center gap-1.5 rounded-full border text-xs font-medium transition px-3 py-1.5",
        isPink
          ? "border-rose-300 bg-rose-100/80 text-rose-800 hover:bg-rose-200"
          : "border-white/25 bg-black/40 text-slate-100 hover:bg-black/70",
      ].join(" ")}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-gradient-to-r from-cyan-400 to-indigo-400 shadow-[0_0_8px_rgba(129,230,217,0.9)]" />
      <span>{isPink ? "Pink Theme" : "Premium Theme"}</span>
    </button>
  );
}
