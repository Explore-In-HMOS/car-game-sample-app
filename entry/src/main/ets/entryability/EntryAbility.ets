import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { ControlMode, KEY_BEST_SCORE, KEY_CONTROL_MODE, KEY_GESTURE_BRAKE, KEY_TILT_SENS } from '../model/GameTypes';
import { KEY_LANGUAGE, Language } from '../model/Localization';
const DOMAIN: number = 0x0000;
const TAG: string = 'EndlessRide';

function initPersistentDefaults(): void {
  PersistentStorage.persistProp(KEY_CONTROL_MODE, ControlMode.TOUCH);
  PersistentStorage.persistProp(KEY_BEST_SCORE, 0);
  PersistentStorage.persistProp(KEY_TILT_SENS, 1.0);
  PersistentStorage.persistProp(KEY_GESTURE_BRAKE, false);
  PersistentStorage.persistProp(KEY_LANGUAGE, Language.TR);
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    initPersistentDefaults();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'loadContent succeeded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
