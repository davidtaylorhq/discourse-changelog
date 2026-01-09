import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ChangelogData } from "../../lib/git-utils.js";

const data = new ChangelogData();

export default class RefSelector extends Component {
  @tracked advancedMode = false;
  @tracked inputValue = "";

  isSelected = (value) => {
    if (this.currentValue) {
      return this.currentValue === value;
    }
    return value === this.args.defaultValue;
  };

  get currentValue() {
    return this.args.value || "";
  }

  @action
  toggleAdvancedMode() {
    this.advancedMode = !this.advancedMode;
    if (this.advancedMode) {
      this.inputValue = this.currentValue;
    } else {
      this.args.onChange?.(this.args.defaultValue);
    }
  }

  @action
  handleInput(event) {
    this.inputValue = event.target.value;
    this.args.onChange?.(this.inputValue);
  }

  @action
  handleSelect(event) {
    this.args.onChange?.(event.target.value);
  }

  <template>
    <div class="input-group">
      <div class="input-header">
        <label for={{@inputId}}>{{@label}}:</label>
        <button
          type="button"
          class="advanced-toggle"
          {{on "click" this.toggleAdvancedMode}}
        >
          {{if this.advancedMode "Use Dropdown" "Advanced"}}
        </button>
      </div>

      {{#if this.advancedMode}}
        <input
          id={{@inputId}}
          type="text"
          value={{this.inputValue}}
          placeholder="Enter commit hash..."
          {{on "input" this.handleInput}}
        />
        <small class="input-help">Enter a commit hash</small>
      {{else}}
        <select id={{@inputId}} {{on "change" this.handleSelect}}>
          <optgroup label="Branches">
            {{#each data.branches as |ref|}}
              <option
                value={{ref.value}}
                selected={{this.isSelected ref.value}}
              >
                {{ref.label}}
              </option>
            {{/each}}
          </optgroup>
          {{#if data.provisionalVersions.length}}
            <optgroup label="Provisional">
              {{#each data.provisionalVersions as |ref|}}
                <option
                  value={{ref.value}}
                  selected={{this.isSelected ref.value}}
                >
                  {{ref.label}}
                </option>
              {{/each}}
            </optgroup>
          {{/if}}
          <optgroup label="Tags">
            {{#each data.sortedTags as |ref|}}
              <option
                value={{ref.value}}
                selected={{this.isSelected ref.value}}
              >
                {{ref.label}}
              </option>
            {{/each}}
          </optgroup>
        </select>
        <small class="input-help">Select a tag or branch</small>
      {{/if}}
    </div>
  </template>
}
