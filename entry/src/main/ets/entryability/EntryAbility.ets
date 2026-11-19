import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SmartHomeStore } from '../service/SmartHomeStore';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    SmartHomeStore.getInstance().init(this.context);
    hilog.info(DOMAIN, 'SmartNest', '%{public}s', 'Ability onCreate & SmartHomeStore initialized');
  }

  onDestroy(): void {
    SmartHomeStore.getInstance().stopSimulationTimer();
    SmartHomeStore.getInstance().flushSync();
    hilog.info(DOMAIN, 'SmartNest', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'SmartNest', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'SmartNest', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'SmartNest', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'SmartNest', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // 回到前台时恢复处于开启状态的自动环境仿真
    SmartHomeStore.getInstance().resumeSimulationForForeground();
    hilog.info(DOMAIN, 'SmartNest', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // 应用退至后台时挂起仿真定时器并强制同步落盘业务状态
    SmartHomeStore.getInstance().pauseSimulationForBackground();
    SmartHomeStore.getInstance().flushSync();
    hilog.info(DOMAIN, 'SmartNest', '%{public}s', 'Ability onBackground');
  }
}