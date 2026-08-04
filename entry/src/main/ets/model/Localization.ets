
export enum Language {
  TR = 0, // Türkçe
  EN = 1, // English
  ZH = 2  // 中文 (Simplified Chinese)
}

export const KEY_LANGUAGE: string = 'language';

export interface Strings {
  appTitle: string;
  best: string;
  start: string;
  settings: string;
  controlTouch: string;
  controlTilt: string;
  controlLabelTouch: string;
  controlLabelTilt: string;
  // Settings page
  settingsTitle: string;
  sectionControl: string;
  controlHintTouch: string;
  controlHintTilt: string;
  sensitivity: string;
  sectionLanguage: string;
  sectionGesture: string;
  gestureBrake: string;
  gestureHint: string;
  on: string;
  off: string;
  back: string;
  // Game page
  brake: string;
  crashed: string;
  score: string;
  retry: string;
  menu: string;
}

const TR_STRINGS: Strings = {
  appTitle: 'ENDLESS RIDE',
  best: 'En iyi',
  start: 'BAŞLA',
  settings: 'AYARLAR',
  controlTouch: 'Dokunma',
  controlTilt: 'Eğim (Sensör)',
  controlLabelTouch: 'Kontrol: Dokunma',
  controlLabelTilt: 'Kontrol: Eğim',
  settingsTitle: 'AYARLAR',
  sectionControl: 'Araç Kontrolü',
  controlHintTouch: 'Sol/sağ bölgeyi basılı tutarak sürersin.',
  controlHintTilt: 'Saati sağa/sola eğerek sürersin.',
  sensitivity: 'Duyarlılık',
  sectionLanguage: 'Dil',
  sectionGesture: 'El Hareketi',
  gestureBrake: 'El hareketiyle fren',
  gestureHint: 'Ekrana dokunmadan baş parmağınla bir parmağına vurarak (tık) fren yaparsın.',
  on: 'Açık',
  off: 'Kapalı',
  back: 'GERİ',
  brake: 'FREN',
  crashed: 'ÇARPTIN!',
  score: 'Skor',
  retry: 'TEKRAR',
  menu: 'MENÜ'
};

const EN_STRINGS: Strings = {
  appTitle: 'ENDLESS RIDE',
  best: 'Best',
  start: 'START',
  settings: 'SETTINGS',
  controlTouch: 'Touch',
  controlTilt: 'Tilt (Sensor)',
  controlLabelTouch: 'Control: Touch',
  controlLabelTilt: 'Control: Tilt',
  settingsTitle: 'SETTINGS',
  sectionControl: 'Vehicle Control',
  controlHintTouch: 'Hold the left/right half to steer.',
  controlHintTilt: 'Tilt the watch left/right to steer.',
  sensitivity: 'Sensitivity',
  sectionLanguage: 'Language',
  sectionGesture: 'Hand Gesture',
  gestureBrake: 'Brake with hand gesture',
  gestureHint: 'Tap your thumb against a finger (no screen touch) to brake.',
  on: 'On',
  off: 'Off',
  back: 'BACK',
  brake: 'BRAKE',
  crashed: 'CRASHED!',
  score: 'Score',
  retry: 'RETRY',
  menu: 'MENU'
};

const ZH_STRINGS: Strings = {
  appTitle: 'ENDLESS RIDE',
  best: '最高',
  start: '开始',
  settings: '设置',
  controlTouch: '触摸',
  controlTilt: '倾斜（传感器）',
  controlLabelTouch: '控制：触摸',
  controlLabelTilt: '控制：倾斜',
  settingsTitle: '设置',
  sectionControl: '车辆控制',
  controlHintTouch: '按住左/右半屏进行转向。',
  controlHintTilt: '左右倾斜手表进行转向。',
  sensitivity: '灵敏度',
  sectionLanguage: '语言',
  sectionGesture: '手势',
  gestureBrake: '手势刹车',
  gestureHint: '无需触屏，用拇指轻叩手指即可刹车。',
  on: '开',
  off: '关',
  back: '返回',
  brake: '刹车',
  crashed: '撞车了！',
  score: '得分',
  retry: '重试',
  menu: '菜单'
};

function isValidLanguage(lang: number): boolean {
  return lang === Language.TR || lang === Language.EN || lang === Language.ZH;
}

export function getStrings(lang: number): Strings {
  if (!isValidLanguage(lang)) {
    throw new RangeError(`getStrings: invalid language value "${lang}". Expected a Language enum member (0=TR, 1=EN, 2=ZH).`);
  }
  if (lang === Language.EN) {
    return EN_STRINGS;
  } else if (lang === Language.ZH) {
    return ZH_STRINGS;
  }
  return TR_STRINGS;
}

export function languageName(lang: number): string {
  if (!isValidLanguage(lang)) {
    throw new RangeError(`languageName: invalid language value "${lang}". Expected a Language enum member (0=TR, 1=EN, 2=ZH).`);
  }
  if (lang === Language.EN) {
    return 'English';
  } else if (lang === Language.ZH) {
    return '中文';
  }
  return 'Türkçe';
}
