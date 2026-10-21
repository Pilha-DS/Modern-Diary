import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_durations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Nó do grafo. O `weight` aumenta o tamanho da bolinha; `tooltip` é o resumo
/// curto usado quando não há [NetworkGraph.nodePreview].
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

/// Rede de nós e conexões com layout de forças, sem dependência externa.
///
/// O componente não conhece a aplicação: recebe nós e arestas prontos e
/// devolve o nó tocado por callback. Ao ficar [tooltipWait] sobre um nó, abre
/// um mini-modal ao lado dele, montado por [nodePreview]; sem preview, o
/// resumo curto do `tooltip` aparece no lugar.
///
/// Uso com mini-modal:
///
/// ```dart
/// NetworkGraph(
///   nodes: const [NetworkNode(id: '1', label: 'SQL', weight: 3)],
///   edges: const [],
///   onNodeTap: (node) => openDetail(node.id),
///   nodePreview: (context, node) => NodePreview(node: node),
/// )
/// ```
class NetworkGraph extends StatefulWidget {
  const NetworkGraph({
    super.key,
    required this.nodes,
    required this.edges,
    required this.onNodeTap,
    this.selectedId,
    this.semanticLabel,
    this.fallbackHeight = 520,
    this.tooltipWait = AppDurations.hoverTooltip,
    this.nodePreview,
  });

  final List<NetworkNode> nodes;
  final List<NetworkEdge> edges;
  final ValueChanged<NetworkNode> onNodeTap;
  final String? selectedId;
  final String? semanticLabel;
  final double fallbackHeight;

  /// Tempo de hover sobre o nó para o resumo aparecer.
  final Duration tooltipWait;

  /// Mini-modal exibido ao lado do nó depois de [tooltipWait]. Tem prioridade
  /// sobre o `tooltip` do nó.
  final Widget Function(BuildContext context, NetworkNode node)? nodePreview;

  @override
  State<NetworkGraph> createState() => _NetworkGraphState();
}

class _NetworkGraphState extends State<NetworkGraph> {
  static const int _maxLayoutNodes = 200;
  static const int _iterations = 140;

  late List<Offset> _positions;
  late List<NetworkNode> _visibleNodes;
  late List<NetworkEdge> _visibleEdges;
  String? _layoutSignature;
  String? _hoveredId;

  /// Nó com a prévia aberta depois do tempo de espera.
  String? _previewId;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _visibleNodes = const [];
    _visibleEdges = const [];
    _positions = const [];
    _ensureLayout();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NetworkGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureLayout();
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

  void _ensureLayout() {
    final signature = _signatureOf(widget.nodes, widget.edges);
    if (signature == _layoutSignature) {
      return;
    }
    _layoutSignature = signature;

    final nodes = widget.nodes.take(_maxLayoutNodes).toList(growable: false);
    final ids = {for (final node in nodes) node.id};
    _visibleNodes = nodes;
    _visibleEdges = [
      for (final edge in widget.edges)
        if (ids.contains(edge.source) && ids.contains(edge.target)) edge,
    ];
    _positions = _simulate(_visibleNodes, _visibleEdges);
  }

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
        final radii = _radiiFor(size);

        return Semantics(
          label: widget.semanticLabel,
          child: MouseRegion(
            cursor: _hoveredId == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onHover: (details) {
              _setHovered(_nodeAt(details.localPosition, size, radii));
            },
            onExit: (_) => _setHovered(null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final node = _nodeAt(details.localPosition, size, radii);
                if (node != null) {
                  widget.onNodeTap(node);
                }
              },
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: _GraphPainter(
                        nodes: _visibleNodes,
                        edges: _visibleEdges,
                        positions: _positions,
                        radii: radii,
                        selectedId: widget.selectedId,
                        hoveredId: _hoveredId,
                        nodeColor: colorScheme.primaryContainer,
                        selectedColor: colorScheme.primary,
                        labelColor: colorScheme.onSurfaceVariant,
                        selectedLabelColor: colorScheme.onSurface,
                        edgeColor: semanticColors.brand,
                      ),
                    ),
                  ),
                  if (_previewNode != null)
                    _previewLayer(size, radii, _previewNode!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<double> _radiiFor(Size size) {
    final count = _visibleNodes.length;
    final scale = count > 60 ? 0.75 : 1.0;
    return [
      for (final node in _visibleNodes)
        (9 + math.min(node.weight, 8) * 2) * scale,
    ];
  }

  /// Nó com a prévia aberta, se ainda existe no grafo.
  NetworkNode? get _previewNode {
    final id = _previewId;
    if (id == null) {
      return null;
    }
    for (final node in _visibleNodes) {
      if (node.id == id && _hasPreview(node)) {
        return node;
      }
    }
    return null;
  }

  /// Camada da prévia: o mini-modal do chamador ou o resumo curto do nó.
  Widget _previewLayer(Size size, List<double> radii, NetworkNode node) {
    final index = _visibleNodes.indexWhere(
      (candidate) => candidate.id == node.id,
    );
    if (index < 0 || index >= _positions.length) {
      return const SizedBox.shrink();
    }

    final center = _pointsFor(size)[index];
    final radius = radii[index];
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

  NetworkNode? _nodeAt(Offset position, Size size, List<double> radii) {
    if (_visibleNodes.isEmpty) {
      return null;
    }
    final points = _pointsFor(size);
    NetworkNode? closest;
    var closestDistance = double.infinity;

    for (var index = 0; index < _visibleNodes.length; index++) {
      final distance = (points[index] - position).distance;
      final reach = radii[index] + AppSpacing.sm;
      if (distance <= reach && distance < closestDistance) {
        closest = _visibleNodes[index];
        closestDistance = distance;
      }
    }
    return closest;
  }

  List<Offset> _pointsFor(Size size) {
    return [
      for (final position in _positions)
        Offset(
          position.dx * (size.width - 48) + 24,
          position.dy * (size.height - 48) + 24,
        ),
    ];
  }

  String _signatureOf(List<NetworkNode> nodes, List<NetworkEdge> edges) {
    return '${nodes.map((node) => '${node.id}:${node.weight}').join(',')}'
        '|${edges.map((edge) => '${edge.source}>${edge.target}').join(',')}';
  }

  /// Simulação simples de forças em espaço normalizado (0 a 1).
  List<Offset> _simulate(List<NetworkNode> nodes, List<NetworkEdge> edges) {
    final count = math.min(nodes.length, _maxLayoutNodes);
    if (count == 0) {
      return const [];
    }

    final indexOf = <String, int>{
      for (var index = 0; index < count; index++) nodes[index].id: index,
    };
    final points = List<Offset>.generate(count, (index) {
      final angle = index * 2.399963229728653;
      final radius = 0.18 + 0.22 * ((index % 7) / 6);
      return Offset(
        0.5 + radius * math.cos(angle),
        0.5 + radius * math.sin(angle),
      );
    });

    final pairs = <(int, int)>[
      for (final edge in edges)
        if (indexOf.containsKey(edge.source) &&
            indexOf.containsKey(edge.target) &&
            edge.source != edge.target)
          (indexOf[edge.source]!, indexOf[edge.target]!),
    ];

    final area = 1.0;
    final k = math.sqrt(area / count);
    var temperature = 0.12;

    for (var iteration = 0; iteration < _iterations; iteration++) {
      final displacement = List<Offset>.filled(count, Offset.zero);

      for (var first = 0; first < count; first++) {
        for (var second = first + 1; second < count; second++) {
          var delta = points[first] - points[second];
          var distance = delta.distance;
          if (distance < 0.0001) {
            delta = Offset(0.001, 0.001);
            distance = 0.0014;
          }
          final force = (k * k) / distance;
          final direction = delta / distance;
          displacement[first] += direction * force;
          displacement[second] -= direction * force;
        }
      }

      for (final (source, target) in pairs) {
        var delta = points[target] - points[source];
        var distance = delta.distance;
        if (distance < 0.0001) {
          delta = Offset(0.001, 0.001);
          distance = 0.0014;
        }
        final force = (distance * distance) / k;
        final direction = delta / distance;
        displacement[source] += direction * force;
        displacement[target] -= direction * force;
      }

      for (var index = 0; index < count; index++) {
        final center = const Offset(0.5, 0.5) - points[index];
        final step = Offset(
          displacement[index].dx * 0.6 + center.dx * 0.02,
          displacement[index].dy * 0.6 + center.dy * 0.02,
        );
        final length = step.distance;
        final limited = length > temperature
            ? step / length * temperature
            : step;
        points[index] = Offset(
          (points[index].dx + limited.dx).clamp(0.03, 0.97),
          (points[index].dy + limited.dy).clamp(0.03, 0.97),
        );
      }

      temperature = math.max(0.01, temperature * 0.96);
    }

    return points;
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
    required this.positions,
    required this.radii,
    required this.selectedId,
    required this.hoveredId,
    required this.nodeColor,
    required this.selectedColor,
    required this.labelColor,
    required this.selectedLabelColor,
    required this.edgeColor,
  });

  final List<NetworkNode> nodes;
  final List<NetworkEdge> edges;
  final List<Offset> positions;
  final List<double> radii;
  final String? selectedId;
  final String? hoveredId;
  final Color nodeColor;
  final Color selectedColor;
  final Color labelColor;
  final Color selectedLabelColor;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || positions.length != nodes.length) {
      return;
    }

    final points = [
      for (final position in positions)
        Offset(
          position.dx * (size.width - 48) + 24,
          position.dy * (size.height - 48) + 24,
        ),
    ];
    final indexOf = <String, int>{
      for (var index = 0; index < nodes.length; index++) nodes[index].id: index,
    };

    final edgePaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.18)
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
      final highlighted =
          edge.source == selectedId ||
          edge.target == selectedId ||
          edge.source == hoveredId ||
          edge.target == hoveredId;
      canvas.drawLine(
        points[source],
        points[target],
        highlighted ? highlightedEdgePaint : edgePaint,
      );
    }

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final selected = node.id == selectedId;
      final hovered = node.id == hoveredId;
      final center = points[index];
      final radius = radii[index];

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
        Paint()..color = selected ? selectedColor : nodeColor,
      );

      _paintLabel(
        canvas,
        node,
        center,
        radius,
        selected || hovered ? selectedLabelColor : labelColor,
        selected || hovered,
      );
    }
  }

  void _paintLabel(
    Canvas canvas,
    NetworkNode node,
    Offset center,
    double radius,
    Color color,
    bool highlighted,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
          color: color,
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
        oldDelegate.positions != positions ||
        oldDelegate.nodes.length != nodes.length;
  }
}
