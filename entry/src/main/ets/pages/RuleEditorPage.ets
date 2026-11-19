import { ActuatorDevice, SensorDevice } from '../model/DeviceModels';
import {
  AutomationRule,
  ConditionOperator,
  getOperatorSymbol,
  getRulePriorityColor,
  getRulePriorityLabel,
  LogicOperator,
  MetricKey,
  RuleAction,
  RuleCondition,
  RulePriority
} from '../model/Types';
import { SmartHomeStore } from '../service/SmartHomeStore';

interface EditableCondition {
  id: string;
  deviceId: string;
  metricKey: MetricKey;
  operator: ConditionOperator;
  thresholdText: string;
}

interface EditableAction {
  id: string;
  deviceId: string;
  targetPowerOn: boolean;
  levelText: string;
  targetMode?: string;
}

/**
 * 可视化规则编排编辑器页面（支持新建与编辑）
 */
@Component
export struct RuleEditorPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Prop ruleId: string = '';

  @State ruleName: string = '';
  @State ruleDesc: string = '';
  @State logicOp: LogicOperator = LogicOperator.AND;
  @State priority: RulePriority = RulePriority.NORMAL;
  @State cooldownSec: number = 8;
  @State ruleEnabled: boolean = true;
  @State conditions: EditableCondition[] = [];
  @State actions: EditableAction[] = [];

  private store: SmartHomeStore = SmartHomeStore.getInstance();
  private operators: ConditionOperator[] = [
    ConditionOperator.GT,
    ConditionOperator.GTE,
    ConditionOperator.LT,
    ConditionOperator.LTE,
    ConditionOperator.EQ,
    ConditionOperator.NEQ
  ];
  private priorities: RulePriority[] = [
    RulePriority.LOW,
    RulePriority.NORMAL,
    RulePriority.HIGH,
    RulePriority.EMERGENCY
  ];
  private existingLastTriggeredAt: number = 0;
  private existingTriggerCount: number = 0;

  aboutToAppear(): void {
    const sensors = this.store.getSensors();
    const actuators = this.store.getActuators();

    if (this.ruleId.length > 0) {
      const existing = this.store.getRuleById(this.ruleId);
      if (existing) {
        this.ruleName = existing.name;
        this.ruleDesc = existing.description;
        this.logicOp = existing.logic;
        this.priority = existing.priority !== undefined ? existing.priority : RulePriority.NORMAL;
        this.cooldownSec = Math.round(existing.cooldownMs / 1000);
        this.ruleEnabled = existing.enabled;
        this.existingLastTriggeredAt = existing.lastTriggeredAt;
        this.existingTriggerCount = existing.triggerCount;

        const clonedConds: EditableCondition[] = [];
        for (let i = 0; i < existing.conditions.length; i++) {
          const c = existing.conditions[i];
          clonedConds.push({
            id: c.id,
            deviceId: c.deviceId,
            metricKey: c.metricKey,
            operator: c.operator,
            thresholdText: `${c.threshold}`
          });
        }
        this.conditions = clonedConds;

        const clonedActs: EditableAction[] = [];
        for (let i = 0; i < existing.actions.length; i++) {
          const a = existing.actions[i];
          clonedActs.push({
            id: a.id,
            deviceId: a.deviceId,
            targetPowerOn: a.targetPowerOn,
            levelText: a.targetLevel !== undefined ? `${a.targetLevel}` : '',
            targetMode: a.targetMode
          });
        }
        this.actions = clonedActs;
        return;
      }
    }

    // 新建规则默认值
    this.ruleName = '';
    this.ruleDesc = '';
    const firstSensor = sensors.length > 0 ? sensors[0] : undefined;
    const firstActuator = actuators.length > 0 ? actuators[0] : undefined;
    this.conditions = [
      {
        id: `cond_${Date.now()}`,
        deviceId: firstSensor ? firstSensor.id : 'sensor_living_temp',
        metricKey: firstSensor ? firstSensor.metricKey : MetricKey.TEMPERATURE,
        operator: ConditionOperator.GT,
        thresholdText: '28'
      }
    ];
    this.actions = [
      {
        id: `act_${Date.now()}`,
        deviceId: firstActuator ? firstActuator.id : 'act_living_ac',
        targetPowerOn: true,
        levelText: '24'
      }
    ];
  }

  private showTip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (_err) {
      // ignore
    }
  }

  private getSensorHint(deviceId: string): string {
    const dev = this.store.getDeviceById(deviceId);
    if (dev instanceof SensorDevice) {
      if (dev.metricKey === MetricKey.MOTION_DETECTED) {
        return `当前：${dev.getPrimaryValueText()} · 提示：0 表示无人，1 表示有人活动`;
      }
      return `当前读数：${dev.value}${dev.unit} · 有效量程：${dev.minVal}~${dev.maxVal}${dev.unit}`;
    }
    return '';
  }

  private addCondition(): void {
    const sensors = this.store.getSensors();
    const firstSensor = sensors.length > 0 ? sensors[0] : undefined;
    const next = this.conditions.slice();
    next.push({
      id: `cond_${Date.now()}_${next.length}`,
      deviceId: firstSensor ? firstSensor.id : 'sensor_living_temp',
      metricKey: firstSensor ? firstSensor.metricKey : MetricKey.TEMPERATURE,
      operator: ConditionOperator.GT,
      thresholdText: '25'
    });
    this.conditions = next;
  }

  private removeCondition(index: number): void {
    if (this.conditions.length <= 1) {
      this.showTip('至少保留一条触发条件');
      return;
    }
    const next: EditableCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      if (i !== index) {
        next.push(this.conditions[i]);
      }
    }
    this.conditions = next;
  }

  private updateConditionSensor(index: number, sensor: SensorDevice): void {
    const next = this.conditions.slice();
    const cur = next[index];
    next[index] = {
      id: cur.id,
      deviceId: sensor.id,
      metricKey: sensor.metricKey,
      operator: cur.operator,
      thresholdText: cur.thresholdText
    };
    this.conditions = next;
  }

  private updateConditionOp(index: number, op: ConditionOperator): void {
    const next = this.conditions.slice();
    const cur = next[index];
    next[index] = {
      id: cur.id,
      deviceId: cur.deviceId,
      metricKey: cur.metricKey,
      operator: op,
      thresholdText: cur.thresholdText
    };
    this.conditions = next;
  }

  private updateConditionThreshold(index: number, val: string): void {
    const next = this.conditions.slice();
    const cur = next[index];
    next[index] = {
      id: cur.id,
      deviceId: cur.deviceId,
      metricKey: cur.metricKey,
      operator: cur.operator,
      thresholdText: val
    };
    this.conditions = next;
  }

  private addAction(): void {
    const actuators = this.store.getActuators();
    const firstAct = actuators.length > 0 ? actuators[0] : undefined;
    const next = this.actions.slice();
    next.push({
      id: `act_${Date.now()}_${next.length}`,
      deviceId: firstAct ? firstAct.id : 'act_living_ac',
      targetPowerOn: true,
      levelText: ''
    });
    this.actions = next;
  }

  private removeAction(index: number): void {
    if (this.actions.length <= 1) {
      this.showTip('至少保留一条联动动作');
      return;
    }
    const next: EditableAction[] = [];
    for (let i = 0; i < this.actions.length; i++) {
      if (i !== index) {
        next.push(this.actions[i]);
      }
    }
    this.actions = next;
  }

  private updateActionDevice(index: number, act: ActuatorDevice): void {
    const next = this.actions.slice();
    const cur = next[index];
    next[index] = {
      id: cur.id,
      deviceId: act.id,
      targetPowerOn: cur.targetPowerOn,
      levelText: cur.levelText,
      targetMode: cur.targetMode
    };
    this.actions = next;
  }

  private updateActionPower(index: number, powerOn: boolean): void {
    const next = this.actions.slice();
    const cur = next[index];
    next[index] = {
      id: cur.id,
      deviceId: cur.deviceId,
      targetPowerOn: powerOn,
      levelText: cur.levelText,
      targetMode: cur.targetMode
    };
    this.actions = next;
  }

  private updateActionLevel(index: number, val: string): void {
    const next = this.actions.slice();
    const cur = next[index];
    next[index] = {
      id: cur.id,
      deviceId: cur.deviceId,
      targetPowerOn: cur.targetPowerOn,
      levelText: val,
      targetMode: cur.targetMode
    };
    this.actions = next;
  }

  private handleSave(): void {
    const parsedConditions: RuleCondition[] = [];
    for (let i = 0; i < this.conditions.length; i++) {
      const c = this.conditions[i];
      const num = Number(c.thresholdText.trim());
      if (c.thresholdText.trim().length === 0 || Number.isNaN(num)) {
        this.showTip(`第 ${i + 1} 条条件阈值必须是有效数字`);
        return;
      }
      parsedConditions.push({
        id: c.id,
        deviceId: c.deviceId,
        metricKey: c.metricKey,
        operator: c.operator,
        threshold: num
      });
    }

    const parsedActions: RuleAction[] = [];
    for (let j = 0; j < this.actions.length; j++) {
      const a = this.actions[j];
      let parsedLevel: number | undefined = undefined;
      if (a.levelText.trim().length > 0) {
        const lvl = Number(a.levelText.trim());
        if (Number.isNaN(lvl)) {
          this.showTip(`第 ${j + 1} 条动作目标参数必须是有效数字`);
          return;
        }
        parsedLevel = lvl;
      }
      parsedActions.push({
        id: a.id,
        deviceId: a.deviceId,
        targetPowerOn: a.targetPowerOn,
        targetLevel: parsedLevel,
        targetMode: a.targetMode
      });
    }

    const rule: AutomationRule = {
      id: this.ruleId.length > 0 ? this.ruleId : `rule_${Date.now()}`,
      name: this.ruleName.trim(),
      description: this.ruleDesc.trim(),
      enabled: this.ruleEnabled,
      priority: this.priority,
      logic: this.logicOp,
      conditions: parsedConditions,
      actions: parsedActions,
      cooldownMs: this.cooldownSec * 1000,
      lastTriggeredAt: this.existingLastTriggeredAt,
      triggerCount: this.existingTriggerCount
    };

    const result = this.store.saveRule(rule);
    if (!result.valid) {
      this.showTip(result.message);
      return;
    }
    this.showTip('规则已保存并写入本地存储');
    this.pageStack.pop();
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          // 1. 基本信息
          Column({ space: 10 }) {
            Text('规则基本信息')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A2233')

            TextInput({ placeholder: '请输入规则名称（如：卧室高温开灯提醒）', text: this.ruleName })
              .height(42)
              .backgroundColor('#F5F7FA')
              .borderRadius(10)
              .onChange((val: string) => {
                this.ruleName = val;
              })

            TextInput({ placeholder: '规则说明（选填）', text: this.ruleDesc })
              .height(42)
              .backgroundColor('#F5F7FA')
              .borderRadius(10)
              .onChange((val: string) => {
                this.ruleDesc = val;
              })

            Row({ space: 8 }) {
              Text('组合逻辑：')
                .fontSize(13)
                .fontColor('#4E5969')

              Button('AND 全部满足')
                .type(ButtonType.Capsule)
                .height(30)
                .fontSize(12)
                .backgroundColor(this.logicOp === LogicOperator.AND ? '#1677FF' : '#F2F4F8')
                .fontColor(this.logicOp === LogicOperator.AND ? '#FFFFFF' : '#4E5969')
                .onClick(() => {
                  this.logicOp = LogicOperator.AND;
                })

              Button('OR 任一满足')
                .type(ButtonType.Capsule)
                .height(30)
                .fontSize(12)
                .backgroundColor(this.logicOp === LogicOperator.OR ? '#1677FF' : '#F2F4F8')
                .fontColor(this.logicOp === LogicOperator.OR ? '#FFFFFF' : '#4E5969')
                .onClick(() => {
                  this.logicOp = LogicOperator.OR;
                })
            }
            .width('100%')

            Row({ space: 8 }) {
              Text('仲裁级别：')
                .fontSize(13)
                .fontColor('#4E5969')

              ForEach(this.priorities, (p: RulePriority) => {
                Text(getRulePriorityLabel(p))
                  .fontSize(12)
                  .fontWeight(this.priority === p ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(this.priority === p ? '#FFFFFF' : '#4E5969')
                  .backgroundColor(this.priority === p ? getRulePriorityColor(p) : '#F2F4F8')
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .onClick(() => {
                    this.priority = p;
                  })
              }, (p: RulePriority) => `${p}`)
            }
            .width('100%')

            Row({ space: 8 }) {
              Text('防抖冷却：')
                .fontSize(13)
                .fontColor('#4E5969')

              ForEach([0, 5, 8, 15], (sec: number) => {
                Text(`${sec}s`)
                  .fontSize(12)
                  .fontColor(this.cooldownSec === sec ? '#FFFFFF' : '#4E5969')
                  .backgroundColor(this.cooldownSec === sec ? '#00B578' : '#F2F4F8')
                  .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                  .borderRadius(12)
                  .onClick(() => {
                    this.cooldownSec = sec;
                  })
              }, (sec: number) => `${sec}`)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .alignItems(HorizontalAlign.Start)

          // 2. 触发条件列表
          Column({ space: 10 }) {
            Row() {
              Text('触发条件 (IF)')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FA8C16')
              Blank()
              Button('+ 添加条件')
                .type(ButtonType.Capsule)
                .height(28)
                .fontSize(12)
                .backgroundColor('#FFF7E6')
                .fontColor('#D46B08')
                .onClick(() => {
                  this.addCondition();
                })
            }
            .width('100%')

            ForEach(this.conditions, (cond: EditableCondition, index: number) => {
              Column({ space: 8 }) {
                Row() {
                  Text(`条件 #${index + 1}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#4E5969')
                  Blank()
                  Text('删除')
                    .fontSize(12)
                    .fontColor('#FF4D4F')
                    .onClick(() => {
                      this.removeCondition(index);
                    })
                }
                .width('100%')

                Scroll() {
                  Row({ space: 6 }) {
                    ForEach(this.store.getSensors(), (sensor: SensorDevice) => {
                      Text(sensor.name)
                        .fontSize(11)
                        .fontColor(cond.deviceId === sensor.id ? '#FFFFFF' : '#4E5969')
                        .backgroundColor(cond.deviceId === sensor.id ? '#1677FF' : '#F2F4F8')
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .borderRadius(12)
                        .onClick(() => {
                          this.updateConditionSensor(index, sensor);
                        })
                    }, (sensor: SensorDevice) => sensor.id)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')

                if (this.getSensorHint(cond.deviceId).length > 0) {
                  Text(this.getSensorHint(cond.deviceId))
                    .fontSize(11)
                    .fontColor('#1677FF')
                    .width('100%')
                }

                Row({ space: 6 }) {
                  ForEach(this.operators, (op: ConditionOperator) => {
                    Text(getOperatorSymbol(op))
                      .fontSize(12)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(cond.operator === op ? '#FFFFFF' : '#4E5969')
                      .backgroundColor(cond.operator === op ? '#FA8C16' : '#F2F4F8')
                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                      .borderRadius(10)
                      .onClick(() => {
                        this.updateConditionOp(index, op);
                      })
                  }, (op: ConditionOperator) => op)
                }
                .width('100%')

                Row({ space: 8 }) {
                  Text('触发阈值：')
                    .fontSize(12)
                    .fontColor('#4E5969')

                  TextInput({ placeholder: '请输入数值阈值', text: cond.thresholdText })
                    .height(34)
                    .fontSize(13)
                    .backgroundColor('#F5F7FA')
                    .borderRadius(8)
                    .layoutWeight(1)
                    .onChange((val: string) => {
                      this.updateConditionThreshold(index, val);
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#FAFBFD')
              .borderRadius(12)
              .border({ width: 1, color: '#FFE7BA' })
            }, (cond: EditableCondition) => cond.id)
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)

          // 3. 联动动作列表
          Column({ space: 10 }) {
            Row() {
              Text('联动动作 (THEN)')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#00B578')
              Blank()
              Button('+ 添加动作')
                .type(ButtonType.Capsule)
                .height(28)
                .fontSize(12)
                .backgroundColor('#F6FFED')
                .fontColor('#00B578')
                .onClick(() => {
                  this.addAction();
                })
            }
            .width('100%')

            ForEach(this.actions, (act: EditableAction, index: number) => {
              Column({ space: 8 }) {
                Row() {
                  Text(`动作 #${index + 1}`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#4E5969')
                  Blank()
                  Text('删除')
                    .fontSize(12)
                    .fontColor('#FF4D4F')
                    .onClick(() => {
                      this.removeAction(index);
                    })
                }
                .width('100%')

                Scroll() {
                  Row({ space: 6 }) {
                    ForEach(this.store.getActuators(), (dev: ActuatorDevice) => {
                      Text(dev.name)
                        .fontSize(11)
                        .fontColor(act.deviceId === dev.id ? '#FFFFFF' : '#4E5969')
                        .backgroundColor(act.deviceId === dev.id ? '#00B578' : '#F2F4F8')
                        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                        .borderRadius(12)
                        .onClick(() => {
                          this.updateActionDevice(index, dev);
                        })
                    }, (dev: ActuatorDevice) => dev.id)
                  }
                }
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)
                .width('100%')

                Row({ space: 8 }) {
                  Button('开启')
                    .type(ButtonType.Normal)
                    .height(30)
                    .fontSize(12)
                    .borderRadius(8)
                    .backgroundColor(act.targetPowerOn ? '#00B578' : '#F2F4F8')
                    .fontColor(act.targetPowerOn ? '#FFFFFF' : '#4E5969')
                    .onClick(() => {
                      this.updateActionPower(index, true);
                    })

                  Button('关闭')
                    .type(ButtonType.Normal)
                    .height(30)
                    .fontSize(12)
                    .borderRadius(8)
                    .backgroundColor(!act.targetPowerOn ? '#FF4D4F' : '#F2F4F8')
                    .fontColor(!act.targetPowerOn ? '#FFFFFF' : '#4E5969')
                    .onClick(() => {
                      this.updateActionPower(index, false);
                    })

                  TextInput({ placeholder: '目标档位/温度(选填)', text: act.levelText })
                    .height(32)
                    .fontSize(12)
                    .backgroundColor('#F5F7FA')
                    .borderRadius(8)
                    .layoutWeight(1)
                    .onChange((val: string) => {
                      this.updateActionLevel(index, val);
                    })
                }
                .width('100%')
              }
              .width('100%')
              .padding(10)
              .backgroundColor('#FAFBFD')
              .borderRadius(12)
              .border({ width: 1, color: '#D9F7BE' })
            }, (act: EditableAction) => act.id)
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)

          // 4. 保存按钮
          Button('保存规则并同步存储')
            .type(ButtonType.Capsule)
            .width('100%')
            .height(44)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#1677FF')
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.handleSave();
            })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F3F6FA')
    }
    .title(this.ruleId.length > 0 ? '编辑联动规则' : '新建联动规则')
    .backgroundColor('#F3F6FA')
  }
}
