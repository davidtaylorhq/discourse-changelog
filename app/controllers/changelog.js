import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';

export default class ChangelogController extends Controller {
  queryParams = ['start', 'end'];

  @tracked start = null;
  @tracked end = null;

  @action
  updateStart(value) {
    this.start = value;
  }

  @action
  updateEnd(value) {
    this.end = value;
  }
}
