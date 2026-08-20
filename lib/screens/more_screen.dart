import 'package:flutter/material.dart';

import '../features/measuring_tools/screens/measuring_tools_manager_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/protocolflow_app_bar.dart';
import '../widgets/protocolflow_ui.dart';
import 'dashboard_screen.dart';
import 'user_guide_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ProtocolFlowContentBoundary(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          const ProtocolFlowScreenHeader(
            title: 'More',
            subtitle: 'Insights, guidance, and laboratory settings.',
          ),
          const SizedBox(height: 24),
          _MoreSection(
            title: 'Insights',
            children: [
              _MoreTile(
                key: const Key('more-dashboard'),
                icon: Icons.dashboard_outlined,
                title: 'Dashboard',
                subtitle: 'Activity and protocol insights',
                onTap: () => _push(
                  context,
                  Scaffold(
                    appBar: ProtocolFlowAppBar(title: 'Dashboard'),
                    body: const DashboardScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MoreSection(
            title: 'Tools and guidance',
            children: [
              _MoreTile(
                key: const Key('more-measuring-tools'),
                icon: Icons.straighten_outlined,
                title: 'Measuring Tools',
                subtitle: 'Configure pipettes and measuring equipment',
                onTap: () =>
                    _push(context, const MeasuringToolsManagerScreen()),
              ),
              _MoreTile(
                key: const Key('more-user-guide'),
                icon: Icons.menu_book_outlined,
                title: 'User Guide',
                subtitle: 'Learn ProtocolFlow workflows',
                onTap: () => _push(context, const UserGuideScreen()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MoreSection(
            title: 'Settings and data',
            children: [
              _MoreTile(
                key: const Key('more-settings'),
                icon: Icons.settings_outlined,
                title: 'Settings, Backup and Restore',
                subtitle: 'App preferences, import, export, and reset',
                onTap: onOpenSettings,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
