import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:dart_git/plumbing/packp/capabilities.dart';

void main() {
  test('Decode', () {
    var cap = Capabilities.decodeString('symref=foo symref=qux thin-pack');

    expect(cap.length, 2);
    expect(cap.get(Capability.SymRef), ['foo', 'qux']);
    expect(cap.get(Capability.ThinPack), null); // FIXME: Why null?
  }, skip: true);

  test('Decode With Leading Space', () {
    var cap = Capabilities.decodeString(' report-status');

    expect(cap.length, 1);
    expect(cap.get(Capability.ReportStatus), []);
  }, skip: true);

  test('Decode Empty', () {
    var cap = Capabilities.decode(Uint8List.fromList([]));

    expect(cap.length, 0);
  }, skip: true);

  test('Decode With Error Arguments', () {
    var cap = Capabilities.decodeString('thin-pack=foo');

    expect(cap.length, 0);
    // FIXME: ErrArguments
  }, skip: true);

  test('Decode with Equal', () {
    var cap = Capabilities.decodeString('agent=foo=bar');

    expect(cap.length, 1);
    expect(cap.get(Capability.Agent), ['foo=bar']);
  }, skip: true);

  test('Decode with Unknown Capability', () {
    var cap = Capabilities.decodeString('agent=foo=bar');

    expect(cap.length, 1);
    expect(cap.supports('foo'), true);
  }, skip: true);

  test('Decode with Unknown Capability With Argument', () {
    var cap = Capabilities.decodeString('oldref=HEAD:refs/heads/v2 thin-pack');

    expect(cap.length, 2);
    expect(cap.get('oldref'), ['HEAD:refs/heads/v2']);
    expect(cap.supports(Capability.ThinPack), true);
  }, skip: true);

  test('Decode with Unknown Capability With Multtiple Arguments', () {
    var cap = Capabilities.decodeString(
        'foo=HEAD:refs/heads/v2 foo=HEAD:refs/heads/v1 thin-pack');

    expect(cap.length, 2);
    expect(cap.get('oldref'), ['HEAD:refs/heads/v2', 'HEAD:refs/heads/v1']);
    expect(cap.supports(Capability.ThinPack), true);
  }, skip: true);

  test('string', () {
    var cap = Capabilities();
    cap.set(Capability.Agent, 'bar');
    cap.set(Capability.SymRef, 'foo:qux');
    cap.enable(Capability.ThinPack);

    expect(cap.encode(), 'agent=bar symref=foo:qux thin-pack');
  }, skip: true);

  test('add', () {
    var cap = Capabilities();
    cap.add(Capability.SymRef, 'foo');
    cap.add(Capability.SymRef, 'qux');

    expect(cap.encode(), 'symref=foo:qux thin-pack');
  }, skip: true);
}

/*

func (s *SuiteCapabilities) TestAddErrArgumentsRequired(c *check.C) {
	cap := NewList()
	err := cap.Add(SymRef)
	c.Assert(err, check.Equals, ErrArgumentsRequired)
}

func (s *SuiteCapabilities) TestAddErrArgumentsNotAllowed(c *check.C) {
	cap := NewList()
	err := cap.Add(OFSDelta, "foo")
	c.Assert(err, check.Equals, ErrArguments)
}

func (s *SuiteCapabilities) TestAddErrArguments(c *check.C) {
	cap := NewList()
	err := cap.Add(SymRef, "")
	c.Assert(err, check.Equals, ErrEmptyArgument)
}

func (s *SuiteCapabilities) TestAddErrMultipleArguments(c *check.C) {
	cap := NewList()
	err := cap.Add(Agent, "foo")
	c.Assert(err, check.IsNil)

	err = cap.Add(Agent, "bar")
	c.Assert(err, check.Equals, ErrMultipleArguments)
}

func (s *SuiteCapabilities) TestAddErrMultipleArgumentsAtTheSameTime(c *check.C) {
	cap := NewList()
	err := cap.Add(Agent, "foo", "bar")
	c.Assert(err, check.Equals, ErrMultipleArguments)
}

func (s *SuiteCapabilities) TestAll(c *check.C) {
	cap := NewList()
	c.Assert(NewList().All(), check.IsNil)

	cap.Add(Agent, "foo")
	c.Assert(cap.All(), check.DeepEquals, []Capability{Agent})

	cap.Add(OFSDelta)
	c.Assert(cap.All(), check.DeepEquals, []Capability{Agent, OFSDelta})
}


*/
