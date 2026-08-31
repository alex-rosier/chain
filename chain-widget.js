// ═══════════════════════════════════════════════════════════════
//  Chain — iOS home screen widget (Scriptable)
//
//  Install: Scriptable app → + → paste this → name it "Chain"
//  Then long-press the home screen → + → Scriptable → pick a size
//  → tap the widget → Script: Chain, When Interacting: Open URL → APP_URL
//
//  macOS Sonoma or later shows iPhone widgets on the Mac desktop
//  (System Settings → Desktop & Dock → Widgets → Use iPhone widgets),
//  so this one script covers both screens.
// ═══════════════════════════════════════════════════════════════

const SUPABASE_URL = "https://owuractrglhippvuilxa.supabase.co";
const SUPABASE_KEY = "PASTE_PUBLISHABLE_KEY_HERE";   // ← fill this in, in Scriptable only
const APP_URL      = "https://alex-rosier.github.io/chain/";

const MARKER  = new Color("#D33726");
const MARKER_D= new Color("#FF5240");
const PAPER   = new Color("#FBFAF7");
const PAPER_D = new Color("#141416");
const INK     = new Color("#17161A");
const INK_D   = new Color("#F2EFE9");
const FAINT   = new Color("#D8D3CA");
const FAINT_D = new Color("#39383B");

const dark    = Device.isUsingDarkAppearance();
const marker  = dark ? MARKER_D : MARKER;
const paper   = dark ? PAPER_D  : PAPER;
const ink     = dark ? INK_D    : INK;
const faint   = dark ? FAINT_D  : FAINT;

// ── data ──────────────────────────────────────────────────────
const CACHE = FileManager.local().joinPath(
  FileManager.local().cacheDirectory(), "chain-status.json");

async function fetchStatus() {
  const req = new Request(`${SUPABASE_URL}/rest/v1/rpc/chain_status`);
  req.method = "POST";
  req.headers = {
    apikey: SUPABASE_KEY,
    Authorization: `Bearer ${SUPABASE_KEY}`,
    "Content-Type": "application/json"
  };
  req.body = "{}";
  req.timeoutInterval = 12;
  const rows = await req.loadJSON();
  const s = Array.isArray(rows) ? rows[0] : rows;
  if (!s) throw new Error("empty response");
  return { w: !!s.w, c: !!s.c, r: !!s.r, streak: s.streak | 0, stale: false };
}

async function getStatus() {
  try {
    const s = await fetchStatus();
    FileManager.local().writeString(CACHE, JSON.stringify({ ...s, at: Date.now() }));
    return s;
  } catch (e) {
    try {
      const c = JSON.parse(FileManager.local().readString(CACHE));
      return { ...c, stale: true };
    } catch (_) {
      return { w: false, c: false, r: false, streak: 0, stale: true, offline: true };
    }
  }
}

// ── the X, drawn the way the app draws it ─────────────────────
function xImage(w, c, r, size) {
  const dc = new DrawContext();
  dc.size = new Size(size, size);
  dc.opaque = false;
  dc.respectScreenScale = true;

  const pad = size * 0.14;
  dc.setLineWidth(size * 0.105);

  if (r) {                                   // rest day: a dashed ring
    dc.setStrokeColor(faint);
    dc.setLineWidth(size * 0.07);
    const inset = size * 0.16;
    dc.strokeEllipse(new Rect(inset, inset, size - inset * 2, size - inset * 2));
    return dc.getImage();
  }

  const stroke = (from, to, on) => {
    dc.setStrokeColor(on ? marker : faint);
    const p = new Path();
    p.move(from); p.addLine(to);
    dc.addPath(p); dc.strokePath();
  };
  // "\" is the workout, "/" is the content — same as the app
  stroke(new Point(pad, pad), new Point(size - pad, size - pad), w);
  stroke(new Point(size - pad, pad), new Point(pad, size - pad), c);
  return dc.getImage();
}

function label(stack, text, color, size, weight) {
  const t = stack.addText(text);
  t.textColor = color;
  t.font = weight === "bold" ? Font.semiboldSystemFont(size) : Font.systemFont(size);
  return t;
}

// ── layouts ───────────────────────────────────────────────────
function buildSmall(s) {
  const wdg = new ListWidget();
  wdg.backgroundColor = paper;
  wdg.setPadding(14, 14, 12, 14);

  const top = wdg.addStack();
  top.centerAlignContent();
  const tag = label(top, s.r ? "REST" : "CHAIN", dark ? FAINT_D : new Color("#8C877E"), 9.5, "bold");
  tag.font = Font.semiboldSystemFont(9.5);
  top.addSpacer();
  if (s.stale) label(top, "•", new Color("#8C877E"), 9.5);

  wdg.addSpacer(6);
  const mid = wdg.addStack();
  mid.addSpacer();
  mid.addImage(xImage(s.w, s.c, s.r, 150)).imageSize = new Size(58, 58);
  mid.addSpacer();
  wdg.addSpacer(8);

  const bot = wdg.addStack();
  bot.centerAlignContent();
  const n = bot.addText(String(s.streak));
  n.font = Font.semiboldRoundedSystemFont(26);
  n.textColor = ink;
  bot.addSpacer(5);
  const d = bot.addText(s.streak === 1 ? "day" : "days");
  d.font = Font.systemFont(11.5);
  d.textColor = new Color("#8C877E");
  bot.addSpacer();
  return wdg;
}

function buildMedium(s) {
  const wdg = new ListWidget();
  wdg.backgroundColor = paper;
  wdg.setPadding(16, 18, 16, 18);

  const row = wdg.addStack();
  row.centerAlignContent();

  row.addImage(xImage(s.w, s.c, s.r, 180)).imageSize = new Size(76, 76);
  row.addSpacer(18);

  const col = row.addStack();
  col.layoutVertically();

  const head = col.addStack();
  head.centerAlignContent();
  const n = head.addText(String(s.streak));
  n.font = Font.semiboldRoundedSystemFont(34);
  n.textColor = ink;
  head.addSpacer(6);
  const d = head.addText(s.streak === 1 ? "day chain" : "day chain");
  d.font = Font.systemFont(13);
  d.textColor = new Color("#8C877E");

  col.addSpacer(8);
  const line = (name, done) => {
    const r = col.addStack();
    r.centerAlignContent();
    const mark = r.addText(done ? "✓" : "○");
    mark.font = Font.semiboldSystemFont(12);
    mark.textColor = done ? marker : faint;
    r.addSpacer(7);
    const t = r.addText(name);
    t.font = Font.systemFont(13);
    t.textColor = done ? ink : new Color("#8C877E");
    col.addSpacer(3);
  };
  if (s.r) {
    const t = col.addText("Rest day — chain bridged");
    t.font = Font.systemFont(13);
    t.textColor = new Color("#8C877E");
  } else {
    line("Workout", s.w);
    line("Content", s.c);
  }
  row.addSpacer();
  return wdg;
}

// ── run ───────────────────────────────────────────────────────
const status = await getStatus();
const family = config.widgetFamily || "medium";
const widget = family === "small" ? buildSmall(status) : buildMedium(status);
widget.url = APP_URL;
widget.refreshAfterDate = new Date(Date.now() + 15 * 60 * 1000);

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  family === "small" ? widget.presentSmall() : widget.presentMedium();
}
Script.complete();
