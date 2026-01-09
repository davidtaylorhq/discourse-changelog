import { visit } from "@ember/test-helpers";
import CommitsData from "/data/commits.json";
import { module, test } from "qunit";
import { setupApplicationTest } from "discourse-releases/tests/helpers";

module("Acceptance | provisional changelog", function (hooks) {
  setupApplicationTest(hooks);

  // Get test data dynamically from commits.json
  const provisionalVersions = Object.keys(
    CommitsData.provisionalVersions || {}
  );
  const firstProvisional = provisionalVersions[0];

  // Get a released tag for comparison
  const releasedTags = Object.keys(CommitsData.refs.tags).filter((tag) =>
    /^v\d+\.\d+\.\d+$/.test(tag)
  );
  const firstReleasedTag = releasedTags[0];

  test("provisional changelog displays the provisional notice", async function (assert) {
    await visit(`/changelog/${firstProvisional}`);

    assert.dom(".provisional-notice").exists("shows provisional notice");
    assert
      .dom(".provisional-notice")
      .includesText(
        firstProvisional,
        "notice mentions the provisional version"
      );
  });

  test("provisional changelog displays commits", async function (assert) {
    await visit(`/changelog/${firstProvisional}`);

    assert.dom(".commit-viewer").exists("shows commit viewer");
    assert.dom(".commit-card").exists("shows commits");
  });

  test("provisional changelog shows correct version in range display", async function (assert) {
    await visit(`/changelog/${firstProvisional}`);

    assert
      .dom(".changelog-range")
      .includesText(
        firstProvisional,
        "range display shows provisional version"
      );
  });

  test("released version does not show provisional notice", async function (assert) {
    await visit(`/changelog/${firstReleasedTag}`);

    assert
      .dom(".provisional-notice")
      .doesNotExist("no provisional notice for released versions");
    assert.dom(".commit-viewer").exists("shows commit viewer");
  });

  test("invalid provisional version returns 404", async function (assert) {
    // Use a version that definitely won't exist
    await visit("/changelog/9999.99.99");

    assert.dom(".error-container").exists("shows error page");
  });

  test("non-next patch version returns 404", async function (assert) {
    // If there's a provisional like v2025.12.1, then v2025.12.999 should 404
    if (firstProvisional) {
      // firstProvisional is like "v2026.1.0", extract major.minor
      const match = firstProvisional.match(/^v?(\d+)\.(\d+)/);
      const nonNextPatch = `v${match[1]}.${match[2]}.999`;

      await visit(`/changelog/${nonNextPatch}`);

      assert
        .dom(".error-container")
        .exists("shows error page for non-next patch");
    } else {
      assert.ok(true, "skipped - no provisional versions available");
    }
  });
});
