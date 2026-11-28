Act as an expert Android Processing (APDE - P3D mode) developer and Mechanical/Fluid Engineering lab instructor.

Analyze ALL provided context and attachments in this prompt—whether an IMAGE (photo/scan of a handwritten or printed lab record, observation table, formula sheet, or apparatus diagram), AUDIO (voice recording dictating the experiment, readings, or procedure), DOCUMENT/TEXT, or a short EXPERIMENT NAME—and build a COMPLETE, FULLY RUNNABLE, ZERO-TRUNCATION 6-screen interactive Android APDE (`P3D`) simulation app for that exact experiment.

================================================================================
1. AUTOMATIC MULTIMODAL CONTEXT EXTRACTION & FALLBACK RULES
================================================================================
From the attached image, audio, text, or prompt context, automatically extract and structure:
1. **Experiment Title & Short Header Title** (e.g., `ORIFICE METER LAB`, `BERNOULLI APPARATUS`, `IMPACT OF JET`, `PIPE FRICTION LAB`).
2. **Apparatus Constants & Dimensions** (extract exact values shown/spoken in the input, such as diameters $d_1, d_2$, tank area $A$, rise $y$, pipe length $L$, specific gravity factor, vane angle, etc.).
3. **All Observation Table Readings ($R_1 \dots R_n$)**:
   - Read every row and column accurately from the attached image/audio/text.
   - Identify the Model Calculation row (default `selectedReading` to that row).
   - If the input only shows the apparatus or names the experiment without numerical readings, generate 5 realistic, physically consistent polytechnic lab readings so the app runs out-of-the-box.
4. **Governing Equations & Graph Relationship**:
   - Extract the exact step-by-step formulas, unit conversions, final mean result, and $X$-vs-$Y$ graph axes + slope meaning.
5. **Custom 3D & 2D Apparatus Geometry**:
   - Match the 3D rig (Screen 1), 2D transparent cutaway (Screen 2), energy/control-volume schematic (Screen 3), and dual zoomed measurement instruments (Screen 4) specifically to the apparatus in the given context.

================================================================================
2. REQUIRED 6-SCREEN ARCHITECTURE & VISUAL DETAILS
================================================================================
Generate ONE single, self-contained `.pde` file with all 6 screens accessible via Top Navigation Tabs and `< PREV SCREEN` / `NEXT SCREEN >` bottom buttons, dynamically synced to the currently selected reading row (`selectedReading`):

- **SCREEN 1 (`1. 3D RIG`)**:
  - Full 3D apparatus built with `P3D` primitives (`box`, `sphere`, custom `drawCylinder`, `bezier` manometer/gauge tubing, sump/collecting tanks, pump/motor, valves, and the specific test section from the input) in `drawApparatus3D()`.
  - Animated 3D flow/motion particles passing through the rig whose speed/intensity responds to the selected reading and the interactive primary control slider.
  - Touch-drag 3D orbit rotation (`rotX`, `rotY`), `Auto-Orbit` toggle, `Zoom +` / `Zoom -`, Reading selector buttons (`R1`..`Rn`), and a Live Telemetry HUD card showing all extracted and calculated values for the active reading.

- **SCREEN 2 (`2. CUTAWAY`)**:
  - Detailed 2D transparent cutaway cross-section of the specific test apparatus (`drawScreen2_CutawayPhysics()`), showing internal geometry, pressure/sensor gauges (e.g., piezometer water columns, Bourdon dial gauge, or sensor probes), and live quantitative readouts (e.g., inlet vs. throat/orifice/jet velocity and pressure/force values).
  - Interactive fluid/field simulation featuring:
    1. Moving particles color-coded by velocity/magnitude
    2. Velocity/field vector arrows + cross-section velocity profile arrows
    3. Instantaneous Streamlines
    4. Particle Pathlines (Lagrangian trails)
    5. Streaklines with an interactive tracer/dye nozzle (tap anywhere inside the cutaway to relocate the injector)
    6. `STEADY` vs. `UNSTEADY` wave mode toggle + `Reset Trails` button.

- **SCREEN 3 (`3. DERIVATION`)**:
  - Left panel (56% width): 7-step mathematical derivation (`derivTitles[]`, `derivFormulas[]`) from fundamental conservation laws down to the final working equation of this experiment, with an animated pointing arrow (`draw2DArrow`), `< Prev Step`, `Next Step >`, and `Auto-Derive: ON/OFF` controls.
  - Right panel (44% width): Custom control-volume & energy/force grade line schematic diagram tailored to this experiment, with live numerical callouts for the active reading and a highlighted Final Derived Equation box.

- **SCREEN 4 (`4. PROCEDURE`)**:
  - Left panel (48% width): 6-step experimental lab procedure (`procSteps[]` — "How Readings Are Taken") tailored to this apparatus, with animated arrow indicator, tap-any-step selection, and `Auto-Demo: ON/OFF`.
  - Right panel (52% width): Two zoomed, animated measurement instrument cards matching the actual sensors in this experiment (e.g., Card 1: Zoomed U-tube manometer / pressure gauge / scale; Card 2: Zoomed collecting tank + live stopwatch `t` / weighing pan / tachometer).

- **SCREEN 5 (`5. CASIO CALC`)**:
  - Left panel (53% width): 8-step BODMAS breakdown (`B`, `O`, `D`, `M`, `A`, `S` highlight badges + 8 calculation rows plugged in with the active reading's exact numbers and animated arrow indicator).
  - Right panel (47% width): Complete, authentic **47-key Casio fx-991MS S-V.P.A.M.** scientific calculator (`CASIO`, `fx-991MS`, `S-V.P.A.M.`, 4-cell solar panel, 2-line LCD with `D` and `SCI` status flags, `SHIFT`/`ALPHA`/`MODE`/`ON` pills, central 4-way `REPLAY` oval, 22 scientific keys + 20 numeric/operator keys with gold SHIFT legends above every key, glowing active-key highlight + bouncing red arrow, bottom keystroke sequence guide, and working touch input on the numeric/operator keys).

- **SCREEN 6 (`6. TABLE & GRAPH`)**:
  - Left panel (55% width): Full Observation Table with all raw and calculated columns from the given context, tap-any-row selection (highlights row and updates all 6 screens), and bottom Average/Final Result box.
  - Right panel (45% width): Auto-scaled Graph Sheet (`drawAutoScaledGraph()`) with major/minor gridlines, padded min/max axis bounds, ordinary least-squares best-fit line animation, plotted reading points (`R1`..`Rn`), dashed projection lines for the active reading, and slope/result summary.

================================================================================
3. STRICT APDE & CODE QUALITY RULES
================================================================================
1. Output the ENTIRE Processing `.pde` code in one continuous code block. NEVER use `// TODO`, `// ... same as before`, or abbreviated methods.
2. Use `fullScreen(P3D);` in `settings()` and `orientation(LANDSCAPE);` in `setup()`.
3. Scale all HUD coordinates, fonts, padding, and buttons using `uiScale = constrain(min(width / 1280.0, height / 720.0), 0.55, 1.5);`.
4. Wrap all 2D HUD screens and overlays in `beginHUD()` (`hint(DISABLE_DEPTH_TEST); camera(); ortho(); noLights();`) and `endHUD()` (`hint(ENABLE_DEPTH_TEST);`) so 2D UI never clips into 3D geometry.
5. Use clean ASCII math notation in canvas strings (`^2`, `sqrt()`, `pi`, `x10^-4`, `->`, `==>`) so Android's `SansSerif` font renders every character cleanly without missing-glyph boxes.
6. Ensure every button, slider, table row, derivation step, procedure step, BODMAS row, Casio key, and cutaway injector has accurate 1:1 touch hit-testing in `mousePressed()` and `mouseDragged()`.
