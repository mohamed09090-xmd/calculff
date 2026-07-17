import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_credit_profit_manager/features/admin_platform/domain/admin_auth_failure.dart';
import 'package:game_credit_profit_manager/features/admin_platform/presentation/admin_login_screen.dart';

void main() {
  testWidgets('validates empty and malformed email', (tester) async {
    await _pumpLogin(tester);

    await tester.tap(find.byKey(const Key('platform-sign-in-button')));
    await tester.pump();
    expect(find.text('البريد مطلوب.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('platform-email-field')),
      'invalid-email',
    );
    await tester.enterText(
      find.byKey(const Key('platform-password-field')),
      'test-password',
    );
    await tester.tap(find.byKey(const Key('platform-sign-in-button')));
    await tester.pump();
    expect(find.text('صيغة البريد غير صالحة.'), findsOneWidget);
  });

  testWidgets('password visibility toggle changes obscureText', (tester) async {
    await _pumpLogin(tester);

    final passwordEditableText = find.descendant(
      of: find.byKey(const Key('platform-password-field')),
      matching: find.byType(EditableText),
    );
    expect(passwordEditableText, findsOneWidget);

    bool passwordIsObscured() =>
        tester.widget<EditableText>(passwordEditableText).obscureText;

    expect(passwordIsObscured(), isTrue);

    await tester.tap(find.byKey(const Key('platform-password-visibility')));
    await tester.pump();
    expect(passwordIsObscured(), isFalse);

    await tester.tap(find.byKey(const Key('platform-password-visibility')));
    await tester.pump();
    expect(passwordIsObscured(), isTrue);
  });

  testWidgets('authenticating disables fields and submit button', (
    tester,
  ) async {
    await _pumpLogin(tester, authenticating: true);

    final email = tester.widget<TextFormField>(
      find.byKey(const Key('platform-email-field')),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('platform-sign-in-button')),
    );

    expect(email.enabled, isFalse);
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('local submit lock prevents duplicate attempts', (tester) async {
    final completer = Completer<void>();
    var calls = 0;
    await _pumpLogin(
      tester,
      onSignIn: ({required email, required password}) {
        calls += 1;
        return completer.future;
      },
    );

    await tester.enterText(
      find.byKey(const Key('platform-email-field')),
      'admin@example.test',
    );
    await tester.enterText(
      find.byKey(const Key('platform-password-field')),
      'test-password',
    );
    await tester.tap(find.byKey(const Key('platform-sign-in-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('platform-sign-in-button')));
    await tester.pump();

    expect(calls, 1);
    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('maps failure codes without raw errors', (tester) async {
    await _pumpLogin(
      tester,
      failureCode: AdminAuthFailureCode.invalidCredentials,
    );

    expect(find.text('بيانات الدخول غير صحيحة.'), findsOneWidget);
    expect(find.textContaining('AuthException'), findsNothing);
  });

  testWidgets('email, password, visibility and login expose semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await _pumpLogin(tester);

    expect(find.bySemanticsLabel('البريد'), findsWidgets);
    expect(find.bySemanticsLabel('كلمة المرور'), findsWidgets);
    expect(find.bySemanticsLabel('إظهار كلمة المرور'), findsWidgets);
    expect(find.bySemanticsLabel('دخول'), findsWidgets);
  });
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  bool authenticating = false,
  AdminAuthFailureCode? failureCode,
  Future<void> Function({required String email, required String password})?
  onSignIn,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar', 'DZ'),
      supportedLocales: const [Locale('ar', 'DZ'), Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminLoginScreen(
        authenticating: authenticating,
        failureCode: failureCode,
        onSignIn: onSignIn ?? ({required email, required password}) async {},
      ),
    ),
  );
  await tester.pump();
}
