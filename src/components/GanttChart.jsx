import { useEffect, useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  ReferenceLine,
} from "recharts";
const API_BASE = import.meta.env.VITE_API_BASE_URL;

// Цвета по схемам
const schemaColorMap = {
  stg: "#8884d8",
  dict_stg: "#a28dd0",
  dict_dds: "#7f90d4",
  ods: "#82ca9d",
  dds: "#20b2aa",
  dm_calc: "#ffc658",
  dm: "#ff7f50",
  export: "#84d8d8",
  default: "#c0c0c0"
};

export default function GanttChart({ schema, table }) {
  const [data, setData] = useState([]);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!schema || !table) return;
    setLoading(true);
    fetch(`${API_BASE}/api/gantt/${schema}/${table}`)
      .then((res) => res.ok ? res.json() : Promise.reject("Ошибка загрузки"))
      .then((raw) => {
        const latestByTable = raw.reduce((acc, item) => {
          const key = item.table_name;
          const start = new Date(item.start).getTime();
          const end = new Date(item.end).getTime();
          if (!acc[key] || new Date(acc[key].start).getTime() < start) {
            acc[key] = {
              name: key,
              start,
              end,
              duration: (end - start) / 1000,
              offset: start,
              is_bad: item.is_bad
            };
          }
          return acc;
        }, {});
        setData(Object.values(latestByTable));
      })
      .catch(setError)
      .finally(() => setLoading(false));
  }, [schema, table]);

  if (loading) return <p>Загрузка диаграммы Ганта...</p>;
  if (error) return <p className="error">Ошибка: {error}</p>;
  if (!data.length) return <p>Нет данных для отображения</p>;

  const minStart = Math.min(...data.map((d) => d.offset));

  const dayStarts = [...new Set(data.map(d => {
    const dt = new Date(d.offset);
    dt.setHours(0, 0, 0, 0);
    return dt.getTime();
  }))];

  const normalizeVisual = (duration) => {
    const base = 20;
    return duration < base ? duration : Math.log(duration) * base;
  };

  const normalizedData = data.map((d) => ({
    ...d,
    offset: d.offset - minStart + 20000,
    visualDuration: normalizeVisual(d.duration),
  }));

  const getSchemaColor = (tableName) => {
    const schema = (tableName || "").split(".")[0].toLowerCase();
    return schemaColorMap[schema] || schemaColorMap.default;
  };

  const formatDuration = (seconds) => {
    return seconds >= 60
      ? `${Math.round(seconds / 60)} мин`
      : `${Math.round(seconds)} сек`;
  };

  return (
    <div style={{
      border: '1px solid #ccc',
      borderRadius: '8px',
      padding: '20px',
      margin: '20px 0',
      backgroundColor: '#f9f9f9'
    }}>
      <h3 style={{ fontWeight: 'bold', fontSize: '18px', marginBottom: '10px' }}>
        📊 Диаграмма Ганта загрузки таблиц
      </h3>

      {/* График */}
      <div style={{ height: Math.max(800, data.length * 50), width: "100%", minWidth: 1400 }}>
        <ResponsiveContainer width="100%" height="100%">
          <BarChart
            layout="vertical"
            data={normalizedData}
            barCategoryGap={25}
            barSize={50}
            margin={{ top: 20, right: 100, left: 140, bottom: 60 }}
          >
            {dayStarts.map((start, i) => (
              <ReferenceLine
                key={i}
                x={start - minStart}
                stroke="#ccc"
                strokeDasharray="3 3"
                label={{
                  position: "top",
                  value: new Date(start).toLocaleDateString("ru-RU"),
                  fontSize: 12,
                  fill: "#555"
                }}
              />
            ))}
            <XAxis
              type="number"
              domain={[0, Math.max(...normalizedData.map(d => d.offset + d.visualDuration)) + 60000]}
              tickFormatter={(ms) =>
                new Date(minStart + ms).toLocaleString("ru-RU", {
                  hour: "2-digit",
                  minute: "2-digit",
                  second: "2-digit"
                })
              }
              tick={{ fontSize: 12 }}
            />
            <YAxis
              type="category"
              dataKey="name"
              width={260}
              tick={{ fontSize: 16 }}
            />
            <Tooltip
              content={({ payload }) => {
                if (!payload || !payload.length) return null;
                const d = payload[1]?.payload;
                if (!d) return null;
                return (
                  <div style={{
                    backgroundColor: "#fff",
                    border: "1px solid #ccc",
                    padding: "6px 10px",
                    fontSize: "13px",
                    maxWidth: "250px",
                    whiteSpace: "normal",
                    boxShadow: "2px 2px 6px rgba(0,0,0,0.1)",
                    lineHeight: "1.4em"
                  }}>
                    <div><strong>Таблица:</strong> {d.name}</div>
                    <div><strong>Длительность:</strong> {formatDuration(d.duration)}</div>
                    <div><strong>Статус:</strong> {d.is_bad ? "⚠️ Загрузка раньше источника" : "✅ Всё корректно"}</div>
                  </div>
                );
              }}
            />
            <Bar dataKey="offset" stackId="a" fill="transparent" />
            <Bar
              dataKey="visualDuration"
              stackId="a"
              isAnimationActive={false}
              shape={(props) => {
                const { x, y, width, height, payload } = props;
                const color = getSchemaColor(payload.name);
                const strokeColor = payload.is_bad ? "#e53935" : "#43a047";
                const strokeWidth = 1.2;
                return (
                  <rect
                    x={x}
                    y={y}
                    width={Math.max(width, 6)}
                    height={height}
                    fill={color}
                    stroke={strokeColor}
                    strokeWidth={strokeWidth}
                    rx={4}
                  />
                );
              }}
            />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Легенда */}
      <div style={{
        display: "flex",
        flexWrap: "wrap",
        gap: "16px",
        marginTop: "20px",
        fontSize: "14px"
      }}>
        {Object.entries(schemaColorMap).map(([schemaKey, color]) => (
          schemaKey !== "default" && (
            <div key={schemaKey} style={{ display: "flex", alignItems: "center" }}>
              <div style={{
                width: "16px",
                height: "16px",
                backgroundColor: color,
                marginRight: "6px",
                borderRadius: "3px",
                border: "1px solid #999"
              }} />
              <span style={{ fontFamily: "monospace" }}>{schemaKey}</span>
            </div>
          )
        ))}
      </div>
    </div>
  );
}