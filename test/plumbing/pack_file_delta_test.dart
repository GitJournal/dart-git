// This file has been adapted from go-git delta_test.go

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:dart_git/plumbing/pack_file_delta.dart';

class Piece {
  final String val;
  final int times;

  Piece(this.val, this.times);
}

Uint8List genBytes(List<Piece> pieces) {
  var result = <int>[];
  for (var p in pieces) {
    var l = Uint8List(p.times);
    for (var i = 0; i < p.times; i++) {
      // FIXME: Is this correct?
      l[i] = ascii.encode(p.val)[0];
    }
    result.addAll(l);
  }

  return Uint8List.fromList(result);
}

class DeltaTest {
  final String description;
  final List<Piece> base;
  final List<Piece> target;

  DeltaTest(this.description, {required this.base, required this.target});
}

var testData = <DeltaTest>[
  DeltaTest(
    'distinct file',
    base: [Piece('0', 300)],
    target: [Piece('2', 200)],
  ),
  DeltaTest(
    'same file',
    base: [Piece('1', 3000)],
    target: [Piece('1', 2000)],
  ),
  DeltaTest(
    'small file',
    base: [Piece('1', 3)],
    target: [Piece('1', 3), Piece('0', 1)],
  ),
  DeltaTest(
    'big file',
    base: [Piece('1', 300000)],
    target: [Piece('1', 30000), Piece('0', 1000000)],
  ),
  DeltaTest(
    'add elements before',
    base: [Piece('0', 200)],
    target: [Piece('1', 300), Piece('0', 200)],
  ),
  DeltaTest(
    'add 10 times more elements at the end',
    base: [Piece('1', 300), Piece('0', 200)],
    target: [Piece('0', 2000)],
  ),
  DeltaTest(
    'add elements between',
    base: [Piece('0', 400)],
    target: [Piece('0', 200), Piece('1', 200), Piece('0', 200)],
  ),
  DeltaTest(
    'add elements after',
    base: [Piece('0', 200)],
    target: [Piece('0', 200), Piece('1', 200)],
  ),
  DeltaTest(
    'modify elements at the end',
    base: [Piece('1', 300), Piece('0', 200)],
    target: [Piece('0', 100)],
  ),
  DeltaTest(
    'complex modification',
    base: [
      Piece('0', 3),
      Piece('1', 40),
      Piece('2', 30),
      Piece('3', 2),
      Piece('4', 400),
      Piece('5', 23),
    ],
    target: [
      Piece('1', 30),
      Piece('2', 20),
      Piece('7', 40),
      Piece('4', 400),
      Piece('5', 10),
    ],
  ),
];

void main() {
  test('AddDelta', () {
    for (var t in testData) {
      var base = genBytes(t.base);
      var target = genBytes(t.target);
      var delta = diffDelta(base, target);
      var result = patchDelta(base, delta as Uint8List);

      expect(result, target);
    }
  }, skip: true);

  test('IncompleteDelta', () {
    for (var t in testData) {
      var base = genBytes(t.base);
      var target = genBytes(t.target);

      var delta = diffDelta(base, target);
      delta = delta.sublist(0, delta.length - 2);
      var result = patchDelta(base, delta as Uint8List);

      expect(result, null);
    }
  }, skip: true);

  /*

func (s *DeltaSuite) TestMaxCopySizeDelta(c *C) {
	baseBuf := randBytes(maxCopySize)
	targetBuf := baseBuf[0:]
	targetBuf = append(targetBuf, byte(1))

	delta := DiffDelta(baseBuf, targetBuf)
	result, err := PatchDelta(baseBuf, delta)
	c.Assert(err, IsNil)
	c.Assert(result, DeepEquals, targetBuf)
}
*/
}

/*
  {
		description: "A copy operation bigger than 64kb",
		base:        []piece{{bigRandStr, 1}, {"1", 200}},
		target:      []piece{{bigRandStr, 1}},
	}}
}

var bigRandStr = randStringBytes(100 * 1024)

const letterBytes = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

func randBytes(n int) []byte {
	b := make([]byte, n)
	for i := range b {
		b[i] = letterBytes[rand.Intn(len(letterBytes))]
	}
	return b
}

func randStringBytes(n int) string {
	return string(randBytes(n))
}


*/
