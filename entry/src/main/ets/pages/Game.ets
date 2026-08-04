import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { GameEngine } from '../model/GameEngine';
import {
  carSpec,
  CarType,
  ControlMode,
  DecorType,
  GameStatus,
  KEY_BEST_SCORE,
  KEY_CONTROL_MODE,
  KEY_GESTURE_BRAKE,
  KEY_TILT_SENS,
  LANE_COUNT
} from '../model/GameTypes';
import { getStrings, Language, Strings } from '../model/Localization';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/** Returns a cryptographically secure float in [0, 1). */
function secureRandom(): number {
  const rand = cryptoFramework.createRandom();
  const buf = rand.generateRandomSync(4); // 4 bytes = Uint32
  const bytes = buf.data;
  // Combine 4 bytes into an unsigned 32-bit integer
  const u32 = ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) >>> 0;
  return u32 / 0x100000000; // normalize to [0, 1)
}

/** A single smoke puff drifting behind the player's car. */
class SmokeParticle {
  x: number;
  y: number;
  radius: number;
  alpha: number;
  vx: number;
  vy: number;

  constructor(x: number, y: number, radius: number, vx: number, vy: number) {
    this.x = x;
    this.y = y;
    this.radius = radius;
    this.alpha = 0.45;
    this.vx = vx;
    this.vy = vy;
  }
}

/**
 * 2D car game scene for wearables.
 * The road, roadside decorations, the player and obstacles are drawn on a
 * Canvas and updated with a frame-based loop. Steering: touch or tilt
 * (accelerometer). Braking: button, or a Huawei wearable hand gesture.
 */
@Entry
@Component
struct Game {

  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack()
  private renderSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderSettings);
  private engine: GameEngine = new GameEngine();

  // Game loop
  private loopId: number = -1;
  private lastTs: number = 0;

  // Scrolling lane-line offset (for a sense of motion)
  private roadOffset: number = 0;

  // Smoke trail behind the player
  private smoke: SmokeParticle[] = [];
  private smokeTimer: number = 0;

  // Control mode (comes from settings)
  private controlMode: number = ControlMode.TOUCH;
  private tiltSensitivity: number = 1.0;
  private gestureBrakeEnabled: boolean = false;
  private sensorSubscribed: boolean = false;

  // Brake sources: the on-screen button and the touchless finger-tap gesture.
  private manualBrake: boolean = false;
  // Touchless finger-tap detection: tapping the thumb against a finger makes a
  // short, sharp jerk on the wrist that the accelerometer can pick up. (Huawei
  // does not expose its system pinch gesture to apps, so we recognize the tap
  // ourselves from the IMU.)
  private gestureBrakeUntil: number = 0; // ms timestamp the tap keeps the brake held until
  private prevAccelMag: number = 0;      // previous |acceleration|, for the jerk computation
  private lastTapTs: number = 0;         // debounce guard between detected taps
  // Tuning for the finger-tap detector.
  private readonly tapJerkThreshold: number = 6.0; // m/s^2 change between samples
  private readonly tapDebounceMs: number = 220;     // min gap between two taps
  private readonly gestureHoldMs: number = 800;     // how long one tap holds the brake

  // Active language (drives string lookups, updates UI on change)
  @StorageLink('language') language: number = Language.TR;

  // State copies to trigger UI updates
  @State status: GameStatus = GameStatus.READY;
  @State score: number = 0;
  @State braking: boolean = false;

  /** Convenience accessor for the localized strings. */
  private str(): Strings {
    return getStrings(this.language);
  }

  aboutToAppear(): void {
    const mode: number | undefined = AppStorage.get<number>(KEY_CONTROL_MODE);
    this.controlMode = mode === undefined ? ControlMode.TOUCH : mode;
    const sens: number | undefined = AppStorage.get<number>(KEY_TILT_SENS);
    this.tiltSensitivity = sens === undefined ? 1.0 : sens;
    const gesture: boolean | undefined = AppStorage.get<boolean>(KEY_GESTURE_BRAKE);
    this.gestureBrakeEnabled = gesture === undefined ? false : gesture;
  }

  aboutToDisappear(): void {
    this.stopLoop();
    this.unsubscribeSensors();
  }

  /** When the canvas is ready, read its size, set up the engine and start. */
  private onCanvasReady(): void {
    const w: number = this.ctx.width;
    const h: number = this.ctx.height;
    this.engine.init(w, h);
    this.startGame();
  }

  private startGame(): void {
    this.engine.start();
    this.status = this.engine.status;
    this.score = 0;
    this.braking = false;
    this.manualBrake = false;
    this.gestureBrakeUntil = 0;
    this.prevAccelMag = 9.81; // seed with resting gravity so the first sample isn't a false tap
    this.lastTapTs = 0;
    this.smoke = [];
    this.lastTs = 0;
    // The accelerometer powers tilt steering and/or finger-tap brake detection.
    if (this.controlMode === ControlMode.TILT || this.gestureBrakeEnabled) {
      this.subscribeSensors();
    }
    this.startLoop();
  }

  private startLoop(): void {
    this.stopLoop();
    this.loopId = setInterval(() => {
      this.tick();
    }, 16); // ~60 FPS
  }

  private stopLoop(): void {
    if (this.loopId !== -1) {
      clearInterval(this.loopId);
      this.loopId = -1;
    }
  }

  // ---------- Accelerometer: tilt steering + touchless finger-tap brake ----------

  private subscribeSensors(): void {
    if (this.sensorSubscribed) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        // Tilt steering: tilting the watch left/right changes the x axis.
        if (this.controlMode === ControlMode.TILT) {
          const raw: number = -data.x;
          const dead: number = 0.7;
          let steer: number = 0;
          if (raw > dead) {
            steer = (raw - dead) / 4.5;
          } else if (raw < -dead) {
            steer = (raw + dead) / 4.5;
          }
          this.engine.setSteer(steer * this.tiltSensitivity);
        }

        // Touchless finger-tap brake detection.
        if (this.gestureBrakeEnabled) {
          this.detectFingerTap(data.x, data.y, data.z);
        }
      }, { interval: 20000000 }); // ~20ms
      this.sensorSubscribed = true;
    } catch (err) {
      const e = err as BusinessError;
      console.error(`Accelerometer unavailable: ${e.code} ${e.message}`);
    }
  }

  /**
   * Detects a thumb-to-finger tap from the accelerometer.
   * A tap shows up as a sudden jerk: a large change in acceleration magnitude
   * between two consecutive samples. Gravity and slow arm motion have a near-
   * zero jerk, so this isolates the sharp tap impulse. A debounce avoids one
   * tap registering many times; each accepted tap holds the brake briefly, and
   * repeated taps keep extending it.
   */
  private detectFingerTap(x: number, y: number, z: number): void {
    const mag: number = Math.sqrt(x * x + y * y + z * z);
    const jerk: number = Math.abs(mag - this.prevAccelMag);
    this.prevAccelMag = mag;

    const now: number = Date.now();
    if (jerk > this.tapJerkThreshold && now - this.lastTapTs > this.tapDebounceMs) {
      this.lastTapTs = now;
      this.gestureBrakeUntil = now + this.gestureHoldMs;
    }
  }

  private unsubscribeSensors(): void {
    if (!this.sensorSubscribed) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (err) {
      const e = err as BusinessError;
      console.error(`Accelerometer off failed: ${e.code} ${e.message}`);
    }
    this.sensorSubscribed = false;
  }

  /** One frame: compute the time delta, update, draw. */
  private tick(): void {
    const now: number = Date.now();
    let dt: number = this.lastTs === 0 ? 0.016 : (now - this.lastTs) / 1000;
    this.lastTs = now;
    if (dt > 0.05) {
      dt = 0.05; // avoid a big jump after a stall
    }

    // Combine brake sources (button + finger-tap gesture) before stepping the engine.
    const brakeActive: boolean = this.manualBrake || now < this.gestureBrakeUntil;
    this.engine.setBrake(brakeActive);
    if (this.braking !== brakeActive) {
      this.braking = brakeActive;
    }

    this.roadOffset = (this.roadOffset + this.engine.speed * dt) % 44;
    this.engine.update(dt);
    this.updateSmoke(dt);

    this.score = this.engine.score;
    this.status = this.engine.status;

    this.draw();

    if (this.engine.status === GameStatus.FAILED) {
      this.engine.setSteer(0);
      this.gestureBrakeUntil = 0;
      this.unsubscribeSensors();
      this.saveBestScore();
      this.stopLoop();
    }
  }

  // ---------------- Smoke trail ----------------

  /** Spawns and ages the smoke puffs behind the player's car. */
  private updateSmoke(dt: number): void {
    if (this.engine.status === GameStatus.RUNNING) {
      // Spawn faster as the car goes faster.
      const interval: number = Math.max(0.03, 0.12 - this.engine.speed / 8000);
      this.smokeTimer += dt;
      while (this.smokeTimer >= interval) {
        this.smokeTimer -= interval;
        this.spawnSmoke();
      }
    }

    const alive: SmokeParticle[] = [];
    for (let i = 0; i < this.smoke.length; i++) {
      const p = this.smoke[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.radius += 18 * dt;
      p.alpha -= 0.9 * dt;
      if (p.alpha > 0) {
        alive.push(p);
      }
    }
    this.smoke = alive;
  }

  /** Emits one puff just behind the rear bumper of the player car. */
  private spawnSmoke(): void {
    const ph: number = this.engine.carEffectiveHeight(this.engine.playerType);
    const rearY: number = this.engine.playerY + ph;
    // eslint-disable-next-line no-insecure-randomness
    const jitterX: number = (secureRandom() - 0.5) * this.engine.carWidth * 0.5;
    const baseR: number = this.engine.carWidth * 0.16;
    // eslint-disable-next-line no-insecure-randomness
    const vx: number = (secureRandom() - 0.5) * 24;
    // eslint-disable-next-line no-insecure-randomness
    const vy: number = 30 + secureRandom() * 40; // drift down (away from the car)
    this.smoke.push(new SmokeParticle(this.engine.playerX + jitterX, rearY, baseR, vx, vy));
  }

  private saveBestScore(): void {
    const best: number | undefined = AppStorage.get<number>(KEY_BEST_SCORE);
    const prev: number = best === undefined ? 0 : best;
    if (this.score > prev) {
      AppStorage.setOrCreate(KEY_BEST_SCORE, this.score);
    }
  }

  // ---------------- Drawing ----------------

  private draw(): void {
    const w: number = this.engine.width;
    const h: number = this.engine.height;
    if (w === 0 || h === 0) {
      return;
    }

    // Off-road ground (desert / sand)
    this.ctx.fillStyle = '#C2A878';
    this.ctx.fillRect(0, 0, w, h);

    this.drawRoad(w, h);
    this.drawLaneMarkers(w, h);
    this.drawDecorations();
    this.drawObstacles();
    this.drawSmoke();
    this.drawPlayer();
  }

  /** The asphalt road in the middle. */
  private drawRoad(w: number, h: number): void {
    this.ctx.fillStyle = '#2B2B2B';
    this.ctx.fillRect(this.engine.roadLeft, 0, this.engine.roadWidth, h);
  }

  /** Dashed lane dividers (scrolling) + edge stripes. */
  private drawLaneMarkers(w: number, h: number): void {
    const laneW: number = this.engine.laneWidth();
    const left: number = this.engine.roadLeft;

    this.ctx.strokeStyle = '#F5F5F5';
    this.ctx.lineWidth = 3;
    this.ctx.setLineDash([24, 20]);
    for (let i = 1; i < LANE_COUNT; i++) {
      const x: number = left + laneW * i;
      this.ctx.beginPath();
      this.ctx.moveTo(x, -44 + this.roadOffset);
      this.ctx.lineTo(x, h);
      this.ctx.stroke();
    }
    this.ctx.setLineDash([]);

    // Edge stripes (road shoulders)
    this.ctx.strokeStyle = '#FDD835';
    this.ctx.lineWidth = 4;
    const rx: number = left + this.engine.roadWidth;
    this.ctx.beginPath();
    this.ctx.moveTo(left + 2, 0);
    this.ctx.lineTo(left + 2, h);
    this.ctx.moveTo(rx - 2, 0);
    this.ctx.lineTo(rx - 2, h);
    this.ctx.stroke();
  }

  /** Roadside cactus / rock / bush decorations. */
  private drawDecorations(): void {
    const decs = this.engine.decorations;
    for (let i = 0; i < decs.length; i++) {
      const d = decs[i];
      if (d.type === DecorType.CACTUS) {
        this.drawCactus(d.x, d.y, d.scale);
      } else if (d.type === DecorType.ROCK) {
        this.drawRock(d.x, d.y, d.scale);
      } else {
        this.drawBush(d.x, d.y, d.scale);
      }
    }
  }

  private drawCactus(cx: number, cy: number, s: number): void {
    const bw: number = 6 * s;
    const bh: number = 26 * s;
    this.ctx.fillStyle = '#2E7D32';
    // trunk
    this.roundRect(cx - bw / 2, cy - bh, bw, bh, bw * 0.4);
    this.ctx.fill();
    // left arm
    this.roundRect(cx - bw * 1.7, cy - bh * 0.7, bw * 0.8, bh * 0.4, bw * 0.3);
    this.ctx.fill();
    this.roundRect(cx - bw * 1.7, cy - bh * 0.7, bw * 0.8, bh * 0.15, bw * 0.3);
    this.ctx.fill();
    // right arm
    this.roundRect(cx + bw * 0.9, cy - bh * 0.85, bw * 0.8, bh * 0.4, bw * 0.3);
    this.ctx.fill();
  }

  private drawRock(cx: number, cy: number, s: number): void {
    const r: number = 9 * s;
    this.ctx.fillStyle = '#8D8D8D';
    this.ctx.beginPath();
    this.ctx.ellipse(cx, cy - r * 0.5, r, r * 0.75, 0, 0, Math.PI * 2);
    this.ctx.fill();
    this.ctx.fillStyle = '#6E6E6E';
    this.ctx.beginPath();
    this.ctx.ellipse(cx + r * 0.3, cy - r * 0.3, r * 0.5, r * 0.4, 0, 0, Math.PI * 2);
    this.ctx.fill();
  }

  private drawBush(cx: number, cy: number, s: number): void {
    const r: number = 7 * s;
    this.ctx.fillStyle = '#558B2F';
    this.ctx.beginPath();
    this.ctx.arc(cx - r * 0.6, cy - r * 0.4, r * 0.7, 0, Math.PI * 2);
    this.ctx.arc(cx + r * 0.6, cy - r * 0.4, r * 0.7, 0, Math.PI * 2);
    this.ctx.arc(cx, cy - r, r * 0.85, 0, Math.PI * 2);
    this.ctx.fill();
  }

  private drawObstacles(): void {
    const obstacles = this.engine.obstacles;
    for (let i = 0; i < obstacles.length; i++) {
      const ob = obstacles[i];
      this.drawCar(this.engine.laneCenterX(ob.lane), ob.y, ob.color, ob.type, false);
    }
  }

  /** Draws the smoke puffs as soft grey circles. */
  private drawSmoke(): void {
    for (let i = 0; i < this.smoke.length; i++) {
      const p = this.smoke[i];
      const a: number = p.alpha < 0 ? 0 : p.alpha;
      this.ctx.fillStyle = `rgba(170,170,170,${a.toFixed(3)})`;
      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      this.ctx.fill();
    }
  }

  private drawPlayer(): void {
    this.drawCar(this.engine.playerX, this.engine.playerY, '#43A047',
      this.engine.playerType, this.engine.braking);
  }

  /**
   * Draws a single car (wheels + body + cabin) based on its type.
   * cx = horizontal center; y = top of the body.
   */
  private drawCar(cx: number, y: number, color: string, type: CarType, brakeLights: boolean): void {
    const spec = carSpec(type);
    const cw: number = this.engine.carWidth * spec.widthFactor;
    const ch: number = this.engine.carHeight * spec.lengthFactor;
    const x: number = cx - cw / 2;
    const r: number = cw * 0.18;

    // Wheels (drawn first, so the body overlaps their inner edge)
    this.drawWheels(x, y, cw, ch, spec.axles);

    // Body
    this.ctx.fillStyle = color;
    this.roundRect(x, y, cw, ch, r);
    this.ctx.fill();

    // Pickup: darker open cargo bed at the rear.
    if (type === CarType.PICKUP) {
      this.ctx.fillStyle = 'rgba(0,0,0,0.28)';
      this.roundRect(x + cw * 0.16, y + ch * 0.45, cw * 0.68, ch * 0.42, r * 0.5);
      this.ctx.fill();
    }

    // Cabin / windows depend on the body style.
    this.ctx.fillStyle = 'rgba(255,255,255,0.75)';
    if (spec.cabin === 2) {
      // Boxy (van / truck / bus): two stacked window bands.
      this.roundRect(x + cw * 0.16, y + ch * 0.10, cw * 0.68, ch * 0.18, r * 0.4);
      this.ctx.fill();
      this.roundRect(x + cw * 0.16, y + ch * 0.34, cw * 0.68, ch * 0.18, r * 0.4);
      this.ctx.fill();
    } else if (spec.cabin === 1) {
      // Sports: a low centered canopy.
      this.roundRect(x + cw * 0.22, y + ch * 0.30, cw * 0.56, ch * 0.34, r * 0.5);
      this.ctx.fill();
    } else {
      // Front cabin (sedan / pickup): a windshield near the front.
      this.roundRect(x + cw * 0.18, y + ch * 0.16, cw * 0.64, ch * 0.24, r * 0.5);
      this.ctx.fill();
    }

    // Rear brake lights while braking
    if (brakeLights) {
      this.ctx.fillStyle = '#FF1744';
      const lw: number = cw * 0.22;
      const lh: number = ch * 0.06;
      this.roundRect(x + cw * 0.12, y + ch - lh - 2, lw, lh, 2);
      this.ctx.fill();
      this.roundRect(x + cw - cw * 0.12 - lw, y + ch - lh - 2, lw, lh, 2);
      this.ctx.fill();
    }
  }

  /** Draws wheel pairs along both sides of a car body. */
  private drawWheels(x: number, y: number, cw: number, ch: number, axles: number): void {
    const wheelW: number = cw * 0.16;
    const wheelH: number = cw * 0.42;
    const leftX: number = x - wheelW * 0.5;
    const rightX: number = x + cw - wheelW * 0.5;

    // Vertical center of each axle along the body.
    let positions: number[];
    if (axles >= 3) {
      positions = [y + ch * 0.16, y + ch * 0.5, y + ch * 0.84];
    } else {
      positions = [y + ch * 0.18, y + ch * 0.82];
    }

    this.ctx.fillStyle = '#1A1A1A';
    for (let i = 0; i < positions.length; i++) {
      const wy: number = positions[i] - wheelH / 2;
      this.roundRect(leftX, wy, wheelW, wheelH, wheelW * 0.4);
      this.ctx.fill();
      this.roundRect(rightX, wy, wheelW, wheelH, wheelW * 0.4);
      this.ctx.fill();
    }
  }

  private roundRect(x: number, y: number, w: number, h: number, r: number): void {
    this.ctx.beginPath();
    this.ctx.moveTo(x + r, y);
    this.ctx.arcTo(x + w, y, x + w, y + h, r);
    this.ctx.arcTo(x + w, y + h, x, y + h, r);
    this.ctx.arcTo(x, y + h, x, y, r);
    this.ctx.arcTo(x, y, x + w, y, r);
    this.ctx.closePath();
  }

  // ---------------- UI ----------------

  build() {
    Stack() {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .backgroundColor('#C2A878')
        .onReady(() => {
          this.onCanvasReady();
        })

      // In-game controls
      if (this.status === GameStatus.RUNNING) {
        // Touch mode: hold the left/right region to steer.
        if (this.controlMode === ControlMode.TOUCH) {
          Row() {
            Column()
              .width('50%')
              .height('100%')
              .onTouch((e: TouchEvent) => {
                this.handleSteerTouch(e, -1);
              })
            Column()
              .width('50%')
              .height('100%')
              .onTouch((e: TouchEvent) => {
                this.handleSteerTouch(e, 1);
              })
          }
          .width('100%')
          .height('100%')
        }

        // Score
        Text(`${this.score}`)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .position({ x: 0, y: 6 })
          .width('100%')
          .textAlign(TextAlign.Center)
          .hitTestBehavior(HitTestMode.None)

        // Brake button (both modes, bottom center)
        Button(this.str().brake)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.braking ? '#FF1744' : 'rgba(229,57,53,0.55)')
          .borderRadius(22)
          .width(74)
          .height(44)
          .margin({ bottom: 10 })
          .onTouch((e: TouchEvent) => {
            this.handleBrakeTouch(e);
          })
      }

      // Game over screen
      if (this.status === GameStatus.FAILED) {
        this.GameOverPanel()
      }
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
    .backgroundColor('#000000')
  }

  private handleSteerTouch(e: TouchEvent, dir: number): void {
    const t: TouchType = e.type;
    if (t === TouchType.Down || t === TouchType.Move) {
      this.engine.setSteer(dir);
    } else if (t === TouchType.Up || t === TouchType.Cancel) {
      this.engine.setSteer(0);
    }
  }

  private handleBrakeTouch(e: TouchEvent): void {
    const t: TouchType = e.type;
    if (t === TouchType.Down) {
      this.manualBrake = true;
    } else if (t === TouchType.Up || t === TouchType.Cancel) {
      this.manualBrake = false;
    }
  }

  @Builder
  GameOverPanel() {
    Column({ space: 12 }) {
      Text(this.str().crashed)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Text(`${this.str().score}: ${this.score}`)
        .fontSize(15)
        .fontColor('#BDBDBD')
      Row({ space: 10 }) {
        Button(this.str().retry)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor('#43A047')
          .borderRadius(22)
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .onClick(() => {
            this.startGame();
          })
        Button(this.str().menu)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor('#546E7A')
          .borderRadius(22)
          .padding({ left: 18, right: 18, top: 8, bottom: 8 })
          .onClick(() => {
            this.pageStack.pop()
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('rgba(0,0,0,0.6)')
  }
}
