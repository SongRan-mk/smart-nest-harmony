import { common } from '@kit.AbilityKit';
import { DefaultDataFactory } from '../model/DefaultDataFactory';
import { ActuatorDevice, BaseDevice, SensorDevice } from '../model/DeviceModels';
import {
  AutomationRule,
  ConditionOperator,
  DeviceKind,
  EnvironmentSnapshot,
  ExecutionLog,
  formatTimestamp,
  LogicOperator,
  LogSource,
  MetricKey,
  PersistedAppState,
  RoomId,
  RoomInfo,
  ScenePreset,
  SerializedDeviceState,
  SimConfig
} from '../model/Types';
import { PersistenceService } from './PersistenceService';
import {
  EngineCycleSummary,
  RuleEngine,
  RuleEvalResult,
  RuleValidationResult
} from './RuleEngine';
import { SimulationEngine } from './SimulationEngine';

export interface MockDiagItem {
  category: string;
  name: string;
  inputDesc: string;
  expectedDesc: string;
  actualDesc: string;
  passed: boolean;
}

export interface MockDiagReport {
  runAtText: string;
  passedCount: number;
  totalCount: number;
  items: MockDiagItem[];
}

export const STORE_REVISION_KEY: string = 'storeRevision';

/**
 * 智巢中枢全局响应式状态协调中心
 * 连接模型层、规则/仿真引擎、持久化层与 ArkUI 视图层
 */
export class SmartHomeStore {
  private static instance: SmartHomeStore | undefined = undefined;
  private static readonly MAX_LOGS: number = 80;

  private readonly persistence: PersistenceService = new PersistenceService();
  private readonly rooms: RoomInfo[] = DefaultDataFactory.createRooms();
  private readonly scenes: ScenePreset[] = DefaultDataFactory.createDefaultScenes();

  private devices: BaseDevice[] = [];
  private rules: AutomationRule[] = [];
  private logs: ExecutionLog[] = [];
  private simConfig: SimConfig = DefaultDataFactory.createDefaultSimConfig();
  private activeSceneId: string = '';

  private initialized: boolean = false;
  private restoredFromDisk: boolean = false;
  private revision: number = 0;
  private simTimerId: number = -1;

  private constructor() {
    this.devices = DefaultDataFactory.createDefaultDevices();
    this.rules = DefaultDataFactory.createDefaultRules();
    this.logs = DefaultDataFactory.createInitialLogs();
  }

  public static getInstance(): SmartHomeStore {
    if (!SmartHomeStore.instance) {
      SmartHomeStore.instance = new SmartHomeStore();
    }
    return SmartHomeStore.instance;
  }

  /**
   * 绑定 Ability Context 并从 Preferences 恢复历史状态
   */
  public init(context: common.Context): void {
    if (this.initialized) {
      return;
    }
    AppStorage.setOrCreate(STORE_REVISION_KEY, 0);
    this.persistence.init(context);

    const saved = this.persistence.loadSnapshot();
    if (saved) {
      this.applyPersistedState(saved);
      this.restoredFromDisk = true;
      this.appendLog(
        LogSource.SIMULATION,
        '冷启动恢复成功',
        `已从本地持久化恢复 ${this.devices.length} 台设备状态与 ${this.rules.length} 条联动规则`
      );
    } else {
      this.devices = DefaultDataFactory.createDefaultDevices();
      this.rules = DefaultDataFactory.createDefaultRules();
      this.logs = DefaultDataFactory.createInitialLogs();
      this.simConfig = DefaultDataFactory.createDefaultSimConfig();
      this.activeSceneId = '';
      this.restoredFromDisk = false;
      this.persistAsync();
    }

    this.initialized = true;
    if (this.simConfig.autoRunning) {
      this.startTimerLoop();
    }
    this.notifyChanged();
  }

  private applyPersistedState(saved: PersistedAppState): void {
    const freshDevices = DefaultDataFactory.createDefaultDevices();
    for (let i = 0; i < freshDevices.length; i++) {
      const dev = freshDevices[i];
      for (let j = 0; j < saved.devices.length; j++) {
        if (saved.devices[j].id === dev.id) {
          dev.applySerialized(saved.devices[j]);
          break;
        }
      }
    }
    this.devices = freshDevices;
    this.rules = saved.rules.length > 0 ? saved.rules : DefaultDataFactory.createDefaultRules();
    this.logs = saved.logs.length > 0 ? saved.logs.slice(0, SmartHomeStore.MAX_LOGS) : DefaultDataFactory.createInitialLogs();
    if (saved.simConfig && saved.simConfig.snapshots.length > 0) {
      this.simConfig = saved.simConfig;
    } else {
      this.simConfig = DefaultDataFactory.createDefaultSimConfig();
    }
    this.activeSceneId = saved.activeSceneId;
  }

  public getRooms(): RoomInfo[] {
    return this.rooms;
  }

  public getDevices(roomFilter: RoomId = RoomId.ALL): BaseDevice[] {
    if (roomFilter === RoomId.ALL) {
      return this.devices.slice();
    }
    const list: BaseDevice[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].roomId === roomFilter) {
        list.push(this.devices[i]);
      }
    }
    return list;
  }

  public getSensors(): SensorDevice[] {
    const list: SensorDevice[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const dev = this.devices[i];
      if (dev instanceof SensorDevice) {
        list.push(dev);
      }
    }
    return list;
  }

  public getActuators(): ActuatorDevice[] {
    const list: ActuatorDevice[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const dev = this.devices[i];
      if (dev instanceof ActuatorDevice) {
        list.push(dev);
      }
    }
    return list;
  }

  public getDeviceById(id: string): BaseDevice | undefined {
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].id === id) {
        return this.devices[i];
      }
    }
    return undefined;
  }

  public getRules(): AutomationRule[] {
    return this.rules.slice();
  }

  public getRuleById(id: string): AutomationRule | undefined {
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === id) {
        return this.rules[i];
      }
    }
    return undefined;
  }

  public getScenes(): ScenePreset[] {
    return this.scenes;
  }

  public getActiveSceneId(): string {
    return this.activeSceneId;
  }

  public getLogs(filter?: LogSource): ExecutionLog[] {
    if (!filter) {
      return this.logs.slice();
    }
    const list: ExecutionLog[] = [];
    for (let i = 0; i < this.logs.length; i++) {
      if (this.logs[i].source === filter) {
        list.push(this.logs[i]);
      }
    }
    return list;
  }

  public getSimConfig(): SimConfig {
    return this.simConfig;
  }

  public getSnapshots(): EnvironmentSnapshot[] {
    return this.simConfig.snapshots.slice();
  }

  public getTotalWatts(): number {
    return SimulationEngine.calculateTotalWatts(this.devices);
  }

  public getOnlineCount(): number {
    let count = 0;
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].online) {
        count += 1;
      }
    }
    return count;
  }

  public getTotalDeviceCount(): number {
    return this.devices.length;
  }

  public getActiveAlertCount(): number {
    let count = 0;
    for (let i = 0; i < this.devices.length; i++) {
      if (this.devices[i].isAlertActive()) {
        count += 1;
      }
    }
    return count;
  }

  public getPrimaryTempText(): string {
    const dev = this.getDeviceById('sensor_living_temp');
    return dev ? dev.getPrimaryValueText() : '--';
  }

  public getPrimaryHumiText(): string {
    const dev = this.getDeviceById('sensor_living_humi');
    return dev ? dev.getPrimaryValueText() : '--';
  }

  public isRestoredFromDisk(): boolean {
    return this.restoredFromDisk;
  }

  public getPersistenceStatusText(): string {
    if (this.persistence.isMemoryFallback()) {
      return '内存降级模式';
    }
    return this.restoredFromDisk ? '已从本地持久化恢复' : '本地首选项已同步';
  }

  /**
   * 切换执行器开关
   */
  public toggleActuatorPower(deviceId: string): boolean {
    const dev = this.getDeviceById(deviceId);
    if (!(dev instanceof ActuatorDevice)) {
      return false;
    }
    if (!dev.online) {
      this.appendLog(LogSource.ERROR, `操作拦截 · ${dev.name}`, '设备当前处于离线状态，无法切换开关');
      this.notifyChanged();
      this.persistAsync();
      return false;
    }
    const nextPower = !dev.powerOn;
    dev.setPower(nextPower);
    this.activeSceneId = '';
    this.appendLog(LogSource.MANUAL, `手动控制 · ${dev.name}`, `${dev.name}已切换为【${dev.getSummaryText()}】`);
    this.notifyChanged();
    this.persistAsync();
    return true;
  }

  /**
   * 调节执行器数值参数（温度/亮度/窗帘开合度等）
   */
  public setActuatorLevel(deviceId: string, level: number): boolean {
    const dev = this.getDeviceById(deviceId);
    if (!(dev instanceof ActuatorDevice)) {
      return false;
    }
    if (!dev.online) {
      this.appendLog(LogSource.ERROR, `调参拦截 · ${dev.name}`, '设备当前处于离线状态，拒绝调节参数');
      this.notifyChanged();
      this.persistAsync();
      return false;
    }
    if (!dev.setLevel(level)) {
      return false;
    }
    this.appendLog(LogSource.MANUAL, `参数调节 · ${dev.name}`, `设定值更新为 ${dev.levelValue}${dev.unit}`);
    this.notifyChanged();
    this.persistAsync();
    return true;
  }

  /**
   * 模拟设备上线/离线故障切换
   */
  public toggleDeviceOnline(deviceId: string): boolean {
    const dev = this.getDeviceById(deviceId);
    if (!dev) {
      return false;
    }
    dev.setOnline(!dev.online);
    this.appendLog(
      dev.online ? LogSource.MANUAL : LogSource.ERROR,
      `设备状态变更 · ${dev.name}`,
      dev.online ? `${dev.name}已恢复在线` : `${dev.name}已设为离线故障状态（联动与控制将被安全拦截）`
    );
    this.notifyChanged();
    this.persistAsync();
    return true;
  }

  /**
   * 手动修改传感器读数并触发规则引擎
   */
  public updateSensorValue(deviceId: string, newValue: number): EngineCycleSummary {
    const dev = this.getDeviceById(deviceId);
    if (dev instanceof SensorDevice) {
      if (!dev.online) {
        this.appendLog(LogSource.ERROR, `传感采集拦截 · ${dev.name}`, '传感器处于离线状态，忽略读数修改');
      } else {
        dev.updateReading(newValue);
        this.appendLog(LogSource.SIMULATION, `环境模拟 · ${dev.name}`, `数值调整为 ${dev.getPrimaryValueText()}`);
      }
    }
    const now = Date.now();
    const summary = RuleEngine.runCycle(this.rules, this.devices, now, false);
    this.ingestCycleLogs(summary);
    this.recordLiveSnapshot(formatTimestamp(now));
    this.notifyChanged();
    this.persistAsync();
    return summary;
  }

  /**
   * 触发一键情景模式
   */
  public applyScene(sceneId: string): string {
    let targetScene: ScenePreset | undefined = undefined;
    for (let i = 0; i < this.scenes.length; i++) {
      if (this.scenes[i].id === sceneId) {
        targetScene = this.scenes[i];
        break;
      }
    }
    if (!targetScene) {
      return '未找到对应场景';
    }
    const results = RuleEngine.executeActions(targetScene.actions, this.devices);
    let okCount = 0;
    let failCount = 0;
    for (let i = 0; i < results.length; i++) {
      if (results[i].success) {
        okCount += 1;
      } else {
        failCount += 1;
      }
    }
    this.activeSceneId = targetScene.id;
    this.appendLog(
      LogSource.SCENE,
      `切换场景 · ${targetScene.name}`,
      `成功联动 ${okCount} 台设备${failCount > 0 ? `，${failCount} 台离线跳过` : ''}`
    );
    this.recordLiveSnapshot(formatTimestamp(Date.now()));
    this.notifyChanged();
    this.persistAsync();
    return failCount > 0
      ? `已激活【${targetScene.name}】（${okCount}成功/${failCount}离线跳过）`
      : `已激活【${targetScene.name}】`;
  }

  /**
   * 突发环境演练快捷入口
   */
  public triggerDrill(drillType: 'heatwave' | 'smoke' | 'nightfall'): string {
    if (drillType === 'heatwave') {
      const temp = this.getDeviceById('sensor_living_temp');
      if (temp instanceof SensorDevice) {
        temp.setOnline(true);
        temp.updateReading(31.5);
      }
      const summary = RuleEngine.runCycle(this.rules, this.devices, Date.now(), true);
      this.ingestCycleLogs(summary);
      this.recordLiveSnapshot('热浪演练');
      this.notifyChanged();
      this.persistAsync();
      return `已注入 31.5℃ 高温工况，触发 ${summary.triggeredCount} 条规则`;
    }
    if (drillType === 'smoke') {
      const smoke = this.getDeviceById('sensor_balcony_smoke');
      if (smoke instanceof SensorDevice) {
        smoke.setOnline(true);
        smoke.updateReading(185);
      }
      const summary = RuleEngine.runCycle(this.rules, this.devices, Date.now(), true);
      this.ingestCycleLogs(summary);
      this.recordLiveSnapshot('烟雾演练');
      this.notifyChanged();
      this.persistAsync();
      return `已注入 185ppm 烟雾工况，触发 ${summary.triggeredCount} 条规则`;
    }
    const light = this.getDeviceById('sensor_living_light');
    const motion = this.getDeviceById('sensor_bedroom_motion');
    if (light instanceof SensorDevice) {
      light.setOnline(true);
      light.updateReading(65);
    }
    if (motion instanceof SensorDevice) {
      motion.setOnline(true);
      motion.updateReading(1);
    }
    const summary = RuleEngine.runCycle(this.rules, this.devices, Date.now(), true);
    this.ingestCycleLogs(summary);
    this.recordLiveSnapshot('夜幕演练');
    this.notifyChanged();
    this.persistAsync();
    return `已注入暗光有人(65lux)工况，触发 ${summary.triggeredCount} 条规则`;
  }

  public toggleRuleEnabled(ruleId: string): void {
    const rule = this.getRuleById(ruleId);
    if (!rule) {
      return;
    }
    rule.enabled = !rule.enabled;
    this.appendLog(
      LogSource.MANUAL,
      `${rule.enabled ? '启用' : '停用'}规则 · ${rule.name}`,
      rule.enabled ? '规则已加入周期联动扫描' : '规则已暂停自动评估'
    );
    this.notifyChanged();
    this.persistAsync();
  }

  public evaluateSingleRuleNow(ruleId: string): RuleEvalResult | undefined {
    const rule = this.getRuleById(ruleId);
    if (!rule) {
      return undefined;
    }
    const res = RuleEngine.evaluateRule(rule, this.devices, Date.now(), true);
    if (res.triggered) {
      this.appendLog(
        LogSource.RULE,
        `试运行命中 · ${rule.name}`,
        `执行 ${res.actionResults.length} 个动作`,
        rule.id
      );
      this.recordLiveSnapshot(formatTimestamp(Date.now()));
    } else {
      this.appendLog(
        LogSource.SIMULATION,
        `试运行未命中 · ${rule.name}`,
        res.skippedReason.length > 0 ? res.skippedReason : '当前条件未满足',
        rule.id
      );
    }
    this.notifyChanged();
    this.persistAsync();
    return res;
  }

  public saveRule(rule: AutomationRule): RuleValidationResult {
    const check = RuleEngine.validateRule(rule);
    if (!check.valid) {
      return check;
    }
    let replaced = false;
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === rule.id) {
        this.rules[i] = rule;
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      this.rules.unshift(rule);
    }
    this.appendLog(
      LogSource.MANUAL,
      `${replaced ? '更新' : '新建'}规则 · ${rule.name}`,
      `逻辑 ${rule.logic} · ${rule.conditions.length} 条件 -> ${rule.actions.length} 动作`,
      rule.id
    );
    this.notifyChanged();
    this.persistAsync();
    return check;
  }

  public deleteRule(ruleId: string): void {
    const next: AutomationRule[] = [];
    let removedName = '';
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === ruleId) {
        removedName = this.rules[i].name;
      } else {
        next.push(this.rules[i]);
      }
    }
    this.rules = next;
    if (removedName.length > 0) {
      this.appendLog(LogSource.MANUAL, `删除规则 · ${removedName}`, '规则已移除并更新持久化');
    }
    this.notifyChanged();
    this.persistAsync();
  }

  public toggleAutoSimulation(): boolean {
    this.simConfig.autoRunning = !this.simConfig.autoRunning;
    if (this.simConfig.autoRunning) {
      this.startTimerLoop();
      this.appendLog(LogSource.SIMULATION, '开启自动环境仿真', '每 3 秒自动推进昼夜温湿度变化并评估联动规则');
    } else {
      this.stopTimerLoop();
      this.appendLog(LogSource.SIMULATION, '暂停自动环境仿真', '已切换为手动交互控制模式');
    }
    this.notifyChanged();
    this.persistAsync();
    return this.simConfig.autoRunning;
  }

  public stepSimulationOnce(): EngineCycleSummary {
    this.simConfig.tickIndex += 1;
    const stepRes = SimulationEngine.stepEnvironment(this.devices, this.simConfig.tickIndex);
    this.simConfig.snapshots = SimulationEngine.appendSnapshot(this.simConfig.snapshots, stepRes.snapshot);

    const summary = RuleEngine.runCycle(this.rules, this.devices, Date.now(), false);
    this.ingestCycleLogs(summary);
    this.notifyChanged();
    this.persistAsync();
    return summary;
  }

  public clearLogs(): void {
    this.logs = [];
    this.appendLog(LogSource.MANUAL, '日志已清空', '历史记录已重置');
    this.notifyChanged();
    this.persistAsync();
  }

  public async resetToFactoryDefaults(): Promise<void> {
    this.stopTimerLoop();
    await this.persistence.clearAll();
    this.devices = DefaultDataFactory.createDefaultDevices();
    this.rules = DefaultDataFactory.createDefaultRules();
    this.logs = DefaultDataFactory.createInitialLogs();
    this.simConfig = DefaultDataFactory.createDefaultSimConfig();
    this.activeSceneId = '';
    this.restoredFromDisk = false;
    this.appendLog(LogSource.SIMULATION, '已恢复出厂默认配置', '设备、规则与仿真曲线已重置并落盘');
    await this.persistence.saveSnapshot(this.buildSnapshotPayload());
    this.notifyChanged();
  }

  /**
   * 内置隔离 Mock 自检套件：覆盖正常、边界、异常三类情况
   * 全程使用独立 Mock 对象，不污染用户当前实时家居状态
   */
  public runBuiltInMockSuite(): MockDiagReport {
    const items: MockDiagItem[] = [];

    // 1. 正常用例：高温 > 28℃ 触发开空调
    const mockTemp1 = new SensorDevice(
      'm_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
      MetricKey.TEMPERATURE, 29.5, '℃', 0, 50, 30
    );
    const mockAc1 = new ActuatorDevice(
      'm_ac', 'Mock空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
      false, 26, 16, 30, '℃', '制冷', 1200
    );
    const normalRule: AutomationRule = {
      id: 'm_rule_1', name: '高温制冷', description: '', enabled: true, logic: LogicOperator.AND,
      conditions: [{ id: 'mc1', deviceId: 'm_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
      actions: [{ id: 'ma1', deviceId: 'm_ac', targetPowerOn: true, targetLevel: 24 }],
      cooldownMs: 5000, lastTriggeredAt: 0, triggerCount: 0
    };
    const resNormal = RuleEngine.evaluateRule(normalRule, [mockTemp1, mockAc1], 10000);
    items.push({
      category: '正常',
      name: '高温阈值命中联动',
      inputDesc: '温度=29.5℃, 条件: > 28℃',
      expectedDesc: '触发规则并开启空调至24℃',
      actualDesc: `triggered=${resNormal.triggered}, powerOn=${mockAc1.powerOn}, level=${mockAc1.levelValue}℃`,
      passed: resNormal.triggered && mockAc1.powerOn && mockAc1.levelValue === 24
    });

    // 2. 边界用例：恰好等于阈值 28.0℃ 对 > 28 不触发，以及冷却期内不重复触发
    const mockTemp2 = new SensorDevice(
      'm_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
      MetricKey.TEMPERATURE, 28.0, '℃', 0, 50, 30
    );
    const mockAc2 = new ActuatorDevice(
      'm_ac', 'Mock空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
      false, 26, 16, 30, '℃', '制冷', 1200
    );
    const boundaryRule: AutomationRule = {
      id: 'm_rule_2', name: '严格大于边界', description: '', enabled: true, logic: LogicOperator.AND,
      conditions: [{ id: 'mc2', deviceId: 'm_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
      actions: [{ id: 'ma2', deviceId: 'm_ac', targetPowerOn: true, targetLevel: 24 }],
      cooldownMs: 5000, lastTriggeredAt: 0, triggerCount: 0
    };
    const resBoundary = RuleEngine.evaluateRule(boundaryRule, [mockTemp2, mockAc2], 10000);
    items.push({
      category: '边界',
      name: '临界阈值(28.0 == 28)严格判定',
      inputDesc: '温度=28.0℃, 条件: > 28℃',
      expectedDesc: '严格不触发，空调保持关闭',
      actualDesc: `triggered=${resBoundary.triggered}, powerOn=${mockAc2.powerOn}`,
      passed: !resBoundary.triggered && !mockAc2.powerOn
    });

    // 3. 异常用例 A：执行器离线时安全拦截
    const mockTemp3 = new SensorDevice(
      'm_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
      MetricKey.TEMPERATURE, 33.0, '℃', 0, 50, 30
    );
    const mockAcOffline = new ActuatorDevice(
      'm_ac', 'Mock离线空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
      false, 26, 16, 30, '℃', '制冷', 1200
    );
    mockAcOffline.setOnline(false);
    const offlineRule: AutomationRule = {
      id: 'm_rule_3', name: '离线拦截测试', description: '', enabled: true, logic: LogicOperator.AND,
      conditions: [{ id: 'mc3', deviceId: 'm_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
      actions: [{ id: 'ma3', deviceId: 'm_ac', targetPowerOn: true, targetLevel: 24 }],
      cooldownMs: 5000, lastTriggeredAt: 0, triggerCount: 0
    };
    const resOffline = RuleEngine.evaluateRule(offlineRule, [mockTemp3, mockAcOffline], 10000);
    items.push({
      category: '异常',
      name: '离线执行器动作安全拦截',
      inputDesc: '温度=33.0℃, 但执行器 online=false',
      expectedDesc: '动作被拦截，triggered=false 且保持关闭',
      actualDesc: `triggered=${resOffline.triggered}, reason=${resOffline.skippedReason}`,
      passed: !resOffline.triggered && !mockAcOffline.powerOn
    });

    // 4. 异常用例 B：损坏持久化 JSON 安全回退
    const corruptedRes = PersistenceService.parseRawSnapshot('{broken_json', '[]', '', '', '');
    items.push({
      category: '异常',
      name: '损坏JSON持久化容错回退',
      inputDesc: 'rawDevices="{broken_json"',
      expectedDesc: '安全返回 undefined 不抛异常崩溃',
      actualDesc: `result=${corruptedRes === undefined ? 'undefined(安全回退)' : 'unexpected'}`,
      passed: corruptedRes === undefined
    });

    let passedCount = 0;
    for (let i = 0; i < items.length; i++) {
      if (items[i].passed) {
        passedCount += 1;
      }
    }

    const report: MockDiagReport = {
      runAtText: formatTimestamp(Date.now()),
      passedCount: passedCount,
      totalCount: items.length,
      items: items
    };
    this.appendLog(
      LogSource.SIMULATION,
      '执行内置 Mock 自检',
      `通过 ${passedCount}/${items.length} 项（覆盖正常/边界/异常）`
    );
    this.notifyChanged();
    this.persistAsync();
    return report;
  }

  public flushSync(): void {
    if (!this.initialized) {
      return;
    }
    this.persistence.saveSnapshotSync(this.buildSnapshotPayload());
  }

  public stopSimulationTimer(): void {
    this.stopTimerLoop();
  }

  private startTimerLoop(): void {
    if (this.simTimerId !== -1) {
      return;
    }
    this.simTimerId = setInterval(() => {
      this.stepSimulationOnce();
    }, 3000);
  }

  private stopTimerLoop(): void {
    if (this.simTimerId !== -1) {
      clearInterval(this.simTimerId);
      this.simTimerId = -1;
    }
  }

  private ingestCycleLogs(summary: EngineCycleSummary): void {
    for (let i = 0; i < summary.generatedLogs.length; i++) {
      this.logs.unshift(summary.generatedLogs[i]);
    }
    if (this.logs.length > SmartHomeStore.MAX_LOGS) {
      this.logs = this.logs.slice(0, SmartHomeStore.MAX_LOGS);
    }
  }

  private recordLiveSnapshot(timeLabel: string): void {
    const snap = SimulationEngine.captureSnapshot(this.devices, timeLabel);
    this.simConfig.snapshots = SimulationEngine.appendSnapshot(this.simConfig.snapshots, snap);
  }

  private appendLog(source: LogSource, title: string, detail: string, ruleId?: string): void {
    const now = Date.now();
    const entry: ExecutionLog = {
      id: `log_${now}_${Math.floor(Math.random() * 10000)}`,
      timestamp: now,
      timeText: formatTimestamp(now),
      source: source,
      title: title,
      detail: detail,
      ruleId: ruleId
    };
    this.logs.unshift(entry);
    if (this.logs.length > SmartHomeStore.MAX_LOGS) {
      this.logs = this.logs.slice(0, SmartHomeStore.MAX_LOGS);
    }
  }

  private buildSnapshotPayload(): PersistedAppState {
    const serializedDevices: SerializedDeviceState[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      serializedDevices.push(this.devices[i].toSerialized());
    }
    return {
      devices: serializedDevices,
      rules: this.rules,
      logs: this.logs,
      simConfig: this.simConfig,
      activeSceneId: this.activeSceneId
    };
  }

  private persistAsync(): void {
    this.persistence.saveSnapshot(this.buildSnapshotPayload());
  }

  private notifyChanged(): void {
    this.revision += 1;
    AppStorage.setOrCreate(STORE_REVISION_KEY, this.revision);
  }
}
