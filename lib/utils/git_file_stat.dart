import 'package:file/file.dart';

class GitFileStat {
  final DateTime cTime;
  final DateTime mTime;
  final int dev;
  final int ino;
  final int mode;
  final int uid;
  final int gid;
  final int fileSize;

  const GitFileStat({
    required this.cTime,
    required this.mTime,
    required this.dev,
    required this.ino,
    required this.mode,
    required this.uid,
    required this.gid,
    required this.fileSize,
  });

  factory GitFileStat.fromFileStat(FileStat stat) {
    return GitFileStat(
      cTime: stat.changed,
      mTime: stat.modified,
      dev: 0,
      ino: 0,
      mode: stat.mode,
      uid: 0,
      gid: 0,
      fileSize: stat.size,
    );
  }
}
