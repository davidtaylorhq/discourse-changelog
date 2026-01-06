import { concat } from "@ember/helper";
import { pageTitle } from "ember-page-title";
import CommitViewer from "../components/changelog/commit-viewer";
import metaDescription from "../helpers/meta-description";

<template>
  {{pageTitle (concat @controller.end " Changelog")}}
  {{metaDescription
    (concat
      "Featured changes and detailed commit history for Discourse '"
      @controller.end
      "'."
    )
  }}

  <CommitViewer
    @start={{@controller.start}}
    @end={{@controller.end}}
    @onUpdateRange={{@controller.updateRange}}
  />
</template>
