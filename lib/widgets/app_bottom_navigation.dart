import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/sell_pet/sell_home_screen.dart';
import '../app/routes.dart';

/// The three primary destinations: buy, sell and chat.
///
/// Buy is the main screen after login. Sell is the centre action and opens the
/// listing flow. Chat is the buyer ↔ seller inbox. Profile and everything else
/// stay reachable as pushed routes so each tab keeps a clean stack.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => AppShellState();

  /// Allows any screen to jump to a specific tab.
  static AppShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();
}

class AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;
  final _navKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  int get index => _index;

  void goToTab(int index) {
    if (index < 0 || index >= _navKeys.length) return;
    if (index == _index) {
      // Tapping the active tab pops that tab's stack back to its root.
      _navKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back must never pop the root navigator: doing so reveals the login
      // screen sitting underneath /shell and never moves between the screens
      // stacked inside a tab. Every system back gesture is instead routed to
      // the active tab by _handleBack below.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        // The bar is opaque, so the body must stop at its top edge. Extending the
        // body would push every pushed route's own bottom bar (checkout, chat
        // composer, FABs) underneath the shell bar instead of above it.
        body: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(
              navigatorKey: _navKeys[0],
              initialRoute: AppRoutes.home,
              builder: (_) => const HomeScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navKeys[1],
              initialRoute: AppRoutes.sellHome,
              builder: (_) => const SellHomeScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navKeys[2],
              initialRoute: AppRoutes.messages,
              builder: (_) => const ChatListScreen(),
            ),
          ],
        ),
        bottomNavigationBar: const _ShellBottomBar(),
      ),
    );
  }

  /// Routes a system back gesture: pop within the active tab first so back
  /// returns to the previous screen, otherwise fall back to the Buy tab, and
  /// only leave the app from the Buy tab's root screen.
  void _handleBack() {
    final navigator = _navKeys[_index].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (_index != 0) {
      goToTab(0);
      return;
    }
    // Nowhere left to navigate inside the app — hand back to the OS.
    SystemNavigator.pop();
  }
}

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar();

  @override
  Widget build(BuildContext context) {
    final shell = AppShell.of(context);
    final scheme = Theme.of(context).colorScheme;
    final selected = shell?.index ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              Expanded(
                child: _BarItem(
                  icon: Icons.shopping_bag_outlined,
                  selectedIcon: Icons.shopping_bag_rounded,
                  label: 'Buy',
                  selected: selected == 0,
                  onTap: () => shell?.goToTab(0),
                ),
              ),
              Expanded(child: _SellAction(shell: shell)),
              Expanded(
                child: _BarItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  selectedIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  selected: selected == 2,
                  onTap: () => shell?.goToTab(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.6);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centre action: a raised lavender plus button that switches to the sell tab.
class _SellAction extends StatelessWidget {
  const _SellAction({required this.shell});

  final AppShellState? shell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = (shell?.index ?? 0) == 1;
    final color = selected ? scheme.primary : AppColors.lavender;
    final foreground = selected ? scheme.onPrimary : AppColors.brandDark;

    return InkWell(
      onTap: () => shell?.goToTab(1),
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              selected ? Icons.edit_rounded : Icons.add_rounded,
              color: foreground,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Sell',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Each tab keeps its own navigation stack so deep screens do not reset when
/// the user switches tabs. Named routes pushed from a tab resolve against the
/// app's central route table so detail screens open inside the tab's stack.
class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navigatorKey,
    required this.initialRoute,
    required this.builder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final String initialRoute;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (initial, _) => [
        MaterialPageRoute(
          settings: RouteSettings(name: initialRoute),
          builder: builder,
        ),
      ],
      onGenerateRoute: (settings) {
        final table = AppRoutes.all;
        final screen = table[settings.name];
        if (screen != null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => screen(context),
          );
        }
        return MaterialPageRoute(settings: settings, builder: builder);
      },
    );
  }
}
