import {
  CarEntity,
  carSpec,
  CarType,
  CAR_TYPE_COUNT,
  Decoration,
  DecorType,
  GameStatus,
  LANE_COUNT,
  OBSTACLE_COLORS
} from './GameTypes';
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

export class GameEngine {
  width: number = 0;
  height: number = 0;

  roadLeft: number = 0;
  roadWidth: number = 0;

  status: GameStatus = GameStatus.READY;
  score: number = 0;

  playerX: number = 0;
  carWidth: number = 0;
  carHeight: number = 0;
  playerY: number = 0;
  playerType: CarType = CarType.SPORTS;

  steerInput: number = 0;
  private readonly steerLanesPerSec: number = 3.4;

  braking: boolean = false;

  obstacles: CarEntity[] = [];
  decorations: Decoration[] = [];

  speed: number = 170;
  cruiseSpeed: number = 170;
  private readonly baseSpeed: number = 170;
  private readonly minSpeed: number = 70;
  private readonly maxSpeed: number = 620;
  private readonly acceleration: number = 12;   // px/s^2 (automatic speed-up of the cruise speed)
  private readonly brakeDecel: number = 360;     // px/s^2 (braking)
  private readonly recoveryAccel: number = 260;  // px/s^2 (catching back up to cruise after braking)
  private readonly brakeFloorRatio: number = 0.6;

  private spawnTimer: number = 0;
  private spawnInterval: number = 1.3; // seconds
  private decorTimer: number = 0;
  private decorInterval: number = 0.55; // seconds

  init(width: number, height: number): void {
    this.width = width;
    this.height = height;

    this.roadWidth = width * 0.66;
    this.roadLeft = (width - this.roadWidth) / 2;

    this.carWidth = this.laneWidth() * 0.68;
    this.carHeight = this.carWidth * 1.7;
    this.playerY = height - this.carHeight - height * 0.08;
    this.reset();
  }

  laneWidth(): number {
    return this.roadWidth / LANE_COUNT;
  }

  laneCenterX(lane: number): number {
    return this.roadLeft + this.laneWidth() * (lane + 0.5);
  }

  carEffectiveHeight(type: CarType): number {
    return this.carHeight * carSpec(type).lengthFactor;
  }

  private minPlayerX(): number {
    return this.roadLeft + this.carWidth / 2;
  }

  private maxPlayerX(): number {
    return this.roadLeft + this.roadWidth - this.carWidth / 2;
  }

  reset(): void {
    this.status = GameStatus.READY;
    this.score = 0;
    this.playerX = this.roadLeft + this.roadWidth / 2;
    this.steerInput = 0;
    this.braking = false;
    this.speed = this.baseSpeed;
    this.cruiseSpeed = this.baseSpeed;
    this.obstacles = [];
    this.decorations = [];
    this.spawnTimer = 0;
    this.spawnInterval = 1.3;
    this.decorTimer = 0;
    this.seedDecorations();
  }

  start(): void {
    this.reset();
    this.status = GameStatus.RUNNING;
  }

  setSteer(value: number): void {
    if (value < -1) {
      value = -1;
    } else if (value > 1) {
      value = 1;
    }
    this.steerInput = value;
  }

  setBrake(on: boolean): void {
    this.braking = on;
  }

  update(dt: number): void {
    if (this.status !== GameStatus.RUNNING) {
      return;
    }

    this.cruiseSpeed = Math.min(this.maxSpeed, this.cruiseSpeed + this.acceleration * dt);

    if (this.braking) {
      const floor: number = Math.max(this.minSpeed, this.cruiseSpeed * this.brakeFloorRatio);
      this.speed = Math.max(floor, this.speed - this.brakeDecel * dt);
    } else if (this.speed < this.cruiseSpeed) {
      this.speed = Math.min(this.cruiseSpeed, this.speed + this.recoveryAccel * dt);
    } else {
      this.speed = this.cruiseSpeed;
    }

    if (this.steerInput !== 0) {
      const dx: number = this.steerInput * this.steerLanesPerSec * this.laneWidth() * dt;
      this.playerX += dx;
      const lo: number = this.minPlayerX();
      const hi: number = this.maxPlayerX();
      if (this.playerX < lo) {
        this.playerX = lo;
      } else if (this.playerX > hi) {
        this.playerX = hi;
      }
    }

    for (let i = 0; i < this.obstacles.length; i++) {
      this.obstacles[i].y += this.speed * dt;
    }

    const survivors: CarEntity[] = [];
    for (let i = 0; i < this.obstacles.length; i++) {
      const ob = this.obstacles[i];
      if (ob.y > this.height) {
        this.score += 1;
      } else {
        survivors.push(ob);
      }
    }
    this.obstacles = survivors;

    const decAlive: Decoration[] = [];
    for (let i = 0; i < this.decorations.length; i++) {
      const d = this.decorations[i];
      d.y += this.speed * dt;
      if (d.y <= this.height + 60) {
        decAlive.push(d);
      }
    }
    this.decorations = decAlive;

    this.spawnTimer += dt;
    if (this.spawnTimer >= this.spawnInterval) {
      this.spawnTimer = 0;
      this.spawnObstacle();
      this.spawnInterval = Math.max(0.6, this.spawnInterval - 0.02);
    }

    this.decorTimer += dt;
    if (this.decorTimer >= this.decorInterval) {
      this.decorTimer = 0;
      this.spawnDecoration(-this.height * 0.15);
    }

    if (this.checkCollision()) {
      this.status = GameStatus.FAILED;
    }
  }

  private spawnObstacle(): void {
    // eslint-disable-next-line no-insecure-randomness
    const lane: number = Math.floor(secureRandom() * LANE_COUNT);
    // eslint-disable-next-line no-insecure-randomness
    const type: CarType = Math.floor(secureRandom() * CAR_TYPE_COUNT) as CarType;
    const spawnHeight: number = this.carEffectiveHeight(type);

    for (let i = 0; i < this.obstacles.length; i++) {
      const ob = this.obstacles[i];
      if (ob.lane === lane && ob.y < spawnHeight * 2.2) {
        return;
      }
    }
    // eslint-disable-next-line no-insecure-randomness
    const color: string = OBSTACLE_COLORS[Math.floor(secureRandom() * OBSTACLE_COLORS.length)];
    this.obstacles.push(new CarEntity(lane, -spawnHeight * 2.5, color, type));
  }

  private seedDecorations(): void {
    const count: number = 6;
    for (let i = 0; i < count; i++) {
      // eslint-disable-next-line no-insecure-randomness
      this.spawnDecoration(secureRandom() * this.height);
    }
  }

  private spawnDecoration(y: number): void {
    // eslint-disable-next-line no-insecure-randomness
    const rightSide: boolean = secureRandom() < 0.5;
    const margin: number = this.roadLeft; // width of one side band
    if (margin < 12) {
      return;
    }
    let x: number;
    if (rightSide) {
      const start: number = this.roadLeft + this.roadWidth;
      // eslint-disable-next-line no-insecure-randomness
      x = start + margin * (0.15 + secureRandom() * 0.7);
    } else {
      // eslint-disable-next-line no-insecure-randomness
      x = margin * (0.15 + secureRandom() * 0.7);
    }
    // eslint-disable-next-line no-insecure-randomness
    const roll: number = secureRandom();
    let type: DecorType;
    if (roll < 0.45) {
      type = DecorType.CACTUS;
    } else if (roll < 0.8) {
      type = DecorType.ROCK;
    } else {
      type = DecorType.BUSH;
    }
    // eslint-disable-next-line no-insecure-randomness
    const scale: number = 0.7 + secureRandom() * 0.6;
    this.decorations.push(new Decoration(x, y, type, scale));
  }

  private checkCollision(): boolean {
    const px: number = this.playerX - this.carWidth / 2;
    const py: number = this.playerY;
    const ph: number = this.carEffectiveHeight(this.playerType);

    for (let i = 0; i < this.obstacles.length; i++) {
      const ob = this.obstacles[i];
      const ox: number = this.laneCenterX(ob.lane) - this.carWidth / 2;
      const oy: number = ob.y;
      const oh: number = this.carEffectiveHeight(ob.type);

      const overlapX: boolean = px < ox + this.carWidth && px + this.carWidth > ox;
      const overlapY: boolean = py < oy + oh && py + ph > oy;
      if (overlapX && overlapY) {
        return true;
      }
    }
    return false;
  }
}
