import 'package:material_ui/material_ui.dart';

import 'game_webview_screen.dart';

/// Buka layar latihan (game). Sesi direkam otomatis selama layar terbuka.
Future<void> openTraining(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const GameWebViewScreen()));
