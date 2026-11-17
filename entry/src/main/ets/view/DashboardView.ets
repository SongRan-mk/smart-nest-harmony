import { DeviceCard } from '../components/DeviceCard';
import { ActuatorDevice, BaseDevice } from '../model/DeviceModels';
import { DeviceDetailParam, ROUTE_DEVICE_DETAIL } from '../model/NavTypes';
import { RoomId, RoomInfo, ScenePreset } from '../model/Types';
import { SmartHomeStore, STORE_REVISION_KEY } from '../service/SmartHomeStore';

/**
 * 智居看板视图：全屋摘要、突发演练、一键场景与多房间设备控制网格
 */
@Component
export struct DashboardView {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(STORE_REVISION_KEY) revision: number = 0;
  @State selectedRoom: RoomId = RoomId.ALL;

  private store: SmartHomeStore = SmartHomeStore.getInstance();

  private showTip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: msg,
        duration: 1800
      });
    } catch (_err) {
      // ignore
    }
  }

  private openDeviceDetail(deviceId: string): void {
    const param: DeviceDetailParam = { deviceId: deviceId };
    this.pageStack.pushPathByName(ROUTE_DEVICE_DETAIL, param);
  }

  private getFilteredDevices(): BaseDevice[] {
    // 读取 revision 建立响应式依赖
    if (this.revision < 0) {
      return [];
    }
    return this.store.getDevices(this.selectedRoom);
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        // 1. 顶部标题与持久化状态徽章
        Row() {
          Column({ space: 2 }) {
            Text('智巢中枢 SmartNest')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A2233')
            Text(this.store.getPersistenceStatusText())
              .fontSize(12)
              .fontColor('#00B578')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row({ space: 6 }) {
            Text(`在线 ${this.store.getOnlineCount()}/${this.store.getTotalDeviceCount()}`)
              .fontSize(12)
              .fontColor('#1677FF')
              .backgroundColor('#E6F4FF')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(14)

            if (this.store.getActiveAlertCount() > 0) {
              Text(`告警 ${this.store.getActiveAlertCount()}`)
                .fontSize(12)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF4D4F')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .borderRadius(14)
            }
          }
        }
        .width('100%')
        .padding({ top: 6 })

        // 2. 全屋运行摘要卡
        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text('客厅环境')
                .fontSize(12)
                .fontColor('#D6E4FF')
              Text(`${this.store.getPrimaryTempText()} · ${this.store.getPrimaryHumiText()}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Column({ space: 4 }) {
              Text('全屋实时功耗')
                .fontSize(12)
                .fontColor('#D6E4FF')
              Text(`${this.store.getTotalWatts()} W`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')

          Row({ space: 10 }) {
            Button(this.store.getSimConfig().autoRunning ? '暂停自动仿真' : '开启自动仿真')
              .type(ButtonType.Capsule)
              .height(34)
              .fontSize(13)
              .fontColor(this.store.getSimConfig().autoRunning ? '#FFFFFF' : '#1677FF')
              .backgroundColor(this.store.getSimConfig().autoRunning ? '#00B578' : '#FFFFFF')
              .layoutWeight(1)
              .onClick(() => {
                const running = this.store.toggleAutoSimulation();
                this.showTip(running ? '已启动 3 秒周期环境仿真' : '已暂停自动仿真');
              })

            Button('推进仿真步 +1')
              .type(ButtonType.Capsule)
              .height(34)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(255, 255, 255, 0.22)')
              .layoutWeight(1)
              .onClick(() => {
                const summary = this.store.stepSimulationOnce();
                this.showTip(`仿真步进完成 · 命中 ${summary.triggeredCount} 条规则`);
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(16)
        .borderRadius(18)
        .linearGradient({
          direction: GradientDirection.RightBottom,
          colors: [['#1677FF', 0.0], ['#2F54EB', 1.0]]
        })
        .shadow({ radius: 12, color: '#241677FF', offsetX: 0, offsetY: 4 })

        // 3. 突发工况演练快捷栏
        Column({ space: 8 }) {
          Text('突发工况演练（即时驱动规则联动）')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#4E5969')

          Row({ space: 8 }) {
            Button('高温 31.5℃')
              .type(ButtonType.Normal)
              .borderRadius(10)
              .height(34)
              .fontSize(12)
              .fontColor('#D46B08')
              .backgroundColor('#FFF7E6')
              .layoutWeight(1)
              .onClick(() => {
                this.showTip(this.store.triggerDrill('heatwave'));
              })

            Button('烟雾 185ppm')
              .type(ButtonType.Normal)
              .borderRadius(10)
              .height(34)
              .fontSize(12)
              .fontColor('#CF1322')
              .backgroundColor('#FFF1F0')
              .layoutWeight(1)
              .onClick(() => {
                this.showTip(this.store.triggerDrill('smoke'));
              })

            Button('夜幕暗光')
              .type(ButtonType.Normal)
              .borderRadius(10)
              .height(34)
              .fontSize(12)
              .fontColor('#531DAB')
              .backgroundColor('#F9F0FF')
              .layoutWeight(1)
              .onClick(() => {
                this.showTip(this.store.triggerDrill('nightfall'));
              })
          }
          .width('100%')
        }
        .width('100%')

        // 4. 一键场景模式
        Column({ space: 8 }) {
          Text('一键情景模式')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#4E5969')

          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.store.getScenes(), (scene: ScenePreset) => {
                Column({ space: 4 }) {
                  Text(scene.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.store.getActiveSceneId() === scene.id ? '#FFFFFF' : '#1A2233')
                  Text(scene.description)
                    .fontSize(10)
                    .fontColor(this.store.getActiveSceneId() === scene.id ? '#E6F4FF' : '#8C95A6')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width(132)
                .padding(10)
                .alignItems(HorizontalAlign.Start)
                .borderRadius(12)
                .backgroundColor(this.store.getActiveSceneId() === scene.id ? scene.accentColor : '#FFFFFF')
                .border({
                  width: 1,
                  color: this.store.getActiveSceneId() === scene.id ? scene.accentColor : '#EAECEF'
                })
                .onClick(() => {
                  this.showTip(this.store.applyScene(scene.id));
                })
              }, (scene: ScenePreset) => scene.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .width('100%')

        // 5. 房间切换栏 + 设备网格
        Column({ space: 10 }) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.store.getRooms(), (room: RoomInfo) => {
                Text(room.shortTag)
                  .fontSize(13)
                  .fontWeight(this.selectedRoom === room.id ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.selectedRoom === room.id ? '#FFFFFF' : '#4E5969')
                  .backgroundColor(this.selectedRoom === room.id ? '#1677FF' : '#FFFFFF')
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .borderRadius(16)
                  .border({ width: 1, color: this.selectedRoom === room.id ? '#1677FF' : '#E5E7EB' })
                  .onClick(() => {
                    this.selectedRoom = room.id;
                  })
              }, (room: RoomInfo) => room.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          GridRow({ columns: 2, gutter: { x: 10, y: 10 } }) {
            ForEach(this.getFilteredDevices(), (dev: BaseDevice) => {
              GridCol() {
                DeviceCard({
                  deviceId: dev.id,
                  deviceName: dev.name,
                  roomId: dev.roomId,
                  isActuator: dev instanceof ActuatorDevice,
                  online: dev.online,
                  powerOn: dev instanceof ActuatorDevice ? dev.powerOn : false,
                  alertActive: dev.isAlertActive(),
                  primaryValue: dev.getPrimaryValueText(),
                  summaryText: dev.getSummaryText(),
                  effectiveWatts: dev.getEffectiveWatts(),
                  onCardClick: (id: string) => {
                    this.openDeviceDetail(id);
                  },
                  onTogglePower: (id: string) => {
                    const ok = this.store.toggleActuatorPower(id);
                    if (!ok) {
                      this.showTip('设备离线或不可控，操作已拦截');
                    }
                  }
                })
              }
            }, (dev: BaseDevice) => `${dev.id}_${this.revision}`)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ bottom: 16 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FA')
  }
}
