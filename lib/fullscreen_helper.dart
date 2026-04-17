import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class FullScreenHelper {
  static void enableImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void disableImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
