<!-- Generated from docs/ux-accessibility/README.md by scripts/sync-plugin.sh. Edit the original. -->

# UI/UX & Accessibility Checklist

An app that people can't use isn't ready to ship. This checklist covers the
basics of usable, accessible, fast interfaces. It targets **WCAG 2.2 level AA**,
the standard most accessibility laws refer to, including the European
Accessibility Act (in force since June 2025) and US ADA cases.

Each item: **what to check → how to check it.**

---

## 1. Accessibility (WCAG 2.2 AA)

### Perceivable
- [ ] **Text contrast** is at least 4.5:1 for normal text and 3:1 for large text
      (18pt, or 14pt bold) → browser DevTools contrast checker, or axe.
- [ ] **Interface and focus indicators** (input borders, icons, focus rings)
      have at least 3:1 contrast against what's around them.
- [ ] **Meaningful images have `alt` text.** Decorative ones use `alt=""`.
- [ ] **Color is never the only signal.** An error is a message and an icon, not
      just a red border.
- [ ] **The page works at 320px width** and at 200% zoom without horizontal
      scrolling or cut-off content.
- [ ] Videos have captions. Audio has a transcript.

### Operable
- [ ] **Everything works with a keyboard alone.** Tab through the whole flow
      without touching the mouse.
- [ ] **Focus is always visible** and never hidden under sticky headers or
      cookie banners.
- [ ] **No keyboard traps.** Modals trap focus while open and return it to the
      triggering element when closed. Escape closes them.
- [ ] **Touch and click targets** are at least 24×24 CSS px. Aim for 44×44 on mobile.
- [ ] Anything that needs dragging also has a single-click alternative.
- [ ] A "skip to main content" link is the first focusable element.

### Understandable
- [ ] `<html lang="…">` is set correctly.
- [ ] **Every input has a visible `<label>`.** Placeholders are not labels.
- [ ] **Errors say what went wrong and how to fix it**, next to the field, and
      screen readers announce them.
- [ ] **Login doesn't require a memory or puzzle test.** Allow password
      managers and paste. Offer alternatives to CAPTCHAs.
- [ ] Users aren't asked to re-enter information they already gave in the same flow.

### Robust
- [ ] **Use native elements first**: `<button>`, `<a href>`, `<select>`. A
      `<div onclick>` is invisible to keyboards and screen readers.
- [ ] ARIA is only used where no native element fits, and it's used correctly.
- [ ] Headings form a logical outline (one `h1`, no skipped levels).

**Automate the checks you can:**
```bash
npx @axe-core/cli https://localhost:3000        # one page
npx pa11y-ci --sitemap https://yoursite/sitemap.xml
npx lighthouse https://yoursite --only-categories=accessibility
```
Automated tools catch roughly a third to a half of accessibility issues. Do one
keyboard-only pass and one screen-reader pass (VoiceOver, NVDA or TalkBack) on
your main flow before launch.

---

## 2. UX states and flows
- [ ] **Every screen that loads data handles four states:** loading, empty,
      error, and success.
- [ ] **Loading feedback matches the wait**: none under about 100 ms, a small
      inline indicator up to about 1 s, and a skeleton or progress bar beyond that.
- [ ] **Empty states explain what will appear** and offer the next action.
- [ ] **Error messages don't blame the user** and always give a way to recover.
- [ ] **Buttons say what they do** ("Save changes", "Delete project"), not "OK" or "Submit".
- [ ] **Destructive actions** ask for confirmation by name, or offer undo.
- [ ] **Forms validate when the user leaves a field** (not on every keystroke),
      clear the error as soon as it's fixed, and keep entered data if submission fails.
- [ ] **Forms only ask for what's needed** and have sensible defaults.
- [ ] Double-submitting a payment or form is prevented (disabled button plus
      server-side idempotency).

## 3. Responsive layout
- [ ] Test at 375px, 768px and 1280px or wider. Nothing overflows the page.
- [ ] Line length for reading text is roughly 45–75 characters.
- [ ] Tables and wide content scroll inside their own container, not the whole page.

## 4. Motion
- [ ] **Respect `prefers-reduced-motion`.** Turn off movement-heavy animation,
      or replace it with fades:
  ```css
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: 0.01ms !important;
      transition-duration: 0.01ms !important;
      scroll-behavior: auto !important;
    }
  }
  ```
- [ ] **UI transitions are short**: about 100–300 ms for most interface feedback.
      Longer animations feel slow.
- [ ] **Animate `transform` and `opacity`**, not layout properties like
      `width`, `top` or `margin`, so animations stay smooth.
- [ ] Nothing flashes more than 3 times per second. Autoplaying motion that lasts
      over 5 seconds can be paused.

## 5. Performance users can feel (Core Web Vitals)
| Metric | "Good" threshold |
|---|---|
| Largest Contentful Paint (LCP) | ≤ 2.5 s |
| Interaction to Next Paint (INP) | ≤ 200 ms |
| Cumulative Layout Shift (CLS) | ≤ 0.1 |

- [ ] Images are sized (`width`/`height`), compressed (WebP/AVIF), and lazy-loaded below the fold.
- [ ] Fonts don't block rendering (`font-display: swap`), and you load only the weights you use.
- [ ] Check with `npx lighthouse https://yoursite` and real-user data from
      PageSpeed Insights.

---

## Pre-launch quick pass (15 minutes)
1. Tab through the main flow with the keyboard only.
2. Zoom to 200% and resize to 375px wide.
3. Run axe and Lighthouse on the 3 most important pages.
4. Turn on "reduce motion" in your OS and reload.
5. Trigger an error, an empty list and a slow network (DevTools throttling) to
   see each state.
