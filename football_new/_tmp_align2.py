# -*- coding: utf-8 -*-
from pathlib import Path
path = Path('frontend/src/pages/MatchSchedulePage.jsx')
text = path.read_text(encoding='utf-8')
old = '                <div className="flex items-center gap-2 min-w-0">'
new = '                <div className="flex items-center gap-2 min-w-0 justify-self-start text-left md:min-w-[180px]">'
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected 1 occurrence left, found {count}')
text = text.replace(old, new, 1)
text = text.replace('className="shrink-0"', 'className="shrink-0 h-7 w-7 rounded-full border border-gray-200 bg-white grid place-items-center"')
path.write_text(text, encoding='utf-8')
