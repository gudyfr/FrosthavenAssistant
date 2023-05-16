import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:bson/bson.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart';

import 'package:hash/hash.dart';
import 'package:steamworks/steamworks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TTSCloudManager {
  late SteamClient _client;
  late Pointer<ISteamRemoteStorage> _remoteStorage;

  TTSCloudManager() {
    SteamClient.init();
    _client = SteamClient.instance;
    _remoteStorage = _client.steamRemoteStorage;
  }

  Uint8List getFile(String name) {
    var size = _remoteStorage.getFileSize(name.toNativeUtf8());
    final pointer = malloc.allocate<Uint8>(size);
    _remoteStorage.fileRead(name.toNativeUtf8(), pointer.cast(), size);
    Uint8List result = Uint8List(size);
    for (var i = 0; i < size; i++) {
      result[i] = pointer[i];
    }
    malloc.free(pointer);
    return result;
  }

  void backupFile(String name, Uint8List data) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var documentsPath = await getApplicationDocumentsDirectory();
  var abilityCardsPath =
      p.join(documentsPath.path, "frosthaven", "abilityCards");
  var outputPath = p.join(abilityCardsPath, "output");
  Directory(outputPath).create(recursive: true);
  Directory dir = Directory(abilityCardsPath);
  var mapping = <String, String>{};
  var manager = TTSCloudManager();
  var data = manager.getFile("CloudInfo.bson");
  var cloudInfo = BSON().deserialize(BsonBinary.from(data));
  var namesToUrls = <String, String>{};
  for (var entry in cloudInfo.entries) {
    var entryMap = entry.value as Map<String, dynamic>;
    namesToUrls[entryMap["Name"]!] = entryMap["URL"]!;
  }
  if (false && await dir.exists()) {
    dir.list().listen((entity) async {
      if ((await entity.stat()).type == FileSystemEntityType.file) {
        var content = await File(entity.path).readAsBytes();
        var hash = SHA1().update(content).digest();
        var fileName = encodeHEX(hash);
        File outputFile = File(p.join(outputPath, "$fileName.png"));
        if (!await outputFile.exists()) {
          outputFile.writeAsBytes(content);
        }
        mapping[p.basenameWithoutExtension(entity.path)] =
            namesToUrls["$fileName.png"] ?? "";
      }
    }).onDone(() async {
      var output = mapping.entries
          .map((entry) => "\"${entry.key}\" : \"${entry.value}\"")
          .join(",");
      await File(p.join(outputPath, "_mapping.json"))
          .writeAsString("{$output}", flush: true, mode: FileMode.writeOnly);
    });
  }

  getFileMappings(
      p.join(documentsPath.path, "frosthaven", "statsCards"), namesToUrls);
  getFileMappings("D:/fhtts/docs/images/initiativeTrackers", namesToUrls);
}

void getFileMappings(String path, Map<String, String> nameToUrls) async {
  var mappings = <String, String>{};
  var directory = Directory(path);
  if (await directory.exists()) {
    directory.list().listen((entity) async {
      if ((await entity.stat()).type == FileSystemEntityType.file) {
        var fileName = p.basename(entity.path);
        var url = nameToUrls[fileName] ?? "";
        mappings[p.basenameWithoutExtension(entity.path)] = url;
      }
    }).onDone(() async {
      var output = mappings.entries
          .map((entry) => "\"${entry.key}\" : \"${entry.value}\"")
          .join(",");
      await File(p.join(path, "mapping.json")).writeAsString("{$output}");
    });
  }
}

String encodeHEX(List<int> bytes) {
  var str = '';
  for (var i = 0; i < bytes.length; i++) {
    var s = bytes[i].toRadixString(16);
    str += s.padLeft(2 - s.length, '0');
  }
  return str;
}
