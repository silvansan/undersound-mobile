import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ablaut_app/services/listener_link_parser.dart';
import 'package:ablaut_app/services/undersound_api_client.dart';

void main() {
  test('verify-password parses session token response', () async {
    final client = _MockClient(onPost: (url, {headers, body}) async {
      expect(url.path, '/api/listener/verify-password');
      final decoded = jsonDecode(body as String) as Map<String, dynamic>;
      expect(decoded['eventSlug'], 'evt');
      expect(decoded['channelSlug'], 'en');
      expect(decoded['password'], 'secret');
      return http.Response(
        jsonEncode({
          'ok': true,
          'required': true,
          'listenerSessionToken': 'session-token',
          'expiresIn': 3600,
        }),
        200,
      );
    });

    final api = UnderSoundApiClient(httpClient: client);
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/listen/evt/en',
    );
    final response = await api.verifyListenerPassword(
      link: link,
      password: 'secret',
    );

    expect(response.ok, isTrue);
    expect(response.listenerSessionToken, 'session-token');
    expect(response.expiresIn, 3600);
  });

  test('listener-token includes session token in body and header', () async {
    final client = _MockClient(onPost: (url, {headers, body}) async {
      expect(url.path, '/api/livekit/listener-token');
      expect(headers?['X-Ablaut-Listener-Session'], 'session-token');
      final decoded = jsonDecode(body as String) as Map<String, dynamic>;
      expect(decoded['listenerSessionToken'], 'session-token');
      return http.Response(
        jsonEncode({'url': 'wss://lk.example.com', 'token': 'jwt'}),
        200,
      );
    });

    final api = UnderSoundApiClient(httpClient: client);
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/listen/evt/en',
    );
    final response = await api.fetchListenerToken(
      link: link,
      listenerSessionToken: 'session-token',
    );

    expect(response.url, 'wss://lk.example.com');
    expect(response.token, 'jwt');
  });

  test('verify-password maps 401 to wrong password message', () async {
    final client = _MockClient(onPost: (_, {headers, body}) async {
      return http.Response(jsonEncode({'error': 'Unauthorized'}), 401);
    });

    final api = UnderSoundApiClient(httpClient: client);
    final link = ListenerLinkParser.parse(
      'https://voice.example.com/listen/evt/en',
    );

    expect(
      api.verifyListenerPassword(link: link, password: 'bad'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  });
}

class _MockClient implements http.Client {
  _MockClient({required this.onPost});

  final Future<http.Response> Function(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) onPost;

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return onPost(url, headers: headers, body: body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
