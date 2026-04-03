// components/MatchEventsTimeline.jsx
import { useEffect, useState } from "react";

const ICON = {
  goal: "⚽",
  own_goal: "🆚",      // можно поменять на "🥅" или "🙈"
  goal_cancelled: "🚫",
  pen_missed: "⛔",
  yellow: "🟨",
  red: "🟥",
  sub: "🔁",
  var: "🎥",
  other: "•",
};

const eventsCache = new Map();
const DISABLE_MATCH_EVENTS_FETCH = true;

export default function MatchEventsTimeline({ fixtureId }) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!fixtureId) return;
    if (DISABLE_MATCH_EVENTS_FETCH) {
      setError("События недоступны");
      setEvents([]);
      return;
    }
    if (eventsCache.has(fixtureId)) {
      const cached = eventsCache.get(fixtureId);
      if (cached?.error) {
        setError(cached.error);
        setEvents([]);
      } else {
        setEvents(Array.isArray(cached?.events) ? cached.events : []);
      }
      return;
    }
    setLoading(true);
    setError("");
    fetch(`/api/match-events?fixture_id=${fixtureId}`)
      .then(r => r.json())
      .then((data) => {
        const list = Array.isArray(data) ? data : [];
        eventsCache.set(fixtureId, { events: list });
        setEvents(list);
      })
      .catch(() => {
        const err = "События недоступны";
        eventsCache.set(fixtureId, { error: err });
        setError(err);
        setEvents([]);
      })
      .finally(() => setLoading(false));
  }, [fixtureId]);

  if (loading) return <div className="text-sm text-slate-400">Загружаем события…</div>;
  if (error) return <div className="text-sm text-slate-400">{error}</div>;
  if (!events.length) return <div className="text-sm text-slate-400">Событий нет</div>;

  return (
    <div className="mt-3 space-y-2">
      {events.map((e, i) => (
        <div key={i} className="flex items-start gap-3 text-sm">
          <div className="w-14 text-right text-slate-400">{e.minute_str || (e.elapsed != null ? `${e.elapsed}'` : "—")}</div>
          <div className="w-5 text-center">{ICON[e.kind] || ICON.other}</div>
          <div className={`flex-1 ${e.team_side === "home" ? "text-emerald-300" : "text-sky-300"}`}>
            <div className="font-medium">
              {e.player_name || "—"}
              {e.assist_name ? <span className="text-slate-400"> (ассист {e.assist_name})</span> : null}
            </div>
            <div className="text-slate-300">
              {e.detail || e.type || e.comments || ""}
              {e.score_after ? <span className="ml-2 font-semibold text-slate-100">{e.score_after}</span> : null}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
