import { ActuatorDevice, BaseDevice, SensorDevice } from '../model/DeviceModels';
import { SmartHomeStore } from '../service/SmartHomeStore';

/**
 * 智巢全屋交互式数字孪生户型沙盘组件
 * 将客厅、阳台、主卧、书房玄关的照明光晕、窗帘开合、空调制冷、烟雾告警与门锁状态可视化呈现
 */
@Component
export struct HomeFloorPlan {
  @Prop revision: number = 0;

  onSelectDevice: (deviceId: string) => void = () => {};
  onToggleActuator: (deviceId: string) => void = () => {};

  private store: SmartHomeStore = SmartHomeStore.getInstance();

  private getSensorVal(id: string, fallback: number): number {
    if (this.revision < 0) {
      return fallback;
    }
    const dev: BaseDevice | undefined = this.store.getDeviceById(id);
    if (dev instanceof SensorDevice && dev.online) {
      return dev.value;
    }
    return fallback;
  }

  private isSensorOnline(id: string): boolean {
    if (this.revision < 0) {
      return false;
    }
    const dev = this.store.getDeviceById(id);
    return dev ? dev.online : false;
  }

  private isActuatorOn(id: string): boolean {
    if (this.revision < 0) {
      return false;
    }
    const dev = this.store.getDeviceById(id);
    return (dev instanceof ActuatorDevice) && dev.online && dev.powerOn;
  }

  private isActuatorOnline(id: string): boolean {
    if (this.revision < 0) {
      return false;
    }
    const dev = this.store.getDeviceById(id);
    return dev ? dev.online : false;
  }

  private getActuatorLevel(id: string, fallback: number): number {
    if (this.revision < 0) {
      return fallback;
    }
    const dev = this.store.getDeviceById(id);
    if (dev instanceof ActuatorDevice) {
      return dev.levelValue;
    }
    return fallback;
  }

  private isDarkAmbient(): boolean {
    return this.getSensorVal('sensor_living_light', 320) < 150;
  }

  private getLivingBg(): string {
    if (this.isActuatorOn('act_living_light')) {
      const level = this.getActuatorLevel('act_living_light', 75);
      return level >= 60 ? '#FFF6D6' : '#FEF9E7';
    }
    return this.isDarkAmbient() ? '#1E293B' : '#F8FAFC';
  }

  private getBedroomBg(): string {
    if (this.isActuatorOn('act_bedroom_light')) {
      return '#FEF3C7';
    }
    return this.isDarkAmbient() ? '#1E293B' : '#F8FAFC';
  }

  private getStudyBg(): string {
    if (this.isActuatorOn('act_study_lamp')) {
      return '#FFFBEB';
    }
    return this.isDarkAmbient() ? '#1E293B' : '#F8FAFC';
  }

  private getBalconyBg(): string {
    const smoke = this.getSensorVal('sensor_balcony_smoke', 18);
    if (smoke >= 120 || this.isActuatorOn('act_balcony_siren')) {
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
    const openPct = this.isActuatorOn('act_living_curtain')
      ? this.getActuatorLevel('act_living_curtain', 65)
      : 0;
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

        Text(this.isDarkAmbient() ? '夜间弱光环境' : '日间采光环境')
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
            // 客厅顶栏 + 电动窗帘动态窗户
            Row() {
              Text('客厅')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.isActuatorOn('act_living_light')))

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

            // 环境传感读数条（温度/湿度/光照）
            Row({ space: 4 }) {
              Text(this.isSensorOnline('sensor_living_temp') ? `${this.getSensorVal('sensor_living_temp', 25.4)}℃` : '离线')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getSensorVal('sensor_living_temp', 25.4) >= 28 ? '#FFFFFF' : '#D46B08')
                .backgroundColor(this.getSensorVal('sensor_living_temp', 25.4) >= 28 ? '#FF4D4F' : '#FFF7E6')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_living_temp');
                })

              Text(this.isSensorOnline('sensor_living_humi') ? `${this.getSensorVal('sensor_living_humi', 54)}%` : '离线')
                .fontSize(10)
                .fontColor('#1677FF')
                .backgroundColor('#E6F4FF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_living_humi');
                })

              Text(this.isSensorOnline('sensor_living_light') ? `${this.getSensorVal('sensor_living_light', 320)}lx` : '离线')
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

            // 客厅执行器控件（主灯 + 空调 + 窗帘开度）
            Row({ space: 6 }) {
              // 主灯
              Column({ space: 2 }) {
                Text(this.isActuatorOn('act_living_light') ? '💡 亮灯' : '○ 熄灭')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isActuatorOn('act_living_light') ? '#D48806' : '#64748B')
                Text(this.isActuatorOnline('act_living_light')
                  ? (this.isActuatorOn('act_living_light') ? `${this.getActuatorLevel('act_living_light', 75)}%` : '主灯')
                  : '离线')
                  .fontSize(10)
                  .fontColor('#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 6, bottom: 6 })
              .borderRadius(10)
              .backgroundColor(this.isActuatorOn('act_living_light') ? '#FFF1B8' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_living_light');
              })

              // 空调
              Column({ space: 2 }) {
                Text(this.isActuatorOn('act_living_ac') ? '❄ 制冷' : '空调')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isActuatorOn('act_living_ac') ? '#FFFFFF' : '#64748B')
                Text(this.isActuatorOnline('act_living_ac')
                  ? (this.isActuatorOn('act_living_ac') ? `${this.getActuatorLevel('act_living_ac', 25)}℃` : '待机')
                  : '离线')
                  .fontSize(10)
                  .fontColor(this.isActuatorOn('act_living_ac') ? '#E6F4FF' : '#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 6, bottom: 6 })
              .borderRadius(10)
              .backgroundColor(this.isActuatorOn('act_living_ac') ? '#1677FF' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_living_ac');
              })
            }
            .width('100%')

            Text(`窗帘开度 ${this.isActuatorOn('act_living_curtain') ? this.getActuatorLevel('act_living_curtain', 65) : 0}%（点击调节）`)
              .fontSize(10)
              .fontColor(this.getRoomTitleColor(this.isActuatorOn('act_living_light')))
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
          .border({ width: 1.5, color: this.isActuatorOn('act_living_light') ? '#FACC15' : '#CBD5E1' })
          .animation({ duration: 320 })

          // 阳台安防区域
          Column({ space: 8 }) {
            Row() {
              Text('阳台')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.getSensorVal('sensor_balcony_smoke', 18) >= 120))
              Blank()
              Text('安防区')
                .fontSize(10)
                .fontColor('#64748B')
            }
            .width('100%')

            // 烟雾传感器节点
            Column({ space: 2 }) {
              Text('烟雾监测')
                .fontSize(10)
                .fontColor('#64748B')
              Text(this.isSensorOnline('sensor_balcony_smoke')
                ? `${this.getSensorVal('sensor_balcony_smoke', 18)} ppm`
                : '离线')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getSensorVal('sensor_balcony_smoke', 18) >= 120 ? '#CF1322' : '#00B578')
            }
            .width('100%')
            .padding(6)
            .borderRadius(8)
            .backgroundColor('#FFFFFF')
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              this.onSelectDevice('sensor_balcony_smoke');
            })

            // 声光报警器节点
            Row({ space: 4 }) {
              Text(this.isActuatorOn('act_balcony_siren') ? '🚨 鸣笛告警' : '🔔 报警待机')
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isActuatorOn('act_balcony_siren') ? '#FFFFFF' : '#4E5969')
            }
            .width('100%')
            .padding({ top: 7, bottom: 7 })
            .justifyContent(FlexAlign.Center)
            .borderRadius(8)
            .backgroundColor(this.isActuatorOn('act_balcony_siren') ? '#FF4D4F' : '#E2E8F0')
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
            color: (this.getSensorVal('sensor_balcony_smoke', 18) >= 120 || this.isActuatorOn('act_balcony_siren'))
              ? '#FF4D4F'
              : '#CBD5E1'
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
                .fontColor(this.getRoomTitleColor(this.isActuatorOn('act_bedroom_light')))
              Blank()
              Text(this.isSensorOnline('sensor_bedroom_motion')
                ? (this.getSensorVal('sensor_bedroom_motion', 1) >= 1 ? '● 有人' : '○ 无人')
                : '离线')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getSensorVal('sensor_bedroom_motion', 1) >= 1 ? '#00B578' : '#8C95A6')
                .backgroundColor('#FFFFFF')
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(8)
                .onClick(() => {
                  this.onSelectDevice('sensor_bedroom_motion');
                })
            }
            .width('100%')

            Row({ space: 6 }) {
              // 卧室氛围灯
              Column({ space: 2 }) {
                Text(this.isActuatorOn('act_bedroom_light') ? '💡 暖光' : '○ 关灯')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isActuatorOn('act_bedroom_light') ? '#D48806' : '#64748B')
                Text(this.isActuatorOn('act_bedroom_light')
                  ? `${this.getActuatorLevel('act_bedroom_light', 40)}%`
                  : '氛围灯')
                  .fontSize(10)
                  .fontColor('#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.isActuatorOn('act_bedroom_light') ? '#FDE68A' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_bedroom_light');
              })

              // 空气净化器
              Column({ space: 2 }) {
                Text(this.isActuatorOn('act_bedroom_purifier') ? '🌀 净化' : '净化器')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isActuatorOn('act_bedroom_purifier') ? '#FFFFFF' : '#64748B')
                Text(this.isActuatorOn('act_bedroom_purifier')
                  ? `${this.getActuatorLevel('act_bedroom_purifier', 50)}%`
                  : '待机')
                  .fontSize(10)
                  .fontColor(this.isActuatorOn('act_bedroom_purifier') ? '#D1FAE5' : '#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.isActuatorOn('act_bedroom_purifier') ? '#00B578' : '#E2E8F0')
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
          .border({ width: 1.5, color: this.isActuatorOn('act_bedroom_light') ? '#FACC15' : '#CBD5E1' })
          .animation({ duration: 320 })

          // 书房与入户玄关
          Column({ space: 8 }) {
            Row() {
              Text('书房 · 玄关')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getRoomTitleColor(this.isActuatorOn('act_study_lamp')))
              Blank()
            }
            .width('100%')

            Row({ space: 6 }) {
              // 书房护眼台灯
              Column({ space: 2 }) {
                Text(this.isActuatorOn('act_study_lamp') ? '💡 台灯' : '○ 关灯')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isActuatorOn('act_study_lamp') ? '#D48806' : '#64748B')
                Text(this.isActuatorOn('act_study_lamp')
                  ? `${this.getActuatorLevel('act_study_lamp', 85)}%`
                  : '待机')
                  .fontSize(10)
                  .fontColor('#64748B')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.isActuatorOn('act_study_lamp') ? '#FDE68A' : '#E2E8F0')
              .onClick(() => {
                this.onToggleActuator('act_study_lamp');
              })

              // 入户智能门锁
              Column({ space: 2 }) {
                Text(this.isActuatorOn('act_entry_lock') ? '🔒 已锁' : '🔓 未锁')
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                Text('入户门锁')
                  .fontSize(10)
                  .fontColor('#F1F5F9')
              }
              .layoutWeight(1)
              .padding({ top: 7, bottom: 7 })
              .borderRadius(10)
              .backgroundColor(this.isActuatorOn('act_entry_lock') ? '#00B578' : '#FA8C16')
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
          .border({ width: 1.5, color: this.isActuatorOn('act_study_lamp') ? '#FACC15' : '#CBD5E1' })
          .animation({ duration: 320 })
        }
        .width('100%')
      }
      .width('100%')
      .padding(6)
      .backgroundColor('#E2E8F0')
      .borderRadius(14)

      // 数据来源透明说明条
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
