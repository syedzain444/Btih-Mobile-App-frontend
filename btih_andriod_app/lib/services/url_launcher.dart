// import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter/material.dart';
// Future<void> _openReportUrl(String url, BuildContext context) async {
//   try {
//     final Uri uri = Uri.parse(url);
    
//     if (await canLaunchUrl(uri)) {
//       await launchUrl(
//         uri,
//         mode: LaunchMode.externalApplication,
//       );
//     } else {
//       // Show error if URL can't be launched
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Could not open report URL'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   } catch (e) {
//     if (context.mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error opening report: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }
// }