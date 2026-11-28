// ============================================================================
// BERNOULLI'S THEOREM VERIFICATION LAB - 6-SCREEN INTERACTIVE 3D SIMULATION
// Platform: Android Processing (APDE - P3D Mode, Landscape)
// Extracted from Lab Record (Ex. No. 6: Bernoulli's Experiment)
// ============================================================================

// --- GLOBAL UI & NAVIGATION STATE ---
int currentScreen = 0; // 0:3D Rig, 1:Cutaway, 2:Derivation, 3:Procedure, 4:Casio, 5:Table&Graph
String[] screenNames = {
  "1. 3D RIG",
  "2. CUTAWAY",
  "3. DERIVATION",
  "4. PROCEDURE",
  "5. CASIO CALC",
  "6. TABLE & GRAPH"
};

float uiScale = 1.0;
float topBarH, botBarH, contentTop, contentBot, contentH;

// --- APPARATUS CONSTANTS (FROM LAB RECORD) ---
final float GRAVITY = 9.81;        // m/s^2
final float TANK_L = 0.30;         // Collecting tank inner length = 300 mm = 0.3 m
final float TANK_B = 0.30;         // Collecting tank inner breadth = 300 mm = 0.3 m
final float TANK_AREA = 0.09;      // A_t = 0.3 * 0.3 = 0.09 m^2
final float RISE_H = 0.10;         // Height of water collection h = 10 cm = 0.1 m
final float COLLECT_VOL = 0.009;   // A_t * h = 0.009 m^3

// --- OBSERVATION TABLE DATA (5 DUCT SECTIONS: R1..R5) ---
int numReadings = 5;
int selectedReading = 0; // Default R1 (Section 1 - Model Calculation Row in Record)

int[] sectionNo     = { 1,        2,        3,        4,        5        };
float[] ductDia     = { 0.055,    0.050,    0.045,    0.040,    0.035    }; // m (55mm -> 35mm)
float[] ductArea    = { 0.00237,  0.00196,  0.00154,  0.00125,  0.000962 }; // m^2
float[] timeTaken   = { 28.0,     31.0,     31.0,     30.0,     29.0     }; // T (sec)
float[] dischargeQ  = { 0.000321, 0.000290, 0.000290, 0.000300, 0.000310 }; // Q (m^3/s)
float[] velocityV   = { 0.135,    0.147,    0.183,    0.240,    0.322    }; // V (m/s)
float[] velHead     = { 0.000928, 0.00110,  0.00168,  0.00293,  0.00528  }; // V^2/(2g) (m)
float[] piezoHead   = { 0.295,    0.293,    0.294,    0.295,    0.279    }; // [z + P/w] (m)
float[] totalHead   = { 0.2959,   0.2941,   0.2957,   0.2979,   0.2843   }; // H (m)
float meanTotalHead = 0.2936; // Average Total Head across S1..S5 (m)

// --- SCREEN 1: 3D RIG ORBIT & FLOW STATE ---
float rotX = -0.32;
float rotY = 0.42;
float zoom3D = 1.0;
boolean autoOrbit = true;
float flowSliderVal = 1.0; // 0.5x to 2.0x flow rate multiplier
boolean draggingSlider1 = false;
boolean draggingOrbit = false;
float lastTouchX, lastTouchY;

class FlowParticle3D {
  float progress; // 0.0 -> 1.0 along rig loop
  float radialOffset;
  float angleOffset;
  FlowParticle3D(float p, float r, float a) {
    progress = p;
    radialOffset = r;
    angleOffset = a;
  }
}
ArrayList<FlowParticle3D> rigParticles;

// --- SCREEN 2: 2D TRANSPARENT CUTAWAY & FLOW VISUALIZATION ---
boolean showParticles = true;
boolean showVectors = true;
boolean showStreamlines = true;
boolean showPathlines = true;
boolean showStreaklines = true;
boolean unsteadyMode = false;

float nozzleNormX = 0.14; // Normalized [0..1] inside cutaway duct
float nozzleNormY = 0.45;
float cutBoxX, cutBoxY, cutBoxW, cutBoxH; // Live bounds for touch injector

class CutawayParticle {
  float x, y; // Normalized [0..1] inside duct
  ArrayList<PVector> trail;
  CutawayParticle(float nx, float ny) {
    x = nx;
    y = ny;
    trail = new ArrayList<PVector>();
  }
}
ArrayList<CutawayParticle> cutParticles;
ArrayList<PVector> streakPoints;
float streakEmitTimer = 0;

// --- SCREEN 3: 7-STEP MATHEMATICAL DERIVATION ---
int derivStep = 0;
boolean autoDerive = false;
float autoDeriveTimer = 0;
String[] derivTitles = {
  "STEP 1: Euler's Equation Along a Streamline",
  "STEP 2: Integration for Steady Incompressible Flow",
  "STEP 3: Head Form (Specific Weight w = rho * g)",
  "STEP 4: Continuity Equation Across Duct Sections",
  "STEP 5: Experimental Discharge via Collecting Tank",
  "STEP 6: Section Flow Velocity & Velocity Head",
  "STEP 7: Bernoulli's Total Head Conservation"
};
String[] derivFormulas = {
  "(dP / rho) + g * dz + V * dV = 0",
  "Integral(dP / rho) + Integral(g * dz) + Integral(V * dV) = Const",
  "[ z + (P / w) ] + (V^2 / 2g) = H = Constant (m)",
  "Q = a1*V1 = a2*V2 = a3*V3 = a4*V4 = a5*V5",
  "Q = (A_t * h) / T   [ A_t = 0.3 x 0.3 = 0.09 m^2 ]",
  "V = Q / a  (m/s)   ==>   h_v = V^2 / (2 * 9.81)  (m)",
  "H_1 = H_2 = H_3 = H_4 = H_5 ~= 0.294 m (Verified)"
};
String[] derivNotes = {
  "Forces acting on an ideal fluid element along streamline s.",
  "Density rho and gravity g are constant for water in steady flow.",
  "Piezometric head [z + P/w] is measured directly by piezometers.",
  "As duct diameter narrows (55mm -> 35mm), velocity V increases.",
  "Volume collected (0.09 * 0.10 = 0.009 m^3) divided by time T.",
  "Kinetic energy per unit weight rises as cross-section narrows.",
  "Drop in pressure head balances rise in velocity head; H stays constant."
};

// --- SCREEN 4: 6-STEP LAB PROCEDURE & ZOOMED INSTRUMENTS ---
int procStep = 0;
boolean autoDemo = true;
float autoDemoTimer = 0;
float stopwatchSim = 0;
String[] procTitles = {
  "1. Measure Duct Sections & Collecting Tank",
  "2. Start Pump & Purge Piezometer Air Bubbles",
  "3. Stabilize Head in Balancing Tank",
  "4. Record Piezometer Water Levels [z + P/w]",
  "5. Time h = 10 cm Rise in Collecting Tank",
  "6. Vary Flow via Outlet Valve & Repeat"
};
String[] procDetails = {
  "Measure diameters d1..d5 (55 to 35 mm) and tank inner plan (300 x 300 mm).",
  "Open delivery & outlet valves; bleed trapped air bubbles from all 5 tubes.",
  "Regulate outlet valve until water level in balancing tank stays steady.",
  "Taking duct bed as datum, note water column height [z + P/w] in each tube.",
  "Close gate valve; use stopwatch to measure time T for h = 0.1 m rise.",
  "Change flow rate with outlet valve, repeat readings, and switch off pump."
};

// --- SCREEN 5: BODMAS BREAKDOWN & 47-KEY CASIO fx-991MS ---
int bodmasStep = 0;
String[] bodmasBadges = { "B", "B", "D", "O", "D", "O", "D", "A" };
String[] bodmasNames = {
  "1. Collecting Tank Area (A_t)",
  "2. Collected Water Volume (Vol)",
  "3. Actual Discharge (Q)",
  "4. Duct Cross-Section Area (a)",
  "5. Flow Velocity at Section (V)",
  "6. Velocity Squared (V^2)",
  "7. Velocity Head (V^2 / 2g)",
  "8. Total Bernoulli Head (H)"
};

String casioCustomExpr = "";
String casioCustomAns = "";
boolean casioManualMode = false;
boolean casioShift = false;
boolean casioAlpha = false;

// 22 Scientific Keys (4 rows: 6 + 6 + 5 + 5)
String[][] sciKeys = {
  { "d/dx", "x!",  "nPr", "Pol(", "x^3", "" },
  { "a b/c","sqrt","x^2", "^",    "log", "ln" },
  { "(-)",  "o'\"", "hyp", "sin",  "cos", "tan" },
  { "RCL",  "ENG", "(",   ")",    ",",   "M+" }
};
String[][] sciShift = {
  { "Integral","x^-1","nCr","Rec(","3sqrt","" },
  { "d/c",  "",    "",    "x-root","10^x","e^x" },
  { "A",    "<-",  "B",   "sin^-1","cos^-1","tan^-1" },
  { "STO",  "<-",  "%",   "X",    ";",   "M-" }
};

// 20 Numeric & Operator Keys (4 rows x 5 cols)
String[][] numKeys = {
  { "7", "8", "9", "DEL", "AC" },
  { "4", "5", "6", "x",   "/"  },
  { "1", "2", "3", "+",   "-"  },
  { "0", ".", "EXP","Ans","="  }
};
String[][] numShift = {
  { "CONST","CONV","CLR","INS","OFF" },
  { "",     "",    "",   "",   ""    },
  { "S-SUM","S-VAR","DISTR","",""    },
  { "Rnd",  "Ran#","pi", "DRG>","%"  }
};

// --- SCREEN 6: GRAPH ANIMATION ---
float graphAnim = 0.0;

// ============================================================================
// PROCESSING LIFECYCLE
// ============================================================================
void settings() {
  fullScreen(P3D);
}

void setup() {
  orientation(LANDSCAPE);
  smooth(4);
  textFont(createFont("SansSerif", 16, true));
  initSimulations();
}

void initSimulations() {
  rigParticles = new ArrayList<FlowParticle3D>();
  for (int i = 0; i < 65; i++) {
    rigParticles.add(new FlowParticle3D(i / 65.0, random(-0.65, 0.65), random(TWO_PI)));
  }

  cutParticles = new ArrayList<CutawayParticle>();
  for (int i = 0; i < 42; i++) {
    cutParticles.add(new CutawayParticle(random(0.02, 0.98), random(0.15, 0.85)));
  }

  streakPoints = new ArrayList<PVector>();
}

void computeLayoutMetrics() {
  uiScale = constrain(min(width / 1280.0, height / 720.0), 0.55, 1.5);
  topBarH = 54 * uiScale;
  botBarH = 50 * uiScale;
  contentTop = topBarH + 8 * uiScale;
  contentBot = height - botBarH - 8 * uiScale;
  contentH = contentBot - contentTop;
}

void draw() {
  computeLayoutMetrics();
  updateAnimations();

  background(12, 18, 28);

  if (currentScreen == 0) {
    drawScreen1_3DRig();
  } else {
    beginHUD();
    if (currentScreen == 1) drawScreen2_CutawayPhysics();
    else if (currentScreen == 2) drawScreen3_Derivation();
    else if (currentScreen == 3) drawScreen4_Procedure();
    else if (currentScreen == 4) drawScreen5_CasioCalc();
    else if (currentScreen == 5) drawScreen6_TableAndGraph();
    endHUD();
  }

  // Draw persistent Top Navigation Bar & Bottom Navigation Bar in 2D HUD
  beginHUD();
  drawTopNavBar();
  drawBottomNavBar();
  endHUD();
}

void updateAnimations() {
  float dt = 1.0 / max(frameRate, 30.0);

  if (currentScreen == 0 && autoOrbit && !draggingOrbit) {
    rotY += 0.0045;
  }

  // Update 3D Rig particles
  float speedFactor = (velocityV[selectedReading] / 0.135) * flowSliderVal * 0.0032;
  for (FlowParticle3D p : rigParticles) {
    float localMult = 1.0;
    if (p.progress > 0.35 && p.progress < 0.72) {
      // Accelerate inside converging duct
      float tDuct = map(p.progress, 0.35, 0.72, 1.0, 2.38);
      localMult = tDuct;
    }
    p.progress += speedFactor * localMult;
    if (p.progress > 1.0) p.progress -= 1.0;
  }

  // Update Screen 2 Cutaway particles & streaklines
  if (currentScreen == 1) {
    float vBase = velocityV[selectedReading] * 1.4;
    float wave = unsteadyMode ? (1.0 + 0.35 * sin(frameCount * 0.09)) : 1.0;
    for (CutawayParticle cp : cutParticles) {
      float areaFactor = map(cp.x, 0.0, 1.0, 1.0, 2.46); // Continuity acceleration
      float vx = 0.0038 * vBase * areaFactor * wave;
      float vy = unsteadyMode ? 0.0025 * sin(cp.x * 12.0 - frameCount * 0.12) : 0.0;
      cp.x += vx;
      cp.y = constrain(cp.y + vy, 0.12, 0.88);
      cp.trail.add(new PVector(cp.x, cp.y));
      if (cp.trail.size() > 18) cp.trail.remove(0);
      if (cp.x > 0.99) {
        cp.x = 0.01;
        cp.y = random(0.15, 0.85);
        cp.trail.clear();
      }
    }

    streakEmitTimer += dt;
    if (streakEmitTimer > 0.04) {
      streakEmitTimer = 0;
      streakPoints.add(new PVector(nozzleNormX, nozzleNormY));
      if (streakPoints.size() > 85) streakPoints.remove(0);
    }
    for (int i = streakPoints.size() - 1; i >= 0; i--) {
      PVector sp = streakPoints.get(i);
      float areaFactor = map(sp.x, 0.0, 1.0, 1.0, 2.46);
      sp.x += 0.0042 * vBase * areaFactor * wave;
      if (unsteadyMode) {
        sp.y += 0.0032 * sin(sp.x * 14.0 - frameCount * 0.14);
      }
      if (sp.x > 0.99) streakPoints.remove(i);
    }
  }

  // Auto-derive timer on Screen 3
  if (currentScreen == 2 && autoDerive) {
    autoDeriveTimer += dt;
    if (autoDeriveTimer > 2.6) {
      autoDeriveTimer = 0;
      derivStep = (derivStep + 1) % derivTitles.length;
    }
  }

  // Auto-demo & live stopwatch on Screen 4
  if (currentScreen == 3) {
    if (autoDemo) {
      autoDemoTimer += dt;
      if (autoDemoTimer > 3.2) {
        autoDemoTimer = 0;
        procStep = (procStep + 1) % procTitles.length;
      }
    }
    stopwatchSim += dt * 4.5;
    if (stopwatchSim > timeTaken[selectedReading]) {
      stopwatchSim = 0;
    }
  }

  // Graph reveal animation on Screen 6
  if (currentScreen == 5) {
    graphAnim = min(1.0, graphAnim + 0.03);
  }
}

// ============================================================================
// HUD & DRAWING HELPERS
// ============================================================================
void beginHUD() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  ortho();
  noLights();
}

void endHUD() {
  hint(ENABLE_DEPTH_TEST);
}

void drawPanelCard(float x, float y, float w, float h, color fillCol, color strokeCol) {
  fill(fillCol);
  stroke(strokeCol);
  strokeWeight(1.5 * uiScale);
  rect(x, y, w, h, 10 * uiScale);
}

void drawSectionHeader(String title, float x, float y, float w) {
  fill(24, 38, 58);
  noStroke();
  rect(x, y, w, 32 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(90, 210, 255);
  textAlign(LEFT, CENTER);
  textSize(14 * uiScale);
  text(title, x + 12 * uiScale, y + 16 * uiScale);
}

void drawPillButton(String label, float x, float y, float w, float h, boolean active, color activeBg) {
  if (active) {
    fill(activeBg);
    stroke(255, 230, 120);
    strokeWeight(2.0 * uiScale);
  } else {
    fill(28, 42, 64);
    stroke(70, 105, 145);
    strokeWeight(1.2 * uiScale);
  }
  rect(x, y, w, h, 7 * uiScale);
  fill(active ? color(255) : color(205, 222, 242));
  textAlign(CENTER, CENTER);
  textSize(12.5 * uiScale);
  text(label, x + w * 0.5, y + h * 0.5);
}

void draw2DArrow(float x1, float y1, float x2, float y2, color c, float weight) {
  stroke(c);
  strokeWeight(weight);
  line(x1, y1, x2, y2);
  float ang = atan2(y2 - y1, x2 - x1);
  float headLen = 9 * uiScale;
  fill(c);
  noStroke();
  triangle(
    x2, y2,
    x2 - headLen * cos(ang - 0.42), y2 - headLen * sin(ang - 0.42),
    x2 - headLen * cos(ang + 0.42), y2 - headLen * sin(ang + 0.42)
  );
}

// ============================================================================
// TOP & BOTTOM NAVIGATION BARS
// ============================================================================
void drawTopNavBar() {
  fill(16, 25, 38, 248);
  noStroke();
  rect(0, 0, width, topBarH);
  stroke(50, 80, 115);
  strokeWeight(1.2 * uiScale);
  line(0, topBarH, width, topBarH);

  // Left Experiment Badge
  float badgeW = 248 * uiScale;
  fill(22, 48, 76);
  stroke(75, 175, 235);
  strokeWeight(1.4 * uiScale);
  rect(8 * uiScale, 7 * uiScale, badgeW, topBarH - 14 * uiScale, 8 * uiScale);

  fill(100, 225, 255);
  textAlign(LEFT, CENTER);
  textSize(13.5 * uiScale);
  text("BERNOULLI APPARATUS LAB", 18 * uiScale, topBarH * 0.36);
  fill(180, 205, 230);
  textSize(10.5 * uiScale);
  text("Ex.6 | Duct 55->35mm | Tank 0.3x0.3m", 18 * uiScale, topBarH * 0.72);

  // 6 Screen Tabs
  float tabsStartX = badgeW + 18 * uiScale;
  float tabsAvailW = width - tabsStartX - 10 * uiScale;
  float gap = 6 * uiScale;
  float tabW = (tabsAvailW - gap * 5) / 6.0;
  float tabH = topBarH - 14 * uiScale;

  for (int i = 0; i < 6; i++) {
    float tx = tabsStartX + i * (tabW + gap);
    float ty = 7 * uiScale;
    boolean isCur = (i == currentScreen);
    if (isCur) {
      fill(28, 125, 195);
      stroke(120, 230, 255);
      strokeWeight(2.0 * uiScale);
    } else {
      fill(24, 36, 54);
      stroke(55, 82, 115);
      strokeWeight(1.0 * uiScale);
    }
    rect(tx, ty, tabW, tabH, 7 * uiScale);

    fill(isCur ? color(255) : color(185, 205, 228));
    textAlign(CENTER, CENTER);
    textSize(11.5 * uiScale);
    text(screenNames[i], tx + tabW * 0.5, ty + tabH * 0.5);
  }
}

void drawBottomNavBar() {
  float by = height - botBarH;
  fill(16, 25, 38, 248);
  noStroke();
  rect(0, by, width, botBarH);
  stroke(50, 80, 115);
  strokeWeight(1.2 * uiScale);
  line(0, by, width, by);

  float btnW = 165 * uiScale;
  float btnH = botBarH - 12 * uiScale;
  float btnY = by + 6 * uiScale;

  // < PREV SCREEN
  drawPillButton("< PREV SCREEN", 12 * uiScale, btnY, btnW, btnH, currentScreen > 0, color(34, 95, 145));

  // Center Active Reading Quick Selector (S1..S5)
  float pillW = 62 * uiScale;
  float pillGap = 6 * uiScale;
  float groupW = 5 * pillW + 4 * pillGap;
  float startX = width * 0.5 - groupW * 0.5 + 35 * uiScale;

  fill(185, 210, 235);
  textAlign(RIGHT, CENTER);
  textSize(12 * uiScale);
  text("Active Section:", startX - 10 * uiScale, by + botBarH * 0.5);

  for (int i = 0; i < numReadings; i++) {
    float px = startX + i * (pillW + pillGap);
    boolean sel = (i == selectedReading);
    drawPillButton("S" + sectionNo[i], px, btnY, pillW, btnH, sel, color(210, 135, 25));
  }

  // NEXT SCREEN >
  drawPillButton("NEXT SCREEN >", width - btnW - 12 * uiScale, btnY, btnW, btnH, currentScreen < 5, color(34, 125, 185));
}

// ============================================================================
// SCREEN 1: FULL 3D BERNOULLI APPARATUS RIG (P3D)
// ============================================================================
void drawScreen1_3DRig() {
  // 3D Lighting & Perspective Camera
  perspective(PI / 3.2, float(width) / float(height), 10, 5000);
  ambientLight(95, 105, 120);
  directionalLight(235, 242, 255, -0.4, 0.7, -0.6);
  pointLight(90, 195, 255, 0, -220, 260);

  pushMatrix();
  translate(width * 0.54, height * 0.53, -80);
  scale(uiScale * zoom3D);
  rotateX(rotX);
  rotateY(rotY);
  drawApparatus3D();
  popMatrix();

  // 2D Overlay HUD for Screen 1
  beginHUD();
  drawScreen1HUD();
  endHUD();
}

void drawApparatus3D() {
  // 1. Floor Base & Steel Support Stand
  pushMatrix();
  translate(0, 165, 0);
  fill(32, 42, 56);
  stroke(65, 85, 110);
  strokeWeight(1);
  box(660, 14, 240);
  popMatrix();

  // Vertical Stand Legs supporting Tapered Duct
  fill(70, 82, 98);
  noStroke();
  float[] legX = { -160, 110 };
  float[] legZ = { -35, 35 };
  for (float lx : legX) {
    for (float lz : legZ) {
      pushMatrix();
      translate(lx, 75, lz);
      box(10, 168, 10);
      popMatrix();
    }
  }

  // 2. Main Reservoir Tank (Bottom Right)
  pushMatrix();
  translate(215, 118, 0);
  // Water inside reservoir
  fill(35, 145, 225, 175);
  noStroke();
  box(176, 62, 136);
  // Tank glass walls
  noFill();
  stroke(140, 210, 255);
  strokeWeight(1.5);
  box(180, 80, 140);
  popMatrix();

  // 3. Motor Pump Set (Bottom Center-Right)
  pushMatrix();
  translate(75, 135, 0);
  // Motor body
  fill(45, 115, 175);
  noStroke();
  drawCylinderX(52, 24);
  // Pump volute casing
  translate(-38, 0, 0);
  fill(210, 95, 45);
  drawCylinderZ(22, 26);
  popMatrix();

  // Suction Pipe (Reservoir -> Pump)
  fill(140, 155, 172);
  noStroke();
  pushMatrix();
  translate(115, 142, 0);
  box(65, 10, 10);
  popMatrix();

  // Delivery Pipe (Pump -> Delivery Valve -> Balancing Tank)
  pushMatrix();
  translate(-110, 142, 0);
  box(295, 10, 10);
  popMatrix();
  pushMatrix();
  translate(-255, 62, 0);
  box(10, 170, 10);
  popMatrix();

  // Red Delivery Valve Handwheel
  pushMatrix();
  translate(-155, 142, 14);
  fill(225, 55, 55);
  drawCylinderZ(6, 16);
  popMatrix();

  // 4. Balancing Tank (Left Vertical Constant-Head Tank)
  pushMatrix();
  translate(-255, -35, 0);
  // Water column inside balancing tank
  fill(40, 165, 245, 185);
  noStroke();
  box(44, 152, 44);
  // Glass housing
  noFill();
  stroke(165, 225, 255);
  strokeWeight(1.5);
  box(48, 175, 48);
  popMatrix();

  // 5. Converging Tapered Glass Duct (d1 = 55mm at Section 1 -> d5 = 35mm at Section 5)
  float ductX0 = -195;
  float ductX1 = 125;
  float ductY = -10;
  int segs = 28;
  for (int i = 0; i < segs; i++) {
    float t0 = i / float(segs);
    float t1 = (i + 1) / float(segs);
    float xA = lerp(ductX0, ductX1, t0);
    float xB = lerp(ductX0, ductX1, t1);
    float rA = lerp(24, 15, t0);
    float rB = lerp(24, 15, t1);

    // Inner water core
    fill(45, 185, 255, 165);
    noStroke();
    drawFrustumX(xA, xB, ductY, 0, rA * 0.88, rB * 0.88);

    // Outer glass duct wall
    fill(190, 235, 255, 55);
    drawFrustumX(xA, xB, ductY, 0, rA, rB);
  }

  // 6. Five Section Rings & Five Graduated Piezometer Tubes (S1..S5)
  float[] secX = { -160, -95, -30, 35, 100 };
  for (int i = 0; i < numReadings; i++) {
    float sx = secX[i];
    float tSec = map(sx, ductX0, ductX1, 0, 1);
    float rSec = lerp(24, 15, tSec);
    boolean isSel = (i == selectedReading);

    // Highlight ring around duct section
    pushMatrix();
    translate(sx, ductY, 0);
    fill(isSel ? color(255, 200, 40) : color(95, 175, 225));
    noStroke();
    drawCylinderX(isSel ? 7 : 4, rSec + (isSel ? 3.5 : 1.5));
    popMatrix();

    // Vertical Piezometer Glass Tube
    float tubeH = 175;
    float tubeBottomY = ductY - rSec;
    pushMatrix();
    translate(sx, tubeBottomY - tubeH * 0.5, 0);
    fill(220, 245, 255, 65);
    stroke(140, 200, 240, 140);
    strokeWeight(1);
    box(8, tubeH, 8);
    popMatrix();

    // Piezometer Water Column matching [z + P/w] (0.295m -> 0.279m)
    float waterH = map(piezoHead[i], 0.250, 0.310, 95, 148);
    pushMatrix();
    translate(sx, tubeBottomY - waterH * 0.5, 0);
    fill(isSel ? color(255, 195, 45, 230) : color(45, 185, 255, 215));
    noStroke();
    box(5.5, waterH, 5.5);
    popMatrix();
  }

  // 7. Outlet Pipe & Outlet Control Valve -> Collecting Tank
  fill(140, 155, 172);
  noStroke();
  pushMatrix();
  translate(168, ductY, 0);
  box(86, 12, 12);
  popMatrix();

  // Green Outlet Valve
  pushMatrix();
  translate(162, ductY - 14, 0);
  fill(55, 205, 115);
  drawCylinderY(6, 14);
  popMatrix();

  // 8. Collecting Tank (300mm x 300mm) above Reservoir
  pushMatrix();
  translate(230, 25, 0);
  // Water rising inside collecting tank
  float riseAnim = map(stopwatchSim % 10.0, 0, 10.0, 14, 42);
  fill(50, 190, 255, 190);
  noStroke();
  translate(0, 32 - riseAnim * 0.5, 0);
  box(86, riseAnim, 86);
  popMatrix();

  pushMatrix();
  translate(230, 25, 0);
  noFill();
  stroke(170, 225, 255);
  strokeWeight(1.5);
  box(90, 66, 90);
  popMatrix();

  // 9. Animated 3D Flow Particles along Hydraulic Circuit
  for (FlowParticle3D p : rigParticles) {
    float px = 0, py = 0, pz = 0;
    if (p.progress < 0.20) {
      // Delivery line bottom
      float t = p.progress / 0.20;
      px = lerp(40, -255, t);
      py = 142;
    } else if (p.progress < 0.35) {
      // Rising up balancing tank
      float t = (p.progress - 0.20) / 0.15;
      px = -255 + cos(p.angleOffset) * 10 * p.radialOffset;
      py = lerp(142, -10, t);
      pz = sin(p.angleOffset) * 10 * p.radialOffset;
    } else if (p.progress < 0.75) {
      // Flowing through converging duct S1 -> S5
      float t = (p.progress - 0.35) / 0.40;
      px = lerp(ductX0, ductX1, t);
      float rLocal = lerp(18, 10, t) * abs(p.radialOffset);
      py = ductY + cos(p.angleOffset) * rLocal;
      pz = sin(p.angleOffset) * rLocal;
    } else {
      // Outlet pipe into collecting tank
      float t = (p.progress - 0.75) / 0.25;
      px = lerp(ductX1, 225, t);
      py = lerp(ductY, 15, t * t);
    }

    pushMatrix();
    translate(px, py, pz);
    float speedCol = constrain(map(p.progress, 0.35, 0.75, 0, 1), 0, 1);
    fill(lerpColor(color(70, 220, 255), color(255, 210, 60), speedCol));
    noStroke();
    sphere(3.2);
    popMatrix();
  }
}

void drawCylinderX(float len, float rad) {
  int sides = 18;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = i * TWO_PI / sides;
    float y = cos(a) * rad;
    float z = sin(a) * rad;
    vertex(-len * 0.5, y, z);
    vertex(len * 0.5, y, z);
  }
  endShape();
}

void drawCylinderY(float h, float rad) {
  int sides = 18;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = i * TWO_PI / sides;
    float x = cos(a) * rad;
    float z = sin(a) * rad;
    vertex(x, -h * 0.5, z);
    vertex(x, h * 0.5, z);
  }
  endShape();
}

void drawCylinderZ(float depth, float rad) {
  int sides = 18;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = i * TWO_PI / sides;
    float x = cos(a) * rad;
    float y = sin(a) * rad;
    vertex(x, y, -depth * 0.5);
    vertex(x, y, depth * 0.5);
  }
  endShape();
}

void drawFrustumX(float x0, float x1, float cy, float cz, float r0, float r1) {
  int sides = 20;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = i * TWO_PI / sides;
    float ca = cos(a);
    float sa = sin(a);
    vertex(x0, cy + ca * r0, cz + sa * r0);
    vertex(x1, cy + ca * r1, cz + sa * r1);
  }
  endShape();
}

void drawScreen1HUD() {
  int r = selectedReading;
  float cardX = 14 * uiScale;
  float cardY = contentTop + 4 * uiScale;
  float cardW = 325 * uiScale;
  float cardH = 310 * uiScale;

  // Live Telemetry Card
  drawPanelCard(cardX, cardY, cardW, cardH, color(15, 25, 40, 225), color(65, 145, 210));
  drawSectionHeader("LIVE TELEMETRY - SECTION S" + sectionNo[r], cardX, cardY, cardW);

  String[][] rows = {
    { "Duct Diameter (d):", nf(ductDia[r] * 1000, 0, 0) + " mm (" + nf(ductDia[r], 1, 3) + " m)" },
    { "Cross-Section Area (a):", nf(ductArea[r], 1, 6) + " m^2" },
    { "Time for 0.1m Rise (T):", nf(timeTaken[r], 0, 0) + " sec" },
    { "Discharge (Q):", nf(dischargeQ[r], 1, 6) + " m^3/s" },
    { "Flow Velocity (V):", nf(velocityV[r], 1, 3) + " m/s" },
    { "Velocity Head (V^2/2g):", nf(velHead[r], 1, 6) + " m" },
    { "Piezometric [z + P/w]:", nf(piezoHead[r], 1, 3) + " m (" + nf(piezoHead[r]*100, 0, 1) + " cm)" },
    { "TOTAL HEAD (H):", nf(totalHead[r], 1, 4) + " m (Const)" }
  };

  float rowY = cardY + 42 * uiScale;
  float rowStep = 31 * uiScale;
  for (int i = 0; i < rows.length; i++) {
    boolean isTotal = (i == rows.length - 1);
    if (isTotal) {
      fill(25, 65, 95);
      noStroke();
      rect(cardX + 8 * uiScale, rowY - 4 * uiScale, cardW - 16 * uiScale, 26 * uiScale, 5 * uiScale);
    }
    fill(isTotal ? color(255, 220, 90) : color(175, 200, 225));
    textAlign(LEFT, CENTER);
    textSize(12 * uiScale);
    text(rows[i][0], cardX + 14 * uiScale, rowY + 8 * uiScale);

    fill(isTotal ? color(110, 255, 175) : color(245));
    textAlign(RIGHT, CENTER);
    text(rows[i][1], cardX + cardW - 14 * uiScale, rowY + 8 * uiScale);
    rowY += rowStep;
  }

  // Bottom-Left Flow & Camera Control Card
  float ctrlY = contentBot - 118 * uiScale;
  float ctrlH = 114 * uiScale;
  drawPanelCard(cardX, ctrlY, cardW, ctrlH, color(15, 25, 40, 225), color(65, 145, 210));

  fill(190, 215, 240);
  textAlign(LEFT, CENTER);
  textSize(12 * uiScale);
  text("Flow Valve Multiplier: " + nf(flowSliderVal, 1, 2) + "x", cardX + 14 * uiScale, ctrlY + 18 * uiScale);

  // Slider track
  float slX = cardX + 14 * uiScale;
  float slY = ctrlY + 38 * uiScale;
  float slW = cardW - 28 * uiScale;
  float slH = 10 * uiScale;
  fill(35, 52, 75);
  noStroke();
  rect(slX, slY, slW, slH, 5 * uiScale);
  float knobX = map(flowSliderVal, 0.5, 2.0, slX, slX + slW);
  fill(65, 195, 255);
  rect(slX, slY, knobX - slX, slH, 5 * uiScale);
  fill(255, 215, 70);
  ellipse(knobX, slY + slH * 0.5, 18 * uiScale, 18 * uiScale);

  // Camera buttons: Auto-Orbit, Zoom -, Zoom +
  float bY = ctrlY + 62 * uiScale;
  float bH = 38 * uiScale;
  float bW = (cardW - 36 * uiScale) / 3.0;
  drawPillButton(autoOrbit ? "Orbit: ON" : "Orbit: OFF", cardX + 12 * uiScale, bY, bW, bH, autoOrbit, color(32, 130, 95));
  drawPillButton("Zoom -", cardX + 18 * uiScale + bW, bY, bW, bH, false, color(40, 90, 140));
  drawPillButton("Zoom +", cardX + 24 * uiScale + 2 * bW, bY, bW, bH, false, color(40, 90, 140));

  // Top-right 3D Legend & Gesture Hint Pill
  float legW = 290 * uiScale;
  float legH = 74 * uiScale;
  float legX = width - legW - 14 * uiScale;
  float legY = contentTop + 4 * uiScale;
  drawPanelCard(legX, legY, legW, legH, color(15, 25, 40, 215), color(60, 110, 160));
  fill(110, 225, 255);
  textAlign(LEFT, CENTER);
  textSize(12 * uiScale);
  text("3D Rig Controls & Apparatus Key", legX + 12 * uiScale, legY + 18 * uiScale);
  fill(200, 218, 238);
  textSize(11 * uiScale);
  text("Drag anywhere to rotate 3D rig", legX + 12 * uiScale, legY + 38 * uiScale);
  text("Gold Ring/Tube = Active Section S" + sectionNo[r], legX + 12 * uiScale, legY + 56 * uiScale);
}

// ============================================================================
// SCREEN 2: 2D TRANSPARENT CUTAWAY & FLOW VISUALIZATION
// ============================================================================
void drawScreen2_CutawayPhysics() {
  int r = selectedReading;
  float margin = 12 * uiScale;
  float leftW = width - 295 * uiScale - margin * 3;
  float rightX = margin * 2 + leftW;
  float rightW = 295 * uiScale;

  // Main Cutaway Viewport Card
  drawPanelCard(margin, contentTop, leftW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("2D TRANSPARENT CUTAWAY - CONVERGING DUCT & 5 PIEZOMETERS", margin, contentTop, leftW);

  // Define Cutaway Duct Coordinates
  float tankW = 72 * uiScale;
  float tankX = margin + 22 * uiScale;
  float tankY = contentTop + 56 * uiScale;
  float tankH = contentH - 84 * uiScale;

  // Balancing Tank on Left
  fill(26, 42, 65);
  stroke(120, 195, 245);
  strokeWeight(2 * uiScale);
  rect(tankX, tankY, tankW, tankH, 4 * uiScale);
  // Water inside Balancing Tank
  fill(35, 145, 225, 165);
  noStroke();
  rect(tankX + 3 * uiScale, tankY + 26 * uiScale, tankW - 6 * uiScale, tankH - 29 * uiScale);
  fill(215, 238, 255);
  textAlign(CENTER, CENTER);
  textSize(10.5 * uiScale);
  text("BALANCING\nTANK", tankX + tankW * 0.5, tankY + tankH * 0.5);

  // Converging Duct Geometry
  cutBoxX = tankX + tankW;
  cutBoxW = leftW - tankW - 56 * uiScale;
  float ductCenterY = contentTop + contentH * 0.74;
  float halfH1 = 62 * uiScale; // Section 1 (d1 = 55mm)
  float halfH5 = 38 * uiScale; // Section 5 (d5 = 35mm)
  cutBoxY = ductCenterY - halfH1;
  cutBoxH = halfH1 * 2;

  // Draw Water Fill inside Converging Duct
  fill(24, 95, 155, 190);
  noStroke();
  quad(
    cutBoxX, ductCenterY - halfH1,
    cutBoxX + cutBoxW, ductCenterY - halfH5,
    cutBoxX + cutBoxW, ductCenterY + halfH5,
    cutBoxX, ductCenterY + halfH1
  );

  // Draw Glass Walls of Converging Duct
  stroke(145, 220, 255);
  strokeWeight(2.5 * uiScale);
  line(cutBoxX, ductCenterY - halfH1, cutBoxX + cutBoxW, ductCenterY - halfH5);
  line(cutBoxX, ductCenterY + halfH1, cutBoxX + cutBoxW, ductCenterY + halfH5);

  // 1. Instantaneous Streamlines
  if (showStreamlines) {
    stroke(90, 230, 255, 110);
    strokeWeight(1.3 * uiScale);
    noFill();
    for (int s = -3; s <= 3; s++) {
      float frac = s / 4.0;
      beginShape();
      for (int k = 0; k <= 20; k++) {
        float t = k / 20.0;
        float sx = cutBoxX + t * cutBoxW;
        float hLocal = lerp(halfH1, halfH5, t);
        float waveOff = unsteadyMode ? sin(t * 10.0 - frameCount * 0.12) * 4 * uiScale * (1.0 - abs(frac)) : 0;
        float sy = ductCenterY + frac * hLocal + waveOff;
        vertex(sx, sy);
      }
      endShape();
    }
  }

  // 2. Particle Pathlines & Color-Coded Velocity Particles
  for (CutawayParticle cp : cutParticles) {
    float px = cutBoxX + cp.x * cutBoxW;
    float hLocal = lerp(halfH1, halfH5, cp.x);
    float py = ductCenterY + (cp.y - 0.5) * 1.75 * hLocal;
    float speedNorm = cp.x; // Accelerates from left (0) to right (1)
    color pCol = lerpColor(color(65, 215, 255), color(255, 165, 45), speedNorm);

    if (showPathlines && cp.trail.size() > 1) {
      noFill();
      stroke(pCol, 120);
      strokeWeight(1.4 * uiScale);
      beginShape();
      for (PVector pt : cp.trail) {
        float tx = cutBoxX + pt.x * cutBoxW;
        float th = lerp(halfH1, halfH5, pt.x);
        float ty = ductCenterY + (pt.y - 0.5) * 1.75 * th;
        vertex(tx, ty);
      }
      endShape();
    }

    if (showParticles) {
      fill(pCol);
      noStroke();
      ellipse(px, py, 6.5 * uiScale, 6.5 * uiScale);
    }
  }

  // 3. Velocity Vector Profile Arrows at Sections 1..5
  if (showVectors) {
    for (int i = 0; i < numReadings; i++) {
      float tSec = map(i, 0, numReadings - 1, 0.10, 0.90);
      float vxPos = cutBoxX + tSec * cutBoxW;
      float hLocal = lerp(halfH1, halfH5, tSec);
      float arrowLen = map(velocityV[i], 0.135, 0.322, 22 * uiScale, 52 * uiScale);
      for (int row = -1; row <= 1; row++) {
        float vyPos = ductCenterY + row * hLocal * 0.52;
        float profScale = (row == 0) ? 1.12 : 0.85;
        draw2DArrow(vxPos, vyPos, vxPos + arrowLen * profScale, vyPos, color(255, 235, 95, 200), 1.8 * uiScale);
      }
    }
  }

  // 4. Streaklines & Interactive Tracer Nozzle (Tap inside duct to move!)
  float nozPx = cutBoxX + nozzleNormX * cutBoxW;
  float nozH = lerp(halfH1, halfH5, nozzleNormX);
  float nozPy = ductCenterY + (nozzleNormY - 0.5) * 1.75 * nozH;

  if (showStreaklines && streakPoints.size() > 1) {
    noFill();
    stroke(255, 75, 165);
    strokeWeight(2.6 * uiScale);
    beginShape();
    for (PVector sp : streakPoints) {
      float sx = cutBoxX + sp.x * cutBoxW;
      float sh = lerp(halfH1, halfH5, sp.x);
      float sy = ductCenterY + (sp.y - 0.5) * 1.75 * sh;
      vertex(sx, sy);
    }
    endShape();
  }

  // Draw Tracer Nozzle Crosshair
  stroke(255, 90, 180);
  strokeWeight(2 * uiScale);
  noFill();
  ellipse(nozPx, nozPy, 16 * uiScale, 16 * uiScale);
  line(nozPx - 12 * uiScale, nozPy, nozPx + 12 * uiScale, nozPy);
  line(nozPx, nozPy - 12 * uiScale, nozPx, nozPy + 12 * uiScale);

  // 5. Five Vertical Piezometer Tubes, HGL & EGL Lines above Duct
  float[] hglX = new float[numReadings];
  float[] hglY = new float[numReadings];
  float[] eglY = new float[numReadings];

  for (int i = 0; i < numReadings; i++) {
    float tSec = map(i, 0, numReadings - 1, 0.10, 0.90);
    float sx = cutBoxX + tSec * cutBoxW;
    float topWallY = ductCenterY - lerp(halfH1, halfH5, tSec);
    float tubeTopY = contentTop + 56 * uiScale;
    float tubeW = 14 * uiScale;
    boolean isSel = (i == selectedReading);

    // Glass tube
    fill(210, 240, 255, 45);
    stroke(isSel ? color(255, 210, 60) : color(135, 195, 240));
    strokeWeight(isSel ? 2.2 * uiScale : 1.3 * uiScale);
    rect(sx - tubeW * 0.5, tubeTopY, tubeW, topWallY - tubeTopY);

    // Water height scaled visually so head drop & velocity head rise are crisp
    float maxColH = topWallY - tubeTopY - 26 * uiScale;
    float colH = map(piezoHead[i], 0.270, 0.300, maxColH * 0.72, maxColH * 0.96);
    float waterTopY = topWallY - colH;

    fill(isSel ? color(255, 195, 45, 225) : color(45, 185, 255, 200));
    noStroke();
    rect(sx - tubeW * 0.5 + 2 * uiScale, waterTopY, tubeW - 4 * uiScale, colH);

    hglX[i] = sx;
    hglY[i] = waterTopY;
    float velHeadPix = map(velHead[i], 0.0009, 0.0055, 4 * uiScale, 24 * uiScale);
    eglY[i] = waterTopY - velHeadPix;

    // Section Label & Callout
    fill(isSel ? color(255, 220, 85) : color(205, 225, 245));
    textAlign(CENTER, TOP);
    textSize(11 * uiScale);
    text("S" + sectionNo[i] + "\nd=" + nf(ductDia[i]*1000, 0, 0) + "mm", sx, ductCenterY + lerp(halfH1, halfH5, tSec) + 6 * uiScale);

    if (isSel) {
      fill(255, 225, 95);
      textAlign(CENTER, BOTTOM);
      textSize(10.5 * uiScale);
      text("H=" + nf(totalHead[i], 1, 4) + "m", sx, eglY[i] - 5 * uiScale);
    }
  }

  // Draw Hydraulic Grade Line (HGL) & Total Energy Grade Line (EGL)
  stroke(60, 235, 150);
  strokeWeight(2 * uiScale);
  noFill();
  beginShape();
  for (int i = 0; i < numReadings; i++) vertex(hglX[i], hglY[i]);
  endShape();

  stroke(255, 95, 95);
  strokeWeight(2 * uiScale);
  beginShape();
  for (int i = 0; i < numReadings; i++) vertex(hglX[i], eglY[i]);
  endShape();

  // Legend top-left inside cutaway
  fill(255, 95, 95);
  textAlign(LEFT, CENTER);
  textSize(11 * uiScale);
  text("--- EGL: Total Head [z + P/w + V^2/2g] ~= 0.294m", cutBoxX + 10 * uiScale, contentTop + 44 * uiScale);
  fill(60, 235, 150);
  text("--- HGL: Piezometric Head [z + P/w]", cutBoxX + 310 * uiScale, contentTop + 44 * uiScale);

  // Right Control & Quantitative Readout Panel
  drawPanelCard(rightX, contentTop, rightW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("FLOW LAYERS & READOUTS", rightX, contentTop, rightW);

  float bx = rightX + 12 * uiScale;
  float bw = rightW - 24 * uiScale;
  float bh = 32 * uiScale;
  float by = contentTop + 42 * uiScale;
  float bStep = 38 * uiScale;

  drawPillButton("Particles: " + (showParticles ? "ON" : "OFF"), bx, by, bw, bh, showParticles, color(30, 130, 185));
  drawPillButton("Velocity Vectors: " + (showVectors ? "ON" : "OFF"), bx, by + bStep, bw, bh, showVectors, color(175, 135, 30));
  drawPillButton("Streamlines: " + (showStreamlines ? "ON" : "OFF"), bx, by + 2 * bStep, bw, bh, showStreamlines, color(30, 145, 165));
  drawPillButton("Pathlines: " + (showPathlines ? "ON" : "OFF"), bx, by + 3 * bStep, bw, bh, showPathlines, color(45, 125, 195));
  drawPillButton("Streakline Dye: " + (showStreaklines ? "ON" : "OFF"), bx, by + 4 * bStep, bw, bh, showStreaklines, color(195, 55, 125));

  float halfW = (bw - 8 * uiScale) * 0.5;
  drawPillButton(unsteadyMode ? "UNSTEADY" : "STEADY", bx, by + 5 * bStep, halfW, bh, unsteadyMode, color(205, 95, 40));
  drawPillButton("Reset Trails", bx + halfW + 8 * uiScale, by + 5 * bStep, halfW, bh, false, color(55, 80, 110));

  // Quantitative Box at bottom of right panel
  float qBoxY = by + 6 * bStep + 10 * uiScale;
  float qBoxH = contentBot - qBoxY - 10 * uiScale;
  fill(22, 36, 56);
  stroke(75, 140, 200);
  strokeWeight(1.2 * uiScale);
  rect(bx, qBoxY, bw, qBoxH, 8 * uiScale);

  fill(110, 225, 255);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("Section S" + sectionNo[r] + " Live Physics:", bx + 10 * uiScale, qBoxY + 8 * uiScale);

  fill(225, 238, 250);
  textSize(11 * uiScale);
  String qInfo =
    "Area a = " + nf(ductArea[r], 1, 6) + " m^2\n" +
    "Velocity V = " + nf(velocityV[r], 1, 3) + " m/s\n" +
    "Kinetic Head = " + nf(velHead[r], 1, 6) + " m\n" +
    "Pressure Head = " + nf(piezoHead[r], 1, 3) + " m\n" +
    "Total Head H = " + nf(totalHead[r], 1, 4) + " m\n" +
    "Tip: Tap inside duct to move dye nozzle.";
  text(qInfo, bx + 10 * uiScale, qBoxY + 28 * uiScale);
}

// ============================================================================
// SCREEN 3: 7-STEP MATHEMATICAL DERIVATION & CONTROL-VOLUME SCHEMATIC
// ============================================================================
void drawScreen3_Derivation() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.56;
  float rightX = margin * 2 + leftW;
  float rightW = (width - margin * 3) * 0.44;

  // Left Panel: 7-Step Derivation
  drawPanelCard(margin, contentTop, leftW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("MATHEMATICAL DERIVATION OF BERNOULLI'S EQUATION", margin, contentTop, leftW);

  float listTop = contentTop + 40 * uiScale;
  float ctrlH = 44 * uiScale;
  float listH = contentH - 48 * uiScale - ctrlH;
  float stepH = listH / derivTitles.length;

  for (int i = 0; i < derivTitles.length; i++) {
    float sy = listTop + i * stepH;
    boolean isCur = (i == derivStep);

    fill(isCur ? color(28, 62, 98) : color(20, 32, 48));
    stroke(isCur ? color(255, 205, 65) : color(45, 70, 100));
    strokeWeight(isCur ? 1.8 * uiScale : 1.0 * uiScale);
    rect(margin + 36 * uiScale, sy + 2 * uiScale, leftW - 48 * uiScale, stepH - 5 * uiScale, 7 * uiScale);

    if (isCur) {
      float pulse = sin(frameCount * 0.15) * 4 * uiScale;
      draw2DArrow(margin + 8 * uiScale + pulse, sy + stepH * 0.5, margin + 32 * uiScale + pulse, sy + stepH * 0.5, color(255, 85, 85), 3 * uiScale);
    }

    fill(isCur ? color(255, 220, 85) : color(115, 205, 250));
    textAlign(LEFT, TOP);
    textSize(11.5 * uiScale);
    text(derivTitles[i], margin + 46 * uiScale, sy + 5 * uiScale);

    fill(isCur ? color(255) : color(210, 225, 242));
    textSize(12 * uiScale);
    text(derivFormulas[i], margin + 46 * uiScale, sy + 21 * uiScale);

    if (stepH > 54 * uiScale) {
      fill(155, 185, 215);
      textSize(10 * uiScale);
      text(derivNotes[i], margin + 46 * uiScale, sy + 38 * uiScale);
    }
  }

  // Bottom Controls on Left Panel
  float bY = contentBot - ctrlH + 2 * uiScale;
  float bW = (leftW - 36 * uiScale) / 3.0;
  float bH = ctrlH - 8 * uiScale;
  drawPillButton("< Prev Step", margin + 12 * uiScale, bY, bW, bH, derivStep > 0, color(38, 105, 165));
  drawPillButton("Next Step >", margin + 18 * uiScale + bW, bY, bW, bH, derivStep < derivTitles.length - 1, color(38, 125, 185));
  drawPillButton(autoDerive ? "Auto-Derive: ON" : "Auto-Derive: OFF", margin + 24 * uiScale + 2 * bW, bY, bW, bH, autoDerive, color(34, 145, 95));

  // Right Panel: Control-Volume & Energy Grade Line Schematic
  drawPanelCard(rightX, contentTop, rightW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("CONTROL VOLUME & ENERGY GRADE LINE", rightX, contentTop, rightW);

  int r = selectedReading;
  float diagX = rightX + 20 * uiScale;
  float diagW = rightW - 40 * uiScale;
  float datumY = contentTop + contentH * 0.65;

  // Datum Line
  stroke(150, 170, 195);
  strokeWeight(1.5 * uiScale);
  line(diagX, datumY, diagX + diagW, datumY);
  fill(170, 195, 220);
  textAlign(LEFT, TOP);
  textSize(10.5 * uiScale);
  text("Horizontal Datum Line (Duct Bed, z = 0)", diagX, datumY + 4 * uiScale);

  // Tapered Control Volume Duct
  float x1 = diagX + 35 * uiScale;
  float x2 = diagX + diagW - 35 * uiScale;
  float yCenter = datumY - 34 * uiScale;
  float r1 = 24 * uiScale;
  float r2 = 14 * uiScale;

  fill(28, 95, 155, 180);
  stroke(130, 215, 255);
  strokeWeight(2 * uiScale);
  quad(x1, yCenter - r1, x2, yCenter - r2, x2, yCenter + r2, x1, yCenter + r1);

  // Piezometer Columns at Section 1 & Active Section
  float hglY1 = yCenter - 78 * uiScale;
  float hglY2 = yCenter - 66 * uiScale;
  float eglY1 = hglY1 - 12 * uiScale;
  float eglY2 = hglY2 - 24 * uiScale;

  // Section 1 Vertical Line
  stroke(90, 210, 255);
  line(x1, datumY, x1, eglY1);
  // Section 5 / Active Vertical Line
  stroke(255, 205, 65);
  line(x2, datumY, x2, eglY2);

  // HGL & EGL Lines
  stroke(60, 235, 150);
  strokeWeight(2.2 * uiScale);
  line(x1, hglY1, x2, hglY2);
  fill(60, 235, 150);
  textAlign(LEFT, BOTTOM);
  text("HGL: [z + P/w]", x1 + 6 * uiScale, hglY1 - 2 * uiScale);

  stroke(255, 90, 90);
  line(x1, eglY1, x2, eglY2);
  fill(255, 95, 95);
  text("EGL: H = [z + P/w] + V^2/2g = Const", x1 + 6 * uiScale, eglY1 - 4 * uiScale);

  // Live Callouts for Selected Reading
  fill(225, 238, 252);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text("Active Section S" + sectionNo[r] + " (d = " + nf(ductDia[r]*1000, 0, 0) + " mm):", diagX, datumY + 24 * uiScale);
  fill(120, 230, 255);
  text("  [z + P/w] = " + nf(piezoHead[r], 1, 3) + " m   |   V^2/2g = " + nf(velHead[r], 1, 6) + " m", diagX, datumY + 42 * uiScale);

  // Highlighted Final Derived Equation Box
  float eqH = 68 * uiScale;
  float eqY = contentBot - eqH - 10 * uiScale;
  fill(22, 54, 82);
  stroke(255, 205, 65);
  strokeWeight(2 * uiScale);
  rect(diagX, eqY, diagW, eqH, 8 * uiScale);

  fill(255, 220, 85);
  textAlign(CENTER, TOP);
  textSize(12 * uiScale);
  text("WORKING BERNOULLI EQUATION", diagX + diagW * 0.5, eqY + 8 * uiScale);
  fill(255);
  textSize(13.5 * uiScale);
  text("H = [z + P/w] + (V^2 / 2g) = " + nf(totalHead[r], 1, 4) + " m", diagX + diagW * 0.5, eqY + 32 * uiScale);
}

// ============================================================================
// SCREEN 4: 6-STEP LAB PROCEDURE & ZOOMED SENSOR INSTRUMENTS
// ============================================================================
void drawScreen4_Procedure() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.48;
  float rightX = margin * 2 + leftW;
  float rightW = (width - margin * 3) * 0.52;

  // Left Panel: 6-Step Experimental Procedure
  drawPanelCard(margin, contentTop, leftW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("EXPERIMENTAL PROCEDURE (HOW READINGS ARE TAKEN)", margin, contentTop, leftW);

  float listTop = contentTop + 40 * uiScale;
  float ctrlH = 44 * uiScale;
  float listH = contentH - 48 * uiScale - ctrlH;
  float stepH = listH / procTitles.length;

  for (int i = 0; i < procTitles.length; i++) {
    float sy = listTop + i * stepH;
    boolean isCur = (i == procStep);

    fill(isCur ? color(28, 62, 98) : color(20, 32, 48));
    stroke(isCur ? color(105, 235, 165) : color(45, 70, 100));
    strokeWeight(isCur ? 1.8 * uiScale : 1.0 * uiScale);
    rect(margin + 36 * uiScale, sy + 2 * uiScale, leftW - 48 * uiScale, stepH - 5 * uiScale, 7 * uiScale);

    if (isCur) {
      float pulse = sin(frameCount * 0.15) * 4 * uiScale;
      draw2DArrow(margin + 8 * uiScale + pulse, sy + stepH * 0.5, margin + 32 * uiScale + pulse, sy + stepH * 0.5, color(105, 235, 165), 3 * uiScale);
    }

    fill(isCur ? color(115, 245, 175) : color(115, 205, 250));
    textAlign(LEFT, TOP);
    textSize(12 * uiScale);
    text(procTitles[i], margin + 46 * uiScale, sy + 6 * uiScale);

    fill(isCur ? color(255) : color(195, 215, 235));
    textSize(11 * uiScale);
    text(procDetails[i], margin + 46 * uiScale, sy + 24 * uiScale);
  }

  float bY = contentBot - ctrlH + 2 * uiScale;
  float bH = ctrlH - 8 * uiScale;
  drawPillButton(autoDemo ? "Auto-Demo: ON" : "Auto-Demo: OFF", margin + 12 * uiScale, bY, leftW - 24 * uiScale, bH, autoDemo, color(34, 145, 95));

  // Right Panel: Two Zoomed Measurement Instrument Cards
  float cardGap = 10 * uiScale;
  float cardH = (contentH - cardGap) * 0.5;
  int r = selectedReading;

  // Instrument Card 1: Zoomed Piezometer Bank & Metre Scale
  drawPanelCard(rightX, contentTop, rightW, cardH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("INSTRUMENT 1: ZOOMED PIEZOMETER BANK & METRE SCALE", rightX, contentTop, rightW);

  float scaleX = rightX + 46 * uiScale;
  float scaleTop = contentTop + 44 * uiScale;
  float scaleBot = contentTop + cardH - 22 * uiScale;

  // Vertical Metre Scale (25 cm to 31 cm zoomed range)
  stroke(220, 235, 250);
  strokeWeight(1.5 * uiScale);
  line(scaleX, scaleTop, scaleX, scaleBot);
  for (int cm = 25; cm <= 31; cm++) {
    float ty = map(cm, 25, 31, scaleBot, scaleTop);
    line(scaleX - 8 * uiScale, ty, scaleX, ty);
    fill(190, 215, 240);
    textAlign(RIGHT, CENTER);
    textSize(10 * uiScale);
    text(cm + "cm", scaleX - 10 * uiScale, ty);
  }

  // 5 Zoomed Piezometer Tubes
  float tubesW = rightW - 105 * uiScale;
  for (int i = 0; i < numReadings; i++) {
    float tx = scaleX + 34 * uiScale + i * (tubesW / 5.0);
    float tw = 22 * uiScale;
    boolean isSel = (i == selectedReading);
    float cmVal = piezoHead[i] * 100.0;
    float menY = map(cmVal, 25.0, 31.0, scaleBot, scaleTop);

    fill(215, 240, 255, 45);
    stroke(isSel ? color(255, 210, 65) : color(120, 185, 235));
    strokeWeight(isSel ? 2 * uiScale : 1.2 * uiScale);
    rect(tx, scaleTop, tw, scaleBot - scaleTop);

    fill(isSel ? color(255, 195, 45, 225) : color(45, 185, 255, 200));
    noStroke();
    rect(tx + 2 * uiScale, menY, tw - 4 * uiScale, scaleBot - menY);

    fill(isSel ? color(255, 220, 85) : color(200, 220, 240));
    textAlign(CENTER, TOP);
    textSize(10.5 * uiScale);
    text("P" + (i + 1) + "\n" + nf(cmVal, 0, 1), tx + tw * 0.5, scaleBot + 2 * uiScale);
  }

  // Instrument Card 2: Zoomed Collecting Tank (300x300mm) & Digital Stopwatch
  float c2Y = contentTop + cardH + cardGap;
  drawPanelCard(rightX, c2Y, rightW, cardH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("INSTRUMENT 2: COLLECTING TANK (0.3x0.3m) & STOPWATCH", rightX, c2Y, rightW);

  float ctX = rightX + 26 * uiScale;
  float ctY = c2Y + 46 * uiScale;
  float ctW = 145 * uiScale;
  float ctH = cardH - 64 * uiScale;

  // Collecting Tank Cross-Section
  fill(24, 38, 58);
  stroke(135, 205, 245);
  strokeWeight(2 * uiScale);
  rect(ctX, ctY, ctW, ctH);

  // Animated water rise up to h = 10 cm (0.10 m)
  float fracRise = constrain(stopwatchSim / timeTaken[r], 0, 1);
  float maxRisePx = ctH * 0.72;
  float curRisePx = fracRise * maxRisePx;
  fill(40, 185, 255, 200);
  noStroke();
  rect(ctX + 2 * uiScale, ctY + ctH - curRisePx, ctW - 4 * uiScale, curRisePx);

  // Target h = 10 cm dashed line
  float targetY = ctY + ctH - maxRisePx;
  stroke(255, 205, 65);
  strokeWeight(1.5 * uiScale);
  line(ctX, targetY, ctX + ctW, targetY);
  fill(255, 220, 85);
  textAlign(LEFT, BOTTOM);
  textSize(10.5 * uiScale);
  text("h = 10 cm (0.10 m)", ctX + 6 * uiScale, targetY - 2 * uiScale);

  // Digital Stopwatch & Calculation Box on Right of Card 2
  float swX = ctX + ctW + 20 * uiScale;
  float swW = rightW - ctW - 64 * uiScale;
  fill(20, 34, 52);
  stroke(90, 210, 165);
  strokeWeight(1.5 * uiScale);
  rect(swX, ctY, swW, ctH * 0.48, 8 * uiScale);

  fill(110, 245, 175);
  textAlign(CENTER, CENTER);
  textSize(11 * uiScale);
  text("STOP WATCH (Section S" + sectionNo[r] + ")", swX + swW * 0.5, ctY + 14 * uiScale);
  fill(255);
  textSize(20 * uiScale);
  text(nf(stopwatchSim, 0, 1) + " / " + nf(timeTaken[r], 0, 0) + " s", swX + swW * 0.5, ctY + ctH * 0.30);

  fill(205, 225, 245);
  textAlign(LEFT, TOP);
  textSize(11 * uiScale);
  String swNotes =
    "Tank Area A_t = 0.3 x 0.3 = 0.09 m^2\n" +
    "Rise Height h = 0.10 m\n" +
    "Discharge Q = (0.09 x 0.10) / " + nf(timeTaken[r], 0, 0) + "\n" +
    "Q = " + nf(dischargeQ[r], 1, 6) + " m^3/sec";
  text(swNotes, swX, ctY + ctH * 0.53);
}

// ============================================================================
// SCREEN 5: 8-STEP BODMAS BREAKDOWN & 47-KEY CASIO fx-991MS CALCULATOR
// ============================================================================
void drawScreen5_CasioCalc() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.53;
  float rightX = margin * 2 + leftW;
  float rightW = (width - margin * 3) * 0.47;
  int r = selectedReading;

  // Left Panel: 8-Step BODMAS Breakdown
  drawPanelCard(margin, contentTop, leftW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("BODMAS STEP-BY-STEP CALCULATION - SECTION S" + sectionNo[r], margin, contentTop, leftW);

  // BODMAS Pill Strip (B, O, D, M, A, S)
  String[] letters = { "B", "O", "D", "M", "A", "S" };
  String[] lDesc   = { "Brackets", "Orders", "Division", "Multiply", "Addition", "Subtract" };
  float pillStripY = contentTop + 38 * uiScale;
  float pillStripH = 26 * uiScale;
  float pW = (leftW - 24 * uiScale - 5 * 5 * uiScale) / 6.0;
  String activeBadge = bodmasBadges[bodmasStep];

  for (int i = 0; i < 6; i++) {
    float px = margin + 12 * uiScale + i * (pW + 5 * uiScale);
    boolean isMatch = letters[i].equals(activeBadge);
    fill(isMatch ? color(220, 130, 30) : color(26, 42, 65));
    stroke(isMatch ? color(255, 230, 110) : color(65, 95, 135));
    strokeWeight(isMatch ? 1.8 * uiScale : 1.0 * uiScale);
    rect(px, pillStripY, pW, pillStripH, 5 * uiScale);

    fill(255);
    textAlign(CENTER, CENTER);
    textSize(10.5 * uiScale);
    text(letters[i] + ": " + lDesc[i], px + pW * 0.5, pillStripY + pillStripH * 0.5);
  }

  // 8 Plugged-In Calculation Rows
  String[] bodmasExprs = {
    "A_t = (0.30 x 0.30) = 0.0900 m^2",
    "Vol = (0.0900 x 0.10) = 0.0090 m^3",
    "Q = 0.0090 / " + nf(timeTaken[r], 0, 0) + " = " + nf(dischargeQ[r], 1, 6) + " m^3/s",
    "a = (pi / 4) x (" + nf(ductDia[r], 1, 3) + ")^2 = " + nf(ductArea[r], 1, 6) + " m^2",
    "V = " + nf(dischargeQ[r], 1, 6) + " / " + nf(ductArea[r], 1, 6) + " = " + nf(velocityV[r], 1, 3) + " m/s",
    "V^2 = (" + nf(velocityV[r], 1, 3) + ")^2 = " + nf(sq(velocityV[r]), 1, 5) + " m^2/s^2",
    "h_v = " + nf(sq(velocityV[r]), 1, 5) + " / (2 x 9.81) = " + nf(velHead[r], 1, 6) + " m",
    "H = " + nf(piezoHead[r], 1, 3) + " + " + nf(velHead[r], 1, 6) + " = " + nf(totalHead[r], 1, 4) + " m"
  };

  float rowsTop = pillStripY + pillStripH + 8 * uiScale;
  float rowsAvailH = contentBot - rowsTop - 8 * uiScale;
  float rowH = rowsAvailH / 8.0;

  for (int i = 0; i < 8; i++) {
    float ry = rowsTop + i * rowH;
    boolean isCur = (i == bodmasStep);

    fill(isCur ? color(28, 66, 102) : color(20, 32, 48));
    stroke(isCur ? color(255, 205, 65) : color(45, 70, 100));
    strokeWeight(isCur ? 1.8 * uiScale : 1.0 * uiScale);
    rect(margin + 34 * uiScale, ry + 1.5 * uiScale, leftW - 46 * uiScale, rowH - 4 * uiScale, 6 * uiScale);

    if (isCur) {
      float pulse = sin(frameCount * 0.16) * 3.5 * uiScale;
      draw2DArrow(margin + 8 * uiScale + pulse, ry + rowH * 0.5, margin + 30 * uiScale + pulse, ry + rowH * 0.5, color(255, 85, 85), 2.8 * uiScale);
    }

    // Badge pill
    fill(isCur ? color(225, 135, 30) : color(38, 65, 98));
    noStroke();
    rect(margin + 40 * uiScale, ry + 5 * uiScale, 22 * uiScale, rowH - 11 * uiScale, 4 * uiScale);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text(bodmasBadges[i], margin + 51 * uiScale, ry + rowH * 0.5);

    // Title & Plugged Equation
    fill(isCur ? color(255, 220, 85) : color(135, 205, 245));
    textAlign(LEFT, CENTER);
    textSize(11 * uiScale);
    text(bodmasNames[i], margin + 68 * uiScale, ry + rowH * 0.30);

    fill(isCur ? color(255) : color(215, 230, 245));
    textSize(11.5 * uiScale);
    text(bodmasExprs[i], margin + 68 * uiScale, ry + rowH * 0.70);
  }

  // Right Panel: Authentic 47-Key Casio fx-991MS S-V.P.A.M. Calculator
  drawCasioCalculator(rightX, contentTop, rightW, contentH, bodmasExprs);
}

void drawCasioCalculator(float cx, float cy, float cw, float ch, String[] bodmasExprs) {
  // Calculator Outer Metallic-Blue Chassis
  fill(34, 44, 62);
  stroke(95, 130, 175);
  strokeWeight(2 * uiScale);
  rect(cx, cy, cw, ch, 14 * uiScale);

  // Header: CASIO, fx-991MS, Solar Cell, S-V.P.A.M.
  fill(235, 242, 250);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("CASIO", cx + 16 * uiScale, cy + 16 * uiScale);
  fill(145, 215, 255);
  textSize(11.5 * uiScale);
  text("fx-991MS", cx + 70 * uiScale, cy + 16 * uiScale);
  fill(245, 185, 75);
  textSize(10 * uiScale);
  text("S-V.P.A.M.", cx + 16 * uiScale, cy + 31 * uiScale);

  // 4-Cell Solar Panel
  float solW = 92 * uiScale;
  float solH = 22 * uiScale;
  float solX = cx + cw - solW - 16 * uiScale;
  float solY = cy + 10 * uiScale;
  fill(48, 34, 28);
  stroke(120, 130, 145);
  strokeWeight(1.2 * uiScale);
  rect(solX, solY, solW, solH, 3 * uiScale);
  for (int i = 1; i < 4; i++) {
    float lx = solX + i * (solW / 4.0);
    line(lx, solY, lx, solY + solH);
  }

  // 2-Line LCD Display
  float lcdX = cx + 14 * uiScale;
  float lcdY = cy + 40 * uiScale;
  float lcdW = cw - 28 * uiScale;
  float lcdH = 54 * uiScale;
  fill(178, 196, 168);
  stroke(25, 32, 42);
  strokeWeight(2 * uiScale);
  rect(lcdX, lcdY, lcdW, lcdH, 6 * uiScale);

  // LCD Status Indicators (D, SCI, SHIFT)
  fill(25, 38, 28);
  textAlign(LEFT, TOP);
  textSize(9.5 * uiScale);
  String flags = (casioShift ? "S  " : "") + (casioAlpha ? "A  " : "") + "D   SCI   Math";
  text(flags, lcdX + 8 * uiScale, lcdY + 4 * uiScale);

  // Line 1: Expression, Line 2: Result
  String line1 = casioManualMode ? casioCustomExpr : bodmasExprs[bodmasStep].split("=")[0];
  String line2 = casioManualMode ? casioCustomAns : bodmasExprs[bodmasStep].split("=")[1].trim();

  textAlign(LEFT, CENTER);
  textSize(12 * uiScale);
  text(line1, lcdX + 10 * uiScale, lcdY + 23 * uiScale);

  textAlign(RIGHT, CENTER);
  textSize(14.5 * uiScale);
  text(line2, lcdX + lcdW - 10 * uiScale, lcdY + 41 * uiScale);

  // Top Control Row: SHIFT, ALPHA, REPLAY 4-Way Oval, MODE, ON (5 controls)
  float topCtrlY = lcdY + lcdH + 8 * uiScale;
  float pillW = 46 * uiScale;
  float pillH = 22 * uiScale;

  // SHIFT pill
  fill(casioShift ? color(245, 195, 55) : color(75, 88, 110));
  noStroke();
  rect(lcdX, topCtrlY + 4 * uiScale, pillW, pillH, 10 * uiScale);
  fill(245, 195, 55);
  textAlign(CENTER, CENTER);
  textSize(9.5 * uiScale);
  text("SHIFT", lcdX + pillW * 0.5, topCtrlY + 15 * uiScale);

  // ALPHA pill
  fill(casioAlpha ? color(235, 85, 115) : color(75, 88, 110));
  rect(lcdX + pillW + 8 * uiScale, topCtrlY + 4 * uiScale, pillW, pillH, 10 * uiScale);
  fill(240, 115, 135);
  text("ALPHA", lcdX + pillW * 1.5 + 8 * uiScale, topCtrlY + 15 * uiScale);

  // Central REPLAY Oval Pad
  float repW = 74 * uiScale;
  float repH = 32 * uiScale;
  float repX = cx + cw * 0.5 - repW * 0.5;
  fill(65, 78, 102);
  stroke(125, 145, 175);
  strokeWeight(1.2 * uiScale);
  ellipse(repX + repW * 0.5, topCtrlY + repH * 0.5, repW, repH);
  fill(210, 225, 245);
  noStroke();
  textSize(8.5 * uiScale);
  text("REPLAY", repX + repW * 0.5, topCtrlY + repH * 0.5);

  // MODE & ON pills on right
  float rightPillX = cx + cw - 14 * uiScale - pillW * 2 - 8 * uiScale;
  fill(75, 88, 110);
  rect(rightPillX, topCtrlY + 4 * uiScale, pillW, pillH, 10 * uiScale);
  fill(220, 232, 245);
  text("MODE", rightPillX + pillW * 0.5, topCtrlY + 15 * uiScale);

  fill(75, 88, 110);
  rect(rightPillX + pillW + 8 * uiScale, topCtrlY + 4 * uiScale, pillW, pillH, 10 * uiScale);
  fill(220, 232, 245);
  text("ON", rightPillX + pillW * 1.5 + 8 * uiScale, topCtrlY + 15 * uiScale);

  // Determine target highlighted key for current BODMAS step
  String[] stepTargetKey = { "x", "x", "/", "x^2", "/", "x^2", "/", "+" };
  String targetKey = stepTargetKey[bodmasStep];
  float targetCenterX = -1, targetCenterY = -1;

  // 22 Scientific Keys Grid (4 rows x 6 cols, skipping [0][5] so count = 23 -> 22 active + 5 top = 27 + 20 = 47 keys!)
  float sciTop = topCtrlY + repH + 8 * uiScale;
  float guideH = 26 * uiScale;
  float keysAvailH = (cy + ch - guideH - 8 * uiScale) - sciTop;
  float sciAreaH = keysAvailH * 0.46;
  float numAreaH = keysAvailH * 0.54;

  float sciGapX = 5 * uiScale;
  float sciGapY = 6 * uiScale;
  float sciBtnW = (lcdW - 5 * sciGapX) / 6.0;
  float sciBtnH = (sciAreaH - 3 * sciGapY) / 4.0 - 6 * uiScale;

  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 6; col++) {
      String lbl = sciKeys[row][col];
      if (lbl.equals("")) continue;
      float kx = lcdX + col * (sciBtnW + sciGapX);
      float ky = sciTop + row * (sciBtnH + sciGapY + 6 * uiScale) + 6 * uiScale;
      boolean isHighlight = lbl.equals(targetKey);

      // Gold SHIFT legend above key
      fill(245, 195, 75);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(sciShift[row][col], kx + sciBtnW * 0.5, ky - 1 * uiScale);

      // Dark Scientific Key Cap
      fill(isHighlight ? color(220, 125, 25) : color(26, 33, 46));
      stroke(isHighlight ? color(255, 235, 110) : color(75, 92, 118));
      strokeWeight(isHighlight ? 1.8 * uiScale : 1.0 * uiScale);
      rect(kx, ky, sciBtnW, sciBtnH, 4 * uiScale);

      fill(240);
      textAlign(CENTER, CENTER);
      textSize(9.5 * uiScale);
      text(lbl, kx + sciBtnW * 0.5, ky + sciBtnH * 0.5);

      if (isHighlight) {
        targetCenterX = kx + sciBtnW * 0.5;
        targetCenterY = ky;
      }
    }
  }

  // 20 Numeric & Operator Keys Grid (4 rows x 5 cols)
  float numTop = sciTop + sciAreaH + 4 * uiScale;
  float numGapX = 6 * uiScale;
  float numGapY = 6 * uiScale;
  float numBtnW = (lcdW - 4 * numGapX) / 5.0;
  float numBtnH = (numAreaH - 3 * numGapY) / 4.0 - 5 * uiScale;

  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 5; col++) {
      String lbl = numKeys[row][col];
      float kx = lcdX + col * (numBtnW + numGapX);
      float ky = numTop + row * (numBtnH + numGapY + 5 * uiScale) + 5 * uiScale;
      boolean isDelAc = lbl.equals("DEL") || lbl.equals("AC");
      boolean isHighlight = lbl.equals(targetKey);

      // Gold SHIFT legend above key
      fill(245, 195, 75);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(numShift[row][col], kx + numBtnW * 0.5, ky - 1 * uiScale);

      if (isHighlight) {
        fill(225, 130, 25);
        stroke(255, 235, 110);
        strokeWeight(2.0 * uiScale);
      } else if (isDelAc) {
        fill(165, 58, 68);
        stroke(225, 115, 125);
        strokeWeight(1.0 * uiScale);
      } else {
        fill(195, 206, 222);
        stroke(110, 125, 145);
        strokeWeight(1.0 * uiScale);
      }
      rect(kx, ky, numBtnW, numBtnH, 5 * uiScale);

      fill(isHighlight || isDelAc ? color(255) : color(20, 28, 38));
      textAlign(CENTER, CENTER);
      textSize(11 * uiScale);
      text(lbl, kx + numBtnW * 0.5, ky + numBtnH * 0.5);

      if (isHighlight) {
        targetCenterX = kx + numBtnW * 0.5;
        targetCenterY = ky;
      }
    }
  }

  // Bouncing Red Arrow pointing to Active BODMAS Key
  if (targetCenterX > 0) {
    float bounce = abs(sin(frameCount * 0.16)) * 7 * uiScale;
    draw2DArrow(targetCenterX, targetCenterY - 18 * uiScale - bounce, targetCenterX, targetCenterY - 2 * uiScale - bounce, color(255, 65, 65), 3 * uiScale);
  }

  // Bottom Keystroke Sequence Guide Strip
  String[] keyGuides = {
    "Keys: 0 . 3 0 [x] 0 . 3 0 [=]",
    "Keys: 0 . 0 9 [x] 0 . 1 0 [=]",
    "Keys: 0 . 0 0 9 [/] T [=]",
    "Keys: [SHIFT] [pi] [/] 4 [x] d [x^2] [=]",
    "Keys: Q [/] a [=]",
    "Keys: V [x^2] [=]",
    "Keys: V^2 [/] [(] 2 [x] 9 . 8 1 [)] [=]",
    "Keys: [z+P/w] [+] h_v [=]"
  };
  float gY = cy + ch - guideH - 4 * uiScale;
  fill(22, 34, 52);
  noStroke();
  rect(lcdX, gY, lcdW, guideH, 5 * uiScale);
  fill(255, 220, 95);
  textAlign(CENTER, CENTER);
  textSize(10.5 * uiScale);
  text(keyGuides[bodmasStep], lcdX + lcdW * 0.5, gY + guideH * 0.5);
}

// ============================================================================
// SCREEN 6: COMPLETE OBSERVATION TABLE & AUTO-SCALED GRAPH SHEET
// ============================================================================
void drawScreen6_TableAndGraph() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.55;
  float rightX = margin * 2 + leftW;
  float rightW = (width - margin * 3) * 0.45;

  // Left Panel: Observation Table & Final Result Box
  drawPanelCard(margin, contentTop, leftW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("OBSERVATION & CALCULATION TABLE (TAP ANY ROW)", margin, contentTop, leftW);

  String[] headers = { "Sec", "Area a", "Time T", "Q (m^3/s)", "Vel V", "V^2/2g", "z+P/w", "Total H" };
  float[] colFracs = { 0.08, 0.14, 0.11, 0.15, 0.12, 0.14, 0.13, 0.13 };

  float tblX = margin + 8 * uiScale;
  float tblW = leftW - 16 * uiScale;
  float hdrY = contentTop + 38 * uiScale;
  float hdrH = 30 * uiScale;

  // Table Header Row
  fill(26, 48, 76);
  noStroke();
  rect(tblX, hdrY, tblW, hdrH, 5 * uiScale);

  float curX = tblX;
  fill(115, 225, 255);
  textAlign(CENTER, CENTER);
  textSize(10.5 * uiScale);
  for (int c = 0; c < headers.length; c++) {
    float cw = tblW * colFracs[c];
    text(headers[c], curX + cw * 0.5, hdrY + hdrH * 0.5);
    curX += cw;
  }

  // 5 Data Rows
  float resBoxH = 92 * uiScale;
  float rowsTop = hdrY + hdrH + 4 * uiScale;
  float rowsAreaH = (contentBot - resBoxH - 12 * uiScale) - rowsTop;
  float rH = rowsAreaH / numReadings;

  for (int r = 0; r < numReadings; r++) {
    float ry = rowsTop + r * rH;
    boolean isSel = (r == selectedReading);

    fill(isSel ? color(32, 74, 114) : (r % 2 == 0 ? color(20, 32, 48) : color(24, 38, 56)));
    stroke(isSel ? color(255, 205, 65) : color(45, 70, 100));
    strokeWeight(isSel ? 1.8 * uiScale : 0.8 * uiScale);
    rect(tblX, ry + 1 * uiScale, tblW, rH - 3 * uiScale, 5 * uiScale);

    String[] cells = {
      "S" + sectionNo[r],
      nf(ductArea[r], 1, 5),
      nf(timeTaken[r], 0, 0) + "s",
      nf(dischargeQ[r], 1, 6),
      nf(velocityV[r], 1, 3),
      nf(velHead[r], 1, 5),
      nf(piezoHead[r], 1, 3),
      nf(totalHead[r], 1, 4)
    };

    curX = tblX;
    textAlign(CENTER, CENTER);
    textSize(10.5 * uiScale);
    for (int c = 0; c < cells.length; c++) {
      float cw = tblW * colFracs[c];
      fill(isSel ? (c == 7 ? color(110, 255, 175) : color(255, 225, 110)) : color(220, 232, 245));
      text(cells[c], curX + cw * 0.5, ry + rH * 0.5);
      curX += cw;
    }
  }

  // Final Result Summary Box at Bottom of Table
  float resY = contentBot - resBoxH - 6 * uiScale;
  fill(22, 52, 80);
  stroke(95, 225, 155);
  strokeWeight(1.8 * uiScale);
  rect(tblX, resY, tblW, resBoxH, 8 * uiScale);

  fill(110, 250, 175);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("EXPERIMENTAL RESULT & VERIFICATION:", tblX + 12 * uiScale, resY + 8 * uiScale);

  fill(245);
  textSize(11 * uiScale);
  String resText =
    "Mean Total Head across Sections S1 to S5 = " + nf(meanTotalHead, 1, 4) + " m (~0.294 m)\n" +
    "Active Section S" + sectionNo[selectedReading] + " Total Head H = " + nf(totalHead[selectedReading], 1, 4) + " m\n" +
    "Conclusion: Total head at all duct sections is nearly same -> Bernoulli's Theorem is verified.";
  text(resText, tblX + 12 * uiScale, resY + 28 * uiScale);

  // Right Panel: Auto-Scaled Engineering Graph Sheet (Cross Section Area vs Total Head)
  drawPanelCard(rightX, contentTop, rightW, contentH, color(16, 26, 40), color(60, 125, 185));
  drawSectionHeader("GRAPH: CROSS SECTION AREA (a) VS TOTAL HEAD (H)", rightX, contentTop, rightW);
  drawAutoScaledGraph(rightX + 10 * uiScale, contentTop + 38 * uiScale, rightW - 20 * uiScale, contentH - 46 * uiScale);
}

void drawAutoScaledGraph(float gx, float gy, float gw, float gh) {
  float padL = 56 * uiScale;
  float padR = 22 * uiScale;
  float padT = 22 * uiScale;
  float padB = 54 * uiScale;

  float plotX = gx + padL;
  float plotY = gy + padT;
  float plotW = gw - padL - padR;
  float plotH = gh - padT - padB;

  // Graph Paper Background
  fill(244, 248, 252);
  stroke(90, 145, 195);
  strokeWeight(1.5 * uiScale);
  rect(plotX, plotY, plotW, plotH);

  // Padded Axis Bounds matching lab graph (a: 0.0008 -> 0.0026 m^2, H: 0.250 -> 0.330 m)
  float xMin = 0.0008, xMax = 0.0026;
  float yMin = 0.250,  yMax = 0.330;

  // Minor & Major Gridlines
  int xDivs = 9;
  int yDivs = 8;
  for (int i = 0; i <= xDivs; i++) {
    float vx = lerp(plotX, plotX + plotW, i / float(xDivs));
    stroke(i % 2 == 0 ? color(175, 205, 225) : color(215, 230, 240));
    strokeWeight(1 * uiScale);
    line(vx, plotY, vx, plotY + plotH);

    if (i % 2 == 0) {
      float valX = lerp(xMin, xMax, i / float(xDivs));
      fill(195, 220, 245);
      textAlign(CENTER, TOP);
      textSize(9.5 * uiScale);
      text(nf(valX, 1, 4), vx, plotY + plotH + 4 * uiScale);
    }
  }

  for (int j = 0; j <= yDivs; j++) {
    float vy = lerp(plotY + plotH, plotY, j / float(yDivs));
    stroke(j % 2 == 0 ? color(175, 205, 225) : color(215, 230, 240));
    strokeWeight(1 * uiScale);
    line(plotX, vy, plotX + plotW, vy);

    if (j % 2 == 0) {
      float valY = lerp(yMin, yMax, j / float(yDivs));
      fill(195, 220, 245);
      textAlign(RIGHT, CENTER);
      textSize(9.5 * uiScale);
      text(nf(valY, 1, 3), plotX - 6 * uiScale, vy);
    }
  }

  // Axis Titles
  fill(115, 225, 255);
  textAlign(CENTER, TOP);
  textSize(11 * uiScale);
  text("Cross Section Area a (m^2)", plotX + plotW * 0.5, plotY + plotH + 22 * uiScale);

  pushMatrix();
  translate(gx + 12 * uiScale, plotY + plotH * 0.5);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text("Total Head H (m)", 0, 0);
  popMatrix();

  // Horizontal Mean Line (H_mean = 0.2936 m -> Bernoulli Constant Head Line)
  float meanY = map(meanTotalHead, yMin, yMax, plotY + plotH, plotY);
  stroke(220, 65, 65);
  strokeWeight(2.2 * uiScale);
  float endLineX = lerp(plotX, plotX + plotW, graphAnim);
  line(plotX, meanY, endLineX, meanY);

  fill(200, 40, 40);
  textAlign(RIGHT, BOTTOM);
  textSize(10 * uiScale);
  text("Mean Total Head H = 0.2936 m (Constant)", plotX + plotW - 6 * uiScale, meanY - 3 * uiScale);

  // Plot all 5 Reading Points (S1..S5)
  for (int i = 0; i < numReadings; i++) {
    float px = map(ductArea[i], xMin, xMax, plotX, plotX + plotW);
    float py = map(totalHead[i], yMin, yMax, plotY + plotH, plotY);
    boolean isSel = (i == selectedReading);

    if (isSel) {
      // Dashed projection lines to X & Y axes
      stroke(230, 120, 20, 180);
      strokeWeight(1.4 * uiScale);
      line(px, py, px, plotY + plotH);
      line(plotX, py, px, py);

      fill(255, 195, 45, 120);
      noStroke();
      ellipse(px, py, 20 * uiScale, 20 * uiScale);
    }

    fill(isSel ? color(230, 115, 15) : color(24, 110, 195));
    stroke(255);
    strokeWeight(1.5 * uiScale);
    ellipse(px, py, 10 * uiScale, 10 * uiScale);

    fill(20, 35, 55);
    textAlign(CENTER, TOP);
    textSize(9.5 * uiScale);
    text("S" + sectionNo[i], px, py + 7 * uiScale);
  }
}

// ============================================================================
// TOUCH & MOUSE INTERACTION (1:1 HIT-TESTING ACROSS ALL 6 SCREENS)
// ============================================================================
void mousePressed() {
  lastTouchX = mouseX;
  lastTouchY = mouseY;

  // 1. Top Navigation Tabs
  float badgeW = 248 * uiScale;
  float tabsStartX = badgeW + 18 * uiScale;
  float tabsAvailW = width - tabsStartX - 10 * uiScale;
  float gap = 6 * uiScale;
  float tabW = (tabsAvailW - gap * 5) / 6.0;
  if (mouseY >= 0 && mouseY <= topBarH) {
    for (int i = 0; i < 6; i++) {
      float tx = tabsStartX + i * (tabW + gap);
      if (mouseX >= tx && mouseX <= tx + tabW) {
        currentScreen = i;
        if (currentScreen == 5) graphAnim = 0.0;
        return;
      }
    }
  }

  // 2. Bottom Navigation Bar (< PREV SCREEN, S1..S5 Pills, NEXT SCREEN >)
  float by = height - botBarH;
  if (mouseY >= by) {
    float btnW = 165 * uiScale;
    if (mouseX <= 12 * uiScale + btnW && currentScreen > 0) {
      currentScreen--;
      if (currentScreen == 5) graphAnim = 0.0;
      return;
    }
    if (mouseX >= width - btnW - 12 * uiScale && currentScreen < 5) {
      currentScreen++;
      if (currentScreen == 5) graphAnim = 0.0;
      return;
    }
    float pillW = 62 * uiScale;
    float pillGap = 6 * uiScale;
    float groupW = 5 * pillW + 4 * pillGap;
    float startX = width * 0.5 - groupW * 0.5 + 35 * uiScale;
    for (int i = 0; i < numReadings; i++) {
      float px = startX + i * (pillW + pillGap);
      if (mouseX >= px && mouseX <= px + pillW) {
        selectedReading = i;
        stopwatchSim = 0;
        return;
      }
    }
    return;
  }

  // 3. Screen-Specific Controls
  if (currentScreen == 0) {
    handleScreen1Press();
  } else if (currentScreen == 1) {
    handleScreen2Press();
  } else if (currentScreen == 2) {
    handleScreen3Press();
  } else if (currentScreen == 3) {
    handleScreen4Press();
  } else if (currentScreen == 4) {
    handleScreen5Press();
  } else if (currentScreen == 5) {
    handleScreen6Press();
  }
}

void mouseDragged() {
  if (currentScreen == 0) {
    if (draggingSlider1) {
      float cardX = 14 * uiScale;
      float cardW = 325 * uiScale;
      float slX = cardX + 14 * uiScale;
      float slW = cardW - 28 * uiScale;
      flowSliderVal = constrain(map(mouseX, slX, slX + slW, 0.5, 2.0), 0.5, 2.0);
    } else if (draggingOrbit) {
      rotY += (mouseX - lastTouchX) * 0.008;
      rotX = constrain(rotX + (mouseY - lastTouchY) * 0.008, -1.2, 0.45);
    }
  }
  lastTouchX = mouseX;
  lastTouchY = mouseY;
}

void mouseReleased() {
  draggingSlider1 = false;
  draggingOrbit = false;
}

void handleScreen1Press() {
  float cardX = 14 * uiScale;
  float cardW = 325 * uiScale;
  float ctrlY = contentBot - 118 * uiScale;

  // Slider hit check
  float slX = cardX + 14 * uiScale;
  float slY = ctrlY + 28 * uiScale;
  float slW = cardW - 28 * uiScale;
  if (mouseX >= slX - 10 * uiScale && mouseX <= slX + slW + 10 * uiScale &&
      mouseY >= slY && mouseY <= slY + 30 * uiScale) {
    draggingSlider1 = true;
    flowSliderVal = constrain(map(mouseX, slX, slX + slW, 0.5, 2.0), 0.5, 2.0);
    return;
  }

  // Camera buttons hit check
  float bY = ctrlY + 62 * uiScale;
  float bH = 38 * uiScale;
  float bW = (cardW - 36 * uiScale) / 3.0;
  if (mouseY >= bY && mouseY <= bY + bH) {
    if (mouseX >= cardX + 12 * uiScale && mouseX <= cardX + 12 * uiScale + bW) {
      autoOrbit = !autoOrbit;
      return;
    }
    if (mouseX >= cardX + 18 * uiScale + bW && mouseX <= cardX + 18 * uiScale + 2 * bW) {
      zoom3D = constrain(zoom3D - 0.12, 0.65, 1.75);
      return;
    }
    if (mouseX >= cardX + 24 * uiScale + 2 * bW && mouseX <= cardX + 24 * uiScale + 3 * bW) {
      zoom3D = constrain(zoom3D + 0.12, 0.65, 1.75);
      return;
    }
  }

  // Otherwise start 3D Orbit Drag
  draggingOrbit = true;
}

void handleScreen2Press() {
  float margin = 12 * uiScale;
  float leftW = width - 295 * uiScale - margin * 3;
  float rightX = margin * 2 + leftW;
  float rightW = 295 * uiScale;

  // Check Right Panel Layer Toggles
  float bx = rightX + 12 * uiScale;
  float bw = rightW - 24 * uiScale;
  float bh = 32 * uiScale;
  float by = contentTop + 42 * uiScale;
  float bStep = 38 * uiScale;

  if (mouseX >= bx && mouseX <= bx + bw) {
    if (mouseY >= by && mouseY <= by + bh) { showParticles = !showParticles; return; }
    if (mouseY >= by + bStep && mouseY <= by + bStep + bh) { showVectors = !showVectors; return; }
    if (mouseY >= by + 2 * bStep && mouseY <= by + 2 * bStep + bh) { showStreamlines = !showStreamlines; return; }
    if (mouseY >= by + 3 * bStep && mouseY <= by + 3 * bStep + bh) { showPathlines = !showPathlines; return; }
    if (mouseY >= by + 4 * bStep && mouseY <= by + 4 * bStep + bh) { showStreaklines = !showStreaklines; return; }
    if (mouseY >= by + 5 * bStep && mouseY <= by + 5 * bStep + bh) {
      float halfW = (bw - 8 * uiScale) * 0.5;
      if (mouseX <= bx + halfW) unsteadyMode = !unsteadyMode;
      else {
        streakPoints.clear();
        for (CutawayParticle cp : cutParticles) cp.trail.clear();
      }
      return;
    }
  }

  // Check Tap Inside Cutaway Duct to Relocate Tracer Dye Nozzle
  if (mouseX >= cutBoxX && mouseX <= cutBoxX + cutBoxW &&
      mouseY >= cutBoxY && mouseY <= cutBoxY + cutBoxH) {
    nozzleNormX = constrain((mouseX - cutBoxX) / cutBoxW, 0.04, 0.92);
    nozzleNormY = constrain((mouseY - cutBoxY) / cutBoxH, 0.15, 0.85);
    streakPoints.clear();
  }
}

void handleScreen3Press() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.56;
  float listTop = contentTop + 40 * uiScale;
  float ctrlH = 44 * uiScale;
  float listH = contentH - 48 * uiScale - ctrlH;
  float stepH = listH / derivTitles.length;

  // Tap any derivation step row
  if (mouseX >= margin + 30 * uiScale && mouseX <= margin + leftW - 10 * uiScale &&
      mouseY >= listTop && mouseY <= listTop + listH) {
    int idx = int((mouseY - listTop) / stepH);
    derivStep = constrain(idx, 0, derivTitles.length - 1);
    return;
  }

  // Bottom buttons: < Prev Step, Next Step >, Auto-Derive
  float bY = contentBot - ctrlH + 2 * uiScale;
  float bW = (leftW - 36 * uiScale) / 3.0;
  float bH = ctrlH - 8 * uiScale;
  if (mouseY >= bY && mouseY <= bY + bH) {
    if (mouseX >= margin + 12 * uiScale && mouseX <= margin + 12 * uiScale + bW) {
      derivStep = max(0, derivStep - 1);
    } else if (mouseX >= margin + 18 * uiScale + bW && mouseX <= margin + 18 * uiScale + 2 * bW) {
      derivStep = min(derivTitles.length - 1, derivStep + 1);
    } else if (mouseX >= margin + 24 * uiScale + 2 * bW && mouseX <= margin + 24 * uiScale + 3 * bW) {
      autoDerive = !autoDerive;
    }
  }
}

void handleScreen4Press() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.48;
  float listTop = contentTop + 40 * uiScale;
  float ctrlH = 44 * uiScale;
  float listH = contentH - 48 * uiScale - ctrlH;
  float stepH = listH / procTitles.length;

  if (mouseX >= margin + 30 * uiScale && mouseX <= margin + leftW - 10 * uiScale &&
      mouseY >= listTop && mouseY <= listTop + listH) {
    int idx = int((mouseY - listTop) / stepH);
    procStep = constrain(idx, 0, procTitles.length - 1);
    autoDemo = false;
    return;
  }

  float bY = contentBot - ctrlH + 2 * uiScale;
  float bH = ctrlH - 8 * uiScale;
  if (mouseX >= margin + 12 * uiScale && mouseX <= margin + leftW - 12 * uiScale &&
      mouseY >= bY && mouseY <= bY + bH) {
    autoDemo = !autoDemo;
  }
}

void handleScreen5Press() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.53;
  float rightX = margin * 2 + leftW;
  float rightW = (width - margin * 3) * 0.47;

  // Left Panel: Tap any BODMAS row
  float pillStripY = contentTop + 38 * uiScale;
  float pillStripH = 26 * uiScale;
  float rowsTop = pillStripY + pillStripH + 8 * uiScale;
  float rowsAvailH = contentBot - rowsTop - 8 * uiScale;
  float rowH = rowsAvailH / 8.0;

  if (mouseX >= margin + 30 * uiScale && mouseX <= margin + leftW - 10 * uiScale &&
      mouseY >= rowsTop && mouseY <= rowsTop + rowsAvailH) {
    bodmasStep = constrain(int((mouseY - rowsTop) / rowH), 0, 7);
    casioManualMode = false;
    return;
  }

  // Right Panel: Casio Touch Keys
  float lcdX = rightX + 14 * uiScale;
  float lcdY = contentTop + 40 * uiScale;
  float lcdW = rightW - 28 * uiScale;
  float lcdH = 54 * uiScale;
  float topCtrlY = lcdY + lcdH + 8 * uiScale;
  float pillW = 46 * uiScale;
  float pillH = 22 * uiScale;

  // SHIFT & ALPHA pills
  if (mouseY >= topCtrlY && mouseY <= topCtrlY + pillH + 6 * uiScale) {
    if (mouseX >= lcdX && mouseX <= lcdX + pillW) {
      casioShift = !casioShift;
      return;
    }
    if (mouseX >= lcdX + pillW + 8 * uiScale && mouseX <= lcdX + pillW * 2 + 8 * uiScale) {
      casioAlpha = !casioAlpha;
      return;
    }
  }

  float repH = 32 * uiScale;
  float sciTop = topCtrlY + repH + 8 * uiScale;
  float guideH = 26 * uiScale;
  float keysAvailH = (contentTop + contentH - guideH - 8 * uiScale) - sciTop;
  float sciAreaH = keysAvailH * 0.46;
  float numAreaH = keysAvailH * 0.54;

  // Numeric & Operator Keys Hit-Test
  float numTop = sciTop + sciAreaH + 4 * uiScale;
  float numGapX = 6 * uiScale;
  float numGapY = 6 * uiScale;
  float numBtnW = (lcdW - 4 * numGapX) / 5.0;
  float numBtnH = (numAreaH - 3 * numGapY) / 4.0 - 5 * uiScale;

  for (int row = 0; row < 4; row++) {
    for (int col = 0; col < 5; col++) {
      float kx = lcdX + col * (numBtnW + numGapX);
      float ky = numTop + row * (numBtnH + numGapY + 5 * uiScale) + 5 * uiScale;
      if (mouseX >= kx && mouseX <= kx + numBtnW && mouseY >= ky && mouseY <= ky + numBtnH) {
        processCasioKey(numKeys[row][col]);
        return;
      }
    }
  }
}

void processCasioKey(String k) {
  casioManualMode = true;
  if (k.equals("AC")) {
    casioCustomExpr = "";
    casioCustomAns = "0";
    casioManualMode = false;
  } else if (k.equals("DEL")) {
    if (casioCustomExpr.length() > 0) {
      casioCustomExpr = casioCustomExpr.substring(0, casioCustomExpr.length() - 1);
    }
  } else if (k.equals("=")) {
    casioCustomAns = nf(evalSimpleExpr(casioCustomExpr), 1, 5);
  } else if (k.equals("Ans")) {
    casioCustomExpr += nf(totalHead[selectedReading], 1, 4);
  } else if (k.equals("EXP")) {
    casioCustomExpr += "*10^";
  } else {
    casioCustomExpr += k;
  }
}

float evalSimpleExpr(String expr) {
  try {
    String clean = expr.replace("x", "*");
    if (clean.contains("+")) {
      String[] p = split(clean, '+');
      return float(p[0]) + float(p[1]);
    } else if (clean.contains("-")) {
      String[] p = split(clean, '-');
      return float(p[0]) - float(p[1]);
    } else if (clean.contains("*")) {
      String[] p = split(clean, '*');
      return float(p[0]) * float(p[1]);
    } else if (clean.contains("/")) {
      String[] p = split(clean, '/');
      if (float(p[1]) != 0) return float(p[0]) / float(p[1]);
    }
    return float(clean);
  } catch (Exception e) {
    return totalHead[selectedReading];
  }
}

void handleScreen6Press() {
  float margin = 12 * uiScale;
  float leftW = (width - margin * 3) * 0.55;
  float tblX = margin + 8 * uiScale;
  float tblW = leftW - 16 * uiScale;
  float hdrY = contentTop + 38 * uiScale;
  float hdrH = 30 * uiScale;
  float resBoxH = 92 * uiScale;
  float rowsTop = hdrY + hdrH + 4 * uiScale;
  float rowsAreaH = (contentBot - resBoxH - 12 * uiScale) - rowsTop;
  float rH = rowsAreaH / numReadings;

  if (mouseX >= tblX && mouseX <= tblX + tblW &&
      mouseY >= rowsTop && mouseY <= rowsTop + rowsAreaH) {
    selectedReading = constrain(int((mouseY - rowsTop) / rH), 0, numReadings - 1);
    stopwatchSim = 0;
  }
}
