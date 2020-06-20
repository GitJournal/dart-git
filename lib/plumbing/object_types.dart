abstract class ObjectTypes {
  static const String BLOB_STR = 'blob';
  static const String TREE_STR = 'tree';
  static const String COMMIT_STR = 'commit';
  static const String TAG_STR = 'tag';
  static const String OFS_DELTA_STR = 'ofs_delta';
  static const String REF_DELTA_STR = 'ref_delta';

  static const int COMMIT = 1;
  static const int TREE = 2;
  static const int BLOB = 3;
  static const int TAG = 4;
  static const int OFS_DELTA = 6;
  static const int REF_DELTA = 7;

  static String getTypeString(int type) {
    switch (type) {
      case COMMIT:
        return COMMIT_STR;
      case TREE:
        return TREE_STR;
      case BLOB:
        return BLOB_STR;
      case TAG:
        return TAG_STR;
      case OFS_DELTA:
        return OFS_DELTA_STR;
      case REF_DELTA:
        return REF_DELTA_STR;
      default:
        throw Exception('unsupported pack type ${type}');
    }
  }

  static int getType(String type) {
    switch (type) {
      case COMMIT_STR:
        return COMMIT;
      case TREE_STR:
        return TREE;
      case BLOB_STR:
        return BLOB;
      case TAG_STR:
        return TAG;
      case OFS_DELTA_STR:
        return OFS_DELTA;
      case REF_DELTA_STR:
        return REF_DELTA;
      default:
        throw Exception('unsupported pack type ${type}');
    }
  }
}
