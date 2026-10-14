import 'package:web/web.dart' as web;

bool traverseBrowserHistory(int delta) {
  web.window.history.go(delta);
  return true;
}
