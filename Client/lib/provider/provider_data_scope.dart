import 'package:flutter/widgets.dart';

class ProviderDataScope extends InheritedWidget {
  final Map<String, dynamic> provider;
  final Future<void> Function() refresh;

  const ProviderDataScope({
    super.key,
    required this.provider,
    required this.refresh,
    required super.child,
  });

  static ProviderDataScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProviderDataScope>();
    assert(scope != null, 'ProviderDataScope was not found above this page.');
    return scope!;
  }

  String get companyName {
    final value = provider['companyName']?.toString().trim();
    return value?.isNotEmpty == true ? value! : 'Provider';
  }

  String get currency {
    final value = provider['currency']?.toString().trim().toUpperCase();
    return value?.isNotEmpty == true ? value! : 'AED';
  }

  String get profilePicture =>
      provider['profilePicture']?.toString().trim() ?? '';

  @override
  bool updateShouldNotify(ProviderDataScope oldWidget) =>
      oldWidget.provider != provider;
}
