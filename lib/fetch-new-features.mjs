/* eslint-disable no-console */
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

// Get project root directory
const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, "..");

const NEW_FEATURES_URL = "https://meta.discourse.org/new-features.json";

async function fetchNewFeatures() {
  console.log(`Fetching new features from ${NEW_FEATURES_URL}...`);

  const response = await fetch(NEW_FEATURES_URL);

  if (!response.ok) {
    throw new Error(
      `Failed to fetch new features: ${response.status} ${response.statusText}`
    );
  }

  const data = await response.json();

  console.log(`Fetched new features data`);

  // Write to JSON file
  const outputPath = join(PROJECT_ROOT, "data/new-features.json");
  mkdirSync(join(PROJECT_ROOT, "data"), { recursive: true });
  writeFileSync(outputPath, JSON.stringify(data, null, 2));

  console.log(`Written new features data to ${outputPath}`);
}

fetchNewFeatures().catch((error) => {
  console.error("Error fetching new features:", error);
  process.exit(1);
});
