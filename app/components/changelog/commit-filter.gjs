import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import eq from "../../helpers/eq.js";
import { COMMIT_TYPES } from "../../lib/git-utils.js";

const CommitFilter = <template>
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
      {{#each COMMIT_TYPES as |type|}}
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
</template>;

export default CommitFilter;
