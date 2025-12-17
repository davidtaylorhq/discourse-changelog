import Component from '@glimmer/component';
import { service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import CommitCard from './commit-card';
import VerticalCollection from '@html-next/vertical-collection/components/vertical-collection/component';

export default class CommitViewer extends Component {
  @service router;
  @tracked commits = [];
  @tracked isLoading = false;
  @tracked error = null;
  @tracked startHash = '';
  @tracked endHash = '';
  @tracked allCommits = [];

  constructor() {
    super(...arguments);
    this.loadCommitData();
  }

  async loadCommitData() {
    this.isLoading = true;
    try {
      const module = await import('/data/commits.json');
      this.allCommits = module.default;
      this.loadQueryParams();
    } catch (error) {
      this.error = `Failed to load commit data: ${error.message}`;
    } finally {
      this.isLoading = false;
    }
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
    if (!this.allCommits.length) return;

    let filtered = this.allCommits;

    // Find start commit
    if (this.startHash.trim()) {
      const startCommit = this.allCommits.find((c) =>
        c.hash.startsWith(this.startHash.trim())
      );
      if (startCommit) {
        filtered = filtered.filter(
          (c) => c.commitIndex >= startCommit.commitIndex
        );
      } else {
        this.error = `Start commit not found: ${this.startHash}`;
        this.commits = [];
        return;
      }
    }

    // Find end commit
    if (this.endHash.trim()) {
      const endCommit = this.allCommits.find((c) =>
        c.hash.startsWith(this.endHash.trim())
      );
      if (endCommit) {
        filtered = filtered.filter((c) => c.commitIndex <= endCommit.commitIndex);
      } else {
        this.error = `End commit not found: ${this.endHash}`;
        this.commits = [];
        return;
      }
    }

    this.error = null;
    this.commits = filtered;
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
    return this.allCommits.length;
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

      {{#if this.error}}
        <div class="error">
          {{this.error}}
        </div>
      {{/if}}

      {{#if this.isLoading}}
        <div class="loading">Loading commit data...</div>
      {{/if}}

      {{#if this.commits.length}}
        <div class="results-header">
          <h2>{{this.formattedCommitCount}} found</h2>
        </div>

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
