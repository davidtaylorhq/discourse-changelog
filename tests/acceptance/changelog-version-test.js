import { module, test } from 'qunit';
import { visit, fillIn, click, currentURL, findAll } from '@ember/test-helpers';
import { setupApplicationTest } from 'discourse-changelog/tests/helpers';

module('Acceptance | changelog version', function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(async function () {
    await visit('/changelog/v2025.11.0');
  });

  test('displays commit viewer', async function (assert) {
    assert.dom('.commit-viewer').exists();
  });

  test('displays version range', async function (assert) {
    assert.dom('.changelog-range').hasText(/→/);
    assert.dom('.changelog-range strong').exists({ count: 2 });
  });

  test('displays back link', async function (assert) {
    assert.dom('.back-to-versions').hasAttribute('href', '/');
  });

  test('displays commit tabs', async function (assert) {
    assert.dom('.commit-tab.active').exists();
    assert.dom('.commit-tab.active').hasText(/All/);
  });

  test('displays filter input', async function (assert) {
    assert.dom('.filter-input').hasAttribute('placeholder', 'Filter commits...');
  });

  test('displays commits', async function (assert) {
    assert.dom('.commit-card').exists();
    assert.dom('.commit-subject').exists();
    assert.dom('.commit-date').exists();
  });

  test('filters commits by search text', async function (assert) {
    await fillIn('.filter-input', 'xyz-nonexistent-search-term');

    assert.dom('.commit-card').doesNotExist();
  });

  test('commit cards show detailed metadata', async function (assert) {
    assert.dom('.commit-card .commit-subject').exists();
    assert.dom('.commit-card .commit-date').exists();
    assert.dom('.commit-card .commit-time').exists();
    assert.dom('.commit-card .commit-badge').exists();
  });

  test('commits can be expanded and collapsed', async function (assert) {
    const firstCommit = '.commit-card';

    // Initially should be collapsed
    assert.dom(`${firstCommit} .commit-details`).doesNotHaveAttribute('open');

    // Click to expand
    await click(firstCommit);
    assert.dom(`${firstCommit} .commit-details`).hasAttribute('open');
    assert.dom(`${firstCommit} .commit-author`).exists();

    // Click to collapse
    await click(firstCommit);
    assert.dom(`${firstCommit} .commit-details`).doesNotHaveAttribute('open');
  });

  test('filter tabs actually filter commits', async function (assert) {
    const tabs = findAll('.commit-tab');
    assert.true(tabs.length > 1);

    // Count all commits initially (excluding feature cards)
    const allCount = findAll('.commit-card:not(.feature-card)').length;
    assert.true(allCount > 0, 'Should have commits displayed');

    // Click a filter tab (not "All")
    await click(tabs[1]);
    assert.dom(tabs[1]).hasClass('active');

    // Count filtered commits
    const filteredCount = findAll('.commit-card:not(.feature-card)').length;
    assert.true(filteredCount > 0, 'Should have some commits after filtering');
    assert.true(filteredCount <= allCount, 'Filtered commits should not exceed total');

    // Click back to "All" tab
    await click(tabs[0]);
    assert.dom(tabs[0]).hasClass('active');

    // Verify we have the same count as before
    const backToAllCount = findAll('.commit-card:not(.feature-card)').length;
    assert.strictEqual(backToAllCount, allCount, 'Should show all commits again');
  });

  test('feature cards are displayed', async function (assert) {
    assert.dom('.feature-card').exists();
    assert.dom('.feature-card .feature-title').exists();
    assert.dom('.feature-card .feature-description').exists();
  });
});
