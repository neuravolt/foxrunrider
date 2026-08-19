import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:ride_on/core/utils/translate.dart';
import '../../../core/services/data_store.dart';
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

  String _sanitizeContent(String raw, String title) {
    final lang = lanBox.get('lCode') ?? 'en';
    final lowerTitle = title.toLowerCase();

    if (lang == 'hi') {
      if (lowerTitle.contains("about") || lowerTitle.contains("हमारे बारे")) {
        return '''
<p><strong>FoxRun बाइक और टैक्सी के साथ आसान राइड बुकिंग</strong></p>
<p>FoxRun ऐप दैनिक यात्रियों, पर्यटकों और तेज़ तथा विश्वसनीय परिवहन की तलाश करने वाले किसी भी व्यक्ति के लिए डिज़ाइन किया गया एक सहज और स्मार्ट राइड बुकिंग अनुभव प्रदान करता है। बस कुछ ही टैप में, आप अपने वर्तमान स्थान से किसी भी गंतव्य के लिए राइड बुक कर सकते हैं — चाहे वह शहर की छोटी यात्रा हो या लंबी दूरी का सफर।</p>

<p><strong>✨ मुख्य विशेषताएं:</strong></p>
<p>• <strong>तुरंत राइड बुकिंग:</strong> अपने पिकअप और ड्रॉप-ऑफ स्थान दर्ज करें और सेकंडों में पास के ड्राइवर से जुड़ें।</p>
<p>• <strong>लाइव ड्राइवर ट्रैकिंग:</strong> मैप पर रियल-टाइम में अपने ड्राइवर को आते हुए देखें।</p>
<p>• <strong>विभिन्न वाहन विकल्प:</strong> अपनी आवश्यकताओं और आराम के आधार पर बाइक, ऑटो और कैब में से चुनें।</p>
<p>• <strong>पारदर्शी किराया अनुमान:</strong> राइड की पुष्टि करने से पहले यात्रा का स्पष्ट किराया जानें — कोई छिपा हुआ शुल्क नहीं।</p>
<p>• <strong>सत्यापित ड्राइवर:</strong> आपकी सुरक्षा के लिए सभी ड्राइवरों का पुलिस सत्यापन और प्रशिक्षण किया जाता है।</p>
<p>• <strong>यात्रा इतिहास:</strong> सीधे अपने खाते से अपनी पिछली सभी राइड्स देखें।</p>
<p>• <strong>24/7 ग्राहक सहायता:</strong> यात्रा के दौरान किसी भी समस्या के समाधान के लिए हम हमेशा उपलब्ध हैं।</p>

<br/>
<p><strong>📞 संपर्क करें:</strong></p>
<p>• <strong>फोन और व्हाट्सएप सहायता:</strong> +91 02269620985</p>
<p>• <strong>ईमेल:</strong> Contact@foxrun.in</p>
''';
      } else if (lowerTitle.contains("help") ||
          lowerTitle.contains("support") ||
          lowerTitle.contains("सहायता") ||
          lowerTitle.contains("समर्थन")) {
        return '''
<p><strong>सहायता और समर्थन — हम आपकी मदद के लिए हमेशा तत्पर हैं</strong></p>
<p>चाहे आप FoxRun <strong>राइडर ऐप</strong> से राइड बुक कर रहे हों या FoxRun <strong>ड्राइवर ऐप</strong> से ड्राइव कर रहे हों, हमारी सहायता टीम आपके अनुभव को सुरक्षित, सुचारू और तनावमुक्त बनाने के लिए हमेशा तैयार है।</p>

<br/>
<p><strong>📞 संपर्क साधन:</strong></p>
<p><strong>✉️ ईमेल सहायता</strong></p>
<p>• <strong>Contact@foxrun.in</strong><br/>कोई प्रश्न है या सहायता चाहिए? हमें कभी भी ईमेल भेजें। हमारी टीम 24 घंटे के भीतर उत्तर देती है।</p>

<br/>
<p><strong>📞 फोन एवं व्हाट्सएप सहायता</strong></p>
<p>• <strong>+91 02269620985</strong><br/>सीधे बात करने के लिए कार्य समय के दौरान हमारे सहायता नंबर पर कॉल करें।</p>

<br/>
<p><strong>❓ अक्सर पूछे जाने वाले प्रश्न (FAQs)</strong></p>
<p><strong>1. मैं अपनी प्रोफ़ाइल जानकारी कैसे अपडेट करूँ?</strong><br/>
<strong>राइडर्स:</strong> साइड मेनू में <strong>प्रोफ़ाइल</strong> पर जाएँ — अपना नाम, नंबर या फोटो बदलें — <strong>सहेजें</strong> पर टैप करें।<br/>
<strong>ड्राइवर्स:</strong> मेनू में <strong>प्रोफ़ाइल</strong> खोलें — व्यक्तिगत एवं वाहन विवरण अपडेट करें — सहेजें।</p>

<br/>
<p><strong>2. मैं किसी समस्या या बग की रिपोर्ट कैसे करूँ?</strong><br/>
ऐप के <strong>सहायता और समर्थन</strong> विकल्प का उपयोग करें या अपनी समस्या का विवरण/स्क्रीनशॉट <strong>Contact@foxrun.in</strong> पर भेजें। हमारी तकनीकी टीम तुरंत कार्रवाई करेगी।</p>
''';
      } else if (lowerTitle.contains("terms") ||
          lowerTitle.contains("privacy") ||
          lowerTitle.contains("condition") ||
          lowerTitle.contains("नियम") ||
          lowerTitle.contains("शर्त")) {
        return '''
<p><strong>नियम, शर्तें एवं गोपनीयता नीति</strong></p>
<p>FoxRun का उपयोग करने के लिए धन्यवाद। हमारी सेवाएं आपकी सुरक्षा, गोपनीयता और सर्वोत्तम यात्रा अनुभव के लिए प्रतिबद्ध हैं। ऐप का उपयोग करने पर निम्नलिखित शर्तें लागू होती हैं:</p>

<p>• <strong>1. खाता सुरक्षा:</strong> उपयोगकर्ताओं को अपनी प्रोफ़ाइल जानकारी सटीक रखनी होगी।</p>
<p>• <strong>2. राइड बुकिंग एवं किराया:</strong> बुकिंग से पहले दिखाया गया किराया अंतिम होता है। यात्रा समाप्ति पर भुगतान अनिवार्य है।</p>
<p>• <strong>3. रद्दीकरण नीति:</strong> यदि आवश्यक हो तो आप राइड रद्द कर सकते हैं। बार-बार रद्द करने पर शुल्क लग सकता है।</p>
<p>• <strong>4. व्यवहार एवं सुरक्षा:</strong> राइडर और ड्राइवर दोनों से एक-दूसरे के प्रति सम्मानजनक व्यवहार की अपेक्षा की जाती है।</p>

<br/>
<p><strong>📞 संपर्क:</strong> नियमों से संबंधित किसी भी प्रश्न के लिए Contact@foxrun.in पर संपर्क करें।</p>
''';
      }
    }

    if (raw.isEmpty) return raw;
    String text = raw;

    // Clean broken character encoding questions (?)
    text = text.replaceAllMapped(
      RegExp(r'(\b\w+)\?([s|re|ve|m|ll|d|t]\b)', caseSensitive: false),
      (m) => "${m[1]}'${m[2]}",
    );

    text = text.replaceAll('? Key Features:', '✨ Key Features:');
    text = text.replaceAll('? Contact Us:', '📞 Contact Us:');
    text = text.replaceAll('? Phone & WhatsApp Support:', '📞 Phone & WhatsApp Support:');
    text = text.replaceAll('? Email Support', '✉️ Email Support');
    text = text.replaceAll('? Email:', '✉️ Email:');

    text = text.replaceAll('? Instant Ride Booking ?', '• Instant Ride Booking:');
    text = text.replaceAll('? Live Driver Tracking ?', '• Live Driver Tracking:');
    text = text.replaceAll('? Multiple Vehicle Choices ?', '• Multiple Vehicle Choices:');
    text = text.replaceAll('? Transparent Fare Estimates ?', '• Transparent Fare Estimates:');
    text = text.replaceAll('? Verified Drivers ?', '• Verified Drivers:');
    text = text.replaceAll('? Trip History ?', '• Trip History:');
    text = text.replaceAll('? 24/7 Support ?', '• 24/7 Support:');

    text = text.replaceAllMapped(
      RegExp(r'(\w+)\s*\?\s*(\w+)'),
      (m) => "${m[1]} — ${m[2]}",
    );

    text = text.replaceAll(RegExp(r'^\s*\?\s*', multiLine: true), '• ');
    text = text.replaceAll(RegExp(r'<p>\s*\?\s*'), '<p>• ');
    text = text.replaceAll(RegExp(r'<br\s*/?>\s*\?\s*'), '<br/>• ');
    text = text.replaceAllMapped(
      RegExp(r'\?\s*(<b>|<strong>)'),
      (m) => "• ${m[1]}",
    );
    text = text.replaceAll(RegExp(r'\s*\?\s*$'), '');

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
                widget.data,
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
