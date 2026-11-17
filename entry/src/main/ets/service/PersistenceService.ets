import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AutomationRule,
  ExecutionLog,
  PersistedAppState,
  SerializedDeviceState,
  SimConfig
} from '../model/Types';

const TAG = 'SmartNestPersistence';
const DOMAIN = 0x0001;
const STORE_NAME = 'smart_nest_store_v1';

const KEY_DEVICES = 'devices_state_v1';
const KEY_RULES = 'rules_list_v1';
const KEY_LOGS = 'logs_list_v1';
const KEY_SIM = 'sim_config_v1';
const KEY_SCENE = 'active_scene_v1';

/**
 * 基于 @kit.ArkData Preferences 的数据持久化服务
 * 负责应用核心状态的落盘、冷启动恢复及异常数据兜底
 */
export class PersistenceService {
  private pref: preferences.Preferences | undefined = undefined;
  private memoryFallback: boolean = false;

  /**
   * 绑定 Ability Context 并打开首选项存储
   */
  public init(context: common.Context): void {
    if (this.pref !== undefined) {
      return;
    }
    try {
      this.pref = preferences.getPreferencesSync(context, { name: STORE_NAME });
      this.memoryFallback = false;
      hilog.info(DOMAIN, TAG, 'Preferences initialized successfully');
    } catch (err) {
      this.memoryFallback = true;
      hilog.error(DOMAIN, TAG, 'Failed to init preferences, fallback to memory: %{public}s', JSON.stringify(err));
    }
  }

  public isMemoryFallback(): boolean {
    return this.memoryFallback;
  }

  /**
   * 保存全量业务状态并刷新至磁盘
   */
  public async saveSnapshot(state: PersistedAppState): Promise<boolean> {
    if (!this.pref) {
      return false;
    }
    try {
      this.pref.putSync(KEY_DEVICES, JSON.stringify(state.devices));
      this.pref.putSync(KEY_RULES, JSON.stringify(state.rules));
      this.pref.putSync(KEY_LOGS, JSON.stringify(state.logs));
      this.pref.putSync(KEY_SIM, JSON.stringify(state.simConfig));
      this.pref.putSync(KEY_SCENE, state.activeSceneId);
      await this.pref.flush();
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to save snapshot: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  /**
   * 同步保存（用于生命周期退出兜底）
   */
  public saveSnapshotSync(state: PersistedAppState): void {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.putSync(KEY_DEVICES, JSON.stringify(state.devices));
      this.pref.putSync(KEY_RULES, JSON.stringify(state.rules));
      this.pref.putSync(KEY_LOGS, JSON.stringify(state.logs));
      this.pref.putSync(KEY_SIM, JSON.stringify(state.simConfig));
      this.pref.putSync(KEY_SCENE, state.activeSceneId);
      this.pref.flush().catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Async flush error: %{public}s', err.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to save snapshot sync: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 从首选项读取并恢复业务状态
   */
  public loadSnapshot(): PersistedAppState | undefined {
    if (!this.pref) {
      return undefined;
    }
    try {
      const rawDevices = this.pref.getSync(KEY_DEVICES, '') as string;
      const rawRules = this.pref.getSync(KEY_RULES, '') as string;
      const rawLogs = this.pref.getSync(KEY_LOGS, '') as string;
      const rawSim = this.pref.getSync(KEY_SIM, '') as string;
      const activeScene = this.pref.getSync(KEY_SCENE, '') as string;

      return PersistenceService.parseRawSnapshot(rawDevices, rawRules, rawLogs, rawSim, activeScene);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to load snapshot: %{public}s', JSON.stringify(err));
      return undefined;
    }
  }

  /**
   * 解析并校验序列化字符串，遇到空值或损坏 JSON 返回 undefined 安全回退
   */
  public static parseRawSnapshot(
    rawDevices: string,
    rawRules: string,
    rawLogs: string,
    rawSim: string,
    activeSceneId: string
  ): PersistedAppState | undefined {
    if (rawDevices.trim().length === 0 || rawRules.trim().length === 0) {
      return undefined;
    }
    try {
      const devices = JSON.parse(rawDevices) as SerializedDeviceState[];
      const rules = JSON.parse(rawRules) as AutomationRule[];
      if (!Array.isArray(devices) || !Array.isArray(rules)) {
        return undefined;
      }

      let logs: ExecutionLog[] = [];
      if (rawLogs.trim().length > 0) {
        const parsedLogs = JSON.parse(rawLogs) as ExecutionLog[];
        if (Array.isArray(parsedLogs)) {
          logs = parsedLogs;
        }
      }

      let simConfig: SimConfig = {
        autoRunning: false,
        tickIndex: 4,
        snapshots: []
      };
      if (rawSim.trim().length > 0) {
        const parsedSim = JSON.parse(rawSim) as SimConfig;
        if (parsedSim && Array.isArray(parsedSim.snapshots)) {
          simConfig = parsedSim;
        }
      }

      return {
        devices: devices,
        rules: rules,
        logs: logs,
        simConfig: simConfig,
        activeSceneId: activeSceneId
      };
    } catch (_err) {
      return undefined;
    }
  }

  /**
   * 清空持久化记录
   */
  public async clearAll(): Promise<void> {
    if (!this.pref) {
      return;
    }
    try {
      this.pref.clearSync();
      await this.pref.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to clear preferences: %{public}s', JSON.stringify(err));
    }
  }
}
