import 'package:flutter/widgets.dart';

import 'browser_history.dart';

/// Adds ephemeral entries for dialogs, without serializing their contents.
/// Restore the browser cursor before asking a dialog to close: replacing the
/// destination entry would destroy the user's previous workspace destination.
class AppHistory extends PlatformRouteInformationProvider {
  AppHistory({
    required this.overlayDepth,
    required this.popOverlay,
    this.traverse = traverseBrowserHistory,
  }) : super(
         initialRouteInformation: RouteInformation(
           uri: Uri.parse(
             WidgetsBinding.instance.platformDispatcher.defaultRouteName,
           ),
         ),
       );

  final int Function() overlayDepth;
  final Future<bool> Function() popOverlay;
  final bool Function(int delta) traverse;
  final String _historyId = DateTime.now().microsecondsSinceEpoch.toString();
  int _index = 0;
  int _depth = 0;
  int _session = 0;
  bool _initialized = false;
  bool _restoring = false;
  bool _dismissing = false;
  bool _cancelledTraversal = false;

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    final state = Map<String, Object?>.from(routeInformation.state! as Map);
    final depth = state['overlayDepth']! as int;
    final session = state['session']! as int;
    final reset = session != _session;
    if (reset) {
      _cancelledTraversal = _cancelledTraversal || _restoring || _dismissing;
      _restoring = false;
      _dismissing = false;
    } else if (_restoring || _dismissing) {
      return;
    }
    if (_initialized && !reset && depth < _depth) {
      _dismissing = traverse(depth - _depth);
      if (_dismissing) return;
    }
    final push =
        _initialized &&
        !reset &&
        (depth > _depth ||
            (type != RouteInformationReportingType.neglect &&
                routeInformation.uri != value.uri));
    if (push) _index++;
    _depth = depth;
    _session = session;
    _initialized = true;
    state['historyId'] = _historyId;
    state['historyIndex'] = _index;
    super.routerReportsNewRouteInformation(
      RouteInformation(uri: routeInformation.uri, state: state),
      type: push
          ? RouteInformationReportingType.navigate
          : RouteInformationReportingType.neglect,
    );
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final state = routeInformation.state;
    final sameHistory = state is Map && state['historyId'] == _historyId;
    final incomingIndex = sameHistory ? state['historyIndex'] as int? : null;
    if (_cancelledTraversal) {
      _cancelledTraversal = false;
      if (incomingIndex != null) _index = incomingIndex;
      // The browser completed a move initiated by the old session. Keep the
      // new session's route and never run a delayed pop on its navigator.
      routerReportsNewRouteInformation(
        value,
        type: RouteInformationReportingType.neglect,
      );
      return true;
    }
    if (_restoring) {
      if (incomingIndex != _index) return true;
      _restoring = false;
      await popOverlay();
      return true;
    }
    final dismissing = _dismissing;
    _dismissing = false;
    if (!dismissing &&
        overlayDepth() > 0 &&
        incomingIndex != null &&
        incomingIndex != _index) {
      _restoring = traverse(_index - incomingIndex);
      if (_restoring) return true;
    }
    if (incomingIndex != null) _index = incomingIndex;
    _depth = overlayDepth();
    return super.didPushRouteInformation(routeInformation);
  }
}
