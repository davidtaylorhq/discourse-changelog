import Component from '@glimmer/component';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { get } from '@ember/helper';
import semver from 'semver';
import CommitCard from './commit-card';
import FeatureCard from './feature-card';
import VerticalCollection from '@html-next/vertical-collection/components/vertical-collection/component';

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
  @tracked commits = [];
  @tracked isLoading = false;
  @tracked error = null;
  @tracked startHash = '';
  @tracked endHash = '';
  @tracked commitData = null; // {commits: {}, refs: {}, baseTag: ''}
  @tracked hiddenTypes = new Set();
  @tracked newFeatures = [];
  @tracked matchingFeatures = [];

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

  // Resolve a ref (tag/branch/hash) to a commit hash
  resolveRef(ref) {
    if (!this.commitData) return ref;

    // Check if it's a tag
    if (this.commitData.refs.tags[ref]) {
      return this.commitData.refs.tags[ref];
    }

    // Check if it's a branch
    if (this.commitData.refs.branches[ref]) {
      return this.commitData.refs.branches[ref];
    }

    // Check if it's a partial hash
    if (ref.length < 40) {
      const fullHash = Object.keys(this.commitData.commits).find((h) =>
        h.startsWith(ref)
      );
      return fullHash || ref;
    }

    // Otherwise assume it's a full hash
    return ref;
  }

  // Iterative traversal to find all commits reachable from a given commit
  traverseParents(commitHash) {
    if (!this.commitData) return new Set();

    const visited = new Set();
    const queue = [commitHash];

    while (queue.length > 0) {
      const currentHash = queue.shift();

      // Skip if already visited or not in our dataset
      if (!currentHash || visited.has(currentHash) || !this.commitData.commits[currentHash]) {
        continue;
      }

      visited.add(currentHash);
      const commit = this.commitData.commits[currentHash];

      // Add parents to queue
      if (commit.parents) {
        commit.parents.forEach((parentHash) => {
          if (!visited.has(parentHash)) {
            queue.push(parentHash);
          }
        });
      }
    }

    return visited;
  }

  // Get commits between two refs
  getCommitsBetween(startRef, endRef) {
    if (!this.commitData) return [];

    // Resolve refs to commit hashes
    const startHash = this.resolveRef(startRef);
    const endHash = this.resolveRef(endRef);

    // Build set of all commits reachable from startRef (exclusive set)
    const reachableFromStart = this.traverseParents(startHash);

    // Build set of all commits reachable from endRef (inclusive set)
    const reachableFromEnd = this.traverseParents(endHash);

    // Difference: commits in endRef but not in startRef
    const betweenSet = new Set(
      [...reachableFromEnd].filter((hash) => !reachableFromStart.has(hash))
    );

    // Convert to commit objects
    return [...betweenSet].map((hash) => this.commitData.commits[hash]).filter((c) => c);
  }

  loadQueryParams() {
    const queryParams = this.router.currentRoute.queryParams;
    this.startHash = queryParams.start || '';
    this.endHash = queryParams.end || '';
    this.updateCommitRange();
  }

  @action
  updateStartHash(event) {
    this.startHash = event.target.value;
    this.updateQueryParams();
    this.updateCommitRange();
  }

  @action
  updateEndHash(event) {
    this.endHash = event.target.value;
    this.updateQueryParams();
    this.updateCommitRange();
  }

  updateCommitRange() {
    if (!this.commitData) return;

    const startRef = this.startHash.trim() || this.commitData.baseTag;
    const endRef = this.endHash.trim() || 'main';

    // Get commits between the two refs using graph traversal
    let filtered = this.getCommitsBetween(startRef, endRef);

    if (filtered.length === 0 && (this.startHash.trim() || this.endHash.trim())) {
      this.error = `No commits found between "${startRef}" and "${endRef}"`;
      this.commits = [];
      return;
    }

    // Filter by commit type
    if (this.hiddenTypes.size > 0) {
      filtered = filtered.filter((commit) => {
        const type = this.getCommitType(commit.subject) || 'OTHER';
        return !this.hiddenTypes.has(type);
      });
    }

    this.error = null;
    this.commits = filtered;
    this.updateMatchingFeatures();
  }

  updateMatchingFeatures() {
    if (!this.commits.length || !this.newFeatures.length) {
      this.matchingFeatures = [];
      return;
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
    this.matchingFeatures = this.newFeatures.filter((feature) => {
      const discourseVersion = feature.discourse_version;
      if (!discourseVersion) return false;

      // Check if it's a full hash (40 characters) and if it matches any commit
      if (discourseVersion.length === 40 && commitHashes.has(discourseVersion)) {
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

  getCommitType(subject) {
    const match = subject.match(/^(FEATURE|FIX|PERF|UX|A11Y|SECURITY|DEV):/);
    return match ? match[1] : null;
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
    this.updateCommitRange();
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

  get commitTypeCounts() {
    const counts = {};
    COMMIT_TYPES.forEach(type => {
      counts[type.key] = 0;
    });

    if (!this.commitData) return counts;

    Object.values(this.commitData.commits).forEach(commit => {
      const type = this.getCommitType(commit.subject);
      if (type && counts[type] !== undefined) {
        counts[type]++;
      } else if (!type) {
        counts['OTHER']++;
      }
    });

    return counts;
  }

  <template>
    <div class="commit-viewer">
      <div class="header">
        <h1>Discourse Changelog</h1>
        <p>View commits since v3.4.0 (total: {{this.totalCommits}} commits)</p>
      </div>

      <div class="form-section">
        <div class="input-group">
          <label for="start-hash">Start Commit (optional):</label>
          <input
            id="start-hash"
            type="text"
            value={{this.startHash}}
            placeholder="Leave empty for first commit, or enter commit hash..."
            {{on "input" this.updateStartHash}}
          />
          <small class="input-help">Enter a commit hash (full or partial) or leave empty to start from the beginning</small>
        </div>

        <div class="input-group">
          <label for="end-hash">End Commit (optional):</label>
          <input
            id="end-hash"
            type="text"
            value={{this.endHash}}
            placeholder="Leave empty for latest commit, or enter commit hash..."
            {{on "input" this.updateEndHash}}
          />
          <small class="input-help">Enter a commit hash (full or partial) or leave empty to show up to the latest</small>
        </div>
      </div>

      {{#if this.matchingFeatures.length}}
        <div class="section-header">
          <h2>Highlights</h2>
        </div>
        <div class="features-section">
          {{#each this.matchingFeatures as |feature|}}
            <FeatureCard @feature={{feature}} />
          {{/each}}
        </div>
      {{/if}}

      <div class="section-header">
        <h2>Detailed Changes</h2>
      </div>

      <div class="filter-section">
        <div class="filter-pills">
          {{#each this.commitTypes as |type|}}
            <button
              type="button"
              class="filter-pill {{if (this.isTypeHidden type.key) 'hidden'}}"
              style="--pill-color: {{type.color}}"
              {{on "click" (fn this.toggleCommitType type.key)}}
            >
              {{type.label}} ({{get this.commitTypeCounts type.key}})
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
    </div>
  </template>
}
