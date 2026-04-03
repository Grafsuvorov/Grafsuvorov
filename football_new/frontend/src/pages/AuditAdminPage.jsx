import { useEffect, useState } from "react";
import { http } from "@/lib/http.js";

function StatCard({ label, value, hint }) {
  return (
    <div className="rounded-3xl border border-glass bg-surface-2/80 p-5 shadow-[0_18px_55px_rgba(0,0,0,0.35)]">
      <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">{label}</div>
      <div className="mt-3 text-3xl font-semibold text-white">{value}</div>
      {hint ? <div className="mt-1 text-sm text-slate-400">{hint}</div> : null}
    </div>
  );
}

function formatDateTime(value) {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(+d)) return String(value);
  return d.toLocaleString("ru-RU");
}

export default function AuditAdminPage() {
  const [days, setDays] = useState(7);
  const [limit, setLimit] = useState(100);
  const [pathFilter, setPathFilter] = useState("");
  const [emailFilter, setEmailFilter] = useState("");
  const [summary, setSummary] = useState(null);
  const [recent, setRecent] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = async () => {
    try {
      setLoading(true);
      setError("");
      const [summaryRes, recentRes] = await Promise.all([
        http.get(`/api/audit/admin/summary?days=${days}`),
        http.get(
          `/api/audit/admin/recent?days=${days}&limit=${limit}${
            emailFilter ? `&user_email=${encodeURIComponent(emailFilter)}` : ""
          }${pathFilter ? `&path=${encodeURIComponent(pathFilter)}` : ""}`
        ),
      ]);
      setSummary(summaryRes.data || null);
      setRecent(recentRes.data?.items || []);
    } catch (err) {
      setError(err?.data?.detail || err?.message || "Не удалось загрузить аудит.");
      setSummary(null);
      setRecent([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div className="w-full px-4 py-8 space-y-8">
      <section className="rounded-[32px] border border-glass bg-surface-2/75 p-6 md:p-8 shadow-[0_24px_80px_rgba(0,0,0,0.42)] backdrop-blur-xl">
        <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Admin</div>
        <h1 className="mt-2 text-3xl font-semibold text-white">Аудит активности</h1>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-300">
          Кто заходил на сайт, какие страницы открывал, какие API вызывал и с какого IP.
        </p>

        <div className="mt-6 grid gap-3 md:grid-cols-4">
          <label className="rounded-2xl border border-glass bg-surface-1/70 px-4 py-3">
            <div className="text-[11px] uppercase tracking-[0.16em] text-slate-400">Период</div>
            <select
              className="mt-2 w-full bg-transparent text-sm text-white outline-none"
              value={days}
              onChange={(e) => setDays(Number(e.target.value))}
            >
              <option value={1}>1 день</option>
              <option value={7}>7 дней</option>
              <option value={14}>14 дней</option>
              <option value={30}>30 дней</option>
              <option value={90}>90 дней</option>
            </select>
          </label>

          <label className="rounded-2xl border border-glass bg-surface-1/70 px-4 py-3">
            <div className="text-[11px] uppercase tracking-[0.16em] text-slate-400">Лимит</div>
            <select
              className="mt-2 w-full bg-transparent text-sm text-white outline-none"
              value={limit}
              onChange={(e) => setLimit(Number(e.target.value))}
            >
              <option value={50}>50</option>
              <option value={100}>100</option>
              <option value={200}>200</option>
              <option value={500}>500</option>
            </select>
          </label>

          <label className="rounded-2xl border border-glass bg-surface-1/70 px-4 py-3">
            <div className="text-[11px] uppercase tracking-[0.16em] text-slate-400">Email</div>
            <input
              value={emailFilter}
              onChange={(e) => setEmailFilter(e.target.value)}
              placeholder="user@example.com"
              className="mt-2 w-full bg-transparent text-sm text-white placeholder:text-slate-500 outline-none"
            />
          </label>

          <label className="rounded-2xl border border-glass bg-surface-1/70 px-4 py-3">
            <div className="text-[11px] uppercase tracking-[0.16em] text-slate-400">Путь</div>
            <input
              value={pathFilter}
              onChange={(e) => setPathFilter(e.target.value)}
              placeholder="/insights"
              className="mt-2 w-full bg-transparent text-sm text-white placeholder:text-slate-500 outline-none"
            />
          </label>
        </div>

        <div className="mt-4 flex flex-wrap gap-3">
          <button
            onClick={load}
            className="rounded-2xl border border-violet-400/35 bg-[linear-gradient(135deg,rgba(124,58,237,0.9),rgba(99,102,241,0.82))] px-5 py-2.5 text-sm font-semibold text-white shadow-[0_14px_34px_rgba(124,58,237,0.24),inset_0_1px_0_rgba(255,255,255,0.18)] transition hover:brightness-110"
          >
            Обновить
          </button>
          {error ? <div className="self-center text-sm text-rose-300">{error}</div> : null}
        </div>
      </section>

      {loading ? (
        <div className="rounded-3xl border border-glass bg-surface-1/70 p-8 text-sm text-slate-300">
          Загрузка аудита…
        </div>
      ) : (
        <>
          <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            <StatCard label="Всего событий" value={summary?.total_events ?? 0} />
            <StatCard label="Page Views" value={summary?.page_views ?? 0} />
            <StatCard label="API Requests" value={summary?.api_requests ?? 0} />
            <StatCard
              label="Уникальные пользователи"
              value={summary?.unique_users_count ?? 0}
              hint={summary?.last_seen_at ? `Последняя активность: ${formatDateTime(summary.last_seen_at)}` : ""}
            />
          </section>

          <section className="grid gap-6 xl:grid-cols-[1.15fr_0.85fr]">
            <div className="rounded-3xl border border-glass bg-surface-1/75 p-6">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Recent</div>
                  <div className="mt-2 text-xl font-semibold text-white">Последние действия</div>
                </div>
                <div className="text-sm text-slate-400">{recent.length} записей</div>
              </div>

              <div className="mt-5 space-y-3">
                {recent.length ? (
                  recent.map((row) => (
                    <div key={row.id} className="rounded-2xl border border-glass bg-surface-2/60 p-4">
                      <div className="flex flex-wrap items-center gap-2 text-xs text-slate-400">
                        <span className="rounded-full border border-glass px-2 py-1 text-slate-300">
                          {row.event_type}
                        </span>
                        <span>{formatDateTime(row.created_at)}</span>
                        <span>{row.ip_address || "—"}</span>
                        <span>{row.response_status ?? "—"}</span>
                        <span>{row.response_time_ms ? `${row.response_time_ms} ms` : "—"}</span>
                      </div>
                      <div className="mt-3 text-sm font-medium text-white break-all">
                        {row.user_email || row.username || "unknown"}
                      </div>
                      <div className="mt-1 text-sm text-slate-300 break-all">
                        {row.method || "—"} {row.path || "—"}
                      </div>
                      {row.referer ? (
                        <div className="mt-1 text-xs text-slate-500 break-all">Referer: {row.referer}</div>
                      ) : null}
                      {row.user_agent ? (
                        <div className="mt-1 text-xs text-slate-500 break-all">UA: {row.user_agent}</div>
                      ) : null}
                    </div>
                  ))
                ) : (
                  <div className="rounded-2xl border border-glass bg-surface-2/60 p-6 text-sm text-slate-400">
                    Нет данных по выбранным фильтрам.
                  </div>
                )}
              </div>
            </div>

            <div className="space-y-6">
              <div className="rounded-3xl border border-glass bg-surface-1/75 p-6">
                <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Top Paths</div>
                <div className="mt-2 text-xl font-semibold text-white">Популярные пути</div>
                <div className="mt-4 space-y-3">
                  {(summary?.top_paths || []).length ? (
                    summary.top_paths.map(([path, count]) => (
                      <div key={path} className="flex items-center justify-between gap-4 rounded-2xl border border-glass bg-surface-2/60 px-4 py-3">
                        <div className="min-w-0 truncate text-sm text-white">{path}</div>
                        <div className="text-sm font-semibold text-violet-300">{count}</div>
                      </div>
                    ))
                  ) : (
                    <div className="text-sm text-slate-400">Нет данных.</div>
                  )}
                </div>
              </div>

              <div className="rounded-3xl border border-glass bg-surface-1/75 p-6">
                <div className="text-[11px] uppercase tracking-[0.18em] text-slate-400">Top Users</div>
                <div className="mt-2 text-xl font-semibold text-white">Активные пользователи</div>
                <div className="mt-4 space-y-3">
                  {(summary?.top_users || []).length ? (
                    summary.top_users.map(([email, count]) => (
                      <div key={email} className="flex items-center justify-between gap-4 rounded-2xl border border-glass bg-surface-2/60 px-4 py-3">
                        <div className="min-w-0 truncate text-sm text-white">{email}</div>
                        <div className="text-sm font-semibold text-violet-300">{count}</div>
                      </div>
                    ))
                  ) : (
                    <div className="text-sm text-slate-400">Нет данных.</div>
                  )}
                </div>
              </div>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
