import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createGeminiHttpClient() {
  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 60)
    ..idleTimeout = const Duration(seconds: 120);

  return IOClient(httpClient);
}
