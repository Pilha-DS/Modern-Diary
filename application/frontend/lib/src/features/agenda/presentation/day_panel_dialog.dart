import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import 'agenda_controller.dart';
import 'day_panel.dart';

/// Abre o dia em modal, sem trocar de tela: a nota, as tags e as atividades
/// daquele dia ficam editáveis por cima do que já estava aberto.
///
/// O dia é selecionado no controller antes do modal aparecer; enquanto carrega,
/// o próprio [DayPanel] mostra o estado de carregamento.
Future<void> showDayPanelDialog(
  BuildContext context, {
  required AgendaController controller,
  required TagsDataSource tagsDataSource,
  required ToatController toat,
  required DateTime day,
  HomeNavigation? navigation,
}) {
  controller.selectDay(day);

  return showAppDialog<void>(
    context,
    title: AppStrings.dayTitle(day),
    closeLabel: AppStrings.close,
    child: DayPanel(
      controller: controller,
      tagsDataSource: tagsDataSource,
      toat: toat,
      navigation: navigation,
      embedded: true,
    ),
  );
}
