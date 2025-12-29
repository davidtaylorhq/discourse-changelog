import { setApplication } from "@ember/test-helpers";
import { setupEmberOnerrorValidation, start as qunitStart } from "ember-qunit";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";
import Application from "discourse-changelog/app";
import config from "discourse-changelog/config/environment";

export function start() {
  setApplication(Application.create(config.APP));

  setup(QUnit.assert);
  setupEmberOnerrorValidation();

  qunitStart();
}
