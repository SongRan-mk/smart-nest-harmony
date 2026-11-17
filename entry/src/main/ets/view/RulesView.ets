import { ROUTE_RULE_EDITOR, RuleEditorParam } from '../model/NavTypes';
import { AutomationRule, getOperatorSymbol, RuleAction, RuleCondition } from '../model/Types';
import { SmartHomeStore, STORE_REVISION_KEY } from '../service/SmartHomeStore';

/**
 * 规则编排管理视图
 */
@Component
export struct RulesView {
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp(STORE_REVISION_KEY) revision: number = 0;

  private store: SmartHomeStore = SmartHomeStore.getInstance();

  private showTip(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
    } catch (_err) {
      // ignore
    }
  }

  private getRulesList(): AutomationRule[] {
    if (this.revision < 0) {
      return [];
    }
    return this.store.getRules();
  }

  private countEnabled(rules: AutomationRule[]): number {
    let count = 0;
    for (let i = 0; i < rules.length; i++) {
      if (rules[i].enabled) {
        count += 1;
      }
    }
    return count;
  }

  private formatCondition(cond: RuleCondition): string {
    const dev = this.store.getDeviceById(cond.deviceId);
    const name = dev ? dev.name : cond.deviceId;
    return `${name} ${getOperatorSymbol(cond.operator)} ${cond.threshold}`;
  }

  private formatAction(act: RuleAction): string {
    const dev = this.store.getDeviceById(act.deviceId);
    const name = dev ? dev.name : act.deviceId;
    const stateText = act.targetPowerOn ? '开启' : '关闭';
    if (act.targetLevel !== undefined && act.targetPowerOn) {
      return `${name}: ${stateText}(${act.targetLevel})`;
    }
    return `${name}: ${stateText}`;
  }

  private openEditor(ruleId: string): void {
    const param: RuleEditorParam = { ruleId: ruleId };
    this.pageStack.pushPathByName(ROUTE_RULE_EDITOR, param);
  }

  build() {
    Column({ space: 12 }) {
      // 顶部栏
      Row() {
        Column({ space: 2 }) {
          Text('自动化规则编排')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A2233')
          Text(`已启用 ${this.countEnabled(this.getRulesList())} / 共 ${this.getRulesList().length} 条联动规则`)
            .fontSize(12)
            .fontColor('#6E7787')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('+ 新建规则')
          .type(ButtonType.Capsule)
          .height(36)
          .fontSize(13)
          .backgroundColor('#1677FF')
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.openEditor('');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14 })

      // 规则卡片列表
      List({ space: 12 }) {
        ForEach(this.getRulesList(), (rule: AutomationRule) => {
          ListItem() {
            Column({ space: 10 }) {
              // 标题行与启停开关
              Row() {
                Row({ space: 6 }) {
                  Text(rule.logic)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1677FF')
                    .backgroundColor('#E6F4FF')
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .borderRadius(6)

                  Text(rule.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A2233')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
                  .selectedColor('#1677FF')
                  .onChange((isOn: boolean) => {
                    if (isOn !== rule.enabled) {
                      this.store.toggleRuleEnabled(rule.id);
                    }
                  })
              }
              .width('100%')

              if (rule.description.length > 0) {
                Text(rule.description)
                  .fontSize(12)
                  .fontColor('#6E7787')
                  .width('100%')
              }

              // 条件展示
              Column({ space: 4 }) {
                Text(`IF (${rule.logic === 'AND' ? '全部满足' : '任一满足'})`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FA8C16')

                ForEach(rule.conditions, (cond: RuleCondition) => {
                  Text(`• ${this.formatCondition(cond)}`)
                    .fontSize(12)
                    .fontColor('#333B48')
                }, (cond: RuleCondition) => cond.id)
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#FFFBE6')
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)

              // 动作展示
              Column({ space: 4 }) {
                Text('THEN (联动动作)')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#00B578')

                ForEach(rule.actions, (act: RuleAction) => {
                  Text(`• ${this.formatAction(act)}`)
                    .fontSize(12)
                    .fontColor('#333B48')
                }, (act: RuleAction) => act.id)
              }
              .width('100%')
              .padding(8)
              .backgroundColor('#F6FFED')
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)

              // 底部统计与操作按钮
              Row({ space: 8 }) {
                Text(`已触发 ${rule.triggerCount} 次 · 冷却 ${Math.round(rule.cooldownMs / 1000)}s`)
                  .fontSize(11)
                  .fontColor('#8C95A6')
                  .layoutWeight(1)

                Button('试运行')
                  .type(ButtonType.Normal)
                  .height(28)
                  .fontSize(12)
                  .borderRadius(8)
                  .fontColor('#1677FF')
                  .backgroundColor('#E6F4FF')
                  .onClick(() => {
                    const res = this.store.evaluateSingleRuleNow(rule.id);
                    if (res) {
                      this.showTip(res.triggered ? `命中执行: ${rule.name}` : `未触发: ${res.skippedReason}`);
                    }
                  })

                Button('编辑')
                  .type(ButtonType.Normal)
                  .height(28)
                  .fontSize(12)
                  .borderRadius(8)
                  .fontColor('#4E5969')
                  .backgroundColor('#F2F4F8')
                  .onClick(() => {
                    this.openEditor(rule.id);
                  })

                Button('删除')
                  .type(ButtonType.Normal)
                  .height(28)
                  .fontSize(12)
                  .borderRadius(8)
                  .fontColor('#FF4D4F')
                  .backgroundColor('#FFF1F0')
                  .onClick(() => {
                    this.store.deleteRule(rule.id);
                    this.showTip(`已删除规则「${rule.name}」`);
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .border({ width: 1, color: rule.enabled ? '#EAECEF' : '#F2F3F5' })
            .opacity(rule.enabled ? 1.0 : 0.72)
          }
        }, (rule: AutomationRule) => `${rule.id}_${this.revision}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FA')
  }
}
