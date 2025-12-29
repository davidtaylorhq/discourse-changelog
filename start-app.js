import Application from "./app/app";
import environment from "./app/config/environment";

if (!import.meta.env.SSR) {
  Application.create(environment.APP);
}
