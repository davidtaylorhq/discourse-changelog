import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class TimelineRow extends Component {
  get devWidth() {
    return Math.max(0, this.args.supportStart - this.args.devStart);
  }

  get supportedWidth() {
    return Math.max(0, this.args.eol - this.args.supportStart);
  }

  get hasPhases() {
    return this.devWidth > 0 && this.supportedWidth > 0;
  }

  get devStyle() {
    return htmlSafe(
      `left: ${this.args.devStart}%; width: ${this.devWidth}%; background-color: var(--color-active-development)`
    );
  }

  get supportedStyle() {
    return htmlSafe(
      `left: ${this.args.supportStart}%; width: ${this.supportedWidth}%; background-color: var(--color-supported)`
    );
  }

  get barStyle() {
    const totalWidth = this.devWidth + this.supportedWidth;
    return htmlSafe(
      `left: ${this.args.devStart}%; width: ${totalWidth}%; background-color: var(--color-supported)`
    );
  }

  <template>
    <div class="timeline-row">
      <div class="timeline-row-label">
        <span class="timeline-status-dot timeline-status-{{@status}}"></span>
        <a href="#version-{{@version}}" class="version-label">v{{@version}}</a>
      </div>
      <div class="timeline-row-timeline">
        <a href="#version-{{@version}}" class="timeline-bar-link">
          {{#if this.hasPhases}}
            <div
              class="timeline-bar timeline-bar-{{@status}}
                timeline-bar-development"
              style={{this.devStyle}}
            ></div>
            <div
              class="timeline-bar timeline-bar-{{@status}}
                timeline-bar-supported"
              style={{this.supportedStyle}}
            ></div>
          {{else}}
            <div
              class="timeline-bar timeline-bar-{{@status}}"
              style={{this.barStyle}}
            ></div>
          {{/if}}
        </a>
      </div>
    </div>
  </template>
}
