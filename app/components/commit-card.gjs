import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { htmlSafe } from '@ember/template';
import './commit-card.css';
import { concat } from '@ember/helper';
import { getCommitType } from '../lib/git-utils.js';

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

const COMMIT_TYPE_CONFIG = {
  FEATURE: { label: 'Feature', color: '#27ae60' },
  FIX: { label: 'Fix', color: '#c0392b' },
  PERF: { label: 'Performance', color: '#8e44ad' },
  UX: { label: 'UX', color: '#2980b9' },
  A11Y: { label: 'Accessibility', color: '#16a085' },
  SECURITY: { label: 'Security', color: '#d35400' },
  TRANSLATIONS: { label: 'Translations', color: '#e91e63' },
  DEV: { label: 'Dev', color: '#7f8c8d' },
};

export default class CommitCard extends Component {
  get commitUrl() {
    return `https://github.com/discourse/discourse/commit/${this.args.commit.hash}`;
  }

  get shortHash() {
    return this.args.commit.hash.substring(0, 7);
  }

  get formattedDate() {
    const date = new Date(this.args.commit.date);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  }

  get formattedTime() {
    const date = new Date(this.args.commit.date);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  get commitType() {
    return getCommitType(this.args.commit.subject);
  }

  get commitTypeConfig() {
    return this.commitType ? COMMIT_TYPE_CONFIG[this.commitType] : null;
  }

  get subjectWithLinks() {
    const subject = this.args.commit.subject;
    // Escape the entire text first
    const escaped = escapeHtml(subject);
    // Then replace PR references with links (now safe)
    const withLinks = escaped.replace(
      /\(#(\d+)\)/g,
      '<a href="https://github.com/discourse/discourse/pull/$1" target="_blank" class="pr-link" onclick="event.stopPropagation()">(#$1)</a>'
    );
    return htmlSafe(withLinks);
  }

  @action
  openCommit() {
    window.open(this.commitUrl, '_blank');
  }

  <template>
    <div class="commit-card" {{on "click" this.openCommit}}>
      <div class="commit-header">
        <div class="commit-message">
          {{this.subjectWithLinks}}
        </div>
        <div class="commit-tags">
          {{#if this.commitTypeConfig}}
            <span
              class="commit-badge"
              style={{htmlSafe
                (concat "background-color: " this.commitTypeConfig.color)
              }}
            >{{this.commitTypeConfig.label}}</span>
          {{/if}}
          <span class="commit-sha">
            {{this.shortHash}}
          </span>
        </div>
      </div>

      <div class="commit-meta">
        <span class="commit-author">{{@commit.author}}</span>
        <span class="commit-date">{{this.formattedDate}}
          ·
          {{this.formattedTime}}</span>
      </div>
    </div>
  </template>
}
