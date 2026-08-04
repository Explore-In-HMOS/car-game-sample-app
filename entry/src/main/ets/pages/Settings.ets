import { ControlMode } from '../model/GameTypes';
import { getStrings, Language, languageName, Strings } from '../model/Localization';

/**
 * Settings page.
 * Selects the steering method (Touch / Tilt), the tilt sensitivity, the UI
 * language (Turkish / English / Chinese) and the Huawei wearable hand-gesture
 * brake. Choices are persisted via AppStorage + PersistentStorage.
 */
@Entry
@Component
struct Settings {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack()
  @StorageLink('controlMode') controlMode: number = ControlMode.TOUCH;
  @StorageLink('tiltSensitivity') tiltSensitivity: number = 1.0;
  @StorageLink('gestureBrake') gestureBrake: boolean = false;
  @StorageLink('language') language: number = Language.TR;
   supportedLanguages = [Language.TR, Language.EN, Language.ZH];

  /** Convenience accessor for the localized strings. */
  private str(): Strings {
    return getStrings(this.language);
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text(this.str().settingsTitle)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ top: 8 })

        // ----- Language selection -----
        Text(this.str().sectionLanguage)
          .fontSize(13)
          .fontColor('#9E9E9E')

        Row({ space: 8 }) {
          ForEach(this.supportedLanguages, (language: Language) => {
            this.LanguageButton(language)
          }, (language: Language) => language.toString())
        }

        // ----- Vehicle control -----
        Text(this.str().sectionControl)
          .fontSize(13)
          .fontColor('#9E9E9E')

        Button(this.str().controlTouch)
          .fontSize(15)
          .fontWeight(this.controlMode === ControlMode.TOUCH ? FontWeight.Bold : FontWeight.Normal)
          .fontColor('#FFFFFF')
          .backgroundColor(this.controlMode === ControlMode.TOUCH ? '#43A047' : '#37474F')
          .borderRadius(24)
          .width(160)
          .height(44)
          .onClick(() => {
            this.controlMode = ControlMode.TOUCH;
          })

        Button(this.str().controlTilt)
          .fontSize(15)
          .fontWeight(this.controlMode === ControlMode.TILT ? FontWeight.Bold : FontWeight.Normal)
          .fontColor('#FFFFFF')
          .backgroundColor(this.controlMode === ControlMode.TILT ? '#43A047' : '#37474F')
          .borderRadius(24)
          .width(160)
          .height(44)
          .onClick(() => {
            this.controlMode = ControlMode.TILT;
          })

        Text(this.controlMode === ControlMode.TILT
          ? this.str().controlHintTilt
          : this.str().controlHintTouch)
          .fontSize(11)
          .fontColor('#9E9E9E')
          .textAlign(TextAlign.Center)
          .width('86%')

        // Tilt sensitivity (only meaningful in tilt mode)
        if (this.controlMode === ControlMode.TILT) {
          Text(`${this.str().sensitivity}: ${this.tiltSensitivity.toFixed(1)}x`)
            .fontSize(13)
            .fontColor('#FDD835')
          Slider({
            value: this.tiltSensitivity,
            min: 0.5,
            max: 2.0,
            step: 0.1,
            style: SliderStyle.OutSet
          })
            .width('80%')
            .selectedColor('#43A047')
            .onChange((value: number) => {
              this.tiltSensitivity = value;
            })
        }

        // ----- Hand-gesture brake (Huawei wearable) -----
        Text(this.str().sectionGesture)
          .fontSize(13)
          .fontColor('#9E9E9E')

        Button(`${this.str().gestureBrake}: ${this.gestureBrake ? this.str().on : this.str().off}`)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(this.gestureBrake ? '#43A047' : '#37474F')
          .borderRadius(24)
          .width(180)
          .height(44)
          .onClick(() => {
            this.gestureBrake = !this.gestureBrake;
          })

        Text(this.str().gestureHint)
          .fontSize(11)
          .fontColor('#9E9E9E')
          .textAlign(TextAlign.Center)
          .width('86%')

        Button(this.str().back)
          .fontSize(15)
          .fontColor('#FFFFFF')
          .backgroundColor('#546E7A')
          .borderRadius(24)
          .width(160)
          .height(44)
          .margin({ bottom: 12 })
          .onClick(() => {
            this.pageStack.pop()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor('#1A1A1A')
  }

  /** A single language selector chip. */
  @Builder
  LanguageButton(lang: number) {
    Button(languageName(lang))
      .fontSize(13)
      .fontWeight(this.language === lang ? FontWeight.Bold : FontWeight.Normal)
      .fontColor('#FFFFFF')
      .backgroundColor(this.language === lang ? '#43A047' : '#37474F')
      .borderRadius(20)
      .height(40)
      .padding({ left: 12, right: 12 })
      .onClick(() => {
        this.language = lang;
      })
  }
}
