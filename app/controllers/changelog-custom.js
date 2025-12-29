import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class ChangelogCustomController extends Controller {
  @tracked start = null;
  @tracked end = null;
  queryParams = ["start", "end"];

  @action
  updateStart(value) {
    this.start = value;
  }

  @action
  updateEnd(value) {
    this.end = value;
  }
}
