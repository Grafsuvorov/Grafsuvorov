import { useEffect, useMemo, useState } from "react";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend } from "recharts";

const API_SUMMARY = "/api/roi-admin/summary";
const API_MATCHES = "/api/roi-admin/matches";

const getStoredToken = () => {
  try {
    return localStorage.getItem("access_token") || sessionStorage.getItem("access_token");
  } catch {
    return null;
  }
};

const getStoredRefreshToken = () => {
  try {
    return localStorage.getItem("refresh_token") || sessionStorage.getItem("refresh_token");
  } catch {
    return null;
  }
};

const setStoredToken = (accessToken, refreshToken) => {
  try {
    if (accessToken) localStorage.setItem("access_token", accessToken);
    if (refreshToken) localStorage.setItem("refresh_token", refreshToken);
    return "local";
  } catch {
    try {
      if (accessToken) sessionStorage.setItem("access_token", accessToken);
      if (refreshToken) sessionStorage.setItem("refresh_token", refreshToken);
      return "session";
    } catch {
      return null;
    }
  }
};

const refreshSession = async () => {
  const refreshToken = getStoredRefreshToken();
  if (!refreshToken) return false;
  const res = await fetch("/auth-dwh/refresh", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });
  if (!res.ok) return false;
  const data = await res.json();
  setStoredToken(data.access_token, data.refresh_token);
  return true;
};

const fetchWithAuth = async (url) => {
  const token = getStoredToken();
  const res = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  });
  if (res.status === 401 || res.status === 403) {
    const refreshed = await refreshSession();
    if (!refreshed) return res;
    const retryToken = getStoredToken();
    return fetch(url, {
      headers: retryToken ? { Authorization: `Bearer ${retryToken}` } : undefined,
    });
  }
  return res;
};

const fmtPct = (v) => (v == null || Number.isNaN(v) ? "—" : `${(v * 100).toFixed(1)}%`);
const fmtNum = (v) => (v == null || Number.isNaN(v) ? "—" : Number(v).toFixed(2));
const FLAT_UNIT = 1000;

export default function RoiAdminPage() {
  const [season, setSeason] = useState("");
  const [leagueId, setLeagueId] = useState("");
  const [dateFrom, setDateFrom] = useState("2025-08-01");
  const [dateTo, setDateTo] = useState("2026-01-30");
  const [summary, setSummary] = useState(null);
  const [selectedRound, setSelectedRound] = useState("");
  const [matches, setMatches] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [loadingMatches, setLoadingMatches] = useState(false);

  const leagueOptions = useMemo(() => summary?.leagues || [], [summary]);
  const activeLeague = useMemo(() => {
    if (!leagueOptions.length) return null;
    if (!leagueId) return leagueOptions[0];
    return leagueOptions.find((l) => String(l.league_id) === String(leagueId)) || leagueOptions[0];
  }, [leagueOptions, leagueId]);

  const chartData = useMemo(() => {
    if (!activeLeague?.rounds) return [];
    return activeLeague.rounds.map((r) => ({
      round: r.round_num ?? r.round,
      roundLabel: r.round,
      outcomeRoi: r.outcome?.roi_flat ?? r.outcome?.roi ?? null,
      totalRoi: r.total?.roi_flat ?? r.total?.roi ?? null,
      outcomeBets: r.outcome?.bets ?? 0,
      totalBets: r.total?.bets ?? 0,
    }));
  }, [activeLeague]);

  const loadSummary = async () => {
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams();
      if (season) params.set("season", season);
      if (dateFrom) params.set("date_from", dateFrom);
      if (dateTo) params.set("date_to", dateTo);
      const res = await fetchWithAuth(`${API_SUMMARY}?${params.toString()}`);
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      const data = await res.json();
      setSummary(data);
      if (data?.leagues?.length && !leagueId) {
        setLeagueId(String(data.leagues[0].league_id));
      }
    } catch (e) {
      setError(e?.message || "Не удалось загрузить данные.");
    } finally {
      setLoading(false);
    }
  };

  const loadMatches = async (roundLabel) => {
    if (!roundLabel) return;
    setLoadingMatches(true);
    setError("");
    try {
      const params = new URLSearchParams();
      if (season) params.set("season", season);
      if (leagueId) params.set("league_id", leagueId);
      if (dateFrom) params.set("date_from", dateFrom);
      if (dateTo) params.set("date_to", dateTo);
      params.set("round_label", roundLabel);
      const res = await fetchWithAuth(`${API_MATCHES}?${params.toString()}`);
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || `HTTP ${res.status}`);
      }
      const data = await res.json();
      setMatches(data?.rows || []);
    } catch (e) {
      setError(e?.message || "Не удалось загрузить матчи.");
    } finally {
      setLoadingMatches(false);
    }
  };

  useEffect(() => {
    loadSummary();
  }, []);

  useEffect(() => {
    if (selectedRound) loadMatches(selectedRound);
  }, [selectedRound]);

  return (
    <div className="min-h-screen bg-surface-1 text-slate-100">
      <div className="mx-auto max-w-6xl px-6 py-8">
        <div className="mb-6">
          <div className="text-sm uppercase tracking-[0.2em] text-slate-500">Internal</div>
          <h1 className="text-2xl font-semibold">ROI Dashboard</h1>
          <p className="mt-1 text-sm text-slate-400">Графики по турам и детализация по матчам.</p>
        </div>

          <div className="mb-6 rounded-2xl border border-white/10 bg-surface-2 p-4">
            <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
            <label className="text-sm text-slate-400">
              Сезон
              <input
                value={season}
                onChange={(e) => setSeason(e.target.value)}
                placeholder="2025"
                className="mt-2 w-full rounded-lg border border-white/10 bg-surface-1 px-3 py-2 text-slate-100"
              />
            </label>
            <label className="text-sm text-slate-400">
              Лига
              <select
                value={leagueId}
                onChange={(e) => setLeagueId(e.target.value)}
                className="mt-2 w-full rounded-lg border border-white/10 bg-surface-1 px-3 py-2 text-slate-100"
              >
                {leagueOptions.map((l) => (
                  <option key={l.league_id} value={l.league_id}>
                    {l.league}
                  </option>
                ))}
              </select>
            </label>
            <label className="text-sm text-slate-400">
              Дата от
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                className="mt-2 w-full rounded-lg border border-white/10 bg-surface-1 px-3 py-2 text-slate-100"
              />
            </label>
            <label className="text-sm text-slate-400">
              Дата до
              <input
                type="date"
                value={dateTo}
                onChange={(e) => setDateTo(e.target.value)}
                className="mt-2 w-full rounded-lg border border-white/10 bg-surface-1 px-3 py-2 text-slate-100"
              />
            </label>
          </div>
          <div className="mt-4 flex items-center gap-3">
            <button
              onClick={loadSummary}
              className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-slate-900"
            >
              Обновить
            </button>
            {loading && <div className="text-sm text-slate-400">Загрузка…</div>}
            {error && <div className="text-sm text-rose-300">{error}</div>}
          </div>
        </div>

        {activeLeague && (
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
            <div className="rounded-2xl border border-white/10 bg-surface-2 p-4">
              <div className="mb-3 text-sm font-semibold text-slate-200">ROI по турам · 1X2</div>
              <div style={{ width: "100%", height: 260 }}>
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#27364f" />
                    <XAxis dataKey="round" tick={{ fontSize: 11, fill: "#94a3b8" }} />
                    <YAxis tick={{ fontSize: 11, fill: "#94a3b8" }} />
                    <Tooltip
                      formatter={(value) => fmtPct(value)}
                      labelFormatter={(_, payload) => payload?.[0]?.payload?.roundLabel || ""}
                      contentStyle={{ background: "#0b1220", border: "1px solid #1f2a44", color: "#e2e8f0" }}
                    />
                    <Legend />
                    <Line type="monotone" dataKey="outcomeRoi" name="ROI" stroke="#8b5cf6" dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="rounded-2xl border border-white/10 bg-surface-2 p-4">
              <div className="mb-3 text-sm font-semibold text-slate-200">ROI по турам · Totals</div>
              <div style={{ width: "100%", height: 260 }}>
                <ResponsiveContainer>
                  <LineChart data={chartData}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#27364f" />
                    <XAxis dataKey="round" tick={{ fontSize: 11, fill: "#94a3b8" }} />
                    <YAxis tick={{ fontSize: 11, fill: "#94a3b8" }} />
                    <Tooltip
                      formatter={(value) => fmtPct(value)}
                      labelFormatter={(_, payload) => payload?.[0]?.payload?.roundLabel || ""}
                      contentStyle={{ background: "#0b1220", border: "1px solid #1f2a44", color: "#e2e8f0" }}
                    />
                    <Legend />
                    <Line type="monotone" dataKey="totalRoi" name="ROI" stroke="#22d3ee" dot={false} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        )}

        {activeLeague && (
          <div className="mt-6 rounded-2xl border border-white/10 bg-surface-2 p-4">
            <div className="mb-3 text-sm font-semibold text-slate-200">Туры</div>
            <div className="grid grid-cols-1 gap-2">
              {activeLeague.rounds.map((r) => (
                <button
                  key={r.round}
                  onClick={() => {
                    setSelectedRound(r.round);
                    setMatches([]);
                  }}
                  className={`flex items-center justify-between rounded-lg border px-3 py-2 text-sm ${
                    selectedRound === r.round
                      ? "border-primary/60 bg-primary/10 text-white"
                      : "border-white/10 text-slate-300 hover:border-white/20"
                  }`}
                >
                  <div className="grid w-full grid-cols-1 gap-2 text-left md:grid-cols-[1.2fr_1fr_1fr]">
                    <div>
                      <div className="text-sm font-medium">{r.round}</div>
                      <div className="text-[11px] text-slate-500">
                        матчей {r.matches ?? 0} · {r.first_date || ""}
                      </div>
                    </div>
                    <div className="text-[11px] text-slate-400">
                      <div className="font-semibold text-slate-200">1X2</div>
                      <div>
                        ROI {fmtPct(r.outcome?.roi_flat ?? r.outcome?.roi)} · bets{" "}
                        {r.outcome?.bets ?? 0} · +{r.outcome?.wins ?? 0}/-
                        {r.outcome?.losses ?? 0}
                      </div>
                      <div className="text-slate-500">
                        profit ${fmtNum((r.outcome?.profit_base_sum ?? 0) * FLAT_UNIT)} · stake $
                        {fmtNum((r.outcome?.bets ?? 0) * FLAT_UNIT)}
                      </div>
                    </div>
                    <div className="text-[11px] text-slate-400">
                      <div className="font-semibold text-slate-200">Totals</div>
                      <div>
                        ROI {fmtPct(r.total?.roi_flat ?? r.total?.roi)} · bets{" "}
                        {r.total?.bets ?? 0} · +{r.total?.wins ?? 0}/-
                        {r.total?.losses ?? 0}
                      </div>
                      <div className="text-slate-500">
                        profit ${fmtNum((r.total?.profit_base_sum ?? 0) * FLAT_UNIT)} · stake $
                        {fmtNum((r.total?.bets ?? 0) * FLAT_UNIT)}
                      </div>
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>
        )}

        {selectedRound && (
          <div className="mt-6 rounded-2xl border border-white/10 bg-surface-2 p-4">
            <div className="mb-3 text-sm font-semibold text-slate-200">Матчи · {selectedRound}</div>
            {loadingMatches && <div className="text-sm text-slate-400">Загрузка…</div>}
            {!loadingMatches && matches.length === 0 && (
              <div className="text-sm text-slate-400">Нет данных для выбранного тура.</div>
            )}
            <div className="grid grid-cols-1 gap-3">
              {matches.map((m) => (
                <div key={m.fixture_id} className="rounded-lg border border-white/10 bg-surface-1 px-3 py-3">
                  <div className="flex items-center justify-between text-sm">
                    <div className="text-slate-200">
                      {m.home_team} — {m.away_team}
                    </div>
                    <div className="tabular-nums text-slate-400">{m.score}</div>
                  </div>
                  <div className="mt-2 grid grid-cols-1 gap-2 text-xs text-slate-400 md:grid-cols-2">
                    <div>
                      1X2: {m.outcome?.pick || "—"} · tier {m.outcome?.tier || "—"} ·
                      odds {m.outcome?.odds?.toFixed?.(2) || "—"} · EV{" "}
                      {m.outcome?.ev != null ? `${(m.outcome.ev * 100).toFixed(1)}%` : "—"} ·
                      profit {m.outcome?.profit != null ? m.outcome.profit.toFixed(2) : "—"}
                    </div>
                    <div>
                      Total: {m.total?.pick || "—"} · tier {m.total?.tier || "—"} ·
                      odds {m.total?.odds?.toFixed?.(2) || "—"} · edge{" "}
                      {m.total?.edge != null ? `${(m.total.edge * 100).toFixed(1)}%` : "—"} ·
                      profit {m.total?.profit != null ? m.total.profit.toFixed(2) : "—"}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
