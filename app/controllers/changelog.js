import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class ChangelogController extends Controller {
  @service router;

  get start() {
    return this.model.start;
  }

  get end() {
    return this.model.end;
  }

  @action
  updateStart(value) {
    // If a start value is provided, always go to custom route
    this.router.transitionTo("changelog-custom", {
      queryParams: { start: value, end: this.end },
    });
  }

  @action
  updateEnd(value) {
    if (this.start) {
      // If we have a start, go to custom route
      this.router.transitionTo("changelog-custom", {
        queryParams: { start: this.start, end: value },
      });
    } else {
      // Otherwise use the standard changelog route
      this.router.transitionTo("changelog", value);
    }
  }
}
