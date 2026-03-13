// Recycled Sound — Figma Wireframe Generator v3
// Design system components + reliable absolute-positioned wireframes

// ─── Colours ──────────────────────────────────────────────────
const C = {
  primary:      { r: 0.165, g: 0.490, b: 0.373 },
  primaryLight: { r: 0.910, g: 0.961, b: 0.933 },
  accent:       { r: 0.902, g: 0.494, b: 0.133 },
  text:         { r: 0.102, g: 0.102, b: 0.102 },
  muted:        { r: 0.420, g: 0.443, b: 0.498 },
  border:       { r: 0.820, g: 0.835, b: 0.855 },
  surface:      { r: 0.976, g: 0.980, b: 0.984 },
  white:        { r: 1, g: 1, b: 1 },
  black:        { r: 0.102, g: 0.102, b: 0.102 },
  ok:           { r: 0.063, g: 0.725, b: 0.506 },
  okLight:      { r: 0.820, g: 0.980, b: 0.898 },
  okDark:       { r: 0.024, g: 0.373, b: 0.275 },
  warn:         { r: 0.961, g: 0.620, b: 0.043 },
  warnLight:    { r: 0.996, g: 0.953, b: 0.780 },
  err:          { r: 0.937, g: 0.267, b: 0.267 },
  errLight:     { r: 0.996, g: 0.886, b: 0.886 },
  errDark:      { r: 0.600, g: 0.106, b: 0.106 },
  blueLight:    { r: 0.859, g: 0.914, b: 0.976 },
  blue:         { r: 0.118, g: 0.251, b: 0.686 },
  amberBg:      { r: 1.000, g: 0.984, b: 0.929 },
  amberBorder:  { r: 0.988, g: 0.827, b: 0.302 },
  amberText:    { r: 0.573, g: 0.251, b: 0.055 },
  chip:         { r: 0.953, g: 0.957, b: 0.965 },
  dark:         { r: 0.15, g: 0.15, b: 0.15 },
};

function s(c) { return c ? [{ type: 'SOLID', color: { r: c.r, g: c.g, b: c.b } }] : []; }
function noF() { return []; }

let _eb = null;
function w(weight) {
  if (weight === "Extra Bold") {
    if (_eb === null) {
      try { const t = figma.createText(); t.fontName = { family: "Inter", style: "Extra Bold" }; t.remove(); _eb = true; } catch (e) { _eb = false; }
    }
    return _eb ? "Extra Bold" : "Bold";
  }
  return weight || "Regular";
}

async function loadFonts() {
  for (const st of ["Regular", "Medium", "Semi Bold", "Bold"]) {
    await figma.loadFontAsync({ family: "Inter", style: st });
  }
  try { await figma.loadFontAsync({ family: "Inter", style: "Extra Bold" }); } catch (e) { /* ok */ }
}

// ─── Drawing helpers ──────────────────────────────────────────
function R(parent, name, x, y, ww, h, fill, radius, stroke, strokeW) {
  const r = figma.createRectangle();
  r.name = name || "Rect";
  r.x = x; r.y = y; r.resize(ww, h);
  r.fills = fill ? s(fill) : noF();
  if (radius != null) r.cornerRadius = radius;
  if (stroke) { r.strokes = s(stroke); r.strokeWeight = strokeW || 1; }
  parent.appendChild(r);
  return r;
}

function T(parent, name, x, y, text, size, weight, color, ww, align) {
  const t = figma.createText();
  t.name = name || "Text";
  t.x = x; t.y = y;
  t.fontName = { family: "Inter", style: w(weight || "Regular") };
  t.fontSize = size || 12;
  t.fills = s(color || C.text);
  t.characters = text;
  t.textAutoResize = "WIDTH_AND_HEIGHT";
  if (ww) { t.resize(ww, t.height); t.textAutoResize = "HEIGHT"; }
  if (align) t.textAlignHorizontal = align;
  parent.appendChild(t);
  return t;
}

function G(parent, name, x, y) {
  const f = figma.createFrame();
  f.name = name;
  f.x = x; f.y = y;
  f.resize(1, 1);
  f.fills = noF();
  f.clipsContent = false;
  parent.appendChild(f);
  return f;
}

// ─── Reusable UI patterns ─────────────────────────────────────
function chip(parent, x, y, label, bg, fg) {
  const cw = Math.max(label.length * 6 + 18, 36);
  const g = G(parent, "Chip: " + label, x, y);
  g.resize(cw, 22);
  R(g, "Bg", 0, 0, cw, 22, bg || C.chip, 6);
  T(g, "Label", 8, 4, label, 10, "Semi Bold", fg || C.muted);
  return cw;
}

function btn(parent, x, y, ww, h, label, style) {
  const bg = style === "primary" ? C.primary : style === "outline" ? C.white : C.surface;
  const fg = style === "primary" ? C.white : style === "outline" ? C.primary : C.text;
  const st = style === "outline" ? C.primary : style === "ghost" ? C.border : null;
  const g = G(parent, "Button: " + label, x, y);
  g.resize(ww, h);
  R(g, "Bg", 0, 0, ww, h, bg, 12, st, st ? 1.5 : 0);
  T(g, "Label", 0, (h - 14) / 2, label, 14, "Semi Bold", fg, ww, "CENTER");
  return g;
}

function navBar(parent, y, title, back, action) {
  const g = G(parent, "Nav Bar", 0, y);
  g.resize(280, 44);
  R(g, "Bg", 0, 0, 280, 44, C.white);
  R(g, "Border", 0, 43, 280, 1, C.border);
  if (back) T(g, "Back", 16, 12, "\u2039", 20, "Regular", C.primary);
  T(g, "Title", back ? 32 : 16, 14, title, 15, "Semi Bold", C.text);
  if (action) T(g, "Action", 220, 16, action, 12, "Semi Bold", C.primary);
  return y + 44;
}

function tabBar(parent, active) {
  const g = G(parent, "Tab Bar", 0, 496);
  g.resize(280, 64);
  R(g, "Bg", 0, 0, 280, 64, C.white);
  R(g, "Border", 0, 0, 280, 1, C.border);
  var tabs = ["Home", "Scan", "Devices", "Profile"];
  for (var i = 0; i < 4; i++) {
    var tx = 16 + i * 64;
    var isA = i === active;
    if (isA) R(g, "Active Bg", tx + 7, 8, 22, 22, C.primary, 4);
    else R(g, "Icon", tx + 7, 8, 22, 22, null, 4, C.muted, 1.5);
    T(g, tabs[i], tx, 34, tabs[i], 9, "Regular", isA ? C.primary : C.muted, 36, "CENTER");
  }
}

function specRow(parent, x, y, ww, label, value, checkColor) {
  T(parent, label, x, y, label, 11, "Regular", C.muted);
  var prefix = checkColor ? "\u2713 " : "";
  T(parent, "Val:" + label, x + ww * 0.5, y, prefix + value, 12, "Semi Bold", checkColor || C.text);
  return y + 20;
}

function inputField(parent, x, y, ww, label, value, filled) {
  T(parent, "Label:" + label, x, y, label.toUpperCase(), 10, "Semi Bold", C.muted, ww);
  R(parent, "Field:" + label, x, y + 16, ww, 36, filled ? C.primaryLight : C.surface, 8, filled ? C.primary : C.border, 1.5);
  T(parent, "Value:" + label, x + 12, y + 26, value, 13, "Regular", C.text);
  return y + 58;
}

function progressDots(parent, y, active, total) {
  var sw = 32, gap = 4;
  var startX = (280 - (total * sw + (total - 1) * gap)) / 2;
  for (var i = 0; i < total; i++) {
    var col = i < active ? C.ok : i === active ? C.primary : C.border;
    R(parent, "Step " + (i + 1), startX + i * (sw + gap), y, sw, 4, col, 2);
  }
  return y + 16;
}

function sectionHdr(parent, x, y, text) {
  T(parent, "Section: " + text, x, y, text, 13, "Bold", C.text, 248);
  return y + 20;
}

function annotation(parent, x, y, ww, text) {
  var h = Math.ceil(text.length / 40) * 14 + 24;
  var r = R(parent, "Annotation Bg", x, y, ww, h, C.amberBg, 8, C.amberBorder, 1);
  r.dashPattern = [4, 4];
  T(parent, "Note Label", x + 8, y + 6, "NOTE", 9, "Bold", C.amberText);
  T(parent, "Note Text", x + 8, y + 20, text, 10, "Regular", C.amberText, ww - 16);
  return y + h + 8;
}

function listItem(parent, y, title, sub, status, sBg, sFg) {
  var g = G(parent, "Item: " + title, 0, y);
  g.resize(280, 52);
  R(g, "Bg", 0, 0, 280, 52, C.white);
  R(g, "Divider", 0, 51, 280, 1, C.surface);
  R(g, "Avatar", 16, 8, 36, 36, C.blueLight, 10);
  T(g, "Emoji", 22, 16, "\uD83C\uDFA7", 16, "Regular", C.text);
  T(g, "Title", 62, 12, title, 13, "Semi Bold", C.text, 130);
  T(g, "Sub", 62, 28, sub, 11, "Regular", C.muted, 130);
  chip(g, 204, 16, status, sBg, sFg);
  return y + 52;
}

function confidenceRow(parent, x, y, ww, label, status, sBg, sFg, barW, barC) {
  T(parent, label, x, y, label, 11, "Regular", C.muted);
  chip(parent, x + ww - 60, y - 2, status, sBg, sFg);
  R(parent, "BarBg", x, y + 18, ww, 4, C.border, 2);
  R(parent, "BarFill", x, y + 18, barW, 4, barC, 2);
  return y + 30;
}

function toggleRow(parent, x, y, ww, label, sub, on) {
  T(parent, "Toggle:" + label, x, y, label, 12, "Semi Bold", C.text, ww - 60);
  if (sub) T(parent, "ToggleSub", x, y + 16, sub, 10, "Regular", C.muted, ww - 60);
  R(parent, "Track", x + ww - 40, y, 40, 22, on ? C.primary : C.border, 11);
  R(parent, "Knob", on ? x + ww - 20 : x + ww - 40 + 2, y + 2, 18, 18, C.white, 9);
  return y + (sub ? 36 : 28);
}

// ─── Phone Frame ──────────────────────────────────────────────
function phone(page, x, y, name) {
  var f = figma.createFrame();
  f.name = name;
  f.x = x; f.y = y;
  f.resize(280, 560);
  f.fills = s(C.white);
  f.cornerRadius = 32;
  f.clipsContent = true;
  f.strokes = s(C.black);
  f.strokeWeight = 3;
  page.appendChild(f);
  // Notch
  var n = R(f, "Notch", 90, 0, 100, 24, C.black, 0);
  n.topLeftRadius = 0; n.topRightRadius = 0;
  n.bottomLeftRadius = 16; n.bottomRightRadius = 16;
  // Status bar
  T(f, "Time", 20, 28, "9:41", 11, "Semi Bold", C.text);
  return f;
}

// ─── Screen Builders ──────────────────────────────────────────

function screen1A(page, x, y) {
  var p = phone(page, x, y, "1A. Home");
  // Hero
  R(p, "Icon Bg", 104, 60, 72, 72, C.primaryLight, 20);
  T(p, "Icon", 122, 78, "\uD83C\uDFB5", 32, "Regular", C.text);
  T(p, "Title", 0, 144, "Recycled Sound", 18, "Extra Bold", C.text, 280, "CENTER");
  T(p, "Tagline", 30, 168, "Give hearing aids a second life.\nScan, donate, match, connect.", 12, "Regular", C.muted, 220, "CENTER");
  // Buttons
  btn(p, 16, 206, 248, 48, "\uD83D\uDCF7  Scan a Hearing Aid", "primary");
  btn(p, 16, 262, 248, 42, "\uD83C\uDF81  Donate a Device", "outline");
  btn(p, 16, 312, 248, 42, "\uD83D\uDCCB  Browse Available Aids", "ghost");
  // Divider
  R(p, "Divider", 16, 366, 248, 1, C.border);
  // Stats
  T(p, "Stats Title", 16, 378, "Quick Stats", 13, "Bold", C.text);
  // Stat cards
  R(p, "Card1", 16, 398, 76, 56, C.white, 12, C.border, 1);
  T(p, "N1", 16, 406, "20", 22, "Extra Bold", C.primary, 76, "CENTER");
  T(p, "L1", 16, 432, "Devices", 10, "Regular", C.muted, 76, "CENTER");
  R(p, "Card2", 100, 398, 76, 56, C.white, 12, C.border, 1);
  T(p, "N2", 100, 406, "12", 22, "Extra Bold", C.accent, 76, "CENTER");
  T(p, "L2", 100, 432, "Awaiting QA", 10, "Regular", C.muted, 76, "CENTER");
  R(p, "Card3", 184, 398, 80, 56, C.white, 12, C.border, 1);
  T(p, "N3", 184, 406, "5", 22, "Extra Bold", C.ok, 80, "CENTER");
  T(p, "L3", 184, 432, "Matched", 10, "Regular", C.muted, 80, "CENTER");
  tabBar(p, 0);
}

function screen1B(page, x, y) {
  var p = phone(page, x, y, "1B. Camera Scanner");
  // Dark bg
  R(p, "Camera Bg", 0, 0, 280, 560, C.dark, 0);
  // Re-notch
  var n = R(p, "Notch", 90, 0, 100, 24, C.black, 0);
  n.topLeftRadius = 0; n.topRightRadius = 0; n.bottomLeftRadius = 16; n.bottomRightRadius = 16;
  T(p, "Time", 20, 28, "9:41", 11, "Semi Bold", C.white);
  // Top bar
  T(p, "Close", 20, 52, "\u2715", 14, "Regular", C.white);
  T(p, "Title", 90, 52, "Scan Hearing Aid", 12, "Semi Bold", C.white, 100, "CENTER");
  T(p, "Flash", 244, 52, "\u26A1", 14, "Regular", C.white);
  // Scan frame
  R(p, "Frame", 50, 120, 180, 180, null, 16, { r: 1, g: 1, b: 1 }, 1.5);
  // Corners
  R(p, "TL-H", 48, 118, 28, 3, C.primary); R(p, "TL-V", 48, 118, 3, 28, C.primary);
  R(p, "TR-H", 204, 118, 28, 3, C.primary); R(p, "TR-V", 229, 118, 3, 28, C.primary);
  R(p, "BL-H", 48, 297, 28, 3, C.primary); R(p, "BL-V", 48, 272, 3, 28, C.primary);
  R(p, "BR-H", 204, 297, 28, 3, C.primary); R(p, "BR-V", 229, 272, 3, 28, C.primary);
  // Placeholder
  T(p, "HA", 112, 185, "\uD83E\uDDBB", 40, "Regular", { r: 0.4, g: 0.4, b: 0.4 });
  // Instruction
  T(p, "Hint", 30, 320, "Position hearing aid within the frame", 12, "Regular", { r: 0.7, g: 0.7, b: 0.7 }, 220, "CENTER");
  // Shutter area
  R(p, "Gallery", 48, 440, 40, 40, { r: 0.25, g: 0.25, b: 0.25 }, 20);
  R(p, "Shutter Outer", 108, 430, 64, 64, C.white, 32);
  R(p, "Shutter Inner", 112, 434, 56, 56, null, 28, C.primary, 3);
  R(p, "Flip", 192, 440, 40, 40, { r: 0.25, g: 0.25, b: 0.25 }, 20);
  // Mode labels
  T(p, "M1", 52, 510, "Gallery", 11, "Regular", { r: 0.5, g: 0.5, b: 0.5 }, 56, "CENTER");
  T(p, "M2", 112, 510, "Photo", 11, "Semi Bold", C.white, 56, "CENTER");
  T(p, "M3", 172, 510, "Multi", 11, "Regular", { r: 0.5, g: 0.5, b: 0.5 }, 56, "CENTER");
}

function screen1C(page, x, y) {
  var p = phone(page, x, y, "1C. AI Analysing");
  var cy = navBar(p, 44, "Analysing...", true, "");
  // Photo
  R(p, "Photo Bg", 16, cy + 8, 248, 80, C.surface, 12, C.border, 1);
  T(p, "HA", 120, cy + 30, "\uD83E\uDDBB", 28, "Regular", C.muted);
  cy += 96;
  // Scanning indicator
  R(p, "Indicator Bg", 80, cy, 120, 28, C.primary, 14);
  T(p, "Indicator", 80, cy + 7, "Identifying device...", 11, "Semi Bold", C.white, 120, "CENTER");
  cy += 40;
  // Confidence rows
  cy = confidenceRow(p, 16, cy, 248, "Brand detection", "Done", C.okLight, C.okDark, 240, C.ok);
  cy = confidenceRow(p, 16, cy, 248, "Model identification", "Done", C.okLight, C.okDark, 235, C.ok);
  cy = confidenceRow(p, 16, cy, 248, "Battery type", "Done", C.okLight, C.okDark, 240, C.ok);
  cy = confidenceRow(p, 16, cy, 248, "Dome / mould type", "Analysing", C.warnLight, C.amberText, 180, C.warn);
  cy = confidenceRow(p, 16, cy, 248, "Technology level", "Estimating", C.warnLight, C.amberText, 100, C.err);
  cy += 8;
  annotation(p, 16, cy, 248, "AI confidence varies by attribute. Brand & model are high confidence. Tech level needs audiologist.");
}

function screen1D(page, x, y) {
  var p = phone(page, x, y, "1D. AI Results");
  var cy = navBar(p, 44, "Scan Results", true, "Edit");
  // Photo
  R(p, "Photo", 16, cy + 6, 248, 60, C.surface, 12, C.border, 1);
  T(p, "HA", 122, cy + 20, "\uD83E\uDDBB", 24, "Regular", C.muted);
  cy += 72;
  // Results card
  R(p, "Card Bg", 16, cy, 248, 196, C.white, 12, C.primary, 1.5);
  T(p, "Device Name", 28, cy + 10, "Phonak Audeo P90-R", 14, "Bold", C.text);
  chip(p, 198, cy + 10, "95%", C.okLight, C.okDark);
  var sy = cy + 32;
  sy = specRow(p, 28, sy, 220, "Brand", "Phonak");
  sy = specRow(p, 28, sy, 220, "Model", "Audeo Paradise P90-R");
  sy = specRow(p, 28, sy, 220, "Type", "RIC/RITE");
  sy = specRow(p, 28, sy, 220, "Year (est.)", "2021 \u270E");
  sy = specRow(p, 28, sy, 220, "Battery", "Rechargeable (Li-ion)");
  sy = specRow(p, 28, sy, 220, "Dome", "Open dome \u270E");
  sy = specRow(p, 28, sy, 220, "Wax Filter", "CeruShield Disk");
  sy = specRow(p, 28, sy, 220, "Receiver", "M receiver");
  cy += 204;
  // Warning
  R(p, "Warn Bg", 16, cy, 248, 56, C.amberBg, 12, C.amberBorder, 1);
  T(p, "Warn Icon", 28, cy + 6, "\uD83D\uDD0D", 14, "Regular", C.text);
  T(p, "Warn Title", 48, cy + 8, "Needs Audiologist Review", 12, "Bold", C.amberText, 200);
  T(p, "Warn Desc", 48, cy + 24, "Tech level, programming interface, and gain range require professional assessment.", 10, "Regular", C.amberText, 200);
  cy += 64;
  btn(p, 16, cy, 200, 42, "Add to Register", "primary");
  R(p, "Cam Btn", 224, cy, 40, 42, C.white, 12, C.primary, 1.5);
  T(p, "Cam Icon", 232, cy + 12, "\uD83D\uDCF7", 16, "Regular", C.primary);
}

function screen2A(page, x, y) {
  var p = phone(page, x, y, "2A. QA Queue");
  var cy = navBar(p, 44, "Devices Awaiting QA", false, "Filter");
  cy += 8;
  chip(p, 16, cy, "\u23F3 12 Pending", C.warnLight, C.amberText);
  chip(p, 118, cy, "\u2713 5 Passed", C.okLight, C.okDark);
  chip(p, 200, cy, "\u2717 2 Failed", C.errLight, C.errDark);
  cy += 30;
  cy = listItem(p, cy, "Phonak Audeo P90-R", "Donor: PL \u00B7 2d ago", "Pending", C.warnLight, C.amberText);
  cy = listItem(p, cy, "Unitron Moxi Next 4", "Donor: PL \u00B7 3d ago", "Pending", C.warnLight, C.amberText);
  cy = listItem(p, cy, "GN Resound LiNX 2", "Donor: JM \u00B7 5d ago", "Pending", C.warnLight, C.amberText);
  cy = listItem(p, cy, "Oticon Ria 2 P", "Donor: WR \u00B7 today", "Passed", C.okLight, C.okDark);
  cy = listItem(p, cy, "Signia Motion 13P", "Donor: JH \u00B7 yesterday", "Passed", C.okLight, C.okDark);
  cy = listItem(p, cy, "Blamey & Saunders", "Donor: EB \u00B7 broken", "Failed", C.errLight, C.errDark);
  tabBar(p, 2);
}

function screen2B(page, x, y) {
  var p = phone(page, x, y, "2B. Audiologist Review");
  var cy = navBar(p, 44, "Review Device", true, "Save");
  cy = progressDots(p, cy + 4, 2, 4);
  cy = sectionHdr(p, 16, cy, "AI-Identified (confirmed \u2713)");
  cy = specRow(p, 16, cy, 248, "Brand", "Phonak", C.ok);
  cy = specRow(p, 16, cy, 248, "Model", "Audeo P90-R", C.ok);
  cy = specRow(p, 16, cy, 248, "Type", "RIC/RITE", C.ok);
  cy = specRow(p, 16, cy, 248, "Battery", "Rechargeable", C.ok);
  R(p, "Divider", 16, cy + 2, 248, 1, C.border); cy += 10;
  cy = sectionHdr(p, 16, cy, "Audiologist Assessment");
  cy = inputField(p, 16, cy, 248, "Technology Level", "Premium (Level 9)");
  cy = inputField(p, 16, cy, 248, "Programming Interface", "Noahlink Wireless");
  cy = inputField(p, 16, cy, 248, "Gain Range", "Mild to Moderate");
  T(p, "Cond Label", 16, cy, "PHYSICAL CONDITION", 10, "Semi Bold", C.muted);
  cy += 16;
  chip(p, 16, cy, "Good", C.okLight, C.okDark);
  chip(p, 68, cy, "Fair", C.chip, C.muted);
  chip(p, 108, cy, "Poor", C.chip, C.muted);
  cy += 30;
  cy = toggleRow(p, 16, cy, 248, "Remote fine-tuning?", "", true);
  cy = toggleRow(p, 16, cy, 248, "App compatible?", "", true);
  cy = toggleRow(p, 16, cy, 248, "Auracast ready?", "", false);
  cy += 4;
  btn(p, 16, cy, 248, 42, "\u2713 Mark as QA Passed", "primary");
}

function screen2C(page, x, y) {
  var p = phone(page, x, y, "2C. Device Ready");
  var cy = navBar(p, 44, "Device Profile", true, "Share");
  // Success
  R(p, "Success Bg", 108, cy + 12, 64, 64, C.okLight, 32);
  T(p, "Check", 124, cy + 28, "\u2713", 28, "Bold", C.ok);
  T(p, "Name", 0, cy + 84, "Phonak Audeo P90-R", 16, "Bold", C.text, 280, "CENTER");
  T(p, "Status", 0, cy + 106, "QA Passed \u00B7 Ready for Matching", 12, "Regular", C.muted, 280, "CENTER");
  cy += 126;
  // Specs card
  R(p, "Specs Card", 16, cy, 248, 176, C.white, 12, C.border, 1);
  T(p, "Specs Hdr", 28, cy + 8, "DEVICE SPECIFICATIONS", 11, "Bold", C.muted);
  var sy = cy + 26;
  sy = specRow(p, 28, sy, 220, "Brand", "Phonak");
  sy = specRow(p, 28, sy, 220, "Model", "Audeo P90-R");
  sy = specRow(p, 28, sy, 220, "Type", "RIC/RITE");
  sy = specRow(p, 28, sy, 220, "Tech Level", "Premium (9)");
  sy = specRow(p, 28, sy, 220, "Fitting Range", "Mild\u2013Moderate");
  sy = specRow(p, 28, sy, 220, "Battery", "Rechargeable");
  sy = specRow(p, 28, sy, 220, "Programming", "Noahlink Wireless");
  cy += 184;
  // Features
  R(p, "Feat Card", 16, cy, 248, 42, C.white, 12, C.border, 1);
  T(p, "Feat Hdr", 28, cy + 6, "FEATURES", 11, "Bold", C.muted);
  chip(p, 28, cy + 22, "Remote Fine-Tuning", C.blueLight, C.blue);
  chip(p, 150, cy + 22, "App Compatible", C.blueLight, C.blue);
  cy += 50;
  // Lifecycle
  R(p, "LC Card", 16, cy, 248, 32, C.white, 12, C.border, 1);
  T(p, "LC Text", 28, cy + 10, "Donated \u2192 Scanned \u2192 QA'd \u2192 Matched", 10, "Semi Bold", C.muted);
  cy += 40;
  btn(p, 16, cy, 248, 42, "Find a Match", "primary");
}

function screen3A(page, x, y) {
  var p = phone(page, x, y, "3A. Donor Signup");
  var cy = navBar(p, 44, "Create Account", true, "");
  cy = progressDots(p, cy + 4, 0, 3);
  T(p, "Heading", 0, cy + 4, "I want to...", 15, "Bold", C.text, 280, "CENTER");
  T(p, "Sub", 0, cy + 24, "Select your role", 12, "Regular", C.muted, 280, "CENTER");
  cy += 48;
  // Donor (selected)
  R(p, "Role1 Bg", 16, cy, 248, 56, C.primaryLight, 12, C.primary, 1.5);
  T(p, "R1 Icon", 28, cy + 10, "\uD83C\uDF81", 24, "Regular", C.text);
  T(p, "R1 Title", 60, cy + 12, "Donate a Hearing Aid", 14, "Bold", C.primary);
  T(p, "R1 Sub", 60, cy + 30, "I have a device to give", 11, "Regular", C.muted);
  cy += 64;
  // Recipient
  R(p, "Role2 Bg", 16, cy, 248, 56, C.white, 12, C.border, 1);
  T(p, "R2 Icon", 28, cy + 10, "\uD83E\uDD1D", 24, "Regular", C.text);
  T(p, "R2 Title", 60, cy + 12, "Receive a Hearing Aid", 14, "Semi Bold", C.text);
  T(p, "R2 Sub", 60, cy + 30, "I need hearing support", 11, "Regular", C.muted);
  cy += 64;
  // Professional
  R(p, "Role3 Bg", 16, cy, 248, 56, C.white, 12, C.border, 1);
  T(p, "R3 Icon", 28, cy + 10, "\uD83E\uDE7A", 24, "Regular", C.text);
  T(p, "R3 Title", 60, cy + 12, "I'm a Hearing Professional", 14, "Semi Bold", C.text);
  T(p, "R3 Sub", 60, cy + 30, "Audiologist or clinic", 11, "Regular", C.muted);
  cy += 72;
  btn(p, 16, cy, 248, 42, "Continue", "primary");
}

function screen3B(page, x, y) {
  var p = phone(page, x, y, "3B. Donation Form");
  var cy = navBar(p, 44, "Donate a Device", true, "");
  cy = progressDots(p, cy + 4, 1, 3);
  cy = sectionHdr(p, 16, cy, "Device (from scan)");
  // Scanned device card
  R(p, "Dev Card", 16, cy, 248, 48, C.white, 12, C.border, 1);
  R(p, "Dev Icon Bg", 24, cy + 8, 32, 32, C.primaryLight, 8);
  T(p, "Dev Emoji", 30, cy + 14, "\uD83C\uDFA7", 16, "Regular", C.text);
  T(p, "Dev Name", 64, cy + 10, "Phonak Audeo P90-R", 13, "Bold", C.text);
  T(p, "Dev Info", 64, cy + 26, "RIC/RITE \u00B7 Rechargeable", 10, "Regular", C.muted);
  chip(p, 200, cy + 14, "Scanned", C.okLight, C.okDark);
  cy += 56;
  cy = sectionHdr(p, 16, cy + 4, "About the Device");
  cy = inputField(p, 16, cy, 248, "How old is this device?", "Less than 5 years");
  T(p, "Cond Label", 16, cy, "CONDITION", 10, "Semi Bold", C.muted);
  cy += 16;
  chip(p, 16, cy, "Working", C.okLight, C.okDark);
  chip(p, 80, cy, "Not sure", C.chip, C.muted);
  chip(p, 146, cy, "Broken", C.chip, C.muted);
  cy += 28;
  T(p, "Charger", 16, cy, "CHARGER/CASE?", 10, "Semi Bold", C.muted);
  cy += 16;
  chip(p, 16, cy, "Yes", C.okLight, C.okDark);
  chip(p, 56, cy, "No", C.chip, C.muted);
  cy += 28;
  R(p, "Divider", 16, cy, 248, 1, C.border);
  cy += 8;
  cy = sectionHdr(p, 16, cy, "Connection");
  cy = toggleRow(p, 16, cy, 248, "I'd like to connect with the recipient", "Optional, anonymous until both agree", true);
  cy += 8;
  btn(p, 16, cy, 248, 42, "Submit Donation", "primary");
}

function screen3C(page, x, y) {
  var p = phone(page, x, y, "3C. Confirmation");
  R(p, "Success Bg", 100, 72, 80, 80, C.okLight, 40);
  T(p, "Icon", 118, 90, "\uD83C\uDFB5", 36, "Regular", C.text);
  T(p, "Thanks", 0, 168, "Thank You!", 20, "Extra Bold", C.primary, 280, "CENTER");
  T(p, "Desc", 30, 198, "Your Phonak Audeo P90-R has been added to the Recycled Sound register.\n\nAn audiologist will assess the device and we'll notify you when it finds a new home.", 12, "Regular", C.muted, 220, "CENTER");
  // Impact card
  R(p, "Impact Bg", 16, 296, 248, 56, C.primaryLight, 12, C.primary, 1);
  T(p, "Impact Hdr", 0, 304, "YOUR IMPACT", 11, "Semi Bold", C.primary, 280, "CENTER");
  T(p, "Impact Body", 0, 320, "\u267B\uFE0F 1 device saved from landfill\n\uD83E\uDD1D Helping someone hear again", 12, "Regular", C.text, 280, "CENTER");
  btn(p, 16, 372, 248, 42, "Donate Another Device", "primary");
  btn(p, 16, 422, 248, 42, "Go to Home", "ghost");
}

function screen4A(page, x, y) {
  var p = phone(page, x, y, "4A. Hearing Needs");
  var cy = navBar(p, 44, "Apply for a Device", true, "");
  cy = progressDots(p, cy + 4, 1, 4);
  T(p, "Heading", 0, cy + 2, "Tell us about your hearing", 15, "Bold", C.text, 280, "CENTER");
  T(p, "Sub", 0, cy + 22, "This helps us find the right device", 11, "Regular", C.muted, 280, "CENTER");
  cy += 40;
  T(p, "Deg Label", 16, cy, "DEGREE OF HEARING LOSS", 10, "Semi Bold", C.muted);
  cy += 14;
  chip(p, 16, cy, "Mild", C.chip, C.muted);
  var cw = chip(p, 60, cy, "Moderate", C.blueLight, C.blue);
  chip(p, 128, cy, "Severe", C.chip, C.muted);
  chip(p, 182, cy, "Profound", C.chip, C.muted);
  cy += 24;
  chip(p, 16, cy, "Not sure", C.chip, C.muted);
  cy += 30;
  T(p, "Ear Label", 16, cy, "WHICH EAR(S)?", 10, "Semi Bold", C.muted);
  cy += 14;
  chip(p, 16, cy, "Left", C.chip, C.muted);
  chip(p, 60, cy, "Right", C.chip, C.muted);
  chip(p, 110, cy, "Both", C.blueLight, C.blue);
  cy += 30;
  T(p, "Assess Label", 16, cy, "RECENT HEARING ASSESSMENT?", 10, "Semi Bold", C.muted);
  cy += 14;
  chip(p, 16, cy, "Yes, I can upload", C.okLight, C.okDark);
  chip(p, 140, cy, "No", C.chip, C.muted);
  cy += 28;
  R(p, "Upload", 16, cy, 248, 32, C.white, 8, C.border, 1.5);
  T(p, "Upload Hint", 16, cy + 9, "\uD83D\uDCC4 Tap to upload PDF or photo", 11, "Regular", C.muted, 248, "CENTER");
  cy += 40;
  T(p, "Goals Label", 16, cy, "WHAT'S MOST IMPORTANT?", 10, "Semi Bold", C.muted);
  T(p, "Goals Sub", 16, cy + 14, "Select up to 3 communication goals", 10, "Regular", C.muted);
  cy += 30;
  chip(p, 16, cy, "Conversations", C.blueLight, C.blue);
  chip(p, 116, cy, "Phone calls", C.chip, C.muted);
  cy += 24;
  chip(p, 16, cy, "Work / meetings", C.blueLight, C.blue);
  chip(p, 128, cy, "TV / media", C.chip, C.muted);
  cy += 24;
  chip(p, 16, cy, "Learning English", C.chip, C.muted);
  chip(p, 128, cy, "Social connection", C.blueLight, C.blue);
  cy += 32;
  btn(p, 16, cy, 248, 42, "Continue", "primary");
}

function screen4B(page, x, y) {
  var p = phone(page, x, y, "4B. Your Situation");
  var cy = navBar(p, 44, "Apply for a Device", true, "");
  cy = progressDots(p, cy + 4, 2, 4);
  cy = sectionHdr(p, 16, cy, "About You");
  cy = inputField(p, 16, cy, 248, "Location", "Springvale, VIC 3171", true);
  cy = inputField(p, 16, cy, 248, "Country of origin", "Afghanistan");
  cy = inputField(p, 16, cy, 248, "Preferred language", "Dari / Farsi");
  T(p, "Visa Label", 16, cy, "VISA / RESIDENCY STATUS", 10, "Semi Bold", C.muted);
  cy += 14;
  chip(p, 16, cy, "Citizen", C.chip, C.muted);
  chip(p, 76, cy, "PR", C.chip, C.muted);
  chip(p, 106, cy, "Bridging visa", C.blueLight, C.blue);
  chip(p, 202, cy, "Other", C.chip, C.muted);
  cy += 30;
  T(p, "Prev Label", 16, cy, "TRIED ACCESSING AIDS BEFORE?", 10, "Semi Bold", C.muted);
  cy += 14;
  chip(p, 16, cy, "Yes, too expensive", C.blueLight, C.blue);
  chip(p, 148, cy, "Not eligible", C.chip, C.muted);
  cy += 24;
  chip(p, 16, cy, "No", C.chip, C.muted);
  cy += 30;
  T(p, "Doc Label", 16, cy, "SUPPORTING DOCS (OPTIONAL)", 10, "Semi Bold", C.muted);
  cy += 14;
  R(p, "Doc Upload", 16, cy, 248, 32, C.white, 8, C.border, 1.5);
  T(p, "Doc Hint", 16, cy + 9, "Referral letter, Centrelink card, etc.", 11, "Regular", C.muted, 248, "CENTER");
  cy += 42;
  btn(p, 16, cy, 248, 42, "Submit Application", "primary");
}

function screen4C(page, x, y) {
  var p = phone(page, x, y, "4C. Application Status");
  var cy = navBar(p, 44, "My Application", false, "");
  // Status hero
  R(p, "Status Bg", 112, cy + 12, 56, 56, C.blueLight, 28);
  T(p, "Clock", 126, cy + 24, "\u23F3", 24, "Regular", C.text);
  T(p, "Title", 0, cy + 76, "Application Received", 16, "Bold", C.text, 280, "CENTER");
  T(p, "Desc", 30, cy + 98, "Our team is reviewing your application.\nWe'll be in touch when we find a suitable device.", 12, "Regular", C.muted, 220, "CENTER");
  cy += 140;
  // Progress card
  R(p, "Card Bg", 16, cy, 248, 200, C.white, 12, C.border, 1);
  T(p, "Card Hdr", 28, cy + 10, "APPLICATION PROGRESS", 11, "Bold", C.muted);
  var steps = [
    { l: "Application submitted", st: "done" },
    { l: "Under review", st: "active" },
    { l: "Device matched", st: "pending" },
    { l: "Device programmed", st: "pending" },
    { l: "Fitting appointment", st: "pending" },
    { l: "Active & connected", st: "pending" },
  ];
  for (var i = 0; i < steps.length; i++) {
    var sy = cy + 34 + i * 26;
    var st = steps[i].st;
    var dotC = st === "done" ? C.ok : st === "active" ? C.warn : C.border;
    R(p, "Dot " + i, 28, sy, 20, 20, dotC, 10);
    if (st === "done") T(p, "DotCheck", 33, sy + 4, "\u2713", 10, "Bold", C.white);
    if (st === "active") T(p, "DotActive", 35, sy + 4, "\u25CF", 8, "Regular", C.white);
    var tc = st === "pending" ? C.muted : C.text;
    var tw = st === "active" ? "Semi Bold" : "Regular";
    T(p, "Step " + i, 56, sy + 4, steps[i].l, 12, tw, tc, 180);
  }
  cy += 208;
  annotation(p, 16, cy, 248, "All state changes are admin-triggered (human in the loop).");
  tabBar(p, 3);
}

// ─── Design System Components ─────────────────────────────────
function buildDesignSystem(dsPage) {
  // Title
  T(dsPage, "DS Title", 0, -60, "Design System", 24, "Bold", C.primary, 400);
  T(dsPage, "DS Sub", 0, -30, "Recycled Sound \u2014 Component Library", 14, "Regular", C.muted, 400);

  // Colour swatches
  T(dsPage, "Colours Hdr", 0, 0, "Colours", 16, "Bold", C.text);
  var colours = [
    ["Primary", C.primary], ["Primary Light", C.primaryLight], ["Accent", C.accent],
    ["Success", C.ok], ["Success Light", C.okLight],
    ["Warning", C.warn], ["Warning Light", C.warnLight],
    ["Error", C.err], ["Error Light", C.errLight],
    ["Blue Light", C.blueLight], ["Text", C.text], ["Muted", C.muted],
    ["Border", C.border], ["Surface", C.surface], ["White", C.white],
  ];
  for (var i = 0; i < colours.length; i++) {
    var cx = (i % 5) * 80;
    var ry = 24 + Math.floor(i / 5) * 60;
    R(dsPage, colours[i][0], cx, ry, 64, 40, colours[i][1], 8, C.border, 1);
    T(dsPage, colours[i][0] + " label", cx, ry + 44, colours[i][0], 9, "Regular", C.muted);
  }

  var by = 220;
  // Typography
  T(dsPage, "Type Hdr", 0, by, "Typography", 16, "Bold", C.text);
  by += 24;
  T(dsPage, "H1 Sample", 0, by, "Heading 1 \u2014 Extra Bold 20", 20, "Extra Bold", C.text); by += 30;
  T(dsPage, "H2 Sample", 0, by, "Heading 2 \u2014 Bold 18", 18, "Bold", C.text); by += 26;
  T(dsPage, "H3 Sample", 0, by, "Heading 3 \u2014 Bold 16", 16, "Bold", C.text); by += 24;
  T(dsPage, "H4 Sample", 0, by, "Heading 4 \u2014 Bold 15", 15, "Bold", C.text); by += 22;
  T(dsPage, "Body Sample", 0, by, "Body \u2014 Regular 13", 13, "Regular", C.text); by += 20;
  T(dsPage, "Caption Sample", 0, by, "Caption \u2014 Regular 11", 11, "Regular", C.muted); by += 18;
  T(dsPage, "Label Sample", 0, by, "LABEL \u2014 SEMI BOLD 10", 10, "Semi Bold", C.muted); by += 18;
  T(dsPage, "Chip Sample", 0, by, "Chip \u2014 Semi Bold 10", 10, "Semi Bold", C.text);

  by += 40;
  // Buttons
  T(dsPage, "Btn Hdr", 0, by, "Buttons", 16, "Bold", C.text); by += 24;
  btn(dsPage, 0, by, 200, 44, "Primary Button", "primary"); by += 52;
  btn(dsPage, 0, by, 200, 44, "Outline Button", "outline"); by += 52;
  btn(dsPage, 0, by, 200, 44, "Ghost Button", "ghost");

  by += 60;
  // Chips
  T(dsPage, "Chip Hdr", 0, by, "Chips / Tags", 16, "Bold", C.text); by += 24;
  chip(dsPage, 0, by, "Success", C.okLight, C.okDark);
  chip(dsPage, 80, by, "Warning", C.warnLight, C.amberText);
  chip(dsPage, 160, by, "Error", C.errLight, C.errDark);
  by += 28;
  chip(dsPage, 0, by, "Info / Selected", C.blueLight, C.blue);
  chip(dsPage, 120, by, "Default", C.chip, C.muted);

  by += 40;
  // Input field
  T(dsPage, "Input Hdr", 0, by, "Input Fields", 16, "Bold", C.text); by += 24;
  inputField(dsPage, 0, by, 248, "Label", "Value text");
  by += 58;
  inputField(dsPage, 0, by, 248, "Filled Field", "Springvale, VIC", true);

  by += 72;
  // Toggle
  T(dsPage, "Toggle Hdr", 0, by, "Toggles", 16, "Bold", C.text); by += 24;
  toggleRow(dsPage, 0, by, 248, "Toggle On", "Description", true);
  by += 40;
  toggleRow(dsPage, 0, by, 248, "Toggle Off", "Description", false);

  by += 48;
  // Spec row
  T(dsPage, "Spec Hdr", 0, by, "Spec Rows", 16, "Bold", C.text); by += 24;
  specRow(dsPage, 0, by, 248, "Label", "Value"); by += 22;
  specRow(dsPage, 0, by, 248, "Confirmed", "Value", C.ok);

  by += 36;
  // Annotation
  T(dsPage, "Ann Hdr", 0, by, "Annotations", 16, "Bold", C.text); by += 24;
  annotation(dsPage, 0, by, 248, "Design note or implementation callout.");

  by += 72;
  // Confidence row
  T(dsPage, "Conf Hdr", 0, by, "Confidence Rows", 16, "Bold", C.text); by += 24;
  confidenceRow(dsPage, 0, by, 248, "High confidence", "Done", C.okLight, C.okDark, 235, C.ok);
  by += 36;
  confidenceRow(dsPage, 0, by, 248, "Medium confidence", "Analysing", C.warnLight, C.amberText, 150, C.warn);

  by += 48;
  // List item
  T(dsPage, "List Hdr", 0, by, "List Items", 16, "Bold", C.text); by += 24;
  listItem(dsPage, by, "Device Name", "Subtitle text", "Status", C.warnLight, C.amberText);

  by += 72;
  // Nav bar
  T(dsPage, "Nav Hdr", 0, by, "Navigation", 16, "Bold", C.text); by += 24;
  var navG = G(dsPage, "Nav Bar Sample", 0, by);
  navG.resize(280, 44);
  navBar(navG, 0, "Page Title", true, "Action");

  by += 56;
  // Tab bar
  T(dsPage, "Tab Hdr", 0, by, "Tab Bars", 16, "Bold", C.text); by += 24;
  var tabG = G(dsPage, "Tab Bar Sample", 0, by);
  tabG.resize(280, 64);
  tabBar(tabG, 0);

  // Create paint styles
  var styleColors = [
    ["Primary", C.primary], ["Primary Light", C.primaryLight], ["Accent", C.accent],
    ["Text", C.text], ["Text Muted", C.muted], ["Border", C.border], ["Surface", C.surface],
    ["Success", C.ok], ["Success Light", C.okLight], ["Warning", C.warn],
    ["Error", C.err], ["Blue Light", C.blueLight], ["White", C.white],
  ];
  for (var i = 0; i < styleColors.length; i++) {
    var ps = figma.createPaintStyle();
    ps.name = "Recycled Sound / " + styleColors[i][0];
    ps.paints = s(styleColors[i][1]);
  }
}

// ─── Main ─────────────────────────────────────────────────────
async function main() {
  await loadFonts();

  // Use current page for Design System
  var dsPage = figma.currentPage;
  dsPage.name = "Design System";
  buildDesignSystem(dsPage);

  // Create Wireframes page
  var wfPage;
  var existing = figma.root.children.find(function(p) { return p.name === "Wireframes"; });
  if (existing) {
    wfPage = existing;
  } else {
    try {
      wfPage = figma.createPage();
      wfPage.name = "Wireframes";
    } catch (e) {
      // Free plan: place wireframes on same page, offset right
      wfPage = dsPage;
    }
  }
  figma.currentPage = wfPage;

  var GAP = 80, PW = 280, RGAP = 160;
  var offsetX = (wfPage === dsPage) ? 600 : 0;

  // Title
  T(wfPage, "Title", offsetX, -80, "Recycled Sound", 36, "Extra Bold", C.primary, 600);
  T(wfPage, "Subtitle", offsetX, -36, "Wireframes v0.1 \u2014 Hearing Aid Scanner Flow + Donor Journey", 14, "Regular", C.muted, 600);

  // Flow 1
  var rowY = 0;
  T(wfPage, "F1 Title", offsetX, rowY, "Flow 1: Hearing Aid Scanner", 24, "Bold", C.text, 900);
  T(wfPage, "F1 Desc", offsetX, rowY + 36, "Google Lens-style: photograph a hearing aid, AI identifies brand, model, year, battery, wax filters, domes, moulds.", 14, "Regular", C.muted, 900);
  var lY = rowY + 80, pY = lY + 24;
  var labels1 = ["1A. HOME", "1B. CAMERA", "1C. AI ANALYSING", "1D. AI RESULTS"];
  for (var i = 0; i < 4; i++) T(wfPage, labels1[i], offsetX + i * (PW + GAP), lY, labels1[i], 12, "Semi Bold", C.muted, PW, "CENTER");
  screen1A(wfPage, offsetX + 0 * (PW + GAP), pY);
  screen1B(wfPage, offsetX + 1 * (PW + GAP), pY);
  screen1C(wfPage, offsetX + 2 * (PW + GAP), pY);
  screen1D(wfPage, offsetX + 3 * (PW + GAP), pY);

  // Flow 2
  rowY = pY + 560 + RGAP;
  T(wfPage, "F2 Title", offsetX, rowY, "Flow 2: Audiologist Review & QA", 24, "Bold", C.text, 900);
  T(wfPage, "F2 Desc", offsetX, rowY + 36, "Audiologist confirms AI specs, adds tech level / programming interface / gain range. Human-in-the-loop gate.", 14, "Regular", C.muted, 900);
  lY = rowY + 80; pY = lY + 24;
  var labels2 = ["2A. QA QUEUE", "2B. AUDIOLOGIST REVIEW", "2C. DEVICE READY"];
  for (var i = 0; i < 3; i++) T(wfPage, labels2[i], offsetX + i * (PW + GAP), lY, labels2[i], 12, "Semi Bold", C.muted, PW, "CENTER");
  screen2A(wfPage, offsetX + 0 * (PW + GAP), pY);
  screen2B(wfPage, offsetX + 1 * (PW + GAP), pY);
  screen2C(wfPage, offsetX + 2 * (PW + GAP), pY);

  // Flow 3
  rowY = pY + 560 + RGAP;
  T(wfPage, "F3 Title", offsetX, rowY, "Flow 3: Donor Journey", 24, "Bold", C.text, 900);
  T(wfPage, "F3 Desc", offsetX, rowY + 36, "Donor signs up, scans device, fills donation form, gets impact confirmation.", 14, "Regular", C.muted, 900);
  lY = rowY + 80; pY = lY + 24;
  var labels3 = ["3A. DONOR SIGNUP", "3B. DONATION FORM", "3C. CONFIRMATION"];
  for (var i = 0; i < 3; i++) T(wfPage, labels3[i], offsetX + i * (PW + GAP), lY, labels3[i], 12, "Semi Bold", C.muted, PW, "CENTER");
  screen3A(wfPage, offsetX + 0 * (PW + GAP), pY);
  screen3B(wfPage, offsetX + 1 * (PW + GAP), pY);
  screen3C(wfPage, offsetX + 2 * (PW + GAP), pY);

  // Flow 4
  rowY = pY + 560 + RGAP;
  T(wfPage, "F4 Title", offsetX, rowY, "Flow 4: Recipient Application", 24, "Bold", C.text, 900);
  T(wfPage, "F4 Desc", offsetX, rowY + 36, "Recipient describes hearing needs, situation, and tracks application status. All admin-mediated.", 14, "Regular", C.muted, 900);
  lY = rowY + 80; pY = lY + 24;
  var labels4 = ["4A. HEARING NEEDS", "4B. YOUR SITUATION", "4C. APPLICATION STATUS"];
  for (var i = 0; i < 3; i++) T(wfPage, labels4[i], offsetX + i * (PW + GAP), lY, labels4[i], 12, "Semi Bold", C.muted, PW, "CENTER");
  screen4A(wfPage, offsetX + 0 * (PW + GAP), pY);
  screen4B(wfPage, offsetX + 1 * (PW + GAP), pY);
  screen4C(wfPage, offsetX + 2 * (PW + GAP), pY);

  figma.viewport.scrollAndZoomIntoView(wfPage.children);
  figma.notify("\uD83C\uDFB5 Recycled Sound: 13 screens + design system generated!", { timeout: 4000 });
  figma.closePlugin();
}

main().catch(function(err) {
  figma.notify("Error: " + err.message, { error: true, timeout: 10000 });
  console.error(err);
  figma.closePlugin();
});
