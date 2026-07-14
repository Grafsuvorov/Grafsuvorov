import clsx from "clsx";
import { useLanguage } from "@/context/LanguageContext.jsx";

export default function LanguageSwitcher({ compact = false }) {
  const { lang, setLang } = useLanguage();

  return (
    <div
      className={clsx(
        "inline-flex items-center rounded-full border border-white/10 bg-slate-950/60 p-1 shadow-[0_10px_24px_rgba(0,0,0,0.35)]",
        compact && "scale-95 shadow-[0_8px_18px_rgba(0,0,0,0.28)]"
      )}
    >
      {[
        ["en", "EN"],
        ["ru", "RU"],
      ].map(([value, label]) => {
        const active = lang === value;
        return (
          <button
            key={value}
            type="button"
            onClick={() => setLang(value)}
            className={clsx(
              "rounded-full px-3 py-1.5 text-xs font-semibold transition",
              compact && "px-2.5 py-1 text-[11px]",
              active
                ? "bg-white text-slate-950"
                : "text-slate-300 hover:bg-white/5 hover:text-white"
            )}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
