import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/knowledge_models.dart';
import 'knowledge_node_preview.dart';

/// Converte a rede da API nos nós e arestas genéricos do package.
///
/// Cada nó abre um mini-modal ao lado dele no hover, com o nível, as tags e as
/// conexões do conhecimento; o resumo curto do `tooltip` fica como apoio de
/// leitor de tela.
class KnowledgeGraphView extends StatelessWidget {
  const KnowledgeGraphView({
    super.key,
    required this.graph,
    required this.onNodeTap,
  });

  final KnowledgeGraphData graph;
  final ValueChanged<KnowledgeNodeData> onNodeTap;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final node in graph.nodes) node.id: node};

    return NetworkGraph(
      semanticLabel: AppStrings.knowledgeGraphSemantics,
      nodes: [
        for (final node in graph.nodes)
          NetworkNode(
            id: '${node.id}',
            label: node.title,
            weight: node.degree,
            tooltip: AppStrings.knowledgeGraphNodeTooltip(
              connections: node.degree,
              sensitivity: AppStrings.sensitivityLabelOf(
                node.sensitivity.apiValue,
              ),
              tags: [for (final tag in node.tags) tag.name],
            ),
          ),
      ],
      edges: [
        for (final edge in graph.edges)
          NetworkEdge(source: '${edge.source}', target: '${edge.target}'),
      ],
      onNodeTap: (node) {
        final data = byId[int.tryParse(node.id)];
        if (data != null) {
          onNodeTap(data);
        }
      },
      nodePreview: (context, node) {
        final data = byId[int.tryParse(node.id)];
        return data == null
            ? const SizedBox.shrink()
            : KnowledgeNodePreview(node: data);
      },
    );
  }
}
