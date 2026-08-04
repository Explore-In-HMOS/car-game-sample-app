import { ControlMode, KEY_BEST_SCORE, KEY_CONTROL_MODE, KEY_GESTURE_BRAKE, KEY_TILT_SENS } from '../model/GameTypes';
import { getStrings, KEY_LANGUAGE, Language, Strings } from '../model/Localization';

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack()
  @StorageLink('bestScore') bestScore: number = 0;
  @StorageLink('controlMode') controlMode: number = ControlMode.TOUCH;
  @StorageLink('language') language: number = Language.TR;

  private str(): Strings {
    return getStrings(this.language);
  }

  build() {
    Column({ space: 14 }) {
      Text(this.str().appTitle)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')

      Text(`${this.str().best}: ${this.bestScore}`)
        .fontSize(14)
        .fontColor('#FDD835')

      Button(this.str().start)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor('#43A047')
        .borderRadius(26)
        .width(150)
        .height(48)
        .onClick(() => {
          this.pageStack.pushPathByName('pages/Game',null)
        })

      Button(this.str().settings)
        .fontSize(16)
        .fontColor('#FFFFFF')
        .backgroundColor('#546E7A')
        .borderRadius(26)
        .width(150)
        .height(44)
        .onClick(() => {
          this.pageStack.pushPathByName('pages/Settings',null)

        })

      Text(this.controlMode === ControlMode.TILT
        ? this.str().controlLabelTilt
        : this.str().controlLabelTouch)
        .fontSize(12)
        .fontColor('#9E9E9E')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#1A1A1A')
  }
}
