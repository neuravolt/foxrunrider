import 'package:flutter/material.dart';
import '../../core/services/data_store.dart';
import '../../core/utils/theme/project_color.dart';
import '../../core/utils/translate.dart';

void showParcelComingSoonSheet(BuildContext context, {String type = 'parcel'}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ParcelComingSoonSheet(type: type),
  );
}

class ParcelComingSoonSheet extends StatefulWidget {
  final String type;
  const ParcelComingSoonSheet({super.key, this.type = 'parcel'});

  @override
  State<ParcelComingSoonSheet> createState() => _ParcelComingSoonSheetState();
}

class _ParcelComingSoonSheetState extends State<ParcelComingSoonSheet> {
  bool isNotified = false;

  bool get isRental => widget.type.toLowerCase().contains('rental');

  @override
  void initState() {
    super.initState();
    final boxKey = isRental ? "rental_waitlist_registered" : "parcel_waitlist_registered";
    isNotified = box.get(boxKey) == true;
  }

  void _handleNotifyMe() {
    setState(() {
      isNotified = true;
    });
    final boxKey = isRental ? "rental_waitlist_registered" : "parcel_waitlist_registered";
    box.put(boxKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3D Delivery or Bike Rental Graphic with Soft Glow
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFB300).withValues(alpha: 0.25),
                  const Color(0xFFFF8F00).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.4, 0.75, 1.0],
              ),
            ),
            child: Center(
              child: Image.asset(
                isRental ? 'assets/images/BIKE.png' : 'assets/images/parcel_box.png',
                width: isRental ? 95 : 90,
                height: isRental ? 95 : 90,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Launch Date Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  "Coming Soon on 16 October 2026".translate(context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            (isRental ? "FoxRun Bike Rental" : "FoxRun Parcel Delivery").translate(context),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2022),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            (isRental
                    ? "Rent self-drive bikes & scooters on flexible hourly or daily plans with zero fuel hassle."
                    : "Send packages, documents & daily essentials anywhere across town with trusted FoxRun delivery pilots.")
                .translate(context),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // 3 Feature Highlights
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9F0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
            ),
            child: Column(
              children: isRental
                  ? [
                      _buildFeatureRow(
                        Icons.two_wheeler_rounded,
                        "Flexible Hourly & Daily Plans",
                        "Affordable self-drive rates tailored to your trip",
                        const Color(0xFFE65100),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFFFE0B2)),
                      ),
                      _buildFeatureRow(
                        Icons.verified_user_rounded,
                        "Zero Security Deposit",
                        "Ride freely with instant paperless digital verification",
                        const Color(0xFF2E7D32),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFFFE0B2)),
                      ),
                      _buildFeatureRow(
                        Icons.electric_moped_rounded,
                        "Well-Maintained & Inspected",
                        "Sanitized two-wheelers with safety helmets provided",
                        const Color(0xFF1565C0),
                      ),
                    ]
                  : [
                      _buildFeatureRow(
                        Icons.doorbell_outlined,
                        "Doorstep Pickup & Drop",
                        "Pilot reaches your location within minutes",
                        const Color(0xFFE65100),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFFFE0B2)),
                      ),
                      _buildFeatureRow(
                        Icons.security_rounded,
                        "Safe & OTP-Verified",
                        "Secure delivery with secret handover PIN",
                        const Color(0xFF2E7D32),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFFFE0B2)),
                      ),
                      _buildFeatureRow(
                        Icons.gps_fixed_rounded,
                        "Live Package Tracking",
                        "Watch your parcel travel in real-time on map",
                        const Color(0xFF1565C0),
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isNotified
                ? Container(
                    key: const ValueKey('notified'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "You're on the early-access list!"
                              .translate(context),
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    key: const ValueKey('button'),
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleNotifyMe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.notifications_active_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Notify Me on 16 Oct 2026".translate(context),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),

          // Dismiss Button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Got it".translate(context),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.translate(context),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle.translate(context),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
