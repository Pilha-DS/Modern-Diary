import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_durations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'network_graph_model.dart';

export 'network_graph_model.dart';

/// Rede de nós e conexões com layout de forças, sem dependência externa.
///
/// O componente não conhece a aplicação: recebe nós e arestas prontos e
/// devolve por callback o nó tocado e, quando permitido, o par conectado.
///
/// Interações:
/// - arrastar um nó move e fixa a posição dele;
/// - arrastar o fundo desloca a rede; a roda do mouse dá zoom;
/// - com [NetworkGraphController.connectMode] ligado, arrastar de um nó até
///   outro chama [onConnect] em vez de mover;
/// - [NetworkGraphController.reorganize] solta os nós fixados e refaz o
///   layout; [resetView] volta o zoom e o deslocamento ao original.
///
/// Uso com mini-modal:
///
/// ```dart
/// final controller = NetworkGraphController();
///
/// NetworkGraph(
///   controller: controller,
///   nodes: const [NetworkNode(id: '1', label: 'SQL', weight: 3)],
///   edges: const [],
///   onNodeTap: (node) => openDetail(node.id),
///   onConnect: (source, target) => connect(source.id, target.id),
///   nodePreview: (context, node) => NodePreview(node: node),
/// )
/// ```
class NetworkGraph extends StatefulWidget {
  const NetworkGraph({
    super.key,
    required this.nodes,
    required this.edges,
    required this.onNodeTap,
    this.controller,
    this.selectedId,
    this.semanticLabel,
    this.fallbackHeight = 520,
    this.tooltipWait = AppDurations.hoverTooltip,
    this.nodePreview,
    this.onConnect,
  });

  final List<NetworkNode> nodes;
  final List<NetworkEdge> edges;
  final ValueChanged<NetworkNode> onNodeTap;

  /// Estado externo opcional: ajustes de força e comandos do painel.
  final NetworkGraphController? controller;

  final String? selectedId;
  final String? semanticLabel;
  final double fallbackHeight;

  /// Tempo de hover sobre o nó para o resumo aparecer.
  final Duration tooltipWait;

  /// Mini-modal exibido ao lado do nó depois de [tooltipWait]. Tem prioridade
  /// sobre o `tooltip` do nó.
  final Widget Function(BuildContext context, NetworkNode node)? nodePreview;

  /// Chamado quando a conexão é criada arrastando um nó sobre outro, no modo
  /// de conexão do controller. Sem ele, o modo de conexão fica desligado.
  final void Function(NetworkNode source, NetworkNode target)? onConnect;

  @override
  State<NetworkGraph> createState() => _NetworkGraphState();
}

enum _DragMode { none, node, connect, pan }

class _NetworkGraphState extends State<NetworkGraph>
    with SingleTickerProviderStateMixin {
  static const int _maxLayoutNodes = 200;
  static const double _edgeInset = 24;

  /// Temperatura inicial do layout e dos reaquecimentos: quanto um nó pode
  /// andar por quadro. Ela cai a cada quadro, então a rede assenta sozinha.
  static const double _layoutTemperature = 0.03;
  static const double _reheatTemperature = 0.012;
  static const double _cooling = 0.975;
  static const double _minTemperature = 0.0004;
  static const double _minScale = 0.45;
  static const double _maxScale = 2.4;

  // Pesos da simulação. Foram calibrados para a rede se espalhar pela área,
  // sem colar nas bordas nem sobrepor os nós.
  static const double _repulsionStrength = 0.02;
  static const double _springStrength = 0.1;
  static const double _gravityStrength = 0.05;
  static const double _linkRestScale = 1.8;
  static const double _collisionScale = 0.8;
  static const double _collisionStrength = 0.5;
  static const double _margin = 0.05;
  static const double _marginStrength = 0.5;

  late final Ticker _ticker;
  NetworkGraphController? _ownController;

  NetworkGraphController get _controller =>
      widget.controller ?? _ownController!;

  List<NetworkNode> _visibleNodes = const [];
  List<NetworkEdge> _visibleEdges = const [];
  List<(int, int)> _springPairs = const [];
  List<Offset> _positions = const [];
  List<Offset> _displacements = const [];
  late NetworkGraphSettings _settings;
  String? _layoutSignature;

  final Set<String> _pinned = <String>{};
  double _temperature = 0;
  Size _size = Size.zero;

  double _scale = 1;
  Offset _pan = Offset.zero;

  String? _hoveredId;
  String? _previewId;
  Timer? _previewTimer;

  _DragMode _dragMode = _DragMode.none;
  String? _dragNodeId;
  Offset? _dragPointer;
  String? _connectTargetId;
  Offset? _pointerDownPosition;
  int _activePointers = 0;
  Offset _gestureStartFocalPoint = Offset.zero;
  Offset _gestureStartPan = Offset.zero;
  double _lastGestureScale = 1;
  bool _movedDuringGesture = false;

  int _lastLayoutCommand = 0;
  int _lastViewCommand = 0;
  double _lastZoomCommand = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (widget.controller == null) {
      _ownController = NetworkGraphController();
    }
    _settings = _controller.settings;
    _lastLayoutCommand = _controller.layoutCommand;
    _lastViewCommand = _controller.viewCommand;
    _lastZoomCommand = _controller.zoomCommand;
    _controller.addListener(_onControllerChanged);
    _ensureLayout();
  }

  @override
  void didUpdateWidget(covariant NetworkGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final previousController = oldWidget.controller ?? _ownController;
      previousController?.removeListener(_onControllerChanged);
      if (oldWidget.controller == null) {
        _ownController?.dispose();
        _ownController = null;
      }
      if (widget.controller == null) {
        _ownController = NetworkGraphController();
      }
      _settings = _controller.settings;
      _lastLayoutCommand = _controller.layoutCommand;
      _lastViewCommand = _controller.viewCommand;
      _lastZoomCommand = _controller.zoomCommand;
      _controller.addListener(_onControllerChanged);
      _reheat();
    }
    _ensureLayout();
  }

  @override
  void dispose() {
    _rememberPositions();
    _previewTimer?.cancel();
    _controller.removeListener(_onControllerChanged);
    _ownController?.dispose();
    _ticker.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    var needsBuild = false;

    if (_controller.layoutCommand != _lastLayoutCommand) {
      _lastLayoutCommand = _controller.layoutCommand;
      _resetLayout();
      needsBuild = true;
    }
    if (_controller.viewCommand != _lastViewCommand) {
      _lastViewCommand = _controller.viewCommand;
      _scale = 1;
      _pan = Offset.zero;
      needsBuild = true;
    }
    final zoomDelta = _controller.zoomCommand - _lastZoomCommand;
    if (zoomDelta != 0) {
      _lastZoomCommand = _controller.zoomCommand;
      _applyZoom(
        math.pow(1.22, zoomDelta).toDouble(),
        Offset(_size.width / 2, _size.height / 2),
      );
      needsBuild = true;
    }
    if (_controller.settings != _settings) {
      _settings = _controller.settings;
      _reheat();
    }

    if (mounted && needsBuild) {
      setState(() {});
    }
  }

  /// Abre a prévia do nó só depois de [NetworkGraph.tooltipWait] de hover.
  void _setHovered(NetworkNode? node) {
    final id = node?.id;
    if (id == _hoveredId) {
      return;
    }
    _previewTimer?.cancel();
    final changed = id != _previewId;
    setState(() {
      _hoveredId = id;
      if (changed) {
        _previewId = null;
      }
    });
    if (id == null || !_hasPreview(node)) {
      return;
    }
    _previewTimer = Timer(widget.tooltipWait, () {
      if (mounted && _hoveredId == id) {
        setState(() => _previewId = id);
      }
    });
  }

  /// A prévia existe quando o chamador monta o mini-modal ou o nó tem resumo.
  bool _hasPreview(NetworkNode? node) {
    return node != null && (widget.nodePreview != null || node.tooltip != null);
  }

  // ---------------------------------------------------------------------------
  // Layout e simulação
  // ---------------------------------------------------------------------------

  void _ensureLayout() {
    final signature = _signatureOf(widget.nodes, widget.edges);
    if (signature == _layoutSignature) {
      return;
    }
    final isFirstLayout = _layoutSignature == null;
    final previous = <String, Offset>{
      for (var index = 0; index < _visibleNodes.length; index++)
        if (index < _positions.length)
          _visibleNodes[index].id: _positions[index],
    };

    final nodes = widget.nodes.take(_maxLayoutNodes).toList(growable: false);
    final ids = {for (final node in nodes) node.id};
    final edges = [
      for (final edge in widget.edges)
        if (ids.contains(edge.source) && ids.contains(edge.target)) edge,
    ];

    _visibleNodes = nodes;
    _visibleEdges = edges;
    _layoutSignature = signature;
    _pinned.retainWhere(ids.contains);

    final indexOf = <String, int>{
      for (var index = 0; index < nodes.length; index++) nodes[index].id: index,
    };
    _springPairs = [
      for (final edge in edges)
        if (indexOf.containsKey(edge.source) &&
            indexOf.containsKey(edge.target) &&
            edge.source != edge.target)
          (indexOf[edge.source]!, indexOf[edge.target]!),
    ];

    _positions = [
      for (var index = 0; index < nodes.length; index++)
        previous[nodes[index].id] ??
            _controller.rememberedPositionOf(nodes[index].id) ??
            _freshPosition(nodes[index], index, previous),
    ];
    _displacements = List<Offset>.filled(nodes.length, Offset.zero);

    if (nodes.isEmpty) {
      _stopSimulation();
      return;
    }
    // Layout lembrado já está assentado: só um reaquecimento curto.
    final startsFromMemory =
        isFirstLayout &&
        nodes.every(
          (node) => _controller.rememberedPositionOf(node.id) != null,
        );
    if (isFirstLayout && !startsFromMemory) {
      _startSimulation(_layoutTemperature);
    } else {
      _reheat();
    }
  }

  /// Posição de um nó que ainda não estava na tela: perto de um vizinho, se
  /// houver, para a conexão nova nascer encostada em quem já existe.
  Offset _freshPosition(
    NetworkNode node,
    int index,
    Map<String, Offset> previous,
  ) {
    for (final edge in _visibleEdges) {
      final neighborOffset = edge.source == node.id
          ? previous[edge.target]
          : edge.target == node.id
          ? previous[edge.source]
          : null;
      if (neighborOffset == null) {
        continue;
      }
      final angle = index * 2.399963229728653;
      return Offset(
        (neighborOffset.dx + 0.05 * math.cos(angle)).clamp(0.04, 0.96),
        (neighborOffset.dy + 0.05 * math.sin(angle)).clamp(0.04, 0.96),
      );
    }
    final angle = index * 2.399963229728653;
    return Offset(0.5 + 0.06 * math.cos(angle), 0.5 + 0.06 * math.sin(angle));
  }

  void _resetLayout() {
    _pinned.clear();
    _positions = [
      for (var index = 0; index < _visibleNodes.length; index++)
        Offset(
          0.5 + 0.18 * math.cos(index * 2.399963229728653),
          0.5 + 0.18 * math.sin(index * 2.399963229728653),
        ),
    ];
    _displacements = List<Offset>.filled(_positions.length, Offset.zero);
    _startSimulation(_layoutTemperature);
  }

  void _reheat() {
    if (_visibleNodes.isEmpty) {
      return;
    }
    _startSimulation(_reheatTemperature);
  }

  void _startSimulation(double temperature) {
    if (temperature > _temperature) {
      _temperature = temperature;
    }
    if (_temperature < _minTemperature) {
      _temperature = temperature;
    }
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _stopSimulation() {
    _temperature = 0;
    if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    _advanceSimulation();
    if (!mounted) {
      return;
    }
    setState(() {});
    if (_temperature <= _minTemperature) {
      _stopSimulation();
    }
  }

  /// Um quadro da simulação de forças em espaço normalizado (0 a 1).
  void _advanceSimulation() {
    final count = _visibleNodes.length;
    if (count == 0) {
      _stopSimulation();
      return;
    }

    final k = math.sqrt(1 / count);
    final restLength = k * _linkRestScale * _settings.linkDistance;
    final repulsion = _repulsionStrength * _settings.repulsion;
    final gravity = _gravityStrength * _settings.gravity;
    final displacements = _displacements;

    for (var index = 0; index < count; index++) {
      displacements[index] = Offset.zero;
    }

    for (var first = 0; first < count; first++) {
      for (var second = first + 1; second < count; second++) {
        var delta = _positions[first] - _positions[second];
        var distance = delta.distance;
        if (distance < 0.002) {
          delta = const Offset(0.002, 0.002);
          distance = delta.distance;
        }
        final direction = delta / distance;
        var magnitude = repulsion * k * k / distance;
        if (distance < k * _collisionScale) {
          magnitude += (k * _collisionScale - distance) * _collisionStrength;
        }
        final push = direction * magnitude;
        displacements[first] += push;
        displacements[second] -= push;
      }
    }

    for (final (source, target) in _springPairs) {
      var delta = _positions[target] - _positions[source];
      var distance = delta.distance;
      if (distance < 0.002) {
        delta = const Offset(0.002, 0.002);
        distance = delta.distance;
      }
      final push =
          delta / distance * ((distance - restLength) * _springStrength);
      displacements[source] += push;
      displacements[target] -= push;
    }

    for (var index = 0; index < count; index++) {
      if (_pinned.contains(_visibleNodes[index].id)) {
        continue;
      }
      final point = _positions[index];
      var step =
          displacements[index] + (const Offset(0.5, 0.5) - point) * gravity;

      // Parede suave: empurra de volta antes de o nó colar na borda.
      if (point.dx < _margin) {
        step += Offset((_margin - point.dx) * _marginStrength, 0);
      } else if (point.dx > 1 - _margin) {
        step -= Offset((point.dx - (1 - _margin)) * _marginStrength, 0);
      }
      if (point.dy < _margin) {
        step += Offset(0, (_margin - point.dy) * _marginStrength);
      } else if (point.dy > 1 - _margin) {
        step -= Offset(0, (point.dy - (1 - _margin)) * _marginStrength);
      }

      final length = step.distance;
      if (length > _temperature) {
        step = step / length * _temperature;
      }
      _positions[index] = Offset(
        (point.dx + step.dx).clamp(0.02, 0.98),
        (point.dy + step.dy).clamp(0.02, 0.98),
      );
    }

    _rememberPositions();
    _temperature *= _cooling;
  }

  /// Guarda o desenho atual no controller, para o grafo reabrir igual.
  void _rememberPositions() {
    for (var index = 0; index < _positions.length; index++) {
      _controller.rememberPosition(_visibleNodes[index].id, _positions[index]);
    }
  }

  // ---------------------------------------------------------------------------
  // Coordenadas e prévia
  // ---------------------------------------------------------------------------

  List<Offset> _pointsFor(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final worldWidth = math.max(1.0, size.width - 2 * _edgeInset);
    final worldHeight = math.max(1.0, size.height - 2 * _edgeInset);
    return [
      for (final position in _positions)
        center +
            Offset(
              (position.dx * worldWidth + _edgeInset - center.dx) * _scale,
              (position.dy * worldHeight + _edgeInset - center.dy) * _scale,
            ) +
            _pan,
    ];
  }

  Offset _normalizedFromScreen(Offset screen) {
    final center = Offset(_size.width / 2, _size.height / 2);
    final world = center + (screen - center - _pan) / _scale;
    final worldWidth = math.max(1.0, _size.width - 2 * _edgeInset);
    final worldHeight = math.max(1.0, _size.height - 2 * _edgeInset);
    return Offset(
      ((world.dx - _edgeInset) / worldWidth).clamp(0.02, 0.98),
      ((world.dy - _edgeInset) / worldHeight).clamp(0.02, 0.98),
    );
  }

  void _applyZoom(double factor, Offset focalPoint) {
    final nextScale = (_scale * factor).clamp(_minScale, _maxScale);
    if ((nextScale - _scale).abs() < 0.0001) {
      return;
    }
    final center = Offset(_size.width / 2, _size.height / 2);
    final world = center + (focalPoint - center - _pan) / _scale;
    _pan = focalPoint - center - (world - center) * nextScale;
    _scale = nextScale;
  }

  double _baseRadiusOf(NetworkNode node) {
    final count = _visibleNodes.length;
    final density = count > 140
        ? 0.6
        : count > 60
        ? 0.75
        : 1.0;
    return (9 + math.min(node.weight, 8) * 2) * density;
  }

  NetworkNode? _nodeById(String? id) {
    if (id == null) {
      return null;
    }
    for (final node in _visibleNodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  int _indexOf(String? id) {
    if (id == null) {
      return -1;
    }
    return _visibleNodes.indexWhere((node) => node.id == id);
  }

  NetworkNode? _nodeAt(Offset position) {
    if (_visibleNodes.isEmpty) {
      return null;
    }
    final points = _pointsFor(_size);
    NetworkNode? closest;
    var closestDistance = double.infinity;

    for (var index = 0; index < _visibleNodes.length; index++) {
      final distance = (points[index] - position).distance;
      final reach =
          _baseRadiusOf(_visibleNodes[index]) * _scale + AppSpacing.sm;
      if (distance <= reach && distance < closestDistance) {
        closest = _visibleNodes[index];
        closestDistance = distance;
      }
    }
    return closest;
  }

  bool _hasEdgeBetween(String first, String second) {
    for (final edge in _visibleEdges) {
      if ((edge.source == first && edge.target == second) ||
          (edge.target == first && edge.source == second)) {
        return true;
      }
    }
    return false;
  }

  /// Alvo válido do arrasto de conexão: um nó diferente da origem e que ainda
  /// não está conectado a ela.
  NetworkNode? _connectTargetAt(Offset position) {
    final source = _dragNodeId;
    final node = _nodeAt(position);
    if (source == null || node == null || node.id == source) {
      return null;
    }
    return _hasEdgeBetween(source, node.id) ? null : node;
  }

  /// Nó com a prévia aberta, se ainda existe no grafo.
  NetworkNode? get _previewNode {
    final node = _nodeById(_previewId);
    return node != null && _hasPreview(node) ? node : null;
  }

  Set<String> _relatedIds(String? id) {
    if (id == null) {
      return const {};
    }
    final related = {id};
    for (final edge in _visibleEdges) {
      if (edge.source == id) {
        related.add(edge.target);
      }
      if (edge.target == id) {
        related.add(edge.source);
      }
    }
    return related;
  }

  // ---------------------------------------------------------------------------
  // Gestos
  // ---------------------------------------------------------------------------

  void _handleTapDown(TapDownDetails details) {
    _movedDuringGesture = false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers == 1) {
      _pointerDownPosition = event.localPosition;
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) {
      _pointerDownPosition = null;
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_movedDuringGesture) {
      return;
    }
    final node = _nodeAt(details.localPosition);
    if (node != null) {
      widget.onNodeTap(node);
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _previewTimer?.cancel();
    final downPosition = _pointerDownPosition ?? details.localFocalPoint;
    final node = _nodeAt(downPosition);
    final canConnect = widget.onConnect != null && _controller.connectMode;
    setState(() {
      _hoveredId = null;
      _previewId = null;
      _gestureStartFocalPoint = details.localFocalPoint;
      _gestureStartPan = _pan;
      _lastGestureScale = 1;
      _movedDuringGesture = false;
      _connectTargetId = null;
      if (node != null) {
        _dragNodeId = node.id;
        _dragMode = canConnect ? _DragMode.connect : _DragMode.node;
        _dragPointer = details.localFocalPoint;
      } else {
        _dragNodeId = null;
        _dragMode = _DragMode.pan;
        _dragPointer = null;
      }
    });
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.focalPointDelta.distance > 0.5) {
      _movedDuringGesture = true;
    }
    setState(() {
      if (details.pointerCount > 1) {
        _dragNodeId = null;
        _dragMode = _DragMode.pan;
        _dragPointer = null;
        _connectTargetId = null;
        final ratio = _lastGestureScale == 0
            ? 1.0
            : details.scale / _lastGestureScale;
        _applyZoom(ratio, details.localFocalPoint);
        _lastGestureScale = details.scale;
        return;
      }
      switch (_dragMode) {
        case _DragMode.node:
          final index = _indexOf(_dragNodeId);
          if (index >= 0) {
            _positions[index] = _normalizedFromScreen(details.localFocalPoint);
            _pinned.add(_dragNodeId!);
          }
        case _DragMode.connect:
          _dragPointer = details.localFocalPoint;
          _connectTargetId = _connectTargetAt(details.localFocalPoint)?.id;
        case _DragMode.pan:
          _pan =
              _gestureStartPan +
              (details.localFocalPoint - _gestureStartFocalPoint);
        case _DragMode.none:
          break;
      }
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final mode = _dragMode;
    final source = _nodeById(_dragNodeId);
    final target = _nodeById(_connectTargetId);
    final moved = _movedDuringGesture;

    setState(() {
      _dragMode = _DragMode.none;
      _dragNodeId = null;
      _dragPointer = null;
      _connectTargetId = null;
      _lastGestureScale = 1;
    });

    if (mode == _DragMode.node && moved) {
      _reheat();
    }
    if (mode == _DragMode.connect &&
        source != null &&
        target != null &&
        widget.onConnect != null) {
      widget.onConnect!(source, target);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    setState(() {
      _applyZoom(math.exp(-event.scrollDelta.dy * 0.0012), event.localPosition);
    });
  }

  MouseCursor _cursorFor() {
    switch (_dragMode) {
      case _DragMode.node:
      case _DragMode.pan:
        return SystemMouseCursors.grabbing;
      case _DragMode.connect:
        return SystemMouseCursors.precise;
      case _DragMode.none:
        if (_hoveredId != null) {
          return SystemMouseCursors.click;
        }
        return SystemMouseCursors.grab;
    }
  }

  // ---------------------------------------------------------------------------
  // Desenho
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 600.0;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.fallbackHeight;
        final size = Size(width, height);
        _size = size;

        final points = _pointsFor(size);
        final radii = [
          for (final node in _visibleNodes) _baseRadiusOf(node) * _scale,
        ];
        final focusId = _hoveredId ?? widget.selectedId ?? _dragNodeId;
        final relatedIds = _relatedIds(focusId);
        final connectFromIndex = _dragMode == _DragMode.connect
            ? _indexOf(_dragNodeId)
            : -1;
        final previewNode = _previewNode;

        return Semantics(
          label: widget.semanticLabel,
          child: MouseRegion(
            cursor: _cursorFor(),
            onHover: (details) {
              if (_dragMode != _DragMode.none) {
                return;
              }
              _setHovered(_nodeAt(details.localPosition));
            },
            onExit: (_) => _setHovered(null),
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerUp: _handlePointerEnd,
              onPointerCancel: _handlePointerEnd,
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: size,
                        painter: _GraphPainter(
                          nodes: _visibleNodes,
                          edges: _visibleEdges,
                          points: points,
                          radii: radii,
                          focusedId: focusId,
                          relatedIds: relatedIds,
                          selectedId: widget.selectedId,
                          hoveredId: _hoveredId,
                          connectFrom: connectFromIndex >= 0
                              ? points[connectFromIndex]
                              : null,
                          connectTo: _dragPointer,
                          connectTargetId: _connectTargetId,
                          nodeColor: colorScheme.primaryContainer,
                          selectedColor: colorScheme.primary,
                          labelColor: colorScheme.onSurfaceVariant,
                          selectedLabelColor: colorScheme.onSurface,
                          edgeColor: semanticColors.brand,
                          dimmedAlpha: 0.32,
                          showLabels:
                              _visibleNodes.length <= 80 || _scale >= 1.2,
                        ),
                      ),
                    ),
                    if (previewNode != null)
                      _previewLayer(size, previewNode, points),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Camada da prévia: o mini-modal do chamador ou o resumo curto do nó.
  Widget _previewLayer(Size size, NetworkNode node, List<Offset> points) {
    final index = _indexOf(node.id);
    if (index < 0 || index >= points.length) {
      return const SizedBox.shrink();
    }

    final center = points[index];
    final radius = _baseRadiusOf(node) * _scale;
    final builder = widget.nodePreview;
    if (builder == null) {
      return _legacyTooltip(size, center, radius, node);
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomSingleChildLayout(
          delegate: _NodePreviewLayout(center: center, radius: radius),
          child: builder(context, node),
        ),
      ),
    );
  }

  /// Resumo curto do nó, acima dele quando há espaço e abaixo quando não há.
  Widget _legacyTooltip(
    Size size,
    Offset center,
    double radius,
    NetworkNode node,
  ) {
    final width = math.min(
      260.0,
      math.max(140.0, size.width - 2 * AppSpacing.sm),
    );
    final left = (center.dx - width / 2)
        .clamp(
          AppSpacing.sm,
          math.max(AppSpacing.sm, size.width - width - AppSpacing.sm),
        )
        .toDouble();
    final showsAbove = center.dy - radius > 72;
    final offset = radius + AppSpacing.sm;

    return Positioned(
      left: left,
      top: showsAbove ? null : center.dy + offset,
      bottom: showsAbove ? size.height - center.dy + offset : null,
      width: width,
      child: IgnorePointer(
        child: _NodeTooltip(title: node.label, message: node.tooltip!),
      ),
    );
  }

  String _signatureOf(List<NetworkNode> nodes, List<NetworkEdge> edges) {
    return '${nodes.map((node) => '${node.id}:${node.weight}').join(',')}'
        '|${edges.map((edge) => '${edge.source}>${edge.target}').join(',')}';
  }
}

/// Posiciona o mini-modal ao lado do nó, encostado nele.
///
/// Fica à direita e vira para a esquerda quando não cabe; na vertical fica
/// centrado no nó e nunca sai da área do grafo. Como a posição é calculada
/// depois de medir o painel ([getPositionForChild] recebe o tamanho do filho),
/// painel alto ou estreito não estoura a área.
class _NodePreviewLayout extends SingleChildLayoutDelegate {
  const _NodePreviewLayout({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final availableWidth = math.max(
      0.0,
      constraints.maxWidth - AppSpacing.md * 2,
    );
    final width = math.min(AppSpacing.hoverPreviewWidth, availableWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0.0, constraints.maxHeight - AppSpacing.md * 2),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final gap = radius + AppSpacing.sm;
    final fitsRight =
        center.dx + gap + childSize.width <= size.width - AppSpacing.sm;
    final left = fitsRight
        ? center.dx + gap
        : center.dx - gap - childSize.width;
    final maxLeft = math.max(
      AppSpacing.sm,
      size.width - childSize.width - AppSpacing.sm,
    );
    final maxTop = math.max(
      AppSpacing.sm,
      size.height - childSize.height - AppSpacing.sm,
    );
    return Offset(
      left.clamp(AppSpacing.sm, maxLeft),
      (center.dy - childSize.height / 2).clamp(AppSpacing.sm, maxTop),
    );
  }

  @override
  bool shouldRelayout(covariant _NodePreviewLayout oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

/// Resumo do nó: título em destaque e a informação logo abaixo.
class _NodeTooltip extends StatelessWidget {
  const _NodeTooltip({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.of(context).shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.surface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.surface.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.points,
    required this.radii,
    required this.focusedId,
    required this.relatedIds,
    required this.selectedId,
    required this.hoveredId,
    required this.connectFrom,
    required this.connectTo,
    required this.connectTargetId,
    required this.nodeColor,
    required this.selectedColor,
    required this.labelColor,
    required this.selectedLabelColor,
    required this.edgeColor,
    required this.dimmedAlpha,
    required this.showLabels,
  });

  final List<NetworkNode> nodes;
  final List<NetworkEdge> edges;
  final List<Offset> points;
  final List<double> radii;
  final String? focusedId;
  final Set<String> relatedIds;
  final String? selectedId;
  final String? hoveredId;
  final Offset? connectFrom;
  final Offset? connectTo;
  final String? connectTargetId;
  final Color nodeColor;
  final Color selectedColor;
  final Color labelColor;
  final Color selectedLabelColor;
  final Color edgeColor;
  final double dimmedAlpha;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || points.length != nodes.length) {
      return;
    }

    final indexOf = <String, int>{
      for (var index = 0; index < nodes.length; index++) nodes[index].id: index,
    };
    final hasFocus = focusedId != null;

    final edgePaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final dimmedEdgePaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    final highlightedEdgePaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.6;

    for (final edge in edges) {
      final source = indexOf[edge.source];
      final target = indexOf[edge.target];
      if (source == null || target == null) {
        continue;
      }
      final touchesFocus = edge.source == focusedId || edge.target == focusedId;
      final paint = touchesFocus
          ? highlightedEdgePaint
          : hasFocus
          ? dimmedEdgePaint
          : edgePaint;
      canvas.drawLine(points[source], points[target], paint);
    }

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final selected = node.id == selectedId;
      final hovered = node.id == hoveredId;
      final target = node.id == connectTargetId;
      final dimmed = hasFocus && !relatedIds.contains(node.id);
      final center = points[index];
      final radius = radii[index];

      if (target) {
        canvas.drawCircle(
          center,
          radius + 9,
          Paint()..color = selectedColor.withValues(alpha: 0.22),
        );
      }
      if (selected || hovered) {
        canvas.drawCircle(
          center,
          radius + 7,
          Paint()..color = selectedColor.withValues(alpha: 0.16),
        );
      }

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = (selected ? selectedColor : nodeColor).withValues(
            alpha: dimmed ? dimmedAlpha : 1,
          ),
      );

      final showsLabel =
          showLabels ||
          node.id == hoveredId ||
          node.id == selectedId ||
          node.id == connectTargetId;
      if (showsLabel) {
        _paintLabel(
          canvas,
          node,
          center,
          radius,
          (selected || hovered) && !dimmed ? selectedLabelColor : labelColor,
          (selected || hovered) && !dimmed,
          dimmed ? dimmedAlpha : 1,
        );
      }
    }

    _paintConnection(canvas);
  }

  void _paintConnection(Canvas canvas) {
    final from = connectFrom;
    final to = connectTo;
    if (from == null || to == null) {
      return;
    }
    final paint = Paint()
      ..color = selectedColor.withValues(alpha: 0.75)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    _drawDashedLine(canvas, from, to, paint);
    canvas.drawCircle(to, 5, Paint()..color = selectedColor);
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
    final delta = to - from;
    final distance = delta.distance;
    if (distance == 0) {
      return;
    }
    final direction = delta / distance;
    var drawn = 0.0;
    while (drawn < distance) {
      final end = math.min(drawn + dash, distance);
      canvas.drawLine(from + direction * drawn, from + direction * end, paint);
      drawn = end + gap;
    }
  }

  void _paintLabel(
    Canvas canvas,
    NetworkNode node,
    Offset center,
    double radius,
    Color color,
    bool highlighted,
    double alpha,
  ) {
    final fontSize = (11 * math.max(0.9, radius / 11))
        .clamp(9.0, 18.0)
        .toDouble();
    final painter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          color: color.withValues(alpha: alpha),
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 110);

    final offset = Offset(
      center.dx - painter.width / 2,
      center.dy + radius + 4,
    );
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.hoveredId != hoveredId ||
        oldDelegate.focusedId != focusedId ||
        oldDelegate.connectTargetId != connectTargetId ||
        oldDelegate.connectTo != connectTo ||
        oldDelegate.connectFrom != connectFrom ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.points != points ||
        oldDelegate.nodes.length != nodes.length;
  }
}
