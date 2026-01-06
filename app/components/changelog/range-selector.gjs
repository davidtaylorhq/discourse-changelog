import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import RefSelector from "./ref-selector";

export default class RangeSelector extends Component {
  @tracked isOpen = false;
  @tracked pendingStart = null;
  @tracked pendingEnd = null;

  @action
  toggle() {
    this.isOpen = !this.isOpen;
    if (this.isOpen) {
      this.pendingStart = null;
      this.pendingEnd = null;
    }
  }

  @action
  updatePendingStart(value) {
    this.pendingStart = value;
  }

  @action
  updatePendingEnd(value) {
    this.pendingEnd = value;
  }

  @action
  apply() {
    const newStart = this.pendingStart ?? this.args.startValue;
    const newEnd = this.pendingEnd ?? this.args.endValue;
    this.args.onApply?.(newStart, newEnd);
  }

  <template>
    <button
      type="button"
      class="toggle-selector-btn"
      {{on "click" this.toggle}}
    >
      {{if this.isOpen "Hide" "Customize"}}
      Range
    </button>

    {{#if this.isOpen}}
      <div class="form-section">
        <RefSelector
          @inputId="start-ref"
          @label="Start"
          @value={{@startValue}}
          @defaultValue={{@startDefault}}
          @onChange={{this.updatePendingStart}}
        />
        <RefSelector
          @inputId="end-ref"
          @label="End"
          @value={{@endValue}}
          @defaultValue={{@endDefault}}
          @onChange={{this.updatePendingEnd}}
        />
        <button
          type="button"
          class="go-button"
          {{on "click" this.apply}}
        >Go</button>
      </div>
    {{/if}}
  </template>
}
