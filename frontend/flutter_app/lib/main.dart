
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const MyApp());
}

// assets/map.html 파일 읽기
Future<String> loadHtml() async {
  return rootBundle.loadString('assets/map.html');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: KakaoMapScreen(),
    );
  }
}

class KakaoMapScreen extends StatelessWidget {
  const KakaoMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Kakao Map'),
      ),
      body: FutureBuilder<String>(
        future: loadHtml(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('HTML 로드 실패: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return InAppWebView(
            initialData: InAppWebViewInitialData(
              data: snapshot.data!,
            ),
          );
        },
      ),
    );
  }
}
