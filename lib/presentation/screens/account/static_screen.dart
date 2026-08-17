import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:ride_on/core/utils/translate.dart';
import '../../../core/utils/common_widget.dart';
import '../../../core/utils/theme/theme_style.dart';
import '../../cubits/static_page.dart';

class StaticScreen extends StatefulWidget {
  final String data;
  final bool? isBack;
  const StaticScreen({super.key, required this.data, this.isBack});

  @override
  State<StaticScreen> createState() => _StaticScreenState();
}

class _StaticScreenState extends State<StaticScreen> {
  String _contentHtml = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaticPageCubits>().getStaticData(context, data: widget.data);
    });
  }

  String _sanitizeContent(String raw) {
    if (raw.isEmpty) return raw;
    String text = raw;

    // Fix contraction apostrophes (it?s -> it's, you?re -> you're, we?re -> we're, etc.)
    text = text.replaceAllMapped(
      RegExp(r'(\b\w+)\?([s|re|ve|m|ll|d|t]\b)', caseSensitive: false),
      (m) => "${m[1]}'${m[2]}",
    );

    // Specific section header icon fixes
    text = text.replaceAll('? Key Features:', '✨ Key Features:');
    text = text.replaceAll('? Contact Us:', '📞 Contact Us:');
    text = text.replaceAll('? Phone & WhatsApp Support:', '📞 Phone & WhatsApp Support:');
    text = text.replaceAll('? Email:', '✉️ Email:');

    // Bullet point fixes
    text = text.replaceAll('? Instant Ride Booking ?', '• Instant Ride Booking:');
    text = text.replaceAll('? Live Driver Tracking ?', '• Live Driver Tracking:');
    text = text.replaceAll('? Multiple Vehicle Choices ?', '• Multiple Vehicle Choices:');
    text = text.replaceAll('? Transparent Fare Estimates ?', '• Transparent Fare Estimates:');
    text = text.replaceAll('? Verified Drivers ?', '• Verified Drivers:');
    text = text.replaceAll('? Trip History ?', '• Trip History:');
    text = text.replaceAll('? 24/7 Support ?', '• 24/7 Support:');

    // Fix dashes between words (e.g., "destination ? whether" -> "destination — whether")
    text = text.replaceAllMapped(
      RegExp(r'(\w+)\s*\?\s*(\w+)'),
      (m) => "${m[1]} — ${m[2]}",
    );

    // Replace line-start or standalone '?' bullet points with clean bullet character '•'
    text = text.replaceAll(RegExp(r'^\s*\?\s*', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'<p>\s*\?\s*'), '<p>• ');
    text = text.replaceAll(RegExp(r'<br\s*/?>\s*\?\s*'), '<br/>• ');
    text = text.replaceAllMapped(
      RegExp(r'\?\s*(<b>|<strong>)'),
      (m) => "• ${m[1]}",
    );

    return text;
  }

  IconData _getHeaderIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains("about")) return Icons.info_outline_rounded;
    if (lower.contains("terms") || lower.contains("condition")) return Icons.gavel_rounded;
    if (lower.contains("privacy") || lower.contains("policy")) return Icons.shield_outlined;
    if (lower.contains("help") || lower.contains("support")) return Icons.help_outline_rounded;
    return Icons.article_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.data.translate(context);
    final headerIcon = _getHeaderIcon(widget.data);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.isBack == true) {
          goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFFDF7),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: widget.isBack == true
              ? IconButton(
                  onPressed: () => goBack(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF1E1E1E),
                    size: 18,
                  ),
                )
              : null,
          title: Text(
            pageTitle,
            style: heading2(context).copyWith(
              color: const Color(0xFF1E1E1E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: BlocBuilder<StaticPageCubits, StaticPageState>(
          builder: (context, state) {
            if (state is StaticPageLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF59E0B),
                ),
              );
            } else if (state is StaticPageSuccess) {
              _contentHtml = _sanitizeContent(
                state.staticModel.data?.staticPage?.content ??
                    "Content not available".translate(context),
              );
            } else if (state is StaticPageFailure) {
              showErrorToastMessage(state.error);
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    // Top Hero Banner Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFF9EB),
                            Color(0xFFFFF0C2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x22F59E0B),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              headerIcon,
                              color: const Color(0xFFD98A00),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pageTitle,
                                  style: heading1(context).copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E1E1E),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "FoxRun Rider Official Information".translate(context),
                                  style: regular2(context).copyWith(
                                    fontSize: 12,
                                    color: const Color(0xFF78350F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main Content Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF1F5F9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: flutter_html.Html(
                        data: _contentHtml,
                        style: {
                          "body": flutter_html.Style(
                            color: const Color(0xFF334155),
                            fontSize: flutter_html.FontSize(14.5),
                            lineHeight: const flutter_html.LineHeight(1.6),
                            margin: flutter_html.Margins.zero,
                            padding: flutter_html.HtmlPaddings.zero,
                          ),
                          "p": flutter_html.Style(
                            margin: flutter_html.Margins.only(bottom: 12),
                            fontSize: flutter_html.FontSize(14.5),
                            lineHeight: const flutter_html.LineHeight(1.6),
                          ),
                          "h1": flutter_html.Style(
                            color: const Color(0xFF0F172A),
                            fontSize: flutter_html.FontSize(18),
                            fontWeight: FontWeight.bold,
                            margin: flutter_html.Margins.only(top: 14, bottom: 8),
                          ),
                          "h2": flutter_html.Style(
                            color: const Color(0xFF0F172A),
                            fontSize: flutter_html.FontSize(16),
                            fontWeight: FontWeight.bold,
                            margin: flutter_html.Margins.only(top: 12, bottom: 6),
                          ),
                          "h3": flutter_html.Style(
                            color: const Color(0xFF0F172A),
                            fontSize: flutter_html.FontSize(15),
                            fontWeight: FontWeight.bold,
                            margin: flutter_html.Margins.only(top: 10, bottom: 6),
                          ),
                          "strong": flutter_html.Style(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                          ),
                          "b": flutter_html.Style(
                            color: const Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                          ),
                          "ul": flutter_html.Style(
                            padding: flutter_html.HtmlPaddings.only(left: 16),
                            margin: flutter_html.Margins.only(bottom: 12),
                          ),
                          "li": flutter_html.Style(
                            margin: flutter_html.Margins.only(bottom: 6),
                          ),
                          "a": flutter_html.Style(
                            color: const Color(0xFFD98A00),
                            textDecoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
