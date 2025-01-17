import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:leak_tracker/devtools_integration.dart';
import 'package:leak_tracker/leak_tracker.dart';
import 'package:lays/filemgr.dart';
import 'package:lays/map-view-page2.dart';
import 'package:lays/pathhandler.dart';
import 'package:mapsforge_flutter/maps.dart';

import 'location_page.dart';
import 'map-file-data.dart';

/// The [StatefulWidget] which downloads the mapfile.
///
/// Routing to this page requires a [MapFileData] object that shall be rendered.
class MapDownloadPage extends StatefulWidget {
  final MapFileData mapFileData;

  const MapDownloadPage({Key? key, required this.mapFileData})
      : super(key: key);

  @override
  MapDownloadPageState createState() => MapDownloadPageState();
}

/////////////////////////////////////////////////////////////////////////////

/// The [State] of the [MapViewPage] Widget.
class MapDownloadPageState extends State<MapDownloadPage> {
  double? downloadProgress;

  String? error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mapFileData.displayedName),
      ),
      body: _buildDownloadProgressBody(),
    );
  }

  Widget _buildDownloadProgressBody() {
    if (error != null) {
      return Center(
        child: Text(error!),
      );
    }
    return StreamBuilder<FileDownloadEvent>(
        stream: FileMgr().fileDownloadOberve,
        builder: (context, AsyncSnapshot<FileDownloadEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // let's start the download process
            _startDownload();
          } else {
            if (snapshot.data!.status == DOWNLOADSTATUS.ERROR) {
              return const Center(child: Text("Error while downloading file"));
            } else if (snapshot.data!.status == DOWNLOADSTATUS.FINISH) {
              downloadProgress = 1;
              _switchToMap(snapshot.data?.content);
            } else
              downloadProgress = (snapshot.data!.count / snapshot.data!.total);
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CircularProgressIndicator(
                value: downloadProgress == null || downloadProgress == 1
                    ? null
                    : downloadProgress,
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  downloadProgress == null || downloadProgress == 1
                      ? "Loading map"
                      : "Downloading map ${(downloadProgress! * 100).round()} %",
                ),
              ),
            ],
          );
        });
  }

  Future<void> _startDownload() async {
    if (kIsWeb) {
      // web mode does not support filesystems so we need to download to memory instead
      await FileMgr().downloadNow2(widget.mapFileData.url);
      return;
    }

    String fileName = widget.mapFileData.fileName;
    PathHandler pathHandler = await FileMgr().getLocalPathHandler("");
    if (await pathHandler.exists(fileName)) {
      // file already exists locally, start now
      final MapFile mapFile =
          await MapFile.from(pathHandler.getPath(fileName), null, null);
      await _startMap(mapFile);
    } else {
      bool ok = await FileMgr().downloadToFile2(
          widget.mapFileData.url, pathHandler.getPath(fileName));
      if (!ok) {
        error = "Error while putting the downloadrequest in the queue";
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _switchToMap(List<int>? content) async {
    if (content != null) {
      // file downloaded into memory
      MapFile mapFile =
          await MapFile.using(Uint8List.fromList(content), null, null);
      await _startMap(mapFile);
    } else {
      // file is here, hope that _prepareOfflineMap() is happy and prepares the map for us.
      String fileName = widget.mapFileData.fileName;

      PathHandler pathHandler = await FileMgr().getLocalPathHandler("");
      final MapFile mapFile =
          await MapFile.from(pathHandler.getPath(fileName), null, null);
      await _startMap(mapFile);
    }
  }

  Future<void> _startMap(MapFile mapFile) async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (BuildContext context) =>
            MapViewPage2(mapFileData: widget.mapFileData, mapFile: mapFile),
        //LocationPage(),
      ),
    );
    mapFile.dispose();
    // Timer(const Duration(seconds: 5), () {
    //   Leaks leaks = collectLeaks();
    //   leaks.notDisposed.forEach((LeakReport element) {
    //     print("Not disposed: ${element.toYaml("  ")}");
    //   });
    //   leaks.notGCed.forEach((element) {
    //     print("not gced: ${element.toYaml("  ")}");
    //   });
    // });
  }
}
