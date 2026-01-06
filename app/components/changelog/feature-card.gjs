import Component from "@glimmer/component";
import "./feature-card.css";

export default class FeatureCard extends Component {
  get formattedDate() {
    if (!this.args.feature.released_at) {
      return null;
    }
    const date = new Date(this.args.feature.released_at);
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  get hasScreenshot() {
    return !!this.args.feature.screenshot_url;
  }

  get screenshotUrl() {
    const url = this.args.feature.screenshot_url;
    if (!url) {
      return null;
    }
    // Handle protocol-relative URLs
    return url.startsWith("//") ? `https:${url}` : url;
  }

  get versionInfo() {
    const version = this.args.feature.discourse_version;
    if (!version) {
      return null;
    }

    // If it's a full commit hash (40 characters), show shortened version
    if (version.length === 40) {
      return version.substring(0, 7);
    }

    // Otherwise show the version as-is
    return version;
  }

  <template>
    <div class="feature-card">
      <div class="feature-content">
        <div class="feature-header">
          {{#if @feature.emoji}}
            <span class="feature-emoji">{{@feature.emoji}}</span>
          {{/if}}
          <h3 class="feature-title">{{@feature.title}}</h3>
        </div>

        {{#if @feature.description}}
          <p class="feature-description">{{@feature.description}}</p>
        {{/if}}

        <div class="feature-meta">
          {{#if this.formattedDate}}
            <span class="feature-date">
              {{this.formattedDate}}
              {{#if this.versionInfo}}
                <span class="feature-version">({{this.versionInfo}})</span>
              {{/if}}
            </span>
          {{/if}}
          {{#if @feature.link}}
            <a
              href={{@feature.link}}
              target="_blank"
              rel="noopener noreferrer"
              class="feature-link"
            >
              Learn more →
            </a>
          {{/if}}
        </div>
      </div>

      {{#if this.hasScreenshot}}
        <div class="feature-screenshot">
          <img src={{this.screenshotUrl}} alt={{@feature.title}} />
        </div>
      {{/if}}
    </div>
  </template>
}
