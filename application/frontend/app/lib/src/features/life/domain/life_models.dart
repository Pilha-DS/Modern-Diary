/// Entidade que pode virar nó do grafo de vida.
enum LifeEntityType {
  knowledge('knowledge'),
  goal('goal'),
  note('note'),
  activity('activity'),
  day('day');

  const LifeEntityType(this.apiValue);

  final String apiValue;

  static LifeEntityType? fromApi(String value) {
    for (final type in values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return null;
  }
}

class LifeGraphNode {
  const LifeGraphNode({
    required this.id,
    required this.type,
    required this.ref,
    required this.degree,
    this.title,
    this.day,
  });

  final String id;
  final LifeEntityType type;
  final String ref;
  final int degree;
  final String? title;
  final DateTime? day;

  int? get numericRef => int.tryParse(ref);

  static LifeGraphNode? fromJson(Map<String, dynamic> json) {
    final type = LifeEntityType.fromApi(json['type'] as String? ?? '');
    final id = json['id'] as String?;
    if (type == null || id == null) {
      return null;
    }
    final rawDay = json['day'] as String?;
    return LifeGraphNode(
      id: id,
      type: type,
      ref: json['ref'] as String? ?? '',
      degree: (json['degree'] as num?)?.toInt() ?? 0,
      title: json['title'] as String?,
      day: rawDay == null ? null : DateTime.tryParse(rawDay),
    );
  }
}

class LifeGraphEdge {
  const LifeGraphEdge({
    required this.source,
    required this.target,
    required this.kind,
    this.linkId,
  });

  final String source;
  final String target;

  /// `relation`, `goal`, `agenda` ou `custom`.
  final String kind;

  /// Preenchido só nas ligações feitas à mão, que podem ser desfeitas.
  final int? linkId;

  bool get isCustom => linkId != null;

  static LifeGraphEdge? fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    final target = json['target'] as String?;
    if (source == null || target == null) {
      return null;
    }
    return LifeGraphEdge(
      source: source,
      target: target,
      kind: json['kind'] as String? ?? 'custom',
      linkId: (json['link_id'] as num?)?.toInt(),
    );
  }
}

class LifeGraphData {
  const LifeGraphData({
    this.nodes = const [],
    this.edges = const [],
    this.truncated = false,
  });

  final List<LifeGraphNode> nodes;
  final List<LifeGraphEdge> edges;
  final bool truncated;

  bool get isEmpty => nodes.isEmpty;

  LifeGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  /// Ligações da entidade, com quem está do outro lado de cada uma.
  List<LifeConnection> connectionsOf(String id) {
    final connections = <LifeConnection>[];
    for (final edge in edges) {
      if (edge.source != id && edge.target != id) {
        continue;
      }
      final other = nodeById(edge.source == id ? edge.target : edge.source);
      if (other != null) {
        connections.add(LifeConnection(node: other, edge: edge));
      }
    }
    return connections;
  }
}

class LifeConnection {
  const LifeConnection({required this.node, required this.edge});

  final LifeGraphNode node;
  final LifeGraphEdge edge;
}
