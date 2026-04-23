# Todo List

一个基于 Flutter 的本地待办提醒应用，主打「创建任务 + 定时提醒 + 到点响铃」这一条完整链路，当前实现以 Android 端为主。

## 功能概览

- 新建、编辑、删除、完成任务
- 为任务设置标题、备注、提醒时间
- 支持“提醒时响铃”模式
- 响铃任务会在正式提醒前 5 分钟先发出预提醒通知
- 预提醒通知支持提前关闭本次响铃
- 支持按“待办 / 今天 / 已完成”筛选任务
- 任务数据本地持久化保存
- 应用重启或设备重启后自动恢复已安排的提醒
- 内置 Android 后台保活指引页，方便用户补齐自启动、后台无限制等设置

## 技术栈

- Flutter 3.38.9
- Dart 3.10.8
- `flutter_local_notifications`
- `shared_preferences`
- `timezone`
- `flutter_timezone`
- `android_intent_plus`

## 项目结构

```text
lib/
  main.dart                          应用入口
  todo_app.dart                      MaterialApp 与主题配置
  models/
    todo_item.dart                   任务实体与序列化
    todo_draft.dart                  编辑态草稿模型
    todo_filter.dart                 列表筛选枚举
  pages/
    todo_home_page.dart              主页面、任务列表、提醒状态入口
    background_keepalive_guide_page.dart
                                      Android 后台保活引导页
  services/
    todo_storage.dart                本地存储
    notification_service.dart        Flutter 侧提醒服务

android/app/src/main/kotlin/com/example/my_todo_test/
  MainActivity.kt                    Flutter <-> Android 通道
  TodoAlarmScheduler.kt              AlarmManager 调度与通知构建
  TodoAlarmReceiver.kt               闹钟广播接收
  TodoAlarmBootReceiver.kt           开机/升级后恢复提醒
  TodoRingtoneService.kt             响铃前台服务
```

## 运行环境

建议使用以下环境运行项目：

- Flutter 3.38.x
- Dart 3.10.x
- Android 8.0 及以上真机或模拟器

说明：

- 本项目的核心提醒能力依赖 Android 原生 `AlarmManager`、通知权限、精确闹钟权限和前台服务。
- iOS 目录目前未接入对应原生提醒实现，因此当前更适合作为 Android 项目使用和继续开发。



## 提醒机制说明

项目当前的提醒链路如下：

1. Flutter 页面创建或更新任务
2. `notification_service.dart` 将可提醒任务同步到 Android 原生层
3. `TodoAlarmScheduler.kt` 使用 `AlarmManager` 安排精确提醒
4. 到达提醒时间前 5 分钟，如果该任务开启了响铃，会先发送一条预提醒通知
5. 到达正式提醒时间后，发送通知并可启动响铃服务
6. 点击通知后会把任务 ID 回传给 Flutter，并在应用内打开对应任务



## Android 权限与设置

项目在 AndroidManifest 中已经声明了以下关键权限：

- `POST_NOTIFICATIONS`
- `SCHEDULE_EXACT_ALARM`
- `RECEIVE_BOOT_COMPLETED`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
- `USE_FULL_SCREEN_INTENT`

为了让提醒更稳定，除了系统权限之外，通常还需要用户手动完成这些设置：

- 允许通知
- 允许精确闹钟
- 关闭或放宽电池优化限制
- 允许应用自启动
- 允许后台无限制运行

项目里已经提供后台保活指引页，针对常见 Android 厂商给出了设置建议。

## 当前界面说明

- 主页面使用卡片式布局展示仪表盘、任务筛选和任务列表
- 新建任务入口保留为右下角悬浮按钮
- 任务编辑通过底部弹层完成
- 通知点击或响铃提醒可直接定位到对应任务

### 本地存储

- 任务列表保存在 `todo_items_v1`
- 下一个任务 ID 保存在 `todo_next_id_v1`
- 自启动确认状态保存在 `reminder_auto_start_confirmed_v1`
- 后台无限制确认状态保存在 `reminder_unrestricted_background_confirmed_v1`

### 测试

当前项目已包含基础 Widget Test，覆盖：

- 应用首页渲染
- 提醒权限状态的关键逻辑

## 后续可扩展方向

- 增加任务搜索、排序和标签分类
- 支持重复提醒
- 支持桌面小组件或快捷操作
- 增加 iOS 端原生提醒适配
- 接入导出、备份或云同步
