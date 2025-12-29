import Route from "@ember/routing/route";
import CommitsData from "/data/commits.json";

export default class ChangelogRoute extends Route {
  beforeModel(transition) {
    const end = transition.to.params.end;

    if (!end) {
      return;
    }

    // Check if it's a valid branch or tag
    const isValidBranch = CommitsData.refs.branches[end] !== undefined;
    const isValidTag = CommitsData.refs.tags[end] !== undefined;

    if (!isValidBranch && !isValidTag) {
      throw new Error("Not Found");
    }
  }

  model(params) {
    return {
      start: null,
      end: params.end,
    };
  }
}
