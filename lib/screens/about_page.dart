import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    const appBlue = Color(0xFF1565C0);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: appBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: const Row(
                children: [
                  Icon(
                    Icons.wc,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'PottyPal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: const Color(0xFFF5F5F5),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: appBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/pottypal-logo.webp',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'PottyPal',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          'PottyPal is a user-powered public restroom finder designed to help you locate, rate, and review nearby facilities in real time. Instantly search or add restrooms, check ratings and amenities, upload photos to confirm cleanliness, and navigate easily using our mapping system. With PottyPal, you always know where to go when you need it most.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Benefits',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _BenefitItem(
                              text:
                                  'Quickly find clean and accessible restrooms wherever you are.',
                            ),
                            const SizedBox(height: 16),
                            _BenefitItem(
                              text:
                                  'Share ratings, reviews, and photos to help the community',
                            ),
                            const SizedBox(height: 16),
                            _BenefitItem(
                              text:
                                  'Enjoy peace of mind, better convenience, and better community hygiene every day.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Credits',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Developed by the PottyPal Team:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _CreditName(
                                        name: 'James Jethro Dizon',
                                      ),
                                      const SizedBox(height: 12),
                                      _CreditName(
                                        name: 'Charles Daniel Garcia',
                                      ),
                                      const SizedBox(height: 12),
                                      _CreditName(
                                        name: 'Ericka Mae Gavino',
                                      ),
                                      const SizedBox(height: 12),
                                      _CreditName(
                                        name: 'Carla Joves',
                                      ),
                                      const SizedBox(height: 12),
                                      _CreditName(
                                        name: 'Alexander Manabat',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;

  const _BenefitItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2, right: 12),
          child: Icon(
            Icons.check_circle,
            color: Color(0xFF4CAF50),
            size: 20,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreditName extends StatelessWidget {
  final String name;

  const _CreditName({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
