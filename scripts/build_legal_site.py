from pathlib import Path
import markdown

ROOT = Path(__file__).resolve().parents[1]
LEGAL = ROOT / "legal"

STYLE = """
<style>
:root { color-scheme: light; }
body { margin: 0; background: #f5f7fb; color: #17233c; font-family: Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.65; }
main { max-width: 980px; margin: 40px auto; padding: 0 22px 64px; }
article { background: #fff; border: 1px solid #e4e9f2; border-radius: 16px; padding: 32px 38px; box-shadow: 0 8px 28px rgba(23,35,60,.06); }
h1 { color: #0e2347; line-height: 1.2; } h2 { color: #174a88; margin-top: 2em; }
a { color: #1464c4; } table { width: 100%; border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid #dfe5ef; padding: 9px 11px; text-align: left; vertical-align: top; } th { background: #eef4fb; }
footer { max-width: 980px; margin: 18px auto; padding: 0 22px; color: #63708a; font-size: .9rem; }
nav { margin-bottom: 18px; }
</style>
"""

def render(source: Path, target: Path):
    body = markdown.markdown(source.read_text(encoding="utf-8"), extensions=["tables", "fenced_code"])
    html = f'''<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>ENTPA - {source.stem}</title>{STYLE}</head>
<body><main><nav><a href="index.html">ENTPA Legal Bilgilendirme</a> · <a href="privacy-policy.html">Gizlilik Politikası</a> · <a href="kvkk.html">KVKK Aydınlatma Metni</a></nav><article>{body}</article></main><footer>ENTPA Elektronik Cihazlar Tic. Paz. ve Turizm A.Ş. · ekerim@entpa.com.tr</footer></body></html>'''
    target.write_text(html, encoding="utf-8")

render(LEGAL / "index.md", LEGAL / "index.html")
render(LEGAL / "privacy-policy.md", LEGAL / "privacy-policy.html")
render(LEGAL / "kvkk.md", LEGAL / "kvkk.html")
