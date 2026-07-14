import React from 'react';
import { Link } from "react-router-dom";
import RegisterForm from '@/components/auth/RegisterForm';
import { useLanguage } from "@/context/LanguageContext.jsx";

export default function RegisterPage() {
  const { t } = useLanguage();

  return (
    <div className="min-h-screen bg-[#0b1118] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
      <div className="w-full max-w-md space-y-5">
        <div className="surface-toolbar flex items-center justify-between px-4 py-3">
          <div className="text-sm font-medium text-slate-200">{t("registerTitle")}</div>
          <Link to="/" className="surface-button h-auto px-3 py-1.5 text-xs font-medium text-slate-300">
            {t("backHome")}
          </Link>
        </div>
        <RegisterForm />
      </div>
    </div>
  );
}
