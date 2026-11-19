import { ChartMetricType, EnvironmentChart } from '../components/EnvironmentChart';
import { ActuatorDevice } from '../model/DeviceModels';
import { EnvironmentSnapshot } from '../model/Types';
import { MockDiagItem, MockDiagReport, SmartHomeStore, STORE_REVISION_KEY } from '../service/SmartHomeStore';

interface MetricOption {
  key: ChartMetricType;
  label: string;
}

/**
 * 仿真趋势分析与核心引擎 Mock 自检视图
 */
@Component
export struct SimulationView {
  @StorageProp(STORE_REVISION_KEY) @Watch('syncFromStore') revision: number = 0;
  @State activeMetric: ChartMetricType = 'temperature';
  @State diagReport: MockDiagReport | undefined = undefined;

  @State snapshots: EnvironmentSnapshot[] = [];
  @State tickIndex: number = 4;
  @State autoRunning: boolean = false;
  @State totalWatts: number = 0;
  @State dailyKwh: string = '0.00';
  @State dailyCost: string = '0.00';
  @State ecoSuggestion: string = '';
  @State activeActuators: ActuatorDevice[] = [];

  private store: SmartHomeStore = SmartHomeStore.getInstance();
  private metricOptions: MetricOption[] = [
    { key: 'temperature', label: '温度 ℃' },
    { key: 'humidity', label: '湿度 %' },
    { key: 'illuminance', label: '光照 lux' },
    { key: 'smokeLevel', label: '烟雾 ppm' },
    { key: 'totalWatts', label: '功耗 W' }
  ];

  aboutToAppear(): void {
    this.syncFromStore();
  }

  syncFromStore(): void {
    this.snapshots = this.store.getSnapshots();
    const simCfg = this.store.getSimConfig();
    this.tickIndex = simCfg.tickIndex;
    this.autoRunning = simCfg.autoRunning;
    this.totalWatts = this.store.getTotalWatts();
    this.dailyKwh = ((this.totalWatts * 24) / 1000).toFixed(2);
    this.dailyCost = (((this.totalWatts * 24) / 1000) * 0.55).toFixed(2);

    if (this.totalWatts >= 1000) {
      this.ecoSuggestion = '当前含大功率制冷负载，建议启用“凉爽时段节能待机”或调高空调设定 1~2℃';
    } else if (this.totalWatts >= 150) {
      this.ecoSuggestion = '当前功耗中等，离家时建议使用“离家布防”模式一键降低待机耗电';
    } else {
      this.ecoSuggestion = '当前全屋处于绿色低功耗运行状态，节能表现优秀';
    }

    const active: ActuatorDevice[] = [];
    const all = this.store.getActuators();
    for (let i = 0; i < all.length; i++) {
      if (all[i].getEffectiveWatts() > 0) {
        active.push(all[i]);
      }
    }
    this.activeActuators = active;
  }

  private showTip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (_err) {
      // ignore
    }
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        // 顶部标题
        Row() {
          Column({ space: 2 }) {
            Text('仿真趋势与自检')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A2233')
            Text(`累计采样 ${this.snapshots.length} 个环境时间点 · 当前第 ${this.tickIndex} 步`)
              .fontSize(12)
              .fontColor('#6E7787')
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Button(this.autoRunning ? '仿真运行中' : '已暂停')
            .type(ButtonType.Capsule)
            .height(30)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .backgroundColor(this.autoRunning ? '#00B578' : '#8C95A6')
            .onClick(() => {
              const running = this.store.toggleAutoSimulation();
              this.showTip(running ? '自动环境仿真已开启' : '自动环境仿真已暂停');
            })
        }
        .width('100%')
        .padding({ top: 8 })

        // 1. Canvas 趋势图卡片
        Column({ space: 10 }) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(this.metricOptions, (opt: MetricOption) => {
                Text(opt.label)
                  .fontSize(12)
                  .fontWeight(this.activeMetric === opt.key ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.activeMetric === opt.key ? '#FFFFFF' : '#4E5969')
                  .backgroundColor(this.activeMetric === opt.key ? '#1677FF' : '#F2F4F8')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(14)
                  .onClick(() => {
                    this.activeMetric = opt.key;
                  })
              }, (opt: MetricOption) => opt.key)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          EnvironmentChart({
            snapshots: this.snapshots,
            metric: this.activeMetric,
            revision: this.revision
          })

          Row({ space: 10 }) {
            Button(this.autoRunning ? '暂停自动步进' : '启动自动步进 (3s)')
              .type(ButtonType.Normal)
              .borderRadius(10)
              .height(36)
              .fontSize(13)
              .fontColor('#1677FF')
              .backgroundColor('#E6F4FF')
              .layoutWeight(1)
              .onClick(() => {
                this.store.toggleAutoSimulation();
              })

            Button('单步物理反馈 +1')
              .type(ButtonType.Normal)
              .borderRadius(10)
              .height(36)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor('#1677FF')
              .layoutWeight(1)
              .onClick(() => {
                const summary = this.store.stepSimulationOnce();
                this.showTip(`已推进至第 ${this.store.getSimConfig().tickIndex} 步，触发 ${summary.triggeredCount} 条规则`);
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        // 2. 实时设备功耗分布与能耗估算
        Column({ space: 10 }) {
          Row() {
            Text('运行设备功耗拆解')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A2233')
            Blank()
            Text(`总功率 ${this.totalWatts} W`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#00B578')
          }
          .width('100%')

          Column({ space: 6 }) {
            Row() {
              Column({ space: 2 }) {
                Text('按当前负载估算日耗电')
                  .fontSize(10)
                  .fontColor('#6E7787')
                Text(`${this.dailyKwh} kWh`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A2233')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 2 }) {
                Text('预估日电费 (¥0.55/度)')
                  .fontSize(10)
                  .fontColor('#6E7787')
                Text(`¥ ${this.dailyCost}`)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FA8C16')
              }
              .alignItems(HorizontalAlign.End)
              .layoutWeight(1)
            }
            .width('100%')

            Text(this.ecoSuggestion)
              .fontSize(11)
              .fontColor('#00B578')
              .width('100%')
          }
          .width('100%')
          .padding(10)
          .backgroundColor('#F6FFED')
          .borderRadius(10)
          .border({ width: 1, color: '#D9F7BE' })

          if (this.activeActuators.length === 0) {
            Text('当前所有执行器均处于待机状态（仅传感器基础微功耗运行）')
              .fontSize(12)
              .fontColor('#8C95A6')
              .padding({ top: 6, bottom: 6 })
          } else {
            ForEach(this.activeActuators, (act: ActuatorDevice) => {
              Column({ space: 4 }) {
                Row() {
                  Text(`${act.name}（${act.modeText}）`)
                    .fontSize(12)
                    .fontColor('#333B48')
                  Blank()
                  Text(`${act.getEffectiveWatts()} W`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1677FF')
                }
                .width('100%')

                Progress({
                  value: act.getEffectiveWatts(),
                  total: Math.max(100, this.totalWatts),
                  type: ProgressType.Linear
                })
                  .color('#1677FF')
                  .backgroundColor('#EEF1F6')
                  .height(6)
              }
              .width('100%')
            }, (act: ActuatorDevice) => `${act.id}_${this.revision}`)
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        // 3. 内置三类 Mock 核心逻辑自检面板
        Column({ space: 10 }) {
          Row() {
            Column({ space: 2 }) {
              Text('规则引擎 Mock 自检面板')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A2233')
              Text('隔离验证正常 / 边界 / 异常三类用例，不污染当前设备状态')
                .fontSize(11)
                .fontColor('#8C95A6')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button('一键自检')
              .type(ButtonType.Capsule)
              .height(32)
              .fontSize(12)
              .backgroundColor('#722ED1')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.diagReport = this.store.runBuiltInMockSuite();
                this.showTip(`Mock自检完成: ${this.diagReport.passedCount}/${this.diagReport.totalCount} 通过`);
              })
          }
          .width('100%')

          if (this.diagReport !== undefined) {
            Text(`最近执行：${this.diagReport.runAtText} · 通过 ${this.diagReport.passedCount}/${this.diagReport.totalCount}`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.diagReport.passedCount === this.diagReport.totalCount ? '#00B578' : '#FF4D4F')

            ForEach(this.diagReport.items, (item: MockDiagItem) => {
              Column({ space: 4 }) {
                Row() {
                  Text(item.category)
                    .fontSize(10)
                    .fontColor('#FFFFFF')
                    .backgroundColor(item.category === '正常' ? '#1677FF' : (item.category === '边界' ? '#FA8C16' : '#722ED1'))
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(6)

                  Text(item.name)
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A2233')
                    .margin({ left: 6 })
                    .layoutWeight(1)

                  Text(item.passed ? 'PASS' : 'FAIL')
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(item.passed ? '#00B578' : '#FF4D4F')
                }
                .width('100%')

                Text(`输入：${item.inputDesc}`)
                  .fontSize(11)
                  .fontColor('#4E5969')
                Text(`预期：${item.expectedDesc}`)
                  .fontSize(11)
                  .fontColor('#4E5969')
                Text(`实际：${item.actualDesc}`)
                  .fontSize(11)
                  .fontColor('#1677FF')
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#FAFBFD')
              .borderRadius(10)
              .border({ width: 1, color: item.passed ? '#D9F7BE' : '#FFCCC7' })
              .alignItems(HorizontalAlign.Start)
            }, (item: MockDiagItem) => item.name)
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 20 })
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FA')
  }
}
