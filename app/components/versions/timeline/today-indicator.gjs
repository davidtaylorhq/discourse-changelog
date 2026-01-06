import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class TodayIndicator extends Component {
  get style() {
    return htmlSafe(`left: ${this.args.position}%`);
  }

  <template>
    <div class="timeline-today-wrapper">
      <div class="timeline-today-spacer"></div>
      <div class="timeline-today-timeline">
        <div class="timeline-today-indicator" style={{this.style}}>
          <span class="timeline-today-label">Today</span>
          <div class="timeline-today-line"></div>
        </div>
      </div>
    </div>
  </template>
}
