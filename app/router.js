import EmberRouter from "@embroider/router";
import config from "discourse-releases/config/environment";

export default class Router extends EmberRouter {
  location = config.locationType;
  rootURL = config.rootURL;
}

Router.map(function () {
  this.route("changelog", { path: "/changelog/*end" });
  this.route("changelog-custom", { path: "/changelog/custom" });
  this.route("error", { path: "/*path" });
});
