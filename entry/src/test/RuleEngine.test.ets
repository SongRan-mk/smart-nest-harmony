import { describe, it, expect } from '@ohos/hypium';
import { ActuatorDevice, SensorDevice } from '../main/ets/model/DeviceModels';
import {
  AutomationRule,
  ConditionOperator,
  DeviceKind,
  LogicOperator,
  MetricKey,
  RoomId,
  RulePriority
} from '../main/ets/model/Types';
import { PersistenceService } from '../main/ets/service/PersistenceService';
import { RuleEngine } from '../main/ets/service/RuleEngine';
import { SimulationEngine } from '../main/ets/service/SimulationEngine';
import { SmartHomeStore } from '../main/ets/service/SmartHomeStore';

export default function ruleEngineTest() {
  describe('SmartNestRuleEngineAndSimTests', () => {
    // 1. 正常用例：高温触发空调制冷联动
    it('normal_high_temp_triggers_ac', 0, () => {
      const temp = new SensorDevice(
        's_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 29.5, '℃', 0, 55, 30
      );
      const ac = new ActuatorDevice(
        'a_ac', 'Mock空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
        false, 26, 16, 30, '℃', '制冷', 1200
      );
      const rule: AutomationRule = {
        id: 'r_1',
        name: '高温制冷',
        description: '',
        enabled: true,
        logic: LogicOperator.AND,
        conditions: [
          { id: 'c1', deviceId: 's_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }
        ],
        actions: [
          { id: 'act1', deviceId: 'a_ac', targetPowerOn: true, targetLevel: 24, targetMode: '强力制冷' }
        ],
        cooldownMs: 5000,
        lastTriggeredAt: 0,
        triggerCount: 0
      };

      const res = RuleEngine.evaluateRule(rule, [temp, ac], 10000);
      expect(res.triggered).assertTrue();
      expect(ac.powerOn).assertTrue();
      expect(ac.levelValue).assertEqual(24);
      expect(rule.triggerCount).assertEqual(1);
    });

    // 2. 正常用例：AND 与 OR 多条件组合逻辑
    it('normal_and_or_logic_combination', 0, () => {
      const light = new SensorDevice(
        's_light', 'Mock光照', RoomId.LIVING_ROOM, DeviceKind.LIGHT_SENSOR,
        MetricKey.ILLUMINANCE, 90, 'lux', 0, 1200, 1000
      );
      const motion = new SensorDevice(
        's_motion', 'Mock红外', RoomId.BEDROOM, DeviceKind.MOTION_SENSOR,
        MetricKey.MOTION_DETECTED, 0, '', 0, 1, 2
      );
      const lamp = new ActuatorDevice(
        'a_lamp', 'Mock主灯', RoomId.LIVING_ROOM, DeviceKind.SMART_LIGHT,
        false, 80, 10, 100, '%', '暖白', 40
      );

      const andRule: AutomationRule = {
        id: 'r_and', name: '暗光且有人', description: '', enabled: true, logic: LogicOperator.AND,
        conditions: [
          { id: 'c1', deviceId: 's_light', metricKey: MetricKey.ILLUMINANCE, operator: ConditionOperator.LT, threshold: 150 },
          { id: 'c2', deviceId: 's_motion', metricKey: MetricKey.MOTION_DETECTED, operator: ConditionOperator.EQ, threshold: 1 }
        ],
        actions: [{ id: 'a1', deviceId: 'a_lamp', targetPowerOn: true, targetLevel: 75 }],
        cooldownMs: 0, lastTriggeredAt: 0, triggerCount: 0
      };

      const andRes = RuleEngine.evaluateRule(andRule, [light, motion, lamp], 1000);
      expect(andRes.triggered).assertFalse();
      expect(lamp.powerOn).assertFalse();

      andRule.logic = LogicOperator.OR;
      const orRes = RuleEngine.evaluateRule(andRule, [light, motion, lamp], 2000);
      expect(orRes.triggered).assertTrue();
      expect(lamp.powerOn).assertTrue();
    });

    // 3. 正常用例：仿真引擎物理反馈与总功耗计算
    it('normal_simulation_physics_cooling_and_watts', 0, () => {
      const temp = new SensorDevice(
        'sensor_living_temp', '客厅温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 30.0, '℃', 0, 55, 30, 1
      );
      const ac = new ActuatorDevice(
        'act_living_ac', '客厅空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
        true, 24, 16, 30, '℃', '制冷', 1200
      );

      const stepRes = SimulationEngine.stepEnvironment([temp, ac], 3);
      expect(temp.value < 30.0).assertTrue();
      expect(stepRes.snapshot.totalWatts).assertEqual(1201);
    });

    // 4. 边界用例：临界阈值严格相等判定 (> vs >=)
    it('boundary_strict_threshold_equal_not_trigger', 0, () => {
      const temp = new SensorDevice(
        's_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 28.0, '℃', 0, 55, 30
      );
      const ac = new ActuatorDevice(
        'a_ac', 'Mock空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
        false, 26, 16, 30, '℃', '制冷', 1200
      );
      const ruleGt: AutomationRule = {
        id: 'r_gt', name: '严格大于28', description: '', enabled: true, logic: LogicOperator.AND,
        conditions: [{ id: 'c1', deviceId: 's_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
        actions: [{ id: 'a1', deviceId: 'a_ac', targetPowerOn: true }],
        cooldownMs: 0, lastTriggeredAt: 0, triggerCount: 0
      };

      const resGt = RuleEngine.evaluateRule(ruleGt, [temp, ac], 5000);
      expect(resGt.triggered).assertFalse();
      expect(ac.powerOn).assertFalse();

      ruleGt.conditions[0].operator = ConditionOperator.GTE;
      const resGte = RuleEngine.evaluateRule(ruleGt, [temp, ac], 6000);
      expect(resGte.triggered).assertTrue();
      expect(ac.powerOn).assertTrue();
    });

    // 5. 边界用例：冷却防抖时间边界 (4999ms 拦截，5000ms 放行)
    it('boundary_cooldown_debounce', 0, () => {
      const temp = new SensorDevice(
        's_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 30.0, '℃', 0, 55, 30
      );
      const ac = new ActuatorDevice(
        'a_ac', 'Mock空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
        false, 26, 16, 30, '℃', '制冷', 1200
      );
      const rule: AutomationRule = {
        id: 'r_cd', name: '冷却测试', description: '', enabled: true, logic: LogicOperator.AND,
        conditions: [{ id: 'c1', deviceId: 's_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
        actions: [{ id: 'a1', deviceId: 'a_ac', targetPowerOn: true }],
        cooldownMs: 5000, lastTriggeredAt: 0, triggerCount: 0
      };

      const first = RuleEngine.evaluateRule(rule, [temp, ac], 10000);
      expect(first.triggered).assertTrue();

      const insideCooldown = RuleEngine.evaluateRule(rule, [temp, ac], 14999);
      expect(insideCooldown.triggered).assertFalse();
      expect(rule.triggerCount).assertEqual(1);

      const afterCooldown = RuleEngine.evaluateRule(rule, [temp, ac], 15000);
      expect(afterCooldown.triggered).assertTrue();
      expect(rule.triggerCount).assertEqual(2);
    });

    // 6. 边界用例：传感器极值量程钳制
    it('boundary_sensor_value_clamping', 0, () => {
      const smoke = new SensorDevice(
        's_smoke', '烟雾', RoomId.BALCONY, DeviceKind.SMOKE_SENSOR,
        MetricKey.SMOKE_LEVEL, 20, 'ppm', 0, 500, 120
      );
      smoke.updateReading(999);
      expect(smoke.value).assertEqual(500);
      smoke.updateReading(-50);
      expect(smoke.value).assertEqual(0);
    });

    // 7. 异常用例：执行器离线时安全拦截联动动作
    it('abnormal_offline_actuator_intercepted', 0, () => {
      const temp = new SensorDevice(
        's_temp', 'Mock温度计', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 33.0, '℃', 0, 55, 30
      );
      const ac = new ActuatorDevice(
        'a_ac', '离线空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
        false, 26, 16, 30, '℃', '制冷', 1200
      );
      ac.setOnline(false);

      const rule: AutomationRule = {
        id: 'r_off', name: '离线安全测试', description: '', enabled: true, logic: LogicOperator.AND,
        conditions: [{ id: 'c1', deviceId: 's_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
        actions: [{ id: 'a1', deviceId: 'a_ac', targetPowerOn: true, targetLevel: 23 }],
        cooldownMs: 0, lastTriggeredAt: 0, triggerCount: 0
      };

      const summary = RuleEngine.runCycle([rule], [temp, ac], 20000);
      expect(summary.triggeredCount).assertEqual(0);
      expect(summary.errorCount).assertEqual(1);
      expect(ac.powerOn).assertFalse();
    });

    // 8. 异常用例：非法规则校验与 NaN 数值拦截
    it('abnormal_invalid_rule_and_nan_input', 0, () => {
      const sensor = new SensorDevice(
        's_temp', '温度', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 25.0, '℃', 0, 55, 30
      );
      const ok = sensor.updateReading(Number.NaN);
      expect(ok).assertFalse();
      expect(sensor.value).assertEqual(25.0);

      const invalidRule: AutomationRule = {
        id: 'r_bad', name: '   ', description: '', enabled: true, logic: LogicOperator.AND,
        conditions: [], actions: [], cooldownMs: -1, lastTriggeredAt: 0, triggerCount: 0
      };
      const check = RuleEngine.validateRule(invalidRule);
      expect(check.valid).assertFalse();
    });

    // 9. 异常用例：损坏持久化 JSON 安全回退不崩溃
    it('abnormal_corrupted_persistence_json_recovery', 0, () => {
      const recovered = PersistenceService.parseRawSnapshot(
        '{corrupted_json',
        '[]',
        '',
        '',
        ''
      );
      expect(recovered === undefined).assertTrue();
    });

    // 10. 边界/算法用例：高优先级应急规则与常规规则并发冲突仲裁
    it('boundary_priority_conflict_arbitration', 0, () => {
      const temp = new SensorDevice(
        's_temp', '客厅温度', RoomId.LIVING_ROOM, DeviceKind.TEMPERATURE_SENSOR,
        MetricKey.TEMPERATURE, 31.5, '℃', 0, 55, 30
      );
      const smoke = new SensorDevice(
        's_smoke', '阳台烟雾', RoomId.BALCONY, DeviceKind.SMOKE_SENSOR,
        MetricKey.SMOKE_LEVEL, 185, 'ppm', 0, 500, 120
      );
      const curtain = new ActuatorDevice(
        'a_curtain', '电动窗帘', RoomId.LIVING_ROOM, DeviceKind.SMART_CURTAIN,
        true, 60, 0, 100, '%', '开度', 35
      );
      const ac = new ActuatorDevice(
        'a_ac', '客厅空调', RoomId.LIVING_ROOM, DeviceKind.AIR_CONDITIONER,
        false, 26, 16, 30, '℃', '制冷', 1200
      );

      // 常规优先级排在数组前面，验证引擎真实按 priority 降序排序而非数组顺序
      const normalHeatRule: AutomationRule = {
        id: 'r_heat', name: '高温遮阳', description: '', enabled: true, priority: RulePriority.NORMAL,
        logic: LogicOperator.AND,
        conditions: [{ id: 'c_h', deviceId: 's_temp', metricKey: MetricKey.TEMPERATURE, operator: ConditionOperator.GT, threshold: 28 }],
        actions: [
          { id: 'a_ac', deviceId: 'a_ac', targetPowerOn: true, targetLevel: 24 },
          { id: 'a_curt_30', deviceId: 'a_curtain', targetPowerOn: true, targetLevel: 30, targetMode: '遮阳' }
        ],
        cooldownMs: 0, lastTriggeredAt: 0, triggerCount: 0
      };
      const emergencySmokeRule: AutomationRule = {
        id: 'r_smoke', name: '烟雾应急通风', description: '', enabled: true, priority: RulePriority.EMERGENCY,
        logic: LogicOperator.OR,
        conditions: [{ id: 'c_s', deviceId: 's_smoke', metricKey: MetricKey.SMOKE_LEVEL, operator: ConditionOperator.GTE, threshold: 120 }],
        actions: [
          { id: 'a_curt_100', deviceId: 'a_curtain', targetPowerOn: true, targetLevel: 100, targetMode: '紧急通风' }
        ],
        cooldownMs: 0, lastTriggeredAt: 0, triggerCount: 0
      };

      const summary = RuleEngine.runCycle([normalHeatRule, emergencySmokeRule], [temp, smoke, curtain, ac], 30000);
      expect(summary.triggeredCount).assertEqual(2);
      expect(summary.conflictSkippedCount).assertEqual(1);
      expect(curtain.levelValue).assertEqual(100);
      expect(ac.powerOn).assertTrue();
      expect(ac.levelValue).assertEqual(24);
    });

    // 11. 正常用例：!= (NEQ) 运算符求值验证
    it('normal_neq_operator_evaluation', 0, () => {
      const motion = new SensorDevice(
        's_motion', '人体红外', RoomId.BEDROOM, DeviceKind.MOTION_SENSOR,
        MetricKey.MOTION_DETECTED, 0, '', 0, 1, 2
      );
      const lamp = new ActuatorDevice(
        'a_lamp', '卧室灯', RoomId.BEDROOM, DeviceKind.SMART_LIGHT,
        true, 50, 10, 100, '%', '夜灯', 24
      );
      const neqRule: AutomationRule = {
        id: 'r_neq', name: '无人自动关灯', description: '', enabled: true, priority: RulePriority.LOW,
        logic: LogicOperator.AND,
        conditions: [{ id: 'c_neq', deviceId: 's_motion', metricKey: MetricKey.MOTION_DETECTED, operator: ConditionOperator.NEQ, threshold: 1 }],
        actions: [{ id: 'a_off', deviceId: 'a_lamp', targetPowerOn: false }],
        cooldownMs: 0, lastTriggeredAt: 0, triggerCount: 0
      };
      const res = RuleEngine.evaluateRule(neqRule, [motion, lamp], 40000);
      expect(res.triggered).assertTrue();
      expect(lamp.powerOn).assertFalse();
    });

    // 12. 正常用例：场景切换同步人体红外在位状态（离家=无人，睡眠/回家=有人）
    it('normal_scene_away_and_sleep_motion_sync', 0, () => {
      const store = SmartHomeStore.getInstance();
      const motion = store.getDeviceById('sensor_bedroom_motion');
      expect(motion instanceof SensorDevice).assertTrue();
      const sensor = motion as SensorDevice;
      sensor.setOnline(true);

      store.applyScene('scene_away');
      expect(sensor.value).assertEqual(0);
      expect(sensor.getPrimaryValueText()).assertEqual('无人');
      expect(store.isHomeOccupied()).assertFalse();

      // 离家无人状态下夜幕降临不应强制改为有人
      store.triggerDrill('nightfall');
      expect(sensor.value).assertEqual(0);

      // 切换睡眠模式后同步为有人
      store.applyScene('scene_sleep');
      expect(sensor.value).assertEqual(1);
      expect(sensor.getPrimaryValueText()).assertEqual('有人');
      expect(store.isHomeOccupied()).assertTrue();
    });
  });
}
