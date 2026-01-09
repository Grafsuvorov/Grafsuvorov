import React from "react";
import { useAuth } from "@/auth/AuthContext.jsx";
import { useNavigate } from "react-router-dom";
import clsx from "clsx";

export default function AuthIndicator() {
  const { user, isAuthenticated, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate("/");
  };

  /* ============ NOT AUTHENTICATED ============ */
  if (!isAuthenticated) {
    return (
      <div className="flex items-center gap-3">

        {/* ВОЙТИ */}
        <button
          onClick={() => navigate("/login")}
          className={clsx(
            "px-4 py-1.5 rounded-full text-sm font-medium transition",
            "text-slate-200/90 hover:text-white",
            "border border-white/15 bg-slate-950/60",
            "shadow-[0_6px_16px_rgba(0,0,0,0.45)]",
            "hover:border-pink-300/70 hover:shadow-[0_0_25px_rgba(236,72,153,0.45)]"
          )}
        >
          Войти
        </button>

        {/* РЕГИСТРАЦИЯ */}
        <button
          onClick={() => navigate("/register")}
          className={clsx(
            "px-5 py-1.5 rounded-full text-sm font-semibold transition",
            "text-white",
            "bg-gradient-to-r from-pink-500 via-fuchsia-500 to-violet-500",
            "shadow-[0_10px_30px_rgba(236,72,153,0.45)]",
            "hover:shadow-[0_14px_40px_rgba(236,72,153,0.65)]"
          )}
        >
          Регистрация
        </button>

      </div>
    );
  }

  /* ============ AUTHENTICATED ============ */
  return (
    <div className="flex items-center gap-4">

      {/* АВАТАР */}
      <button
        onClick={() => navigate("/profile")}
        className="flex items-center gap-2 group"
      >
        <div className="
          h-9 w-9 rounded-full
          bg-gradient-to-br from-pink-500/25 to-violet-500/25
          border border-white/20
          shadow-[0_4px_14px_rgba(0,0,0,0.6)]
          flex items-center justify-center
          text-white font-semibold
        ">
          {user?.username?.charAt(0)?.toUpperCase() || "U"}
        </div>

        <span className="hidden md:block text-slate-200/90 group-hover:text-white transition">
          {user?.username}
        </span>
      </button>

      {/* КНОПКА: ПРОФИЛЬ */}
      <button
        onClick={() => navigate("/profile")}
        className="
          text-sm font-medium
          text-slate-300 hover:text-white
          transition
        "
      >
        Профиль
      </button>

      {/* КНОПКА: ВЫЙТИ */}
      <button
        onClick={handleLogout}
        className="
          text-sm font-medium
          text-slate-400 hover:text-pink-400
          transition
        "
      >
        Выйти
      </button>

    </div>
  );
}
