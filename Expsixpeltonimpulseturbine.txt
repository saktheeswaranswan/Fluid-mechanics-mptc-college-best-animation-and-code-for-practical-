// ============================================================================
// EX. NO: 6 - IMPULSE TURBINE [PELTON WHEEL] PERFORMANCE TEST (APDE - P3D)
// Complete 6-Screen Interactive Lab Simulator & Casio fx-991MS Calculator
// ============================================================================

import processing.core.*;

// --- SCREEN NAVIGATION & GLOBAL STATE ---
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
int selectedReading = 0; // Default R1 (Model Calculation in Lab Record)

// --- APPARATUS CONSTANTS (Extracted from Lab Record) ---
final float C_DRUM   = 0.200;    // Circumference of brake drum 2*pi*R = 200 mm = 0.2 m
final float R_DRUM   = 0.03183;  // Brake drum radius R = 0.2 / (2*pi) = 0.0318 m
final float T_ROPE   = 0.015;    // Thickness of rope t = 15 mm = 0.015 m
final float R_EFF    = 0.03933;  // Effective radius Re = R + t/2 = 0.0393 m
final float K_VENT   = 3.12e-3;  // Venturimeter constant K = 3.12 x 10^-3 m^3/(s*sqrt(m))
final float HS_HEAD  = 8.0;      // Constant supply head Hs = 0.8 kg/cm^2 * 10 = 8.0 m
final float W0_DEAD  = 1.0;      // Dead weight W0 = 1.0 kg
final float G_ACCEL  = 9.81;     // Acceleration due to gravity (m/s^2)

// --- OBSERVATION TABLE DATA (5 Readings R1..R5 from Lab Record) ---
int[]   rNum   = { 1, 2, 3, 4, 5 };
float[] p1Arr  = { 0.20, 0.20, 0.20, 0.20, 0.20 };         // Venturi inlet P1 (kg/cm^2)
float[] p2Arr  = { 0.12, 0.12, 0.12, 0.12, 0.12 };         // Venturi throat P2 (kg/cm^2)
float[] hArr   = { 0.80, 0.80, 0.80, 0.80, 0.80 };         // Diff head h = (P1-P2)*10 (m)
float[] w1Arr  = { 1.0,  2.0,  3.0,  4.0,  5.0  };         // Hanger load W1 (kg)
float[] w2Arr  = { 0.25, 0.25, 0.50, 1.00, 1.00 };         // Spring balance W2 (kg)
float[] waArr  = { 0.0172, 0.0269, 0.0343, 0.0392, 0.0491 }; // Effective load Wa (kN)
float[] nArr   = { 825.0, 726.0, 675.0, 591.0, 546.0 };    // Runner speed N (rpm)
float[] qArr   = { 2.789e-3, 2.789e-3, 2.789e-3, 2.789e-3, 2.789e-3 }; // Discharge Q (m^3/s)
float[] piArr  = { 0.218, 0.218, 0.218, 0.218, 0.218 };    // Input power Pi (kW)
float[] poArr  = { 0.0583, 0.0803, 0.0959, 0.0953, 0.1103 }; // Output power Po (kW)
float[] etaArr = { 26.743, 36.834, 43.669, 43.715, 50.458 }; // Efficiency eta (%)

// Live working values (synced to selectedReading, adjustable via load slider)
float curP1, curP2, curH, curW1, curW2, curWa, curN, curQ, curPi, curPo, curEta;
boolean customSliderActive = false;

// --- SCREEN 1: 3D RIG INTERACTION & PARTICLES ---
float rotX = -0.20;
float rotY = 0.34;
float zoom3D = 1.0;
boolean autoOrbit = true;
float wheelAngle = 0.0;
boolean dragging3D = false;
boolean draggingLoadSlider = false;
float prevMouseX, prevMouseY;

class FlowParticle3D {
  float t;     // 0..1 along circuit
  float radial;
  float angleOff;
  int branch;  // 0:main pipe+jet, 1:bucket splash
  FlowParticle3D(float t0, int b) {
    t = t0;
    branch = b;
    radial = random(-0.6, 0.6);
    angleOff = random(TWO_PI);
  }
}
ArrayList<FlowParticle3D> rigParticles;

// --- SCREEN 2: 2D CUTAWAY CFD SIMULATION ---
class FluidParticle2D {
  float x, y, vx, vy;
  float[] trailX = new float[16];
  float[] trailY = new float[16];
  int trailCount = 0;
  boolean isDye;
  FluidParticle2D(float x0, float y0, boolean dye) {
    x = x0;
    y = y0;
    isDye = dye;
    resetTrail();
  }
  void resetTrail() {
    trailCount = 0;
    for (int i = 0; i < 16; i++) {
      trailX[i] = x;
      trailY[i] = y;
    }
  }
}
ArrayList<FluidParticle2D> cutParticles;
ArrayList<FluidParticle2D> dyeParticles;
float dyeNozzleRelX = 0.26;
float dyeNozzleRelY = 0.56;
boolean unsteadyMode = false;
float simTime = 0.0;

// --- SCREEN 3: DERIVATION STATE ---
int derivStep = 0;
boolean autoDerive = false;
int lastDerivTick = 0;
String[] derivTitles = {
  "Step 1: Venturimeter Differential Head (h)",
  "Step 2: Volumetric Flow Rate / Discharge (Q)",
  "Step 3: Hydraulic Input Power to Turbine (Pi)",
  "Step 4: Effective Brake Drum Radius (Re)",
  "Step 5: Net Effective Brake Load (Wa)",
  "Step 6: Shaft Brake Output Power (Po)",
  "Step 7: Overall Pelton Turbine Efficiency (eta)"
};
String[] derivFormulas = {
  "h = (P1 - P2) * 10   [m of water]",
  "Q = Cd * a1*a2 / sqrt(a1^2 - a2^2) * sqrt(2*g*h) = K * sqrt(h)",
  "Pi = (rho * g * Q * Hs) / 1000 = (w * Q * Hs)   [kW]",
  "Re = R + (t / 2) = (C_drum / (2*pi)) + (t / 2)   [m]",
  "Wa = ((W0 + W1 - W2) * 9.81) / 1000   [kN]",
  "Po = (2 * pi * N * Wa * Re) / 60   [kW]",
  "eta = (Po / Pi) * 100   [%]"
};
String[] derivNotes = {
  "Converts pressure drop (kg/cm^2) across venturi inlet & throat into water head (m).",
  "Using calibrated venturimeter constant K = 3.12 x 10^-3 m^3/(s*sqrt(m)).",
  "Specific weight w = rho*g = 9.81 kN/m^3; constant supply head Hs = 8.0 m.",
  "Drum circumference 2*pi*R = 0.2 m (R = 0.0318 m) + half rope thickness (0.0075 m).",
  "Dead weight W0 = 1 kg plus slotted mass W1 minus spring balance tension W2.",
  "Brake torque T = Wa * Re (kN*m) multiplied by angular speed omega = 2*pi*N/60.",
  "Ratio of mechanical shaft output power Po to hydraulic jet input power Pi."
};

// --- SCREEN 4: PROCEDURE STATE ---
int procStep = 0;
boolean autoDemo = true;
int lastProcTick = 0;
String[] procTitles = {
  "1. Measure Brake Drum & Rope Dimensions",
  "2. Set Spear Valve & Prime Centrifugal Pump",
  "3. Start Pump & Regulate Constant Head (Hs)",
  "4. Record Venturimeter Manometer Readings",
  "5. Apply Brake Load & Measure Speed (N)",
  "6. Vary Brake Load Across 5 Runs & Shutdown"
};
String[] procDetails = {
  "Measure brake drum circumference (2*pi*R = 0.2 m) and rope thickness (t = 15 mm) with tape; note K = 3.12x10^-3 and W0 = 1 kg.",
  "Open the spear valve handwheel for full nozzle jet opening. Prime the centrifugal pump casing completely from the sump.",
  "Keep delivery valve closed, switch on pump motor, then gradually open delivery valve until inlet gauge reads 0.8 kg/cm^2 (Hs = 8 m).",
  "Note venturimeter inlet pressure P1 = 0.20 kg/cm^2 and throat pressure P2 = 0.12 kg/cm^2 to obtain head h = 0.8 m.",
  "Place slotted weight W1 (1 to 5 kg) on hanger, record spring balance reading W2, and measure shaft rpm N with tachometer.",
  "Repeat for W1 = 1, 2, 3, 4, 5 kg while keeping Hs = 8 m constant. Unload brake, switch off pump, and tabulate results."
};

// --- SCREEN 5: CASIO fx-991MS CALCULATOR & BODMAS STATE ---
int bodmasStep = 0;
boolean autoCalc = false;
int lastCalcTick = 0;
String casioTopLine = "";
String casioBotLine = "0.";
boolean casioShiftOn = false;
boolean casioAlphaOn = false;
String casioLastAns = "0";
String[] bodmasLetters = { "B", "O", "D", "M", "A", "S" };
String[] bodmasWords   = { "Brackets", "Orders/Roots", "Division", "Multiplication", "Addition", "Subtraction" };

// --- SCREEN 6: GRAPH CURVE SELECTOR ---
int graphMode = 0; // 0: Speed vs Efficiency (eta %), 1: Speed vs Output Power (Po kW), 2: Speed vs Pi & Q
float graphAnim = 1.0;

// ============================================================================
// APDE LIFECYCLE: settings(), setup(), draw()
// ============================================================================
public void settings() {
  fullScreen(P3D);
}

public void setup() {
  orientation(LANDSCAPE);
  textFont(createFont("SansSerif", 16, true));
  uiScale = constrain(min(width / 1280.0, height / 720.0), 0.50, 1.6);

  // Initialize 3D flow particles
  rigParticles = new ArrayList<FlowParticle3D>();
  for (int i = 0; i < 95; i++) {
    rigParticles.add(new FlowParticle3D(i / 95.0, 0));
  }
  for (int i = 0; i < 45; i++) {
    rigParticles.add(new FlowParticle3D(random(1.0), 1));
  }

  // Initialize 2D cutaway particles
  cutParticles = new ArrayList<FluidParticle2D>();
  for (int i = 0; i < 75; i++) {
    cutParticles.add(new FluidParticle2D(random(0.05, 0.95), random(0.15, 0.85), false));
  }
  dyeParticles = new ArrayList<FluidParticle2D>();
  for (int i = 0; i < 36; i++) {
    dyeParticles.add(new FluidParticle2D(dyeNozzleRelX, dyeNozzleRelY, true));
  }

  selectReading(0); // Default to Reading 1 (Model Calculation)
}

void selectReading(int idx) {
  selectedReading = constrain(idx, 0, rNum.length - 1);
  customSliderActive = false;
  curP1  = p1Arr[selectedReading];
  curP2  = p2Arr[selectedReading];
  curH   = hArr[selectedReading];
  curW1  = w1Arr[selectedReading];
  curW2  = w2Arr[selectedReading];
  curWa  = waArr[selectedReading];
  curN   = nArr[selectedReading];
  curQ   = qArr[selectedReading];
  curPi  = piArr[selectedReading];
  curPo  = poArr[selectedReading];
  curEta = etaArr[selectedReading];
  syncCasioToStep(bodmasStep);
  graphAnim = 0.0;
}

void updateFromCustomLoad(float newW1) {
  customSliderActive = true;
  curW1 = constrain(newW1, 1.0, 5.0);
  curW2 = lerp(0.25, 1.00, (curW1 - 1.0) / 4.0);
  curN  = lerp(825.0, 546.0, (curW1 - 1.0) / 4.0);
  curP1 = 0.20;
  curP2 = 0.12;
  curH  = 0.80;
  curQ  = K_VENT * sqrt(curH);
  curPi = (9.81 * curQ * HS_HEAD);
  curWa = ((W0_DEAD + curW1 - curW2) * G_ACCEL) / 1000.0;
  curPo = (TWO_PI * curN * curWa * R_EFF) / 60.0;
  curEta = (curPo / curPi) * 100.0;
  syncCasioToStep(bodmasStep);
}

// Helper layout metrics for Screen 1 (Left GUI | Center 3D Frame | Right Telemetry)
float[] getScreen1Layout() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 14 * uiScale;
  float mainH = height - topOff - botOff;
  float leftW = min(285 * uiScale, width * 0.24);
  float rightW = min(305 * uiScale, width * 0.25);
  float centerX = pad + leftW + pad;
  float centerW = width - centerX - rightW - pad;
  return new float[] { topOff, botOff, pad, mainH, leftW, rightW, centerX, centerW };
}

public void draw() {
  uiScale = constrain(min(width / 1280.0, height / 720.0), 0.50, 1.6);
  simTime += 0.04;

  // Update turbine angular speed proportional to RPM
  float omegaVis = map(curN, 500, 900, 0.06, 0.14);
  wheelAngle += omegaVis;

  if (autoOrbit && currentScreen == 0 && !dragging3D) {
    rotY += 0.0045;
  }
  if (autoDerive && currentScreen == 2 && millis() - lastDerivTick > 2600) {
    derivStep = (derivStep + 1) % derivTitles.length;
    lastDerivTick = millis();
  }
  if (autoDemo && currentScreen == 3 && millis() - lastProcTick > 2800) {
    procStep = (procStep + 1) % procTitles.length;
    lastProcTick = millis();
  }
  if (autoCalc && currentScreen == 4 && millis() - lastCalcTick > 2500) {
    bodmasStep = (bodmasStep + 1) % 8;
    syncCasioToStep(bodmasStep);
    lastCalcTick = millis();
  }
  if (graphAnim < 1.0) {
    graphAnim = min(1.0, graphAnim + 0.045);
  }

  background(13, 19, 30);

  if (currentScreen == 0) {
    // 3D Rig rendered first in true P3D space at exact center of center GUI frame
    drawApparatus3D();
  }

  // Switch to 2D Ortho HUD aligned to (0,0) -> (width, height)
  beginHUD();
  drawTopHeaderAndTabs();

  if (currentScreen == 0) {
    drawScreen1_HUD();
  } else if (currentScreen == 1) {
    drawScreen2_CutawayPhysics();
  } else if (currentScreen == 2) {
    drawScreen3_Derivation();
  } else if (currentScreen == 3) {
    drawScreen4_Procedure();
  } else if (currentScreen == 4) {
    drawScreen5_CasioCalc();
  } else if (currentScreen == 5) {
    drawScreen6_TableAndGraph();
  }

  drawBottomNavBar();
  endHUD();
}

// ============================================================================
// 2D HUD PROJECTION HELPERS (TOP-LEFT ORIGIN ALIGNMENT)
// ============================================================================
void beginHUD() {
  hint(DISABLE_DEPTH_TEST);
  noLights();
  camera(
    width * 0.5, height * 0.5, (height * 0.5) / tan(PI / 6.0),
    width * 0.5, height * 0.5, 0,
    0, 1, 0
  );
  ortho(-width * 0.5, width * 0.5, -height * 0.5, height * 0.5, -1000, 1000);
}

void endHUD() {
  hint(ENABLE_DEPTH_TEST);
}

// ============================================================================
// TOP HEADER BAR & 6-SCREEN TABS
// ============================================================================
void drawTopHeaderAndTabs() {
  float topH = 44 * uiScale;
  float tabH = 38 * uiScale;

  // Title banner
  noStroke();
  fill(18, 28, 45);
  rect(0, 0, width, topH);

  fill(56, 189, 248);
  textAlign(LEFT, CENTER);
  textSize(17 * uiScale);
  text("PELTON WHEEL IMPULSE TURBINE LAB (EX. NO: 6)", 16 * uiScale, topH * 0.5);

  // Active Reading Pill on right
  String runBadge = customSliderActive
    ? "CUSTOM LOAD: W1=" + nf(curW1, 1, 2) + " kg | N=" + nf(curN, 1, 0) + " rpm | eta=" + nf(curEta, 1, 2) + "%"
    : "ACTIVE RUN: R" + (selectedReading + 1) + " (W1=" + nf(curW1, 1, 1) + " kg | N=" + nf(curN, 1, 0) + " rpm | eta=" + nf(curEta, 1, 2) + "%)";
  textSize(12.5 * uiScale);
  float badgeW = textWidth(runBadge) + 24 * uiScale;
  fill(28, 46, 74);
  stroke(56, 189, 248, 160);
  strokeWeight(1.2);
  rect(width - badgeW - 14 * uiScale, 6 * uiScale, badgeW, topH - 12 * uiScale, 8 * uiScale);
  fill(224, 242, 254);
  textAlign(CENTER, CENTER);
  text(runBadge, width - badgeW * 0.5 - 14 * uiScale, topH * 0.5);

  // Navigation Tabs Row
  float tabY = topH;
  float tabW = width / 6.0;
  for (int i = 0; i < 6; i++) {
    float tx = i * tabW;
    boolean active = (i == currentScreen);
    fill(active ? color(37, 99, 235) : color(23, 35, 56));
    stroke(45, 68, 102);
    strokeWeight(1);
    rect(tx, tabY, tabW, tabH);

    if (active) {
      noStroke();
      fill(96, 165, 250);
      rect(tx + 6 * uiScale, tabY + tabH - 4 * uiScale, tabW - 12 * uiScale, 4 * uiScale, 2);
    }

    fill(active ? 255 : color(175, 195, 220));
    textAlign(CENTER, CENTER);
    textSize(13 * uiScale);
    text(screenNames[i], tx + tabW * 0.5, tabY + tabH * 0.5);
  }
}

// ============================================================================
// BOTTOM NAVIGATION BAR (< PREV SCREEN / NEXT SCREEN >)
// ============================================================================
void drawBottomNavBar() {
  float barH = 44 * uiScale;
  float by = height - barH;

  noStroke();
  fill(17, 26, 42, 245);
  rect(0, by, width, barH);
  stroke(45, 68, 102);
  strokeWeight(1);
  line(0, by, width, by);

  float btnW = 165 * uiScale;
  float btnH = 30 * uiScale;
  float btnY = by + (barH - btnH) * 0.5;

  // < PREV SCREEN
  fill(currentScreen > 0 ? color(30, 58, 110) : color(26, 36, 54));
  stroke(75, 115, 175);
  rect(16 * uiScale, btnY, btnW, btnH, 7 * uiScale);
  fill(currentScreen > 0 ? 255 : 110);
  textAlign(CENTER, CENTER);
  textSize(12.5 * uiScale);
  text("< PREV SCREEN", 16 * uiScale + btnW * 0.5, btnY + btnH * 0.5);

  // Center Status
  fill(160, 185, 215);
  textSize(12 * uiScale);
  text("Screen " + (currentScreen + 1) + " of 6  |  Hs = 8.0 m (Constant)  |  Q = 2.789x10^-3 m^3/s", width * 0.5, by + barH * 0.5);

  // NEXT SCREEN >
  fill(currentScreen < 5 ? color(37, 99, 235) : color(26, 36, 54));
  stroke(96, 165, 250);
  rect(width - btnW - 16 * uiScale, btnY, btnW, btnH, 7 * uiScale);
  fill(currentScreen < 5 ? 255 : 110);
  text("NEXT SCREEN >", width - btnW * 0.5 - 16 * uiScale, btnY + btnH * 0.5);
}

// ============================================================================
// SCREEN 1: FULL 3D PELTON WHEEL TURBINE TEST RIG (CENTERED IN GUI FRAME)
// ============================================================================
void drawApparatus3D() {
  float[] lay = getScreen1Layout();
  float topOff  = lay[0];
  float mainH   = lay[3];
  float centerX = lay[6];
  float centerW = lay[7];

  float rigCenterX = centerX + centerW * 0.5;
  float rigCenterY = topOff + mainH * 0.51;
  float fitScale = min(centerW / 540.0, mainH / 395.0) * 1.04;

  perspective(PI / 3.2, float(width) / float(height), 1.0, 5000.0);
  camera(
    width * 0.5, height * 0.5, (height * 0.5) / tan(PI / 6.0),
    width * 0.5, height * 0.5, 0,
    0, 1, 0
  );

  lights();
  ambientLight(95, 105, 125);
  directionalLight(235, 240, 255, -0.4, 0.7, -0.6);
  directionalLight(90, 140, 200, 0.5, -0.4, 0.4);

  pushMatrix();
  translate(rigCenterX, rigCenterY, 0);
  scale(zoom3D * fitScale);
  rotateX(rotX);
  rotateY(rotY);

  // Center the 3D rig geometry around its own rotational origin (0,0,0)
  translate(-42, -10, 0);

  // Base laboratory floor frame
  pushMatrix();
  translate(42, 165, 0);
  fill(35, 44, 62);
  stroke(60, 78, 105);
  strokeWeight(1);
  box(475, 16, 235);
  popMatrix();

  // 1. SUMP TANK & TAILRACE CHANNEL (Right side)
  pushMatrix();
  translate(160, 105, 0);
  noFill();
  stroke(120, 180, 230, 180);
  strokeWeight(1.5);
  box(150, 104, 140);
  noStroke();
  fill(20, 130, 210, 125);
  translate(0, 12, 0);
  box(146, 78, 136);
  popMatrix();

  // Tailrace Return Channel from Pelton turbine to Sump
  pushMatrix();
  translate(25, 136, 0);
  fill(25, 145, 225, 130);
  stroke(90, 170, 230, 140);
  box(135, 38, 92);
  popMatrix();

  // Foot Valve & Strainer submerged in Sump
  pushMatrix();
  translate(142, 118, 0);
  fill(190, 150, 55);
  noStroke();
  drawCylinder(14, 14, 28, 16);
  popMatrix();

  // Suction Pipe from Foot Valve up to Centrifugal Pump
  pushMatrix();
  translate(142, 45, 0);
  fill(140, 155, 175);
  noStroke();
  drawCylinder(9, 9, 125, 16);
  popMatrix();

  // 2. CENTRIFUGAL PUMP & ELECTRIC MOTOR (Upper Right)
  pushMatrix();
  translate(112, -20, 0);
  pushMatrix();
  translate(0, 0, -48);
  rotateX(HALF_PI);
  fill(30, 95, 195);
  drawCylinder(28, 28, 65, 20);
  popMatrix();
  pushMatrix();
  translate(0, 0, -14);
  rotateX(HALF_PI);
  fill(210, 215, 225);
  drawCylinder(6, 6, 28, 12);
  popMatrix();
  pushMatrix();
  rotateX(HALF_PI);
  fill(55, 125, 210);
  drawCylinder(36, 36, 26, 24);
  popMatrix();
  popMatrix();

  // Vertical Discharge Pipe from Pump to Top Header
  pushMatrix();
  translate(90, -82, 0);
  fill(145, 160, 180);
  drawCylinder(9, 9, 95, 16);
  popMatrix();

  // Delivery Control Valve (Red Handwheel)
  pushMatrix();
  translate(90, -102, 0);
  fill(210, 55, 55);
  box(24, 18, 24);
  translate(0, 0, 18);
  rotateX(HALF_PI);
  drawCylinder(14, 14, 4, 16);
  popMatrix();

  // 3. TOP HORIZONTAL HEADER & VENTURIMETER + U-TUBE MANOMETER
  pushMatrix();
  translate(0, -128, 0);
  pushMatrix();
  translate(54, 0, 0);
  rotateZ(HALF_PI);
  fill(150, 165, 185);
  drawCylinder(9, 9, 72, 16);
  popMatrix();

  // Venturimeter Converging Cone -> Throat -> Diverging Diffuser
  pushMatrix();
  translate(8, 0, 0);
  rotateZ(HALF_PI);
  fill(56, 189, 248, 175);
  drawCylinder(5.2, 9.5, 20, 18);
  translate(0, 14, 0);
  drawCylinder(5.2, 5.2, 10, 18);
  translate(0, 22, 0);
  drawCylinder(9.5, 5.2, 34, 18);
  popMatrix();

  // Outlet horizontal pipe to left drop
  pushMatrix();
  translate(-64, 0, 0);
  rotateZ(HALF_PI);
  fill(150, 165, 185);
  drawCylinder(9, 9, 82, 16);
  popMatrix();

  // Differential Mercury U-Tube Manometer hanging below Venturimeter
  pushMatrix();
  translate(0, 48, 18);
  fill(235, 240, 248);
  box(44, 72, 4);
  fill(210, 235, 255, 160);
  pushMatrix(); translate(-10, -4, 3); drawCylinder(2.5, 2.5, 56, 12); popMatrix();
  pushMatrix(); translate( 10, -4, 3); drawCylinder(2.5, 2.5, 56, 12); popMatrix();
  float hShift = map(curH, 0.2, 1.4, 3, 14);
  fill(220, 50, 50);
  pushMatrix(); translate(-10, 8 + hShift * 0.5, 3.5); drawCylinder(2.1, 2.1, 26 - hShift, 12); popMatrix();
  pushMatrix(); translate( 10, 8 - hShift * 0.5, 3.5); drawCylinder(2.1, 2.1, 26 + hShift, 12); popMatrix();
  popMatrix();
  popMatrix();

  // 4. LEFT VERTICAL PENSTOCK DROP PIPE, PRESSURE GAUGE & SPEAR VALVE NOZZLE
  pushMatrix();
  translate(-105, -28, 0);
  fill(145, 160, 180);
  drawCylinder(9, 9, 200, 16);
  popMatrix();

  pushMatrix();
  translate(-76, 70, 0);
  rotateZ(HALF_PI);
  fill(145, 160, 180);
  drawCylinder(9, 9, 60, 16);
  popMatrix();

  // Bourdon Pressure Gauge on Inlet Pipe
  pushMatrix();
  translate(-84, 44, 0);
  fill(190, 195, 205);
  drawCylinder(2.5, 2.5, 24, 10);
  translate(0, -16, 0);
  rotateX(HALF_PI);
  fill(245, 248, 252);
  drawCylinder(16, 16, 6, 20);
  rotateY(map(HS_HEAD, 0, 12, -1.8, 1.4));
  fill(220, 38, 38);
  box(2, 4, 12);
  popMatrix();

  // Spear Valve & Converging Nozzle
  pushMatrix();
  translate(-118, 70, 0);
  rotateZ(HALF_PI);
  fill(234, 179, 8);
  drawCylinder(15, 15, 4, 16);
  translate(0, -24, 0);
  fill(200, 205, 215);
  drawCylinder(2.2, 2.2, 48, 10);
  popMatrix();

  pushMatrix();
  translate(-40, 70, 0);
  rotateZ(HALF_PI);
  fill(180, 140, 55);
  drawCylinder(4.5, 9.0, 18, 16);
  popMatrix();

  // High-Velocity Water Jet hitting Pelton Buckets
  pushMatrix();
  translate(-16, 70, 0);
  rotateZ(HALF_PI);
  fill(56, 189, 248, 210);
  drawCylinder(3.8, 3.8, 34, 14);
  popMatrix();

  // 5. PELTON WHEEL RUNNER, BUCKETS, BRAKING NOZZLE & TRANSPARENT CASING
  pushMatrix();
  translate(12, 52, 0);
  pushMatrix();
  rotateX(HALF_PI);
  noFill();
  stroke(148, 163, 184, 170);
  strokeWeight(1.5);
  drawCylinder(56, 56, 44, 28);
  popMatrix();

  // Auxiliary Braking Nozzle (top-right of casing)
  pushMatrix();
  translate(30, -48, 0);
  rotateZ(-0.55);
  fill(160, 170, 185);
  noStroke();
  drawCylinder(3.5, 5.5, 18, 12);
  popMatrix();

  // Spinning Pelton Runner Disk + 16 Double-Hemispherical Buckets
  pushMatrix();
  rotateZ(wheelAngle);
  noStroke();
  fill(215, 165, 45);
  pushMatrix();
  rotateX(HALF_PI);
  drawCylinder(34, 34, 12, 24);
  popMatrix();

  for (int b = 0; b < 16; b++) {
    float ang = b * TWO_PI / 16.0;
    pushMatrix();
    rotateZ(ang);
    translate(40, 0, 0);
    fill(245, 195, 65);
    sphere(6.5);
    popMatrix();
  }
  popMatrix();

  // 6. ROPE BRAKE DYNAMOMETER
  pushMatrix();
  translate(0, 0, 42);
  pushMatrix();
  translate(0, 0, -20);
  rotateX(HALF_PI);
  fill(200, 210, 225);
  drawCylinder(5, 5, 48, 14);
  popMatrix();

  pushMatrix();
  rotateZ(wheelAngle);
  rotateX(HALF_PI);
  fill(75, 85, 105);
  drawCylinder(24, 24, 22, 24);
  popMatrix();

  stroke(215, 175, 95);
  strokeWeight(3.0);
  noFill();
  ellipse(0, 0, 51, 51);
  line(-25.5, 0, -25.5, 68);
  line(25.5, 0, 25.5, -58);

  noStroke();
  pushMatrix();
  translate(-25.5, 76, 0);
  fill(239, 68, 68);
  float wH = 8 + curW1 * 4.5;
  box(18, wH, 18);
  popMatrix();

  pushMatrix();
  translate(25.5, -68, 0);
  fill(56, 189, 248);
  box(12, 24, 10);
  popMatrix();
  popMatrix();
  popMatrix();

  // 7. ANIMATED 3D WATER PARTICLES THROUGH RIG
  noStroke();
  float flowSpeed = map(curQ, 0.001, 0.004, 0.003, 0.009);
  for (FlowParticle3D p : rigParticles) {
    p.t += (p.branch == 0) ? flowSpeed : flowSpeed * 1.8;
    if (p.t > 1.0) p.t -= 1.0;
    PVector pos = getRigPathPoint(p.t, p.branch, p.radial, p.angleOff);
    fill(p.branch == 0 ? color(56, 220, 255, 220) : color(186, 230, 253, 190));
    pushMatrix();
    translate(pos.x, pos.y, pos.z);
    sphere(p.branch == 0 ? 3.2 : 2.4);
    popMatrix();
  }

  popMatrix();
}

PVector getRigPathPoint(float t, int branch, float rad, float ang) {
  float rOff = rad * 4.0;
  float zOff = sin(ang) * rOff;
  float xyOff = cos(ang) * rOff;
  if (branch == 1) {
    float x = lerp(12, 85, t) + xyOff * 2.0;
    float y = 70 + 62 * t * t;
    return new PVector(x, y, zOff * 3.0);
  }
  if (t < 0.18) {
    float u = t / 0.18;
    return new PVector(142 + xyOff, lerp(118, -20, u), zOff);
  } else if (t < 0.34) {
    float u = (t - 0.18) / 0.16;
    return new PVector(lerp(112, 90, u) + xyOff, lerp(-20, -128, u), zOff);
  } else if (t < 0.62) {
    float u = (t - 0.34) / 0.28;
    return new PVector(lerp(90, -105, u), -128 + xyOff, zOff);
  } else if (t < 0.84) {
    float u = (t - 0.62) / 0.22;
    return new PVector(-105 + xyOff, lerp(-128, 70, u), zOff);
  } else {
    float u = (t - 0.84) / 0.16;
    return new PVector(lerp(-105, -2, u), 70 + xyOff * 0.6, zOff * 0.6);
  }
}

void drawCylinder(float rTop, float rBot, float h, int sides) {
  float halfH = h * 0.5;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = i * TWO_PI / sides;
    float ca = cos(a);
    float sa = sin(a);
    vertex(ca * rTop, -halfH, sa * rTop);
    vertex(ca * rBot,  halfH, sa * rBot);
  }
  endShape();
}

// ============================================================================
// SCREEN 1 HUD: LEFT CONTROLS, CENTER 3D VIEWPORT FRAME & RIGHT TELEMETRY
// ============================================================================
void drawScreen1_HUD() {
  float[] lay = getScreen1Layout();
  float topOff  = lay[0];
  float pad     = lay[2];
  float mainH   = lay[3];
  float leftW   = lay[4];
  float rightW  = lay[5];
  float centerX = lay[6];
  float centerW = lay[7];

  // Center 3D Viewport GUI Frame surrounding the 3D animation
  noFill();
  stroke(56, 189, 248, 130);
  strokeWeight(1.8);
  rect(centerX, topOff, centerW, mainH, 12 * uiScale);

  // Inner subtle technical bezel line
  stroke(56, 189, 248, 42);
  strokeWeight(1.0);
  rect(centerX + 5 * uiScale, topOff + 5 * uiScale, centerW - 10 * uiScale, mainH - 10 * uiScale, 9 * uiScale);

  // Corner Accent Brackets on Center 3D Frame
  float bLen = 20 * uiScale;
  stroke(56, 189, 248);
  strokeWeight(2.8);
  line(centerX, topOff + bLen, centerX, topOff);
  line(centerX, topOff, centerX + bLen, topOff);
  line(centerX + centerW - bLen, topOff, centerX + centerW, topOff);
  line(centerX + centerW, topOff, centerX + centerW, topOff + bLen);
  line(centerX, topOff + mainH - bLen, centerX, topOff + mainH);
  line(centerX, topOff + mainH, centerX + bLen, topOff + mainH);
  line(centerX + centerW - bLen, topOff + mainH, centerX + centerW, topOff + mainH);
  line(centerX + centerW, topOff + mainH - bLen, centerX + centerW, topOff + mainH);

  // Top-center floating badge inside 3D frame
  String viewLbl = "3D PELTON TURBINE RIG  |  DRAG TO ORBIT  |  ZOOM: " + nf(zoom3D, 1, 2) + "x";
  textSize(11.5 * uiScale);
  float vW = textWidth(viewLbl) + 22 * uiScale;
  noStroke();
  fill(18, 28, 45, 220);
  rect(centerX + (centerW - vW) * 0.5, topOff + 10 * uiScale, vW, 24 * uiScale, 6 * uiScale);
  fill(186, 230, 253);
  textAlign(CENTER, CENTER);
  text(viewLbl, centerX + centerW * 0.5, topOff + 22 * uiScale);

  // Bottom-center live schematic caption inside 3D frame
  String botCap = "Sump -> Centrifugal Pump -> Venturimeter (h=" + nf(curH, 1, 2) + "m) -> Spear Nozzle -> 16-Bucket Runner -> Rope Brake";
  textSize(10.8 * uiScale);
  float cW = min(centerW - 24 * uiScale, textWidth(botCap) + 20 * uiScale);
  fill(18, 28, 45, 220);
  rect(centerX + (centerW - cW) * 0.5, topOff + mainH - 32 * uiScale, cW, 22 * uiScale, 6 * uiScale);
  fill(148, 163, 184);
  text(botCap, centerX + centerW * 0.5, topOff + mainH - 21 * uiScale);

  // Left Control Card (Orbit, Zoom, Reading Selector, Brake Load W1 Slider)
  float cardX = pad;
  float cardY = topOff;
  float cardW = leftW;
  float cardH = mainH;

  drawPanelCard(cardX, cardY, cardW, cardH, "3D RIG CONTROLS & LOAD");

  float y = cardY + 42 * uiScale;
  float btnW = (cardW - 34 * uiScale) / 2.0;
  float btnH = 30 * uiScale;

  drawButton(cardX + 12 * uiScale, y, btnW, btnH, autoOrbit ? "Auto-Orbit: ON" : "Auto-Orbit: OFF", autoOrbit);
  drawButton(cardX + 20 * uiScale + btnW, y, btnW * 0.48, btnH, "Zoom +", false);
  drawButton(cardX + 20 * uiScale + btnW * 1.52, y, btnW * 0.48, btnH, "Zoom -", false);

  y += 42 * uiScale;
  fill(160, 190, 225);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("Select Lab Reading (R1 - R5):", cardX + 12 * uiScale, y);

  y += 18 * uiScale;
  float rBtnW = (cardW - 40 * uiScale) / 5.0;
  for (int i = 0; i < 5; i++) {
    boolean isSel = (!customSliderActive && selectedReading == i);
    drawButton(cardX + 12 * uiScale + i * (rBtnW + 4 * uiScale), y, rBtnW, 30 * uiScale, "R" + (i + 1), isSel);
  }

  // Interactive Brake Load W1 Slider
  y += 48 * uiScale;
  fill(224, 242, 254);
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text("Brake Hanger Load W1: " + nf(curW1, 1, 2) + " kg", cardX + 12 * uiScale, y);

  y += 22 * uiScale;
  float slX = cardX + 16 * uiScale;
  float slW = cardW - 32 * uiScale;
  float slH = 10 * uiScale;
  noStroke();
  fill(35, 52, 82);
  rect(slX, y, slW, slH, 5 * uiScale);
  float frac = constrain((curW1 - 1.0) / 4.0, 0, 1);
  fill(56, 189, 248);
  rect(slX, y, slW * frac, slH, 5 * uiScale);
  fill(255);
  ellipse(slX + slW * frac, y + slH * 0.5, 20 * uiScale, 20 * uiScale);

  // Legend & Touch Hint
  y += 32 * uiScale;
  fill(148, 163, 184);
  textSize(11.2 * uiScale);
  text("Drag inside center frame to orbit 3D.", cardX + 12 * uiScale, y);
  y += 17 * uiScale;
  text("Increasing W1 slows Pelton runner N", cardX + 12 * uiScale, y);
  y += 16 * uiScale;
  text("and raises shaft power Po & efficiency.", cardX + 12 * uiScale, y);

  // 3D Part Callout Legend
  y += 26 * uiScale;
  drawLegendDot(cardX + 16 * uiScale, y, color(56, 189, 248), "Venturimeter & High-Speed Jet");
  y += 20 * uiScale;
  drawLegendDot(cardX + 16 * uiScale, y, color(245, 195, 65), "Pelton Runner (16 Buckets)");
  y += 20 * uiScale;
  drawLegendDot(cardX + 16 * uiScale, y, color(239, 68, 68), "Rope Brake Load W1 & Manometer");

  // Right Telemetry HUD Card
  float tW = rightW;
  float tX = width - tW - pad;
  float tY = topOff;
  float tH = mainH;
  drawPanelCard(tX, tY, tW, tH, "LIVE TELEMETRY & RESULTS");

  String[][] rows = {
    { "Supply Head (Hs)", nf(HS_HEAD, 1, 1) + " m (0.8 kg/cm^2)" },
    { "Venturi Head (h)", nf(curH, 1, 2) + " m Hg-water" },
    { "Discharge (Q)", nf(curQ * 1000.0, 1, 3) + " x10^-3 m^3/s" },
    { "Input Power (Pi)", nf(curPi, 1, 3) + " kW" },
    { "Hanger Load (W1)", nf(curW1, 1, 2) + " kg (W0=1 kg)" },
    { "Spring Load (W2)", nf(curW2, 1, 2) + " kg" },
    { "Effective Load (Wa)", nf(curWa, 1, 4) + " kN" },
    { "Runner Speed (N)", nf(curN, 1, 0) + " rpm" },
    { "Output Power (Po)", nf(curPo, 1, 4) + " kW" },
    { "Efficiency (eta)", nf(curEta, 1, 3) + " %" }
  };

  float ry = tY + 42 * uiScale;
  float stepY = (tH - 54 * uiScale) / rows.length;
  for (int i = 0; i < rows.length; i++) {
    boolean highlight = (i >= 7);
    if (highlight) {
      noStroke();
      fill(i == 9 ? color(22, 101, 52, 180) : color(30, 58, 110, 160));
      rect(tX + 10 * uiScale, ry - 4 * uiScale, tW - 20 * uiScale, stepY - 3 * uiScale, 6 * uiScale);
    }
    fill(175, 200, 230);
    textAlign(LEFT, CENTER);
    textSize(12 * uiScale);
    text(rows[i][0], tX + 14 * uiScale, ry + stepY * 0.35);

    fill(highlight ? color(134, 239, 172) : 255);
    textAlign(RIGHT, CENTER);
    text(rows[i][1], tX + tW - 14 * uiScale, ry + stepY * 0.35);
    ry += stepY;
  }
}

// ============================================================================
// SCREEN 2: 2D TRANSPARENT CUTAWAY & CFD FLOW VISUALIZATION
// ============================================================================
void drawScreen2_CutawayPhysics() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;

  // Main Cutaway Viewport (Left 67%)
  float boxX = pad;
  float boxY = topOff;
  float boxW = width * 0.67;
  float boxH = height - topOff - botOff;

  drawPanelCard(boxX, boxY, boxW, boxH, "2D CUTAWAY: SPEAR NOZZLE, PELTON BUCKET & VENTURI FLOW");

  float simX = boxX + 14 * uiScale;
  float simY = boxY + 38 * uiScale;
  float simW = boxW - 28 * uiScale;
  float simH = boxH - 86 * uiScale;

  noStroke();
  fill(10, 16, 28);
  rect(simX, simY, simW, simH, 8 * uiScale);

  // Venturimeter Cross-Section
  float vx0 = simX + simW * 0.04;
  float vy0 = simY + simH * 0.16;
  float vw  = simW * 0.34;
  float vh  = simH * 0.11;
  stroke(120, 170, 220);
  strokeWeight(2);
  fill(25, 75, 130, 150);
  beginShape();
  vertex(vx0, vy0 - vh * 0.5);
  vertex(vx0 + vw * 0.25, vy0 - vh * 0.5);
  vertex(vx0 + vw * 0.42, vy0 - vh * 0.22);
  vertex(vx0 + vw * 0.55, vy0 - vh * 0.22);
  vertex(vx0 + vw * 0.88, vy0 - vh * 0.5);
  vertex(vx0 + vw, vy0 - vh * 0.5);
  vertex(vx0 + vw, vy0 + vh * 0.5);
  vertex(vx0 + vw * 0.88, vy0 + vh * 0.5);
  vertex(vx0 + vw * 0.55, vy0 + vh * 0.22);
  vertex(vx0 + vw * 0.42, vy0 + vh * 0.22);
  vertex(vx0 + vw * 0.25, vy0 + vh * 0.5);
  vertex(vx0, vy0 + vh * 0.5);
  endShape(CLOSE);

  fill(224, 242, 254);
  textAlign(LEFT, CENTER);
  textSize(11.5 * uiScale);
  text("Venturimeter: P1=0.20 | P2=0.12 kg/cm^2 -> h=0.80 m | Q=2.789x10^-3 m^3/s", vx0, vy0 - vh * 0.82);

  // Instantaneous Streamlines in Nozzle & Bucket Jet Deflection Zone
  float nozStartX = simX + simW * 0.05;
  float nozExitX  = simX + simW * 0.36;
  float jetCenterY = simY + simH * 0.56;
  float wheelCX = simX + simW * 0.66;
  float wheelCY = simY + simH * 0.44;
  float wheelR  = min(simW, simH) * 0.27;

  // Nozzle outer walls
  stroke(148, 163, 184);
  strokeWeight(2.5);
  fill(30, 50, 80, 160);
  beginShape();
  vertex(nozStartX, jetCenterY - 26 * uiScale);
  vertex(nozExitX - 36 * uiScale, jetCenterY - 26 * uiScale);
  vertex(nozExitX, jetCenterY - 11 * uiScale);
  vertex(nozExitX, jetCenterY + 11 * uiScale);
  vertex(nozExitX - 36 * uiScale, jetCenterY + 26 * uiScale);
  vertex(nozStartX, jetCenterY + 26 * uiScale);
  endShape(CLOSE);

  // Spear Needle inside Nozzle
  fill(234, 179, 8);
  noStroke();
  beginShape();
  vertex(nozStartX - 10 * uiScale, jetCenterY - 5 * uiScale);
  vertex(nozExitX - 24 * uiScale, jetCenterY - 5 * uiScale);
  vertex(nozExitX + 8 * uiScale, jetCenterY);
  vertex(nozExitX - 24 * uiScale, jetCenterY + 5 * uiScale);
  vertex(nozStartX - 10 * uiScale, jetCenterY + 5 * uiScale);
  endShape(CLOSE);

  // Instantaneous Streamlines
  stroke(56, 189, 248, 95);
  strokeWeight(1.3);
  noFill();
  float waveAmp = unsteadyMode ? sin(simTime * 3.0) * 6.0 * uiScale : 0.0;
  for (int s = -3; s <= 3; s++) {
    float offY = s * 3.2 * uiScale;
    beginShape();
    for (int k = 0; k <= 24; k++) {
      float u = k / 24.0;
      float sx = lerp(nozStartX + 10 * uiScale, wheelCX - wheelR * 0.15, u);
      float sy = jetCenterY + offY * (1.0 - 0.55 * min(1.0, u * 2.0)) + waveAmp * sin(u * PI);
      if (u > 0.78) {
        float d = (u - 0.78) / 0.22;
        float dir = (s >= 0) ? 1.0 : -1.0;
        sx -= d * d * 42 * uiScale;
        sy += dir * d * d * 48 * uiScale;
      }
      vertex(sx, sy);
    }
    endShape();
  }

  // Velocity Profile Arrows inside Jet
  float vJet = 0.98 * sqrt(2.0 * G_ACCEL * HS_HEAD);
  for (int a = 0; a < 4; a++) {
    float ax = lerp(nozExitX + 14 * uiScale, wheelCX - wheelR - 14 * uiScale, a / 3.0);
    draw2DArrow(ax, jetCenterY, ax + 24 * uiScale, jetCenterY, color(34, 211, 238));
  }

  // Pelton Runner Wheel & Double-Cup Buckets
  pushMatrix();
  translate(wheelCX, wheelCY);
  noFill();
  stroke(100, 116, 139, 150);
  strokeWeight(3);
  arc(0, 0, wheelR * 2.55, wheelR * 2.55, -PI * 1.15, PI * 0.25);

  rotate(wheelAngle);
  fill(202, 138, 4);
  stroke(253, 224, 71);
  strokeWeight(1.5);
  ellipse(0, 0, wheelR * 1.45, wheelR * 1.45);
  for (int b = 0; b < 14; b++) {
    float ang = b * TWO_PI / 14.0;
    pushMatrix();
    rotate(ang);
    translate(wheelR * 0.86, 0);
    fill(234, 179, 8);
    arc(0, 0, 22 * uiScale, 26 * uiScale, -HALF_PI, HALF_PI);
    popMatrix();
  }
  popMatrix();

  // CFD Velocity-Color-Coded Particles + Pathline Trails
  float pSpeed = (unsteadyMode ? (1.0 + 0.25 * sin(simTime * 3.5)) : 1.0) * 6.5 * uiScale;
  for (FluidParticle2D p : cutParticles) {
    p.x += pSpeed;
    float targetY = jetCenterY + (unsteadyMode ? sin(simTime * 3.0 + p.x * 0.02) * 5.0 * uiScale : 0);
    p.y = lerp(p.y, targetY + random(-6, 6) * uiScale, 0.08);
    if (p.x > wheelCX - wheelR * 0.1) {
      float dir = (p.y >= jetCenterY) ? 1.0 : -1.0;
      p.x -= pSpeed * 1.35;
      p.y += dir * pSpeed * 0.95;
    }
    if (p.x > simX + simW - 10 || p.x < nozStartX || p.y < simY + 10 || p.y > simY + simH - 10) {
      p.x = nozStartX + random(0, 40 * uiScale);
      p.y = jetCenterY + random(-14, 14) * uiScale;
      p.resetTrail();
    }
    for (int k = 15; k > 0; k--) {
      p.trailX[k] = p.trailX[k - 1];
      p.trailY[k] = p.trailY[k - 1];
    }
    p.trailX[0] = p.x;
    p.trailY[0] = p.y;
    if (p.trailCount < 16) p.trailCount++;

    stroke(56, 189, 248, 110);
    strokeWeight(1.4);
    noFill();
    beginShape();
    for (int k = 0; k < p.trailCount; k++) vertex(p.trailX[k], p.trailY[k]);
    endShape();

    noStroke();
    fill(125, 211, 252);
    ellipse(p.x, p.y, 4.5 * uiScale, 4.5 * uiScale);
  }

  // Interactive Dye Tracer Streakline Nozzle
  float injX = simX + dyeNozzleRelX * simW;
  float injY = simY + dyeNozzleRelY * simH;
  for (int i = 0; i < dyeParticles.size(); i++) {
    FluidParticle2D dp = dyeParticles.get(i);
    dp.x += pSpeed * 1.05;
    dp.y += (unsteadyMode ? sin(simTime * 4.0 + i * 0.3) * 2.2 * uiScale : 0);
    if (dp.x > wheelCX - wheelR * 0.12) {
      float dir = (dp.y >= jetCenterY) ? 1.0 : -1.0;
      dp.x -= pSpeed * 1.3;
      dp.y += dir * pSpeed * 1.1;
    }
    if (dp.x > simX + simW - 10 || dp.x < simX + 8 || dp.y < simY + 8 || dp.y > simY + simH - 8) {
      dp.x = injX;
      dp.y = injY;
    }
  }
  stroke(244, 63, 94, 210);
  strokeWeight(2.2);
  noFill();
  beginShape();
  for (FluidParticle2D dp : dyeParticles) {
    if (dist(dp.x, dp.y, injX, injY) < simW * 0.55) vertex(dp.x, dp.y);
  }
  endShape();

  fill(244, 63, 94);
  stroke(255);
  strokeWeight(1.5);
  ellipse(injX, injY, 12 * uiScale, 12 * uiScale);
  fill(254, 205, 211);
  textAlign(LEFT, CENTER);
  textSize(11 * uiScale);
  text("Dye Injector (Tap to relocate)", injX + 10 * uiScale, injY - 8 * uiScale);

  // Bottom Controls Bar inside Cutaway Card
  float ctrlY = simY + simH + 8 * uiScale;
  drawButton(simX, ctrlY, 175 * uiScale, 30 * uiScale, unsteadyMode ? "Mode: UNSTEADY WAVE" : "Mode: STEADY FLOW", unsteadyMode);
  drawButton(simX + 185 * uiScale, ctrlY, 130 * uiScale, 30 * uiScale, "Reset Trails", false);

  fill(148, 163, 184);
  textAlign(RIGHT, CENTER);
  textSize(11.5 * uiScale);
  text("V_jet = " + nf(vJet, 1, 2) + " m/s  |  Bucket u = " + nf(PI * 0.16 * curN / 60.0, 1, 2) + " m/s", simX + simW, ctrlY + 15 * uiScale);

  // Right Panel: Quantitative Cutaway Gauges & Energy Transfer Readout
  float rX = boxX + boxW + 14 * uiScale;
  float rY = topOff;
  float rW = width - rX - pad;
  float rH = boxH;
  drawPanelCard(rX, rY, rW, rH, "CUTAWAY JET & BRAKE PHYSICS");

  float py = rY + 46 * uiScale;
  String[][] phys = {
    { "Nozzle Supply Head (Hs)", nf(HS_HEAD, 1, 1) + " m" },
    { "Theoretical Jet Vel (V1)", nf(vJet, 1, 2) + " m/s" },
    { "Runner Speed (N)", nf(curN, 1, 0) + " rpm" },
    { "Bucket Deflection Angle", "165 deg (Splitter)" },
    { "Venturi Head Drop (h)", nf(curH, 1, 2) + " m" },
    { "Volume Flow Rate (Q)", nf(curQ * 1000.0, 1, 3) + " x10^-3 m^3/s" },
    { "Hydraulic Input (Pi)", nf(curPi, 1, 3) + " kW" },
    { "Net Brake Load (Wa)", nf(curWa, 1, 4) + " kN" },
    { "Effective Radius (Re)", nf(R_EFF, 1, 4) + " m" },
    { "Shaft Output (Po)", nf(curPo, 1, 4) + " kW" },
    { "Turbine Efficiency (eta)", nf(curEta, 1, 3) + " %" }
  };

  float rowStep = (rH - 62 * uiScale) / phys.length;
  for (int i = 0; i < phys.length; i++) {
    fill(175, 200, 230);
    textAlign(LEFT, CENTER);
    textSize(12 * uiScale);
    text(phys[i][0], rX + 14 * uiScale, py + rowStep * 0.35);

    fill(i >= 9 ? color(134, 239, 172) : 255);
    textAlign(RIGHT, CENTER);
    text(phys[i][1], rX + rW - 14 * uiScale, py + rowStep * 0.35);
    py += rowStep;
  }
}

// ============================================================================
// SCREEN 3: 7-STEP MATHEMATICAL DERIVATION & CONTROL-VOLUME SCHEMATIC
// ============================================================================
void drawScreen3_Derivation() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;

  float lX = pad;
  float lY = topOff;
  float lW = width * 0.55;
  float lH = height - topOff - botOff;
  drawPanelCard(lX, lY, lW, lH, "GOVERNING EQUATIONS & 7-STEP DERIVATION");

  float stepAreaH = lH - 92 * uiScale;
  float stepH = stepAreaH / derivTitles.length;
  float sy = lY + 40 * uiScale;

  for (int i = 0; i < derivTitles.length; i++) {
    boolean active = (i == derivStep);
    fill(active ? color(30, 58, 110) : color(20, 31, 50));
    stroke(active ? color(56, 189, 248) : color(42, 60, 90));
    strokeWeight(active ? 1.8 : 1.0);
    rect(lX + 34 * uiScale, sy + 2 * uiScale, lW - 48 * uiScale, stepH - 5 * uiScale, 7 * uiScale);

    if (active) {
      float pulse = sin(frameCount * 0.14) * 3.5 * uiScale;
      draw2DArrow(lX + 8 * uiScale + pulse, sy + stepH * 0.5, lX + 30 * uiScale + pulse, sy + stepH * 0.5, color(244, 63, 94));
    }

    fill(active ? color(125, 211, 252) : color(160, 185, 215));
    textAlign(LEFT, TOP);
    textSize(11.5 * uiScale);
    text(derivTitles[i], lX + 44 * uiScale, sy + 5 * uiScale);

    fill(active ? 255 : color(215, 230, 245));
    textSize(12.5 * uiScale);
    text(derivFormulas[i], lX + 44 * uiScale, sy + 21 * uiScale);

    if (active && stepH > 46 * uiScale) {
      fill(148, 163, 184);
      textSize(10.5 * uiScale);
      text(derivNotes[i], lX + 44 * uiScale, sy + 38 * uiScale);
    }
    sy += stepH;
  }

  float bY = lY + lH - 42 * uiScale;
  drawButton(lX + 16 * uiScale, bY, 120 * uiScale, 30 * uiScale, "< Prev Step", false);
  drawButton(lX + 146 * uiScale, bY, 120 * uiScale, 30 * uiScale, "Next Step >", false);
  drawButton(lX + lW - 165 * uiScale, bY, 150 * uiScale, 30 * uiScale, autoDerive ? "Auto-Derive: ON" : "Auto-Derive: OFF", autoDerive);

  float rX = lX + lW + 14 * uiScale;
  float rY = topOff;
  float rW = width - rX - pad;
  float rH = lH;
  drawPanelCard(rX, rY, rW, rH, "CONTROL-VOLUME & ENERGY BALANCE");

  float cx = rX + rW * 0.5;
  float diagY = rY + 48 * uiScale;
  float blkH = (rH - 135 * uiScale) / 4.0;
  float gapH = 22 * uiScale;

  drawSchematicBlock(rX + 18 * uiScale, diagY, rW - 36 * uiScale, blkH,
    "1. VENTURIMETER FLOW METERING",
    "h = (P1 - P2)*10 = " + nf(curH, 1, 2) + " m   ==>   Q = K*sqrt(h) = " + nf(curQ * 1000, 1, 3) + " x10^-3 m^3/s",
    color(30, 64, 115));

  draw2DArrow(cx, diagY + blkH, cx, diagY + blkH + gapH - 2 * uiScale, color(56, 189, 248));

  float y2 = diagY + blkH + gapH;
  drawSchematicBlock(rX + 18 * uiScale, y2, rW - 36 * uiScale, blkH,
    "2. NOZZLE JET & PELTON BUCKET IMPULSE",
    "Hs = 8.0 m  ==>  Input Power Pi = 9.81 * Q * Hs = " + nf(curPi, 1, 3) + " kW",
    color(28, 78, 95));

  draw2DArrow(cx, y2 + blkH, cx, y2 + blkH + gapH - 2 * uiScale, color(250, 204, 21));

  float y3 = y2 + blkH + gapH;
  drawSchematicBlock(rX + 18 * uiScale, y3, rW - 36 * uiScale, blkH,
    "3. ROPE BRAKE DYNAMOMETER (Re = 0.0393 m)",
    "Wa = ((1 + " + nf(curW1, 1, 1) + " - " + nf(curW2, 1, 2) + ")*9.81)/1000 = " + nf(curWa, 1, 4) + " kN  |  N = " + nf(curN, 1, 0) + " rpm",
    color(76, 55, 25));

  draw2DArrow(cx, y3 + blkH, cx, y3 + blkH + gapH - 2 * uiScale, color(74, 222, 128));

  float y4 = y3 + blkH + gapH;
  drawSchematicBlock(rX + 18 * uiScale, y4, rW - 36 * uiScale, blkH,
    "4. SHAFT OUTPUT & OVERALL EFFICIENCY",
    "Po = (2*pi*N*Wa*Re)/60 = " + nf(curPo, 1, 4) + " kW   ==>   eta = (Po/Pi)*100 = " + nf(curEta, 1, 3) + " %",
    color(22, 85, 52));
}

// ============================================================================
// SCREEN 4: 6-STEP EXPERIMENTAL PROCEDURE & RIG CHECKLIST
// ============================================================================
void drawScreen4_Procedure() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;

  float lX = pad;
  float lY = topOff;
  float lW = width * 0.56;
  float lH = height - topOff - botOff;
  drawPanelCard(lX, lY, lW, lH, "EXPERIMENTAL PROCEDURE (6-STEP LAB PROTOCOL)");

  float listH = lH - 92 * uiScale;
  float itemH = listH / procTitles.length;
  float py = lY + 40 * uiScale;

  for (int i = 0; i < procTitles.length; i++) {
    boolean active = (i == procStep);
    boolean done   = (i < procStep);
    fill(active ? color(30, 58, 110) : (done ? color(20, 44, 42) : color(20, 31, 50)));
    stroke(active ? color(56, 189, 248) : (done ? color(34, 197, 94, 150) : color(42, 60, 90)));
    strokeWeight(active ? 1.8 : 1.0);
    rect(lX + 14 * uiScale, py + 2 * uiScale, lW - 28 * uiScale, itemH - 5 * uiScale, 8 * uiScale);

    // Status pill
    String tag = active ? "ACTIVE" : (done ? "DONE" : "NEXT");
    fill(active ? color(37, 99, 235) : (done ? color(22, 101, 52) : color(51, 65, 85)));
    noStroke();
    rect(lX + lW - 76 * uiScale, py + 7 * uiScale, 52 * uiScale, 18 * uiScale, 5 * uiScale);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(10 * uiScale);
    text(tag, lX + lW - 50 * uiScale, py + 16 * uiScale);

    fill(active ? color(125, 211, 252) : (done ? color(134, 239, 172) : color(180, 200, 225)));
    textAlign(LEFT, TOP);
    textSize(12 * uiScale);
    text(procTitles[i], lX + 24 * uiScale, py + 6 * uiScale);

    fill(active ? 245 : color(160, 178, 205));
    textSize(10.8 * uiScale);
    text(procDetails[i], lX + 24 * uiScale, py + 24 * uiScale, lW - 108 * uiScale, itemH - 26 * uiScale);

    py += itemH;
  }

  float bY = lY + lH - 42 * uiScale;
  drawButton(lX + 16 * uiScale, bY, 120 * uiScale, 30 * uiScale, "< Prev Step", false);
  drawButton(lX + 146 * uiScale, bY, 120 * uiScale, 30 * uiScale, "Next Step >", false);
  drawButton(lX + lW - 165 * uiScale, bY, 150 * uiScale, 30 * uiScale, autoDemo ? "Auto-Demo: ON" : "Auto-Demo: OFF", autoDemo);

  // Right Panel: Interactive Visual Rig Check & Safety Parameter Box
  float rX = lX + lW + 14 * uiScale;
  float rY = topOff;
  float rW = width - rX - pad;
  float rH = lH;
  drawPanelCard(rX, rY, rW, rH, "STEP FOCUS & INSTRUMENT CHECKLIST");

  // Visual Station Diagram inside Right Card
  float visX = rX + 16 * uiScale;
  float visY = rY + 42 * uiScale;
  float visW = rW - 32 * uiScale;
  float visH = rH * 0.44;
  fill(12, 20, 34);
  stroke(56, 189, 248, 100);
  strokeWeight(1.2);
  rect(visX, visY, visW, visH, 8 * uiScale);

  drawProcedureSchematic(visX, visY, visW, visH, procStep);

  // Key Apparatus Specifications & Safety Checklist
  float specY = visY + visH + 14 * uiScale;
  String[][] checks = {
    { "Brake Drum Circumference", "2*pi*R = 200 mm (0.200 m)" },
    { "Brake Rope Thickness (t)", "15 mm (0.015 m) -> Re = 0.0393 m" },
    { "Venturimeter Constant (K)", "3.12 x 10^-3 m^3 / (s * sqrt(m))" },
    { "Constant Supply Head (Hs)", "0.8 kg/cm^2 = 8.0 m of water" },
    { "Dead Weight Hanger (W0)", "1.0 kg (Always included in Wa)" },
    { "Pre-Start Safety Check", "Delivery valve CLOSED before start" }
  };

  float rowH = (rY + rH - specY - 12 * uiScale) / checks.length;
  for (int i = 0; i < checks.length; i++) {
    boolean hi = (i == procStep);
    if (hi) {
      noStroke();
      fill(30, 58, 110, 170);
      rect(visX, specY - 2 * uiScale, visW, rowH - 3 * uiScale, 5 * uiScale);
    }
    fill(175, 200, 230);
    textAlign(LEFT, CENTER);
    textSize(11.5 * uiScale);
    text(checks[i][0], visX + 8 * uiScale, specY + rowH * 0.4);

    fill(hi ? color(125, 211, 252) : 240);
    textAlign(RIGHT, CENTER);
    text(checks[i][1], visX + visW - 8 * uiScale, specY + rowH * 0.4);
    specY += rowH;
  }
}

void drawProcedureSchematic(float x, float y, float w, float h, int step) {
  float cx = x + w * 0.5;
  float cy = y + h * 0.48;

  // Draw schematic blocks of the test rig and highlight the active station
  float bw = w * 0.24;
  float bh = h * 0.34;

  // Block A: Pump & Delivery Valve (Step 1, 2)
  boolean hiPump = (step == 1 || step == 2);
  fill(hiPump ? color(37, 99, 235) : color(26, 40, 66));
  stroke(hiPump ? color(125, 211, 252) : color(70, 95, 130));
  rect(x + w * 0.06, cy - bh * 0.5, bw, bh, 7 * uiScale);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(11 * uiScale);
  text("PUMP &\nVALVE", x + w * 0.06 + bw * 0.5, cy);

  draw2DArrow(x + w * 0.06 + bw, cy, x + w * 0.38, cy, color(56, 189, 248));

  // Block B: Venturi & Gauge (Step 2, 3)
  boolean hiVent = (step == 2 || step == 3);
  fill(hiVent ? color(37, 99, 235) : color(26, 40, 66));
  stroke(hiVent ? color(125, 211, 252) : color(70, 95, 130));
  rect(x + w * 0.38, cy - bh * 0.5, bw, bh, 7 * uiScale);
  fill(255);
  text("VENTURI &\nGAUGE (Hs)", x + w * 0.38 + bw * 0.5, cy);

  draw2DArrow(x + w * 0.38 + bw, cy, x + w * 0.70, cy, color(56, 189, 248));

  // Block C: Pelton Runner & Rope Brake (Step 0, 4, 5)
  boolean hiBrake = (step == 0 || step == 4 || step == 5);
  fill(hiBrake ? color(37, 99, 235) : color(26, 40, 66));
  stroke(hiBrake ? color(125, 211, 252) : color(70, 95, 130));
  rect(x + w * 0.70, cy - bh * 0.5, bw, bh, 7 * uiScale);
  fill(255);
  text("PELTON &\nROPE BRAKE", x + w * 0.70 + bw * 0.5, cy);

  // Caption banner at bottom of schematic
  String[] stepFocus = {
    "Focus: Measure Brake Drum (0.2 m) & Rope Thickness (15 mm)",
    "Focus: Open Spear Nozzle & Prime Centrifugal Pump Casing",
    "Focus: Regulate Delivery Valve to Maintain Hs = 0.8 kg/cm^2 (8 m)",
    "Focus: Read Venturi Manometer P1 = 0.20, P2 = 0.12 kg/cm^2",
    "Focus: Load Hanger W1, Read Spring Balance W2 & Tachometer N",
    "Focus: Complete 5 Load Runs (1-5 kg), Unload & Switch Off Pump"
  };
  fill(134, 239, 172);
  textAlign(CENTER, CENTER);
  textSize(11 * uiScale);
  text(stepFocus[constrain(step, 0, 5)], cx, y + h - 18 * uiScale);
}

// ============================================================================
// SCREEN 5: CASIO fx-991MS SCIENTIFIC CALCULATOR & BODMAS MODEL CALCULATION
// ============================================================================
void syncCasioToStep(int step) {
  bodmasStep = constrain(step, 0, 7);
  switch (bodmasStep) {
    case 0:
      casioTopLine = "(0.20-0.12)*10";
      casioBotLine = nf(curH, 1, 2) + " m";
      break;
    case 1:
      casioTopLine = "3.12E-3*sqrt(" + nf(curH, 1, 2) + ")";
      casioBotLine = nf(curQ * 1000.0, 1, 3) + "E-3";
      break;
    case 2:
      casioTopLine = "9.81*" + nf(curQ * 1000.0, 1, 3) + "E-3*8";
      casioBotLine = nf(curPi, 1, 3) + " kW";
      break;
    case 3:
      casioTopLine = "(0.2/(2*pi))+(0.015/2)";
      casioBotLine = nf(R_EFF, 1, 4) + " m";
      break;
    case 4:
      casioTopLine = "((1+" + nf(curW1, 1, 1) + "-" + nf(curW2, 1, 2) + ")*9.81)/1000";
      casioBotLine = nf(curWa, 1, 4) + " kN";
      break;
    case 5:
      casioTopLine = "(2*pi*" + nf(curN, 1, 0) + "*" + nf(curWa, 1, 4) + "*0.0393)/60";
      casioBotLine = nf(curPo, 1, 4) + " kW";
      break;
    case 6:
      casioTopLine = "(" + nf(curPo, 1, 4) + "/" + nf(curPi, 1, 3) + ")*100";
      casioBotLine = nf(curEta, 1, 3) + " %";
      break;
    case 7:
      casioTopLine = "R" + (selectedReading + 1) + ": Po/Pi * 100";
      casioBotLine = "eta = " + nf(curEta, 1, 3) + " %";
      break;
  }
  casioLastAns = casioBotLine;
}

int getActiveBodmasIndex(int step) {
  // 0:B, 1:O, 2:D, 3:M, 4:A, 5:S
  int[] mapIdx = { 0, 1, 3, 2, 4, 3, 2, 0 };
  return mapIdx[constrain(step, 0, 7)];
}

void drawScreen5_CasioCalc() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;

  // Left Panel: Casio fx-991MS Realistic Scientific Calculator (42% width)
  float cX = pad;
  float cY = topOff;
  float cW = width * 0.42;
  float cH = height - topOff - botOff;
  drawPanelCard(cX, cY, cW, cH, "CASIO fx-991MS SCIENTIFIC CALCULATOR");

  float bodyX = cX + 18 * uiScale;
  float bodyY = cY + 38 * uiScale;
  float bodyW = cW - 36 * uiScale;
  float bodyH = cH - 50 * uiScale;

  // Calculator Casing
  fill(32, 41, 58);
  stroke(82, 102, 135);
  strokeWeight(2);
  rect(bodyX, bodyY, bodyW, bodyH, 14 * uiScale);

  // Brand & Solar Cell Strip
  fill(226, 232, 240);
  textAlign(LEFT, CENTER);
  textSize(12.5 * uiScale);
  text("CASIO", bodyX + 14 * uiScale, bodyY + 18 * uiScale);
  fill(56, 189, 248);
  textSize(10.5 * uiScale);
  text("fx-991MS  S-V.P.A.M.", bodyX + 66 * uiScale, bodyY + 18 * uiScale);

  // Solar panel
  fill(55, 38, 32);
  stroke(110, 125, 145);
  rect(bodyX + bodyW - 88 * uiScale, bodyY + 9 * uiScale, 74 * uiScale, 18 * uiScale, 3 * uiScale);

  // Two-Line LCD Screen
  float lcdX = bodyX + 14 * uiScale;
  float lcdY = bodyY + 34 * uiScale;
  float lcdW = bodyW - 28 * uiScale;
  float lcdH = 58 * uiScale;
  fill(168, 192, 162);
  stroke(45, 58, 48);
  strokeWeight(2);
  rect(lcdX, lcdY, lcdW, lcdH, 6 * uiScale);

  // LCD Indicators
  fill(25, 42, 28);
  textAlign(LEFT, TOP);
  textSize(9.5 * uiScale);
  String modeStr = (casioShiftOn ? "[S] " : "") + (casioAlphaOn ? "[A] " : "") + "DEG   MATH   BODMAS";
  text(modeStr, lcdX + 8 * uiScale, lcdY + 4 * uiScale);

  // Top expression line
  textAlign(LEFT, CENTER);
  textSize(13 * uiScale);
  text(casioTopLine, lcdX + 8 * uiScale, lcdY + 25 * uiScale);

  // Bottom result line
  textAlign(RIGHT, CENTER);
  textSize(17 * uiScale);
  text(casioBotLine, lcdX + lcdW - 10 * uiScale, lcdY + 44 * uiScale);

  // Keypad Grid (6 rows x 5 cols)
  String[][] keys = {
    { "SHIFT", "ALPHA", "MODE", "DEL", "AC" },
    { "sqrt",  "x^2",   "^",    "(",   ")"  },
    { "7",     "8",     "9",    "sin", "cos"},
    { "4",     "5",     "6",    "*",   "/"  },
    { "1",     "2",     "3",    "+",   "-"  },
    { "0",     ".",     "pi",   "Ans", "="  }
  };

  float kpX = bodyX + 12 * uiScale;
  float kpY = lcdY + lcdH + 12 * uiScale;
  float kpW = bodyW - 24 * uiScale;
  float kpH = bodyY + bodyH - kpY - 12 * uiScale;
  float gap = 6 * uiScale;
  float keyW = (kpW - gap * 4) / 5.0;
  float keyH = (kpH - gap * 5) / 6.0;

  for (int r = 0; r < 6; r++) {
    for (int c = 0; c < 5; c++) {
      String k = keys[r][c];
      float kx = kpX + c * (keyW + gap);
      float ky = kpY + r * (keyH + gap);

      color bg = color(51, 65, 85);
      color fg = color(255);
      if (k.equals("SHIFT")) { bg = color(180, 130, 30); }
      else if (k.equals("ALPHA")) { bg = color(165, 45, 70); }
      else if (k.equals("DEL") || k.equals("AC")) { bg = color(185, 55, 55); }
      else if (k.equals("=")) { bg = color(37, 99, 235); }
      else if (r >= 2 && c <= 2) { bg = color(71, 85, 105); }

      fill(bg);
      stroke(100, 116, 139);
      strokeWeight(1);
      rect(kx, ky, keyW, keyH, 6 * uiScale);

      fill(fg);
      textAlign(CENTER, CENTER);
      textSize(12 * uiScale);
      text(k, kx + keyW * 0.5, ky + keyH * 0.5);
    }
  }

  // Right Panel: BODMAS Step-by-Step Pelton Turbine Calculation Breakdown
  float rX = cX + cW + 14 * uiScale;
  float rY = topOff;
  float rW = width - rX - pad;
  float rH = cH;
  drawPanelCard(rX, rY, rW, rH, "BODMAS MODEL CALCULATION (RUN R" + (selectedReading + 1) + ")");

  // BODMAS Indicator Pills
  float pillY = rY + 40 * uiScale;
  float pillW = (rW - 28 * uiScale - 5 * 6 * uiScale) / 6.0;
  float pillH = 34 * uiScale;
  int activeBod = getActiveBodmasIndex(bodmasStep);

  for (int i = 0; i < 6; i++) {
    float px = rX + 14 * uiScale + i * (pillW + 6 * uiScale);
    boolean isAct = (i == activeBod);
    fill(isAct ? color(37, 99, 235) : color(24, 38, 62));
    stroke(isAct ? color(125, 211, 252) : color(55, 78, 112));
    rect(px, pillY, pillW, pillH, 6 * uiScale);

    fill(isAct ? 255 : color(148, 163, 184));
    textAlign(CENTER, CENTER);
    textSize(13 * uiScale);
    text(bodmasLetters[i], px + pillW * 0.5, pillY + 11 * uiScale);
    textSize(9.2 * uiScale);
    text(bodmasWords[i], px + pillW * 0.5, pillY + 25 * uiScale);
  }

  // 8-Step Calculation Rows
  String[][] calcSteps = {
    { "1. Diff Head h",     "h = (0.20 - 0.12) * 10 = " + nf(curH, 1, 2) + " m" },
    { "2. Discharge Q",     "Q = 3.12e-3 * sqrt(" + nf(curH, 1, 2) + ") = " + nf(curQ * 1000, 1, 3) + " x10^-3 m^3/s" },
    { "3. Input Power Pi",  "Pi = 9.81 * " + nf(curQ * 1000, 1, 3) + "e-3 * 8.0 = " + nf(curPi, 1, 3) + " kW" },
    { "4. Eff Radius Re",   "Re = (0.200 / (2*pi)) + (0.015 / 2) = " + nf(R_EFF, 1, 4) + " m" },
    { "5. Net Load Wa",     "Wa = ((1.0 + " + nf(curW1, 1, 1) + " - " + nf(curW2, 1, 2) + ") * 9.81)/1000 = " + nf(curWa, 1, 4) + " kN" },
    { "6. Output Power Po", "Po = (2*pi*" + nf(curN, 1, 0) + "*" + nf(curWa, 1, 4) + "*0.0393)/60 = " + nf(curPo, 1, 4) + " kW" },
    { "7. Efficiency eta",  "eta = (" + nf(curPo, 1, 4) + " / " + nf(curPi, 1, 3) + ") * 100 = " + nf(curEta, 1, 3) + " %" },
    { "8. Run R" + (selectedReading + 1) + " Summary", "Pi = " + nf(curPi, 1, 3) + " kW | Po = " + nf(curPo, 1, 4) + " kW | eta = " + nf(curEta, 1, 3) + " %" }
  };

  float listTop = pillY + pillH + 10 * uiScale;
  float listH = rY + rH - listTop - 50 * uiScale;
  float rowH = listH / calcSteps.length;

  for (int i = 0; i < calcSteps.length; i++) {
    boolean active = (i == bodmasStep);
    fill(active ? color(30, 58, 110) : color(20, 31, 50));
    stroke(active ? color(56, 189, 248) : color(42, 60, 90));
    strokeWeight(active ? 1.6 : 1.0);
    rect(rX + 14 * uiScale, listTop + i * rowH + 2 * uiScale, rW - 28 * uiScale, rowH - 4 * uiScale, 6 * uiScale);

    fill(active ? color(125, 211, 252) : color(160, 185, 215));
    textAlign(LEFT, CENTER);
    textSize(11.5 * uiScale);
    text(calcSteps[i][0], rX + 24 * uiScale, listTop + (i + 0.5) * rowH);

    fill(active ? color(134, 239, 172) : 245);
    textAlign(RIGHT, CENTER);
    textSize(11.8 * uiScale);
    text(calcSteps[i][1], rX + rW - 24 * uiScale, listTop + (i + 0.5) * rowH);
  }

  // Bottom Calc Controls
  float btnY = rY + rH - 40 * uiScale;
  drawButton(rX + 14 * uiScale, btnY, 115 * uiScale, 28 * uiScale, "< Prev Calc", false);
  drawButton(rX + 137 * uiScale, btnY, 115 * uiScale, 28 * uiScale, "Next Calc >", false);
  drawButton(rX + rW - 155 * uiScale, btnY, 141 * uiScale, 28 * uiScale, autoCalc ? "Auto-Calc: ON" : "Auto-Calc: OFF", autoCalc);
}

void pressCasioKey(String k) {
  if (k.equals("SHIFT")) {
    casioShiftOn = !casioShiftOn;
    return;
  }
  if (k.equals("ALPHA")) {
    casioAlphaOn = !casioAlphaOn;
    return;
  }
  if (k.equals("MODE")) {
    bodmasStep = (bodmasStep + 1) % 8;
    syncCasioToStep(bodmasStep);
    return;
  }
  if (k.equals("AC")) {
    casioTopLine = "";
    casioBotLine = "0.";
    casioShiftOn = false;
    casioAlphaOn = false;
    return;
  }
  if (k.equals("DEL")) {
    if (casioTopLine.length() > 0) {
      casioTopLine = casioTopLine.substring(0, casioTopLine.length() - 1);
    }
    return;
  }
  if (k.equals("=")) {
    if (casioTopLine.trim().length() == 0) {
      syncCasioToStep(bodmasStep);
      return;
    }
    try {
      String expr = casioTopLine.replace("Ans", casioLastAns.replaceAll("[^0-9.\\-E]", ""));
      double val = evalMathExpr(expr);
      if (Double.isNaN(val) || Double.isInfinite(val)) {
        casioBotLine = "Math ERROR";
      } else {
        casioBotLine = nf((float) val, 1, 4);
        casioLastAns = casioBotLine;
      }
    } catch (Exception e) {
      casioBotLine = "Syntax ERROR";
    }
    return;
  }

  // Append token to expression line
  if (k.equals("sqrt") || k.equals("sin") || k.equals("cos") || k.equals("tan")) {
    casioTopLine += k + "(";
  } else if (k.equals("x^2")) {
    casioTopLine += "^2";
  } else {
    casioTopLine += k;
  }
  casioShiftOn = false;
  casioAlphaOn = false;
}

// Clean Recursive-Descent Math Evaluator for Interactive Casio fx-991MS Keypad
double evalMathExpr(final String str) {
  return new Object() {
    int pos = -1, ch;
    void nextChar() {
      ch = (++pos < str.length()) ? str.charAt(pos) : -1;
    }
    boolean eat(int charToEat) {
      while (ch == ' ') nextChar();
      if (ch == charToEat) {
        nextChar();
        return true;
      }
      return false;
    }
    double parse() {
      nextChar();
      double x = parseExpression();
      if (pos < str.length()) throw new RuntimeException("Unexpected: " + (char) ch);
      return x;
    }
    double parseExpression() {
      double x = parseTerm();
      for (;;) {
        if      (eat('+')) x += parseTerm();
        else if (eat('-')) x -= parseTerm();
        else return x;
      }
    }
    double parseTerm() {
      double x = parseFactor();
      for (;;) {
        if      (eat('*')) x *= parseFactor();
        else if (eat('/')) x /= parseFactor();
        else return x;
      }
    }
    double parseFactor() {
      if (eat('+')) return parseFactor();
      if (eat('-')) return -parseFactor();
      double x;
      int startPos = this.pos;
      if (eat('(')) {
        x = parseExpression();
        eat(')');
      } else if ((ch >= '0' && ch <= '9') || ch == '.') {
        while ((ch >= '0' && ch <= '9') || ch == '.' || ch == 'E') nextChar();
        x = Double.parseDouble(str.substring(startPos, this.pos));
      } else if (ch >= 'a' && ch <= 'z') {
        while (ch >= 'a' && ch <= 'z') nextChar();
        String func = str.substring(startPos, this.pos);
        if (func.equals("pi")) {
          x = Math.PI;
        } else {
          x = parseFactor();
          if (func.equals("sqrt")) x = Math.sqrt(x);
          else if (func.equals("sin")) x = Math.sin(Math.toRadians(x));
          else if (func.equals("cos")) x = Math.cos(Math.toRadians(x));
          else if (func.equals("tan")) x = Math.tan(Math.toRadians(x));
          else throw new RuntimeException("Unknown func: " + func);
        }
      } else {
        throw new RuntimeException("Unexpected: " + (char) ch);
      }
      if (eat('^')) x = Math.pow(x, parseFactor());
      return x;
    }
  }.parse();
}

// ============================================================================
// SCREEN 6: OBSERVATION TABLE & CHARACTERISTIC PERFORMANCE GRAPHS
// ============================================================================
void drawScreen6_TableAndGraph() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;

  // Left Panel: Complete Observation & Result Tabulation (52% width)
  float tX = pad;
  float tY = topOff;
  float tW = width * 0.52;
  float tH = height - topOff - botOff;
  drawPanelCard(tX, tY, tW, tH, "OBSERVATION & TABULATION (TAP ANY ROW TO INSPECT)");

  String[] headers = { "Run", "P1", "P2", "h(m)", "W1", "W2", "Wa(kN)", "N(rpm)", "Po(kW)", "eta(%)" };
  float[] colW = { 0.08, 0.08, 0.08, 0.09, 0.08, 0.08, 0.12, 0.12, 0.13, 0.14 };

  float tblX = tX + 12 * uiScale;
  float tblY = tY + 40 * uiScale;
  float tblW = tW - 24 * uiScale;
  float rowH = 34 * uiScale;

  // Header Row
  fill(30, 58, 110);
  noStroke();
  rect(tblX, tblY, tblW, rowH, 6 * uiScale);
  float cx = tblX;
  for (int c = 0; c < headers.length; c++) {
    float cw = tblW * colW[c];
    fill(186, 230, 253);
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text(headers[c], cx + cw * 0.5, tblY + rowH * 0.5);
    cx += cw;
  }

  // Data Rows R1..R5
  for (int r = 0; r < 5; r++) {
    float ry = tblY + (r + 1) * (rowH + 4 * uiScale);
    boolean sel = (!customSliderActive && selectedReading == r);
    fill(sel ? color(22, 101, 52, 200) : color(20, 31, 50));
    stroke(sel ? color(74, 222, 128) : color(42, 60, 90));
    strokeWeight(sel ? 1.6 : 1.0);
    rect(tblX, ry, tblW, rowH, 6 * uiScale);

    String[] vals = {
      "R" + rNum[r],
      nf(p1Arr[r], 1, 2),
      nf(p2Arr[r], 1, 2),
      nf(hArr[r], 1, 2),
      nf(w1Arr[r], 1, 1),
      nf(w2Arr[r], 1, 2),
      nf(waArr[r], 1, 4),
      nf(nArr[r], 1, 0),
      nf(poArr[r], 1, 4),
      nf(etaArr[r], 1, 2)
    };

    cx = tblX;
    for (int c = 0; c < vals.length; c++) {
      float cw = tblW * colW[c];
      fill(sel ? color(220, 252, 231) : (c >= 8 ? color(125, 211, 252) : 240));
      textAlign(CENTER, CENTER);
      textSize(11 * uiScale);
      text(vals[c], cx + cw * 0.5, ry + rowH * 0.5);
      cx += cw;
    }
  }

  // Constant Parameters & Lab Result Summary Box below table
  float noteY = tblY + 6 * (rowH + 4 * uiScale) + 10 * uiScale;
  float noteH = tY + tH - noteY - 14 * uiScale;
  fill(15, 24, 40);
  stroke(56, 189, 248, 90);
  rect(tblX, noteY, tblW, noteH, 8 * uiScale);

  fill(56, 189, 248);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("CONSTANT APPARATUS PARAMETERS & EXPERIMENTAL RESULT:", tblX + 12 * uiScale, noteY + 10 * uiScale);

  fill(210, 228, 248);
  textSize(11.3 * uiScale);
  text("- Constant Supply Head (Hs) = 8.0 m  |  Discharge (Q) = 2.789 x 10^-3 m^3/s", tblX + 12 * uiScale, noteY + 32 * uiScale);
  text("- Hydraulic Input Power (Pi) = 0.218 kW  |  Effective Drum Radius (Re) = 0.0393 m", tblX + 12 * uiScale, noteY + 52 * uiScale);
  fill(134, 239, 172);
  text("- Peak Efficiency Achieved: eta_max = 50.458 % at N = 546 rpm (Po = 0.1103 kW)", tblX + 12 * uiScale, noteY + 72 * uiScale);

  // Right Panel: Characteristic Performance Curves (44% width)
  float gX = tX + tW + 14 * uiScale;
  float gY = topOff;
  float gW = width - gX - pad;
  float gH = tH;
  drawPanelCard(gX, gY, gW, gH, "CHARACTERISTIC CURVES (CONSTANT HEAD Hs = 8 m)");

  // 3 Curve Mode Toggle Buttons
  float bY = gY + 38 * uiScale;
  float bW = (gW - 36 * uiScale) / 3.0;
  drawButton(gX + 12 * uiScale, bY, bW, 28 * uiScale, "N vs Efficiency", graphMode == 0);
  drawButton(gX + 18 * uiScale + bW, bY, bW, 28 * uiScale, "N vs Output Po", graphMode == 1);
  drawButton(gX + 24 * uiScale + bW * 2, bY, bW, 28 * uiScale, "N vs Pi & Q", graphMode == 2);

  // Plot Area
  float plotX = gX + 54 * uiScale;
  float plotY = bY + 44 * uiScale;
  float plotW = gW - 76 * uiScale;
  float plotH = gY + gH - plotY - 54 * uiScale;

  fill(11, 18, 30);
  stroke(55, 78, 112);
  strokeWeight(1.2);
  rect(plotX, plotY, plotW, plotH);

  // Gridlines (X: Speed N from 500 to 850 rpm)
  float minN = 500.0, maxN = 850.0;
  float minY = 0.0;
  float maxY = (graphMode == 0) ? 60.0 : ((graphMode == 1) ? 0.14 : 0.30);
  String yUnit = (graphMode == 0) ? "Efficiency eta (%)" : ((graphMode == 1) ? "Output Power Po (kW)" : "Input Power Pi (kW)");

  stroke(35, 50, 75);
  strokeWeight(1);
  for (int i = 0; i <= 5; i++) {
    float gy = plotY + plotH - (i / 5.0) * plotH;
    line(plotX, gy, plotX + plotW, gy);
    fill(148, 163, 184);
    textAlign(RIGHT, CENTER);
    textSize(10 * uiScale);
    float val = lerp(minY, maxY, i / 5.0);
    text(graphMode == 0 ? nf(val, 1, 0) : nf(val, 1, 2), plotX - 6 * uiScale, gy);
  }
  for (int i = 0; i <= 5; i++) {
    float gx = plotX + (i / 5.0) * plotW;
    line(gx, plotY, gx, plotY + plotH);
    fill(148, 163, 184);
    textAlign(CENTER, TOP);
    textSize(10 * uiScale);
    text(nf(lerp(minN, maxN, i / 5.0), 1, 0), gx, plotY + plotH + 6 * uiScale);
  }

  // Axis Labels
  fill(186, 230, 253);
  textAlign(CENTER, CENTER);
  textSize(11.5 * uiScale);
  text("Runner Speed N (rpm)", plotX + plotW * 0.5, plotY + plotH + 30 * uiScale);

  pushMatrix();
  translate(gX + 16 * uiScale, plotY + plotH * 0.5);
  rotate(-HALF_PI);
  text(yUnit, 0, 0);
  popMatrix();

  // Plot Curve (Sorted by increasing Speed N: R5 -> R4 -> R3 -> R2 -> R1)
  color curveCol = (graphMode == 0) ? color(74, 222, 128) : ((graphMode == 1) ? color(56, 189, 248) : color(250, 204, 21));
  stroke(curveCol);
  strokeWeight(2.6);
  noFill();
  beginShape();
  for (int idx = 4; idx >= 0; idx--) {
    float valY = (graphMode == 0) ? etaArr[idx] : ((graphMode == 1) ? poArr[idx] : piArr[idx]);
    float px = plotX + map(nArr[idx], minN, maxN, 0, plotW);
    float targetPy = plotY + plotH - map(valY, minY, maxY, 0, plotH);
    float py = lerp(plotY + plotH, targetPy, graphAnim);
    vertex(px, py);
  }
  endShape();

  // Data Points & Labels
  for (int idx = 4; idx >= 0; idx--) {
    float valY = (graphMode == 0) ? etaArr[idx] : ((graphMode == 1) ? poArr[idx] : piArr[idx]);
    float px = plotX + map(nArr[idx], minN, maxN, 0, plotW);
    float targetPy = plotY + plotH - map(valY, minY, maxY, 0, plotH);
    float py = lerp(plotY + plotH, targetPy, graphAnim);

    boolean isSel = (!customSliderActive && selectedReading == idx);
    if (isSel) {
      noFill();
      stroke(244, 63, 94);
      strokeWeight(2.2);
      ellipse(px, py, 18 * uiScale, 18 * uiScale);
    }
    noStroke();
    fill(isSel ? color(244, 63, 94) : curveCol);
    ellipse(px, py, 9 * uiScale, 9 * uiScale);

    fill(240);
    textAlign(CENTER, BOTTOM);
    textSize(10 * uiScale);
    text("R" + (idx + 1) + " (" + (graphMode == 0 ? nf(valY, 1, 1) + "%" : nf(valY, 1, 3)) + ")", px, py - 8 * uiScale);
  }
}

// ============================================================================
// SHARED UI DRAWING PRIMITIVES
// ============================================================================
void drawPanelCard(float x, float y, float w, float h, String title) {
  fill(18, 28, 45, 238);
  stroke(48, 72, 110);
  strokeWeight(1.4);
  rect(x, y, w, h, 10 * uiScale);

  // Header strip
  fill(25, 40, 65);
  noStroke();
  rect(x + 1, y + 1, w - 2, 28 * uiScale, 9 * uiScale, 9 * uiScale, 0, 0);

  fill(125, 211, 252);
  textAlign(LEFT, CENTER);
  textSize(12 * uiScale);
  text(title, x + 12 * uiScale, y + 14 * uiScale);
}

void drawButton(float x, float y, float w, float h, String label, boolean active) {
  fill(active ? color(37, 99, 235) : color(28, 44, 70));
  stroke(active ? color(125, 211, 252) : color(65, 92, 132));
  strokeWeight(1.2);
  rect(x, y, w, h, 7 * uiScale);

  fill(active ? 255 : color(215, 230, 248));
  textAlign(CENTER, CENTER);
  textSize(11.5 * uiScale);
  text(label, x + w * 0.5, y + h * 0.5);
}

void drawLegendDot(float x, float y, color col, String label) {
  noStroke();
  fill(col);
  ellipse(x, y, 9 * uiScale, 9 * uiScale);
  fill(200, 218, 238);
  textAlign(LEFT, CENTER);
  textSize(11 * uiScale);
  text(label, x + 12 * uiScale, y);
}

void draw2DArrow(float x1, float y1, float x2, float y2, color col) {
  stroke(col);
  strokeWeight(2.0);
  line(x1, y1, x2, y2);
  float ang = atan2(y2 - y1, x2 - x1);
  float head = 7 * uiScale;
  line(x2, y2, x2 - head * cos(ang - 0.45), y2 - head * sin(ang - 0.45));
  line(x2, y2, x2 - head * cos(ang + 0.45), y2 - head * sin(ang + 0.45));
}

void drawSchematicBlock(float x, float y, float w, float h, String title, String body, color bgCol) {
  fill(bgCol);
  stroke(96, 165, 250, 140);
  strokeWeight(1.3);
  rect(x, y, w, h, 8 * uiScale);

  fill(186, 230, 253);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text(title, x + 12 * uiScale, y + 7 * uiScale);

  fill(255);
  textSize(11.5 * uiScale);
  text(body, x + 12 * uiScale, y + 26 * uiScale);
}

boolean overRect(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

// ============================================================================
// TOUCH & MOUSE INTERACTION HANDLERS
// ============================================================================
public void mousePressed() {
  prevMouseX = mouseX;
  prevMouseY = mouseY;

  // 1. Top 6-Screen Tabs
  float topH = 44 * uiScale;
  float tabH = 38 * uiScale;
  if (mouseY >= topH && mouseY <= topH + tabH) {
    int idx = int(mouseX / (width / 6.0));
    currentScreen = constrain(idx, 0, 5);
    if (currentScreen == 5) graphAnim = 0.0;
    return;
  }

  // 2. Bottom Navigation Bar (< PREV SCREEN / NEXT SCREEN >)
  float barH = 44 * uiScale;
  float by = height - barH;
  float btnW = 165 * uiScale;
  float btnH = 30 * uiScale;
  float btnY = by + (barH - btnH) * 0.5;
  if (overRect(16 * uiScale, btnY, btnW, btnH) && currentScreen > 0) {
    currentScreen--;
    if (currentScreen == 5) graphAnim = 0.0;
    return;
  }
  if (overRect(width - btnW - 16 * uiScale, btnY, btnW, btnH) && currentScreen < 5) {
    currentScreen++;
    if (currentScreen == 5) graphAnim = 0.0;
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

void handleScreen1Press() {
  float[] lay = getScreen1Layout();
  float topOff  = lay[0];
  float pad     = lay[2];
  float mainH   = lay[3];
  float leftW   = lay[4];
  float centerX = lay[6];
  float centerW = lay[7];

  float cardX = pad;
  float cardY = topOff;
  float cardW = leftW;
  float y = cardY + 42 * uiScale;
  float btnW = (cardW - 34 * uiScale) / 2.0;
  float btnH = 30 * uiScale;

  // Auto-Orbit & Zoom Buttons
  if (overRect(cardX + 12 * uiScale, y, btnW, btnH)) {
    autoOrbit = !autoOrbit;
    return;
  }
  if (overRect(cardX + 20 * uiScale + btnW, y, btnW * 0.48, btnH)) {
    zoom3D = constrain(zoom3D + 0.14, 0.55, 2.2);
    return;
  }
  if (overRect(cardX + 20 * uiScale + btnW * 1.52, y, btnW * 0.48, btnH)) {
    zoom3D = constrain(zoom3D - 0.14, 0.55, 2.2);
    return;
  }

  // Reading R1..R5 Buttons
  y += 60 * uiScale;
  float rBtnW = (cardW - 40 * uiScale) / 5.0;
  for (int i = 0; i < 5; i++) {
    if (overRect(cardX + 12 * uiScale + i * (rBtnW + 4 * uiScale), y, rBtnW, 30 * uiScale)) {
      selectReading(i);
      return;
    }
  }

  // Brake Load W1 Slider
  y += 70 * uiScale;
  float slX = cardX + 16 * uiScale;
  float slW = cardW - 32 * uiScale;
  if (overRect(slX - 10 * uiScale, y - 14 * uiScale, slW + 20 * uiScale, 36 * uiScale)) {
    draggingLoadSlider = true;
    float frac = constrain((mouseX - slX) / slW, 0, 1);
    updateFromCustomLoad(1.0 + frac * 4.0);
    return;
  }

  // Center 3D Viewport Frame Orbit Drag
  if (overRect(centerX, topOff, centerW, mainH)) {
    dragging3D = true;
  }
}

void handleScreen2Press() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;
  float boxX = pad;
  float boxY = topOff;
  float boxW = width * 0.67;
  float boxH = height - topOff - botOff;
  float simX = boxX + 14 * uiScale;
  float simY = boxY + 38 * uiScale;
  float simW = boxW - 28 * uiScale;
  float simH = boxH - 86 * uiScale;
  float ctrlY = simY + simH + 8 * uiScale;

  if (overRect(simX, ctrlY, 175 * uiScale, 30 * uiScale)) {
    unsteadyMode = !unsteadyMode;
    return;
  }
  if (overRect(simX + 185 * uiScale, ctrlY, 130 * uiScale, 30 * uiScale)) {
    for (FluidParticle2D p : cutParticles) p.resetTrail();
    return;
  }
  if (overRect(simX, simY, simW, simH)) {
    dyeNozzleRelX = constrain((mouseX - simX) / simW, 0.06, 0.52);
    dyeNozzleRelY = constrain((mouseY - simY) / simH, 0.25, 0.85);
    for (FluidParticle2D dp : dyeParticles) {
      dp.x = simX + dyeNozzleRelX * simW;
      dp.y = simY + dyeNozzleRelY * simH;
    }
  }
}

void handleScreen3Press() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;
  float lX = pad;
  float lY = topOff;
  float lW = width * 0.55;
  float lH = height - topOff - botOff;

  float stepAreaH = lH - 92 * uiScale;
  float stepH = stepAreaH / derivTitles.length;
  float sy = lY + 40 * uiScale;
  for (int i = 0; i < derivTitles.length; i++) {
    if (overRect(lX + 34 * uiScale, sy + 2 * uiScale, lW - 48 * uiScale, stepH - 5 * uiScale)) {
      derivStep = i;
      autoDerive = false;
      return;
    }
    sy += stepH;
  }

  float bY = lY + lH - 42 * uiScale;
  if (overRect(lX + 16 * uiScale, bY, 120 * uiScale, 30 * uiScale)) {
    derivStep = (derivStep - 1 + derivTitles.length) % derivTitles.length;
    autoDerive = false;
  } else if (overRect(lX + 146 * uiScale, bY, 120 * uiScale, 30 * uiScale)) {
    derivStep = (derivStep + 1) % derivTitles.length;
    autoDerive = false;
  } else if (overRect(lX + lW - 165 * uiScale, bY, 150 * uiScale, 30 * uiScale)) {
    autoDerive = !autoDerive;
    lastDerivTick = millis();
  }
}

void handleScreen4Press() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;
  float lX = pad;
  float lY = topOff;
  float lW = width * 0.56;
  float lH = height - topOff - botOff;

  float listH = lH - 92 * uiScale;
  float itemH = listH / procTitles.length;
  float py = lY + 40 * uiScale;
  for (int i = 0; i < procTitles.length; i++) {
    if (overRect(lX + 14 * uiScale, py + 2 * uiScale, lW - 28 * uiScale, itemH - 5 * uiScale)) {
      procStep = i;
      autoDemo = false;
      return;
    }
    py += itemH;
  }

  float bY = lY + lH - 42 * uiScale;
  if (overRect(lX + 16 * uiScale, bY, 120 * uiScale, 30 * uiScale)) {
    procStep = (procStep - 1 + procTitles.length) % procTitles.length;
    autoDemo = false;
  } else if (overRect(lX + 146 * uiScale, bY, 120 * uiScale, 30 * uiScale)) {
    procStep = (procStep + 1) % procTitles.length;
    autoDemo = false;
  } else if (overRect(lX + lW - 165 * uiScale, bY, 150 * uiScale, 30 * uiScale)) {
    autoDemo = !autoDemo;
    lastProcTick = millis();
  }
}

void handleScreen5Press() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;
  float cX = pad;
  float cY = topOff;
  float cW = width * 0.42;
  float cH = height - topOff - botOff;

  // Check Casio fx-991MS Keypad
  float bodyX = cX + 18 * uiScale;
  float bodyY = cY + 38 * uiScale;
  float bodyW = cW - 36 * uiScale;
  float bodyH = cH - 50 * uiScale;
  float lcdY = bodyY + 34 * uiScale;
  float lcdH = 58 * uiScale;

  String[][] keys = {
    { "SHIFT", "ALPHA", "MODE", "DEL", "AC" },
    { "sqrt",  "x^2",   "^",    "(",   ")"  },
    { "7",     "8",     "9",    "sin", "cos"},
    { "4",     "5",     "6",    "*",   "/"  },
    { "1",     "2",     "3",    "+",   "-"  },
    { "0",     ".",     "pi",   "Ans", "="  }
  };

  float kpX = bodyX + 12 * uiScale;
  float kpY = lcdY + lcdH + 12 * uiScale;
  float kpW = bodyW - 24 * uiScale;
  float kpH = bodyY + bodyH - kpY - 12 * uiScale;
  float gap = 6 * uiScale;
  float keyW = (kpW - gap * 4) / 5.0;
  float keyH = (kpH - gap * 5) / 6.0;

  for (int r = 0; r < 6; r++) {
    for (int c = 0; c < 5; c++) {
      float kx = kpX + c * (keyW + gap);
      float ky = kpY + r * (keyH + gap);
      if (overRect(kx, ky, keyW, keyH)) {
        pressCasioKey(keys[r][c]);
        return;
      }
    }
  }

  // Check Right Panel BODMAS Steps & Controls
  float rX = cX + cW + 14 * uiScale;
  float rY = topOff;
  float rW = width - rX - pad;
  float rH = cH;
  float pillY = rY + 40 * uiScale;
  float pillH = 34 * uiScale;
  float listTop = pillY + pillH + 10 * uiScale;
  float listH = rY + rH - listTop - 50 * uiScale;
  float rowH = listH / 8.0;

  for (int i = 0; i < 8; i++) {
    if (overRect(rX + 14 * uiScale, listTop + i * rowH + 2 * uiScale, rW - 28 * uiScale, rowH - 4 * uiScale)) {
      bodmasStep = i;
      autoCalc = false;
      syncCasioToStep(bodmasStep);
      return;
    }
  }

  float btnY = rY + rH - 40 * uiScale;
  if (overRect(rX + 14 * uiScale, btnY, 115 * uiScale, 28 * uiScale)) {
    bodmasStep = (bodmasStep - 1 + 8) % 8;
    autoCalc = false;
    syncCasioToStep(bodmasStep);
  } else if (overRect(rX + 137 * uiScale, btnY, 115 * uiScale, 28 * uiScale)) {
    bodmasStep = (bodmasStep + 1) % 8;
    autoCalc = false;
    syncCasioToStep(bodmasStep);
  } else if (overRect(rX + rW - 155 * uiScale, btnY, 141 * uiScale, 28 * uiScale)) {
    autoCalc = !autoCalc;
    lastCalcTick = millis();
  }
}

void handleScreen6Press() {
  float topOff = 90 * uiScale;
  float botOff = 52 * uiScale;
  float pad = 16 * uiScale;
  float tX = pad;
  float tY = topOff;
  float tW = width * 0.52;
  float tH = height - topOff - botOff;

  // Table Row Selection
  float tblX = tX + 12 * uiScale;
  float tblY = tY + 40 * uiScale;
  float tblW = tW - 24 * uiScale;
  float rowH = 34 * uiScale;
  for (int r = 0; r < 5; r++) {
    float ry = tblY + (r + 1) * (rowH + 4 * uiScale);
    if (overRect(tblX, ry, tblW, rowH)) {
      selectReading(r);
      return;
    }
  }

  // Graph Curve Toggle Buttons
  float gX = tX + tW + 14 * uiScale;
  float gY = topOff;
  float gW = width - gX - pad;
  float bY = gY + 38 * uiScale;
  float bW = (gW - 36 * uiScale) / 3.0;
  for (int m = 0; m < 3; m++) {
    if (overRect(gX + (12 + m * 6) * uiScale + m * bW, bY, bW, 28 * uiScale)) {
      graphMode = m;
      graphAnim = 0.0;
      return;
    }
  }
}

public void mouseDragged() {
  if (currentScreen == 0) {
    if (draggingLoadSlider) {
      float[] lay = getScreen1Layout();
      float slX = lay[2] + 16 * uiScale;
      float slW = lay[4] - 32 * uiScale;
      float frac = constrain((mouseX - slX) / slW, 0, 1);
      updateFromCustomLoad(1.0 + frac * 4.0);
    } else if (dragging3D) {
      rotY += (mouseX - prevMouseX) * 0.008;
      rotX = constrain(rotX + (mouseY - prevMouseY) * 0.008, -1.15, 0.85);
    }
  } else if (currentScreen == 1) {
    float topOff = 90 * uiScale;
    float botOff = 52 * uiScale;
    float pad = 16 * uiScale;
    float simX = pad + 14 * uiScale;
    float simY = topOff + 38 * uiScale;
    float simW = width * 0.67 - 28 * uiScale;
    float simH = (height - topOff - botOff) - 86 * uiScale;
    if (overRect(simX, simY, simW, simH)) {
      dyeNozzleRelX = constrain((mouseX - simX) / simW, 0.06, 0.52);
      dyeNozzleRelY = constrain((mouseY - simY) / simH, 0.25, 0.85);
    }
  }
  prevMouseX = mouseX;
  prevMouseY = mouseY;
}

public void mouseReleased() {
  dragging3D = false;
  draggingLoadSlider = false;
}

public void keyPressed() {
  if (key >= '1' && key <= '6') {
    currentScreen = key - '1';
    if (currentScreen == 5) graphAnim = 0.0;
  } else if (key == '+' || key == '=') {
    zoom3D = constrain(zoom3D + 0.12, 0.55, 2.2);
  } else if (key == '-' || key == '_') {
    zoom3D = constrain(zoom3D - 0.12, 0.55, 2.2);
  } else if (key == 'r' || key == 'R') {
    rotX = -0.20;
    rotY = 0.34;
    zoom3D = 1.0;
  }
}
