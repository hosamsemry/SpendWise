import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardAmountsHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void setHidden(bool hidden) => state = hidden;
}

/// Controls whether monetary amounts on the Dashboard hero card are masked for privacy.
final dashboardAmountsHiddenProvider =
    NotifierProvider<DashboardAmountsHiddenNotifier, bool>(
      DashboardAmountsHiddenNotifier.new,
    );
