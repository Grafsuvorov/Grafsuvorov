// src/components/LeftRail.jsx
import { useLocation, useNavigate } from "react-router-dom";
import clsx from "clsx";
import { useLanguage } from "@/context/LanguageContext.jsx";

export default function LeftRail() {
  const nav = useNavigate();
  const { pathname } = useLocation();
  const { t, language } = useLanguage();
  const NAV = [
    { to: "/", label: language === "ru" ? "Домой" : "Home", icon: "🏠" },
    { to: "/matches-v3", label: t("results"), icon: "📊" },
    { to: "/schedule", label: t("calendar"), icon: "🗓️" },
    { to: "/table", label: t("table"), icon: "🏆" },
    { to: "/best-picks", label: t("picks"), icon: "✨" },
    { to: "/leagues", label: language === "ru" ? "Лиги" : "Leagues", icon: "🧭" },
  ];

  return (
    <nav className="w-[74px] rounded-3xl border border-white/15 bg-slate-950/70 p-3 shadow-[0_18px_60px_rgba(15,23,42,0.95)] backdrop-blur-2xl">
      <ul className="flex flex-col items-center gap-3">
        {NAV.map((i) => {
          const active =
            i.to === "/" ? pathname === "/" : pathname.startsWith(i.to);

          return (
            <li key={i.to}>
              <button
                onClick={() => nav(i.to)}
                title={i.label}
                className={clsx(
                  "group relative grid h-11 w-11 place-items-center rounded-2xl text-sm font-medium transition",
                  active
                    ? "bg-gradient-to-br from-cyan-400 to-violet-500 text-slate-950 shadow-[0_14px_38px_rgba(8,47,73,0.9)]"
                    : "bg-white/5 text-slate-200/80 hover:bg-white/10 hover:text-white border border-white/10"
                )}
              >
                <span>{i.icon}</span>

                {/* Tooltip */}
                <span className="absolute left-14 top-1/2 -translate-y-1/2 whitespace-nowrap rounded-xl bg-slate-950/95 px-2 py-1 text-xs text-slate-50 opacity-0 pointer-events-none group-hover:opacity-100 transition shadow-[0_10px_25px_rgba(15,23,42,0.9)]">
                  {i.label}
                </span>
              </button>
            </li>
          );
        })}

        <li className="mt-4 text-center">
          <div className="text-[10px] text-slate-300/70">{language === "ru" ? "лайв" : "live"}</div>
          <div className="mx-auto mt-1 h-1.5 w-1.5 rounded-full bg-rose-400 shadow-[0_0_12px_rgba(248,113,113,0.9)] animate-pulse" />
        </li>
      </ul>
    </nav>
  );
}
