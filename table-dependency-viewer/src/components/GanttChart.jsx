import { useEffect, useState } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

const API_BASE = import.meta.env.VITE_API_BASE_URL || "";

/* =========================================================
   CONFIG
   ========================================================= */

const schemaColorMap = {
  stg: "#64748b",
  dict_stg: "#4c6b9b",
  dict_ods: "#2563eb",
  dict_dds: "#3d4d82",
  ods: "#0d9488",
  dds: "#0891b2",
  dm_calc: "#f59e0b",
  dm: "#2563eb",
  default: "#6b7280",
};

const SCHEMA_PRIORITY = {
  dict_stg: 0,
  dict_ods: 1,
  dict_dds: 2,
  stg: 3,
  ods: 4,
  dds: 5,
  dm_calc: 6,
  dm: 7,
  dm_view: 8,
  default: 50,
};

const ROW_HEIGHT = 44;      // fixed row height
const HEADER_OFFSET = 90;   // space for axes/header
const DM_EXTRA_OFFSET = 20 * 60; // +20 minutes for dm offset

/* =========================================================
   COMPONENT
   ========================================================= */

export default function GanttChart({ schema, table }) {
  const [data, setData] = useState([]);
  const [error, setError] = useState(null);

  /* ----------------------------------------------------- */
  /* LOAD DATA                                             */
  /* ----------------------------------------------------- */

  useEffect(() => {
    if (!schema || !table) return;

    fetch(`${API_BASE}/api/gantt/${schema}/${table}`)
      .then((res) =>
        res.ok ? res.json() : Promise.reject("Не удалось загрузить данные")
      )
      .then((raw) => {
        const latestByTable = Object.values(
          raw.reduce((acc, r) => {
            const start = new Date(r.start).getTime();
            const end = new Date(r.end).getTime();

            acc[r.table_name] = {
              name: r.table_name,
              schema: r.table_name.split(".")[0],
              start,
              end,
              duration: (end - start) / 1000,
              offset: start,
              is_bad: r.is_bad,
            };
            return acc;
          }, {})
        );

        setData(latestByTable);
      })
      .catch(setError);
  }, [schema, table]);

  if (error) {
    return <div className="card-error">Ошибка: {error}</div>;
  }

  if (!data.length) {
    return <div className="card-muted">Нет данных</div>;
  }

  /* ----------------------------------------------------- */
  /* PREPARE DATA                                          */
  /* ----------------------------------------------------- */

  const minStart = Math.min(...data.map((d) => d.offset));

  // soft duration cap (no logs)
  const normalizeDuration = (seconds) => {
    const min = 6;
    const max = 140;
    return Math.min(Math.max(seconds, min), max);
  };

  const sortedData = [...data].sort((a, b) => {
    const pa = SCHEMA_PRIORITY[a.schema] ?? SCHEMA_PRIORITY.default;
    const pb = SCHEMA_PRIORITY[b.schema] ?? SCHEMA_PRIORITY.default;
    if (pa !== pb) return pa - pb;
    return a.name.localeCompare(b.name);
  });

  const prepared = sortedData.map((d) => {
    const isDm = d.schema === "dm";
    return {
      ...d,
      offset:
        d.offset -
        minStart +
        (isDm ? DM_EXTRA_OFFSET : 0),
      visualDuration: normalizeDuration(d.duration),
    };
  });

  const maxX =
    Math.max(...prepared.map((d) => d.offset + d.visualDuration)) + 60;

  /* ----------------------------------------------------- */
  /* RENDER                                                */
  /* ----------------------------------------------------- */

  return (
    <div
      style={{
        borderRadius: 16,
        padding: "18px 20px",
        background:
          "linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015))",
        border: "1px solid rgba(255,255,255,.08)",
        marginTop: 24,
      }}
    >
      {/* HEADER */}
      <div
        style={{
          fontSize: 14,
          fontWeight: 600,
          marginBottom: 14,
          color: "#e5e7eb",
        }}
      >
        Таймлайн загрузки зависимостей
      </div>

      {/* CHART */}
      <div
        style={{
          height: prepared.length * ROW_HEIGHT + HEADER_OFFSET,
          minHeight: 520,
          width: "100%",
          minWidth: 1400,
        }}
      >
        <ResponsiveContainer width="100%" height="100%">
          <BarChart
            layout="vertical"
            data={prepared}
            barCategoryGap={12}
            barSize={28}
            margin={{ left: 300, right: 120, top: 20, bottom: 20 }}
          >
            <XAxis
              type="number"
              domain={[0, maxX]}
              tickFormatter={(v) =>
                new Date(minStart + v * 1000).toLocaleTimeString("ru-RU")
              }
              tick={{ fill: "#9ca3af", fontSize: 11 }}
              axisLine={{ stroke: "rgba(255,255,255,.1)" }}
              tickLine={{ stroke: "rgba(255,255,255,.1)" }}
            />

            <YAxis
              type="category"
              dataKey="name"
              width={300}
              interval={0}
              tick={{
                fontFamily: "monospace",
                fontSize: 12,
                fill: "#e5e7eb",
              }}
            />

            <Tooltip
              wrapperStyle={{ pointerEvents: "none" }}
              content={({ payload }) => {
                if (!payload?.length) return null;
                const d = payload[1]?.payload;
                if (!d) return null;

                return (
                  <div
                    style={{
                      background:
                        "linear-gradient(180deg,#020617,#020617dd)",
                      border: "1px solid rgba(255,255,255,.18)",
                      padding: "10px 12px",
                      borderRadius: 8,
                      boxShadow: "0 12px 32px rgba(0,0,0,.6)",
                      color: "#e5e7eb",
                      fontSize: 12,
                      maxWidth: 280,
                    }}
                  >
                    <div
                      style={{
                        fontFamily: "monospace",
                        fontWeight: 600,
                        marginBottom: 6,
                      }}
                    >
                      {d.name}
                    </div>
                    <div>
                      Duration:{" "}
                      {Math.round(d.duration / 60)} min
                    </div>
                    {d.is_bad && (
                      <div
                        style={{
                          color: "#f87171",
                          marginTop: 6,
                        }}
                      >
                        ⚠ blocks downstream marts
                      </div>
                    )}
                  </div>
                );
              }}
            />

            {/* invisible offset */}
            <Bar dataKey="offset" stackId="a" fill="transparent" />

            {/* actual bars */}
            <Bar
              dataKey="visualDuration"
              stackId="a"
              isAnimationActive={false}
              shape={({ x, y, width, height, payload, index }) => (
                <>
                  {/* row background for grid */}
                  <rect
                    x={0}
                    y={y - 6}
                    width={maxX + 200}
                    height={height + 12}
                    fill={
                      index % 2 === 0
                        ? "rgba(255,255,255,0.02)"
                        : "rgba(255,255,255,0.035)"
                    }
                  />

                  <rect
                    x={x}
                    y={y}
                    width={Math.max(width, 6)}
                    height={height}
                    rx={4}
                    fill={
                      schemaColorMap[payload.schema] ||
                      schemaColorMap.default
                    }
                    stroke={
                      payload.schema === "dm"
                        ? "#60a5fa"
                        : payload.is_bad
                        ? "#f87171"
                        : "rgba(0,0,0,.35)"
                    }
                    strokeWidth={
                      payload.schema === "dm" ? 2 : 1
                    }
                  />
                </>
              )}
            />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
