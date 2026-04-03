import React from 'react';
import { Link } from "react-router-dom";
import RegisterForm from '@/components/auth/RegisterForm';

export default function RegisterPage() {
  return (
    <div className="min-h-screen bg-[#0b1118] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md space-y-5">
        <div className="flex items-center justify-between rounded-2xl border border-glass bg-surface-2/70 px-4 py-3 shadow-[0_10px_28px_rgba(0,0,0,0.28)]">
          <div className="text-sm font-medium text-slate-200">Регистрация</div>
          <Link to="/" className="rounded-full border border-glass bg-surface-2/80 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:text-white hover:bg-surface-2">
            На главную
          </Link>
        </div>
        <RegisterForm />
      </div>
    </div>
  );
}
