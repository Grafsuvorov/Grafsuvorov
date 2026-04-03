# -*- coding: utf-8 -*-
from pathlib import Path
path = Path('frontend/src/pages/MatchSchedulePage.jsx')
text = path.read_text(encoding='utf-8')
old_block = '{/* 4-�: ����� */}\n                <div className="flex items-center gap-2 min-w-0">'
new_block = '{/* 4-�: ����� */}\n                <div className="flex items-center gap-2 min-w-0 justify-self-start text-left md:min-w-[180px]">'
if old_block not in text:
    raise SystemExit('away block signature not found')
text = text.replace(old_block, new_block, 1)
text = text.replace('className="shrink-0"', 'className="shrink-0 h-7 w-7 rounded-full border border-gray-200 bg-white grid place-items-center"')
path.write_text(text, encoding='utf-8')
