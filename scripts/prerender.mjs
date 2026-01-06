/* eslint-disable no-console */

import { mkdir, readFile, writeFile } from "fs/promises";
import { JSDOM } from "jsdom";
import { dirname } from "node:path";
import commitsData from "../data/commits.json" with { type: "json" };

globalThis.window = globalThis;

const { default: App } = await import("../dist-ssr/app.mjs");
const wrapperHTML = await readFile("dist/index.html", "utf8");

let instance = App.create({
  autoboot: false,
  modulePrefix: "discourse-releases",
});

async function preRender(path, output) {
  try {
    const result = await render(path);
    await mkdir(dirname(output), { recursive: true });
    await writeFile(output, result);
    console.log(`Rendered: ${path}`);
  } catch (e) {
    console.error(`Error Rendering path: ${e.message}`);
    throw e;
  }
}

function buildBootOptions() {
  const dom = new JSDOM(wrapperHTML);
  return {
    isBrowser: false,
    jsdom: dom,
    rootElement: dom.window.document.querySelector("#main-outlet"),
    shouldRender: true,
  };
}

async function render(url) {
  let bootOptions = buildBootOptions();
  globalThis.document = bootOptions.jsdom.window.document;
  await instance.visit(url, bootOptions);
  return bootOptions.jsdom.serialize();
}

const changelogRoutes = [
  ...Object.keys(commitsData.refs.branches).map(
    (branch) => `/changelog/${branch}`
  ),
  ...Object.keys(commitsData.refs.tags).map((tag) => `/changelog/${tag}`),
];

const routesToPrerender = ["/", "/changelog/custom", ...changelogRoutes];

for (let path of routesToPrerender) {
  await preRender(path, `dist${path}/index.html`);
}
await preRender("/404", `dist/404.html`);
