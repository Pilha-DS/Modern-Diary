import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/life_models.dart';
import 'life_node_preview.dart';

/// Desenho do grafo de vida sobre o [NetworkGraph] do package.
///
/// Os nós podem ser arrastados, o fundo desloca a rede e a roda do mouse dá
/// zoom. No modo conexão, arrastar um nó sobre outro pede a ligação dos dois
/// registros. A tela cheia usa o mesmo controller: ajustes e posições ficam.
class LifeGraphView extends StatefulWidget {
  const LifeGraphView({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.onConnect,
    this.controller,
    this.fullscreen = false,
  });

  final LifeGraphData graph;
  final ValueChanged<LifeGraphNode> onNodeTap;
  final void Function(LifeGraphNode source, LifeGraphNode target)? onConnect;
  final NetworkGraphController? controller;
  final bool fullscreen;

  @override
  State<LifeGraphView> createState() => _LifeGraphViewState();
}

class _LifeGraphViewState extends State<LifeGraphView> {
  late NetworkGraphController _controller;
  late bool _ownsController;
  bool _showsSettings = false;
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

  /// Abre a rede em tela cheia; a versão encaixada sai da árvore para o
  /// desenho vir do controller e não ficar diferente ao voltar.
  void _openFullscreen() {
    setState(() => _graphHidden = true);
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (context) => _LifeFullscreenPage(
              graph: widget.graph,
              onNodeTap: widget.onNodeTap,
              onConnect: widget.onConnect,
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
    final connections = {
      for (final node in widget.graph.nodes)
        node.id: widget.graph.connectionsOf(node.id).length,
    };

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          if (_controller.connectMode) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.liveGraphConnectHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _graphHidden
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Positioned.fill(
                          child: AppSurface(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            borderRadius: AppSpacing.radiusMd,
                            child: NetworkGraph(
                              controller: _controller,
                              semanticLabel: AppStrings.liveGraphSemantics,
                              nodes: [
                                for (final node in widget.graph.nodes)
                                  NetworkNode(
                                    id: node.id,
                                    label: lifeNodeLabel(node),
                                    weight: node.degree,
                                  ),
                              ],
                              edges: [
                                for (final edge in widget.graph.edges)
                                  NetworkEdge(
                                    source: edge.source,
                                    target: edge.target,
                                  ),
                              ],
                              onNodeTap: (node) {
                                final data = byId[node.id];
                                if (data != null) {
                                  widget.onNodeTap(data);
                                }
                              },
                              onConnect: widget.onConnect == null
                                  ? null
                                  : (source, target) {
                                      final sourceData = byId[source.id];
                                      final targetData = byId[target.id];
                                      if (sourceData != null &&
                                          targetData != null) {
                                        widget.onConnect!(
                                          sourceData,
                                          targetData,
                                        );
                                      }
                                    },
                              nodePreview: (context, node) {
                                final data = byId[node.id];
                                return data == null
                                    ? const SizedBox.shrink()
                                    : LifeNodePreview(
                                        node: data,
                                        connections: connections[node.id] ?? 0,
                                      );
                              },
                            ),
                          ),
                        ),
                        if (_showsSettings)
                          Positioned(
                            top: AppSpacing.sm,
                            right: AppSpacing.sm,
                            child: NetworkGraphSettingsPanel(
                              controller: _controller,
                              labels: const NetworkGraphSettingsLabels(
                                repulsion: AppStrings.liveGraphRepulsion,
                                linkDistance: AppStrings.liveGraphLinkDistance,
                                gravity: AppStrings.liveGraphGravity,
                                dragHint: AppStrings.liveGraphDragHint,
                              ),
                              maxWidth:
                                  (constraints.maxWidth - 2 * AppSpacing.md)
                                      .clamp(180.0, 320.0)
                                      .toDouble(),
                              maxHeight: constraints.maxHeight,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final canConnect = widget.onConnect != null;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          label: _controller.connectMode
              ? AppStrings.liveGraphConnectOn
              : AppStrings.liveGraphConnect,
          icon: Icons.hub_outlined,
          variant: _controller.connectMode
              ? AppButtonVariant.primary
              : AppButtonVariant.secondary,
          onPressed: canConnect ? _controller.toggleConnectMode : null,
        ),
        AppButton(
          label: _showsSettings
              ? AppStrings.liveGraphSettingsHide
              : AppStrings.liveGraphSettings,
          icon: Icons.tune_rounded,
          variant: _showsSettings
              ? AppButtonVariant.primary
              : AppButtonVariant.secondary,
          onPressed: () => setState(() => _showsSettings = !_showsSettings),
        ),
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
    );
  }
}

/// A mesma rede ocupando a tela, com o controller da versão encaixada.
class _LifeFullscreenPage extends StatelessWidget {
  const _LifeFullscreenPage({
    required this.graph,
    required this.onNodeTap,
    required this.onConnect,
    required this.controller,
  });

  final LifeGraphData graph;
  final ValueChanged<LifeGraphNode> onNodeTap;
  final void Function(LifeGraphNode source, LifeGraphNode target)? onConnect;
  final NetworkGraphController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LifeGraphView(
            graph: graph,
            onNodeTap: onNodeTap,
            onConnect: onConnect,
            controller: controller,
            fullscreen: true,
          ),
        ),
      ),
    );
  }
}
