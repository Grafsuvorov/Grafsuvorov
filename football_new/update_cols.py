from pathlib import Path
path = Path('frontend/src/pages/MatchSchedulePage.jsx')
text = path.read_text(encoding='utf-8')
old_grid = 'const GRID_COLS = "grid-cols-[94px,minmax(0,1fr),88px,minmax(0,1fr)] md:grid-cols-[120px,minmax(0,1fr),100px,minmax(0,1fr)]";'
new_grid = 'const GRID_COLS = "grid-cols-[90px,1fr,80px,1fr] md:grid-cols-[110px,1fr,80px,1fr]";'
if old_grid not in text:
    raise SystemExit('grid marker not found')
text = text.replace(old_grid, new_grid, 1)
home_old = 'className="flex items-center gap-2 min-w-0 justify-self-end text-right"'
home_new = 'className="flex items-center gap-2 min-w-0 justify-self-end text-right md:min-w-[150px]"'
if text.count(home_old) < 2:
    raise SystemExit('home marker missing')
text = text.replace(home_old, home_new, 2)
away_old = 'className="flex items-center gap-2 min-w-0 justify-self-start text-left"'
away_new = 'className="flex items-center gap-2 min-w-0 justify-self-start text-left md:min-w-[150px]"'
if text.count(away_old) < 2:
    raise SystemExit('away marker missing')
text = text.replace(away_old, away_new, 2)
block_start = text.index('                <DateCell date={m.date} result={r} />')
block_end = block_start + len('                <DateCell date={m.date} result={r} />')
text = text[:block_start] + '                <span className="inline-flex min-w-[60px] justify-center px-1.5 py-0.5 rounded border bg-white tabular-nums">\n                  {toDDMM(m.date)}\n                </span>\n' + text[block_end+1:]
Path('frontend/src/pages/MatchSchedulePage.jsx').write_text(text, encoding='utf-8')
