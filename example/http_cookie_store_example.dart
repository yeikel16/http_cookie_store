import 'package:collection/collection.dart';
import 'package:http_cookie_store/http_cookie_store.dart';

void main() async {
  final client = CookieClient();

  await client.get(Uri.parse('https://www.nytimes.com/'));

  await client.get(Uri.parse('https://edition.cnn.com/'));

  groupBy(client.store.cookies, (c) => c.domain).forEach((key, value) {
    print("$key:");
    for (var cookie in value) {
      print('\t$cookie');
    }
  });

  print(client.store[CookieKey('geoData', Uri(host: 'cnn.com'))]);

  client.close();
}
