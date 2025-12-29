import { click, currentURL, findAll, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupApplicationTest } from "discourse-changelog/tests/helpers";

module("Acceptance | home page", function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(async function () {
    await visit("/");
  });

  test("displays versions table", async function (assert) {
    assert.dom(".versions-container").exists();
    assert.dom(".version-info").exists();
    assert.dom(".version-card").exists();
  });

  test("displays version card metadata", async function (assert) {
    assert.dom(".version-card .version-title").exists();
    assert.dom(".version-card .status-badge").exists();
    assert.dom(".version-card .status-badge").hasAnyText();
    assert.dom(".version-card .card-row").exists();
    assert.dom(".version-card .card-label").exists();
  });

  test("displays ESR indicator", async function (assert) {
    assert.dom(".version-card.esr-version").exists();
    assert.dom(".version-card.esr-version .esr-indicator").exists();
    assert.dom(".version-card.esr-version .esr-indicator").hasText("ESR");
  });

  test("displays patch versions for released versions", async function (assert) {
    assert
      .dom(".version-card:not(.upcoming-version):not(.in-development-version)")
      .exists();
    assert
      .dom(
        ".version-card:not(.upcoming-version):not(.in-development-version) .patch-versions"
      )
      .exists();
    assert.dom(".patch-version-row").exists();
    assert.dom(".patch-version-link").exists();
  });

  test("displays timeline chart", async function (assert) {
    assert.dom(".timeline-chart").exists();
    assert.dom(".timeline-month-marker").exists();
    assert.dom(".timeline-bar").exists();
    assert.dom(".timeline-legend").exists();
    assert.dom(".timeline-legend-label").exists({ count: 2 });
  });

  test("navigates to changelog when clicking version link", async function (assert) {
    await click(".version-link");

    assert.true(currentURL().startsWith("/changelog/"));
    assert.dom(".commit-viewer").exists();
  });

  test("timeline bars link to version cards", async function (assert) {
    const links = findAll(".timeline-bar-link");
    assert.true(links.length > 0);

    // Verify all links point to existing version cards
    links.forEach((link) => {
      const href = link.getAttribute("href");
      assert.true(href.startsWith("#version-"));

      const targetId = href.substring(1);
      assert.true(!!document.getElementById(targetId));
    });
  });
});
