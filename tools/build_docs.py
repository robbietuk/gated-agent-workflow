"""Rebuild docs/slides/index.html and docs/guide/index.html.

Sources:  docs/src/slides/ (deck.json, deck.css, slides/<id>.html)
          docs/guide.md + docs/src/guide_template.html
Usage:    python3 tools/build_docs.py      (needs pandoc for the guide)
"""
import json, re, subprocess, pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
DECK = REPO / "docs" / "src" / "slides"
DOCS = REPO / "docs"
FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
         '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;600;700'
         '&family=Inter:wght@400;600;700&family=JetBrains+Mono:wght@400;600&display=swap">')

# ---------------------------------------------------------------- slides
deck = json.loads((DECK / "deck.json").read_text())
css = (DECK / "deck.css").read_text()
slides, notes = [], []
for sid in deck["order"]:
    h = (DECK / "slides" / f"{sid}.html").read_text()
    m = re.search(r"<aside>(.*?)</aside>", h, re.S)
    notes.append(m.group(1).strip() if m else "")
    slides.append(re.sub(r"<aside>.*?</aside>", "", h, flags=re.S))

viewer_css = """
html, body { margin: 0; height: 100%; background: #0E1422; overflow: hidden; }
#stage { position: absolute; left: 50%; top: 50%; width: 1920px; height: 1080px; transform-origin: center center; }
#stage > section { position: absolute; inset: 0; width: 1920px; height: 1080px; display: none; box-shadow: 0 20px 60px rgba(0,0,0,.45); }
#stage > section.on { display: flex; }
x-shape { display: block; }
x-shape[kind="arrow-right"] { clip-path: polygon(0 30%, 60% 30%, 60% 0, 100% 50%, 60% 100%, 60% 70%, 0 70%); }
#bar { position: fixed; left: 0; right: 0; bottom: 0; height: 44px; display: flex; align-items: center; gap: 12px;
       padding: 0 16px; font: 14px Inter, Arial, sans-serif; color: #B9C3D3; background: rgba(14,20,34,.85); }
#bar button { background: #172033; color: #F6F4EF; border: 1px solid #2A3550; border-radius: 6px; padding: 5px 12px; cursor: pointer; font: inherit; }
#bar button:hover { border-color: #5B4BD1; }
#prog { flex: 1; height: 4px; background: #2A3550; border-radius: 2px; overflow: hidden; }
#prog i { display: block; height: 100%; background: #5B4BD1; width: 0; transition: width .2s; }
#notes { position: fixed; left: 16px; right: 16px; bottom: 52px; max-width: 900px; margin: 0 auto; background: #F6F4EF; color: #172033;
         border-radius: 10px; padding: 14px 18px; font: 15px/1.5 Inter, Arial, sans-serif; display: none; box-shadow: 0 10px 30px rgba(0,0,0,.4); }
body.shownotes #notes { display: block; }
a.home { color: #B8AFF5; text-decoration: none; }
@media print {
  html, body { overflow: visible; background: none; }
  #bar, #notes { display: none !important; }
  #stage { position: static; transform: none !important; }
  #stage > section { display: flex !important; position: relative; break-after: page; box-shadow: none; }
  @page { size: 1920px 1080px; margin: 0; }
}
"""
viewer_js = """
const S = [...document.querySelectorAll('#stage > section')], N = %s;
let i = 0;
function fit() { const k = Math.min(innerWidth / 1920, (innerHeight - 44) / 1080) * 0.96;
  document.getElementById('stage').style.transform = `translate(-50%%, calc(-50%% - 22px)) scale(${k})`; }
function go(n) { i = Math.max(0, Math.min(S.length - 1, n)); S.forEach((s, j) => s.classList.toggle('on', j === i));
  document.getElementById('count').textContent = `${i + 1} / ${S.length}`;
  document.querySelector('#prog i').style.width = `${(i + 1) / S.length * 100}%%`;
  document.getElementById('notes').textContent = N[i] || 'No notes for this slide.';
  history.replaceState(null, '', '#' + (i + 1)); }
addEventListener('keydown', e => {
  if (['ArrowRight', 'PageDown', ' ', 'Enter'].includes(e.key)) { e.preventDefault(); go(i + 1); }
  else if (['ArrowLeft', 'PageUp', 'Backspace'].includes(e.key)) { e.preventDefault(); go(i - 1); }
  else if (e.key === 'Home') go(0); else if (e.key === 'End') go(S.length - 1);
  else if (e.key === 'n') document.body.classList.toggle('shownotes');
  else if (e.key === 'f') document.documentElement.requestFullscreen?.(); });
document.getElementById('stage').addEventListener('click', e => go(e.clientX > innerWidth / 2 ? i + 1 : i - 1));
document.getElementById('prev').onclick = () => go(i - 1);
document.getElementById('next').onclick = () => go(i + 1);
document.getElementById('nb').onclick = () => document.body.classList.toggle('shownotes');
addEventListener('resize', fit); fit();
go((parseInt(location.hash.slice(1)) || 1) - 1);
""" % json.dumps(notes)

slides_html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{deck['title']} · slides</title>{FONTS}
<style>{css}
{viewer_css}</style></head>
<body>
<div id="stage">
{''.join(slides)}
</div>
<div id="notes"></div>
<div id="bar"><a class="home" href="../index.html">◂ Docs</a><button id="prev" type="button">‹ Prev</button>
<button id="next" type="button">Next ›</button><div id="prog"><i></i></div><span id="count"></span>
<button id="nb" type="button">Notes (n)</button><span>← → keys · f fullscreen</span></div>
<script>{viewer_js}</script>
</body></html>
"""
(DOCS / "slides").mkdir(parents=True, exist_ok=True)
(DOCS / "slides" / "index.html").write_text(slides_html)

# ---------------------------------------------------------------- guide
md = (DOCS / "guide.md").read_text().split("\n", 1)[1]
body = subprocess.run(["pandoc", "-f", "gfm", "-t", "html5", "--toc", "--toc-depth=2", "-s",
                       "--template", str(REPO / "docs" / "src" / "guide_template.html"), "--metadata", "title=Agentic workflow guide"],
                      input=md, capture_output=True, text=True, check=True).stdout
body = body.replace('src="media/', 'src="../media/')
(DOCS / "guide").mkdir(parents=True, exist_ok=True)
(DOCS / "guide" / "index.html").write_text(body)
print("ok", len(slides), "slides")
