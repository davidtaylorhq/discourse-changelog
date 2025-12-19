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
import {
  ChangelogData,
  getCommitType,
  parseVersion,
} from '../lib/git-utils.js';

const COMMIT_TYPES = [
  { key: 'FEATURE', label: 'Feature', color: '#27ae60' },
  { key: 'FIX', label: 'Fix', color: '#c0392b' },
  { key: 'PERF', label: 'Performance', color: '#8e44ad' },
  { key: 'UX', label: 'UX', color: '#2980b9' },
  { key: 'A11Y', label: 'Accessibility', color: '#16a085' },
  { key: 'SECURITY', label: 'Security', color: '#d35400' },
  { key: 'TRANSLATIONS', label: 'Translations', color: '#e91e63' },
  { key: 'DEV', label: 'Dev', color: '#7f8c8d' },
  { key: 'OTHER', label: 'Other', color: '#95a5a6' },
];

const DEFAULT_START_REF = 'v2025.11.0';
const DEFAULT_END_REF = 'latest';

export default class CommitViewer extends Component {
  @tracked data = new ChangelogData();
  @tracked activeTypes = new Set();
  @tracked startAdvancedMode = false;
  @tracked endAdvancedMode = false;
  @tracked showSelectorUI = false;

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    try {
      await this.data.load();
    } catch (error) {
      console.error('Failed to load data:', error);
    }
  }

  get startHash() {
    return this.args.start || '';
  }

  get endHash() {
    return this.args.end || '';
  }

  isStartSelected = (value) => {
    if (this.startHash) {
      return this.startHash === value;
    }
    // When start is not specified, compute the previous version from end
    if (!this.data.commitData) {
      return false;
    }
    const endRef = this.endHash.trim() || DEFAULT_END_REF;
    const computedStart =
      this.data.getPreviousVersion(endRef) || DEFAULT_START_REF;
    return value === computedStart;
  };

  isEndSelected = (value) => {
    if (this.endHash) {
      return this.endHash === value;
    }
    return value === DEFAULT_END_REF;
  };

  @action
  updateStartHash(event) {
    this.args.onUpdateStart?.(event.target.value);
  }

  @action
  updateEndHash(event) {
    this.args.onUpdateEnd?.(event.target.value);
  }

  @action
  toggleStartAdvancedMode() {
    this.startAdvancedMode = !this.startAdvancedMode;
    if (!this.startAdvancedMode) {
      // Reset to default when leaving advanced mode
      this.args.onUpdateStart?.(DEFAULT_START_REF);
    }
  }

  @action
  toggleEndAdvancedMode() {
    this.endAdvancedMode = !this.endAdvancedMode;
    if (!this.endAdvancedMode) {
      // Reset to default when leaving advanced mode
      this.args.onUpdateEnd?.(DEFAULT_END_REF);
    }
  }

  @action
  updateStartRef(event) {
    this.args.onUpdateStart?.(event.target.value);
  }

  @action
  updateEndRef(event) {
    this.args.onUpdateEnd?.(event.target.value);
  }

  @cached
  get allCommits() {
    if (!this.data.commitData) return [];

    const endRef = this.endHash.trim() || DEFAULT_END_REF;

    // If start is not specified, find the previous version from end
    let startRef = this.startHash.trim();
    if (!startRef) {
      startRef = this.data.getPreviousVersion(endRef) || DEFAULT_START_REF;
    }

    // Get commits between the two refs using graph traversal
    return this.data.getCommitsBetween(startRef, endRef);
  }

  @cached
  get commits() {
    let filtered = this.allCommits;

    // Filter by commit type - show only active types if any are selected
    if (this.activeTypes.size > 0) {
      filtered = filtered.filter((commit) => {
        const type = getCommitType(commit.subject) || 'OTHER';
        return this.activeTypes.has(type);
      });
    }

    return filtered;
  }

  @cached
  get error() {
    if (!this.data.commitData) return null;

    // If user has specified custom refs and we got no commits, show error
    if (this.commits.length === 0) {
      const endRef = this.endHash.trim() || DEFAULT_END_REF;
      let startRef = this.startHash.trim();
      if (!startRef) {
        startRef = this.data.getPreviousVersion(endRef) || DEFAULT_START_REF;
      }
      return `No commits found between "${startRef}" and "${endRef}"`;
    }

    return null;
  }

  @cached
  get matchingFeatures() {
    if (!this.allCommits.length || !this.data.newFeatures.length) {
      return [];
    }

    // Create a Set of commit hashes for quick lookup
    const commitHashes = new Set(this.allCommits.map((c) => c.hash));

    const newestVersion = parseVersion(
      this.allCommits[0].version?.replace(/\s*\+\d+$/, '')
    );

    const oldestVersion = parseVersion(
      this.allCommits.at(-1).version?.replace(/\s*\+\d+$/, '')
    );

    console.log(oldestVersion, newestVersion);

    // Find features that match either by hash or by version
    return this.data.newFeatures.filter((feature) => {
      const discourseVersion = feature.discourse_version;
      if (!discourseVersion) return false;

      if (discourseVersion.match(/\d+\.\d+\.\d+/)) {
        const parsedVersion = parseVersion(discourseVersion);
        return (
          semver.gt(parsedVersion, oldestVersion) &&
          semver.lte(parsedVersion, newestVersion)
        );
      } else {
        const fullCommitHash = this.data.resolveRef(discourseVersion);
        return commitHashes.has(fullCommitHash);
      }
    });
  }

  @action
  isTypeActive(typeKey) {
    // If no types are active, all types are shown (return true)
    if (this.activeTypes.size === 0) return true;
    return this.activeTypes.has(typeKey);
  }

  @action
  toggleCommitType(typeKey, event) {
    const isModifierKey = event.metaKey || event.ctrlKey;

    if (isModifierKey) {
      // Mod+click: toggle this type in the active set
      if (this.activeTypes.has(typeKey)) {
        this.activeTypes.delete(typeKey);
      } else {
        this.activeTypes.add(typeKey);
      }
    } else {
      // Regular click
      if (this.activeTypes.size === 1 && this.activeTypes.has(typeKey)) {
        // If this is the only active type, clear filter (show all)
        this.activeTypes.clear();
      } else {
        // Otherwise, make this the only active type
        this.activeTypes.clear();
        this.activeTypes.add(typeKey);
      }
    }

    this.activeTypes = new Set(this.activeTypes); // Trigger reactivity
  }

  @action
  toggleSelectorUI() {
    this.showSelectorUI = !this.showSelectorUI;
  }

  get formattedCommitCount() {
    return this.commits.length === 1
      ? '1 commit'
      : `${this.commits.length} commits`;
  }

  get commitTypes() {
    return COMMIT_TYPES;
  }

  get defaultStartRef() {
    return DEFAULT_START_REF;
  }

  get defaultEndRef() {
    return DEFAULT_END_REF;
  }

  @cached
  get commitTypeCounts() {
    const counts = {};
    COMMIT_TYPES.forEach((type) => {
      counts[type.key] = 0;
    });

    this.allCommits.forEach((commit) => {
      const type = getCommitType(commit.subject);
      if (type && counts[type] !== undefined) {
        counts[type]++;
      } else if (!type) {
        counts['OTHER']++;
      }
    });

    return counts;
  }

  get displayStartRef() {
    if (!this.data.commitData) return '';
    const endRef = this.endHash.trim() || DEFAULT_END_REF;
    let startRef = this.startHash.trim();
    if (!startRef) {
      startRef = this.data.getPreviousVersion(endRef) || DEFAULT_START_REF;
    }
    return startRef;
  }

  get displayEndRef() {
    return this.endHash.trim() || DEFAULT_END_REF;
  }

  <template>
    <div class="commit-viewer">
      <a href="/" class="back-to-versions">← Back to Versions</a>
      <div class="header">
        <h1>Discourse Changelog</h1>
        <div class="changelog-info">
          <p class="changelog-range">
            <strong>{{this.displayStartRef}}</strong>
            →
            <strong>{{this.displayEndRef}}</strong>
          </p>
          <button
            type="button"
            class="toggle-selector-btn"
            {{on "click" this.toggleSelectorUI}}
          >
            {{if this.showSelectorUI "Hide" "Customize"}}
            Range
          </button>
        </div>
      </div>

      {{#if this.showSelectorUI}}
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
              <select id="start-ref" {{on "change" this.updateStartRef}}>
                <optgroup label="Branches">
                  {{#each this.data.branches as |ref|}}
                    <option
                      value={{ref.value}}
                      selected={{this.isStartSelected ref.value}}
                    >
                      {{ref.label}}
                    </option>
                  {{/each}}
                </optgroup>
                <optgroup label="Tags">
                  {{#each this.data.sortedTags as |ref|}}
                    <option
                      value={{ref.value}}
                      selected={{this.isStartSelected ref.value}}
                    >
                      {{ref.label}}
                    </option>
                  {{/each}}
                </optgroup>
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
              <select id="end-ref" {{on "change" this.updateEndRef}}>
                <optgroup label="Branches">
                  {{#each this.data.branches as |ref|}}
                    <option
                      value={{ref.value}}
                      selected={{this.isEndSelected ref.value}}
                    >
                      {{ref.label}}
                    </option>
                  {{/each}}
                </optgroup>
                <optgroup label="Tags">
                  {{#each this.data.sortedTags as |ref|}}
                    <option
                      value={{ref.value}}
                      selected={{this.isEndSelected ref.value}}
                    >
                      {{ref.label}}
                    </option>
                  {{/each}}
                </optgroup>
              </select>
              <small class="input-help">Select a tag or branch to end at</small>
            {{/if}}
          </div>
        </div>
      {{/if}}

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
                class="filter-pill {{unless (this.isTypeActive type.key) 'hidden'}}"
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

        {{#if this.data.isLoading}}
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
