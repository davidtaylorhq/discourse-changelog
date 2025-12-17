import Component from '@glimmer/component';
import { service } from '@ember/service';
import { tracked, cached } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, concat } from '@ember/helper';
import { get } from '@ember/helper';
import { htmlSafe } from '@ember/template';
import semver from 'semver';
import CommitCard from './commit-card';
import FeatureCard from './feature-card';
import VerticalCollection from '@html-next/vertical-collection/components/vertical-collection/component';
import { getCommitsBetween, getCommitType } from '../lib/git-utils.js';

const COMMIT_TYPES = [
  { key: 'FEATURE', label: 'Feature', color: '#27ae60' },
  { key: 'FIX', label: 'Fix', color: '#c0392b' },
  { key: 'PERF', label: 'Performance', color: '#8e44ad' },
  { key: 'UX', label: 'UX', color: '#2980b9' },
  { key: 'A11Y', label: 'Accessibility', color: '#16a085' },
  { key: 'SECURITY', label: 'Security', color: '#d35400' },
  { key: 'DEV', label: 'Dev', color: '#7f8c8d' },
  { key: 'OTHER', label: 'Other', color: '#95a5a6' },
];

export default class CommitViewer extends Component {
  @service router;
  @tracked isLoading = false;
  @tracked startHash = '';
  @tracked endHash = '';
  @tracked commitData = null; // {commits: {}, refs: {}, baseTag: ''}
  @tracked hiddenTypes = new Set();
  @tracked newFeatures = [];
  @tracked startAdvancedMode = false;
  @tracked endAdvancedMode = false;

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    this.isLoading = true;
    try {
      const [commitsModule, featuresModule] = await Promise.all([
        import('/data/commits.json'),
        import('/data/new-features.json'),
      ]);
      this.commitData = commitsModule.default;
      this.newFeatures = featuresModule.default;
      this.loadQueryParams();
    } catch (error) {
      this.error = `Failed to load data: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
  }

  loadQueryParams() {
    const queryParams = this.router.currentRoute.queryParams;
    this.startHash = queryParams.start || '';
    this.endHash = queryParams.end || '';
  }

  @action
  updateStartHash(event) {
    this.startHash = event.target.value;
    this.updateQueryParams();
  }

  @action
  updateEndHash(event) {
    this.endHash = event.target.value;
    this.updateQueryParams();
  }

  @action
  toggleStartAdvancedMode() {
    this.startAdvancedMode = !this.startAdvancedMode;
    if (!this.startAdvancedMode) {
      // Reset to first option when leaving advanced mode
      this.startHash = this.commitData?.baseTag || '';
      this.updateQueryParams();
    }
  }

  @action
  toggleEndAdvancedMode() {
    this.endAdvancedMode = !this.endAdvancedMode;
    if (!this.endAdvancedMode) {
      // Reset to first option when leaving advanced mode
      this.endHash = '';
      this.updateQueryParams();
    }
  }

  @action
  updateStartRef(event) {
    this.startHash = event.target.value;
    this.updateQueryParams();
  }

  @action
  updateEndRef(event) {
    this.endHash = event.target.value;
    this.updateQueryParams();
  }

  @cached
  get commits() {
    if (!this.commitData) return [];

    const startRef = this.startHash.trim() || this.commitData.baseTag;
    const endRef = this.endHash.trim() || 'main';

    // Get commits between the two refs using graph traversal
    let filtered = getCommitsBetween(this.commitData, startRef, endRef);

    // Filter by commit type
    if (this.hiddenTypes.size > 0) {
      filtered = filtered.filter((commit) => {
        const type = getCommitType(commit.subject) || 'OTHER';
        return !this.hiddenTypes.has(type);
      });
    }

    return filtered;
  }

  @cached
  get error() {
    if (!this.commitData) return null;

    // If user has specified custom refs and we got no commits, show error
    if (
      this.commits.length === 0 &&
      (this.startHash.trim() || this.endHash.trim())
    ) {
      const startRef = this.startHash.trim() || this.commitData.baseTag;
      const endRef = this.endHash.trim() || 'main';
      return `No commits found between "${startRef}" and "${endRef}"`;
    }

    return null;
  }

  @cached
  get matchingFeatures() {
    if (!this.commits.length || !this.newFeatures.length) {
      return [];
    }

    // Create a Set of commit hashes for quick lookup
    const commitHashes = new Set(this.commits.map((c) => c.hash));

    // Get version range from commits (strip +### suffix for comparison)
    const versions = this.commits
      .map((c) => c.version?.replace(/\s*\+\d+$/, ''))
      .filter((v) => v && semver.valid(semver.coerce(v)));

    let oldestVersion = null;
    let newestVersion = null;

    if (versions.length > 0) {
      // Sort versions to find min/max
      const sortedVersions = versions
        .map((v) => semver.coerce(v))
        .filter((v) => v)
        .sort(semver.compare);

      if (sortedVersions.length > 0) {
        oldestVersion = sortedVersions[0];
        newestVersion = sortedVersions[sortedVersions.length - 1];
      }
    }

    // Find features that match either by hash or by version
    return this.newFeatures.filter((feature) => {
      const discourseVersion = feature.discourse_version;
      if (!discourseVersion) return false;

      // Check if it's a full hash (40 characters) and if it matches any commit
      if (
        discourseVersion.length === 40 &&
        commitHashes.has(discourseVersion)
      ) {
        return true;
      }

      // Otherwise, try semver comparison
      if (oldestVersion && newestVersion) {
        const featureVersion = semver.coerce(discourseVersion);
        if (featureVersion) {
          return (
            semver.gte(featureVersion, oldestVersion) &&
            semver.lte(featureVersion, newestVersion)
          );
        }
      }

      return false;
    });
  }


  @action
  isTypeHidden(typeKey) {
    return this.hiddenTypes.has(typeKey);
  }

  @action
  toggleCommitType(typeKey) {
    if (this.hiddenTypes.has(typeKey)) {
      this.hiddenTypes.delete(typeKey);
    } else {
      this.hiddenTypes.add(typeKey);
    }
    this.hiddenTypes = new Set(this.hiddenTypes); // Trigger reactivity
  }

  updateQueryParams() {
    const queryParams = {};
    if (this.startHash) queryParams.start = this.startHash;
    if (this.endHash) queryParams.end = this.endHash;
    this.router.transitionTo({ queryParams });
  }

  get formattedCommitCount() {
    return this.commits.length === 1
      ? '1 commit'
      : `${this.commits.length} commits`;
  }

  get totalCommits() {
    return this.commitData ? Object.keys(this.commitData.commits).length : 0;
  }

  get commitTypes() {
    return COMMIT_TYPES;
  }

  @cached
  get commitTypeCounts() {
    const counts = {};
    COMMIT_TYPES.forEach((type) => {
      counts[type.key] = 0;
    });

    this.commits.forEach((commit) => {
      const type = getCommitType(commit.subject);
      if (type && counts[type] !== undefined) {
        counts[type]++;
      } else if (!type) {
        counts['OTHER']++;
      }
    });

    return counts;
  }

  get sortedRefs() {
    if (!this.commitData) return [];

    const refs = [];

    // Add branches first
    Object.keys(this.commitData.refs.branches).forEach((branch) => {
      refs.push({ value: branch, label: branch, type: 'branch' });
    });

    // Add tags sorted in descending order
    const tags = Object.keys(this.commitData.refs.tags).sort((a, b) => {
      const aVersion = semver.coerce(a);
      const bVersion = semver.coerce(b);
      if (aVersion && bVersion) {
        return semver.rcompare(aVersion, bVersion);
      }
      return b.localeCompare(a);
    });

    tags.forEach((tag) => {
      refs.push({ value: tag, label: tag, type: 'tag' });
    });

    return refs;
  }

  <template>
    <div class="commit-viewer">
      <div class="header">
        <h1>Discourse Changelog</h1>
        <p>View commits since v3.4.0 (total: {{this.totalCommits}} commits)</p>
      </div>

      <div class="form-section">
        <div class="input-group">
          <div class="input-header">
            <label for="start-ref">Start:</label>
            <button
              type="button"
              class="advanced-toggle"
              {{on "click" this.toggleStartAdvancedMode}}
            >
              {{if this.startAdvancedMode "Use Dropdown" "Advanced"}}
            </button>
          </div>

          {{#if this.startAdvancedMode}}
            <input
              id="start-ref"
              type="text"
              value={{this.startHash}}
              placeholder="Enter commit hash..."
              {{on "input" this.updateStartHash}}
            />
            <small class="input-help">Enter a specific commit hash (full or
              partial)</small>
          {{else}}
            <select
              id="start-ref"
              value={{if this.startHash this.startHash this.commitData.baseTag}}
              {{on "change" this.updateStartRef}}
            >
              <option value={{this.commitData.baseTag}}>
                {{this.commitData.baseTag}}
                (base)
              </option>
              {{#each this.sortedRefs as |ref|}}
                <option value={{ref.value}}>
                  {{ref.label}}
                </option>
              {{/each}}
            </select>
            <small class="input-help">Select a tag or branch to start from</small>
          {{/if}}
        </div>

        <div class="input-group">
          <div class="input-header">
            <label for="end-ref">End:</label>
            <button
              type="button"
              class="advanced-toggle"
              {{on "click" this.toggleEndAdvancedMode}}
            >
              {{if this.endAdvancedMode "Use Dropdown" "Advanced"}}
            </button>
          </div>

          {{#if this.endAdvancedMode}}
            <input
              id="end-ref"
              type="text"
              value={{this.endHash}}
              placeholder="Enter commit hash..."
              {{on "input" this.updateEndHash}}
            />
            <small class="input-help">Enter a specific commit hash (full or
              partial)</small>
          {{else}}
            <select
              id="end-ref"
              value={{if this.endHash this.endHash "main"}}
              {{on "change" this.updateEndRef}}
            >
              {{#each this.sortedRefs as |ref|}}
                <option value={{ref.value}}>
                  {{ref.label}}
                </option>
              {{/each}}
            </select>
            <small class="input-help">Select a tag or branch to end at</small>
          {{/if}}
        </div>
      </div>

      {{#if this.matchingFeatures.length}}
        <details class="collapsible-section" open>
          <summary class="section-header">
            <h2>Highlights</h2>
          </summary>
          <div class="features-section">
            {{#each this.matchingFeatures as |feature|}}
              <FeatureCard @feature={{feature}} />
            {{/each}}
          </div>
        </details>
      {{/if}}

      <details class="collapsible-section" open>
        <summary class="section-header">
          <h2>Detailed Changes</h2>
        </summary>

        <div class="filter-section">
        <div class="filter-pills">
          {{#each this.commitTypes as |type|}}
            <button
              type="button"
              class="filter-pill {{if (this.isTypeHidden type.key) 'hidden'}}"
              style={{htmlSafe (concat "--pill-color: " type.color)}}
              {{on "click" (fn this.toggleCommitType type.key)}}
            >
              {{type.label}}
              ({{get this.commitTypeCounts type.key}})
            </button>
          {{/each}}
        </div>
      </div>

      {{#if this.error}}
        <div class="error">
          {{this.error}}
        </div>
      {{/if}}

      {{#if this.isLoading}}
        <div class="loading">Loading commit data...</div>
      {{/if}}

      {{#if this.commits.length}}
        <VerticalCollection
          @items={{this.commits}}
          @estimateHeight={{120}}
          @staticHeight={{false}}
          @tagName="div"
          @class="commits-list"
          @useContentTags={{true}}
          @containerSelector="body"
          as |commit|
        >
          <CommitCard @commit={{commit}} />
        </VerticalCollection>
      {{/if}}
      </details>
    </div>
  </template>
}
