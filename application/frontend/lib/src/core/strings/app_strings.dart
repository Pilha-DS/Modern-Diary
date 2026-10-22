/// Todo texto visível do aplicativo fica aqui.
abstract final class AppStrings {
  static const String appName = 'Modern Diary';
  static const String appTagline = 'Organize seu dia.';

  static const String login = 'Entrar';
  static const String register = 'Criar conta';

  static const String usernameLabel = 'Nome de usuário';
  static const String usernameHint = 'ex.: jonathan';
  static const String passwordLabel = 'Senha';
  static const String passwordHint = 'Sua senha';
  static const String showPassword = 'Mostrar senha';
  static const String hidePassword = 'Ocultar senha';
  static const String usernameRequired = 'Informe seu nome de usuário.';
  static const String passwordRequired = 'Informe sua senha.';

  static const String switchToRegisterQuestion = 'Ainda não tem conta?';
  static const String switchToRegisterAction = 'Criar agora';
  static const String switchToLoginQuestion = 'Já tem uma conta?';
  static const String switchToLoginAction = 'Entrar';

  static const String loginSuccess = 'Bem-vindo de volta!';
  static const String registerSuccess = 'Conta criada com sucesso.';
  static const String logoutSuccess = 'Sessão encerrada.';
  static const String sessionLoading = 'Verificando sua sessão...';

  static const String connectionError =
      'Não foi possível conectar à API. Verifique sua conexão e tente novamente.';
  static const String unexpectedError =
      'Não foi possível concluir a ação. Tente novamente.';
  static const String invalidResponse =
      'A API respondeu em um formato inesperado.';

  static const String usersTitle = 'Usuários';
  static const String usersEmptyTitle = 'Nenhum usuário ainda';
  static const String usersEmptyMessage =
      'Assim que alguém se cadastrar, aparecerá aqui.';
  static const String usersErrorTitle = 'Não foi possível carregar os usuários';
  static const String usersLoadMore = 'Carregar mais';
  static const String refresh = 'Atualizar';
  static const String retry = 'Tentar novamente';
  static const String loadingUsers = 'Carregando usuários...';

  static const String logout = 'Sair';
  static const String roleAdmin = 'ADMIN';
  static const String roleModerator = 'MODERADOR';
  static const String roleUser = 'USUÁRIO';
  static const String roleAdminDescription =
      'Você administra o sistema e as contas de usuário.';
  static const String roleModeratorDescription =
      'Você está no time de moderação. As ferramentas chegam em breve.';
  static const String roleUserDescription =
      'Sua agenda e suas notas ficarão aqui. Estamos preparando esse espaço.';

  static String greeting(String username) => 'Olá, $username.';

  static String roleLabel(String role) {
    return switch (role) {
      'ADMIN' => roleAdmin,
      'MODERATOR' => roleModerator,
      _ => roleUser,
    };
  }

  static String roleDescription(String role) {
    return switch (role) {
      'ADMIN' => roleAdminDescription,
      'MODERATOR' => roleModeratorDescription,
      _ => roleUserDescription,
    };
  }

  static String usersTotal(int total) {
    return total == 1 ? '1 usuário' : '$total usuários';
  }

  // Navegação
  static const String dashboardTab = 'Início';
  static const String calendarTab = 'Calendário';
  static const String notesTab = 'Notas';
  static const String knowledgeTab = 'Conhecimentos';
  static const String menuLabel = 'Menu de navegação';
  static const String logoHomeTooltip = 'Ir para Início';
  static const String previousYear = 'Ano anterior';
  static const String nextYear = 'Próximo ano';
  static const String todayButton = 'Hoje';
  static const String quickAccessTitle = 'Seleção rápida';
  static const String quickAccessHint = 'Escolha a tela que quer abrir.';
  static const String dashboardDayHint =
      'Clique em um dia para adicionar nota, tag ou atividade.';

  // Calendário
  static const List<String> monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const List<String> weekdayShort = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  static const List<String> weekdayNames = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];

  static String monthName(int month) => monthNames[month - 1];

  static String monthTitle(int month, int year) {
    return '${monthName(month)} de $year';
  }

  static String dayTitle(DateTime day) {
    return '${day.day} de ${monthName(day.month)} de ${day.year} | ${weekdayNames[day.weekday - 1]}';
  }

  static String calendarYearSemantics(String year) => 'Ano $year';

  static String monthsOfYear(int year) => 'Meses de $year';

  static String monthCardSemantics(int month, int year) {
    return '${monthName(month)} de $year';
  }

  static String daySemantics(
    DateTime day, {
    required bool hasNote,
    int activities = 0,
    int done = 0,
    int tags = 0,
    String? holiday,
  }) {
    final parts = <String>['${day.day} de ${monthName(day.month)}'];
    if (holiday != null) {
      parts.add('feriado: $holiday');
    }
    if (hasNote) {
      parts.add('com nota');
    }
    if (activities > 0) {
      parts.add(
        '$activities ${activities == 1 ? 'atividade' : 'atividades'}, $done concluídas',
      );
    }
    if (tags > 0) {
      parts.add(tags == 1 ? 'com tag' : 'com tags');
    }
    return parts.join(', ');
  }

  // Agenda
  static const String agendaLoadingMonth = 'Carregando o calendário...';
  static const String agendaMonthErrorTitle =
      'Não foi possível carregar o calendário';
  static const String agendaYearErrorTitle = 'Não foi possível carregar o ano';
  static const String agendaDayErrorTitle =
      'Não foi possível carregar este dia';
  static const String agendaDayLoading = 'Carregando o dia...';
  static const String agendaCurrentMonth = 'Mês atual';

  static const String noteTitle = 'Notas do dia';
  static const String noteHint =
      'Markdown: # título, **negrito**, - item, - [x] feito';
  static const String noteEmpty = 'Nenhuma nota neste dia.';
  static const String saveNote = 'Salvar nota';
  static const String dayNoteCreated = 'Nota criada.';
  static const String dayNoteUpdated = 'Nota atualizada.';
  static const String dayNoteDeleted = 'Nota excluída.';
  static const String dayNoteDeleteTitle = 'Excluir nota?';
  static const String dayNoteDeleteMessage =
      'A nota será removida deste dia. Essa ação não pode ser desfeita.';
  static const String noteEditAction = 'Editar nota';
  static const String noteExpand = 'Ver a nota completa';
  static const String noteCollapse = 'Recolher a nota';
  static const String dayNoteContentRequired = 'Escreva a nota.';
  static const String confirmSelection = 'Confirmar';

  static String noteIndex(int index) => 'Nota $index';
  static String noteWords(int words) =>
      words == 1 ? '1 palavra' : '$words palavras';
  static String noteMore(int count) =>
      count == 1 ? '+ 1 nota' : '+ $count notas';

  static const String editDay = 'Editar';
  static const String finishDayEditing = 'Concluir';
  static const String daySensitivityLabel = 'Nível do dia';
  static const String daySensitivitySaved = 'Nível do dia atualizado.';
  static const String daySensitivityNone = 'Sem nível definido';
  static const String activitySensitivityAction = 'Alterar nível da atividade';
  static const String activitySensitivitySaved =
      'Nível da atividade atualizado.';

  static const String dayPreviewLoading = 'Carregando o dia...';
  static const String dayPreviewNoActivities = 'Nenhuma atividade.';

  static const String activitiesTitle = 'Atividades';
  static const String newActivity = 'Nova atividade';
  static const String activityTitleLabel = 'Atividade';
  static const String activityTitleHint = 'ex.: Estudar FastAPI';
  static const String activityTimeLabel = 'Horário (opcional)';
  static const String activityTimePlaceholder = 'Escolher horário';
  static const String activityTimeClear = 'Remover horário';
  static const String timePickerTitle = 'Escolher horário';
  static const String timePickerHours = 'Hora';
  static const String timePickerMinutes = 'Minuto';
  static const String timePickerConfirm = 'Confirmar';
  static const String activityTitleRequired = 'Informe a atividade.';
  static const String priorityLabel = 'Prioridade';
  static const String priorityLow = 'Baixa';
  static const String priorityMedium = 'Média';
  static const String priorityHigh = 'Alta';
  static const String createActivity = 'Criar atividade';
  static const String cancel = 'Cancelar';
  static const String save = 'Salvar';
  static const String close = 'Fechar';
  static const String delete = 'Excluir';
  static const String activityCreated = 'Atividade criada.';
  static const String activityDeleted = 'Atividade excluída.';
  static const String activityDeleteTitle = 'Excluir atividade?';
  static const String activityDeleteAction = 'Excluir atividade';
  static const String activityMarkDone = 'Marcar como concluída';
  static const String activityMarkPending = 'Marcar como pendente';
  static const String activitiesEmptyTitle = 'Nada agendado';
  static const String activitiesEmptyMessage =
      'Adicione uma atividade ou escreva uma nota para este dia.';

  static String activityDeleteMessage(String title) {
    return 'A atividade "$title" será removida deste dia.';
  }

  static String activitiesCount(int done, int total) {
    return total == 1 ? '$done de 1 concluída' : '$done de $total concluídas';
  }

  // Metas
  static const String goalsTab = 'Metas';
  static const String goalsTitle = 'Metas';
  static const String newGoal = 'Nova meta';
  static const String editGoal = 'Editar meta';
  static const String goalTitleLabel = 'Meta';
  static const String goalTitleHint = 'ex.: Aprender Flutter';
  static const String goalTitleRequired = 'Informe a meta.';
  static const String goalDescriptionLabel = 'Descrição (opcional)';
  static const String goalDescriptionHint = 'Por que essa meta importa?';
  static const String goalDueDateLabel = 'Prazo (opcional)';
  static const String goalDueDatePick = 'Escolher data';
  static const String goalDueDateClear = 'Remover prazo';
  static const String goalStepsLabel = 'Etapas (opcional)';
  static const String goalStepHint = 'ex.: Instalar o Flutter';
  static const String goalStepLabel = 'Etapa';
  static const String goalAddStep = 'Adicionar etapa';
  static const String goalStepTitleRequired = 'Informe a etapa.';
  static const String goalCreate = 'Criar meta';
  static const String goalSave = 'Salvar alterações';
  static const String goalStepCreate = 'Adicionar';
  static const String goalStepDialogTitle = 'Nova etapa';
  static const String goalCreated = 'Meta criada.';
  static const String goalUpdated = 'Meta atualizada.';
  static const String goalDeleted = 'Meta excluída.';
  static const String goalCompleted = 'Meta concluída.';
  static const String goalReopened = 'Meta reaberta.';
  static const String goalArchived = 'Meta arquivada.';
  static const String goalUnarchived = 'Meta desarquivada.';
  static const String goalStepCreated = 'Etapa criada.';
  static const String goalStepDeleted = 'Etapa excluída.';
  static const String goalCompleteAction = 'Concluir meta';
  static const String goalReopenAction = 'Reabrir meta';
  static const String goalArchiveAction = 'Arquivar meta';
  static const String goalUnarchiveAction = 'Desarquivar meta';
  static const String goalEditAction = 'Editar meta';
  static const String goalDeleteAction = 'Excluir meta';
  static const String goalDeleteTitle = 'Excluir meta?';
  static const String goalArchiveTitle = 'Arquivar meta?';
  static const String goalStepDeleteTitle = 'Excluir etapa?';
  static const String goalStepDeleteAction = 'Excluir etapa';
  static const String goalCompletedBadge = 'Concluída';
  static const String goalArchivedBadge = 'Arquivada';
  static const String goalsLoading = 'Carregando metas...';
  static const String goalsErrorTitle = 'Não foi possível carregar as metas';
  static const String goalsLoadMore = 'Carregar mais';
  static const String goalsEmptyTitle = 'Nenhuma meta aqui';
  static const String goalsEmptyActiveMessage =
      'Crie uma meta e divida em etapas para acompanhar o progresso.';
  static const String goalsEmptyCompletedMessage =
      'As metas concluídas aparecerão aqui.';
  static const String goalsEmptyArchivedMessage =
      'As metas arquivadas aparecerão aqui.';
  static const String goalsFilterActive = 'Ativas';
  static const String goalsFilterCompleted = 'Concluídas';
  static const String goalsFilterArchived = 'Arquivadas';
  static const String goalStepsTitle = 'Etapas';
  static const String goalDescriptionTitle = 'Descrição';

  static String goalsTotal(int total) => total == 1 ? '1 meta' : '$total metas';

  static String goalProgress(int done, int total) => '$done/$total';

  static String goalStepsCount(int total) {
    return total == 1 ? '1 etapa' : '$total etapas';
  }

  static String goalDueDate(DateTime day) {
    return 'Prazo: ${day.day} de ${monthName(day.month).toLowerCase()} de ${day.year}';
  }

  static String goalOverdueDate(DateTime day) {
    return 'Atrasada desde ${day.day} de ${monthName(day.month).toLowerCase()}';
  }

  static String goalOpenLabel(String title) => 'Abrir meta $title';

  static String goalDeleteMessage(String title) {
    return 'A meta "$title" e todas as etapas serão removidas. '
        'Esta ação não pode ser desfeita.';
  }

  static String goalArchiveMessage(String title) {
    return 'A meta "$title" sai da lista de ativas, mas não é excluída.';
  }

  static String goalStepDeleteMessage(String title) {
    return 'A etapa "$title" será removida desta meta.';
  }

  static String goalStepDoneLabel(String title) => 'Concluir etapa $title';

  static String goalStepPendingLabel(String title) => 'Reabrir etapa $title';

  static String goalProgressSemantics(String title, int done, int total) {
    return 'Progresso da meta $title: $done de $total';
  }

  // Notas
  static const String notesTitle = 'Notas';
  static const String notesSubtitle =
      'Anotações livres em markdown, do rascunho à ideia pronta.';
  static const String newNote = 'Nova nota';
  static const String noteCreateFirst = 'Criar primeira nota';
  static const String editNote = 'Editar nota';
  static const String noteTitleLabel = 'Título (opcional)';
  static const String noteTitleHint = 'ex.: Ideias para o projeto';
  static const String noteContentLabel = 'Nota';
  static const String noteContentHint =
      'Markdown: # título, **negrito**, - item, - [x] feito';
  static const String noteContentRequired =
      'Escreva alguma coisa antes de salvar.';
  static const String noteUntitled = 'Sem título';
  static const String noteCreate = 'Criar nota';
  static const String noteSave = 'Salvar nota';
  static const String noteCreated = 'Nota criada.';
  static const String noteUpdated = 'Nota atualizada.';
  static const String noteDeleted = 'Nota excluída.';
  static const String noteDeleteTitle = 'Excluir nota?';
  static const String noteDeleteAction = 'Excluir nota';
  static const String notePinAction = 'Fixar nota';
  static const String noteUnpinAction = 'Desafixar nota';
  static const String notePinned = 'Nota fixada no topo.';
  static const String noteUnpinned = 'Nota desafixada.';
  static const String notePinnedBadge = 'Fixada';
  static const String noteSearchHint = 'Buscar nas notas';
  static const String noteSearchClear = 'Limpar busca';
  static const String noteFilterAll = 'Todas';
  static const String noteFilterPinned = 'Fixadas';
  static const String notesLoading = 'Carregando notas...';
  static const String notesErrorTitle = 'Não foi possível carregar as notas';
  static const String notesEmptyTitle = 'Nenhuma nota ainda';
  static const String notesEmptyMessage =
      'Comece com uma ideia solta: o editor cuida do markdown.';
  static const String notesNoResultsTitle = 'Nada encontrado';
  static const String notesNoResultsMessage =
      'Tente outro termo ou limpe a busca.';
  static const String noteClearFilters = 'Limpar filtros';
  static const String notesLoadMore = 'Carregar mais';
  static const String noteEditorEmptyPreview =
      'Clique aqui para escrever em markdown.';
  static const String markdownEdit = 'Clique para editar';
  static const String markdownDone = 'Concluir edição';
  static const String markdownEmptyPreview = 'O texto aparece aqui.';
  static const String noteToolbarHeading = 'Título';
  static const String noteToolbarBold = 'Negrito';
  static const String noteToolbarItalic = 'Itálico';
  static const String noteToolbarList = 'Lista';
  static const String noteToolbarChecklist = 'Checklist';
  static const String noteToolbarQuote = 'Citação';
  static const String noteToolbarCode = 'Código';
  static const String noteToolbarLink = 'Link';
  static const String noteOpenAction = 'Abrir nota';

  static String notesTotal(int total) => total == 1 ? '1 nota' : '$total notas';

  static String noteUpdatedAt(DateTime at) {
    return 'Editada em ${shortDate(at)} às ${shortTime(at)}';
  }

  static String noteCount(int characters, int words) {
    return '$words palavras · $characters caracteres';
  }

  static String noteDeleteMessage(String title) {
    return 'A nota "$title" será removida. Esta ação não pode ser desfeita.';
  }

  static String noteSemantics(String title) => 'Nota $title';

  // Conhecimentos
  static const String knowledgeTitle = 'Conhecimentos';
  static const String newKnowledge = 'Novo conhecimento';
  static const String editKnowledge = 'Editar conhecimento';
  static const String knowledgeTitleLabel = 'Título';
  static const String knowledgeTitleHint = 'ex.: Como funciona um índice';
  static const String knowledgeTitleRequired = 'Informe o título.';
  static const String knowledgeContentLabel = 'Conteúdo (opcional)';
  static const String knowledgeContentHint =
      'Markdown: # título, **negrito**, - item, - [x] feito';
  static const String knowledgeLinksLabel = 'Links (opcional)';
  static const String knowledgeLinkUrlLabel = 'Link';
  static const String knowledgeLinkUrlHint = 'https://exemplo.com';
  static const String knowledgeLinkLabel = 'Nome do link (opcional)';
  static const String knowledgeAddLink = 'Adicionar link';
  static const String knowledgeInvalidLink =
      'Use um endereço começando com http:// ou https://.';
  static const String knowledgeAttachmentsLabel = 'Anexos (opcional)';
  static const String knowledgePickFiles = 'Anexar arquivos';
  static const String knowledgeFileTooLarge =
      'Cada arquivo pode ter no máximo 5 MB.';
  static const String knowledgeCreate = 'Criar conhecimento';
  static const String knowledgeSave = 'Salvar alterações';
  static const String knowledgeCreated = 'Conhecimento criado.';
  static const String knowledgeUpdated = 'Conhecimento atualizado.';
  static const String knowledgeDeleted = 'Conhecimento excluído.';
  static const String knowledgeDeleteTitle = 'Excluir conhecimento?';
  static const String knowledgeDeleteAction = 'Excluir conhecimento';
  static const String knowledgeEditAction = 'Editar conhecimento';
  static const String knowledgeConnect = 'Conectar';
  static const String knowledgeRelationDialogTitle = 'Conectar conhecimento';
  static const String knowledgeRelationCreated = 'Conhecimentos conectados.';
  static const String knowledgeRelationRemoved = 'Conexão removida.';
  static const String knowledgeNoCandidates =
      'Nenhum outro conhecimento disponível para conectar.';
  static const String knowledgeAttachmentAdded = 'Anexo enviado.';
  static const String knowledgeAttachmentRemoved = 'Anexo removido.';
  static const String knowledgeAttachmentFailed =
      'Não foi possível abrir o anexo. Tente novamente.';
  static const String knowledgeLoading = 'Carregando conhecimentos...';
  static const String knowledgeErrorTitle =
      'Não foi possível carregar os conhecimentos';
  static const String knowledgeLoadMore = 'Carregar mais';
  static const String knowledgeEmptyTitle = 'Nenhum conhecimento ainda';
  static const String knowledgeEmptyMessage =
      'Registre o que aprendeu e conecte as ideias em uma rede.';
  static const String knowledgeGraphTitle = 'Rede de conhecimentos';
  static const String knowledgeGraphLoading = 'Montando a rede...';
  static const String knowledgeGraphEmptyTitle = 'A rede está vazia';
  static const String knowledgeGraphEmptyMessage =
      'Crie conhecimentos e conecte-os para ver a rede crescer.';
  static const String knowledgeGraphSemantics = 'Rede de conhecimentos';
  static const String knowledgeGraphConnect = 'Conectar nós';
  static const String knowledgeGraphConnectOn = 'Conectando nós';
  static const String knowledgeGraphConnectHint =
      'Modo conexão: arraste um nó até outro para criar a conexão. '
      'Desligue o modo para voltar a mover os nós.';
  static const String knowledgeGraphSettings = 'Ajustes da rede';
  static const String knowledgeGraphSettingsHide = 'Fechar ajustes';
  static const String knowledgeGraphRepulsion = 'Repulsão';
  static const String knowledgeGraphLinkDistance = 'Distância das conexões';
  static const String knowledgeGraphGravity = 'Gravidade';
  static const String knowledgeGraphReorganize = 'Reorganizar a rede';
  static const String knowledgeGraphCenter = 'Centralizar a rede';
  static const String knowledgeGraphZoomIn = 'Aproximar';
  static const String knowledgeGraphZoomOut = 'Afastar';
  static const String knowledgeGraphFullscreen = 'Tela cheia';
  static const String knowledgeGraphFullscreenExit = 'Sair da tela cheia';
  static const String knowledgeGraphDragHint =
      'Arraste os nós para mudar a posição e use a roda do mouse para o zoom.';
  static String knowledgeGraphConnected(String target) =>
      'Conhecimento conectado a "$target".';

  static String knowledgeGraphConnectLabel(String title) =>
      'Conectar $title a outro nó';
  static const String knowledgeViewList = 'Lista';
  static const String knowledgeViewGraph = 'Grafo';
  static const String knowledgeNoContent = 'Sem conteúdo.';
  static const String knowledgeNoRelations = 'Ainda sem conexões.';
  static const String knowledgeNoLinks = 'Sem links.';
  static const String knowledgeNoAttachments = 'Sem anexos.';

  // Cartão compacto: uma célula por informação, três linhas fixas.
  static const String knowledgeGoalsCell = 'Metas';
  static const String knowledgeLinksCell = 'Links';
  static const String knowledgeConnectionsCell = 'Conexões';
  static const String knowledgeQuantityLabel = 'Qtd.';
  static const String knowledgeTagsCell = 'Tags';
  static const String knowledgeTagsShowAll = 'Ver mais';
  static const String knowledgeNoTags = 'Nenhuma tag.';
  static const String knowledgeAttachmentsTitle = 'Anexos';
  static const String knowledgeDeleteAttachmentTitle = 'Remover anexo?';
  static const String knowledgeObservationsTitle = 'Observações';
  static const String knowledgeNoObservations = 'Nenhuma observação ainda.';
  static const String knowledgeAddObservation = 'Adicionar observação';
  static const String knowledgeObservationHint =
      'Escreva o que percebeu, aprendeu ou ainda quer revisar.';
  static const String knowledgeObservationEmpty =
      'Escreva a observação antes de salvar.';
  static const String knowledgeObservationAdded = 'Observação adicionada.';
  static const String knowledgeObservationRemoved = 'Observação removida.';
  static const String knowledgeObservationDeleteTitle = 'Remover observação?';
  static const String knowledgeObservationDeleteConfirm = 'Remover';
  static const String knowledgeLinksUpdated = 'Links atualizados.';
  static const String knowledgeNewLinkTitle = 'Novo link';

  static String knowledgeTotal(int total) =>
      total == 1 ? '1 conhecimento' : '$total conhecimentos';

  static String knowledgeRelationsCount(int total) =>
      total == 1 ? '1 conexão' : '$total conexões';

  /// Rodapé do mini-modal do nó: o clique ainda abre o detalhe.
  static const String knowledgeNodeOpenHint = 'Clique no nó para abrir';

  static String knowledgeNodeMoreTags(int count) =>
      count == 1 ? '+ 1 tag' : '+ $count tags';

  /// Resumo do nó no grafo: conexões, nível e tags.
  static String knowledgeGraphNodeTooltip({
    required int connections,
    required String sensitivity,
    List<String> tags = const [],
  }) {
    return [
      knowledgeRelationsCount(connections),
      sensitivity,
      if (tags.isNotEmpty) tags.join(', '),
    ].join(' · ');
  }

  static String knowledgeDeleteMessage(String title) {
    return 'O conhecimento "$title", seus links e anexos serão removidos. '
        'As conexões com outros conhecimentos também serão desfeitas.';
  }

  static String knowledgeRemoveRelationLabel(String title) =>
      'Remover conexão com $title';

  static String knowledgeRemoveLinkLabel(String label) => 'Remover link $label';

  static String knowledgeRemoveAttachmentLabel(String filename) =>
      'Remover anexo $filename';

  static String knowledgeDeleteAttachmentMessage(String filename) =>
      'O anexo "$filename" será removido deste conhecimento.';

  static String knowledgeObservationCreatedAt(DateTime at) =>
      '${shortDate(at)} às ${shortTime(at)}';

  static String knowledgeRemoveObservationLabel(String text) =>
      'Remover observação $text';

  static String knowledgeObservationPreview(String text) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 60
        ? singleLine
        : '${singleLine.substring(0, 60)}...';
  }

  static String openItemLabel(String title) => 'Abrir $title';

  static String knowledgeOpenAttachmentLabel(String filename) =>
      'Abrir anexo $filename';

  static String knowledgeGraphTruncated(int shown, int total) =>
      'Mostrando $shown de $total conhecimentos.';

  static String knowledgeFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Metas em conhecimentos
  static const String knowledgeGoalsTitle = 'Metas ligadas';
  static const String knowledgeLinkGoal = 'Ligar meta';
  static const String knowledgeGoalDialogTitle = 'Ligar meta';
  static const String knowledgeGoalLinked = 'Meta ligada ao conhecimento.';
  static const String knowledgeGoalUnlinked = 'Ligação com a meta removida.';
  static const String knowledgeNoGoalCandidates =
      'Nenhuma meta disponível para ligar.';
  static const String knowledgeNoLinkedGoals = 'Nenhuma meta ligada.';

  static String knowledgeRemoveGoalLabel(String title) =>
      'Desligar meta $title';

  // Tags
  static const String tagsTab = 'Tags';
  static const String tagsTitle = 'Tags';
  static const String newTag = 'Nova tag';
  static const String editTag = 'Editar tag';
  static const String tagCreate = 'Criar tag';
  static const String tagSave = 'Salvar alterações';
  static const String tagNameLabel = 'Nome';
  static const String tagNameHint = 'ex.: estudo';
  static const String tagNameRequired = 'Informe o nome da tag.';
  static const String tagColorLabel = 'Cor';
  static const String tagDescriptionLabel = 'Descrição (opcional)';
  static const String tagDescriptionHint = 'Para que essa tag serve?';
  static const String tagCreated = 'Tag criada.';
  static const String tagUpdated = 'Tag atualizada.';
  static const String tagDeleted = 'Tag excluída.';
  static const String tagDeleteTitle = 'Excluir tag?';
  static const String tagDeleteAction = 'Excluir tag';
  static const String tagEditAction = 'Editar tag';
  static const String tagUsageEmptyTitle = 'Tag sem usos';
  static const String tagUsageEmptyMessage =
      'Marque um conhecimento, uma meta ou um dia com essa tag.';
  static const String tagUsageKnowledge = 'Conhecimento';
  static const String tagUsageGoal = 'Meta';
  static const String tagUsageDay = 'Dia';
  static const String tagUsageLoadMore = 'Carregar mais';
  static const String tagsLoading = 'Carregando tags...';
  static const String tagsErrorTitle = 'Não foi possível carregar as tags';
  static const String tagsEmptyTitle = 'Nenhuma tag ainda';
  static const String tagsEmptyMessage =
      'Crie tags com cor e descrição para organizar conhecimentos, metas e dias.';
  static const String tagsLoadMore = 'Carregar mais';
  static const String tagViewUsages = 'Ver usos';
  static const String tagFilterAll = 'Todas';
  static const String dayTagsTitle = 'Tags do dia';
  static const String dayTagsEmpty = 'Nenhuma tag neste dia.';
  static const String dayTagsSaved = 'Tags do dia atualizadas.';
  static const String tagPickerTitle = 'Escolher tags';
  static const String tagPickerSearchHint = 'Buscar ou criar tag';
  static const String tagPickerEmpty = 'Nenhuma tag encontrada.';
  static const String tagPickerDone = 'Concluir';
  static const String tagPickerAdd = 'Adicionar tag';
  static const String tagsLabel = 'Tags (opcional)';
  static const String tagPickColorLabel = 'Cor da tag';

  static String tagDeleteMessage(String name) {
    return 'A tag "$name" será removida de todos os registros que a usam.';
  }

  static String tagOpenUsagesLabel(String name) => 'Ver onde $name é usada';

  static String tagOpenLabel(String name) => 'Abrir tag $name';

  static String tagUsageOpenLabel(String title) => 'Abrir $title';
  static String tagUsageTitle(String name) => 'Usos de $name';

  static String tagUsageTotal(int total) =>
      total == 1 ? '1 uso' : '$total usos';

  static String fullDate(DateTime day) {
    return '${day.day} de ${monthName(day.month).toLowerCase()} de ${day.year}';
  }

  static String shortDate(DateTime day) {
    return '${_twoDigits(day.day)}/${_twoDigits(day.month)}/${day.year}';
  }

  static String shortTime(DateTime time) {
    return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
  }

  static String knowledgeCreatedAt(DateTime at) {
    return 'Criado em ${shortDate(at)} às ${shortTime(at)}';
  }

  // Sensibilidade
  static const String sensitivityLabel = 'Sensibilidade';
  static const String sensitivityPublic = 'Público';
  static const String sensitivityBasic = 'Básico';
  static const String sensitivityModerate = 'Moderado';
  static const String sensitivityComplex = 'Complexo';
  static const String sensitivitySecret = 'Sigiloso';
  static const String sensitivityAll = 'Todos';
  static const String sensitivityKnowledgeLabel = 'Nível de sensibilidade';
  static const String sensitivityGoalLabel = 'Nível de sensibilidade';
  static const String sensitivityNoteLabel = 'Nível da nota';
  static const String sensitivityActivityLabel = 'Nível da atividade';

  /// Rótulo de um nível; o valor vem da API em português.
  static String sensitivityLabelOf(String apiValue) {
    return switch (apiValue) {
      'basico' => sensitivityBasic,
      'moderado' => sensitivityModerate,
      'complexo' => sensitivityComplex,
      'sigiloso' => sensitivitySecret,
      'all' => sensitivityAll,
      _ => sensitivityPublic,
    };
  }

  static String sensitivityBadgeLabel(String apiValue) {
    return 'Nível ${sensitivityLabelOf(apiValue)}';
  }

  // Áreas de permissão
  static const String permissionAreaKnowledge = 'Conhecimentos';
  static const String permissionAreaNotes = 'Notas';
  static const String permissionAreaGoals = 'Metas';
  static const String permissionAreaDays = 'Dias';
  static const String permissionAreaActivities = 'Atividades';

  static String permissionAreaLabel(String apiValue) {
    return switch (apiValue) {
      'notas' => permissionAreaNotes,
      'metas' => permissionAreaGoals,
      'dias' => permissionAreaDays,
      'atividades' => permissionAreaActivities,
      _ => permissionAreaKnowledge,
    };
  }

  // Credenciais de API
  static const String secretsTab = 'Credenciais';
  static const String secretsTitle = 'Credenciais de API';
  static const String secretsSubtitle =
      'Cada credencial acessa apenas as áreas e os níveis que você liberar.';
  static const String newSecret = 'Nova credencial';
  static const String editSecret = 'Editar credencial';
  static const String secretNameLabel = 'Nome da credencial';
  static const String secretNameHint = 'ex.: integracao_externa';
  static const String secretNameRequired = 'Informe o nome da credencial.';
  static const String secretPermissionsLabel = 'Permissões por área';
  static const String secretPermissionRequired = 'Libere ao menos uma área.';
  static const String secretAreaAccessLabel = 'Liberar área';
  static const String secretReadLabel = 'Ler até';
  static const String secretCreateLabel = 'Criar';
  static const String secretWriteLabel = 'Alterar';
  static const String secretCreateRule =
      'Criar libera registros em qualquer nível. Ler e alterar continuam '
      'limitados ao nível escolhido.';
  static const String secretNoPermission = 'Nenhuma área liberada.';
  static const String secretCreate = 'Criar credencial';
  static const String secretSave = 'Salvar permissões';
  static const String secretCreated = 'Credencial criada.';
  static const String secretUpdated = 'Credencial atualizada.';
  static const String secretRotated = 'Token trocado.';
  static const String secretRevoked = 'Credencial revogada.';
  static const String secretActive = 'Ativa';
  static const String secretRevokedBadge = 'Revogada';
  static const String secretEditAction = 'Editar credencial';
  static const String secretRotateLabel = 'Trocar token';
  static const String secretRevokeLabel = 'Revogar credencial';
  static const String secretAuditLabel = 'Ver auditoria';
  static const String secretRotateTitle = 'Trocar o token?';
  static const String secretRevokeTitle = 'Revogar credencial?';
  static const String secretRotateAction = 'Trocar';
  static const String secretRevokeAction = 'Revogar';
  static const String secretAuditAction = 'Auditoria';
  static const String secretsLoading = 'Carregando credenciais...';
  static const String secretsErrorTitle =
      'Não foi possível carregar as credenciais';
  static const String secretsEmptyTitle = 'Nenhuma credencial ainda';
  static const String secretsEmptyMessage =
      'Crie uma credencial para integrar um aplicativo ou serviço à sua conta.';
  static const String secretsLoadMore = 'Carregar mais';
  static const String secretNeverUsed = 'Nunca usada';
  static const String secretTokenTitle = 'Guarde este token';
  static const String secretTokenWarning =
      'Copie agora: por segurança, o token não será mostrado novamente.';
  static const String secretTokenLabel = 'Token de acesso';
  static const String secretTokenCopy = 'Copiar token';
  static const String secretTokenCopied = 'Token copiado.';
  static const String secretTokenDone = 'Concluir';

  static String secretHint(String hint) => '••••$hint';

  static String secretHintSemantics(String hint) => 'Token terminado em $hint';

  static String secretCreatedAt(DateTime at) {
    return 'Criada em ${shortDate(at)}';
  }

  static String secretLastUsed(DateTime at) {
    return 'Último uso em ${shortDate(at)} às ${shortTime(at)}';
  }

  static String secretRotateMessage(String name) {
    return 'O token atual de "$name" deixa de funcionar e um novo será gerado.';
  }

  static String secretRevokeMessage(String name) {
    return 'A credencial "$name" para de funcionar imediatamente. '
        'O histórico de auditoria continua guardado.';
  }

  static String secretPermissionLine(
    String area,
    String level, {
    required bool create,
    required bool write,
  }) {
    final parts = <String>['$area: até $level'];
    if (create) {
      parts.add('criar');
    }
    if (write) {
      parts.add('alterar');
    }
    return parts.join(' · ');
  }

  static String secretsTotal(int total) =>
      total == 1 ? '1 credencial' : '$total credenciais';

  static String secretAuditTitle(String name) => 'Auditoria de $name';

  static String secretAuditActionLabel(String action) {
    return switch (action) {
      'CREATE' => 'Criação',
      'UPDATE' => 'Alteração',
      'DELETE' => 'Exclusão',
      _ => 'Leitura',
    };
  }

  static String secretAuditResultLabel(String result) {
    return result == 'DENIED' ? 'Negado' : 'Permitido';
  }

  /// Tipo técnico do alvo vira rótulo; desconhecido não aparece.
  static String? secretAuditTargetLabel(String? targetType) {
    return switch (targetType) {
      'knowledge_item' => 'Conhecimento',
      'goal' => 'Meta',
      'goal_step' => 'Etapa',
      'agenda_day' => 'Dia',
      'activity' => 'Atividade',
      _ => null,
    };
  }

  static String secretAuditLine(String action, String area, String result) {
    return '$action · $area · $result';
  }

  static String secretAuditTime(DateTime at) {
    return '${shortDate(at)} às ${shortTime(at)}';
  }

  static const String secretAuditLoading = 'Carregando auditoria...';
  static const String secretAuditErrorTitle =
      'Não foi possível carregar a auditoria';
  static const String secretAuditEmptyTitle = 'Nenhuma operação registrada';
  static const String secretAuditEmptyMessage =
      'As leituras e alterações feitas com esta credencial aparecem aqui.';
  static const String secretAuditLoadMore = 'Carregar mais';

  static String secretAuditTotal(int total) =>
      total == 1 ? '1 operação' : '$total operações';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');

  static String tagPickerCreate(String name) => 'Criar tag "$name"';

  static String tagRemoveLabel(String name) => 'Remover tag $name';

  static String tagsTotal(int total) => total == 1 ? '1 tag' : '$total tags';

  static String knowledgeGoalsCount(int total) =>
      total == 1 ? '1 meta' : '$total metas';

  // Cabeçalho, configurações básicas e rodapé.
  static const String profileMenuLabel = 'Perfil e configurações';
  static const String settingsTitle = 'Configurações básicas';
  static const String settingsShortLabel = 'Ajustes';
  static const String settingsAppearanceSection = 'Aparência';
  static const String settingsThemeLabel = 'Tema';
  static const String settingsThemeLight = 'Claro';
  static const String settingsThemeDark = 'Escuro';
  static const String settingsThemeSystem = 'Sistema';
  static const String settingsProfileSection = 'Perfil';
  static const String settingsAvatarLabel = 'Foto de perfil';
  static const String settingsAvatarChoose = 'Escolher foto';
  static const String settingsAvatarRemove = 'Remover foto';
  static const String settingsAvatarTooLarge =
      'A imagem passa de 512 KB. Escolha uma foto menor.';
  static const String settingsAvatarFailed =
      'Não foi possível ler a imagem. Tente outro arquivo.';
  static const String settingsLocationLabel = 'Localidade';
  static const String settingsLocationHint = 'Cidade, estado ou país';
  static const String settingsNationalityLabel = 'Nacionalidade';
  static const String settingsNationalityHint = 'Escolher país';
  static const String settingsNationalityClear = 'Remover nacionalidade';
  static const String holidaySyncButton = 'Puxar feriados';
  static const String holidaySyncHint =
      'Baixa os feriados do ano corrente e do próximo e guarda no calendário, sem consultar a fonte toda vez.';
  static const String holidaySyncChooseNationality =
      'Escolha sua nacionalidade para puxar os feriados.';
  static String holidaySyncDone(int total) =>
      '$total feriados guardados no calendário.';
  static String holidayStatus(String name) => 'Feriado · $name';
  static const String countryPickerTitle = 'Escolher nacionalidade';
  static const String countrySearchLabel = 'Buscar país';
  static const String countrySearchHint = 'Nome, sigla ou código';
  static const String countriesLoading = 'Carregando países...';
  static const String countriesErrorTitle =
      'Não foi possível carregar os países';
  static const String countriesEmptyTitle = 'Nenhum país encontrado';
  static const String countriesEmptyMessage =
      'Tente outro nome, sigla ou código de telefone.';
  static const String countriesLoadMore = 'Carregar mais países';
  static const String settingsPhoneLabel = 'Telefone';
  static const String settingsPhoneHint = '(00) 00000-0000';
  static const String settingsLocalNote =
      'Estes ajustes ficam guardados neste dispositivo.';
  static const String settingsSave = save;
  static const String settingsSaved = 'Configurações salvas.';

  static const String footerAboutLabel = 'Sobre o projeto';
  static const String footerContactLabel = 'Contato';
  static const String footerPhoneLabel = 'Telefone';
  static const String footerSiteLabel = 'Site';

  static String footerCreatedBy(String name) => 'Criado por $name';
  static String footerVersion(String version) => 'Versão $version';

  // Sobre mim e auditoria
  static const String aboutMeTab = 'Sobre mim';
  static const String aboutMeTitle = 'Sobre mim';
  static const String aboutMeSubtitle =
      'Quem você é neste diário e o que fez em cada dia.';
  static const String aboutMeUsername = 'Usuário';
  static const String aboutMeRoleLabel = 'Permissão';
  static const String aboutMeMemberSince = 'Na conta desde';

  static const String auditTitle = 'Auditoria';
  static const String previousMonth = 'Mês anterior';
  static const String nextMonth = 'Próximo mês';
  static const String auditToday = 'Hoje';
  static const String auditSubtitle =
      'As ações do dia e as conexões que elas criaram entre notas, metas e conhecimentos.';
  static const String auditGraphSemantics = 'Grafo das ações do dia';
  static const String auditGraphTruncated =
      'Este dia tem muitas ações: o grafo mostra as primeiras.';
  static const String auditLoading = 'Carregando a auditoria...';
  static const String auditErrorTitle = 'Não foi possível carregar a auditoria';
  static const String auditErrorRetry = 'Tentar novamente';
  static const String auditEmptyTitle = 'Nenhuma ação neste dia';
  static const String auditEmptyMessage =
      'Escolha outro dia no calendário ou faça algo para o histórico começar.';
  static const String auditLoadMore = 'Carregar mais ações';
  static const String auditConnectHint =
      'Cada ação liga os registros que ela tocou ao dia.';
  static const String auditOpenEntity = 'Abrir registro';
  static const String auditNodeOpenHint = 'Clique para abrir o registro';
  static const String auditNodeDayHint = 'Clique para abrir o dia';

  static String auditConnectionsCount(int total) =>
      total == 1 ? '1 conexão' : '$total conexões';

  static String auditDayTotal(int total) =>
      total == 1 ? '1 ação' : '$total ações';

  static String auditDaySemantics(DateTime day, int total) {
    return '${day.day} de ${monthName(day.month)}, ${auditDayTotal(total)}';
  }

  static String auditCreated(String noun, String label) =>
      'Criou $noun «$label».';

  static String auditUpdated(String noun, String label) =>
      'Editou $noun «$label».';

  static String auditDeleted(String noun, String label) =>
      'Excluiu $noun «$label».';

  static String auditLinked(String source, String target) =>
      'Conectou «$source» a «$target».';

  static String auditUnlinked(String source, String target) =>
      'Desconectou «$source» de «$target».';

  /// Nome do tipo de registro com artigo, para a frase da ação.
  static String auditEntityNoun(String type) {
    return switch (type) {
      'knowledge' => 'o conhecimento',
      'goal' => 'a meta',
      'note' => 'a nota',
      'tag' => 'a tag',
      'day' => 'o dia',
      'activity' => 'a atividade',
      _ => 'o registro',
    };
  }

  /// Nome curto do tipo de registro, usado no resumo do nó do grafo.
  static String auditEntityType(String type) {
    return switch (type) {
      'knowledge' => 'Conhecimento',
      'goal' => 'Meta',
      'note' => 'Nota',
      'agenda_note' => 'Diário',
      'tag' => 'Tag',
      'day' => 'Dia',
      'activity' => 'Atividade',
      _ => 'Registro',
    };
  }

  // Grafo de vida (Live graph)
  static const String liveGraphTab = 'Live graph';
  static const String liveGraphTitle = 'Grafo de vida';
  static const String liveGraphSubtitle =
      'Dias, atividades, notas, metas e conhecimentos: tudo o que você '
      'registrou, conectado em um só lugar.';
  static const String liveGraphSemantics = 'Grafo de vida';
  static const String liveGraphLoading = 'Montando o grafo de vida...';
  static const String liveGraphErrorTitle =
      'Não foi possível carregar o grafo de vida';
  static const String liveGraphErrorRetry = 'Tentar novamente';
  static const String liveGraphEmptyTitle = 'Nada para conectar ainda';
  static const String liveGraphEmptyMessage =
      'Registre um dia, uma atividade, uma nota, uma meta ou um '
      'conhecimento para o grafo começar.';
  static const String liveGraphEmptyFilterTitle = 'Nenhum registro deste tipo';
  static const String liveGraphEmptyFilterMessage =
      'Escolha outro tipo ou volte para todos.';
  static const String liveGraphAllTypes = 'Tudo';
  static const String liveGraphConnect = 'Conectar nós';
  static const String liveGraphConnectOn = 'Conectando nós';
  static const String liveGraphConnectHint =
      'Modo conexão: arraste um nó até outro para ligar os dois registros. '
      'Desligue o modo para voltar a mover os nós.';
  static const String liveGraphSettings = 'Ajustes da rede';
  static const String liveGraphSettingsHide = 'Fechar ajustes';
  static const String liveGraphRepulsion = 'Repulsão';
  static const String liveGraphLinkDistance = 'Distância das conexões';
  static const String liveGraphGravity = 'Gravidade';
  static const String liveGraphDragHint =
      'Arraste os nós para mudar a posição e use a roda do mouse para o zoom.';
  static const String liveGraphRefresh = 'Atualizar o grafo';
  static const String liveGraphTruncated =
      'O grafo mostra os registros mais recentes de cada tipo.';
  static const String liveGraphLinkCreated = 'Registros conectados.';
  static const String liveGraphLinkFailed =
      'Não foi possível conectar os registros. Tente novamente.';
  static const String liveGraphLinkRemoved = 'Conexão removida.';
  static const String liveGraphLinkRemoveFailed =
      'Não foi possível remover a conexão. Tente novamente.';
  static const String liveGraphLinksButton = 'Conexões';
  static const String liveGraphLinksTitle = 'Conexões entre registros';
  static const String liveGraphLinksHint =
      'Só as conexões feitas aqui podem ser desfeitas; as que vieram de '
      'relações, metas ou do dia continuam na origem.';
  static const String liveGraphLinksEmpty =
      'Nenhuma conexão manual ainda. Use "Conectar nós" no grafo.';
  static const String liveGraphLinksClose = 'Fechar';
  static const String liveGraphRemoveLinkTitle = 'Remover conexão?';
  static const String liveGraphRemoveLinkAction = 'Remover conexão';
  static const String liveGraphNodeOpenHint = 'Clique no nó para abrir';

  static String liveGraphRemoveLinkMessage(String source, String target) {
    return '«$source» e «$target» deixarão de aparecer conectados.';
  }

  static String liveGraphRemoveLinkLabel(String source, String target) {
    return 'Remover conexão entre $source e $target';
  }

  static String liveGraphLinksCount(int total) {
    return total == 1 ? '1 conexão manual' : '$total conexões manuais';
  }

  static String liveGraphTotal(int total) {
    return total == 1 ? '1 registro' : '$total registros';
  }

  static String liveGraphConnected(String source, String target) {
    return '«$source» conectado a «$target».';
  }

  // Pesquisa universal
  static const String searchTitle = 'Pesquisar';
  static const String searchAction = 'Pesquisar em tudo (Q)';
  static const String searchClose = 'Fechar';
  static const String searchHint = 'Pesquisar em todas as áreas';
  static const String searchClear = 'Limpar busca';
  static const String searchStartTitle = 'Pesquise em tudo';
  static const String searchStartMessage =
      'Dias, atividades, notas, metas e conhecimentos em um só lugar.';
  static const String searchLoading = 'Pesquisando...';
  static const String searchErrorTitle = 'Não foi possível pesquisar';
  static const String searchRetry = 'Tentar novamente';
  static const String searchEmptyTitle = 'Nada encontrado';
  static const String searchLoadMore = 'Carregar mais';
  static const String searchAllTypes = 'Tudo';
  static const String searchAnyLevel = 'Qualquer nível';
  static const String searchPeriodAny = 'Período';
  static const String searchPeriodClear = 'Limpar período';
  static const String searchTagLabel = 'Tag';

  static String searchEmptyMessage(String query) {
    return 'Nenhum registro contém «$query».';
  }

  static String searchTotal(int total) {
    return total == 1 ? '1 registro' : '$total registros';
  }

  static String searchPeriodRange(String from, String to) {
    return 'De $from a $to';
  }

  static String searchPeriodFrom(String from) => 'A partir de $from';

  static String searchPeriodUntil(String to) => 'Até $to';
}
