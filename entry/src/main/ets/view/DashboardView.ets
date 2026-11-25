import { DeviceCard } from '../components/DeviceCard';
import { HomeFloorPlan } from '../components/HomeFloorPlan';
import { ActuatorDevice, BaseDevice } from '../model/DeviceModels';
import { DeviceDetailParam, ROUTE_DEVICE_DETAIL } from '../model/NavTypes';
import { RoomId, RoomInfo, ScenePreset } from '../model/Types';
import { SmartHomeStore, STORE_REVISION_KEY } from '../service/SmartHomeStore';

interface TheaterStepChip {
  idx: number;
  label: string;
}

/**
 * 智居看板视图：全屋摘要、应急告警横幅、数字孪生沙盘、突发演练、一键场景与多房间设备网格
 */
@Component
export struct DashboardView {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(STORE_REVISION_KEY) @Watch('syncFromStore') revision: number = 0;
  @State selectedRoom: RoomId = RoomId.ALL;

  @State persistenceStatus: string = '本地首选项已同步';
  @State onlineCount: number = 13;
  @State totalDeviceCount: number = 13;
  @State alertCount: number = 0;
  @State primaryTempText: string = '25.4℃';
  @State primaryHumiText: string = '54%';
  @State totalWatts: number = 0;
  @State autoRunning: boolean = false;
  @State activeSceneId: string = '';
  @State homeOccupied: boolean = true;
  @State theaterRunning: boolean = false;
  @State theaterCompleted: boolean = false;
  @State theaterMitigating: boolean = false;
  @State theaterStage: number = 0;
  @State butlerHeadline: string = '智巢管家 · 待命守卫中';
  @State butlerNarration: string = '';
  @State filteredDevices: BaseDevice[] = [];

  private store: SmartHomeStore = SmartHomeStore.getInstance();
  private theaterChips: TheaterStepChip[] = [
    { idx: 1, label: '08 唤醒' },
    { idx: 2, label: '10 离家' },
    { idx: 3, label: '14 热浪' },
    { idx: 4, label: '19 归家' },
    { idx: 5, label: '21 仲裁' }
  ];

  aboutToAppear(): void {
    this.syncFromStore();
  }

  syncFromStore(): void {
    this.persistenceStatus = this.store.getPersistenceStatusText();
    this.onlineCount = this.store.getOnlineCount();
    this.totalDeviceCount = this.store.getTotalDeviceCount();
    this.alertCount = this.store.getActiveAlertCount();
    this.primaryTempText = this.store.getPrimaryTempText();
    this.primaryHumiText = this.store.getPrimaryHumiText();
    this.totalWatts = this.store.getTotalWatts();
    this.autoRunning = this.store.getSimConfig().autoRunning;
    this.activeSceneId = this.store.getActiveSceneId();
    this.homeOccupied = this.store.isHomeOccupied();
    const tStatus = this.store.getDayTheaterStatus();
    this.theaterRunning = tStatus.running;
    this.theaterCompleted = tStatus.completed;
    this.theaterMitigating = tStatus.mitigating;
    this.theaterStage = tStatus.stageIndex;
    this.butlerHeadline = tStatus.butlerHeadline;
    this.butlerNarration = tStatus.butlerNarration;
    this.filteredDevices = this.store.getDevices(this.selectedRoom);
  }

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

  build() {
    Scroll() {
      Column({ space: 14 }) {
        // 1. 顶部标题与状态徽章
        Row() {
          Column({ space: 2 }) {
            Text('智巢中枢 SmartNest')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A2233')
            Text(this.persistenceStatus)
              .fontSize(12)
              .fontColor('#00B578')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row({ space: 6 }) {
            Text(this.homeOccupied ? '有人在家' : '离家无人')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.homeOccupied ? '#00B578' : '#64748B')
              .backgroundColor(this.homeOccupied ? '#E6FFFB' : '#EDF2F7')
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .borderRadius(14)

            Text(`在线 ${this.onlineCount}/${this.totalDeviceCount}`)
              .fontSize(11)
              .fontColor('#1677FF')
              .backgroundColor('#E6F4FF')
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .borderRadius(14)

            if (this.alertCount > 0) {
              Text(`告警 ${this.alertCount}`)
                .fontSize(11)
                .fontColor('#FFFFFF')
                .backgroundColor('#FF4D4F')
                .padding({ left: 8, right: 8, top: 5, bottom: 5 })
                .borderRadius(14)
            }
          }
        }
        .width('100%')
        .padding({ top: 6 })

        // 1.5 紧急告警应急横幅
        if (this.alertCount > 0) {
          Row({ space: 10 }) {
            Column({ space: 2 }) {
              Text(`检测到 ${this.alertCount} 项环境/安防异常告警`)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#CF1322')
              Text('已按应急优先策略执行联动，可点击右侧一键复位')
                .fontSize(11)
                .fontColor('#A8071A')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button('一键解除')
              .type(ButtonType.Capsule)
              .height(30)
              .fontSize(12)
              .backgroundColor('#FF4D4F')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.showTip(this.store.dismissAllAlerts());
              })
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#FFF1F0')
          .borderRadius(14)
          .border({ width: 1.5, color: '#FFA39E' })
        }

        // 2. 全屋运行摘要卡（精简紧凑，首屏完整释放空间给沙盘）
        Row() {
          Column({ space: 4 }) {
            Text('客厅实时环境')
              .fontSize(12)
              .fontColor('#D6E4FF')
            Text(`${this.primaryTempText} · ${this.primaryHumiText}`)
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
            Text(`${this.totalWatts} W`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .borderRadius(16)
        .linearGradient({
          direction: GradientDirection.RightBottom,
          colors: [['#1677FF', 0.0], ['#2F54EB', 1.0]]
        })
        .shadow({ radius: 10, color: '#241677FF', offsetX: 0, offsetY: 4 })

        // 2.2 24h 智巢一天沉浸式互动剧场 + 管家实时播报气泡
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Row({ space: 6 }) {
                Text('24h 智巢一天沉浸剧场')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A2233')
                if (this.theaterMitigating) {
                  Text('消警等待中')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#FF4D4F')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(8)
                } else if (this.theaterRunning) {
                  Text('演播中')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#722ED1')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(8)
                } else if (this.theaterCompleted) {
                  Text('已完成')
                    .fontSize(10)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FFFFFF')
                    .backgroundColor('#00B578')
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(8)
                }
              }
              Text('异常未消除前自动暂缓推进，闭环自愈后结束')
                .fontSize(11)
                .fontColor('#6E7787')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button(this.theaterRunning ? '暂停演播' : (this.theaterCompleted ? '▶ 重新演播' : '▶ 体验智巢一天'))
              .type(ButtonType.Capsule)
              .height(32)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .backgroundColor(this.theaterRunning ? '#FA8C16' : '#722ED1')
              .fontColor('#FFFFFF')
              .onClick(() => {
                if (this.theaterRunning) {
                  this.store.stopDayTheater();
                  this.showTip('已暂停智巢剧场演播');
                } else {
                  this.store.startDayTheater();
                  this.showTip('开启 24h 智巢一天闭环演播');
                }
              })

            Button('下一幕 ›')
              .type(ButtonType.Capsule)
              .height(32)
              .fontSize(12)
              .backgroundColor('#F9F0FF')
              .fontColor('#722ED1')
              .onClick(() => {
                const st = this.store.stepDayTheaterNext();
                this.showTip(st.butlerHeadline);
              })
          }
          .width('100%')

          // 5 幕等分可点击进度时间轴（完整显示不截断）
          Row({ space: 5 }) {
            ForEach(this.theaterChips, (chip: TheaterStepChip) => {
              Text(chip.label)
                .fontSize(10)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .fontWeight(this.theaterStage === chip.idx ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.theaterStage === chip.idx
                  ? '#FFFFFF'
                  : (this.theaterStage > chip.idx ? '#00B578' : '#64748B'))
                .backgroundColor(this.theaterStage === chip.idx
                  ? (chip.idx === 5 ? '#FF4D4F' : '#722ED1')
                  : (this.theaterStage > chip.idx ? '#E6FFFB' : '#F2F4F8'))
                .padding({ top: 5, bottom: 5 })
                .borderRadius(10)
                .onClick(() => {
                  const st = this.store.jumpToTheaterStage(chip.idx);
                  this.showTip(st.butlerHeadline);
                })
            }, (chip: TheaterStepChip) => `${chip.idx}_${this.theaterStage}`)
          }
          .width('100%')

          // 智巢管家实时解说气泡
          Column({ space: 4 }) {
            Text(this.butlerHeadline)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theaterCompleted
                ? '#00875A'
                : ((this.theaterMitigating || this.alertCount > 0) ? '#CF1322' : '#531DAB'))
            Text(this.butlerNarration)
              .fontSize(12)
              .lineHeight(18)
              .fontColor('#333B48')
          }
          .width('100%')
          .padding(10)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(this.theaterCompleted
            ? '#F6FFED'
            : ((this.theaterMitigating || this.alertCount > 0) ? '#FFF1F0' : '#F9F0FF'))
          .borderRadius(12)
          .border({
            width: 1,
            color: this.theaterCompleted
              ? '#B7EB8F'
              : ((this.theaterMitigating || this.alertCount > 0) ? '#FFA39E' : '#EFDBFF')
          })
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(18)
        .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })

        // 2.5 全屋数字孪生交互沙盘
        HomeFloorPlan({
          revision: this.revision,
          onSelectDevice: (id: string) => {
            this.openDeviceDetail(id);
          },
          onToggleActuator: (id: string) => {
            const ok = this.store.toggleActuatorPower(id);
            const dev = this.store.getDeviceById(id);
            if (!ok) {
              this.showTip('设备离线或不可控，操作已拦截');
            } else if (dev) {
              this.showTip(`${dev.name}：${dev.getSummaryText()}`);
            }
          }
        })

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
                    .fontColor(this.activeSceneId === scene.id ? '#FFFFFF' : '#1A2233')
                  Text(scene.description)
                    .fontSize(10)
                    .fontColor(this.activeSceneId === scene.id ? '#E6F4FF' : '#8C95A6')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width(136)
                .padding(10)
                .alignItems(HorizontalAlign.Start)
                .borderRadius(12)
                .backgroundColor(this.activeSceneId === scene.id ? scene.accentColor : '#FFFFFF')
                .border({
                  width: 1,
                  color: this.activeSceneId === scene.id ? scene.accentColor : '#EAECEF'
                })
                .onClick(() => {
                  this.showTip(this.store.applyScene(scene.id));
                })
              }, (scene: ScenePreset) => `${scene.id}_${this.activeSceneId === scene.id}`)
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
                    this.filteredDevices = this.store.getDevices(room.id);
                  })
              }, (room: RoomInfo) => room.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          GridRow({ columns: 2, gutter: { x: 10, y: 10 } }) {
            ForEach(this.filteredDevices, (dev: BaseDevice) => {
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
