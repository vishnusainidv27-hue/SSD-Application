import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../services/firestore_service.dart';

/// An app-bar bell with an unread-count badge, opening a list of the
/// signed-in user's notifications (Requirements §7, §4.10, §5.7). Reused
/// as-is by all three apps — each just supplies its own [userId].
class NotificationCentre extends StatelessWidget {
  const NotificationCentre({
    super.key,
    required this.userId,
    required this.firestoreService,
  });

  final String userId;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationModel>>(
      stream: firestoreService.watchNotifications(userId),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <NotificationModel>[];
        final unread = notifications.where((n) => !n.read).length;
        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            label: Text('$unread'),
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _NotificationSheet(
              notifications: notifications,
              firestoreService: firestoreService,
            ),
          ),
        );
      },
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet({
    required this.notifications,
    required this.firestoreService,
  });

  final List<NotificationModel> notifications;
  final FirestoreService firestoreService;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text('No notifications yet.'))
                  : ListView.separated(
                      controller: controller,
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n = notifications[i];
                        return ListTile(
                          leading: Icon(
                            n.read ? Icons.notifications_none : Icons.notifications_active,
                            color: n.read ? null : Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(n.message),
                          subtitle: n.createdAt == null
                              ? null
                              : Text(_relativeTime(n.createdAt!)),
                          onTap: n.read
                              ? null
                              : () => firestoreService.markNotificationRead(n.id),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}-${dt.month}-${dt.year}';
  }
}
