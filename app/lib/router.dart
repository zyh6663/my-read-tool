import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_pages.dart';
import 'bookshelf_page.dart';
import 'config/api_config.dart';
import 'pages/auth_service.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/search_page.dart';
import 'reading_page.dart';
import 'widgets/app_scaffold.dart';

Widget _shell(Widget child, {required int index, required BuildContext context}) {
  return AppScaffold(
    currentIndex: index,
    onTabChanged: (tabIndex) {
      switch (tabIndex) {
        case 0:
          context.go('/');
          break;
        case 1:
          context.go('/bookshelf');
          break;
        case 2:
          context.go('/library');
          break;
        case 3:
          context.go('/user');
          break;
      }
    },
    child: child,
  );
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final path = state.matchedLocation;
    final isAuthPage = path == '/login' || path == '/register';
    if (!AuthService.isLoggedIn && !isAuthPage) return '/login';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => _shell(const HomePage(), index: 0, context: context),
    ),
    GoRoute(
      path: '/bookshelf',
      builder: (context, state) => _shell(const BookShelfPage(userId: 'me', baseUrl: ApiConfig.baseUrl), index: 1, context: context),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => _shell(const LibraryPage(), index: 2, context: context),
    ),
    GoRoute(
      path: '/user',
      builder: (context, state) => _shell(const UserCenterPage(), index: 3, context: context),
    ),
    GoRoute(
      path: '/reading/:bookId',
      builder: (context, state) {
        final bookId = int.tryParse(state.pathParameters['bookId'] ?? '') ?? 0;
        return ReadingPage(bookId: bookId, bookTitle: '阅读');
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
    GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
  ],
);
