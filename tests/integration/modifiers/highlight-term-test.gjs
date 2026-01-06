import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import highlightTerm from "discourse-releases/modifiers/highlight-term";
import { setupRenderingTest } from "discourse-releases/tests/helpers";

module("Integration | Modifier | highlight-term", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    CSS.highlights.clear();
  });

  test("highlights multiple occurrences in same text node", async function (assert) {
    await render(
      <template>
        <div
          id="test-element"
          {{highlightTerm searchString="foo" id="test-highlight"}}
        >foo bar foo baz foo</div>
      </template>
    );

    const highlight = CSS.highlights.get("test-highlight");
    assert.ok(highlight, "highlight should be registered");
    assert.strictEqual(
      highlight.size,
      3,
      "should have 3 ranges for 3 occurrences of 'foo'"
    );
  });

  test("highlights matches across multiple text nodes", async function (assert) {
    await render(
      <template>
        <div
          id="test-element"
          {{highlightTerm searchString="test" id="multi-node-highlight"}}
        >
          <span>test one</span>
          <span>test two</span>
        </div>
      </template>
    );

    const highlight = CSS.highlights.get("multi-node-highlight");
    assert.ok(highlight, "highlight should be registered");
    assert.strictEqual(
      highlight.size,
      2,
      "should have 2 ranges for 2 text nodes containing 'test'"
    );
  });

  test("does not highlight when search string is empty", async function (assert) {
    await render(
      <template>
        <div
          id="test-element"
          {{highlightTerm searchString="" id="empty-highlight"}}
        >foo bar foo</div>
      </template>
    );

    const highlight = CSS.highlights.get("empty-highlight");
    assert.notOk(
      highlight,
      "highlight should not be registered for empty search"
    );
  });

  test("case insensitive matching", async function (assert) {
    await render(
      <template>
        <div
          id="test-element"
          {{highlightTerm searchString="FOO" id="case-highlight"}}
        >Foo fOO foo FOO</div>
      </template>
    );

    const highlight = CSS.highlights.get("case-highlight");
    assert.ok(highlight, "highlight should be registered");
    assert.strictEqual(highlight.size, 4, "should match all case variations");
  });
});
