import { EnvironmentSnapshot } from '../model/Types';

export type ChartMetricType = 'temperature' | 'humidity' | 'illuminance' | 'smokeLevel' | 'totalWatts';

/**
 * 基于 Canvas 的环境指标历史趋势折线图组件
 */
@Component
export struct EnvironmentChart {
  @Prop @Watch('onPropsChanged') snapshots: EnvironmentSnapshot[] = [];
  @Prop @Watch('onPropsChanged') metric: ChartMetricType = 'temperature';
  @Prop @Watch('onPropsChanged') revision: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasReady: boolean = false;

  onPropsChanged(): void {
    if (this.canvasReady) {
      this.drawChart();
    }
  }

  private extractValue(snap: EnvironmentSnapshot): number {
    switch (this.metric) {
      case 'temperature':
        return snap.temperature;
      case 'humidity':
        return snap.humidity;
      case 'illuminance':
        return snap.illuminance;
      case 'smokeLevel':
        return snap.smokeLevel;
      case 'totalWatts':
        return snap.totalWatts;
      default:
        return snap.temperature;
    }
  }

  private getStrokeColor(): string {
    switch (this.metric) {
      case 'temperature':
        return '#FA8C16';
      case 'humidity':
        return '#1677FF';
      case 'illuminance':
        return '#722ED1';
      case 'smokeLevel':
        return '#FF4D4F';
      case 'totalWatts':
        return '#00B578';
      default:
        return '#1677FF';
    }
  }

  private getUnit(): string {
    switch (this.metric) {
      case 'temperature':
        return '℃';
      case 'humidity':
        return '%';
      case 'illuminance':
        return 'lux';
      case 'smokeLevel':
        return 'ppm';
      case 'totalWatts':
        return 'W';
      default:
        return '';
    }
  }

  private drawChart(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }

    this.ctx.clearRect(0, 0, w, h);

    const padLeft = 42;
    const padRight = 16;
    const padTop = 18;
    const padBottom = 28;
    const plotW = w - padLeft - padRight;
    const plotH = h - padTop - padBottom;

    if (this.snapshots.length === 0) {
      this.ctx.fillStyle = '#8C95A6';
      this.ctx.font = '12vp sans-serif';
      this.ctx.fillText('暂无采样数据', padLeft, h / 2);
      return;
    }

    let minVal = this.extractValue(this.snapshots[0]);
    let maxVal = minVal;
    for (let i = 1; i < this.snapshots.length; i++) {
      const v = this.extractValue(this.snapshots[i]);
      if (v < minVal) {
        minVal = v;
      }
      if (v > maxVal) {
        maxVal = v;
      }
    }
    if (Math.abs(maxVal - minVal) < 2) {
      minVal = Math.max(0, minVal - 2);
      maxVal = maxVal + 2;
    } else {
      const margin = (maxVal - minVal) * 0.15;
      minVal = Math.max(0, Math.floor(minVal - margin));
      maxVal = Math.ceil(maxVal + margin);
    }

    // 绘制水平辅助网格与 Y 轴刻度
    this.ctx.strokeStyle = '#ECEFF5';
    this.ctx.lineWidth = 1;
    this.ctx.fillStyle = '#7A8394';
    this.ctx.font = '10vp sans-serif';
    const gridRows = 4;
    for (let r = 0; r <= gridRows; r++) {
      const ratio = r / gridRows;
      const y = padTop + plotH * (1 - ratio);
      const labelVal = Math.round((minVal + (maxVal - minVal) * ratio) * 10) / 10;

      this.ctx.beginPath();
      this.ctx.moveTo(padLeft, y);
      this.ctx.lineTo(w - padRight, y);
      this.ctx.stroke();

      this.ctx.fillText(`${labelVal}`, 4, y + 3);
    }

    // 计算坐标点
    const count = this.snapshots.length;
    const strokeColor = this.getStrokeColor();
    const xs: number[] = [];
    const ys: number[] = [];

    for (let i = 0; i < count; i++) {
      const x = count === 1 ? (padLeft + plotW / 2) : (padLeft + (plotW * i) / (count - 1));
      const v = this.extractValue(this.snapshots[i]);
      const norm = (v - minVal) / (maxVal - minVal);
      const y = padTop + plotH * (1 - norm);
      xs.push(x);
      ys.push(y);
    }

    // 渐变填充区域
    if (count >= 2) {
      this.ctx.beginPath();
      this.ctx.moveTo(xs[0], padTop + plotH);
      for (let i = 0; i < count; i++) {
        this.ctx.lineTo(xs[i], ys[i]);
      }
      this.ctx.lineTo(xs[count - 1], padTop + plotH);
      this.ctx.closePath();
      this.ctx.fillStyle = 'rgba(22, 119, 255, 0.09)';
      this.ctx.fill();
    }

    // 折线主路径
    this.ctx.beginPath();
    this.ctx.strokeStyle = strokeColor;
    this.ctx.lineWidth = 2.5;
    for (let i = 0; i < count; i++) {
      if (i === 0) {
        this.ctx.moveTo(xs[i], ys[i]);
      } else {
        this.ctx.lineTo(xs[i], ys[i]);
      }
    }
    this.ctx.stroke();

    // 数据节点圆点与最新值标注
    for (let i = 0; i < count; i++) {
      this.ctx.beginPath();
      this.ctx.fillStyle = '#FFFFFF';
      this.ctx.arc(xs[i], ys[i], 3.5, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.strokeStyle = strokeColor;
      this.ctx.lineWidth = 2;
      this.ctx.stroke();
    }

    const lastIdx = count - 1;
    const lastVal = this.extractValue(this.snapshots[lastIdx]);
    this.ctx.fillStyle = strokeColor;
    this.ctx.font = 'bold 11vp sans-serif';
    const textX = Math.max(padLeft, Math.min(xs[lastIdx] - 18, w - padRight - 46));
    const textY = Math.max(12, ys[lastIdx] - 8);
    this.ctx.fillText(`${lastVal}${this.getUnit()}`, textX, textY);

    // X 轴稀疏时间标签
    this.ctx.fillStyle = '#7A8394';
    this.ctx.font = '10vp sans-serif';
    const step = count <= 5 ? 1 : Math.ceil(count / 4);
    for (let i = 0; i < count; i += step) {
      this.ctx.fillText(this.snapshots[i].timeLabel, Math.max(padLeft, xs[i] - 14), h - 8);
    }
    if (lastIdx > 0 && lastIdx % step !== 0) {
      this.ctx.fillText(this.snapshots[lastIdx].timeLabel, Math.min(xs[lastIdx] - 14, w - padRight - 30), h - 8);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(190)
      .backgroundColor('#FAFBFD')
      .borderRadius(12)
      .onReady(() => {
        this.canvasReady = true;
        this.drawChart();
      })
  }
}
