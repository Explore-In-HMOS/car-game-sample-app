
export const LANE_COUNT: number = 4;

export enum GameStatus {
  READY = 0,   // Ready to start
  RUNNING = 1, // Playing
  FAILED = 2   // Crashed / game over
}

export enum ControlMode {
  TOUCH = 0, // By touch (left/right region)
  TILT = 1   // By tilting the watch left/right (accelerometer)
}

export const KEY_CONTROL_MODE: string = 'controlMode';
export const KEY_BEST_SCORE: string = 'bestScore';
export const KEY_TILT_SENS: string = 'tiltSensitivity';
export const KEY_GESTURE_BRAKE: string = 'gestureBrake';

export enum CarType {
  SEDAN = 0,  // Standard car
  SPORTS = 1, // Short, wide sports car
  TRUCK = 2,  // Long cargo truck (3 axles)
  VAN = 3,    // Tall boxy van
  BUS = 4,    // Long bus (3 axles)
  PICKUP = 5  // Pickup with an open bed
}

export const CAR_TYPE_COUNT: number = 6;

export class CarSpec {
  widthFactor: number;
  lengthFactor: number;
  cabin: number;
  axles: number;

  constructor(widthFactor: number, lengthFactor: number, cabin: number, axles: number) {
    this.widthFactor = widthFactor;
    this.lengthFactor = lengthFactor;
    this.cabin = cabin;
    this.axles = axles;
  }
}

export function carSpec(type: CarType): CarSpec {
  switch (type) {
    case CarType.SPORTS:
      return new CarSpec(1.0, 0.92, 1, 2);
    case CarType.TRUCK:
      return new CarSpec(0.96, 1.5, 2, 3);
    case CarType.VAN:
      return new CarSpec(0.98, 1.2, 2, 2);
    case CarType.BUS:
      return new CarSpec(0.94, 1.55, 2, 3);
    case CarType.PICKUP:
      return new CarSpec(0.95, 1.15, 0, 2);
    case CarType.SEDAN:
    default:
      return new CarSpec(0.92, 1.0, 0, 2);
  }
}

export class CarEntity {
  lane: number;
  y: number;
  color: string;
  type: CarType;

  constructor(lane: number, y: number, color: string, type: CarType) {
    this.lane = lane;
    this.y = y;
    this.color = color;
    this.type = type;
  }
}

export enum DecorType {
  CACTUS = 0, // Cactus
  ROCK = 1,   // Rock / stone
  BUSH = 2    // Bush
}

export class Decoration {
  x: number;
  y: number;
  type: DecorType;
  scale: number;

  constructor(x: number, y: number, type: DecorType, scale: number) {
    this.x = x;
    this.y = y;
    this.type = type;
    this.scale = scale;
  }
}

export const OBSTACLE_COLORS: string[] = [
  '#D81B60', // pink
  '#5E35B1', // deep purple
  '#1E88E5', // blue
  '#039BE5', // light blue
  '#00ACC1', // cyan
  '#43A047', // green
  '#7CB342', // light green
  '#C0CA33', // lime
  '#FDD835', // yellow
  '#FFB300', // amber
  '#F4511E', // deep orange
  '#6D4C41', // brown
  '#757575', // gray
  '#546E7A', // blue gray
  '#E91E63', // pink
  '#9C27B0', // purple
  '#3F51B5', // indigo
  '#009688', // teal
  '#4CAF50', // green
  '#FF5722', // deep orange
];
