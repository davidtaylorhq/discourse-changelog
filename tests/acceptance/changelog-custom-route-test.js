import { currentURL, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupApplicationTest } from "discourse-releases/tests/helpers";

module("Acceptance | changelog custom route", function (hooks) {
  setupApplicationTest(hooks);

  test("displays custom range with query params", async function (assert) {
    await visit("/changelog/custom?start=v2025.11.0&end=v2025.12.0");

    assert.dom(".commit-viewer").exists();
    assert.dom(".changelog-range").hasText(/v2025\.11\.0/);
    assert.dom(".changelog-range").hasText(/v2025\.12\.0/);
    assert.dom(".commit-card").exists();
  });

  test("navigates between version and custom routes", async function (assert) {
    await visit("/changelog/v2025.11.0");
    assert.true(currentURL().startsWith("/changelog/v2025.11.0"));

    await visit("/changelog/custom?start=v2025.11.0&end=v2025.12.0");
    assert.true(currentURL().startsWith("/changelog/custom?"));
    assert.true(currentURL().includes("start=v2025.11.0"));
    assert.true(currentURL().includes("end=v2025.12.0"));
  });
});
