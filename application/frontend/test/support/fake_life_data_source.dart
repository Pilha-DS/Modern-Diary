import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/life/data/life_repository.dart';
import 'package:modern_diary/src/features/life/domain/life_models.dart';

/// Fonte do grafo de vida sem HTTP, com os pedidos guardados para conferência.
class FakeLifeDataSource implements LifeDataSource {
  FakeLifeDataSource({this.nodes = const [], this.edges = const []});

  List<LifeGraphNode> nodes;
  List<LifeGraphEdge> edges;
  ApiException? error;
  ApiException? linkError;

  final List<List<LifeEntityType>> typeRequests = [];
  int linkCalls = 0;
  int unlinkCalls = 0;
  LifeGraphNode? lastSource;
  LifeGraphNode? lastTarget;

  @override
  Future<LifeGraphData> fetchGraph({
    List<LifeEntityType> types = const [],
  }) async {
    typeRequests.add(types);
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return LifeGraphData(
      nodes: [
        for (final node in nodes)
          if (types.isEmpty || types.contains(node.type)) node,
      ],
      edges: edges,
    );
  }

  @override
  Future<void> link(LifeGraphNode source, LifeGraphNode target) async {
    linkCalls++;
    lastSource = source;
    lastTarget = target;
    final failure = linkError;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> unlink(LifeGraphNode source, LifeGraphNode target) async {
    unlinkCalls++;
    lastSource = source;
    lastTarget = target;
    final failure = linkError;
    if (failure != null) {
      throw failure;
    }
    edges = [
      for (final edge in edges)
        if (!((edge.source == source.id && edge.target == target.id) ||
            (edge.source == target.id && edge.target == source.id)))
          edge,
    ];
  }
}

LifeGraphNode lifeNode({
  required String id,
  required LifeEntityType type,
  String? title,
  int degree = 0,
}) {
  return LifeGraphNode(
    id: id,
    type: type,
    ref: id.split(':').last,
    title: title,
    degree: degree,
  );
}
