import { useEffect, useMemo, useRef, useState } from "react";
import { assistantApi } from "../api/assistant.js";

const QUICK_ACTIONS = [
  "Самая долгая загрузка",
  "Самая долгая загрузка на слое dm",
];

function renderContextLabel(context) {
  if (context?.schema && context?.table) {
    return `${context.schema}.${context.table}${context?.source && context.source !== "current" ? ` · ${context.source}` : ""}`;
  }
  return "Глобальный поиск";
}

function initialAssistantMessage(context) {
  return {
    role: "assistant",
    text: context?.schema && context?.table
      ? `Контекст зафиксирован на ${renderContextLabel(context)}. Могу быстро подсказать зависимости, влияние, похожие таблицы и проблемные загрузки.`
      : "Могу искать таблицы по описанию, показывать самые долгие загрузки, искать по слоям и объяснять зависимости.",
  };
}

export default function AdminAssistantPanel({
  open,
  onOpen,
  onClose,
  context,
  onOpenTable,
}) {
  const [messages, setMessages] = useState(() => [initialAssistantMessage(context)]);
  const [question, setQuestion] = useState("");
  const [loading, setLoading] = useState(false);
  const lastContextLabelRef = useRef(renderContextLabel(context));

  useEffect(() => {
    const nextLabel = renderContextLabel(context);
    setMessages((prev) => {
      const intro = initialAssistantMessage(context);
      if (!prev.length) return [intro];
      if (lastContextLabelRef.current !== nextLabel) {
        lastContextLabelRef.current = nextLabel;
        return [
          ...prev,
          {
            role: "assistant",
            text: `Контекст переключен на ${nextLabel}. Можешь продолжать диалог, я буду отвечать уже относительно этой страницы.`,
          },
        ];
      }
      return prev;
    });
  }, [context?.schema, context?.table, context?.source, context?.page]);

  const contextLabel = useMemo(() => renderContextLabel(context), [context]);
  const quickActions = useMemo(() => {
    const items = [...QUICK_ACTIONS];
    if (context?.schema) {
      items.push(`Самая долгая загрузка на слое ${context.schema}`);
    }
    return Array.from(new Set(items));
  }, [context?.schema]);

  const submitQuestion = async (rawQuestion) => {
    const text = String(rawQuestion || question).trim();
    if (!text || loading) return;
    setMessages((prev) => [...prev, { role: "user", text }]);
    setQuestion("");
    setLoading(true);
    try {
      const response = await assistantApi.query({ question: text, context });
      setMessages((prev) => [...prev, { role: "assistant", response }]);
    } catch (err) {
      setMessages((prev) => [
        ...prev,
        {
          role: "assistant",
          response: {
            title: "Ошибка ассистента",
            answer: err?.message || "Не удалось получить ответ.",
            tables: [],
            stats: [],
            suggestions: [],
          },
        },
      ]);
    } finally {
      setLoading(false);
    }
  };

  const onInputKeyDown = (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      submitQuestion();
    }
  };

  return (
    <>
      <button
        type="button"
        className={`assistant-fab ${open ? "open" : ""}`}
        onClick={open ? onClose : onOpen}
      >
        <span className="assistant-fab-mark">AI</span>
        <span className="assistant-fab-label">Ассистент</span>
      </button>

      <div className={`assistant-shell ${open ? "open" : ""}`} aria-hidden={!open}>
        <div className="assistant-backdrop" onClick={onClose} />
        <aside className="assistant-panel">
          <div className="assistant-head">
            <div>
              <div className="assistant-kicker-row">
                <div className="assistant-kicker">Admin only</div>
                <div className="assistant-head-badge">DWH Navigator</div>
              </div>
              <div className="assistant-title">Ассистент DWH</div>
              <div className="assistant-context">{contextLabel}</div>
            </div>
            <button type="button" className="assistant-close" onClick={onClose}>Закрыть</button>
          </div>

          <div className="assistant-hero-card">
            <div className="assistant-hero-title">Что умеет сейчас</div>
            <div className="assistant-hero-text">
              Поиск по описанию и названиям, самые долгие загрузки, upstream/downstream и быстрый разбор текущей таблицы без выхода со страницы.
            </div>
          </div>

          <div className="assistant-quick-actions">
            {quickActions.map((item) => (
              <button key={item} type="button" className="assistant-chip" onClick={() => submitQuestion(item)}>
                {item}
              </button>
            ))}
            {context?.schema && context?.table ? (
              <>
                <button type="button" className="assistant-chip" onClick={() => submitQuestion("Что это за таблица?")}>
                  Что это за таблица?
                </button>
                <button type="button" className="assistant-chip" onClick={() => submitQuestion("От чего зависит таблица?")}>
                  От чего зависит?
                </button>
                <button type="button" className="assistant-chip" onClick={() => submitQuestion("На что влияет таблица?")}>
                  На что влияет?
                </button>
              </>
            ) : null}
          </div>

          <div className="assistant-feed">
            {messages.map((message, index) => (
              <div key={`${message.role}-${index}`} className={`assistant-message ${message.role}`}>
                {message.role === "user" ? (
                  <div className="assistant-user-bubble">{message.text}</div>
                ) : message.response ? (
                  <div className="assistant-response-card">
                    <div className="assistant-response-title">{message.response.title || "Ответ"}</div>
                    <div className="assistant-response-text">{message.response.answer || "—"}</div>

                    {Array.isArray(message.response.stats) && message.response.stats.length > 0 ? (
                      <div className="assistant-stats">
                        {message.response.stats.map((stat) => (
                          <div key={`${stat.label}-${stat.value}`} className="assistant-stat">
                            <span>{stat.label}</span>
                            <strong>{stat.value}</strong>
                          </div>
                        ))}
                      </div>
                    ) : null}

                    {Array.isArray(message.response.tables) && message.response.tables.length > 0 ? (
                      <div className="assistant-table-list">
                        {message.response.tables.map((item) => (
                          <button
                            key={`${item.source}-${item.fqn}`}
                            type="button"
                            className="assistant-table-item"
                            onClick={() => onOpenTable?.(item)}
                          >
                            <span className="mono assistant-table-fqn">{item.fqn}</span>
                            <span className="assistant-table-meta">
                              {item.entity_name || "—"}
                              {item.description ? ` · ${item.description}` : ""}
                            </span>
                          </button>
                        ))}
                      </div>
                    ) : null}

                    {Array.isArray(message.response.suggestions) && message.response.suggestions.length > 0 ? (
                      <div className="assistant-suggestion-row">
                        {message.response.suggestions.map((item) => (
                          <button key={item} type="button" className="assistant-chip subtle" onClick={() => submitQuestion(item)}>
                            {item}
                          </button>
                        ))}
                      </div>
                    ) : null}
                  </div>
                ) : (
                  <div className="assistant-response-card">
                    <div className="assistant-response-text">{message.text}</div>
                  </div>
                )}
              </div>
            ))}
            {loading ? <div className="assistant-loading">Ассистент собирает ответ...</div> : null}
          </div>

          <div className="assistant-input-bar">
            <textarea
              className="assistant-input"
              rows={3}
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              onKeyDown={onInputKeyDown}
              placeholder="Спроси про описание таблицы, зависимости, влияние или загрузки..."
            />
            <button type="button" className="btn btn-primary assistant-send" onClick={() => submitQuestion()}>
              Спросить
            </button>
          </div>
        </aside>
      </div>
    </>
  );
}
