import '../providers/glove_provider.dart';
import 'glove_data_source.dart';

/// Sumber data glove nyata: key event dari EventChannel Android, gaya dan status
/// koneksi dari notifikasi GATT yang dikelola [GloveProvider].
class RealGloveSource extends GloveDataSource {
  final GloveProvider glove;
  RealGloveSource(this.glove);

  @override
  String get id => 'real';

  @override
  Stream<KeyPress> get keyEvents => KeyEventChannel.stream;

  @override
  Stream<ForceSample> get forceSamples => glove.forceSampleStream;

  @override
  Stream<bool> get connectionState => glove.connectionStream;

  @override
  bool get isConnected => glove.isConnected;
}
