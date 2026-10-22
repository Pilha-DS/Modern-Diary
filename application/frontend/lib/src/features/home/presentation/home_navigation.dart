import 'package:flutter/widgets.dart';

import '../../tags/domain/tag_models.dart';

/// Áreas da home. Quem troca de área é a `HomeScreen`.
enum HomeSection {
  dashboard,
  calendar,
  notes,
  goals,
  knowledge,
  lifeGraph,
  tags,
  aboutMe,
  secrets,
  users,
}

/// Atalho da seleção rápida de telas do dashboard.
class HomeQuickLink {
  const HomeQuickLink({
    required this.section,
    required this.icon,
    required this.label,
  });

  final HomeSection section;
  final IconData icon;
  final String label;
}

/// Pedido de navegação entre as áreas da home.
///
/// A área de origem só dispara o pedido; quem troca de aba e abre o item é a
/// `HomeScreen`. Assim nenhuma área conhece a navegação das outras.
class HomeNavigation {
  const HomeNavigation({
    required this.openTag,
    required this.openGoal,
    required this.openKnowledgeItem,
    required this.openNote,
    required this.openDay,
    required this.openSection,
  });

  /// Abre a tag no menu de tags, com a lista de onde ela é usada.
  final void Function(Tag tag) openTag;

  /// Abre a meta na tela de metas, mostrando os detalhes dela.
  final void Function(int goalId) openGoal;

  /// Abre o conhecimento na tela de conhecimentos.
  final void Function(int itemId) openKnowledgeItem;

  /// Abre a nota na tela de notas.
  final void Function(int noteId) openNote;

  /// Abre o dia no calendário.
  final void Function(DateTime day) openDay;

  /// Troca a área da home, como pede a seleção rápida de telas.
  final void Function(HomeSection section) openSection;
}
