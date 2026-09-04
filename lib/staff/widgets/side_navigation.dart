import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../shared/brand_widgets.dart';
import 'nav_item.dart';

enum StaffPage { overview, liveQueue, checkIn, insights, settings }

class SideNavigation extends StatelessWidget {
  const SideNavigation({
    super.key,
    required this.selectedPage,
    required this.onSelected,
    this.staffName = 'Alex Tan',
    this.staffRole = 'Manager',
    this.onSignOut,
  });

  final StaffPage selectedPage;
  final ValueChanged<StaffPage> onSelected;
  final String staffName;
  final String staffRole;
  final VoidCallback? onSignOut;

  String get _initials {
    final parts = staffName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return staffName.isNotEmpty ? staffName.substring(0, 1).toUpperCase() : 'ST';
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 244,
    color: AppColors.forest,
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandMark(light: true),
        const SizedBox(height: 48),
        NavItem(
          icon: Icons.space_dashboard_rounded,
          label: 'Overview',
          selected: selectedPage == StaffPage.overview,
          onTap: () => onSelected(StaffPage.overview),
        ),
        NavItem(
          icon: Icons.format_list_numbered_rounded,
          label: 'Live queue',
          selected: selectedPage == StaffPage.liveQueue,
          onTap: () => onSelected(StaffPage.liveQueue),
        ),
        NavItem(
          icon: Icons.qr_code_scanner_rounded,
          label: 'Check-in',
          selected: selectedPage == StaffPage.checkIn,
          onTap: () => onSelected(StaffPage.checkIn),
        ),
        NavItem(
          icon: Icons.insights_rounded,
          label: 'Insights',
          selected: selectedPage == StaffPage.insights,
          onTap: () => onSelected(StaffPage.insights),
        ),
        NavItem(
          icon: Icons.settings_outlined,
          label: 'Settings',
          selected: selectedPage == StaffPage.settings,
          onTap: () => onSelected(StaffPage.settings),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.amber,
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staffName,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      staffRole,
                      style: const TextStyle(color: AppColors.sage, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (onSignOut != null)
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.sage,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
