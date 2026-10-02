import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TimetableApp());
}

class TimetableApp extends StatelessWidget {
  const TimetableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جدول توزيع الحصص',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1D6B78),
      ),
      home: const AppPage(),
    );
  }
}

class AppPage extends StatefulWidget {
  const AppPage({super.key});

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  late final WebViewController _c;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF17324D),
      statusBarIconBrightness: Brightness.light,
    ));

    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEEF2F5))
      ..addJavaScriptChannel('FlutterBridge', onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _ready = true),
        // لا يُسمح بفتح أي روابط خارجية داخل التطبيق
        onNavigationRequest: (req) => req.url.startsWith('https://app.local') ||
                req.url.startsWith('about:') ||
                req.url.startsWith('data:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));

    // اختيار الملفات (استعادة نسخة احتياطية / شعار المدرسة) على أندرويد
    final p = _c.platform;
    if (p is AndroidWebViewController) {
      p.setOnShowFileSelector(_pickFile);
    }
    _load();
  }

  Future<void> _load() async {
    final html = await rootBundle.loadString('assets/app.html');
    // أصل ثابت (origin) لضمان بقاء بيانات localStorage بين مرات التشغيل
    await _c.loadHtmlString(html, baseUrl: 'https://app.local/');
  }

  Future<List<String>> _pickFile(FileSelectorParams params) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = r?.files.single.path;
    if (path == null) return [];
    return [Uri.file(path).toString()];
  }

  void _toast(String msg) {
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(msg)));
  }

  /// الرسائل القادمة من صفحة البرنامج: حفظ/مشاركة ملف، أو طباعة.
  Future<void> _onMessage(String raw) async {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      switch (m['type']) {
        case 'file':
          final dir = await getTemporaryDirectory();
          final name = (m['name'] as String).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final f = File('${dir.path}/$name');
          await f.writeAsBytes(base64Decode(m['b64'] as String));
          await Share.shareXFiles(
            [XFile(f.path, mimeType: m['mime'] as String?)],
            subject: name,
          );
          break;
        case 'print':
          var fmt = (m['paper'] == 'A3') ? PdfPageFormat.a3 : PdfPageFormat.a4;
          if (m['orient'] == 'landscape') fmt = fmt.landscape;
          final html = m['html'] as String;
          await Printing.layoutPdf(
            name: 'جدول الحصص',
            format: fmt,
            onLayout: (f) => Printing.convertHtml(format: f, html: html),
          );
          break;
      }
    } catch (e) {
      _toast('تعذر تنفيذ العملية: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messenger,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          // زر الرجوع: يغلق القائمة/النافذة إن وُجدت ثم يخرج
          final closed = await _c.runJavaScriptReturningResult(
              "(function(){var r=document.getElementById('modalRoot');if(r&&r.classList.contains('on')){closeModal();return 1}"
              "var s=document.getElementById('side');if(s&&s.classList.contains('open')){s.classList.remove('open');return 1}return 0})()");
          if ('$closed' != '1') SystemNavigator.pop();
        },
        child: Scaffold(
          body: SafeArea(
            child: Stack(children: [
              WebViewWidget(controller: _c),
              if (!_ready) const Center(child: CircularProgressIndicator()),
            ]),
          ),
        ),
      ),
    );
  }
}
