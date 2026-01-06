import { setApplication } from "@ember/test-helpers";
import { setupEmberOnerrorValidation, start as qunitStart } from "ember-qunit";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";
import Application from "discourse-releases/app";
import config from "discourse-releases/config/environment";

export function start() {
  setApplication(Application.create(config.APP));

  setup(QUnit.assert);
  setupEmberOnerrorValidation();

  qunitStart();
}
