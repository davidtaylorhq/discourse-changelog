import { cancel, next } from "@ember/runloop";
import { modifier } from "ember-modifier";

// Global registry of highlights by ID
const highlightRegistry = new Map();

function getOrCreateHighlightSet(id) {
  if (!highlightRegistry.has(id)) {
    highlightRegistry.set(id, new Set());
  }
  return highlightRegistry.get(id);
}

function rerenderHighlights(id) {
  const ranges = getOrCreateHighlightSet(id);

  if (ranges.size > 0) {
    const highlight = new Highlight(...ranges.values());
    CSS.highlights.set(id, highlight);
  } else {
    CSS.highlights.delete(id);
  }
}

function addHighlightRanges(id, ranges) {
  const highlightSet = getOrCreateHighlightSet(id);
  for (const range of ranges) {
    highlightSet.add(range);
  }
  rerenderHighlights(id);
}

function removeHighlightRanges(id, ranges) {
  const highlightSet = getOrCreateHighlightSet(id);
  for (const range of ranges) {
    highlightSet.delete(range);
  }
  rerenderHighlights(id);
}

export default modifier((element, _positional, { searchString, id }) => {
  if (!CSS.highlights) {
    return;
  }

  if (!searchString?.trim()) {
    return;
  }

  const ranges = [];

  // Annoyingly, Ember's timing when **re-**rendering modifiers is not
  // quite right. It calls the modifier again before the DOM is updated.
  // Work around this by scheduling the highlight work in the next tick.
  const scheduled = next(() => {
    performHighlight(searchString, element, ranges);

    if (ranges.length) {
      addHighlightRanges(id, ranges);
    }
  });

  return () => {
    cancel(scheduled);
    removeHighlightRanges(id, ranges);
  };
});

function performHighlight(searchString, element, ranges) {
  const term = searchString.toLowerCase();

  const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT, null);

  let node;
  while ((node = walker.nextNode())) {
    const text = node.textContent.toLowerCase();
    let startPos = 0;

    // Find all occurrences in this text node
    while (true) {
      const index = text.indexOf(term, startPos);
      if (index === -1) {
        break;
      }

      const range = new Range();
      range.setStart(node, index);
      range.setEnd(node, index + term.length);
      ranges.push(range);

      startPos = index + term.length;
    }
  }
}
