---
name: multi-variant-site-design
description: >
  Guide for designing a website by generating multiple parallel design variants, housing them in
  a gallery for comparison, and promoting a winner as the production site. Use this skill when
  the user wants to explore multiple visual directions for a site, asks for "design variants",
  "design exploration", "parallel designs", "A/B site concepts", "show me options", "gallery of
  designs", "compare layouts", or wants to build multiple versions of the same page/site to pick
  the best one. Also trigger when the user says "give me choices", "explore different directions",
  "I want to see alternatives before committing", or "design sprint" for a static site.
---

# Multi-Variant Site Design

A methodology for exploring multiple design directions in parallel, comparing them in a gallery,
and promoting the winner to production — without throwing away the exploration.

## When to use this

- A new site needs a strong visual identity and you want to see options before committing
- A redesign where the right aesthetic direction is unclear
- Building a site for a friend/client where showing alternatives is more effective than describing
- Any time "just pick one direction" feels premature

## Philosophy

Instead of iterating on a single design endlessly, generate N parallel interpretations of the
same content brief. Each variant is a self-contained, working static site — not a mockup. The
user browses them in a gallery, reacts viscerally, and picks a winner (or a composite of
elements from several). The gallery remains as a design archive.

## Directory Structure

```
docs/
├── site/                    ← Production (the promoted winner)
│   ├── index.html
│   ├── style.css
│   ├── script.js
│   └── assets/             ← Self-contained assets
└── variants/               ← Design exploration archive
    ├── index.html           ← Gallery page (links to all variants)
    ├── assets/              ← Shared assets across variants
    │   └── images/
    ├── variant-a/
    │   ├── index.html
    │   ├── style.css
    │   └── script.js
    ├── variant-b/
    │   └── ...
    ├── variant-c/
    │   └── ...
    └── original/            ← The pre-existing site (if any), preserved
        └── ...
```

### Key principles

1. **Each variant is self-contained** — its own HTML, CSS, JS. No shared frameworks between variants.
2. **Shared assets live one level up** — images, fonts used by multiple variants go in `variants/assets/`.
3. **The gallery is a real page** — not a README. It should look good and let you feel the difference between variants at a glance.
4. **Promotion = copy + path fix** — when a variant wins, copy it to `docs/site/`, fix relative asset paths, remove gallery-specific navigation.
5. **The gallery stays** — it's a design artifact worth keeping. Link to it from the main site if you want.

## Workflow

### Phase 1: Brief

Write a content brief that all variants will implement. This should include:

- **Content inventory** — what sections/chapters the site must have
- **Tone keywords** — 3-5 adjectives (e.g., "military, nostalgic, premium, editorial, cinematic")
- **Technical constraints** — vanilla HTML/CSS/JS only? Specific libraries allowed? Must work without build step?
- **Content** — actual text, images, data that each variant must include
- **Non-negotiables** — accessibility, mobile support, performance budget

Store this as `variants/BRIEF.md`.

### Phase 2: Generate Variants

Create 3-9 distinct interpretations. Each should differ in:

| Dimension | Examples |
|-----------|----------|
| Layout | Single-column editorial, grid magazine, side-scrolling, full-bleed sections |
| Typography | Serif-heavy classical, mono brutalist, geometric sans modern |
| Color | Dark cinematic, light minimal, high-contrast duotone, earthy organic |
| Animation | Scroll-pinned reveals, parallax layers, WebGL particles, CSS-only transitions |
| Personality | Formal/institutional, playful/bold, quiet/refined, dramatic/immersive |

**Naming convention**: Use evocative short names, not "variant-1". Examples: `trailer`, `briefing`, `memorial`, `field-manual`, `hangar`.

### Phase 3: Gallery Page

Build `variants/index.html` as a visual gallery. Each variant gets a tile showing:

- A numbering scheme (01, 02, ... or Roman numerals)
- A mini-preview chip that captures the variant's visual signature (colors, typography, layout hint)
- The variant's name and a one-line vibe description
- A link to enter it

The gallery itself should be well-designed — it sets the tone for the exploration.

#### Gallery tile anatomy

```html
<a class="tile" href="variant-name/" data-slug="variant-name">
  <div class="tile-frame">
    <span class="tile-num">01</span>
    <div class="tile-preview preview-variant-name">
      <!-- Mini visual signature of this variant's aesthetic -->
    </div>
    <span class="tile-enter">Enter</span>
  </div>
  <div class="tile-info">
    <span class="tile-slug">01 · variant-name</span>
    <span class="tile-name">Human-Readable Name</span>
    <span class="tile-vibe">One-sentence description of the design direction.</span>
  </div>
</a>
```

### Phase 4: Review & Choose

Browse the variants. Common outcomes:

- **Clear winner** → promote directly
- **Composite** → take elements from multiple variants into a new synthesis variant, then promote that
- **None work** → refine the brief and generate more

### Phase 5: Promote

When a winner is chosen:

1. Copy its files to `docs/site/` (or wherever production lives)
2. Copy shared assets into `docs/site/assets/` (so it's self-contained)
3. Fix relative paths (variant used `../assets/X` → production uses `assets/X`)
4. Remove gallery-specific UI (e.g., "← Gallery" back-link)
5. Keep the gallery intact as `docs/variants/` — it's a design archive

### Phase 6: Evolve

The production site continues to evolve independently. The gallery captures a moment-in-time
exploration. If you need another round of exploration later, you can add more variants to the
gallery.

## Gallery Page Template

Below is a minimal gallery page you can adapt. It uses no dependencies — just HTML + inline CSS.

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Design Variants — [Project Name]</title>
  <style>
    :root {
      --bg: #0a0a0a;
      --ink: #f4ede0;
      --ink-dim: #a39b8a;
      --line: #2a2a2a;
      --accent: #c41e1e;
    }
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--ink);
      font-family: system-ui, -apple-system, sans-serif;
      line-height: 1.5;
      padding: 4rem 2rem;
    }
    h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
    .subtitle { color: var(--ink-dim); margin-bottom: 3rem; }
    .tiles {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 2rem;
    }
    .tile {
      display: block;
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
      text-decoration: none;
      color: inherit;
      transition: border-color 0.3s, transform 0.3s;
    }
    .tile:hover { border-color: var(--accent); transform: translateY(-4px); }
    .tile-preview {
      aspect-ratio: 16/10;
      display: grid;
      place-items: center;
      padding: 1.5rem;
      /* Each variant overrides this with its own colors/typography */
    }
    .tile-info { padding: 1rem 1.2rem; border-top: 1px solid var(--line); }
    .tile-name { display: block; font-weight: 600; margin-bottom: 0.25rem; }
    .tile-vibe { display: block; font-size: 0.85rem; color: var(--ink-dim); }
  </style>
</head>
<body>
  <h1>[Project Name] — Design Variants</h1>
  <p class="subtitle">N directions. One brief. Click any tile to walk in.</p>

  <div class="tiles">
    <!-- Repeat for each variant -->
    <a class="tile" href="variant-name/">
      <div class="tile-preview" style="background: #1a1a2e; color: #e0e0e0;">
        <span style="font-size: 1.4rem; font-weight: 600;">Variant Name</span>
      </div>
      <div class="tile-info">
        <span class="tile-name">Variant Name</span>
        <span class="tile-vibe">One-sentence aesthetic description.</span>
      </div>
    </a>
  </div>
</body>
</html>
```

## Variant Checklist

Each variant should:

- [ ] Implement the full content brief (not a subset)
- [ ] Work without a build step (open index.html in browser or serve statically)
- [ ] Be responsive (at minimum: mobile + desktop)
- [ ] Have a distinct visual identity from other variants
- [ ] Include a "← Gallery" link back to the gallery page
- [ ] Use shared assets from `../assets/` where possible (images, data)
- [ ] Be self-descriptive — someone browsing should understand the design intent

## Tips

- **Don't over-polish early** — the point is divergence, not perfection. Polish the winner.
- **Name variants evocatively** — it helps discussion ("I like the trailer vibe but with memorial's typography")
- **Shared assets prevent drift** — if all variants show the same images, put them in one place.
- **The gallery IS the deliverable** (until promotion) — treat it as a design presentation.
- **Composite variants are fine** — if none wins outright, synthesize. Name it "composite" or "synthesis".
- **Keep the archive** — future-you will appreciate seeing the roads not taken.

## Promotion Checklist

When promoting a variant to production:

- [ ] Files copied to production location
- [ ] Shared assets copied (site is self-contained, no relative path to variants/)
- [ ] `../assets/` paths updated to `assets/` (or wherever they now live)
- [ ] Gallery-specific navigation removed (back link, variant slug display)
- [ ] Meta tags updated (title, description, OG image for production URL)
- [ ] Tested from production path (all images load, links work)
- [ ] Gallery page updated to note which variant was promoted
