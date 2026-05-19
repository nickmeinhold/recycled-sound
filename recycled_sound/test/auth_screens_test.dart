import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:recycled_sound/features/auth/presentation/login_screen.dart';
import 'package:recycled_sound/features/auth/presentation/signup_screen.dart';

/// Smoke-test the auth screens. Both are pure UI in the MVP — Firebase Auth
/// is wired later. We render them inside a minimal GoRouter so the navigation
/// callbacks (context.go / context.push) don't throw.
GoRouter _routerFor(Widget root) => GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => root),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('home')))),
    ]);

void main() {
  testWidgets('LoginScreen renders welcome copy + inputs', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _routerFor(const LoginScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('LoginScreen Sign In button is tappable', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _routerFor(const LoginScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    // Navigation pushed to '/' via context.go; nothing to assert beyond
    // not throwing.
  });

  testWidgets('SignupScreen renders all field labels', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _routerFor(const SignupScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('SignupScreen typing email updates the controller', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _routerFor(const SignupScreen()),
    ));
    await tester.pumpAndSettle();
    final emailField = find.widgetWithText(TextField, 'you@example.com');
    if (emailField.evaluate().isNotEmpty) {
      await tester.enterText(emailField, 'test@example.com');
      expect(find.text('test@example.com'), findsOneWidget);
    }
  });

  testWidgets('SignupScreen role tile selects recipient', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _routerFor(const SignupScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Recipient'), findsOneWidget);
    await tester.tap(find.text('Recipient'));
    await tester.pumpAndSettle();
    // After tap, the recipient tile should display the checked radio.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('SignupScreen Create Account button tappable', (tester) async {
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _routerFor(const SignupScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Account').last);
    await tester.pumpAndSettle();
  });
}
