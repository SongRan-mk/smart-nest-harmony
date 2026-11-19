import { ActuatorDevice, BaseDevice, SensorDevice } from '../model/DeviceModels';
import {
  AutomationRule,
  ConditionOperator,
  ExecutionLog,
  formatTimestamp,
  getOperatorSymbol,
  LogicOperator,
  LogSource,
  RuleAction,
  RuleCondition,
  RulePriority
} from '../model/Types';

export interface ConditionEvalResult {
  conditionId: string;
  matched: boolean;
  reason: string;
  actualValue?: number;
}

export interface ActionExecResult {
  actionId: string;
  deviceId: string;
  deviceName: string;
  success: boolean;
  conflictSkipped?: boolean;
  reason: string;
}

export interface RuleEvalResult {
  ruleId: string;
  ruleName: string;
  triggered: boolean;
  skippedReason: string;
  conditionResults: ConditionEvalResult[];
  actionResults: ActionExecResult[];
}

export interface EngineCycleSummary {
  evaluatedCount: number;
  triggeredCount: number;
  executedActionCount: number;
  conflictSkippedCount: number;
  errorCount: number;
  results: RuleEvalResult[];
  generatedLogs: ExecutionLog[];
}

export interface RuleValidationResult {
  valid: boolean;
  message: string;
}

/**
 * 智巢规则求值与自动执行引擎
 * 纯业务无 UI 耦合，支持正常逻辑求值、边界比较、防抖冷却与异常设备拦截
 */
export class RuleEngine {
  /**
   * 校验规则表单或导入规则的合法性
   */
  public static validateRule(rule: AutomationRule): RuleValidationResult {
    if (rule.name.trim().length === 0) {
      return { valid: false, message: '规则名称不能为空' };
    }
    if (rule.conditions.length === 0) {
      return { valid: false, message: '至少需要配置一条触发条件' };
    }
    if (rule.actions.length === 0) {
      return { valid: false, message: '至少需要配置一条联动动作' };
    }
    if (Number.isNaN(rule.cooldownMs) || !Number.isFinite(rule.cooldownMs) || rule.cooldownMs < 0) {
      return { valid: false, message: '冷却时间必须为非负有效数字' };
    }
    for (let i = 0; i < rule.conditions.length; i++) {
      const cond = rule.conditions[i];
      if (cond.deviceId.trim().length === 0) {
        return { valid: false, message: `第 ${i + 1} 条条件未指定传感器设备` };
      }
      if (Number.isNaN(cond.threshold) || !Number.isFinite(cond.threshold)) {
        return { valid: false, message: `第 ${i + 1} 条条件的阈值无效` };
      }
    }
    for (let j = 0; j < rule.actions.length; j++) {
      const act = rule.actions[j];
      if (act.deviceId.trim().length === 0) {
        return { valid: false, message: `第 ${j + 1} 条动作未指定执行器设备` };
      }
    }
    return { valid: true, message: '规则配置合法' };
  }

  /**
   * 评估单条触发条件
   */
  public static evaluateCondition(
    condition: RuleCondition,
    devices: BaseDevice[]
  ): ConditionEvalResult {
    if (Number.isNaN(condition.threshold) || !Number.isFinite(condition.threshold)) {
      return {
        conditionId: condition.id,
        matched: false,
        reason: '条件阈值非法(NaN/Infinity)'
      };
    }

    const target = RuleEngine.findDeviceById(devices, condition.deviceId);
    if (!target) {
      return {
        conditionId: condition.id,
        matched: false,
        reason: `未找到设备(${condition.deviceId})`
      };
    }

    if (!(target instanceof SensorDevice)) {
      return {
        conditionId: condition.id,
        matched: false,
        reason: `设备(${target.name})不是传感器`
      };
    }

    if (!target.online) {
      return {
        conditionId: condition.id,
        matched: false,
        reason: `传感器(${target.name})已离线`
      };
    }

    const actual = target.value;
    const matched = RuleEngine.compareNumeric(actual, condition.operator, condition.threshold);
    const symbol = getOperatorSymbol(condition.operator);
    const reason = `${target.name} 当前 ${actual}${target.unit} ${symbol} ${condition.threshold}${target.unit} => ${matched ? '满足' : '未满足'}`;

    return {
      conditionId: condition.id,
      matched: matched,
      reason: reason,
      actualValue: actual
    };
  }

  /**
   * 获取规则有效优先级（缺省回退为常规级）
   */
  public static getEffectivePriority(rule: AutomationRule): number {
    return rule.priority !== undefined ? rule.priority : RulePriority.NORMAL;
  }

  /**
   * 评估整条规则（含启用状态、异常条件、AND/OR 组合、冷却防抖、冲突仲裁与动作执行）
   */
  public static evaluateRule(
    rule: AutomationRule,
    devices: BaseDevice[],
    nowMs: number,
    ignoreCooldown: boolean = false,
    lockedDeviceOwners?: Map<string, string>
  ): RuleEvalResult {
    if (!rule.enabled) {
      return {
        ruleId: rule.id,
        ruleName: rule.name,
        triggered: false,
        skippedReason: '规则已停用',
        conditionResults: [],
        actionResults: []
      };
    }

    if (rule.conditions.length === 0 || rule.actions.length === 0) {
      return {
        ruleId: rule.id,
        ruleName: rule.name,
        triggered: false,
        skippedReason: '规则条件或动作列表为空',
        conditionResults: [],
        actionResults: []
      };
    }

    if (!ignoreCooldown && rule.lastTriggeredAt > 0 && rule.cooldownMs > 0) {
      const elapsed = nowMs - rule.lastTriggeredAt;
      if (elapsed >= 0 && elapsed < rule.cooldownMs) {
        return {
          ruleId: rule.id,
          ruleName: rule.name,
          triggered: false,
          skippedReason: `处于冷却防抖期(剩余 ${Math.ceil((rule.cooldownMs - elapsed) / 1000)} 秒)`,
          conditionResults: [],
          actionResults: []
        };
      }
    }

    const conditionResults: ConditionEvalResult[] = [];
    for (let i = 0; i < rule.conditions.length; i++) {
      conditionResults.push(RuleEngine.evaluateCondition(rule.conditions[i], devices));
    }

    let allMatched = false;
    if (rule.logic === LogicOperator.AND) {
      allMatched = true;
      for (let i = 0; i < conditionResults.length; i++) {
        if (!conditionResults[i].matched) {
          allMatched = false;
          break;
        }
      }
    } else {
      allMatched = false;
      for (let i = 0; i < conditionResults.length; i++) {
        if (conditionResults[i].matched) {
          allMatched = true;
          break;
        }
      }
    }

    if (!allMatched) {
      let failedDetail = '条件组合未命中';
      for (let i = 0; i < conditionResults.length; i++) {
        if (!conditionResults[i].matched) {
          failedDetail = conditionResults[i].reason;
          break;
        }
      }
      return {
        ruleId: rule.id,
        ruleName: rule.name,
        triggered: false,
        skippedReason: failedDetail,
        conditionResults: conditionResults,
        actionResults: []
      };
    }

    const actionResults = RuleEngine.executeActions(rule.actions, devices, lockedDeviceOwners, rule.name);
    let hasSuccess = false;
    let hasConflictOnly = false;
    for (let i = 0; i < actionResults.length; i++) {
      if (actionResults[i].success) {
        hasSuccess = true;
      } else if (actionResults[i].conflictSkipped) {
        hasConflictOnly = true;
      }
    }

    if (hasSuccess) {
      rule.lastTriggeredAt = nowMs;
      rule.triggerCount += 1;
    }

    return {
      ruleId: rule.id,
      ruleName: rule.name,
      triggered: hasSuccess,
      skippedReason: hasSuccess ? '' : (hasConflictOnly ? '动作被高优先级规则冲突仲裁避让' : '所有联动动作均执行失败'),
      conditionResults: conditionResults,
      actionResults: actionResults
    };
  }

  /**
   * 执行动作集合并返回逐条结果（支持同周期高优先级执行器锁定仲裁）
   */
  public static executeActions(
    actions: RuleAction[],
    devices: BaseDevice[],
    lockedDeviceOwners?: Map<string, string>,
    ownerRuleName: string = ''
  ): ActionExecResult[] {
    const results: ActionExecResult[] = [];
    for (let i = 0; i < actions.length; i++) {
      const action = actions[i];
      const device = RuleEngine.findDeviceById(devices, action.deviceId);
      if (!device) {
        results.push({
          actionId: action.id,
          deviceId: action.deviceId,
          deviceName: action.deviceId,
          success: false,
          reason: `目标设备(${action.deviceId})不存在`
        });
        continue;
      }

      if (!(device instanceof ActuatorDevice)) {
        results.push({
          actionId: action.id,
          deviceId: device.id,
          deviceName: device.name,
          success: false,
          reason: `设备(${device.name})不是可执行设备`
        });
        continue;
      }

      if (!device.online) {
        results.push({
          actionId: action.id,
          deviceId: device.id,
          deviceName: device.name,
          success: false,
          reason: `执行器(${device.name})离线，动作被安全拦截`
        });
        continue;
      }

      // 同周期高优先级冲突仲裁：若设备已被高优先级规则锁定，则低优先级动作安全避让
      if (lockedDeviceOwners && lockedDeviceOwners.has(device.id)) {
        const winner = lockedDeviceOwners.get(device.id) || '高优先级规则';
        results.push({
          actionId: action.id,
          deviceId: device.id,
          deviceName: device.name,
          success: false,
          conflictSkipped: true,
          reason: `冲突仲裁避让：${device.name}已被高优先级规则【${winner}】锁定`
        });
        continue;
      }

      device.setPower(action.targetPowerOn);
      if (action.targetLevel !== undefined && !Number.isNaN(action.targetLevel)) {
        device.setLevel(action.targetLevel);
      }
      if (action.targetMode !== undefined && action.targetMode.trim().length > 0) {
        device.setMode(action.targetMode);
      }

      if (lockedDeviceOwners && ownerRuleName.length > 0) {
        lockedDeviceOwners.set(device.id, ownerRuleName);
      }

      results.push({
        actionId: action.id,
        deviceId: device.id,
        deviceName: device.name,
        success: true,
        reason: `${device.name} -> ${device.getSummaryText()}`
      });
    }
    return results;
  }

  /**
   * 按优先级降序扫描并执行全量规则周期（支持同周期设备冲突仲裁）
   */
  public static runCycle(
    rules: AutomationRule[],
    devices: BaseDevice[],
    nowMs: number,
    ignoreCooldown: boolean = false
  ): EngineCycleSummary {
    const orderedRules = rules.slice().sort((a: AutomationRule, b: AutomationRule) => {
      return RuleEngine.getEffectivePriority(b) - RuleEngine.getEffectivePriority(a);
    });
    const lockedDeviceOwners: Map<string, string> = new Map<string, string>();

    const results: RuleEvalResult[] = [];
    const generatedLogs: ExecutionLog[] = [];
    let triggeredCount = 0;
    let executedActionCount = 0;
    let conflictSkippedCount = 0;
    let errorCount = 0;

    for (let i = 0; i < orderedRules.length; i++) {
      const rule = orderedRules[i];
      const evalRes = RuleEngine.evaluateRule(rule, devices, nowMs, ignoreCooldown, lockedDeviceOwners);
      results.push(evalRes);

      if (evalRes.triggered) {
        triggeredCount += 1;
        const successDesc: string[] = [];
        for (let j = 0; j < evalRes.actionResults.length; j++) {
          const ar = evalRes.actionResults[j];
          if (ar.success) {
            executedActionCount += 1;
            successDesc.push(ar.reason);
          } else if (ar.conflictSkipped) {
            conflictSkippedCount += 1;
            generatedLogs.push({
              id: `log_arb_${nowMs}_${i}_${j}`,
              timestamp: nowMs,
              timeText: formatTimestamp(nowMs),
              source: LogSource.SIMULATION,
              title: `冲突仲裁避让 · ${rule.name}`,
              detail: ar.reason,
              ruleId: rule.id
            });
          } else {
            errorCount += 1;
            generatedLogs.push({
              id: `log_err_${nowMs}_${i}_${j}`,
              timestamp: nowMs,
              timeText: formatTimestamp(nowMs),
              source: LogSource.ERROR,
              title: `联动异常拦截 · ${rule.name}`,
              detail: ar.reason,
              ruleId: rule.id
            });
          }
        }

        if (successDesc.length > 0) {
          generatedLogs.push({
            id: `log_rule_${nowMs}_${i}`,
            timestamp: nowMs,
            timeText: formatTimestamp(nowMs),
            source: LogSource.RULE,
            title: `规则触发 · ${rule.name}`,
            detail: successDesc.join('；'),
            ruleId: rule.id
          });
        }
      } else if (evalRes.actionResults.length > 0) {
        // 满足条件但动作全部失败或全部被冲突仲裁避让
        for (let j = 0; j < evalRes.actionResults.length; j++) {
          const ar = evalRes.actionResults[j];
          if (ar.conflictSkipped) {
            conflictSkippedCount += 1;
            generatedLogs.push({
              id: `log_arb_${nowMs}_${i}_${j}`,
              timestamp: nowMs,
              timeText: formatTimestamp(nowMs),
              source: LogSource.SIMULATION,
              title: `冲突仲裁避让 · ${rule.name}`,
              detail: ar.reason,
              ruleId: rule.id
            });
          } else if (!ar.success) {
            errorCount += 1;
            generatedLogs.push({
              id: `log_err_${nowMs}_${i}_${j}`,
              timestamp: nowMs,
              timeText: formatTimestamp(nowMs),
              source: LogSource.ERROR,
              title: `规则动作受阻 · ${rule.name}`,
              detail: ar.reason,
              ruleId: rule.id
            });
          }
        }
      }
    }

    return {
      evaluatedCount: rules.length,
      triggeredCount: triggeredCount,
      executedActionCount: executedActionCount,
      conflictSkippedCount: conflictSkippedCount,
      errorCount: errorCount,
      results: results,
      generatedLogs: generatedLogs
    };
  }

  private static findDeviceById(devices: BaseDevice[], id: string): BaseDevice | undefined {
    for (let i = 0; i < devices.length; i++) {
      if (devices[i].id === id) {
        return devices[i];
      }
    }
    return undefined;
  }

  private static compareNumeric(actual: number, op: ConditionOperator, threshold: number): boolean {
    const epsilon = 0.0001;
    switch (op) {
      case ConditionOperator.GT:
        return actual > threshold;
      case ConditionOperator.GTE:
        return actual >= threshold - epsilon;
      case ConditionOperator.LT:
        return actual < threshold;
      case ConditionOperator.LTE:
        return actual <= threshold + epsilon;
      case ConditionOperator.EQ:
        return Math.abs(actual - threshold) < epsilon;
      case ConditionOperator.NEQ:
        return Math.abs(actual - threshold) >= epsilon;
      default:
        return false;
    }
  }
}
