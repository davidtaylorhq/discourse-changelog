import { currentURL, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupApplicationTest } from "discourse-releases/tests/helpers";

module("Acceptance | route validation", function (hooks) {
  setupApplicationTest(hooks);

  test("accepts valid tag as changelog end parameter", async function (assert) {
    await visit("/changelog/v2025.11.0");

    assert.true(currentURL().includes("/changelog/v2025.11.0"));
    assert.dom(".commit-viewer").exists();
    assert.dom(".changelog-range").hasText(/v2025\.11\.0/);
  });

  test("accepts latest as changelog end parameter", async function (assert) {
    await visit("/changelog/latest");

    assert.true(currentURL().includes("/changelog/latest"));
    assert.dom(".commit-viewer").exists();
    assert.dom(".changelog-range").hasText(/latest/);
  });

  test("accepts different valid tags", async function (assert) {
    await visit("/changelog/v3.4.1");

    assert.true(currentURL().includes("/changelog/v3.4.1"));
    assert.dom(".commit-viewer").exists();
    assert.dom(".changelog-range").hasText(/v3\.4\.1/);
  });

  test("custom route accepts valid query params", async function (assert) {
    await visit("/changelog/custom?start=v2025.11.0&end=latest");

    assert.true(currentURL().startsWith("/changelog/custom?"));
    assert.dom(".commit-viewer").exists();
    assert.dom(".changelog-range").hasText(/v2025\.11\.0/);
    assert.dom(".changelog-range").hasText(/latest/);
  });

  test("custom route works without query params", async function (assert) {
    await visit("/changelog/custom");

    assert.true(currentURL().startsWith("/changelog/custom"));
    assert.dom(".commit-viewer").exists();
  });

  test("shows 404 page for invalid changelog version", async function (assert) {
    await visit("/changelog/v999.999.999").catch(() => {});

    assert.dom(".error-container").exists();
    assert.dom(".error-title").hasText("404");
    assert.dom(".commit-viewer").doesNotExist();
  });
});
