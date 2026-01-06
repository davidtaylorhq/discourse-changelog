import { visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupApplicationTest } from "discourse-releases/tests/helpers";

module("Acceptance | error handling", function (hooks) {
  setupApplicationTest(hooks);

  test("displays 404 page for unmatched routes", async function (assert) {
    await visit("/this-does-not-exist");

    assert.dom(".error-container").exists();
    assert.dom(".error-title").hasText("404");
    assert.dom(".error-subtitle").hasText("Page Not Found");
    assert.dom(".error-message").containsText("doesn't exist");
    assert.dom(".error-link").hasAttribute("href", "/");
  });
});
