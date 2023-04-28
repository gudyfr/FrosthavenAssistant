// Copyright 2022, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import 'forteller.dart';
import 'package:path/path.dart' as p;

class Downloader {
  final currentChapter = ValueNotifier<String>("");
  final chapterProgress = ValueNotifier<double>(0.0);

  final currentTrack = ValueNotifier<String>("");
  final trackProgress = ValueNotifier<double>(0.0);

  Future<void> stopFetchingData() async {
    getIt<Settings>().forteller.value = false;
  }

  void startFetchingData() {
    getIt<Settings>().forteller.value = true;
    fetchData();
  }

  Future<void> fetchData() async {
    var settings = getIt<Settings>();
    // Insert email and password of forteller account here
    var forteller = Forteller(
        settings.lastKnownFortellerEmail, settings.lastKnownFortellerPassword);
    var catalog = await forteller.getCatalog();
    var frosthavenEntry =
        catalog.entries.firstWhere((element) => element.name == "Frosthaven");
    var tempFolder = p.join((await getApplicationDocumentsDirectory()).path, "frosthaven","audio","temp");
    var chapters = await forteller.getChapters(frosthavenEntry.id);

    final Pattern scenarioPattern = RegExp(r'[0-9]{3}');

    var totalChapters = chapters.length;
    var currentChapterNb = 1;
    for (var chapter in chapters) {
      print("Processing Chapter ${currentChapter.value}/$totalChapters");
      chapterProgress.value =
      (currentChapterNb.toDouble()-1) / totalChapters.toDouble();
      currentChapter.value = "$currentChapterNb of $totalChapters : ${chapter.name}";
      currentChapterNb++;
      var trackCount = 0;
      var currentCount = 0;

      var playlist =
          await forteller.getPlaylist(frosthavenEntry.id, chapter.id);
      for (var track in playlist.content) {
        trackCount += countTracks(track);
      }

      var chapterFolder = p.join(tempFolder, chapter.name);
      var currentTrackNb = 0;
      for (var track in playlist.content) {
        currentTrack.value = "${currentTrackNb+1} of ${playlist.content.length} : ${track.title}";
        trackProgress.value =
            currentTrackNb.toDouble() / playlist.content.length.toDouble();
        currentTrackNb++;

        if (!getIt<Settings>().forteller.value) {
          return;
        }
        currentCount = await downloadTrack(forteller, chapterFolder, track,
            playlist, currentCount, trackCount);
      }

      currentTrack.value = "Processing Chapter Downloads";
      
      // Re-organize the content
      var outFolder = p.join((await getApplicationDocumentsDirectory()).path, "frosthaven","audio","output");
      var scenarioFolder = p.join(outFolder, "scenarios");
      var sectionsFolder = p.join(outFolder, "sections");
      var soloFolder = p.join(outFolder, "solo");
      var eventsFolder = p.join(outFolder, "events");

      Directory(scenarioFolder).createSync(recursive: true);
      Directory(sectionsFolder).createSync();
      Directory(soloFolder).createSync();
      Directory(eventsFolder).createSync();

      if (scenarioPattern.allMatches(chapter.shortKey).isNotEmpty) {
        // This is a scenario Chapter, Copy the introduction to scenarios/{number}.mp3
        int scenarioNumber = int.parse(chapter.shortKey);
        var destination = p.join(scenarioFolder, "$scenarioNumber.mp3");
        if (!File(destination).existsSync()) {
          final introductionCandidates = [
            "Introduction.mp3",
            "Intro.mp3",
            "introduction.mp3",
            " Introduction.mp3"
          ];
          for (var candidate in introductionCandidates) {
            File introduction = File(p.join(chapterFolder, candidate));
            if (introduction.existsSync()) {
              introduction
                  .copySync(p.join(scenarioFolder, "$scenarioNumber.mp3"));
            }
          }
        }
      } else if (chapter.shortKey == "RD01" ||
          chapter.shortKey == "RD02" ||
          chapter.shortKey == "WOE" ||
          chapter.shortKey == "SOE") {
        //Events
        var dir = Directory(chapterFolder);
        for (var entity in dir.listSync()) {
          var stat = entity.statSync();
          if (stat.type == FileSystemEntityType.file) {
            var name = p.basename(entity.path);
            if (chapter.shortKey == "SOE") {
              // Rename some bogus Summer Outpost Events
              name = name.replaceAll("SR", "SO").replaceAll("S0", "SO");
            } else if (chapter.shortKey == "RD02") {
              name = name.replaceAll("W0", "WO");
            }

            var destination = p.join(eventsFolder, name);
            if (!File(destination).existsSync()) {
              File(entity.path).copySync(destination);
            }

            var outcomeDirectory = Directory(
                "${p.join(entity.parent.path, p.basenameWithoutExtension(entity.path))}.subs");
            if (outcomeDirectory.existsSync()) {
              for (var subEntity in outcomeDirectory.listSync()) {
                if (p.basename(subEntity.path) == "Option A_.mp3") {
                  var copyName = "${p.basenameWithoutExtension(name)}_A.mp3";
                  destination = p.join(eventsFolder, copyName);
                  File(subEntity.path).copySync(destination);
                } else if (p.basename(subEntity.path) == "Option B_.mp3") {
                  var copyName = "${p.basenameWithoutExtension(name)}_B.mp3";
                  destination = p.join(eventsFolder, copyName);
                  File(subEntity.path).copySync(destination);
                }
              }
            }
          }
        }
      }

      // Also copy all "Section" sub files to the sections folder
      recursiveCopySections(chapterFolder, sectionsFolder);
    }
  }

  void recursiveCopySections(String folder, String sectionsFolder) {
    final sectionsPattern = RegExp(r'\d{1,3}\.\d{1,2}\.mp3');
    var dir = Directory(folder);

    for (var entity in dir.listSync()) {
      var stat = entity.statSync();
      if (stat.type == FileSystemEntityType.file) {
        var name = p.basename(entity.path).trim();
        if (sectionsPattern.hasMatch(name)) {
          var destination = p.join(sectionsFolder, name);
          if (!File(destination).existsSync()) {
            File(entity.path).copySync(destination);
          }
        }
      } else if (stat.type == FileSystemEntityType.directory) {
        recursiveCopySections(entity.path, sectionsFolder);
      }
    }
  }

  int countTracks(Track track) {
    var total = 1;
    for (var subTrack in track.transition.childNodes) {
      total += countTracks(subTrack);
    }
    return total;
  }

  String sanitize(String path) {
    return path.replaceAll(RegExp(r'[:?<>]'), '_');
  }

  Future<int> downloadTrack(Forteller forteller, String base, Track track,
      Playlist playlist, int currentCount, int totalCount) async {
    currentCount++;
    var outFile = File(p.join(base, "${sanitize(track.title)}.mp3"));

    if (outFile.existsSync()) {
      print(
          "Skipping [$currentCount/$totalCount] ${outFile.path} (already downloaded)");
    } else {
      print("Downloading [$currentCount/$totalCount] ${outFile.path}");
      Directory(base).create(recursive: true);
      await forteller.getMedia(
          track.asset.streamUrl, track.asset.locatorId, playlist.id, outFile);
    }
    if (track.transition != null) {
      var tracks = track.transition.childNodes;
      var subBase = p.join(base, "${sanitize(track.title)}.subs");
      for (var subTrack in tracks) {
        currentCount = await downloadTrack(
            forteller, subBase, subTrack, playlist, currentCount, totalCount);
      }
    }

    return currentCount;
  }
}
