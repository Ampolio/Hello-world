# PharmacyFinder（iOS）

一个用于**查询附近药店**的 iOS SwiftUI 示例应用。

## 功能

- 获取用户当前位置（CoreLocation）
- 使用 Apple MapKit 本地搜索「药店」
- 按距离由近到远展示药店列表
- 显示名称、地址、电话、距离
- 点击条目可直接在 Apple 地图中打开导航

## 目录

- `PharmacyFinder/PharmacyFinderApp.swift`：应用入口
- `PharmacyFinder/ContentView.swift`：主界面与交互逻辑
- `PharmacyFinder/LocationManager.swift`：定位权限与定位获取
- `PharmacyFinder/PharmacySearchService.swift`：附近药店搜索服务
- `PharmacyFinder/Pharmacy.swift`：药店数据模型

## 接入 Xcode

1. 新建 iOS App（SwiftUI）工程。
2. 将 `PharmacyFinder` 目录中的 Swift 文件拖入工程。
3. 在 `Info.plist` 中添加定位权限文案：
   - `NSLocationWhenInUseUsageDescription`：例如“用于查询附近药店”
4. 在真机或模拟器运行，点击“查找附近药店”。

> 说明：MapKit 搜索结果依赖 Apple 地图数据与地理位置。不同地区返回结果可能不同。

## 其他文档

- `docs/password-manager-design.md`：类 1Password 密码保存与同步软件的完整设计方案。
