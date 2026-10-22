import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/knowledge_models.dart';
import 'knowledge_node_preview.dart';

/// Converte a rede da API nos nós e arestas genéricos do package.
///
/// O grafo é interativo: os nós podem ser arrastados (e ficam fixos onde o
/// usuário soltou), a roda do mouse dá zoom, o fundo desloca a rede e o modo
/// de conexão transforma o arrasto de um nó sobre outro em uma conexão nova.
/// Os ajustes de força (repulsão, distância e gravidade) ficam no painel
/// "Ajustes da rede", acima do desenho.
class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    super.key,
    required this.graph,
    required this.onNodeTap,
    this.onConnect,
    this.controller,
    this.fullscreen = false,
  });

  final KnowledgeGraphData graph;
  final ValueChanged<KnowledgeNodeData> onNodeTap;

  /// Cria a conexão arrastando um nó sobre outro no modo de conexão.
  final void Function(KnowledgeNodeData source, KnowledgeNodeData target)?
  onConnect;

  /// Controller compartilhado com a tela cheia: mantém os ajustes de força e
  /// o desenho da rede entre as duas apresentações.
  final NetworkGraphController? controller;

  /// Versão em tela cheia: o botão passa a fechar a apresentação.
  final bool fullscreen;

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
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

  /// Abre a rede ocupando a tela. A versão encaixada é desmontada para o
  /// desenho vir do controller e não ficar diferente ao voltar.
  void _openFullscreen() {
    setState(() => _graphHidden = true);
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (context) => _GraphFullscreenPage(
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

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(context),
          if (_controller.connectMode) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.knowledgeGraphConnectHint,
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
                              semanticLabel: AppStrings.knowledgeGraphSemantics,
                              nodes: [
                                for (final node in widget.graph.nodes)
                                  NetworkNode(
                                    id: '${node.id}',
                                    label: node.title,
                                    weight: node.degree,
                                    tooltip:
                                        AppStrings.knowledgeGraphNodeTooltip(
                                          connections: node.degree,
                                          sensitivity:
                                              AppStrings.sensitivityLabelOf(
                                                node.sensitivity.apiValue,
                                              ),
                                          tags: [
                                            for (final tag in node.tags)
                                              tag.name,
                                          ],
                                        ),
                                  ),
                              ],
                              edges: [
                                for (final edge in widget.graph.edges)
                                  NetworkEdge(
                                    source: '${edge.source}',
                                    target: '${edge.target}',
                                  ),
                              ],
                              onNodeTap: (node) {
                                final data = byId[int.tryParse(node.id)];
                                if (data != null) {
                                  widget.onNodeTap(data);
                                }
                              },
                              onConnect: widget.onConnect == null
                                  ? null
                                  : (source, target) {
                                      final sourceData =
                                          byId[int.tryParse(source.id)];
                                      final targetData =
                                          byId[int.tryParse(target.id)];
                                      if (sourceData != null &&
                                          targetData != null) {
                                        widget.onConnect!(
                                          sourceData,
                                          targetData,
                                        );
                                      }
                                    },
                              nodePreview: (context, node) {
                                final data = byId[int.tryParse(node.id)];
                                return data == null
                                    ? const SizedBox.shrink()
                                    : KnowledgeNodePreview(node: data);
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
                                repulsion: AppStrings.knowledgeGraphRepulsion,
                                linkDistance:
                                    AppStrings.knowledgeGraphLinkDistance,
                                gravity: AppStrings.knowledgeGraphGravity,
                                dragHint: AppStrings.knowledgeGraphDragHint,
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
              ? AppStrings.knowledgeGraphConnectOn
              : AppStrings.knowledgeGraphConnect,
          icon: Icons.hub_outlined,
          variant: _controller.connectMode
              ? AppButtonVariant.primary
              : AppButtonVariant.secondary,
          onPressed: canConnect ? _controller.toggleConnectMode : null,
        ),
        AppButton(
          label: _showsSettings
              ? AppStrings.knowledgeGraphSettingsHide
              : AppStrings.knowledgeGraphSettings,
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

/// A mesma rede ocupando a tela, com o controller da versão encaixada para
/// manter ajustes e posições.
class _GraphFullscreenPage extends StatelessWidget {
  const _GraphFullscreenPage({
    required this.graph,
    required this.onNodeTap,
    required this.onConnect,
    required this.controller,
  });

  final KnowledgeGraphData graph;
  final ValueChanged<KnowledgeNodeData> onNodeTap;
  final void Function(KnowledgeNodeData source, KnowledgeNodeData target)?
  onConnect;
  final NetworkGraphController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: KnowledgeGraphView(
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
