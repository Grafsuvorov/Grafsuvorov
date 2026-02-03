import { useState } from "react";
import { useNavigate } from "react-router-dom";
import "../style/app.css";
import "../style/assistant.css";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

const QUICK_QUESTIONS = [
  "Что произошло в окне 04:30-05:20?",
  "Какие таблицы самые тяжёлые за ночь?",
  "Почему выросло число инцидентов?",
];

export default function AssistantPage() {
  const navigate = useNavigate();
  const [messages, setMessages] = useState([]);
  const [question, setQuestion] = useState("");
  const [timeWindow, setTimeWindow] = useState("04:30-05:20");
  const [tableFqn, setTableFqn] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const ask = async (text) => {
    const q = (text || question || "").trim();
    if (!q || loading) return;

    const history = messages.slice(-6).map((m) => ({ role: m.role, text: m.text }));
    const userMessage = { role: "user", text: q };
    setMessages((prev) => [...prev, userMessage]);
    setQuestion("");
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(`${API_BASE}/api/assistant/query`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          question: q,
          time_window: timeWindow || null,
          table_fqn: tableFqn || null,
          history,
        }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          text: data.answer || "Нет данных",
          payload: data,
        },
      ]);
    } catch (e) {
      setError(typeof e?.message === "string" ? e.message : "Assistant request failed");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container cc-page">
      <section className="cc-header-zone">
        <button className="btn" onClick={() => navigate("/")}>← Назад</button>
        <h1>Assistant</h1>
        <div className="cc-subtitle">Спроси, что случилось, и получи разбор с источниками из приложения.</div>
      </section>

      <section className="cc-surface assistant-controls">
        <label className="assistant-field">
          Окно времени
          <input value={timeWindow} onChange={(e) => setTimeWindow(e.target.value)} placeholder="04:30-05:20" />
        </label>
        <label className="assistant-field assistant-field-wide">
          Таблица (опционально)
          <input value={tableFqn} onChange={(e) => setTableFqn(e.target.value)} placeholder="schema.table" />
        </label>
      </section>

      <section className="cc-surface assistant-quick">
        {QUICK_QUESTIONS.map((x) => (
          <button key={x} className="btn btn-secondary" onClick={() => ask(x)}>{x}</button>
        ))}
      </section>

      <section className="cc-surface assistant-chat">
        {!messages.length && <div className="muted">Задай вопрос: что произошло, почему, что проверить дальше.</div>}
        {messages.map((m, i) => (
          <div key={`${m.role}-${i}`} className={`assistant-msg ${m.role === "assistant" ? "is-assistant" : "is-user"}`}>
            <div className="assistant-role">{m.role === "assistant" ? "Ассистент" : "Ты"}</div>
            <div>{m.text}</div>
            {m.role === "assistant" && m.payload?.blocks && (
              <div className="assistant-blocks">
                {(m.payload.blocks.what_happened || []).map((x, idx) => <div key={`wh-${idx}`}>• {x}</div>)}
                {(m.payload.blocks.possible_causes || []).map((x, idx) => <div key={`pc-${idx}`}>• {x}</div>)}
                {(m.payload.blocks.next_steps || []).map((x, idx) => <div key={`ns-${idx}`}>• {x}</div>)}
                {m.payload.compare && (
                  <div>
                    • Script diff: aliases diff={m.payload.compare.expr_diff?.length || 0}, sources only left={m.payload.compare.left_sources_only?.length || 0}, right={m.payload.compare.right_sources_only?.length || 0}
                  </div>
                )}
                {m.payload.duration && (
                  <div>
                    • Duration: avg={m.payload.duration.avg_minutes ?? "n/a"} min, p95={m.payload.duration.p95_minutes ?? "n/a"} min, max={m.payload.duration.max_minutes ?? "n/a"} min
                  </div>
                )}
                {m.payload.max_duration && (
                  <div>
                    • Max duration: {m.payload.max_duration.table_fqn} (max={m.payload.max_duration.max_duration_minutes ?? "n/a"} min)
                  </div>
                )}
                {Array.isArray(m.payload.used_tools) && m.payload.used_tools.length > 0 && (
                  <div className="muted">Источники: {m.payload.used_tools.join(", ")}</div>
                )}
              </div>
            )}
          </div>
        ))}
        {loading && <div className="muted">Думаю над ответом...</div>}
        {error && <div className="dep-error-title">{error}</div>}
      </section>

      <section className="cc-surface assistant-input-row">
        <input
          value={question}
          onChange={(e) => setQuestion(e.target.value)}
          placeholder="Например: почему пик с 04:30 до 05:20 и где корень?"
          onKeyDown={(e) => {
            if (e.key === "Enter") ask();
          }}
        />
        <button className="btn" onClick={() => ask()} disabled={loading}>Спросить</button>
      </section>
    </div>
  );
}
