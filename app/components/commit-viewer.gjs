import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import VerticalCollection from "@html-next/vertical-collection/components/vertical-collection/component";
import config from "discourse-changelog/config/environment";
import {
  ChangelogData,
  countCommitsByType,
  filterCommits,
  filterFeaturesByCommits,
  sortCommitsByDate,
} from "../lib/git-utils.js";
import CommitCard from "./commit-card";
import CommitFilter from "./commit-filter";
import FeatureCard from "./feature-card";
import RefSelector from "./ref-selector";

const data = new ChangelogData();

export default class CommitViewer extends Component {
  @tracked activeTab = "all";
  @tracked filterText = "";
  @tracked showSelectorUI = false;

  get startHash() {
    return this.args.start || "";
  }

  get endHash() {
    return this.args.end || "";
  }

  // Computed default for start ref - based on end ref
  get computedStartDefault() {
    if (!data.commitData) {
      return data.defaultStartRef;
    }
    const endRef = this.endHash.trim() || data.defaultEndRef;
    return data.getPreviousVersion(endRef) || data.defaultStartRef;
  }

  @cached
  get allCommits() {
    if (!data.commitData) {
      return [];
    }

    const endRef = this.endHash.trim() || data.defaultEndRef;
    const startRef =
      this.startHash.trim() ||
      data.getPreviousVersion(endRef) ||
      data.defaultStartRef;

    return data.getCommitsBetween(startRef, endRef);
  }

  @cached
  get commits() {
    const filtered = filterCommits(this.allCommits, {
      type: this.activeTab,
      searchTerm: this.filterText,
    });
    return sortCommitsByDate(filtered, "desc");
  }

  @cached
  get error() {
    if (!data.commitData) {
      return null;
    }
    return this.commits.length === 0 ? "No commits found" : null;
  }

  @cached
  get matchingFeatures() {
    return filterFeaturesByCommits(data.newFeatures, this.allCommits, (ref) =>
      data.resolveRef(ref)
    );
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

  get defaultEndRef() {
    return data.defaultEndRef;
  }

  @cached
  get commitTypeCounts() {
    return countCommitsByType(this.allCommits);
  }

  get displayStartRef() {
    if (!data.commitData) {
      return "";
    }
    const endRef = this.endHash.trim() || data.defaultEndRef;
    return (
      this.startHash.trim() ||
      data.getPreviousVersion(endRef) ||
      data.defaultStartRef
    );
  }

  get displayEndRef() {
    return this.endHash.trim() || data.defaultEndRef;
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
          <RefSelector
            @inputId="start-ref"
            @label="Start"
            @value={{this.startHash}}
            @defaultValue={{this.computedStartDefault}}
            @onUpdate={{this.args.onUpdateStart}}
          />
          <RefSelector
            @inputId="end-ref"
            @label="End"
            @value={{this.endHash}}
            @defaultValue={{this.defaultEndRef}}
            @onUpdate={{this.args.onUpdateEnd}}
          />
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

        <CommitFilter
          @activeTab={{this.activeTab}}
          @onTabChange={{this.setActiveTab}}
          @totalCount={{this.allCommits.length}}
          @typeCounts={{this.commitTypeCounts}}
          @filterText={{this.filterText}}
          @onFilterChange={{this.updateFilterText}}
        />

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
