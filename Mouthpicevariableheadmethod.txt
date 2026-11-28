// ============================================================================
// MOUTHPIECE (VARIABLE HEAD METHOD) - 6-SCREEN INTERACTIVE APDE (P3D) LAB APP
// Experiment No. 2: Coefficient of Discharge (Cd) of External Mouthpiece
// Compatible with Android Processing (APDE) in P3D Landscape Mode
// ============================================================================

int currentScreen = 0; // 0..5 for the 6 screens
final String[] screenNames = {
  "1. 3D RIG",
  "2. CUTAWAY",
  "3. DERIVATION",
  "4. PROCEDURE",
  "5. CASIO CALC",
  "6. TABLE & GRAPH"
};

// Apparatus Constants (from Lab Record)
final float DIA_MOUTHPIECE = 0.02f;          // d = 20 mm = 0.02 m
final float AREA_MOUTHPIECE = 0.00031416f;   // a = (pi/4)*d^2 = 3.1416 x 10^-4 m^2
final float TANK_L = 0.30f;                  // L = 300 mm = 0.30 m
final float TANK_B = 0.30f;                  // B = 300 mm = 0.30 m
final float AREA_TANK = 0.09f;               // A = L * B = 0.09 m^2
final float GRAVITY = 9.81f;                 // g = 9.81 m/s^2
final float SQRT_2G = 4.42945f;              // sqrt(2 * 9.81) = 4.429 m^(1/2)/s
final float FINAL_RECORD_CD = 0.695f;        // Final reported Cd from lab record

// Observation Table Data (Readings R1 to R5)
final int NUM_READINGS = 5;
int selectedReading = 2; // Default to R3 (Model Calculation row)

float[] H1_vals      = { 0.75f,   0.71f,   0.68f,   0.66f,   0.58f   };
float[] H2_vals      = { 0.65f,   0.61f,   0.58f,   0.56f,   0.48f   };
float[] sqrtH1_vals  = { 0.866f,  0.842f,  0.824f,  0.812f,  0.761f  };
float[] sqrtH2_vals  = { 0.806f,  0.781f,  0.761f,  0.748f,  0.692f  };
float[] timeT_vals   = { 11.0f,   11.6f,   11.8f,   11.6f,   18.9f   };
float[] dSqrtH_vals  = { 0.0600f, 0.0616f, 0.0640f, 0.0640f, 0.0710f };
float[] cd_vals      = { 0.644f,  0.683f,  0.689f,  0.671f,  0.731f  };

// UI Scaling & Layout
float uiScale = 1.0f;
float topBarH = 52.0f;
float botBarH = 46.0f;

// Screen 1: 3D Rig Orbit, Zoom & Head Control
float rotX = -0.24f;
float rotY = -0.52f;
float zoom3D = 1.0f;
boolean autoOrbit = true;
boolean show3DLabels = true;
float currentHeadH = 0.68f; // Instantaneous water head H between H1 and H2
boolean autoFallSim = true;
float fallProgress = 0.0f;  // 0.0 (at H1) -> 1.0 (at H2)
boolean draggingSliderH = false;
float lastMouseX = 0;
float lastMouseY = 0;
boolean dragging3D = false;

class JetParticle3D {
  float t;      // 0..1 along jet + slope channel
  float speed;
  float offY;
  float offZ;
  JetParticle3D() {
    reset(random(1.0f));
  }
  void reset(float startT) {
    t = startT;
    speed = random(0.85f, 1.15f);
    offY = random(-3.2f, 3.2f);
    offZ = random(-3.2f, 3.2f);
  }
}
ArrayList<JetParticle3D> jetParticles3D;

// Screen 2: 2D Cutaway Physics Simulation
boolean unsteadyMode = false;
float nozzleNormX = 0.34f; // Normalized X inside cutaway box
float nozzleNormY = 0.62f; // Normalized Y inside cutaway box

class FluidParticle2D {
  float x, y;
  float vx, vy;
  float speedMag;
  ArrayList<PVector> trail;
  FluidParticle2D() {
    trail = new ArrayList<PVector>();
    respawn(true);
  }
  void respawn(boolean randomX) {
    if (randomX) {
      x = random(0.06f, 0.94f);
    } else {
      x = random(0.05f, 0.14f);
    }
    if (x < 0.44f) {
      y = random(0.24f, 0.86f);
    } else if (x < 0.62f) {
      y = random(0.67f, 0.77f);
    } else {
      float dx = x - 0.62f;
      y = 0.72f + dx * dx * 0.55f + random(-0.025f, 0.025f);
    }
    trail.clear();
  }
}
ArrayList<FluidParticle2D> particles2D;
ArrayList<PVector> streaklinePts;

// Screen 3: 7-Step Derivation
int derivStep = 0;
boolean autoDerive = true;
int lastDerivTick = 0;
final String[] derivTitles = {
  "1. Theoretical Jet Velocity (Torricelli)",
  "2. Theoretical Instantaneous Discharge",
  "3. Actual Instantaneous Discharge",
  "4. Continuity in Balancing Tank (-dh)",
  "5. Separate Variables & Integrate",
  "6. Evaluate Definite Integral (H1 to H2)",
  "7. Final Working Formula for Cd"
};
final String[] derivFormulas = {
  "At instantaneous head h above mouthpiece center:  V_th = sqrt(2 * g * h)",
  "For mouthpiece cross-section area a = (pi/4)*d^2:  Q_th = a * sqrt(2 * g * h)",
  "Introducing Coefficient of Discharge Cd:  Q_act = Cd * a * sqrt(2 * g * h)",
  "Volume drop in tank (area A) in time dt:  -A * dh = Q_act * dt = Cd * a * sqrt(2*g*h) * dt",
  "dt = [ -A / (Cd * a * sqrt(2 * g)) ] * h^(-1/2) dh",
  "T = integral(H1 to H2) dt = [ 2 * A / (Cd * a * sqrt(2 * g)) ] * (sqrt(H1) - sqrt(H2))",
  "Cd = [ 2 * A * (sqrt(H1) - sqrt(H2)) ] / [ T * a * sqrt(2 * g) ]"
};

// Screen 4: 6-Step Experimental Procedure
int procStep = 0;
boolean autoProc = true;
int lastProcTick = 0;
final String[] procTitles = {
  "1. Start Pump with Delivery Valve Closed",
  "2. Open Delivery Valve & Fill Tank",
  "3. Isolate Supply & Switch Off Pump",
  "4. Time Head Fall (H1 to H2) with Stopwatch",
  "5. Repeat for Different H1 and H2 Ranges",
  "6. Tabulate Readings & Plot Graph"
};
final String[] procDescs = {
  "Keep the delivery valve closed and switch on the electric motor pump set.",
  "Open the delivery valve to admit water from the reservoir into the balancing tank.",
  "Close the delivery valve once the balancing tank is completely filled and switch off pump.",
  "Measure time T (sec) required for water level in piezometer to fall from H1 to H2.",
  "Repeat steps 1 to 4 for 5 different pairs of initial head H1 and final head H2.",
  "Compute Cd for each run and plot sqrt(H1) - sqrt(H2) (X-axis) vs Time T (Y-axis)."
};

// Screen 5: 8-Step BODMAS & Casio fx-991MS Calculator
int bodmasStep = 0;
boolean autoBodmas = true;
int lastBodmasTick = 0;
String calcCustomExpr = "";
String calcCustomAns = "0.";
boolean calcUserOverride = false;
boolean casioShiftMode = false;
boolean casioAlphaMode = false;

// Screen 6: Graph Animation
float graphAnim = 0.0f;

// Color Palette (High-Contrast Engineering Lab Theme)
color colBgDark    = color(14, 21, 34);
color colPanel     = color(22, 33, 52);
color colPanelLite = color(30, 44, 68);
color colBorder    = color(58, 82, 118);
color colAccent    = color(0, 196, 224);
color colAccent2   = color(255, 178, 40);
color colGreen     = color(46, 213, 115);
color colRed       = color(255, 75, 92);
color colTextMain  = color(240, 246, 255);
color colTextDim   = color(165, 184, 210);

void settings() {
  fullScreen(P3D);
}

void setup() {
  orientation(LANDSCAPE);
  smooth(4);
  textFont(createFont("SansSerif", 16, true));

  jetParticles3D = new ArrayList<JetParticle3D>();
  for (int i = 0; i < 65; i++) {
    jetParticles3D.add(new JetParticle3D());
  }

  particles2D = new ArrayList<FluidParticle2D>();
  for (int i = 0; i < 140; i++) {
    particles2D.add(new FluidParticle2D());
  }

  streaklinePts = new ArrayList<PVector>();
  selectReading(2); // Default to R3 (Model Calculation)
}

void selectReading(int idx) {
  selectedReading = constrain(idx, 0, NUM_READINGS - 1);
  currentHeadH = H1_vals[selectedReading];
  fallProgress = 0.0f;
  calcUserOverride = false;
  graphAnim = 0.0f;
}

float getMeanCd() {
  float sum = 0;
  for (int i = 0; i < NUM_READINGS; i++) {
    sum += cd_vals[i];
  }
  return sum / NUM_READINGS;
}

// ============================================================================
// HUD DEPTH & ORTHOGRAPHIC CAMERA MANAGEMENT (EXACT TOP-LEFT 0,0 ALIGNMENT)
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
// MAIN DRAW LOOP
// ============================================================================
void draw() {
  uiScale = constrain(min(width / 1280.0f, height / 720.0f), 0.55f, 1.5f);
  topBarH = 52.0f * uiScale;
  botBarH = 46.0f * uiScale;

  updateSimulations();
  background(colBgDark);

  if (currentScreen == 0) {
    // Draw framed 3D viewport background first in 2D HUD
    beginHUD();
    drawScreen1_ViewportFrame();
    endHUD();

    // Render 3D Rig centered inside the central viewport frame
    drawScreen1_3DRig();

    // Draw Top/Bottom Nav Bars and Left/Right HUD Cards on top
    beginHUD();
    drawTopNavBar();
    drawScreen1_HUD();
    drawBottomNavBar();
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

void updateSimulations() {
  float h1 = H1_vals[selectedReading];
  float h2 = H2_vals[selectedReading];
  float tRun = timeT_vals[selectedReading];

  if (autoFallSim && !draggingSliderH) {
    float dt = (1.0f / 60.0f) * 3.5f;
    fallProgress += dt / max(tRun, 1.0f);
    if (fallProgress > 1.0f) {
      fallProgress = 0.0f;
    }
    currentHeadH = lerp(h1, h2, fallProgress);
  } else {
    fallProgress = constrain((h1 - currentHeadH) / max(h1 - h2, 0.001f), 0.0f, 1.0f);
  }

  if (currentScreen == 0 && autoOrbit && !dragging3D) {
    rotY += 0.0045f;
  }

  if (currentScreen == 2 && autoDerive && millis() - lastDerivTick > 3200) {
    derivStep = (derivStep + 1) % derivTitles.length;
    lastDerivTick = millis();
  }

  if (currentScreen == 3 && autoProc && millis() - lastProcTick > 3400) {
    procStep = (procStep + 1) % procTitles.length;
    lastProcTick = millis();
  }

  if (currentScreen == 4 && autoBodmas && millis() - lastBodmasTick > 2600) {
    bodmasStep = (bodmasStep + 1) % 8;
    lastBodmasTick = millis();
  }

  if (currentScreen == 5 && graphAnim < 1.0f) {
    graphAnim = min(1.0f, graphAnim + 0.025f);
  }
}

// ============================================================================
// TOP & BOTTOM NAVIGATION BARS
// ============================================================================
void drawTopNavBar() {
  fill(10, 16, 28);
  noStroke();
  rect(0, 0, width, topBarH);

  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  line(0, topBarH, width, topBarH);

  // Title Badge
  float badgeW = 215.0f * uiScale;
  fill(0, 145, 175);
  noStroke();
  rect(8 * uiScale, 6 * uiScale, badgeW, topBarH - 12 * uiScale, 6 * uiScale);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(13.2f * uiScale);
  text("MOUTHPIECE LAB (EX. 2)", 8 * uiScale + badgeW * 0.5f, topBarH * 0.40f);
  textSize(9.8f * uiScale);
  fill(225, 248, 255);
  text("Variable Head Method", 8 * uiScale + badgeW * 0.5f, topBarH * 0.74f);

  // 6 Screen Tabs
  float tabAreaX = badgeW + 18 * uiScale;
  float tabAreaW = width - tabAreaX - 10 * uiScale;
  float tabW = (tabAreaW - 5 * 6 * uiScale) / 6.0f;
  float tabH = topBarH - 12 * uiScale;

  for (int i = 0; i < 6; i++) {
    float tx = tabAreaX + i * (tabW + 6 * uiScale);
    float ty = 6 * uiScale;
    if (i == currentScreen) {
      fill(colAccent);
      stroke(255);
      strokeWeight(1.5f * uiScale);
    } else {
      fill(colPanelLite);
      stroke(colBorder);
      strokeWeight(1.0f * uiScale);
    }
    rect(tx, ty, tabW, tabH, 6 * uiScale);

    fill(i == currentScreen ? color(10, 18, 30) : colTextMain);
    textAlign(CENTER, CENTER);
    textSize(11.5f * uiScale);
    text(screenNames[i], tx + tabW * 0.5f, ty + tabH * 0.5f);
  }
}

void drawBottomNavBar() {
  float y0 = height - botBarH;
  fill(10, 16, 28);
  noStroke();
  rect(0, y0, width, botBarH);

  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  line(0, y0, width, y0);

  float btnW = 165.0f * uiScale;
  float btnH = botBarH - 10 * uiScale;
  float btnY = y0 + 5 * uiScale;

  // < PREV SCREEN
  fill(currentScreen > 0 ? colPanelLite : color(20, 26, 38));
  stroke(currentScreen > 0 ? colAccent : colBorder);
  strokeWeight(1.5f * uiScale);
  rect(12 * uiScale, btnY, btnW, btnH, 6 * uiScale);
  fill(currentScreen > 0 ? colTextMain : colTextDim);
  textAlign(CENTER, CENTER);
  textSize(12.2f * uiScale);
  text("< PREV SCREEN", 12 * uiScale + btnW * 0.5f, btnY + btnH * 0.5f);

  // NEXT SCREEN >
  float nextX = width - btnW - 12 * uiScale;
  fill(currentScreen < 5 ? colPanelLite : color(20, 26, 38));
  stroke(currentScreen < 5 ? colAccent : colBorder);
  strokeWeight(1.5f * uiScale);
  rect(nextX, btnY, btnW, btnH, 6 * uiScale);
  fill(currentScreen < 5 ? colTextMain : colTextDim);
  text("NEXT SCREEN >", nextX + btnW * 0.5f, btnY + btnH * 0.5f);

  // Center Active Reading Status Pill (Tap to cycle readings R1..R5)
  float pillW = width - 2 * btnW - 48 * uiScale;
  float pillX = btnW + 24 * uiScale;
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.0f * uiScale);
  rect(pillX, btnY, pillW, btnH, 6 * uiScale);

  int r = selectedReading;
  String modelTag = (r == 2) ? " [MODEL]" : "";
  String status = "ACTIVE R" + (r + 1) + modelTag +
    "  |  H1 = " + nf(H1_vals[r], 1, 2) + " m -> H2 = " + nf(H2_vals[r], 1, 2) + " m" +
    "  |  T = " + nf(timeT_vals[r], 1, 1) + " s" +
    "  |  sqrt(H1)-sqrt(H2) = " + nf(dSqrtH_vals[r], 1, 4) +
    "  |  Cd = " + nf(cd_vals[r], 1, 3);
  fill(colAccent2);
  textAlign(CENTER, CENTER);
  textSize(11.8f * uiScale);
  text(status, pillX + pillW * 0.5f, btnY + btnH * 0.5f);
}

// ============================================================================
// SCREEN 1: 3D RIG (FRAMED VIEWPORT + 3D APPARATUS + TELEMETRY HUD)
// ============================================================================
void drawScreen1_ViewportFrame() {
  float ctrlW = 300 * uiScale;
  float hudW = 345 * uiScale;
  float vpX = ctrlW + 24 * uiScale;
  float vpY = topBarH + 12 * uiScale;
  float vpW = width - ctrlW - hudW - 48 * uiScale;
  float vpH = height - topBarH - botBarH - 24 * uiScale;

  // Framed 3D Stage Card
  fill(11, 17, 29);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(vpX, vpY, vpW, vpH, 10 * uiScale);

  // Subtle floor reference gridlines inside stage
  stroke(22, 34, 54);
  strokeWeight(1.0f * uiScale);
  for (int i = 1; i < 6; i++) {
    float gx = vpX + (vpW * i) / 6.0f;
    line(gx, vpY + 34 * uiScale, gx, vpY + vpH - 28 * uiScale);
  }
  for (int j = 1; j < 5; j++) {
    float gy = vpY + (vpH * j) / 5.0f;
    line(vpX + 12 * uiScale, gy, vpX + vpW - 12 * uiScale, gy);
  }
}

void drawScreen1_3DRig() {
  float ctrlW = 300 * uiScale;
  float hudW = 345 * uiScale;
  float vpX = ctrlW + 24 * uiScale;
  float vpY = topBarH + 12 * uiScale;
  float vpW = width - ctrlW - hudW - 48 * uiScale;
  float vpH = height - topBarH - botBarH - 24 * uiScale;

  float centerX = vpX + vpW * 0.50f;
  float centerY = vpY + vpH * 0.52f;

  perspective(PI / 3.2f, float(width) / float(height), 1.0f, 5000.0f);
  ambientLight(110, 120, 136);
  directionalLight(235, 240, 255, -0.45f, 0.75f, -0.6f);
  pointLight(120, 210, 255, 180, -180, 220);

  // Auto-fit scale so the 3D rig stays neatly inside the central frame
  float fitScale = min(vpW / 590.0f, vpH / 410.0f) * zoom3D;

  pushMatrix();
  translate(centerX, centerY, 0);
  scale(fitScale);
  rotateX(rotX);
  rotateY(rotY);

  drawApparatus3D();
  popMatrix();
}

void drawApparatus3D() {
  // 1. Steel Lab Frame & Base Platform
  pushMatrix();
  translate(0, 145, 0);
  fill(48, 58, 74);
  stroke(25, 32, 44);
  strokeWeight(1);
  box(510, 16, 220);
  popMatrix();

  // Vertical support legs for Balancing Tank (Left-Center)
  fill(70, 82, 102);
  noStroke();
  float[] legX = { -160, -55, -160, -55 };
  float[] legZ = { -52, -52, 52, 52 };
  for (int i = 0; i < 4; i++) {
    pushMatrix();
    translate(legX[i], 80, legZ[i]);
    box(10, 120, 10);
    popMatrix();
  }

  // 2. Main Reservoir / Sump Tank (Bottom Right)
  pushMatrix();
  translate(140, 104, 0);
  fill(20, 135, 200, 190);
  noStroke();
  box(180, 52, 142);
  noFill();
  stroke(140, 175, 215);
  strokeWeight(2);
  box(186, 66, 148);
  popMatrix();

  // 3. Electric Motor + Centrifugal Pump Set (Front Right)
  pushMatrix();
  translate(205, 48, 52);
  fill(55, 65, 80);
  noStroke();
  box(74, 10, 42);
  // Electric motor body
  pushMatrix();
  translate(15, -15, 0);
  rotateZ(HALF_PI);
  fill(35, 110, 195);
  drawCylinder(15, 15, 40, 20);
  fill(25, 85, 160);
  for (int f = -14; f <= 14; f += 7) {
    pushMatrix();
    translate(0, f, 0);
    drawCylinder(16.5f, 16.5f, 3, 20);
    popMatrix();
  }
  popMatrix();
  // Pump volute casing
  pushMatrix();
  translate(-15, -13, 0);
  fill(215, 85, 45);
  drawCylinder(14, 14, 18, 20);
  popMatrix();
  popMatrix();

  // 4. Suction & Vertical Delivery Pipe with Gate Valve
  fill(155, 172, 192);
  noStroke();
  pushMatrix();
  translate(190, 64, 52);
  drawCylinder(5, 5, 48, 14);
  popMatrix();
  pushMatrix();
  translate(190, -58, 52);
  drawCylinder(5.5f, 5.5f, 186, 14);
  popMatrix();
  pushMatrix();
  translate(41, -150, 52);
  rotateZ(HALF_PI);
  drawCylinder(5.5f, 5.5f, 298, 14);
  popMatrix();
  pushMatrix();
  translate(-108, -150, 26);
  rotateX(HALF_PI);
  drawCylinder(5.5f, 5.5f, 52, 14);
  popMatrix();
  pushMatrix();
  translate(-108, -132, 0);
  drawCylinder(5.5f, 5.5f, 36, 14);
  popMatrix();

  // Delivery Gate Valve on top pipe (Red Handwheel)
  pushMatrix();
  translate(60, -150, 52);
  fill(210, 165, 40);
  box(19, 17, 17);
  translate(0, -15, 0);
  fill(225, 45, 55);
  drawCylinder(13, 13, 4, 18);
  popMatrix();

  // 5. Balancing Tank (300 mm x 300 mm plan)
  float tankW = 122.0f;
  float tankD = 122.0f;
  float tankH = 148.0f;
  float tankCenterX = -108.0f;
  float tankBottomY = 18.0f;

  float hNorm = constrain(currentHeadH / 0.85f, 0.1f, 0.95f);
  float waterH = tankH * hNorm;
  float h1Y = tankBottomY - tankH * constrain(H1_vals[selectedReading] / 0.85f, 0.1f, 0.95f);
  float h2Y = tankBottomY - tankH * constrain(H2_vals[selectedReading] / 0.85f, 0.1f, 0.95f);

  // Water body inside Balancing Tank
  pushMatrix();
  translate(tankCenterX, tankBottomY - waterH * 0.5f, 0);
  fill(25, 175, 240, 185);
  noStroke();
  box(tankW - 4, waterH, tankD - 4);
  popMatrix();

  // H1 & H2 Reference Rings
  stroke(255, 200, 45);
  strokeWeight(2);
  noFill();
  pushMatrix();
  translate(tankCenterX, h1Y, 0);
  box(tankW + 2, 1, tankD + 2);
  popMatrix();

  stroke(46, 225, 130);
  pushMatrix();
  translate(tankCenterX, h2Y, 0);
  box(tankW + 2, 1, tankD + 2);
  popMatrix();

  // Transparent Acrylic Tank Walls
  pushMatrix();
  translate(tankCenterX, tankBottomY - tankH * 0.5f, 0);
  noFill();
  stroke(185, 220, 255);
  strokeWeight(2.2f);
  box(tankW, tankH, tankD);
  popMatrix();

  // 6. Side Piezometer Tube + Graduated Meter Scale
  float piezoX = tankCenterX - tankW * 0.5f - 20.0f;
  pushMatrix();
  translate(piezoX + 10, tankBottomY - 12, 20);
  rotateZ(HALF_PI);
  fill(170, 185, 205);
  noStroke();
  drawCylinder(3.5f, 3.5f, 20, 12);
  popMatrix();

  pushMatrix();
  translate(piezoX, tankBottomY - waterH * 0.5f, 20);
  fill(0, 220, 255, 220);
  noStroke();
  drawCylinder(4.0f, 4.0f, waterH, 14);
  popMatrix();

  pushMatrix();
  translate(piezoX, tankBottomY - tankH * 0.5f, 20);
  noFill();
  stroke(210, 235, 255, 180);
  strokeWeight(1.5f);
  drawCylinder(5.5f, 5.5f, tankH + 12, 14);
  popMatrix();

  pushMatrix();
  translate(piezoX - 12, tankBottomY - tankH * 0.5f, 20);
  fill(245, 248, 252);
  noStroke();
  box(10, tankH + 12, 3);
  fill(25, 35, 50);
  for (int k = -60; k <= 60; k += 10) {
    pushMatrix();
    translate(2, k, 2);
    box(6, 1.5f, 1);
    popMatrix();
  }
  popMatrix();

  // 7. External Cylindrical Mouthpiece (d = 20 mm)
  float mpX = tankCenterX + tankW * 0.5f;
  float mpY = tankBottomY - 16.0f;
  pushMatrix();
  translate(mpX + 15, mpY, 0);
  rotateZ(HALF_PI);
  fill(218, 175, 55);
  noStroke();
  drawCylinder(8.2f, 8.2f, 30, 20);
  translate(0, 13, 0);
  drawCylinder(12.5f, 12.5f, 4, 20);
  popMatrix();

  // 8. Inclined Slope Channel & Collecting Tank + Regulating Valve
  pushMatrix();
  translate(26, 36, 0);
  rotateZ(0.46f);
  fill(130, 150, 175);
  noStroke();
  box(130, 5, 30);
  popMatrix();

  pushMatrix();
  translate(130, 30, -24);
  fill(35, 165, 220, 175);
  noStroke();
  box(70, 40, 70);
  noFill();
  stroke(180, 215, 245);
  strokeWeight(1.8f);
  box(74, 54, 74);
  popMatrix();

  pushMatrix();
  translate(130, 64, -24);
  fill(160, 175, 195);
  noStroke();
  drawCylinder(4.5f, 4.5f, 20, 12);
  translate(0, 0, 13);
  fill(46, 213, 115);
  rotateX(HALF_PI);
  drawCylinder(10, 10, 3, 16);
  popMatrix();

  // 9. Animated 3D Discharge Jet & Slope Flow Particles
  float cdActive = cd_vals[selectedReading];
  float jetVelFactor = cdActive * sqrt(max(currentHeadH, 0.05f)) / 0.55f;

  noStroke();
  fill(90, 235, 255, 235);
  for (int i = 0; i < jetParticles3D.size(); i++) {
    JetParticle3D p = jetParticles3D.get(i);
    p.t += 0.014f * p.speed * jetVelFactor;
    if (p.t > 1.0f) {
      p.reset(0.0f);
    }
    float px, py, pz;
    if (p.t < 0.35f) {
      float u = p.t / 0.35f;
      px = (mpX + 30) + u * 42.0f * jetVelFactor;
      py = mpY + u * u * 21.0f + p.offY * 0.5f;
      pz = p.offZ * 0.5f;
    } else {
      float u = (p.t - 0.35f) / 0.65f;
      px = lerp(-15, 96, u);
      py = lerp(16, 62, u) + p.offY * 0.4f;
      pz = lerp(0, -18, u) + p.offZ * 0.6f;
    }
    pushMatrix();
    translate(px, py, pz);
    sphere(2.5f);
    popMatrix();
  }
}

void drawCylinder(float rBottom, float rTop, float h, int sides) {
  float halfH = h * 0.5f;
  float angleStep = TWO_PI / sides;
  beginShape(QUAD_STRIP);
  for (int i = 0; i <= sides; i++) {
    float a = i * angleStep;
    float ca = cos(a);
    float sa = sin(a);
    vertex(ca * rBottom, halfH, sa * rBottom);
    vertex(ca * rTop, -halfH, sa * rTop);
  }
  endShape();

  beginShape(TRIANGLE_FAN);
  vertex(0, -halfH, 0);
  for (int i = 0; i <= sides; i++) {
    float a = i * angleStep;
    vertex(cos(a) * rTop, -halfH, sin(a) * rTop);
  }
  endShape();

  beginShape(TRIANGLE_FAN);
  vertex(0, halfH, 0);
  for (int i = 0; i <= sides; i++) {
    float a = i * angleStep;
    vertex(cos(a) * rBottom, halfH, sin(a) * rBottom);
  }
  endShape();
}

void drawScreen1_HUD() {
  int r = selectedReading;
  float vTh = sqrt(2.0f * GRAVITY * currentHeadH);
  float vAct = cd_vals[r] * vTh;
  float qActLps = AREA_MOUTHPIECE * vAct * 1000.0f;

  // Left-Top Controls Panel
  float ctrlX = 12 * uiScale;
  float ctrlY = topBarH + 12 * uiScale;
  float ctrlW = 300 * uiScale;

  // Card A: Observation Reading Selector (R1..R5)
  fill(colPanel, 238);
  stroke(colBorder);
  strokeWeight(1.2f * uiScale);
  rect(ctrlX, ctrlY, ctrlW, 68 * uiScale, 8 * uiScale);

  fill(colTextDim);
  textAlign(LEFT, CENTER);
  textSize(10.8f * uiScale);
  text("SELECT OBSERVATION READING (R1 - R5):", ctrlX + 10 * uiScale, ctrlY + 15 * uiScale);

  float rBtnW = (ctrlW - 20 * uiScale - 4 * 6 * uiScale) / 5.0f;
  for (int i = 0; i < NUM_READINGS; i++) {
    float bx = ctrlX + 10 * uiScale + i * (rBtnW + 6 * uiScale);
    float by = ctrlY + 29 * uiScale;
    float bh = 30 * uiScale;
    fill(i == selectedReading ? colAccent2 : colPanelLite);
    stroke(i == selectedReading ? color(255) : colBorder);
    strokeWeight(1.2f * uiScale);
    rect(bx, by, rBtnW, bh, 5 * uiScale);

    fill(i == selectedReading ? color(15, 20, 30) : colTextMain);
    textAlign(CENTER, CENTER);
    textSize(11.8f * uiScale);
    text("R" + (i + 1) + (i == 2 ? "*" : ""), bx + rBtnW * 0.5f, by + bh * 0.5f);
  }

  // Card B: Camera, Zoom, Fall Toggle & Head H Slider
  float camY = ctrlY + 76 * uiScale;
  fill(colPanel, 238);
  stroke(colBorder);
  rect(ctrlX, camY, ctrlW, 132 * uiScale, 8 * uiScale);

  float bW3 = (ctrlW - 28 * uiScale) / 3.0f;
  float bH3 = 28 * uiScale;
  drawHudBtn(ctrlX + 10 * uiScale, camY + 10 * uiScale, bW3, bH3,
             autoOrbit ? "Orbit: ON" : "Orbit: OFF", autoOrbit);
  drawHudBtn(ctrlX + 14 * uiScale + bW3, camY + 10 * uiScale, bW3, bH3, "Zoom +", false);
  drawHudBtn(ctrlX + 18 * uiScale + 2 * bW3, camY + 10 * uiScale, bW3, bH3, "Zoom -", false);

  // Second row of buttons: Fall Auto/Pause, Labels ON/OFF, Reset View
  float row2Y = camY + 44 * uiScale;
  drawHudBtn(ctrlX + 10 * uiScale, row2Y, bW3, bH3,
             autoFallSim ? "Fall: AUTO" : "Fall: HOLD", autoFallSim);
  drawHudBtn(ctrlX + 14 * uiScale + bW3, row2Y, bW3, bH3,
             show3DLabels ? "Labels: ON" : "Labels: OFF", show3DLabels);
  drawHudBtn(ctrlX + 18 * uiScale + 2 * bW3, row2Y, bW3, bH3, "Reset View", false);

  // Instantaneous Head H Slider
  float slX = ctrlX + 12 * uiScale;
  float slY = camY + 112 * uiScale;
  float slW = ctrlW - 24 * uiScale;
  fill(colTextMain);
  textAlign(LEFT, CENTER);
  textSize(10.8f * uiScale);
  text("Head H = " + nf(currentHeadH, 1, 3) + " m  (H1=" + nf(H1_vals[r], 1, 2) + " -> H2=" + nf(H2_vals[r], 1, 2) + ")",
       slX, camY + 90 * uiScale);

  stroke(colBorder);
  strokeWeight(5 * uiScale);
  line(slX, slY, slX + slW, slY);
  float normH = constrain((currentHeadH - H2_vals[r]) / max(H1_vals[r] - H2_vals[r], 0.001f), 0.0f, 1.0f);
  float knobX = slX + normH * slW;
  stroke(colAccent);
  line(slX, slY, knobX, slY);
  fill(colAccent2);
  stroke(255);
  strokeWeight(1.5f * uiScale);
  ellipse(knobX, slY, 15 * uiScale, 15 * uiScale);

  // Card C: Apparatus Component Legend Card (Bottom-Left under controls)
  float legY = camY + 140 * uiScale;
  float legH = height - botBarH - legY - 12 * uiScale;
  fill(colPanel, 238);
  stroke(colBorder);
  rect(ctrlX, legY, ctrlW, legH, 8 * uiScale);

  fill(colAccent);
  textAlign(LEFT, TOP);
  textSize(11.2f * uiScale);
  text("3D APPARATUS COMPONENTS", ctrlX + 12 * uiScale, legY + 10 * uiScale);

  String[] compItems = {
    "1. Balancing Tank (300x300 mm Acrylic)",
    "2. Side Piezometer Tube + Meter Scale",
    "3. External Mouthpiece (Brass, d=20mm)",
    "4. Delivery Pipe + Red Gate Valve",
    "5. Centrifugal Pump + Electric Motor",
    "6. Slope Channel, Collecting Tank & Sump"
  };
  float cGap = (legH - 36 * uiScale) / 6.0f;
  fill(colTextDim);
  textSize(10.4f * uiScale);
  for (int c = 0; c < compItems.length; c++) {
    text(compItems[c], ctrlX + 12 * uiScale, legY + 30 * uiScale + c * cGap);
  }

  // Central 3D Viewport Top Banner & Bottom Hint
  float hudW = 345 * uiScale;
  float vpX = ctrlW + 24 * uiScale;
  float vpY = topBarH + 12 * uiScale;
  float vpW = width - ctrlW - hudW - 48 * uiScale;
  float vpH = height - topBarH - botBarH - 24 * uiScale;

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(12.2f * uiScale);
  text("3D EXPERIMENTAL RIG: EXTERNAL MOUTHPIECE", vpX + 14 * uiScale, vpY + 18 * uiScale);

  if (show3DLabels) {
    // Clean callout badges inside the 3D frame corners
    drawStageTag(vpX + 14 * uiScale, vpY + 42 * uiScale, "Piezometer + Scale", colAccent);
    drawStageTag(vpX + vpW - 145 * uiScale, vpY + 42 * uiScale, "Gate Valve & Supply", colAccent2);
    drawStageTag(vpX + 14 * uiScale, vpY + vpH - 50 * uiScale, "Balancing Tank (A=0.09m^2)", colTextMain);
    drawStageTag(vpX + vpW - 155 * uiScale, vpY + vpH - 50 * uiScale, "Motor Pump & Sump", colGreen);
  }

  fill(colTextDim);
  textAlign(CENTER, CENTER);
  textSize(10.5f * uiScale);
  text("Touch & drag inside this frame to rotate 3D rig in 360 deg",
       vpX + vpW * 0.5f, vpY + vpH - 14 * uiScale);

  // Right-Side Live Telemetry HUD Card
  float hudH = height - topBarH - botBarH - 24 * uiScale;
  float hudX = width - hudW - 12 * uiScale;
  float hudY = topBarH + 12 * uiScale;

  fill(colPanel, 240);
  stroke(colAccent);
  strokeWeight(1.5f * uiScale);
  rect(hudX, hudY, hudW, hudH, 10 * uiScale);

  fill(colAccent);
  noStroke();
  rect(hudX, hudY, hudW, 34 * uiScale, 10 * uiScale, 10 * uiScale, 0, 0);
  fill(10, 18, 30);
  textAlign(LEFT, CENTER);
  textSize(12.8f * uiScale);
  text("LIVE APPARATUS TELEMETRY (R" + (r + 1) + ")", hudX + 12 * uiScale, hudY + 17 * uiScale);

  float rowY = hudY + 48 * uiScale;
  float rowGap = (hudH - 58 * uiScale) / 11.0f;

  drawTelemetryRow(hudX + 12 * uiScale, rowY + 0 * rowGap, hudW - 24 * uiScale,
                   "Mouthpiece Dia (d):", "20 mm = 0.02 m", colTextMain);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 1 * rowGap, hudW - 24 * uiScale,
                   "Mouthpiece Area (a):", "3.1416 x 10^-4 m^2", colTextMain);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 2 * rowGap, hudW - 24 * uiScale,
                   "Balancing Tank Area (A):", "0.3 x 0.3 = 0.09 m^2", colTextMain);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 3 * rowGap, hudW - 24 * uiScale,
                   "Initial Head (H1):", nf(H1_vals[r], 1, 2) + " m (sqrt=" + nf(sqrtH1_vals[r], 1, 3) + ")", colAccent2);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 4 * rowGap, hudW - 24 * uiScale,
                   "Final Head (H2):", nf(H2_vals[r], 1, 2) + " m (sqrt=" + nf(sqrtH2_vals[r], 1, 3) + ")", colGreen);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 5 * rowGap, hudW - 24 * uiScale,
                   "Fall Time Taken (T):", nf(timeT_vals[r], 1, 1) + " sec", colTextMain);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 6 * rowGap, hudW - 24 * uiScale,
                   "sqrt(H1) - sqrt(H2):", nf(dSqrtH_vals[r], 1, 4) + " m^(1/2)", colAccent);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 7 * rowGap, hudW - 24 * uiScale,
                   "Live Jet Velocity (V_act):", nf(vAct, 1, 2) + " m/s", colTextMain);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 8 * rowGap, hudW - 24 * uiScale,
                   "Live Discharge (Q_act):", nf(qActLps, 1, 3) + " L/s", colTextMain);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 9 * rowGap, hudW - 24 * uiScale,
                   "Run Coeff. of Discharge:", "Cd = " + nf(cd_vals[r], 1, 3), colAccent2);
  drawTelemetryRow(hudX + 12 * uiScale, rowY + 10 * rowGap, hudW - 24 * uiScale,
                   "Lab Record Final Result:", "Cd = 0.695 (Mean: " + nf(getMeanCd(), 1, 3) + ")", colGreen);
}

void drawStageTag(float x, float y, String txt, color c) {
  fill(18, 28, 46, 210);
  stroke(c, 180);
  strokeWeight(1.0f * uiScale);
  rect(x, y, 132 * uiScale, 20 * uiScale, 4 * uiScale);
  fill(c);
  textAlign(CENTER, CENTER);
  textSize(9.5f * uiScale);
  text(txt, x + 66 * uiScale, y + 10 * uiScale);
}

void drawTelemetryRow(float x, float y, float w, String label, String val, color valCol) {
  fill(colTextDim);
  textAlign(LEFT, CENTER);
  textSize(11.2f * uiScale);
  text(label, x, y);

  fill(valCol);
  textAlign(RIGHT, CENTER);
  textSize(11.5f * uiScale);
  text(val, x + w, y);
}

void drawHudBtn(float x, float y, float w, float h, String label, boolean active) {
  fill(active ? colAccent : colPanelLite);
  stroke(active ? color(255) : colBorder);
  strokeWeight(1.2f * uiScale);
  rect(x, y, w, h, 5 * uiScale);

  fill(active ? color(10, 18, 30) : colTextMain);
  textAlign(CENTER, CENTER);
  textSize(10.8f * uiScale);
  text(label, x + w * 0.5f, y + h * 0.5f);
}

// ============================================================================
// SCREEN 2: 2D CUTAWAY CROSS-SECTION & FLOW VISUALIZATION
// ============================================================================
void drawScreen2_CutawayPhysics() {
  int r = selectedReading;
  float pad = 14 * uiScale;
  float x0 = pad;
  float y0 = topBarH + pad;
  float w = width - 2 * pad;
  float h = height - topBarH - botBarH - 2 * pad;

  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(x0, y0, w, h, 10 * uiScale);

  fill(colTextMain);
  textAlign(LEFT, CENTER);
  textSize(13.8f * uiScale);
  text("2D TRANSPARENT CUTAWAY: BALANCING TANK + EXTERNAL MOUTHPIECE (d = 20 mm)",
       x0 + 14 * uiScale, y0 + 20 * uiScale);

  float btnW = 148 * uiScale;
  float btnH = 28 * uiScale;
  float btnY = y0 + 7 * uiScale;
  drawHudBtn(x0 + w - 2 * btnW - 22 * uiScale, btnY, btnW, btnH,
             unsteadyMode ? "UNSTEADY WAVE" : "STEADY FLOW", unsteadyMode);
  drawHudBtn(x0 + w - btnW - 12 * uiScale, btnY, btnW, btnH, "Reset Trails", false);

  float simX = x0 + 14 * uiScale;
  float simY = y0 + 42 * uiScale;
  float simW = w - 28 * uiScale;
  float simH = h - 98 * uiScale;

  fill(12, 20, 32);
  stroke(colBorder);
  strokeWeight(1.2f * uiScale);
  rect(simX, simY, simW, simH, 6 * uiScale);

  float tankLeft  = simX + simW * 0.11f;
  float tankRight = simX + simW * 0.44f;
  float tankTop   = simY + simH * 0.10f;
  float tankBot   = simY + simH * 0.88f;
  float tankInnerH = tankBot - tankTop;

  float mpStartX = tankRight;
  float mpEndX   = simX + simW * 0.60f;
  float mpCenterY = simY + simH * 0.72f;
  float mpHalfH   = simH * 0.052f;

  float waveOffset = unsteadyMode ? sin(frameCount * 0.12f) * 10.0f * uiScale : 0.0f;
  float headFrac = constrain(currentHeadH / 0.85f, 0.15f, 0.92f);
  float waterSurfY = tankBot - tankInnerH * headFrac + waveOffset;
  float h1LineY = tankBot - tankInnerH * constrain(H1_vals[r] / 0.85f, 0.15f, 0.92f);
  float h2LineY = tankBot - tankInnerH * constrain(H2_vals[r] / 0.85f, 0.15f, 0.92f);

  // 1. Water inside Balancing Tank
  noStroke();
  fill(20, 130, 195, 165);
  rect(tankLeft, waterSurfY, tankRight - tankLeft, tankBot - waterSurfY);

  // 2. Water inside External Mouthpiece & Vena Contracta Contraction Zone
  fill(28, 165, 225, 185);
  rect(mpStartX, mpCenterY - mpHalfH, mpEndX - mpStartX, mpHalfH * 2.0f);

  // Vena contracta eddy zones
  fill(14, 52, 85, 190);
  ellipse(mpStartX + (mpEndX - mpStartX) * 0.28f, mpCenterY - mpHalfH * 0.82f, (mpEndX - mpStartX) * 0.34f, mpHalfH * 0.36f);
  ellipse(mpStartX + (mpEndX - mpStartX) * 0.28f, mpCenterY + mpHalfH * 0.82f, (mpEndX - mpStartX) * 0.34f, mpHalfH * 0.36f);

  // 3. Streamlines
  stroke(80, 210, 255, 105);
  strokeWeight(1.3f * uiScale);
  noFill();
  for (int s = 0; s < 5; s++) {
    float frac = (s + 1) / 6.0f;
    float sy0 = lerp(waterSurfY + 12 * uiScale, tankBot - 10 * uiScale, frac);
    float syMid = mpCenterY + (frac - 0.5f) * mpHalfH * 1.45f;
    beginShape();
    vertex(tankLeft + 10 * uiScale, sy0);
    bezierVertex(tankLeft + (tankRight - tankLeft) * 0.65f, sy0,
                 tankRight - 25 * uiScale, syMid,
                 mpStartX, syMid);
    vertex(mpEndX, syMid);
    endShape();
  }

  // 4. Velocity-Colored Particles + Lagrangian Pathlines
  float vTh = sqrt(2.0f * GRAVITY * currentHeadH);
  float vAct = cd_vals[r] * vTh;
  float speedScale = (vAct / 2.5f) * (unsteadyMode ? (1.0f + 0.25f * sin(frameCount * 0.14f)) : 1.0f);

  for (int i = 0; i < particles2D.size(); i++) {
    FluidParticle2D p = particles2D.get(i);
    float px = simX + p.x * simW;
    float py = simY + p.y * simH;

    if (px < tankRight) {
      float dx = (mpStartX - px);
      float dy = (mpCenterY - py);
      float dist = max(sqrt(dx * dx + dy * dy), 18.0f);
      float vMag = 0.0014f * speedScale * (simW * 0.32f / dist);
      p.vx = (dx / dist) * vMag;
      p.vy = (dy / dist) * vMag + 0.00035f * speedScale;
      p.speedMag = constrain(vMag * 180.0f, 0.0f, 0.45f);
    } else if (px < mpEndX) {
      float localU = (px - mpStartX) / (mpEndX - mpStartX);
      float vcBoost = (localU < 0.45f) ? 1.22f : 1.0f;
      p.vx = 0.0072f * speedScale * vcBoost;
      p.vy = (mpCenterY - py) * 0.04f;
      p.speedMag = constrain(0.65f + 0.35f * vcBoost, 0.0f, 1.0f);
    } else {
      float jetU = (px - mpEndX) / (simW * 0.36f);
      p.vx = 0.0070f * speedScale;
      p.vy = 0.0042f * jetU * (2.2f / max(speedScale, 0.5f));
      p.speedMag = 0.88f;
    }

    p.x += p.vx;
    p.y += p.vy;

    float newPx = simX + p.x * simW;
    float newPy = simY + p.y * simH;

    if (newPx < tankRight && newPy < waterSurfY + 4 * uiScale) {
      newPy = waterSurfY + 6 * uiScale;
      p.y = (newPy - simY) / simH;
    }

    p.trail.add(new PVector(newPx, newPy));
    if (p.trail.size() > 12) {
      p.trail.remove(0);
    }

    if (newPx > simX + simW - 8 * uiScale || newPy > simY + simH - 8 * uiScale) {
      p.respawn(false);
      continue;
    }

    color pCol = lerpColor(color(45, 190, 255), color(255, 195, 35), constrain(p.speedMag * 1.2f, 0, 1));
    if (p.speedMag > 0.82f) {
      pCol = lerpColor(color(255, 195, 35), color(255, 70, 80), (p.speedMag - 0.82f) / 0.18f);
    }

    stroke(pCol, 110);
    strokeWeight(1.3f * uiScale);
    noFill();
    beginShape();
    for (int k = 0; k < p.trail.size(); k++) {
      PVector pt = p.trail.get(k);
      vertex(pt.x, pt.y);
    }
    endShape();

    noStroke();
    fill(pCol);
    ellipse(newPx, newPy, 4.4f * uiScale, 4.4f * uiScale);
  }

  // 5. Interactive Streakline Dye Nozzle
  float injX = simX + nozzleNormX * simW;
  float injY = simY + nozzleNormY * simH;
  streaklinePts.add(0, new PVector(injX, injY));
  for (int i = 0; i < streaklinePts.size(); i++) {
    PVector sp = streaklinePts.get(i);
    if (sp.x < tankRight) {
      float dx = mpStartX - sp.x;
      float dy = mpCenterY - sp.y;
      float dist = max(sqrt(dx * dx + dy * dy), 16.0f);
      float v = 3.2f * uiScale * speedScale * (simW * 0.30f / dist);
      sp.x += (dx / dist) * v;
      sp.y += (dy / dist) * v;
    } else if (sp.x < mpEndX) {
      sp.x += 6.2f * uiScale * speedScale;
      sp.y += (mpCenterY - sp.y) * 0.08f;
    } else {
      float jetU = (sp.x - mpEndX) / (simW * 0.36f);
      sp.x += 6.0f * uiScale * speedScale;
      sp.y += 3.5f * uiScale * jetU;
    }
  }
  while (streaklinePts.size() > 75 || (streaklinePts.size() > 0 && streaklinePts.get(streaklinePts.size() - 1).x > simX + simW - 8 * uiScale)) {
    streaklinePts.remove(streaklinePts.size() - 1);
  }

  stroke(255, 65, 195);
  strokeWeight(2.6f * uiScale);
  noFill();
  beginShape();
  for (int i = 0; i < streaklinePts.size(); i++) {
    PVector sp = streaklinePts.get(i);
    vertex(sp.x, sp.y);
  }
  endShape();

  fill(255, 65, 195);
  stroke(255);
  strokeWeight(1.5f * uiScale);
  ellipse(injX, injY, 12 * uiScale, 12 * uiScale);
  fill(255, 180, 235);
  textAlign(LEFT, CENTER);
  textSize(10.0f * uiScale);
  text("Dye Nozzle (Tap to move)", injX + 9 * uiScale, injY - 8 * uiScale);

  // 6. Velocity Profile Arrows at Mouthpiece Exit
  stroke(colGreen);
  strokeWeight(1.8f * uiScale);
  for (int a = -2; a <= 2; a++) {
    float ay = mpCenterY + a * (mpHalfH * 0.34f);
    float prof = 1.0f - 0.18f * (a * a) / 4.0f;
    float arrowLen = (28.0f + 16.0f * prof) * uiScale;
    draw2DArrow(mpEndX + 4 * uiScale, ay, mpEndX + 4 * uiScale + arrowLen, ay, colGreen);
  }

  // 7. Tank & Mouthpiece Solid Walls + Piezometer Scale
  stroke(215, 230, 250);
  strokeWeight(3.0f * uiScale);
  noFill();
  line(tankLeft, tankTop, tankLeft, tankBot);
  line(tankLeft, tankBot, tankRight, tankBot);
  line(tankRight, tankTop, tankRight, mpCenterY - mpHalfH);
  line(tankRight, mpCenterY + mpHalfH, tankRight, tankBot);

  stroke(colAccent2);
  strokeWeight(3.5f * uiScale);
  line(mpStartX, mpCenterY - mpHalfH, mpEndX, mpCenterY - mpHalfH);
  line(mpStartX, mpCenterY + mpHalfH, mpEndX, mpCenterY + mpHalfH);

  float pzX = simX + simW * 0.055f;
  fill(0, 210, 255, 210);
  noStroke();
  rect(pzX - 5 * uiScale, waterSurfY, 10 * uiScale, tankBot - waterSurfY);
  stroke(200, 225, 255);
  strokeWeight(1.6f * uiScale);
  noFill();
  rect(pzX - 6 * uiScale, tankTop, 12 * uiScale, tankBot - tankTop);
  line(pzX + 6 * uiScale, tankBot - 8 * uiScale, tankLeft, tankBot - 8 * uiScale);

  stroke(colAccent2);
  strokeWeight(1.4f * uiScale);
  drawDashedLine(pzX - 10 * uiScale, h1LineY, tankRight, h1LineY, 6 * uiScale);
  fill(colAccent2);
  textAlign(LEFT, BOTTOM);
  textSize(10.5f * uiScale);
  text("H1 = " + nf(H1_vals[r], 1, 2) + " m", tankLeft + 8 * uiScale, h1LineY - 2 * uiScale);

  stroke(colGreen);
  drawDashedLine(pzX - 10 * uiScale, h2LineY, tankRight, h2LineY, 6 * uiScale);
  fill(colGreen);
  text("H2 = " + nf(H2_vals[r], 1, 2) + " m", tankLeft + 8 * uiScale, h2LineY - 2 * uiScale);

  fill(colTextMain);
  textAlign(CENTER, TOP);
  textSize(11.0f * uiScale);
  text("BALANCING TANK (A = 0.09 m^2)", (tankLeft + tankRight) * 0.5f, tankTop + 4 * uiScale);
  text("PIEZOMETER", pzX + 12 * uiScale, tankTop - 16 * uiScale);

  fill(colAccent2);
  textAlign(CENTER, BOTTOM);
  text("External Mouthpiece (d = 20 mm)", (mpStartX + mpEndX) * 0.5f, mpCenterY - mpHalfH - 6 * uiScale);

  // Top-Right Quantitative Telemetry Box inside Sim
  float qBoxW = 275 * uiScale;
  float qBoxH = 126 * uiScale;
  float qBoxX = simX + simW - qBoxW - 12 * uiScale;
  float qBoxY = simY + 12 * uiScale;
  fill(18, 28, 46, 235);
  stroke(colAccent);
  strokeWeight(1.3f * uiScale);
  rect(qBoxX, qBoxY, qBoxW, qBoxH, 7 * uiScale);

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(11.5f * uiScale);
  text("LIVE CUTAWAY HYDRODYNAMICS (R" + (r + 1) + ")", qBoxX + 10 * uiScale, qBoxY + 16 * uiScale);
  drawTelemetryRow(qBoxX + 10 * uiScale, qBoxY + 38 * uiScale, qBoxW - 20 * uiScale,
                   "Instantaneous Head H:", nf(currentHeadH, 1, 3) + " m", colAccent2);
  drawTelemetryRow(qBoxX + 10 * uiScale, qBoxY + 58 * uiScale, qBoxW - 20 * uiScale,
                   "Theoretical Vel (V_th):", nf(vTh, 1, 2) + " m/s", colTextMain);
  drawTelemetryRow(qBoxX + 10 * uiScale, qBoxY + 78 * uiScale, qBoxW - 20 * uiScale,
                   "Actual Exit Vel (V_act):", nf(vAct, 1, 2) + " m/s", colGreen);
  drawTelemetryRow(qBoxX + 10 * uiScale, qBoxY + 98 * uiScale, qBoxW - 20 * uiScale,
                   "Discharge Coeff (Cd):", nf(cd_vals[r], 1, 3), colAccent2);

  float legY = simY + simH + 22 * uiScale;
  fill(colTextDim);
  textAlign(LEFT, CENTER);
  textSize(11.0f * uiScale);
  text("LEGEND:   [Blue->Red] Velocity Particles   |   [Cyan] Streamlines   |   [Magenta] Streakline (Tap inside tank to move dye nozzle)   |   [Green] Exit Velocity Profile",
       simX, legY);
}

// ============================================================================
// SCREEN 3: 7-STEP MATHEMATICAL DERIVATION & CONTROL-VOLUME SCHEMATIC
// ============================================================================
void drawScreen3_Derivation() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.56f;
  float rightW = (width - 3 * pad) * 0.44f;
  float leftX = pad;
  float rightX = leftX + leftW + pad;

  // LEFT PANEL: 7-Step Derivation
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(leftX, y0, leftW, totalH, 10 * uiScale);

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(14.0f * uiScale);
  text("MATHEMATICAL DERIVATION: VARIABLE HEAD MOUTHPIECE", leftX + 16 * uiScale, y0 + 22 * uiScale);

  float stepListY = y0 + 44 * uiScale;
  float stepH = (totalH - 98 * uiScale) / 7.0f;

  for (int i = 0; i < 7; i++) {
    float sy = stepListY + i * stepH;
    boolean isSel = (i == derivStep);
    fill(isSel ? color(28, 52, 82) : colPanelLite);
    stroke(isSel ? colAccent2 : colBorder);
    strokeWeight(isSel ? 2.0f * uiScale : 1.0f * uiScale);
    rect(leftX + 34 * uiScale, sy + 2 * uiScale, leftW - 46 * uiScale, stepH - 5 * uiScale, 6 * uiScale);

    if (isSel) {
      float pulse = sin(frameCount * 0.18f) * 4.0f * uiScale;
      draw2DArrow(leftX + 8 * uiScale + pulse, sy + stepH * 0.5f,
                  leftX + 30 * uiScale + pulse, sy + stepH * 0.5f, colAccent2);
    }

    fill(isSel ? colAccent2 : colAccent);
    textAlign(LEFT, TOP);
    textSize(11.2f * uiScale);
    text(derivTitles[i], leftX + 44 * uiScale, sy + 6 * uiScale);

    fill(isSel ? color(255) : colTextMain);
    textSize(11.8f * uiScale);
    text(derivFormulas[i], leftX + 44 * uiScale, sy + 23 * uiScale);
  }

  float bY = y0 + totalH - 42 * uiScale;
  float bW = 135 * uiScale;
  float bH = 30 * uiScale;
  drawHudBtn(leftX + 16 * uiScale, bY, bW, bH, "< Prev Step", false);
  drawHudBtn(leftX + 24 * uiScale + bW, bY, bW, bH, "Next Step >", false);
  drawHudBtn(leftX + leftW - bW - 16 * uiScale, bY, bW, bH,
             autoDerive ? "Auto-Derive: ON" : "Auto-Derive: OFF", autoDerive);

  // RIGHT PANEL: Control-Volume & Energy Grade Line Schematic
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(rightX, y0, rightW, totalH, 10 * uiScale);

  fill(colAccent2);
  textAlign(LEFT, CENTER);
  textSize(13.5f * uiScale);
  text("CONTROL-VOLUME & ENERGY SCHEMATIC", rightX + 14 * uiScale, y0 + 22 * uiScale);

  float schX = rightX + 14 * uiScale;
  float schY = y0 + 42 * uiScale;
  float schW = rightW - 28 * uiScale;
  float schH = totalH - 155 * uiScale;

  fill(13, 21, 35);
  stroke(colBorder);
  rect(schX, schY, schW, schH, 8 * uiScale);

  float tL = schX + schW * 0.16f;
  float tR = schX + schW * 0.56f;
  float tT = schY + schH * 0.14f;
  float tB = schY + schH * 0.86f;
  float mpY = tB - 18 * uiScale;
  float mpOutX = schX + schW * 0.78f;

  float yH1 = tT + (tB - tT) * 0.16f;
  float yH2 = tT + (tB - tT) * 0.44f;
  float yElem = lerp(yH1, yH2, 0.48f);

  noStroke();
  fill(22, 120, 185, 130);
  rect(tL, yH1, tR - tL, tB - yH1);

  fill(255, 195, 45, 140);
  rect(tL, yElem, tR - tL, 12 * uiScale);

  stroke(210, 225, 245);
  strokeWeight(2.5f * uiScale);
  noFill();
  line(tL, tT, tL, tB);
  line(tL, tB, tR, tB);
  line(tR, tT, tR, mpY - 10 * uiScale);
  line(tR, mpY + 10 * uiScale, tR, tB);

  stroke(colAccent2);
  line(tR, mpY - 10 * uiScale, mpOutX, mpY - 10 * uiScale);
  line(tR, mpY + 10 * uiScale, mpOutX, mpY + 10 * uiScale);

  stroke(colRed);
  strokeWeight(1.8f * uiScale);
  drawDashedLine(tL, yH1, tR, yH1, 6 * uiScale);
  line(tR, yH1, mpOutX, yH1 + 26 * uiScale);
  fill(colRed);
  textAlign(LEFT, BOTTOM);
  textSize(10.5f * uiScale);
  text("EGL (Total Head H)", tR + 6 * uiScale, yH1 + 10 * uiScale);

  int r = selectedReading;
  stroke(colAccent2);
  line(tL - 12 * uiScale, yH1, tL - 12 * uiScale, mpY);
  fill(colAccent2);
  textAlign(RIGHT, CENTER);
  textSize(10.5f * uiScale);
  text("H1=" + nf(H1_vals[r], 1, 2) + "m", tL - 15 * uiScale, (yH1 + mpY) * 0.42f);

  stroke(colGreen);
  line(tL + 22 * uiScale, yH2, tL + 22 * uiScale, mpY);
  fill(colGreen);
  textAlign(LEFT, CENTER);
  text("H2=" + nf(H2_vals[r], 1, 2) + "m", tL + 26 * uiScale, (yH2 + mpY) * 0.55f);

  fill(255);
  textAlign(CENTER, CENTER);
  text("Elemental strip: -A * dh", (tL + tR) * 0.5f, yElem + 6 * uiScale);
  text("Plan Area A = 0.09 m^2", (tL + tR) * 0.5f, tT + 10 * uiScale);
  fill(colAccent);
  text("Q_act = Cd * a * sqrt(2gh)", mpOutX + 22 * uiScale, mpY + 26 * uiScale);

  float eqY = schY + schH + 12 * uiScale;
  float eqH = totalH - schH - 66 * uiScale;
  fill(16, 42, 66);
  stroke(colGreen);
  strokeWeight(2.0f * uiScale);
  rect(schX, eqY, schW, eqH, 8 * uiScale);

  fill(colGreen);
  textAlign(CENTER, TOP);
  textSize(12.0f * uiScale);
  text("FINAL DERIVED WORKING FORMULA", schX + schW * 0.5f, eqY + 8 * uiScale);

  fill(255);
  textAlign(CENTER, CENTER);
  textSize(14.2f * uiScale);
  text("Cd = [ 2 * A * (sqrt(H1) - sqrt(H2)) ] / [ T * a * sqrt(2 * g) ]",
       schX + schW * 0.5f, eqY + eqH * 0.52f);

  fill(colAccent2);
  textSize(11.2f * uiScale);
  text("Active R" + (r + 1) + ":  Cd = [ 2 * 0.09 * " + nf(dSqrtH_vals[r], 1, 4) +
       " ] / [ " + nf(timeT_vals[r], 1, 1) + " * 3.1416x10^-4 * 4.429 ] = " + nf(cd_vals[r], 1, 3),
       schX + schW * 0.5f, eqY + eqH - 16 * uiScale);
}

// ============================================================================
// SCREEN 4: 6-STEP EXPERIMENTAL PROCEDURE & DUAL ZOOMED INSTRUMENTS
// ============================================================================
void drawScreen4_Procedure() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.48f;
  float rightW = (width - 3 * pad) * 0.52f;
  float leftX = pad;
  float rightX = leftX + leftW + pad;

  // LEFT PANEL: 6-Step Lab Procedure
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(leftX, y0, leftW, totalH, 10 * uiScale);

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(14.0f * uiScale);
  text("EXPERIMENTAL PROCEDURE (HOW READINGS ARE TAKEN)", leftX + 16 * uiScale, y0 + 22 * uiScale);

  float listY = y0 + 44 * uiScale;
  float itemH = (totalH - 98 * uiScale) / 6.0f;

  for (int i = 0; i < 6; i++) {
    float iy = listY + i * itemH;
    boolean isSel = (i == procStep);
    fill(isSel ? color(28, 54, 84) : colPanelLite);
    stroke(isSel ? colAccent2 : colBorder);
    strokeWeight(isSel ? 2.0f * uiScale : 1.0f * uiScale);
    rect(leftX + 34 * uiScale, iy + 3 * uiScale, leftW - 46 * uiScale, itemH - 6 * uiScale, 6 * uiScale);

    if (isSel) {
      float pulse = sin(frameCount * 0.18f) * 4.0f * uiScale;
      draw2DArrow(leftX + 8 * uiScale + pulse, iy + itemH * 0.5f,
                  leftX + 30 * uiScale + pulse, iy + itemH * 0.5f, colAccent2);
    }

    fill(isSel ? colAccent2 : colAccent);
    textAlign(LEFT, TOP);
    textSize(11.8f * uiScale);
    text(procTitles[i], leftX + 44 * uiScale, iy + 7 * uiScale);

    fill(isSel ? color(255) : colTextDim);
    textSize(10.8f * uiScale);
    text(procDescs[i], leftX + 44 * uiScale, iy + 25 * uiScale, leftW - 64 * uiScale, itemH - 28 * uiScale);
  }

  float bY = y0 + totalH - 42 * uiScale;
  float bW = 115 * uiScale;
  drawHudBtn(leftX + 16 * uiScale, bY, bW, 30 * uiScale, "< Prev Step", false);
  drawHudBtn(leftX + 22 * uiScale + bW, bY, bW, 30 * uiScale, "Next Step >", false);
  drawHudBtn(leftX + leftW - 145 * uiScale - 16 * uiScale, bY, 145 * uiScale, 30 * uiScale,
             autoProc ? "Auto-Demo: ON" : "Auto-Demo: OFF", autoProc);

  // RIGHT PANEL: Two Zoomed Measurement Instruments
  float cardH = (totalH - pad) * 0.5f;
  int r = selectedReading;

  // INSTRUMENT CARD 1: Zoomed Piezometer Tube & Graduated Meter Scale
  fill(colPanel);
  stroke(colAccent);
  strokeWeight(1.5f * uiScale);
  rect(rightX, y0, rightW, cardH, 10 * uiScale);

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(13.0f * uiScale);
  text("INSTRUMENT 1: ZOOMED PIEZOMETER & METER SCALE (H1 -> H2)", rightX + 14 * uiScale, y0 + 20 * uiScale);

  float pzBoxX = rightX + 24 * uiScale;
  float pzBoxY = y0 + 40 * uiScale;
  float pzBoxW = rightW - 48 * uiScale;
  float pzBoxH = cardH - 54 * uiScale;

  fill(12, 20, 32);
  stroke(colBorder);
  rect(pzBoxX, pzBoxY, pzBoxW, pzBoxH, 6 * uiScale);

  float scaleX = pzBoxX + 95 * uiScale;
  float tubeX  = pzBoxX + 145 * uiScale;
  float topScaleY = pzBoxY + 18 * uiScale;
  float botScaleY = pzBoxY + pzBoxH - 18 * uiScale;

  fill(242, 246, 252);
  noStroke();
  rect(scaleX - 38 * uiScale, topScaleY, 38 * uiScale, botScaleY - topScaleY);

  stroke(25, 35, 50);
  textAlign(RIGHT, CENTER);
  textSize(10.0f * uiScale);
  for (int cm = 40; cm <= 80; cm += 2) {
    float frac = (cm - 40.0f) / 40.0f;
    float ty = lerp(botScaleY, topScaleY, frac);
    boolean major = (cm % 5 == 0);
    strokeWeight(major ? 1.6f * uiScale : 1.0f * uiScale);
    line(scaleX - (major ? 14 : 8) * uiScale, ty, scaleX, ty);
    if (major) {
      fill(20, 30, 45);
      text(nf(cm / 100.0f, 1, 2) + "m", scaleX - 16 * uiScale, ty);
    }
  }

  float h1Y = lerp(botScaleY, topScaleY, constrain((H1_vals[r] - 0.40f) / 0.40f, 0, 1));
  float h2Y = lerp(botScaleY, topScaleY, constrain((H2_vals[r] - 0.40f) / 0.40f, 0, 1));
  float curY = lerp(botScaleY, topScaleY, constrain((currentHeadH - 0.40f) / 0.40f, 0, 1));

  fill(0, 210, 255, 210);
  noStroke();
  rect(tubeX - 12 * uiScale, curY, 24 * uiScale, botScaleY - curY);

  stroke(210, 235, 255);
  strokeWeight(2.0f * uiScale);
  noFill();
  rect(tubeX - 13 * uiScale, topScaleY, 26 * uiScale, botScaleY - topScaleY);

  stroke(colAccent2);
  drawDashedLine(scaleX, h1Y, tubeX + 85 * uiScale, h1Y, 5 * uiScale);
  fill(colAccent2);
  textAlign(LEFT, CENTER);
  textSize(11.5f * uiScale);
  text("Initial H1 = " + nf(H1_vals[r], 1, 2) + " m (Start Timer)", tubeX + 22 * uiScale, h1Y - 8 * uiScale);

  stroke(colGreen);
  drawDashedLine(scaleX, h2Y, tubeX + 85 * uiScale, h2Y, 5 * uiScale);
  fill(colGreen);
  text("Final H2 = " + nf(H2_vals[r], 1, 2) + " m (Stop Timer)", tubeX + 22 * uiScale, h2Y + 9 * uiScale);

  fill(255);
  textSize(12.0f * uiScale);
  text("Live Meniscus: " + nf(currentHeadH, 1, 3) + " m", tubeX + 22 * uiScale, (h1Y + h2Y) * 0.5f);

  // INSTRUMENT CARD 2: Zoomed Lab Stopwatch (T sec)
  float card2Y = y0 + cardH + pad;
  fill(colPanel);
  stroke(colAccent2);
  strokeWeight(1.5f * uiScale);
  rect(rightX, card2Y, rightW, cardH, 10 * uiScale);

  fill(colAccent2);
  textAlign(LEFT, CENTER);
  textSize(13.0f * uiScale);
  text("INSTRUMENT 2: LAB STOPWATCH (FALL TIME T) & JET DISCHARGE", rightX + 14 * uiScale, card2Y + 20 * uiScale);

  float swBoxX = rightX + 24 * uiScale;
  float swBoxY = card2Y + 40 * uiScale;
  float swBoxW = rightW - 48 * uiScale;
  float swBoxH = cardH - 54 * uiScale;

  fill(12, 20, 32);
  stroke(colBorder);
  rect(swBoxX, swBoxY, swBoxW, swBoxH, 6 * uiScale);

  float dialR = min(swBoxH * 0.40f, 68 * uiScale);
  float dialCX = swBoxX + dialR + 28 * uiScale;
  float dialCY = swBoxY + swBoxH * 0.52f;

  fill(180, 195, 215);
  noStroke();
  rect(dialCX - 8 * uiScale, dialCY - dialR - 12 * uiScale, 16 * uiScale, 12 * uiScale, 3 * uiScale);

  fill(28, 38, 56);
  stroke(colAccent2);
  strokeWeight(2.5f * uiScale);
  ellipse(dialCX, dialCY, dialR * 2.0f, dialR * 2.0f);

  for (int t = 0; t < 60; t += 5) {
    float ang = -HALF_PI + (t / 60.0f) * TWO_PI;
    stroke(210, 225, 245);
    strokeWeight(1.5f * uiScale);
    line(dialCX + cos(ang) * dialR * 0.78f, dialCY + sin(ang) * dialR * 0.78f,
         dialCX + cos(ang) * dialR * 0.92f, dialCY + sin(ang) * dialR * 0.92f);
  }

  float elapsedT = fallProgress * timeT_vals[r];
  float handAng = -HALF_PI + (elapsedT / 30.0f) * TWO_PI;
  stroke(colRed);
  strokeWeight(2.4f * uiScale);
  line(dialCX, dialCY, dialCX + cos(handAng) * dialR * 0.82f, dialCY + sin(handAng) * dialR * 0.82f);
  fill(colAccent2);
  noStroke();
  ellipse(dialCX, dialCY, 8 * uiScale, 8 * uiScale);

  float lcdX = dialCX + dialR + 26 * uiScale;
  float lcdW = swBoxX + swBoxW - lcdX - 16 * uiScale;
  float lcdY = swBoxY + 12 * uiScale;
  float lcdH = swBoxH - 54 * uiScale;

  fill(168, 190, 165);
  stroke(45, 65, 55);
  strokeWeight(2.0f * uiScale);
  rect(lcdX, lcdY, lcdW, lcdH, 6 * uiScale);

  fill(18, 28, 20);
  textAlign(LEFT, TOP);
  textSize(10.0f * uiScale);
  text("STOPWATCH (R" + (r + 1) + ")", lcdX + 10 * uiScale, lcdY + 6 * uiScale);

  textAlign(CENTER, CENTER);
  textSize(22.0f * uiScale);
  text(nf(elapsedT, 1, 2) + " s", lcdX + lcdW * 0.5f, lcdY + lcdH * 0.48f);

  textSize(10.8f * uiScale);
  text("Target Fall Time T = " + nf(timeT_vals[r], 1, 1) + " sec",
       lcdX + lcdW * 0.5f, lcdY + lcdH - 12 * uiScale);

  // Stopwatch Control Buttons (Start/Pause & Reset)
  float swBtnY = lcdY + lcdH + 8 * uiScale;
  float swBtnW = (lcdW - 8 * uiScale) * 0.5f;
  drawHudBtn(lcdX, swBtnY, swBtnW, 24 * uiScale, autoFallSim ? "Pause Timer" : "Start Timer", autoFallSim);
  drawHudBtn(lcdX + swBtnW + 8 * uiScale, swBtnY, swBtnW, 24 * uiScale, "Reset Timer", false);
}

// ============================================================================
// SCREEN 5: 8-STEP BODMAS BREAKDOWN & AUTHENTIC 47-KEY CASIO fx-991MS
// ============================================================================
void drawScreen5_CasioCalc() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.53f;
  float rightW = (width - 3 * pad) * 0.47f;
  float leftX = pad;
  float rightX = leftX + leftW + pad;

  int r = selectedReading;
  float h1 = H1_vals[r];
  float h2 = H2_vals[r];
  float s1 = sqrtH1_vals[r];
  float s2 = sqrtH2_vals[r];
  float ds = dSqrtH_vals[r];
  float tSec = timeT_vals[r];
  float numVal = 2.0f * AREA_TANK * ds;
  float denVal = tSec * AREA_MOUTHPIECE * SQRT_2G;
  float cdVal = cd_vals[r];

  String[] bodmasBadges = { "B", "O", "O", "B", "M", "M", "D", "A/S" };
  String[] bodmasTitles = {
    "1. [B] Mouthpiece Area (a = pi/4 * d^2)",
    "2. [O] Tank Plan Area (A = L * B)",
    "3. [O] Velocity Factor sqrt(2 * g)",
    "4. [B] Head Roots (sqrt(H1) - sqrt(H2))",
    "5. [M] Numerator = 2 * A * (sqrt(H1) - sqrt(H2))",
    "6. [M] Denominator = T * a * sqrt(2 * g)",
    "7. [D] Coefficient of Discharge (Cd = Num / Den)",
    "8. [A/S] Lab Mean & Final Record Result"
  };
  String[] bodmasExprs = {
    "(3.1416 / 4) * (0.02)^2 = 3.1416 x 10^-4 m^2",
    "0.30 m * 0.30 m = 0.09 m^2",
    "sqrt(2 * 9.81) = sqrt(19.62) = 4.429 m^(1/2)/s",
    "sqrt(" + nf(h1, 1, 2) + ") - sqrt(" + nf(h2, 1, 2) + ") = " + nf(s1, 1, 3) + " - " + nf(s2, 1, 3) + " = " + nf(ds, 1, 4),
    "2 * 0.09 * " + nf(ds, 1, 4) + " = " + nf(numVal, 1, 5),
    nf(tSec, 1, 1) + " * 3.1416x10^-4 * 4.429 = " + nf(denVal, 1, 5),
    nf(numVal, 1, 5) + " / " + nf(denVal, 1, 5) + "  ==>  Cd = " + nf(cdVal, 1, 3),
    "Mean(R1..R5) = " + nf(getMeanCd(), 1, 3) + "  |  Final Record Cd = 0.695"
  };
  String[] casioTopLine = {
    "pi / 4 x 0.02^2",
    "0.30 x 0.30",
    "sqrt(2 x 9.81)",
    "sqrt(" + nf(h1, 1, 2) + ") - sqrt(" + nf(h2, 1, 2) + ")",
    "2 x 0.09 x " + nf(ds, 1, 4),
    nf(tSec, 1, 1) + " x 3.1416E-4 x 4.429",
    nf(numVal, 1, 5) + " / " + nf(denVal, 1, 5),
    "(0.644+0.683+0.689+0.671+0.731)/5"
  };
  String[] casioBotLine = {
    "3.1416x10^-04",
    "0.09",
    "4.429446918",
    nf(ds, 1, 4),
    nf(numVal, 1, 5),
    nf(denVal, 1, 5),
    nf(cdVal, 1, 3),
    "0.6836 (Rec: 0.695)"
  };
  String[] targetKeyHighlight = {
    "x^2", "x", "sqrt", "sqrt", "x", "EXP", "/", "="
  };
  String[] keySeqGuide = {
    "Keys: [SHIFT] [EXP(pi)] [/] [4] [x] [0] [.] [0] [2] [x^2] [=]",
    "Keys: [0] [.] [3] [0] [x] [0] [.] [3] [0] [=]",
    "Keys: [sqrt] [(] [2] [x] [9] [.] [8] [1] [)] [=]",
    "Keys: [sqrt] [" + nf(h1, 1, 2) + "] [-] [sqrt] [" + nf(h2, 1, 2) + "] [=]",
    "Keys: [2] [x] [0] [.] [0] [9] [x] [" + nf(ds, 1, 4) + "] [=]",
    "Keys: [" + nf(tSec, 1, 1) + "] [x] [3.1416] [EXP] [(-)] [4] [x] [4.429] [=]",
    "Keys: [" + nf(numVal, 1, 5) + "] [/] [" + nf(denVal, 1, 5) + "] [=]",
    "Keys: [(] [0.644+0.683+0.689+0.671+0.731] [)] [/] [5] [=]"
  };

  // LEFT PANEL: 8-Step BODMAS Breakdown
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(leftX, y0, leftW, totalH, 10 * uiScale);

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(13.5f * uiScale);
  text("BODMAS STEP-BY-STEP SOLVER (R" + (r + 1) + ")", leftX + 14 * uiScale, y0 + 20 * uiScale);

  String[] letters = { "B", "O", "D", "M", "A", "S" };
  float pillStartX = leftX + leftW - 195 * uiScale;
  for (int k = 0; k < 6; k++) {
    float px = pillStartX + k * 30 * uiScale;
    boolean activeLetter = bodmasBadges[bodmasStep].indexOf(letters[k]) >= 0;
    fill(activeLetter ? colAccent2 : colPanelLite);
    stroke(activeLetter ? color(255) : colBorder);
    rect(px, y0 + 8 * uiScale, 25 * uiScale, 23 * uiScale, 4 * uiScale);
    fill(activeLetter ? color(15, 20, 30) : colTextDim);
    textAlign(CENTER, CENTER);
    textSize(11.0f * uiScale);
    text(letters[k], px + 12.5f * uiScale, y0 + 19.5f * uiScale);
  }

  float rowStartY = y0 + 38 * uiScale;
  float rowH = (totalH - 86 * uiScale) / 8.0f;

  for (int i = 0; i < 8; i++) {
    float ry = rowStartY + i * rowH;
    boolean isSel = (i == bodmasStep && !calcUserOverride);
    fill(isSel ? color(28, 54, 84) : colPanelLite);
    stroke(isSel ? colAccent2 : colBorder);
    strokeWeight(isSel ? 1.8f * uiScale : 1.0f * uiScale);
    rect(leftX + 32 * uiScale, ry + 2 * uiScale, leftW - 44 * uiScale, rowH - 4 * uiScale, 5 * uiScale);

    if (isSel) {
      float pulse = sin(frameCount * 0.18f) * 3.5f * uiScale;
      draw2DArrow(leftX + 7 * uiScale + pulse, ry + rowH * 0.5f,
                  leftX + 28 * uiScale + pulse, ry + rowH * 0.5f, colAccent2);
    }

    fill(isSel ? colAccent2 : colAccent);
    noStroke();
    rect(leftX + 38 * uiScale, ry + 5 * uiScale, 28 * uiScale, 16 * uiScale, 3 * uiScale);
    fill(10, 18, 30);
    textAlign(CENTER, CENTER);
    textSize(9.5f * uiScale);
    text(bodmasBadges[i], leftX + 52 * uiScale, ry + 13 * uiScale);

    fill(isSel ? colAccent2 : colTextMain);
    textAlign(LEFT, CENTER);
    textSize(10.8f * uiScale);
    text(bodmasTitles[i], leftX + 72 * uiScale, ry + 13 * uiScale);

    fill(isSel ? color(255) : colTextDim);
    textSize(11.2f * uiScale);
    text(bodmasExprs[i], leftX + 40 * uiScale, ry + rowH - 12 * uiScale);
  }

  float bY = y0 + totalH - 38 * uiScale;
  drawHudBtn(leftX + 14 * uiScale, bY, 155 * uiScale, 28 * uiScale,
             autoBodmas ? "Auto-Step: ON" : "Auto-Step: OFF", autoBodmas);
  fill(colTextDim);
  textAlign(RIGHT, CENTER);
  textSize(10.5f * uiScale);
  text("Tap any BODMAS row or press any of the 47 Casio keys ->", leftX + leftW - 14 * uiScale, bY + 14 * uiScale);

  // RIGHT PANEL: Authentic 47-Key Casio fx-991MS S-V.P.A.M.
  drawCasioFx991MS(rightX, y0, rightW, totalH,
                   calcUserOverride ? calcCustomExpr : casioTopLine[bodmasStep],
                   calcUserOverride ? calcCustomAns  : casioBotLine[bodmasStep],
                   targetKeyHighlight[bodmasStep],
                   keySeqGuide[bodmasStep]);
}

void drawCasioFx991MS(float bx, float by, float bw, float bh,
                      String lcdTop, String lcdBot, String activeKey, String seqGuide) {
  fill(46, 54, 68);
  stroke(110, 125, 148);
  strokeWeight(2.2f * uiScale);
  rect(bx, by, bw, bh, 16 * uiScale);

  float pad = 12 * uiScale;
  float ix = bx + pad;
  float iw = bw - 2 * pad;

  // 1. Header Branding + 4-Cell Solar Panel
  fill(235, 240, 248);
  textAlign(LEFT, TOP);
  textSize(14.5f * uiScale);
  text("CASIO", ix + 4 * uiScale, by + 10 * uiScale);

  fill(175, 195, 220);
  textSize(10.5f * uiScale);
  text("fx-991MS", ix + 64 * uiScale, by + 13 * uiScale);

  fill(235, 175, 55);
  textSize(9.5f * uiScale);
  text("S-V.P.A.M.", ix + 4 * uiScale, by + 27 * uiScale);

  float solW = 92 * uiScale;
  float solH = 22 * uiScale;
  float solX = ix + iw - solW - 4 * uiScale;
  float solY = by + 11 * uiScale;
  fill(58, 36, 28);
  stroke(135, 145, 160);
  strokeWeight(1.2f * uiScale);
  rect(solX, solY, solW, solH, 3 * uiScale);
  for (int c = 1; c < 4; c++) {
    line(solX + c * (solW / 4.0f), solY, solX + c * (solW / 4.0f), solY + solH);
  }

  // 2. 2-Line Dot-Matrix + 7-Segment LCD Screen
  float lcdX = ix + 2 * uiScale;
  float lcdY = by + 42 * uiScale;
  float lcdW = iw - 4 * uiScale;
  float lcdH = 54 * uiScale;

  fill(22, 26, 34);
  stroke(95, 110, 130);
  rect(lcdX - 3 * uiScale, lcdY - 3 * uiScale, lcdW + 6 * uiScale, lcdH + 6 * uiScale, 6 * uiScale);

  fill(178, 198, 172);
  noStroke();
  rect(lcdX, lcdY, lcdW, lcdH, 4 * uiScale);

  fill(22, 32, 22);
  textAlign(LEFT, TOP);
  textSize(9.0f * uiScale);
  String flags = (casioShiftMode ? "[S]  " : "") + (casioAlphaMode ? "[A]  " : "") + "D    SCI    MATH";
  text(flags, lcdX + 8 * uiScale, lcdY + 4 * uiScale);

  textAlign(LEFT, CENTER);
  textSize(12.0f * uiScale);
  text(lcdTop, lcdX + 10 * uiScale, lcdY + 23 * uiScale);

  textAlign(RIGHT, CENTER);
  textSize(16.5f * uiScale);
  text(lcdBot, lcdX + lcdW - 10 * uiScale, lcdY + 41 * uiScale);

  // 3. Top Control Pills (SHIFT, ALPHA, 4-Way REPLAY Oval, MODE, ON) = 5 controls
  float ctrlY = lcdY + lcdH + 10 * uiScale;
  float ctrlH = 38 * uiScale;
  float pillW = 46 * uiScale;
  float pillH = 20 * uiScale;

  drawCasioPill(ix + 6 * uiScale, ctrlY + 6 * uiScale, pillW, pillH, "SHIFT",
                casioShiftMode ? color(255, 225, 90) : color(220, 175, 50));
  drawCasioPill(ix + 12 * uiScale + pillW, ctrlY + 6 * uiScale, pillW, pillH, "ALPHA",
                casioAlphaMode ? color(255, 110, 130) : color(205, 65, 85));

  float repCX = ix + iw * 0.5f;
  float repCY = ctrlY + ctrlH * 0.5f;
  fill(78, 88, 106);
  stroke(150, 165, 185);
  strokeWeight(1.5f * uiScale);
  ellipse(repCX, repCY, 76 * uiScale, 36 * uiScale);
  fill(225, 235, 248);
  textAlign(CENTER, CENTER);
  textSize(8.5f * uiScale);
  text("REPLAY", repCX, repCY);

  drawCasioPill(ix + iw - 2 * pillW - 12 * uiScale, ctrlY + 6 * uiScale, pillW, pillH, "MODE", color(155, 170, 190));
  drawCasioPill(ix + iw - pillW - 6 * uiScale, ctrlY + 6 * uiScale, pillW, pillH, "ON", color(155, 170, 190));

  // 4. 22 Scientific Keys (4 rows: 6 + 6 + 5 + 5 = 22 keys)
  float sciY = ctrlY + ctrlH + 8 * uiScale;
  String[][] sciRows = {
    { "x^-1", "nCr", "Pol(", "x^3", "ab/c", "d/dx" },
    { "sqrt", "x^2", "^",   "log", "ln",   "(-)"  },
    { "hyp",  "sin", "cos", "tan", "RCL"          },
    { "ENG",  "(",   ")",   ",",   "M+"           }
  };
  String[][] sciShifts = {
    { "x!",   "nPr", "Rec(", "3v", "d/c",  "int"  },
    { "3v",   "x^3", "x^1/y","10^x","e^x", "A"    },
    { "abs",  "sin-1","cos-1","tan-1","STO"       },
    { "<-",   "%",   "X",   ";",   "M-"           }
  };

  float sciRowH = 29 * uiScale;
  for (int rIdx = 0; rIdx < sciRows.length; rIdx++) {
    int cols = sciRows[rIdx].length;
    float gap = 5 * uiScale;
    float kw = (iw - (cols - 1) * gap) / cols;
    float kh = 19 * uiScale;
    float ky = sciY + rIdx * sciRowH + 8 * uiScale;

    for (int cIdx = 0; cIdx < cols; cIdx++) {
      float kx = ix + cIdx * (kw + gap);
      String kLbl = sciRows[rIdx][cIdx];
      String sLbl = sciShifts[rIdx][cIdx];
      boolean isHighlight = kLbl.equals(activeKey) && !calcUserOverride;

      fill(235, 185, 65);
      textAlign(CENTER, BOTTOM);
      textSize(7.8f * uiScale);
      text(sLbl, kx + kw * 0.5f, ky - 1 * uiScale);

      fill(isHighlight ? colAccent2 : color(32, 38, 48));
      stroke(isHighlight ? color(255) : color(85, 98, 118));
      strokeWeight(isHighlight ? 1.8f * uiScale : 1.0f * uiScale);
      rect(kx, ky, kw, kh, 4 * uiScale);

      fill(isHighlight ? color(15, 20, 30) : color(235, 242, 252));
      textAlign(CENTER, CENTER);
      textSize(9.2f * uiScale);
      text(kLbl, kx + kw * 0.5f, ky + kh * 0.5f);

      if (isHighlight) {
        float bounce = sin(frameCount * 0.22f) * 3.0f * uiScale;
        draw2DArrow(kx + kw * 0.5f, ky - 16 * uiScale + bounce,
                    kx + kw * 0.5f, ky - 2 * uiScale + bounce, colRed);
      }
    }
  }

  // 5. 20 Numeric & Operator Keys (4 rows x 5 cols = 20 keys; total = 47 keys)
  float numY = sciY + 4 * sciRowH + 6 * uiScale;
  float guideH = 26 * uiScale;
  float availNumH = (by + bh - guideH - 8 * uiScale) - numY;
  float numRowH = availNumH / 4.0f;

  String[][] numRows = {
    { "7", "8", "9", "DEL", "AC"  },
    { "4", "5", "6", "x",   "/"   },
    { "1", "2", "3", "+",   "-"   },
    { "0", ".", "EXP", "Ans", "=" }
  };
  String[][] numShifts = {
    { "CONST", "CONV", "CLR", "INS", "OFF" },
    { "MATRIX","VECTOR","STAT","nPr","nCr" },
    { "S-SUM", "S-VAR","DISTR","Pol","Rec" },
    { "Rnd",   "Ran#", "pi",  "DRG", "%"   }
  };

  for (int rIdx = 0; rIdx < 4; rIdx++) {
    float gap = 6 * uiScale;
    float kw = (iw - 4 * gap) / 5.0f;
    float kh = numRowH - 9 * uiScale;
    float ky = numY + rIdx * numRowH + 8 * uiScale;

    for (int cIdx = 0; cIdx < 5; cIdx++) {
      float kx = ix + cIdx * (kw + gap);
      String kLbl = numRows[rIdx][cIdx];
      String sLbl = numShifts[rIdx][cIdx];
      boolean isDelAc = (kLbl.equals("DEL") || kLbl.equals("AC"));
      boolean isHighlight = kLbl.equals(activeKey) && !calcUserOverride;

      fill(235, 185, 65);
      textAlign(CENTER, BOTTOM);
      textSize(7.8f * uiScale);
      text(sLbl, kx + kw * 0.5f, ky - 1 * uiScale);

      color keyCol = isDelAc ? color(195, 72, 58) : color(92, 102, 118);
      if (isHighlight) keyCol = colAccent2;

      fill(keyCol);
      stroke(isHighlight ? color(255) : color(135, 148, 168));
      strokeWeight(isHighlight ? 1.8f * uiScale : 1.0f * uiScale);
      rect(kx, ky, kw, kh, 5 * uiScale);

      fill(isHighlight ? color(15, 20, 30) : color(255));
      textAlign(CENTER, CENTER);
      textSize(11.2f * uiScale);
      text(kLbl, kx + kw * 0.5f, ky + kh * 0.5f);

      if (isHighlight) {
        float bounce = sin(frameCount * 0.22f) * 3.0f * uiScale;
        draw2DArrow(kx + kw * 0.5f, ky - 16 * uiScale + bounce,
                    kx + kw * 0.5f, ky - 2 * uiScale + bounce, colRed);
      }
    }
  }

  // 6. Bottom Keystroke Sequence Guide
  float gY = by + bh - guideH - 4 * uiScale;
  fill(20, 28, 42);
  stroke(colAccent);
  strokeWeight(1.0f * uiScale);
  rect(ix, gY, iw, guideH, 5 * uiScale);

  fill(colAccent2);
  textAlign(CENTER, CENTER);
  textSize(10.0f * uiScale);
  text(seqGuide, ix + iw * 0.5f, gY + guideH * 0.5f);
}

void drawCasioPill(float x, float y, float w, float h, String lbl, color c) {
  fill(c);
  noStroke();
  rect(x, y, w, h, h * 0.5f);
  fill(15, 20, 30);
  textAlign(CENTER, CENTER);
  textSize(8.5f * uiScale);
  text(lbl, x + w * 0.5f, y + h * 0.5f);
}

// ============================================================================
// SCREEN 6: OBSERVATION TABLE & LAB-RECORD GRAPH SHEET
// ============================================================================
void drawScreen6_TableAndGraph() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.55f;
  float rightW = (width - 3 * pad) * 0.45f;
  float leftX = pad;
  float rightX = leftX + leftW + pad;

  // LEFT PANEL: Observation Table (R1..R5)
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(leftX, y0, leftW, totalH, 10 * uiScale);

  fill(colAccent);
  textAlign(LEFT, CENTER);
  textSize(13.5f * uiScale);
  text("OBSERVATION TABLE: MOUTHPIECE (VARIABLE HEAD METHOD)", leftX + 14 * uiScale, y0 + 20 * uiScale);

  fill(colTextDim);
  textSize(10.5f * uiScale);
  text("Constants: d = 20 mm (a = 3.1416x10^-4 m^2)  |  Tank L = B = 0.30 m (A = 0.09 m^2)  |  Tap row to select",
       leftX + 14 * uiScale, y0 + 38 * uiScale);

  float tblX = leftX + 12 * uiScale;
  float tblY = y0 + 54 * uiScale;
  float tblW = leftW - 24 * uiScale;
  float hdrH = 38 * uiScale;
  float rowH = 44 * uiScale;

  String[] colHeaders = {
    "Run", "H1 (m)", "H2 (m)", "sqrt(H1)", "sqrt(H2)", "Time T (s)", "sqrtH1-sqrtH2", "Cd"
  };
  float[] colWeights = { 0.09f, 0.11f, 0.11f, 0.12f, 0.12f, 0.13f, 0.18f, 0.14f };

  fill(28, 46, 74);
  stroke(colAccent);
  strokeWeight(1.2f * uiScale);
  rect(tblX, tblY, tblW, hdrH, 5 * uiScale, 5 * uiScale, 0, 0);

  float cx = tblX;
  for (int c = 0; c < colHeaders.length; c++) {
    float cw = tblW * colWeights[c];
    fill(colAccent);
    textAlign(CENTER, CENTER);
    textSize(10.5f * uiScale);
    text(colHeaders[c], cx + cw * 0.5f, tblY + hdrH * 0.5f);
    if (c > 0) {
      stroke(colBorder);
      line(cx, tblY, cx, tblY + hdrH + NUM_READINGS * rowH);
    }
    cx += cw;
  }

  for (int r = 0; r < NUM_READINGS; r++) {
    float ry = tblY + hdrH + r * rowH;
    boolean isSel = (r == selectedReading);
    fill(isSel ? color(36, 68, 105) : (r % 2 == 0 ? colPanelLite : color(24, 36, 56)));
    stroke(isSel ? colAccent2 : colBorder);
    strokeWeight(isSel ? 1.8f * uiScale : 1.0f * uiScale);
    rect(tblX, ry, tblW, rowH);

    String[] cells = {
      "R" + (r + 1) + (r == 2 ? "*" : ""),
      nf(H1_vals[r], 1, 2),
      nf(H2_vals[r], 1, 2),
      nf(sqrtH1_vals[r], 1, 3),
      nf(sqrtH2_vals[r], 1, 3),
      nf(timeT_vals[r], 1, 1),
      nf(dSqrtH_vals[r], 1, 4),
      nf(cd_vals[r], 1, 3)
    };

    float cellX = tblX;
    for (int c = 0; c < cells.length; c++) {
      float cw = tblW * colWeights[c];
      fill(isSel ? (c == 7 || c == 0 ? colAccent2 : color(255)) : (c == 7 ? colGreen : colTextMain));
      textAlign(CENTER, CENTER);
      textSize(11.5f * uiScale);
      text(cells[c], cellX + cw * 0.5f, ry + rowH * 0.5f);
      cellX += cw;
    }
  }

  float resY = tblY + hdrH + NUM_READINGS * rowH + 14 * uiScale;
  float resH = y0 + totalH - resY - 12 * uiScale;
  fill(16, 42, 66);
  stroke(colGreen);
  strokeWeight(1.8f * uiScale);
  rect(tblX, resY, tblW, resH, 8 * uiScale);

  fill(colGreen);
  textAlign(LEFT, CENTER);
  textSize(12.5f * uiScale);
  text("FINAL LAB RESULT (VARIABLE HEAD METHOD):", tblX + 14 * uiScale, resY + resH * 0.30f);

  fill(255);
  textSize(13.2f * uiScale);
  text("Coefficient of Discharge of External Mouthpiece:   Cd = 0.695   (Arithmetic Mean = " + nf(getMeanCd(), 1, 3) + ")",
       tblX + 14 * uiScale, resY + resH * 0.70f);

  // RIGHT PANEL: Lab-Record Millimeter Graph Sheet (X: 0..0.085, Y: 0..44)
  drawAutoScaledGraph(rightX, y0, rightW, totalH);
}

void drawAutoScaledGraph(float gx, float gy, float gw, float gh) {
  fill(colPanel);
  stroke(colBorder);
  strokeWeight(1.5f * uiScale);
  rect(gx, gy, gw, gh, 10 * uiScale);

  fill(colAccent2);
  textAlign(LEFT, CENTER);
  textSize(12.6f * uiScale);
  text("GRAPH: sqrt(H1) - sqrt(H2) (X) vs. TIME T (Y)", gx + 14 * uiScale, gy + 20 * uiScale);

  float pL = gx + 50 * uiScale;
  float pR = gx + gw - 16 * uiScale;
  float pT = gy + 40 * uiScale;
  float pB = gy + gh - 74 * uiScale;
  float pW = pR - pL;
  float pH = pB - pT;

  // Authentic warm millimeter engineering graph paper background
  fill(248, 237, 237);
  stroke(155, 85, 85);
  strokeWeight(1.6f * uiScale);
  rect(pL, pT, pW, pH);

  // Lab Record Full Origin Scale:
  // X-Axis: 0.000 to 0.085 (1 cm = 0.005 -> 17 major divisions)
  // Y-Axis: 0 to 44 sec     (1 cm = 2 sec -> 22 major divisions)
  float xMin = 0.0f;
  float xMax = 0.085f;
  float yMin = 0.0f;
  float yMax = 44.0f;

  // Draw X-axis major (0.005) and minor (0.001) millimeter gridlines
  int xMajDivs = 17;
  for (int i = 0; i <= xMajDivs * 5; i++) {
    float fx = i / float(xMajDivs * 5);
    float xx = pL + fx * pW;
    boolean isMajor = (i % 5 == 0);
    stroke(isMajor ? color(210, 145, 145) : color(236, 198, 198));
    strokeWeight(isMajor ? 1.05f * uiScale : 0.55f * uiScale);
    line(xx, pT, xx, pB);

    if (isMajor) {
      int majIdx = i / 5;
      float val = majIdx * 0.005f;
      if (majIdx == 0) {
        fill(colTextDim);
        textAlign(RIGHT, TOP);
        textSize(8.8f * uiScale);
        text("0", pL - 2 * uiScale, pB + 3 * uiScale);
      } else if (majIdx % 2 == 0 || majIdx == 17) {
        fill(colTextDim);
        textAlign(CENTER, TOP);
        textSize(8.4f * uiScale);
        text(nf(val, 1, 3), xx, pB + 4 * uiScale);
      }
    }
  }

  // Draw Y-axis major (2 sec) and minor (0.4 sec) millimeter gridlines
  int yMajDivs = 22;
  for (int j = 0; j <= yMajDivs * 5; j++) {
    float fy = j / float(yMajDivs * 5);
    float yy = pB - fy * pH;
    boolean isMajor = (j % 5 == 0);
    stroke(isMajor ? color(210, 145, 145) : color(236, 198, 198));
    strokeWeight(isMajor ? 1.05f * uiScale : 0.55f * uiScale);
    line(pL, yy, pR, yy);

    if (isMajor) {
      int majIdx = j / 5;
      int tVal = majIdx * 2;
      if (majIdx > 0 && majIdx % 2 == 0) {
        fill(colTextDim);
        textAlign(RIGHT, CENTER);
        textSize(8.6f * uiScale);
        text(str(tVal), pL - 5 * uiScale, yy);
      }
    }
  }

  // Bold Origin Axes Lines
  stroke(125, 55, 55);
  strokeWeight(1.6f * uiScale);
  line(pL, pB, pR, pB);
  line(pL, pT, pL, pB);

  // Top-Right Scale Legend Box inside Graph Paper (matching record sheet)
  float scBoxW = 148 * uiScale;
  float scBoxH = 38 * uiScale;
  float scBoxX = pR - scBoxW - 6 * uiScale;
  float scBoxY = pT + 6 * uiScale;
  fill(252, 245, 245, 235);
  stroke(170, 105, 105);
  strokeWeight(1.0f * uiScale);
  rect(scBoxX, scBoxY, scBoxW, scBoxH, 3 * uiScale);

  fill(45, 25, 25);
  textAlign(LEFT, TOP);
  textSize(8.5f * uiScale);
  text("Scale:", scBoxX + 6 * uiScale, scBoxY + 3 * uiScale);
  text("X-axis: 1 cm = 0.005", scBoxX + 6 * uiScale, scBoxY + 14 * uiScale);
  text("Y-axis: 1 cm = 2 sec", scBoxX + 6 * uiScale, scBoxY + 25 * uiScale);

  // Axis Titles
  fill(colTextMain);
  textAlign(CENTER, TOP);
  textSize(10.5f * uiScale);
  text("sqrt(H1) - sqrt(H2)   X-Axis", (pL + pR) * 0.5f, pB + 17 * uiScale);

  pushMatrix();
  translate(gx + 14 * uiScale, (pT + pB) * 0.5f);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text("Time taken (sec)   Y-Axis", 0, 0);
  popMatrix();

  // Map data coordinates to screen pixels
  // Red lower tangent extension tail (from x = 0.0505, y = 7.8 to R1 = 0.0600, 11.0)
  float redX1 = pL + (0.0505f / xMax) * pW;
  float redY1 = pB - (7.8f    / yMax) * pH;
  float redX2 = pL + (0.0600f / xMax) * pW;
  float redY2 = pB - (11.0f   / yMax) * pH;

  if (graphAnim > 0.0f) {
    float redT = constrain(graphAnim * 2.5f, 0.0f, 1.0f);
    stroke(205, 55, 65);
    strokeWeight(1.8f * uiScale);
    line(redX1, redY1, lerp(redX1, redX2, redT), lerp(redY1, redY2, redT));
  }

  // Small smooth curve going directly through ALL 5 plotted points (R1..R5)
  float[] curveXData = { 0.0582f, 0.0600f, 0.0616f, 0.0640f, 0.0675f, 0.0710f, 0.0745f };
  float[] curveYData = { 10.2f,   11.0f,   11.6f,   11.7f,   15.1f,   18.9f,   21.6f   };

  int totalCurvePts = curveXData.length;
  int visiblePts = max(2, ceil(totalCurvePts * graphAnim));

  noFill();
  stroke(48, 52, 62);
  strokeWeight(2.2f * uiScale);
  beginShape();
  for (int i = 0; i < visiblePts; i++) {
    float sx = pL + (curveXData[i] / xMax) * pW;
    float sy = pB - (curveYData[i] / yMax) * pH;
    if (i == 0) {
      curveVertex(sx, sy);
    }
    curveVertex(sx, sy);
    if (i == visiblePts - 1) {
      curveVertex(sx, sy);
    }
  }
  endShape();

  // Angled "sqrt(h) Vs Time" label along the small curve (matching record sheet)
  if (graphAnim > 0.6f) {
    float lblX = pL + (0.0615f / xMax) * pW;
    float lblY = pB - (13.8f   / yMax) * pH;
    pushMatrix();
    translate(lblX, lblY);
    rotate(-0.68f);
    fill(55, 45, 50);
    textAlign(LEFT, CENTER);
    textSize(9.5f * uiScale);
    text("sqrt(h) Vs Time", 0, 0);
    popMatrix();
  }

  // Plot all 5 circled points R1..R5 on the curve
  for (int i = 0; i < NUM_READINGS; i++) {
    float px = pL + (dSqrtH_vals[i] / xMax) * pW;
    float py = pB - (timeT_vals[i]  / yMax) * pH;
    boolean isSel = (i == selectedReading);

    if (isSel) {
      stroke(0, 125, 185, 190);
      strokeWeight(1.3f * uiScale);
      drawDashedLine(px, py, px, pB, 4 * uiScale);
      drawDashedLine(pL, py, px, py, 4 * uiScale);
    }

    // Outer pencil-style circle ring around each plotted point
    noFill();
    stroke(isSel ? color(230, 120, 0) : color(55, 60, 72));
    strokeWeight(1.4f * uiScale);
    ellipse(px, py, (isSel ? 14 : 10) * uiScale, (isSel ? 14 : 10) * uiScale);

    // Center point dot
    fill(isSel ? color(255, 150, 0) : color(35, 40, 52));
    noStroke();
    ellipse(px, py, (isSel ? 6 : 4) * uiScale, (isSel ? 6 : 4) * uiScale);

    if (isSel) {
      fill(20, 30, 48);
      textAlign(LEFT, TOP);
      textSize(9.5f * uiScale);
      text("R" + (i + 1) + " (" + nf(dSqrtH_vals[i], 1, 4) + ", " + nf(timeT_vals[i], 1, 1) + "s)",
           px + 7 * uiScale, py + 2 * uiScale);
    }
  }

  // Bottom Result Strip inside Graph Card
  float sbY = pB + 35 * uiScale;
  float sbH = gy + gh - sbY - 8 * uiScale;
  fill(18, 28, 46);
  stroke(colAccent2);
  strokeWeight(1.2f * uiScale);
  rect(pL, sbY, pW, sbH, 6 * uiScale);

  fill(colAccent2);
  textAlign(CENTER, CENTER);
  textSize(10.5f * uiScale);
  text("Smooth Curve Through R1-R5 (0.060..0.071, 11.0s..18.9s)   |   Record Cd = 0.695",
       pL + pW * 0.5f, sbY + sbH * 0.5f);
}

// ============================================================================
// SHARED 2D DRAWING HELPERS
// ============================================================================
void draw2DArrow(float x1, float y1, float x2, float y2, color c) {
  stroke(c);
  strokeWeight(2.2f * uiScale);
  line(x1, y1, x2, y2);
  float ang = atan2(y2 - y1, x2 - x1);
  float head = 7.0f * uiScale;
  fill(c);
  noStroke();
  triangle(x2, y2,
           x2 - cos(ang - 0.45f) * head, y2 - sin(ang - 0.45f) * head,
           x2 - cos(ang + 0.45f) * head, y2 - sin(ang + 0.45f) * head);
}

void drawDashedLine(float x1, float y1, float x2, float y2, float dashLen) {
  float d = dist(x1, y1, x2, y2);
  int steps = max(int(d / dashLen), 1);
  for (int i = 0; i < steps; i += 2) {
    float t1 = i / float(steps);
    float t2 = min((i + 1) / float(steps), 1.0f);
    line(lerp(x1, x2, t1), lerp(y1, y2, t1), lerp(x1, x2, t2), lerp(y1, y2, t2));
  }
}

boolean overRect(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

// ============================================================================
// TOUCH & MOUSE INTERACTION HANDLERS (1:1 HIT-TESTING ACROSS ALL 6 SCREENS)
// ============================================================================
void mousePressed() {
  lastMouseX = mouseX;
  lastMouseY = mouseY;

  // 1. Title Badge -> Jump to Screen 1
  float badgeW = 215.0f * uiScale;
  if (overRect(8 * uiScale, 6 * uiScale, badgeW, topBarH - 12 * uiScale)) {
    currentScreen = 0;
    return;
  }

  // 2. Top Navigation Tabs
  float tabAreaX = badgeW + 18 * uiScale;
  float tabAreaW = width - tabAreaX - 10 * uiScale;
  float tabW = (tabAreaW - 5 * 6 * uiScale) / 6.0f;
  float tabH = topBarH - 12 * uiScale;
  for (int i = 0; i < 6; i++) {
    float tx = tabAreaX + i * (tabW + 6 * uiScale);
    if (overRect(tx, 6 * uiScale, tabW, tabH)) {
      currentScreen = i;
      if (i == 5) graphAnim = 0.0f;
      return;
    }
  }

  // 3. Bottom Navigation Buttons (< PREV SCREEN / Reading Pill / NEXT SCREEN >)
  float y0Bot = height - botBarH;
  float btnW = 165.0f * uiScale;
  float btnH = botBarH - 10 * uiScale;
  float btnY = y0Bot + 5 * uiScale;
  if (overRect(12 * uiScale, btnY, btnW, btnH) && currentScreen > 0) {
    currentScreen--;
    if (currentScreen == 5) graphAnim = 0.0f;
    return;
  }
  if (overRect(width - btnW - 12 * uiScale, btnY, btnW, btnH) && currentScreen < 5) {
    currentScreen++;
    if (currentScreen == 5) graphAnim = 0.0f;
    return;
  }
  float pillW = width - 2 * btnW - 48 * uiScale;
  float pillX = btnW + 24 * uiScale;
  if (overRect(pillX, btnY, pillW, btnH)) {
    selectReading((selectedReading + 1) % NUM_READINGS);
    return;
  }

  // 4. Screen-Specific Hit-Testing
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
    if (draggingSliderH) {
      updateSliderHFromMouse();
    } else if (dragging3D) {
      rotY += (mouseX - lastMouseX) * 0.008f;
      rotX = constrain(rotX + (mouseY - lastMouseY) * 0.008f, -1.15f, 0.35f);
    }
  }
  lastMouseX = mouseX;
  lastMouseY = mouseY;
}

void mouseReleased() {
  draggingSliderH = false;
  dragging3D = false;
}

void handleScreen1Press() {
  float ctrlX = 12 * uiScale;
  float ctrlY = topBarH + 12 * uiScale;
  float ctrlW = 300 * uiScale;

  // Reading buttons R1..R5
  float rBtnW = (ctrlW - 20 * uiScale - 4 * 6 * uiScale) / 5.0f;
  for (int i = 0; i < NUM_READINGS; i++) {
    float bx = ctrlX + 10 * uiScale + i * (rBtnW + 6 * uiScale);
    if (overRect(bx, ctrlY + 29 * uiScale, rBtnW, 30 * uiScale)) {
      selectReading(i);
      return;
    }
  }

  // Camera buttons Row 1: Orbit, Zoom+, Zoom-
  float camY = ctrlY + 76 * uiScale;
  float bW3 = (ctrlW - 28 * uiScale) / 3.0f;
  float bH3 = 28 * uiScale;
  if (overRect(ctrlX + 10 * uiScale, camY + 10 * uiScale, bW3, bH3)) {
    autoOrbit = !autoOrbit;
    return;
  }
  if (overRect(ctrlX + 14 * uiScale + bW3, camY + 10 * uiScale, bW3, bH3)) {
    zoom3D = constrain(zoom3D + 0.12f, 0.65f, 1.55f);
    return;
  }
  if (overRect(ctrlX + 18 * uiScale + 2 * bW3, camY + 10 * uiScale, bW3, bH3)) {
    zoom3D = constrain(zoom3D - 0.12f, 0.65f, 1.55f);
    return;
  }

  // Camera buttons Row 2: Fall AUTO/HOLD, Labels ON/OFF, Reset View
  float row2Y = camY + 44 * uiScale;
  if (overRect(ctrlX + 10 * uiScale, row2Y, bW3, bH3)) {
    autoFallSim = !autoFallSim;
    return;
  }
  if (overRect(ctrlX + 14 * uiScale + bW3, row2Y, bW3, bH3)) {
    show3DLabels = !show3DLabels;
    return;
  }
  if (overRect(ctrlX + 18 * uiScale + 2 * bW3, row2Y, bW3, bH3)) {
    rotX = -0.24f;
    rotY = -0.52f;
    zoom3D = 1.0f;
    autoOrbit = true;
    autoFallSim = true;
    return;
  }

  // Head H slider hit area
  if (overRect(ctrlX, camY + 80 * uiScale, ctrlW, 48 * uiScale)) {
    draggingSliderH = true;
    autoFallSim = false;
    updateSliderHFromMouse();
    return;
  }

  // Start 3D orbit drag inside central 3D frame
  dragging3D = true;
}

void updateSliderHFromMouse() {
  int r = selectedReading;
  float ctrlX = 12 * uiScale;
  float ctrlW = 300 * uiScale;
  float slX = ctrlX + 12 * uiScale;
  float slW = ctrlW - 24 * uiScale;
  float norm = constrain((mouseX - slX) / slW, 0.0f, 1.0f);
  currentHeadH = lerp(H2_vals[r], H1_vals[r], norm);
}

void handleScreen2Press() {
  float pad = 14 * uiScale;
  float x0 = pad;
  float y0 = topBarH + pad;
  float w = width - 2 * pad;
  float h = height - topBarH - botBarH - 2 * pad;

  float btnW = 148 * uiScale;
  float btnH = 28 * uiScale;
  float btnY = y0 + 7 * uiScale;
  if (overRect(x0 + w - 2 * btnW - 22 * uiScale, btnY, btnW, btnH)) {
    unsteadyMode = !unsteadyMode;
    return;
  }
  if (overRect(x0 + w - btnW - 12 * uiScale, btnY, btnW, btnH)) {
    streaklinePts.clear();
    for (int i = 0; i < particles2D.size(); i++) {
      particles2D.get(i).respawn(true);
    }
    return;
  }

  float simX = x0 + 14 * uiScale;
  float simY = y0 + 42 * uiScale;
  float simW = w - 28 * uiScale;
  float simH = h - 98 * uiScale;
  if (overRect(simX + simW * 0.11f, simY + simH * 0.18f, simW * 0.48f, simH * 0.68f)) {
    nozzleNormX = (mouseX - simX) / simW;
    nozzleNormY = (mouseY - simY) / simH;
    streaklinePts.clear();
  }
}

void handleScreen3Press() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.56f;
  float leftX = pad;

  float stepListY = y0 + 44 * uiScale;
  float stepH = (totalH - 98 * uiScale) / 7.0f;
  for (int i = 0; i < 7; i++) {
    if (overRect(leftX + 34 * uiScale, stepListY + i * stepH, leftW - 46 * uiScale, stepH)) {
      derivStep = i;
      autoDerive = false;
      return;
    }
  }

  float bY = y0 + totalH - 42 * uiScale;
  float bW = 135 * uiScale;
  float bH = 30 * uiScale;
  if (overRect(leftX + 16 * uiScale, bY, bW, bH)) {
    derivStep = (derivStep + 6) % 7;
    autoDerive = false;
    return;
  }
  if (overRect(leftX + 24 * uiScale + bW, bY, bW, bH)) {
    derivStep = (derivStep + 1) % 7;
    autoDerive = false;
    return;
  }
  if (overRect(leftX + leftW - bW - 16 * uiScale, bY, bW, bH)) {
    autoDerive = !autoDerive;
    lastDerivTick = millis();
  }
}

void handleScreen4Press() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.48f;
  float rightW = (width - 3 * pad) * 0.52f;
  float leftX = pad;
  float rightX = leftX + leftW + pad;

  float listY = y0 + 44 * uiScale;
  float itemH = (totalH - 98 * uiScale) / 6.0f;
  for (int i = 0; i < 6; i++) {
    if (overRect(leftX + 34 * uiScale, listY + i * itemH, leftW - 46 * uiScale, itemH)) {
      procStep = i;
      autoProc = false;
      return;
    }
  }

  float bY = y0 + totalH - 42 * uiScale;
  float bW = 115 * uiScale;
  if (overRect(leftX + 16 * uiScale, bY, bW, 30 * uiScale)) {
    procStep = (procStep + 5) % 6;
    autoProc = false;
    return;
  }
  if (overRect(leftX + 22 * uiScale + bW, bY, bW, 30 * uiScale)) {
    procStep = (procStep + 1) % 6;
    autoProc = false;
    return;
  }
  if (overRect(leftX + leftW - 145 * uiScale - 16 * uiScale, bY, 145 * uiScale, 30 * uiScale)) {
    autoProc = !autoProc;
    lastProcTick = millis();
    return;
  }

  // Stopwatch Start/Pause & Reset buttons on Instrument Card 2
  float cardH = (totalH - pad) * 0.5f;
  float card2Y = y0 + cardH + pad;
  float swBoxX = rightX + 24 * uiScale;
  float swBoxY = card2Y + 40 * uiScale;
  float swBoxW = rightW - 48 * uiScale;
  float swBoxH = cardH - 54 * uiScale;
  float dialR = min(swBoxH * 0.40f, 68 * uiScale);
  float dialCX = swBoxX + dialR + 28 * uiScale;
  float lcdX = dialCX + dialR + 26 * uiScale;
  float lcdW = swBoxX + swBoxW - lcdX - 16 * uiScale;
  float lcdY = swBoxY + 12 * uiScale;
  float lcdH = swBoxH - 54 * uiScale;
  float swBtnY = lcdY + lcdH + 8 * uiScale;
  float swBtnW = (lcdW - 8 * uiScale) * 0.5f;

  if (overRect(lcdX, swBtnY, swBtnW, 24 * uiScale)) {
    autoFallSim = !autoFallSim;
    return;
  }
  if (overRect(lcdX + swBtnW + 8 * uiScale, swBtnY, swBtnW, 24 * uiScale)) {
    fallProgress = 0.0f;
    currentHeadH = H1_vals[selectedReading];
    return;
  }
}

void handleScreen5Press() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float totalH = height - topBarH - botBarH - 2 * pad;
  float leftW = (width - 3 * pad) * 0.53f;
  float rightW = (width - 3 * pad) * 0.47f;
  float leftX = pad;
  float rightX = leftX + leftW + pad;

  // Check BODMAS rows
  float rowStartY = y0 + 38 * uiScale;
  float rowH = (totalH - 86 * uiScale) / 8.0f;
  for (int i = 0; i < 8; i++) {
    if (overRect(leftX + 32 * uiScale, rowStartY + i * rowH, leftW - 44 * uiScale, rowH)) {
      bodmasStep = i;
      autoBodmas = false;
      calcUserOverride = false;
      return;
    }
  }

  float bY = y0 + totalH - 38 * uiScale;
  if (overRect(leftX + 14 * uiScale, bY, 155 * uiScale, 28 * uiScale)) {
    autoBodmas = !autoBodmas;
    calcUserOverride = false;
    lastBodmasTick = millis();
    return;
  }

  // Casio Calculator Full 47-Key Hit-Testing
  float ix = rightX + 12 * uiScale;
  float iw = rightW - 24 * uiScale;
  float lcdY = y0 + 42 * uiScale;
  float lcdH = 54 * uiScale;
  float ctrlY = lcdY + lcdH + 10 * uiScale;
  float ctrlH = 38 * uiScale;
  float pillW = 46 * uiScale;
  float pillH = 20 * uiScale;

  // Top Control Pills (SHIFT, ALPHA, REPLAY, MODE, ON)
  if (overRect(ix + 6 * uiScale, ctrlY + 6 * uiScale, pillW, pillH)) {
    casioShiftMode = !casioShiftMode;
    casioAlphaMode = false;
    return;
  }
  if (overRect(ix + 12 * uiScale + pillW, ctrlY + 6 * uiScale, pillW, pillH)) {
    casioAlphaMode = !casioAlphaMode;
    casioShiftMode = false;
    return;
  }
  if (overRect(ix + iw * 0.5f - 38 * uiScale, ctrlY, 76 * uiScale, ctrlH)) {
    bodmasStep = (bodmasStep + 1) % 8;
    calcUserOverride = false;
    return;
  }
  if (overRect(ix + iw - 2 * pillW - 12 * uiScale, ctrlY + 6 * uiScale, pillW, pillH)) {
    calcUserOverride = false;
    casioShiftMode = false;
    return;
  }
  if (overRect(ix + iw - pillW - 6 * uiScale, ctrlY + 6 * uiScale, pillW, pillH)) {
    calcCustomExpr = "";
    calcCustomAns = "0.";
    calcUserOverride = false;
    casioShiftMode = false;
    return;
  }

  // 22 Scientific Keys
  float sciY = ctrlY + ctrlH + 8 * uiScale;
  String[][] sciRows = {
    { "x^-1", "nCr", "Pol(", "x^3", "ab/c", "d/dx" },
    { "sqrt", "x^2", "^",   "log", "ln",   "(-)"  },
    { "hyp",  "sin", "cos", "tan", "RCL"          },
    { "ENG",  "(",   ")",   ",",   "M+"           }
  };
  float sciRowH = 29 * uiScale;
  for (int rIdx = 0; rIdx < sciRows.length; rIdx++) {
    int cols = sciRows[rIdx].length;
    float gap = 5 * uiScale;
    float kw = (iw - (cols - 1) * gap) / cols;
    float kh = 19 * uiScale;
    float ky = sciY + rIdx * sciRowH + 8 * uiScale;
    for (int cIdx = 0; cIdx < cols; cIdx++) {
      float kx = ix + cIdx * (kw + gap);
      if (overRect(kx, ky, kw, kh)) {
        processCasioKey(sciRows[rIdx][cIdx]);
        return;
      }
    }
  }

  // 20 Numeric/Operator Keys
  float numY = sciY + 4 * sciRowH + 6 * uiScale;
  float guideH = 26 * uiScale;
  float availNumH = (y0 + totalH - guideH - 8 * uiScale) - numY;
  float numRowH = availNumH / 4.0f;

  String[][] numRows = {
    { "7", "8", "9", "DEL", "AC"  },
    { "4", "5", "6", "x",   "/"   },
    { "1", "2", "3", "+",   "-"   },
    { "0", ".", "EXP", "Ans", "=" }
  };

  for (int rIdx = 0; rIdx < 4; rIdx++) {
    float gap = 6 * uiScale;
    float kw = (iw - 4 * gap) / 5.0f;
    float kh = numRowH - 9 * uiScale;
    float ky = numY + rIdx * numRowH + 8 * uiScale;
    for (int cIdx = 0; cIdx < 5; cIdx++) {
      float kx = ix + cIdx * (kw + gap);
      if (overRect(kx, ky, kw, kh)) {
        processCasioKey(numRows[rIdx][cIdx]);
        return;
      }
    }
  }
}

void processCasioKey(String k) {
  autoBodmas = false;
  calcUserOverride = true;

  if (casioShiftMode) {
    casioShiftMode = false;
    if (k.equals("EXP")) {
      calcCustomExpr += "3.1416";
      return;
    } else if (k.equals("sqrt")) {
      float v = evalSimpleExpr(calcCustomExpr);
      calcCustomAns = nf(pow(v, 1.0f / 3.0f), 1, 4);
      return;
    }
  }

  if (k.equals("AC")) {
    calcCustomExpr = "";
    calcCustomAns = "0.";
  } else if (k.equals("DEL")) {
    if (calcCustomExpr.length() > 0) {
      calcCustomExpr = calcCustomExpr.substring(0, calcCustomExpr.length() - 1);
    }
  } else if (k.equals("=")) {
    calcCustomAns = nf(evalSimpleExpr(calcCustomExpr), 1, 4);
  } else if (k.equals("Ans")) {
    calcCustomExpr += nf(cd_vals[selectedReading], 1, 3);
  } else if (k.equals("EXP")) {
    calcCustomExpr += "E";
  } else if (k.equals("sqrt")) {
    float v = evalSimpleExpr(calcCustomExpr);
    calcCustomAns = nf(sqrt(max(v, 0)), 1, 4);
  } else if (k.equals("x^2")) {
    float v = evalSimpleExpr(calcCustomExpr);
    calcCustomAns = nf(v * v, 1, 5);
  } else if (k.equals("x^3")) {
    float v = evalSimpleExpr(calcCustomExpr);
    calcCustomAns = nf(v * v * v, 1, 5);
  } else if (k.equals("x^-1")) {
    float v = evalSimpleExpr(calcCustomExpr);
    calcCustomAns = (v != 0) ? nf(1.0f / v, 1, 5) : "Math ERROR";
  } else if (k.equals("sin")) {
    calcCustomAns = nf(sin(radians(evalSimpleExpr(calcCustomExpr))), 1, 4);
  } else if (k.equals("cos")) {
    calcCustomAns = nf(cos(radians(evalSimpleExpr(calcCustomExpr))), 1, 4);
  } else if (k.equals("tan")) {
    calcCustomAns = nf(tan(radians(evalSimpleExpr(calcCustomExpr))), 1, 4);
  } else if (k.equals("log")) {
    float v = evalSimpleExpr(calcCustomExpr);
    calcCustomAns = (v > 0) ? nf(log(v) / log(10.0f), 1, 4) : "Math ERROR";
  } else if (k.equals("ln")) {
    float v = evalSimpleExpr(calcCustomExpr);
    calcCustomAns = (v > 0) ? nf(log(v), 1, 4) : "Math ERROR";
  } else if (k.equals("(-)")) {
    calcCustomExpr += "-";
  } else if (k.equals("(") || k.equals(")") || k.equals(".")) {
    calcCustomExpr += k;
  } else if (k.length() == 1 && "0123456789+-x/".indexOf(k) >= 0) {
    calcCustomExpr += k;
  } else {
    calcCustomExpr += k;
  }
}

float evalSimpleExpr(String expr) {
  String s = expr.replace("x", "*").replace("(", "").replace(")", "").trim();
  if (s.length() == 0) return 0.0f;
  try {
    int plusIdx = s.lastIndexOf('+');
    if (plusIdx > 0) {
      return evalSimpleExpr(s.substring(0, plusIdx)) + evalSimpleExpr(s.substring(plusIdx + 1));
    }
    int minusIdx = s.lastIndexOf('-');
    if (minusIdx > 0 && s.charAt(minusIdx - 1) != 'E') {
      return evalSimpleExpr(s.substring(0, minusIdx)) - evalSimpleExpr(s.substring(minusIdx + 1));
    }
    int mulIdx = s.lastIndexOf('*');
    if (mulIdx > 0) {
      return evalSimpleExpr(s.substring(0, mulIdx)) * evalSimpleExpr(s.substring(mulIdx + 1));
    }
    int divIdx = s.lastIndexOf('/');
    if (divIdx > 0) {
      float den = evalSimpleExpr(s.substring(divIdx + 1));
      return (den != 0) ? evalSimpleExpr(s.substring(0, divIdx)) / den : 0.0f;
    }
    return Float.parseFloat(s);
  } catch (Exception e) {
    return cd_vals[selectedReading];
  }
}

void handleScreen6Press() {
  float pad = 14 * uiScale;
  float y0 = topBarH + pad;
  float leftW = (width - 3 * pad) * 0.55f;
  float leftX = pad;

  float tblX = leftX + 12 * uiScale;
  float tblY = y0 + 54 * uiScale;
  float tblW = leftW - 24 * uiScale;
  float hdrH = 38 * uiScale;
  float rowH = 44 * uiScale;

  for (int r = 0; r < NUM_READINGS; r++) {
    float ry = tblY + hdrH + r * rowH;
    if (overRect(tblX, ry, tblW, rowH)) {
      selectReading(r);
      return;
    }
  }
}
