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

export default function MatchEventsTimeline({ fixtureId }) {
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!fixtureId) return;
    setLoading(true);
    fetch(`http://localhost:8001/api/match-events?fixture_id=${fixtureId}`)
      .then(r => r.json())
      .then(setEvents)
      .catch(() => setEvents([]))
      .finally(() => setLoading(false));
  }, [fixtureId]);

  if (loading) return <div className="text-sm text-gray-500">Загружаем события…</div>;
  if (!events.length) return <div className="text-sm text-gray-500">Событий нет</div>;

  return (
    <div className="mt-3 space-y-2">
      {events.map((e, i) => (
        <div key={i} className="flex items-start gap-3 text-sm">
          <div className="w-14 text-right text-gray-500">{e.minute_str || (e.elapsed != null ? `${e.elapsed}'` : "—")}</div>
          <div className="w-5 text-center">{ICON[e.kind] || ICON.other}</div>
          <div className={`flex-1 ${e.team_side === "home" ? "text-emerald-800" : "text-sky-800"}`}>
            <div className="font-medium">
              {e.player_name || "—"}
              {e.assist_name ? <span className="text-gray-500"> (ассист {e.assist_name})</span> : null}
            </div>
            <div className="text-gray-600">
              {e.detail || e.type || e.comments || ""}
              {e.score_after ? <span className="ml-2 font-semibold text-gray-800">{e.score_after}</span> : null}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
