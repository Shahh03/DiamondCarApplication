import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final void Function(String action) onAction;

  const QuickActions({Key? key, required this.onAction}) : super(key: key);

  Widget _buildAction({
    required IconData icon,
    required String label,
    required String actionKey,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => onAction(actionKey),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(
        children: [
          _buildAction(
            icon: Icons.directions_car,
            label: 'Browse Cars',
            actionKey: 'browse',
            color: Colors.blue.shade200,
          ),
          _buildAction(
            icon: Icons.favorite,
            label: 'Wishlist',
            actionKey: 'favorites',
            color: Colors.red.shade200,
          ),
          _buildAction(
            icon: Icons.receipt_long,
            label: 'My Rentals',
            actionKey: 'rentals',
            color: Colors.amber.shade200,
          ),
        ],
      ),
    );
  }
}
