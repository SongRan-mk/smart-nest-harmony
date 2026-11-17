import { ExecutionLog, LogSource } from '../model/Types';
import { SmartHomeStore, STORE_REVISION_KEY } from '../service/SmartHomeStore';

interface LogFilterOption {
  key: string;
  label: string;
  source?: LogSource;
}

/**
 * 联动日志与数据持久化管理视图
 */
@Component
export struct LogsView {
  @StorageProp(STORE_REVISION_KEY) revision: number = 0;
  @State selectedFilterKey: string = 'all';

  private store: SmartHomeStore = SmartHomeStore.getInstance();
  private filterOptions: LogFilterOption[] = [
    { key: 'all', label: '全部' },
    { key: 'rule', label: '规则联动', source: LogSource.RULE },
    { key: 'manual', label: '手动控制', source: LogSource.MANUAL },
    { key: 'scene', label: '场景切换', source: LogSource.SCENE },
    { key: 'sim', label: '仿真运行', source: LogSource.SIMULATION },
    { key: 'error', label: '异常拦截', source: LogSource.ERROR }
  ];

  private getFilteredLogs(): ExecutionLog[] {
    if (this.revision < 0) {
      return [];
    }
    for (let i = 0; i < this.filterOptions.length; i++) {
      if (this.filterOptions[i].key === this.selectedFilterKey) {
        return this.store.getLogs(this.filterOptions[i].source);
      }
    }
    return this.store.getLogs();
  }

  private getSourceLabel(src: LogSource): string {
    switch (src) {
      case LogSource.RULE:
        return '规则触发';
      case LogSource.MANUAL:
        return '手动操作';
      case LogSource.SCENE:
        return '场景模式';
      case LogSource.SIMULATION:
        return '仿真系统';
      case LogSource.ERROR:
        return '异常拦截';
      default:
        return '系统';
    }
  }

  private getSourceColor(src: LogSource): string {
    switch (src) {
      case LogSource.RULE:
        return '#00B578';
      case LogSource.MANUAL:
        return '#1677FF';
      case LogSource.SCENE:
        return '#722ED1';
      case LogSource.SIMULATION:
        return '#FA8C16';
      case LogSource.ERROR:
        return '#FF4D4F';
      default:
        return '#8C95A6';
    }
  }

  private showTip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (_err) {
      // ignore
    }
  }

  private confirmFactoryReset(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: '恢复出厂默认配置',
        message: '确定清空本地 Preferences 持久化并恢复默认设备、规则与曲线吗？',
        autoCancel: true,
        primaryButton: {
          value: '取消',
          action: () => {}
        },
        secondaryButton: {
          value: '确认重置',
          fontColor: '#FF4D4F',
          action: () => {
            this.store.resetToFactoryDefaults().then(() => {
              this.showTip('已恢复出厂配置并重新持久化');
            });
          }
        }
      });
    } catch (_err) {
      this.store.resetToFactoryDefaults();
    }
  }

  build() {
    Column({ space: 12 }) {
      // 顶部标题与操作按钮
      Row() {
        Column({ space: 2 }) {
          Text('联动日志与存储')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A2233')
          Text(`共记录 ${this.getFilteredLogs().length} 条事件 · 重启自动恢复`)
            .fontSize(12)
            .fontColor('#6E7787')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 8 }) {
          Button('清空')
            .type(ButtonType.Normal)
            .height(30)
            .fontSize(12)
            .borderRadius(8)
            .fontColor('#4E5969')
            .backgroundColor('#FFFFFF')
            .onClick(() => {
              this.store.clearLogs();
              this.showTip('日志已清空');
            })

          Button('恢复出厂')
            .type(ButtonType.Normal)
            .height(30)
            .fontSize(12)
            .borderRadius(8)
            .fontColor('#FF4D4F')
            .backgroundColor('#FFF1F0')
            .onClick(() => {
              this.confirmFactoryReset();
            })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 })

      // 类别过滤栏
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.filterOptions, (opt: LogFilterOption) => {
            Text(opt.label)
              .fontSize(12)
              .fontWeight(this.selectedFilterKey === opt.key ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.selectedFilterKey === opt.key ? '#FFFFFF' : '#4E5969')
              .backgroundColor(this.selectedFilterKey === opt.key ? '#1677FF' : '#FFFFFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .border({ width: 1, color: this.selectedFilterKey === opt.key ? '#1677FF' : '#E5E7EB' })
              .onClick(() => {
                this.selectedFilterKey = opt.key;
              })
          }, (opt: LogFilterOption) => opt.key)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      // 日志列表
      if (this.getFilteredLogs().length === 0) {
        Column({ space: 8 }) {
          Text('当前筛选分类下暂无日志')
            .fontSize(14)
            .fontColor('#8C95A6')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.getFilteredLogs(), (log: ExecutionLog) => {
            ListItem() {
              Column({ space: 6 }) {
                Row() {
                  Text(this.getSourceLabel(log.source))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .backgroundColor(this.getSourceColor(log.source))
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                    .borderRadius(8)

                  Text(log.title)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A2233')
                    .margin({ left: 8 })
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(log.timeText)
                    .fontSize(11)
                    .fontColor('#8C95A6')
                }
                .width('100%')

                Text(log.detail)
                  .fontSize(12)
                  .fontColor('#4E5969')
                  .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .border({ width: 1, color: log.source === LogSource.ERROR ? '#FFCCC7' : '#EEF1F6' })
            }
          }, (log: ExecutionLog) => log.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FA')
  }
}
