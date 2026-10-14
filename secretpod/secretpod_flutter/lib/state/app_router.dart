import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'invitation_link.dart';

/// Only navigation metadata belongs here. Never include vault or form contents.
class AppRoute {
  const AppRoute({
    this.page = 0,
    this.invitationToken,
    this.workspacePage,
    this.overlayDepth = 0,
    this.session = 0,
  });

  static const paths = [
    '/secrets',
    '/activity',
    '/members',
    '/invitations',
    '/settings',
  ];
  final int page;
  final String? invitationToken;
  final int? workspacePage;
  final int overlayDepth;
  final int session;
}

class AppRouteParser extends RouteInformationParser<AppRoute> {
  const AppRouteParser();

  @override
  Future<AppRoute> parseRouteInformation(RouteInformation routeInformation) {
    final uri = routeInformation.uri;
    final token = invitationTokenFromRoute(uri);
    final path = uri.hasFragment ? uri.fragment : uri.path;
    final index = AppRoute.paths.indexOf(path);
    final state = routeInformation.state;
    final previous = state is Map ? state['workspacePage'] : null;
    final depth = state is Map ? state['overlayDepth'] : null;
    return SynchronousFuture(
      AppRoute(
        page: index < 0 ? 0 : index,
        invitationToken: token,
        workspacePage: previous is int && previous >= 0 && previous < 3
            ? previous
            : null,
        overlayDepth: depth is int && depth >= 0 ? depth : 0,
      ),
    );
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute configuration) =>
      RouteInformation(
        // The default Flutter hash strategy keeps invitation tokens in the
        // browser fragment, including when opening an existing private link.
        uri: Uri.parse(
          configuration.invitationToken == null
              ? AppRoute.paths[configuration.page]
              : '/invite=${configuration.invitationToken}',
        ),
        state: {
          'workspacePage': configuration.workspacePage ?? 0,
          'overlayDepth': configuration.overlayDepth,
          'session': configuration.session,
        },
      );
}

class AppRouter extends RouterDelegate<AppRoute>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoute> {
  AppRouter({required this.homeBuilder});

  final WidgetBuilder homeBuilder;
  @override
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  AppRoute _route = const AppRoute();
  int _workspacePage = 0;
  int _revision = 0;
  int _session = 0;
  bool _disposed = false;
  late _OverlayObserver _observer = _OverlayObserver(_overlaysChanged);
  bool invitationPreferSignIn = false;

  int get page => _route.page;
  int get workspacePage => _workspacePage;
  String? get invitationToken => _route.invitationToken;
  int get overlayDepth => _observer.depth;

  @override
  AppRoute get currentConfiguration => AppRoute(
    page: page,
    invitationToken: invitationToken,
    workspacePage: _workspacePage,
    overlayDepth: overlayDepth,
    session: _session,
  );

  void navigate(int page) {
    if (page == this.page && invitationToken == null) return;
    _revision++;
    _apply(AppRoute(page: page));
    notifyListeners();
  }

  void _apply(AppRoute route) {
    if (route.workspacePage != null) _workspacePage = route.workspacePage!;
    if (route.page < 3 && route.invitationToken == null) {
      _workspacePage = route.page;
    }
    _route = route;
    invitationPreferSignIn = false;
  }

  void closeInvitation() {
    final context = navigatorKey.currentContext;
    void close() {
      _revision++;
      _apply(AppRoute(page: _workspacePage));
      notifyListeners();
    }

    if (context != null) {
      Router.neglect(context, close);
    } else {
      close();
    }
  }

  /// Discard all transient UI on logout or account switching, without prompting.
  void resetSession({required bool signedOut}) {
    _revision++;
    _session++;
    navigatorKey = GlobalKey<NavigatorState>();
    _observer = _OverlayObserver(_overlaysChanged);
    _workspacePage = 0;
    _route = AppRoute(invitationToken: invitationToken);
    invitationPreferSignIn = invitationToken != null && signedOut;
    notifyListeners();
  }

  @override
  Future<void> setInitialRoutePath(AppRoute configuration) {
    _apply(configuration);
    return SynchronousFuture(null);
  }

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    final revision = ++_revision;
    final navigator = navigatorKey.currentState;
    if (navigator != null &&
        navigator.canPop() &&
        (configuration.overlayDepth != overlayDepth ||
            configuration.page != page ||
            configuration.invitationToken != invitationToken)) {
      // Browser Back must use the same PopScope/dirty-form guard as in-app
      // Back. Consume one transient route before changing the workspace page.
      await navigator.maybePop();
      if (revision != _revision) return;
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Router.neglect(context, notifyListeners);
      }
      return;
    }
    _apply(configuration);
  }

  void _overlaysChanged() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    observers: [_observer],
    pages: [
      MaterialPage<void>(
        key: const ValueKey('home'),
        child: homeBuilder(context),
      ),
    ],
    onDidRemovePage: (_) {},
  );
}

class _OverlayObserver extends NavigatorObserver {
  _OverlayObserver(this.onChanged);
  final VoidCallback onChanged;
  final List<Route<dynamic>> _routes = [];
  int get depth => _routes.where((route) => route.settings is! Page).length;

  void _change(VoidCallback update) {
    final previousDepth = depth;
    update();
    if (depth != previousDepth) onChanged();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(() => _routes.add(route));
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(() => _routes.remove(route));
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(() => _routes.remove(route));
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _change(() {
        _routes.remove(oldRoute);
        if (newRoute != null) _routes.add(newRoute);
      });
}
