import React, { useState } from 'react';
import { useAuth } from '@/auth/AuthContext.jsx';
import { useNavigate } from 'react-router-dom';

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
      setError('Пароли не совпадают');
      return;
    }

    if (formData.password.length < 8) {
      setError('Пароль должен содержать минимум 8 символов');
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
      setError(err.message || 'Ошибка регистрации');
    } finally {
      setIsLoading(false);
    }
  };

  if (isSuccess) {
    return (
      <div className="max-w-md mx-auto rounded-3xl border border-glass bg-surface-2/75 backdrop-blur-2xl shadow-[0_22px_70px_rgba(0,0,0,0.6),inset_0_1px_0_rgba(255,255,255,0.08)] p-8 text-slate-100">
        <div className="text-center">
          <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-emerald-500/20 mb-4 border border-emerald-400/40">
            <svg className="h-6 w-6 text-emerald-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Регистрация успешна!</h2>
          <p className="text-slate-300 mb-4">
            Проверьте ваш email для подтверждения аккаунта. После подтверждения вы сможете войти в систему.
          </p>
          <p className="text-sm text-slate-400">
            Перенаправление на страницу входа через несколько секунд...
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-md mx-auto rounded-3xl border border-glass bg-surface-2/75 shadow-[0_22px_70px_rgba(0,0,0,0.6),inset_0_1px_0_rgba(255,255,255,0.08)] backdrop-blur-2xl p-8 text-slate-100">
      <div className="text-center mb-8">
        <h2 className="text-2xl font-bold text-white">Регистрация</h2>
        <p className="text-sm text-slate-400 mt-1">EdgeScore • Football Analytics</p>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-rose-500/15 border border-rose-400/40 text-rose-100 rounded-xl">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-5">
        <div>
          <label htmlFor="email" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            Email
          </label>
          <input
            type="email"
            id="email"
            name="email"
            value={formData.email}
            onChange={handleChange}
            required
            className="w-full rounded-xl border border-glass bg-surface-1/70 px-3 py-2.5 text-slate-200 placeholder:text-slate-500 outline-none focus:border-white/20 focus:ring-2 focus:ring-violet-400/20"
            placeholder="Введите ваш email"
          />
        </div>

        <div>
          <label htmlFor="username" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            Имя пользователя
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
            placeholder="Введите имя пользователя"
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            Пароль
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
            placeholder="Минимум 8 символов"
          />
        </div>

        <div>
          <label htmlFor="confirmPassword" className="block text-xs font-medium uppercase tracking-wider text-slate-300 mb-1.5">
            Подтвердите пароль
          </label>
          <input
            type="password"
            id="confirmPassword"
            name="confirmPassword"
            value={formData.confirmPassword}
            onChange={handleChange}
            required
            className="w-full rounded-xl border border-glass bg-surface-1/70 px-3 py-2.5 text-slate-200 placeholder:text-slate-500 outline-none focus:border-white/20 focus:ring-2 focus:ring-violet-400/20"
            placeholder="Повторите пароль"
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          className="w-full rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(168,85,247,0.95),rgba(139,92,246,0.92),rgba(99,102,241,0.9))] px-4 py-3 text-sm font-semibold text-white shadow-[0_16px_35px_rgba(139,92,246,0.34),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:shadow-[0_20px_45px_rgba(139,92,246,0.42),inset_0_1px_0_rgba(255,255,255,0.22)] disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isLoading ? 'Регистрация...' : 'Зарегистрироваться'}
        </button>
      </form>

      <div className="mt-6 text-center">
        <p className="text-sm text-slate-400">
          Уже есть аккаунт?{' '}
          <button
            onClick={() => navigate('/login')}
            className="font-medium text-violet-300 transition hover:text-violet-200"
          >
            Войти
          </button>
        </p>
      </div>
    </div>
  );
}
