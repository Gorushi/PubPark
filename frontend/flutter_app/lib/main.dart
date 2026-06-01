import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        title: const Text("Test Kakao Map"),
      ),
        body: InAppWebView(
          initialData: InAppWebViewInitialData(
            data: '''
                  <!DOCTYPE html>
                  <html>
                  <head>
                  <meta charset="utf-8">
                  <meta name="viewport"
                        content="width=device-width, initial-scale=1.0">
                  
                  <script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=6ff5862f3b23c7383d8586db1f0f93c1&autoload=false"></script>
                  
                  <style>
                  html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                  }
                  
                  #map {
                    width: 100%;
                    height: 100%;
                  }
                  </style>
                  </head>
                  
                  <body>
                  
                  <div id="map"></div>
                  
                  <script>
                  kakao.maps.load(function(){

                      var container = document.getElementById('map');

                      var options = {
                          center: new kakao.maps.LatLng(36.6358, 127.4914),
                          level: 3
                      };

                      var map = new kakao.maps.Map(container, options);

                  });
                  </script>
                                    
                  </body>
                  </html>
                  ''',
          ),

        )
    );
  }
}