import { getRoomDisplayName, RoomId } from '../model/Types';

/**
 * 可复用设备卡片自定义组件
 * 支持传感器读数展示、告警高亮、离线标识与执行器快捷开关
 */
@Component
export struct DeviceCard {
  @Prop deviceId: string = '';
  @Prop deviceName: string = '';
  @Prop roomId: RoomId = RoomId.LIVING_ROOM;
  @Prop isActuator: boolean = false;
  @Prop online: boolean = true;
  @Prop powerOn: boolean = false;
  @Prop alertActive: boolean = false;
  @Prop primaryValue: string = '';
  @Prop summaryText: string = '';
  @Prop effectiveWatts: number = 0;

  onCardClick: (deviceId: string) => void = () => {};
  onTogglePower: (deviceId: string) => void = () => {};

  private getBadgeColor(): string {
    if (!this.online) {
      return '#8C95A6';
    }
    if (this.alertActive) {
      return '#FF4D4F';
    }
    if (this.isActuator) {
      return this.powerOn ? '#1677FF' : '#8C95A6';
    }
    return '#00B578';
  }

  private getCardBorderColor(): string {
    if (this.alertActive) {
      return '#FFA39E';
    }
    if (!this.online) {
      return '#E5E7EB';
    }
    if (this.isActuator && this.powerOn) {
      return '#BAE0FF';
    }
    return '#EEF1F6';
  }

  build() {
    Column({ space: 8 }) {
      // 顶部：房间标签 + 在线/告警状态点
      Row() {
        Text(getRoomDisplayName(this.roomId))
          .fontSize(11)
          .fontColor('#5B6577')
          .backgroundColor('#F2F4F8')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)

        Blank()

        Row({ space: 4 }) {
          Circle({ width: 7, height: 7 })
            .fill(this.getBadgeColor())
          Text(!this.online ? '离线' : (this.alertActive ? '告警' : (this.isActuator ? (this.powerOn ? '运行' : '待机') : '传感')))
            .fontSize(11)
            .fontColor(this.getBadgeColor())
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')

      // 中部：设备名称与核心数值
      Column({ space: 4 }) {
        Text(this.deviceName)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A2233')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.primaryValue)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(!this.online ? '#99A1B3' : (this.alertActive ? '#FF4D4F' : (this.isActuator && this.powerOn ? '#1677FF' : '#1A2233')))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 底部：摘要描述 + 执行器开关 / 传感器详情提示
      Row() {
        Column({ space: 2 }) {
          Text(this.summaryText)
            .fontSize(11)
            .fontColor('#6E7787')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.isActuator && this.online && this.powerOn) {
            Text(`实时功耗 ${this.effectiveWatts}W`)
              .fontSize(10)
              .fontColor('#1677FF')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.isActuator) {
          Toggle({ type: ToggleType.Switch, isOn: this.powerOn })
            .selectedColor('#1677FF')
            .switchPointColor('#FFFFFF')
            .enabled(this.online)
            .width(42)
            .height(24)
            .onChange((isOn: boolean) => {
              if (isOn !== this.powerOn) {
                this.onTogglePower(this.deviceId);
              }
            })
        } else {
          Text('调节 ›')
            .fontSize(11)
            .fontColor('#1677FF')
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.alertActive ? '#FFF2F0' : '#FFFFFF')
    .borderRadius(16)
    .border({ width: 1, color: this.getCardBorderColor() })
    .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 2 })
    .onClick(() => {
      this.onCardClick(this.deviceId);
    })
  }
}
