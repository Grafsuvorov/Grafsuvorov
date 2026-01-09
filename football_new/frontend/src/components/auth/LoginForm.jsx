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
          border border-white/10
          bg-slate-950/80
          backdrop-blur-2xl
          shadow-[0_18px_65px_rgba(0,0,0,0.85)]
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
                bg-slate-900/60
                border border-white/10
                px-3 py-2.5
                text-slate-200
                focus:border-pink-400 focus:ring-2 focus:ring-pink-400/40
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
                bg-slate-900/60
                border border-white/10
                px-3 py-2.5
                text-slate-200
                focus:border-pink-400 focus:ring-2 focus:ring-pink-400/40
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
              rounded-xl
              py-3
              text-sm font-semibold
              tracking-wide
              text-white
              bg-gradient-to-r from-pink-500 via-fuchsia-500 to-violet-500
              shadow-[0_12px_30px_rgba(236,72,153,0.45)]
              hover:shadow-[0_18px_40px_rgba(236,72,153,0.6)]
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
              className="text-pink-400 hover:text-pink-300 font-medium"
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
