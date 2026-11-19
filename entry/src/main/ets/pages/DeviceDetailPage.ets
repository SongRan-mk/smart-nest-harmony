import { ActuatorDevice, BaseDevice, SensorDevice } from '../model/DeviceModels';
import { DeviceKind, getRoomDisplayName, MetricKey } from '../model/Types';
import { SmartHomeStore, STORE_REVISION_KEY } from '../service/SmartHomeStore';

/**
 * 设备详情与交互仿真调节页
 */
@Component
export struct DeviceDetailPage {
  @Prop deviceId: string = '';
  @StorageProp(STORE_REVISION_KEY) revision: number = 0;
  @State sliderDraft: number = 0;
  @State isDragging: boolean = false;

  private store: SmartHomeStore = SmartHomeStore.getInstance();

  aboutToAppear(): void {
    const dev = this.store.getDeviceById(this.deviceId);
    if (dev instanceof SensorDevice) {
      this.sliderDraft = dev.value;
    } else if (dev instanceof ActuatorDevice) {
      this.sliderDraft = dev.levelValue;
    }
  }

  private getDevice(): BaseDevice | undefined {
    if (this.revision < 0) {
      return undefined;
    }
    return this.store.getDeviceById(this.deviceId);
  }

  private showTip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (_err) {
      // ignore
    }
  }

  private getSensorPresetHigh(dev: SensorDevice): number {
    if (dev.metricKey === MetricKey.TEMPERATURE) {
      return 31.0;
    }
    if (dev.metricKey === MetricKey.SMOKE_LEVEL) {
      return 160;
    }
    if (dev.metricKey === MetricKey.ILLUMINANCE) {
      return 80;
    }
    return Math.min(dev.maxVal, dev.alertThreshold);
  }

  private getSensorPresetNormal(dev: SensorDevice): number {
    if (dev.metricKey === MetricKey.TEMPERATURE) {
      return 24.5;
    }
    if (dev.metricKey === MetricKey.SMOKE_LEVEL) {
      return 15;
    }
    if (dev.metricKey === MetricKey.ILLUMINANCE) {
      return 380;
    }
    if (dev.metricKey === MetricKey.HUMIDITY) {
      return 55;
    }
    return 0;
  }

  private supportsLevelSlider(dev: ActuatorDevice): boolean {
    if (dev.kind === DeviceKind.SMART_LOCK || dev.kind === DeviceKind.ALARM_SIREN) {
      return false;
    }
    return dev.maxLevel > dev.minLevel;
  }

  private getModePresets(kind: DeviceKind): string[] {
    switch (kind) {
      case DeviceKind.AIR_CONDITIONER:
        return ['制冷', '强力制冷', '除湿', '睡眠静音', '节能待机'];
      case DeviceKind.SMART_LIGHT:
        return ['暖白光', '读写模式', '温馨照明', '夜灯柔光'];
      case DeviceKind.SMART_CURTAIN:
        return ['采光', '遮阳', '遮光', '紧急通风'];
      case DeviceKind.AIR_PURIFIER:
        return ['静音除味', '标准循环', '强效排烟'];
      default:
        return [];
    }
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          if (this.getDevice() === undefined) {
            Text('未找到对应设备信息')
              .fontSize(15)
              .fontColor('#8C95A6')
              .margin({ top: 40 })
          } else {
            // 1. 设备概览卡
            Column({ space: 8 }) {
              Row() {
                Text(getRoomDisplayName(this.getDevice()!.roomId))
                  .fontSize(12)
                  .fontColor('#1677FF')
                  .backgroundColor('#E6F4FF')
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                  .borderRadius(12)

                Blank()

                Text(this.getDevice()!.online ? '在线' : '已离线')
                  .fontSize(12)
                  .fontColor(this.getDevice()!.online ? '#00B578' : '#FF4D4F')
                  .fontWeight(FontWeight.Bold)
              }
              .width('100%')

              Text(this.getDevice()!.name)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A2233')

              Text(this.getDevice()!.getPrimaryValueText())
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getDevice()!.isAlertActive() ? '#FF4D4F' : '#1677FF')

              Text(`${this.getDevice()!.getSummaryText()} · 实时功耗 ${this.getDevice()!.getEffectiveWatts()}W`)
                .fontSize(13)
                .fontColor('#6E7787')
            }
            .width('100%')
            .padding(18)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .alignItems(HorizontalAlign.Start)

            // 2. 传感器交互仿真控制
            if (this.getDevice() instanceof SensorDevice) {
              Column({ space: 12 }) {
                Text('环境传感仿真调节（松手即评估联动规则）')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A2233')

                if ((this.getDevice() as SensorDevice).metricKey === MetricKey.MOTION_DETECTED) {
                  Row({ space: 10 }) {
                    Button('设为无人 (0)')
                      .type(ButtonType.Normal)
                      .borderRadius(10)
                      .layoutWeight(1)
                      .backgroundColor((this.getDevice() as SensorDevice).value < 1 ? '#1677FF' : '#F2F4F8')
                      .fontColor((this.getDevice() as SensorDevice).value < 1 ? '#FFFFFF' : '#4E5969')
                      .onClick(() => {
                        const summary = this.store.updateSensorValue(this.deviceId, 0);
                        this.showTip(`已更新为无人，触发 ${summary.triggeredCount} 条规则`);
                      })

                    Button('设为有人活动 (1)')
                      .type(ButtonType.Normal)
                      .borderRadius(10)
                      .layoutWeight(1)
                      .backgroundColor((this.getDevice() as SensorDevice).value >= 1 ? '#1677FF' : '#F2F4F8')
                      .fontColor((this.getDevice() as SensorDevice).value >= 1 ? '#FFFFFF' : '#4E5969')
                      .onClick(() => {
                        const summary = this.store.updateSensorValue(this.deviceId, 1);
                        this.showTip(`已更新为有人，触发 ${summary.triggeredCount} 条规则`);
                      })
                  }
                  .width('100%')
                } else {
                  Row() {
                    Text(`设定数值：${this.isDragging ? Math.round(this.sliderDraft * 10) / 10 : (this.getDevice() as SensorDevice).value}${(this.getDevice() as SensorDevice).unit}`)
                      .fontSize(14)
                      .fontColor('#1677FF')
                      .fontWeight(FontWeight.Medium)
                    Blank()
                    Text(`量程 ${(this.getDevice() as SensorDevice).minVal}~${(this.getDevice() as SensorDevice).maxVal}${(this.getDevice() as SensorDevice).unit}`)
                      .fontSize(11)
                      .fontColor('#8C95A6')
                  }
                  .width('100%')

                  Slider({
                    value: this.isDragging ? this.sliderDraft : (this.getDevice() as SensorDevice).value,
                    min: (this.getDevice() as SensorDevice).minVal,
                    max: (this.getDevice() as SensorDevice).maxVal,
                    step: (this.getDevice() as SensorDevice).metricKey === MetricKey.TEMPERATURE ? 0.5 : 5,
                    style: SliderStyle.OutSet
                  })
                    .blockColor('#1677FF')
                    .selectedColor('#1677FF')
                    .enabled(this.getDevice()!.online)
                    .onChange((val: number, mode: SliderChangeMode) => {
                      this.sliderDraft = val;
                      if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
                        this.isDragging = true;
                      } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                        this.isDragging = false;
                        const summary = this.store.updateSensorValue(this.deviceId, val);
                        this.showTip(`环境已更新 · 触发 ${summary.triggeredCount} 条规则`);
                      }
                    })

                  Row({ space: 10 }) {
                    Button('恢复舒适值')
                      .type(ButtonType.Normal)
                      .borderRadius(10)
                      .height(34)
                      .fontSize(12)
                      .fontColor('#00B578')
                      .backgroundColor('#F6FFED')
                      .layoutWeight(1)
                      .onClick(() => {
                        const v = this.getSensorPresetNormal(this.getDevice() as SensorDevice);
                        this.sliderDraft = v;
                        const summary = this.store.updateSensorValue(this.deviceId, v);
                        this.showTip(`已设为舒适值 ${v} · 触发 ${summary.triggeredCount} 条规则`);
                      })

                    Button('模拟极端工况')
                      .type(ButtonType.Normal)
                      .borderRadius(10)
                      .height(34)
                      .fontSize(12)
                      .fontColor('#FF4D4F')
                      .backgroundColor('#FFF1F0')
                      .layoutWeight(1)
                      .onClick(() => {
                        const v = this.getSensorPresetHigh(this.getDevice() as SensorDevice);
                        this.sliderDraft = v;
                        const summary = this.store.updateSensorValue(this.deviceId, v);
                        this.showTip(`已注入极端值 ${v} · 触发 ${summary.triggeredCount} 条规则`);
                      })
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .alignItems(HorizontalAlign.Start)
            }

            // 3. 执行器精细控制
            if (this.getDevice() instanceof ActuatorDevice) {
              Column({ space: 12 }) {
                Row() {
                  Text('设备电源开关')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A2233')
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: (this.getDevice() as ActuatorDevice).powerOn })
                    .selectedColor('#1677FF')
                    .enabled(this.getDevice()!.online)
                    .onChange((isOn: boolean) => {
                      const cur = (this.getDevice() as ActuatorDevice).powerOn;
                      if (isOn !== cur) {
                        this.store.toggleActuatorPower(this.deviceId);
                      }
                    })
                }
                .width('100%')

                if (this.supportsLevelSlider(this.getDevice() as ActuatorDevice)) {
                  Divider().color('#F0F2F5')
                  Row() {
                    Text(`目标参数：${this.isDragging ? Math.round(this.sliderDraft) : (this.getDevice() as ActuatorDevice).levelValue}${(this.getDevice() as ActuatorDevice).unit}`)
                      .fontSize(14)
                      .fontColor('#1677FF')
                    Blank()
                    Text(`${(this.getDevice() as ActuatorDevice).minLevel}~${(this.getDevice() as ActuatorDevice).maxLevel}${(this.getDevice() as ActuatorDevice).unit}`)
                      .fontSize(11)
                      .fontColor('#8C95A6')
                  }
                  .width('100%')

                  Slider({
                    value: this.isDragging ? this.sliderDraft : (this.getDevice() as ActuatorDevice).levelValue,
                    min: (this.getDevice() as ActuatorDevice).minLevel,
                    max: (this.getDevice() as ActuatorDevice).maxLevel,
                    step: 1,
                    style: SliderStyle.OutSet
                  })
                    .blockColor('#1677FF')
                    .selectedColor('#1677FF')
                    .enabled(this.getDevice()!.online)
                    .onChange((val: number, mode: SliderChangeMode) => {
                      this.sliderDraft = val;
                      if (mode === SliderChangeMode.Begin || mode === SliderChangeMode.Moving) {
                        this.isDragging = true;
                      } else if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                        this.isDragging = false;
                        this.store.setActuatorLevel(this.deviceId, val);
                        this.showTip(`参数已保存：${Math.round(val)}${(this.getDevice() as ActuatorDevice).unit}`);
                      }
                    })
                }

                if (this.getModePresets((this.getDevice() as ActuatorDevice).kind).length > 0) {
                  Divider().color('#F0F2F5')
                  Column({ space: 8 }) {
                    Text('运行模式切换')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#4E5969')

                    Scroll() {
                      Row({ space: 8 }) {
                        ForEach(this.getModePresets((this.getDevice() as ActuatorDevice).kind), (modeItem: string) => {
                          Text(modeItem)
                            .fontSize(12)
                            .fontWeight((this.getDevice() as ActuatorDevice).modeText === modeItem ? FontWeight.Bold : FontWeight.Normal)
                            .fontColor((this.getDevice() as ActuatorDevice).modeText === modeItem ? '#FFFFFF' : '#4E5969')
                            .backgroundColor((this.getDevice() as ActuatorDevice).modeText === modeItem ? '#1677FF' : '#F2F4F8')
                            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                            .borderRadius(14)
                            .onClick(() => {
                              const ok = this.store.setActuatorMode(this.deviceId, modeItem);
                              this.showTip(ok ? `已切换为【${modeItem}】` : '设备离线，模式切换被拦截');
                            })
                        }, (modeItem: string) => modeItem)
                      }
                    }
                    .scrollable(ScrollDirection.Horizontal)
                    .scrollBar(BarState.Off)
                    .width('100%')
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
            }

            // 4. 在线/离线故障模拟开关
            Row() {
              Column({ space: 2 }) {
                Text('设备在线状态（异常容错测试）')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A2233')
                Text('设为离线后，手动控制与规则自动联动均将被安全拦截')
                  .fontSize(11)
                  .fontColor('#8C95A6')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.getDevice()!.online })
                .selectedColor('#00B578')
                .onChange((isOn: boolean) => {
                  if (isOn !== this.getDevice()!.online) {
                    this.store.toggleDeviceOnline(this.deviceId);
                    this.showTip(isOn ? '设备已恢复在线' : '设备已模拟离线故障');
                  }
                })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
          }
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F3F6FA')
    }
    .title('设备详情与仿真')
    .backgroundColor('#F3F6FA')
  }
}
