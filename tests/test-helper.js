import Application from 'discourse-changelog/app';
import config from 'discourse-changelog/config/environment';
import * as QUnit from 'qunit';
import { setApplication } from '@ember/test-helpers';
import { setup } from 'qunit-dom';
import { start as qunitStart, setupEmberOnerrorValidation } from 'ember-qunit';

export function start() {
  setApplication(Application.create({...config.APP, autoboot: false}));

  setup(QUnit.assert);
  setupEmberOnerrorValidation();

  qunitStart();
}
