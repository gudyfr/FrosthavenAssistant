import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:bson/bson.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart';

import 'package:hash/hash.dart';
import 'package:intl/intl.dart';
import 'package:steamworks/steamworks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileInfo {
  String name;
  int size;
  DateTime date;

  FileInfo(this.name, this.size, this.date);
}

class TTSCloudManager {
  late SteamClient _client;
  late Pointer<ISteamRemoteStorage> _remoteStorage;

  TTSCloudManager() {
    _client = SteamClient.instance;
    _remoteStorage = _client.steamRemoteStorage;
    _client.registerCallback<PersonaStateChange>(
      cb: (data) {
        debugPrint("Persona State Change");
      },
    );
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

  Future<void> uploadFile(String name, Uint8List data) async {
    debugPrint("Uploading File $name");
    var size = data.length;
    final pointer = malloc.allocate<Uint8>(size);
    for (var i = 0; i < size; i++) {
      pointer[i] = data[i];
    }
    SteamApiCall call = _remoteStorage.fileWriteAsync(name.toNativeUtf8(), pointer.cast(), size);
    debugPrint("Waiting for file to upload");
    Completer<bool> completer = Completer();
    _client.registerCallResult<RemoteStorageFileWriteAsyncComplete>(asyncCallId: call, cb: (data, hasFailed) {
      if (hasFailed) {
        completer.completeError("Failed to upload file");
      } else {
        completer.complete(true);
      }
    });
    await completer.future;
    debugPrint("File uploaded");
  }

  Future<String> uploadTTSFile(String name, String hash, Uint8List data) async {
    var cloudName = "${hash.toUpperCase()}_$name";
    await uploadFile(cloudName, data);
    return cloudName;
  }

  Future<String> uploadAndShareFile(String name, String hash, Uint8List data) async {
    var cloudName = await uploadTTSFile(name, hash, data);
    debugPrint("Sharing File $cloudName");
    SteamApiCall callId = _remoteStorage.fileShare(cloudName.toNativeUtf8());


    debugPrint("Waiting for Share Name");


    Completer<String> completer = Completer();
    _client.registerCallResult<RemoteStorageFileShareResult>(
        asyncCallId: callId, cb: (ptrUserShare, hasFailed) {
      if (hasFailed) {
        completer.completeError("Failed to share file");
      } else {
        completer.complete(ptrUserShare.filename.toDartString());
      }
    });
    var fileName = await completer.future;
    return "http://cloud-3.steamusercontent.com/ugc/$fileName/$hash/";
  }

  void updateCloudInfo(Map<String, dynamic> cloudInfo) {
    var bson = BSON().serialize(cloudInfo);
    uploadFile("CloudInfo.bson", bson.byteList);
  }

  Map<String, dynamic> createInfoMap(String name, String url, int size, DateTime date, String folder) {
    DateFormat format = DateFormat("M/d/Y h:mm:ss a");
    return {
      "Name": name,
      "URL": url,
      "Size": size,
      "Date": format.format(date),
      "Folder": folder
    };
  }

  List<FileInfo> listFiles() {
    var files = <FileInfo>[];
    var count = _remoteStorage.getFileCount();
    var ptrSize = malloc.allocate<Int>(1);
    for (var i = 0; i < count; i++) {
      var name = _remoteStorage.getFileNameAndSize(i,ptrSize);
      var timeStamp = _remoteStorage.getFileTimestamp(name);
      var date = DateTime.fromMillisecondsSinceEpoch(timeStamp*1000);
      files.add(FileInfo(name.toDartString(), ptrSize.value, date));
    }
    return files;
  }

  void deleteFile(String name) {
    _remoteStorage.fileDelete(name.toNativeUtf8());
  }
}

void backup(Map<String, dynamic> data) async {
  var documentsPath = await getApplicationDocumentsDirectory();
  var frosthavenPath = p.join(documentsPath.path, "frosthaven");
  var format = DateFormat("y_MM_dd HH_mm_ss");
  var fileName = "CloudInfo ${format.format(DateTime.now())}.bson";
  await File(p.join(frosthavenPath, fileName)).writeAsBytes(BSON().serialize(data).byteList);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SteamClient.init();
  var manager = TTSCloudManager();
  // var files = manager.listFiles();
  // debugPrint("${files.length} Files");
  // var cutoffDate = DateTime(2023,6,15);
  // debugPrint("${files.length} Files");

  // var data = manager.getFile("CloudInfo.bson");
  // var cloudInfo = BSON().deserialize(BsonBinary.from(data));
  // debugPrint("${cloudInfo.length} files in cloudInfo");
  // RegExp exp = RegExp(r'[\dA-F]{40}');
  // for (var file in files) {
  //   if(!exp.hasMatch(file.name)) {
  //     continue;
  //   }
  //   if(cloudInfo[file.name] == null) {
  //     debugPrint("File ${file.name} (${file.size}) ${file.date} not in cloudInfo, deleting");
  //     manager.deleteFile(file.name);
  //   }
  // }

  // var documentsPath = await getApplicationDocumentsDirectory();
  // var frosthavenPath = p.join(documentsPath.path, "frosthaven");
  // var backupFolder = p.join(frosthavenPath, "backup");
  // var flatOutputFolder = p.join(backupFolder, "flat");
  // var structuredOutputFolder = p.join(backupFolder, "structured");
  // var usedOutputFolder = p.join(backupFolder, "used");
  // await Directory(flatOutputFolder).create(recursive: true);
  // await Directory(structuredOutputFolder).create(recursive: true);
  //
  // var save = await File(p.join(backupFolder, "TS_Save_101.json")).readAsString();
  // Map<String,dynamic> cloudInfo = jsonDecode(await File(p.join(backupFolder, "CloudInfo.json")).readAsString());
  // var exp = RegExp(r'http://cloud-3\.steamusercontent\.com/ugc/(\d+)/([\dA-F]{40})/');
  // var usedKeys = <String>{};
  // var unmatchedUrls = <String>{};
  // var nbMatches = 0;
  // var matchedMatches = 0;
  // for(var match in exp.allMatches(save)) {
  //   nbMatches++;
  //   var url = match.group(0)!!;
  //   var id = match.group(1);
  //   var hash = match.group(2);
  //   var matched = false;
  //   for (var info in cloudInfo.keys) {
  //     if (cloudInfo[info]["URL"] == url) {
  //       usedKeys.add(info);
  //       matched = true;
  //       break;
  //     }
  //   }
  //   if(matched) {
  //     matchedMatches++;
  //     continue;
  //   }
  //   unmatchedUrls.add(url);
  //   // debugPrint("Unmatched url : $url");
  // }
  // for (var key in usedKeys) {
  //   var info = cloudInfo[key];
  //   // Copy the corresponding file to the used folder
  //   var folder = info["Folder"].replaceAll("/", "\\");
  //   var fileName = p.join(folder,key);
  //   var srcFile = p.join(structuredOutputFolder, fileName);
  //   var outFile = p.join(usedOutputFolder, folder, info["Name"]);
  //   var outFolder = p.dirname(outFile);
  //   await Directory(outFolder).create(recursive: true);
  //   await File(srcFile).copy(outFile);
  // }
  // // for (var key in cloudInfo.keys) {
  // //   debugPrint("Used key : $key");
  // // }
  // debugPrint("Used ${usedKeys.length} keys, over $nbMatches matches, $matchedMatches matched");
  //
  // for(var url in unmatchedUrls) {
  //   debugPrint("Unmatched url : $url");
  // }

  //   var fileName = "_ugc_${id}_${hash}"
  //   var data = await manager.getFile(name);
  //   var outputFileName = p.join(flatOutputFolder, name);
  //   if(await File(outputFileName).exists()) {
  //     debugPrint("File $outputFileName already exists, skipping");
  //     continue;
  //   }
  //   await File(outputFileName).writeAsBytes(data);
  //   debugPrint("Wrote $outputFileName");
  // }

  // var httpClient = HttpClient();
  // var dataFormat = DateFormat("M/d/y h:mm:ss a");
  // await File(p.join(backupFolder, "CloudInfo.bson")).writeAsBytes(BSON().serialize(cloudInfo).byteList);
  // await File(p.join(backupFolder, "CloudInfo.json")).writeAsString(jsonEncode(cloudInfo));
  // for (var key in cloudInfo.keys) {
  //   var info = cloudInfo[key];
  //   var outputFolder = p.join(structuredOutputFolder, info["Folder"]);
  //   var outputFileName = p.join(outputFolder, key);
  //   Directory(outputFolder).create(recursive: true);
  //   if(await File(outputFileName).exists()) {
  //     debugPrint("File $outputFileName already exists, skipping");
  //     continue;
  //   }
  //   debugPrint("$info");
  //   var uri = Uri.parse(info["URL"]);
  //   HttpClientRequest request = await httpClient.get(uri.host, 80, uri.path);
  //   var response = await request.close();
  //   await response.pipe(File(outputFileName).openWrite());
  //
  //   var flatFileName = p.join(flatOutputFolder, uri.path.replaceAll("/", "_"));
  //   await File(outputFileName).copy(flatFileName);
  //
  //   File(outputFileName).setLastModifiedSync(dataFormat.parse(info["Date"]));
  // }

  // mapAndUpload();
  // while(true) {
  //   debugPrint("Running frames");
  //   SteamClient.instance.runFrame();
  //   await Future.delayed(const Duration(milliseconds: 300));
  // }

  mapAndUpload();
}

void mapAndUpload() async {
  var frosthavenPath = p.join( "D:/frosthaven");
  var abilityCardsPath =
  p.join(frosthavenPath, "abilityCards");
  var outputPath = p.join(abilityCardsPath, "output");
  Directory(outputPath).create(recursive: true);
  Directory dir = Directory(abilityCardsPath);
  var mapping = <String, String>{};
  var manager = TTSCloudManager();
  var data = manager.getFile("CloudInfo.bson");
  // await File(p.join(frosthavenPath, "CloudInfo.bson"))
  //     .writeAsBytes(data);
  var cloudInfo = BSON().deserialize(BsonBinary.from(data));
  // backup(cloudInfo);
  var namesToUrls = <String, String>{};
  for (var entry in cloudInfo.entries) {
    var entryMap = entry.value as Map<String, dynamic>;
    if (!(entryMap["Folder"] as String).contains("Attack Modifiers")) {
      namesToUrls[entryMap["Name"]!] = entryMap["URL"]!;
    }
  }

  if (await dir.exists()) {
    await for (final entity in dir.list()) {
      FileStat fileStat = await entity.stat();
      if (fileStat.type == FileSystemEntityType.file) {
        var originalName = p.basename(entity.path);
        var content = await File(entity.path).readAsBytes();
        var hash = SHA1().update(content).digest();
        var fileName = encodeHEX(hash);
        var url = namesToUrls["$fileName.png"];
        debugPrint(
            "${entity.path} => $fileName => $url");

        File outputFile = File(p.join(outputPath, "$fileName.png"));
        if (!await outputFile.exists()) {
          outputFile.writeAsBytes(content);
        }

        // if(url == null) {
        //   // We need to upload and share the file
        //   url = await manager.uploadAndShareFile("$fileName.png", fileName, content);
        //   namesToUrls["$fileName.png"] = url;
        //   cloudInfo["${fileName}_$originalName"] = manager.createInfoMap(
        //       originalName, url, content.length, fileStat.modified, "Frosthaven/New Ability Cards");
        //   nbChanges++;
        //   if(nbChanges > 50) {
        //     backup(cloudInfo);
        //     manager.updateCloudInfo(cloudInfo);
        //     nbChanges = 0;
        //   }
        // }
        mapping[p.basenameWithoutExtension(entity.path)] =
            namesToUrls["$fileName.png"] ?? "";
      }
    }

    // if(nbChanges > 0) {
    //   backup(cloudInfo);
    //   manager.updateCloudInfo(cloudInfo);
    // }

    var output = mapping.entries
        .map((entry) => "\"${entry.key}\" : \"${entry.value}\"")
        .join(",");
    await File(p.join(outputPath, "_mapping.json"))
        .writeAsString("{$output}", flush: true);
  }

  getFileMappings(
      p.join(frosthavenPath, "statsCards"), namesToUrls);
  // getFileMappings("D:/fhtts/docs/images/initiativeTrackers", namesToUrls);
  // getFileMappings("D:/fhtts/docs/images/attackModifiers", namesToUrls);
}

void getFileMappings(String path, Map<String, String> nameToUrls) async {
  var mappings = <String, String>{};
  var directory = Directory(path);
  if (await directory.exists()) {
    await for (var entity in directory.list()) {
      if ((await entity.stat()).type == FileSystemEntityType.file) {
        var fileName = p.basename(entity.path);
        debugPrint("Processing $fileName");
        var url = nameToUrls[fileName] ?? "";
        mappings[p.basenameWithoutExtension(entity.path)] = url;
      }
    }
    var output = mappings.entries
        .map((entry) => "\"${entry.key}\" : \"${entry.value}\"")
        .join(",");
    await File(p.join(path, "mapping.json")).writeAsString("{$output}");
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
