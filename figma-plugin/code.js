// Recycled Sound — Figma Wireframe Generator v2
// Creates a proper design system with components, then builds screens from instances.

// ─── Colour Palette ───────────────────────────────────────────
const C = {
  primary:      { r: 0.165, g: 0.490, b: 0.373 },
  primaryLight: { r: 0.910, g: 0.961, b: 0.933 },
  accent:       { r: 0.902, g: 0.494, b: 0.133 },
  text:         { r: 0.102, g: 0.102, b: 0.102 },
  textMuted:    { r: 0.420, g: 0.443, b: 0.498 },
  border:       { r: 0.820, g: 0.835, b: 0.855 },
  surface:      { r: 0.976, g: 0.980, b: 0.984 },
  white:        { r: 1, g: 1, b: 1 },
  black:        { r: 0.102, g: 0.102, b: 0.102 },
  success:      { r: 0.063, g: 0.725, b: 0.506 },
  successLight: { r: 0.820, g: 0.980, b: 0.898 },
  successDark:  { r: 0.024, g: 0.373, b: 0.275 },
  warning:      { r: 0.961, g: 0.620, b: 0.043 },
  warningLight: { r: 0.996, g: 0.953, b: 0.780 },
  error:        { r: 0.937, g: 0.267, b: 0.267 },
  errorLight:   { r: 0.996, g: 0.886, b: 0.886 },
  errorDark:    { r: 0.600, g: 0.106, b: 0.106 },
  blueLight:    { r: 0.859, g: 0.914, b: 0.976 },
  blue:         { r: 0.118, g: 0.251, b: 0.686 },
  camera:       { r: 0.102, g: 0.102, b: 0.102 },
  amberBg:      { r: 1.000, g: 0.984, b: 0.929 },
  amberBorder:  { r: 0.988, g: 0.827, b: 0.302 },
  amberText:    { r: 0.573, g: 0.251, b: 0.055 },
  chipDefault:  { r: 0.953, g: 0.957, b: 0.965 },
  transparent:  null,
};

// ─── Helpers ──────────────────────────────────────────────────
function rgb(c) { return c ? { r: c.r, g: c.g, b: c.b } : { r: 1, g: 1, b: 1 }; }
function solid(c) { return c ? [{ type: 'SOLID', color: rgb(c) }] : []; }
function noFill() { return []; }

async function loadFonts() {
  const styles = ["Regular", "Medium", "Semi Bold", "Bold", "Extra Bold"];
  for (const s of styles) {
    await figma.loadFontAsync({ family: "Inter", style: s });
  }
}

// ─── Paint & Text Styles ──────────────────────────────────────
const paintStyles = {};
const textStyles = {};

function createPaintStyle(name, color) {
  const s = figma.createPaintStyle();
  s.name = name;
  s.paints = solid(color);
  paintStyles[name] = s;
  return s;
}

function createTextStyle(name, size, weight, lineHeight) {
  const s = figma.createTextStyle();
  s.name = name;
  s.fontName = { family: "Inter", style: weight };
  s.fontSize = size;
  if (lineHeight) s.lineHeight = { value: lineHeight, unit: "PIXELS" };
  textStyles[name] = s;
  return s;
}

function applyPaintStyle(node, styleName, prop) {
  if (paintStyles[styleName]) {
    if (prop === 'fills') node.fillStyleId = paintStyles[styleName].id;
    else if (prop === 'strokes') node.strokeStyleId = paintStyles[styleName].id;
  }
}

// ─── Auto-layout Frame Builder ────────────────────────────────
function alFrame(name, opts = {}) {
  const f = figma.createFrame();
  f.name = name;
  f.layoutMode = opts.direction || "VERTICAL";
  f.primaryAxisSizingMode = opts.hug ? "AUTO" : "FIXED";
  f.counterAxisSizingMode = opts.hugCross ? "AUTO" : "FIXED";
  if (opts.w) f.resize(opts.w, opts.h || 10);
  f.itemSpacing = opts.gap != null ? opts.gap : 8;
  f.paddingTop = opts.pt != null ? opts.pt : (opts.p != null ? opts.p : 0);
  f.paddingBottom = opts.pb != null ? opts.pb : (opts.p != null ? opts.p : 0);
  f.paddingLeft = opts.pl != null ? opts.pl : (opts.p != null ? opts.p : 0);
  f.paddingRight = opts.pr != null ? opts.pr : (opts.p != null ? opts.p : 0);
  f.fills = opts.fill ? solid(opts.fill) : noFill();
  if (opts.radius) f.cornerRadius = opts.radius;
  if (opts.stroke) { f.strokes = solid(opts.stroke); f.strokeWeight = opts.strokeW || 1; }
  if (opts.clip) f.clipsContent = true;
  if (opts.align) f.counterAxisAlignItems = opts.align;
  if (opts.mainAlign) f.primaryAxisAlignItems = opts.mainAlign;
  return f;
}

function textNode(content, opts = {}) {
  const t = figma.createText();
  t.fontName = { family: "Inter", style: opts.weight || "Regular" };
  t.characters = content;
  t.fontSize = opts.size || 12;
  t.fills = solid(opts.color || C.text);
  if (opts.align) t.textAlignHorizontal = opts.align;
  t.textAutoResize = "WIDTH_AND_HEIGHT";
  if (opts.w) {
    t.resize(opts.w, t.height);
    t.textAutoResize = "HEIGHT";
  }
  if (opts.style && textStyles[opts.style]) {
    t.textStyleId = textStyles[opts.style].id;
  }
  t.layoutAlign = opts.stretch ? "STRETCH" : "INHERIT";
  return t;
}

function spacer(h) {
  const r = figma.createRectangle();
  r.name = "Spacer";
  r.resize(1, h);
  r.fills = noFill();
  return r;
}

function divider(w) {
  const d = figma.createRectangle();
  d.name = "Divider";
  d.resize(w || 248, 1);
  d.fills = solid(C.border);
  d.layoutAlign = "STRETCH";
  return d;
}

// ─── Component Registry ───────────────────────────────────────
const components = {};

// ─── Component: Chip ──────────────────────────────────────────
function createChipComponent(name, bgColor, textColor, selected) {
  const comp = figma.createComponent();
  comp.name = name;
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "AUTO";
  comp.paddingTop = 4; comp.paddingBottom = 4;
  comp.paddingLeft = 10; comp.paddingRight = 10;
  comp.cornerRadius = 6;
  comp.fills = solid(bgColor);
  comp.itemSpacing = 0;

  const label = textNode("Label", { size: 10, weight: "Semi Bold", color: textColor });
  comp.appendChild(label);

  return comp;
}

function chipInstance(comp, label) {
  const inst = comp.createInstance();
  const textChild = inst.findOne(n => n.type === "TEXT");
  if (textChild) textChild.characters = label;
  return inst;
}

// ─── Component: Button ────────────────────────────────────────
function createButtonComponent(name, bgColor, textColor, strokeColor) {
  const comp = figma.createComponent();
  comp.name = name;
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "AUTO";
  comp.primaryAxisAlignItems = "CENTER";
  comp.counterAxisAlignItems = "CENTER";
  comp.paddingTop = 12; comp.paddingBottom = 12;
  comp.paddingLeft = 20; comp.paddingRight = 20;
  comp.cornerRadius = 12;
  comp.fills = solid(bgColor);
  comp.itemSpacing = 8;
  if (strokeColor) { comp.strokes = solid(strokeColor); comp.strokeWeight = 1.5; }

  const label = textNode("Button Label", { size: 14, weight: "Semi Bold", color: textColor });
  comp.appendChild(label);

  return comp;
}

function buttonInstance(comp, label, stretch) {
  const inst = comp.createInstance();
  const textChild = inst.findOne(n => n.type === "TEXT");
  if (textChild) textChild.characters = label;
  if (stretch) inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Input Field ───────────────────────────────────
function createInputFieldComponent() {
  const comp = figma.createComponent();
  comp.name = "Input Field";
  comp.layoutMode = "VERTICAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(248, 10);
  comp.fills = noFill();
  comp.itemSpacing = 4;

  const label = textNode("LABEL", { size: 10, weight: "Semi Bold", color: C.textMuted, w: 248 });
  label.layoutAlign = "STRETCH";
  comp.appendChild(label);

  const field = alFrame("Field", { direction: "HORIZONTAL", hug: false, w: 248, h: 36,
    fill: C.surface, radius: 8, stroke: C.border, strokeW: 1.5, p: 0, pl: 12, pr: 12, gap: 4,
    align: "CENTER" });
  field.layoutAlign = "STRETCH";
  field.primaryAxisSizingMode = "FIXED";
  field.counterAxisSizingMode = "FIXED";
  field.resize(248, 36);
  const value = textNode("Value", { size: 13, color: C.text });
  field.appendChild(value);
  comp.appendChild(field);

  return comp;
}

function inputInstance(comp, label, value, filled) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  if (texts[0]) texts[0].characters = label.toUpperCase();
  if (texts[1]) texts[1].characters = value;
  if (filled) {
    const field = inst.findOne(n => n.name === "Field");
    if (field) {
      field.fills = solid(C.primaryLight);
      field.strokes = solid(C.primary);
    }
  }
  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Spec Row ──────────────────────────────────────
function createSpecRowComponent() {
  const comp = figma.createComponent();
  comp.name = "Spec Row";
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "AUTO";
  comp.resize(220, 10);
  comp.fills = noFill();
  comp.itemSpacing = 8;
  comp.primaryAxisAlignItems = "SPACE_BETWEEN";

  const label = textNode("Label", { size: 11, color: C.textMuted });
  comp.appendChild(label);

  const value = textNode("Value", { size: 12, weight: "Semi Bold", color: C.text });
  comp.appendChild(value);

  return comp;
}

function specRowInstance(comp, label, value, checkColor) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  if (texts[0]) texts[0].characters = label;
  if (texts[1]) {
    texts[1].characters = checkColor ? "\u2713 " + value : value;
    if (checkColor) texts[1].fills = solid(checkColor);
  }
  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Nav Bar ───────────────────────────────────────
function createNavBarComponent() {
  const comp = figma.createComponent();
  comp.name = "Nav Bar";
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(280, 44);
  comp.fills = solid(C.white);
  comp.itemSpacing = 8;
  comp.paddingLeft = 16; comp.paddingRight = 16;
  comp.counterAxisAlignItems = "CENTER";
  comp.strokes = [{ type: 'SOLID', color: rgb(C.border), opacity: 1 }];
  comp.strokeWeight = 1;
  comp.strokeAlign = "INSIDE";
  comp.strokeBottomWeight = 1;

  const back = textNode("\u2039", { size: 20, color: C.primary });
  comp.appendChild(back);

  const title = textNode("Title", { size: 15, weight: "Semi Bold", color: C.text });
  title.layoutGrow = 1;
  comp.appendChild(title);

  const action = textNode("Action", { size: 12, weight: "Semi Bold", color: C.primary });
  comp.appendChild(action);

  return comp;
}

function navBarInstance(comp, title, hasBack, actionText) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  if (texts[0] && !hasBack) texts[0].characters = "";
  if (texts[1]) texts[1].characters = title;
  if (texts[2]) texts[2].characters = actionText || "";
  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Tab Bar ───────────────────────────────────────
function createTabBarComponent(activeIndex) {
  const comp = figma.createComponent();
  comp.name = `Tab Bar / Active=${activeIndex}`;
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(280, 56);
  comp.fills = solid(C.white);
  comp.paddingTop = 6; comp.paddingBottom = 10;
  comp.paddingLeft = 12; comp.paddingRight = 12;
  comp.primaryAxisAlignItems = "SPACE_BETWEEN";
  comp.strokes = [{ type: 'SOLID', color: rgb(C.border) }];
  comp.strokeWeight = 1;
  comp.strokeAlign = "INSIDE";

  const tabs = [
    { label: "Home" },
    { label: "Scan" },
    { label: "Devices" },
    { label: "Profile" },
  ];

  tabs.forEach((tab, i) => {
    const isActive = i === activeIndex;
    const tabFrame = alFrame(`Tab ${tab.label}`, {
      direction: "VERTICAL", hug: true, hugCross: true, gap: 2, align: "CENTER"
    });

    const icon = alFrame("Icon", {
      direction: "HORIZONTAL", w: 24, h: 24,
      fill: isActive ? C.primary : C.transparent,
      radius: 4, align: "CENTER", mainAlign: "CENTER"
    });
    icon.primaryAxisSizingMode = "FIXED";
    icon.counterAxisSizingMode = "FIXED";
    icon.resize(24, 24);
    if (!isActive) { icon.strokes = solid(C.textMuted); icon.strokeWeight = 1.5; }
    tabFrame.appendChild(icon);

    const label = textNode(tab.label, {
      size: 9, weight: "Regular", color: isActive ? C.primary : C.textMuted, align: "CENTER"
    });
    tabFrame.appendChild(label);
    comp.appendChild(tabFrame);
  });

  return comp;
}

// ─── Component: Status Bar ────────────────────────────────────
function createStatusBarComponent(dark) {
  const comp = figma.createComponent();
  comp.name = dark ? "Status Bar / Dark" : "Status Bar / Light";
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(280, 44);
  comp.fills = noFill();
  comp.paddingLeft = 24; comp.paddingRight = 24;
  comp.paddingBottom = 4;
  comp.primaryAxisAlignItems = "SPACE_BETWEEN";
  comp.counterAxisAlignItems = "MAX";

  const time = textNode("9:41", { size: 11, weight: "Semi Bold", color: dark ? C.white : C.text });
  comp.appendChild(time);

  return comp;
}

// ─── Component: Notch ─────────────────────────────────────────
function createNotchComponent() {
  const comp = figma.createComponent();
  comp.name = "Notch";
  comp.resize(100, 24);
  comp.fills = solid(C.black);
  comp.bottomLeftRadius = 16;
  comp.bottomRightRadius = 16;
  comp.topLeftRadius = 0;
  comp.topRightRadius = 0;
  return comp;
}

// ─── Component: Card ──────────────────────────────────────────
function createCardComponent() {
  const comp = figma.createComponent();
  comp.name = "Card";
  comp.layoutMode = "VERTICAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(248, 10);
  comp.fills = solid(C.white);
  comp.cornerRadius = 12;
  comp.strokes = solid(C.border);
  comp.strokeWeight = 1;
  comp.paddingTop = 12; comp.paddingBottom = 12;
  comp.paddingLeft = 12; comp.paddingRight = 12;
  comp.itemSpacing = 8;

  return comp;
}

// ─── Component: Progress Steps ────────────────────────────────
function createProgressStepsComponent(active, total) {
  const comp = figma.createComponent();
  comp.name = `Progress Steps / ${active + 1} of ${total}`;
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "AUTO";
  comp.itemSpacing = 4;
  comp.paddingTop = 8; comp.paddingBottom = 8;

  for (let i = 0; i < total; i++) {
    const dot = figma.createRectangle();
    dot.name = i < active ? "Done" : i === active ? "Active" : "Pending";
    dot.resize(32, 4);
    dot.cornerRadius = 2;
    dot.fills = solid(i < active ? C.success : i === active ? C.primary : C.border);
    comp.appendChild(dot);
  }

  return comp;
}

// ─── Component: List Item ─────────────────────────────────────
function createListItemComponent() {
  const comp = figma.createComponent();
  comp.name = "List Item";
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "AUTO";
  comp.resize(280, 10);
  comp.fills = solid(C.white);
  comp.paddingTop = 10; comp.paddingBottom = 10;
  comp.paddingLeft = 16; comp.paddingRight = 16;
  comp.itemSpacing = 10;
  comp.counterAxisAlignItems = "CENTER";

  // Avatar
  const avatar = alFrame("Avatar", { w: 36, h: 36, fill: C.blueLight, radius: 10,
    align: "CENTER", mainAlign: "CENTER" });
  avatar.primaryAxisSizingMode = "FIXED";
  avatar.counterAxisSizingMode = "FIXED";
  avatar.resize(36, 36);
  const emoji = textNode("\uD83C\uDFA7", { size: 16 });
  avatar.appendChild(emoji);
  comp.appendChild(avatar);

  // Info
  const info = alFrame("Info", { hug: true, hugCross: true, gap: 2 });
  info.layoutGrow = 1;
  const title = textNode("Device Name", { size: 13, weight: "Semi Bold" });
  info.appendChild(title);
  const sub = textNode("Subtitle text", { size: 11, color: C.textMuted });
  info.appendChild(sub);
  comp.appendChild(info);

  // Status chip placeholder
  const statusChip = alFrame("Status", { direction: "HORIZONTAL", hug: true, hugCross: true,
    fill: C.warningLight, radius: 6, gap: 0, pt: 4, pb: 4, pl: 8, pr: 8 });
  const statusLabel = textNode("Status", { size: 10, weight: "Semi Bold", color: C.amberText });
  statusChip.appendChild(statusLabel);
  comp.appendChild(statusChip);

  return comp;
}

function listItemInstance(comp, title, subtitle, status, statusBg, statusColor) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  // texts: emoji, title, subtitle, status
  if (texts[1]) texts[1].characters = title;
  if (texts[2]) texts[2].characters = subtitle;
  if (texts[3]) texts[3].characters = status;

  const statusFrame = inst.findOne(n => n.name === "Status");
  if (statusFrame && statusBg) statusFrame.fills = solid(statusBg);
  if (texts[3] && statusColor) texts[3].fills = solid(statusColor);

  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Annotation ────────────────────────────────────
function createAnnotationComponent() {
  const comp = figma.createComponent();
  comp.name = "Annotation";
  comp.layoutMode = "VERTICAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(248, 10);
  comp.fills = solid(C.amberBg);
  comp.cornerRadius = 8;
  comp.strokes = [{ type: 'SOLID', color: rgb(C.amberBorder), dashPattern: [4, 4] }];
  comp.strokeWeight = 1;
  comp.paddingTop = 8; comp.paddingBottom = 8;
  comp.paddingLeft = 12; comp.paddingRight = 12;
  comp.itemSpacing = 2;

  const noteLabel = textNode("NOTE", { size: 9, weight: "Bold", color: C.amberText });
  comp.appendChild(noteLabel);
  const noteText = textNode("Annotation content goes here.", { size: 10, color: C.amberText, w: 224 });
  noteText.layoutAlign = "STRETCH";
  comp.appendChild(noteText);

  return comp;
}

function annotationInstance(comp, text) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  if (texts[1]) texts[1].characters = text;
  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Toggle Row ────────────────────────────────────
function createToggleComponent(on) {
  const comp = figma.createComponent();
  comp.name = on ? "Toggle / On" : "Toggle / Off";
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "AUTO";
  comp.resize(248, 10);
  comp.fills = noFill();
  comp.itemSpacing = 8;
  comp.counterAxisAlignItems = "CENTER";
  comp.primaryAxisAlignItems = "SPACE_BETWEEN";

  const labelFrame = alFrame("Label", { hug: true, hugCross: true, gap: 2 });
  const mainLabel = textNode("Toggle label", { size: 12, weight: "Semi Bold" });
  labelFrame.appendChild(mainLabel);
  const subLabel = textNode("Description text", { size: 10, color: C.textMuted });
  labelFrame.appendChild(subLabel);
  comp.appendChild(labelFrame);

  // Track
  const track = figma.createRectangle();
  track.name = "Track";
  track.resize(40, 22);
  track.cornerRadius = 11;
  track.fills = solid(on ? C.primary : C.border);
  comp.appendChild(track);

  return comp;
}

function toggleInstance(comp, label, sublabel) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  if (texts[0]) texts[0].characters = label;
  if (texts[1]) texts[1].characters = sublabel || "";
  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Confidence Row ────────────────────────────────
function createConfidenceRowComponent() {
  const comp = figma.createComponent();
  comp.name = "Confidence Row";
  comp.layoutMode = "VERTICAL";
  comp.primaryAxisSizingMode = "AUTO";
  comp.counterAxisSizingMode = "FIXED";
  comp.resize(248, 10);
  comp.fills = noFill();
  comp.itemSpacing = 4;

  // Header row
  const header = alFrame("Header", { direction: "HORIZONTAL", hug: true, w: 248, gap: 8 });
  header.primaryAxisAlignItems = "SPACE_BETWEEN";
  header.layoutAlign = "STRETCH";
  const label = textNode("Attribute name", { size: 11, color: C.textMuted });
  label.layoutGrow = 1;
  header.appendChild(label);

  const statusChip = alFrame("StatusChip", { direction: "HORIZONTAL", hug: true, hugCross: true,
    fill: C.successLight, radius: 6, pt: 2, pb: 2, pl: 6, pr: 6 });
  const statusText = textNode("Done", { size: 10, weight: "Semi Bold", color: C.successDark });
  statusChip.appendChild(statusText);
  header.appendChild(statusChip);
  comp.appendChild(header);

  // Bar background
  const barBg = figma.createRectangle();
  barBg.name = "Bar BG";
  barBg.resize(248, 4);
  barBg.cornerRadius = 2;
  barBg.fills = solid(C.border);
  barBg.layoutAlign = "STRETCH";
  comp.appendChild(barBg);

  // Bar fill
  const barFill = figma.createRectangle();
  barFill.name = "Bar Fill";
  barFill.resize(235, 4);
  barFill.cornerRadius = 2;
  barFill.fills = solid(C.success);
  barFill.layoutAlign = "INHERIT";
  comp.appendChild(barFill);

  return comp;
}

function confidenceInstance(comp, label, status, statusBg, statusColor, fillWidth, fillColor) {
  const inst = comp.createInstance();
  const texts = inst.findAll(n => n.type === "TEXT");
  if (texts[0]) texts[0].characters = label;
  if (texts[1]) texts[1].characters = status;

  const chip = inst.findOne(n => n.name === "StatusChip");
  if (chip) chip.fills = solid(statusBg);
  if (texts[1]) texts[1].fills = solid(statusColor);

  const fill = inst.findOne(n => n.name === "Bar Fill");
  if (fill) { fill.resize(fillWidth, 4); fill.fills = solid(fillColor); }

  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Section Header ────────────────────────────────
function createSectionHeaderComponent() {
  const comp = figma.createComponent();
  comp.name = "Section Header";
  comp.layoutMode = "HORIZONTAL";
  comp.primaryAxisSizingMode = "FIXED";
  comp.counterAxisSizingMode = "AUTO";
  comp.resize(248, 10);
  comp.fills = noFill();
  comp.paddingTop = 4; comp.paddingBottom = 4;

  const t = textNode("Section Title", { size: 13, weight: "Bold" });
  comp.appendChild(t);

  return comp;
}

function sectionHeaderInstance(comp, text) {
  const inst = comp.createInstance();
  const t = inst.findOne(n => n.type === "TEXT");
  if (t) t.characters = text;
  inst.layoutAlign = "STRETCH";
  return inst;
}

// ─── Component: Chip Row ──────────────────────────────────────
function chipRow(chips) {
  const row = alFrame("Chip Row", { direction: "HORIZONTAL", hug: true, hugCross: true, gap: 6 });
  chips.forEach(c => row.appendChild(c));
  row.layoutAlign = "STRETCH";
  row.layoutWrap = "WRAP";
  return row;
}

// ─── Phone Frame Builder ──────────────────────────────────────
function createPhoneFrame(name) {
  const phone = alFrame(name, {
    w: 280, h: 560, fill: C.white, radius: 32, clip: true,
    stroke: C.black, strokeW: 3, gap: 0
  });
  phone.primaryAxisSizingMode = "FIXED";
  phone.counterAxisSizingMode = "FIXED";

  // Notch (absolute positioned)
  if (components.notch) {
    const notch = components.notch.createInstance();
    notch.layoutPositioning = "ABSOLUTE";
    notch.x = 90; notch.y = 0;
    phone.appendChild(notch);
  }

  return phone;
}

// ─── Build Screens ────────────────────────────────────────────

function buildScreen1A(page, x, y) {
  const phone = createPhoneFrame("1A. Home");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  // Status bar
  phone.appendChild(components.statusBar.createInstance());

  // Hero
  const hero = alFrame("Hero", { w: 280, gap: 6, align: "CENTER", pt: 16, pb: 8 });
  hero.layoutAlign = "STRETCH";

  const iconBg = alFrame("Icon", { w: 72, h: 72, fill: C.primaryLight, radius: 20, align: "CENTER", mainAlign: "CENTER" });
  iconBg.primaryAxisSizingMode = "FIXED"; iconBg.counterAxisSizingMode = "FIXED";
  iconBg.resize(72, 72);
  iconBg.appendChild(textNode("\uD83C\uDFB5", { size: 32 }));
  hero.appendChild(iconBg);

  hero.appendChild(textNode("Recycled Sound", { size: 18, weight: "Extra Bold", align: "CENTER", w: 248 }));
  hero.appendChild(textNode("Give hearing aids a second life.\nScan, donate, match, connect.", { size: 12, color: C.textMuted, align: "CENTER", w: 248 }));
  phone.appendChild(hero);

  // Buttons
  const btns = alFrame("Actions", { w: 280, gap: 10, pl: 16, pr: 16, pt: 4, pb: 4 });
  btns.layoutAlign = "STRETCH";
  btns.appendChild(buttonInstance(components.btnPrimary, "\uD83D\uDCF7  Scan a Hearing Aid", true));
  btns.appendChild(buttonInstance(components.btnOutline, "\uD83C\uDF81  Donate a Device", true));
  btns.appendChild(buttonInstance(components.btnGhost, "\uD83D\uDCCB  Browse Available Aids", true));
  phone.appendChild(btns);

  phone.appendChild(divider());

  // Stats
  const stats = alFrame("Stats Section", { w: 280, gap: 8, pl: 16, pr: 16, pt: 4 });
  stats.layoutAlign = "STRETCH";
  stats.appendChild(textNode("Quick Stats", { size: 13, weight: "Bold" }));

  const statRow = alFrame("Stat Cards", { direction: "HORIZONTAL", w: 248, gap: 8 });
  statRow.layoutAlign = "STRETCH";

  const statNames = [
    { n: "20", l: "Devices\non Register", c: C.primary },
    { n: "12", l: "Awaiting\nQA", c: C.accent },
    { n: "5", l: "Matched &\nFitted", c: C.success },
  ];
  statNames.forEach(s => {
    const card = alFrame("Stat", { hug: true, hugCross: false, fill: C.white, radius: 12,
      stroke: C.border, p: 8, gap: 2, align: "CENTER" });
    card.layoutGrow = 1;
    card.appendChild(textNode(s.n, { size: 22, weight: "Extra Bold", color: s.c, align: "CENTER", w: 60 }));
    card.appendChild(textNode(s.l, { size: 10, color: C.textMuted, align: "CENTER", w: 60 }));
    statRow.appendChild(card);
  });
  stats.appendChild(statRow);
  phone.appendChild(stats);

  // Tab bar (absolute at bottom)
  const tabBar = components.tabBar0.createInstance();
  tabBar.layoutPositioning = "ABSOLUTE";
  tabBar.x = 0; tabBar.y = 504;
  phone.appendChild(tabBar);

  return phone;
}

function buildScreen1B(page, x, y) {
  const phone = createPhoneFrame("1B. Camera Scanner");
  phone.x = x; phone.y = y;
  phone.fills = solid(C.camera);
  page.appendChild(phone);

  // Status bar (dark)
  phone.appendChild(components.statusBarDark.createInstance());

  // Top bar
  const topBar = alFrame("Top Bar", { direction: "HORIZONTAL", w: 280, gap: 8, pl: 20, pr: 20,
    pt: 0, pb: 8, mainAlign: "SPACE_BETWEEN", align: "CENTER" });
  topBar.layoutAlign = "STRETCH";
  topBar.appendChild(textNode("\u2715", { size: 14, color: C.white }));
  topBar.appendChild(textNode("Scan Hearing Aid", { size: 12, weight: "Semi Bold", color: C.white }));
  topBar.appendChild(textNode("\u26A1", { size: 14, color: C.white }));
  phone.appendChild(topBar);

  // Spacer to push scan frame down
  phone.appendChild(spacer(24));

  // Scan frame area
  const scanArea = alFrame("Scan Area", { w: 280, gap: 12, align: "CENTER" });
  scanArea.layoutAlign = "STRETCH";
  scanArea.layoutGrow = 1;

  // Frame with corners
  const frame = alFrame("Viewfinder Frame", { w: 180, h: 180, radius: 16, stroke: C.white, strokeW: 1.5,
    align: "CENTER", mainAlign: "CENTER" });
  frame.primaryAxisSizingMode = "FIXED"; frame.counterAxisSizingMode = "FIXED";
  frame.resize(180, 180);
  frame.fills = [{ type: 'SOLID', color: rgb(C.white), opacity: 0.05 }];

  // HA placeholder text
  frame.appendChild(textNode("\uD83E\uDDBB", { size: 48, color: { r: 0.4, g: 0.4, b: 0.4 } }));
  scanArea.appendChild(frame);

  scanArea.appendChild(textNode("Position hearing aid within the frame", { size: 12,
    color: { r: 0.7, g: 0.7, b: 0.7 }, align: "CENTER", w: 248 }));
  phone.appendChild(scanArea);

  // Camera controls
  const controls = alFrame("Camera Controls", { w: 280, gap: 12, align: "CENTER", pb: 12, pt: 8 });
  controls.layoutAlign = "STRETCH";

  const btnRow = alFrame("Buttons", { direction: "HORIZONTAL", hug: true, hugCross: true, gap: 20,
    align: "CENTER" });

  // Gallery
  const galleryBtn = alFrame("Gallery", { w: 40, h: 40, fill: { r: 0.2, g: 0.2, b: 0.2 }, radius: 20,
    align: "CENTER", mainAlign: "CENTER" });
  galleryBtn.primaryAxisSizingMode = "FIXED"; galleryBtn.counterAxisSizingMode = "FIXED";
  galleryBtn.resize(40, 40);
  btnRow.appendChild(galleryBtn);

  // Shutter
  const shutter = alFrame("Shutter", { w: 64, h: 64, fill: C.white, radius: 32,
    align: "CENTER", mainAlign: "CENTER" });
  shutter.primaryAxisSizingMode = "FIXED"; shutter.counterAxisSizingMode = "FIXED";
  shutter.resize(64, 64);
  const inner = figma.createEllipse();
  inner.resize(52, 52);
  inner.fills = noFill();
  inner.strokes = solid(C.primary);
  inner.strokeWeight = 3;
  shutter.appendChild(inner);
  btnRow.appendChild(shutter);

  // Flip
  const flipBtn = alFrame("Flip", { w: 40, h: 40, fill: { r: 0.2, g: 0.2, b: 0.2 }, radius: 20,
    align: "CENTER", mainAlign: "CENTER" });
  flipBtn.primaryAxisSizingMode = "FIXED"; flipBtn.counterAxisSizingMode = "FIXED";
  flipBtn.resize(40, 40);
  btnRow.appendChild(flipBtn);

  controls.appendChild(btnRow);

  // Mode labels
  const modeRow = alFrame("Modes", { direction: "HORIZONTAL", hug: true, hugCross: true, gap: 20 });
  modeRow.appendChild(textNode("Gallery", { size: 11, color: { r: 0.5, g: 0.5, b: 0.5 } }));
  modeRow.appendChild(textNode("Photo", { size: 11, weight: "Semi Bold", color: C.white }));
  modeRow.appendChild(textNode("Multi", { size: 11, color: { r: 0.5, g: 0.5, b: 0.5 } }));
  controls.appendChild(modeRow);

  phone.appendChild(controls);

  return phone;
}

function buildScreen1C(page, x, y) {
  const phone = createPhoneFrame("1C. AI Analysing");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Analysing...", true, ""));

  // Photo area
  const photo = alFrame("Photo", { w: 248, h: 90, fill: C.surface, radius: 12,
    stroke: C.border, align: "CENTER", mainAlign: "CENTER" });
  photo.primaryAxisSizingMode = "FIXED"; photo.counterAxisSizingMode = "FIXED";
  photo.resize(248, 90);
  photo.layoutAlign = "STRETCH";
  photo.appendChild(textNode("\uD83E\uDDBB", { size: 32, color: C.textMuted }));

  const photoWrap = alFrame("Photo Wrap", { w: 280, pl: 16, pr: 16, pt: 8, pb: 8, gap: 0 });
  photoWrap.layoutAlign = "STRETCH";
  photoWrap.appendChild(photo);
  phone.appendChild(photoWrap);

  // Scanning indicator
  const indicatorWrap = alFrame("Indicator Wrap", { w: 280, align: "CENTER", gap: 0, pt: 4, pb: 8 });
  indicatorWrap.layoutAlign = "STRETCH";
  const indicator = alFrame("Scanning Indicator", { direction: "HORIZONTAL", hug: true, hugCross: true,
    fill: C.primary, radius: 15, pl: 14, pr: 14, pt: 6, pb: 6, gap: 6 });
  indicator.appendChild(textNode("Identifying device...", { size: 11, weight: "Semi Bold", color: C.white }));
  indicatorWrap.appendChild(indicator);
  phone.appendChild(indicatorWrap);

  // Confidence rows
  const rows = alFrame("Confidence Rows", { w: 280, pl: 16, pr: 16, gap: 12 });
  rows.layoutAlign = "STRETCH";

  rows.appendChild(confidenceInstance(components.confidenceRow, "Brand detection", "Done",
    C.successLight, C.successDark, 240, C.success));
  rows.appendChild(confidenceInstance(components.confidenceRow, "Model identification", "Done",
    C.successLight, C.successDark, 235, C.success));
  rows.appendChild(confidenceInstance(components.confidenceRow, "Battery type", "Done",
    C.successLight, C.successDark, 240, C.success));
  rows.appendChild(confidenceInstance(components.confidenceRow, "Dome / mould type", "Analysing",
    C.warningLight, C.amberText, 180, C.warning));
  rows.appendChild(confidenceInstance(components.confidenceRow, "Technology level", "Estimating",
    C.warningLight, C.amberText, 100, C.error));
  phone.appendChild(rows);

  // Annotation
  const annWrap = alFrame("Annotation Wrap", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  annWrap.layoutAlign = "STRETCH";
  annWrap.appendChild(annotationInstance(components.annotation,
    "AI confidence varies by attribute. Brand & model are high confidence. Tech level needs audiologist."));
  phone.appendChild(annWrap);

  return phone;
}

function buildScreen1D(page, x, y) {
  const phone = createPhoneFrame("1D. AI Results");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Scan Results", true, "Edit"));

  // Photo thumbnail
  const photoWrap = alFrame("Photo Wrap", { w: 280, pl: 16, pr: 16, pt: 8, pb: 4, gap: 0 });
  photoWrap.layoutAlign = "STRETCH";
  const photo = alFrame("Photo", { w: 248, h: 64, fill: C.surface, radius: 12,
    stroke: C.border, align: "CENTER", mainAlign: "CENTER" });
  photo.primaryAxisSizingMode = "FIXED"; photo.counterAxisSizingMode = "FIXED";
  photo.resize(248, 64);
  photo.layoutAlign = "STRETCH";
  photo.appendChild(textNode("\uD83E\uDDBB", { size: 24, color: C.textMuted }));
  photoWrap.appendChild(photo);
  phone.appendChild(photoWrap);

  // Results card
  const cardWrap = alFrame("Results Card Wrap", { w: 280, pl: 16, pr: 16, gap: 0, pt: 4 });
  cardWrap.layoutAlign = "STRETCH";

  const card = alFrame("Results Card", { w: 248, gap: 4, fill: C.white, radius: 12,
    stroke: C.primary, strokeW: 1.5, p: 12 });
  card.layoutAlign = "STRETCH";

  // Title row
  const titleRow = alFrame("Title", { direction: "HORIZONTAL", w: 224, gap: 4, mainAlign: "SPACE_BETWEEN", align: "CENTER" });
  titleRow.layoutAlign = "STRETCH";
  titleRow.appendChild(textNode("Phonak Audeo P90-R", { size: 14, weight: "Bold" }));
  titleRow.appendChild(chipInstance(components.chipGreen, "95%"));
  card.appendChild(titleRow);

  // Spec rows
  card.appendChild(specRowInstance(components.specRow, "Brand", "Phonak"));
  card.appendChild(specRowInstance(components.specRow, "Model", "Audeo Paradise P90-R"));
  card.appendChild(specRowInstance(components.specRow, "Type", "RIC/RITE"));
  card.appendChild(specRowInstance(components.specRow, "Year (est.)", "2021 \u270E"));
  card.appendChild(specRowInstance(components.specRow, "Battery", "Rechargeable (Li-ion)"));
  card.appendChild(specRowInstance(components.specRow, "Dome", "Open dome \u270E"));
  card.appendChild(specRowInstance(components.specRow, "Wax Filter", "CeruShield Disk"));
  card.appendChild(specRowInstance(components.specRow, "Receiver", "M receiver"));
  cardWrap.appendChild(card);
  phone.appendChild(cardWrap);

  // Warning card
  const warnWrap = alFrame("Warning Wrap", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  warnWrap.layoutAlign = "STRETCH";
  const warn = alFrame("Warning Card", { w: 248, gap: 2, fill: C.amberBg, radius: 12,
    stroke: C.amberBorder, p: 10 });
  warn.layoutAlign = "STRETCH";
  warn.appendChild(textNode("\uD83D\uDD0D Needs Audiologist Review", { size: 12, weight: "Bold", color: C.amberText, w: 228 }));
  warn.appendChild(textNode("Tech level, programming interface, and gain range require professional assessment.", { size: 10, color: C.amberText, w: 228 }));
  warnWrap.appendChild(warn);
  phone.appendChild(warnWrap);

  // Buttons
  const btnWrap = alFrame("Buttons", { direction: "HORIZONTAL", w: 280, pl: 16, pr: 16, pt: 8, gap: 8 });
  btnWrap.layoutAlign = "STRETCH";
  const mainBtn = buttonInstance(components.btnPrimary, "Add to Register");
  mainBtn.layoutGrow = 1;
  btnWrap.appendChild(mainBtn);

  const camBtn = alFrame("Camera Btn", { w: 40, h: 42, fill: C.white, radius: 12,
    stroke: C.primary, strokeW: 1.5, align: "CENTER", mainAlign: "CENTER" });
  camBtn.primaryAxisSizingMode = "FIXED"; camBtn.counterAxisSizingMode = "FIXED";
  camBtn.resize(40, 42);
  camBtn.appendChild(textNode("\uD83D\uDCF7", { size: 16 }));
  btnWrap.appendChild(camBtn);
  phone.appendChild(btnWrap);

  return phone;
}

function buildScreen2A(page, x, y) {
  const phone = createPhoneFrame("2A. QA Queue");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Devices Awaiting QA", false, "Filter"));

  // Filter chips
  const filters = alFrame("Filters", { direction: "HORIZONTAL", w: 280, pl: 16, pr: 16,
    pt: 8, pb: 8, gap: 6 });
  filters.layoutAlign = "STRETCH";
  filters.appendChild(chipInstance(components.chipAmber, "\u23F3 12 Pending"));
  filters.appendChild(chipInstance(components.chipGreen, "\u2713 5 Passed"));
  filters.appendChild(chipInstance(components.chipRed, "\u2717 2 Failed"));
  phone.appendChild(filters);

  // List
  const list = alFrame("Device List", { w: 280, gap: 0 });
  list.layoutAlign = "STRETCH";
  list.appendChild(listItemInstance(components.listItem, "Phonak Audeo P90-R", "Donor: PL \u00B7 Scanned 2d ago", "Pending", C.warningLight, C.amberText));
  list.appendChild(listItemInstance(components.listItem, "Unitron Moxi Next 4", "Donor: PL \u00B7 Scanned 3d ago", "Pending", C.warningLight, C.amberText));
  list.appendChild(listItemInstance(components.listItem, "GN Resound LiNX 2", "Donor: JM \u00B7 Scanned 5d ago", "Pending", C.warningLight, C.amberText));
  list.appendChild(listItemInstance(components.listItem, "Oticon Ria 2 P", "Donor: WR \u00B7 QA'd today", "Passed", C.successLight, C.successDark));
  list.appendChild(listItemInstance(components.listItem, "Signia Motion 13P", "Donor: JH \u00B7 QA'd yesterday", "Passed", C.successLight, C.successDark));
  list.appendChild(listItemInstance(components.listItem, "Blamey & Saunders", "Donor: EB \u00B7 Non-functional", "Failed", C.errorLight, C.errorDark));
  phone.appendChild(list);

  const tabBar = components.tabBar2.createInstance();
  tabBar.layoutPositioning = "ABSOLUTE";
  tabBar.x = 0; tabBar.y = 504;
  phone.appendChild(tabBar);

  return phone;
}

function buildScreen2B(page, x, y) {
  const phone = createPhoneFrame("2B. Audiologist Review");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Review Device", true, "Save"));

  // Progress
  const progWrap = alFrame("Prog", { w: 280, align: "CENTER", gap: 0 });
  progWrap.layoutAlign = "STRETCH";
  progWrap.appendChild(components.progress2of4.createInstance());
  phone.appendChild(progWrap);

  // AI-confirmed section
  const confirmed = alFrame("AI Confirmed", { w: 280, pl: 16, pr: 16, gap: 4 });
  confirmed.layoutAlign = "STRETCH";
  confirmed.appendChild(sectionHeaderInstance(components.sectionHeader, "AI-Identified (confirmed \u2713)"));
  confirmed.appendChild(specRowInstance(components.specRow, "Brand", "Phonak", C.success));
  confirmed.appendChild(specRowInstance(components.specRow, "Model", "Audeo P90-R", C.success));
  confirmed.appendChild(specRowInstance(components.specRow, "Type", "RIC/RITE", C.success));
  confirmed.appendChild(specRowInstance(components.specRow, "Battery", "Rechargeable", C.success));
  phone.appendChild(confirmed);

  phone.appendChild(divider());

  // Audiologist assessment
  const assessment = alFrame("Assessment", { w: 280, pl: 16, pr: 16, gap: 4 });
  assessment.layoutAlign = "STRETCH";
  assessment.appendChild(sectionHeaderInstance(components.sectionHeader, "Audiologist Assessment"));
  assessment.appendChild(inputInstance(components.inputField, "Technology Level", "Premium (Level 9)"));
  assessment.appendChild(inputInstance(components.inputField, "Programming Interface", "Noahlink Wireless"));
  assessment.appendChild(inputInstance(components.inputField, "Gain Range (Fitting Range)", "Mild to Moderate"));

  // Condition chips
  const condLabel = textNode("PHYSICAL CONDITION", { size: 10, weight: "Semi Bold", color: C.textMuted });
  condLabel.layoutAlign = "STRETCH";
  assessment.appendChild(condLabel);
  assessment.appendChild(chipRow([
    chipInstance(components.chipGreen, "Good"),
    chipInstance(components.chipDefault, "Fair"),
    chipInstance(components.chipDefault, "Poor"),
  ]));
  phone.appendChild(assessment);

  // Toggles
  const toggles = alFrame("Toggles", { w: 280, pl: 16, pr: 16, gap: 4, pt: 4 });
  toggles.layoutAlign = "STRETCH";
  toggles.appendChild(toggleInstance(components.toggleOn, "Remote fine-tuning capable?", ""));
  toggles.appendChild(toggleInstance(components.toggleOn, "App compatible?", ""));
  toggles.appendChild(toggleInstance(components.toggleOff, "Auracast ready?", ""));
  phone.appendChild(toggles);

  // CTA
  const cta = alFrame("CTA", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  cta.layoutAlign = "STRETCH";
  cta.appendChild(buttonInstance(components.btnPrimary, "\u2713 Mark as QA Passed", true));
  phone.appendChild(cta);

  return phone;
}

function buildScreen2C(page, x, y) {
  const phone = createPhoneFrame("2C. Device Ready");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Device Profile", true, "Share"));

  // Success hero
  const heroFrame = alFrame("Success Hero", { w: 280, gap: 6, align: "CENTER", pt: 12, pb: 8 });
  heroFrame.layoutAlign = "STRETCH";
  const successIcon = alFrame("Success Icon", { w: 64, h: 64, fill: C.successLight, radius: 32,
    align: "CENTER", mainAlign: "CENTER" });
  successIcon.primaryAxisSizingMode = "FIXED"; successIcon.counterAxisSizingMode = "FIXED";
  successIcon.resize(64, 64);
  successIcon.appendChild(textNode("\u2713", { size: 28, weight: "Bold", color: C.success }));
  heroFrame.appendChild(successIcon);
  heroFrame.appendChild(textNode("Phonak Audeo P90-R", { size: 16, weight: "Bold", align: "CENTER", w: 248 }));
  heroFrame.appendChild(textNode("QA Passed \u00B7 Ready for Matching", { size: 12, color: C.textMuted, align: "CENTER", w: 248 }));
  phone.appendChild(heroFrame);

  // Specs card
  const specsWrap = alFrame("Specs Wrap", { w: 280, pl: 16, pr: 16, gap: 0 });
  specsWrap.layoutAlign = "STRETCH";
  const specsCard = alFrame("Specs Card", { w: 248, gap: 4, fill: C.white, radius: 12,
    stroke: C.border, p: 12 });
  specsCard.layoutAlign = "STRETCH";
  specsCard.appendChild(textNode("DEVICE SPECIFICATIONS", { size: 11, weight: "Bold", color: C.textMuted }));
  specsCard.appendChild(specRowInstance(components.specRow, "Brand", "Phonak"));
  specsCard.appendChild(specRowInstance(components.specRow, "Model", "Audeo P90-R"));
  specsCard.appendChild(specRowInstance(components.specRow, "Type", "RIC/RITE"));
  specsCard.appendChild(specRowInstance(components.specRow, "Tech Level", "Premium (9)"));
  specsCard.appendChild(specRowInstance(components.specRow, "Fitting Range", "Mild\u2013Moderate"));
  specsCard.appendChild(specRowInstance(components.specRow, "Battery", "Rechargeable"));
  specsCard.appendChild(specRowInstance(components.specRow, "Programming", "Noahlink Wireless"));
  specsWrap.appendChild(specsCard);
  phone.appendChild(specsWrap);

  // Features card
  const featWrap = alFrame("Feat Wrap", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  featWrap.layoutAlign = "STRETCH";
  const featCard = alFrame("Features", { w: 248, gap: 6, fill: C.white, radius: 12,
    stroke: C.border, p: 12 });
  featCard.layoutAlign = "STRETCH";
  featCard.appendChild(textNode("FEATURES", { size: 11, weight: "Bold", color: C.textMuted }));
  featCard.appendChild(chipRow([
    chipInstance(components.chipBlue, "Remote Fine-Tuning"),
    chipInstance(components.chipBlue, "App Compatible"),
    chipInstance(components.chipBlue, "Bluetooth"),
  ]));
  featWrap.appendChild(featCard);
  phone.appendChild(featWrap);

  // Lifecycle
  const lcWrap = alFrame("LC Wrap", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  lcWrap.layoutAlign = "STRETCH";
  const lcCard = alFrame("Lifecycle", { w: 248, gap: 4, fill: C.white, radius: 12,
    stroke: C.border, p: 12 });
  lcCard.layoutAlign = "STRETCH";
  lcCard.appendChild(textNode("LIFECYCLE", { size: 11, weight: "Bold", color: C.textMuted }));
  lcCard.appendChild(textNode("Donated \u2192 Scanned \u2192 QA'd \u2192 Matched", { size: 10, weight: "Semi Bold", color: C.textMuted, w: 224 }));
  lcWrap.appendChild(lcCard);
  phone.appendChild(lcWrap);

  // CTA
  const cta = alFrame("CTA", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  cta.layoutAlign = "STRETCH";
  cta.appendChild(buttonInstance(components.btnPrimary, "Find a Match", true));
  phone.appendChild(cta);

  return phone;
}

function buildScreen3A(page, x, y) {
  const phone = createPhoneFrame("3A. Donor Signup");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Create Account", true, ""));

  const progWrap = alFrame("Prog", { w: 280, align: "CENTER", gap: 0 });
  progWrap.layoutAlign = "STRETCH";
  progWrap.appendChild(components.progress0of3.createInstance());
  phone.appendChild(progWrap);

  // Title
  const titleFrame = alFrame("Title", { w: 280, gap: 4, align: "CENTER", pt: 8, pb: 8 });
  titleFrame.layoutAlign = "STRETCH";
  titleFrame.appendChild(textNode("I want to...", { size: 15, weight: "Bold", align: "CENTER", w: 248 }));
  titleFrame.appendChild(textNode("Select your role", { size: 12, color: C.textMuted, align: "CENTER", w: 248 }));
  phone.appendChild(titleFrame);

  // Role cards
  const rolesWrap = alFrame("Roles", { w: 280, pl: 16, pr: 16, gap: 8 });
  rolesWrap.layoutAlign = "STRETCH";

  const roles = [
    { emoji: "\uD83C\uDF81", title: "Donate a Hearing Aid", sub: "I have a device to give", selected: true },
    { emoji: "\uD83E\uDD1D", title: "Receive a Hearing Aid", sub: "I need hearing support", selected: false },
    { emoji: "\uD83E\uDE7A", title: "I'm a Hearing Professional", sub: "Audiologist or clinic", selected: false },
  ];

  roles.forEach(role => {
    const card = alFrame("Role Card", { direction: "HORIZONTAL", w: 248, gap: 12,
      fill: role.selected ? C.primaryLight : C.white, radius: 12,
      stroke: role.selected ? C.primary : C.border, strokeW: role.selected ? 1.5 : 1,
      p: 12, align: "CENTER" });
    card.layoutAlign = "STRETCH";
    card.appendChild(textNode(role.emoji, { size: 24 }));
    const info = alFrame("Info", { hug: true, hugCross: true, gap: 2 });
    info.appendChild(textNode(role.title, { size: 14, weight: role.selected ? "Bold" : "Semi Bold",
      color: role.selected ? C.primary : C.text }));
    info.appendChild(textNode(role.sub, { size: 11, color: C.textMuted }));
    card.appendChild(info);
    rolesWrap.appendChild(card);
  });
  phone.appendChild(rolesWrap);

  // CTA
  const cta = alFrame("CTA", { w: 280, pl: 16, pr: 16, pt: 12, gap: 0 });
  cta.layoutAlign = "STRETCH";
  cta.appendChild(buttonInstance(components.btnPrimary, "Continue", true));
  phone.appendChild(cta);

  return phone;
}

function buildScreen3B(page, x, y) {
  const phone = createPhoneFrame("3B. Donation Form");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Donate a Device", true, ""));

  const progWrap = alFrame("Prog", { w: 280, align: "CENTER", gap: 0 });
  progWrap.layoutAlign = "STRETCH";
  progWrap.appendChild(components.progress1of3.createInstance());
  phone.appendChild(progWrap);

  // Device from scan
  const deviceSection = alFrame("Device Section", { w: 280, pl: 16, pr: 16, gap: 4 });
  deviceSection.layoutAlign = "STRETCH";
  deviceSection.appendChild(sectionHeaderInstance(components.sectionHeader, "Device (from scan)"));

  const deviceCard = alFrame("Scanned Device", { direction: "HORIZONTAL", w: 248, gap: 8,
    fill: C.white, radius: 12, stroke: C.border, p: 10, align: "CENTER" });
  deviceCard.layoutAlign = "STRETCH";
  const devIcon = alFrame("Dev Icon", { w: 32, h: 32, fill: C.primaryLight, radius: 8,
    align: "CENTER", mainAlign: "CENTER" });
  devIcon.primaryAxisSizingMode = "FIXED"; devIcon.counterAxisSizingMode = "FIXED";
  devIcon.resize(32, 32);
  devIcon.appendChild(textNode("\uD83C\uDFA7", { size: 14 }));
  deviceCard.appendChild(devIcon);
  const devInfo = alFrame("Dev Info", { hug: true, hugCross: true, gap: 1 });
  devInfo.layoutGrow = 1;
  devInfo.appendChild(textNode("Phonak Audeo P90-R", { size: 13, weight: "Bold" }));
  devInfo.appendChild(textNode("RIC/RITE \u00B7 Rechargeable", { size: 10, color: C.textMuted }));
  deviceCard.appendChild(devInfo);
  deviceCard.appendChild(chipInstance(components.chipGreen, "Scanned"));
  deviceSection.appendChild(deviceCard);
  phone.appendChild(deviceSection);

  // Form
  const form = alFrame("Form", { w: 280, pl: 16, pr: 16, gap: 6 });
  form.layoutAlign = "STRETCH";
  form.appendChild(sectionHeaderInstance(components.sectionHeader, "About the Device"));
  form.appendChild(inputInstance(components.inputField, "How old is this device? (approx.)", "Less than 5 years"));

  const condLabel = textNode("CONDITION", { size: 10, weight: "Semi Bold", color: C.textMuted });
  condLabel.layoutAlign = "STRETCH";
  form.appendChild(condLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipGreen, "Working"),
    chipInstance(components.chipDefault, "Not sure"),
    chipInstance(components.chipDefault, "Broken"),
  ]));

  const chargerLabel = textNode("DO YOU HAVE THE CHARGER/CASE?", { size: 10, weight: "Semi Bold", color: C.textMuted });
  chargerLabel.layoutAlign = "STRETCH";
  form.appendChild(chargerLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipGreen, "Yes"),
    chipInstance(components.chipDefault, "No"),
  ]));
  phone.appendChild(form);

  phone.appendChild(divider());

  // Connection
  const conn = alFrame("Connection", { w: 280, pl: 16, pr: 16, gap: 4 });
  conn.layoutAlign = "STRETCH";
  conn.appendChild(sectionHeaderInstance(components.sectionHeader, "Connection"));
  conn.appendChild(toggleInstance(components.toggleOn, "I'd like to connect with the recipient", "Optional, anonymous until both agree"));
  phone.appendChild(conn);

  // CTA
  const cta = alFrame("CTA", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  cta.layoutAlign = "STRETCH";
  cta.appendChild(buttonInstance(components.btnPrimary, "Submit Donation", true));
  phone.appendChild(cta);

  return phone;
}

function buildScreen3C(page, x, y) {
  const phone = createPhoneFrame("3C. Confirmation");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());

  // Success hero
  const hero = alFrame("Success", { w: 280, gap: 8, align: "CENTER", pt: 32, pb: 8 });
  hero.layoutAlign = "STRETCH";
  const icon = alFrame("Icon", { w: 80, h: 80, fill: C.successLight, radius: 40,
    align: "CENTER", mainAlign: "CENTER" });
  icon.primaryAxisSizingMode = "FIXED"; icon.counterAxisSizingMode = "FIXED";
  icon.resize(80, 80);
  icon.appendChild(textNode("\uD83C\uDFB5", { size: 36 }));
  hero.appendChild(icon);
  hero.appendChild(textNode("Thank You!", { size: 20, weight: "Extra Bold", color: C.primary, align: "CENTER", w: 248 }));
  hero.appendChild(textNode("Your Phonak Audeo P90-R has been added to the Recycled Sound register.\n\nAn audiologist will assess the device and we'll notify you when it finds a new home.", { size: 12, color: C.textMuted, align: "CENTER", w: 220 }));
  phone.appendChild(hero);

  // Impact card
  const impactWrap = alFrame("Impact Wrap", { w: 280, pl: 16, pr: 16, gap: 0 });
  impactWrap.layoutAlign = "STRETCH";
  const impactCard = alFrame("Impact Card", { w: 248, gap: 4, fill: C.primaryLight, radius: 12,
    stroke: C.primary, p: 12, align: "CENTER" });
  impactCard.layoutAlign = "STRETCH";
  impactCard.appendChild(textNode("YOUR IMPACT", { size: 11, weight: "Semi Bold", color: C.primary, align: "CENTER", w: 224 }));
  impactCard.appendChild(textNode("\u267B\uFE0F 1 device saved from landfill\n\uD83E\uDD1D Helping someone hear again", { size: 12, align: "CENTER", w: 224 }));
  impactWrap.appendChild(impactCard);
  phone.appendChild(impactWrap);

  // Buttons
  const btns = alFrame("Buttons", { w: 280, pl: 16, pr: 16, pt: 12, gap: 8 });
  btns.layoutAlign = "STRETCH";
  btns.appendChild(buttonInstance(components.btnPrimary, "Donate Another Device", true));
  btns.appendChild(buttonInstance(components.btnGhost, "Go to Home", true));
  phone.appendChild(btns);

  return phone;
}

function buildScreen4A(page, x, y) {
  const phone = createPhoneFrame("4A. Hearing Needs");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Apply for a Device", true, ""));

  const progWrap = alFrame("Prog", { w: 280, align: "CENTER", gap: 0 });
  progWrap.layoutAlign = "STRETCH";
  progWrap.appendChild(components.progress1of4.createInstance());
  phone.appendChild(progWrap);

  // Title
  const titleFrame = alFrame("Title", { w: 280, gap: 2, align: "CENTER", pt: 4, pb: 4 });
  titleFrame.layoutAlign = "STRETCH";
  titleFrame.appendChild(textNode("Tell us about your hearing", { size: 15, weight: "Bold", align: "CENTER", w: 248 }));
  titleFrame.appendChild(textNode("This helps us find the right device", { size: 11, color: C.textMuted, align: "CENTER", w: 248 }));
  phone.appendChild(titleFrame);

  // Form
  const form = alFrame("Form", { w: 280, pl: 16, pr: 16, gap: 8 });
  form.layoutAlign = "STRETCH";

  // Degree
  const degLabel = textNode("DEGREE OF HEARING LOSS", { size: 10, weight: "Semi Bold", color: C.textMuted });
  degLabel.layoutAlign = "STRETCH";
  form.appendChild(degLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipDefault, "Mild"),
    chipInstance(components.chipBlue, "Moderate"),
    chipInstance(components.chipDefault, "Severe"),
    chipInstance(components.chipDefault, "Profound"),
    chipInstance(components.chipDefault, "Not sure"),
  ]));

  // Ear
  const earLabel = textNode("WHICH EAR(S)?", { size: 10, weight: "Semi Bold", color: C.textMuted });
  earLabel.layoutAlign = "STRETCH";
  form.appendChild(earLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipDefault, "Left"),
    chipInstance(components.chipDefault, "Right"),
    chipInstance(components.chipBlue, "Both"),
  ]));

  // Assessment
  const assLabel = textNode("RECENT HEARING ASSESSMENT?", { size: 10, weight: "Semi Bold", color: C.textMuted });
  assLabel.layoutAlign = "STRETCH";
  form.appendChild(assLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipGreen, "Yes, I can upload it"),
    chipInstance(components.chipDefault, "No"),
  ]));

  // Upload area
  const upload = alFrame("Upload", { w: 248, h: 36, fill: C.white, radius: 8,
    stroke: C.border, strokeW: 1.5, align: "CENTER", mainAlign: "CENTER" });
  upload.primaryAxisSizingMode = "FIXED"; upload.counterAxisSizingMode = "FIXED";
  upload.resize(248, 36);
  upload.layoutAlign = "STRETCH";
  upload.appendChild(textNode("\uD83D\uDCC4 Tap to upload PDF or photo", { size: 11, color: C.textMuted }));
  form.appendChild(upload);

  // Goals
  const goalsLabel = textNode("WHAT'S MOST IMPORTANT TO YOU?", { size: 10, weight: "Semi Bold", color: C.textMuted });
  goalsLabel.layoutAlign = "STRETCH";
  form.appendChild(goalsLabel);
  form.appendChild(textNode("Select up to 3 communication goals", { size: 10, color: C.textMuted, w: 248 }));
  form.appendChild(chipRow([
    chipInstance(components.chipBlue, "Conversations"),
    chipInstance(components.chipDefault, "Phone calls"),
    chipInstance(components.chipBlue, "Work"),
  ]));
  form.appendChild(chipRow([
    chipInstance(components.chipDefault, "TV / media"),
    chipInstance(components.chipDefault, "Learning English"),
    chipInstance(components.chipBlue, "Social"),
  ]));

  phone.appendChild(form);

  // CTA
  const cta = alFrame("CTA", { w: 280, pl: 16, pr: 16, pt: 6, gap: 0 });
  cta.layoutAlign = "STRETCH";
  cta.appendChild(buttonInstance(components.btnPrimary, "Continue", true));
  phone.appendChild(cta);

  return phone;
}

function buildScreen4B(page, x, y) {
  const phone = createPhoneFrame("4B. Your Situation");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "Apply for a Device", true, ""));

  const progWrap = alFrame("Prog", { w: 280, align: "CENTER", gap: 0 });
  progWrap.layoutAlign = "STRETCH";
  progWrap.appendChild(components.progress2of4.createInstance());
  phone.appendChild(progWrap);

  const form = alFrame("Form", { w: 280, pl: 16, pr: 16, gap: 6 });
  form.layoutAlign = "STRETCH";
  form.appendChild(sectionHeaderInstance(components.sectionHeader, "About You"));
  form.appendChild(inputInstance(components.inputField, "Location (suburb or postcode)", "Springvale, VIC 3171", true));
  form.appendChild(inputInstance(components.inputField, "Country of origin", "Afghanistan"));
  form.appendChild(inputInstance(components.inputField, "Preferred language", "Dari / Farsi"));

  // Visa
  const visaLabel = textNode("VISA / RESIDENCY STATUS", { size: 10, weight: "Semi Bold", color: C.textMuted });
  visaLabel.layoutAlign = "STRETCH";
  form.appendChild(visaLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipDefault, "Citizen"),
    chipInstance(components.chipDefault, "PR"),
    chipInstance(components.chipBlue, "Bridging visa"),
    chipInstance(components.chipDefault, "Other"),
  ]));

  // Previous access
  const prevLabel = textNode("TRIED ACCESSING HEARING AIDS BEFORE?", { size: 10, weight: "Semi Bold", color: C.textMuted });
  prevLabel.layoutAlign = "STRETCH";
  form.appendChild(prevLabel);
  form.appendChild(chipRow([
    chipInstance(components.chipBlue, "Yes, too expensive"),
    chipInstance(components.chipDefault, "Not eligible"),
    chipInstance(components.chipDefault, "No"),
  ]));

  // Upload
  const docLabel = textNode("SUPPORTING DOCUMENTS (OPTIONAL)", { size: 10, weight: "Semi Bold", color: C.textMuted });
  docLabel.layoutAlign = "STRETCH";
  form.appendChild(docLabel);
  const docUpload = alFrame("Doc Upload", { w: 248, h: 36, fill: C.white, radius: 8,
    stroke: C.border, strokeW: 1.5, align: "CENTER", mainAlign: "CENTER" });
  docUpload.primaryAxisSizingMode = "FIXED"; docUpload.counterAxisSizingMode = "FIXED";
  docUpload.resize(248, 36);
  docUpload.layoutAlign = "STRETCH";
  docUpload.appendChild(textNode("Referral letter, Centrelink card, etc.", { size: 11, color: C.textMuted }));
  form.appendChild(docUpload);
  phone.appendChild(form);

  // CTA
  const cta = alFrame("CTA", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  cta.layoutAlign = "STRETCH";
  cta.appendChild(buttonInstance(components.btnPrimary, "Submit Application", true));
  phone.appendChild(cta);

  return phone;
}

function buildScreen4C(page, x, y) {
  const phone = createPhoneFrame("4C. Application Status");
  phone.x = x; phone.y = y;
  page.appendChild(phone);

  phone.appendChild(components.statusBar.createInstance());
  phone.appendChild(navBarInstance(components.navBar, "My Application", false, ""));

  // Status hero
  const hero = alFrame("Status Hero", { w: 280, gap: 6, align: "CENTER", pt: 16, pb: 8 });
  hero.layoutAlign = "STRETCH";
  const statusIcon = alFrame("Icon", { w: 56, h: 56, fill: C.blueLight, radius: 28,
    align: "CENTER", mainAlign: "CENTER" });
  statusIcon.primaryAxisSizingMode = "FIXED"; statusIcon.counterAxisSizingMode = "FIXED";
  statusIcon.resize(56, 56);
  statusIcon.appendChild(textNode("\u23F3", { size: 24 }));
  hero.appendChild(statusIcon);
  hero.appendChild(textNode("Application Received", { size: 16, weight: "Bold", align: "CENTER", w: 248 }));
  hero.appendChild(textNode("Our team is reviewing your application.\nWe'll be in touch when we find a suitable device.", { size: 12, color: C.textMuted, align: "CENTER", w: 220 }));
  phone.appendChild(hero);

  // Progress card
  const cardWrap = alFrame("Card Wrap", { w: 280, pl: 16, pr: 16, gap: 0 });
  cardWrap.layoutAlign = "STRETCH";
  const card = alFrame("Progress Card", { w: 248, gap: 6, fill: C.white, radius: 12,
    stroke: C.border, p: 12 });
  card.layoutAlign = "STRETCH";
  card.appendChild(textNode("APPLICATION PROGRESS", { size: 11, weight: "Bold", color: C.textMuted }));

  const steps = [
    { label: "Application submitted", state: "done" },
    { label: "Under review", state: "active" },
    { label: "Device matched", state: "pending" },
    { label: "Device programmed", state: "pending" },
    { label: "Fitting appointment", state: "pending" },
    { label: "Active & connected", state: "pending" },
  ];

  steps.forEach(step => {
    const row = alFrame("Step", { direction: "HORIZONTAL", hug: true, hugCross: true, gap: 8, align: "CENTER" });
    row.layoutAlign = "STRETCH";

    const dot = alFrame("Dot", { w: 20, h: 20, radius: 10,
      fill: step.state === "done" ? C.success : step.state === "active" ? C.warning : C.border,
      align: "CENTER", mainAlign: "CENTER" });
    dot.primaryAxisSizingMode = "FIXED"; dot.counterAxisSizingMode = "FIXED";
    dot.resize(20, 20);
    if (step.state === "done") dot.appendChild(textNode("\u2713", { size: 10, weight: "Bold", color: C.white }));
    row.appendChild(dot);

    const textColor = step.state === "pending" ? C.textMuted : C.text;
    const textWeight = step.state === "active" ? "Semi Bold" : "Regular";
    row.appendChild(textNode(step.label, { size: 12, weight: textWeight, color: textColor }));
    card.appendChild(row);
  });

  cardWrap.appendChild(card);
  phone.appendChild(cardWrap);

  // Annotation
  const annWrap = alFrame("Ann Wrap", { w: 280, pl: 16, pr: 16, pt: 8, gap: 0 });
  annWrap.layoutAlign = "STRETCH";
  annWrap.appendChild(annotationInstance(components.annotation,
    "All state changes are admin-triggered (human in the loop)."));
  phone.appendChild(annWrap);

  const tabBar = components.tabBar3.createInstance();
  tabBar.layoutPositioning = "ABSOLUTE";
  tabBar.x = 0; tabBar.y = 504;
  phone.appendChild(tabBar);

  return phone;
}

// ─── Main ─────────────────────────────────────────────────────
async function main() {
  await loadFonts();

  // ── Create Design System Page ──
  const dsPage = figma.createPage();
  dsPage.name = "Design System";

  // Paint styles
  createPaintStyle("Primary", C.primary);
  createPaintStyle("Primary Light", C.primaryLight);
  createPaintStyle("Accent", C.accent);
  createPaintStyle("Text", C.text);
  createPaintStyle("Text Muted", C.textMuted);
  createPaintStyle("Border", C.border);
  createPaintStyle("Surface", C.surface);
  createPaintStyle("White", C.white);
  createPaintStyle("Success", C.success);
  createPaintStyle("Success Light", C.successLight);
  createPaintStyle("Warning", C.warning);
  createPaintStyle("Warning Light", C.warningLight);
  createPaintStyle("Error", C.error);
  createPaintStyle("Error Light", C.errorLight);
  createPaintStyle("Blue Light", C.blueLight);

  // Text styles
  createTextStyle("Heading / H1", 20, "Extra Bold", 28);
  createTextStyle("Heading / H2", 18, "Extra Bold", 24);
  createTextStyle("Heading / H3", 16, "Bold", 22);
  createTextStyle("Heading / H4", 15, "Bold", 20);
  createTextStyle("Body / Regular", 13, "Regular", 18);
  createTextStyle("Body / Medium", 13, "Medium", 18);
  createTextStyle("Body / Semi Bold", 13, "Semi Bold", 18);
  createTextStyle("Caption / Regular", 11, "Regular", 16);
  createTextStyle("Caption / Semi Bold", 11, "Semi Bold", 16);
  createTextStyle("Label / Uppercase", 10, "Semi Bold", 14);
  createTextStyle("Chip / Text", 10, "Semi Bold", 14);
  createTextStyle("Button / Label", 14, "Semi Bold", 20);
  createTextStyle("Nav / Title", 15, "Semi Bold", 20);

  // ── Create Components ──
  let cx = 0;
  const COL_GAP = 320;

  // Notch
  components.notch = createNotchComponent();
  dsPage.appendChild(components.notch);
  components.notch.x = cx; components.notch.y = 0;

  // Status bars
  components.statusBar = createStatusBarComponent(false);
  dsPage.appendChild(components.statusBar);
  components.statusBar.x = cx; components.statusBar.y = 40;

  components.statusBarDark = createStatusBarComponent(true);
  dsPage.appendChild(components.statusBarDark);
  components.statusBarDark.x = cx; components.statusBarDark.y = 100;

  // Nav bar
  components.navBar = createNavBarComponent();
  dsPage.appendChild(components.navBar);
  components.navBar.x = cx; components.navBar.y = 160;
  cx += COL_GAP;

  // Buttons
  components.btnPrimary = createButtonComponent("Button / Primary", C.primary, C.white);
  dsPage.appendChild(components.btnPrimary);
  components.btnPrimary.x = cx; components.btnPrimary.y = 0;

  components.btnOutline = createButtonComponent("Button / Outline", C.white, C.primary, C.primary);
  dsPage.appendChild(components.btnOutline);
  components.btnOutline.x = cx; components.btnOutline.y = 60;

  components.btnGhost = createButtonComponent("Button / Ghost", C.surface, C.text, C.border);
  dsPage.appendChild(components.btnGhost);
  components.btnGhost.x = cx; components.btnGhost.y = 120;

  // Input field
  components.inputField = createInputFieldComponent();
  dsPage.appendChild(components.inputField);
  components.inputField.x = cx; components.inputField.y = 200;
  cx += COL_GAP;

  // Chips
  components.chipGreen = createChipComponent("Chip / Green", C.successLight, C.successDark);
  dsPage.appendChild(components.chipGreen);
  components.chipGreen.x = cx; components.chipGreen.y = 0;

  components.chipAmber = createChipComponent("Chip / Amber", C.warningLight, C.amberText);
  dsPage.appendChild(components.chipAmber);
  components.chipAmber.x = cx; components.chipAmber.y = 40;

  components.chipRed = createChipComponent("Chip / Red", C.errorLight, C.errorDark);
  dsPage.appendChild(components.chipRed);
  components.chipRed.x = cx; components.chipRed.y = 80;

  components.chipBlue = createChipComponent("Chip / Blue", C.blueLight, C.blue);
  dsPage.appendChild(components.chipBlue);
  components.chipBlue.x = cx; components.chipBlue.y = 120;

  components.chipDefault = createChipComponent("Chip / Default", C.chipDefault, C.textMuted);
  dsPage.appendChild(components.chipDefault);
  components.chipDefault.x = cx; components.chipDefault.y = 160;

  // Spec row
  components.specRow = createSpecRowComponent();
  dsPage.appendChild(components.specRow);
  components.specRow.x = cx; components.specRow.y = 220;

  // Section header
  components.sectionHeader = createSectionHeaderComponent();
  dsPage.appendChild(components.sectionHeader);
  components.sectionHeader.x = cx; components.sectionHeader.y = 260;
  cx += COL_GAP;

  // List item
  components.listItem = createListItemComponent();
  dsPage.appendChild(components.listItem);
  components.listItem.x = cx; components.listItem.y = 0;

  // Confidence row
  components.confidenceRow = createConfidenceRowComponent();
  dsPage.appendChild(components.confidenceRow);
  components.confidenceRow.x = cx; components.confidenceRow.y = 80;

  // Annotation
  components.annotation = createAnnotationComponent();
  dsPage.appendChild(components.annotation);
  components.annotation.x = cx; components.annotation.y = 160;

  // Toggles
  components.toggleOn = createToggleComponent(true);
  dsPage.appendChild(components.toggleOn);
  components.toggleOn.x = cx; components.toggleOn.y = 240;

  components.toggleOff = createToggleComponent(false);
  dsPage.appendChild(components.toggleOff);
  components.toggleOff.x = cx; components.toggleOff.y = 300;
  cx += COL_GAP;

  // Tab bars
  components.tabBar0 = createTabBarComponent(0);
  dsPage.appendChild(components.tabBar0);
  components.tabBar0.x = cx; components.tabBar0.y = 0;

  components.tabBar1 = createTabBarComponent(1);
  dsPage.appendChild(components.tabBar1);
  components.tabBar1.x = cx; components.tabBar1.y = 70;

  components.tabBar2 = createTabBarComponent(2);
  dsPage.appendChild(components.tabBar2);
  components.tabBar2.x = cx; components.tabBar2.y = 140;

  components.tabBar3 = createTabBarComponent(3);
  dsPage.appendChild(components.tabBar3);
  components.tabBar3.x = cx; components.tabBar3.y = 210;

  // Progress steps
  components.progress0of3 = createProgressStepsComponent(0, 3);
  dsPage.appendChild(components.progress0of3);
  components.progress0of3.x = cx; components.progress0of3.y = 290;

  components.progress1of3 = createProgressStepsComponent(1, 3);
  dsPage.appendChild(components.progress1of3);
  components.progress1of3.x = cx; components.progress1of3.y = 320;

  components.progress1of4 = createProgressStepsComponent(1, 4);
  dsPage.appendChild(components.progress1of4);
  components.progress1of4.x = cx; components.progress1of4.y = 350;

  components.progress2of4 = createProgressStepsComponent(2, 4);
  dsPage.appendChild(components.progress2of4);
  components.progress2of4.x = cx; components.progress2of4.y = 380;

  // Card (generic)
  components.card = createCardComponent();
  dsPage.appendChild(components.card);
  components.card.x = cx; components.card.y = 420;

  // ── Create Wireframes Page ──
  const wfPage = figma.createPage();
  wfPage.name = "Wireframes";
  figma.currentPage = wfPage;

  const GAP = 80;
  const PHONE_W = 280;
  const ROW_GAP = 160;

  function flowLabel(x, y, title, desc) {
    const t = textNode(title, { size: 24, weight: "Bold" });
    t.x = x; t.y = y;
    wfPage.appendChild(t);
    if (desc) {
      const d = textNode(desc, { size: 14, color: C.textMuted, w: 900 });
      d.x = x; d.y = y + 36;
      wfPage.appendChild(d);
    }
  }

  function screenLabel(x, y, label) {
    const t = textNode(label, { size: 12, weight: "Semi Bold", color: C.textMuted, align: "CENTER", w: PHONE_W });
    t.x = x; t.y = y;
    wfPage.appendChild(t);
  }

  // Title
  const mainTitle = textNode("Recycled Sound", { size: 36, weight: "Extra Bold", color: C.primary });
  mainTitle.x = 0; mainTitle.y = -80;
  wfPage.appendChild(mainTitle);
  const subTitle = textNode("Wireframes v0.1 \u2014 Hearing Aid Scanner Flow + Donor Journey", { size: 14, color: C.textMuted });
  subTitle.x = 0; subTitle.y = -36;
  wfPage.appendChild(subTitle);

  // ── Flow 1 ──
  let rowY = 0;
  flowLabel(0, rowY, "Flow 1: Hearing Aid Scanner",
    "Google Lens-style: photograph a hearing aid, AI identifies brand, model, year, battery, wax filters, domes, moulds.");
  const l1Y = rowY + 80;
  const p1Y = l1Y + 24;
  for (let i = 0; i < 4; i++) screenLabel(i * (PHONE_W + GAP), l1Y, ["1A. HOME", "1B. CAMERA", "1C. AI ANALYSING", "1D. AI RESULTS"][i]);
  buildScreen1A(wfPage, 0, p1Y);
  buildScreen1B(wfPage, PHONE_W + GAP, p1Y);
  buildScreen1C(wfPage, 2 * (PHONE_W + GAP), p1Y);
  buildScreen1D(wfPage, 3 * (PHONE_W + GAP), p1Y);

  // ── Flow 2 ──
  rowY = p1Y + 560 + ROW_GAP;
  flowLabel(0, rowY, "Flow 2: Audiologist Review & QA",
    "Audiologist confirms AI specs, adds tech level / programming interface / gain range. Human-in-the-loop gate.");
  const l2Y = rowY + 80;
  const p2Y = l2Y + 24;
  for (let i = 0; i < 3; i++) screenLabel(i * (PHONE_W + GAP), l2Y, ["2A. QA QUEUE", "2B. AUDIOLOGIST REVIEW", "2C. DEVICE READY"][i]);
  buildScreen2A(wfPage, 0, p2Y);
  buildScreen2B(wfPage, PHONE_W + GAP, p2Y);
  buildScreen2C(wfPage, 2 * (PHONE_W + GAP), p2Y);

  // ── Flow 3 ──
  rowY = p2Y + 560 + ROW_GAP;
  flowLabel(0, rowY, "Flow 3: Donor Journey",
    "Donor signs up, scans device, fills donation form, gets impact confirmation.");
  const l3Y = rowY + 80;
  const p3Y = l3Y + 24;
  for (let i = 0; i < 3; i++) screenLabel(i * (PHONE_W + GAP), l3Y, ["3A. DONOR SIGNUP", "3B. DONATION FORM", "3C. CONFIRMATION"][i]);
  buildScreen3A(wfPage, 0, p3Y);
  buildScreen3B(wfPage, PHONE_W + GAP, p3Y);
  buildScreen3C(wfPage, 2 * (PHONE_W + GAP), p3Y);

  // ── Flow 4 ──
  rowY = p3Y + 560 + ROW_GAP;
  flowLabel(0, rowY, "Flow 4: Recipient Application",
    "Recipient describes hearing needs, situation, and tracks application status. All admin-mediated.");
  const l4Y = rowY + 80;
  const p4Y = l4Y + 24;
  for (let i = 0; i < 3; i++) screenLabel(i * (PHONE_W + GAP), l4Y, ["4A. HEARING NEEDS", "4B. YOUR SITUATION", "4C. APPLICATION STATUS"][i]);
  buildScreen4A(wfPage, 0, p4Y);
  buildScreen4B(wfPage, PHONE_W + GAP, p4Y);
  buildScreen4C(wfPage, 2 * (PHONE_W + GAP), p4Y);

  // ── Done ──
  figma.viewport.scrollAndZoomIntoView(wfPage.children);
  figma.notify("\uD83C\uDFB5 Recycled Sound wireframes generated with design system!", { timeout: 4000 });
  figma.closePlugin();
}

main();
