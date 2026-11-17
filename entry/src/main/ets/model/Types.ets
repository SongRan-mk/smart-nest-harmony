/**
 * 核心领域类型、枚举与数据结构定义
 * 对应《软件需求说明书》第 5 章数据模型设计
 */

export enum RoomId {
  ALL = 'all',
  LIVING_ROOM = 'living_room',
  BEDROOM = 'bedroom',
  STUDY = 'study',
  BALCONY = 'balcony'
}

export enum DeviceCategory {
  SENSOR = 'sensor',
  ACTUATOR = 'actuator'
}

export enum DeviceKind {
  TEMPERATURE_SENSOR = 'temperature_sensor',
  HUMIDITY_SENSOR = 'humidity_sensor',
  LIGHT_SENSOR = 'light_sensor',
  SMOKE_SENSOR = 'smoke_sensor',
  MOTION_SENSOR = 'motion_sensor',
  AIR_CONDITIONER = 'air_conditioner',
  SMART_LIGHT = 'smart_light',
  SMART_CURTAIN = 'smart_curtain',
  AIR_PURIFIER = 'air_purifier',
  SMART_LOCK = 'smart_lock',
  ALARM_SIREN = 'alarm_siren'
}

export enum MetricKey {
  TEMPERATURE = 'temperature',
  HUMIDITY = 'humidity',
  ILLUMINANCE = 'illuminance',
  SMOKE_LEVEL = 'smokeLevel',
  MOTION_DETECTED = 'motionDetected'
}

export enum ConditionOperator {
  GT = 'gt',
  GTE = 'gte',
  LT = 'lt',
  LTE = 'lte',
  EQ = 'eq',
  NEQ = 'neq'
}

export enum LogicOperator {
  AND = 'AND',
  OR = 'OR'
}

export enum LogSource {
  RULE = 'rule',
  MANUAL = 'manual',
  SCENE = 'scene',
  SIMULATION = 'simulation',
  ERROR = 'error'
}

export interface RoomInfo {
  id: RoomId;
  name: string;
  shortTag: string;
}

export interface SerializedDeviceState {
  id: string;
  online: boolean;
  lastUpdated: number;
  sensorValue?: number;
  powerOn?: boolean;
  levelValue?: number;
  modeText?: string;
}

export interface RuleCondition {
  id: string;
  deviceId: string;
  metricKey: MetricKey;
  operator: ConditionOperator;
  threshold: number;
}

export interface RuleAction {
  id: string;
  deviceId: string;
  targetPowerOn: boolean;
  targetLevel?: number;
  targetMode?: string;
}

export interface AutomationRule {
  id: string;
  name: string;
  description: string;
  enabled: boolean;
  logic: LogicOperator;
  conditions: RuleCondition[];
  actions: RuleAction[];
  cooldownMs: number;
  lastTriggeredAt: number;
  triggerCount: number;
}

export interface ScenePreset {
  id: string;
  name: string;
  description: string;
  accentColor: string;
  actions: RuleAction[];
}

export interface ExecutionLog {
  id: string;
  timestamp: number;
  timeText: string;
  source: LogSource;
  title: string;
  detail: string;
  ruleId?: string;
}

export interface EnvironmentSnapshot {
  timeLabel: string;
  temperature: number;
  humidity: number;
  illuminance: number;
  smokeLevel: number;
  totalWatts: number;
}

export interface SimConfig {
  autoRunning: boolean;
  tickIndex: number;
  snapshots: EnvironmentSnapshot[];
}

export interface PersistedAppState {
  devices: SerializedDeviceState[];
  rules: AutomationRule[];
  logs: ExecutionLog[];
  simConfig: SimConfig;
  activeSceneId: string;
}

export function getRoomDisplayName(roomId: RoomId): string {
  switch (roomId) {
    case RoomId.LIVING_ROOM:
      return '客厅';
    case RoomId.BEDROOM:
      return '卧室';
    case RoomId.STUDY:
      return '书房';
    case RoomId.BALCONY:
      return '阳台';
    default:
      return '全部房间';
  }
}

export function getOperatorSymbol(op: ConditionOperator): string {
  switch (op) {
    case ConditionOperator.GT:
      return '>';
    case ConditionOperator.GTE:
      return '>=';
    case ConditionOperator.LT:
      return '<';
    case ConditionOperator.LTE:
      return '<=';
    case ConditionOperator.EQ:
      return '==';
    case ConditionOperator.NEQ:
      return '!=';
    default:
      return '>';
  }
}

export function formatTimestamp(ts: number): string {
  const date = new Date(ts);
  const hh = date.getHours().toString().padStart(2, '0');
  const mm = date.getMinutes().toString().padStart(2, '0');
  const ss = date.getSeconds().toString().padStart(2, '0');
  return `${hh}:${mm}:${ss}`;
}
