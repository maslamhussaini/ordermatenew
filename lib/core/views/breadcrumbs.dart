import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordermate/core/router/app_route_model.dart';

class Breadcrumbs extends StatelessWidget {
  final GoRouterState state;
  final List<AppRoute> routes;

  const Breadcrumbs({super.key, required this.state, required this.routes});

  List<({String title, String fullPath})> _getBreadcrumbs(
      String location, List<AppRoute> currentRoutes, String parentPath) {
    for (final r in currentRoutes) {
      // Construct full path
      String currentPath =
          r.path.startsWith('/') ? r.path : '$parentPath/${r.path}';
      currentPath = currentPath.replaceAll('//', '/');

      // Check for match
      // Logic: If the location matches this path exactly, OR if location starts with this path + '/'
      bool isMatch = false;
      if (location == currentPath) {
        isMatch = true;
      } else if (location.startsWith('$currentPath/')) {
        isMatch = true;
      }

      if (isMatch) {
        final childCrumbs = _getBreadcrumbs(location, r.children, currentPath);
        return [(title: r.title, fullPath: currentPath), ...childCrumbs];
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final location = state.matchedLocation;
    final crumbs = _getBreadcrumbs(location, routes, '');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: crumbs.map((c) {
          final isLast = c == crumbs.last;
          return Row(
            children: [
              InkWell(
                onTap: isLast ? null : () => context.go(c.fullPath),
                child: Text(
                  c.title,
                  style: TextStyle(
                    color: isLast ? Colors.white : Colors.white70,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    decoration:
                        isLast ? TextDecoration.none : TextDecoration.underline,
                  ),
                ),
              ),
              if (!isLast)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child:
                      Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
