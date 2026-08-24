// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:webview_flutter/webview_flutter.dart';

// Future<void> _openReportInWebView(Map<String, dynamic> report) async {
//   final reportId = report['pat_diag_id'];
  
//   if (reportId == null) return;

//   final url = 'https://btkhospital.com/patientreports/Reports/ReportViewer.aspx'
//       '?lRptNo=19&lRptNm=Labrpt&lParam=$reportId';

//   final controller = WebViewController()
//     ..setJavaScriptMode(JavaScriptMode.unrestricted)
//     ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36') // Desktop user agent
//     ..setNavigationDelegate(
//       NavigationDelegate(
//         onPageStarted: (String url) {
//           print('Loading: $url');
//         },
//         onHttpError: (HttpResponseError error) {
//           print('HTTP Error: ${error.response?.statusCode}');
//         },
//         onWebResourceError: (error) {
//           print('WebView error: $error');
//         },
//       ),
//     )
//     ..loadRequest(Uri.parse(url));

//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => Scaffold(
//         appBar: AppBar(
//           title: Text(report['name'] ?? 'Report Viewer'),
//           backgroundColor: const Color(0xFF1FC9C0),
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.refresh),
//               onPressed: () {
//                 controller.reload();
//               },
//             ),
//           ],
//         ),
//         body: WebViewWidget(controller: controller),
//       ),
//     ),
//   );
// }