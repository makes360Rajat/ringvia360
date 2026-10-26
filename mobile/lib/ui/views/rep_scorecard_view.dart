import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RepScorecardView extends StatelessWidget {
  const RepScorecardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sales Scorecard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rep Profile Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.bgSurfaceElevated, AppColors.bgSurface],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      image: const DecorationImage(
                        image: NetworkImage('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rajesh Kumar',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textMain),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Senior Enterprise AE • Rank #1',
                          style: TextStyle(fontSize: 12, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accentAmber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, size: 16, color: AppColors.accentAmber),
                        SizedBox(width: 4),
                        Text(
                          '14 Days',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentAmber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Daily Target Progress Ring
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TODAY\'S CALL TARGET',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                      ),
                      Text(
                        '38 / 40 Calls',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const LinearProgressIndicator(
                      value: 0.95,
                      minHeight: 10,
                      backgroundColor: AppColors.bgSurfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentEmerald),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '2 more calls to complete daily streak!',
                      style: TextStyle(fontSize: 11, color: AppColors.accentEmerald),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Scorecard Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: const [
                _ScoreCardTile(
                  icon: Icons.phone_in_talk,
                  color: AppColors.primary,
                  title: 'Talk Time Today',
                  value: '184 min',
                  subtitle: 'Avg 4.8 min/call',
                ),
                _ScoreCardTile(
                  icon: Icons.check_circle_outline,
                  color: AppColors.accentEmerald,
                  title: 'Conversion Rate',
                  value: '28.5%',
                  subtitle: '+4.2% this week',
                ),
                _ScoreCardTile(
                  icon: Icons.monetization_on_outlined,
                  color: AppColors.accentAmber,
                  title: 'Pipeline Influenced',
                  value: '\$148,000',
                  subtitle: '4 deals closed won',
                ),
                _ScoreCardTile(
                  icon: Icons.security,
                  color: AppColors.accentCyan,
                  title: 'Compliance Score',
                  value: '100%',
                  subtitle: 'E2EE & Consent OK',
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Badges & Achievements
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EARNED ACHIEVEMENTS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textDim),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _BadgePill(title: 'Top Performer', icon: Icons.star, color: AppColors.accentAmber),
                      _BadgePill(title: 'Speed Demon', icon: Icons.bolt, color: AppColors.accentCyan),
                      _BadgePill(title: 'Objection Crusher', icon: Icons.shield, color: AppColors.primary),
                      _BadgePill(title: 'Knox E2EE Certified', icon: Icons.lock, color: AppColors.accentEmerald),
                    ],
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

class _ScoreCardTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;

  const _ScoreCardTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: AppColors.textDim, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textMain),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _BadgePill({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
