import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../models/notification_item.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        backgroundColor: const Color(0xFF800000),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'mark_read') {
                await NotificationService().markAllNotificationsAsRead();
              } else if (value == 'clear_all') {
                await NotificationService().clearAllNotifications();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ล้างการแจ้งเตือนทั้งหมดแล้ว')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_read',
                child: Text('ทำเครื่องหมายว่าอ่านแล้วทั้งหมด'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('ล้างทั้งหมด', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: NotificationService().getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF800000)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีการแจ้งเตือน',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  await NotificationService().deleteNotification(notification.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ลบการแจ้งเตือนแล้ว'), duration: Duration(seconds: 2)),
                    );
                  }
                },
                child: _buildNotificationTile(context, notification),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, NotificationItem notification) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'pawn':
        iconData = Icons.account_balance;
        iconColor = Colors.orange;
        break;
      case 'cart':
        iconData = Icons.shopping_cart;
        iconColor = Colors.blue;
        break;
      case 'store':
        iconData = Icons.storefront;
        iconColor = Colors.red;
        break;
      case 'appointment':
        iconData = Icons.event_available;
        iconColor = Colors.purple;
        break;
      case 'price':
        iconData = Icons.show_chart;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'th');

    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          NotificationService().markNotificationAsRead(notification.id);
        }
        // Potential navigation logic here based on type.
      },
      child: Container(
        color: notification.isRead ? Colors.transparent : Colors.blue.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: notification.isRead ? Colors.grey.shade700 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormat.format(notification.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
