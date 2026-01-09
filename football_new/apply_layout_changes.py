from pathlib import Path
path = Path('frontend/src/pages/MatchSchedulePage.jsx')
text = path.read_text(encoding='utf-8')
old_grid = 'const GRID_COLS = "grid-cols-[94px,minmax(0,1fr),88px,minmax(0,1fr)] md:grid-cols-[120px,minmax(0,1fr),100px,minmax(0,1fr)]";'
new_grid = 'const GRID_COLS = "grid-cols-[90px,1fr,80px,1fr] md:grid-cols-[110px,1fr,80px,1fr]";'
if old_grid not in text:
    raise SystemExit('grid const not found')
text = text.replace(old_grid, new_grid, 1)
start = text.index('function DateCell')
end = text.find('\r\n\r\n/*', start)
if end == -1:
    end = text.find('\n\n/*', start)
new_date = 'function DateCell({ date }) {\r\n  return (\r\n    <div className="flex w-full items-center">\r\n      <span className="inline-flex min-w-[70px] justify-center px-1.5 py-0.5 rounded border bg-white text-[11px] tabular-nums">\r\n        {toDDMM(date)}\r\n      </span>\r\n    </div>\r\n  );\r\n}\r\n'
text = text[:start] + new_date + text[end+2:]
old_call = '<DateCell date={m.date} result={r} />'
if old_call not in text:
    raise SystemExit('DateCell call not found')
text = text.replace(old_call, '<DateCell date={m.date} />', 1)
text = text.replace('className="flex items-center gap-2 min-w-0 justify-self-end text-right"',
                    'className="flex items-center gap-2 min-w-0 justify-self-end text-right md:min-w-[150px]"')
text = text.replace('className="flex items-center gap-2 min-w-0 justify-self-start text-left"',
                    'className="flex items-center gap-2 min-w-0 justify-self-start text-left md:min-w-[150px]"')
old_home = '                <div className="flex items-center gap-2 min-w-0 justify-self-end text-right md:min-w-[150px]">\r\n                  <button\r\n                    type="button"\r\n                    onClick={(e) => { e.stopPropagation(); onGoTeam?.(m.home_team_id); }}\r\n                    title="������ �������"\r\n                    className="shrink-0 h-7 w-7 rounded-full border border-gray-200 bg-white grid place-items-center"\r\n                  >\r\n                    <img className="w-4 h-4" src={logoSafe(m.home_team_id, m.home_team)} alt="" />\r\n                  </button>\r\n                  <span className="truncate text-right">{m.home_team}</span>\r\n                </div>\r\n'
new_home = '                <div className="flex items-center gap-2 min-w-0 justify-self-end text-right md:min-w-[150px]">\r\n                  <span className={`px-1.5 py-0.5 rounded text-[11px] ${resultBadgeClasses(r)}`}>
                    {r || "—"}
                  </span>\r\n                  <button\r\n                    type="button"\r\n                    onClick={(e) => { e.stopPropagation(); onGoTeam?.(m.home_team_id); }}\r\n                    title="������ �������"\r\n                    className="shrink-0 h-7 w-7 rounded-full border border-gray-200 bg-white grid place-items-center"\r\n                  >\r\n                    <img className="w-4 h-4" src={logoSafe(m.home_team_id, m.home_team)} alt="" />\r\n                  </button>\r\n                  <span className="truncate text-right">{m.home_team}</span>\r\n                </div>\r\n'
if old_home not in text:
    raise SystemExit('home block not found')
text = text.replace(old_home, new_home, 1)
path.write_text(text, encoding='utf-8')
