# Changelog

## 1.1.0

- Expose `slide(grid, from, dir)` as a public function so downstream game
  engines can reuse the canonical slide simulation instead of reimplementing
  it. Returns a `SlideResult` with the resting position and the cells painted
  along the way.

## 1.0.0

- Initial version.
