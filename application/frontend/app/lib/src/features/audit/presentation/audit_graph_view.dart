import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/audit_models.dart';
import 'audit_node_preview.dart';

/// Grafo do dia: cada ação liga ao nó do dia os registros que ela tocou.
///
/// Reaproveita o [NetworkGraph] do package: arrastar move e fixa o nó, o fundo
/// desloca a rede e a roda do mouse dá zoom. A tela cheia usa o mesmo
/// controller, então ajustes e desenho continuam iguais ao voltar.
class AuditGraphView extends StatefulWidget {
  const AuditGraphView({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.controller,
    this.fullscreen = false,
  });

  final AuditGraphData graph;
  final ValueChanged<AuditGraphNode> onNodeTap;
  final NetworkGraphController? controller;
  final bool fullscreen;

  @override
  State<AuditGraphView> createState() => _AuditGraphViewState();
}

class _AuditGraphViewState extends State<AuditGraphView> {
  late NetworkGraphController _controller;
  late bool _ownsController;
  bool _graphHidden = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? NetworkGraphController();
    _ownsController = widget.controller == null;
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _openFullscreen() {
    setState(() => _graphHidden = true);
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (context) => _AuditFullscreenPage(
              graph: widget.graph,
              onNodeTap: widget.onNodeTap,
              controller: _controller,
            ),
          ),
        )
        .whenComplete(() {
          if (mounted) {
            setState(() => _graphHidden = false);
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final node in widget.graph.nodes) node.id: node};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: AppStrings.knowledgeGraphReorganize,
              onPressed: _controller.reorganize,
              icon: const Icon(Icons.auto_awesome_motion_outlined),
            ),
            IconButton(
              tooltip: AppStrings.knowledgeGraphCenter,
              onPressed: _controller.resetView,
              icon: const Icon(Icons.center_focus_strong_outlined),
            ),
            IconButton(
              tooltip: AppStrings.knowledgeGraphZoomIn,
              onPressed: _controller.zoomIn,
              icon: const Icon(Icons.zoom_in_rounded),
            ),
            IconButton(
              tooltip: AppStrings.knowledgeGraphZoomOut,
              onPressed: _controller.zoomOut,
              icon: const Icon(Icons.zoom_out_rounded),
            ),
            IconButton(
              tooltip: widget.fullscreen
                  ? AppStrings.knowledgeGraphFullscreenExit
                  : AppStrings.knowledgeGraphFullscreen,
              onPressed: widget.fullscreen
                  ? () => Navigator.of(context).maybePop()
                  : _openFullscreen,
              icon: Icon(
                widget.fullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: _graphHidden
              ? const SizedBox.shrink()
              : AppSurface(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  borderRadius: AppSpacing.radiusMd,
                  child: NetworkGraph(
                    controller: _controller,
                    semanticLabel: AppStrings.auditGraphSemantics,
                    nodes: [
                      for (final node in widget.graph.nodes)
                        NetworkNode(
                          id: node.id,
                          label: auditNodeLabel(node),
                          weight: node.degree,
                        ),
                    ],
                    edges: [
                      for (final edge in widget.graph.edges)
                        NetworkEdge(source: edge.source, target: edge.target),
                    ],
                    onNodeTap: (node) {
                      final data = byId[node.id];
                      if (data != null) {
                        widget.onNodeTap(data);
                      }
                    },
                    nodePreview: (context, node) {
                      final data = byId[node.id];
                      return data == null
                          ? const SizedBox.shrink()
                          : AuditNodePreview(node: data);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

/// A mesma rede ocupando a tela, com o controller da versão encaixada.
class _AuditFullscreenPage extends StatelessWidget {
  const _AuditFullscreenPage({
    required this.graph,
    required this.onNodeTap,
    required this.controller,
  });

  final AuditGraphData graph;
  final ValueChanged<AuditGraphNode> onNodeTap;
  final NetworkGraphController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AuditGraphView(
            graph: graph,
            onNodeTap: onNodeTap,
            controller: controller,
            fullscreen: true,
          ),
        ),
      ),
    );
  }
}
