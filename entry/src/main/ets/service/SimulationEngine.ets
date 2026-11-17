import { ActuatorDevice, BaseDevice, SensorDevice } from '../model/DeviceModels';
import { EnvironmentSnapshot, MetricKey } from '../model/Types';

export interface SimStepResult {
  snapshot: EnvironmentSnapshot;
  updatedSensors: number;
}

/**
 * 智能家居环境物理仿真引擎
 * 负责推进虚拟时间、模拟昼夜环境变化与执行器物理反馈（制冷降温、开帘增光、净化降烟）
 */
export class SimulationEngine {
  public static readonly MAX_HISTORY_POINTS: number = 24;

  /**
   * 推进一个仿真时间步长，计算执行器对环境的真实反馈
   */
  public static stepEnvironment(devices: BaseDevice[], tickIndex: number): SimStepResult {
    const virtualHour = (8 + Math.max(0, tickIndex - 1) * 2) % 24;
    const timeLabel = `${virtualHour.toString().padStart(2, '0')}:00`;

    const tempSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.TEMPERATURE);
    const humiSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.HUMIDITY);
    const lightSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.ILLUMINANCE);
    const smokeSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.SMOKE_LEVEL);

    const ac = SimulationEngine.findActuatorById(devices, 'act_living_ac');
    const curtain = SimulationEngine.findActuatorById(devices, 'act_living_curtain');
    const purifier = SimulationEngine.findActuatorById(devices, 'act_bedroom_purifier');

    let updatedSensors = 0;

    // 1. 温度物理反馈仿真
    if (tempSensor && tempSensor.online) {
      let nextTemp = tempSensor.value;
      const isAfternoon = virtualHour >= 12 && virtualHour <= 18;
      if (ac && ac.online && ac.powerOn) {
        const diff = nextTemp - ac.levelValue;
        if (diff > 0.3) {
          nextTemp -= Math.min(1.2, diff * 0.4);
        } else if (diff < -0.3) {
          nextTemp += 0.3;
        }
      } else {
        nextTemp += isAfternoon ? 0.9 : -0.4;
      }
      if (tempSensor.updateReading(nextTemp)) {
        updatedSensors += 1;
      }
    }

    // 2. 湿度协同变化仿真
    if (humiSensor && humiSensor.online) {
      let nextHumi = humiSensor.value;
      if (ac && ac.online && ac.powerOn) {
        nextHumi -= 1.2;
      } else {
        nextHumi += (virtualHour < 8 || virtualHour >= 20) ? 1.5 : -0.5;
      }
      if (humiSensor.updateReading(nextHumi)) {
        updatedSensors += 1;
      }
    }

    // 3. 光照与窗帘开度联动仿真
    if (lightSensor && lightSensor.online) {
      let outdoorLux = 40;
      if (virtualHour >= 7 && virtualHour <= 18) {
        const noonDistance = Math.abs(13 - virtualHour);
        outdoorLux = Math.max(120, 820 - noonDistance * 110);
      }
      const curtainRatio = (curtain && curtain.online && curtain.powerOn)
        ? (curtain.levelValue / 100)
        : 0.15;
      const targetIndoorLux = Math.round(outdoorLux * (0.2 + 0.8 * curtainRatio));
      if (lightSensor.updateReading(targetIndoorLux)) {
        updatedSensors += 1;
      }
    }

    // 4. 烟雾浓度随空气净化器运行逐步消散
    if (smokeSensor && smokeSensor.online) {
      let nextSmoke = smokeSensor.value;
      if (purifier && purifier.online && purifier.powerOn && nextSmoke > 18) {
        const decay = Math.max(8, Math.round(purifier.levelValue * 0.35));
        nextSmoke = Math.max(15, nextSmoke - decay);
      } else if (nextSmoke > 20) {
        nextSmoke = Math.max(18, nextSmoke - 4);
      }
      if (smokeSensor.updateReading(nextSmoke)) {
        updatedSensors += 1;
      }
    }

    const snapshot = SimulationEngine.captureSnapshot(devices, timeLabel);
    return {
      snapshot: snapshot,
      updatedSensors: updatedSensors
    };
  }

  /**
   * 采集当前全屋环境与总功耗快照
   */
  public static captureSnapshot(devices: BaseDevice[], timeLabel: string): EnvironmentSnapshot {
    const tempSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.TEMPERATURE);
    const humiSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.HUMIDITY);
    const lightSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.ILLUMINANCE);
    const smokeSensor = SimulationEngine.findSensorByMetric(devices, MetricKey.SMOKE_LEVEL);

    return {
      timeLabel: timeLabel,
      temperature: tempSensor ? tempSensor.value : 25.0,
      humidity: humiSensor ? humiSensor.value : 55.0,
      illuminance: lightSensor ? lightSensor.value : 300,
      smokeLevel: smokeSensor ? smokeSensor.value : 15,
      totalWatts: SimulationEngine.calculateTotalWatts(devices)
    };
  }

  /**
   * 汇总所有在线且开启设备的实时总功耗 (W)
   */
  public static calculateTotalWatts(devices: BaseDevice[]): number {
    let total = 0;
    for (let i = 0; i < devices.length; i++) {
      const watts = devices[i].getEffectiveWatts();
      if (watts > 0 && Number.isFinite(watts)) {
        total += watts;
      }
    }
    return Math.round(total);
  }

  /**
   * 追加快照并维持最大队列长度
   */
  public static appendSnapshot(
    history: EnvironmentSnapshot[],
    snapshot: EnvironmentSnapshot
  ): EnvironmentSnapshot[] {
    const next = history.slice();
    next.push(snapshot);
    if (next.length > SimulationEngine.MAX_HISTORY_POINTS) {
      return next.slice(next.length - SimulationEngine.MAX_HISTORY_POINTS);
    }
    return next;
  }

  private static findSensorByMetric(devices: BaseDevice[], metric: MetricKey): SensorDevice | undefined {
    for (let i = 0; i < devices.length; i++) {
      const dev = devices[i];
      if (dev instanceof SensorDevice && dev.metricKey === metric) {
        return dev;
      }
    }
    return undefined;
  }

  private static findActuatorById(devices: BaseDevice[], id: string): ActuatorDevice | undefined {
    for (let i = 0; i < devices.length; i++) {
      const dev = devices[i];
      if (dev instanceof ActuatorDevice && dev.id === id) {
        return dev;
      }
    }
    return undefined;
  }
}
