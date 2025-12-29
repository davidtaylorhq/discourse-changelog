import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedWeakMap } from "@ember/reactive/collections";
import { htmlSafe } from "@ember/template";
import "./commit-card.css";
import { COMMIT_TYPES, getCommitType } from "../lib/git-utils.js";
import highlightTerm from "../modifiers/highlight-term.js";

const expandedCommits = trackedWeakMap(new WeakMap());

function escapeHtml(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

export default class CommitCard extends Component {
  get commitUrl() {
    return `https://github.com/discourse/discourse/commit/${this.args.commit.hash}`;
  }

  get shortHash() {
    return this.args.commit.hash.substring(0, 7);
  }

  get formattedDate() {
    const date = new Date(this.args.commit.date);
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  get formattedTime() {
    const date = new Date(this.args.commit.date);
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }

  get commitType() {
    return getCommitType(this.args.commit.subject);
  }

  get commitTypeConfig() {
    return this.commitType
      ? COMMIT_TYPES.find((type) => type.key === this.commitType)
      : null;
  }

  get subjectWithLinks() {
    let subject = this.args.commit.subject;

    // Strip known type prefixes
    if (this.commitTypeConfig?.prefix) {
      subject = subject.replace(
        new RegExp(`^${this.commitTypeConfig.prefix}:\\s*`),
        ""
      );
    }

    // Strip PR references
    subject = subject.replace(/\s*\(#\d+\)\s*$/, "");

    // Capitalize first letter
    subject = subject.replace(/^./, (str) => str.toUpperCase());

    return subject;
  }

  get hasBody() {
    return this.args.commit.body && this.args.commit.body.trim().length > 0;
  }

  get prNumber() {
    const match = this.args.commit.subject.match(/\(#(\d+)\)/);
    return match ? match[1] : null;
  }

  get prUrl() {
    if (!this.prNumber) {
      return null;
    }
    return `https://github.com/discourse/discourse/pull/${this.prNumber}`;
  }

  get isExpanded() {
    return expandedCommits.get(this.args.commit) || false;
  }

  get bodyHtml() {
    if (!this.hasBody) {
      return "";
    }

    const body = this.args.commit.body.trim();

    // Escape HTML first
    const escaped = escapeHtml(body);

    // Then add hyperlinks for URLs (now safe)
    const withLinks = escaped.replace(
      /(https?:\/\/[^\s]+)/g,
      '<a href="$1" target="_blank" rel="noopener noreferrer" class="commit-body-link" onclick="event.stopPropagation()">$1</a>'
    );

    return htmlSafe(withLinks);
  }

  @action
  toggleDetails(event) {
    // Don't toggle if clicking on a link
    if (event.target.tagName === "A" || event.target.closest("a")) {
      return;
    }

    // Toggle the expanded state in the WeakMap
    const currentState = expandedCommits.get(this.args.commit) || false;
    expandedCommits.set(this.args.commit, !currentState);

    // Manually toggle the details element to trigger re-render
    const card = event.currentTarget;
    const details = card.querySelector(".commit-details");
    if (details) {
      details.open = !currentState;
    }
  }

  <template>
    <div
      class="commit-card expandable"
      style={{if
        this.commitTypeConfig
        (htmlSafe (concat "border-left-color: " this.commitTypeConfig.color))
      }}
      {{on "click" this.toggleDetails}}
    >
      <div class="commit-header">
        <div
          class="commit-message commit-subject"
          {{highlightTerm searchString=@searchTerm id="search-match"}}
        >
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
          <a
            href={{this.commitUrl}}
            target="_blank"
            rel="noopener noreferrer"
            class="commit-sha"
            title="Open on GitHub"
            onclick="event.stopPropagation()"
          >
            {{this.shortHash}}
          </a>
        </div>
      </div>

      <div class="commit-meta-summary">
        <span class="commit-date">{{this.formattedDate}}</span>
        <span class="commit-time">{{this.formattedTime}}</span>
        {{#if this.prNumber}}
          <span class="commit-separator">·</span>
          <a
            href={{this.prUrl}}
            target="_blank"
            rel="noopener noreferrer"
            class="commit-pr-link"
            title="Open PR on GitHub"
            onclick="event.stopPropagation()"
          >
            #{{this.prNumber}}
          </a>
        {{/if}}
      </div>

      <details class="commit-details" open={{this.isExpanded}}>
        <summary class="commit-summary"></summary>
        <div class="commit-body">
          <div class="commit-meta-details">
            <span class="commit-author">Authored by {{@commit.author}}</span>
            <span class="commit-separator">·</span>
            <span class="commit-version">v{{@commit.version}}</span>
          </div>
          {{#if this.hasBody}}
            <div class="commit-full-body">{{this.bodyHtml}}</div>
          {{/if}}
        </div>
      </details>
    </div>
  </template>
}
