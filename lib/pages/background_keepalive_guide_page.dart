import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';

class BackgroundKeepAliveGuidePage extends StatefulWidget {
  const BackgroundKeepAliveGuidePage({super.key});

  @override
  State<BackgroundKeepAliveGuidePage> createState() =>
      _BackgroundKeepAliveGuidePageState();
}

class _BackgroundKeepAliveGuidePageState
    extends State<BackgroundKeepAliveGuidePage> {
  bool _unrestrictedBackgroundConfirmed = false;
  bool _autoStartConfirmed = false;

  static const String _applicationId = 'com.example.my_todo_test';

  Future<void> _openAppSettings() async {
    final AndroidIntent intent = AndroidIntent(
      action: 'action_application_details_settings',
      data: 'package:$_applicationId',
    );
    await intent.launch();
  }

  Future<void> _openBatteryOptimizationSettings() async {
    const AndroidIntent intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('后台保活引导')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '为什么会清后台后不提醒',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '部分 Android 厂商会在你手动划掉最近任务后停止应用，连本地闹铃提醒也可能一起失效。这不是普通 Flutter 通知代码能完全绕过的限制。',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _openAppSettings,
                        icon: const Icon(Icons.settings_applications),
                        label: const Text('打开应用设置'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openBatteryOptimizationSettings,
                        icon: const Icon(Icons.battery_saver),
                        label: const Text('电池优化设置'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '完成后请手动确认',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _unrestrictedBackgroundConfirmed,
                    title: const Text('我已设置为不限制后台'),
                    subtitle: const Text('包括无限制后台、允许后台活动、关闭后台冻结等'),
                    onChanged: (bool? value) {
                      setState(() {
                        _unrestrictedBackgroundConfirmed = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _autoStartConfirmed,
                    title: const Text('我已允许应用自启动'),
                    subtitle: const Text('包括自启动、开机自启、应用启动管理等'),
                    onChanged: (bool? value) {
                      setState(() {
                        _autoStartConfirmed = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop<Map<String, bool>>(<String, bool>{
                        'unrestrictedBackgroundConfirmed':
                            _unrestrictedBackgroundConfirmed,
                        'autoStartConfirmed': _autoStartConfirmed,
                      });
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('保存确认结果'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _GuideSection(
            title: '通用设置',
            steps: <String>[
              '允许通知、精确闹钟、全屏提醒。',
              '把应用设置成“不限制后台”或“无限制”。',
              '允许自启动、后台弹出界面、锁屏显示。',
              '尽量不要从最近任务里手动划掉应用。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '小米 / Redmi / POCO',
            steps: <String>[
              '设置 -> 应用设置 -> 授权管理 -> 自启动，允许本应用。',
              '设置 -> 省电与电池 -> 应用省电，改为“无限制”。',
              '最近任务里下拉应用卡片，尝试加锁防止被清理。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '华为 / 荣耀',
            steps: <String>[
              '设置 -> 应用和服务 -> 应用启动管理，关闭自动管理并手动全开。',
              '设置 -> 电池 -> 启动管理或耗电保护，允许后台活动。',
              '把应用加入受保护应用或后台锁定名单。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: 'OPPO / 一加 / realme',
            steps: <String>[
              '设置 -> 应用管理 -> 自启动管理，允许本应用。',
              '设置 -> 电池 -> 更多 -> 高耗电管理 / 后台冻结，改成不限制。',
              '最近任务中给应用加锁，避免一键清理。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: 'vivo / iQOO',
            steps: <String>[
              '设置 -> 应用与权限 -> 权限管理 -> 自启动，允许本应用。',
              '设置 -> 电池 -> 后台高耗电 / 后台耗电管理，设为允许。',
              '检查 i 管家里是否把应用加入了省电清理。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '三星',
            steps: <String>[
              '设置 -> 电池和设备维护 -> 电池 -> 后台使用限制。',
              '把应用从“深度睡眠应用”移除。',
              '如果有“未监视应用”，可以把本应用加入进去。',
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...steps.asMap().entries.map((MapEntry<int, String> entry) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == steps.length - 1 ? 0 : 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${entry.key + 1}. '),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
