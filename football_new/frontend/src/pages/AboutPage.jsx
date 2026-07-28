import React from "react";
import BrandLockup from "@/components/brand/BrandLockup";
import { useLanguage } from "@/context/LanguageContext.jsx";

export default function AboutPage() {
  const { t } = useLanguage();
  const cards = [
    {
      title: t("whatIsEdgescore"),
      text: t("whatIsEdgescoreText"),
    },
    {
      title: t("howItWorks"),
      text: t("howItWorksText"),
    },
    {
      title: t("whatUserGets"),
      text: t("whatUserGetsText"),
    },
    {
      title: t("importantToKnow"),
      text: t("importantToKnowText"),
    },
  ];

  return (
    <div className="type-page w-full min-w-0 overflow-x-hidden space-y-6 px-1 py-5 text-slate-100 sm:space-y-8 sm:px-4 sm:py-8">
      <section className="surface-hero p-4 sm:p-6 md:p-8">
        <BrandLockup size="sm" compact />
        <h1 className="type-page-title mt-2 text-xl sm:text-2xl">
          {t("aboutProject")}
        </h1>
        <p className="type-subtitle mt-3 max-w-3xl md:text-[15px]">
          {t("aboutLead")}
        </p>
      </section>

      <section className="grid gap-4 lg:grid-cols-2">
        {cards.map((card) => (
          <article
            key={card.title}
            className="glass-card p-6"
          >
            <h2 className="text-lg font-semibold text-white">{card.title}</h2>
            <p className="mt-3 text-sm leading-7 text-slate-300">{card.text}</p>
          </article>
        ))}
      </section>

      <section className="glass-card relative overflow-hidden p-6 md:p-8">
        <div className="pointer-events-none absolute -right-20 -top-16 h-48 w-48 rounded-full bg-violet-500/10 blur-3xl" />
        <div className="type-eyebrow">
          {t("contacts")}
        </div>
        <div className="mt-3 text-2xl font-semibold text-white">
          support@edgescore.pro
        </div>
        <p className="mt-3 max-w-2xl text-sm leading-7 text-slate-300">
          {t("contactLead")}
        </p>
      </section>
    </div>
  );
}
