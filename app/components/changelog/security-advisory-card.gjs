import Component from "@glimmer/component";
import "./security-advisory-card.css";

export default class SecurityAdvisoryCard extends Component {
  get formattedDate() {
    if (!this.args.advisory.published_at) {
      return null;
    }
    const date = new Date(this.args.advisory.published_at);
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  <template>
    <a
      href={{@advisory.html_url}}
      target="_blank"
      rel="noopener noreferrer"
      class="security-advisory-card"
    >
      <div class="advisory-icon">
        <svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24">
          <path
            d="M12 2L4 5v6.09c0 5.05 3.41 9.76 8 10.91 4.59-1.15 8-5.86 8-10.91V5l-8-3zm-1 6h2v2h-2V8zm0 4h2v6h-2v-6z"
          />
        </svg>
      </div>
      <div class="advisory-content">
        <span class="advisory-cve">{{@advisory.cve_id}}</span>
        <p class="advisory-summary">{{@advisory.summary}}</p>
        <div class="advisory-meta">
          {{#if this.formattedDate}}
            <span class="advisory-date">{{this.formattedDate}}</span>
          {{/if}}
          <span class="advisory-link-hint">View details →</span>
        </div>
      </div>
    </a>
  </template>
}
