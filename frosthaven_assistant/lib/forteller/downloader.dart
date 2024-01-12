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

  int _runNumber = 0;

  Future<void> stopFetchingData() async {
    _runNumber++;
    getIt<Settings>().forteller.value = false;
  }

  void startFetchingData() async {
    getIt<Settings>().forteller.value = true;
    var cancelled = await fetchData(_runNumber);
    if (!cancelled) {
      _runNumber++;
      currentChapter.value = "";
      currentTrack.value = "";
      chapterProgress.value = 0;
      trackProgress.value = 0;
      getIt<Settings>().forteller.value = false;
    }
  }

  Future<bool> fetchData(localRunNumber) async {
    var settings = getIt<Settings>();
    // Insert email and password of forteller account here
    var forteller = Forteller(
        settings.lastKnownFortellerEmail, settings.lastKnownFortellerPassword);
    var catalog = await forteller.getCatalog();
    var frosthavenEntry =
        catalog.entries.firstWhere((element) => element.name == "Frosthaven");
    var tempFolder = p.join((await getApplicationDocumentsDirectory()).path,
        "frosthaven", "audio", "temp");
    var chapters = await forteller.getChapters(frosthavenEntry.id);

    final Pattern scenarioPattern = RegExp(r'[0-9]{3}');

    var totalChapters = chapters.length;
    var currentChapterNb = 1;
    for (var chapter in chapters) {
      // if (chapter.name != "Solo Scenarios") {
      //   continue;
      // }
      print("Processing Chapter ${currentChapter.value}/$totalChapters");
      chapterProgress.value =
          (currentChapterNb.toDouble() - 1) / totalChapters.toDouble();
      currentChapter.value =
          "$currentChapterNb of $totalChapters : ${chapter.name}";
      trackProgress.value = 0;
      currentTrack.value = "Fetching Playlist";
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
        currentTrack.value =
            "Fetching ${currentTrackNb + 1} of ${playlist.content.length} : ${track.title}";
        trackProgress.value =
            currentTrackNb.toDouble() / playlist.content.length.toDouble();
        currentTrackNb++;

        if (localRunNumber != _runNumber) {
          return true;
        }
        currentCount = await downloadTrack(forteller, chapterFolder, track,
            playlist, currentCount, trackCount);
      }

      currentTrack.value = "Processing Chapter Downloads";

      // Re-organize the content
      var outFolder = p.join((await getApplicationDocumentsDirectory()).path,
          "frosthaven", "audio", "output");
      var scenarioFolder = p.join(outFolder, "scenarios");
      var sectionsFolder = p.join(outFolder, "sections");
      var soloFolder = p.join(outFolder, "solo");
      var eventsFolder = p.join(outFolder, "events");

      await Directory(scenarioFolder).create(recursive: true);
      await Directory(sectionsFolder).create();
      await Directory(soloFolder).create();
      await Directory(eventsFolder).create();

      if (scenarioPattern.allMatches(chapter.shortKey).isNotEmpty) {
        // This is a scenario Chapter, Copy the introduction to scenarios/{number}.mp3
        int scenarioNumber = int.parse(chapter.shortKey);

        final introductionCandidates = [
          "Introduction.mp3",
          "Intro.mp3",
          "introduction.mp3",
          " Introduction.mp3",
          "Introduction .mp3",
        ];
        for (var candidate in introductionCandidates) {
          tentativeCopy(
              chapterFolder, candidate, scenarioFolder, "$scenarioNumber.mp3");
        }

        // Special case for scenario 4 (choice)
        if (scenarioNumber == 4) {
          tentativeCopy(chapterFolder, "Hold.mp3", scenarioFolder, "4.mp3");
          for (var choice in ["A", "B"]) {
            tentativeCopy(chapterFolder, "Hold.subs/Introduction $choice.mp3",
                scenarioFolder, "4$choice.mp3");
          }
        }
        //Special case for scenario 93 (choice)
        if (scenarioNumber == 93) {
          tentativeCopy(chapterFolder, "Introduction.subs/Section A.mp3",
              scenarioFolder, "93A.mp3");
          tentativeCopy(chapterFolder, "Introduction.subs/Section B.mp3",
              scenarioFolder, "93B.mp3");
        }
      } else if (chapter.shortKey == "RD01" ||
          chapter.shortKey == "RD02" ||
          chapter.shortKey == "WOE" ||
          chapter.shortKey == "SOE") {
        //Events
        var dir = Directory(chapterFolder);
        dir.list().listen((entity) async {
          var stat = await entity.stat();
          if (stat.type == FileSystemEntityType.file) {
            var name = p.basename(entity.path);
            if (chapter.shortKey == "SOE") {
              // Rename some bogus Summer Outpost Events
              name = name.replaceAll("SR", "SO").replaceAll("S0", "SO");
            } else if (chapter.shortKey == "RD02") {
              name = name.replaceAll("W0", "WO");
            }

            var destination = p.join(eventsFolder, name);
            if (!await File(destination).exists()) {
              File(entity.path).copy(destination);
            }

            var outcomeDirectory = Directory(
                "${p.join(entity.parent.path, p.basenameWithoutExtension(entity.path))}.subs");
            if (await outcomeDirectory.exists()) {
              outcomeDirectory.list().listen((subEntity) async {
                if (p.basename(subEntity.path) == "Option A_.mp3") {
                  var copyName = "${p.basenameWithoutExtension(name)}_A.mp3";
                  destination = p.join(eventsFolder, copyName);
                  File(subEntity.path).copy(destination);
                } else if (p.basename(subEntity.path) == "Option B_.mp3") {
                  var copyName = "${p.basenameWithoutExtension(name)}_B.mp3";
                  destination = p.join(eventsFolder, copyName);
                  File(subEntity.path).copy(destination);
                }
              });
            }
          }
        });
      } else if (chapter.name == "Solo Scenarios") {
        var mappings = [
          "Wonder of Nature",
          "Race Against the Clock",
          "Scouting Ambush",
          "The Dead of Night",
          "Bones in the Dirt",
          "Divide and Conquer",
          "Path of Ancestry",
          "Crumbling Descent",
          "Tuning the Resonance",
          "A Magnificent Trap",
          "A Collection of Suffering",
          "Fighting Snow with Snow",
          "Under the Ice",
          "Recharge",
          "Boiler Room",
          "Wet Work",
          "Crash Against the Waves",
        ];
        var dir = Directory(chapterFolder);
        dir.list().listen((entity) async {
          var stat = await entity.stat();
          if (stat.type == FileSystemEntityType.file) {
            var name = p.basenameWithoutExtension(entity.path);
            var index = mappings.indexOf(name);
            if (index > -1) {
              var number = 138 + index;
              tentativeCopy(chapterFolder, "$name.mp3", soloFolder,
                  "$number.mp3");
              await recursiveCopySolo(p.join(chapterFolder,"$name.subs"), number, 1, soloFolder);
            }
          }
        });
      }

      // Also copy all "Section" sub files to the sections folder
      recursiveCopySections(chapterFolder, sectionsFolder);

      currentTrack.value = "Done";
      trackProgress.value = 1;
    }
    return false;
  }

  Future<void> recursiveCopySolo(String folder, int number, int level, String soloFolder) async {
    var dir = Directory(folder);
    dir.list().listen((entity) async {
      var stat = await entity.stat();
      if (stat.type == FileSystemEntityType.file) {
        var name = p.basenameWithoutExtension(entity.path);
        if (name.startsWith("Section ")) {
          tentativeCopy(folder, "$name.mp3", soloFolder,
              "$number.$level.mp3");
          recursiveCopySolo(p.join(folder,"$name.subs"), number, level+1, soloFolder);
        } else if (name == "Conclusion") {
          tentativeCopy(folder, "$name.mp3", soloFolder,
              "$number.end.mp3");
        }
      }
    });
  }

  void tentativeCopy(String sourceFolder, String sourceName,
      String destinationFolder, String destinationName) async {
    var destination = p.join(destinationFolder, destinationName);
    if (!await File(destination).exists()) {
      File source = File(p.join(sourceFolder, sourceName));
      if (await source.exists()) {
        // No need to wait for this one to complete, it can run in the BG as we get onto downloading other assets
        source.copy(destination);
      }
    }
  }

  void recursiveCopySections(String folder, String sectionsFolder) async {
    final sectionsPattern = RegExp(r'\d{1,3}\.\d{1,2}\.mp3');
    var dir = Directory(folder);

    dir.list().listen((entity) async {
      var stat = await entity.stat();
      if (stat.type == FileSystemEntityType.file) {
        var name = p.basenameWithoutExtension(entity.path).trim() +
            p.extension(entity.path);
        if (sectionsPattern.hasMatch(name)) {
          var destination = p.join(sectionsFolder, name);
          if (!await File(destination).exists()) {
            File(entity.path).copy(destination);
          }
        }
      } else if (stat.type == FileSystemEntityType.directory) {
        recursiveCopySections(entity.path, sectionsFolder);
      }
    });
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

    if (await outFile.exists()) {
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
