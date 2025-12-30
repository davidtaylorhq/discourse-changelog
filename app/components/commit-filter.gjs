import Component from "@glimmer/component";
import { helper } from "@ember/component/helper";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import { COMMIT_TYPES } from "../lib/git-utils.js";

const eq = helper(([a, b]) => a === b);

export default class CommitFilter extends Component {
  get commitTypes() {
    return COMMIT_TYPES;
  }

  <template>
    <div class="filter-section">
      <div class="commit-tabs">
        <button
          type="button"
          class="commit-tab {{if (eq @activeTab 'all') 'active'}}"
          {{on "click" (fn @onTabChange "all")}}
        >
          All
          <span class="tab-count">({{@totalCount}})</span>
        </button>
        {{#each this.commitTypes as |type|}}
          <button
            type="button"
            class="commit-tab {{if (eq @activeTab type.key) 'active'}}"
            style={{htmlSafe (concat "--tab-color: " type.color)}}
            {{on "click" (fn @onTabChange type.key)}}
          >
            {{type.label}}
            <span class="tab-count">({{get @typeCounts type.key}})</span>
          </button>
        {{/each}}
      </div>

      <div class="filter-input-wrapper">
        <input
          type="text"
          class="filter-input"
          placeholder="Filter commits..."
          value={{@filterText}}
          {{on "input" @onFilterChange}}
        />
      </div>
    </div>
  </template>
}
