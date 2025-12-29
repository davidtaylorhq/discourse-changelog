import Route from "@ember/routing/route";

export default class ChangelogCustomRoute extends Route {
  queryParams = {
    start: {
      refreshModel: false,
    },
    end: {
      refreshModel: false,
    },
  };
}
