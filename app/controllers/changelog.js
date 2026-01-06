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
  updateRange(start, end) {
    if (start) {
      // If a start value is provided, use custom route
      this.router.transitionTo("changelog-custom", {
        queryParams: { start, end },
      });
    } else {
      // Otherwise use the standard changelog route
      this.router.transitionTo("changelog", end);
    }
  }
}
