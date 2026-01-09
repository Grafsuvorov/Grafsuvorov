# -*- coding: utf-8 -*-
from pathlib import Path
path=Path('frontend/src/pages/MatchSchedulePage.jsx')
text=path.read_text(encoding='utf-8')
old_block="""                <div className=\"flex items-center gap-1\">\r\n                  <span className=\"px-1.5 py-0.5 rounded border bg-white text-[11px] tabular-nums text-gray-600\">\r\n                    {toDDMM(m.date)}\r\n                  </span>\r\n                  <span className={`px-1.5 py-0.5 rounded text-[11px] ${resultBadgeClasses(r)}`}>{r || \"-\"}</span>\r\n                </div>\r\n"""
new_block="""                <span className=\"inline-flex min-w-[70px] justify-center px-1.5 py-0.5 rounded border bg-white text-[11px] tabular-nums\">\r\n                  {toDDMM(m.date)}\r\n                </span>\r\n"""
if old_block not in text:
    raise SystemExit('target block not found')
text=text.replace(old_block,new_block,1)
path.write_text(text,encoding='utf-8')
