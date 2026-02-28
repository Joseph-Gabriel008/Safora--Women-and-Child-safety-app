import 'package:flutter/foundation.dart';

class AppController extends ChangeNotifier {
  int _tabIndex = 0;

  int get tabIndex => _tabIndex;

  void setTab(int index) {
    if (_tabIndex == index) {
      return;
    }
    _tabIndex = index;
    notifyListeners();
  }
}
