/**
 * Minimal baseline behavior for the disposable rehearsal.
 * Milestone 7 autonomous task will improve punctuation and whitespace handling.
 * This file intentionally has a small, bounded feature gap, not a hidden security flaw.
 */
export function toSlug(value) {
  if (typeof value !== "string") throw new TypeError("Expected a string");
  return value.toLowerCase().trim().split(" ").filter(Boolean).join("-");
}
