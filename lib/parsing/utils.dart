import 'package:http/http.dart' as http;

Future<http.Response> requestPage(
  http.Client client,
  http.Request request,
) async {
  final res = await client.send(request);
  final response = await http.Response.fromStream(res);
  if (response.statusCode == 302) {
    throw http.ClientException(
      'Request failed: ${response.statusCode}',
      request.url,
    );
  }
  return response;
}
