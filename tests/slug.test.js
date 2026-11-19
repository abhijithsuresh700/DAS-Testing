import test from "node:test";
import assert from "node:assert/strict";
import { toSlug } from "../src/slug.js";

test("converts a simple title to a slug", () => {
  assert.equal(toSlug("Hello World"), "hello-world");
});

test("normalizes repeated ASCII spaces in baseline", () => {
  assert.equal(toSlug("  Hello   World  "), "hello-world");
});

test("preserves simple alphanumeric titles", () => {
  assert.equal(toSlug("v2 Feature"), "v2-feature");
});

test("rejects non-string inputs", () => {
  assert.throws(() => toSlug(null), TypeError);
});
