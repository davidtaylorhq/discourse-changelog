import { module, test } from "qunit";
import {
  AmbiguousRefError,
  ChangelogData,
  UnknownRefError,
} from "discourse-releases/lib/git-utils";

module("Unit | Lib | git-utils | resolveRef", function () {
  function createChangelogData(commits, refs = {}) {
    const data = new ChangelogData();
    data.commitData = {
      commits,
      refs: {
        tags: refs.tags || {},
        branches: refs.branches || {},
      },
    };
    return data;
  }

  test("resolves tag to commit hash", function (assert) {
    const data = createChangelogData(
      { abc123def456: { subject: "commit" } },
      { tags: { "v1.0.0": "abc123def456" } }
    );

    assert.strictEqual(data.resolveRef("v1.0.0"), "abc123def456");
  });

  test("resolves branch to commit hash", function (assert) {
    const data = createChangelogData(
      { abc123def456: { subject: "commit" } },
      { branches: { main: "abc123def456" } }
    );

    assert.strictEqual(data.resolveRef("main"), "abc123def456");
  });

  test("resolves full hash to itself", function (assert) {
    const fullHash = "abc123def456abc123def456abc123def456abcd";
    const data = createChangelogData({ [fullHash]: { subject: "commit" } });

    assert.strictEqual(data.resolveRef(fullHash), fullHash);
  });

  test("resolves partial hash to full hash", function (assert) {
    const fullHash = "abc123def456abc123def456abc123def456abcd";
    const data = createChangelogData({ [fullHash]: { subject: "commit" } });

    assert.strictEqual(data.resolveRef("abc123"), fullHash);
  });

  test("throws UnknownRefError for unmatched partial hash", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "commit" },
    });

    assert.throws(
      () => data.resolveRef("xyz789"),
      UnknownRefError,
      "throws UnknownRefError for unknown partial hash"
    );
  });

  test("throws UnknownRefError for unmatched full hash", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "commit" },
    });

    const unknownFullHash = "ffffffffffffffffffffffffffffffffffffffff";
    assert.throws(
      () => data.resolveRef(unknownFullHash),
      UnknownRefError,
      "throws UnknownRefError for unknown full hash"
    );
  });

  test("UnknownRefError contains ref", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "commit" },
    });

    try {
      data.resolveRef("xyz789");
      assert.ok(false, "should have thrown");
    } catch (error) {
      assert.strictEqual(error.name, "UnknownRefError");
      assert.strictEqual(error.ref, "xyz789");
      assert.true(error.message.includes("xyz789"));
    }
  });

  test("throws AmbiguousRefError when partial hash matches multiple commits", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "first" },
      abc123fff456abc123def456abc123def456abcd: { subject: "second" },
      abc123ggg456abc123def456abc123def456abcd: { subject: "third" },
    });

    assert.throws(
      () => data.resolveRef("abc123"),
      AmbiguousRefError,
      "throws AmbiguousRefError"
    );
  });

  test("AmbiguousRefError contains ref and matches", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "first" },
      abc123fff456abc123def456abc123def456abcd: { subject: "second" },
    });

    try {
      data.resolveRef("abc123");
      assert.ok(false, "should have thrown");
    } catch (error) {
      assert.strictEqual(error.name, "AmbiguousRefError");
      assert.strictEqual(error.ref, "abc123");
      assert.strictEqual(error.matches.length, 2);
      assert.true(error.message.includes("abc123"));
      assert.true(error.message.includes("2 commits"));
    }
  });

  test("AmbiguousRefError message truncates long match lists", function (assert) {
    const commits = {};
    for (let i = 0; i < 10; i++) {
      const hash = `abc${i.toString().padStart(37, "0")}`;
      commits[hash] = { subject: `commit ${i}` };
    }
    const data = createChangelogData(commits);

    try {
      data.resolveRef("abc");
      assert.ok(false, "should have thrown");
    } catch (error) {
      assert.true(error.message.includes("10 commits"));
      assert.true(error.message.includes("and 5 more"));
    }
  });

  test("longer partial hash resolves uniquely", function (assert) {
    const data = createChangelogData({
      abc123def456abc123def456abc123def456abcd: { subject: "first" },
      abc123fff456abc123def456abc123def456abcd: { subject: "second" },
    });

    assert.strictEqual(
      data.resolveRef("abc123d"),
      "abc123def456abc123def456abc123def456abcd"
    );
    assert.strictEqual(
      data.resolveRef("abc123f"),
      "abc123fff456abc123def456abc123def456abcd"
    );
  });

  test("tag takes precedence over partial hash match", function (assert) {
    const data = createChangelogData(
      {
        abc123def456abc123def456abc123def456abcd: { subject: "commit" },
        fff999def456abc123def456abc123def456abcd: { subject: "tagged" },
      },
      { tags: { abc123: "fff999def456abc123def456abc123def456abcd" } }
    );

    assert.strictEqual(
      data.resolveRef("abc123"),
      "fff999def456abc123def456abc123def456abcd"
    );
  });
});
