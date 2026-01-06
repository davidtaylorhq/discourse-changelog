import { pageTitle } from "ember-page-title";
import SiteHeader from "../components/site-header.gjs";

<template>
  {{pageTitle "Discourse Releases"}}

  <SiteHeader />

  {{outlet}}
</template>
