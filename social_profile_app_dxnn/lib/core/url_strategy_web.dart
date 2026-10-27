import 'package:flutter_web_plugins/url_strategy.dart';

/// URL propres sur le Web : `/post/<id>` au lieu de `/#/post/<id>`.
void configureUrlStrategy() {
  usePathUrlStrategy();
}
