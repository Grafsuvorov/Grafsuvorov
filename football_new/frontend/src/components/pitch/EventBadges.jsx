// src/components/pitch/EventBadges.jsx
import React from "react";
import { ratingClasses } from "@/lib/ratingColor";

export default function EventBadges({ meta = {}, rating, goals, assists, isMVP }) {
  const Card = ({ color, text }) => (
    <span
      className={`px-1 py-[1px] rounded text-[9px] font-semibold text-white shadow ${
        color === "y" ? "bg-amber-500" : "bg-rose-600"
      }`}
    >
      {text}
    </span>
  );

  const g = Number(goals || meta.goals || 0);
  const a = Number(assists || meta.assists || 0);

  const r = Number(rating);
  const pillCls = rating != null ? ratingClasses(r, isMVP) : "bg-surface-2/80 text-slate-200 border border-glass";

  return (
    <>
      {(meta.yellow > 0 || meta.red > 0) && (
        <div className="absolute -bottom-2 -left-2 flex gap-0.5">
          {meta.yellow > 0 && <Card color="y" text={`🟨${meta.yellow > 1 ? `×${meta.yellow}` : ""}`} />}
          {meta.red > 0 && <Card color="r" text={`🟥${meta.red > 1 ? `×${meta.red}` : ""}`} />}
        </div>
      )}

      {(meta.subInMin != null || meta.subOutMin != null) && (
        <div className="absolute top-1/2 -translate-y-1/2 -right-3 flex flex-col gap-0.5">
          {meta.subInMin != null && (
            <span className="px-1 text-[9px] rounded bg-emerald-600 text-white shadow" title={`IN ${meta.subInMin}'`}>
              ↗︎
            </span>
          )}
          {meta.subOutMin != null && (
            <span className="px-1 text-[9px] rounded bg-rose-600 text-white shadow" title={`OUT ${meta.subOutMin}'`}>
              ↘︎
            </span>
          )}
        </div>
      )}

      {rating != null && (
        <div className={`absolute -bottom-2 left-1/2 -translate-x-1/2 px-1 py-0.5 rounded shadow text-[10px] ${pillCls}`}>
          {isMVP && <span className="mr-0.5">⭐</span>}
          {Number(rating).toFixed(1)}
        </div>
      )}

      {g > 0 && (
        <div className="absolute -top-2 -left-2">
          <span className="px-1 py-[1px] text-[10px] rounded bg-surface-1/80 text-white shadow border border-glass">⚽{g > 1 ? `×${g}` : ""}</span>
        </div>
      )}
      {a > 0 && (
        <div className="absolute -top-2 -right-2">
          <span className="px-1 py-[1px] text-[10px] rounded bg-surface-1/80 text-white shadow border border-glass font-bold">
            A{a > 1 ? `×${a}` : ""}
          </span>
        </div>
      )}
    </>
  );
}
