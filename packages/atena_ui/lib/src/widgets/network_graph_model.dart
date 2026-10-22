import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// Nó do grafo. O `weight` aumenta o tamanho da bolinha; `tooltip` é o resumo
/// curto usado quando não há `NetworkGraph.nodePreview`.
class NetworkNode {
  const NetworkNode({
    required this.id,
    required this.label,
    this.weight = 1,
    this.tooltip,
  });

  final String id;
  final String label;
  final int weight;
  final String? tooltip;
}

/// Aresta entre dois nós, referenciados pelo `id`.
class NetworkEdge {
  const NetworkEdge({required this.source, required this.target});

  final String source;
  final String target;
}

/// Ajustes da força que posiciona os nós.
///
/// Os valores são multiplicadores: `1` é o equilíbrio padrão da simulação.
/// Mexer em [repulsion] afasta os nós, em [linkDistance] estica as conexões e
/// em [gravity] puxa a rede para o centro.
@immutable
class NetworkGraphSettings {
  const NetworkGraphSettings({
    this.repulsion = 1,
    this.linkDistance = 1,
    this.gravity = 1,
  });

  static const NetworkGraphSettings defaults = NetworkGraphSettings();
  static const double minRepulsion = 0.3;
  static const double maxRepulsion = 2.4;
  static const double minLinkDistance = 0.4;
  static const double maxLinkDistance = 2.2;
  static const double minGravity = 0.3;
  static const double maxGravity = 2.4;

  /// Força que afasta os nós entre si.
  final double repulsion;

  /// Tamanho desejado das conexões.
  final double linkDistance;

  /// Força que traz a rede para o centro da área.
  final double gravity;

  NetworkGraphSettings copyWith({
    double? repulsion,
    double? linkDistance,
    double? gravity,
  }) {
    return NetworkGraphSettings(
      repulsion: repulsion ?? this.repulsion,
      linkDistance: linkDistance ?? this.linkDistance,
      gravity: gravity ?? this.gravity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NetworkGraphSettings &&
        other.repulsion == repulsion &&
        other.linkDistance == linkDistance &&
        other.gravity == gravity;
  }

  @override
  int get hashCode => Object.hash(repulsion, linkDistance, gravity);
}

/// Estado externo da rede: ajustes de força, modo de conexão e comandos do
/// painel (reorganizar, centralizar e zoom).
///
/// O componente funciona sem controller: sem ele, usa os ajustes padrão e não
/// expõe comandos. O controller não conhece a aplicação: só guarda valores e
/// avisa quando algo muda.
class NetworkGraphController extends ChangeNotifier {
  NetworkGraphController({NetworkGraphSettings? settings})
    : _settings = settings ?? NetworkGraphSettings.defaults;

  NetworkGraphSettings _settings;
  bool _connectMode = false;
  int _layoutCommand = 0;
  int _viewCommand = 0;
  double _zoomCommand = 0;

  /// Posições normalizadas (0 a 1) da última montagem, para o grafo reabrir
  /// com o mesmo desenho em vez de começar de novo.
  final Map<String, Offset> _positions = <String, Offset>{};

  NetworkGraphSettings get settings => _settings;
  bool get connectMode => _connectMode;

  Offset? rememberedPositionOf(String id) => _positions[id];

  void rememberPosition(String id, Offset position) =>
      _positions[id] = position;

  /// Contador de pedidos de reorganização; o grafo observa o valor.
  int get layoutCommand => _layoutCommand;

  /// Contador de pedidos de centralização (zoom e deslocamento originais).
  int get viewCommand => _viewCommand;

  /// Zoom acumulado em passos; o grafo converte cada passo em escala.
  double get zoomCommand => _zoomCommand;

  void updateSettings(NetworkGraphSettings settings) {
    if (_settings == settings) {
      return;
    }
    _settings = settings;
    notifyListeners();
  }

  void setConnectMode(bool value) {
    if (_connectMode == value) {
      return;
    }
    _connectMode = value;
    notifyListeners();
  }

  void toggleConnectMode() => setConnectMode(!_connectMode);

  void reorganize() {
    _layoutCommand++;
    notifyListeners();
  }

  void resetView() {
    _viewCommand++;
    notifyListeners();
  }

  void zoomIn() {
    _zoomCommand++;
    notifyListeners();
  }

  void zoomOut() {
    _zoomCommand--;
    notifyListeners();
  }
}
