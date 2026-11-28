// ============================================================================
// VENTURIMETER COMPLETE 6-SCREEN ANDROID APDE APP (P3D MODE - FULL VERSION)
// Screen 1: 3D Venturimeter Rig & Bernoulli Water Flow Simulation
// Screen 2: Transparent Venturimeter, Particles, Vectors, Stream/Path/Streaklines
// Screen 3: Step-by-Step Bernoulli's Theorem & Discharge Formula Derivation
// Screen 4: Animated "How Readings Are Taken" (Manometer + Collecting Tank)
// Screen 5: BODMAS Arrow Animation & Full 47-Key Casio fx-991MS Calculator
// Screen 6: Side-by-Side Observation Table & Live Qa vs sqrt(H) Graph
// ============================================================================

int currentScreen = 0;   // 0..5 (6 screens navigated via Top Tabs or PREV / NEXT)
int selectedReading = 1; // Default: Reading #2 (Model Calculation in Record)

// Apparatus Constants from Lab Record
final float D1 = 0.025;          // Inlet diameter = 25 mm = 0.025 m
final float D2 = 0.015;          // Throat diameter = 15 mm = 0.015 m
final float G_ACC = 9.81;        // Gravity (m/s^2)
final float TANK_A = 0.09;       // Collecting tank area A = 0.3 * 0.3 = 0.09 m^2
final float RISE_Y = 0.10;       // Water rise y = 10 cm = 0.10 m
final float SP_GRAV_DIFF = 12.6; // (13.6 - 1.0)
final float AVG_CD = 0.938;      // Result Cd from record

float area1, area2, venturiC;

// Lab Observation Table Data (Readings 1 to 5)
int[] rNo      = {1, 2, 3, 4, 5};
float[] h1Arr  = {70.2, 68.3, 68.0, 67.6, 67.2};          // Left limb (mm)
float[] h2Arr  = {25.4, 27.4, 27.2, 27.4, 27.0};          // Right limb (mm)
float[] hArr   = {0.0448, 0.040, 0.041, 0.040, 0.040};    // Diff head h (m Hg)
float[] HArr   = {0.564, 0.504, 0.516, 0.504, 0.504};     // Venturi head H (m H2O)
float[] tArr   = {15.0, 16.0, 15.2, 15.4, 16.0};          // Time for y=0.1m (sec)
float[] QaArr  = {6.000e-4, 5.625e-4, 5.921e-4, 5.844e-4, 5.769e-4}; // Actual Q
float[] QtArr  = {6.338e-4, 5.993e-4, 6.062e-4, 5.992e-4, 5.991e-4}; // Theor Q
float[] CdArr  = {0.946, 0.938, 0.922, 0.975, 0.961};     // Coeff of discharge
float[] sqHArr = {0.757, 0.752, 0.762, 0.772, 0.750};     // sqrt(H) for graph

// 3D Camera & Touch State
float rotX = -0.20;
float rotY = 0.28;
float zoomScale = 1.0;
boolean autoRotate = true;
float prevTouchX, prevTouchY;
boolean isDragging = false;
boolean draggingSlider = false;
float touchRippleAlpha = 0;
float lastTapX = 0, lastTapY = 0;

// Simulation & Animation Timers
float simTime = 0;
float valveOpening = 0.75;
float tankWaterLevel = 0.20;
ArrayList<WaterParticle> particles;

// Screen 2 (Transparent Venturimeter: Particles, Vectors, Stream/Path/Streaklines)
ArrayList<TransparentParticle> transParticles;
ArrayList<PVector> streakParticles; // Holds (u, eta, spawnPhase)
boolean showParticles = true;
boolean showVectors = true;
boolean showStreamlines = true;
boolean showPathlines = true;
boolean showStreaklines = true;
boolean unsteadyWaveMode = false;
float nozzleU = 0.10;    // Streakline dye injector axial position (0..1)
float nozzleEta = -0.35; // Streakline dye injector normalized radial position (-0.85..0.85)
int streakSpawnCounter = 0;

// Screen 3 (Bernoulli Derivation) Animation State
int derivStep = 0;
float derivTimer = 0;
boolean derivAutoPlay = true;

// Screen 4 ("How Readings Are Taken") Animation State
int procStep = 0;
float procTimer = 0;
boolean procAutoPlay = true;

// Screen 5 (BODMAS & Full Casio fx-991MS) Animation State
int bodmasStep = 0;
float bodmasTimer = 0;
boolean bodmasAutoPlay = true;
String customCalcInput = "";
String customCalcOutput = "";
boolean customCalcMode = false;

// Screen 6 (Graph) Animation State
float graphAnimProgress = 0;

// Responsive UI Scale
float uiScale = 1.0;

public void settings() {
  fullScreen(P3D);
}

void setup() {
  orientation(LANDSCAPE);
  area1 = (PI / 4.0) * D1 * D1;
  area2 = (PI / 4.0) * D2 * D2;
  venturiC = (area1 * area2 * sqrt(2.0 * G_ACC)) / sqrt(area1 * area1 - area2 * area2);

  // Initialize Screen 1 3D loop particles
  particles = new ArrayList<WaterParticle>();
  for (int i = 0; i < 150; i++) {
    particles.add(new WaterParticle(random(1.0)));
  }

  // Initialize Screen 2 Transparent Venturi flow particles
  initTransparentFlow();

  selectReading(selectedReading);
  textFont(createFont("SansSerif", 16));
}

void initTransparentFlow() {
  transParticles = new ArrayList<TransparentParticle>();
  float[] etaBands = {-0.75, -0.50, -0.25, 0.0, 0.25, 0.50, 0.75};
  for (int b = 0; b < etaBands.length; b++) {
    for (int k = 0; k < 6; k++) {
      float uStart = (k / 6.0) + (b % 2) * 0.04;
      if (uStart > 1.0) uStart -= 1.0;
      boolean trackTrail = (k == 0 && (b == 1 || b == 3 || b == 5));
      transParticles.add(new TransparentParticle(uStart, etaBands[b], trackTrail));
    }
  }
  streakParticles = new ArrayList<PVector>();
}

void selectReading(int idx) {
  selectedReading = constrain(idx, 0, 4);
  valveOpening = map(HArr[selectedReading], 0.500, 0.570, 0.65, 1.0);
  tankWaterLevel = 0.10;
  graphAnimProgress = 0;
  customCalcMode = false;
}

void draw() {
  uiScale = constrain(min(width / 1280.0, height / 720.0), 0.55, 1.5);

  background(13, 20, 33);
  simTime += 0.03;

  float fillRate = map(valveOpening, 0.2, 1.0, 0.0012, 0.0040);
  tankWaterLevel += fillRate;
  if (tankWaterLevel > 1.0) tankWaterLevel = 0.0;

  if (currentScreen == 0) {
    drawScreen1_3DSimulation();
  } else if (currentScreen == 1) {
    drawScreen2_TransparentVenturiFlow();
  } else if (currentScreen == 2) {
    drawScreen3_BernoulliDerivation();
  } else if (currentScreen == 3) {
    drawScreen4_HowReadingsTaken();
  } else if (currentScreen == 4) {
    drawScreen5_BodmasAndFullCasio();
  } else {
    drawScreen6_TableAndGraphSideBySide();
  }

  beginHUD();
  drawTopNavBar();
  drawBottomNavBar();
  drawTouchFeedback();
  endHUD();
}

// ============================================================================
// HUD PROJECTION HELPERS (ALIGNED 1:1 WITH ANDROID SCREEN PIXELS)
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

void drawTouchFeedback() {
  if (touchRippleAlpha > 0) {
    noFill();
    stroke(100, 220, 255, touchRippleAlpha);
    strokeWeight(2.5);
    float r = map(touchRippleAlpha, 255, 0, 12, 48) * uiScale;
    ellipse(lastTapX, lastTapY, r, r);
    touchRippleAlpha = max(0, touchRippleAlpha - 14);
  }
}

// ============================================================================
// SCREEN 1: 3D VENTURIMETER APPARATUS & BERNOULLI WATER FLOW SIMULATION
// ============================================================================
void drawScreen1_3DSimulation() {
  perspective(PI / 3.2, float(width) / float(height), 10, 5000);
  camera(0, -35, 670 / zoomScale, 0, 10, 0, 0, 1, 0);

  ambientLight(95, 108, 128);
  directionalLight(255, 250, 240, -0.4, 0.7, -0.6);
  directionalLight(85, 175, 255, 0.6, -0.3, 0.5);

  if (autoRotate && !isDragging) {
    rotY = 0.26 * sin(simTime * 0.25);
  }

  pushMatrix();
  translate(0, 22, 0);
  rotateX(rotX);
  rotateY(rotY);

  // Base Bench
  pushMatrix();
  translate(0, 195, 0);
  fill(34, 44, 62);
  stroke(72, 92, 118);
  strokeWeight(1);
  box(780, 18, 280);
  popMatrix();

  drawSumpTank3D();
  drawPumpAndMotor3D();
  drawSuctionPipe3D();
  drawDeliveryPipe3D();
  drawVenturimeter3D();
  drawManometer3D();
  drawCollectingTank3D();
  updateAndDrawWaterParticles();
  draw3DFlowArrows();

  popMatrix();

  beginHUD();
  drawScreen1HUD();
  endHUD();
}

void drawSumpTank3D() {
  pushMatrix();
  translate(210, 115, 0);
  fill(25, 135, 225, 145);
  noStroke();
  pushMatrix();
  translate(0, 18, 0);
  box(250, 105, 170);
  popMatrix();

  fill(65, 190, 255, 185);
  pushMatrix();
  translate(0, -35 + sin(simTime * 2.2) * 1.6, 0);
  box(250, 4, 170);
  popMatrix();

  noFill();
  stroke(130, 200, 255, 190);
  strokeWeight(2);
  box(256, 142, 176);
  popMatrix();
}

void drawSuctionPipe3D() {
  pushMatrix();
  translate(145, 145, 0);
  fill(200, 148, 52);
  noStroke();
  drawCylinder(16, 16, 32, 16);
  popMatrix();

  fill(140, 160, 185);
  pushMatrix();
  translate(145, 112, 0);
  drawCylinder(8, 8, 52, 14);
  popMatrix();

  pushMatrix();
  translate(110, 86, 0);
  rotateZ(HALF_PI);
  drawCylinder(8, 8, 70, 14);
  popMatrix();
}

void drawPumpAndMotor3D() {
  pushMatrix();
  translate(55, 145, 0);
  fill(54, 65, 82);
  box(90, 75, 70);

  pushMatrix();
  translate(22, -48, 0);
  rotateZ(HALF_PI);
  fill(35, 115, 210);
  drawCylinder(22, 22, 46, 20);
  popMatrix();

  pushMatrix();
  translate(-18, -48, 0);
  fill(225, 95, 45);
  sphere(24);
  popMatrix();
  popMatrix();
}

void drawDeliveryPipe3D() {
  fill(140, 160, 185);
  noStroke();
  pushMatrix();
  translate(-75, 97, 0);
  rotateZ(HALF_PI);
  drawCylinder(8, 8, 225, 14);
  popMatrix();

  // Priming valve
  pushMatrix();
  translate(10, 80, 0);
  drawCylinder(5, 5, 24, 12);
  translate(0, -14, 0);
  fill(235, 75, 75);
  box(18, 6, 18);
  popMatrix();

  // Delivery Control Valve
  pushMatrix();
  translate(-75, 97, 0);
  fill(230, 175, 40);
  sphere(14);
  rotateY(valveOpening * HALF_PI);
  fill(235, 65, 65);
  translate(0, -18, 0);
  box(26, 6, 8);
  popMatrix();

  // Vertical riser & top inlet bend
  fill(140, 160, 185);
  pushMatrix();
  translate(-188, -10, 0);
  drawCylinder(8, 8, 214, 14);
  popMatrix();

  pushMatrix();
  translate(-155, -117, 0);
  rotateZ(HALF_PI);
  drawCylinder(8, 8, 66, 14);
  popMatrix();
}

void drawVenturimeter3D() {
  pushMatrix();
  translate(-55, -117, 0);

  // 1. Inlet Section (d1 = 25 mm)
  pushMatrix();
  translate(-55, 0, 0);
  rotateZ(HALF_PI);
  fill(115, 210, 255, 105);
  stroke(185, 238, 255, 190);
  drawCylinder(16, 16, 26, 24);
  popMatrix();

  // 2. Convergent Cone
  pushMatrix();
  translate(-27, 0, 0);
  rotateZ(HALF_PI);
  fill(90, 200, 255, 115);
  drawCylinder(8, 16, 30, 24);
  popMatrix();

  // 3. Cylindrical Throat (d2 = 15 mm)
  pushMatrix();
  translate(-2, 0, 0);
  rotateZ(HALF_PI);
  fill(255, 195, 65, 130);
  drawCylinder(8, 8, 20, 24);
  popMatrix();

  // 4. Divergent Cone
  pushMatrix();
  translate(38, 0, 0);
  rotateZ(HALF_PI);
  fill(90, 200, 255, 115);
  drawCylinder(16, 8, 60, 24);
  popMatrix();

  // Pressure tapping nipples
  noStroke();
  fill(235, 190, 65);
  pushMatrix();
  translate(-52, 18, 0);
  drawCylinder(3, 3, 14, 10);
  popMatrix();
  pushMatrix();
  translate(-2, 12, 0);
  drawCylinder(3, 3, 22, 10);
  popMatrix();

  popMatrix();
}

void drawManometer3D() {
  float hDiffPx = map(HArr[selectedReading], 0.45, 0.60, 16, 34) * valveOpening;

  pushMatrix();
  translate(-82, -25, 12);

  fill(245, 248, 252);
  stroke(80, 100, 125);
  box(74, 118, 6);

  stroke(40, 50, 70);
  for (int y = -45; y <= 45; y += 9) {
    line(-10, y, 4, 10, y, 4);
  }

  noFill();
  stroke(100, 210, 255, 180);
  strokeWeight(3);
  bezier(-25, -74, -25, -55, -18, -55, -18, -45);
  bezier(25, -80, 25, -55, 18, -55, 18, -45);

  noStroke();
  fill(210, 240, 255, 95);
  pushMatrix();
  translate(-18, -5, 6);
  drawCylinder(4.5, 4.5, 80, 12);
  popMatrix();
  pushMatrix();
  translate(18, -5, 6);
  drawCylinder(4.5, 4.5, 80, 12);
  popMatrix();

  float leftTopY = 5 + hDiffPx * 0.5;
  float rightTopY = 5 - hDiffPx * 0.5;
  fill(215, 222, 232);

  float leftH = 35 - leftTopY;
  pushMatrix();
  translate(-18, leftTopY + leftH * 0.5, 6);
  drawCylinder(3.5, 3.5, max(6, leftH), 12);
  popMatrix();

  float rightH = 35 - rightTopY;
  pushMatrix();
  translate(18, rightTopY + rightH * 0.5, 6);
  drawCylinder(3.5, 3.5, max(6, rightH), 12);
  popMatrix();

  pushMatrix();
  translate(0, 35, 6);
  rotateZ(HALF_PI);
  drawCylinder(3.5, 3.5, 36, 12);
  popMatrix();

  drawArrow3D(new PVector(-28, leftTopY, 8), new PVector(-28, rightTopY, 8), color(255, 80, 90));
  popMatrix();
}

void drawCollectingTank3D() {
  fill(140, 160, 185);
  noStroke();
  pushMatrix();
  translate(85, -117, 0);
  rotateZ(HALF_PI);
  drawCylinder(8, 8, 165, 14);
  popMatrix();

  pushMatrix();
  translate(45, -117, 0);
  fill(230, 175, 40);
  sphere(12);
  popMatrix();

  pushMatrix();
  translate(168, -92, 0);
  drawCylinder(8, 8, 50, 14);
  popMatrix();

  pushMatrix();
  translate(225, -22, 0);

  float waterH = 92 * constrain(tankWaterLevel, 0.08, 0.95);
  fill(35, 175, 245, 165);
  pushMatrix();
  translate(0, 50 - waterH * 0.5, 0);
  box(134, waterH, 114);
  popMatrix();

  noFill();
  stroke(160, 225, 255, 210);
  strokeWeight(2);
  box(140, 104, 120);

  noStroke();
  fill(245, 248, 255);
  pushMatrix();
  translate(-76, 0, 35);
  box(8, 96, 4);
  fill(35, 185, 255);
  translate(-4, 48 - waterH * 0.5, 0);
  drawCylinder(2.5, 2.5, waterH, 10);
  popMatrix();

  fill(220, 75, 65);
  pushMatrix();
  translate(-25, 58, 0);
  drawCylinder(7, 7, 18, 12);
  popMatrix();

  popMatrix();
}

class WaterParticle {
  float t, offsetR, offsetZ;

  WaterParticle(float startT) {
    t = startT;
    offsetR = random(-4, 4);
    offsetZ = random(-4, 4);
  }

  void update(float speedScale) {
    float localMult = (t > 0.43 && t < 0.55) ? 2.78 : 1.0;
    t += 0.0045 * speedScale * localMult;
    if (t >= 1.0) t -= 1.0;
  }

  PVector getPos() {
    if (t < 0.12) {
      float u = t / 0.12;
      return new PVector(145 + offsetR * 0.6, lerp(145, 86, u), offsetZ * 0.6);
    } else if (t < 0.20) {
      float u = (t - 0.12) / 0.08;
      return new PVector(lerp(145, 55, u), 86 + offsetR * 0.6, offsetZ * 0.6);
    } else if (t < 0.34) {
      float u = (t - 0.20) / 0.14;
      return new PVector(lerp(35, -188, u), 97 + offsetR * 0.6, offsetZ * 0.6);
    } else if (t < 0.43) {
      float u = (t - 0.34) / 0.09;
      return new PVector(-188 + offsetR * 0.6, lerp(97, -117, u), offsetZ * 0.6);
    } else if (t < 0.58) {
      float u = (t - 0.43) / 0.15;
      float constrict = (u > 0.25 && u < 0.55) ? 0.35 : 0.7;
      return new PVector(lerp(-188, 168, u), -117 + offsetR * constrict, offsetZ * constrict);
    } else if (t < 0.68) {
      float u = (t - 0.58) / 0.10;
      return new PVector(168 + sin(u * PI) * 8 + offsetR, lerp(-117, -10, u), offsetZ);
    } else {
      float u = (t - 0.68) / 0.32;
      return new PVector(lerp(225, 160, u) + offsetR * 4, lerp(10, 145, u), offsetZ * 4);
    }
  }
}

void updateAndDrawWaterParticles() {
  noStroke();
  for (WaterParticle p : particles) {
    p.update(valveOpening * 1.3);
    PVector pos = p.getPos();
    pushMatrix();
    translate(pos.x, pos.y, pos.z);
    if (p.t > 0.45 && p.t < 0.52) {
      fill(255, 225, 75);
      sphere(3.6);
    } else {
      fill(60, 215, 255);
      sphere(3.0);
    }
    popMatrix();
  }
}

void draw3DFlowArrows() {
  float pulse = sin(simTime * 3.0) * 6.0;
  drawArrow3D(new PVector(165, 135, 18), new PVector(165, 95 + pulse * 0.3, 18), color(80, 240, 160));
  drawArrow3D(new PVector(-15, 118, 18), new PVector(-125 - pulse, 118, 18), color(80, 220, 255));
  drawArrow3D(new PVector(-110, -142, 0), new PVector(-15 + pulse, -142, 0), color(255, 210, 65));
  drawArrow3D(new PVector(85, -142, 0), new PVector(155 + pulse * 0.5, -142, 0), color(80, 220, 255));
}

void drawScreen1HUD() {
  float pad = 14 * uiScale;
  float topY = 64 * uiScale;

  // Left Live Telemetry Card
  fill(18, 28, 46, 225);
  stroke(65, 120, 185);
  strokeWeight(1.5);
  rect(pad, topY, 315 * uiScale, 245 * uiScale, 12);

  fill(110, 215, 255);
  textAlign(LEFT, TOP);
  textSize(14 * uiScale);
  text("3D VENTURIMETER LIVE TELEMETRY", pad + 14 * uiScale, topY + 12 * uiScale);

  fill(235, 242, 250);
  textSize(12.5 * uiScale);
  float lh = 21 * uiScale;
  float y0 = topY + 38 * uiScale;
  text("Active Reading: #" + rNo[selectedReading] + (selectedReading == 1 ? " (Model)" : ""), pad + 14 * uiScale, y0);
  text("Inlet d1 = 25 mm | Throat d2 = 15 mm", pad + 14 * uiScale, y0 + lh);
  text("Manometer: h1=" + nf(h1Arr[selectedReading], 1, 1) + " mm, h2=" + nf(h2Arr[selectedReading], 1, 1) + " mm", pad + 14 * uiScale, y0 + lh * 2);
  text("Diff Head h = " + nf(hArr[selectedReading], 1, 4) + " m of Hg", pad + 14 * uiScale, y0 + lh * 3);
  text("Venturi Head H = " + nf(HArr[selectedReading], 1, 3) + " m of H2O", pad + 14 * uiScale, y0 + lh * 4);
  text("Actual Flow Qa = " + nf(QaArr[selectedReading] * 1e4, 1, 3) + " x 10^-4 m3/s", pad + 14 * uiScale, y0 + lh * 5);
  text("Theor. Flow Qt = " + nf(QtArr[selectedReading] * 1e4, 1, 3) + " x 10^-4 m3/s", pad + 14 * uiScale, y0 + lh * 6);
  fill(105, 245, 165);
  text("Coeff. of Discharge Cd = " + nf(CdArr[selectedReading], 1, 3), pad + 14 * uiScale, y0 + lh * 7);

  // Right Controls Card
  float rx = width - 255 * uiScale - pad;
  fill(18, 28, 46, 225);
  stroke(65, 120, 185);
  rect(rx, topY, 255 * uiScale, 250 * uiScale, 12);

  fill(255, 210, 90);
  textSize(13.5 * uiScale);
  text("SELECT READING (R1 - R5):", rx + 14 * uiScale, topY + 12 * uiScale);

  for (int i = 0; i < 5; i++) {
    float bx = rx + 14 * uiScale + i * 46 * uiScale;
    float by = topY + 38 * uiScale;
    float bw = 40 * uiScale;
    float bh = 36 * uiScale;
    fill(i == selectedReading ? color(40, 155, 245) : color(38, 52, 76));
    noStroke();
    rect(bx, by, bw, bh, 8);
    fill(255);
    textAlign(CENTER, CENTER);
    text("R" + (i + 1), bx + bw * 0.5, by + bh * 0.5);
  }

  // Delivery Valve Slider
  textAlign(LEFT, TOP);
  fill(220, 232, 245);
  textSize(12.5 * uiScale);
  text("Delivery Valve Flow: " + int(valveOpening * 100) + "%", rx + 14 * uiScale, topY + 86 * uiScale);
  float sx = rx + 14 * uiScale;
  float sy = topY + 108 * uiScale;
  float sw = 225 * uiScale;
  fill(45, 60, 85);
  rect(sx, sy, sw, 16 * uiScale, 8);
  fill(65, 200, 255);
  rect(sx, sy, sw * valveOpening, 16 * uiScale, 8);
  fill(255);
  ellipse(sx + sw * valveOpening, sy + 8 * uiScale, 20 * uiScale, 20 * uiScale);

  drawButton(rx + 14 * uiScale, topY + 140 * uiScale, 225 * uiScale, 38 * uiScale,
             autoRotate ? "3D Auto-Orbit: ON" : "3D Auto-Orbit: OFF (Drag)",
             autoRotate ? color(38, 150, 115) : color(65, 80, 105));

  drawButton(rx + 14 * uiScale, topY + 190 * uiScale, 108 * uiScale, 38 * uiScale, "Zoom +", color(52, 75, 110));
  drawButton(rx + 131 * uiScale, topY + 190 * uiScale, 108 * uiScale, 38 * uiScale, "Zoom -", color(52, 75, 110));
}

// ============================================================================
// SCREEN 2: TRANSPARENT VENTURIMETER FLUID FLOW, PARTICLES, VECTORS,
//           STREAMLINES, PATHLINES & STREAKLINES
// ============================================================================
float getVenturiHalfRadius(float u, float rInlet) {
  float rThroat = rInlet * (D2 / D1); // 0.60 * rInlet (15mm / 25mm)
  if (u <= 0.18) {
    return rInlet;
  } else if (u <= 0.36) {
    float t = (u - 0.18) / 0.18;
    float s = t * t * (3.0 - 2.0 * t); // Smooth C1 cubic transition
    return lerp(rInlet, rThroat, s);
  } else if (u <= 0.50) {
    return rThroat;
  } else if (u <= 0.88) {
    float t = (u - 0.50) / 0.38;
    float s = t * t * (3.0 - 2.0 * t); // Gradual diffuser cone
    return lerp(rThroat, rInlet, s);
  } else {
    return rInlet;
  }
}

float getVenturiSlopeDRDU(float u, float rInlet) {
  float eps = 0.002;
  float u1 = max(0.0, u - eps);
  float u2 = min(1.0, u + eps);
  return (getVenturiHalfRadius(u2, rInlet) - getVenturiHalfRadius(u1, rInlet)) / (u2 - u1);
}

// Returns true 2D velocity vector (vx, vy) in screen pixels/frame at (u, eta)
PVector getFluidVelocityVector(float u, float eta, float tubeW, float rInlet, float speedMult) {
  float rLocal = getVenturiHalfRadius(u, rInlet);
  // Continuity equation: A1 * v1 = A(x) * v(x) => v(x) = v1 * (R1 / R(x))^2
  float areaRatio = (rInlet * rInlet) / (rLocal * rLocal);
  float vx = 2.2 * speedMult * areaRatio;

  // Radial component follows wall contour: vy = eta * (dR/dx) * vx
  float dRdx = getVenturiSlopeDRDU(u, rInlet) / tubeW;
  float vy = eta * dRdx * vx;

  // In Unsteady Mode, add transverse oscillatory wave component
  if (unsteadyWaveMode) {
    float wave = 0.72 * speedMult * (1.0 - abs(eta) * 0.7) * cos(u * TWO_PI * 2.5 - simTime * 3.8);
    vy += wave;
  }
  return new PVector(vx, vy);
}

class TransparentParticle {
  float u, eta;
  boolean recordPath;
  ArrayList<PVector> trail;

  TransparentParticle(float startU, float startEta, boolean track) {
    u = startU;
    eta = startEta;
    recordPath = track;
    trail = new ArrayList<PVector>();
  }

  void update(float tubeX, float tubeY, float tubeW, float rInlet, float speedMult) {
    PVector vel = getFluidVelocityVector(u, eta, tubeW, rInlet, speedMult);
    float rLocal = getVenturiHalfRadius(u, rInlet);
    float yAbs = eta * rLocal;

    u += vel.x / tubeW;
    yAbs += vel.y;
    float rNext = getVenturiHalfRadius(constrain(u, 0, 1), rInlet);
    eta = constrain(yAbs / rNext, -0.88, 0.88);

    if (u >= 1.0) {
      u -= 1.0;
      trail.clear();
      // Reset to laminar band if steady, or keep wave entry
      if (!unsteadyWaveMode) {
        eta = round(eta * 4.0) / 4.0;
      }
    }

    if (recordPath && showPathlines) {
      float px = tubeX + u * tubeW;
      float py = tubeY + eta * getVenturiHalfRadius(u, rInlet);
      trail.add(new PVector(px, py));
      if (trail.size() > 75) {
        trail.remove(0);
      }
    } else if (!showPathlines && trail.size() > 0) {
      trail.clear();
    }
  }
}

void drawScreen2_TransparentVenturiFlow() {
  beginHUD();

  float pad = 14 * uiScale;
  float topY = 64 * uiScale;
  float availH = height - topY - 62 * uiScale;

  // Main Transparent Venturi Visualization Canvas
  float mainW = width - 2 * pad;
  fill(14, 22, 36, 245);
  stroke(65, 125, 195);
  strokeWeight(1.5);
  rect(pad, topY, mainW, availH, 12);

  // Header & Physics Readout
  fill(110, 220, 255);
  textAlign(LEFT, TOP);
  textSize(14.5 * uiScale);
  text("TRANSPARENT VENTURIMETER: PARTICLES, VELOCITY VECTORS & FLOW LINES", pad + 14 * uiScale, topY + 10 * uiScale);

  // Live Quantitative Velocity & Pressure Comparison
  float v1Real = QaArr[selectedReading] / area1; // ~ 1.14 m/s
  float v2Real = QaArr[selectedReading] / area2; // ~ 3.18 m/s (2.78x faster!)
  fill(225, 238, 252);
  textSize(12 * uiScale);
  text("Reading #" + rNo[selectedReading] +
       "  |  Inlet v1 = " + nf(v1Real, 1, 2) + " m/s (High P1)" +
       "  -->  Throat v2 = " + nf(v2Real, 1, 2) + " m/s (Low P2, 2.78x Speed)" +
       "  |  Head H = " + nf(HArr[selectedReading], 1, 3) + " m H2O",
       pad + 14 * uiScale, topY + 30 * uiScale);

  // Geometry coordinates for the Transparent Venturimeter
  float tubeX = pad + 85 * uiScale;
  float tubeW = mainW - 170 * uiScale;
  float tubeCenterY = topY + availH * 0.56;
  float rInlet = min(84 * uiScale, availH * 0.23);
  float rThroat = rInlet * (D2 / D1);
  float speedMult = map(HArr[selectedReading], 0.500, 0.570, 0.85, 1.25) * valveOpening;

  // 1. Draw Top Bourdon Pressure Gauge & 3 Piezometer Pressure Columns
  drawTransparentGaugeAndPiezometers(tubeX, tubeCenterY, tubeW, rInlet, rThroat, topY + 52 * uiScale);

  // 2. Draw Subtle Interior Fluid Fill inside Transparent Tube
  noStroke();
  fill(24, 95, 165, 58);
  beginShape();
  for (int i = 0; i <= 80; i++) {
    float u = i / 80.0;
    float r = getVenturiHalfRadius(u, rInlet);
    vertex(tubeX + u * tubeW, tubeCenterY - r);
  }
  for (int i = 80; i >= 0; i--) {
    float u = i / 80.0;
    float r = getVenturiHalfRadius(u, rInlet);
    vertex(tubeX + u * tubeW, tubeCenterY + r);
  }
  endShape(CLOSE);

  // 3. Draw Cross-Section Velocity Profile Vectors at Inlet (u=0.09) and Throat (u=0.43)
  if (showVectors) {
    drawVelocityProfileAtSection(tubeX, tubeCenterY, tubeW, rInlet, 0.09, speedMult, "v1 Profile");
    drawVelocityProfileAtSection(tubeX, tubeCenterY, tubeW, rInlet, 0.43, speedMult, "v2 Profile (Max)");
  }

  // 4. STREAMLINES (Instantaneous curves tangent to velocity field)
  if (showStreamlines) {
    float[] streamEtas = {-0.75, -0.50, -0.25, 0.0, 0.25, 0.50, 0.75};
    for (int s = 0; s < streamEtas.length; s++) {
      stroke(55, 215, 255, 165);
      strokeWeight(1.5 * uiScale);
      noFill();
      beginShape();
      float curU = 0.0;
      float curEta = streamEtas[s];
      for (int step = 0; step <= 60; step++) {
        float sx = tubeX + curU * tubeW;
        float sy = tubeCenterY + curEta * getVenturiHalfRadius(curU, rInlet);
        vertex(sx, sy);
        PVector v = getFluidVelocityVector(curU, curEta, tubeW, rInlet, speedMult);
        float du = 1.0 / 60.0;
        float dt = du * tubeW / max(0.5, v.x);
        float yNext = curEta * getVenturiHalfRadius(curU, rInlet) + v.y * dt;
        curU = min(1.0, curU + du);
        curEta = constrain(yNext / getVenturiHalfRadius(curU, rInlet), -0.88, 0.88);
      }
      endShape();
    }
  }

  // 5. STREAKLINES (Locus of all fluid particles that passed through injector nozzle)
  streakSpawnCounter++;
  if (streakSpawnCounter % 2 == 0) {
    streakParticles.add(new PVector(nozzleU, nozzleEta, 0));
  }
  for (int i = streakParticles.size() - 1; i >= 0; i--) {
    PVector sp = streakParticles.get(i);
    PVector v = getFluidVelocityVector(sp.x, sp.y, tubeW, rInlet, speedMult);
    float rCurr = getVenturiHalfRadius(sp.x, rInlet);
    float yCurr = sp.y * rCurr + v.y;
    sp.x += v.x / tubeW;
    if (sp.x >= 1.0) {
      streakParticles.remove(i);
    } else {
      sp.y = constrain(yCurr / getVenturiHalfRadius(sp.x, rInlet), -0.88, 0.88);
    }
  }

  if (showStreaklines) {
    float nx = tubeX + nozzleU * tubeW;
    float ny = tubeCenterY + nozzleEta * getVenturiHalfRadius(nozzleU, rInlet);

    // Draw continuous Streakline locus connecting dye particles
    noFill();
    stroke(255, 90, 210, 235);
    strokeWeight(2.6 * uiScale);
    beginShape();
    vertex(nx, ny);
    for (int i = streakParticles.size() - 1; i >= 0; i--) {
      PVector sp = streakParticles.get(i);
      float sx = tubeX + sp.x * tubeW;
      float sy = tubeCenterY + sp.y * getVenturiHalfRadius(sp.x, rInlet);
      vertex(sx, sy);
    }
    endShape();

    // Draw Streakline dye nodes
    noStroke();
    fill(255, 130, 230);
    for (int i = 0; i < streakParticles.size(); i += 2) {
      PVector sp = streakParticles.get(i);
      ellipse(tubeX + sp.x * tubeW, tubeCenterY + sp.y * getVenturiHalfRadius(sp.x, rInlet), 4.5 * uiScale, 4.5 * uiScale);
    }

    // Draw Injector Nozzle Marker
    fill(255, 65, 195);
    stroke(255);
    strokeWeight(1.5);
    ellipse(nx, ny, 11 * uiScale, 11 * uiScale);
    fill(255, 175, 240);
    textAlign(LEFT, BOTTOM);
    textSize(10.5 * uiScale);
    text("Dye Nozzle (Tap tube to move)", nx + 8 * uiScale, ny - 4 * uiScale);
  }

  // 6. UPDATE & DRAW PARTICLES, PATHLINES & INDIVIDUAL PARTICLE VELOCITY VECTORS
  for (TransparentParticle p : transParticles) {
    p.update(tubeX, tubeCenterY, tubeW, rInlet, speedMult);
    float px = tubeX + p.u * tubeW;
    float py = tubeCenterY + p.eta * getVenturiHalfRadius(p.u, rInlet);

    // Draw Pathline trajectory trail
    if (showPathlines && p.trail.size() > 1) {
      noFill();
      stroke(75, 245, 155, 225);
      strokeWeight(2.3 * uiScale);
      beginShape();
      for (PVector pt : p.trail) {
        vertex(pt.x, pt.y);
      }
      endShape();
    }

    // Compute instantaneous velocity vector for this particle
    PVector vel = getFluidVelocityVector(p.u, p.eta, tubeW, rInlet, speedMult);
    float speedMag = vel.mag();
    float speedNorm = constrain(map(speedMag, 1.8 * speedMult, 6.2 * speedMult, 0.0, 1.0), 0.0, 1.0);
    color vCol = lerpColor(color(70, 210, 255), color(255, 210, 55), speedNorm);
    if (speedNorm > 0.75) {
      vCol = lerpColor(color(255, 210, 55), color(255, 95, 70), (speedNorm - 0.75) * 4.0);
    }

    // Draw individual Particle Velocity Vector arrow
    if (showVectors) {
      float vecScale = 6.2 * uiScale;
      float vxEnd = px + vel.x * vecScale;
      float vyEnd = py + vel.y * vecScale;
      draw2DArrow(px, py, vxEnd, vyEnd, vCol, 2.0 * uiScale);
    }

    // Draw glowing Fluid Particle sphere
    if (showParticles) {
      noStroke();
      fill(vCol, 90);
      ellipse(px, py, 13 * uiScale, 13 * uiScale);
      fill(235, 250, 255);
      ellipse(px, py, 6.5 * uiScale, 6.5 * uiScale);
      if (p.recordPath && showPathlines) {
        stroke(75, 245, 155);
        strokeWeight(1.8);
        noFill();
        ellipse(px, py, 12 * uiScale, 12 * uiScale);
      }
    }
  }

  // 7. Draw Transparent Glass Venturimeter Outer Walls, Specular Highlights & Flanges
  drawTransparentVenturiGlassShell(tubeX, tubeCenterY, tubeW, rInlet, rThroat);

  // 8. Bottom Legend & Interactive Layer Toggle Bar
  drawScreen2ControlsBar(pad + 12 * uiScale, topY + availH - 76 * uiScale, mainW - 24 * uiScale);

  endHUD();
}

void drawTransparentGaugeAndPiezometers(float tubeX, float tubeCenterY, float tubeW, float rInlet, float rThroat, float topBarY) {
  // Three piezometric pressure head columns: Inlet (u=0.10), Throat (u=0.43), Outlet (u=0.92)
  float[] uTap = {0.10, 0.43, 0.92};
  float[] pHeadRatio = {0.92, 0.24, 0.78}; // High P1, Low P2 at throat, Recovered P3
  String[] pLabels = {"P1/pg (High)", "P2/pg (Low)", "P3/pg (Recov)"};
  color[] pColors = {color(70, 200, 255), color(255, 105, 95), color(95, 225, 175)};

  float colMaxH = max(46 * uiScale, (tubeCenterY - rInlet) - topBarY - 10 * uiScale);

  for (int i = 0; i < 3; i++) {
    float tx = tubeX + uTap[i] * tubeW;
    float rWall = getVenturiHalfRadius(uTap[i], rInlet);
    float pipeTopY = tubeCenterY - rWall;
    float colBaseY = tubeCenterY - rInlet - 6 * uiScale;
    float colTopY = colBaseY - colMaxH;

    // Glass piezometer riser tube
    stroke(160, 220, 255, 180);
    strokeWeight(1.5);
    fill(200, 235, 255, 35);
    rect(tx - 6 * uiScale, colTopY, 12 * uiScale, pipeTopY - colTopY, 3);

    // Water column height proportional to static pressure head
    float hPx = colMaxH * pHeadRatio[i] * constrain(valveOpening, 0.4, 1.0);
    noStroke();
    fill(pColors[i], 195);
    rect(tx - 4.5 * uiScale, colBaseY - hPx, 9 * uiScale, (pipeTopY - colBaseY) + hPx);

    // Label
    fill(pColors[i]);
    textAlign(LEFT, CENTER);
    textSize(10.5 * uiScale);
    text(pLabels[i], tx + 10 * uiScale, colBaseY - hPx);
  }

  // Dial Pressure Gauge mounted above Converging Cone (u=0.26)
  float gx = tubeX + 0.26 * tubeW;
  float rTap = getVenturiHalfRadius(0.26, rInlet);
  float gaugeR = 26 * uiScale;
  float gy = tubeCenterY - rTap - 22 * uiScale - gaugeR;

  // Brass stem
  fill(215, 175, 65);
  noStroke();
  rect(gx - 4 * uiScale, gy + gaugeR - 2 * uiScale, 8 * uiScale, 24 * uiScale);

  // Dial bezel & face
  fill(245, 248, 252);
  stroke(130, 150, 175);
  strokeWeight(2.5);
  ellipse(gx, gy, gaugeR * 2, gaugeR * 2);

  // Red danger arc & needle
  noFill();
  stroke(235, 70, 70);
  strokeWeight(2.5);
  arc(gx, gy, gaugeR * 1.5, gaugeR * 1.5, -0.6, 0.5);

  float needleAng = map(HArr[selectedReading] * valveOpening, 0.2, 0.6, -2.3, 0.35);
  stroke(220, 45, 45);
  strokeWeight(2);
  line(gx, gy, gx + cos(needleAng) * gaugeR * 0.72, gy + sin(needleAng) * gaugeR * 0.72);
  fill(40);
  noStroke();
  ellipse(gx, gy, 5 * uiScale, 5 * uiScale);
}

void drawVelocityProfileAtSection(float tubeX, float tubeCenterY, float tubeW, float rInlet, float uSec, float speedMult, String label) {
  float sx = tubeX + uSec * tubeW;
  float rLocal = getVenturiHalfRadius(uSec, rInlet);

  // Dashed reference plane
  stroke(255, 255, 255, 85);
  strokeWeight(1.2);
  for (float y = -rLocal + 4; y < rLocal - 4; y += 8) {
    line(sx, tubeCenterY + y, sx, tubeCenterY + y + 4);
  }

  // Profile arrows across cross-section
  for (int k = -3; k <= 3; k++) {
    float eta = k / 3.5;
    float py = tubeCenterY + eta * rLocal;
    // Slight laminar parabolic profile factor (1 - 0.18 * eta^2)
    PVector vel = getFluidVelocityVector(uSec, eta, tubeW, rInlet, speedMult);
    float len = vel.x * (1.0 - 0.18 * eta * eta) * 6.5 * uiScale;
    color c = (uSec > 0.35 && uSec < 0.52) ? color(255, 215, 75, 210) : color(95, 225, 255, 200);
    draw2DArrow(sx, py, sx + len, py, c, 1.6 * uiScale);
  }

  fill(210, 230, 250);
  textAlign(CENTER, TOP);
  textSize(10.5 * uiScale);
  text(label, sx, tubeCenterY + rLocal + 6 * uiScale);
}

void drawTransparentVenturiGlassShell(float tubeX, float tubeCenterY, float tubeW, float rInlet, float rThroat) {
  // Top & Bottom Glass Wall Contours
  stroke(185, 238, 255, 235);
  strokeWeight(3.0 * uiScale);
  noFill();

  // Top outer wall
  beginShape();
  for (int i = 0; i <= 80; i++) {
    float u = i / 80.0;
    vertex(tubeX + u * tubeW, tubeCenterY - getVenturiHalfRadius(u, rInlet));
  }
  endShape();

  // Bottom outer wall
  beginShape();
  for (int i = 0; i <= 80; i++) {
    float u = i / 80.0;
    vertex(tubeX + u * tubeW, tubeCenterY + getVenturiHalfRadius(u, rInlet));
  }
  endShape();

  // Specular glass reflection highlight line near upper wall
  stroke(255, 255, 255, 110);
  strokeWeight(1.5 * uiScale);
  beginShape();
  for (int i = 2; i <= 78; i++) {
    float u = i / 80.0;
    vertex(tubeX + u * tubeW, tubeCenterY - getVenturiHalfRadius(u, rInlet) * 0.82);
  }
  endShape();

  // Inlet & Outlet Transparent Flanges
  fill(165, 225, 255, 85);
  stroke(195, 242, 255, 220);
  strokeWeight(2);
  rect(tubeX - 10 * uiScale, tubeCenterY - rInlet - 12 * uiScale, 10 * uiScale, (rInlet + 12 * uiScale) * 2, 3);
  rect(tubeX + tubeW, tubeCenterY - rInlet - 12 * uiScale, 10 * uiScale, (rInlet + 12 * uiScale) * 2, 3);

  // Dimension Callouts (d1 = 25 mm, d2 = 15 mm)
  float throatX = tubeX + 0.43 * tubeW;
  stroke(255, 210, 90, 190);
  strokeWeight(1.4);
  line(tubeX + 18 * uiScale, tubeCenterY - rInlet, tubeX + 18 * uiScale, tubeCenterY + rInlet);
  line(throatX, tubeCenterY - rThroat, throatX, tubeCenterY + rThroat);

  fill(255, 220, 110);
  textAlign(LEFT, CENTER);
  textSize(11 * uiScale);
  text("d1 = 25 mm", tubeX + 23 * uiScale, tubeCenterY + rInlet - 14 * uiScale);
  text("d2 = 15 mm (Throat)", throatX + 6 * uiScale, tubeCenterY + rThroat + 14 * uiScale);
}

void drawScreen2ControlsBar(float x, float y, float w) {
  // Legend & Physics Note
  fill(22, 34, 54, 235);
  stroke(60, 105, 165);
  strokeWeight(1);
  rect(x, y, w, 70 * uiScale, 10);

  fill(210, 228, 248);
  textAlign(LEFT, TOP);
  textSize(11 * uiScale);
  String modeNote = unsteadyWaveMode
    ? "UNSTEADY FLOW: Streamlines (Cyan), Pathlines (Green) & Streaklines (Pink) SEPARATE!"
    : "STEADY FLOW: Streamlines (Cyan), Pathlines (Green) & Streaklines (Pink) COINCIDE!";
  text(modeNote, x + 12 * uiScale, y + 6 * uiScale);

  // 7 Interactive Layer Toggle Pills
  String[] labels = {
    showParticles ? "Particles: ON" : "Particles: OFF",
    showVectors ? "Vel Vectors: ON" : "Vel Vectors: OFF",
    showStreamlines ? "Streamlines: ON" : "Streamlines: OFF",
    showPathlines ? "Pathlines: ON" : "Pathlines: OFF",
    showStreaklines ? "Streaklines: ON" : "Streaklines: OFF",
    unsteadyWaveMode ? "Flow: UNSTEADY" : "Flow: STEADY",
    "Reset Trails"
  };

  color[] cols = {
    showParticles ? color(38, 145, 225) : color(52, 65, 88),
    showVectors ? color(215, 150, 35) : color(52, 65, 88),
    showStreamlines ? color(25, 165, 205) : color(52, 65, 88),
    showPathlines ? color(35, 165, 115) : color(52, 65, 88),
    showStreaklines ? color(195, 65, 165) : color(52, 65, 88),
    unsteadyWaveMode ? color(215, 85, 65) : color(45, 135, 105),
    color(70, 88, 118)
  };

  float gap = 8 * uiScale;
  float btnW = (w - 24 * uiScale - gap * 6) / 7.0;
  float btnY = y + 26 * uiScale;
  float btnH = 36 * uiScale;

  for (int i = 0; i < 7; i++) {
    drawButton(x + 12 * uiScale + i * (btnW + gap), btnY, btnW, btnH, labels[i], cols[i]);
  }
}

// ============================================================================
// SCREEN 3: STEP-BY-STEP BERNOULLI'S FORMULA DERIVATION FOR VENTURIMETER
// ============================================================================
void drawScreen3_BernoulliDerivation() {
  beginHUD();

  if (derivAutoPlay) {
    derivTimer += 0.011;
    if (derivTimer >= 1.0) {
      derivTimer = 0;
      derivStep = (derivStep + 1) % 7;
    }
  }

  float pad = 14 * uiScale;
  float topY = 64 * uiScale;
  float availH = height - topY - 62 * uiScale;

  // LEFT HALF (56%): 7-STEP MATHEMATICAL DERIVATION
  float leftW = width * 0.56;
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  strokeWeight(1.5);
  rect(pad, topY, leftW, availH, 12);

  fill(255, 210, 80);
  textAlign(LEFT, TOP);
  textSize(15 * uiScale);
  text("BERNOULLI'S EQUATION -> VENTURIMETER DISCHARGE DERIVATION", pad + 16 * uiScale, topY + 10 * uiScale);

  String[] dTitles = {
    "STEP 1: Apply Bernoulli's Theorem at Inlet (1) & Throat (2)",
    "STEP 2: Horizontal Venturimeter Datum (z1 = z2)",
    "STEP 3: Differential Mercury Manometer Pressure Head (H)",
    "STEP 4: Continuity Equation for Incompressible Fluid",
    "STEP 5: Substitute v1 = (a2 / a1) * v2 into Head Equation",
    "STEP 6: Solve for Throat Velocity (v2) & Theoretical Flow (Qt)",
    "STEP 7: Actual Discharge (Qa) & Coefficient of Discharge (Cd)"
  };

  float HVal = HArr[selectedReading];
  float QtVal = QtArr[selectedReading];
  float QaVal = QaArr[selectedReading];
  float CdVal = CdArr[selectedReading];

  String[] dFormulas = {
    "P1/(p*g) + v1^2/(2g) + z1  =  P2/(p*g) + v2^2/(2g) + z2",
    "Since z1 = z2  ==>  H = (P1 - P2)/(p*g) = (v2^2 - v1^2) / (2g)",
    "H = h * (Sm/Sf - 1) = h * (13.6 - 1) = 12.6 * h  =  " + nf(HVal, 1, 3) + " m H2O",
    "Q = a1 * v1 = a2 * v2   ==>   v1 = (a2 / a1) * v2",
    "H = (v2^2 / 2g) * [1 - (a2/a1)^2] = (v2^2 / 2g) * [(a1^2 - a2^2) / a1^2]",
    "v2 = a1*sqrt(2gH)/sqrt(a1^2-a2^2)  ==>  Qt = a2*v2 = [a1*a2*sqrt(2gH)] / sqrt(a1^2-a2^2)",
    "Qa = Cd * Qt = (A * y) / t   ==>   Cd = Qa / Qt = " + nf(QaVal*1e4,1,3) + " / " + nf(QtVal*1e4,1,3) + " = " + nf(CdVal,1,3)
  };

  float listY = topY + 40 * uiScale;
  float rowH = (availH - 92 * uiScale) / 7.0;

  for (int i = 0; i < 7; i++) {
    float ry = listY + i * rowH;
    boolean act = (i == derivStep);
    fill(act ? color(36, 76, 128) : color(25, 37, 57));
    stroke(act ? color(95, 220, 255) : color(48, 65, 92));
    strokeWeight(act ? 2.0 : 1.0);
    rect(pad + 34 * uiScale, ry, leftW - 48 * uiScale, rowH - 5 * uiScale, 8);

    if (act) {
      float shift = sin(simTime * 5.0) * 5.0 * uiScale;
      draw2DArrow(pad + 6 * uiScale + shift, ry + (rowH - 5 * uiScale) * 0.5,
                  pad + 31 * uiScale + shift, ry + (rowH - 5 * uiScale) * 0.5,
                  color(255, 210, 65), 3.0);
    }

    textAlign(LEFT, TOP);
    fill(act ? color(135, 230, 255) : color(165, 185, 210));
    textSize(11 * uiScale);
    text(dTitles[i], pad + 44 * uiScale, ry + 3 * uiScale);

    fill(act ? color(255, 245, 175) : color(220, 230, 245));
    textSize(12 * uiScale);
    text(dFormulas[i], pad + 44 * uiScale, ry + 19 * uiScale);
  }

  float ctrlY = height - 62 * uiScale - 42 * uiScale;
  drawButton(pad + 16 * uiScale, ctrlY, 120 * uiScale, 34 * uiScale, "< Prev Step", color(55, 78, 115));
  drawButton(pad + 146 * uiScale, ctrlY, 120 * uiScale, 34 * uiScale, "Next Step >", color(40, 145, 230));
  drawButton(pad + 276 * uiScale, ctrlY, 155 * uiScale, 34 * uiScale,
             derivAutoPlay ? "Auto-Derive: ON" : "Auto-Derive: OFF",
             derivAutoPlay ? color(38, 150, 115) : color(75, 85, 105));

  // RIGHT HALF (44%): ANIMATED BERNOULLI ENERGY GRADE LINE & CONTROL VOLUME DIAGRAM
  float rightX = pad + leftW + 14 * uiScale;
  float rightW = width - rightX - pad;
  drawBernoulliEnergyDiagram(rightX, topY, rightW, availH);

  endHUD();
}

void drawBernoulliEnergyDiagram(float x, float y, float w, float h) {
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  strokeWeight(1.5);
  rect(x, y, w, h, 12);

  fill(110, 215, 255);
  textAlign(CENTER, TOP);
  textSize(13.5 * uiScale);
  text("BERNOULLI ENERGY BALANCE (SECTION 1 -> 2)", x + w * 0.5, y + 12 * uiScale);

  float pipeY = y + h * 0.56;
  float datumY = y + h * 0.76;
  float sec1X = x + w * 0.25;
  float sec2X = x + w * 0.68;

  // Datum Line (z1 = z2)
  stroke(140, 160, 185);
  strokeWeight(1.5);
  line(x + 24 * uiScale, datumY, x + w - 24 * uiScale, datumY);
  fill(175, 195, 220);
  textAlign(LEFT, BOTTOM);
  textSize(10.5 * uiScale);
  text("Horizontal Datum Line (z1 = z2)", x + 28 * uiScale, datumY - 3 * uiScale);

  // Venturi Section Outline
  float r1 = 38 * uiScale;
  float r2 = 22 * uiScale;
  fill(35, 115, 195, 95);
  stroke(145, 220, 255);
  strokeWeight(2);
  beginShape();
  vertex(x + 30 * uiScale, pipeY - r1);
  vertex(sec1X + 20 * uiScale, pipeY - r1);
  vertex(sec2X - 15 * uiScale, pipeY - r2);
  vertex(sec2X + 15 * uiScale, pipeY - r2);
  vertex(x + w - 30 * uiScale, pipeY - r1 * 0.88);
  vertex(x + w - 30 * uiScale, pipeY + r1 * 0.88);
  vertex(sec2X + 15 * uiScale, pipeY + r2);
  vertex(sec2X - 15 * uiScale, pipeY + r2);
  vertex(sec1X + 20 * uiScale, pipeY + r1);
  vertex(x + 30 * uiScale, pipeY + r1);
  endShape(CLOSE);

  // Section 1 & Section 2 vertical dashed markers
  stroke(255, 210, 80);
  strokeWeight(1.5);
  line(sec1X, pipeY - r1 - 10 * uiScale, sec1X, datumY);
  line(sec2X, pipeY - r2 - 10 * uiScale, sec2X, datumY);

  // Energy Grade Line (Total Head = Const)
  float eglY = y + 58 * uiScale;
  stroke(255, 95, 95);
  strokeWeight(2.2);
  line(x + 35 * uiScale, eglY, x + w - 35 * uiScale, eglY);
  fill(255, 120, 120);
  textAlign(LEFT, BOTTOM);
  text("Total Energy Line (P/pg + v^2/2g + z = Const)", x + 38 * uiScale, eglY - 3 * uiScale);

  // Piezometric Head Columns at Sec 1 & Sec 2
  float p1Top = eglY + 22 * uiScale; // Small v1^2 / 2g
  float p2Top = eglY + 86 * uiScale; // Large v2^2 / 2g

  // Sec 1 Piezometer
  fill(65, 195, 255, 180);
  noStroke();
  rect(sec1X - 8 * uiScale, p1Top, 16 * uiScale, (pipeY - r1) - p1Top);

  // Sec 2 Piezometer
  fill(65, 195, 255, 180);
  rect(sec2X - 8 * uiScale, p2Top, 16 * uiScale, (pipeY - r2) - p2Top);

  // Differential Head H = (P1 - P2)/pg
  stroke(255, 225, 85);
  strokeWeight(2);
  line(sec1X + 14 * uiScale, p1Top, sec2X - 14 * uiScale, p1Top);
  draw2DArrow(sec2X - 16 * uiScale, p1Top, sec2X - 16 * uiScale, p2Top, color(255, 225, 85), 2.2);
  fill(255, 225, 85);
  textAlign(RIGHT, CENTER);
  textSize(11 * uiScale);
  text("H = (P1-P2)/pg\n= " + nf(HArr[selectedReading], 1, 3) + " m", sec2X - 22 * uiScale, (p1Top + p2Top) * 0.5);

  // Velocity Head Callouts
  fill(120, 245, 185);
  textAlign(LEFT, CENTER);
  text("v1^2/2g", sec1X + 12 * uiScale, (eglY + p1Top) * 0.5);
  text("v2^2/2g\n(7.7x v1^2/2g)", sec2X + 12 * uiScale, (eglY + p2Top) * 0.5);

  // Bottom Active Formula Summary Box
  float boxY = y + h - 88 * uiScale;
  fill(24, 46, 68);
  stroke(85, 215, 165);
  rect(x + 14 * uiScale, boxY, w - 28 * uiScale, 74 * uiScale, 8);

  fill(255, 220, 95);
  textAlign(CENTER, TOP);
  textSize(12 * uiScale);
  text("FINAL DERIVED VENTURIMETER EQUATION:", x + w * 0.5, boxY + 8 * uiScale);
  fill(105, 245, 175);
  textSize(13 * uiScale);
  text("Qa = Cd * [ a1 * a2 * sqrt(2 * g * H) ] / sqrt(a1^2 - a2^2)", x + w * 0.5, boxY + 28 * uiScale);
  fill(225, 238, 252);
  textSize(11.5 * uiScale);
  text("With C = " + nf(venturiC * 1e4, 1, 3) + "x10^-4:   Qt = C * sqrt(H) = " + nf(QtArr[selectedReading] * 1e4, 1, 3) + "x10^-4 m^3/s", x + w * 0.5, boxY + 50 * uiScale);
}

// ============================================================================
// SCREEN 4: ANIMATED STEP-BY-STEP "HOW READINGS ARE TAKEN"
// ============================================================================
void drawScreen4_HowReadingsTaken() {
  beginHUD();

  if (procAutoPlay) {
    procTimer += 0.012;
    if (procTimer >= 1.0) {
      procTimer = 0;
      procStep = (procStep + 1) % 6;
    }
  }

  float pad = 14 * uiScale;
  float topY = 64 * uiScale;
  float availH = height - topY - 62 * uiScale;

  // LEFT HALF: 6-STEP LAB PROCEDURE WITH ANIMATED ARROWS
  float leftW = width * 0.48;
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  strokeWeight(1.5);
  rect(pad, topY, leftW, availH, 12);

  fill(255, 210, 80);
  textAlign(LEFT, TOP);
  textSize(15.5 * uiScale);
  text("HOW READINGS ARE TAKEN (TAP ANY STEP)", pad + 16 * uiScale, topY + 12 * uiScale);

  String[] steps = {
    "STEP 1: Note inlet d1=25mm, throat d2=15mm & tank area A=0.3x0.3=0.09m^2.",
    "STEP 2: Keep delivery valve closed, switch ON motor pump & open valve.",
    "STEP 3: Open outlet valve slightly & remove air bubbles from manometer.",
    "STEP 4: Read mercury levels in Left Limb (h1) & Right Limb (h2) in mm.",
    "STEP 5: Close collecting tank gate valve & start stopwatch at 0 cm mark.",
    "STEP 6: Stop stopwatch at y = 10 cm (0.1 m) rise -> Time t (sec)."
  };

  float stepListY = topY + 46 * uiScale;
  float stepH = (availH - 98 * uiScale) / 6.0;

  for (int i = 0; i < 6; i++) {
    float sy = stepListY + i * stepH;
    boolean isAct = (i == procStep);
    fill(isAct ? color(36, 76, 126) : color(25, 37, 57));
    stroke(isAct ? color(95, 220, 255) : color(48, 65, 92));
    strokeWeight(isAct ? 2.0 : 1.0);
    rect(pad + 34 * uiScale, sy, leftW - 48 * uiScale, stepH - 7 * uiScale, 8);

    if (isAct) {
      float shift = sin(simTime * 5.0) * 5.0 * uiScale;
      draw2DArrow(pad + 6 * uiScale + shift, sy + (stepH - 7 * uiScale) * 0.5,
                  pad + 31 * uiScale + shift, sy + (stepH - 7 * uiScale) * 0.5,
                  color(255, 210, 65), 3.0);
    }

    fill(isAct ? color(255) : color(205, 218, 235));
    textAlign(LEFT, CENTER);
    textSize(12.5 * uiScale);
    text(steps[i], pad + 44 * uiScale, sy + (stepH - 7 * uiScale) * 0.5);
  }

  float ctrlY = height - 62 * uiScale - 42 * uiScale;
  drawButton(pad + 16 * uiScale, ctrlY, 115 * uiScale, 34 * uiScale, "< Prev Step", color(55, 78, 115));
  drawButton(pad + 140 * uiScale, ctrlY, 115 * uiScale, 34 * uiScale, "Next Step >", color(40, 145, 230));
  drawButton(pad + 264 * uiScale, ctrlY, 145 * uiScale, 34 * uiScale,
             procAutoPlay ? "Auto-Demo: ON" : "Auto-Demo: OFF",
             procAutoPlay ? color(38, 150, 115) : color(75, 85, 105));

  // RIGHT HALF: LIVE ZOOMED MEASUREMENT INSTRUMENTS
  float rightX = pad + leftW + 14 * uiScale;
  float rightW = width - rightX - pad;
  float halfRightW = (rightW - 12 * uiScale) * 0.5;

  drawZoomedManometerCard(rightX, topY, halfRightW, availH);
  drawZoomedTankStopwatchCard(rightX + halfRightW + 12 * uiScale, topY, halfRightW, availH);

  endHUD();
}

void drawZoomedManometerCard(float x, float y, float w, float h) {
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  rect(x, y, w, h, 12);

  fill(110, 215, 255);
  textAlign(CENTER, TOP);
  textSize(13.5 * uiScale);
  text("1. MANOMETER (h1, h2)", x + w * 0.5, y + 12 * uiScale);

  float boardW = 140 * uiScale;
  float boardH = h - 135 * uiScale;
  float boardX = x + (w - boardW) * 0.5;
  float boardY = y + 46 * uiScale;

  fill(244, 247, 252);
  stroke(90, 115, 145);
  rect(boardX, boardY, boardW, boardH, 8);

  float scaleTop = boardY + 20 * uiScale;
  float scaleBot = boardY + boardH - 35 * uiScale;
  stroke(50, 65, 85);
  textAlign(CENTER, CENTER);
  textSize(10 * uiScale);
  for (int mm = 0; mm <= 100; mm += 10) {
    float ty = map(mm, 100, 0, scaleTop, scaleBot);
    line(boardX + boardW * 0.5 - 12 * uiScale, ty, boardX + boardW * 0.5 + 12 * uiScale, ty);
    fill(40, 50, 70);
    text(mm, boardX + boardW * 0.5, ty);
  }

  float h1Val = h1Arr[selectedReading];
  float h2Val = h2Arr[selectedReading];
  float y1 = map(h1Val, 100, 0, scaleTop, scaleBot);
  float y2 = map(h2Val, 100, 0, scaleTop, scaleBot);

  float leftTubeX = boardX + 32 * uiScale;
  float rightTubeX = boardX + boardW - 32 * uiScale;

  fill(200, 232, 250);
  noStroke();
  rect(leftTubeX - 8 * uiScale, scaleTop, 16 * uiScale, scaleBot - scaleTop, 6);
  rect(rightTubeX - 8 * uiScale, scaleTop, 16 * uiScale, scaleBot - scaleTop, 6);

  fill(120, 130, 145);
  rect(leftTubeX - 6 * uiScale, y1, 12 * uiScale, scaleBot - y1 + 8 * uiScale);
  rect(rightTubeX - 6 * uiScale, y2, 12 * uiScale, scaleBot - y2 + 8 * uiScale);
  rect(leftTubeX - 6 * uiScale, scaleBot, (rightTubeX - leftTubeX) + 12 * uiScale, 12 * uiScale, 6);

  float pulse = sin(simTime * 4.0) * 4 * uiScale;
  draw2DArrow(boardX - 8 * uiScale + pulse, y1, leftTubeX - 10 * uiScale, y1, color(255, 85, 85), 2.5);
  draw2DArrow(boardX + boardW + 8 * uiScale - pulse, y2, rightTubeX + 10 * uiScale, y2, color(40, 215, 145), 2.5);

  fill(255, 120, 120);
  textAlign(LEFT, BOTTOM);
  textSize(11 * uiScale);
  text("h1=" + nf(h1Val, 1, 1), boardX - 10 * uiScale, y1 - 3 * uiScale);

  fill(105, 245, 175);
  textAlign(RIGHT, BOTTOM);
  text("h2=" + nf(h2Val, 1, 1), boardX + boardW + 10 * uiScale, y2 - 3 * uiScale);

  fill(235, 245, 255);
  textAlign(CENTER, TOP);
  textSize(12 * uiScale);
  float footY = boardY + boardH + 10 * uiScale;
  text("h1=" + nf(h1Val, 1, 1) + "mm | h2=" + nf(h2Val, 1, 1) + "mm", x + w * 0.5, footY);
  fill(255, 215, 85);
  text("h = (h1-h2)/1000 = " + nf(hArr[selectedReading], 1, 4) + " m", x + w * 0.5, footY + 21 * uiScale);
  fill(105, 245, 175);
  text("H = h x 12.6 = " + nf(HArr[selectedReading], 1, 3) + " m H2O", x + w * 0.5, footY + 42 * uiScale);
}

void drawZoomedTankStopwatchCard(float x, float y, float w, float h) {
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  rect(x, y, w, h, 12);

  fill(110, 215, 255);
  textAlign(CENTER, TOP);
  textSize(13.5 * uiScale);
  text("2. TANK & STOPWATCH", x + w * 0.5, y + 12 * uiScale);

  float cycle = (simTime * 0.22) % 1.0;
  float targetT = tArr[selectedReading];
  float currentT = cycle * targetT;
  float currentCm = cycle * 10.0;

  float swW = 165 * uiScale;
  float swH = 42 * uiScale;
  float swX = x + (w - swW) * 0.5;
  float swY = y + 42 * uiScale;
  fill(28, 38, 56);
  stroke(255, 195, 65);
  rect(swX, swY, swW, swH, 8);
  fill(255, 225, 95);
  textAlign(CENTER, CENTER);
  textSize(16 * uiScale);
  text("t = " + nf(currentT, 1, 1) + " / " + nf(targetT, 1, 1) + " s", swX + swW * 0.5, swY + swH * 0.5);

  float tankW = 140 * uiScale;
  float tankH = h - 185 * uiScale;
  float tankX = x + (w - tankW) * 0.5 + 14 * uiScale;
  float tankY = swY + swH + 14 * uiScale;

  float waterPx = tankH * cycle;
  fill(35, 175, 245, 175);
  noStroke();
  rect(tankX, tankY + tankH - waterPx, tankW, waterPx, 0, 0, 8, 8);

  noFill();
  stroke(165, 225, 255);
  strokeWeight(2);
  rect(tankX, tankY, tankW, tankH, 8);

  float pzX = tankX - 24 * uiScale;
  fill(245, 248, 255);
  noStroke();
  rect(pzX, tankY, 14 * uiScale, tankH, 4);
  fill(35, 190, 255);
  rect(pzX + 2 * uiScale, tankY + tankH - waterPx, 10 * uiScale, waterPx);

  float levelY = tankY + tankH - waterPx;
  draw2DArrow(pzX - 24 * uiScale, levelY, pzX - 2 * uiScale, levelY, color(255, 95, 95), 2.5);
  fill(255, 215, 85);
  textAlign(RIGHT, CENTER);
  textSize(11 * uiScale);
  text(nf(currentCm, 1, 1) + "cm", pzX - 26 * uiScale, levelY);

  fill(235, 245, 255);
  textAlign(CENTER, TOP);
  textSize(12 * uiScale);
  float footY = tankY + tankH + 10 * uiScale;
  text("Area A = 0.09 m^2 | Rise y = 0.10 m", x + w * 0.5, footY);
  fill(105, 245, 175);
  text("Qa = (A x y)/t = " + nf(QaArr[selectedReading] * 1e4, 1, 3) + "x10^-4", x + w * 0.5, footY + 21 * uiScale);
}

// ============================================================================
// SCREEN 5: BODMAS ARROW ANIMATION & FULL 47-KEY CASIO FX-991MS CALCULATOR
// ============================================================================
void drawScreen5_BodmasAndFullCasio() {
  beginHUD();

  if (bodmasAutoPlay) {
    bodmasTimer += 0.015;
    if (bodmasTimer >= 1.0) {
      bodmasTimer = 0;
      bodmasStep = (bodmasStep + 1) % 8;
      customCalcMode = false;
    }
  }

  float pad = 14 * uiScale;
  float topY = 64 * uiScale;
  float panelH = height - topY - 62 * uiScale;

  // LEFT PANEL (53%): BODMAS ORDER OF OPERATIONS WITH ANIMATED ARROWS
  float leftW = width * 0.53;
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  strokeWeight(1.5);
  rect(pad, topY, leftW, panelH, 12);

  fill(255, 210, 80);
  textAlign(LEFT, TOP);
  textSize(14.5 * uiScale);
  text("BODMAS FORMULA APPLICATION (TAP ANY FORMULA ROW)", pad + 16 * uiScale, topY + 10 * uiScale);

  String[] letters = {"B", "O", "D", "M", "A", "S"};
  String[] names   = {"Brackets", "Orders/sqrt", "Division", "Multiply", "Addition", "Subtract"};
  int activeBadge = (bodmasStep == 0 || bodmasStep == 1) ? 1 :
                    (bodmasStep == 2 || bodmasStep == 3) ? 0 :
                    (bodmasStep == 4 || bodmasStep == 5) ? 3 : 2;

  for (int i = 0; i < 6; i++) {
    float bx = pad + 16 * uiScale + i * (leftW - 32 * uiScale) / 6.0;
    float by = topY + 38 * uiScale;
    float bw = (leftW - 48 * uiScale) / 6.0;
    float bh = 38 * uiScale;
    boolean isAct = (i == activeBadge);
    fill(isAct ? color(245, 135, 40) : color(36, 48, 72));
    stroke(isAct ? color(255, 230, 120) : color(70, 90, 120));
    rect(bx, by, bw, bh, 8);

    textAlign(CENTER, CENTER);
    fill(255);
    textSize(14 * uiScale);
    text(letters[i], bx + bw * 0.5, by + 12 * uiScale);
    textSize(9 * uiScale);
    fill(220, 232, 245);
    text(names[i], bx + bw * 0.5, by + 27 * uiScale);
  }

  float hVal  = hArr[selectedReading];
  float HVal  = HArr[selectedReading];
  float QtVal = QtArr[selectedReading];
  float QaVal = QaArr[selectedReading];
  float CdVal = CdArr[selectedReading];

  String[] stepTitles = {
    "1. Inlet Area (a1)  [O: Power d1^2 -> M/D: pi/4]",
    "2. Throat Area (a2) [O: Power d2^2 -> M/D: pi/4]",
    "3. Venturi Constant C [B: (a1^2-a2^2) -> O: sqrt -> D]",
    "4. Manometer Head h [B: (h1 - h2) -> D: / 1000]",
    "5. Venturi Head H   [M: h x 12.6]",
    "6. Theor. Discharge Qt [O: sqrt(H) -> M: C x sqrt(H)]",
    "7. Actual Discharge Qa [M: A x y -> D: / t]",
    "8. Coeff. of Discharge Cd [D: Qa / Qt]"
  };

  String[] stepExprs = {
    "a1 = (pi / 4) x (0.025)^2  =  4.908 x 10^-4 m^2",
    "a2 = (pi / 4) x (0.015)^2  =  1.767 x 10^-4 m^2",
    "C = (a1 x a2 x sqrt(2x9.81)) / sqrt(a1^2 - a2^2) = 8.443 x 10^-4",
    "h = (" + nf(h1Arr[selectedReading], 1, 1) + " - " + nf(h2Arr[selectedReading], 1, 1) + ") / 1000  =  " + nf(hVal, 1, 4) + " m",
    "H = " + nf(hVal, 1, 4) + " x 12.6  =  " + nf(HVal, 1, 3) + " m of water",
    "Qt = 8.443 x 10^-4 x sqrt(" + nf(HVal, 1, 3) + ")  =  " + nf(QtVal * 1e4, 1, 3) + " x 10^-4 m^3/s",
    "Qa = (0.09 x 0.10) / " + nf(tArr[selectedReading], 1, 1) + "  =  " + nf(QaVal * 1e4, 1, 3) + " x 10^-4 m^3/s",
    "Cd = (" + nf(QaVal * 1e4, 1, 3) + " x 10^-4) / (" + nf(QtVal * 1e4, 1, 3) + " x 10^-4)  =  " + nf(CdVal, 1, 3)
  };

  float listTop = topY + 86 * uiScale;
  float rowH = (panelH - 136 * uiScale) / 8.0;

  for (int i = 0; i < 8; i++) {
    float ry = listTop + i * rowH;
    boolean active = (i == bodmasStep);
    fill(active ? color(38, 78, 128) : color(25, 37, 57));
    stroke(active ? color(95, 215, 255) : color(48, 65, 92));
    strokeWeight(active ? 2.0 : 1.0);
    rect(pad + 34 * uiScale, ry, leftW - 50 * uiScale, rowH - 5 * uiScale, 8);

    if (active) {
      float arrowShift = sin(simTime * 5.0) * 5.0 * uiScale;
      draw2DArrow(pad + 6 * uiScale + arrowShift, ry + (rowH - 5 * uiScale) * 0.5,
                  pad + 32 * uiScale + arrowShift, ry + (rowH - 5 * uiScale) * 0.5,
                  color(255, 210, 65), 3.0);
    }

    textAlign(LEFT, TOP);
    fill(active ? color(135, 230, 255) : color(165, 185, 210));
    textSize(10.5 * uiScale);
    text(stepTitles[i], pad + 44 * uiScale, ry + 2 * uiScale);

    fill(active ? color(255) : color(215, 225, 238));
    textSize(12 * uiScale);
    text(stepExprs[i], pad + 44 * uiScale, ry + 16 * uiScale);
  }

  float btnY = height - 62 * uiScale - 42 * uiScale;
  drawButton(pad + 16 * uiScale, btnY, 115 * uiScale, 34 * uiScale, "< Prev Step", color(55, 78, 115));
  drawButton(pad + 140 * uiScale, btnY, 115 * uiScale, 34 * uiScale, "Next Step >", color(40, 145, 230));
  drawButton(pad + 264 * uiScale, btnY, 145 * uiScale, 34 * uiScale,
             bodmasAutoPlay ? "Auto-Flow: ON" : "Auto-Flow: OFF",
             bodmasAutoPlay ? color(38, 150, 115) : color(75, 85, 105));

  // RIGHT PANEL (47%): COMPLETE 47-KEY CASIO FX-991MS SCIENTIFIC CALCULATOR
  float calcX = pad + leftW + 14 * uiScale;
  float calcW = width - calcX - pad;
  drawCompleteCasioFx991MS(calcX, topY, calcW, panelH);

  endHUD();
}

void drawCompleteCasioFx991MS(float x, float y, float w, float h) {
  // Authentic Dark Navy-Charcoal Casio fx-991MS Body
  fill(42, 48, 66);
  stroke(115, 130, 158);
  strokeWeight(2.2);
  rect(x, y, w, h, 20);

  // Inner Silver/Dark Bezel around Screen & Top Controls
  fill(32, 37, 52);
  noStroke();
  rect(x + 8 * uiScale, y + 6 * uiScale, w - 16 * uiScale, h * 0.36, 14);

  // Top Header: CASIO | fx-991MS | S-V.P.A.M. | TWO WAY POWER + Solar Cell
  fill(240, 244, 250);
  textAlign(LEFT, TOP);
  textSize(14.5 * uiScale);
  text("CASIO", x + 18 * uiScale, y + 10 * uiScale);

  fill(175, 218, 255);
  textSize(11.5 * uiScale);
  text("fx-991MS", x + 18 * uiScale, y + 26 * uiScale);

  fill(235, 195, 85);
  textSize(10 * uiScale);
  text("S-V.P.A.M.", x + 82 * uiScale, y + 27 * uiScale);

  // Solar Panel (4 cells on top right)
  float solW = 104 * uiScale;
  float solH = 22 * uiScale;
  float solX = x + w - solW - 18 * uiScale;
  float solY = y + 10 * uiScale;
  fill(68, 52, 46);
  stroke(95, 105, 125);
  strokeWeight(1.5);
  rect(solX, solY, solW, solH, 4);
  stroke(110, 90, 80);
  for (int c = 1; c < 4; c++) {
    float lx = solX + c * (solW / 4.0);
    line(lx, solY, lx, solY + solH);
  }
  fill(190, 205, 225);
  textAlign(RIGHT, TOP);
  textSize(8.5 * uiScale);
  text("TWO WAY POWER", solX + solW, solY + solH + 2 * uiScale);

  // 2-Line LCD Display (Dot-matrix top line + 7-segment bottom result + D / SCI flags)
  float lcdX = x + 16 * uiScale;
  float lcdY = y + 43 * uiScale;
  float lcdW = w - 32 * uiScale;
  float lcdH = 56 * uiScale;
  fill(180, 196, 174);
  stroke(22, 26, 34);
  strokeWeight(2.5);
  rect(lcdX, lcdY, lcdW, lcdH, 7);

  // LCD Status Flags ("D" and "SCI")
  fill(24, 38, 28);
  textAlign(LEFT, TOP);
  textSize(8.5 * uiScale);
  text("D       SCI", lcdX + lcdW * 0.45, lcdY + 3 * uiScale);

  String[] lcdInput = {
    "(pi/4)x0.025^2",
    "(pi/4)x0.015^2",
    "(a1xa2xsqrt(2x9.81))/sqrt(a1^2-a2^2)",
    "(" + nf(h1Arr[selectedReading], 1, 1) + "-" + nf(h2Arr[selectedReading], 1, 1) + ")/1000",
    nf(hArr[selectedReading], 1, 4) + "x12.6",
    "8.443E-4xsqrt(" + nf(HArr[selectedReading], 1, 3) + ")",
    "(0.09x0.10)/" + nf(tArr[selectedReading], 1, 1),
    nf(QaArr[selectedReading] * 1e4, 1, 3) + "E-4/" + nf(QtArr[selectedReading] * 1e4, 1, 3) + "E-4"
  };

  String[] lcdOutput = {
    "4.908738521 x10^-04",
    "1.767145868 x10^-04",
    "8.443000000 x10^-04",
    nf(hArr[selectedReading], 1, 4) + "  (m Hg)",
    nf(HArr[selectedReading], 1, 3) + "  (m H2O)",
    nf(QtArr[selectedReading] * 1e4, 1, 3) + " x10^-04",
    nf(QaArr[selectedReading] * 1e4, 1, 3) + " x10^-04",
    nf(CdArr[selectedReading], 1, 3) + "  (Cd)"
  };

  String dispTop = customCalcMode ? customCalcInput : lcdInput[bodmasStep];
  String dispBot = customCalcMode ? customCalcOutput : lcdOutput[bodmasStep];

  fill(18, 30, 22);
  textAlign(LEFT, TOP);
  textSize(11.5 * uiScale);
  text(dispTop, lcdX + 8 * uiScale, lcdY + 12 * uiScale);

  textAlign(RIGHT, BOTTOM);
  textSize(15.5 * uiScale);
  text(dispBot, lcdX + lcdW - 8 * uiScale, lcdY + lcdH - 4 * uiScale);

  // Active Key Highlight & Keystroke Sequence Guide for Active BODMAS Step
  String[] highlightKeys = {"x^2", "x^2", "sqrt", "(", "x", "sqrt", "/", "="};
  String[] keystrokeGuides = {
    "Keys:  (  SHIFT [pi]  /  4  )  x  0.025  [x^2]  =",
    "Keys:  (  SHIFT [pi]  /  4  )  x  0.015  [x^2]  =",
    "Keys:  ( a1 x a2 x [sqrt](2x9.81) ) / [sqrt](a1^2 - a2^2) =",
    "Keys:  [ ( ]  " + nf(h1Arr[selectedReading],1,1) + "  -  " + nf(h2Arr[selectedReading],1,1) + "  )  /  1000  =",
    "Keys:  " + nf(hArr[selectedReading],1,4) + "  [ x ]  12.6  =",
    "Keys:  8.443  EXP  (-) 4  x  [sqrt]  " + nf(HArr[selectedReading],1,3) + "  =",
    "Keys:  (  0.09  x  0.10  )  [ / ]  " + nf(tArr[selectedReading],1,1) + "  =",
    "Keys:  Qa  /  Qt  [ = ]  -->  Cd = " + nf(CdArr[selectedReading],1,3)
  };
  String activeKey = highlightKeys[bodmasStep];

  // Control Row + Central 4-Way REPLAY Pad
  float ctrlTop = lcdY + lcdH + 10 * uiScale;
  float pillW = (lcdW - 96 * uiScale) / 4.2;
  float pillH = 22 * uiScale;

  // SHIFT, ALPHA, MODE CLR, ON
  drawCasioPillKey(lcdX, ctrlTop + 4 * uiScale, pillW, pillH, "SHIFT", color(215, 175, 65), color(195, 202, 214), color(25));
  drawCasioPillKey(lcdX + pillW + 6 * uiScale, ctrlTop + 4 * uiScale, pillW, pillH, "ALPHA", color(225, 95, 115), color(195, 202, 214), color(25));
  drawCasioPillKey(lcdX + lcdW - pillW * 2 - 6 * uiScale, ctrlTop + 4 * uiScale, pillW, pillH, "MODE", color(200, 210, 225), color(195, 202, 214), color(25));
  drawCasioPillKey(lcdX + lcdW - pillW, ctrlTop + 4 * uiScale, pillW, pillH, "ON", color(200, 210, 225), color(195, 202, 214), color(25));

  // Large Central 4-Way REPLAY Oval Pad
  float repCx = lcdX + lcdW * 0.5;
  float repCy = ctrlTop + 26 * uiScale;
  float repW = 76 * uiScale;
  float repH = 52 * uiScale;
  fill(178, 186, 200);
  stroke(60, 68, 84);
  strokeWeight(2);
  ellipse(repCx, repCy, repW, repH);
  fill(45, 52, 66);
  textAlign(CENTER, CENTER);
  textSize(8.5 * uiScale);
  text("REPLAY", repCx, repCy);
  textSize(8 * uiScale);
  text("^", repCx, repCy - 16 * uiScale);
  text("v", repCx, repCy + 16 * uiScale);
  text("<", repCx - 26 * uiScale, repCy);
  text(">", repCx + 26 * uiScale, repCy);

  // 4 Rows x 6 Columns of Scientific Function Keys (22 keys)
  String[][] sciKeys = {
    {"CALC", "Sdx",  "",     "",     "x^-1", "CONST"},
    {"ab/c", "sqrt", "x^2",  "^",    "log",  "ln"},
    {"(-)",  "deg",  "hyp",  "sin",  "cos",  "tan"},
    {"RCL",  "ENG",  "(",    ")",    ",",    "M+"}
  };
  String[][] sciShift = {
    {"SOLVE", "d/dx", "",    "",     "x!",   "CONV"},
    {"d/c",   "3rt",  "x^3", "xrt",  "10^x", "e^x"},
    {"A",     "B",    "C",   "sin-1","cos-1","tan-1"},
    {"STO",   "<-",   "%",   "abs",  ";",    "M-"}
  };

  float sciStartY = ctrlTop + 32 * uiScale;
  float sciGapX = 5 * uiScale;
  float sciGapY = 6 * uiScale;
  float sciW = (lcdW - sciGapX * 5) / 6.0;
  float sciH = 23 * uiScale;

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 6; c++) {
      String k = sciKeys[r][c];
      if (k.equals("")) continue; // Covered by REPLAY pad
      float kx = lcdX + c * (sciW + sciGapX);
      float ky = sciStartY + r * (sciH + sciGapY);
      boolean isHi = k.equals(activeKey);

      // Gold SHIFT legend above key
      fill(225, 185, 75);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(sciShift[r][c], kx + sciW * 0.5, ky - 1 * uiScale);

      // Key body
      if (isHi) {
        fill(245, 165, 35);
        stroke(255, 240, 140);
        strokeWeight(2);
      } else {
        fill(28, 33, 44);
        stroke(75, 84, 102);
        strokeWeight(1);
      }
      rect(kx, ky, sciW, sciH, 5);
      fill(isHi ? color(20) : color(240));
      textAlign(CENTER, CENTER);
      textSize(9.5 * uiScale);
      text(k, kx + sciW * 0.5, ky + sciH * 0.5);

      if (isHi) {
        float bounce = sin(simTime * 6.0) * 3.5 * uiScale;
        draw2DArrow(kx - 14 * uiScale + bounce, ky + sciH * 0.5, kx - 2 * uiScale + bounce, ky + sciH * 0.5, color(255, 75, 75), 2.2);
      }
    }
  }

  // 4 Rows x 5 Columns of Primary Number & Operator Keys (20 keys)
  String[][] numKeys = {
    {"7", "8", "9", "DEL", "AC"},
    {"4", "5", "6", "x",   "/"},
    {"1", "2", "3", "+",   "-"},
    {"0", ".", "EXP", "Ans", "="}
  };
  String[][] numShift = {
    {"M",   "G",   "T",   "INS", "OFF"},
    {"MAT", "VCT", "k",   "nPr", "nCr"},
    {"S-SUM","S-VAR","DISTR","Pol(","Rec("},
    {"Rnd", "Ran#","pi",  "DRG", "%"}
  };

  float numStartY = sciStartY + 4 * (sciH + sciGapY) + 8 * uiScale;
  float numBottomLimit = y + h - 24 * uiScale;
  float numGapX = 6 * uiScale;
  float numGapY = 6 * uiScale;
  float numW = (lcdW - numGapX * 4) / 5.0;
  float numH = max(22 * uiScale, (numBottomLimit - numStartY - numGapY * 3) / 4.0);

  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 5; c++) {
      String k = numKeys[r][c];
      float kx = lcdX + c * (numW + numGapX);
      float ky = numStartY + r * (numH + numGapY);
      boolean isHi = k.equals(activeKey);

      // Gold SHIFT legend above key
      fill(225, 185, 75);
      textAlign(CENTER, BOTTOM);
      textSize(7.5 * uiScale);
      text(numShift[r][c], kx + numW * 0.5, ky - 1 * uiScale);

      if (isHi) {
        fill(245, 165, 35);
        stroke(255, 240, 140);
        strokeWeight(2.2);
      } else if (k.equals("DEL") || k.equals("AC")) {
        fill(198, 82, 102); // Authentic rose-pink DEL & AC keys
        noStroke();
      } else {
        fill(138, 146, 162); // Authentic light-grey numeric/operator keys
        noStroke();
      }

      rect(kx, ky, numW, numH, 6);
      fill(isHi ? color(20) : (k.equals("DEL") || k.equals("AC") ? color(255) : color(22, 26, 34)));
      textAlign(CENTER, CENTER);
      textSize(11.5 * uiScale);
      text(k, kx + numW * 0.5, ky + numH * 0.5);

      if (isHi) {
        float bounce = sin(simTime * 6.0) * 3.5 * uiScale;
        draw2DArrow(kx - 14 * uiScale + bounce, ky + numH * 0.5, kx - 2 * uiScale + bounce, ky + numH * 0.5, color(255, 75, 75), 2.2);
      }
    }
  }

  // Bottom Keystroke Sequence Guide Strip
  fill(255, 220, 105);
  textAlign(CENTER, BOTTOM);
  textSize(10.5 * uiScale);
  text(keystrokeGuides[bodmasStep], x + w * 0.5, y + h - 5 * uiScale);
}

void drawCasioPillKey(float x, float y, float w, float h, String lbl, color topLblCol, color bg, color fg) {
  fill(topLblCol);
  textAlign(CENTER, BOTTOM);
  textSize(8 * uiScale);
  text(lbl, x + w * 0.5, y - 1 * uiScale);
  fill(bg);
  noStroke();
  rect(x, y, w, h, h * 0.5);
  fill(fg);
  textAlign(CENTER, CENTER);
  textSize(8 * uiScale);
  text(lbl, x + w * 0.5, y + h * 0.5);
}

// ============================================================================
// SCREEN 6: SIDE-BY-SIDE OBSERVATION TABLE & LIVE Qa vs sqrt(H) GRAPH
// ============================================================================
void drawScreen6_TableAndGraphSideBySide() {
  beginHUD();

  graphAnimProgress = min(1.0, graphAnimProgress + 0.02);

  float pad = 14 * uiScale;
  float topY = 64 * uiScale;
  float availH = height - topY - 62 * uiScale;

  // LEFT SIDE (55% WIDTH): COMPLETE OBSERVATION TABLE + RESULT
  float tableCardW = width * 0.55;
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  strokeWeight(1.5);
  rect(pad, topY, tableCardW, availH, 12);

  fill(110, 215, 255);
  textAlign(LEFT, TOP);
  textSize(14 * uiScale);
  text("OBSERVATION TABLE (Tap any row to highlight on Graph)", pad + 12 * uiScale, topY + 10 * uiScale);

  fill(190, 210, 235);
  textSize(11.5 * uiScale);
  text("Inlet d1=25mm | Throat d2=15mm | Tank Area A=0.09 m^2 | Rise y=0.10 m", pad + 12 * uiScale, topY + 30 * uiScale);

  String[] headers = {"R.No", "h1", "h2", "h (m)", "H (m)", "t (s)", "Qa", "Qt", "Cd", "sqrt(H)"};
  float[] weights  = {0.07, 0.09, 0.09, 0.11, 0.10, 0.09, 0.12, 0.12, 0.10, 0.11};

  float tblX = pad + 10 * uiScale;
  float tblW = tableCardW - 20 * uiScale;
  float hdrY = topY + 52 * uiScale;
  float rowH = (availH - 155 * uiScale) / 6.0;

  float curX = tblX;
  for (int c = 0; c < headers.length; c++) {
    float cw = tblW * weights[c];
    fill(38, 62, 96);
    stroke(70, 105, 145);
    rect(curX, hdrY, cw, rowH);
    fill(255, 225, 120);
    textAlign(CENTER, CENTER);
    textSize(11 * uiScale);
    text(headers[c], curX + cw * 0.5, hdrY + rowH * 0.5);
    curX += cw;
  }

  for (int r = 0; r < 5; r++) {
    float ry = hdrY + (r + 1) * rowH;
    boolean isSel = (r == selectedReading);
    String[] vals = {
      str(rNo[r]),
      nf(h1Arr[r], 1, 1),
      nf(h2Arr[r], 1, 1),
      nf(hArr[r], 1, 4),
      nf(HArr[r], 1, 3),
      nf(tArr[r], 1, 1),
      nf(QaArr[r] * 1e4, 1, 3),
      nf(QtArr[r] * 1e4, 1, 3),
      nf(CdArr[r], 1, 3),
      nf(sqHArr[r], 1, 3)
    };

    curX = tblX;
    for (int c = 0; c < vals.length; c++) {
      float cw = tblW * weights[c];
      fill(isSel ? color(42, 115, 185) : (r % 2 == 0 ? color(25, 36, 56) : color(30, 43, 66)));
      stroke(55, 80, 115);
      rect(curX, ry, cw, rowH);
      fill(isSel ? color(255) : color(225, 235, 248));
      textAlign(CENTER, CENTER);
      textSize(11.5 * uiScale);
      text(vals[c], curX + cw * 0.5, ry + rowH * 0.5);
      curX += cw;
    }
  }

  float resY = hdrY + 6 * rowH + 10 * uiScale;
  float resH = availH - (resY - topY) - 10 * uiScale;
  fill(24, 48, 68);
  stroke(85, 215, 165);
  rect(tblX, resY, tblW, resH, 8);

  fill(255, 220, 95);
  textAlign(LEFT, TOP);
  textSize(12 * uiScale);
  text("AVERAGE VALUE:  Cd = (0.946 + 0.938 + 0.922 + 0.975 + 0.961) / 5  =  0.938", tblX + 10 * uiScale, resY + 8 * uiScale);

  fill(105, 245, 175);
  textSize(13 * uiScale);
  text("RESULT: Coefficient of discharge of given Venturimeter Cd = 0.938", tblX + 10 * uiScale, resY + 32 * uiScale);

  // RIGHT SIDE (45% WIDTH): ANIMATED GRAPH SHEET (Qa vs sqrt(H))
  float graphCardX = pad + tableCardW + 12 * uiScale;
  float graphCardW = width - graphCardX - pad;
  fill(18, 28, 46, 240);
  stroke(65, 125, 195);
  rect(graphCardX, topY, graphCardW, availH, 12);

  drawSideBySideGraph(graphCardX + 12 * uiScale, topY + 10 * uiScale, graphCardW - 24 * uiScale, availH - 20 * uiScale);

  endHUD();
}

void drawSideBySideGraph(float gx, float gy, float gw, float gh) {
  fill(110, 215, 255);
  textAlign(LEFT, TOP);
  textSize(13.5 * uiScale);
  text("GRAPH: Actual Discharge Qa vs sqrt(H)", gx, gy);

  fill(190, 210, 235);
  textSize(11 * uiScale);
  text("X-Axis: sqrt(H) (m^1/2)   |   Y-Axis: Qa (x 10^-4 m^3/s)", gx, gy + 20 * uiScale);

  float plotX = gx + 48 * uiScale;
  float plotY = gy + 44 * uiScale;
  float plotW = gw - 62 * uiScale;
  float plotH = gh - 92 * uiScale;

  fill(245, 249, 246);
  noStroke();
  rect(plotX, plotY, plotW, plotH);

  stroke(195, 222, 202);
  strokeWeight(1);
  for (int i = 0; i <= 20; i++) {
    float xG = plotX + i * (plotW / 20.0);
    line(xG, plotY, xG, plotY + plotH);
    float yG = plotY + i * (plotH / 20.0);
    line(plotX, yG, plotX + plotW, yG);
  }

  stroke(135, 180, 148);
  for (int i = 0; i <= 4; i++) {
    float xM = plotX + i * (plotW / 4.0);
    line(xM, plotY, xM, plotY + plotH);
    float yM = plotY + i * (plotH / 4.0);
    line(plotX, yM, plotX + plotW, yM);
  }

  stroke(30, 45, 65);
  strokeWeight(2);
  line(plotX, plotY, plotX, plotY + plotH);
  line(plotX, plotY + plotH, plotX + plotW, plotY + plotH);

  fill(215, 230, 248);
  textSize(10.5 * uiScale);
  textAlign(RIGHT, CENTER);
  text("6.2", plotX - 6 * uiScale, plotY);
  text("6.0", plotX - 6 * uiScale, plotY + plotH * 0.25);
  text("5.8", plotX - 6 * uiScale, plotY + plotH * 0.50);
  text("5.6", plotX - 6 * uiScale, plotY + plotH * 0.75);
  text("5.4", plotX - 6 * uiScale, plotY + plotH);

  textAlign(CENTER, TOP);
  text("0.745", plotX, plotY + plotH + 5 * uiScale);
  text("0.760", plotX + plotW * 0.5, plotY + plotH + 5 * uiScale);
  text("0.775", plotX + plotW, plotY + plotH + 5 * uiScale);

  float xStart = plotX + plotW * 0.10;
  float yStart = plotY + plotH * 0.76;
  float xEnd = lerp(xStart, plotX + plotW * 0.92, graphAnimProgress);
  float yEnd = lerp(yStart, plotY + plotH * 0.20, graphAnimProgress);
  stroke(225, 65, 55);
  strokeWeight(2.5);
  line(xStart, yStart, xEnd, yEnd);

  for (int i = 0; i < 5; i++) {
    float px = map(sqHArr[i], 0.745, 0.775, plotX, plotX + plotW);
    float py = map(QaArr[i] * 1e4, 5.4, 6.2, plotY + plotH, plotY);
    boolean isSel = (i == selectedReading);

    if (isSel) {
      stroke(30, 120, 220);
      strokeWeight(1.5);
      line(plotX, py, px, py);
      line(px, py, px, plotY + plotH);
    }

    noStroke();
    fill(isSel ? color(235, 55, 55) : color(25, 115, 210));
    ellipse(px, py, isSel ? 13 * uiScale : 9 * uiScale, isSel ? 13 * uiScale : 9 * uiScale);

    fill(20, 35, 55);
    textAlign(CENTER, BOTTOM);
    textSize(10.5 * uiScale);
    text("R" + (i + 1), px, py - 7 * uiScale);
  }

  fill(255, 215, 90);
  textAlign(LEFT, BOTTOM);
  textSize(11.5 * uiScale);
  text("Active R" + rNo[selectedReading] + ": sqrt(H)=" + nf(sqHArr[selectedReading], 1, 3) +
       ", Qa=" + nf(QaArr[selectedReading] * 1e4, 1, 3) + "x10^-4  |  Slope = Cd x C", gx, gy + gh);
}

// ============================================================================
// NAVIGATION BARS & GEOMETRY HELPERS
// ============================================================================
void drawTopNavBar() {
  fill(16, 24, 38, 248);
  noStroke();
  rect(0, 0, width, 54 * uiScale);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(14 * uiScale);
  text("VENTURIMETER LAB", 14 * uiScale, 27 * uiScale);

  String[] tabs = {
    "1. 3D RIG",
    "2. FLOW LINES",
    "3. DERIVATION",
    "4. PROCEDURE",
    "5. CASIO CALC",
    "6. TABLE & GRAPH"
  };

  float leftClearance = 185 * uiScale;
  float tabGap = 6 * uiScale;
  float tabW = (width - leftClearance - 14 * uiScale - tabGap * (tabs.length - 1)) / float(tabs.length);

  for (int i = 0; i < tabs.length; i++) {
    float tx = leftClearance + i * (tabW + tabGap);
    fill(currentScreen == i ? color(38, 148, 240) : color(34, 46, 68));
    rect(tx, 9 * uiScale, tabW, 36 * uiScale, 8);
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(10.8 * uiScale);
    text(tabs[i], tx + tabW * 0.5, 27 * uiScale);
  }
}

void drawBottomNavBar() {
  float barY = height - 50 * uiScale;
  fill(16, 24, 38, 248);
  noStroke();
  rect(0, barY, width, 50 * uiScale);

  drawButton(16 * uiScale, barY + 7 * uiScale, 165 * uiScale, 36 * uiScale, "< PREV SCREEN", color(52, 72, 105));
  drawButton(width - 181 * uiScale, barY + 7 * uiScale, 165 * uiScale, 36 * uiScale, "NEXT SCREEN >", color(38, 148, 240));

  fill(180, 200, 225);
  textAlign(CENTER, CENTER);
  textSize(12 * uiScale);
  text("Screen " + (currentScreen + 1) + " of 6  |  Reading #" + rNo[selectedReading] + " (Cd=" + nf(CdArr[selectedReading], 1, 3) + ")  |  Mean Cd = 0.938",
       width * 0.5, barY + 25 * uiScale);
}

void drawButton(float x, float y, float w, float h, String label, color bg) {
  fill(bg);
  noStroke();
  rect(x, y, w, h, 8);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(11.5 * uiScale);
  text(label, x + w * 0.5, y + h * 0.5);
}

void draw2DArrow(float x1, float y1, float x2, float y2, color col, float sw) {
  stroke(col);
  strokeWeight(sw);
  line(x1, y1, x2, y2);
  float ang = atan2(y2 - y1, x2 - x1);
  float head = 7 * uiScale;
  line(x2, y2, x2 - head * cos(ang - 0.5), y2 - head * sin(ang - 0.5));
  line(x2, y2, x2 - head * cos(ang + 0.5), y2 - head * sin(ang + 0.5));
}

void drawArrow3D(PVector a, PVector b, color col) {
  stroke(col);
  strokeWeight(3);
  line(a.x, a.y, a.z, b.x, b.y, b.z);
  pushMatrix();
  translate(b.x, b.y, b.z);
  fill(col);
  noStroke();
  sphere(5);
  popMatrix();
}

void drawCylinder(float rTop, float rBot, float h, int sides) {
  float halfH = h * 0.5;
  beginShape(TRIANGLE_STRIP);
  for (int i = 0; i <= sides; i++) {
    float ang = TWO_PI * i / sides;
    float x = cos(ang);
    float z = sin(ang);
    vertex(x * rTop, -halfH, z * rTop);
    vertex(x * rBot, halfH, z * rBot);
  }
  endShape();
}

// ============================================================================
// ANDROID TOUCH & DRAG HANDLERS (1:1 SCREEN COORDINATE MAPPING)
// ============================================================================
void mousePressed() {
  prevTouchX = mouseX;
  prevTouchY = mouseY;
  lastTapX = mouseX;
  lastTapY = mouseY;
  touchRippleAlpha = 255;
  isDragging = true;
  draggingSlider = false;

  // 1. Top 6 Navigation Tabs
  float leftClearance = 185 * uiScale;
  float tabGap = 6 * uiScale;
  float tabW = (width - leftClearance - 14 * uiScale - tabGap * 5) / 6.0;
  if (mouseY >= 0 && mouseY <= 54 * uiScale) {
    for (int i = 0; i < 6; i++) {
      float tx = leftClearance + i * (tabW + tabGap);
      if (mouseX >= tx && mouseX <= tx + tabW) {
        currentScreen = i;
        if (currentScreen == 5) graphAnimProgress = 0;
        return;
      }
    }
  }

  // 2. Bottom Prev / Next Screen Buttons
  float barY = height - 50 * uiScale;
  if (mouseY >= barY) {
    if (mouseX <= 200 * uiScale) {
      currentScreen = (currentScreen + 5) % 6;
      if (currentScreen == 5) graphAnimProgress = 0;
    } else if (mouseX >= width - 200 * uiScale) {
      currentScreen = (currentScreen + 1) % 6;
      if (currentScreen == 5) graphAnimProgress = 0;
    }
    return;
  }

  float pad = 14 * uiScale;
  float topY = 64 * uiScale;

  // 3. Screen-Specific Touch Controls
  if (currentScreen == 0) {
    // SCREEN 1: 3D RIG CONTROLS
    float rx = width - 255 * uiScale - pad;
    for (int i = 0; i < 5; i++) {
      float bx = rx + 14 * uiScale + i * 46 * uiScale;
      float by = topY + 38 * uiScale;
      if (mouseX >= bx && mouseX <= bx + 40 * uiScale &&
          mouseY >= by && mouseY <= by + 36 * uiScale) {
        selectReading(i);
        return;
      }
    }
    float sx = rx + 14 * uiScale;
    float sy = topY + 98 * uiScale;
    float sw = 225 * uiScale;
    if (mouseX >= sx - 10 * uiScale && mouseX <= sx + sw + 10 * uiScale &&
        mouseY >= sy && mouseY <= sy + 36 * uiScale) {
      draggingSlider = true;
      valveOpening = constrain((mouseX - sx) / sw, 0.2, 1.0);
      return;
    }
    if (mouseX >= rx + 14 * uiScale && mouseX <= rx + 239 * uiScale &&
        mouseY >= topY + 140 * uiScale && mouseY <= topY + 178 * uiScale) {
      autoRotate = !autoRotate;
      return;
    }
    if (mouseY >= topY + 190 * uiScale && mouseY <= topY + 228 * uiScale) {
      if (mouseX >= rx + 14 * uiScale && mouseX <= rx + 122 * uiScale) {
        zoomScale = constrain(zoomScale + 0.15, 0.65, 1.8);
      } else if (mouseX >= rx + 131 * uiScale && mouseX <= rx + 239 * uiScale) {
        zoomScale = constrain(zoomScale - 0.15, 0.65, 1.8);
      }
    }

  } else if (currentScreen == 1) {
    // SCREEN 2: TRANSPARENT VENTURI LAYER TOGGLES & DYE INJECTOR TAP
    float availH = height - topY - 62 * uiScale;
    float mainW = width - 2 * pad;
    float ctrlBarX = pad + 12 * uiScale;
    float ctrlBarY = topY + availH - 76 * uiScale;
    float ctrlBarW = mainW - 24 * uiScale;
    float gap = 8 * uiScale;
    float btnW = (ctrlBarW - 24 * uiScale - gap * 6) / 7.0;
    float btnY = ctrlBarY + 26 * uiScale;

    if (mouseY >= btnY && mouseY <= btnY + 38 * uiScale) {
      for (int i = 0; i < 7; i++) {
        float bx = ctrlBarX + 12 * uiScale + i * (btnW + gap);
        if (mouseX >= bx && mouseX <= bx + btnW) {
          if (i == 0) showParticles = !showParticles;
          else if (i == 1) showVectors = !showVectors;
          else if (i == 2) showStreamlines = !showStreamlines;
          else if (i == 3) showPathlines = !showPathlines;
          else if (i == 4) showStreaklines = !showStreaklines;
          else if (i == 5) {
            unsteadyWaveMode = !unsteadyWaveMode;
            streakParticles.clear();
          } else if (i == 6) {
            streakParticles.clear();
            for (TransparentParticle p : transParticles) p.trail.clear();
          }
          return;
        }
      }
    }

    // Tap inside the Transparent Venturi Tube to relocate Streakline Dye Nozzle
    float tubeX = pad + 85 * uiScale;
    float tubeW = mainW - 170 * uiScale;
    float tubeCenterY = topY + availH * 0.56;
    float rInlet = min(84 * uiScale, availH * 0.23);
    if (mouseX >= tubeX && mouseX <= tubeX + tubeW &&
        abs(mouseY - tubeCenterY) <= rInlet) {
      float uTap = constrain((mouseX - tubeX) / tubeW, 0.03, 0.90);
      float rLocal = getVenturiHalfRadius(uTap, rInlet);
      if (abs(mouseY - tubeCenterY) <= rLocal) {
        nozzleU = uTap;
        nozzleEta = constrain((mouseY - tubeCenterY) / rLocal, -0.82, 0.82);
        streakParticles.clear();
        transParticles.add(new TransparentParticle(nozzleU, nozzleEta, true));
        if (transParticles.size() > 50) transParticles.remove(0);
      }
    }

  } else if (currentScreen == 2) {
    // SCREEN 3: BERNOULLI DERIVATION STEPS
    float availH = height - topY - 62 * uiScale;
    float leftW = width * 0.56;
    float listY = topY + 40 * uiScale;
    float rowH = (availH - 92 * uiScale) / 7.0;
    if (mouseX >= pad && mouseX <= pad + leftW) {
      for (int i = 0; i < 7; i++) {
        float ry = listY + i * rowH;
        if (mouseY >= ry && mouseY <= ry + rowH) {
          derivAutoPlay = false;
          derivStep = i;
          return;
        }
      }
    }
    float ctrlY = height - 62 * uiScale - 42 * uiScale;
    if (mouseY >= ctrlY && mouseY <= ctrlY + 36 * uiScale) {
      if (mouseX >= pad + 16 * uiScale && mouseX <= pad + 136 * uiScale) {
        derivAutoPlay = false;
        derivStep = (derivStep + 6) % 7;
      } else if (mouseX >= pad + 146 * uiScale && mouseX <= pad + 266 * uiScale) {
        derivAutoPlay = false;
        derivStep = (derivStep + 1) % 7;
      } else if (mouseX >= pad + 276 * uiScale && mouseX <= pad + 431 * uiScale) {
        derivAutoPlay = !derivAutoPlay;
      }
    }

  } else if (currentScreen == 3) {
    // SCREEN 4: HOW READINGS ARE TAKEN
    float availH = height - topY - 62 * uiScale;
    float leftW = width * 0.48;
    float stepListY = topY + 46 * uiScale;
    float stepH = (availH - 98 * uiScale) / 6.0;
    if (mouseX >= pad && mouseX <= pad + leftW) {
      for (int i = 0; i < 6; i++) {
        float sy = stepListY + i * stepH;
        if (mouseY >= sy && mouseY <= sy + stepH) {
          procAutoPlay = false;
          procStep = i;
          return;
        }
      }
    }
    float ctrlY = height - 62 * uiScale - 42 * uiScale;
    if (mouseY >= ctrlY && mouseY <= ctrlY + 36 * uiScale) {
      if (mouseX >= pad + 16 * uiScale && mouseX <= pad + 131 * uiScale) {
        procAutoPlay = false;
        procStep = (procStep + 5) % 6;
      } else if (mouseX >= pad + 140 * uiScale && mouseX <= pad + 255 * uiScale) {
        procAutoPlay = false;
        procStep = (procStep + 1) % 6;
      } else if (mouseX >= pad + 264 * uiScale && mouseX <= pad + 409 * uiScale) {
        procAutoPlay = !procAutoPlay;
      }
    }

  } else if (currentScreen == 4) {
    // SCREEN 5: BODMAS ROWS & INTERACTIVE CASIO FX-991MS KEYPAD
    float panelH = height - topY - 62 * uiScale;
    float leftW = width * 0.53;
    float listTop = topY + 86 * uiScale;
    float rowH = (panelH - 136 * uiScale) / 8.0;
    if (mouseX >= pad && mouseX <= pad + leftW) {
      for (int i = 0; i < 8; i++) {
        float ry = listTop + i * rowH;
        if (mouseY >= ry && mouseY <= ry + rowH) {
          bodmasAutoPlay = false;
          bodmasStep = i;
          customCalcMode = false;
          return;
        }
      }
    }
    float btnY = height - 62 * uiScale - 42 * uiScale;
    if (mouseY >= btnY && mouseY <= btnY + 36 * uiScale) {
      if (mouseX >= pad + 16 * uiScale && mouseX <= pad + 131 * uiScale) {
        bodmasAutoPlay = false;
        bodmasStep = (bodmasStep + 7) % 8;
        customCalcMode = false;
      } else if (mouseX >= pad + 140 * uiScale && mouseX <= pad + 255 * uiScale) {
        bodmasAutoPlay = false;
        bodmasStep = (bodmasStep + 1) % 8;
        customCalcMode = false;
      } else if (mouseX >= pad + 264 * uiScale && mouseX <= pad + 409 * uiScale) {
        bodmasAutoPlay = !bodmasAutoPlay;
        customCalcMode = false;
      }
      return;
    }

    // Check interactive touches on the Casio fx-991MS numeric/operator keys
    float calcX = pad + leftW + 14 * uiScale;
    float calcW = width - calcX - pad;
    float lcdX = calcX + 16 * uiScale;
    float lcdW = calcW - 32 * uiScale;
    float lcdY = topY + 43 * uiScale;
    float lcdH = 56 * uiScale;
    float ctrlTop = lcdY + lcdH + 10 * uiScale;
    float sciStartY = ctrlTop + 32 * uiScale;
    float sciGapY = 6 * uiScale;
    float sciH = 23 * uiScale;
    float numStartY = sciStartY + 4 * (sciH + sciGapY) + 8 * uiScale;
    float numBottomLimit = topY + panelH - 24 * uiScale;
    float numGapX = 6 * uiScale;
    float numGapY = 6 * uiScale;
    float numW = (lcdW - numGapX * 4) / 5.0;
    float numH = max(22 * uiScale, (numBottomLimit - numStartY - numGapY * 3) / 4.0);

    String[][] numKeys = {
      {"7", "8", "9", "DEL", "AC"},
      {"4", "5", "6", "x",   "/"},
      {"1", "2", "3", "+",   "-"},
      {"0", ".", "EXP", "Ans", "="}
    };

    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 5; c++) {
        float kx = lcdX + c * (numW + numGapX);
        float ky = numStartY + r * (numH + numGapY);
        if (mouseX >= kx && mouseX <= kx + numW && mouseY >= ky && mouseY <= ky + numH) {
          handleCasioKeyTap(numKeys[r][c]);
          return;
        }
      }
    }

  } else if (currentScreen == 5) {
    // SCREEN 6: OBSERVATION TABLE ROW SELECTION
    float availH = height - topY - 62 * uiScale;
    float hdrY = topY + 52 * uiScale;
    float rowH = (availH - 155 * uiScale) / 6.0;
    if (mouseX <= width * 0.56) {
      for (int r = 0; r < 5; r++) {
        float ry = hdrY + (r + 1) * rowH;
        if (mouseY >= ry && mouseY <= ry + rowH) {
          selectReading(r);
          break;
        }
      }
    }
  }
}

void handleCasioKeyTap(String key) {
  bodmasAutoPlay = false;
  if (key.equals("AC")) {
    customCalcMode = false;
    customCalcInput = "";
    customCalcOutput = "0.";
  } else if (key.equals("DEL")) {
    customCalcMode = true;
    if (customCalcInput.length() > 0) {
      customCalcInput = customCalcInput.substring(0, customCalcInput.length() - 1);
    }
  } else if (key.equals("=")) {
    customCalcMode = false; // Returns to active BODMAS step result
  } else {
    customCalcMode = true;
    if (customCalcInput.length() < 24) {
      customCalcInput += key;
    }
    customCalcOutput = "KEY INPUT";
  }
}

void mouseDragged() {
  if (currentScreen == 0 && isDragging) {
    if (draggingSlider) {
      float pad = 14 * uiScale;
      float rx = width - 255 * uiScale - pad;
      float sx = rx + 14 * uiScale;
      float sw = 225 * uiScale;
      valveOpening = constrain((mouseX - sx) / sw, 0.2, 1.0);
    } else {
      float dx = mouseX - prevTouchX;
      float dy = mouseY - prevTouchY;
      rotY += dx * 0.008;
      rotX = constrain(rotX + dy * 0.008, -1.1, 0.6);
      prevTouchX = mouseX;
      prevTouchY = mouseY;
    }
  }
}

void mouseReleased() {
  isDragging = false;
  draggingSlider = false;
}
