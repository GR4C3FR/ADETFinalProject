import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final int addedCount;
  final int reviewsCount;
  final int savedCount;
  final int flagCount;

  const ProfilePage({
    super.key,
    this.addedCount = 0,
    this.reviewsCount = 0,
    this.savedCount = 0,
    this.flagCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const appBlue = Color(0xFF1565C0);

    return SingleChildScrollView(
      child: Column(
        children: [
          // ADDED: profile header with themed avatar icon
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ADDED: solid blue avatar with white person icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: appBlue,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guest User',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'PottyPal Member',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                ),
              ],
            ),
          ),

          // ADDED: stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatTile(
                  icon: Icons.wc,
                  value: '$addedCount',
                  label: 'Added',
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                _StatTile(
                  icon: Icons.star,
                  value: '$reviewsCount',
                  label: 'Reviews',
                  color: Colors.amber[700]!,
                ),
                const SizedBox(width: 10),
                _StatTile(
                  icon: Icons.bookmark,
                  value: '$savedCount',
                  label: 'Saved',
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(width: 10),
                _StatTile(
                  icon: Icons.flag_rounded,
                  value: '$flagCount',
                  label: 'Flags',
                  color: Colors.deepOrange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
