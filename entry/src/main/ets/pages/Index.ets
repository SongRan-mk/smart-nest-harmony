import { DeviceDetailParam, ROUTE_DEVICE_DETAIL, ROUTE_RULE_EDITOR, RuleEditorParam } from '../model/NavTypes';
import { STORE_REVISION_KEY } from '../service/SmartHomeStore';
import { DashboardView } from '../view/DashboardView';
import { LogsView } from '../view/LogsView';
import { RulesView } from '../view/RulesView';
import { SimulationView } from '../view/SimulationView';
import { DeviceDetailPage } from './DeviceDetailPage';
import { RuleEditorPage } from './RuleEditorPage';

/**
 * 智巢中枢主入口页面
 * 集成 Navigation 页面路由栈与四模块底部 Tabs 导航
 */
@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @State currentIndex: number = 0;

  aboutToAppear(): void {
    AppStorage.setOrCreate(STORE_REVISION_KEY, 0);
  }

  @Builder
  pageMap(name: string, param: Object) {
    if (name === ROUTE_DEVICE_DETAIL) {
      DeviceDetailPage({ deviceId: (param as DeviceDetailParam).deviceId })
    } else if (name === ROUTE_RULE_EDITOR) {
      RuleEditorPage({ ruleId: (param as RuleEditorParam).ruleId })
    }
  }

  @Builder
  tabBarItem(index: number, title: string, iconRes: Resource) {
    Column({ space: 3 }) {
      SymbolGlyph(iconRes)
        .fontSize(21)
        .fontColor([this.currentIndex === index ? '#1677FF' : '#8C95A6'])
      Text(title)
        .fontSize(11)
        .fontWeight(this.currentIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? '#1677FF' : '#8C95A6')
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
  }

  build() {
    Navigation(this.pageStack) {
      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        TabContent() {
          DashboardView()
        }
        .tabBar(this.tabBarItem(0, '看板', $r('sys.symbol.house_fill')))

        TabContent() {
          RulesView()
        }
        .tabBar(this.tabBarItem(1, '规则', $r('sys.symbol.gearshape_fill')))

        TabContent() {
          SimulationView()
        }
        .tabBar(this.tabBarItem(2, '仿真', $r('sys.symbol.waveform_path_circle')))

        TabContent() {
          LogsView()
        }
        .tabBar(this.tabBarItem(3, '日志', $r('sys.symbol.doc_plaintext_fill')))
      }
      .barHeight(54)
      .barBackgroundColor('#FFFFFF')
      .scrollable(false)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
      .width('100%')
      .height('100%')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(this.pageMap)
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FA')
  }
}
