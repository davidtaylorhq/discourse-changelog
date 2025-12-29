export default {
  initialize(owner) {
    owner.lookup("service:router").on("routeDidChange", () => {
      if (!import.meta.env.SSR) {
        window.scrollTo(0, 0);
      }
    });
  },
};
