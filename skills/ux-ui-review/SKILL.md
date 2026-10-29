---
name: ux-ui-review
description: Review and fix the UX and UI of every screen like a demanding designer - 375px and desktop, empty/loading/error states, copy, hierarchy, spacing, contrast, touch targets, keyboard and focus, consistency - with screenshots as evidence and fixes applied, not just listed. Use during /ship after a flow is built, before QA, or whenever asked to make something look and feel good. Pairs with the ui-ux-pro-max skill for style and palette choices.
---

# UX/UI review

You are the designer and you also ship the fix. Every finding is either fixed now or a READINESS row with a screenshot. No "consider improving" lists.

## Procedure per screen

1. Open the real screen (dev server or production) in the browser at **375 x 812** and at **1440 wide**. Screenshot both to `qa/ux/<screen>-<width>.png`.
2. Walk the checklist below. Fix what you can in the same pass. Re-screenshot after fixing; the "after" image is the evidence.
3. Record one READINESS row per unfixed defect (`| U<n> | <screen>: <defect> | <surface> | todo | qa/ux/... | |`).

## Checklist

- **First impression**: what the screen is for is obvious in 3 seconds; one primary action per screen; the primary action is visually primary.
- **States**: empty (helpful, with the next action), loading (skeleton or spinner, no layout jump), error (plain words, what to do next, keeps the user's input), success (confirmation that something happened).
- **Copy**: short, specific, in the product's language; buttons are verbs ("Save list", not "Submit"); no developer words (null, undefined, error 500, token).
- **Layout**: nothing overflows or is clipped at 375px; no horizontal scroll; consistent spacing scale; aligned edges; sensible max width on desktop.
- **Forms**: labels (not placeholders only), inline validation, visible focus, Enter submits, errors next to the field, sensible keyboard types on mobile.
- **Touch and keyboard**: targets at least 44px; Tab order follows reading order; Escape closes overlays; focus returns after modals.
- **Accessibility**: contrast at least 4.5:1 for text; images have alt text; icons with labels; headings in order; `prefers-reduced-motion` respected.
- **Consistency**: one font pairing, one palette, one button style, one icon set; same component for the same job everywhere.
- **Performance feel**: first screen usable under 2 seconds on a throttled phone; no blocking fonts; images sized.
- **Dark mode** if the product offers it: both themes checked.

## Tools

- Claude Code: the built-in browser (`mcp__Claude_Browser__*`, `resize_window` for 375/desktop), or Chrome DevTools MCP; iOS simulator for native screens.
- Codex: the browser plugin / computer use; the same widths.
- Style decisions (palette, type, component style) come from the ui-ux-pro-max skill when installed; otherwise keep what the product already uses and make it consistent.
- Lighthouse accessibility score (Chrome DevTools `lighthouse_audit`) is the gate evidence: at least 90.

## Output

Short list in the report: "<screen>: fixed <n>, open <n> (rows U<a>-U<b>)". Screenshots linked from the rows.
