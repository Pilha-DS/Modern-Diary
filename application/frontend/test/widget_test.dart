import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/app.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mostra o login quando não existe sessão salva', (tester) async {
    await tester.pumpWidget(const ModernDiaryApp());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.appName), findsOneWidget);
    expect(find.text(AppStrings.appTagline), findsOneWidget);
    expect(find.text(AppStrings.usernameLabel), findsOneWidget);
    expect(find.text(AppStrings.passwordLabel), findsOneWidget);
  });

  testWidgets('alterna para o modo de cadastro', (tester) async {
    await tester.pumpWidget(const ModernDiaryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.switchToRegisterAction));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.register), findsOneWidget);
    expect(find.text(AppStrings.usernameLabel), findsOneWidget);
  });

  testWidgets('valida campos obrigatórios antes de chamar a API', (
    tester,
  ) async {
    await tester.pumpWidget(const ModernDiaryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.login));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.usernameRequired), findsOneWidget);
    expect(find.text(AppStrings.passwordRequired), findsOneWidget);
  });
}
