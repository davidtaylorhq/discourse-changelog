import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import VerticalCollection from "@html-next/vertical-collection/components/vertical-collection/component";
import semver from "semver";
import config from "discourse-changelog/config/environment";
import {
  ChangelogData,
  COMMIT_TYPES,
  getCommitType,
  parseVersion,
} from "../lib/git-utils.js";
import CommitCard from "./commit-card";
import FeatureCard from "./feature-card";

const eq = helper(([a, b]) => a === b);

const data = new ChangelogData();

const DEFAULT_START_REF = data.sortedTags[0].value;
const DEFAULT_END_REF = "latest";

export default class CommitViewer extends Component {
  @tracked activeTab = "all";
  @tracked filterText = "";
  @tracked startAdvancedMode = false;
  @tracked endAdvancedMode = false;
  @tracked showSelectorUI = false;

  isStartSelected = (value) => {
    if (this.startHash) {
      return this.startHash === value;
    }
    // When start is not specified, compute the previous version from end
    if (!data.commitData) {
      return false;
    }
    const endRef = this.endHash.trim() || DEFAULT_END_REF;
    const computedStart = data.getPreviousVersion(endRef) || DEFAULT_START_REF;
    return value === computedStart;
  };

  isEndSelected = (value) => {
    if (this.endHash) {
      return this.endHash === value;
    }
    return value === DEFAULT_END_REF;
  };

  get startHash() {
    return this.args.start || "";
  }

  get endHash() {
    return this.args.end || "";
  }

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
    if (!data.commitData) {
      return [];
    }

    const endRef = this.endHash.trim() || DEFAULT_END_REF;

    // If start is not specified, find the previous version from end
    let startRef = this.startHash.trim();
    if (!startRef) {
      startRef = data.getPreviousVersion(endRef) || DEFAULT_START_REF;
    }

    // Get commits between the two refs using graph traversal
    return data.getCommitsBetween(startRef, endRef);
  }

  @cached
  get commits() {
    let filtered = this.allCommits;

    // Filter by active tab
    if (this.activeTab !== "all") {
      filtered = filtered.filter((commit) => {
        const type = getCommitType(commit.subject) || "OTHER";
        return type === this.activeTab;
      });
    }

    // Filter by search text
    if (this.filterText.trim()) {
      const searchTerm = this.filterText.toLowerCase();
      filtered = filtered.filter((commit) => {
        return commit.subject.toLowerCase().includes(searchTerm);
      });
    }

    // Sort chronologically, newest first
    return this.sortChronological(filtered, "desc");
  }

  @cached
  get error() {
    if (!data.commitData) {
      return null;
    }

    // If user has specified custom refs and we got no commits, show error
    if (this.commits.length === 0) {
      const endRef = this.endHash.trim() || DEFAULT_END_REF;
      let startRef = this.startHash.trim();
      if (!startRef) {
        startRef = data.getPreviousVersion(endRef) || DEFAULT_START_REF;
      }
      return `No commits found`;
    }

    return null;
  }

  @cached
  get matchingFeatures() {
    if (!this.allCommits.length || !data.newFeatures.length) {
      return [];
    }

    // Create a Set of commit hashes for quick lookup
    const commitHashes = new Set(this.allCommits.map((c) => c.hash));

    const newestVersion = parseVersion(
      this.allCommits[0].version?.replace(/\s*\+\d+$/, "")
    );

    const oldestVersion = parseVersion(
      this.allCommits.at(-1).version?.replace(/\s*\+\d+$/, "")
    );

    // Find features that match either by hash or by version
    return data.newFeatures.filter((feature) => {
      const discourseVersion = feature.discourse_version;
      if (!discourseVersion) {
        return false;
      }

      if (discourseVersion.match(/\d+\.\d+\.\d+/)) {
        const parsedVersion = parseVersion(discourseVersion);
        return (
          semver.gt(parsedVersion, oldestVersion) &&
          semver.lte(parsedVersion, newestVersion)
        );
      } else {
        const fullCommitHash = data.resolveRef(discourseVersion);
        return commitHashes.has(fullCommitHash);
      }
    });
  }

  @action
  toggleSelectorUI() {
    this.showSelectorUI = !this.showSelectorUI;
  }

  @action
  setActiveTab(tab) {
    this.activeTab = tab;
  }

  @action
  updateFilterText(event) {
    this.filterText = event.target.value;
  }

  get formattedCommitCount() {
    return this.commits.length === 1
      ? "1 commit"
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
        counts["OTHER"]++;
      }
    });

    return counts;
  }

  sortChronological(commits, direction) {
    return [...commits].sort((a, b) => {
      const dateA = new Date(a.date);
      const dateB = new Date(b.date);
      return direction === "desc" ? dateB - dateA : dateA - dateB;
    });
  }

  get displayStartRef() {
    if (!data.commitData) {
      return "";
    }
    const endRef = this.endHash.trim() || DEFAULT_END_REF;
    let startRef = this.startHash.trim();
    if (!startRef) {
      startRef = data.getPreviousVersion(endRef) || DEFAULT_START_REF;
    }
    return startRef;
  }

  get displayEndRef() {
    return this.endHash.trim() || DEFAULT_END_REF;
  }

  get bufferSize() {
    // In test mode, render all commits to avoid flaky tests
    return config.environment === "test" ? 9999 : 5;
  }

  <template>
    <div class="commit-viewer">
      <a href="/" class="back-to-versions">← Back to Versions</a>
      <div class="header">
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
                  {{#each data.branches as |ref|}}
                    <option
                      value={{ref.value}}
                      selected={{this.isStartSelected ref.value}}
                    >
                      {{ref.label}}
                    </option>
                  {{/each}}
                </optgroup>
                <optgroup label="Tags">
                  {{#each data.sortedTags as |ref|}}
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
                  {{#each data.branches as |ref|}}
                    <option
                      value={{ref.value}}
                      selected={{this.isEndSelected ref.value}}
                    >
                      {{ref.label}}
                    </option>
                  {{/each}}
                </optgroup>
                <optgroup label="Tags">
                  {{#each data.sortedTags as |ref|}}
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
        <div class="section">
          <div class="section-header">
            <h2>Highlights</h2>
          </div>
          <div class="features-section">
            {{#each this.matchingFeatures as |feature|}}
              <FeatureCard @feature={{feature}} />
            {{/each}}
          </div>
        </div>
      {{/if}}

      <div class="section">
        <div class="section-header">
          <h2>Detailed Changes</h2>
        </div>

        <div class="filter-section">
          <div class="commit-tabs">
            <button
              type="button"
              class="commit-tab {{if (eq this.activeTab 'all') 'active'}}"
              {{on "click" (fn this.setActiveTab "all")}}
            >
              All
              <span class="tab-count">({{this.allCommits.length}})</span>
            </button>
            {{#each this.commitTypes as |type|}}
              <button
                type="button"
                class="commit-tab {{if (eq this.activeTab type.key) 'active'}}"
                style={{htmlSafe (concat "--tab-color: " type.color)}}
                {{on "click" (fn this.setActiveTab type.key)}}
              >
                {{type.label}}
                <span class="tab-count">({{get
                    this.commitTypeCounts
                    type.key
                  }})</span>
              </button>
            {{/each}}
          </div>

          <div class="filter-input-wrapper">
            <input
              type="text"
              class="filter-input"
              placeholder="Filter commits..."
              value={{this.filterText}}
              {{on "input" this.updateFilterText}}
            />
          </div>
        </div>

        {{#if this.error}}
          <div class="error">
            {{this.error}}
          </div>
        {{/if}}

        {{#if data.isLoading}}
          <div class="loading">Loading commit data...</div>
        {{/if}}

        {{#if this.commits.length}}
          <VerticalCollection
            @items={{this.commits}}
            @estimateHeight={{120}}
            @staticHeight={{false}}
            @tagName="div"
            @class="commits-list"
            @containerSelector="body"
            @bufferSize={{this.bufferSize}}
            as |commit|
          >
            <CommitCard @commit={{commit}} @searchTerm={{this.filterText}} />
          </VerticalCollection>
        {{/if}}
      </div>
    </div>
  </template>
}
