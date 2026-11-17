/**
 * Navigation 路由参数定义
 */
export interface DeviceDetailParam {
  deviceId: string;
}

export interface RuleEditorParam {
  ruleId: string;
}

export const ROUTE_DEVICE_DETAIL: string = 'DeviceDetail';
export const ROUTE_RULE_EDITOR: string = 'RuleEditor';
