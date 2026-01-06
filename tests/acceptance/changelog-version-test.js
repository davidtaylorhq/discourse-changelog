import { click, currentURL, fillIn, findAll, visit } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupApplicationTest } from "discourse-releases/tests/helpers";

module("Acceptance | changelog version", function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(async function () {
    await visit("/changelog/v2025.12.0");
  });

  test("displays commit viewer", async function (assert) {
    assert.dom(".commit-viewer").exists();
  });

  test("displays version range", async function (assert) {
    assert.dom(".changelog-range").hasText(/→/);
    assert.dom(".changelog-range strong").exists({ count: 2 });
  });

  test("displays back link", async function (assert) {
    assert.dom(".back-to-versions").hasAttribute("href", "/");
  });

  test("displays commit tabs", async function (assert) {
    assert.dom(".commit-tab.active").exists();
    assert.dom(".commit-tab.active").hasText(/All/);
  });

  test("displays filter input", async function (assert) {
    assert
      .dom(".filter-input")
      .hasAttribute("placeholder", "Filter commits...");
  });

  test("displays commits", async function (assert) {
    assert.dom(".commit-card").exists();
    assert.dom(".commit-subject").exists();
    assert.dom(".commit-date").exists();
  });

  test("filters commits by search text", async function (assert) {
    await fillIn(".filter-input", "xyz-nonexistent-search-term");

    assert.dom(".commit-card").doesNotExist();
  });

  test("commit cards show detailed metadata", async function (assert) {
    assert.dom(".commit-card .commit-subject").exists();
    assert.dom(".commit-card .commit-date").exists();
    assert.dom(".commit-card .commit-time").exists();
    assert.dom(".commit-card .commit-badge").exists();
  });

  test("commits can be expanded and collapsed", async function (assert) {
    const firstCommit = ".commit-card";

    // Initially should be collapsed
    assert.dom(`${firstCommit} .commit-details`).doesNotHaveAttribute("open");

    // Click to expand
    await click(firstCommit);
    assert.dom(`${firstCommit} .commit-details`).hasAttribute("open");
    assert.dom(`${firstCommit} .commit-author`).exists();

    // Click to collapse
    await click(firstCommit);
    assert.dom(`${firstCommit} .commit-details`).doesNotHaveAttribute("open");
  });

  test("filter tabs actually filter commits", async function (assert) {
    const tabs = findAll(".commit-tab");
    assert.true(tabs.length > 1);

    // Count all commits initially (excluding feature cards)
    const allCount = findAll(".commit-card").length;
    assert.true(allCount > 0, "Should have commits displayed");

    // Click a filter tab (not "All")
    await click(tabs[1]);
    assert.dom(tabs[1]).hasClass("active");

    // Count filtered commits
    const filteredCount = findAll(".commit-card").length;
    assert.true(filteredCount > 0, "Should have some commits after filtering");
    assert.true(
      filteredCount <= allCount,
      "Filtered commits should not exceed total"
    );

    // Click back to "All" tab
    await click(tabs[0]);
    assert.dom(tabs[0]).hasClass("active");

    // Workaround flakiness. Seems that vertical-collection isn't setting up test waiters properly?
    await new Promise((resolve) => requestAnimationFrame(resolve));

    // Verify we have the same count as before
    const backToAllCount = findAll(".commit-card").length;
    assert.strictEqual(
      backToAllCount,
      allCount,
      "Should show all commits again"
    );
  });

  test("feature cards are displayed", async function (assert) {
    assert.dom(".feature-card").exists();
    assert.dom(".feature-card .feature-title").exists();
    assert.dom(".feature-card .feature-description").exists();
  });

  test("toggles selector UI with start and end dropdowns", async function (assert) {
    // Initially hidden
    assert.dom(".form-section").doesNotExist();

    // Click to show
    await click(".toggle-selector-btn");
    assert.dom(".form-section").exists();
    assert.dom("#start-ref").hasTagName("select");
    assert.dom("#end-ref").hasTagName("select");
    assert.dom(".advanced-toggle").exists({ count: 2 });
    assert.dom(".toggle-selector-btn").hasText(/Hide/);

    // Click to hide
    await click(".toggle-selector-btn");
    assert.dom(".form-section").doesNotExist();
    assert.dom(".toggle-selector-btn").hasText(/Customize/);
  });

  test("advanced mode switches between dropdown and text input", async function (assert) {
    await click(".toggle-selector-btn");

    // Check start ref advanced mode
    assert.dom("#start-ref").hasTagName("select");
    await click(findAll(".advanced-toggle")[0]);
    assert.dom("#start-ref").hasTagName("input");
    assert.dom("#start-ref").hasAttribute("placeholder", /commit hash/);
    assert.dom(findAll(".advanced-toggle")[0]).hasText(/Use Dropdown/);

    // Check end ref advanced mode
    assert.dom("#end-ref").hasTagName("select");
    await click(findAll(".advanced-toggle")[1]);
    assert.dom("#end-ref").hasTagName("input");
    assert.dom("#end-ref").hasAttribute("placeholder", /commit hash/);
    assert.dom(findAll(".advanced-toggle")[1]).hasText(/Use Dropdown/);
  });

  test("changing end ref in dropdown mode navigates to new version", async function (assert) {
    await click(".toggle-selector-btn");

    // Change end ref to a different version and click Go
    await fillIn("#end-ref", "v2025.12.0-latest");
    await click(".form-section .go-button");

    // Should navigate to /changelog/v2025.12.0-latest
    assert.true(currentURL().includes("/changelog/v2025.12.0-latest"));
    assert.dom(".changelog-range").hasText(/v2025\.12\.0-latest/);
  });

  test("changing start ref in dropdown mode navigates to custom route", async function (assert) {
    await click(".toggle-selector-btn");

    // Change start ref to a specific version and click Go
    await fillIn("#start-ref", "v2025.11.0");
    await click(".form-section .go-button");

    // Should navigate to /changelog/custom with query params
    assert.true(currentURL().startsWith("/changelog/custom?"));
    assert.true(currentURL().includes("start=v2025.11.0"));
    assert.dom(".changelog-range").hasText(/v2025\.11\.0/);
  });

  test("entering commit hash in advanced mode navigates correctly", async function (assert) {
    await click(".toggle-selector-btn");

    // Switch to advanced mode for start
    await click(findAll(".advanced-toggle")[0]);

    // Enter a commit hash and click Go
    await fillIn("#start-ref", "0005565fb3ebf11137ab93a312828863d25f3e2c");
    await click(".form-section .go-button");

    // Should navigate to /changelog/custom with the commit hash
    assert.true(currentURL().startsWith("/changelog/custom?"));
    assert.true(
      currentURL().includes("start=0005565fb3ebf11137ab93a312828863d25f3e2c")
    );
  });

  test("security advisory cards are displayed for v2025.12.0", async function (assert) {
    await visit("/changelog/v2025.12.0");

    assert.dom(".security-advisory-card").exists();
    assert.dom(".advisory-cve").hasText(/CVE-/);
    assert.dom(".advisory-summary").exists();
    assert
      .dom(".security-advisory-card")
      .hasAttribute("href", /github\.com.*security.*advisories/);
  });
});
