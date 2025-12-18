import Route from '@ember/routing/route';

export default class ChangelogRoute extends Route {
  queryParams = {
    start: {
      refreshModel: false,
    },
    end: {
      refreshModel: false,
    },
  };
}
