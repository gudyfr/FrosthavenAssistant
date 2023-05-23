import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:process_run/shell.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Forteller {
  static const String API_KEY = "AIzaSyAs2zSk1Xx-yq6pu4GNCqOUPLuCD1HPDYo";
  static const String SUB_KEY = "d025d5c78feb48fe9331d8f7efc87ea0";

  final String email;
  final String password;

  String? accessToken;
  String? refreshToken;

  Forteller(this.email, this.password) {
    login();
  }

  Future<bool> login() async {
    print("Login in");
    Map<String, String> headers = {
      "content-type": "application/json",
      "Forteller-Subscription-Key": SUB_KEY
    };

    Map<String, dynamic> data = {
      "email": email,
      "password": password,
      "returnSecureToken": true
    };

    final response = await http.post(
        Uri.parse(
            "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=AIzaSyAs2zSk1Xx-yq6pu4GNCqOUPLuCD1HPDYo"),
        headers: headers,
        body: jsonEncode(data));

    if (response.statusCode == 200) {
      var result = jsonDecode(response.body);
      accessToken = result["idToken"];
      return true;
    }

    return false;
  }

  Future<Catalog> getCatalog() async {
    var json = await apiCall("https://api.forteller.io/catalog/games");
    return Catalog.fromJson(json);
  }

  Future<List<Chapter>> getChapters(String gameId) async {
    var json = await apiCall(
        "https://api.forteller.io/catalog/games/$gameId/containers");
    return (json as List).map((entry) => Chapter.fromJson(entry)).toList();
  }

  Future<Playlist> getPlaylist(String gameId, String chapterId) async {
    var json = await apiCall(
        "https://api.forteller.io/catalog/games/$gameId/containers/$chapterId/playlist");
    return Playlist.fromJson(json);
  }

  Future<String?> getStreamKey(String trackLocatorId, String playlistId) async {
    String? result;
    do {
      var json = await apiCall(
          "https://api.forteller.io/media/streamkey/$trackLocatorId?playlistId=$playlistId");
      if(json == false) {
        return null;
      }
      result = json["token"] as String?;
      if (result == null) {
        print("Got a null Stream key, waiting 10 seconds");
        sleep(const Duration(seconds: 10));
      }
    } while (result == null);
    return result;
  }

  Future<void> getMedia(String playlistUrl, String trackLocatorId,
      String playlistId, File out) async {
    var token = await getStreamKey(trackLocatorId, playlistId);
    if(token != null) {
      var cmd =
          "-headers \"Authorization: Bearer $token\" -i \"${playlistUrl
          .replaceAll(" ",
          "%20")}(format=m3u8-aapl,encryption=cbc,type=audio)\" -v error -b:a 192k \"${out
          .path}\"";
      if(Platform.isWindows || Platform.isLinux) {
        var shell = Shell(stdout: stdout, commandVerbose: false);
        await shell.run("ffmpeg $cmd");
      } else {
        await FFmpegKit.execute(cmd);
      }
      var stat = await out.stat();
      print("Got ${stat.size} bytes");
    }
    return;
  }

  dynamic apiCall(String url) async {
    Map<String, String> headers = {
      "Authorization": "Bearer ${accessToken}",
      "Forteller-Subscription-Key": SUB_KEY,
    };
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode != 200) {
      print(
          "Got statusCode ${response.statusCode} on api call $url (${response.body})");
      if (response.statusCode == 429) {
        //print(response.headers);
        int retryAfter = int.parse(response.headers["retry-after"] ?? "5");
        await Future.delayed(Duration(seconds: retryAfter));
      } else {
        // We got de-authenticated, let's re-authenticate
        if (! await login()) {
          print("Could not login, aborting");
          throw Exception("Could not login");
        }
        // Try again
      }
      return apiCall(url);
    }
    // print(response.body);

    return jsonDecode(response.body);
  }
}

class Playlist {
  final String id; //": "0d4bf57f-6fe6-43ff-8e5a-a3b6139f6036",
  final String containerId; //": "6b4b1ae8-b5c8-45bd-a2fc-955d104b2290",
  final String gameId; //": "8a7596e2-ab72-482a-95be-0083145b9d36",
  final List<Track> content; //": [

  Playlist(this.id, this.containerId, this.gameId, this.content);

  factory Playlist.fromJson(dynamic json) {
    return Playlist(
        json["id"] as String,
        json["containerId"] as String,
        json["gameId"] as String,
        (json["content"] as List).map((e) => Track.fromJson(e)).toList());
  }
}

class Track {
  final String id; //"b4d1b785-a2ab-425e-932e-aab05e52e4cc",
  final String title; //": "Introduction",
  final Asset asset;
  final Transition transition;

  Track(this.id, this.title, this.asset, this.transition);

  factory Track.fromJson(dynamic json) {
    return Track(json["id"] as String, json["title"] as String,
        Asset.fromJson(json["asset"]), Transition.fromJson(json["transition"]));
  }

  @override
  String toString() {
    return '{'
        '"id":"$id"'
        '}';
  }
}

class Asset {
  final String id; //": "ef1dc89a-c8df-44a2-94c3-1c64ff0bb042",
  final String name; //": "FH_134_TowerOfKnowledge_Intro_v2.wav",
  final String contentType; //": "Audio",
  final String
      streamUrl; //": "https://fortellermedia-usct.streaming.media.azure.net/ce0769b6-b1e9-4e25-afc1-2123973a1f83/FH_134_TowerOfKnowledge_Intro_v2.ism/manifest",
  final int duration; //": 109,
  final String sku; //": "ceph_fh",
  final String locatorId; //": "ce0769b6-b1e9-4e25-afc1-2123973a1f83",
  final String locatorName; //": "loc-3ea5a8d9-ecb4-483a-a48a-3df95ebc3048",
  final String requiredKeyPolicyId; //": "f17d0675-32b5-487a-8c52-38ef682ca9d0"

  Asset(this.id, this.name, this.contentType, this.streamUrl, this.duration,
      this.sku, this.locatorId, this.locatorName, this.requiredKeyPolicyId);

  factory Asset.fromJson(dynamic json) {
    return Asset(
        json["id"] as String,
        json["name"] as String,
        json["contentType"] as String,
        json["streamUrl"] as String,
        json["duration"] as int,
        json["sku"] as String,
        json["locatorId"] as String,
        json["locatorName"] as String,
        json["requiredKeyPolicyId"] as String);
  }

  @override
  String toString() {
    return '{"id": "$id", '
        '"name": "$name", '
        '"contentType": "$contentType", '
        '"streamUrl": "$streamUrl", '
        '"duration": $duration, '
        '"sku": "$sku", '
        '"locatorId": "$locatorId", '
        '"locatorName": "$locatorName", '
        '"requiredKeyPolicyId": "$requiredKeyPolicyId"'
        '}';
  }
}

class Transition {
  final String type; //": "linear",
  final String requirementDescription; //": "",
  final String transitionPrompt; //": "",
  final bool forceEnd; //": false,
  final String? endType; //": null,
  final List<Track> childNodes; //[]

  Transition(this.type, this.requirementDescription, this.transitionPrompt,
      this.forceEnd, this.endType, this.childNodes);

  factory Transition.fromJson(dynamic json) {
    return Transition(
        json["type"] as String,
        json["requirementDescription"] as String,
        json["transitionPrompt"] as String,
        json["forceEnd"] as bool,
        json["endType"] as String?,
        (json["childNodes"] as List).map((e) => Track.fromJson(e)).toList());
  }
}

class Chapter {
  final String id;
  final String gameId;
  final bool isFree;
  final int order;
  final double duration;
  final String name;
  final String shortKey; //": "SAM",
  final bool published; //": true,
  final String
      foregroundUri; //": "https://forteller.azureedge.net/assets/games/8a7596e2ab72482a95be0083145b9d36/containers/3032f04a9d0b4f6c8105168f5e8141e6/fg.png",
  final backgroundUri; //": "https://forteller.azureedge.net/assets/games/8a7596e2ab72482a95be0083145b9d36/containers/3032f04a9d0b4f6c8105168f5e8141e6/bg.png"

  Chapter(
      this.id,
      this.gameId,
      this.isFree,
      this.order,
      this.duration,
      this.name,
      this.shortKey,
      this.published,
      this.foregroundUri,
      this.backgroundUri);

  factory Chapter.fromJson(dynamic json) {
    return Chapter(
        json["id"] as String,
        json["gameId"] as String,
        json["isFree"] as bool,
        json["order"] as int,
        json["duration"] as double,
        json["name"] as String,
        json["shortKey"] as String,
        json["published"] as bool,
        json["foregroundUri"] as String,
        json["backgroundUri"] as String);
  }

  @override
  String toString() {
    return '{'
        '"id":"$id",'
        '"gameId" : "$gameId",'
        '"isFree": $isFree,'
        '"order" : $order,'
        '"duration" : $duration,'
        '"name" : "$name",'
        '"shortKey" : "$shortKey",'
        '"published" : $published,'
        '"foregroundUri" : "$foregroundUri",'
        '"backgroundUri" : "$backgroundUri",'
        '}';
  }
}

class Publisher {
  final String name;

  Publisher(this.name);

  factory Publisher.fromJson(dynamic json) {
    return Publisher(json['name'] as String);
  }

  @override
  String toString() {
    return '{ ${this.name} }';
  }
}

class CatalogEntry {
  final String id;
  final String name;
  final double duration;
  final String storeCardUri;
  final String gameDetailCardUri;
  final String learnMoreUri;
  final String type;
  final String aboutUri;
  final int price;
  final bool published;
  final bool forSale;
  final String sku;
  final double shopifyId;
  final String publisherId;
  final Publisher publisher;

  CatalogEntry(
      this.id,
      this.name,
      this.duration,
      this.storeCardUri,
      this.gameDetailCardUri,
      this.learnMoreUri,
      this.type,
      this.aboutUri,
      this.price,
      this.published,
      this.forSale,
      this.sku,
      this.shopifyId,
      this.publisherId,
      this.publisher);

  factory CatalogEntry.fromJson(dynamic json) {
    return CatalogEntry(
        json["id"] as String,
        json["name"] as String,
        json["duration"] as double,
        json["storeCardUri"] as String,
        json["gameDetailCardUri"] as String,
        json["learnMoreUri"] as String,
        json["type"] as String,
        json["aboutUri"] as String,
        json["price"] as int,
        json["published"] as bool,
        json["forSale"] as bool,
        json["sku"] as String,
        json["shopifyId"] as double,
        json["publisherId"] as String,
        Publisher.fromJson(json["publisher"]));
  }

  @override
  String toString() {
    return '{'
        '"id": "${this.id}", '
        '"name" : "$name", '
        '"sku" : "$sku"'
        '}';
  }
}

class Catalog {
  final List<CatalogEntry> entries;

  Catalog(this.entries);

  factory Catalog.fromJson(dynamic json) {
    List<CatalogEntry> entries =
        (json as List).map((entry) => CatalogEntry.fromJson(entry)).toList();
    return Catalog(entries);
  }

  @override
  String toString() {
    return "$entries";
  }
}
