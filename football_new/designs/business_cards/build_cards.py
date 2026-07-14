from __future__ import annotations

import base64
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DOWNLOADS = Path.home() / "Downloads"

PHOTO = DOWNLOADS / "ChatGPT Image 13 мая 2026 г., 00_03_24.png"
QR = DOWNLOADS / "IMG_7939.JPG"
SHOE = DOWNLOADS / "copy_FD6623A8-86B9-4F33-8C4F-94138AA8A6EA.PNG"

WIDTH = 1080
HEIGHT = 600
CARD_W_MM = 90
CARD_H_MM = 50


def data_uri(path: Path) -> str:
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    mime = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
    }[path.suffix.lower()]
    return f"data:{mime};base64,{encoded}"


PHOTO_URI = data_uri(PHOTO)
QR_URI = data_uri(QR)
SHOE_URI = data_uri(SHOE)


def svg(doc: str, defs: str = "", bg: str = "#ffffff") -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CARD_W_MM}mm" height="{CARD_H_MM}mm" viewBox="0 0 {WIDTH} {HEIGHT}" fill="none">
  <defs>
    <style>
      .serif {{ font-family: "Cormorant Garamond", "Bodoni 72", "Times New Roman", serif; }}
      .sans {{ font-family: "Helvetica Neue", Helvetica, Arial, sans-serif; }}
      .caps {{ letter-spacing: 0.18em; text-transform: uppercase; }}
    </style>
    <filter id="blur24"><feGaussianBlur stdDeviation="24"/></filter>
    <filter id="blur40"><feGaussianBlur stdDeviation="40"/></filter>
    <linearGradient id="lilacGlow" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#f4ebff"/>
      <stop offset="100%" stop-color="#d5b8f5"/>
    </linearGradient>
    <linearGradient id="darkLilac" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#171118"/>
      <stop offset="100%" stop-color="#302033"/>
    </linearGradient>
    {defs}
  </defs>
  <rect width="{WIDTH}" height="{HEIGHT}" fill="{bg}" />
  {doc}
</svg>
"""


def qr_card(x: int, y: int, size: int, panel: str, stroke: str, user_fill: str, label_fill: str) -> str:
    total_h = size + 76
    return f"""
  <rect x="{x}" y="{y}" width="{size}" height="{total_h}" rx="28" fill="{panel}" stroke="{stroke}" stroke-width="2" />
  <image href="{QR_URI}" x="{x + 22}" y="{y + 20}" width="{size - 44}" height="{size - 44}" preserveAspectRatio="xMidYMid slice" />
  <text x="{x + size/2}" y="{y + size + 24}" text-anchor="middle" class="sans caps" font-size="16" fill="{label_fill}">Instagram</text>
  <text x="{x + size/2}" y="{y + size + 56}" text-anchor="middle" class="sans" font-size="34" font-weight="700" fill="{user_fill}">@_DRAGON_MOM</text>
"""


def photo_panel(x: int, y: int, w: int, h: int, radius: int, defs_id: str, overlay: str = "") -> tuple[str, str]:
    defs = f'<clipPath id="{defs_id}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" /></clipPath>'
    group = f"""
  <g clip-path="url(#{defs_id})">
    <image href="{PHOTO_URI}" x="{x - 90}" y="{y - 80}" width="{w + 260}" height="{h + 160}" preserveAspectRatio="xMidYMid slice" />
    {overlay}
  </g>
"""
    return defs, group


def concept_a_front() -> str:
    defs, image = photo_panel(
        728,
        52,
        286,
        496,
        24,
        "photo_a_front",
        '<rect x="728" y="52" width="286" height="496" rx="24" fill="#ae84d4" opacity="0.14" />',
    )
    doc = f"""
  <rect x="24" y="24" width="1032" height="552" rx="30" fill="#fffdfd" stroke="#eadcf3" stroke-width="2" />
  <circle cx="910" cy="88" r="90" fill="#efe0fb" opacity="0.7" filter="url(#blur24)" />
  <text x="88" y="106" class="sans caps" font-size="18" fill="#9a75bc">Dance studio</text>
  <text x="88" y="190" class="serif" font-size="86" fill="#19131d">Танцы</text>
  <text x="88" y="246" class="serif" font-size="52" fill="#9a75bc" font-style="italic">для девушек</text>
  <line x1="90" y1="284" x2="640" y2="284" stroke="#eadcf3" stroke-width="2" />
  <text x="88" y="350" class="sans caps" font-size="19" fill="#7f6797">Frame up</text>
  <text x="88" y="402" class="sans caps" font-size="19" fill="#7f6797">Strip</text>
  <text x="88" y="454" class="sans caps" font-size="19" fill="#7f6797">Twerk</text>
  <text x="230" y="350" class="sans" font-size="34" fill="#1c1520">женственная пластика</text>
  <text x="230" y="402" class="sans" font-size="34" fill="#1c1520">уверенность и подача</text>
  <text x="230" y="454" class="sans" font-size="34" fill="#1c1520">энергия и сцена</text>
  <rect x="86" y="500" width="420" height="46" rx="23" fill="#f5edf9" />
  <text x="296" y="530" text-anchor="middle" class="sans" font-size="29" font-weight="700" fill="#8d62b2">Пробное занятие 500 ₽</text>
  {image}
  <rect x="728" y="52" width="286" height="496" rx="24" stroke="#eadcf3" stroke-width="2" />
"""
    return svg(doc, defs)


def concept_a_back() -> str:
    doc = f"""
  <rect x="24" y="24" width="1032" height="552" rx="30" fill="url(#darkLilac)" />
  <circle cx="165" cy="154" r="120" fill="#5f3e77" opacity="0.46" filter="url(#blur40)" />
  <circle cx="924" cy="456" r="138" fill="#ba8ee8" opacity="0.24" filter="url(#blur40)" />
  <text x="88" y="114" class="serif" font-size="68" fill="#fffafc">Танцы</text>
  <text x="88" y="160" class="serif" font-size="42" fill="#d4b5ef" font-style="italic">для девушек</text>
  <text x="88" y="230" class="sans caps" font-size="18" fill="#eddcfb">Запись через Instagram</text>
  <text x="88" y="286" class="sans" font-size="31" fill="#fffafc">Отсканируй QR и напиши в директ.</text>
  <text x="88" y="328" class="sans" font-size="31" fill="#fffafc">Первое занятие: 500 ₽</text>
  <text x="88" y="392" class="sans caps" font-size="16" fill="#bca0d4">Направления</text>
  <text x="88" y="430" class="sans" font-size="29" fill="#fffafc">Frame up   ·   Strip   ·   Twerk</text>
  {qr_card(712, 112, 256, "#fffdfd", "#eadcf3", "#171118", "#8c69ac")}
  <g opacity="0.18">
    <image href="{SHOE_URI}" x="454" y="310" width="210" height="250" preserveAspectRatio="xMidYMid meet" />
  </g>
"""
    return svg(doc, bg="#171118")


def concept_b_front() -> str:
    defs, image = photo_panel(
        0,
        0,
        422,
        600,
        0,
        "photo_b_front",
        """
    <rect x="0" y="0" width="422" height="600" fill="#171118" opacity="0.36" />
    <rect x="0" y="0" width="422" height="600" fill="#be94e2" opacity="0.10" />
""",
    )
    doc = f"""
  <rect width="{WIDTH}" height="{HEIGHT}" fill="#171118" />
  {image}
  <rect x="422" y="0" width="658" height="600" fill="#fffdfd" />
  <circle cx="992" cy="72" r="86" fill="#f3e7fc" opacity="0.9" filter="url(#blur24)" />
  <text x="486" y="102" class="sans caps" font-size="18" fill="#9670b8">Dance card</text>
  <text x="482" y="188" class="serif" font-size="84" fill="#171118">Танцы</text>
  <text x="482" y="244" class="serif" font-size="50" fill="#966fba" font-style="italic">для девушек</text>
  <text x="482" y="334" class="sans caps" font-size="20" fill="#7f6797">Frame up</text>
  <text x="482" y="392" class="sans caps" font-size="20" fill="#7f6797">Strip</text>
  <text x="482" y="450" class="sans caps" font-size="20" fill="#7f6797">Twerk</text>
  <rect x="478" y="496" width="390" height="46" rx="23" fill="#f4ebfb" />
  <text x="673" y="526" text-anchor="middle" class="sans" font-size="29" font-weight="700" fill="#8d62b2">Пробное занятие 500 ₽</text>
  <g opacity="0.26">
    <image href="{SHOE_URI}" x="816" y="286" width="218" height="262" preserveAspectRatio="xMidYMid meet" />
  </g>
"""
    return svg(doc, defs, bg="#171118")


def concept_b_back() -> str:
    doc = f"""
  <rect width="{WIDTH}" height="{HEIGHT}" fill="#fffdfd" />
  <rect x="32" y="32" width="1016" height="536" rx="28" fill="white" stroke="#eadcf3" stroke-width="2" />
  <circle cx="150" cy="470" r="118" fill="#f2e6fc" opacity="0.8" filter="url(#blur24)" />
  <text x="88" y="112" class="serif" font-size="64" fill="#171118">Instagram</text>
  <text x="88" y="160" class="sans caps" font-size="18" fill="#9b77bc">Запись на занятия</text>
  <text x="88" y="240" class="sans" font-size="31" fill="#1a141d">Frame up, Strip, Twerk</text>
  <text x="88" y="286" class="sans" font-size="31" fill="#1a141d">Для девушек любого уровня подготовки</text>
  <text x="88" y="360" class="sans" font-size="31" fill="#1a141d">Пробное занятие: 500 ₽</text>
  <text x="88" y="444" class="sans caps" font-size="16" fill="#9b77bc">Direct / booking</text>
  <text x="88" y="486" class="sans" font-size="38" font-weight="700" fill="#171118">@_DRAGON_MOM</text>
  {qr_card(728, 126, 240, "#faf5fd", "#eadcf3", "#171118", "#8c69ac")}
  <g opacity="0.18">
    <image href="{SHOE_URI}" x="542" y="374" width="170" height="202" preserveAspectRatio="xMidYMid meet" />
  </g>
"""
    return svg(doc)


def build_preview(files: list[str]) -> str:
    cards = "\n".join(
        f"""
    <section class="item">
      <h2>{name.replace('_', ' ').replace('.svg', '')}</h2>
      <img src="{name}" alt="{name}" />
    </section>
"""
        for name in files
    )
    return f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Business Cards Preview</title>
  <style>
    body {{
      margin: 0;
      padding: 32px;
      background: #141016;
      color: #faf7fd;
      font-family: "Helvetica Neue", Helvetica, Arial, sans-serif;
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: 30px;
    }}
    p {{
      margin: 0 0 28px;
      max-width: 880px;
      color: #cbbbd8;
      line-height: 1.45;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
      gap: 20px;
    }}
    .item {{
      background: #1d1720;
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 22px;
      padding: 16px;
    }}
    h2 {{
      margin: 0 0 12px;
      font-size: 14px;
      color: #d9c9e5;
      letter-spacing: 0.16em;
      text-transform: uppercase;
    }}
    img {{
      width: 100%;
      display: block;
      border-radius: 16px;
      background: white;
    }}
  </style>
</head>
<body>
  <h1>Аккуратные варианты визитки</h1>
  <p>Оба концепта сделаны в пропорции стандартной визитки 90x50 мм. Первый более спокойный и дорогой, второй чуть контрастнее и ближе к fashion-подаче. У обоих есть лицевая и оборотная сторона.</p>
  <div class="grid">
    {cards}
  </div>
</body>
</html>
"""


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    files = {
        "concept_a_front.svg": concept_a_front(),
        "concept_a_back.svg": concept_a_back(),
        "concept_b_front.svg": concept_b_front(),
        "concept_b_back.svg": concept_b_back(),
    }
    for name, content in files.items():
        (ROOT / name).write_text(content, encoding="utf-8")
    (ROOT / "preview.html").write_text(build_preview(list(files)), encoding="utf-8")


if __name__ == "__main__":
    main()
