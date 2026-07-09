import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_on/core/utils/theme/theme_style.dart';
import 'package:ride_on/core/utils/translate.dart';
import 'package:ride_on/data/repositories/coupon_repository.dart';
import 'package:ride_on/domain/entities/coupon_data.dart';

class ShareAppScreen extends StatefulWidget {
  const ShareAppScreen({super.key});

  @override
  State<ShareAppScreen> createState() => _ShareAppScreenState();
}

class _ShareAppScreenState extends State<ShareAppScreen>
    with SingleTickerProviderStateMixin {
  static const String appLink =
      'https://play.google.com/store/apps/details?id=com.foxrunmobility.rider&pcampaignid=web_share';

  late String shareMessage =
      'Download FoxRun Ride App now and get your FIRST RIDE FREE\n\n$appLink';

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  
  final CouponRepository _couponRepository = CouponRepository();
  Coupon? _firstBookingCoupon;
  bool _couponLoading = true;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _fetchFirstBookingCoupon();
  }

  Future<void> _fetchFirstBookingCoupon() async {
    try {
      final response = await _couponRepository.getFirstBookingCoupon();
      if (mounted) {
        if (response['status'] == 200 && response['data'] != null) {
          final couponData = CouponData.fromJson(response['data']);
          if (couponData.coupon != null) {
            setState(() {
              _firstBookingCoupon = couponData.coupon;
              _couponLoading = false;
              // Update share message with coupon code
              shareMessage = 'Download FoxRun Ride App now and get your FIRST RIDE FREE with code: ${_firstBookingCoupon!.couponCode}\n\n$appLink';
            });
          } else {
            setState(() {
              _couponLoading = false;
              _couponError = 'Coupon not found';
            });
          }
        } else {
          setState(() {
            _couponLoading = false;
            _couponError = response['message'] ?? 'Failed to fetch coupon';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _couponLoading = false;
          _couponError = 'Error fetching coupon: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: shareMessage));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _shareSystem() async {
    await Share.share(shareMessage);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share sheet opened')),
    );
  }

  Future<void> _openWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(shareMessage)}',
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp opened')),
      );
      return;
    }

    await _shareSystem();
  }

  Future<void> _openSms() async {
    final Uri smsUri = Uri.parse('sms:?body=${Uri.encodeComponent(shareMessage)}');

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS app opened')),
      );
      return;
    }

    await _shareSystem();
  }

  void _copyCouponCode() async {
    if (_firstBookingCoupon != null) {
      await Clipboard.setData(ClipboardData(text: _firstBookingCoupon!.couponCode ?? ''));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Coupon code copied: ${_firstBookingCoupon!.couponCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundTop = isDark ? const Color(0xFF0E1220) : const Color(0xFFFFF9E6);
    final backgroundBottom = isDark ? const Color(0xFF1A2238) : const Color(0xFFFFECD1);
    final cardColor = isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.14);
    final borderColor = Colors.white.withOpacity(isDark ? 0.10 : 0.18);
    final textPrimary = isDark ? Colors.white : const Color(0xFF10213C);
    final textSecondary = isDark ? Colors.white.withOpacity(0.78) : const Color(0xFF10213C).withOpacity(0.7);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [backgroundTop, backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text(
                      'Share FoxRun'.translate(context),
                      style: headingBlack(context).copyWith(
                        color: textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroBanner(
                            logoAsset: 'assets/images/appIcon.png',
                            titleColor: textPrimary,
                            subtitleColor: textSecondary,
                          ),
                          const SizedBox(height: 20),
                          _GlassCard(
                            borderColor: borderColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Play Store Link'.translate(context),
                                  style: headingBlack(context).copyWith(
                                    color: textPrimary,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(isDark ? 0.06 : 0.12),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Text(
                                    appLink,
                                    style: heading3Grey1(context).copyWith(
                                      color: textSecondary,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.copy_rounded,
                                        label: 'Copy'.translate(context),
                                        backgroundColor: Colors.white.withOpacity(0.16),
                                        textColor: textPrimary,
                                        onTap: _copyLink,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.share_rounded,
                                        label: 'Share'.translate(context),
                                        backgroundColor: const Color(0xFFFFC533),
                                        textColor: const Color(0xFF10213C),
                                        onTap: _shareSystem,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // First Booking Coupon Section
                          if (_couponLoading)
                            _GlassCard(
                              borderColor: borderColor,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(textPrimary),
                                  ),
                                ),
                              ),
                            )
                          else if (_firstBookingCoupon != null)
                            _GlassCard(
                              borderColor: borderColor,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'First Booking Promo Code'.translate(context),
                                    style: headingBlack(context).copyWith(
                                      color: textPrimary,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFC533).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: const Color(0xFFFFC533).withOpacity(0.5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Code: ${_firstBookingCoupon!.couponCode}',
                                          style: headingBlack(context).copyWith(
                                            color: const Color(0xFFFFC533),
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${_firstBookingCoupon!.couponValue}% off on your first ride',
                                          style: heading3Grey1(context).copyWith(
                                            color: textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _ActionButton(
                                    icon: Icons.copy_rounded,
                                    label: 'Copy Promo Code'.translate(context),
                                    backgroundColor: const Color(0xFFFFC533).withOpacity(0.2),
                                    textColor: const Color(0xFFFFC533),
                                    onTap: _copyCouponCode,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _BigShareButton(
                                  icon: Icons.chat_rounded,
                                  label: 'WhatsApp',
                                  color: const Color(0xFF25D366),
                                  onTap: _openWhatsApp,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _BigShareButton(
                                  icon: Icons.sms_rounded,
                                  label: 'SMS',
                                  color: const Color(0xFF4DA3FF),
                                  onTap: _openSms,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _BigShareButton(
                            icon: Icons.more_horiz_rounded,
                            label: 'More Share Options',
                            color: Colors.white.withOpacity(0.14),
                            onTap: _shareSystem,
                            fullWidth: true,
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              'Terms & Conditions Apply'.translate(context),
                              style: heading3Grey1(context).copyWith(
                                color: Colors.white.withOpacity(0.62),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final String logoAsset;
  final Color titleColor;
  final Color subtitleColor;

  const _HeroBanner({
    required this.logoAsset,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFC533).withOpacity(0.40),
                    const Color(0xFFFFC533).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(logoAsset, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share FoxRun',
                          style: headingBlack(context).copyWith(
                            color: titleColor,
                            fontSize: 26,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Share the app and your friend can get a FREE first ride',
                          style: heading3Grey1(context).copyWith(
                            color: subtitleColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AspectRatio(
                aspectRatio: 1.95,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFC533).withOpacity(0.95),
                        const Color(0xFFFF8B4A).withOpacity(0.92),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Opacity(
                          opacity: 0.18,
                          child: Icon(
                            Icons.route_rounded,
                            size: 120,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'First Ride Free',
                            style: headingBlack(context).copyWith(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 130,
                          height: 86,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.18)),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.local_taxi_rounded,
                              size: 50,
                              color: Colors.white.withOpacity(0.92),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Invite friends • Earn rewards',
                            style: heading3Grey1(context).copyWith(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _GlassCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: headingBlack(context).copyWith(
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;

  const _BigShareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: headingBlack(context).copyWith(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.14),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}