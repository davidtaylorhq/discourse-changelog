import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { htmlSafe } from "@ember/template";
import "./versions-timeline.css";
import TimelineLegend from "./timeline-legend";
import TimelineRow from "./timeline-row";
import TodayIndicator from "./today-indicator";

// Normalize date strings - convert "yyyy-mm" to "yyyy-mm-dd" (last day of month)
function normalizeDate(dateString) {
  if (!dateString) {
    return null;
  }
  if (/^\d{4}-\d{2}$/.test(dateString)) {
    const [year, month] = dateString.split("-");
    const lastDay = new Date(
      parseInt(year, 10),
      parseInt(month, 10),
      0
    ).getDate();
    return `${year}-${month}-${lastDay}`;
  }
  return dateString;
}

// Convert a date to a percentage position within the timeline range
function dateToPercent(date, minDate, totalDays) {
  if (!date) {
    return 0;
  }
  const d = new Date(normalizeDate(date));
  const days = (d - minDate) / (1000 * 60 * 60 * 24);
  return (days / totalDays) * 100;
}

export default class VersionsTimeline extends Component {
  @cached
  get timelineRange() {
    const today = new Date();
    const minDate = new Date(today);
    minDate.setMonth(minDate.getMonth() - 10);

    const maxDate = new Date(today);
    maxDate.setMonth(maxDate.getMonth() + 10);

    const totalDays = (maxDate - minDate) / (1000 * 60 * 60 * 24);

    return { today, minDate, maxDate, totalDays };
  }

  @cached
  get monthMarkers() {
    const { minDate, maxDate, totalDays } = this.timelineRange;
    const markers = [];
    const current = new Date(minDate);
    current.setDate(1);

    // Start from the first Jan/Apr/Jul/Oct after minDate
    const quarterMonths = [0, 3, 6, 9];
    while (!quarterMonths.includes(current.getMonth())) {
      current.setMonth(current.getMonth() + 1);
    }

    while (current <= maxDate) {
      const percent = dateToPercent(current, minDate, totalDays);
      markers.push({
        style: htmlSafe(`left: ${percent}%`),
        month: current.toLocaleDateString("en-US", { month: "short" }),
        year: current.toLocaleDateString("en-US", { year: "numeric" }),
      });
      current.setMonth(current.getMonth() + 3);
    }

    return markers;
  }

  get todayPosition() {
    const { today, minDate, totalDays } = this.timelineRange;
    return dateToPercent(today, minDate, totalDays);
  }

  @cached
  get versionBars() {
    if (!this.args.versions?.length) {
      return [];
    }

    const { minDate, totalDays } = this.timelineRange;

    return this.args.versions
      .filter((group) => group.headerVersion.date)
      .map((group) => {
        const releaseDate = group.headerVersion.date;
        const endDate = group.supportInfo.supportEndDate;
        const devStartDate =
          group.supportInfo.developmentStartDate || releaseDate;

        return {
          version: group.minorVersion,
          status: group.supportInfo.status,
          devStart: dateToPercent(devStartDate, minDate, totalDays),
          supportStart: dateToPercent(releaseDate, minDate, totalDays),
          eol: dateToPercent(endDate, minDate, totalDays),
        };
      });
  }

  <template>
    {{#if this.versionBars.length}}
      <div class="timeline-chart">
        <div class="timeline-content-wrapper">
          <div class="timeline-header">
            <div class="timeline-row-label"></div>
            <div class="timeline-timeline">
              {{#each this.monthMarkers as |marker|}}
                <div class="timeline-month-marker" style={{marker.style}}>
                  {{marker.month}}<br />{{marker.year}}
                </div>
              {{/each}}
            </div>
          </div>

          <div class="timeline-body">
            <div class="timeline-rows-wrapper">
              {{#each this.versionBars as |bar|}}
                <TimelineRow
                  @version={{bar.version}}
                  @status={{bar.status}}
                  @devStart={{bar.devStart}}
                  @supportStart={{bar.supportStart}}
                  @eol={{bar.eol}}
                />
              {{/each}}
            </div>

            <div class="timeline-grid-wrapper">
              <div class="timeline-grid-spacer"></div>
              <div class="timeline-grid-timeline">
                {{#each this.monthMarkers as |marker|}}
                  <div class="timeline-grid-line" style={{marker.style}}></div>
                {{/each}}
              </div>
            </div>

            <TodayIndicator @position={{this.todayPosition}} />
          </div>
        </div>

        <TimelineLegend />
      </div>
    {{/if}}
  </template>
}
