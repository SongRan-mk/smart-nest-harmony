import { ActuatorDevice, BaseDevice, SensorDevice } from '../model/DeviceModels';
import { SmartHomeStore } from '../service/SmartHomeStore';

/**
 * 智巢全屋交互式数字孪生户型沙盘组件
 * 使用 @Watch + 显式 @State 同步全部房间与设备状态，确保 ArkUI 细粒度精准刷新
 */
@Component
export struct HomeFloorPlan {
  @Prop @Watch('syncSnapshot') revision: number = 0;

  onSelectDevice: (deviceId: string) => void = () => {};
  onToggleActuator: (deviceId: string) => void = () => {};

  @State virtualTime: string = '14:00';
  @State livingTemp: number = 25.4;
  @State livingTempOnline: boolean = true;
  @State livingHumi: number = 54;
  @State livingHumiOnline: boolean = true;
  @State livingLux: number = 320;
  @State livingLuxOnline: boolean = true;

  @State livingLightOn: boolean = false;
  @State livingLightOnline: boolean = true;
  @State livingLightLevel: number = 75;

  @State livingAcOn: boolean = false;
  @State livingAcOnline: boolean = true;
  @State livingAcLevel: number = 25;

  @State curtainOn: boolean = true;
  @State curtainLevel: number = 65;

  @State balconySmoke: number = 18;
  @State balconySmokeOnline: boolean = true;
  @State sirenOn: boolean = false;
  @State sirenOnline: boolean = true;

  @State bedroomMotion: number = 1;
  @State bedroomMotionOnline: boolean = true;
  @State bedroomLightOn: boolean = false;
  @State bedroomLightOnline: boolean = true;
  @State bedroomLightLevel: number = 40;
  @State purifierOn: boolean = true;
  @State purifierOnline: boolean = true;
  @State purifierLevel: number = 50;

  @State studyLampOn: boolean = true;
  @State studyLampOnline: boolean = true;
  @State studyLampLevel: number = 85;
  @State entryLockOn: boolean = true;
  @State entryLockOnline: boolean = true;

  private store: SmartHomeStore = SmartHomeStore.getInstance();

  aboutToAppear(): void {
    this.syncSnapshot();
  }

  private readSensor(id: string, fallback: number): number {
    const dev: BaseDevice | undefined = this.store.getDeviceById(id);
    if (dev instanceof SensorDevice && dev.online) {
      return dev.value;
    }
    return fallback;
  }

  private readOnline(id: string): boolean {
    const dev = this.store.getDeviceById(id);
    return dev ? dev.online : false;
  }

  private readActuatorOn(id: string): boolean {
    const dev = this.store.getDeviceById(id);
    return (dev instanceof ActuatorDevice) && dev.online && dev.powerOn;
  }

  private readActuatorLevel(id: string, fallback: number): number {
    const dev = this.store.getDeviceById(id);
    if (dev instanceof ActuatorDevice) {
      return dev.levelValue;
    }
    return fallback;
  }

  syncSnapshot(): void {
    this.virtualTime = this.store.getCurrentVirtualTimeText();

    this.livingTempOnline = this.readOnline('sensor_living_temp');
    this.livingTemp = this.readSensor('sensor_living_temp', 25.4);
    this.livingHumiOnline = this.readOnline('sensor_living_humi');
    this.livingHumi = this.readSensor('sensor_living_humi', 54);
    this.livingLuxOnline = this.readOnline('sensor_living_light');
    this.livingLux = this.readSensor('sensor_living_light', 320);

    this.livingLightOnline = this.readOnline('act_living_light');
    this.livingLightOn = this.readActuatorOn('act_living_light');
    this.livingLightLevel = this.readActuatorLevel('act_living_light', 75);

    this.livingAcOnline = this.readOnline('act_living_ac');
    this.livingAcOn = this.readActuatorOn('act_living_ac');
    this.livingAcLevel = this.readActuatorLevel('act_living_ac', 25);

    this.curtainOn = this.readActuatorOn('act_living_curtain');
    this.curtainLevel = this.readActuatorLevel('act_living_curtain', 65);

    this.balconySmokeOnline = this.readOnline('sensor_balcony_smoke');
    this.balconySmoke = this.readSensor('sensor_balcony_smoke', 18);
    this.sirenOnline = this.readOnline('act_balcony_siren');
    this.sirenOn = this.readActuatorOn('act_balcony_siren');

    this.bedroomMotionOnline = this.readOnline('sensor_bedroom_motion');
    this.bedroomMotion = this.readSensor('sensor_bedroom_motion', 0);
    this.bedroomLightOnline = this.readOnline('act_bedroom_light');
    this.bedroomLightOn = this.readActuatorOn('act_bedroom_light');
    this.bedroomLightLevel = this.readActuatorLevel('act_bedroom_light', 40);
    this.purifierOnline = this.readOnline('act_bedroom_purifier');
    this.purifierOn = this.readActuatorOn('act_bedroom_purifier');
    this.purifierLevel = this.readActuatorLevel('act_bedroom_purifier', 50);

    this.studyLampOnline = this.readOnline('act_study_lamp');
    this.studyLampOn = this.readActuatorOn('act_study_lamp');
    this.studyLampLevel = this.readActuatorLevel('act_study_lamp', 85);
    this.entryLockOnline = this.readOnline('act_entry_lock');
    this.entryLockOn = this.readActuatorOn('act_entry_lock');
  }

  private isDarkAmbient(): boolean {
    return this.livingLux < 150;
  }

  private getLivingBg(): string {
    if (this.livingLightOn) {
      return this.livingLightLevel >= 60 ? '#FFF6D6' : '#FEF9E7';
    }
    return this.isDarkAmbient() ? '#1E293B' : '#F8FAFC';
  }

  private getBedroomBg(): string {
    if (this.bedroomLightOn) {
      return '#FEF3C7';
    }
    return this.isDarkAmbient() ? '#1E293B' : '#F8FAFC';
  }

  private getStudyBg(): string {
    if (this.studyLampOn) {
      return '#FFFBEB';
    }
    return this.isDarkAmbient() ? '#1E293B' : '#F8FAFC';
  }

  private getBalconyBg(): string {
    if (this.balconySmoke >= 120 || this.sirenOn) {
      return '#FFE4E6';
    }
    return this.isDarkAmbient() ? '#334155' : '#ECFDF5';
  }

  private getRoomTitleColor(isLit: boolean): string {
    if (isLit) {
      return '#1A2233';
    }
    return this.isDarkAmbient() ? '#F1F5F9' : '#1A2233';
  }

  private getCurtainLeafWidth(): number {
    const openPct = this.curtainOn ? this.curtainLevel : 0;
    return Math.max(4, Math.round(30 * (1 - openPct / 100)));
  }

  build() {
    Column({ space: 10 }) {
      // 标题行
      Row() {
        Column({ space: 2 }) {
          Text('全屋数字孪生沙盘')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A2233')
          Text('点击执行器直接开关 · 点击传感角标调参')
            .fontSize(11)
            .fontColor('#6E7787')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text(`${this.virtualTime} · ${this.isDarkAmbient() ? '夜间弱光' : '日间采光'}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDarkAmbient() ? '#FDE68A' : '#1677FF')
          .backgroundColor(this.isDarkAmbient() ? '#1E293B' : '#E6F4FF')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
      }
      .width('100%')

      // 户型沙盘平面图主体
      Column({ space: 6 }) {
        // 第一排：客厅 (左) + 阳台 (右)
        Row({ space: 6 }) {
          // 客厅区域
          Column({ space: 8 }) {
            Row() {
              Text('客厅')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.livingLightOn))

              Blank()

              // 动态窗帘可视化窗户
              Stack() {
                Row()
                  .width('100%')
                  .height('100%')
                  .backgroundColor(this.isDarkAmbient() ? '#0F172A' : '#BAE6FD')
                  .borderRadius(4)

                Row() {
                  Row()
                    .width(this.getCurtainLeafWidth())
                    .height('100%')
                    .backgroundColor('#94A3B8')
                    .borderRadius({ topLeft: 4, bottomLeft: 4 })
                    .animation({ duration: 350, curve: Curve.EaseOut })
                  Blank()
                  Row()
                    .width(this.getCurtainLeafWidth())
                    .height('100%')
                    .backgroundColor('#94A3B8')
                    .borderRadius({ topRight: 4, bottomRight: 4 })
                    .animation({ duration: 350, curve: Curve.EaseOut })
                }
                .width('100%')
                .height('100%')
              }
              .width(66)
              .height(16)
              .border({ width: 1, color: '#64748B' })
              .borderRadius(4)
              .onClick(() => {
                this.onSelectDevice('act_living_curtain');
              })
            }
            .width('100%')

            // 环境传感读数条
            Row({ space: 4 }) {
              Text(this.livingTempOnline ? `${this.livingTemp}℃` : '离线')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.livingTemp >= 28 ? '#FFFFFF' : '#D46B08')
                .backgroundColor(this.livingTemp >= 28 ? '#FF4D4F' : '#FFF7E6')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_living_temp');
                })

              Text(this.livingHumiOnline ? `${this.livingHumi}%` : '离线')
                .fontSize(10)
                .fontColor('#1677FF')
                .backgroundColor('#E6F4FF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_living_humi');
                })

              Text(this.livingLuxOnline ? `${this.livingLux}lx` : '离线')
                .fontSize(10)
                .fontColor('#722ED1')
                .backgroundColor('#F9F0FF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_living_light');
                })
            }
            .width('100%')

            // 客厅执行器控件
            Row({ space: 6 }) {
              Column({ space: 2 }) {
                Text(!this.livingLightOnline ? '离线' : (this.livingLightOn ? '💡 亮灯' : '○ 熄灭'))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.livingLightOn ? '#D48806' : '#64748B')
                Text(!this.livingLightOnline ? '主灯' : (this.livingLightOn ? `${this.livingLightLevel}%` : '主灯'))
                  .fontSize(10)
                  .fontColor('#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 6, bottom: 6 })
              .borderRadius(10)
              .backgroundColor(this.livingLightOn ? '#FFF1B8' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_living_light');
              })

              Column({ space: 2 }) {
                Text(!this.livingAcOnline ? '离线' : (this.livingAcOn ? '❄ 制冷' : '空调'))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.livingAcOn ? '#FFFFFF' : '#64748B')
                Text(!this.livingAcOnline ? '不可用' : (this.livingAcOn ? `${this.livingAcLevel}℃` : '待机'))
                  .fontSize(10)
                  .fontColor(this.livingAcOn ? '#E6F4FF' : '#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 6, bottom: 6 })
              .borderRadius(10)
              .backgroundColor(this.livingAcOn ? '#1677FF' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_living_ac');
              })
            }
            .width('100%')

            Text(`窗帘开度 ${this.curtainOn ? this.curtainLevel : 0}%（点击调节）`)
              .fontSize(10)
              .fontColor(this.getRoomTitleColor(this.livingLightOn))
              .opacity(0.72)
              .onClick(() => {
                this.onSelectDevice('act_living_curtain');
              })
          }
          .layoutWeight(58)
          .height(148)
          .padding(10)
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.SpaceBetween)
          .backgroundColor(this.getLivingBg())
          .borderRadius(12)
          .border({ width: 1.5, color: this.livingLightOn ? '#FACC15' : '#CBD5E1' })
          .animation({ duration: 320 })

          // 阳台安防区域
          Column({ space: 8 }) {
            Row() {
              Text('阳台')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.balconySmoke >= 120))
              Blank()
              Text('安防区')
                .fontSize(10)
                .fontColor('#64748B')
            }
            .width('100%')

            Column({ space: 2 }) {
              Text('烟雾监测')
                .fontSize(10)
                .fontColor('#64748B')
              Text(this.balconySmokeOnline ? `${this.balconySmoke} ppm` : '离线')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.balconySmoke >= 120 ? '#CF1322' : '#00B578')
            }
            .width('100%')
            .padding(6)
            .borderRadius(8)
            .backgroundColor('#FFFFFF')
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              this.onSelectDevice('sensor_balcony_smoke');
            })

            Row({ space: 4 }) {
              Text(!this.sirenOnline ? '报警器离线' : (this.sirenOn ? '🚨 鸣笛告警' : '🔔 报警待机'))
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.sirenOn ? '#FFFFFF' : '#4E5969')
            }
            .width('100%')
            .padding({ top: 7, bottom: 7 })
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.sirenOn ? '#FF4D4F' : '#E2E8F0')
            .onClick(() => {
              this.onToggleActuator('act_balcony_siren');
            })
          }
          .layoutWeight(42)
          .height(148)
          .padding(10)
          .justifyContent(FlexAlign.SpaceBetween)
          .backgroundColor(this.getBalconyBg())
          .borderRadius(12)
          .border({
            width: 1.5,
            color: (this.balconySmoke >= 120 || this.sirenOn) ? '#FF4D4F' : '#CBD5E1'
          })
          .animation({ duration: 320 })
        }
        .width('100%')

        // 第二排：主卧 (左) + 书房与玄关 (右)
        Row({ space: 6 }) {
          // 主卧区域
          Column({ space: 8 }) {
            Row() {
              Text('主卧')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.bedroomLightOn))
              Blank()
              Text(this.bedroomMotionOnline
                ? (this.bedroomMotion >= 1 ? '● 有人' : '○ 无人')
                : '离线')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(!this.bedroomMotionOnline
                  ? '#8C95A6'
                  : (this.bedroomMotion >= 1 ? '#00B578' : '#64748B'))
                .backgroundColor(this.bedroomMotionOnline && this.bedroomMotion >= 1 ? '#E6FFFB' : '#FFFFFF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_bedroom_motion');
                })
            }
            .width('100%')

            Row({ space: 6 }) {
              Column({ space: 2 }) {
                Text(!this.bedroomLightOnline ? '离线' : (this.bedroomLightOn ? '💡 暖光' : '○ 关灯'))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.bedroomLightOn ? '#D48806' : '#64748B')
                Text(!this.bedroomLightOnline ? '氛围灯' : (this.bedroomLightOn ? `${this.bedroomLightLevel}%` : '氛围灯'))
                  .fontSize(10)
                  .fontColor('#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.bedroomLightOn ? '#FDE68A' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_bedroom_light');
              })

              Column({ space: 2 }) {
                Text(!this.purifierOnline ? '离线' : (this.purifierOn ? '🌀 净化' : '净化器'))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.purifierOn ? '#FFFFFF' : '#64748B')
                Text(!this.purifierOnline ? '不可用' : (this.purifierOn ? `${this.purifierLevel}%` : '待机'))
                  .fontSize(10)
                  .fontColor(this.purifierOn ? '#D1FAE5' : '#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.purifierOn ? '#00B578' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_bedroom_purifier');
              })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .height(108)
          .padding(10)
          .justifyContent(FlexAlign.SpaceBetween)
          .backgroundColor(this.getBedroomBg())
          .borderRadius(12)
          .border({ width: 1.5, color: this.bedroomLightOn ? '#FACC15' : '#CBD5E1' })
          .animation({ duration: 320 })

          // 书房与入户玄关
          Column({ space: 8 }) {
            Row() {
              Text('书房 · 玄关')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.studyLampOn))
              Blank()
            }
            .width('100%')

            Row({ space: 6 }) {
              Column({ space: 2 }) {
                Text(!this.studyLampOnline ? '离线' : (this.studyLampOn ? '💡 台灯' : '○ 关灯'))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.studyLampOn ? '#D48806' : '#64748B')
                Text(!this.studyLampOnline ? '不可用' : (this.studyLampOn ? `${this.studyLampLevel}%` : '待机'))
                  .fontSize(10)
                  .fontColor('#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.studyLampOn ? '#FDE68A' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_study_lamp');
              })

              Column({ space: 2 }) {
                Text(!this.entryLockOnline ? '门锁离线' : (this.entryLockOn ? '🔒 已锁' : '🔓 未锁'))
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(!this.entryLockOnline ? '#4E5969' : '#FFFFFF')
                Text('入户门锁')
                  .fontSize(10)
                  .fontColor(!this.entryLockOnline ? '#64748B' : '#F1F5F9')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(!this.entryLockOnline ? '#E2E8F0' : (this.entryLockOn ? '#00B578' : '#FA8C16'))
              .onClick(() => {
                this.onToggleActuator('act_entry_lock');
              })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .height(108)
          .padding(10)
          .justifyContent(FlexAlign.SpaceBetween)
          .backgroundColor(this.getStudyBg())
          .borderRadius(12)
          .border({ width: 1.5, color: this.studyLampOn ? '#FACC15' : '#CBD5E1' })
          .animation({ duration: 320 })
        }
        .width('100%')
      }
      .width('100%')
      .padding(6)
      .backgroundColor('#E2E8F0')
      .borderRadius(14)

      Text('数据来源：出厂基线数据 + 本地物理仿真引擎实时演算 + ArkData 本地持久化')
        .fontSize(10)
        .fontColor('#7A8394')
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })
  }
}
