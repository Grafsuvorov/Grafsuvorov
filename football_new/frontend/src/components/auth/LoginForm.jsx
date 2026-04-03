import React, { useState } from "react";
import { useAuth } from "@/auth/AuthContext.jsx";
import { useNavigate } from "react-router-dom";
import { motion } from "framer-motion";

export default function LoginForm() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setIsLoading(true);

    try {
      await login(email, password);
      navigate("/profile");
    } catch (err) {
      setError(err.message || "Ошибка входа");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-[80vh] flex items-center justify-center px-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.94 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ duration: 0.25 }}
        className="
          w-full max-w-md
          rounded-3xl
          border border-glass
          bg-surface-2/75
          backdrop-blur-2xl
          shadow-[0_22px_70px_rgba(0,0,0,0.6),inset_0_1px_0_rgba(255,255,255,0.08)]
          p-8
        "
      >
        {/* HEADER */}
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold text-white tracking-tight">
            Вход в аккаунт
          </h2>
          <p className="text-sm text-slate-400 mt-1">
            EdgeScore • Football Analytics
          </p>
        </div>

        {error && (
          <div className="mb-4 rounded-xl border border-red-400/40 bg-red-500/10 text-red-300 px-4 py-3 text-sm">
            {error}
          </div>
        )}

        {/* FORM */}
        <form onSubmit={handleSubmit} className="space-y-5">

          {/* EMAIL */}
          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5 uppercase tracking-wider">
              Email
            </label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="
                w-full rounded-xl
                bg-surface-1/70
                border border-glass
                px-3 py-2.5
                text-slate-200
                focus:border-white/20 focus:ring-2 focus:ring-violet-400/20
                outline-none
              "
              placeholder="Введите email"
            />
          </div>

          {/* PASSWORD */}
          <div>
            <label className="block text-xs font-medium text-slate-300 mb-1.5 uppercase tracking-wider">
              Пароль
            </label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="
                w-full rounded-xl
                bg-surface-1/70
                border border-glass
                px-3 py-2.5
                text-slate-200
                focus:border-white/20 focus:ring-2 focus:ring-violet-400/20
                outline-none
              "
              placeholder="Введите пароль"
            />
          </div>

          {/* SUBMIT */}
          <button
            type="submit"
            disabled={isLoading}
            className="
              w-full mt-2
              rounded-2xl
              py-3
              text-sm font-semibold
              tracking-wide
              text-white
              border border-violet-400/35
              bg-[linear-gradient(135deg,rgba(168,85,247,0.95),rgba(139,92,246,0.92),rgba(99,102,241,0.9))]
              shadow-[0_16px_35px_rgba(139,92,246,0.34),inset_0_1px_0_rgba(255,255,255,0.18)]
              hover:shadow-[0_20px_45px_rgba(139,92,246,0.42),inset_0_1px_0_rgba(255,255,255,0.22)]
              transition
              disabled:opacity-50 disabled:cursor-not-allowed
            "
          >
            {isLoading ? "Вход..." : "Войти"}
          </button>
        </form>

        {/* REGISTER LINK */}
        <div className="mt-6 text-center">
          <p className="text-sm text-slate-400">
            Нет аккаунта?{" "}
            <button
              className="font-medium text-violet-300 transition hover:text-violet-200"
              onClick={() => navigate("/register")}
            >
              Регистрация
            </button>
          </p>
        </div>
      </motion.div>
    </div>
  );
}
