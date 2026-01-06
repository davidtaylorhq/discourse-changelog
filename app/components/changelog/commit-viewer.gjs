import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import VerticalCollection from "@html-next/vertical-collection/components/vertical-collection/component";
import config from "discourse-releases/config/environment";
import {
  AmbiguousRefError,
  ChangelogData,
  countCommitsByType,
  filterAdvisoriesByCommits,
  filterCommits,
  filterFeaturesByCommits,
  sortCommitsByDate,
  UnknownRefError,
} from "../../lib/git-utils.js";
import CommitCard from "./commit-card";
import CommitFilter from "./commit-filter";
import FeatureCard from "./feature-card";
import RangeSelector from "./range-selector";
import SecurityAdvisoryCard from "./security-advisory-card";

const data = new ChangelogData();

export default class CommitViewer extends Component {
  @tracked activeTab = "all";
  @tracked filterText = "";

  get startHash() {
    return this.args.start || "";
  }

  get endHash() {
    return this.args.end || "";
  }

  // Resolves refs and catches AmbiguousRefError
  @cached
  get resolvedRefs() {
    if (!data.commitData) {
      return { start: null, end: null, error: null };
    }

    const endRef = this.endHash.trim() || data.defaultEndRef;
    const startRef =
      this.startHash.trim() ||
      data.getPreviousVersion(endRef) ||
      data.defaultStartRef;

    try {
      return {
        start: data.resolveRef(startRef),
        end: data.resolveRef(endRef),
        error: null,
      };
    } catch (e) {
      if (e instanceof AmbiguousRefError || e instanceof UnknownRefError) {
        return { start: null, end: null, error: e.message };
      }
      throw e;
    }
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
    if (!data.commitData || this.resolvedRefs.error) {
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

  get refError() {
    return this.resolvedRefs.error;
  }

  @cached
  get error() {
    if (this.refError) {
      return this.refError;
    }
    if (!data.commitData) {
      return null;
    }
    return this.commits.length === 0 ? "No commits found" : null;
  }

  @cached
  get matchingFeatures() {
    if (this.resolvedRefs.error) {
      return [];
    }
    return filterFeaturesByCommits(data.newFeatures, this.allCommits, (ref) =>
      data.resolveRef(ref)
    );
  }

  @cached
  get matchingAdvisories() {
    return filterAdvisoriesByCommits(data.securityAdvisories, this.allCommits);
  }

  @action
  handleRangeApply(start, end) {
    this.args.onUpdateRange?.(start, end);
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
          <RangeSelector
            @startValue={{this.startHash}}
            @startDefault={{this.computedStartDefault}}
            @endValue={{this.endHash}}
            @endDefault={{this.defaultEndRef}}
            @onApply={{this.handleRangeApply}}
          />
        </div>
      </div>

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

      {{#if this.matchingAdvisories.length}}
        <div class="section">
          <div class="section-header">
            <h2>Security Fixes</h2>
          </div>
          <div class="advisories-section">
            {{#each this.matchingAdvisories as |advisory|}}
              <SecurityAdvisoryCard @advisory={{advisory}} />
            {{/each}}
          </div>
        </div>
      {{/if}}

      {{#if this.refError}}
        <div class="error">
          {{this.refError}}
        </div>
      {{else}}
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
      {{/if}}
    </div>
  </template>
}
