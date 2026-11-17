import {
  DeviceCategory,
  DeviceKind,
  MetricKey,
  RoomId,
  SerializedDeviceState
} from './Types';

/**
 * 智能设备抽象基类
 * 封装设备基础属性与多态行为接口
 */
export abstract class BaseDevice {
  public readonly id: string;
  public readonly name: string;
  public readonly roomId: RoomId;
  public readonly category: DeviceCategory;
  public readonly kind: DeviceKind;
  public readonly ratedWatts: number;
  public online: boolean;
  public lastUpdated: number;

  constructor(
    id: string,
    name: string,
    roomId: RoomId,
    category: DeviceCategory,
    kind: DeviceKind,
    ratedWatts: number,
    online: boolean = true
  ) {
    this.id = id;
    this.name = name;
    this.roomId = roomId;
    this.category = category;
    this.kind = kind;
    this.ratedWatts = ratedWatts;
    this.online = online;
    this.lastUpdated = Date.now();
  }

  public setOnline(online: boolean): void {
    this.online = online;
    this.lastUpdated = Date.now();
  }

  public abstract getSummaryText(): string;

  public abstract getPrimaryValueText(): string;

  public abstract getEffectiveWatts(): number;

  public abstract isAlertActive(): boolean;

  public abstract toSerialized(): SerializedDeviceState;

  public abstract applySerialized(state: SerializedDeviceState): void;
}

/**
 * 传感器设备子类
 * 负责环境量采集、量程校验与告警判定
 */
export class SensorDevice extends BaseDevice {
  public readonly metricKey: MetricKey;
  public readonly unit: string;
  public readonly minVal: number;
  public readonly maxVal: number;
  public readonly alertThreshold: number;
  public value: number;

  constructor(
    id: string,
    name: string,
    roomId: RoomId,
    kind: DeviceKind,
    metricKey: MetricKey,
    initialValue: number,
    unit: string,
    minVal: number,
    maxVal: number,
    alertThreshold: number,
    ratedWatts: number = 2
  ) {
    super(id, name, roomId, DeviceCategory.SENSOR, kind, ratedWatts, true);
    this.metricKey = metricKey;
    this.unit = unit;
    this.minVal = minVal;
    this.maxVal = maxVal;
    this.alertThreshold = alertThreshold;
    this.value = this.clampValue(initialValue);
  }

  private clampValue(raw: number): number {
    if (raw < this.minVal) {
      return this.minVal;
    }
    if (raw > this.maxVal) {
      return this.maxVal;
    }
    return Math.round(raw * 10) / 10;
  }

  /**
   * 更新传感器读数，自动过滤非法 NaN 并钳制到物理量程内
   */
  public updateReading(newValue: number): boolean {
    if (!this.online || Number.isNaN(newValue) || !Number.isFinite(newValue)) {
      return false;
    }
    this.value = this.clampValue(newValue);
    this.lastUpdated = Date.now();
    return true;
  }

  public getSummaryText(): string {
    if (!this.online) {
      return '传感器离线';
    }
    if (this.metricKey === MetricKey.MOTION_DETECTED) {
      return this.value >= 1 ? '监测到人员活动' : '当前无人';
    }
    return `实时监测 ${this.value}${this.unit}`;
  }

  public getPrimaryValueText(): string {
    if (!this.online) {
      return '离线';
    }
    if (this.metricKey === MetricKey.MOTION_DETECTED) {
      return this.value >= 1 ? '有人' : '无人';
    }
    return `${this.value}${this.unit}`;
  }

  public getEffectiveWatts(): number {
    return this.online ? this.ratedWatts : 0;
  }

  public isAlertActive(): boolean {
    if (!this.online) {
      return false;
    }
    if (this.metricKey === MetricKey.SMOKE_LEVEL) {
      return this.value >= this.alertThreshold;
    }
    if (this.metricKey === MetricKey.TEMPERATURE) {
      return this.value >= this.alertThreshold;
    }
    return false;
  }

  public toSerialized(): SerializedDeviceState {
    return {
      id: this.id,
      online: this.online,
      lastUpdated: this.lastUpdated,
      sensorValue: this.value
    };
  }

  public applySerialized(state: SerializedDeviceState): void {
    this.online = state.online;
    this.lastUpdated = state.lastUpdated;
    if (state.sensorValue !== undefined && !Number.isNaN(state.sensorValue)) {
      this.value = this.clampValue(state.sensorValue);
    }
  }
}

/**
 * 执行器设备子类
 * 支持开关控制、档位/目标数值调节与动态功耗估算
 */
export class ActuatorDevice extends BaseDevice {
  public powerOn: boolean;
  public levelValue: number;
  public readonly minLevel: number;
  public readonly maxLevel: number;
  public readonly unit: string;
  public modeText: string;

  constructor(
    id: string,
    name: string,
    roomId: RoomId,
    kind: DeviceKind,
    powerOn: boolean,
    levelValue: number,
    minLevel: number,
    maxLevel: number,
    unit: string,
    modeText: string,
    ratedWatts: number
  ) {
    super(id, name, roomId, DeviceCategory.ACTUATOR, kind, ratedWatts, true);
    this.powerOn = powerOn;
    this.minLevel = minLevel;
    this.maxLevel = maxLevel;
    this.unit = unit;
    this.modeText = modeText;
    this.levelValue = this.clampLevel(levelValue);
  }

  private clampLevel(raw: number): number {
    if (raw < this.minLevel) {
      return this.minLevel;
    }
    if (raw > this.maxLevel) {
      return this.maxLevel;
    }
    return Math.round(raw);
  }

  public setPower(on: boolean): boolean {
    if (!this.online) {
      return false;
    }
    this.powerOn = on;
    this.lastUpdated = Date.now();
    return true;
  }

  public setLevel(val: number): boolean {
    if (!this.online || Number.isNaN(val) || !Number.isFinite(val)) {
      return false;
    }
    this.levelValue = this.clampLevel(val);
    this.lastUpdated = Date.now();
    return true;
  }

  public setMode(mode: string): void {
    if (mode.trim().length > 0) {
      this.modeText = mode.trim();
      this.lastUpdated = Date.now();
    }
  }

  public getSummaryText(): string {
    if (!this.online) {
      return '设备已离线';
    }
    if (this.kind === DeviceKind.SMART_LOCK) {
      return this.powerOn ? '已反锁 · 安全布防' : '已解锁 · 通道开启';
    }
    if (this.kind === DeviceKind.ALARM_SIREN) {
      return this.powerOn ? '蜂鸣告警触发中' : '待机警戒中';
    }
    if (!this.powerOn) {
      return '已关闭 · 待机中';
    }
    if (this.maxLevel > this.minLevel) {
      return `${this.modeText} · ${this.levelValue}${this.unit}`;
    }
    return `${this.modeText} · 运行中`;
  }

  public getPrimaryValueText(): string {
    if (!this.online) {
      return '离线';
    }
    if (this.kind === DeviceKind.SMART_LOCK) {
      return this.powerOn ? '已锁' : '未锁';
    }
    if (this.kind === DeviceKind.ALARM_SIREN) {
      return this.powerOn ? '告警' : '正常';
    }
    if (!this.powerOn) {
      return '关闭';
    }
    if (this.maxLevel > this.minLevel) {
      return `${this.levelValue}${this.unit}`;
    }
    return '开启';
  }

  public getEffectiveWatts(): number {
    if (!this.online || !this.powerOn) {
      return 0;
    }
    if (this.kind === DeviceKind.SMART_LIGHT && this.maxLevel > 0) {
      return Math.max(3, Math.round(this.ratedWatts * (this.levelValue / this.maxLevel)));
    }
    if (this.kind === DeviceKind.AIR_PURIFIER && this.maxLevel > 0) {
      return Math.max(8, Math.round(this.ratedWatts * (this.levelValue / this.maxLevel)));
    }
    return this.ratedWatts;
  }

  public isAlertActive(): boolean {
    return this.online && this.kind === DeviceKind.ALARM_SIREN && this.powerOn;
  }

  public toSerialized(): SerializedDeviceState {
    return {
      id: this.id,
      online: this.online,
      lastUpdated: this.lastUpdated,
      powerOn: this.powerOn,
      levelValue: this.levelValue,
      modeText: this.modeText
    };
  }

  public applySerialized(state: SerializedDeviceState): void {
    this.online = state.online;
    this.lastUpdated = state.lastUpdated;
    if (state.powerOn !== undefined) {
      this.powerOn = state.powerOn;
    }
    if (state.levelValue !== undefined && !Number.isNaN(state.levelValue)) {
      this.levelValue = this.clampLevel(state.levelValue);
    }
    if (state.modeText !== undefined && state.modeText.length > 0) {
      this.modeText = state.modeText;
    }
  }
}
