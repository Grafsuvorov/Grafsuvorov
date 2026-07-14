import React, { useState } from 'react';
import { useAuth } from '@/auth/AuthContext.jsx';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from "@/context/LanguageContext.jsx";

export default function RegisterForm() {
  const [formData, setFormData] = useState({
    email: '',
    username: '',
    password: '',
    confirmPassword: ''
  });
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const { register } = useAuth();
  const { t } = useLanguage();
  const navigate = useNavigate();

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (formData.password !== formData.confirmPassword) {
      setError(t("passwordsDoNotMatch"));
      return;
    }

    if (formData.password.length < 8) {
      setError(t("passwordTooShort"));
      return;
    }

    setIsLoading(true);

    try {
      await register(formData.email, formData.username, formData.password);
      setIsSuccess(true);
      setTimeout(() => {
        navigate('/login');
      }, 3000);
    } catch (err) {
      setError(err.message || t("registrationFailed"));
    } finally {
      setIsLoading(false);
    }
  };

  if (isSuccess) {
    return (
      <div className="surface-hero max-w-md mx-auto p-8 text-slate-100">
        <div className="text-center">
          <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-emerald-500/20 mb-4 border border-emerald-400/40">
            <svg className="h-6 w-6 text-emerald-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">{t("registrationSuccess")}</h2>
          <p className="text-slate-300 mb-4">
            {t("registrationSuccessBody")}
          </p>
          <p className="text-sm text-slate-400">
            {t("redirectingToLogin")}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="surface-hero max-w-md mx-auto p-8 text-slate-100">
      <div className="text-center mb-8">
        <h2 className="text-2xl font-bold text-white">{t("registerTitle")}</h2>
        <p className="text-sm text-slate-400 mt-1">EdgeScore • {t("footballAnalytics")}</p>
        <p className="mt-3 text-sm text-slate-400">{t("registerLead")}</p>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-rose-500/15 border border-rose-400/40 text-rose-100 rounded-xl">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-5">
        <div>
          <label htmlFor="email" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            {t("email")}
          </label>
          <input
            type="email"
            id="email"
            name="email"
            value={formData.email}
            onChange={handleChange}
            required
            className="w-full rounded-xl border border-glass bg-surface-1/70 px-3 py-2.5 text-slate-200 placeholder:text-slate-500 outline-none focus:border-white/20 focus:ring-2 focus:ring-violet-400/20"
            placeholder={t("emailPlaceholder")}
          />
        </div>

        <div>
          <label htmlFor="username" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            {t("username")}
          </label>
          <input
            type="text"
            id="username"
            name="username"
            value={formData.username}
            onChange={handleChange}
            required
            minLength={3}
            maxLength={100}
            className="w-full rounded-xl border border-glass bg-surface-1/70 px-3 py-2.5 text-slate-200 placeholder:text-slate-500 outline-none focus:border-white/20 focus:ring-2 focus:ring-violet-400/20"
            placeholder={t("usernamePlaceholder")}
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            {t("password")}
          </label>
          <input
            type="password"
            id="password"
            name="password"
            value={formData.password}
            onChange={handleChange}
            required
            minLength={8}
            className="w-full rounded-xl border border-glass bg-surface-1/70 px-3 py-2.5 text-slate-200 placeholder:text-slate-500 outline-none focus:border-white/20 focus:ring-2 focus:ring-violet-400/20"
            placeholder={t("passwordMinPlaceholder")}
          />
        </div>

        <div>
          <label htmlFor="confirmPassword" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            {t("confirmPassword")}
          </label>
          <input
            type="password"
            id="confirmPassword"
            name="confirmPassword"
            value={formData.confirmPassword}
            onChange={handleChange}
            required
            className="w-full rounded-xl border border-glass bg-surface-1/70 px-3 py-2.5 text-slate-200 placeholder:text-slate-500 outline-none focus:border-white/20 focus:ring-2 focus:ring-violet-400/20"
            placeholder={t("confirmPasswordPlaceholder")}
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="w-full rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(168,85,247,0.95),rgba(139,92,246,0.92),rgba(99,102,241,0.9))] px-4 py-3 text-sm font-semibold text-white shadow-[0_16px_35px_rgba(139,92,246,0.34),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:shadow-[0_20px_45px_rgba(139,92,246,0.42),inset_0_1px_0_rgba(255,255,255,0.22)] disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isLoading ? t("registerSubmitting") : t("registerSubmit")}
        </button>
      </form>

      <div className="mt-6 text-center">
        <p className="text-sm text-slate-400">
          {t("haveAccount")}{' '}
          <button
            onClick={() => navigate('/login')}
            className="font-medium text-violet-300 transition hover:text-violet-200"
          >
            {t("loginSubmit")}
          </button>
        </p>
      </div>
    </div>
  );
}
