export default function metaDescription(text) {
  document
    .querySelector("meta[name=description]")
    .setAttribute("content", text);
}
