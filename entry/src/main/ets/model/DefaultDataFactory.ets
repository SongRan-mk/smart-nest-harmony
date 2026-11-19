import { ActuatorDevice, BaseDevice, SensorDevice } from './DeviceModels';
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
  RoomId,
  RoomInfo,
  RulePriority,
  ScenePreset,
  SimConfig
} from './Types';

/**
 * 出厂默认设备、规则、场景与仿真初始数据工厂
 */
export class DefaultDataFactory {
  public static createRooms(): RoomInfo[] {
    return [
      { id: RoomId.ALL, name: '全屋总览', shortTag: '全部' },
      { id: RoomId.LIVING_ROOM, name: '客厅', shortTag: '客厅' },
      { id: RoomId.BEDROOM, name: '主卧', shortTag: '卧室' },
      { id: RoomId.STUDY, name: '书房', shortTag: '书房' },
      { id: RoomId.BALCONY, name: '阳台', shortTag: '阳台' }
    ];
  }

  public static createDefaultDevices(): BaseDevice[] {
    return [
      // 客厅设备
      new SensorDevice(
        'sensor_living_temp',
        '客厅温度计',
        RoomId.LIVING_ROOM,
        DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE,
        25.4,
        '℃',
        0,
        55,
        30,
        1
      ),
      new SensorDevice(
        'sensor_living_humi',
        '客厅湿度计',
        RoomId.LIVING_ROOM,
        DeviceKind.HUMIDITY_SENSOR,
        MetricKey.HUMIDITY,
        54,
        '%',
        10,
        95,
        85,
        1
      ),
      new SensorDevice(
        'sensor_living_light',
        '客厅光照传感器',
        RoomId.LIVING_ROOM,
        DeviceKind.LIGHT_SENSOR,
        MetricKey.ILLUMINANCE,
        320,
        'lux',
        0,
        1200,
        1100,
        1
      ),
      new ActuatorDevice(
        'act_living_ac',
        '客厅变频空调',
        RoomId.LIVING_ROOM,
        DeviceKind.AIR_CONDITIONER,
        false,
        25,
        16,
        30,
        '℃',
        '制冷',
        1200
      ),
      new ActuatorDevice(
        'act_living_light',
        '客厅主吊灯',
        RoomId.LIVING_ROOM,
        DeviceKind.SMART_LIGHT,
        false,
        75,
        10,
        100,
        '%',
        '暖白光',
        45
      ),
      new ActuatorDevice(
        'act_living_curtain',
        '客厅电动窗帘',
        RoomId.LIVING_ROOM,
        DeviceKind.SMART_CURTAIN,
        true,
        65,
        0,
        100,
        '%',
        '开度',
        35
      ),

      // 卧室设备
      new SensorDevice(
        'sensor_bedroom_motion',
        '卧室人体红外',
        RoomId.BEDROOM,
        DeviceKind.MOTION_SENSOR,
        MetricKey.MOTION_DETECTED,
        1,
        '',
        0,
        1,
        2,
        2
      ),
      new ActuatorDevice(
        'act_bedroom_light',
        '卧室氛围灯',
        RoomId.BEDROOM,
        DeviceKind.SMART_LIGHT,
        false,
        40,
        10,
        100,
        '%',
        '助眠暖光',
        24
      ),
      new ActuatorDevice(
        'act_bedroom_purifier',
        '卧室空气净化器',
        RoomId.BEDROOM,
        DeviceKind.AIR_PURIFIER,
        true,
        50,
        1,
        100,
        '%',
        '静音除味',
        48
      ),

      // 书房设备
      new ActuatorDevice(
        'act_study_lamp',
        '书房护眼台灯',
        RoomId.STUDY,
        DeviceKind.SMART_LIGHT,
        true,
        85,
        10,
        100,
        '%',
        '读写模式',
        18
      ),
      new ActuatorDevice(
        'act_entry_lock',
        '入户智能门锁',
        RoomId.STUDY,
        DeviceKind.SMART_LOCK,
        true,
        1,
        0,
        1,
        '',
        '安全反锁',
        5
      ),

      // 阳台安防设备
      new SensorDevice(
        'sensor_balcony_smoke',
        '阳台烟雾传感器',
        RoomId.BALCONY,
        DeviceKind.SMOKE_SENSOR,
        MetricKey.SMOKE_LEVEL,
        18,
        'ppm',
        0,
        500,
        120,
        3
      ),
      new ActuatorDevice(
        'act_balcony_siren',
        '声光应急报警器',
        RoomId.BALCONY,
        DeviceKind.ALARM_SIREN,
        false,
        1,
        0,
        1,
        '',
        '声光警戒',
        15
      )
    ];
  }

  public static createDefaultRules(): AutomationRule[] {
    return [
      {
        id: 'rule_high_temp_ac',
        name: '高温自动开启制冷',
        description: '当客厅温度高于 28℃ 时，自动开启空调制冷至 24℃ 并适当合拢窗帘',
        enabled: true,
        priority: RulePriority.NORMAL,
        logic: LogicOperator.AND,
        conditions: [
          {
            id: 'cond_temp_gt_28',
            deviceId: 'sensor_living_temp',
            metricKey: MetricKey.TEMPERATURE,
            operator: ConditionOperator.GT,
            threshold: 28
          }
        ],
        actions: [
          {
            id: 'act_ac_on_24',
            deviceId: 'act_living_ac',
            targetPowerOn: true,
            targetLevel: 24,
            targetMode: '强力制冷'
          },
          {
            id: 'act_curtain_30',
            deviceId: 'act_living_curtain',
            targetPowerOn: true,
            targetLevel: 30,
            targetMode: '遮阳'
          }
        ],
        cooldownMs: 8000,
        lastTriggeredAt: 0,
        triggerCount: 0
      },
      {
        id: 'rule_dark_motion_light',
        name: '暗光有人自动照明',
        description: '当室内光照低于 150lux 且卧室监测到人员活动时，自动开启客厅主灯与卧室氛围灯',
        enabled: true,
        priority: RulePriority.NORMAL,
        logic: LogicOperator.AND,
        conditions: [
          {
            id: 'cond_light_lt_150',
            deviceId: 'sensor_living_light',
            metricKey: MetricKey.ILLUMINANCE,
            operator: ConditionOperator.LT,
            threshold: 150
          },
          {
            id: 'cond_motion_eq_1',
            deviceId: 'sensor_bedroom_motion',
            metricKey: MetricKey.MOTION_DETECTED,
            operator: ConditionOperator.EQ,
            threshold: 1
          }
        ],
        actions: [
          {
            id: 'act_living_light_80',
            deviceId: 'act_living_light',
            targetPowerOn: true,
            targetLevel: 80,
            targetMode: '温馨照明'
          },
          {
            id: 'act_bedroom_light_45',
            deviceId: 'act_bedroom_light',
            targetPowerOn: true,
            targetLevel: 45,
            targetMode: '夜灯柔光'
          }
        ],
        cooldownMs: 8000,
        lastTriggeredAt: 0,
        triggerCount: 0
      },
      {
        id: 'rule_smoke_emergency',
        name: '烟雾超标应急防护',
        description: '当阳台烟雾浓度 >= 120ppm 时，立即拉响报警器、全开净化器并开启窗帘通风',
        enabled: true,
        priority: RulePriority.EMERGENCY,
        logic: LogicOperator.OR,
        conditions: [
          {
            id: 'cond_smoke_gte_120',
            deviceId: 'sensor_balcony_smoke',
            metricKey: MetricKey.SMOKE_LEVEL,
            operator: ConditionOperator.GTE,
            threshold: 120
          }
        ],
        actions: [
          {
            id: 'act_siren_on',
            deviceId: 'act_balcony_siren',
            targetPowerOn: true,
            targetMode: '紧急鸣笛'
          },
          {
            id: 'act_purifier_100',
            deviceId: 'act_bedroom_purifier',
            targetPowerOn: true,
            targetLevel: 100,
            targetMode: '强效排烟'
          },
          {
            id: 'act_curtain_100',
            deviceId: 'act_living_curtain',
            targetPowerOn: true,
            targetLevel: 100,
            targetMode: '紧急通风'
          }
        ],
        cooldownMs: 5000,
        lastTriggeredAt: 0,
        triggerCount: 0
      },
      {
        id: 'rule_cool_eco_save',
        name: '凉爽时段节能待机',
        description: '当客厅温度 <= 22℃ 时自动关闭客厅空调进入节能模式',
        enabled: false,
        priority: RulePriority.LOW,
        logic: LogicOperator.AND,
        conditions: [
          {
            id: 'cond_temp_lte_22',
            deviceId: 'sensor_living_temp',
            metricKey: MetricKey.TEMPERATURE,
            operator: ConditionOperator.LTE,
            threshold: 22
          }
        ],
        actions: [
          {
            id: 'act_ac_off',
            deviceId: 'act_living_ac',
            targetPowerOn: false,
            targetMode: '节能待机'
          }
        ],
        cooldownMs: 8000,
        lastTriggeredAt: 0,
        triggerCount: 0
      }
    ];
  }

  public static createDefaultScenes(): ScenePreset[] {
    return [
      {
        id: 'scene_home',
        name: '回家模式',
        description: '开客厅主灯、拉开窗帘、净化器常规运行',
        accentColor: '#1677FF',
        actions: [
          { id: 'sh_1', deviceId: 'act_living_light', targetPowerOn: true, targetLevel: 85, targetMode: '明亮迎宾' },
          { id: 'sh_2', deviceId: 'act_living_curtain', targetPowerOn: true, targetLevel: 80, targetMode: '采光' },
          { id: 'sh_3', deviceId: 'act_bedroom_purifier', targetPowerOn: true, targetLevel: 55, targetMode: '标准循环' },
          { id: 'sh_4', deviceId: 'act_balcony_siren', targetPowerOn: false }
        ]
      },
      {
        id: 'scene_sleep',
        name: '睡眠模式',
        description: '关客厅灯与台灯、拉合窗帘、空调26℃静音、卧室微光',
        accentColor: '#722ED1',
        actions: [
          { id: 'ss_1', deviceId: 'act_living_light', targetPowerOn: false },
          { id: 'ss_2', deviceId: 'act_study_lamp', targetPowerOn: false },
          { id: 'ss_3', deviceId: 'act_living_curtain', targetPowerOn: true, targetLevel: 5, targetMode: '遮光' },
          { id: 'ss_4', deviceId: 'act_living_ac', targetPowerOn: true, targetLevel: 26, targetMode: '睡眠静音' },
          { id: 'ss_5', deviceId: 'act_bedroom_light', targetPowerOn: true, targetLevel: 20, targetMode: '睡眠微光' },
          { id: 'ss_6', deviceId: 'act_entry_lock', targetPowerOn: true }
        ]
      },
      {
        id: 'scene_away',
        name: '离家布防',
        description: '关闭照明与空调、锁闭智能门锁、进入低功耗布防',
        accentColor: '#00B578',
        actions: [
          { id: 'sa_1', deviceId: 'act_living_ac', targetPowerOn: false },
          { id: 'sa_2', deviceId: 'act_living_light', targetPowerOn: false },
          { id: 'sa_3', deviceId: 'act_bedroom_light', targetPowerOn: false },
          { id: 'sa_4', deviceId: 'act_study_lamp', targetPowerOn: false },
          { id: 'sa_5', deviceId: 'act_entry_lock', targetPowerOn: true },
          { id: 'sa_6', deviceId: 'act_balcony_siren', targetPowerOn: false }
        ]
      },
      {
        id: 'scene_reset',
        name: '解除告警',
        description: '关闭声光报警器并重置安全状态',
        accentColor: '#FA8C16',
        actions: [
          { id: 'sr_1', deviceId: 'act_balcony_siren', targetPowerOn: false, targetMode: '待机' },
          { id: 'sr_2', deviceId: 'act_bedroom_purifier', targetPowerOn: true, targetLevel: 45, targetMode: '静音除味' }
        ]
      }
    ];
  }

  public static createDefaultSimConfig(): SimConfig {
    const initialSnapshots: EnvironmentSnapshot[] = [
      { timeLabel: '08:00', temperature: 23.2, humidity: 58, illuminance: 240, smokeLevel: 15, totalWatts: 120 },
      { timeLabel: '10:00', temperature: 24.1, humidity: 56, illuminance: 420, smokeLevel: 16, totalWatts: 96 },
      { timeLabel: '12:00', temperature: 25.0, humidity: 55, illuminance: 510, smokeLevel: 17, totalWatts: 96 },
      { timeLabel: '14:00', temperature: 25.4, humidity: 54, illuminance: 320, smokeLevel: 18, totalWatts: 76 }
    ];
    return {
      autoRunning: false,
      tickIndex: 4,
      snapshots: initialSnapshots
    };
  }

  public static createInitialLogs(): ExecutionLog[] {
    const now = Date.now();
    return [
      {
        id: `log_init_${now}`,
        timestamp: now,
        timeText: formatTimestamp(now),
        source: LogSource.SIMULATION,
        title: '智巢中枢初始化完成',
        detail: '已加载 4 个房间、13 台虚拟设备及 4 条默认联动规则，持久化引擎就绪。'
      }
    ];
  }
}
