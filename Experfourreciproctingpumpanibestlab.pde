// ============================================================================
// RECIPROCATING PUMP PERFORMANCE TEST — 6-SCREEN INTERACTIVE APDE (P3D) LAB
// Extracted from Lab Record (Ex. No. 4) & Real Lab Rig Architecture
// Constants: D = 40 mm (0.04 m), L = 45 mm (0.045 m), At = 0.3 x 0.3 = 0.09 m^2
//            h = 10 cm (0.1 m), x = 0.6 m, Ne = 1200 rev/kWh, Nr = 5 rev, eta_m = 0.8
// ============================================================================

int currentScreen = 0; // 0:3D Rig, 1:Cutaway, 2:Derivation, 3:Procedure, 4:Casio Calc, 5:Table & Graph
String[] screenNames = {
  "1. 3D RIG",
  "2. CUTAWAY",
  "3. DERIVATION",
  "4. PROCEDURE",
  "5. CASIO CALC",
  "6. TABLE & GRAPH"
};

float uiScale = 1.0;
int lastW = -1;
int lastH = -1;

// Apparatus Constants (Exact from Lab Record)
final float CYL_DIA_M       = 0.040;   // 40 mm
final float STROKE_M        = 0.045;   // 45 mm
final float CYL_AREA_M2     = 0.0012;  // Lab record value: 0.0012 m^2
final float TANK_LEN_M      = 0.30;    // 300 mm
final float TANK_WID_M      = 0.30;    // 300 mm
final float TANK_AREA_M2    = 0.09;    // 0.3 x 0.3 = 0.09 m^2
final float RISE_H_M        = 0.10;    // 10 cm = 0.1 m
final float GAUGE_DATUM_X   = 0.60;    // 0.6 m vertical difference between gauges
final float SP_WT_WATER     = 9.81;    // kN/m^3
final float SP_GR_HG        = 13.6;    // Mercury specific gravity
final float ENERGY_CONST_NE = 1200.0;  // rev/kWh
final float ENERGY_REV_NR   = 5.0;     // 5 revolutions
final float MOTOR_EFF       = 0.80;    // 80% motor efficiency

// Observation Table Data (5 Readings R1..R5 from Lab Record; R1 = Model Calculation)
int numReadings = 5;
int selectedReading = 0; // Default R1 (Model Calculation row)

int[]   rSlNo    = { 1,     2,      3,      4,      5 };
float[] rVacHg   = { 115,   110,    105,    105,    105 };     // hs (mm of Hg)
float[] rHs      = { 1.562, 1.495,  1.437,  1.437,  1.437 };   // Hs (m of water)
float[] rPressKg = { 0.4,   0.8,    1.2,    1.6,    2.0 };     // pd (kg/cm^2)
float[] rHd      = { 4.0,   8.0,    12.0,   16.0,   20.0 };    // Hd (m of water)
float[] rHT      = { 6.162, 10.095, 14.037, 18.037, 22.037 };  // HT = Hs + Hd + x (m)
float[] rSpeedN  = { 1420,  1420,   1420,   1420,   1420 };    // Crank speed N (rpm)
float[] rTimeT   = { 19.4,  19.8,   20.8,   21.4,   22.0 };    // Time T for 0.1 m rise (sec)
float[] rQa      = { 4.639e-4, 4.545e-4, 4.326e-4, 4.205e-4, 4.090e-4 }; // Actual discharge (m^3/s)
float[] rQt      = { 1.278e-3, 1.278e-3, 1.278e-3, 1.278e-3, 1.278e-3 }; // Theo discharge (m^3/s)
float[] rCd      = { 0.362, 0.355,  0.338,  0.329,  0.320 };   // Coefficient of discharge Cd
float[] rSlipPct = { 63.8,  64.4,   66.2,   67.1,   68.0 };    // % Slip
float[] rTimeE   = { 42.08, 36.24,  33.60,  30.26,  27.43 };   // Time t for 5 rev energy meter (sec)
float[] rPo      = { 0.0280, 0.0450, 0.0595, 0.0743, 0.0883 }; // Output power Po (kW)
float[] rPi      = { 0.285, 0.336,  0.365,  0.396,  0.437 };   // Input power Pi (kW)
float[] rEffPct  = { 9.96,  13.61,  16.69,  18.76,  20.44 };   // Overall efficiency eta (%)

// Live interpolated / interactive parameters
float liveHd      = 4.0;
float liveHs      = 1.562;
float liveVacHg   = 115.0;
float livePressKg = 0.4;
float liveHT      = 6.162;
float liveN       = 1420.0;
float liveT       = 19.4;
float liveQa      = 4.639e-4;
float liveQt      = 1.278e-3;
float liveCd      = 0.362;
float liveSlipPct = 63.8;
float liveTimeE   = 42.08;
float livePo      = 0.0280;
float livePi      = 0.285;
float liveEffPct  = 9.96;

// Screen 1: 3D Camera & Animation State
float rotX = -0.18;
float rotY = -0.24;
float zoom3D = 1.0;
boolean autoOrbit = false;
float crankAngle = 0.0;
float discAngle = 0.0;
float tankWaterLevel = 0.35;
boolean dragging3D = false;
boolean draggingSlider = false;
float lastMouseX, lastMouseY;

class FlowParticle3D {
  float progress;
  float radialOffset;
  float speedMult;
  FlowParticle3D() {
    reset(random(1.0));
  }
  void reset(float p) {
    progress = p;
    radialOffset = random(-4.5, 4.5);
    speedMult = random(0.88, 1.12);
  }
}
ArrayList<FlowParticle3D> particles3D;

// Screen 2: 2D Cutaway Physics Simulation State
boolean unsteadyMode = true;
float simTime = 0.0;
float dyeNozzleX = 0.38;
float dyeNozzleY = 0.56;

class FluidParticle2D {
  float x, y;
  int zone; // 0:suction, 1:cylinder, 2:delivery, 3:slip leak
  ArrayList<PVector> trail;
  FluidParticle2D() {
    trail = new ArrayList<PVector>();
    respawn(true);
  }
  void respawn(boolean randomInit) {
    trail.clear();
    zone = 0;
    x = randomInit ? random(0.12, 0.34) : random(0.10, 0.16);
    y = random(0.71, 0.77);
  }
}
ArrayList<FluidParticle2D> particles2D;
ArrayList<PVector> streaklinePts;

// Screen 3: Derivation State
int derivStep = 0;
boolean autoDerive = false;
float autoDeriveTimer = 0;
String[] derivTitles = {
  "STEP 1: Swept Cylinder Volume & Theoretical Discharge (Qt)",
  "STEP 2: Actual Discharge via Collecting Tank Rise (Qa)",
  "STEP 3: Slip & Percentage Slip (% Slip)",
  "STEP 4: Coefficient of Discharge (Cd)",
  "STEP 5: Total Dynamic Head (HT = Hs + Hd + x)",
  "STEP 6: Hydraulic Output Power (Po) & Motor Input Power (Pi)",
  "STEP 7: Overall Pump Efficiency (eta %)"
};
String[] derivFormulas = {
  "Vs = A x L  ==>  Qt = (A x L x N) / 60  (Single-Acting, 1 stroke/rev)",
  "Vol = At x h  ==>  Qa = (At x h) / T   (At = 0.3 x 0.3 = 0.09 m^2)",
  "Slip = Qt - Qa   |   % Slip = [(Qt - Qa) / Qt] x 100 = (1 - Cd) x 100",
  "Cd = Qa / Qt = (At x h x 60) / (T x A x L x N)",
  "Hs = (hs_mmHg x 13.6)/1000,  Hd = pd_kgcm2 x 10  ==>  HT = Hs + Hd + x",
  "Po = w x Qa x HT (kW)  |  Pi = (Nr / Ne) x (3600 / t) x eta_motor (kW)",
  "eta (%) = (Po / Pi) x 100  ==>  Characteristic Curves vs HT"
};
String[] derivNotes = {
  "A = 0.0012 m^2, L = 0.045 m, N = 1420 rpm ==> Qt = 1.278 x 10^-3 m^3/s",
  "Tank rise h = 0.10 m timed by stopwatch T (sec) with gate valve shut",
  "Valve clearance & ring leakage reduce Qa as delivery head HT rises",
  "Ratio of actual water delivered to swept plunger displacement",
  "w = 9.81 kN/m^3, Hg = 13.6, gauge vertical datum separation x = 0.6 m",
  "Ne = 1200 rev/kWh, Nr = 5 disc revolutions in t sec, eta_motor = 0.80",
  "Evaluated across 5 delivery throttling heads from 6.162 m to 22.037 m"
};

// Screen 4: Procedure State
int procStep = 0;
boolean autoProc = false;
float autoProcTimer = 0;
String[] procTitles = {
  "1. Record Pump & Tank Constants",
  "2. Measure Gauge Datum Height (x)",
  "3. Open Delivery Valve & Start Motor",
  "4. Throttle Valve & Log Gauges + Energy",
  "5. Close Gate Valve & Time Tank Rise (T)",
  "6. Repeat for 5 Heads & Shut Down"
};
String[] procDetails = {
  "Note single-acting pump D = 40 mm, stroke L = 45 mm, energy constant Ne = 1200 rev/kWh, and tank area 0.3 x 0.3 m.",
  "Use metre scale to measure vertical center-to-center distance x = 0.6 m between vacuum and pressure gauges.",
  "Keep delivery gate valve fully open to avoid initial overload, then switch ON electric motor drive.",
  "Partially close delivery valve; record vacuum hs (mm Hg), pressure pd (kg/cm^2), speed N (rpm), and time t for 5 disc revs.",
  "Shut collecting tank return gate valve tightly; start stopwatch to measure time T (sec) for h = 10 cm (0.1 m) rise.",
  "Throttle delivery valve in 5 stages (0.4 to 2.0 kg/cm^2), tabulate readings, open valve fully, and switch OFF."
};

// Screen 5: Casio fx-991MS Calculator & BODMAS State
int bodmasStep = 0;
String calcExpr = "(0.09x0.1)/19.4";
String calcAns = "4.639175258x10^-4";
String activeCasioKey = "=";
String[] bodmasBadges = { "B", "O", "D", "M", "A", "S", "D", "M" };
String[] bodmasLabels = {
  "1. [B] Theoretical Qt = (A x L x N) / 60",
  "2. [O] Actual Qa = (At x h) / T",
  "3. [D] Coeff. of Discharge Cd = Qa / Qt",
  "4. [M] Percentage Slip = (1 - Cd) x 100",
  "5. [A] Total Head HT = Hs + Hd + x",
  "6. [S] Output Power Po = 9.81 x Qa x HT",
  "7. [D] Input Power Pi = (5/1200)x(3600/t)x0.8",
  "8. [M] Efficiency eta = (Po / Pi) x 100"
};

// Screen 6: Graph Curve & Fit Mode
// 0: All 3 Curves (Exact Lab Sheet), 1: HT vs Efficiency (%), 2: HT vs % Slip, 3: HT vs Actual Discharge Qa
int graphCurveMode = 0;
// 0: Lab Record (Smooth monotone curves for Eff% & %Slip, Straight best-fit line for Qa)
// 1: All Smooth Monotone Curves (Point-to-point bend)
// 2: All Straight Best-Fit Lines (OLS)
int graphFitMode = 0;

// Shared Layout Helpers (Guaranteed 1:1 alignment between drawing and touch hit-tests)
float topBarH()   { return 46 * uiScale; }
float botBarH()   { return 42 * uiScale; }
float arenaTop()  { return topBarH() + 8 * uiScale; }
float arenaBot()  { return height - botBarH() - 8 * uiScale; }
float arenaH()    { return arenaBot() - arenaTop(); }

void settings() {
  fullScreen(P3D);
}

void setup() {
  orientation(LANDSCAPE);
  updateResponsiveScale();

  particles3D = new ArrayList<FlowParticle3D>();
  for (int i = 0; i < 48; i++) {
    particles3D.add(new FlowParticle3D());
  }

  particles2D = new ArrayList<FluidParticle2D>();
  for (int i = 0; i < 65; i++) {
    particles2D.add(new FluidParticle2D());
  }
  streaklinePts = new ArrayList<PVector>();

  syncToReading(0);
}

void updateResponsiveScale() {
  if (width != lastW || height != lastH) {
    lastW = width;
    lastH = height;
    uiScale = constrain(min(width / 1280.0, height / 720.0), 0.55, 1.5);
    textFont(createFont("SansSerif", 16 * uiScale));
  }
}

void syncToReading(int idx) {
  selectedReading = constrain(idx, 0, numReadings - 1);
  liveVacHg   = rVacHg[selectedReading];
  liveHs      = rHs[selectedReading];
  livePressKg = rPressKg[selectedReading];
  liveHd      = rHd[selectedReading];
  liveHT      = rHT[selectedReading];
  liveN       = rSpeedN[selectedReading];
  liveT       = rTimeT[selectedReading];
  liveQa      = rQa[selectedReading];
  liveQt      = rQt[selectedReading];
  liveCd      = rCd[selectedReading];
  liveSlipPct = rSlipPct[selectedReading];
  liveTimeE   = rTimeE[selectedReading];
  livePo      = rPo[selectedReading];
  livePi      = rPi[selectedReading];
  liveEffPct  = rEffPct[selectedReading];
  updateCasioForStep(bodmasStep);
}

void updateFromSliderHd(float newHd) {
  liveHd = constrain(newHd, 4.0, 20.0);
  int bestIdx = 0;
  float bestDiff = 999;
  for (int i = 0; i < numReadings; i++) {
    float d = abs(rHd[i] - liveHd);
    if (d < bestDiff) {
      bestDiff = d;
      bestIdx = i;
    }
  }
  selectedReading = bestIdx;
  if (abs(liveHd - rHd[bestIdx]) < 0.45) {
    syncToReading(bestIdx);
    return;
  }
  float frac = (liveHd - 4.0) / 16.0;
  livePressKg = liveHd / 10.0;
  liveVacHg = lerp(115.0, 105.0, constrain(frac * 2.0, 0, 1));
  liveHs = (liveVacHg * SP_GR_HG) / 1000.0;
  liveHT = liveHs + liveHd + GAUGE_DATUM_X;
  liveN = 1420.0;
  liveT = lerp(19.4, 22.0, frac);
  liveQa = (TANK_AREA_M2 * RISE_H_M) / liveT;
  liveQt = (CYL_AREA_M2 * STROKE_M * liveN) / 60.0;
  liveCd = liveQa / liveQt;
  liveSlipPct = (1.0 - liveCd) * 100.0;
  liveTimeE = lerp(42.08, 27.43, frac);
  livePo = SP_WT_WATER * liveQa * liveHT;
  livePi = (ENERGY_REV_NR / ENERGY_CONST_NE) * (3600.0 / liveTimeE) * MOTOR_EFF;
  liveEffPct = (livePo / livePi) * 100.0;
  updateCasioForStep(bodmasStep);
}

void updateCasioForStep(int step) {
  bodmasStep = constrain(step, 0, 7);
  if (bodmasStep == 0) {
    calcExpr = "(0.0012x0.045x1420)/60";
    calcAns = nf(liveQt * 1000.0, 1, 3) + "x10^-3";
    activeCasioKey = "/";
  } else if (bodmasStep == 1) {
    calcExpr = "(0.09x0.1)/" + nf(liveT, 1, 1);
    calcAns = nf(liveQa * 10000.0, 1, 3) + "x10^-4";
    activeCasioKey = "=";
  } else if (bodmasStep == 2) {
    calcExpr = nf(liveQa * 10000.0, 1, 3) + "E-4/" + nf(liveQt * 1000.0, 1, 3) + "E-3";
    calcAns = nf(liveCd, 1, 3);
    activeCasioKey = "EXP";
  } else if (bodmasStep == 3) {
    calcExpr = "(1-" + nf(liveCd, 1, 3) + ")x100";
    calcAns = nf(liveSlipPct, 1, 1) + "%";
    activeCasioKey = "x";
  } else if (bodmasStep == 4) {
    calcExpr = nf(liveHs, 1, 3) + "+" + nf(liveHd, 1, 1) + "+0.6";
    calcAns = nf(liveHT, 1, 3) + " m";
    activeCasioKey = "+";
  } else if (bodmasStep == 5) {
    calcExpr = "9.81x" + nf(liveQa * 10000.0, 1, 3) + "E-4x" + nf(liveHT, 1, 3);
    calcAns = nf(livePo, 1, 4) + " kW";
    activeCasioKey = "x";
  } else if (bodmasStep == 6) {
    calcExpr = "(5/1200)x(3600/" + nf(liveTimeE, 1, 2) + ")x0.8";
    calcAns = nf(livePi, 1, 3) + " kW";
    activeCasioKey = "/";
  } else {
    calcExpr = "(" + nf(livePo, 1, 4) + "/" + nf(livePi, 1, 3) + ")x100";
    calcAns = nf(liveEffPct, 1, 2) + "%";
    activeCasioKey = "=";
  }
}

void draw() {
  updateResponsiveScale();
  background(12, 18, 28);

  float dt = 1.0 / 60.0;
  simTime += dt;
  float omega = (liveN / 60.0) * TWO_PI * 0.15;
  crankAngle = (crankAngle + omega * dt) % TWO_PI;
  float discOmega = (ENERGY_REV_NR / liveTimeE) * TWO_PI * 2.5;
  discAngle = (discAngle + discOmega * dt) % TWO_PI;
  tankWaterLevel = 0.22 + 0.68 * ((simTime * (1.0 / liveT) * 3.5) % 1.0);

  if (autoOrbit && currentScreen == 0) {
    rotY += 0.006;
  }
  if (autoDerive && currentScreen == 2) {
    autoDeriveTimer += dt;
    if (autoDeriveTimer > 2.8) {
      autoDeriveTimer = 0;
      derivStep = (derivStep + 1) % 7;
    }
  }
  if (autoProc && currentScreen == 3) {
    autoProcTimer += dt;
    if (autoProcTimer > 3.0) {
      autoProcTimer = 0;
      procStep = (procStep + 1) % 6;
    }
  }

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

  beginHUD();
  drawTopNavBar();
  drawBottomNavBar();
  endHUD();
}

// ============================================================================
// HUD DEPTH MANAGEMENT (TRUE SCREEN-CENTERED ORTHOGRAPHIC PROJECTION)
// ============================================================================
void beginHUD() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  ortho(-width * 0.5, width * 0.5, -height * 0.5, height * 0.5, -1000, 1000);
  noLights();
}

void endHUD() {
  hint(ENABLE_DEPTH_TEST);
}

// ============================================================================
// TOP & BOTTOM NAVIGATION BARS (CENTERED & SCALED)
// ============================================================================
void drawTopNavBar() {
  float barH = topBarH();
  fill(16, 24, 38, 248);
  noStroke();
  rect(0, 0, width, barH);
  stroke(45, 75, 115);
  strokeWeight(1.5 * uiScale);
  line(0, barH, width, barH);

  float titleW = 235 * uiScale;
  fill(24, 110, 195);
  noStroke();
  rect(12 * uiScale, 5 * uiScale, titleW, barH - 10 * uiScale, 6 * uiScale);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(12.5 * uiScale);
  text("RECIPROCATING PUMP LAB", 12 * uiScale + titleW * 0.5, barH * 0.5);

  float startX = titleW + 20 * uiScale;
  float availW = width - startX - 12 * uiScale;
  float tabW = (availW - 5 * 5 * uiScale) / 6.0;
  for (int i = 0; i < 6; i++) {
    float tx = startX + i * (tabW + 5 * uiScale);
    float ty = 5 * uiScale;
    float th = barH - 10 * uiScale;
    if (i == currentScreen) {
      fill(0, 175, 220);
      stroke(140, 240, 255);
      strokeWeight(1.5 * uiScale);
    } else {
      fill(26, 38, 58);
      stroke(55, 80, 115);
      strokeWeight(1 * uiScale);
    }
    rect(tx, ty, tabW, th, 6 * uiScale);
    fill(i == currentScreen ? color(10, 18, 28) : color(210, 225, 245));
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text(screenNames[i], tx + tabW * 0.5, ty + th * 0.5);
  }
}

void drawBottomNavBar() {
  float barH = botBarH();
  float by = height - barH;
  fill(16, 24, 38, 248);
  noStroke();
  rect(0, by, width, barH);
  stroke(45, 75, 115);
  strokeWeight(1.5 * uiScale);
  line(0, by, width, by);

  float btnW = 150 * uiScale;
  float btnH = barH - 10 * uiScale;

  // < PREV SCREEN
  fill(currentScreen > 0 ? color(34, 54, 82) : color(22, 30, 44));
  stroke(75, 115, 165);
  rect(12 * uiScale, by + 5 * uiScale, btnW, btnH, 6 * uiScale);
  fill(currentScreen > 0 ? 255 : 110);
  textAlign(CENTER, CENTER);
  textSize(11.5 * uiScale);
  text("< PREV SCREEN", 12 * uiScale + btnW * 0.5, by + barH * 0.5);

  // NEXT SCREEN >
  fill(currentScreen < 5 ? color(0, 150, 200) : color(22, 30, 44));
  stroke(90, 210, 250);
  rect(width - btnW - 12 * uiScale, by + 5 * uiScale, btnW, btnH, 6 * uiScale);
  fill(currentScreen < 5 ? 255 : 110);
  text("NEXT SCREEN >", width - btnW * 0.5 - 12 * uiScale, by + barH * 0.5);

  // Center Status Strip
  fill(175, 205, 235);
  textAlign(CENTER, CENTER);
  textSize(11 * uiScale);
  String status = "Active: R" + rSlNo[selectedReading] + (selectedReading == 0 ? " (Model Calc)" : "") +
                  "  |  HT = " + nf(liveHT, 1, 3) + " m  |  Qa = " + nf(liveQa * 1e4, 1, 3) + "x10^-4 m^3/s" +
                  "  |  Cd = " + nf(liveCd, 1, 3) + "  |  Slip = " + nf(liveSlipPct, 1, 1) + "%" +
                  "  |  Eff = " + nf(liveEffPct, 1, 2) + "%";
  text(status, width * 0.5, by + barH * 0.5);
}

// ============================================================================
// SCREEN 1: FULL 3D RECIPROCATING PUMP RIG (ENCLOSED & CENTERED IN VIEWPORT)
// ============================================================================
void drawScreen1_3DRig() {
  float cardX = 12 * uiScale;
  float cardW = 300 * uiScale;
  float viewLeft = cardX + cardW + 10 * uiScale;
  float viewRight = width - 12 * uiScale;
  float viewTop = arenaTop();
  float viewBot = arenaBot();
  float viewW = viewRight - viewLeft;
  float viewH = viewBot - viewTop;

  // 1. Draw Enclosed 3D Viewport Backdrop Panel first
  beginHUD();
  fill(15, 23, 36);
  noStroke();
  rect(viewLeft, viewTop, viewW, viewH, 8 * uiScale);
  endHUD();

  // 2. Render 3D Apparatus centered inside the inner 3D box (between header and slider)
  float fov = PI / 3.2;
  float camZ = (height * 0.88) / zoom3D;
  perspective(fov, float(width) / float(height), 1.0, 6000.0);
  camera(0, 0, camZ, 0, 0, 0, 0, 1, 0);

  ambientLight(115, 125, 140);
  directionalLight(240, 245, 255, -0.45, 0.75, -0.65);
  directionalLight(115, 165, 225, 0.65, -0.35, 0.55);

  float innerTop = viewTop + 34 * uiScale;
  float innerBot = viewBot - 68 * uiScale;
  float viewCenterX = (viewLeft + viewRight) * 0.5;
  float viewCenterY = (innerTop + innerBot) * 0.5;

  float worldPerPixel = (2.0 * camZ * tan(fov * 0.5)) / float(height);
  float worldShiftX = (viewCenterX - width * 0.5) * worldPerPixel;
  float worldShiftY = (viewCenterY - height * 0.5) * worldPerPixel;

  float availViewW = (viewW - 24 * uiScale) * worldPerPixel;
  float availViewH = (innerBot - innerTop - 16 * uiScale) * worldPerPixel;
  float rigFitScale = constrain(min(availViewW / 545.0, availViewH / 315.0), 0.42, 1.25);

  pushMatrix();
  translate(worldShiftX, worldShiftY + 4 * rigFitScale, 0);
  rotateX(rotX);
  rotateY(rotY);
  scale(rigFitScale);
  drawApparatus3D();
  popMatrix();

  // 3. Draw 2D Enclosure Border, Header, Slider & Left Telemetry HUD on top
  beginHUD();
  drawScreen1HUD();
  endHUD();
}

void drawApparatus3D() {
  // Subtle 3D Laboratory Floor Platform so rig sits cleanly grounded inside enclosure
  pushMatrix();
  translate(-5, 144, 0);
  fill(22, 34, 52, 210);
  stroke(55, 95, 145, 160);
  strokeWeight(1);
  box(535, 6, 150);
  popMatrix();

  // --------------------------------------------------------------------------
  // 1. SEPARATE RED TUBULAR STAND + BLUE CONTROL PANEL (Far Left)
  // --------------------------------------------------------------------------
  pushMatrix();
  translate(-225, 0, 0);
  fill(205, 38, 38);
  noStroke();
  float legW = 5;
  drawPipeSegment3D(-22, 14, -18, -26, 138, -22, legW * 0.5, color(205, 38, 38));
  drawPipeSegment3D( 22, 14, -18,  26, 138, -22, legW * 0.5, color(205, 38, 38));
  drawPipeSegment3D(-22, 14,  18, -26, 138,  22, legW * 0.5, color(205, 38, 38));
  drawPipeSegment3D( 22, 14,  18,  26, 138,  22, legW * 0.5, color(205, 38, 38));

  drawPipeSegment3D(-25, 118, -21, 25, 118, -21, 2.2, color(205, 38, 38));
  drawPipeSegment3D(-25, 118,  21, 25, 118,  21, 2.2, color(205, 38, 38));
  drawPipeSegment3D(-25, 118, -21,-25, 118,  21, 2.2, color(205, 38, 38));
  drawPipeSegment3D( 25, 118, -21, 25, 118,  21, 2.2, color(205, 38, 38));

  translate(0, -32, 0);
  fill(26, 86, 175);
  stroke(65, 135, 225);
  strokeWeight(1);
  box(52, 92, 42);

  translate(0, -2, 22);
  fill(242, 245, 250);
  noStroke();
  box(42, 78, 2);

  translate(0, -18, 2);
  fill(35, 45, 58);
  box(26, 16, 2);
  pushMatrix();
  translate(0, 0, 1.5);
  rotateY(discAngle);
  fill(235, 55, 55);
  box(18, 3, 2);
  popMatrix();

  translate(-9, 32, 1);
  fill(35, 185, 85);
  sphere(3.5);
  translate(18, 0, 0);
  fill(225, 45, 45);
  sphere(3.5);
  popMatrix();

  // --------------------------------------------------------------------------
  // 2. MAIN NAVY BLUE CHANNEL BASE SKID FRAME
  // --------------------------------------------------------------------------
  pushMatrix();
  translate(40, 132, 0);
  fill(24, 42, 76);
  stroke(50, 80, 130);
  strokeWeight(1);
  pushMatrix(); translate(0, 0, 48); box(410, 12, 10); popMatrix();
  pushMatrix(); translate(0, 0, -48); box(410, 12, 10); popMatrix();
  for (int rx = -195; rx <= 195; rx += 97) {
    pushMatrix(); translate(rx, 0, 0); box(10, 12, 104); popMatrix();
  }
  popMatrix();

  // --------------------------------------------------------------------------
  // 3. ELEVATED NAVY STAND + RED BELT GUARD + GREEN FLYWHEEL
  // --------------------------------------------------------------------------
  float standX = -112;
  drawPipeSegment3D(standX - 42, -25, -42, standX - 42, 128, -42, 4, color(24, 42, 76));
  drawPipeSegment3D(standX + 42, -25, -42, standX + 42, 128, -42, 4, color(24, 42, 76));
  drawPipeSegment3D(standX - 42, -25,  42, standX - 42, 128,  42, 4, color(24, 42, 76));
  drawPipeSegment3D(standX + 42, -25,  42, standX + 42, 128,  42, 4, color(24, 42, 76));

  pushMatrix();
  translate(standX, -25, 0);
  fill(24, 42, 76);
  noStroke();
  box(96, 8, 92);

  translate(0, -28, 0);
  fill(218, 32, 32);
  stroke(245, 95, 95);
  box(86, 48, 76);

  translate(-6, -30, -14);
  rotateZ(HALF_PI);
  fill(130, 142, 158);
  noStroke();
  drawCylinderY(14, 14, 38, 16);
  popMatrix();

  float crankR = 20.0;
  float conRodL = 56.0;
  float cx = -112.0;
  float cy = 58.0;
  float pinX = cx + crankR * cos(crankAngle);
  float pinY = cy + crankR * sin(crankAngle);
  float pistonX = pinX + sqrt(max(100.0, conRodL * conRodL - (pinY - cy) * (pinY - cy)));

  pushMatrix();
  translate(cx, cy, 0);
  rotateZ(crankAngle);
  fill(62, 138, 82);
  stroke(95, 175, 115);
  drawCylinderZ(34, 34, 12, 24);
  fill(235, 185, 55);
  noStroke();
  translate(crankR * 0.72, 0, 8);
  sphere(4.5);
  popMatrix();

  drawPipeSegment3D(pinX, pinY, 0, pistonX, cy, 0, 4.2, color(220, 175, 60));

  // --------------------------------------------------------------------------
  // 4. GREEN SINGLE-ACTING RECIPROCATING PUMP & VALVE CHEST
  // --------------------------------------------------------------------------
  pushMatrix();
  translate(-34, cy, 0);
  rotateZ(HALF_PI);
  fill(120, 205, 155, 95);
  stroke(75, 175, 110);
  drawCylinderY(22, 22, 68, 22);
  popMatrix();

  pushMatrix();
  translate(pistonX, cy, 0);
  rotateZ(HALF_PI);
  fill(230, 130, 45);
  noStroke();
  drawCylinderY(19.5, 19.5, 14, 22);
  popMatrix();

  float chamberLeft = pistonX + 7;
  float chamberRight = 2;
  float chamberLen = max(6.0, chamberRight - chamberLeft);
  boolean isSuction = (sin(crankAngle) < 0);
  pushMatrix();
  translate((chamberLeft + chamberRight) * 0.5, cy, 0);
  rotateZ(HALF_PI);
  fill(isSuction ? color(30, 165, 245, 180) : color(245, 115, 45, 190));
  noStroke();
  drawCylinderY(18.5, 18.5, chamberLen, 20);
  popMatrix();

  pushMatrix();
  translate(14, 38, 0);
  fill(58, 134, 78);
  stroke(85, 165, 105);
  box(34, 68, 38);
  translate(0, -40, 0);
  noStroke();
  sphere(17);
  popMatrix();

  // --------------------------------------------------------------------------
  // 5. WHITE PIPING, BRASS VALVES, VACUUM & PRESSURE GAUGES
  // --------------------------------------------------------------------------
  drawPipeSegment3D(14, 72, 0, 14, 96, 0, 6.5, color(238, 242, 248));
  drawPipeSegment3D(14, 96, 0, 120, 96, 0, 6.5, color(238, 242, 248));
  drawPipeSegment3D(68, 96, 0, 115, 96, 0, 7.2, color(38, 135, 85));
  pushMatrix();
  translate(56, 96, 0);
  fill(205, 165, 55);
  noStroke();
  box(14, 16, 14);
  translate(0, -14, 0);
  drawCylinderY(9, 9, 3, 14);
  popMatrix();

  drawBourdonGauge3D(44, 68, 12, 28, 68, 0, liveVacHg / 200.0, color(60, 195, 255));

  drawPipeSegment3D(28, 48, 0, 44, 48, 0, 6.5, color(238, 242, 248));
  drawPipeSegment3D(44, 48, 0, 44, -124, 0, 6.5, color(238, 242, 248));

  drawBourdonGauge3D(78, -96, 12, 44, -96, 0, livePressKg / 2.5, color(255, 125, 65));

  drawPipeSegment3D(44, 8, 0, 68, 8, 0, 5, color(238, 242, 248));
  drawPipeSegment3D(68, 8, 0, 145, 36, 0, 5.2, color(38, 135, 85));

  drawPipeSegment3D(44, -124, 0, 205, -124, 0, 6.5, color(238, 242, 248));
  drawPipeSegment3D(205, -124, 0, 205, -52, 0, 6.5, color(238, 242, 248));

  pushMatrix();
  translate(118, -124, 0);
  fill(45, 52, 62);
  noStroke();
  box(18, 18, 18);
  translate(0, -14, 0);
  rotateY(map(liveHd, 4.0, 20.0, 0, TWO_PI * 1.5));
  fill(28, 32, 38);
  stroke(120, 135, 155);
  drawCylinderY(13, 13, 3.5, 16);
  popMatrix();

  drawPipeSegment3D(168, -124, -12, 168, -42, -18, 3.5, color(215, 35, 35));
  drawPipeSegment3D(168, -124,  12, 168, -42,  18, 3.5, color(215, 35, 35));
  pushMatrix();
  translate(205, -86, 0);
  fill(215, 35, 35);
  noStroke();
  drawCylinderY(11, 11, 8, 16);
  popMatrix();

  // --------------------------------------------------------------------------
  // 6. LOWER SUMP TANK & UPPER COLLECTING TANK + PIEZOMETER SCALE
  // --------------------------------------------------------------------------
  pushMatrix();
  translate(175, 84, 0);
  fill(195, 205, 218, 145);
  stroke(135, 150, 170);
  box(135, 84, 96);
  translate(0, 14, 0);
  fill(25, 155, 230, 195);
  noStroke();
  box(129, 52, 90);
  popMatrix();

  pushMatrix();
  translate(186, -2, 0);
  fill(210, 218, 228, 130);
  stroke(145, 165, 190);
  box(76, 92, 76);
  float wH = 84 * tankWaterLevel;
  translate(0, 44 - wH * 0.5, 0);
  fill(20, 175, 245, 205);
  noStroke();
  box(71, wH, 71);
  popMatrix();

  pushMatrix();
  translate(212, -2, 41);
  fill(245, 210, 65);
  noStroke();
  box(8, 84, 2);
  popMatrix();
  drawPipeSegment3D(204, 38, 42, 204, -40, 42, 2.5, color(235, 248, 255));
  pushMatrix();
  translate(204, 38 - 76 * tankWaterLevel * 0.5, 42);
  fill(0, 215, 255);
  noStroke();
  drawCylinderY(2.0, 2.0, 76 * tankWaterLevel, 10);
  popMatrix();

  // --------------------------------------------------------------------------
  // 7. ANIMATED 3D FLOW PARTICLES
  // --------------------------------------------------------------------------
  float flowSpeed = map(liveQa, 4.0e-4, 4.7e-4, 0.005, 0.011);
  noStroke();
  for (FlowParticle3D p : particles3D) {
    p.progress = (p.progress + flowSpeed * p.speedMult) % 1.0;
    PVector pos = getLoopPos3D(p.progress);
    fill(p.progress < 0.35 ? color(55, 215, 255) : color(255, 165, 55));
    pushMatrix();
    translate(pos.x, pos.y, pos.z + p.radialOffset * 0.35);
    sphere(3.2);
    popMatrix();
  }
}

PVector getLoopPos3D(float t) {
  if (t < 0.25) {
    float f = t / 0.25;
    return new PVector(lerp(120, 14, f), 96, 0);
  } else if (t < 0.38) {
    float f = (t - 0.25) / 0.13;
    return new PVector(lerp(14, 44, f), lerp(96, 48, f), 0);
  } else if (t < 0.68) {
    float f = (t - 0.38) / 0.30;
    return new PVector(44, lerp(48, -124, f), 0);
  } else if (t < 0.90) {
    float f = (t - 0.68) / 0.22;
    return new PVector(lerp(44, 205, f), -124, 0);
  } else {
    float f = (t - 0.90) / 0.10;
    return new PVector(205, lerp(-124, -30, f), 0);
  }
}

void drawBourdonGauge3D(float gx, float gy, float gz, float px, float py, float pz, float normVal, color rimCol) {
  drawPipeSegment3D(gx, gy, gz, px, py, pz, 2.8, color(185, 195, 210));
  pushMatrix();
  translate(gx, gy, gz);
  fill(45, 55, 70);
  stroke(rimCol);
  strokeWeight(1.5);
  drawCylinderZ(16, 16, 8, 20);
  translate(0, 0, 5);
  fill(245, 248, 252);
  noStroke();
  drawCylinderZ(13.5, 13.5, 2, 20);
  translate(0, 0, 1.5);
  rotateZ(lerp(-2.1, 2.1, constrain(normVal, 0, 1)));
  fill(220, 35, 35);
  box(2.0, 10.5, 2);
  popMatrix();
}

void drawPipeSegment3D(float x1, float y1, float z1, float x2, float y2, float z2, float r, color c) {
  PVector p1 = new PVector(x1, y1, z1);
  PVector p2 = new PVector(x2, y2, z2);
  PVector dir = PVector.sub(p2, p1);
  float len = dir.mag();
  if (len < 0.1) return;
  PVector mid = PVector.add(p1, p2).mult(0.5);
  pushMatrix();
  translate(mid.x, mid.y, mid.z);
  PVector up = new PVector(0, 1, 0);
  PVector axis = up.cross(dir);
  float angle = acos(constrain(up.dot(dir) / len, -1, 1));
  if (axis.mag() > 0.0001) {
    rotate(angle, axis.x, axis.y, axis.z);
  } else if (dir.y < 0) {
    rotateX(PI);
  }
  fill(c);
  noStroke();
  drawCylinderY(r, r, len, 14);
  popMatrix();
}

void drawCylinderY(float r1, float r2, float h, int sides) {
  float halfH = h * 0.5;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = TWO_PI * i / sides;
    float ca = cos(a);
    float sa = sin(a);
    vertex(ca * r1, -halfH, sa * r1);
    vertex(ca * r2, halfH, sa * r2);
  }
  endShape();
}

void drawCylinderZ(float r1, float r2, float d, int sides) {
  float halfD = d * 0.5;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = TWO_PI * i / sides;
    float ca = cos(a);
    float sa = sin(a);
    vertex(ca * r1, sa * r1, -halfD);
    vertex(ca * r2, sa * r2, halfD);
  }
  endShape();
  beginShape(TRIANGLE_FAN);
  vertex(0, 0, halfD);
  for (int i = 0; i <= sides; i++) {
    float a = TWO_PI * i / sides;
    vertex(cos(a) * r2, sin(a) * r2, halfD);
  }
  endShape();
}

void drawScreen1HUD() {
  float topY = arenaTop();
  float totalH = arenaH();
  float cardX = 12 * uiScale;
  float cardW = 300 * uiScale;

  float ctrlH = 102 * uiScale;
  float cardH = totalH - ctrlH - 8 * uiScale;

  // 1. Live Telemetry Card (Left)
  fill(16, 26, 42, 240);
  stroke(55, 115, 175);
  strokeWeight(1.5 * uiScale);
  rect(cardX, topY, cardW, cardH, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(12.5 * uiScale);
  text("LIVE RIG TELEMETRY (R" + rSlNo[selectedReading] + ")", cardX + 12 * uiScale, topY + 8 * uiScale);

  stroke(45, 75, 110);
  line(cardX + 10 * uiScale, topY + 26 * uiScale, cardX + cardW - 10 * uiScale, topY + 26 * uiScale);

  String[][] rows = {
    { "Cylinder D x Stroke L:", "40 mm x 45 mm" },
    { "Tank Area At / Rise h:", "0.09 m^2 / 0.10 m" },
    { "Vacuum Gauge (hs):", nf(liveVacHg, 1, 0) + " mm Hg (" + nf(liveHs, 1, 3) + " m)" },
    { "Pressure Gauge (pd):", nf(livePressKg, 1, 1) + " kg/cm^2 (" + nf(liveHd, 1, 1) + " m)" },
    { "Gauge Datum Diff (x):", "0.600 m" },
    { "Total Head (HT):", nf(liveHT, 1, 3) + " m of water" },
    { "Crank Speed (N):", nf(liveN, 1, 0) + " rpm (Single-Acting)" },
    { "Tank Rise Time (T):", nf(liveT, 1, 1) + " sec" },
    { "Actual Discharge (Qa):", nf(liveQa * 1e4, 1, 3) + " x10^-4 m^3/s" },
    { "Theo. Discharge (Qt):", "1.278 x10^-3 m^3/s" },
    { "Coeff. Discharge (Cd):", nf(liveCd, 1, 3) },
    { "Percentage Slip:", nf(liveSlipPct, 1, 1) + " %" },
    { "Energy Time (t, 5 rev):", nf(liveTimeE, 1, 2) + " sec" },
    { "Output / Input Power:", nf(livePo, 1, 4) + " / " + nf(livePi, 1, 3) + " kW" },
    { "Overall Efficiency:", nf(liveEffPct, 1, 2) + " %" }
  };

  float ry = topY + 32 * uiScale;
  float stepY = (cardH - 36 * uiScale) / float(rows.length);
  textSize(min(11 * uiScale, stepY * 0.72));
  for (int i = 0; i < rows.length; i++) {
    fill(165, 195, 225);
    textAlign(LEFT, TOP);
    text(rows[i][0], cardX + 12 * uiScale, ry);
    if (i == 5 || i == 8 || i == 10 || i == 14) fill(90, 240, 175);
    else fill(245, 250, 255);
    textAlign(RIGHT, TOP);
    text(rows[i][1], cardX + cardW - 12 * uiScale, ry);
    ry += stepY;
  }

  // 2. Bottom-Left Reading Selector & Camera Controls
  float ctrlY = topY + cardH + 8 * uiScale;
  fill(16, 26, 42, 240);
  stroke(55, 115, 175);
  rect(cardX, ctrlY, cardW, ctrlH, 8 * uiScale);

  fill(190, 215, 240);
  textAlign(LEFT, TOP);
  textSize(10.5 * uiScale);
  text("Select Lab Reading Row:", cardX + 12 * uiScale, ctrlY + 6 * uiScale);

  float pillW = (cardW - 24 * uiScale - 4 * 5 * uiScale) / 5.0;
  float pillH = 26 * uiScale;
  float py = ctrlY + 23 * uiScale;
  for (int i = 0; i < 5; i++) {
    float px = cardX + 12 * uiScale + i * (pillW + 5 * uiScale);
    fill(i == selectedReading ? color(0, 175, 220) : color(28, 42, 64));
    stroke(i == selectedReading ? color(150, 245, 255) : color(65, 95, 135));
    rect(px, py, pillW, pillH, 5 * uiScale);
    fill(i == selectedReading ? 10 : 235);
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text("R" + (i + 1), px + pillW * 0.5, py + pillH * 0.5);
  }

  float camY = ctrlY + 58 * uiScale;
  float camH = 32 * uiScale;
  float camW = (cardW - 24 * uiScale - 3 * 6 * uiScale) / 4.0;
  String[] camLabels = { autoOrbit ? "Orbit: ON" : "Orbit: OFF", "Zoom +", "Zoom -", "Reset" };
  for (int i = 0; i < 4; i++) {
    float bx = cardX + 12 * uiScale + i * (camW + 6 * uiScale);
    fill(i == 0 && autoOrbit ? color(30, 165, 115) : color(28, 42, 64));
    stroke(75, 115, 165);
    rect(bx, camY, camW, camH, 5 * uiScale);
    fill(245);
    textAlign(CENTER, CENTER);
    textSize(10 * uiScale);
    text(camLabels[i], bx + camW * 0.5, camY + camH * 0.5);
  }

  // 3. Enclosed 3D Viewport Border Frame & Controls (Right of Left Panel)
  float viewLeft = cardX + cardW + 10 * uiScale;
  float viewRight = width - 12 * uiScale;
  float viewW = viewRight - viewLeft;
  float viewCenterX = (viewLeft + viewRight) * 0.5;

  noFill();
  stroke(55, 115, 175);
  strokeWeight(1.8 * uiScale);
  rect(viewLeft, topY, viewW, totalH, 8 * uiScale);

  // Enclosed Viewport Top Header Bar
  fill(20, 34, 54, 235);
  stroke(55, 105, 160);
  strokeWeight(1.2 * uiScale);
  rect(viewLeft, topY, viewW, 30 * uiScale, 8 * uiScale, 8 * uiScale, 0, 0);

  fill(0, 195, 240);
  textAlign(LEFT, CENTER);
  textSize(11.5 * uiScale);
  text("3D RIG VIEWPORT — SINGLE-ACTING RECIPROCATING PUMP", viewLeft + 12 * uiScale, topY + 15 * uiScale);

  fill(175, 210, 240);
  textAlign(RIGHT, CENTER);
  textSize(10 * uiScale);
  text("Drag inside frame to Orbit  |  Zoom: " + nf(zoom3D, 1, 2) + "x", viewRight - 12 * uiScale, topY + 15 * uiScale);

  // Enclosed Bottom Delivery Valve Throttling Slider
  float slW = min(440 * uiScale, viewW - 24 * uiScale);
  float slH = 58 * uiScale;
  float slX = viewCenterX - slW * 0.5;
  float slY = arenaBot() - slH - 8 * uiScale;
  fill(18, 30, 48, 240);
  stroke(65, 125, 185);
  strokeWeight(1.5 * uiScale);
  rect(slX, slY, slW, slH, 8 * uiScale);

  fill(245, 200, 70);
  textAlign(CENTER, TOP);
  textSize(11 * uiScale);
  text("Delivery Valve Throttle -> Head Hd: " + nf(liveHd, 1, 1) + " m (" + nf(livePressKg, 1, 1) + " kg/cm^2)", viewCenterX, slY + 7 * uiScale);

  float trackX = slX + 18 * uiScale;
  float trackW = slW - 36 * uiScale;
  float trackY = slY + 38 * uiScale;
  stroke(55, 80, 115);
  strokeWeight(6 * uiScale);
  line(trackX, trackY, trackX + trackW, trackY);

  float norm = constrain((liveHd - 4.0) / 16.0, 0, 1);
  stroke(245, 150, 45);
  line(trackX, trackY, trackX + norm * trackW, trackY);

  fill(255, 215, 70);
  stroke(255);
  strokeWeight(2 * uiScale);
  ellipse(trackX + norm * trackW, trackY, 17 * uiScale, 17 * uiScale);
}

// ============================================================================
// SCREEN 2: 2D TRANSPARENT CUTAWAY & FLOW VISUALIZATION (CENTERED)
// ============================================================================
void drawScreen2_CutawayPhysics() {
  float arenaX = 12 * uiScale;
  float arenaY = arenaTop();
  float arenaW = width - 24 * uiScale;
  float aH = arenaH();

  fill(15, 23, 36);
  stroke(55, 105, 160);
  strokeWeight(1.5 * uiScale);
  rect(arenaX, arenaY, arenaW, aH, 8 * uiScale);

  // Header & Mode Buttons
  fill(0, 195, 240);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("2D CUTAWAY: SINGLE-ACTING RECIPROCATING PUMP & VALVE KINEMATICS", arenaX + 14 * uiScale, arenaY + 19 * uiScale);

  float btnW = 150 * uiScale;
  float btnH = 26 * uiScale;
  float bx1 = arenaX + arenaW - 2 * btnW - 20 * uiScale;
  float bx2 = arenaX + arenaW - btnW - 12 * uiScale;
  float by = arenaY + 6 * uiScale;

  fill(unsteadyMode ? color(215, 115, 35) : color(25, 145, 185));
  stroke(180, 230, 255);
  rect(bx1, by, btnW, btnH, 5 * uiScale);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(10.5 * uiScale);
  text(unsteadyMode ? "MODE: UNSTEADY" : "MODE: STEADY", bx1 + btnW * 0.5, by + btnH * 0.5);

  fill(34, 52, 78);
  stroke(90, 145, 200);
  rect(bx2, by, btnW, btnH, 5 * uiScale);
  fill(235);
  text("Reset Trails / Dye", bx2 + btnW * 0.5, by + btnH * 0.5);

  // Centered Pump Cutaway Geometry inside Arena
  float pumpLeft = arenaX + arenaW * 0.25;
  float pumpRight = arenaX + arenaW * 0.52;
  float cylTop = arenaY + aH * 0.36;
  float cylBot = arenaY + aH * 0.58;
  float cylMidY = (cylTop + cylBot) * 0.5;

  float crankCx = arenaX + arenaW * 0.72;
  float crankR = aH * 0.085;
  float rodLen = arenaW * 0.16;
  float theta = unsteadyMode ? crankAngle : HALF_PI;
  float pinX = crankCx + crankR * cos(theta);
  float pinY = cylMidY + crankR * sin(theta);
  float pistonX = pinX - sqrt(max(100.0, rodLen * rodLen - (pinY - cylMidY) * (pinY - cylMidY)));
  boolean suctionStroke = unsteadyMode ? (sin(theta) > 0) : false;

  // 1. Suction Pipe
  float pipeLeft = arenaX + arenaW * 0.09;
  float valveX = pumpLeft + (pumpRight - pumpLeft) * 0.25;
  float sucPipeY = arenaY + aH * 0.78;
  fill(22, 55, 92);
  stroke(75, 165, 235);
  strokeWeight(2 * uiScale);
  rect(pipeLeft, sucPipeY - 17 * uiScale, valveX - pipeLeft + 17 * uiScale, 34 * uiScale);
  rect(valveX - 17 * uiScale, cylBot, 34 * uiScale, sucPipeY - cylBot + 17 * uiScale);

  // 2. Delivery Pipe
  float delPipeY = arenaY + aH * 0.18;
  float delEndX = arenaX + arenaW * 0.89;
  fill(45, 32, 48);
  stroke(235, 130, 65);
  rect(valveX - 17 * uiScale, delPipeY - 17 * uiScale, 34 * uiScale, cylTop - delPipeY + 17 * uiScale);
  rect(valveX - 17 * uiScale, delPipeY - 17 * uiScale, delEndX - valveX, 34 * uiScale);

  // 3. Cylinder Barrel Cutaway
  fill(20, 38, 62);
  stroke(120, 210, 250);
  strokeWeight(2.5 * uiScale);
  rect(pumpLeft, cylTop, pumpRight - pumpLeft, cylBot - cylTop, 6 * uiScale);

  float chamberW = max(12 * uiScale, pistonX - pumpLeft - 14 * uiScale);
  noStroke();
  fill(suctionStroke ? color(30, 155, 235, 135) : color(235, 115, 45, 145));
  rect(pumpLeft + 2 * uiScale, cylTop + 2 * uiScale, chamberW, cylBot - cylTop - 4 * uiScale);

  // Suction Check Valve
  pushMatrix();
  translate(valveX - 14 * uiScale, cylBot);
  rotate(suctionStroke ? -0.65 : 0.0);
  fill(60, 220, 145);
  noStroke();
  rect(0, -4 * uiScale, 28 * uiScale, 8 * uiScale, 3 * uiScale);
  popMatrix();

  // Delivery Check Valve
  pushMatrix();
  translate(valveX - 14 * uiScale, cylTop);
  rotate(!suctionStroke ? -0.65 : 0.0);
  fill(250, 165, 50);
  noStroke();
  rect(0, -4 * uiScale, 28 * uiScale, 8 * uiScale, 3 * uiScale);
  popMatrix();

  // Piston Head + Connecting Rod + Crank Wheel
  fill(225, 125, 45);
  stroke(255, 200, 130);
  strokeWeight(1.5 * uiScale);
  rect(pistonX - 14 * uiScale, cylTop + 3 * uiScale, 28 * uiScale, cylBot - cylTop - 6 * uiScale, 4 * uiScale);

  noFill();
  stroke(115, 145, 180);
  strokeWeight(2 * uiScale);
  ellipse(crankCx, cylMidY, crankR * 2, crankR * 2);
  stroke(235, 185, 65);
  strokeWeight(4.5 * uiScale);
  line(crankCx, cylMidY, pinX, pinY);
  line(pinX, pinY, pistonX, cylMidY);
  fill(255, 215, 80);
  noStroke();
  ellipse(pinX, pinY, 10 * uiScale, 10 * uiScale);

  // Delivery Throttling Gate Valve
  float throtX = arenaX + arenaW * 0.56;
  float gateGap = map(liveHd, 4.0, 20.0, 24 * uiScale, 8 * uiScale);
  fill(220, 60, 60);
  rect(throtX - 8 * uiScale, delPipeY - 17 * uiScale, 16 * uiScale, (34 * uiScale - gateGap) * 0.5);
  rect(throtX - 8 * uiScale, delPipeY + 17 * uiScale - (34 * uiScale - gateGap) * 0.5, 16 * uiScale, (34 * uiScale - gateGap) * 0.5);

  // 4. Streamlines
  stroke(80, 220, 255, 85);
  strokeWeight(1.2 * uiScale);
  noFill();
  for (int s = -1; s <= 1; s++) {
    float off = s * 7.5 * uiScale;
    beginShape();
    vertex(pipeLeft + 10 * uiScale, sucPipeY + off);
    vertex(valveX + off, sucPipeY + off);
    vertex(valveX + off, cylMidY + off);
    vertex(valveX + off, delPipeY + off);
    vertex(delEndX - 10 * uiScale, delPipeY + off);
    endShape();
  }

  // 5. Velocity Profile Arrows
  float profX = arenaX + arenaW * 0.72;
  for (int k = -2; k <= 2; k++) {
    float py = delPipeY + k * 5.5 * uiScale;
    float parabolic = 1.0 - (k * k) / 6.25;
    float vLen = (14 + 24 * parabolic * (liveQa / 4.639e-4)) * uiScale;
    draw2DArrow(profX, py, profX + vLen, py, color(255, 220, 90));
  }

  // 6. Moving Particles + Lagrangian Pathlines
  float flowRateScale = liveQa / 4.639e-4;
  for (FluidParticle2D p : particles2D) {
    float px = arenaX + p.x * arenaW;
    float py = arenaY + p.y * aH;

    if (p.zone == 0) {
      float spd = (suctionStroke ? 0.0045 : 0.0012) * flowRateScale;
      p.x += spd;
      p.y = lerp(p.y, 0.78, 0.08);
      if (px >= valveX) p.zone = 1;
    } else if (p.zone == 1) {
      float spd = 0.0055 * flowRateScale;
      p.y -= spd;
      p.x = lerp(p.x, (valveX - arenaX) / arenaW + random(-0.01, 0.015), 0.1);
      if (py <= cylMidY) {
        if (random(1.0) < (1.0 - liveCd) * 0.38) p.zone = 3;
        else p.zone = 2;
      }
    } else if (p.zone == 2) {
      if (py > delPipeY) {
        p.y -= 0.006 * flowRateScale;
      } else {
        p.y = lerp(p.y, 0.18, 0.15);
        p.x += (!suctionStroke ? 0.0065 : 0.0022) * flowRateScale;
      }
      if (p.x > 0.88) p.respawn(false);
    } else {
      p.x += 0.0035;
      p.y = lerp(p.y, 0.47, 0.1);
      if (px > pistonX + 20 * uiScale) p.respawn(false);
    }

    p.trail.add(new PVector(px, py));
    if (p.trail.size() > 14) p.trail.remove(0);

    noFill();
    stroke(p.zone == 3 ? color(255, 85, 110, 120) : (p.zone == 2 ? color(255, 175, 65, 120) : color(65, 215, 255, 120)));
    strokeWeight(1.2 * uiScale);
    beginShape();
    for (PVector tv : p.trail) vertex(tv.x, tv.y);
    endShape();

    noStroke();
    fill(p.zone == 3 ? color(255, 80, 110) : (p.zone == 2 ? color(255, 190, 75) : color(80, 230, 255)));
    ellipse(px, py, 5 * uiScale, 5 * uiScale);
  }

  // 7. Interactive Streakline Dye Nozzle
  float nozX = arenaX + dyeNozzleX * arenaW;
  float nozY = arenaY + dyeNozzleY * aH;
  streaklinePts.add(new PVector(nozX, nozY));
  for (int i = streaklinePts.size() - 1; i >= 0; i--) {
    PVector sp = streaklinePts.get(i);
    if (sp.y > cylMidY && sp.x < valveX) sp.x += 2.2 * uiScale;
    else if (sp.y > delPipeY) sp.y -= 2.6 * uiScale;
    else sp.x += 3.1 * uiScale;
    if (sp.x > delEndX || streaklinePts.size() > 55) streaklinePts.remove(i);
  }
  noFill();
  stroke(120, 255, 140, 210);
  strokeWeight(2.2 * uiScale);
  beginShape();
  for (PVector sp : streaklinePts) vertex(sp.x, sp.y);
  endShape();
  fill(120, 255, 140);
  ellipse(nozX, nozY, 9 * uiScale, 9 * uiScale);

  // 8. Live Dial Gauges & Diagnostics Box
  draw2DDialGauge(arenaX + arenaW * 0.14, arenaY + aH * 0.56, 35 * uiScale, "VACUUM GAUGE", nf(liveVacHg, 1, 0) + " mmHg", liveVacHg / 200.0, color(60, 200, 255));
  draw2DDialGauge(arenaX + arenaW * 0.38, arenaY + aH * 0.25, 35 * uiScale, "PRESSURE GAUGE", nf(livePressKg, 1, 1) + " kg/cm2", livePressKg / 2.5, color(255, 130, 65));

  float qBoxW = 345 * uiScale;
  float qBoxH = 142 * uiScale;
  float qBoxX = arenaX + arenaW - qBoxW - 14 * uiScale;
  float qBoxY = arenaY + aH - qBoxH - 10 * uiScale;
  fill(18, 30, 48, 235);
  stroke(75, 145, 210);
  rect(qBoxX, qBoxY, qBoxW, qBoxH, 8 * uiScale);

  fill(0, 205, 245);
  textAlign(LEFT, TOP);
  textSize(11 * uiScale);
  text("CUTAWAY FLOW & SLIP DIAGNOSTICS (R" + rSlNo[selectedReading] + ")", qBoxX + 10 * uiScale, qBoxY + 7 * uiScale);

  fill(225, 238, 252);
  textSize(10.5 * uiScale);
  text("Stroke State: " + (suctionStroke ? "SUCTION (Inlet Open, -Hs)" : "DELIVERY (Outlet Open, +Hd)"), qBoxX + 10 * uiScale, qBoxY + 26 * uiScale);
  text("Theoretical Qt = " + nf(liveQt * 1e3, 1, 3) + " x10^-3 m^3/s", qBoxX + 10 * uiScale, qBoxY + 44 * uiScale);
  text("Actual Qa      = " + nf(liveQa * 1e4, 1, 3) + " x10^-4 m^3/s", qBoxX + 10 * uiScale, qBoxY + 62 * uiScale);
  fill(255, 115, 130);
  text("Slip (Qt - Qa) = " + nf((liveQt - liveQa) * 1e4, 1, 3) + " x10^-4 m^3/s (" + nf(liveSlipPct, 1, 1) + "%)", qBoxX + 10 * uiScale, qBoxY + 80 * uiScale);
  fill(120, 255, 145);
  text("Green Dye Nozzle: Tap anywhere in cutaway to relocate", qBoxX + 10 * uiScale, qBoxY + 100 * uiScale);
  fill(180, 205, 230);
  text("Blue=Suction | Amber=Delivery | Red=Ring/Valve Slip", qBoxX + 10 * uiScale, qBoxY + 118 * uiScale);
}

void draw2DDialGauge(float cx, float cy, float r, String label, String valStr, float norm, color c) {
  fill(22, 34, 52, 235);
  stroke(c);
  strokeWeight(2 * uiScale);
  ellipse(cx, cy, r * 2, r * 2);
  fill(245);
  noStroke();
  ellipse(cx, cy, r * 1.65, r * 1.65);

  float ang = lerp(-2.2, 2.2, constrain(norm, 0, 1)) - HALF_PI;
  stroke(220, 35, 35);
  strokeWeight(2.2 * uiScale);
  line(cx, cy, cx + cos(ang) * r * 0.68, cy + sin(ang) * r * 0.68);
  fill(30);
  noStroke();
  ellipse(cx, cy, 6 * uiScale, 6 * uiScale);

  fill(c);
  textAlign(CENTER, TOP);
  textSize(10 * uiScale);
  text(label, cx, cy + r + 4 * uiScale);
  fill(255);
  text(valStr, cx, cy + r + 16 * uiScale);
}

// ============================================================================
// SCREEN 3: 7-STEP MATHEMATICAL DERIVATION & HEAD ELEVATION SCHEMATIC
// ============================================================================
void drawScreen3_Derivation() {
  float topY = arenaTop();
  float botY = arenaBot();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.56;
  float rightW = (width - 34 * uiScale) * 0.44;
  float leftX = 12 * uiScale;
  float rightX = leftX + leftW + 10 * uiScale;

  // LEFT PANEL: 7-Step Derivation
  fill(16, 25, 40);
  stroke(55, 105, 160);
  strokeWeight(1.5 * uiScale);
  rect(leftX, topY, leftW, h, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(13 * uiScale);
  text("GOVERNING EQUATIONS & 7-STEP DERIVATION", leftX + 14 * uiScale, topY + 9 * uiScale);

  float stepStartY = topY + 34 * uiScale;
  float stepH = (h - 80 * uiScale) / 7.0;
  for (int i = 0; i < 7; i++) {
    float sy = stepStartY + i * stepH;
    boolean active = (i == derivStep);
    fill(active ? color(24, 58, 92) : color(20, 31, 48));
    stroke(active ? color(0, 215, 255) : color(45, 70, 105));
    strokeWeight(active ? 2 * uiScale : 1 * uiScale);
    rect(leftX + 34 * uiScale, sy + 2 * uiScale, leftW - 46 * uiScale, stepH - 4 * uiScale, 6 * uiScale);

    if (active) {
      float pulse = sin(simTime * 6.0) * 4 * uiScale;
      draw2DArrow(leftX + 8 * uiScale + pulse, sy + stepH * 0.5, leftX + 30 * uiScale + pulse, sy + stepH * 0.5, color(255, 210, 60));
    }

    float lineSpacing = (stepH - 8 * uiScale) / 3.0;
    fill(active ? color(255, 220, 80) : color(145, 185, 225));
    textAlign(LEFT, TOP);
    textSize(min(11 * uiScale, lineSpacing * 0.78));
    text(derivTitles[i], leftX + 42 * uiScale, sy + 4 * uiScale);

    fill(active ? color(255) : color(215, 230, 245));
    textSize(min(11.2 * uiScale, lineSpacing * 0.80));
    text(derivFormulas[i], leftX + 42 * uiScale, sy + 4 * uiScale + lineSpacing);

    fill(140, 225, 175);
    textSize(min(10 * uiScale, lineSpacing * 0.74));
    text(derivNotes[i], leftX + 42 * uiScale, sy + 4 * uiScale + 2 * lineSpacing);
  }

  // Bottom controls on Left Panel
  float btnY = botY - 38 * uiScale;
  float btnH = 28 * uiScale;
  float bW = (leftW - 48 * uiScale) / 3.0;
  String[] dBtns = { "< Prev Step", "Next Step >", autoDerive ? "Auto-Derive: ON" : "Auto-Derive: OFF" };
  for (int i = 0; i < 3; i++) {
    float bx = leftX + 12 * uiScale + i * (bW + 12 * uiScale);
    fill(i == 2 && autoDerive ? color(30, 165, 115) : color(30, 48, 74));
    stroke(80, 130, 185);
    rect(bx, btnY, bW, btnH, 5 * uiScale);
    fill(245);
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text(dBtns[i], bx + bW * 0.5, btnY + btnH * 0.5);
  }

  // RIGHT PANEL: Centered Head Ladder Diagram & Final Working Equations
  fill(16, 25, 40);
  stroke(55, 105, 160);
  rect(rightX, topY, rightW, h, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(12.5 * uiScale);
  text("HEAD & POWER BALANCE SCHEMATIC (R" + rSlNo[selectedReading] + ")", rightX + 14 * uiScale, topY + 9 * uiScale);

  float diagX = rightX + 24 * uiScale;
  float diagW = rightW - 48 * uiScale;
  float baseLineY = topY + h * 0.60;

  stroke(70, 165, 235);
  strokeWeight(2 * uiScale);
  line(diagX, baseLineY, diagX + diagW, baseLineY);
  fill(120, 200, 255);
  textSize(10.5 * uiScale);
  text("Sump Water Level Datum (Z = 0.000 m)", diagX, baseLineY + 5 * uiScale);

  float barX = diagX + 24 * uiScale;
  float barW = 54 * uiScale;
  float maxBarH = h * 0.45;
  float scaleM = maxBarH / 24.0;

  float hHs = liveHs * scaleM;
  float hX  = GAUGE_DATUM_X * scaleM * 3.0;
  float hHd = liveHd * scaleM;

  fill(45, 165, 235);
  noStroke();
  rect(barX, baseLineY - hHs, barW, hHs);
  fill(245, 205, 65);
  rect(barX, baseLineY - hHs - hX, barW, hX);
  fill(240, 115, 55);
  rect(barX, baseLineY - hHs - hX - hHd, barW, hHd);

  float lblX = barX + barW + 14 * uiScale;
  textAlign(LEFT, CENTER);
  textSize(10.8 * uiScale);
  fill(80, 200, 255);
  text("Hs = " + nf(liveHs, 1, 3) + " m (Suction Head)", lblX, baseLineY - hHs * 0.5);
  fill(245, 210, 75);
  text("x  = 0.600 m (Gauge Offset)", lblX, baseLineY - hHs - hX * 0.5);
  fill(255, 145, 80);
  text("Hd = " + nf(liveHd, 1, 1) + " m (Delivery Head)", lblX, baseLineY - hHs - hX - hHd * 0.5);

  stroke(120, 255, 165);
  line(barX - 8 * uiScale, baseLineY - hHs - hX - hHd, rightX + rightW - 22 * uiScale, baseLineY - hHs - hX - hHd);
  fill(120, 255, 165);
  text("TOTAL HEAD HT = " + nf(liveHT, 1, 3) + " m", lblX, baseLineY - hHs - hX - hHd - 12 * uiScale);

  float fBoxY = baseLineY + 28 * uiScale;
  float fBoxH = botY - fBoxY - 10 * uiScale;
  fill(22, 38, 60);
  stroke(0, 200, 240);
  strokeWeight(1.5 * uiScale);
  rect(rightX + 14 * uiScale, fBoxY, rightW - 28 * uiScale, fBoxH, 8 * uiScale);

  fill(255, 220, 80);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text("WORKING EQUATIONS & ACTIVE RESULTS (R" + rSlNo[selectedReading] + ")", rightX + 24 * uiScale, fBoxY + 8 * uiScale);

  fill(235, 245, 255);
  textSize(11 * uiScale);
  float fy = fBoxY + 28 * uiScale;
  float fStep = (fBoxH - 34 * uiScale) / 5.0;
  text("1. Qt = (A x L x N)/60 = 1.278 x 10^-3 m^3/s", rightX + 24 * uiScale, fy);
  text("2. Qa = (At x h)/T = " + nf(liveQa * 1e4, 1, 3) + " x 10^-4 m^3/s", rightX + 24 * uiScale, fy + fStep);
  text("3. Cd = Qa / Qt = " + nf(liveCd, 1, 3) + "   |   % Slip = " + nf(liveSlipPct, 1, 1) + "%", rightX + 24 * uiScale, fy + 2 * fStep);
  text("4. Po = 9.81 x Qa x HT = " + nf(livePo, 1, 4) + " kW", rightX + 24 * uiScale, fy + 3 * fStep);
  fill(110, 250, 175);
  text("5. eta = (Po / Pi) x 100 = " + nf(liveEffPct, 1, 2) + "%", rightX + 24 * uiScale, fy + 4 * fStep);
}

// ============================================================================
// SCREEN 4: 6-STEP LAB PROCEDURE & DUAL ZOOMED INSTRUMENT CARDS
// ============================================================================
void drawScreen4_Procedure() {
  float topY = arenaTop();
  float botY = arenaBot();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.48;
  float rightW = (width - 34 * uiScale) * 0.52;
  float leftX = 12 * uiScale;
  float rightX = leftX + leftW + 10 * uiScale;

  // LEFT PANEL: 6-Step Experimental Procedure
  fill(16, 25, 40);
  stroke(55, 105, 160);
  strokeWeight(1.5 * uiScale);
  rect(leftX, topY, leftW, h, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(13 * uiScale);
  text("EXPERIMENTAL PROCEDURE (6 LAB STEPS)", leftX + 14 * uiScale, topY + 9 * uiScale);

  float stepStartY = topY + 34 * uiScale;
  float stepH = (h - 80 * uiScale) / 6.0;
  for (int i = 0; i < 6; i++) {
    float sy = stepStartY + i * stepH;
    boolean active = (i == procStep);
    fill(active ? color(24, 58, 92) : color(20, 31, 48));
    stroke(active ? color(0, 215, 255) : color(45, 70, 105));
    strokeWeight(active ? 2 * uiScale : 1 * uiScale);
    rect(leftX + 34 * uiScale, sy + 2 * uiScale, leftW - 46 * uiScale, stepH - 5 * uiScale, 6 * uiScale);

    if (active) {
      float pulse = sin(simTime * 6.0) * 4 * uiScale;
      draw2DArrow(leftX + 8 * uiScale + pulse, sy + stepH * 0.5, leftX + 30 * uiScale + pulse, sy + stepH * 0.5, color(120, 255, 150));
    }

    fill(active ? color(120, 255, 150) : color(155, 195, 235));
    textAlign(LEFT, TOP);
    textSize(11.2 * uiScale);
    text(procTitles[i], leftX + 42 * uiScale, sy + 5 * uiScale);

    fill(active ? 245 : 195);
    textSize(10 * uiScale);
    text(procDetails[i], leftX + 42 * uiScale, sy + 21 * uiScale, leftW - 60 * uiScale, stepH - 24 * uiScale);
  }

  float btnY = botY - 38 * uiScale;
  fill(autoProc ? color(30, 165, 115) : color(30, 48, 74));
  stroke(80, 130, 185);
  rect(leftX + 14 * uiScale, btnY, leftW - 28 * uiScale, 28 * uiScale, 5 * uiScale);
  fill(245);
  textAlign(CENTER, CENTER);
  textSize(11 * uiScale);
  text(autoProc ? "Auto-Demo Walkthrough: ON (Tap any step to inspect)" : "Auto-Demo Walkthrough: OFF (Tap to start)", leftX + leftW * 0.5, btnY + 14 * uiScale);

  // RIGHT PANEL: Two Centered Zoomed Measurement Instrument Cards
  float cardH = (h - 10 * uiScale) * 0.5;

  // CARD 1 (Top Right)
  fill(16, 25, 40);
  stroke(55, 105, 160);
  rect(rightX, topY, rightW, cardH, 8 * uiScale);

  fill(255, 205, 70);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("INSTRUMENT 1: VACUUM/PRESSURE GAUGES & ENERGY METER", rightX + 14 * uiScale, topY + 9 * uiScale);

  float gY = topY + cardH * 0.52;
  draw2DDialGauge(rightX + rightW * 0.20, gY, 42 * uiScale, "SUCTION VACUUM", nf(liveVacHg, 1, 0) + " mmHg", liveVacHg / 200.0, color(60, 200, 255));
  draw2DDialGauge(rightX + rightW * 0.50, gY, 42 * uiScale, "DELIVERY PRESS.", nf(livePressKg, 1, 1) + " kg/cm2", livePressKg / 2.5, color(255, 130, 65));

  float emX = rightX + rightW * 0.80;
  fill(28, 38, 54);
  stroke(120, 150, 185);
  rect(emX - 58 * uiScale, gY - 44 * uiScale, 116 * uiScale, 88 * uiScale, 6 * uiScale);
  fill(215, 240, 250);
  noStroke();
  rect(emX - 46 * uiScale, gY - 20 * uiScale, 92 * uiScale, 26 * uiScale, 3 * uiScale);
  float stripX = emX + cos(discAngle) * 34 * uiScale;
  fill(140, 155, 170);
  rect(emX - 40 * uiScale, gY - 10 * uiScale, 80 * uiScale, 6 * uiScale);
  fill(235, 45, 45);
  rect(stripX - 4 * uiScale, gY - 11 * uiScale, 8 * uiScale, 8 * uiScale);

  fill(120, 255, 165);
  textAlign(CENTER, TOP);
  textSize(10.5 * uiScale);
  text("ENERGY METER", emX, gY + 13 * uiScale);
  fill(245);
  text("5 rev = " + nf(liveTimeE, 1, 2) + " s", emX, gY + 27 * uiScale);

  // CARD 2 (Bottom Right)
  float c2Y = topY + cardH + 10 * uiScale;
  fill(16, 25, 40);
  stroke(55, 105, 160);
  rect(rightX, c2Y, rightW, cardH, 8 * uiScale);

  fill(0, 210, 245);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("INSTRUMENT 2: COLLECTING TANK PIEZOMETER & STOPWATCH", rightX + 14 * uiScale, c2Y + 9 * uiScale);

  float tkX = rightX + 24 * uiScale;
  float tkY = c2Y + 36 * uiScale;
  float tkW = rightW * 0.44;
  float tkH = cardH - 50 * uiScale;
  fill(22, 42, 68);
  stroke(100, 185, 240);
  rect(tkX, tkY, tkW, tkH, 4 * uiScale);

  float riseFrac = (simTime * (1.0 / liveT) * 3.5) % 1.0;
  float waterH = tkH * (0.20 + 0.65 * riseFrac);
  fill(30, 175, 245, 190);
  noStroke();
  rect(tkX + 2 * uiScale, tkY + tkH - waterH, tkW - 4 * uiScale, waterH - 2 * uiScale);

  float y0 = tkY + tkH * 0.80;
  float y10 = tkY + tkH * 0.15;
  stroke(255, 220, 80);
  strokeWeight(1.5 * uiScale);
  line(tkX, y0, tkX + tkW, y0);
  line(tkX, y10, tkX + tkW, y10);
  fill(255, 220, 80);
  textAlign(LEFT, BOTTOM);
  textSize(10 * uiScale);
  text("0.0 cm (Start)", tkX + 8 * uiScale, y0 - 2 * uiScale);
  text("10.0 cm = 0.10 m (Stop)", tkX + 8 * uiScale, y10 - 2 * uiScale);

  float swX = tkX + tkW + 22 * uiScale;
  float swW = rightW - tkW - 60 * uiScale;
  fill(22, 32, 48);
  stroke(110, 225, 165);
  rect(swX, tkY + 4 * uiScale, swW, tkH - 8 * uiScale, 8 * uiScale);

  fill(170, 205, 235);
  textAlign(CENTER, TOP);
  textSize(10.5 * uiScale);
  text("DIGITAL STOPWATCH (h = 0.1 m)", swX + swW * 0.5, tkY + 12 * uiScale);

  float elapsedT = riseFrac * liveT;
  fill(110, 255, 155);
  textSize(23 * uiScale);
  text(nf(elapsedT, 2, 2) + " s", swX + swW * 0.5, tkY + 34 * uiScale);

  fill(245);
  textSize(10.8 * uiScale);
  text("Target T (R" + rSlNo[selectedReading] + ") = " + nf(liveT, 1, 1) + " sec", swX + swW * 0.5, tkY + 68 * uiScale);
  fill(0, 215, 250);
  text("Qa = (0.09 x 0.1) / " + nf(liveT, 1, 1), swX + swW * 0.5, tkY + 87 * uiScale);
  text("   = " + nf(liveQa * 1e4, 1, 3) + " x10^-4 m^3/s", swX + swW * 0.5, tkY + 104 * uiScale);
}

// ============================================================================
// SCREEN 5: 8-STEP BODMAS BREAKDOWN & 47-KEY CASIO fx-991MS CALCULATOR
// ============================================================================
void drawScreen5_CasioCalc() {
  float topY = arenaTop();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.53;
  float rightW = (width - 34 * uiScale) * 0.47;
  float leftX = 12 * uiScale;
  float rightX = leftX + leftW + 10 * uiScale;

  // LEFT PANEL: 8-Step BODMAS Breakdown
  fill(16, 25, 40);
  stroke(55, 105, 160);
  strokeWeight(1.5 * uiScale);
  rect(leftX, topY, leftW, h, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(12.5 * uiScale);
  text("BODMAS STEP-BY-STEP CALCULATION (R" + rSlNo[selectedReading] + ")", leftX + 14 * uiScale, topY + 9 * uiScale);

  String[] bLetters = { "B", "O", "D", "M", "A", "S" };
  String[] bWords   = { "Brackets", "Orders", "Divide", "Multiply", "Add", "Subtract" };
  float badgeW = (leftW - 28 * uiScale - 5 * 6 * uiScale) / 6.0;
  for (int i = 0; i < 6; i++) {
    float bx = leftX + 14 * uiScale + i * (badgeW + 6 * uiScale);
    boolean activeB = bodmasBadges[bodmasStep].equals(bLetters[i]);
    fill(activeB ? color(245, 175, 40) : color(28, 42, 64));
    stroke(activeB ? color(255, 235, 140) : color(65, 95, 135));
    rect(bx, topY + 30 * uiScale, badgeW, 23 * uiScale, 4 * uiScale);
    fill(activeB ? 15 : 225);
    textAlign(CENTER, CENTER);
    textSize(10 * uiScale);
    text(bLetters[i] + ":" + bWords[i], bx + badgeW * 0.5, topY + 41.5 * uiScale);
  }

  String[] pluggedRows = {
    "Qt = (0.0012 x 0.045 x 1420) / 60 = 1.278 x 10^-3 m^3/s",
    "Qa = (0.09 x 0.10) / " + nf(liveT, 1, 1) + " = " + nf(liveQa * 1e4, 1, 3) + " x 10^-4 m^3/s",
    "Cd = (" + nf(liveQa * 1e4, 1, 3) + " x 10^-4) / (1.278 x 10^-3) = " + nf(liveCd, 1, 3),
    "% Slip = (1 - " + nf(liveCd, 1, 3) + ") x 100 = " + nf(liveSlipPct, 1, 1) + " %",
    "HT = " + nf(liveHs, 1, 3) + " + " + nf(liveHd, 1, 1) + " + 0.600 = " + nf(liveHT, 1, 3) + " m",
    "Po = 9.81 x " + nf(liveQa * 1e4, 1, 3) + "x10^-4 x " + nf(liveHT, 1, 3) + " = " + nf(livePo, 1, 4) + " kW",
    "Pi = (5 / 1200) x (3600 / " + nf(liveTimeE, 1, 2) + ") x 0.8 = " + nf(livePi, 1, 3) + " kW",
    "eta = (" + nf(livePo, 1, 4) + " / " + nf(livePi, 1, 3) + ") x 100 = " + nf(liveEffPct, 1, 2) + " %"
  };

  float rStartY = topY + 60 * uiScale;
  float rH = (h - 68 * uiScale) / 8.0;
  for (int i = 0; i < 8; i++) {
    float ry = rStartY + i * rH;
    boolean active = (i == bodmasStep);
    fill(active ? color(26, 62, 98) : color(20, 31, 48));
    stroke(active ? color(0, 220, 255) : color(45, 70, 105));
    strokeWeight(active ? 1.8 * uiScale : 1 * uiScale);
    rect(leftX + 34 * uiScale, ry + 2 * uiScale, leftW - 46 * uiScale, rH - 4 * uiScale, 5 * uiScale);

    if (active) {
      float pulse = sin(simTime * 6.0) * 4 * uiScale;
      draw2DArrow(leftX + 8 * uiScale + pulse, ry + rH * 0.5, leftX + 30 * uiScale + pulse, ry + rH * 0.5, color(255, 210, 60));
    }

    float lineStep = (rH - 6 * uiScale) / 2.0;
    fill(active ? color(255, 220, 80) : color(145, 185, 225));
    textAlign(LEFT, TOP);
    textSize(min(10.5 * uiScale, lineStep * 0.78));
    text(bodmasLabels[i], leftX + 42 * uiScale, ry + 3 * uiScale);

    fill(active ? color(120, 255, 165) : color(225, 238, 252));
    textSize(min(11 * uiScale, lineStep * 0.82));
    text(pluggedRows[i], leftX + 42 * uiScale, ry + 3 * uiScale + lineStep);
  }

  // RIGHT PANEL: Authentic 47-Key Casio fx-991MS S-V.P.A.M. Scientific Calculator
  drawCasioFX991MS(rightX, topY, rightW, h);
}

void drawCasioFX991MS(float cx, float cy, float cw, float ch) {
  fill(34, 44, 62);
  stroke(95, 115, 145);
  strokeWeight(2 * uiScale);
  rect(cx, cy, cw, ch, 14 * uiScale);

  fill(235, 240, 248);
  textAlign(LEFT, TOP);
  textSize(12.5 * uiScale);
  text("CASIO", cx + 16 * uiScale, cy + 9 * uiScale);
  fill(175, 200, 230);
  textSize(10 * uiScale);
  text("fx-991MS", cx + 70 * uiScale, cy + 11 * uiScale);
  fill(245, 195, 75);
  text("S-V.P.A.M.", cx + 132 * uiScale, cy + 11 * uiScale);

  float solW = 90 * uiScale;
  float solH = 18 * uiScale;
  float solX = cx + cw - solW - 16 * uiScale;
  fill(58, 38, 32);
  stroke(130, 145, 165);
  rect(solX, cy + 8 * uiScale, solW, solH, 3 * uiScale);
  for (int c = 1; c < 4; c++) {
    line(solX + c * (solW / 4.0), cy + 8 * uiScale, solX + c * (solW / 4.0), cy + 8 * uiScale + solH);
  }

  float lcdX = cx + 16 * uiScale;
  float lcdY = cy + 31 * uiScale;
  float lcdW = cw - 32 * uiScale;
  float lcdH = 52 * uiScale;
  fill(178, 196, 174);
  stroke(22, 28, 38);
  strokeWeight(2.5 * uiScale);
  rect(lcdX, lcdY, lcdW, lcdH, 5 * uiScale);

  fill(25, 38, 28);
  textAlign(LEFT, TOP);
  textSize(8.5 * uiScale);
  text("S   A   D   SCI   SVPAM", lcdX + 8 * uiScale, lcdY + 3 * uiScale);

  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text(calcExpr, lcdX + 10 * uiScale, lcdY + 15 * uiScale);

  textAlign(RIGHT, BOTTOM);
  textSize(15 * uiScale);
  text(calcAns, lcdX + lcdW - 10 * uiScale, lcdY + lcdH - 4 * uiScale);

  float topCtrlY = lcdY + lcdH + 9 * uiScale;
  float pillW = (lcdW - 86 * uiScale) / 4.0;
  float pillH = 20 * uiScale;

  drawCasioPill(lcdX, topCtrlY, pillW, pillH, "SHIFT", color(220, 175, 55), color(25));
  drawCasioPill(lcdX + pillW + 6 * uiScale, topCtrlY, pillW, pillH, "ALPHA", color(205, 75, 85), color(255));

  float repX = lcdX + 2 * pillW + 14 * uiScale;
  float repW = 58 * uiScale;
  fill(145, 160, 180);
  stroke(210, 225, 240);
  ellipse(repX + repW * 0.5, topCtrlY + pillH * 0.5, repW, pillH + 7 * uiScale);
  fill(25);
  textAlign(CENTER, CENTER);
  textSize(8.5 * uiScale);
  text("REPLAY", repX + repW * 0.5, topCtrlY + pillH * 0.5);

  drawCasioPill(repX + repW + 8 * uiScale, topCtrlY, pillW, pillH, "MODE", color(75, 90, 115), color(245));
  drawCasioPill(repX + repW + pillW + 14 * uiScale, topCtrlY, pillW, pillH, "ON", color(75, 90, 115), color(245));

  float keypadTop = topCtrlY + pillH + 12 * uiScale;
  float keypadBot = cy + ch - 24 * uiScale;
  float totalKeyAreaH = keypadBot - keypadTop;
  float sciAreaH = totalKeyAreaH * 0.46;
  float numAreaH = totalKeyAreaH * 0.54;

  String[][] sciKeys = {
    { "x^-1", "nCr", "Pol(", "x^3", "ab/c", "sqrt" },
    { "x^2",  "^",   "log", "ln",  "(-)",  "hyp"  },
    { "sin",  "cos", "tan", "RCL", "ENG" },
    { "(",    ")",   ",",   "M+",  "S-D" }
  };
  String[][] sciShift = {
    { "x!",   "nPr", "Rec(", "3rt", "d/c", " " },
    { " ",    "xrt", "10^x", "e^x", "A",   "B" },
    { "sin-1","cos-1","tan-1","STO","<-" },
    { " ",    " ",   ";",   "M-",  " " }
  };

  float sciGapY = 9 * uiScale;
  float sciRowH = (sciAreaH - 4 * sciGapY) / 4.0;
  for (int r = 0; r < 4; r++) {
    int cols = sciKeys[r].length;
    float kw = (lcdW - (cols - 1) * 5 * uiScale) / cols;
    float ky = keypadTop + r * (sciRowH + sciGapY);
    for (int c = 0; c < cols; c++) {
      float kx = lcdX + c * (kw + 5 * uiScale);
      String lbl = sciKeys[r][c];
      boolean isHighlight = lbl.equals(activeCasioKey);

      fill(235, 190, 75);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(sciShift[r][c], kx + kw * 0.5, ky - 1 * uiScale);

      fill(isHighlight ? color(250, 195, 45) : color(48, 58, 78));
      stroke(isHighlight ? color(255, 255, 200) : color(85, 100, 125));
      rect(kx, ky, kw, sciRowH, 4 * uiScale);
      fill(isHighlight ? 15 : 240);
      textAlign(CENTER, CENTER);
      textSize(9 * uiScale);
      text(lbl, kx + kw * 0.5, ky + sciRowH * 0.5);

      if (isHighlight) drawBouncingRedArrow(kx + kw * 0.5, ky - 3 * uiScale);
    }
  }

  String[][] numKeys = {
    { "7", "8", "9", "DEL", "AC" },
    { "4", "5", "6", "x",   "/"  },
    { "1", "2", "3", "+",   "-"  },
    { "0", ".", "EXP", "Ans", "=" }
  };
  String[][] numShift = {
    { "CONST", "CONV", "CLR", "INS", "OFF" },
    { "MAT",   "VCT",  " ",   " ",   " "   },
    { "STAT",  "CMPLX","BASE"," ",   " "   },
    { "Rnd",   "Ran#", "pi",  "DRG", "%"   }
  };

  float numStartY = keypadTop + sciAreaH + 2 * uiScale;
  float numGapY = 9 * uiScale;
  float numRowH = (numAreaH - 3 * numGapY) / 4.0;
  float numColW = (lcdW - 4 * 6 * uiScale) / 5.0;

  for (int r = 0; r < 4; r++) {
    float ky = numStartY + r * (numRowH + numGapY);
    for (int c = 0; c < 5; c++) {
      float kx = lcdX + c * (numColW + 6 * uiScale);
      String lbl = numKeys[r][c];
      boolean isHighlight = lbl.equals(activeCasioKey);

      fill(235, 190, 75);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(numShift[r][c], kx + numColW * 0.5, ky - 1 * uiScale);

      if (isHighlight) fill(250, 195, 45);
      else if (lbl.equals("DEL") || lbl.equals("AC")) fill(185, 65, 75);
      else if (c >= 3) fill(68, 82, 108);
      else fill(195, 205, 220);

      stroke(isHighlight ? color(255, 255, 200) : color(95, 110, 135));
      rect(kx, ky, numColW, numRowH, 5 * uiScale);

      fill((c < 3 && !isHighlight) ? 20 : (isHighlight ? 15 : 250));
      textAlign(CENTER, CENTER);
      textSize(11 * uiScale);
      text(lbl, kx + numColW * 0.5, ky + numRowH * 0.5);

      if (isHighlight) drawBouncingRedArrow(kx + numColW * 0.5, ky - 3 * uiScale);
    }
  }

  fill(175, 215, 245);
  textAlign(CENTER, CENTER);
  textSize(9.8 * uiScale);
  text("Keystroke: " + calcExpr + "  [ = ]  -->  " + calcAns, cx + cw * 0.5, cy + ch - 11 * uiScale);
}

void drawCasioPill(float x, float y, float w, float h, String txt, color bg, color fg) {
  fill(bg);
  stroke(210, 220, 235);
  strokeWeight(1 * uiScale);
  rect(x, y, w, h, h * 0.5);
  fill(fg);
  textAlign(CENTER, CENTER);
  textSize(9 * uiScale);
  text(txt, x + w * 0.5, y + h * 0.5);
}

void drawBouncingRedArrow(float x, float y) {
  float bounce = abs(sin(simTime * 6.5)) * 5 * uiScale;
  fill(245, 55, 55);
  noStroke();
  triangle(x, y - bounce, x - 5.5 * uiScale, y - 10 * uiScale - bounce, x + 5.5 * uiScale, y - 10 * uiScale - bounce);
}

// ============================================================================
// SCREEN 6: COMPLETE OBSERVATION TABLE & LAB-ACCURATE GRAPH SHEET
// ============================================================================
void drawScreen6_TableAndGraph() {
  float topY = arenaTop();
  float botY = arenaBot();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.54;
  float rightW = (width - 34 * uiScale) * 0.46;
  float leftX = 12 * uiScale;
  float rightX = leftX + leftW + 10 * uiScale;

  // LEFT PANEL: Full Observation Table
  fill(16, 25, 40);
  stroke(55, 105, 160);
  strokeWeight(1.5 * uiScale);
  rect(leftX, topY, leftW, h, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(12.5 * uiScale);
  text("OBSERVATION TABLE — RECIPROCATING PUMP (TAP ROW TO SYNC)", leftX + 12 * uiScale, topY + 9 * uiScale);

  String[] cols = { "Sl", "hs", "Hs", "pd", "Hd", "HT", "T", "Qa(e-4)", "Cd", "Slip%", "t(5r)", "Po", "Pi", "Eff%" };
  float[] colWeights = { 0.7, 1.0, 1.2, 0.9, 0.9, 1.3, 1.0, 1.4, 1.1, 1.1, 1.1, 1.2, 1.1, 1.2 };
  float totalWeight = 0;
  for (float w : colWeights) totalWeight += w;

  float tblX = leftX + 8 * uiScale;
  float tblW = leftW - 16 * uiScale;
  float hdrY = topY + 32 * uiScale;
  float hdrH = 28 * uiScale;

  fill(28, 52, 84);
  stroke(75, 125, 180);
  rect(tblX, hdrY, tblW, hdrH, 4 * uiScale);

  float curX = tblX;
  fill(255, 220, 85);
  textAlign(CENTER, CENTER);
  textSize(9.5 * uiScale);
  for (int c = 0; c < cols.length; c++) {
    float cw = tblW * (colWeights[c] / totalWeight);
    text(cols[c], curX + cw * 0.5, hdrY + hdrH * 0.5);
    curX += cw;
  }

  float resH = 98 * uiScale;
  float availRowsH = (botY - 10 * uiScale - resH - 10 * uiScale) - (hdrY + hdrH + 4 * uiScale);
  float rowH = (availRowsH - 4 * 4 * uiScale) / float(numReadings);

  for (int r = 0; r < numReadings; r++) {
    float ry = hdrY + hdrH + 4 * uiScale + r * (rowH + 4 * uiScale);
    boolean sel = (r == selectedReading);
    fill(sel ? color(0, 145, 195) : color(22, 34, 52));
    stroke(sel ? color(150, 245, 255) : color(50, 75, 110));
    strokeWeight(sel ? 1.8 * uiScale : 1 * uiScale);
    rect(tblX, ry, tblW, rowH, 5 * uiScale);

    String[] vals = {
      "R" + rSlNo[r],
      nf(rVacHg[r], 1, 0),
      nf(rHs[r], 1, 3),
      nf(rPressKg[r], 1, 1),
      nf(rHd[r], 1, 0),
      nf(rHT[r], 1, 3),
      nf(rTimeT[r], 1, 1),
      nf(rQa[r] * 1e4, 1, 3),
      nf(rCd[r], 1, 3),
      nf(rSlipPct[r], 1, 1),
      nf(rTimeE[r], 1, 2),
      nf(rPo[r], 1, 4),
      nf(rPi[r], 1, 3),
      nf(rEffPct[r], 1, 2)
    };

    curX = tblX;
    fill(sel ? 10 : 235);
    textSize(10 * uiScale);
    for (int c = 0; c < vals.length; c++) {
      float cw = tblW * (colWeights[c] / totalWeight);
      text(vals[c], curX + cw * 0.5, ry + rowH * 0.5);
      curX += cw;
    }
  }

  // Bottom Result Summary Card
  float resY = botY - 10 * uiScale - resH;
  fill(22, 42, 66);
  stroke(110, 235, 165);
  strokeWeight(1.5 * uiScale);
  rect(tblX, resY, tblW, resH, 8 * uiScale);

  fill(110, 255, 165);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text("EXPERIMENTAL RESULT (FROM LAB RECORD):", tblX + 12 * uiScale, resY + 7 * uiScale);

  fill(245, 250, 255);
  textSize(10.8 * uiScale);
  float lineGap = (resH - 30 * uiScale) / 3.0;
  text("1. Mean Coefficient of Discharge (Cd)   =  0.340   (Theoretical Qt = 1.278 x 10^-3 m^3/s)", tblX + 14 * uiScale, resY + 26 * uiScale);
  text("2. Maximum Percentage Slip (% Slip)     =  68.0 %  (at Total Head HT = 22.037 m)", tblX + 14 * uiScale, resY + 26 * uiScale + lineGap);
  text("3. Maximum Overall Efficiency (eta %)   =  20.44 % (at Output Power Po = 0.0883 kW)", tblX + 14 * uiScale, resY + 26 * uiScale + 2 * lineGap);

  // RIGHT PANEL: Lab Record Graph Sheet (Combined All-3 View + Individual Zoomed Curves)
  drawAutoScaledGraph(rightX, topY, rightW, h);
}

void drawAutoScaledGraph(float gx, float gy, float gw, float gh) {
  fill(16, 25, 40);
  stroke(55, 105, 160);
  strokeWeight(1.5 * uiScale);
  rect(gx, gy, gw, gh, 8 * uiScale);

  fill(0, 195, 240);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("CHARACTERISTIC CURVES (GRAPH SHEET)", gx + 12 * uiScale, gy + 8 * uiScale);

  // Top-right Fit Mode Button
  String[] fitLabels = { "Fit: LAB RECORD", "Fit: ALL CURVED", "Fit: ALL STRAIGHT" };
  float fitW = 122 * uiScale;
  float fitH = 20 * uiScale;
  float fitX = gx + gw - fitW - 12 * uiScale;
  float fitY = gy + 6 * uiScale;
  fill(32, 54, 84);
  stroke(110, 225, 175);
  strokeWeight(1.2 * uiScale);
  rect(fitX, fitY, fitW, fitH, 5 * uiScale);
  fill(120, 255, 175);
  textAlign(CENTER, CENTER);
  textSize(9.2 * uiScale);
  text(fitLabels[graphFitMode], fitX + fitW * 0.5, fitY + fitH * 0.5);

  // 4 View Tabs: 0 = Combined Lab Graph (all 3 curves together), 1..3 = Individual zoomed curves
  String[] cTabs = { "0: ALL 3 (LAB)", "1: HT vs Eff%", "2: HT vs %Slip", "3: HT vs Qa" };
  float tW = (gw - 24 * uiScale - 3 * 5 * uiScale) / 4.0;
  for (int i = 0; i < 4; i++) {
    float tx = gx + 12 * uiScale + i * (tW + 5 * uiScale);
    fill(i == graphCurveMode ? color(0, 175, 220) : color(28, 42, 64));
    stroke(i == graphCurveMode ? color(150, 245, 255) : color(65, 95, 135));
    rect(tx, gy + 30 * uiScale, tW, 22 * uiScale, 5 * uiScale);
    fill(i == graphCurveMode ? 10 : 235);
    textAlign(CENTER, CENTER);
    textSize(9.4 * uiScale);
    text(cTabs[i], tx + tW * 0.5, gy + 41 * uiScale);
  }

  if (graphCurveMode == 0) {
    drawCombinedLabRecordSheet(gx, gy, gw, gh);
    return;
  }

  // Individual Zoomed Curve Plot (Modes 1, 2, 3) on Normal Red Graph Paper
  float plotX = gx + 54 * uiScale;
  float plotY = gy + 60 * uiScale;
  float plotW = gw - 70 * uiScale;
  float plotH = gh - 126 * uiScale;

  fill(250, 244, 244);
  stroke(185, 85, 85);
  strokeWeight(1.5 * uiScale);
  rect(plotX, plotY, plotW, plotH);

  for (int i = 0; i <= 20; i++) {
    float xLine = plotX + (plotW * i) / 20.0;
    stroke(i % 5 == 0 ? color(215, 130, 130) : color(238, 195, 195));
    strokeWeight(i % 5 == 0 ? 1.1 * uiScale : 0.6 * uiScale);
    line(xLine, plotY, xLine, plotY + plotH);

    float yLine = plotY + (plotH * i) / 20.0;
    line(plotX, yLine, plotX + plotW, yLine);
  }

  float[] xData = rHT;
  float[] yData = new float[numReadings];
  String yLabel = "";
  String slopeNote = "";
  color curveCol = color(20, 135, 75);
  boolean useSmoothCurve = true;

  if (graphCurveMode == 1) {
    for (int i = 0; i < numReadings; i++) yData[i] = rEffPct[i];
    yLabel = "Efficiency eta (%)";
    useSmoothCurve = (graphFitMode != 2);
    slopeNote = useSmoothCurve
      ? "Smooth Concave-Down Curve: Rises steeply then bends smoothly to 20.44%"
      : "Linear Fit: Efficiency increases with Total Head HT up to 20.44%";
    curveCol = color(15, 145, 75);
  } else if (graphCurveMode == 2) {
    for (int i = 0; i < numReadings; i++) yData[i] = rSlipPct[i];
    yLabel = "Percentage Slip (%)";
    useSmoothCurve = (graphFitMode != 2);
    slopeNote = useSmoothCurve
      ? "Smooth Upward-Bending Curve: Bends gently through R1..R5 (63.8% -> 68.0%)"
      : "Linear Fit: Percentage slip increases with HT from 63.8% to 68.0%";
    curveCol = color(205, 55, 55);
  } else {
    for (int i = 0; i < numReadings; i++) yData[i] = rQa[i] * 1e4;
    yLabel = "Actual Discharge Qa (x10^-4 m^3/s)";
    useSmoothCurve = (graphFitMode == 1);
    slopeNote = useSmoothCurve
      ? "Point-to-Point Curve: Actual discharge Qa drops nonlinearly with HT"
      : "Straight Best-Fit Line: Qa decreases linearly with HT (Lab Record ruler line)";
    curveCol = color(25, 95, 205);
  }

  float xMin = 4.0, xMax = 24.0;
  float yMin = min(yData);
  float yMax = max(yData);
  float yPad = (yMax - yMin) * 0.22;
  yMin -= yPad;
  yMax += yPad;

  fill(210, 225, 245);
  textSize(9.5 * uiScale);
  textAlign(CENTER, TOP);
  for (int i = 0; i <= 4; i++) {
    float xv = lerp(xMin, xMax, i / 4.0);
    float px = plotX + (plotW * i) / 4.0;
    text(nf(xv, 1, 0), px, plotY + plotH + 4 * uiScale);
  }
  text("Total Head HT (m)", plotX + plotW * 0.5, plotY + plotH + 17 * uiScale);

  textAlign(RIGHT, CENTER);
  for (int i = 0; i <= 4; i++) {
    float yv = lerp(yMin, yMax, i / 4.0);
    float py = plotY + plotH - (plotH * i) / 4.0;
    text(nf(yv, 1, 1), plotX - 5 * uiScale, py);
  }

  pushMatrix();
  translate(gx + 13 * uiScale, plotY + plotH * 0.5);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text(yLabel, 0, 0);
  popMatrix();

  float[] ptsX = new float[numReadings];
  float[] ptsY = new float[numReadings];
  for (int i = 0; i < numReadings; i++) {
    ptsX[i] = map(xData[i], xMin, xMax, plotX, plotX + plotW);
    ptsY[i] = map(yData[i], yMin, yMax, plotY + plotH, plotY);
  }

  if (useSmoothCurve) {
    drawMonotoneCurve(ptsX, ptsY, numReadings, curveCol, 2.3 * uiScale, true, plotX, plotX + plotW, plotY, plotY + plotH);
  } else {
    drawStraightBestFit(xData, yData, numReadings, xMin, xMax, yMin, yMax, plotX, plotY, plotW, plotH, curveCol, 2.3 * uiScale);
  }

  for (int i = 0; i < numReadings; i++) {
    float px = ptsX[i];
    float py = ptsY[i];
    boolean sel = (i == selectedReading);

    if (sel) {
      drawBlinkingXYCrosshair(px, py, plotX, plotY + plotH, curveCol);
      String coordTag = "(" + nf(xData[i], 1, 2) + ", " + nf(yData[i], 1, 2) + ")";
      drawBlinkingCoordPill(px, py, coordTag, plotX, plotX + plotW, plotY);
    }

    drawLabPointCircle(px, py, curveCol, sel);

    fill(20);
    textAlign(LEFT, BOTTOM);
    textSize(9.5 * uiScale);
    text("R" + (i + 1), px + 6 * uiScale, py - 4 * uiScale);
  }

  fill(175, 215, 245);
  textAlign(LEFT, TOP);
  textSize(9.8 * uiScale);
  text(slopeNote, gx + 12 * uiScale, gy + gh - 34 * uiScale);
  fill(110, 255, 165);
  text("Active R" + rSlNo[selectedReading] + ": (x, y) = (" + nf(xData[selectedReading], 1, 3) + " m, " + nf(yData[selectedReading], 1, 2) + ")" +
       "  |  " + (useSmoothCurve ? "Monotone Spline Fit" : "Straight Line Fit"), gx + 12 * uiScale, gy + gh - 18 * uiScale);
}

// ============================================================================
// EXACT MULTI-AXIS LAB GRAPH SHEET (ALL 3 CURVES ON ONE RED GRID SHEET)
// X-Axis: 1 cm = 2 m (0..30 m)
// Y-Axis 1 (Slip %): 1 cm = 5% (0..80%)
// Y-Axis 2 (Eff %):  1 cm = 2% (0..32%)
// Y-Axis 3 (Qa):     1 cm = 0.1 x 10^-4 m^3/s (row 1 = 4.0 .. row 15 = 5.4)
// ============================================================================
void drawCombinedLabRecordSheet(float gx, float gy, float gw, float gh) {
  float plotX = gx + 96 * uiScale;
  float plotY = gy + 58 * uiScale;
  float plotW = gw - 108 * uiScale;
  float plotH = gh - 122 * uiScale;

  // Normal red millimeter engineering graph paper (15 major cols = 0..30 m, 16 major rows)
  int colsCm = 15; // 0 to 30 m (1 cm = 2 m)
  int rowsCm = 16; // 16 cm vertical grid
  fill(250, 244, 244);
  stroke(185, 80, 80);
  strokeWeight(1.5 * uiScale);
  rect(plotX, plotY, plotW, plotH);

  // Minor 2 mm sub-grid + major 1 cm grid
  for (int i = 0; i <= colsCm * 5; i++) {
    float xLine = plotX + (plotW * i) / float(colsCm * 5);
    stroke(i % 5 == 0 ? color(210, 120, 120) : color(240, 202, 202));
    strokeWeight(i % 5 == 0 ? 1.0 * uiScale : 0.45 * uiScale);
    line(xLine, plotY, xLine, plotY + plotH);
  }
  for (int j = 0; j <= rowsCm * 5; j++) {
    float yLine = plotY + (plotH * j) / float(rowsCm * 5);
    stroke(j % 5 == 0 ? color(210, 120, 120) : color(240, 202, 202));
    strokeWeight(j % 5 == 0 ? 1.0 * uiScale : 0.45 * uiScale);
    line(plotX, yLine, plotX + plotW, yLine);
  }

  // X-Axis Labels: 0, 4, 8, 12, 16, 20, 24, 28 (1 cm = 2 m)
  fill(215, 230, 248);
  textSize(8.5 * uiScale);
  textAlign(CENTER, TOP);
  for (int c = 0; c <= colsCm; c += 2) {
    float px = plotX + (plotW * c) / float(colsCm);
    text(str(c * 2), px, plotY + plotH + 3 * uiScale);
  }
  text("HT (m)  [X-Axis: 1 cm = 2 m]", plotX + plotW * 0.5, plotY + plotH + 15 * uiScale);

  // 3 Y-Axis Scale Columns on the Left (matching your lab graph sheet)
  float colQaX   = plotX - 4 * uiScale;
  float colEffX  = plotX - 38 * uiScale;
  float colSlipX = plotX - 66 * uiScale;

  textAlign(RIGHT, BOTTOM);
  textSize(7.6 * uiScale);
  fill(235, 95, 95);
  text("Slip%", colSlipX, plotY - 2 * uiScale);
  fill(95, 235, 155);
  text("Eff%", colEffX, plotY - 2 * uiScale);
  fill(110, 195, 255);
  text("Qa(e-4)", colQaX, plotY - 2 * uiScale);

  textAlign(RIGHT, CENTER);
  textSize(7.4 * uiScale);
  for (int r = 1; r <= rowsCm; r += 2) {
    float py = plotY + plotH - (plotH * r) / float(rowsCm);
    // 1. % Slip: 1 cm = 5% (row r -> r * 5)
    fill(235, 130, 130);
    text(str(r * 5), colSlipX, py);
    // 2. Efficiency: 1 cm = 2% (row r -> r * 2)
    fill(120, 235, 165);
    text(str(r * 2), colEffX, py);
    // 3. Qa: 1 cm = 0.1 x 10^-4 (row 1 = 4.0, row 3 = 4.2, ..., row 15 = 5.4)
    fill(130, 205, 255);
    text(nf(3.9 + 0.1 * r, 1, 1), colQaX, py);
  }

  // Compute screen coordinates for all 3 curves on the shared 15cm x 16cm grid
  float[] xPx     = new float[numReadings];
  float[] slipPy  = new float[numReadings];
  float[] effPy   = new float[numReadings];
  float[] qaPy    = new float[numReadings];
  float[] qaCmArr = new float[numReadings];

  for (int i = 0; i < numReadings; i++) {
    // X: 0..30 m across 15 cm (1 cm = 2 m)
    xPx[i] = plotX + (rHT[i] / 30.0) * plotW;
    // Slip: 0..80% across 16 cm (1 cm = 5%)
    slipPy[i] = plotY + plotH - (rSlipPct[i] / 80.0) * plotH;
    // Efficiency: 0..32% across 16 cm (1 cm = 2%)
    effPy[i] = plotY + plotH - (rEffPct[i] / 32.0) * plotH;
    // Qa: 1 cm = 0.1 x 10^-4 starting at row 1 = 4.0 -> rowCm = (Qa*1e4 - 3.9) * 10.0
    qaCmArr[i] = (rQa[i] * 1e4 - 3.9) * 10.0;
    qaPy[i] = plotY + plotH - (qaCmArr[i] / float(rowsCm)) * plotH;
  }

  color colSlip = color(205, 45, 45);
  color colEff  = color(15, 140, 70);
  color colQa   = color(25, 95, 205);

  boolean curveSlip = (graphFitMode != 2);
  boolean curveEff  = (graphFitMode != 2);
  boolean curveQa   = (graphFitMode == 1); // Straight ruler line in Lab Record (Mode 0 & 2)

  // 1. Draw Top Curve: HT (m) vs % Slip
  if (curveSlip) {
    drawMonotoneCurve(xPx, slipPy, numReadings, colSlip, 2.0 * uiScale, true, plotX, plotX + plotW, plotY, plotY + plotH);
  } else {
    drawStraightBestFit(rHT, rSlipPct, numReadings, 0.0, 30.0, 0.0, 80.0, plotX, plotY, plotW, plotH, colSlip, 2.0 * uiScale);
  }

  // 2. Draw Middle Curve: HT (m) vs Efficiency (%)
  if (curveEff) {
    drawMonotoneCurve(xPx, effPy, numReadings, colEff, 2.0 * uiScale, true, plotX, plotX + plotW, plotY, plotY + plotH);
  } else {
    drawStraightBestFit(rHT, rEffPct, numReadings, 0.0, 30.0, 0.0, 32.0, plotX, plotY, plotW, plotH, colEff, 2.0 * uiScale);
  }

  // 3. Draw Straight Line / Curve: HT (m) vs Actual Discharge Qa (intersects Efficiency curve!)
  if (curveQa) {
    drawMonotoneCurve(xPx, qaPy, numReadings, colQa, 2.0 * uiScale, true, plotX, plotX + plotW, plotY, plotY + plotH);
  } else {
    drawStraightBestFit(rHT, qaCmArr, numReadings, 0.0, 30.0, 0.0, float(rowsCm), plotX, plotY, plotW, plotH, colQa, 2.0 * uiScale);
  }

  // Draw Circled Data Points & Blinking Active (x, y) Crosshairs
  for (int i = 0; i < numReadings; i++) {
    boolean sel = (i == selectedReading);
    if (sel) {
      drawBlinkingXYCrosshair(xPx[i], slipPy[i], plotX, plotY + plotH, colSlip);
      drawBlinkingXYCrosshair(xPx[i], effPy[i],  plotX, plotY + plotH, colEff);
      drawBlinkingXYCrosshair(xPx[i], qaPy[i],   plotX, plotY + plotH, colQa);
    }
    drawLabPointCircle(xPx[i], slipPy[i], colSlip, sel);
    drawLabPointCircle(xPx[i], effPy[i],  colEff,  sel);
    drawLabPointCircle(xPx[i], qaPy[i],   colQa,   sel);

    // Reading number tag near points
    fill(30);
    textAlign(LEFT, BOTTOM);
    textSize(8.2 * uiScale);
    text("R" + (i + 1), xPx[i] + 5 * uiScale, slipPy[i] - 3 * uiScale);
  }

  // Blinking active (x, y) coordinate pill next to selected Efficiency & Qa points
  String activeTag = "R" + (selectedReading + 1) + " (" + nf(rHT[selectedReading], 1, 2) + ", " + nf(rEffPct[selectedReading], 1, 1) + "%)";
  drawBlinkingCoordPill(xPx[selectedReading], effPy[selectedReading], activeTag, plotX, plotX + plotW, plotY);

  // Inline Curve Labels along each path (matching your handwritten labels)
  drawRotatedGraphLabel("HT (m) vs % Slip", xPx[2], slipPy[2] - 11 * uiScale, -0.11, colSlip);
  drawRotatedGraphLabel("HT (m) vs Efficiency", xPx[2] + 8 * uiScale, effPy[2] - 11 * uiScale, -0.32, colEff);
  drawRotatedGraphLabel("HT (m) vs Qa Actual Discharge", xPx[3], qaPy[3] - 11 * uiScale, 0.36, colQa);

  // Bottom Legend & Active Reading Telemetry Strip
  fill(225, 238, 252);
  textAlign(LEFT, TOP);
  textSize(9.2 * uiScale);
  text("[Red] %Slip (Curve)  [Green] Eff% (Curve)  [Blue] Qa (Straight Line, crosses Eff% ~9.3m)", gx + 12 * uiScale, gy + gh - 34 * uiScale);
  fill(110, 255, 165);
  text("Blink R" + rSlNo[selectedReading] + ": x=HT=" + nf(rHT[selectedReading], 1, 3) + "m | y: Slip=" + nf(rSlipPct[selectedReading], 1, 1) +
       "%, Eff=" + nf(rEffPct[selectedReading], 1, 2) + "%, Qa=" + nf(rQa[selectedReading] * 1e4, 1, 3) + "e-4", gx + 12 * uiScale, gy + gh - 18 * uiScale);
}

void drawBlinkingXYCrosshair(float px, float py, float leftAxisX, float bottomAxisY, color col) {
  float blinkWave = 0.5 + 0.5 * sin(simTime * 7.5);
  float alpha = lerp(75, 245, blinkWave);

  stroke(red(col), green(col), blue(col), alpha);
  strokeWeight(1.3 * uiScale);
  // Horizontal dashed line to Y-axis (y-value)
  for (float dx = leftAxisX; dx < px; dx += 6 * uiScale) {
    line(dx, py, min(px, dx + 3.2 * uiScale), py);
  }
  // Vertical dashed line to X-axis (x-value)
  for (float dy = py; dy < bottomAxisY; dy += 6 * uiScale) {
    line(px, dy, px, min(bottomAxisY, dy + 3.2 * uiScale));
  }
}

void drawBlinkingCoordPill(float px, float py, String label, float minX, float maxX, float minY) {
  float blinkWave = 0.5 + 0.5 * sin(simTime * 7.5);
  float alpha = lerp(130, 255, blinkWave);
  float pillW = 86 * uiScale;
  float pillH = 15 * uiScale;
  float bx = constrain(px + 8 * uiScale, minX + 2 * uiScale, maxX - pillW - 2 * uiScale);
  float by = max(minY + 2 * uiScale, py - 22 * uiScale);

  fill(18, 28, 44, alpha);
  stroke(255, 215, 55, alpha);
  strokeWeight(1.1 * uiScale);
  rect(bx, by, pillW, pillH, 4 * uiScale);

  fill(255, 235, 120, alpha);
  textAlign(CENTER, CENTER);
  textSize(8.0 * uiScale);
  text(label, bx + pillW * 0.5, by + pillH * 0.5);
}

void drawLabPointCircle(float cx, float cy, color col, boolean selected) {
  if (selected) {
    float blinkWave = 0.5 + 0.5 * sin(simTime * 7.5);
    float haloR = lerp(11.0, 17.5, blinkWave) * uiScale;
    float haloAlpha = lerp(220, 45, blinkWave);

    noFill();
    stroke(255, 215, 45, haloAlpha);
    strokeWeight(2.0 * uiScale);
    ellipse(cx, cy, haloR, haloR);

    fill(lerpColor(color(255, 215, 45), color(255, 95, 65), blinkWave));
    stroke(20);
    strokeWeight(1.4 * uiScale);
    ellipse(cx, cy, 10.0 * uiScale, 10.0 * uiScale);
  } else {
    noFill();
    stroke(col);
    strokeWeight(1.5 * uiScale);
    ellipse(cx, cy, 7.5 * uiScale, 7.5 * uiScale);
    fill(col);
    noStroke();
    ellipse(cx, cy, 2.5 * uiScale, 2.5 * uiScale);
  }
}

void drawRotatedGraphLabel(String txt, float x, float y, float ang, color col) {
  pushMatrix();
  translate(x, y);
  rotate(ang);
  fill(col);
  textAlign(CENTER, CENTER);
  textSize(8.8 * uiScale);
  text(txt, 0, 0);
  popMatrix();
}

// ============================================================================
// FRITSCH-CARLSON MONOTONE CUBIC HERMITE CURVE (BENDS SMOOTHLY TO POINTS)
// Guarantees zero overshoot/wiggle while passing through every data point
// ============================================================================
void drawMonotoneCurve(float[] px, float[] py, int n, color col, float sw, boolean extendEnds,
                       float minX, float maxX, float minY, float maxY) {
  if (n < 2) return;
  float[] d = new float[n - 1];
  float[] m = new float[n];

  for (int i = 0; i < n - 1; i++) {
    float dx = max(1e-4, px[i + 1] - px[i]);
    d[i] = (py[i + 1] - py[i]) / dx;
  }

  m[0] = d[0];
  m[n - 1] = d[n - 2];
  for (int i = 1; i < n - 1; i++) {
    if (d[i - 1] * d[i] <= 0) m[i] = 0;
    else m[i] = 0.5 * (d[i - 1] + d[i]);
  }

  // Fritsch-Carlson monotonicity limiter
  for (int i = 0; i < n - 1; i++) {
    if (abs(d[i]) < 1e-6) {
      m[i] = 0;
      m[i + 1] = 0;
    } else {
      float alpha = m[i] / d[i];
      float beta = m[i + 1] / d[i];
      float hypot = sqrt(alpha * alpha + beta * beta);
      if (hypot > 3.0) {
        float tau = 3.0 / hypot;
        m[i] = tau * alpha * d[i];
        m[i + 1] = tau * beta * d[i];
      }
    }
  }

  noFill();
  stroke(col);
  strokeWeight(sw);
  beginShape();

  if (extendEnds) {
    float extL = min(14 * uiScale, px[0] - minX);
    float startX = px[0] - extL;
    float startY = constrain(py[0] - m[0] * extL, minY, maxY);
    vertex(startX, startY);
  }

  int steps = 20;
  for (int i = 0; i < n - 1; i++) {
    float h = px[i + 1] - px[i];
    for (int s = 0; s <= steps; s++) {
      if (i > 0 && s == 0) continue;
      float t = s / float(steps);
      float t2 = t * t;
      float t3 = t2 * t;
      float h00 = 2 * t3 - 3 * t2 + 1;
      float h10 = t3 - 2 * t2 + t;
      float h01 = -2 * t3 + 3 * t2;
      float h11 = t3 - t2;
      float vx = px[i] + t * h;
      float vy = h00 * py[i] + h10 * h * m[i] + h01 * py[i + 1] + h11 * h * m[i + 1];
      vertex(vx, constrain(vy, minY, maxY));
    }
  }

  if (extendEnds) {
    float extR = min(14 * uiScale, maxX - px[n - 1]);
    float endX = px[n - 1] + extR;
    float endY = constrain(py[n - 1] + m[n - 1] * extR, minY, maxY);
    vertex(endX, endY);
  }

  endShape();
}

// ============================================================================
// ORDINARY LEAST SQUARES (OLS) STRAIGHT BEST-FIT LINE (FOR QA & LINEAR CHECK)
// ============================================================================
void drawStraightBestFit(float[] xData, float[] yData, int n, float xMin, float xMax,
                         float yMin, float yMax, float plotX, float plotY, float plotW, float plotH,
                         color col, float sw) {
  float sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (int i = 0; i < n; i++) {
    sumX += xData[i];
    sumY += yData[i];
    sumXY += xData[i] * yData[i];
    sumX2 += xData[i] * xData[i];
  }
  float slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  float intercept = (sumY - slope * sumX) / n;

  float xSpan = xData[n - 1] - xData[0];
  float x1 = max(xMin, xData[0] - xSpan * 0.08);
  float x2 = min(xMax, xData[n - 1] + xSpan * 0.08);
  float y1 = constrain(slope * x1 + intercept, yMin, yMax);
  float y2 = constrain(slope * x2 + intercept, yMin, yMax);

  float sx1 = map(x1, xMin, xMax, plotX, plotX + plotW);
  float sy1 = map(y1, yMin, yMax, plotY + plotH, plotY);
  float sx2 = map(x2, xMin, xMax, plotX, plotX + plotW);
  float sy2 = map(y2, yMin, yMax, plotY + plotH, plotY);

  stroke(col);
  strokeWeight(sw);
  line(sx1, sy1, sx2, sy2);
}

// ============================================================================
// UTILITY: 2D VECTOR ARROW
// ============================================================================
void draw2DArrow(float x1, float y1, float x2, float y2, color c) {
  stroke(c);
  strokeWeight(2.2 * uiScale);
  line(x1, y1, x2, y2);
  float ang = atan2(y2 - y1, x2 - x1);
  float sz = 6.5 * uiScale;
  fill(c);
  noStroke();
  triangle(x2, y2,
           x2 - sz * cos(ang - 0.45), y2 - sz * sin(ang - 0.45),
           x2 - sz * cos(ang + 0.45), y2 - sz * sin(ang + 0.45));
}

// ============================================================================
// TOUCH & MOUSE INTERACTION HANDLERS (1:1 HIT-TESTING ACROSS ALL 6 SCREENS)
// ============================================================================
void mousePressed() {
  lastMouseX = mouseX;
  lastMouseY = mouseY;

  // 1. Top Navigation Tabs
  float barH = topBarH();
  if (mouseY <= barH) {
    float titleW = 235 * uiScale;
    float startX = titleW + 20 * uiScale;
    float availW = width - startX - 12 * uiScale;
    float tabW = (availW - 5 * 5 * uiScale) / 6.0;
    for (int i = 0; i < 6; i++) {
      float tx = startX + i * (tabW + 5 * uiScale);
      if (mouseX >= tx && mouseX <= tx + tabW) {
        currentScreen = i;
        return;
      }
    }
  }

  // 2. Bottom Navigation Buttons
  float bBarH = botBarH();
  float by = height - bBarH;
  if (mouseY >= by) {
    float btnW = 150 * uiScale;
    if (mouseX >= 12 * uiScale && mouseX <= 12 * uiScale + btnW && currentScreen > 0) {
      currentScreen--;
      return;
    }
    if (mouseX >= width - btnW - 12 * uiScale && mouseX <= width - 12 * uiScale && currentScreen < 5) {
      currentScreen++;
      return;
    }
  }

  // 3. Screen-Specific Controls
  if (currentScreen == 0) handleScreen1Press();
  else if (currentScreen == 1) handleScreen2Press();
  else if (currentScreen == 2) handleScreen3Press();
  else if (currentScreen == 3) handleScreen4Press();
  else if (currentScreen == 4) handleScreen5Press();
  else if (currentScreen == 5) handleScreen6Press();
}

void mouseDragged() {
  if (currentScreen == 0) {
    if (draggingSlider) {
      float cardX = 12 * uiScale;
      float cardW = 300 * uiScale;
      float viewLeft = cardX + cardW + 10 * uiScale;
      float viewRight = width - 12 * uiScale;
      float viewW = viewRight - viewLeft;
      float viewCenterX = (viewLeft + viewRight) * 0.5;
      float slW = min(440 * uiScale, viewW - 24 * uiScale);
      float slX = viewCenterX - slW * 0.5;
      float trackX = slX + 18 * uiScale;
      float trackW = slW - 36 * uiScale;
      float norm = constrain((mouseX - trackX) / trackW, 0, 1);
      updateFromSliderHd(4.0 + norm * 16.0);
    } else if (dragging3D) {
      rotY += (mouseX - lastMouseX) * 0.008;
      rotX = constrain(rotX + (mouseY - lastMouseY) * 0.008, -1.2, 0.5);
    }
  }
  lastMouseX = mouseX;
  lastMouseY = mouseY;
}

void mouseReleased() {
  dragging3D = false;
  draggingSlider = false;
}

void handleScreen1Press() {
  float topY = arenaTop();
  float totalH = arenaH();
  float cardX = 12 * uiScale;
  float cardW = 300 * uiScale;
  float ctrlH = 102 * uiScale;
  float cardH = totalH - ctrlH - 8 * uiScale;
  float ctrlY = topY + cardH + 8 * uiScale;

  // Reading pills R1..R5
  float pillW = (cardW - 24 * uiScale - 4 * 5 * uiScale) / 5.0;
  float py = ctrlY + 23 * uiScale;
  if (mouseY >= py && mouseY <= py + 26 * uiScale) {
    for (int i = 0; i < 5; i++) {
      float px = cardX + 12 * uiScale + i * (pillW + 5 * uiScale);
      if (mouseX >= px && mouseX <= px + pillW) {
        syncToReading(i);
        return;
      }
    }
  }

  // Camera buttons
  float camY = ctrlY + 58 * uiScale;
  float camW = (cardW - 24 * uiScale - 3 * 6 * uiScale) / 4.0;
  if (mouseY >= camY && mouseY <= camY + 32 * uiScale) {
    for (int i = 0; i < 4; i++) {
      float bx = cardX + 12 * uiScale + i * (camW + 6 * uiScale);
      if (mouseX >= bx && mouseX <= bx + camW) {
        if (i == 0) autoOrbit = !autoOrbit;
        else if (i == 1) zoom3D = constrain(zoom3D + 0.15, 0.6, 2.0);
        else if (i == 2) zoom3D = constrain(zoom3D - 0.15, 0.6, 2.0);
        else { rotX = -0.18; rotY = -0.24; zoom3D = 1.0; autoOrbit = false; }
        return;
      }
    }
  }

  // Centered Slider inside Enclosed 3D Viewport
  float viewLeft = cardX + cardW + 10 * uiScale;
  float viewRight = width - 12 * uiScale;
  float viewW = viewRight - viewLeft;
  float viewCenterX = (viewLeft + viewRight) * 0.5;
  float slW = min(440 * uiScale, viewW - 24 * uiScale);
  float slH = 58 * uiScale;
  float slX = viewCenterX - slW * 0.5;
  float slY = arenaBot() - slH - 8 * uiScale;
  if (mouseX >= slX && mouseX <= slX + slW && mouseY >= slY && mouseY <= slY + slH) {
    draggingSlider = true;
    float trackX = slX + 18 * uiScale;
    float trackW = slW - 36 * uiScale;
    float norm = constrain((mouseX - trackX) / trackW, 0, 1);
    updateFromSliderHd(4.0 + norm * 16.0);
    return;
  }

  // Orbit drag anywhere inside the enclosed 3D viewport
  if (mouseX >= viewLeft && mouseX <= viewRight && mouseY >= topY && mouseY <= arenaBot()) {
    dragging3D = true;
  }
}

void handleScreen2Press() {
  float arenaX = 12 * uiScale;
  float arenaY = arenaTop();
  float arenaW = width - 24 * uiScale;
  float aH = arenaH();

  float btnW = 150 * uiScale;
  float btnH = 26 * uiScale;
  float bx1 = arenaX + arenaW - 2 * btnW - 20 * uiScale;
  float bx2 = arenaX + arenaW - btnW - 12 * uiScale;
  float by = arenaY + 6 * uiScale;

  if (mouseY >= by && mouseY <= by + btnH) {
    if (mouseX >= bx1 && mouseX <= bx1 + btnW) {
      unsteadyMode = !unsteadyMode;
      return;
    }
    if (mouseX >= bx2 && mouseX <= bx2 + btnW) {
      streaklinePts.clear();
      for (FluidParticle2D p : particles2D) p.respawn(true);
      return;
    }
  }

  if (mouseX >= arenaX + 20 * uiScale && mouseX <= arenaX + arenaW - 20 * uiScale &&
      mouseY >= arenaY + 38 * uiScale && mouseY <= arenaY + aH - 20 * uiScale) {
    dyeNozzleX = constrain((mouseX - arenaX) / arenaW, 0.10, 0.80);
    dyeNozzleY = constrain((mouseY - arenaY) / aH, 0.14, 0.80);
    streaklinePts.clear();
  }
}

void handleScreen3Press() {
  float topY = arenaTop();
  float botY = arenaBot();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.56;
  float leftX = 12 * uiScale;

  float stepStartY = topY + 34 * uiScale;
  float stepH = (h - 80 * uiScale) / 7.0;
  if (mouseX >= leftX && mouseX <= leftX + leftW && mouseY >= stepStartY && mouseY <= stepStartY + 7 * stepH) {
    derivStep = constrain(int((mouseY - stepStartY) / stepH), 0, 6);
    autoDerive = false;
    return;
  }

  float btnY = botY - 38 * uiScale;
  float btnH = 28 * uiScale;
  float bW = (leftW - 48 * uiScale) / 3.0;
  if (mouseY >= btnY && mouseY <= btnY + btnH) {
    for (int i = 0; i < 3; i++) {
      float bx = leftX + 12 * uiScale + i * (bW + 12 * uiScale);
      if (mouseX >= bx && mouseX <= bx + bW) {
        if (i == 0) { derivStep = (derivStep + 6) % 7; autoDerive = false; }
        else if (i == 1) { derivStep = (derivStep + 1) % 7; autoDerive = false; }
        else { autoDerive = !autoDerive; autoDeriveTimer = 0; }
        return;
      }
    }
  }
}

void handleScreen4Press() {
  float topY = arenaTop();
  float botY = arenaBot();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.48;
  float leftX = 12 * uiScale;

  float stepStartY = topY + 34 * uiScale;
  float stepH = (h - 80 * uiScale) / 6.0;
  if (mouseX >= leftX && mouseX <= leftX + leftW && mouseY >= stepStartY && mouseY <= stepStartY + 6 * stepH) {
    procStep = constrain(int((mouseY - stepStartY) / stepH), 0, 5);
    autoProc = false;
    return;
  }

  float btnY = botY - 38 * uiScale;
  if (mouseX >= leftX + 14 * uiScale && mouseX <= leftX + leftW - 14 * uiScale &&
      mouseY >= btnY && mouseY <= btnY + 28 * uiScale) {
    autoProc = !autoProc;
    autoProcTimer = 0;
  }
}

void handleScreen5Press() {
  float topY = arenaTop();
  float h = arenaH();
  float leftW = (width - 34 * uiScale) * 0.53;
  float rightW = (width - 34 * uiScale) * 0.47;
  float leftX = 12 * uiScale;
  float rightX = leftX + leftW + 10 * uiScale;

  float rStartY = topY + 60 * uiScale;
  float rH = (h - 68 * uiScale) / 8.0;
  if (mouseX >= leftX && mouseX <= leftX + leftW && mouseY >= rStartY && mouseY <= rStartY + 8 * rH) {
    int idx = constrain(int((mouseY - rStartY) / rH), 0, 7);
    updateCasioForStep(idx);
    return;
  }

  float lcdX = rightX + 16 * uiScale;
  float lcdY = topY + 31 * uiScale;
  float lcdW = rightW - 32 * uiScale;
  float lcdH = 52 * uiScale;
  float topCtrlY = lcdY + lcdH + 9 * uiScale;
  float pillH = 20 * uiScale;
  float keypadTop = topCtrlY + pillH + 12 * uiScale;
  float keypadBot = topY + h - 24 * uiScale;
  float totalKeyAreaH = keypadBot - keypadTop;
  float sciAreaH = totalKeyAreaH * 0.46;
  float numAreaH = totalKeyAreaH * 0.54;
  float numStartY = keypadTop + sciAreaH + 2 * uiScale;
  float numGapY = 9 * uiScale;
  float numRowH = (numAreaH - 3 * numGapY) / 4.0;
  float numColW = (lcdW - 4 * 6 * uiScale) / 5.0;

  String[][] numKeys = {
    { "7", "8", "9", "DEL", "AC" },
    { "4", "5", "6", "x",   "/"  },
    { "1", "2", "3", "+",   "-"  },
    { "0", ".", "EXP", "Ans", "=" }
  };

  for (int r = 0; r < 4; r++) {
    float ky = numStartY + r * (numRowH + numGapY);
    for (int c = 0; c < 5; c++) {
      float kx = lcdX + c * (numColW + 6 * uiScale);
      if (mouseX >= kx && mouseX <= kx + numColW && mouseY >= ky && mouseY <= ky + numRowH) {
        String k = numKeys[r][c];
        activeCasioKey = k;
        if (k.equals("AC")) {
          calcExpr = "0";
          calcAns = "0";
        } else if (k.equals("DEL")) {
          if (calcExpr.length() > 1) calcExpr = calcExpr.substring(0, calcExpr.length() - 1);
          else calcExpr = "0";
        } else if (k.equals("=")) {
          updateCasioForStep(bodmasStep);
        } else if (k.equals("Ans")) {
          updateCasioForStep((bodmasStep + 1) % 8);
        } else {
          if (calcExpr.equals("0")) calcExpr = k;
          else if (calcExpr.length() < 24) calcExpr += k;
        }
        return;
      }
    }
  }
}

void handleScreen6Press() {
  float topY = arenaTop();
  float botY = arenaBot();
  float leftW = (width - 34 * uiScale) * 0.54;
  float rightW = (width - 34 * uiScale) * 0.46;
  float leftX = 12 * uiScale;
  float rightX = leftX + leftW + 10 * uiScale;

  // 1. Observation Table Row Selection
  float tblX = leftX + 8 * uiScale;
  float tblW = leftW - 16 * uiScale;
  float hdrY = topY + 32 * uiScale;
  float hdrH = 28 * uiScale;
  float resH = 98 * uiScale;
  float availRowsH = (botY - 10 * uiScale - resH - 10 * uiScale) - (hdrY + hdrH + 4 * uiScale);
  float rowH = (availRowsH - 4 * 4 * uiScale) / float(numReadings);

  for (int r = 0; r < numReadings; r++) {
    float ry = hdrY + hdrH + 4 * uiScale + r * (rowH + 4 * uiScale);
    if (mouseX >= tblX && mouseX <= tblX + tblW && mouseY >= ry && mouseY <= ry + rowH) {
      syncToReading(r);
      return;
    }
  }

  // 2. Top-Right Fit Mode Toggle Button (LAB RECORD / ALL CURVED / ALL STRAIGHT)
  float fitW = 122 * uiScale;
  float fitH = 20 * uiScale;
  float fitX = rightX + rightW - fitW - 12 * uiScale;
  float fitY = topY + 6 * uiScale;
  if (mouseX >= fitX && mouseX <= fitX + fitW && mouseY >= fitY && mouseY <= fitY + fitH) {
    graphFitMode = (graphFitMode + 1) % 3;
    return;
  }

  // 3. 4 Curve View Tabs (0: ALL 3 LAB, 1: Eff%, 2: %Slip, 3: Qa)
  float tW = (rightW - 24 * uiScale - 3 * 5 * uiScale) / 4.0;
  if (mouseY >= topY + 30 * uiScale && mouseY <= topY + 52 * uiScale) {
    for (int i = 0; i < 4; i++) {
      float tx = rightX + 12 * uiScale + i * (tW + 5 * uiScale);
      if (mouseX >= tx && mouseX <= tx + tW) {
        graphCurveMode = i;
        return;
      }
    }
  }
}
