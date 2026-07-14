import React, { useEffect, useRef, useState } from "react";
import { useAuth } from "@/auth/AuthContext.jsx";
import { useNavigate } from "react-router-dom";
import clsx from "clsx";
import { useLanguage } from "@/context/LanguageContext.jsx";

export default function AuthIndicator({ compact = false }) {
  const { user, isAuthenticated, logout } = useAuth();
  const { t } = useLanguage();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const menuRef = useRef(null);

  const handleLogout = () => {
    logout();
    navigate("/");
  };
  useEffect(() => {
    if (!open) return;
    const onClick = (e) => {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setOpen(false);
      }
    };
    window.addEventListener("click", onClick);
    return () => window.removeEventListener("click", onClick);
  }, [open]);

  /* ============ NOT AUTHENTICATED ============ */
  if (!isAuthenticated) {
    return (
      <div className="flex items-center rounded-full border border-white/10 bg-slate-950/60 p-1 shadow-[0_10px_24px_rgba(0,0,0,0.35)]">
        <button
          onClick={() => navigate("/login")}
          className={clsx(
            "rounded-full px-4 py-2 text-sm font-medium transition",
            compact && "px-3 py-1.5 text-[12px]",
            "text-slate-200/90 hover:text-white",
            "hover:bg-white/5"
          )}
        >
          {t("signIn")}
        </button>
        <button
          onClick={() => navigate("/register")}
          className={clsx(
            "rounded-full px-5 py-2 text-sm font-semibold transition",
            compact && "px-3.5 py-1.5 text-[12px]",
            "text-white",
            "bg-gradient-to-r from-[#7C5CFF] via-[#9B78FF] to-[#B77CFF]",
            "shadow-[0_0_20px_rgba(124,92,255,0.35)]",
            "hover:shadow-[0_0_28px_rgba(124,92,255,0.5)]"
          )}
        >
          {t("signUp")}
        </button>
      </div>
    );
  }

  /* ============ AUTHENTICATED ============ */
  return (
    <div className="relative flex items-center gap-3" ref={menuRef}>
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-2 group"
      >
        <div className="
          h-9 w-9 rounded-full
          bg-gradient-to-br from-[#7C5CFF]/25 to-[#B77CFF]/25
          border border-white/20
          shadow-[0_4px_14px_rgba(0,0,0,0.6)]
          flex items-center justify-center
          text-white font-semibold
        ">
          {user?.username?.charAt(0)?.toUpperCase() || "U"}
        </div>

        <span className={clsx("hidden text-slate-200/90 group-hover:text-white transition", !compact && "md:block")}>
          {user?.username}
        </span>
      </button>

      {!compact && (
        <button
          onClick={() => navigate("/profile")}
          className="text-sm font-medium text-slate-300 hover:text-white transition"
        >
          {t("profile")}
        </button>
      )}

      {open && (
        <div className={clsx("absolute right-0 mt-2 w-40 rounded-2xl border border-white/10 bg-slate-950/95 p-2 shadow-[0_18px_45px_rgba(0,0,0,0.55)]", compact ? "top-full" : "")}>
          <button
            onClick={() => {
              setOpen(false);
              navigate("/profile");
            }}
            className="w-full rounded-xl px-3 py-2 text-left text-sm text-slate-200 hover:bg-white/5"
          >
            {t("profile")}
          </button>
          <button
            onClick={() => {
              setOpen(false);
              handleLogout();
            }}
            className="mt-1 w-full rounded-xl px-3 py-2 text-left text-sm text-rose-300 hover:bg-rose-500/10"
          >
            {t("logOut")}
          </button>
        </div>
      )}
    </div>
  );
}
