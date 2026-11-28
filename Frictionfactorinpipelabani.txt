// ============================================================================
// PIPE FRICTION APPARATUS LAB (DARCY-WEISBACH FRICTION FACTOR)
// Complete 6-Screen Interactive Android APDE (P3D) Simulation App
// - 3D Apparatus centered & clipped cleanly inside its dedicated GUI Frame
// - Smooth Catmull-Rom curve point-joining graph for Friction Factor (f vs V)
// - Centralized CUSTOMIZATION CONFIG block at the top of the sketch
// ============================================================================

// ============================================================================
// 1. CUSTOMIZATION CONFIG (EDIT THESE VALUES FOR ANY PIPE FRICTION LAB RECORD)
// ============================================================================
final String LAB_TITLE          = "PIPE FRICTION LAB";
final String PIPE_MATERIAL      = "GI Pipe";
final int    DEFAULT_READING    = 0;     // 0 = R1 (Model Calculation row), 1 = R2, etc.
final int    NUM_PARALLEL_PIPES = 4;     // Number of test pipes shown on 3D rig
final int    ACTIVE_PIPE_INDEX  = 1;     // Which pipe (0..3) has pressure taps connected

// --- APPARATUS DIMENSIONS & FLUID CONSTANTS ---
final float PIPE_D    = 0.020;           // Pipe inner diameter in meters (20 mm = 0.020 m)
final float PIPE_L    = 3.0;             // Distance between pressure tappings in meters (3.0 m)
final float TANK_L    = 0.60;            // Collecting tank inner length in meters (600 mm = 0.60 m)
final float TANK_B    = 0.30;            // Collecting tank inner breadth in meters (300 mm = 0.30 m)
final float TANK_RISE = 0.10;            // Water rise in collecting tank in meters (10 cm = 0.10 m)
final float SG_MANO   = 13.6;            // Specific gravity of manometric fluid (Mercury = 13.6)
final float SG_FLOW   = 1.0;             // Specific gravity of flowing fluid (Water = 1.0)
final float G_ACC     = 9.81;            // Acceleration due to gravity (m/s^2)

// --- OBSERVATION TABLE INPUTS (ADD OR EDIT ROWS FREELY; ARRAYS MUST MATCH LENGTH) ---
float[] obs_h1 = { 14.0, 14.5, 15.0, 15.6, 16.2 }; // Left limb manometer reading (cm)
float[] obs_h2 = { 11.5, 11.0, 10.5, 10.0,  9.5 }; // Right limb manometer reading (cm)
float[] obs_T  = { 30.0, 26.0, 24.0, 22.0, 20.0 }; // Time taken for TANK_RISE (sec)

// --- VISUAL THEME & SIMULATION SPEED CUSTOMIZATION ---
final color COL_BG_DARK      = color(14, 20, 32);
final color COL_PANEL_BG     = color(20, 29, 46);
final color COL_HEADER_BLUE  = color(30, 58, 138);
final color COL_HEADER_TEAL  = color(14, 116, 144);
final color COL_ACCENT_CYAN  = color(56, 189, 248);
final color COL_ACCENT_GOLD  = color(250, 204, 21);
final color COL_ACCENT_GREEN = color(74, 222, 128);
final color COL_ACCENT_RED   = color(244, 63, 94);
final int   RIG_PARTICLE_COUNT     = 85;
final int   CUTAWAY_PARTICLE_COUNT = 70;

// ============================================================================
// 2. DERIVED CONSTANTS & DYNAMIC ARRAYS (AUTO-COMPUTED FROM CONFIG ABOVE)
// ============================================================================
final float PIPE_A    = PI * PIPE_D * PIPE_D / 4.0;
final float TANK_AREA = TANK_L * TANK_B;
final float SG_FACTOR = (SG_MANO / SG_FLOW) - 1.0; // e.g., 13.6 - 1.0 = 12.6
int NUM_READINGS;

float[] calc_h;   // Manometric head diff h = (h1 - h2) / 100 (m)
float[] calc_hf;  // Friction head loss hf = h * SG_FACTOR (m of flowing fluid)
float[] calc_Q;   // Actual discharge Q = (TANK_AREA * TANK_RISE) / T (m^3/s)
float[] calc_V;   // Flow velocity V = Q / PIPE_A (m/s)
float[] calc_V2;  // Velocity squared V^2 (m^2/s^2)
float[] calc_f;   // Darcy friction factor f = (hf * 2 * g * d) / (L * V^2)

float meanFrictionFactor = 0.0;
float minVelocityObs     = 0.5;
float maxVelocityObs     = 1.0;
float minHeadLossObs     = 0.1;
float maxHeadLossObs     = 1.0;
float minVelSqObs        = 1.0;
float maxVelSqObs        = 10.0;
float minFrictionObs     = 0.005;
float maxFrictionObs     = 0.020;

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

int selectedReading = 0;
float uiScale = 1.0;

// --- SCREEN 1: 3D RIG STATE ---
float rotX = -0.20;
float rotY = 0.36;
float camZoom = 1.0;
boolean autoOrbit = false;
float valveFlowMultiplier = 1.0;
boolean draggingOrbit = false;
boolean draggingSlider = false;
float prevTouchX = 0;
float prevTouchY = 0;

class FlowParticle3D {
  float progress;
  float radialOffset;
  float angleOffset;
  FlowParticle3D(float p, float r, float a) {
    progress = p;
    radialOffset = r;
    angleOffset = a;
  }
}
ArrayList<FlowParticle3D> rigParticles = new ArrayList<FlowParticle3D>();

// --- SCREEN 2: 2D CUTAWAY FLUID SIMULATION STATE ---
boolean unsteadyMode = false;
float dyeNozzleX = 0.22;
float dyeNozzleY = 0.50;

class FluidParticle2D {
  float nx, ny;
  ArrayList<PVector> trail;
  FluidParticle2D(float x, float y) {
    nx = x;
    ny = y;
    trail = new ArrayList<PVector>();
  }
}
ArrayList<FluidParticle2D> cutawayParticles = new ArrayList<FluidParticle2D>();
ArrayList<PVector> streakPoints = new ArrayList<PVector>();

// --- SCREEN 3: DERIVATION STATE ---
int derivStep = 0;
boolean autoDerive = false;
int lastDeriveTick = 0;
String[] derivTitles;
String[] derivFormulas;
String[] derivNotes;

// --- SCREEN 4: PROCEDURE STATE ---
int procStep = 0;
boolean autoProc = false;
int lastProcTick = 0;
float stopwatchAnim = 0.0;
String[] procTitles;
String[] procDetails;

// --- SCREEN 5: BODMAS & CASIO FX-991MS STATE ---
int bodmasStep = 0;
boolean autoBodmas = false;
int lastBodmasTick = 0;
String casioUserExpr = "";
String casioUserAns = "";
boolean casioManualMode = false;

// --- SCREEN 6: GRAPH ANIMATION & MODE STATE ---
float graphAnimProgress = 0.0;
boolean graphModeLinearHf = false; // false = f vs V (Smooth Curve), true = hf vs V^2 (Linear)

// ============================================================================
// SETUP & SETTINGS
// ============================================================================
void settings() {
  fullScreen(P3D);
}

void setup() {
  orientation(LANDSCAPE);
  textFont(createFont("SansSerif", 16, true));
  uiScale = constrain(min(width / 1280.0, height / 720.0), 0.55, 1.5);

  NUM_READINGS = min(obs_h1.length, min(obs_h2.length, obs_T.length));
  selectedReading = constrain(DEFAULT_READING, 0, NUM_READINGS - 1);

  calc_h  = new float[NUM_READINGS];
  calc_hf = new float[NUM_READINGS];
  calc_Q  = new float[NUM_READINGS];
  calc_V  = new float[NUM_READINGS];
  calc_V2 = new float[NUM_READINGS];
  calc_f  = new float[NUM_READINGS];

  computeAllReadings();
  buildDynamicTextContent();
  initRigParticles();
  initCutawayParticles();
  resetGraphAnim();
}

void computeAllReadings() {
  float sumF = 0;
  minVelocityObs = 1e9;
  maxVelocityObs = -1e9;
  minHeadLossObs = 1e9;
  maxHeadLossObs = -1e9;
  minVelSqObs    = 1e9;
  maxVelSqObs    = -1e9;
  minFrictionObs = 1e9;
  maxFrictionObs = -1e9;

  for (int i = 0; i < NUM_READINGS; i++) {
    calc_h[i]  = (obs_h1[i] - obs_h2[i]) / 100.0;
    calc_hf[i] = calc_h[i] * SG_FACTOR;
    calc_Q[i]  = (TANK_AREA * TANK_RISE) / obs_T[i];
    calc_V[i]  = calc_Q[i] / PIPE_A;
    calc_V2[i] = calc_V[i] * calc_V[i];
    calc_f[i]  = (calc_hf[i] * 2.0 * G_ACC * PIPE_D) / (PIPE_L * calc_V2[i]);

    sumF += calc_f[i];
    if (calc_V[i]  < minVelocityObs) minVelocityObs = calc_V[i];
    if (calc_V[i]  > maxVelocityObs) maxVelocityObs = calc_V[i];
    if (calc_hf[i] < minHeadLossObs) minHeadLossObs = calc_hf[i];
    if (calc_hf[i] > maxHeadLossObs) maxHeadLossObs = calc_hf[i];
    if (calc_V2[i] < minVelSqObs)    minVelSqObs    = calc_V2[i];
    if (calc_V2[i] > maxVelSqObs)    maxVelSqObs    = calc_V2[i];
    if (calc_f[i]  < minFrictionObs) minFrictionObs = calc_f[i];
    if (calc_f[i]  > maxFrictionObs) maxFrictionObs = calc_f[i];
  }
  maxVelocityObs = max(0.001, maxVelocityObs);
  meanFrictionFactor = sumF / NUM_READINGS;
}

void buildDynamicTextContent() {
  String dStr = nf(PIPE_D, 0, 3);
  String lStr = nf(PIPE_L, 0, 1);
  String sgStr = nf(SG_FACTOR, 0, 1);
  String aTankStr = nf(TANK_AREA, 0, 2);
  String riseStr = nf(TANK_RISE, 0, 2);
  String meanFStr = nf(meanFrictionFactor, 0, 4);

  derivTitles = new String[] {
    "Step 1: Bernoulli Energy Equation (Sections 1 & 2)",
    "Step 2: Horizontal Uniform Pipe Simplification",
    "Step 3: Darcy-Weisbach Wall Friction Relation",
    "Step 4: Isolate Darcy Friction Factor (f)",
    "Step 5: Differential U-Tube Manometer",
    "Step 6: Volumetric Discharge & Flow Velocity",
    "Step 7: Final Working Lab Formula (f)"
  };

  derivFormulas = new String[] {
    "P1/(rho*g) + V1^2/(2*g) + Z1 = P2/(rho*g) + V2^2/(2*g) + Z2 + hf",
    "Z1 = Z2 & d1 = d2 => V1 = V2 = V  ==>  hf = (P1 - P2)/(rho*g)",
    "hf = (f * L * V^2) / (2 * g * d)   [L = " + lStr + " m, d = " + dStr + " m]",
    "f = (hf * 2 * g * d) / (L * V^2)",
    "h = (h1 - h2)/100 [m]  ==>  hf = h * (S_m/S_w - 1) = " + sgStr + " * h",
    "Q = (A_T * h_rise) / T = (" + aTankStr + " * " + riseStr + ") / T  ==>  V = Q / a",
    "f = (hf * 2 * " + nf(G_ACC, 0, 2) + " * " + dStr + ") / (" + lStr + " * V^2)   [Mean f = " + meanFStr + "]"
  };

  derivNotes = new String[] {
    "Total energy head at upstream tap 1 equals downstream tap 2 plus friction head loss hf.",
    "Since pipe is horizontal (Z1=Z2) and constant diameter (d=" + nf(PIPE_D * 1000, 0, 0) + " mm), velocity head cancels.",
    "Head loss hf is directly proportional to pipe length L and V^2, and inversely to diameter d.",
    "Rearranging Darcy-Weisbach equation isolates dimensionless friction factor f.",
    "Manometric head h (m) converts to equivalent fluid column hf using (" + nf(SG_MANO, 0, 1) + " - 1) = " + sgStr + ".",
    "Tank area A_T = " + nf(TANK_L, 0, 2) + " x " + nf(TANK_B, 0, 2) + " = " + aTankStr + " m^2; pipe area a = " + nf(PIPE_A * 10000, 0, 3) + "x10^-4 m^2.",
    "Substitute hf and V^2 for each reading R1..R" + NUM_READINGS + " to obtain friction factor f."
  };

  procTitles = new String[] {
    "1. Measure Pipe Diameter & Tapping Length",
    "2. Measure Collecting Tank Plan Dimensions",
    "3. Prime Pump & Purge Manometer Air Bubbles",
    "4. Set Flow Rate & Read Manometer Limbs (h1, h2)",
    "5. Close Gate Valve & Time " + riseStr + " m Tank Rise",
    "6. Repeat for " + NUM_READINGS + " Flow Rates & Plot f Curve"
  };

  procDetails = new String[] {
    "Select the d = " + nf(PIPE_D * 1000, 0, 0) + " mm (" + dStr + " m) " + PIPE_MATERIAL + " and verify tapping length L = " + lStr + " m.",
    "Measure inner plan size of collecting tank: Length = " + nf(TANK_L, 0, 2) + " m, Breadth = " + nf(TANK_B, 0, 2) + " m (A_T = " + aTankStr + " m^2).",
    "Close outlet valve, start motor-pump set, crack open outlet valve, and bleed air from U-tube hoses.",
    "Wait for steady flow; record left limb level h1 (cm) and right limb level h2 (cm) on scale.",
    "Shut collecting tank gate valve tightly; start stopwatch to record time T (sec) for " + nf(TANK_RISE * 100, 0, 0) + " cm (" + riseStr + " m) rise.",
    "Open outlet valve gradually for " + NUM_READINGS + " readings (R1..R" + NUM_READINGS + "), stop pump, tabulate data, and plot f vs V curve."
  };
}

void initRigParticles() {
  rigParticles.clear();
  for (int i = 0; i < RIG_PARTICLE_COUNT; i++) {
    rigParticles.add(new FlowParticle3D(float(i) / RIG_PARTICLE_COUNT, random(-0.6, 0.6), random(TWO_PI)));
  }
}

void initCutawayParticles() {
  cutawayParticles.clear();
  streakPoints.clear();
  for (int i = 0; i < CUTAWAY_PARTICLE_COUNT; i++) {
    cutawayParticles.add(new FluidParticle2D(random(0.02, 0.98), random(0.12, 0.88)));
  }
}

void resetGraphAnim() {
  graphAnimProgress = 0.0;
}

void selectReading(int idx) {
  selectedReading = constrain(idx, 0, NUM_READINGS - 1);
  valveFlowMultiplier = 1.0;
  casioManualMode = false;
  stopwatchAnim = 0.0;
}

// ============================================================================
// MAIN DRAW LOOP
// ============================================================================
void draw() {
  background(COL_BG_DARK);

  // Auto-advance timers for interactive demos
  if (currentScreen == 2 && autoDerive && millis() - lastDeriveTick > 2600) {
    derivStep = (derivStep + 1) % derivTitles.length;
    lastDeriveTick = millis();
  }
  if (currentScreen == 3 && autoProc && millis() - lastProcTick > 2800) {
    procStep = (procStep + 1) % procTitles.length;
    lastProcTick = millis();
  }
  if (currentScreen == 4 && autoBodmas && millis() - lastBodmasTick > 2400) {
    bodmasStep = (bodmasStep + 1) % 8;
    casioManualMode = false;
    lastBodmasTick = millis();
  }

  // Advance stopwatch simulation on Screen 4
  float targetT = obs_T[selectedReading];
  stopwatchAnim += 1.0 / 60.0;
  if (stopwatchAnim > targetT) {
    stopwatchAnim = 0.0;
  }

  // Advance graph curve animation on Screen 6
  if (currentScreen == 5 && graphAnimProgress < 1.0) {
    graphAnimProgress = min(1.0, graphAnimProgress + 0.025);
  }

  // Screen 1: Draw GUI Frame first, then 3D Apparatus strictly inside the frame
  if (currentScreen == 0) {
    if (autoOrbit && !draggingOrbit) {
      rotY += 0.008;
    }
    beginHUD();
    drawTopNavBar();
    drawScreen1_FrameBackdrops();
    drawBottomNavBar();
    endHUD();

    // Render 3D Apparatus centered and clipped inside the Left GUI Frame
    drawApparatus3DInFrame();

    // Draw crisp frame border & telemetry HUD overlays on top
    beginHUD();
    drawScreen1_FrameOverlays();
    drawScreen1_TelemetryHUD();
    endHUD();
  } else {
    beginHUD();
    drawTopNavBar();
    if (currentScreen == 1) drawScreen2_CutawayPhysics();
    else if (currentScreen == 2) drawScreen3_Derivation();
    else if (currentScreen == 3) drawScreen4_Procedure();
    else if (currentScreen == 4) drawScreen5_CasioCalc();
    else if (currentScreen == 5) drawScreen6_TableAndGraph();
    drawBottomNavBar();
    endHUD();
  }
}

// ============================================================================
// HUD DEPTH-BUFFER & ORTHOGRAPHIC ISOLATION HELPERS
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

// ============================================================================
// TOP & BOTTOM NAVIGATION BARS (SHARED ACROSS ALL 6 SCREENS)
// ============================================================================
float getTopBarH() {
  return 54 * uiScale;
}

float getBotBarH() {
  return 48 * uiScale;
}

void drawTopNavBar() {
  float barH = getTopBarH();
  noStroke();
  fill(COL_PANEL_BG);
  rect(0, 0, width, barH);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  line(0, barH, width, barH);

  // Title Badge
  float titleW = 245 * uiScale;
  fill(COL_HEADER_TEAL);
  noStroke();
  rect(8 * uiScale, 6 * uiScale, titleW, barH - 12 * uiScale, 6 * uiScale);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(14 * uiScale);
  text(LAB_TITLE, 16 * uiScale, barH * 0.36);
  fill(186, 230, 253);
  textSize(10.5 * uiScale);
  text("d=" + nf(PIPE_D * 1000, 0, 0) + "mm | L=" + nf(PIPE_L, 0, 1) + "m | Mean f=" + nf(meanFrictionFactor, 0, 4),
       16 * uiScale, barH * 0.72);

  // 6 Screen Tabs
  float tabsStartX = titleW + 16 * uiScale;
  float activeBadgeW = 92 * uiScale;
  float tabsAvailW = width - tabsStartX - activeBadgeW - 14 * uiScale;
  float tabW = tabsAvailW / 6.0;

  for (int i = 0; i < 6; i++) {
    float tx = tabsStartX + i * tabW;
    float ty = 6 * uiScale;
    float tw = tabW - 4 * uiScale;
    float th = barH - 12 * uiScale;

    if (i == currentScreen) {
      fill(37, 99, 235);
      stroke(147, 197, 253);
      strokeWeight(1.5);
    } else {
      fill(30, 41, 59);
      stroke(51, 65, 85);
      strokeWeight(1);
    }
    rect(tx, ty, tw, th, 6 * uiScale);

    fill(i == currentScreen ? 255 : 190);
    textAlign(CENTER, CENTER);
    textSize(11.5 * uiScale);
    text(screenNames[i], tx + tw * 0.5, ty + th * 0.5);
  }

  // Active Reading Pill on Right
  float bx = width - activeBadgeW - 6 * uiScale;
  fill(22, 101, 52);
  stroke(COL_ACCENT_GREEN);
  strokeWeight(1.5);
  rect(bx, 6 * uiScale, activeBadgeW, barH - 12 * uiScale, 6 * uiScale);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(12 * uiScale);
  text("ACTIVE: R" + (selectedReading + 1), bx + activeBadgeW * 0.5, barH * 0.5);
}

void drawBottomNavBar() {
  float barH = getBotBarH();
  float y0 = height - barH;
  noStroke();
  fill(COL_PANEL_BG);
  rect(0, y0, width, barH);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  line(0, y0, width, y0);

  float btnW = 155 * uiScale;
  float btnH = barH - 12 * uiScale;
  float btnY = y0 + 6 * uiScale;

  // < PREV SCREEN
  fill(currentScreen > 0 ? color(51, 65, 85) : color(30, 38, 52));
  stroke(100, 116, 139);
  strokeWeight(1);
  rect(10 * uiScale, btnY, btnW, btnH, 6 * uiScale);
  fill(currentScreen > 0 ? 255 : 110);
  textAlign(CENTER, CENTER);
  textSize(12 * uiScale);
  text("< PREV SCREEN", 10 * uiScale + btnW * 0.5, btnY + btnH * 0.5);

  // NEXT SCREEN >
  float nextX = width - btnW - 10 * uiScale;
  fill(currentScreen < 5 ? color(37, 99, 235) : color(30, 38, 52));
  stroke(147, 197, 253);
  strokeWeight(1);
  rect(nextX, btnY, btnW, btnH, 6 * uiScale);
  fill(currentScreen < 5 ? 255 : 110);
  text("NEXT SCREEN >", nextX + btnW * 0.5, btnY + btnH * 0.5);

  // Center Quick Reading Selector Pills (R1..Rn)
  float pillW = constrain(230.0 / max(1, NUM_READINGS), 30, 48) * uiScale;
  float pillGap = 6 * uiScale;
  float labelW = 135 * uiScale;
  float totalGroupW = labelW + NUM_READINGS * (pillW + pillGap);
  float startX = (width - totalGroupW) * 0.5;

  fill(148, 163, 184);
  textAlign(RIGHT, CENTER);
  textSize(11.5 * uiScale);
  text("Select Reading:", startX + labelW - 8 * uiScale, btnY + btnH * 0.5);

  for (int i = 0; i < NUM_READINGS; i++) {
    float px = startX + labelW + i * (pillW + pillGap);
    if (i == selectedReading) {
      fill(234, 88, 12);
      stroke(253, 186, 116);
      strokeWeight(1.5);
    } else {
      fill(30, 41, 59);
      stroke(71, 85, 105);
      strokeWeight(1);
    }
    rect(px, btnY, pillW, btnH, 5 * uiScale);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(12 * uiScale);
    text("R" + (i + 1), px + pillW * 0.5, btnY + btnH * 0.5);
  }
}

// ============================================================================
// SCREEN 1: 3D APPARATUS INSIDE DEDICATED GUI FRAME
// ============================================================================
float[] getRigFrameRect() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float hudW = 355 * uiScale;
  float fx = 14 * uiScale;
  float fy = topY;
  float fw = width - hudW - 36 * uiScale;
  float fh = botY - topY;
  return new float[] { fx, fy, fw, fh };
}

float[] getRigViewportRect() {
  float[] f = getRigFrameRect();
  float hdrH = 34 * uiScale;
  float ctrlAreaH = 98 * uiScale;
  float vx = f[0] + 6 * uiScale;
  float vy = f[1] + hdrH + 4 * uiScale;
  float vw = f[2] - 12 * uiScale;
  float vh = f[3] - hdrH - ctrlAreaH - 8 * uiScale;
  return new float[] { vx, vy, vw, vh };
}

void drawScreen1_FrameBackdrops() {
  float[] f = getRigFrameRect();
  float[] vp = getRigViewportRect();

  // Outer GUI Frame Container for 3D Rig
  fill(COL_PANEL_BG);
  stroke(59, 130, 246);
  strokeWeight(1.5);
  rect(f[0], f[1], f[2], f[3], 8 * uiScale);

  // Header Bar of 3D GUI Frame
  fill(COL_HEADER_BLUE);
  noStroke();
  rect(f[0], f[1], f[2], 34 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("3D PIPE FRICTION APPARATUS RIG (INTERACTIVE VIEW)", f[0] + 12 * uiScale, f[1] + 17 * uiScale);

  fill(186, 230, 253);
  textAlign(RIGHT, CENTER);
  textSize(10.5 * uiScale);
  text("Drag inside frame to orbit  |  Zoom: " + nf(camZoom * 100, 0, 0) + "%",
       f[0] + f[2] - 12 * uiScale, f[1] + 17 * uiScale);

  // Inner 3D Viewport Canvas Backdrop with Subtle Engineering Grid
  fill(11, 18, 30);
  stroke(45, 65, 95);
  strokeWeight(1);
  rect(vp[0], vp[1], vp[2], vp[3], 6 * uiScale);

  stroke(30, 45, 70, 95);
  strokeWeight(1);
  float gridStep = 28 * uiScale;
  for (float gx = vp[0] + gridStep; gx < vp[0] + vp[2]; gx += gridStep) {
    line(gx, vp[1] + 2, gx, vp[1] + vp[3] - 2);
  }
  for (float gy = vp[1] + gridStep; gy < vp[1] + vp[3]; gy += gridStep) {
    line(vp[0] + 2, gy, vp[0] + vp[2] - 2, gy);
  }
}

void drawScreen1_FrameOverlays() {
  float[] f = getRigFrameRect();
  float[] vp = getRigViewportRect();

  // Re-stroke inner viewport frame border cleanly over 3D edges
  noFill();
  stroke(56, 189, 248, 150);
  strokeWeight(1.3);
  rect(vp[0], vp[1], vp[2], vp[3], 6 * uiScale);

  // Bottom Control Dock inside the Left GUI Frame
  float ctrlX = f[0] + 6 * uiScale;
  float ctrlW = f[2] - 12 * uiScale;
  float ctrlH = 90 * uiScale;
  float ctrlY = f[1] + f[3] - ctrlH - 6 * uiScale;

  fill(15, 23, 42, 235);
  stroke(56, 189, 248, 140);
  strokeWeight(1.2);
  rect(ctrlX, ctrlY, ctrlW, ctrlH, 6 * uiScale);

  float bY = ctrlY + 10 * uiScale;
  float bH = 30 * uiScale;
  float gap = 8 * uiScale;
  float bW = min(122 * uiScale, (ctrlW - 5 * gap) / 4.0);

  drawSmallButton(ctrlX + gap, bY, bW, bH,
    autoOrbit ? "Auto-Orbit: ON" : "Auto-Orbit: OFF",
    autoOrbit ? color(22, 163, 74) : color(51, 65, 85));
  drawSmallButton(ctrlX + gap + (bW + gap), bY, bW, bH,
    "Zoom +", color(37, 99, 235));
  drawSmallButton(ctrlX + gap + 2 * (bW + gap), bY, bW, bH,
    "Zoom -", color(37, 99, 235));
  drawSmallButton(ctrlX + gap + 3 * (bW + gap), bY, bW, bH,
    "Reset View", color(71, 85, 105));

  // Outlet Valve Flow Slider
  float slX = ctrlX + 145 * uiScale;
  float slW = ctrlW - 195 * uiScale;
  float slY = ctrlY + 62 * uiScale;

  fill(203, 213, 225);
  textAlign(LEFT, CENTER);
  textSize(11.5 * uiScale);
  text("Outlet Valve Flow:", ctrlX + 12 * uiScale, slY);

  stroke(71, 85, 105);
  strokeWeight(5 * uiScale);
  line(slX, slY, slX + slW, slY);

  float normVal = constrain((valveFlowMultiplier - 0.5) / 1.0, 0, 1);
  float knobX = slX + normVal * slW;
  stroke(COL_ACCENT_CYAN);
  line(slX, slY, knobX, slY);

  noStroke();
  fill(COL_ACCENT_GOLD);
  ellipse(knobX, slY, 16 * uiScale, 16 * uiScale);

  fill(COL_ACCENT_GOLD);
  textAlign(RIGHT, CENTER);
  textSize(11.5 * uiScale);
  text(nf(valveFlowMultiplier * 100, 0, 0) + "%", ctrlX + ctrlW - 12 * uiScale, slY);
}

void drawApparatus3DInFrame() {
  float[] vp = getRigViewportRect();
  float vpCenterX = vp[0] + vp[2] * 0.5;
  float vpCenterY = vp[1] + vp[3] * 0.5;

  // Auto-fit 3D rig dimensions (~680 x 340 units) inside the GUI viewport box
  float rigFitScale = min(vp[2] / 720.0, vp[3] / 365.0);

  // Clip 3D rendering strictly inside the GUI viewport rectangle
  clip(vp[0] + 1, vp[1] + 1, vp[2] - 2, vp[3] - 2);

  float fov = PI / 3.2;
  float baseZ = (height * 0.5) / tan(fov * 0.5);
  float shiftX = (width * 0.5 - vpCenterX) / camZoom;
  float shiftY = (height * 0.5 - vpCenterY) / camZoom;

  perspective(fov, float(width) / float(height), 10, 5000);
  camera(shiftX, shiftY, baseZ / camZoom,
         shiftX, shiftY, 0,
         0, 1, 0);

  ambientLight(105, 115, 130);
  directionalLight(240, 245, 255, -0.35, 0.7, -0.6);
  pointLight(130, 215, 255, -180, -150, 240);

  pushMatrix();
  scale(rigFitScale);
  translate(0, -10, 0);
  rotateX(rotX);
  rotateY(rotY);

  // 1. Floor Base Frame & Support Stanchions
  pushMatrix();
  translate(0, 155, 0);
  fill(45, 55, 72);
  stroke(75, 90, 115);
  strokeWeight(1);
  box(660, 14, 240);
  popMatrix();

  // Vertical Frame Posts supporting test pipe manifold
  fill(51, 65, 85);
  noStroke();
  pushMatrix();
  translate(-220, 15, 55);
  box(10, 270, 10);
  popMatrix();
  pushMatrix();
  translate(95, 15, 55);
  box(10, 270, 10);
  popMatrix();

  // 2. Reservoir Sump Tank (Right-Rear)
  pushMatrix();
  translate(210, 95, -25);
  fill(55, 70, 92, 165);
  stroke(120, 160, 200);
  strokeWeight(1.2);
  box(170, 105, 140);
  translate(0, 12, 0);
  noStroke();
  fill(14, 165, 233, 150);
  box(162, 76, 132);
  popMatrix();

  // Strainer / Foot Valve in Sump
  pushMatrix();
  translate(145, 125, 15);
  fill(217, 119, 6);
  noStroke();
  drawCylinder(10, 22, 14);
  popMatrix();

  // 3. Motor-Pump Set (Bottom Right-Front)
  pushMatrix();
  translate(185, 120, 55);
  fill(30, 41, 59);
  box(95, 12, 55);
  translate(18, -22, 0);
  rotateZ(HALF_PI);
  fill(37, 99, 235);
  drawCylinder(20, 48, 20);
  translate(0, 34, 0);
  fill(COL_HEADER_TEAL);
  drawCylinder(24, 18, 20);
  popMatrix();

  // 4. Suction & Delivery Supply Pipe to Left Vertical Manifold
  noStroke();
  fill(148, 163, 184);
  pushMatrix();
  translate(145, 110, 35);
  rotateX(HALF_PI);
  drawCylinder(6, 42, 12);
  popMatrix();

  pushMatrix();
  translate(-35, 98, 55);
  rotateZ(HALF_PI);
  drawCylinder(7, 370, 14);
  popMatrix();

  // Left Vertical Supply Header
  pushMatrix();
  translate(-220, -25, 55);
  drawCylinder(10, 250, 16);
  popMatrix();

  // Right Vertical Return Header
  pushMatrix();
  translate(95, -25, 55);
  drawCylinder(10, 250, 16);
  popMatrix();

  // 5. Parallel Horizontal Test Pipes of Different Diameters
  int pipeCount = constrain(NUM_PARALLEL_PIPES, 1, 5);
  int activeIdx = constrain(ACTIVE_PIPE_INDEX, 0, pipeCount - 1);
  float activePipeY = -62;

  for (int p = 0; p < pipeCount; p++) {
    float curPipeY = (pipeCount == 1) ? -35 : map(p, 0, pipeCount - 1, -118, 36);
    float curPipeR = map(p, 0, max(1, pipeCount - 1), 4.5, 11.0);
    if (p == activeIdx) activePipeY = curPipeY;

    pushMatrix();
    translate(-62.5, curPipeY, 55);
    rotateZ(HALF_PI);
    fill(p == activeIdx ? COL_ACCENT_CYAN : color(185, 75, 55));
    drawCylinder(curPipeR, 315, 16);
    popMatrix();

    // Outlet Valve on each pipe
    pushMatrix();
    translate(65, curPipeY, 55);
    fill(p == activeIdx ? color(34, 197, 94) : color(220, 38, 38));
    box(16, 16, 16);
    translate(0, -14, 0);
    fill(226, 232, 240);
    drawCylinder(2, 14, 8);
    translate(0, -7, 0);
    fill(p == activeIdx ? COL_ACCENT_GREEN : color(248, 113, 113));
    drawCylinder(11, 3, 14);
    popMatrix();
  }

  // Pressure Tapping Nipples (L apart) on Active Pipe
  float tap1X = -175;
  float tap2X = 25;

  pushMatrix();
  translate(tap1X, activePipeY - 12, 55);
  fill(COL_ACCENT_GOLD);
  drawCylinder(3.5, 14, 10);
  popMatrix();

  pushMatrix();
  translate(tap2X, activePipeY - 12, 55);
  fill(COL_ACCENT_GOLD);
  drawCylinder(3.5, 14, 10);
  popMatrix();

  // 6. Central Differential U-Tube Manometer Board
  pushMatrix();
  translate(-75, -35, 10);
  fill(120, 82, 48);
  stroke(161, 116, 72);
  strokeWeight(1);
  box(74, 175, 10);

  translate(0, 0, 6);
  noStroke();
  fill(241, 245, 249);
  box(26, 150, 2);

  fill(200, 235, 255, 140);
  pushMatrix();
  translate(-18, -5, 3);
  drawCylinder(4, 140, 12);
  popMatrix();
  pushMatrix();
  translate(18, -5, 3);
  drawCylinder(4, 140, 12);
  popMatrix();
  pushMatrix();
  translate(0, 65, 3);
  rotateZ(HALF_PI);
  drawCylinder(4, 36, 12);
  popMatrix();

  // Live Manometer Columns
  float curH_cm = abs(obs_h1[selectedReading] - obs_h2[selectedReading]) * valveFlowMultiplier;
  float deflectPx = constrain(curH_cm * 4.5, 4, 42);
  fill(226, 232, 240);
  float leftHgH = 52 - deflectPx * 0.5;
  pushMatrix();
  translate(-18, 65 - leftHgH * 0.5, 3.5);
  drawCylinder(3.2, leftHgH, 12);
  popMatrix();
  float rightHgH = 52 + deflectPx * 0.5;
  pushMatrix();
  translate(18, 65 - rightHgH * 0.5, 3.5);
  drawCylinder(3.2, rightHgH, 12);
  popMatrix();
  pushMatrix();
  translate(0, 65, 3.5);
  rotateZ(HALF_PI);
  drawCylinder(3.2, 36, 12);
  popMatrix();
  popMatrix();

  // Flexible Manometer Connecting Tubes (Bezier Curves)
  noFill();
  stroke(250, 204, 21, 220);
  strokeWeight(2.5);
  bezier(tap1X, activePipeY - 18, 55,
         tap1X - 15, activePipeY - 75, 45,
         -115, -125, 15,
         -93, -108, 13);
  bezier(tap2X, activePipeY - 18, 55,
         tap2X + 10, activePipeY - 75, 45,
         -35, -125, 15,
         -57, -108, 13);

  // 7. Collecting Tank with Gate Valve & Piezometer
  pushMatrix();
  translate(210, -25, 25);
  fill(56, 189, 248, 65);
  stroke(125, 211, 252);
  strokeWeight(1.2);
  box(125, 95, 95);

  float fillRatio = 0.25 + 0.55 * (stopwatchAnim / max(1.0, obs_T[selectedReading]));
  float waterH = 85 * fillRatio;
  noStroke();
  fill(14, 165, 233, 185);
  pushMatrix();
  translate(0, 45 - waterH * 0.5, 0);
  box(119, waterH, 89);
  popMatrix();

  fill(224, 242, 254, 170);
  pushMatrix();
  translate(-45, 0, 51);
  drawCylinder(3, 86, 10);
  popMatrix();

  pushMatrix();
  translate(0, 56, 0);
  fill(239, 68, 68);
  drawCylinder(7, 22, 12);
  translate(14, 0, 0);
  rotateZ(HALF_PI);
  fill(248, 250, 252);
  drawCylinder(8, 3, 12);
  popMatrix();
  popMatrix();

  // Discharge pipe from top of right return header into Collecting Tank
  noStroke();
  fill(148, 163, 184);
  pushMatrix();
  translate(135, -135, 40);
  rotateZ(HALF_PI);
  drawCylinder(8, 90, 14);
  popMatrix();
  pushMatrix();
  translate(178, -110, 40);
  drawCylinder(8, 55, 14);
  popMatrix();

  // 8. Animated 3D Flow Particles along Rig Loop
  float speedFactor = (calc_V[selectedReading] / maxVelocityObs) * valveFlowMultiplier;
  float dt = 0.0045 * max(0.25, speedFactor);
  noStroke();
  for (FlowParticle3D fp : rigParticles) {
    fp.progress = (fp.progress + dt) % 1.0;
    PVector pos = getRigLoopPoint(fp.progress, activePipeY);
    pushMatrix();
    translate(pos.x, pos.y + sin(fp.angleOffset) * fp.radialOffset * 2.5,
              pos.z + cos(fp.angleOffset) * fp.radialOffset * 2.5);
    fill(125, 249, 255);
    sphere(3.0);
    popMatrix();
  }

  popMatrix();
  noClip();
}

PVector getRigLoopPoint(float t, float activePipeY) {
  if (t < 0.22) {
    float u = t / 0.22;
    return new PVector(lerp(150, -220, u), 98, 55);
  } else if (t < 0.38) {
    float u = (t - 0.22) / 0.16;
    return new PVector(-220, lerp(98, activePipeY, u), 55);
  } else if (t < 0.72) {
    float u = (t - 0.38) / 0.34;
    return new PVector(lerp(-220, 95, u), activePipeY, 55);
  } else if (t < 0.88) {
    float u = (t - 0.72) / 0.16;
    return new PVector(95, lerp(activePipeY, -135, u), 55);
  } else {
    float u = (t - 0.88) / 0.12;
    return new PVector(lerp(95, 178, u), lerp(-135, -85, u), lerp(55, 40, u));
  }
}

void drawCylinder(float r, float h, int sides) {
  float halfH = h * 0.5;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = TWO_PI * i / sides;
    float x = cos(a) * r;
    float z = sin(a) * r;
    vertex(x, -halfH, z);
    vertex(x, halfH, z);
  }
  endShape();

  beginShape(TRIANGLE_FAN);
  vertex(0, -halfH, 0);
  for (int i = 0; i <= sides; i++) {
    float a = TWO_PI * i / sides;
    vertex(cos(a) * r, -halfH, sin(a) * r);
  }
  endShape();

  beginShape(TRIANGLE_FAN);
  vertex(0, halfH, 0);
  for (int i = 0; i <= sides; i++) {
    float a = TWO_PI * i / sides;
    vertex(cos(a) * r, halfH, sin(a) * r);
  }
  endShape();
}

// --- SCREEN 1 RIGHT TELEMETRY HUD CARD ---
void drawScreen1_TelemetryHUD() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;

  float hudW = 355 * uiScale;
  float hudH = botY - topY;
  float hudX = width - hudW - 14 * uiScale;
  float hudY = topY;

  fill(COL_PANEL_BG);
  stroke(59, 130, 246);
  strokeWeight(1.5);
  rect(hudX, hudY, hudW, hudH, 8 * uiScale);

  fill(COL_HEADER_BLUE);
  noStroke();
  rect(hudX, hudY, hudW, 34 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("LIVE TELEMETRY - READING R" + (selectedReading + 1), hudX + 12 * uiScale, hudY + 17 * uiScale);

  float h1 = obs_h1[selectedReading];
  float h2 = obs_h2[selectedReading];
  float hM = calc_h[selectedReading] * valveFlowMultiplier;
  float hf = hM * SG_FACTOR;
  float Q  = calc_Q[selectedReading] * valveFlowMultiplier;
  float V  = calc_V[selectedReading] * valveFlowMultiplier;
  float V2 = V * V;
  float f  = (hf * 2.0 * G_ACC * PIPE_D) / (PIPE_L * max(0.0001, V2));

  String[][] rows = {
    { "Pipe Diameter (d)", nf(PIPE_D * 1000, 0, 0) + " mm (" + nf(PIPE_D, 0, 3) + " m)" },
    { "Tapping Length (L)", nf(PIPE_L, 0, 1) + " m" },
    { "Tank Area (A_T)", nf(TANK_L, 0, 2) + " x " + nf(TANK_B, 0, 2) + " = " + nf(TANK_AREA, 0, 2) + " m^2" },
    { "Left Limb Level (h1)", nf(h1, 0, 1) + " cm" },
    { "Right Limb Level (h2)", nf(h2, 0, 1) + " cm" },
    { "Manometer Diff (h)", nf(hM, 0, 4) + " m" },
    { "Head Loss (hf = " + nf(SG_FACTOR, 0, 1) + "h)", nf(hf, 0, 3) + " m" },
    { "Time for " + nf(TANK_RISE, 0, 2) + "m Rise (T)", nf(obs_T[selectedReading], 0, 0) + " sec" },
    { "Discharge (Q)", nf(Q * 10000.0, 0, 2) + " x10^-4 m^3/s" },
    { "Flow Velocity (V)", nf(V, 0, 3) + " m/s" },
    { "Velocity Squared (V^2)", nf(V2, 0, 3) + " m^2/s^2" },
    { "Friction Factor (f)", nf(f, 0, 4) }
  };

  float startRowY = hudY + 46 * uiScale;
  float rowStep = (hudH - 88 * uiScale) / rows.length;

  for (int i = 0; i < rows.length; i++) {
    float ry = startRowY + i * rowStep;
    if (i % 2 == 0) {
      fill(30, 41, 59, 140);
      noStroke();
      rect(hudX + 8 * uiScale, ry - rowStep * 0.42, hudW - 16 * uiScale, rowStep * 0.88, 4 * uiScale);
    }
    fill(148, 163, 184);
    textAlign(LEFT, CENTER);
    textSize(11 * uiScale);
    text(rows[i][0], hudX + 14 * uiScale, ry);

    fill(i == rows.length - 1 ? COL_ACCENT_GREEN : color(248, 250, 252));
    textAlign(RIGHT, CENTER);
    textSize(11.5 * uiScale);
    text(rows[i][1], hudX + hudW - 14 * uiScale, ry);
  }

  // Bottom Mean Result Banner in HUD
  float resY = hudY + hudH - 34 * uiScale;
  fill(20, 83, 45);
  stroke(COL_ACCENT_GREEN);
  strokeWeight(1);
  rect(hudX + 8 * uiScale, resY, hudW - 16 * uiScale, 26 * uiScale, 5 * uiScale);
  fill(187, 247, 208);
  textAlign(CENTER, CENTER);
  textSize(11.5 * uiScale);
  text("Mean Friction Factor: f = " + nf(meanFrictionFactor, 0, 4), hudX + hudW * 0.5, resY + 13 * uiScale);
}

// ============================================================================
// SCREEN 2: 2D TRANSPARENT CUTAWAY & INTERACTIVE FLUID MECHANICS
// ============================================================================
float getCutawayPipeX() { return 65 * uiScale; }
float getCutawayPipeY() { return getTopBarH() + 145 * uiScale; }
float getCutawayPipeW() { return width - 130 * uiScale; }
float getCutawayPipeH() { return 155 * uiScale; }

void drawScreen2_CutawayPhysics() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;

  // Header & Control Bar
  fill(22, 33, 52);
  stroke(56, 189, 248, 140);
  strokeWeight(1.2);
  rect(14 * uiScale, topY, width - 28 * uiScale, 44 * uiScale, 7 * uiScale);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("2D PIPE CUTAWAY (d = " + nf(PIPE_D * 1000, 0, 0) + " mm, L = " + nf(PIPE_L, 0, 1) + " m) - WALL SHEAR & HEAD LOSS hf",
       26 * uiScale, topY + 22 * uiScale);

  // Mode buttons on right of header bar
  float btnW = 148 * uiScale;
  float btnH = 30 * uiScale;
  float btnY = topY + 7 * uiScale;
  drawSmallButton(width - 2 * btnW - 32 * uiScale, btnY, btnW, btnH,
    unsteadyMode ? "Mode: UNSTEADY" : "Mode: STEADY",
    unsteadyMode ? color(217, 119, 6) : COL_HEADER_TEAL);
  drawSmallButton(width - btnW - 22 * uiScale, btnY, btnW, btnH,
    "Reset Trails", color(71, 85, 105));

  // Cutaway Pipe Geometry
  float px = getCutawayPipeX();
  float py = getCutawayPipeY();
  float pw = getCutawayPipeW();
  float ph = getCutawayPipeH();

  // Hydraulic Grade Line (HGL) above pipe showing linear drop hf across L
  float hf = calc_hf[selectedReading];
  float V  = calc_V[selectedReading];
  float hglY1 = topY + 62 * uiScale;
  float hfSpan = max(0.01, maxHeadLossObs - minHeadLossObs);
  float hglDrop = lerp(18 * uiScale, 52 * uiScale, constrain((hf - minHeadLossObs) / hfSpan, 0, 1));
  float hglY2 = hglY1 + hglDrop;

  float tap1X = px + pw * 0.22;
  float tap2X = px + pw * 0.78;

  // Piezometric Head Columns at Tap 1 and Tap 2
  fill(56, 189, 248, 55);
  stroke(56, 189, 248, 180);
  strokeWeight(1.5);
  rect(tap1X - 10 * uiScale, hglY1, 20 * uiScale, py - hglY1);
  rect(tap2X - 10 * uiScale, hglY2, 20 * uiScale, py - hglY2);

  // Sloped Hydraulic Grade Line (HGL)
  stroke(COL_ACCENT_GOLD);
  strokeWeight(2.5);
  line(tap1X, hglY1, tap2X, hglY2);
  stroke(248, 113, 113, 190);
  strokeWeight(1.5);
  drawDashedLine(tap1X, hglY1, tap2X + 35 * uiScale, hglY1, 6 * uiScale);

  // hf vertical drop indicator
  draw2DArrow(tap2X + 24 * uiScale, hglY1, tap2X + 24 * uiScale, hglY2, color(248, 113, 113));
  fill(254, 202, 202);
  textAlign(LEFT, CENTER);
  textSize(11.5 * uiScale);
  text("Head Loss hf = " + nf(hf, 0, 3) + " m", tap2X + 32 * uiScale, (hglY1 + hglY2) * 0.5);

  fill(COL_ACCENT_GOLD);
  textAlign(CENTER, BOTTOM);
  textSize(11 * uiScale);
  text("Hydraulic Grade Line (Slope = hf / L = " + nf(hf / PIPE_L, 0, 3) + ")",
       (tap1X + tap2X) * 0.5, hglY1 - 4 * uiScale);

  // Pipe Interior Fluid Domain
  noStroke();
  fill(12, 42, 74);
  rect(px, py, pw, ph);

  // Pipe Walls (Top & Bottom)
  fill(100, 116, 139);
  stroke(203, 213, 225);
  strokeWeight(1.5);
  rect(px, py - 14 * uiScale, pw, 14 * uiScale);
  rect(px, py + ph, pw, 14 * uiScale);

  // Roughness teeth along inner wall
  stroke(148, 163, 184);
  strokeWeight(1);
  for (float rx = px + 8 * uiScale; rx < px + pw - 8 * uiScale; rx += 12 * uiScale) {
    line(rx, py, rx + 5 * uiScale, py + 3 * uiScale);
    line(rx, py + ph, rx + 5 * uiScale, py + ph - 3 * uiScale);
  }

  // 3. Instantaneous Streamlines
  stroke(56, 189, 248, 65);
  strokeWeight(1);
  for (int s = 1; s <= 5; s++) {
    float streamY = py + ph * (s / 6.0);
    line(px + 6 * uiScale, streamY, px + pw - 6 * uiScale, streamY);
  }

  // 2. Cross-Section Turbulent Velocity Profile (1/7th Power Law) at X = 0.45 * pw
  float profX = px + pw * 0.45;
  stroke(250, 204, 21, 140);
  strokeWeight(1.5);
  line(profX, py, profX, py + ph);
  int numArrows = 9;
  for (int a = 1; a < numArrows; a++) {
    float frac = float(a) / numArrows;
    float rNorm = abs(frac - 0.5) * 2.0;
    float uLocal = pow(max(0.05, 1.0 - rNorm), 0.18);
    float ay = py + frac * ph;
    float arrowLen = uLocal * 95 * uiScale * (V / maxVelocityObs);
    draw2DArrow(profX, ay, profX + arrowLen, ay, COL_ACCENT_GOLD);
  }

  // 1 & 4. Moving Color-Coded Particles + Lagrangian Pathline Trails
  float pulse = unsteadyMode ? (1.0 + 0.35 * sin(frameCount * 0.12)) : 1.0;
  float baseVx = (0.0038 + 0.0045 * (V / maxVelocityObs)) * pulse;

  for (FluidParticle2D fp : cutawayParticles) {
    float pRNorm = abs(fp.ny - 0.5) * 2.0;
    float profileMult = pow(max(0.12, 1.0 - pRNorm), 0.18);
    float vx = baseVx * profileMult;
    float vy = unsteadyMode ? 0.002 * sin(frameCount * 0.15 + fp.nx * 14.0) : 0.0;

    fp.nx += vx;
    fp.ny = constrain(fp.ny + vy, 0.06, 0.94);

    if (fp.nx > 1.0) {
      fp.nx = 0.0;
      fp.ny = random(0.08, 0.92);
      fp.trail.clear();
    }

    float sx = px + fp.nx * pw;
    float sy = py + fp.ny * ph;
    fp.trail.add(new PVector(sx, sy));
    if (fp.trail.size() > 14) fp.trail.remove(0);

    noFill();
    stroke(56, 189, 248, 90);
    strokeWeight(1.2);
    beginShape();
    for (PVector tv : fp.trail) vertex(tv.x, tv.y);
    endShape();

    noStroke();
    fill(lerpColor(COL_ACCENT_CYAN, COL_ACCENT_GOLD, profileMult));
    ellipse(sx, sy, 5.5 * uiScale, 5.5 * uiScale);
  }

  // 5. Interactive Tracer/Dye Nozzle & Streakline
  float nozSx = px + dyeNozzleX * pw;
  float nozSy = py + dyeNozzleY * ph;

  float rNormNoz = abs(dyeNozzleY - 0.5) * 2.0;
  float uNoz = baseVx * pow(max(0.15, 1.0 - rNormNoz), 0.18);
  streakPoints.add(0, new PVector(nozSx, nozSy));
  for (int i = streakPoints.size() - 1; i >= 0; i--) {
    PVector sp = streakPoints.get(i);
    sp.x += uNoz * pw;
    if (unsteadyMode) {
      sp.y += sin(frameCount * 0.16 - i * 0.25) * 1.4 * uiScale;
    }
    if (sp.x > px + pw) streakPoints.remove(i);
  }

  noFill();
  stroke(COL_ACCENT_RED);
  strokeWeight(3.0 * uiScale);
  beginShape();
  for (PVector sp : streakPoints) vertex(sp.x, sp.y);
  endShape();

  fill(COL_ACCENT_RED);
  stroke(255);
  strokeWeight(1.5);
  ellipse(nozSx, nozSy, 13 * uiScale, 13 * uiScale);
  fill(255);
  textAlign(LEFT, BOTTOM);
  textSize(10.5 * uiScale);
  text("Dye Nozzle (Tap pipe to move)", nozSx + 8 * uiScale, nozSy - 6 * uiScale);

  // Dimension L bracket below pipe
  float dimY = py + ph + 28 * uiScale;
  stroke(148, 163, 184);
  strokeWeight(1.5);
  line(tap1X, py + ph + 14 * uiScale, tap1X, dimY + 5 * uiScale);
  line(tap2X, py + ph + 14 * uiScale, tap2X, dimY + 5 * uiScale);
  draw2DArrow(tap1X, dimY, tap2X, dimY, color(148, 163, 184));
  draw2DArrow(tap2X, dimY, tap1X, dimY, color(148, 163, 184));
  fill(226, 232, 240);
  textAlign(CENTER, BOTTOM);
  textSize(11.5 * uiScale);
  text("Distance Between Pressure Tapping Cocks L = " + nf(PIPE_L, 0, 1) + " m",
       (tap1X + tap2X) * 0.5, dimY - 3 * uiScale);

  // Bottom Quantitative Physics & U-Tube Manometer Summary Cards
  float cardTop = dimY + 14 * uiScale;
  float cardH = botY - cardTop;
  float cardW = (width - 42 * uiScale) / 3.0;

  drawCutawayInfoCard(14 * uiScale, cardTop, cardW, cardH,
    "SECTION 1 vs SECTION 2 (CONTINUITY)",
    new String[] {
      "Pipe Diameter: d1 = d2 = " + nf(PIPE_D * 1000, 0, 0) + " mm (" + nf(PIPE_D, 0, 3) + " m)",
      "Mean Velocity: V1 = V2 = " + nf(V, 0, 3) + " m/s",
      "Discharge: Q = " + nf(calc_Q[selectedReading] * 10000.0, 0, 2) + " x10^-4 m^3/s",
      "Pressure Drop: dP = rho*g*hf = " + nf(1000 * SG_FLOW * G_ACC * hf / 1000.0, 0, 2) + " kPa"
    });

  drawCutawayInfoCard(21 * uiScale + cardW, cardTop, cardW, cardH,
    "DIFFERENTIAL U-TUBE MANOMETER",
    new String[] {
      "Left Limb (h1): " + nf(obs_h1[selectedReading], 0, 1) + " cm",
      "Right Limb (h2): " + nf(obs_h2[selectedReading], 0, 1) + " cm",
      "Manometer Diff (h): " + nf(calc_h[selectedReading], 0, 3) + " m",
      "Head Loss (hf = " + nf(SG_FACTOR, 0, 1) + "h): " + nf(hf, 0, 3) + " m"
    });

  drawCutawayInfoCard(28 * uiScale + 2 * cardW, cardTop, cardW, cardH,
    "DARCY FRICTION & FLOW LEGEND",
    new String[] {
      "Friction Factor f = " + nf(calc_f[selectedReading], 0, 4) + " (Mean: " + nf(meanFrictionFactor, 0, 4) + ")",
      "Gold Arrows: Turbulent 1/7th Velocity Profile",
      "Red Line: Streakline | Blue Trails: Pathlines",
      "Tap inside pipe to reposition dye injector"
    });
}

void drawCutawayInfoCard(float x, float y, float w, float h, String title, String[] lines) {
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.2);
  rect(x, y, w, h, 7 * uiScale);

  fill(COL_HEADER_BLUE);
  noStroke();
  rect(x, y, w, 26 * uiScale, 7 * uiScale, 7 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(11 * uiScale);
  text(title, x + 10 * uiScale, y + 13 * uiScale);

  float stepY = (h - 32 * uiScale) / lines.length;
  for (int i = 0; i < lines.length; i++) {
    fill(i == 0 ? color(125, 211, 252) : color(226, 232, 240));
    textAlign(LEFT, CENTER);
    textSize(11 * uiScale);
    text(lines[i], x + 10 * uiScale, y + 32 * uiScale + (i + 0.5) * stepY);
  }
}

// ============================================================================
// SCREEN 3: MATHEMATICAL DERIVATION (56% LEFT STEPS / 44% RIGHT SCHEMATIC)
// ============================================================================
void drawScreen3_Derivation() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;

  float leftW = (width - 36 * uiScale) * 0.56;
  float rightW = (width - 36 * uiScale) * 0.44;
  float leftX = 14 * uiScale;
  float rightX = leftX + leftW + 8 * uiScale;

  // --- LEFT PANEL: 7-STEP DERIVATION ---
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  rect(leftX, topY, leftW, totalH, 8 * uiScale);

  fill(COL_HEADER_BLUE);
  noStroke();
  rect(leftX, topY, leftW, 38 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("DARCY-WEISBACH FORMULA DERIVATION (7 STEPS)", leftX + 12 * uiScale, topY + 19 * uiScale);

  float ctrlW = 92 * uiScale;
  float ctrlH = 26 * uiScale;
  float ctrlY = topY + 6 * uiScale;
  drawSmallButton(leftX + leftW - 3 * ctrlW - 22 * uiScale, ctrlY, ctrlW * 0.9, ctrlH,
    "< Prev", color(51, 65, 85));
  drawSmallButton(leftX + leftW - 2 * ctrlW - 16 * uiScale, ctrlY, ctrlW * 0.9, ctrlH,
    "Next >", color(37, 99, 235));
  drawSmallButton(leftX + leftW - ctrlW - 10 * uiScale, ctrlY, ctrlW, ctrlH,
    autoDerive ? "Auto: ON" : "Auto: OFF",
    autoDerive ? color(22, 163, 74) : color(71, 85, 105));

  float listStartY = topY + 46 * uiScale;
  float stepH = (totalH - 54 * uiScale) / derivTitles.length;

  for (int i = 0; i < derivTitles.length; i++) {
    float sy = listStartY + i * stepH;
    boolean active = (i == derivStep);

    if (active) {
      fill(30, 58, 138, 220);
      stroke(COL_ACCENT_GOLD);
      strokeWeight(1.8);
    } else {
      fill(26, 36, 56);
      stroke(45, 60, 85);
      strokeWeight(1);
    }
    rect(leftX + 34 * uiScale, sy + 2 * uiScale, leftW - 44 * uiScale, stepH - 5 * uiScale, 6 * uiScale);

    if (active) {
      float pulseX = sin(frameCount * 0.15) * 4 * uiScale;
      draw2DArrow(leftX + 6 * uiScale + pulseX, sy + stepH * 0.5,
                  leftX + 30 * uiScale + pulseX, sy + stepH * 0.5, COL_ACCENT_GOLD);
    }

    fill(active ? COL_ACCENT_GOLD : color(148, 163, 184));
    textAlign(LEFT, TOP);
    textSize(10.5 * uiScale);
    text(derivTitles[i], leftX + 42 * uiScale, sy + 5 * uiScale);

    fill(active ? color(255) : color(203, 213, 225));
    textSize(12 * uiScale);
    text(derivFormulas[i], leftX + 42 * uiScale, sy + 21 * uiScale);

    fill(active ? color(186, 230, 253) : color(120, 135, 155));
    textSize(10 * uiScale);
    text(derivNotes[i], leftX + 42 * uiScale, sy + 39 * uiScale);
  }

  // --- RIGHT PANEL: CONTROL VOLUME & ENERGY GRADE LINE SCHEMATIC ---
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  rect(rightX, topY, rightW, totalH, 8 * uiScale);

  fill(COL_HEADER_TEAL);
  noStroke();
  rect(rightX, topY, rightW, 38 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("CONTROL VOLUME & ENERGY LINE SCHEMATIC", rightX + 12 * uiScale, topY + 19 * uiScale);

  float diagX = rightX + 36 * uiScale;
  float diagW = rightW - 72 * uiScale;
  float eglY1 = topY + 72 * uiScale;
  float hf = calc_hf[selectedReading];
  float V  = calc_V[selectedReading];
  float hfSpan = max(0.01, maxHeadLossObs - minHeadLossObs);
  float drop = lerp(24 * uiScale, 55 * uiScale, constrain((hf - minHeadLossObs) / hfSpan, 0, 1));
  float eglY2 = eglY1 + drop;
  float velHeadH = 26 * uiScale;
  float hglY1 = eglY1 + velHeadH;
  float hglY2 = eglY2 + velHeadH;
  float pipeTopY = hglY2 + 32 * uiScale;
  float pipeH = 44 * uiScale;

  // EGL Line (Red)
  stroke(248, 113, 113);
  strokeWeight(2.2);
  line(diagX, eglY1, diagX + diagW, eglY2);
  drawDashedLine(diagX, eglY1, diagX + diagW, eglY1, 5 * uiScale);

  // HGL Line (Cyan)
  stroke(COL_ACCENT_CYAN);
  strokeWeight(2.2);
  line(diagX, hglY1, diagX + diagW, hglY2);

  fill(248, 113, 113);
  textAlign(LEFT, BOTTOM);
  textSize(10.5 * uiScale);
  text("EGL (Total Head)", diagX, eglY1 - 3 * uiScale);
  text("hf = " + nf(hf, 0, 3) + " m", diagX + diagW - 68 * uiScale, (eglY1 + eglY2) * 0.5);

  fill(COL_ACCENT_CYAN);
  textAlign(LEFT, BOTTOM);
  text("HGL (P/rho*g + Z)", diagX + 6 * uiScale, hglY1 - 2 * uiScale);

  stroke(148, 163, 184, 150);
  strokeWeight(1.2);
  line(diagX, eglY1, diagX, pipeTopY + pipeH);
  line(diagX + diagW, eglY2, diagX + diagW, pipeTopY + pipeH);

  // Pipe Control Volume Box
  fill(30, 58, 138, 150);
  stroke(147, 197, 253);
  strokeWeight(1.8);
  rect(diagX, pipeTopY, diagW, pipeH);

  // Wall shear stress arrows opposing flow
  draw2DArrow(diagX + diagW * 0.65, pipeTopY + 7 * uiScale,
              diagX + diagW * 0.35, pipeTopY + 7 * uiScale, color(251, 146, 60));
  draw2DArrow(diagX + diagW * 0.65, pipeTopY + pipeH - 7 * uiScale,
              diagX + diagW * 0.35, pipeTopY + pipeH - 7 * uiScale, color(251, 146, 60));
  fill(253, 186, 116);
  textAlign(CENTER, CENTER);
  textSize(10 * uiScale);
  text("Wall Shear tau_w  <--  Flow V = " + nf(V, 0, 3) + " m/s -->",
       diagX + diagW * 0.5, pipeTopY + pipeH * 0.5);

  // Datum Z1 = Z2 line
  float datumY = pipeTopY + pipeH + 22 * uiScale;
  stroke(COL_ACCENT_GREEN);
  strokeWeight(1.5);
  line(diagX - 10 * uiScale, datumY, diagX + diagW + 10 * uiScale, datumY);
  fill(COL_ACCENT_GREEN);
  textAlign(CENTER, TOP);
  textSize(10.5 * uiScale);
  text("Datum Line: Z1 = Z2 (Horizontal Pipe, L = " + nf(PIPE_L, 0, 1) + " m, d = " + nf(PIPE_D, 0, 3) + " m)",
       diagX + diagW * 0.5, datumY + 4 * uiScale);

  // Live Numerical Substitution Box for Active Reading
  float subY = datumY + 30 * uiScale;
  float subH = 118 * uiScale;
  fill(15, 23, 42);
  stroke(71, 85, 105);
  strokeWeight(1.2);
  rect(rightX + 12 * uiScale, subY, rightW - 24 * uiScale, subH, 6 * uiScale);

  fill(COL_ACCENT_GOLD);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text("LIVE SUBSTITUTION (READING R" + (selectedReading + 1) + "):",
       rightX + 20 * uiScale, subY + 8 * uiScale);

  fill(226, 232, 240);
  textSize(11 * uiScale);
  text("1. h = (" + nf(obs_h1[selectedReading], 0, 1) + " - " + nf(obs_h2[selectedReading], 0, 1) +
       ") / 100 = " + nf(calc_h[selectedReading], 0, 3) + " m",
       rightX + 20 * uiScale, subY + 30 * uiScale);
  text("2. hf = " + nf(calc_h[selectedReading], 0, 3) + " x " + nf(SG_FACTOR, 0, 1) + " = " + nf(hf, 0, 3) + " m",
       rightX + 20 * uiScale, subY + 50 * uiScale);
  text("3. V = Q / a = " + nf(V, 0, 3) + " m/s  ==>  V^2 = " + nf(calc_V2[selectedReading], 0, 3) + " m^2/s^2",
       rightX + 20 * uiScale, subY + 70 * uiScale);
  fill(COL_ACCENT_GREEN);
  text("4. f = (" + nf(hf, 0, 3) + " x 2 x " + nf(G_ACC, 0, 2) + " x " + nf(PIPE_D, 0, 3) +
       ") / (" + nf(PIPE_L, 0, 1) + " x " + nf(calc_V2[selectedReading], 0, 3) + ") = " + nf(calc_f[selectedReading], 0, 4),
       rightX + 20 * uiScale, subY + 90 * uiScale);

  // Highlighted Final Derived Equation Box at Bottom
  float finY = subY + subH + 10 * uiScale;
  float finH = botY - finY - 10 * uiScale;
  fill(20, 83, 45);
  stroke(COL_ACCENT_GREEN);
  strokeWeight(2);
  rect(rightX + 12 * uiScale, finY, rightW - 24 * uiScale, max(44 * uiScale, finH), 7 * uiScale);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(13.5 * uiScale);
  text("FINAL WORKING EQUATION:   f = (hf * 2 * g * d) / (L * V^2)",
       rightX + rightW * 0.5, finY + max(44 * uiScale, finH) * 0.5);
}

// ============================================================================
// SCREEN 4: EXPERIMENTAL LAB PROCEDURE & DUAL ZOOMED INSTRUMENTS
// ============================================================================
void drawScreen4_Procedure() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;

  float leftW = (width - 36 * uiScale) * 0.48;
  float rightW = (width - 36 * uiScale) * 0.52;
  float leftX = 14 * uiScale;
  float rightX = leftX + leftW + 8 * uiScale;

  // --- LEFT PANEL: 6-STEP LAB PROCEDURE ---
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  rect(leftX, topY, leftW, totalH, 8 * uiScale);

  fill(COL_HEADER_BLUE);
  noStroke();
  rect(leftX, topY, leftW, 38 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("LAB PROCEDURE: HOW READINGS ARE TAKEN", leftX + 12 * uiScale, topY + 19 * uiScale);

  drawSmallButton(leftX + leftW - 118 * uiScale, topY + 6 * uiScale, 108 * uiScale, 26 * uiScale,
    autoProc ? "Auto-Demo: ON" : "Auto-Demo: OFF",
    autoProc ? color(22, 163, 74) : color(71, 85, 105));

  float listY = topY + 46 * uiScale;
  float stepH = (totalH - 54 * uiScale) / procTitles.length;

  for (int i = 0; i < procTitles.length; i++) {
    float sy = listY + i * stepH;
    boolean active = (i == procStep);

    fill(active ? color(30, 58, 138, 225) : color(26, 36, 56));
    stroke(active ? COL_ACCENT_GOLD : color(45, 60, 85));
    strokeWeight(active ? 1.8 : 1.0);
    rect(leftX + 34 * uiScale, sy + 2 * uiScale, leftW - 44 * uiScale, stepH - 6 * uiScale, 6 * uiScale);

    if (active) {
      float bounce = sin(frameCount * 0.15) * 4 * uiScale;
      draw2DArrow(leftX + 6 * uiScale + bounce, sy + stepH * 0.5,
                  leftX + 30 * uiScale + bounce, sy + stepH * 0.5, COL_ACCENT_GOLD);
    }

    fill(active ? COL_ACCENT_GOLD : color(125, 211, 252));
    textAlign(LEFT, TOP);
    textSize(11.5 * uiScale);
    text(procTitles[i], leftX + 42 * uiScale, sy + 7 * uiScale);

    fill(active ? color(255) : color(203, 213, 225));
    textSize(10.5 * uiScale);
    text(procDetails[i], leftX + 42 * uiScale, sy + 26 * uiScale, leftW - 60 * uiScale, stepH - 30 * uiScale);
  }

  // --- RIGHT PANEL: TWO ZOOMED MEASUREMENT INSTRUMENT CARDS ---
  float cardH = (totalH - 10 * uiScale) * 0.5;
  drawZoomedManometerCard(rightX, topY, rightW, cardH);
  drawZoomedTankStopwatchCard(rightX, topY + cardH + 10 * uiScale, rightW, cardH);
}

void drawZoomedManometerCard(float x, float y, float w, float h) {
  fill(COL_PANEL_BG);
  stroke(procStep == 3 ? COL_ACCENT_GOLD : COL_ACCENT_CYAN);
  strokeWeight(procStep == 3 ? 2.0 : 1.3);
  rect(x, y, w, h, 8 * uiScale);

  fill(COL_HEADER_TEAL);
  noStroke();
  rect(x, y, w, 30 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12 * uiScale);
  text("INSTRUMENT 1: ZOOMED DIFFERENTIAL U-TUBE MANOMETER (R" + (selectedReading + 1) + ")",
       x + 12 * uiScale, y + 15 * uiScale);

  float h1 = obs_h1[selectedReading];
  float h2 = obs_h2[selectedReading];
  float hM = calc_h[selectedReading];
  float hf = calc_hf[selectedReading];

  // Auto-fit scale ticks around observed h1/h2 values
  int scaleMin = floor(min(h1, h2) - 2);
  int scaleMax = ceil(max(h1, h2) + 2);
  if (scaleMax - scaleMin < 8) scaleMax = scaleMin + 8;

  float tubeCenterX = x + 125 * uiScale;
  float tubeTopY = y + 46 * uiScale;
  float tubeBotY = y + h - 24 * uiScale;
  float tubeH = tubeBotY - tubeTopY;
  float limbOffset = 34 * uiScale;

  fill(241, 245, 249);
  noStroke();
  rect(tubeCenterX - 18 * uiScale, tubeTopY, 36 * uiScale, tubeH - 16 * uiScale, 3 * uiScale);

  stroke(30, 41, 59);
  strokeWeight(1);
  fill(15, 23, 42);
  textAlign(CENTER, CENTER);
  textSize(8.5 * uiScale);
  for (int cm = scaleMin; cm <= scaleMax; cm++) {
    float ty = map(cm, scaleMax, scaleMin, tubeTopY + 10 * uiScale, tubeBotY - 26 * uiScale);
    line(tubeCenterX - 18 * uiScale, ty, tubeCenterX - 10 * uiScale, ty);
    line(tubeCenterX + 10 * uiScale, ty, tubeCenterX + 18 * uiScale, ty);
    if ((cm - scaleMin) % 2 == 0) {
      text(cm + "", tubeCenterX, ty);
    }
  }

  // Left & Right Glass Limbs
  stroke(148, 163, 184);
  strokeWeight(2);
  noFill();
  rect(tubeCenterX - limbOffset - 8 * uiScale, tubeTopY, 16 * uiScale, tubeH - 16 * uiScale);
  rect(tubeCenterX + limbOffset - 8 * uiScale, tubeTopY, 16 * uiScale, tubeH - 16 * uiScale);
  arc(tubeCenterX, tubeBotY - 16 * uiScale, limbOffset * 2 + 16 * uiScale, 32 * uiScale, 0, PI);

  float y_h1 = map(h1, scaleMax, scaleMin, tubeTopY + 10 * uiScale, tubeBotY - 26 * uiScale);
  float y_h2 = map(h2, scaleMax, scaleMin, tubeTopY + 10 * uiScale, tubeBotY - 26 * uiScale);

  noStroke();
  fill(203, 213, 225);
  rect(tubeCenterX - limbOffset - 6 * uiScale, y_h1, 12 * uiScale, (tubeBotY - 16 * uiScale) - y_h1);
  rect(tubeCenterX + limbOffset - 6 * uiScale, y_h2, 12 * uiScale, (tubeBotY - 16 * uiScale) - y_h2);
  arc(tubeCenterX, tubeBotY - 16 * uiScale, limbOffset * 2 + 12 * uiScale, 28 * uiScale, 0, PI);

  stroke(COL_ACCENT_RED);
  strokeWeight(1.8);
  line(tubeCenterX - limbOffset - 16 * uiScale, y_h1, tubeCenterX + limbOffset + 16 * uiScale, y_h1);
  stroke(COL_ACCENT_GREEN);
  line(tubeCenterX - limbOffset - 16 * uiScale, y_h2, tubeCenterX + limbOffset + 16 * uiScale, y_h2);

  // Readout Callout Box on Right Half of Card
  float infoX = x + 230 * uiScale;
  float infoW = w - 244 * uiScale;
  float infoY = y + 44 * uiScale;

  fill(15, 23, 42);
  stroke(71, 85, 105);
  strokeWeight(1);
  rect(infoX, infoY, infoW, h - 56 * uiScale, 6 * uiScale);

  fill(COL_ACCENT_RED);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text("Left Limb Reading (h1): " + nf(h1, 0, 1) + " cm", infoX + 12 * uiScale, infoY + 10 * uiScale);

  fill(COL_ACCENT_GREEN);
  text("Right Limb Reading (h2): " + nf(h2, 0, 1) + " cm", infoX + 12 * uiScale, infoY + 34 * uiScale);

  fill(COL_ACCENT_GOLD);
  text("Diff Head h = (h1 - h2)/100 = " + nf(hM, 0, 3) + " m", infoX + 12 * uiScale, infoY + 60 * uiScale);

  fill(125, 211, 252);
  text("Equivalent Water Head Loss:", infoX + 12 * uiScale, infoY + 86 * uiScale);
  fill(255);
  textSize(12.5 * uiScale);
  text("hf = h x (" + nf(SG_MANO, 0, 1) + " - 1) = " + nf(hf, 0, 3) + " m", infoX + 12 * uiScale, infoY + 106 * uiScale);
}

void drawZoomedTankStopwatchCard(float x, float y, float w, float h) {
  fill(COL_PANEL_BG);
  stroke(procStep == 4 ? COL_ACCENT_GOLD : COL_ACCENT_CYAN);
  strokeWeight(procStep == 4 ? 2.0 : 1.3);
  rect(x, y, w, h, 8 * uiScale);

  fill(22, 101, 52);
  noStroke();
  rect(x, y, w, 30 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12 * uiScale);
  text("INSTRUMENT 2: COLLECTING TANK (" + nf(TANK_L, 0, 1) + "m x " + nf(TANK_B, 0, 1) + "m) & STOPWATCH",
       x + 12 * uiScale, y + 15 * uiScale);

  float targetT = obs_T[selectedReading];
  float frac = constrain(stopwatchAnim / max(0.1, targetT), 0, 1);

  float tkX = x + 28 * uiScale;
  float tkY = y + 46 * uiScale;
  float tkW = 145 * uiScale;
  float tkH = h - 62 * uiScale;

  fill(15, 23, 42);
  stroke(148, 163, 184);
  strokeWeight(2);
  rect(tkX, tkY, tkW, tkH);

  float baseLineY = tkY + tkH * 0.78;
  float topMarkY  = tkY + tkH * 0.25;
  float curWaterY = lerp(baseLineY, topMarkY, frac);

  noStroke();
  fill(14, 165, 233, 190);
  rect(tkX + 2, curWaterY, tkW - 4, (tkY + tkH) - curWaterY - 2);

  stroke(COL_ACCENT_GOLD);
  strokeWeight(1.5);
  line(tkX - 6 * uiScale, baseLineY, tkX + tkW + 6 * uiScale, baseLineY);
  line(tkX - 6 * uiScale, topMarkY, tkX + tkW + 6 * uiScale, topMarkY);

  fill(COL_ACCENT_GOLD);
  textAlign(LEFT, CENTER);
  textSize(9.5 * uiScale);
  text(nf(TANK_RISE, 0, 2) + "m", tkX + tkW + 8 * uiScale, topMarkY);
  text("0.00m", tkX + tkW + 8 * uiScale, baseLineY);

  float swX = x + 230 * uiScale;
  float swW = w - 244 * uiScale;
  float swY = y + 44 * uiScale;

  fill(15, 23, 42);
  stroke(71, 85, 105);
  strokeWeight(1);
  rect(swX, swY, swW, h - 56 * uiScale, 6 * uiScale);

  fill(20, 35, 25);
  stroke(COL_ACCENT_GREEN);
  strokeWeight(1.5);
  rect(swX + 12 * uiScale, swY + 10 * uiScale, swW - 24 * uiScale, 36 * uiScale, 5 * uiScale);
  fill(COL_ACCENT_GREEN);
  textAlign(CENTER, CENTER);
  textSize(14 * uiScale);
  text("TIMER: " + nf(stopwatchAnim, 0, 1) + " s  /  Target T = " + nf(targetT, 0, 0) + " s",
       swX + swW * 0.5, swY + 28 * uiScale);

  float volCollected = TANK_AREA * TANK_RISE;
  fill(226, 232, 240);
  textAlign(LEFT, TOP);
  textSize(11 * uiScale);
  text("Tank Plan Area A_T = " + nf(TANK_L, 0, 2) + " x " + nf(TANK_B, 0, 2) + " = " + nf(TANK_AREA, 0, 2) + " m^2",
       swX + 12 * uiScale, swY + 54 * uiScale);
  text("Volume Collected Vol = " + nf(TANK_AREA, 0, 2) + " x " + nf(TANK_RISE, 0, 2) + " = " + nf(volCollected, 0, 3) + " m^3",
       swX + 12 * uiScale, swY + 74 * uiScale);
  fill(125, 211, 252);
  text("Discharge Q = " + nf(volCollected, 0, 3) + " / " + nf(targetT, 0, 0) + " = " +
       nf(calc_Q[selectedReading] * 10000.0, 0, 2) + " x10^-4 m^3/s",
       swX + 12 * uiScale, swY + 96 * uiScale);
}

// ============================================================================
// SCREEN 5: BODMAS STEP-BY-STEP & COMPLETE 47-KEY CASIO FX-991MS CALCULATOR
// ============================================================================
void drawScreen5_CasioCalc() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;

  float leftW = (width - 36 * uiScale) * 0.53;
  float rightW = (width - 36 * uiScale) * 0.47;
  float leftX = 14 * uiScale;
  float rightX = leftX + leftW + 8 * uiScale;

  // --- LEFT PANEL: 8-STEP BODMAS BREAKDOWN ---
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  rect(leftX, topY, leftW, totalH, 8 * uiScale);

  fill(COL_HEADER_BLUE);
  noStroke();
  rect(leftX, topY, leftW, 38 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("BODMAS STEP-BY-STEP (READING R" + (selectedReading + 1) + ")", leftX + 12 * uiScale, topY + 19 * uiScale);

  drawSmallButton(leftX + leftW - 108 * uiScale, topY + 6 * uiScale, 98 * uiScale, 26 * uiScale,
    autoBodmas ? "Auto: ON" : "Auto: OFF",
    autoBodmas ? color(22, 163, 74) : color(71, 85, 105));

  String[] bodmasLetters = { "B", "O", "D", "M", "A", "S" };
  String[] bodmasLabels  = { "Brackets", "Orders (^2)", "Division", "Multiply", "Addition", "Subtract" };
  int[] stepToBodmas     = { 0, 3, 2, 2, 1, 3, 3, 2 };

  float badgeBarY = topY + 44 * uiScale;
  float badgeW = (leftW - 24 * uiScale) / 6.0;
  for (int b = 0; b < 6; b++) {
    float bx = leftX + 12 * uiScale + b * badgeW;
    boolean isCurB = (stepToBodmas[bodmasStep] == b);
    fill(isCurB ? color(234, 88, 12) : color(30, 41, 59));
    stroke(isCurB ? color(253, 186, 116) : color(71, 85, 105));
    strokeWeight(1.2);
    rect(bx + 2 * uiScale, badgeBarY, badgeW - 4 * uiScale, 30 * uiScale, 5 * uiScale);

    fill(255);
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text(bodmasLetters[b] + " - " + bodmasLabels[b], bx + badgeW * 0.5, badgeBarY + 15 * uiScale);
  }

  float h1 = obs_h1[selectedReading];
  float h2 = obs_h2[selectedReading];
  float hM = calc_h[selectedReading];
  float hf = calc_hf[selectedReading];
  float T  = obs_T[selectedReading];
  float Q  = calc_Q[selectedReading];
  float V  = calc_V[selectedReading];
  float V2 = calc_V2[selectedReading];
  float num = hf * 2.0 * G_ACC * PIPE_D;
  float den = PIPE_L * V2;
  float f   = calc_f[selectedReading];

  String[] bSteps = {
    "1. [B] Manometer Diff: h = (" + nf(h1, 0, 1) + " - " + nf(h2, 0, 1) + ") / 100 = " + nf(hM, 0, 3) + " m",
    "2. [M] Water Head Loss: hf = " + nf(hM, 0, 3) + " x " + nf(SG_FACTOR, 0, 1) + " = " + nf(hf, 0, 3) + " m",
    "3. [D] Discharge: Q = (" + nf(TANK_AREA, 0, 2) + " x " + nf(TANK_RISE, 0, 2) + ") / " + nf(T, 0, 0) + " = " + nf(Q * 10000.0, 0, 2) + " x10^-4 m^3/s",
    "4. [D] Flow Velocity: V = Q / (" + nf(PIPE_A * 10000, 0, 4) + " x 10^-4) = " + nf(V, 0, 3) + " m/s",
    "5. [O] Velocity Squared: V^2 = (" + nf(V, 0, 3) + ")^2 = " + nf(V2, 0, 3) + " m^2/s^2",
    "6. [M] Numerator: hf x 2 x g x d = " + nf(hf, 0, 3) + " x 2 x " + nf(G_ACC, 0, 2) + " x " + nf(PIPE_D, 0, 3) + " = " + nf(num, 0, 4),
    "7. [M] Denominator: L x V^2 = " + nf(PIPE_L, 0, 1) + " x " + nf(V2, 0, 3) + " = " + nf(den, 0, 3),
    "8. [D] Friction Factor: f = " + nf(num, 0, 4) + " / " + nf(den, 0, 3) + " = " + nf(f, 0, 4)
  };

  float rowsStartY = badgeBarY + 36 * uiScale;
  float rowH = (totalH - 90 * uiScale) / 8.0;

  for (int i = 0; i < 8; i++) {
    float ry = rowsStartY + i * rowH;
    boolean active = (i == bodmasStep);

    fill(active ? color(30, 58, 138, 225) : color(26, 36, 56));
    stroke(active ? COL_ACCENT_GOLD : color(45, 60, 85));
    strokeWeight(active ? 1.8 : 1.0);
    rect(leftX + 32 * uiScale, ry + 2 * uiScale, leftW - 42 * uiScale, rowH - 4 * uiScale, 5 * uiScale);

    if (active) {
      float bounce = sin(frameCount * 0.16) * 4 * uiScale;
      draw2DArrow(leftX + 6 * uiScale + bounce, ry + rowH * 0.5,
                  leftX + 28 * uiScale + bounce, ry + rowH * 0.5, COL_ACCENT_GOLD);
    }

    fill(active ? color(255) : color(203, 213, 225));
    textAlign(LEFT, CENTER);
    textSize(11 * uiScale);
    text(bSteps[i], leftX + 40 * uiScale, ry + rowH * 0.5);
  }

  // --- RIGHT PANEL: AUTHENTIC 47-KEY CASIO FX-991MS S-V.P.A.M. ---
  drawCasioFX991MS(rightX, topY, rightW, totalH);
}

void drawCasioFX991MS(float x, float y, float w, float h) {
  fill(35, 44, 62);
  stroke(100, 116, 139);
  strokeWeight(2);
  rect(x, y, w, h, 14 * uiScale);

  fill(48, 59, 82);
  noStroke();
  rect(x + 10 * uiScale, y + 8 * uiScale, w - 20 * uiScale, 112 * uiScale, 8 * uiScale);

  fill(241, 245, 249);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("CASIO", x + 18 * uiScale, y + 20 * uiScale);

  fill(147, 197, 253);
  textSize(11 * uiScale);
  text("fx-991MS", x + 72 * uiScale, y + 20 * uiScale);

  fill(253, 186, 116);
  textSize(9.5 * uiScale);
  text("S-V.P.A.M.", x + 135 * uiScale, y + 20 * uiScale);

  // 4-Cell Solar Panel
  float solW = 78 * uiScale;
  float solH = 18 * uiScale;
  float solX = x + w - solW - 18 * uiScale;
  float solY = y + 11 * uiScale;
  fill(68, 44, 34);
  stroke(148, 163, 184);
  strokeWeight(1);
  rect(solX, solY, solW, solH, 3 * uiScale);
  for (int sc = 1; sc < 4; sc++) {
    line(solX + sc * (solW / 4.0), solY, solX + sc * (solW / 4.0), solY + solH);
  }

  // 2-Line LCD Screen
  float lcdX = x + 18 * uiScale;
  float lcdY = y + 34 * uiScale;
  float lcdW = w - 36 * uiScale;
  float lcdH = 54 * uiScale;
  fill(175, 196, 172);
  stroke(30, 41, 59);
  strokeWeight(2);
  rect(lcdX, lcdY, lcdW, lcdH, 4 * uiScale);

  fill(20, 35, 25);
  textAlign(LEFT, TOP);
  textSize(8.5 * uiScale);
  text("D   SCI   FIX", lcdX + 6 * uiScale, lcdY + 3 * uiScale);

  String[] lcdExprs = {
    "(" + nf(obs_h1[selectedReading], 0, 1) + "-" + nf(obs_h2[selectedReading], 0, 1) + ")/100",
    nf(calc_h[selectedReading], 0, 3) + " x " + nf(SG_FACTOR, 0, 1),
    "(" + nf(TANK_AREA, 0, 2) + "x" + nf(TANK_RISE, 0, 2) + ")/" + nf(obs_T[selectedReading], 0, 0),
    nf(calc_Q[selectedReading], 0, 6) + " / " + nf(PIPE_A, 0, 6),
    nf(calc_V[selectedReading], 0, 3) + "^2",
    nf(calc_hf[selectedReading], 0, 3) + "x2x" + nf(G_ACC, 0, 2) + "x" + nf(PIPE_D, 0, 3),
    nf(PIPE_L, 0, 1) + " x " + nf(calc_V2[selectedReading], 0, 3),
    nf(calc_hf[selectedReading] * 2 * G_ACC * PIPE_D, 0, 4) + " / " + nf(PIPE_L * calc_V2[selectedReading], 0, 3)
  };
  String[] lcdResults = {
    nf(calc_h[selectedReading], 0, 4),
    nf(calc_hf[selectedReading], 0, 4),
    nf(calc_Q[selectedReading], 0, 6),
    nf(calc_V[selectedReading], 0, 4),
    nf(calc_V2[selectedReading], 0, 4),
    nf(calc_hf[selectedReading] * 2 * G_ACC * PIPE_D, 0, 5),
    nf(PIPE_L * calc_V2[selectedReading], 0, 4),
    nf(calc_f[selectedReading], 0, 5)
  };
  String[] keySequences = {
    "Keys: [ ( ] [h1] [ - ] [h2] [ ) ] [ / ] [ 1 ] [ 0 ] [ 0 ] [ = ]",
    "Keys: [Ans] [ x ] [" + nf(SG_FACTOR, 0, 1) + "] [ = ]",
    "Keys: [ ( ] [A_T] [ x ] [h_rise] [ ) ] [ / ] [ T ] [ = ]",
    "Keys: [Ans] [ / ] [a] [ = ]",
    "Keys: [Ans] [ x^2 ] [ = ]",
    "Keys: [hf] [ x ] [ 2 ] [ x ] [g] [ x ] [d] [ = ]",
    "Keys: [L] [ x ] [V^2] [ = ]",
    "Keys: [Num] [ / ] [Den] [ = ]  ==>  f = " + nf(calc_f[selectedReading], 0, 4)
  };
  String[] highlightKeys = { "(", "x", "/", "/", "x^2", "x", "x", "=" };

  String topLcd = casioManualMode ? casioUserExpr : lcdExprs[bodmasStep];
  String botLcd = casioManualMode ? casioUserAns  : lcdResults[bodmasStep];
  String targetKey = highlightKeys[bodmasStep];

  fill(15, 25, 18);
  textAlign(LEFT, CENTER);
  textSize(11 * uiScale);
  text(topLcd, lcdX + 8 * uiScale, lcdY + 23 * uiScale);

  textAlign(RIGHT, CENTER);
  textSize(14 * uiScale);
  text(botLcd, lcdX + lcdW - 8 * uiScale, lcdY + 41 * uiScale);

  // Top Control Pills (SHIFT, ALPHA, REPLAY OVAL, MODE, ON)
  float ctrlTopY = lcdY + lcdH + 8 * uiScale;
  float pillW = 46 * uiScale;
  float pillH = 20 * uiScale;

  drawCasioPill(x + 18 * uiScale, ctrlTopY, pillW, pillH, "SHIFT", color(180, 130, 20), color(253, 224, 71));
  drawCasioPill(x + 70 * uiScale, ctrlTopY, pillW, pillH, "ALPHA", color(130, 35, 55), color(251, 113, 133));

  float repW = 74 * uiScale;
  float repH = 34 * uiScale;
  float repX = x + w * 0.5 - repW * 0.5;
  fill(71, 85, 105);
  stroke(148, 163, 184);
  strokeWeight(1.2);
  rect(repX, ctrlTopY - 3 * uiScale, repW, repH, 16 * uiScale);
  fill(226, 232, 240);
  textAlign(CENTER, CENTER);
  textSize(8.5 * uiScale);
  text("REPLAY", repX + repW * 0.5, ctrlTopY + repH * 0.5 - 3 * uiScale);

  drawCasioPill(x + w - 2 * pillW - 24 * uiScale, ctrlTopY, pillW, pillH, "MODE", color(51, 65, 85), color(226, 232, 240));
  drawCasioPill(x + w - pillW - 18 * uiScale, ctrlTopY, pillW, pillH, "ON", color(51, 65, 85), color(226, 232, 240));

  // Scientific Keys Grid (4 rows x 6 cols)
  String[][] sciKeys = {
    { "x^-1", "nCr", "Pol(", "x^3", "ab/c", "sqrt" },
    { "x^2",  "^",   "log", "ln",  "(-)",  "hyp" },
    { "sin",  "cos", "tan", "RCL", "ENG",  "(" },
    { ")",    ",",   "M+",  "S<->D","Ans", "EXP" }
  };
  String[][] sciShift = {
    { "x!",   "nPr", "Rec(", "3rt", "d/c",  "3rt" },
    { "xrt",  "10^x","e^x",  "A",   "B",    "C" },
    { "sin-1","cos-1","tan-1","STO","<-",   "D" },
    { "E",    ";",   "M-",   "CLR", "DRG",  "pi" }
  };

  float padX = x + 16 * uiScale;
  float padW = w - 32 * uiScale;
  float sciStartY = ctrlTopY + 36 * uiScale;
  float sciRowH = 26 * uiScale;
  float sciColW = padW / 6.0;

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 6; c++) {
      float kx = padX + c * sciColW + 2 * uiScale;
      float ky = sciStartY + r * sciRowH + 6 * uiScale;
      float kw = sciColW - 4 * uiScale;
      float kh = sciRowH - 8 * uiScale;
      String lbl = sciKeys[r][c];
      boolean isHighlight = (!casioManualMode && lbl.equals(targetKey));

      fill(COL_ACCENT_GOLD);
      textAlign(CENTER, BOTTOM);
      textSize(7.2 * uiScale);
      text(sciShift[r][c], kx + kw * 0.5, ky - 0.5 * uiScale);

      fill(isHighlight ? color(234, 88, 12) : color(30, 41, 59));
      stroke(isHighlight ? color(254, 240, 138) : color(100, 116, 139));
      strokeWeight(isHighlight ? 1.8 : 1.0);
      rect(kx, ky, kw, kh, 4 * uiScale);

      fill(255);
      textAlign(CENTER, CENTER);
      textSize(8.8 * uiScale);
      text(lbl, kx + kw * 0.5, ky + kh * 0.5);

      if (isHighlight) {
        drawBouncingRedArrow(kx + kw * 0.5, ky - 4 * uiScale);
      }
    }
  }

  // Numeric & Operator Keys Grid (4 rows x 5 cols)
  String[][] numKeys = {
    { "7", "8", "9", "DEL", "AC" },
    { "4", "5", "6", "x",   "/" },
    { "1", "2", "3", "+",   "-" },
    { "0", ".", "EXP", "Ans", "=" }
  };
  String[][] numShift = {
    { "CONST", "CONV", "CLR", "INS", "OFF" },
    { "MATRIX","VECTOR","STAT","nPr","nCr" },
    { "S-SUM", "S-VAR","DISTR","Pol","Rec" },
    { "Rnd",   "Ran#", "pi",   "DRG>", "%" }
  };

  float numStartY = sciStartY + 4 * sciRowH + 8 * uiScale;
  float botGuideH = 26 * uiScale;
  float numAvailH = (y + h - botGuideH - 6 * uiScale) - numStartY;
  float numRowH = numAvailH / 4.0;
  float numColW = padW / 5.0;

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 5; c++) {
      float kx = padX + c * numColW + 2 * uiScale;
      float ky = numStartY + r * numRowH + 7 * uiScale;
      float kw = numColW - 4 * uiScale;
      float kh = numRowH - 9 * uiScale;
      String lbl = numKeys[r][c];
      boolean isDelAc = (lbl.equals("DEL") || lbl.equals("AC"));
      boolean isHighlight = (!casioManualMode && lbl.equals(targetKey));

      fill(COL_ACCENT_GOLD);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(numShift[r][c], kx + kw * 0.5, ky - 0.5 * uiScale);

      if (isHighlight) {
        fill(234, 88, 12);
        stroke(254, 240, 138);
        strokeWeight(2.0);
      } else if (isDelAc) {
        fill(153, 27, 27);
        stroke(248, 113, 113);
        strokeWeight(1.0);
      } else {
        fill(71, 85, 105);
        stroke(148, 163, 184);
        strokeWeight(1.0);
      }
      rect(kx, ky, kw, kh, 5 * uiScale);

      fill(255);
      textAlign(CENTER, CENTER);
      textSize(11 * uiScale);
      text(lbl, kx + kw * 0.5, ky + kh * 0.5);

      if (isHighlight) {
        drawBouncingRedArrow(kx + kw * 0.5, ky - 4 * uiScale);
      }
    }
  }

  // Bottom Keystroke Sequence Guide
  float guideY = y + h - botGuideH - 4 * uiScale;
  fill(15, 23, 42);
  noStroke();
  rect(x + 12 * uiScale, guideY, w - 24 * uiScale, botGuideH, 5 * uiScale);
  fill(125, 211, 252);
  textAlign(CENTER, CENTER);
  textSize(10 * uiScale);
  text(keySequences[bodmasStep], x + w * 0.5, guideY + botGuideH * 0.5);
}

void drawCasioPill(float x, float y, float w, float h, String lbl, color bg, color fg) {
  fill(bg);
  stroke(148, 163, 184);
  strokeWeight(1);
  rect(x, y, w, h, h * 0.5);
  fill(fg);
  textAlign(CENTER, CENTER);
  textSize(8.5 * uiScale);
  text(lbl, x + w * 0.5, y + h * 0.5);
}

void drawBouncingRedArrow(float cx, float tipY) {
  float bounce = abs(sin(frameCount * 0.18)) * 5 * uiScale;
  float y1 = tipY - 12 * uiScale - bounce;
  float y2 = tipY - bounce;
  stroke(239, 68, 68);
  strokeWeight(2.5 * uiScale);
  line(cx, y1, cx, y2);
  fill(239, 68, 68);
  noStroke();
  triangle(cx, y2 + 2 * uiScale, cx - 5 * uiScale, y2 - 5 * uiScale, cx + 5 * uiScale, y2 - 5 * uiScale);
}

void handleCasioKeyPress(String keyLbl) {
  casioManualMode = true;
  if (keyLbl.equals("AC")) {
    casioUserExpr = "";
    casioUserAns = "0.";
  } else if (keyLbl.equals("DEL")) {
    if (casioUserExpr.length() > 0) {
      casioUserExpr = casioUserExpr.substring(0, casioUserExpr.length() - 1);
    }
  } else if (keyLbl.equals("Ans")) {
    casioUserExpr += nf(calc_f[selectedReading], 0, 4);
  } else if (keyLbl.equals("x^2")) {
    float val = evalSimpleExpr(casioUserExpr);
    casioUserAns = nf(val * val, 0, 5);
  } else if (keyLbl.equals("=")) {
    float val = evalSimpleExpr(casioUserExpr);
    casioUserAns = nf(val, 0, 5);
  } else {
    if (casioUserExpr.length() < 22) {
      casioUserExpr += keyLbl;
    }
  }
}

float evalSimpleExpr(String expr) {
  String clean = expr.replace("x", "*");
  int opIdx = -1;
  char op = ' ';
  for (int i = clean.length() - 1; i >= 1; i--) {
    char c = clean.charAt(i);
    if (c == '+' || c == '-' || c == '*' || c == '/') {
      opIdx = i;
      op = c;
      break;
    }
  }
  if (opIdx == -1) {
    float v = float(clean);
    return Float.isNaN(v) ? 0 : v;
  }
  float a = float(clean.substring(0, opIdx));
  float b = float(clean.substring(opIdx + 1));
  if (Float.isNaN(a) || Float.isNaN(b)) return 0;
  if (op == '+') return a + b;
  if (op == '-') return a - b;
  if (op == '*') return a * b;
  if (op == '/' && b != 0) return a / b;
  return 0;
}

// ============================================================================
// SCREEN 6: OBSERVATION TABLE & SMOOTH CURVE POINT-JOINING GRAPH (f vs V)
// ============================================================================
void drawScreen6_TableAndGraph() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;

  float leftW = (width - 36 * uiScale) * 0.55;
  float rightW = (width - 36 * uiScale) * 0.45;
  float leftX = 14 * uiScale;
  float rightX = leftX + leftW + 8 * uiScale;

  // --- LEFT PANEL: FULL OBSERVATION TABLE ---
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  rect(leftX, topY, leftW, totalH, 8 * uiScale);

  fill(COL_HEADER_BLUE);
  noStroke();
  rect(leftX, topY, leftW, 36 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("OBSERVATION TABLE (TAP ANY ROW TO SYNC ALL 6 SCREENS)", leftX + 12 * uiScale, topY + 18 * uiScale);

  String[] headers = { "No.", "h1(cm)", "h2(cm)", "h(m)", "hf(m)", "T(s)", "Qx10^-4", "V(m/s)", "V^2", "f" };
  float[] colWeights = { 0.65, 0.95, 0.95, 0.95, 0.95, 0.75, 1.15, 1.0, 1.0, 1.05 };
  float sumW = 0;
  for (float cw : colWeights) sumW += cw;

  float tblX = leftX + 8 * uiScale;
  float tblW = leftW - 16 * uiScale;
  float hdrY = topY + 42 * uiScale;
  float hdrH = 34 * uiScale;

  fill(30, 41, 59);
  stroke(71, 85, 105);
  strokeWeight(1);
  rect(tblX, hdrY, tblW, hdrH);

  float curX = tblX;
  fill(125, 211, 252);
  textAlign(CENTER, CENTER);
  textSize(10 * uiScale);
  for (int c = 0; c < headers.length; c++) {
    float cw = tblW * (colWeights[c] / sumW);
    text(headers[c], curX + cw * 0.5, hdrY + hdrH * 0.5);
    if (c > 0) line(curX, hdrY, curX, hdrY + hdrH);
    curX += cw;
  }

  // Dynamic Observation Rows
  float rowsY = hdrY + hdrH;
  float availRowsH = (botY - 82 * uiScale) - rowsY;
  float rowH = constrain(availRowsH / max(1, NUM_READINGS), 28 * uiScale, 46 * uiScale);

  for (int r = 0; r < NUM_READINGS; r++) {
    float ry = rowsY + r * rowH;
    boolean isSel = (r == selectedReading);

    if (isSel) {
      fill(30, 58, 138, 230);
      stroke(COL_ACCENT_GOLD);
      strokeWeight(1.8);
    } else {
      fill(r % 2 == 0 ? color(24, 34, 52) : color(18, 26, 42));
      stroke(51, 65, 85);
      strokeWeight(1);
    }
    rect(tblX, ry, tblW, rowH);

    String[] cells = {
      "R" + (r + 1),
      nf(obs_h1[r], 0, 1),
      nf(obs_h2[r], 0, 1),
      nf(calc_h[r], 0, 3),
      nf(calc_hf[r], 0, 3),
      nf(obs_T[r], 0, 0),
      nf(calc_Q[r] * 10000.0, 0, 2),
      nf(calc_V[r], 0, 3),
      nf(calc_V2[r], 0, 3),
      nf(calc_f[r], 0, 4)
    };

    curX = tblX;
    for (int c = 0; c < cells.length; c++) {
      float cw = tblW * (colWeights[c] / sumW);
      fill(c == 9 ? COL_ACCENT_GREEN : (isSel ? color(255) : color(226, 232, 240)));
      textAlign(CENTER, CENTER);
      textSize(10.5 * uiScale);
      text(cells[c], curX + cw * 0.5, ry + rowH * 0.5);
      if (c > 0) {
        stroke(51, 65, 85);
        strokeWeight(1);
        line(curX, ry, curX, ry + rowH);
      }
      curX += cw;
    }
  }

  // Apparatus Constants & Average Result Footer Box
  float footY = rowsY + NUM_READINGS * rowH + 10 * uiScale;
  float footH = botY - footY - 8 * uiScale;
  fill(15, 23, 42);
  stroke(71, 85, 105);
  strokeWeight(1.2);
  rect(tblX, footY, tblW, footH, 6 * uiScale);

  fill(148, 163, 184);
  textAlign(LEFT, TOP);
  textSize(10.5 * uiScale);
  text("Apparatus: d = " + nf(PIPE_D * 1000, 0, 0) + " mm (" + nf(PIPE_D, 0, 3) + " m) | L = " +
       nf(PIPE_L, 0, 1) + " m | Tank = " + nf(TANK_L, 0, 1) + "m x " + nf(TANK_B, 0, 1) +
       "m | Rise = " + nf(TANK_RISE, 0, 2) + " m",
       tblX + 10 * uiScale, footY + 8 * uiScale);

  fill(20, 83, 45);
  stroke(COL_ACCENT_GREEN);
  strokeWeight(1.5);
  rect(tblX + 10 * uiScale, footY + footH - 36 * uiScale, tblW - 20 * uiScale, 28 * uiScale, 5 * uiScale);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(12 * uiScale);
  text("FINAL RESULT:  Average Darcy Friction Factor of Pipe  f = " + nf(meanFrictionFactor, 0, 4),
       tblX + tblW * 0.5, footY + footH - 22 * uiScale);

  // --- RIGHT PANEL: AUTO-SCALED LAB GRAPH ---
  drawAutoScaledGraph(rightX, topY, rightW, totalH);
}

void drawAutoScaledGraph(float x, float y, float w, float h) {
  fill(COL_PANEL_BG);
  stroke(52, 74, 110);
  strokeWeight(1.5);
  rect(x, y, w, h, 8 * uiScale);

  fill(COL_HEADER_TEAL);
  noStroke();
  rect(x, y, w, 36 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(11.5 * uiScale);
  text(graphModeLinearHf ? "GRAPH: HEAD LOSS hf vs V^2 (LINEAR)" : "GRAPH: FRICTION FACTOR f vs VELOCITY V (CURVE)",
       x + 10 * uiScale, y + 18 * uiScale);

  // Mode Toggle Button in Graph Header
  float togW = 112 * uiScale;
  float togH = 24 * uiScale;
  drawSmallButton(x + w - togW - 8 * uiScale, y + 6 * uiScale, togW, togH,
    graphModeLinearHf ? "Show f Curve" : "Show hf Linear",
    color(30, 58, 138));

  float padL = 62 * uiScale;
  float padR = 22 * uiScale;
  float padT = 50 * uiScale;
  float padB = 96 * uiScale;

  float gx = x + padL;
  float gy = y + padT;
  float gw = w - padL - padR;
  float gh = h - padT - padB;

  fill(255, 250, 250);
  stroke(185, 28, 28);
  strokeWeight(1.5);
  rect(gx, gy, gw, gh);

  // Select X and Y arrays based on active graph mode
  float[] xData = graphModeLinearHf ? calc_hf : calc_V;
  float[] yData = graphModeLinearHf ? calc_V2 : calc_f;

  float rawXMin = graphModeLinearHf ? minHeadLossObs : minVelocityObs;
  float rawXMax = graphModeLinearHf ? maxHeadLossObs : maxVelocityObs;
  float rawYMin = graphModeLinearHf ? minVelSqObs    : minFrictionObs;
  float rawYMax = graphModeLinearHf ? maxVelSqObs    : maxFrictionObs;

  float xSpan = max(0.001, rawXMax - rawXMin);
  float ySpan = max(0.0002, rawYMax - rawYMin);
  float xMin = max(0.0, rawXMin - xSpan * 0.18);
  float xMax = rawXMax + xSpan * 0.18;
  float yMin = max(0.0, rawYMin - ySpan * 0.22);
  float yMax = rawYMax + ySpan * 0.22;

  int xDivs = 12;
  int yDivs = 10;
  float xStep = (xMax - xMin) / xDivs;
  float yStep = (yMax - yMin) / yDivs;

  for (int i = 0; i <= xDivs; i++) {
    float vx = xMin + i * xStep;
    float px = map(vx, xMin, xMax, gx, gx + gw);
    boolean major = (i % 2 == 0);
    stroke(major ? color(239, 68, 68, 120) : color(252, 165, 165, 90));
    strokeWeight(major ? 1.2 : 0.7);
    line(px, gy, px, gy + gh);
    if (major) {
      fill(203, 213, 225);
      textAlign(CENTER, TOP);
      textSize(9.5 * uiScale);
      text(nf(vx, 0, 2), px, gy + gh + 4 * uiScale);
    }
  }

  for (int j = 0; j <= yDivs; j++) {
    float vy = yMin + j * yStep;
    float py = map(vy, yMin, yMax, gy + gh, gy);
    boolean major = (j % 2 == 0);
    stroke(major ? color(239, 68, 68, 120) : color(252, 165, 165, 90));
    strokeWeight(major ? 1.2 : 0.7);
    line(gx, py, gx + gw, py);
    if (major) {
      fill(203, 213, 225);
      textAlign(RIGHT, CENTER);
      textSize(9 * uiScale);
      text(graphModeLinearHf ? nf(vy, 0, 1) : nf(vy, 0, 4), gx - 5 * uiScale, py);
    }
  }

  // Axis Titles
  fill(COL_ACCENT_GOLD);
  textAlign(CENTER, TOP);
  textSize(11 * uiScale);
  text(graphModeLinearHf ? "Head Lost hf (m)  [X-Axis]" : "Flow Velocity V (m/s)  [X-Axis]",
       gx + gw * 0.5, gy + gh + 20 * uiScale);

  pushMatrix();
  translate(x + 14 * uiScale, gy + gh * 0.5);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text(graphModeLinearHf ? "V^2 (m^2/s^2)  [Y-Axis]" : "Friction Factor f  [Y-Axis]", 0, 0);
  popMatrix();

  // Sort reading indices by ascending X so point-joining curve never loops backward
  int[] order = new int[NUM_READINGS];
  for (int i = 0; i < NUM_READINGS; i++) order[i] = i;
  for (int i = 0; i < NUM_READINGS - 1; i++) {
    for (int j = i + 1; j < NUM_READINGS; j++) {
      if (xData[order[j]] < xData[order[i]]) {
        int tmp = order[i];
        order[i] = order[j];
        order[j] = tmp;
      }
    }
  }

  PVector[] pts = new PVector[NUM_READINGS];
  for (int i = 0; i < NUM_READINGS; i++) {
    int idx = order[i];
    pts[i] = new PVector(
      map(xData[idx], xMin, xMax, gx, gx + gw),
      map(yData[idx], yMin, yMax, gy + gh, gy)
    );
  }

  float summaryBoxY = y + h - 54 * uiScale;

  if (!graphModeLinearHf) {
    // --- MODE 0: SMOOTH CATMULL-ROM CURVE POINT-JOINING FOR f vs V ---
    float meanY = map(meanFrictionFactor, yMin, yMax, gy + gh, gy);
    stroke(22, 163, 74, 170);
    strokeWeight(1.4);
    drawDashedLine(gx, meanY, gx + gw, meanY, 6 * uiScale);
    fill(22, 101, 52);
    textAlign(RIGHT, BOTTOM);
    textSize(9 * uiScale);
    text("Mean f = " + nf(meanFrictionFactor, 0, 4), gx + gw - 6 * uiScale, meanY - 2 * uiScale);

    // Draw smooth Catmull-Rom spline passing directly through every plotted point
    if (NUM_READINGS >= 2) {
      int totalSegs = NUM_READINGS - 1;
      float exactSegProgress = graphAnimProgress * totalSegs;

      noFill();
      stroke(37, 99, 235);
      strokeWeight(2.8 * uiScale);
      beginShape();
      for (int seg = 0; seg < totalSegs; seg++) {
        if (seg > exactSegProgress) break;
        float maxT = constrain(exactSegProgress - seg, 0.0, 1.0);
        PVector p0 = pts[max(0, seg - 1)];
        PVector p1 = pts[seg];
        PVector p2 = pts[seg + 1];
        PVector p3 = pts[min(NUM_READINGS - 1, seg + 2)];

        int subSteps = 20;
        for (int s = 0; s <= subSteps; s++) {
          float t = (float(s) / subSteps) * maxT;
          float cx = curvePoint(p0.x, p1.x, p2.x, p3.x, t);
          float cy = curvePoint(p0.y, p1.y, p2.y, p3.y, t);
          vertex(cx, cy);
        }
      }
      endShape();
    }

    // Bottom Summary Card for f vs V Curve
    fill(15, 23, 42);
    stroke(71, 85, 105);
    strokeWeight(1);
    rect(x + 12 * uiScale, summaryBoxY, w - 24 * uiScale, 44 * uiScale, 6 * uiScale);

    fill(125, 211, 252);
    textAlign(LEFT, CENTER);
    textSize(10.5 * uiScale);
    text("Smooth Curve Joining R1..R" + NUM_READINGS + "  |  Range f: " +
         nf(minFrictionObs, 0, 4) + " - " + nf(maxFrictionObs, 0, 4),
         x + 20 * uiScale, summaryBoxY + 13 * uiScale);
    fill(COL_ACCENT_GREEN);
    text("Active R" + (selectedReading + 1) + ": V = " + nf(calc_V[selectedReading], 0, 3) +
         " m/s, f = " + nf(calc_f[selectedReading], 0, 4) + "  |  Mean f = " + nf(meanFrictionFactor, 0, 4),
         x + 20 * uiScale, summaryBoxY + 31 * uiScale);
  } else {
    // --- MODE 1: OLS LINEAR FIT FOR hf vs V^2 ---
    float sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < NUM_READINGS; i++) {
      sumX += calc_hf[i];
      sumY += calc_V2[i];
      sumXY += calc_hf[i] * calc_V2[i];
      sumXX += calc_hf[i] * calc_hf[i];
    }
    float denom = (NUM_READINGS * sumXX - sumX * sumX);
    float slopeM = (abs(denom) > 1e-6) ? (NUM_READINGS * sumXY - sumX * sumY) / denom : 0;
    float interceptC = (sumY - slopeM * sumX) / NUM_READINGS;

    float lineX1 = lerp(xMin, minHeadLossObs, 0.5);
    float lineY1 = slopeM * lineX1 + interceptC;
    float lineX2 = lerp(lineX1, lerp(maxHeadLossObs, xMax, 0.5), graphAnimProgress);
    float lineY2 = slopeM * lineX2 + interceptC;

    stroke(37, 99, 235);
    strokeWeight(2.5);
    line(map(lineX1, xMin, xMax, gx, gx + gw), map(lineY1, yMin, yMax, gy + gh, gy),
         map(lineX2, xMin, xMax, gx, gx + gw), map(lineY2, yMin, yMax, gy + gh, gy));

    fill(15, 23, 42);
    stroke(71, 85, 105);
    strokeWeight(1);
    rect(x + 12 * uiScale, summaryBoxY, w - 24 * uiScale, 44 * uiScale, 6 * uiScale);

    fill(125, 211, 252);
    textAlign(LEFT, CENTER);
    textSize(10.5 * uiScale);
    text("Best-Fit Slope m = d(V^2)/d(hf) = " + nf(slopeM, 0, 2) + " m/s^2",
         x + 20 * uiScale, summaryBoxY + 13 * uiScale);
    fill(COL_ACCENT_GREEN);
    text("Active R" + (selectedReading + 1) + ": (" + nf(calc_hf[selectedReading], 0, 3) +
         " m, " + nf(calc_V2[selectedReading], 0, 3) + " m^2/s^2)  |  Mean f = " + nf(meanFrictionFactor, 0, 4),
         x + 20 * uiScale, summaryBoxY + 31 * uiScale);
  }

  // Plot All Data Points & Dashed Crosshair Projections for Active Reading
  for (int i = 0; i < NUM_READINGS; i++) {
    int idx = order[i];
    float ptX = pts[i].x;
    float ptY = pts[i].y;
    boolean isSel = (idx == selectedReading);

    if (isSel) {
      stroke(234, 88, 12);
      strokeWeight(1.6);
      drawDashedLine(gx, ptY, ptX, ptY, 5 * uiScale);
      drawDashedLine(ptX, ptY, ptX, gy + gh, 5 * uiScale);
    }

    fill(isSel ? color(234, 88, 12) : color(22, 163, 74));
    stroke(15, 23, 42);
    strokeWeight(1.5);
    ellipse(ptX, ptY, isSel ? 12 * uiScale : 8.5 * uiScale, isSel ? 12 * uiScale : 8.5 * uiScale);

    fill(15, 23, 42);
    textAlign(LEFT, BOTTOM);
    textSize(9.5 * uiScale);
    text("R" + (idx + 1), ptX + 5 * uiScale, ptY - 3 * uiScale);
  }
}

// ============================================================================
// SHARED 2D DRAWING HELPERS
// ============================================================================
void drawSmallButton(float x, float y, float w, float h, String label, color bg) {
  fill(bg);
  stroke(148, 163, 184);
  strokeWeight(1);
  rect(x, y, w, h, 5 * uiScale);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(10.5 * uiScale);
  text(label, x + w * 0.5, y + h * 0.5);
}

void draw2DArrow(float x1, float y1, float x2, float y2, color c) {
  stroke(c);
  strokeWeight(2.2 * uiScale);
  line(x1, y1, x2, y2);
  float angle = atan2(y2 - y1, x2 - x1);
  float headLen = 7 * uiScale;
  fill(c);
  noStroke();
  triangle(x2, y2,
           x2 - headLen * cos(angle - PI / 6), y2 - headLen * sin(angle - PI / 6),
           x2 - headLen * cos(angle + PI / 6), y2 - headLen * sin(angle + PI / 6));
}

void drawDashedLine(float x1, float y1, float x2, float y2, float dashLen) {
  float d = dist(x1, y1, x2, y2);
  int steps = max(1, int(d / (dashLen * 2)));
  for (int i = 0; i < steps; i++) {
    float t1 = (i * 2.0 * dashLen) / d;
    float t2 = min(1.0, ((i * 2.0 + 1.0) * dashLen) / d);
    line(lerp(x1, x2, t1), lerp(y1, y2, t1), lerp(x1, x2, t2), lerp(y1, y2, t2));
  }
}

boolean hitRect(float mx, float my, float x, float y, float w, float h) {
  return (mx >= x && mx <= x + w && my >= y && my <= y + h);
}

// ============================================================================
// TOUCH & MOUSE INTERACTION (1:1 HIT-TESTING ACROSS ALL 6 SCREENS)
// ============================================================================
void mousePressed() {
  float topH = getTopBarH();
  float botH = getBotBarH();

  // 1. Top Navigation Tabs Hit-Test
  if (mouseY <= topH) {
    float titleW = 245 * uiScale;
    float tabsStartX = titleW + 16 * uiScale;
    float activeBadgeW = 92 * uiScale;
    float tabsAvailW = width - tabsStartX - activeBadgeW - 14 * uiScale;
    float tabW = tabsAvailW / 6.0;
    for (int i = 0; i < 6; i++) {
      float tx = tabsStartX + i * tabW;
      if (hitRect(mouseX, mouseY, tx, 6 * uiScale, tabW - 4 * uiScale, topH - 12 * uiScale)) {
        currentScreen = i;
        if (currentScreen == 5) resetGraphAnim();
        return;
      }
    }
  }

  // 2. Bottom Navigation Bar Hit-Test (< PREV, NEXT >, R1..Rn Pills)
  if (mouseY >= height - botH) {
    float btnW = 155 * uiScale;
    float btnH = botH - 12 * uiScale;
    float btnY = height - botH + 6 * uiScale;

    if (hitRect(mouseX, mouseY, 10 * uiScale, btnY, btnW, btnH) && currentScreen > 0) {
      currentScreen--;
      if (currentScreen == 5) resetGraphAnim();
      return;
    }
    if (hitRect(mouseX, mouseY, width - btnW - 10 * uiScale, btnY, btnW, btnH) && currentScreen < 5) {
      currentScreen++;
      if (currentScreen == 5) resetGraphAnim();
      return;
    }

    float pillW = constrain(230.0 / max(1, NUM_READINGS), 30, 48) * uiScale;
    float pillGap = 6 * uiScale;
    float labelW = 135 * uiScale;
    float totalGroupW = labelW + NUM_READINGS * (pillW + pillGap);
    float startX = (width - totalGroupW) * 0.5;
    for (int i = 0; i < NUM_READINGS; i++) {
      float px = startX + labelW + i * (pillW + pillGap);
      if (hitRect(mouseX, mouseY, px, btnY, pillW, btnH)) {
        selectReading(i);
        return;
      }
    }
  }

  // 3. Screen-Specific Hit-Testing
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
    if (draggingSlider) {
      updateScreen1Slider();
    } else if (draggingOrbit) {
      rotY += (mouseX - prevTouchX) * 0.008;
      rotX = constrain(rotX + (mouseY - prevTouchY) * 0.008, -1.1, 0.7);
      prevTouchX = mouseX;
      prevTouchY = mouseY;
    }
  } else if (currentScreen == 1) {
    float px = getCutawayPipeX();
    float py = getCutawayPipeY();
    float pw = getCutawayPipeW();
    float ph = getCutawayPipeH();
    if (hitRect(mouseX, mouseY, px, py, pw, ph)) {
      dyeNozzleX = constrain((mouseX - px) / pw, 0.08, 0.90);
      dyeNozzleY = constrain((mouseY - py) / ph, 0.12, 0.88);
      streakPoints.clear();
    }
  }
}

void mouseReleased() {
  draggingOrbit = false;
  draggingSlider = false;
}

void handleScreen1Press() {
  float[] f = getRigFrameRect();
  float[] vp = getRigViewportRect();

  float ctrlX = f[0] + 6 * uiScale;
  float ctrlW = f[2] - 12 * uiScale;
  float ctrlH = 90 * uiScale;
  float ctrlY = f[1] + f[3] - ctrlH - 6 * uiScale;

  float bY = ctrlY + 10 * uiScale;
  float bH = 30 * uiScale;
  float gap = 8 * uiScale;
  float bW = min(122 * uiScale, (ctrlW - 5 * gap) / 4.0);

  if (hitRect(mouseX, mouseY, ctrlX + gap, bY, bW, bH)) {
    autoOrbit = !autoOrbit;
    return;
  }
  if (hitRect(mouseX, mouseY, ctrlX + gap + (bW + gap), bY, bW, bH)) {
    camZoom = constrain(camZoom + 0.15, 0.6, 1.8);
    return;
  }
  if (hitRect(mouseX, mouseY, ctrlX + gap + 2 * (bW + gap), bY, bW, bH)) {
    camZoom = constrain(camZoom - 0.15, 0.6, 1.8);
    return;
  }
  if (hitRect(mouseX, mouseY, ctrlX + gap + 3 * (bW + gap), bY, bW, bH)) {
    rotX = -0.20;
    rotY = 0.36;
    camZoom = 1.0;
    autoOrbit = false;
    valveFlowMultiplier = 1.0;
    return;
  }

  float slX = ctrlX + 145 * uiScale;
  float slW = ctrlW - 195 * uiScale;
  float slY = ctrlY + 62 * uiScale;
  if (hitRect(mouseX, mouseY, slX - 15 * uiScale, slY - 18 * uiScale, slW + 30 * uiScale, 36 * uiScale)) {
    draggingSlider = true;
    updateScreen1Slider();
    return;
  }

  if (hitRect(mouseX, mouseY, vp[0], vp[1], vp[2], vp[3])) {
    draggingOrbit = true;
    prevTouchX = mouseX;
    prevTouchY = mouseY;
  }
}

void updateScreen1Slider() {
  float[] f = getRigFrameRect();
  float ctrlX = f[0] + 6 * uiScale;
  float ctrlW = f[2] - 12 * uiScale;
  float slX = ctrlX + 145 * uiScale;
  float slW = ctrlW - 195 * uiScale;
  float norm = constrain((mouseX - slX) / slW, 0, 1);
  valveFlowMultiplier = 0.5 + norm * 1.0;
}

void handleScreen2Press() {
  float topY = getTopBarH() + 10 * uiScale;
  float btnW = 148 * uiScale;
  float btnH = 30 * uiScale;
  float btnY = topY + 7 * uiScale;

  if (hitRect(mouseX, mouseY, width - 2 * btnW - 32 * uiScale, btnY, btnW, btnH)) {
    unsteadyMode = !unsteadyMode;
    return;
  }
  if (hitRect(mouseX, mouseY, width - btnW - 22 * uiScale, btnY, btnW, btnH)) {
    initCutawayParticles();
    return;
  }

  float px = getCutawayPipeX();
  float py = getCutawayPipeY();
  float pw = getCutawayPipeW();
  float ph = getCutawayPipeH();
  if (hitRect(mouseX, mouseY, px, py, pw, ph)) {
    dyeNozzleX = constrain((mouseX - px) / pw, 0.08, 0.90);
    dyeNozzleY = constrain((mouseY - py) / ph, 0.12, 0.88);
    streakPoints.clear();
  }
}

void handleScreen3Press() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;
  float leftW = (width - 36 * uiScale) * 0.56;
  float leftX = 14 * uiScale;

  float ctrlW = 92 * uiScale;
  float ctrlH = 26 * uiScale;
  float ctrlY = topY + 6 * uiScale;

  if (hitRect(mouseX, mouseY, leftX + leftW - 3 * ctrlW - 22 * uiScale, ctrlY, ctrlW * 0.9, ctrlH)) {
    derivStep = (derivStep - 1 + derivTitles.length) % derivTitles.length;
    return;
  }
  if (hitRect(mouseX, mouseY, leftX + leftW - 2 * ctrlW - 16 * uiScale, ctrlY, ctrlW * 0.9, ctrlH)) {
    derivStep = (derivStep + 1) % derivTitles.length;
    return;
  }
  if (hitRect(mouseX, mouseY, leftX + leftW - ctrlW - 10 * uiScale, ctrlY, ctrlW, ctrlH)) {
    autoDerive = !autoDerive;
    lastDeriveTick = millis();
    return;
  }

  float listStartY = topY + 46 * uiScale;
  float stepH = (totalH - 54 * uiScale) / derivTitles.length;
  for (int i = 0; i < derivTitles.length; i++) {
    float sy = listStartY + i * stepH;
    if (hitRect(mouseX, mouseY, leftX + 10 * uiScale, sy, leftW - 20 * uiScale, stepH)) {
      derivStep = i;
      autoDerive = false;
      return;
    }
  }
}

void handleScreen4Press() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;
  float leftW = (width - 36 * uiScale) * 0.48;
  float leftX = 14 * uiScale;

  if (hitRect(mouseX, mouseY, leftX + leftW - 118 * uiScale, topY + 6 * uiScale, 108 * uiScale, 26 * uiScale)) {
    autoProc = !autoProc;
    lastProcTick = millis();
    return;
  }

  float listY = topY + 46 * uiScale;
  float stepH = (totalH - 54 * uiScale) / procTitles.length;
  for (int i = 0; i < procTitles.length; i++) {
    float sy = listY + i * stepH;
    if (hitRect(mouseX, mouseY, leftX + 10 * uiScale, sy, leftW - 20 * uiScale, stepH)) {
      procStep = i;
      autoProc = false;
      return;
    }
  }
}

void handleScreen5Press() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float totalH = botY - topY;

  float leftW = (width - 36 * uiScale) * 0.53;
  float rightW = (width - 36 * uiScale) * 0.47;
  float leftX = 14 * uiScale;
  float rightX = leftX + leftW + 8 * uiScale;

  if (hitRect(mouseX, mouseY, leftX + leftW - 108 * uiScale, topY + 6 * uiScale, 98 * uiScale, 26 * uiScale)) {
    autoBodmas = !autoBodmas;
    lastBodmasTick = millis();
    return;
  }

  float badgeBarY = topY + 44 * uiScale;
  float rowsStartY = badgeBarY + 36 * uiScale;
  float rowH = (totalH - 90 * uiScale) / 8.0;
  for (int i = 0; i < 8; i++) {
    float ry = rowsStartY + i * rowH;
    if (hitRect(mouseX, mouseY, leftX + 10 * uiScale, ry, leftW - 20 * uiScale, rowH)) {
      bodmasStep = i;
      casioManualMode = false;
      autoBodmas = false;
      return;
    }
  }

  // Casio Keypad Hit-Testing
  float lcdY = topY + 34 * uiScale;
  float lcdH = 54 * uiScale;
  float ctrlTopY = lcdY + lcdH + 8 * uiScale;
  float sciStartY = ctrlTopY + 36 * uiScale;
  float sciRowH = 26 * uiScale;
  float numStartY = sciStartY + 4 * sciRowH + 8 * uiScale;
  float botGuideH = 26 * uiScale;
  float numAvailH = (topY + totalH - botGuideH - 6 * uiScale) - numStartY;
  float numRowH = numAvailH / 4.0;
  float padX = rightX + 16 * uiScale;
  float padW = rightW - 32 * uiScale;
  float numColW = padW / 5.0;

  String[][] numKeys = {
    { "7", "8", "9", "DEL", "AC" },
    { "4", "5", "6", "x",   "/" },
    { "1", "2", "3", "+",   "-" },
    { "0", ".", "EXP", "Ans", "=" }
  };

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 5; c++) {
      float kx = padX + c * numColW + 2 * uiScale;
      float ky = numStartY + r * numRowH + 7 * uiScale;
      float kw = numColW - 4 * uiScale;
      float kh = numRowH - 9 * uiScale;
      if (hitRect(mouseX, mouseY, kx, ky, kw, kh)) {
        handleCasioKeyPress(numKeys[r][c]);
        return;
      }
    }
  }
}

void handleScreen6Press() {
  float topY = getTopBarH() + 10 * uiScale;
  float botY = height - getBotBarH() - 10 * uiScale;
  float leftW = (width - 36 * uiScale) * 0.55;
  float rightW = (width - 36 * uiScale) * 0.45;
  float leftX = 14 * uiScale;
  float rightX = leftX + leftW + 8 * uiScale;

  // Graph Mode Toggle Button Hit-Test
  float togW = 112 * uiScale;
  float togH = 24 * uiScale;
  if (hitRect(mouseX, mouseY, rightX + rightW - togW - 8 * uiScale, topY + 6 * uiScale, togW, togH)) {
    graphModeLinearHf = !graphModeLinearHf;
    resetGraphAnim();
    return;
  }

  // Observation Table Row Hit-Test
  float tblX = leftX + 8 * uiScale;
  float tblW = leftW - 16 * uiScale;
  float rowsY = topY + 42 * uiScale + 34 * uiScale;
  float availRowsH = (botY - 82 * uiScale) - rowsY;
  float rowH = constrain(availRowsH / max(1, NUM_READINGS), 28 * uiScale, 46 * uiScale);

  for (int r = 0; r < NUM_READINGS; r++) {
    float ry = rowsY + r * rowH;
    if (hitRect(mouseX, mouseY, tblX, ry, tblW, rowH)) {
      selectReading(r);
      return;
    }
  }
}
