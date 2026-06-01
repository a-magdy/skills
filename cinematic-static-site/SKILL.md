---
name: cinematic-static-site
description: >
  Guide for building cinematic, presentation-grade static websites with smooth scroll animations,
  WebGL effects, scroll-triggered reveals, and editorial grid layouts — the kind of high-end
  agency/corporate site that feels like an interactive story rather than a web page.
---

# Cinematic Static Site Builder

Build static websites that feel like interactive presentations — smooth, animated, layered, and
editorial. This skill captures the architectural patterns behind high-end agency sites and gives
you a repeatable playbook to apply them to any static site project.

## When to invoke

Trigger phrases:

- "cinematic", "animation-heavy", "game-like", "interactive storytelling", "presentation-style"
- "award-winning web design", "make it feel premium", "make my static site look amazing"
- "scroll-driven animations", "parallax", "WebGL background", "smooth scrolling"
- "editorial layout", "chapter-based navigation", "I want smooth transitions between sections"
- References to awwwards winners, luxury brand sites, or agency portfolios

Use cases:

- Building a new static site that needs to feel premium and cinematic
- Upgrading an existing static site from "functional" to "impressive"
- Adding scroll-driven animations, smooth scrolling, or WebGL effects
- Creating chapter-based or storytelling page layouts
- Any time the goal is "make people say wow when they scroll"

Related: For exploring multiple visual directions before committing, see the `multi-variant-site-design` skill.

## Architecture Overview

The stack has five layers. Each is independent — you can adopt them incrementally.

```
┌─────────────────────────────────────┐
│  5. WebGL / Canvas Effects          │  ← optional "wow" layer
├─────────────────────────────────────┤
│  4. Scroll-Triggered Animations     │  ← per-section reveals & transitions
├─────────────────────────────────────┤
│  3. Smooth Scroll Engine            │  ← Lenis (or similar)
├─────────────────────────────────────┤
│  2. Editorial Grid Layout           │  ← CSS Grid, custom breakpoints
├─────────────────────────────────────┤
│  1. Static Site Generator + Scoped  │  ← Astro, Next.js static, Hugo, etc.
│     Component Styles                │
└─────────────────────────────────────┘
```

Start from layer 1 and work up. Never skip layers — smooth scroll without a solid grid looks janky,
and WebGL without smooth scroll feels disconnected.

---

## Layer 1: Static Site Generator + Scoped Styles

### Framework choice

Astro is the strongest choice for this pattern because:
- Zero JS by default — you opt in to interactivity per-component
- Scoped `<style>` blocks per `.astro` component (no class name collisions)
- Built-in view transitions via `ClientRouter`
- Easy to mix frameworks (e.g., a React Three.js component inside an Astro page)

Other valid choices: Next.js (static export), Nuxt (static), Hugo + JS modules.

### CSS approach: Hybrid utility + component classes

Do NOT use Tailwind out of the box for this kind of site. The responsive grid and animation needs
are too specific. Instead, create a **custom utility layer** alongside component classes:

```css
/* === Custom breakpoints (use semantic names, not just sm/md/lg) === */
/* tb = tablet, dk = desktop, ml = medium-large, lg = large */
@custom-media --tb (min-width: 768px);
@custom-media --dk (min-width: 1024px);
@custom-media --ml (min-width: 1280px);
@custom-media --lg (min-width: 1440px);

/* === Grid utilities === */
.grid { display: grid; }
.col-start-1 { grid-column-start: 1; }
.col-end-5  { grid-column-end: 5; }
/* Generate responsive variants: tb:col-start-2, dk:col-end-24, etc. */

/* === Typography scale === */
.fs-h1 { /* hero headline */ }
.fs-h2 { /* section headline */ }
.fs-cta-s { /* small call-to-action */ }
.uppercase { text-transform: uppercase; }
```

### Font strategy

Self-host fonts as `.woff2`. Use exactly **two typeface families** for contrast:

| Role | Style | Example |
|------|-------|---------|
| Headlines / display | Elegant, light weight serif or geometric sans | Josefin Sans, Cormorant, Playfair Display |
| Body / UI | Highly legible geometric sans | Century Gothic, Inter, DM Sans |

Load the full weight range for the headline font (it will be used at Thin, Light, Regular, Bold
across different viewport sizes). Body font needs Regular + Bold + Italic minimum.

```css
@font-face {
  font-family: "Display Font";
  src: url("/assets/fonts/DisplayFont-Light.woff2") format("woff2");
  font-weight: 300;
  font-display: swap;
}
```

### CSS Custom Properties (set via JS)

Define viewport-aware variables that CSS alone can't reliably compute (mobile browser chrome):

```js
function setViewportVars() {
  document.documentElement.style.setProperty('--vw', `${window.innerWidth * 0.01}px`);
  document.documentElement.style.setProperty('--dvh', `${window.innerHeight * 0.01}px`);
}
window.addEventListener('resize', setViewportVars);
setViewportVars();
```

Use `--dvh` instead of `vh` for full-screen hero sections. This prevents the "jump" on mobile
when the browser chrome collapses.

---

## Layer 2: Editorial Grid Layout

The secret to editorial layouts is a **high-column-count grid** (20–24 columns) where content
spans different column ranges at different breakpoints.

### The Grid

```css
.grid-page {
  display: grid;
  grid-template-columns: repeat(24, 1fr);
  gap: 0;
  padding: 0 var(--container-padding-x);
}

/* Content block spanning columns 3–23 on desktop */
.content-wide {
  grid-column: 1 / -1;           /* mobile: full width */
}
@media (--dk) {
  .content-wide {
    grid-column: 3 / 23;          /* desktop: generous margins */
  }
}
@media (--lg) {
  .content-wide {
    grid-column: 4 / 22;          /* large: even more breathing room */
  }
}
```

### Section structure

Every page is a sequence of **chapters** (full-height or near-full-height sections):

```html
<main>
  <section class="chapter hero" data-chapter="0">...</section>
  <section class="chapter intro" data-chapter="1">...</section>
  <section class="chapter solutions" data-chapter="2">...</section>
  <section class="chapter locations" data-chapter="3">...</section>
  <section class="chapter sustainability" data-chapter="4">...</section>
</main>
```

Use `data-chapter` attributes for scroll-tracking and chapter navigation.

### Chapter navigation

A sticky side nav or dot indicator showing which chapter the user is in:

```html
<nav class="chapters-nav">
  <button class="dot active" data-target="0"></button>
  <button class="dot" data-target="1"></button>
  <button class="dot" data-target="2"></button>
</nav>
```

Update the `active` dot using an Intersection Observer watching each `[data-chapter]`.

---

## Layer 3: Smooth Scroll Engine

Use **Lenis** for smooth, momentum-based scrolling. It's lightweight (~3KB) and integrates
with all animation libraries.

```bash
npm install lenis
```

```js
import Lenis from 'lenis';

const lenis = new Lenis({
  duration: 1.2,        // scroll duration (seconds)
  easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)), // easeOutExpo
  smoothWheel: true,
  touchMultiplier: 2,
});

function raf(time) {
  lenis.raf(time);
  requestAnimationFrame(raf);
}
requestAnimationFrame(raf);
```

Add the `lenis` class to `<html>` and `loaded` class to `<body>` after initialization:

```css
html.lenis { height: auto; }
html.lenis body { height: auto; }
```

### Connecting Lenis to scroll-based animations

If using GSAP ScrollTrigger:
```js
lenis.on('scroll', ScrollTrigger.update);
gsap.ticker.add((time) => lenis.raf(time * 1000));
gsap.ticker.lagSmoothing(0);
```

---

## Layer 4: Scroll-Triggered Animations

This is where the "cinematic" feel comes from. Every section reveals itself as the user scrolls.

### Approach A: GSAP + ScrollTrigger (recommended for complex timelines)

```bash
npm install gsap
```

```js
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
gsap.registerPlugin(ScrollTrigger);
```

**Common animation patterns:**

1. **Fade-up reveal** (most versatile — use for headings, paragraphs, cards):
```js
gsap.from('.reveal-up', {
  y: 60,
  opacity: 0,
  duration: 1,
  stagger: 0.15,
  ease: 'power3.out',
  scrollTrigger: {
    trigger: '.reveal-up',
    start: 'top 85%',
    toggleActions: 'play none none none',
  },
});
```

2. **Parallax background** (images move slower than scroll):
```js
gsap.to('.parallax-bg', {
  yPercent: -20,
  ease: 'none',
  scrollTrigger: {
    trigger: '.parallax-section',
    start: 'top bottom',
    end: 'bottom top',
    scrub: true,
  },
});
```

3. **Horizontal scroll section** (cards slide left as user scrolls down):
```js
const container = document.querySelector('.horizontal-scroll');
const panels = gsap.utils.toArray('.horizontal-scroll .panel');

gsap.to(panels, {
  xPercent: -100 * (panels.length - 1),
  ease: 'none',
  scrollTrigger: {
    trigger: container,
    pin: true,
    scrub: 1,
    end: () => `+=${container.offsetWidth}`,
  },
});
```

4. **Text split animation** (letters or words animate in):
```js
// Split text into spans first (use SplitType or manual split)
gsap.from('.split-text span', {
  y: '100%',
  opacity: 0,
  duration: 0.8,
  stagger: 0.03,
  ease: 'power4.out',
  scrollTrigger: { trigger: '.split-text', start: 'top 80%' },
});
```

5. **Counter / number tick-up**:
```js
gsap.from('.stat-number', {
  textContent: 0,
  duration: 2,
  snap: { textContent: 1 },
  scrollTrigger: { trigger: '.stat-number', start: 'top 80%' },
});
```

### Approach B: CSS-only with Intersection Observer (lighter, no library)

For simpler sites, skip GSAP and use CSS transitions triggered by a class toggle:

```css
.reveal {
  opacity: 0;
  transform: translateY(40px);
  transition: opacity 0.8s ease, transform 0.8s ease;
}
.reveal.visible {
  opacity: 1;
  transform: none;
}
```

```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      observer.unobserve(entry.target);
    }
  });
}, { threshold: 0.15 });

document.querySelectorAll('.reveal').forEach(el => observer.observe(el));
```

### Animation principles

- **Stagger everything.** Never animate multiple items simultaneously. Use 100–200ms stagger.
- **Ease out, not in.** Elements should decelerate into their final position (`power3.out`, `ease-out`).
- **Trigger at 80–85% viewport.** Elements should start animating just before they're fully visible.
- **Animate once.** Don't replay animations when scrolling back up (use `toggleActions: 'play none none none'` or `unobserve`).
- **Keep durations 0.6–1.2s.** Shorter feels snappy, longer feels luxurious. Match the brand tone.
- **Transform only.** Animate `transform` and `opacity` only — never `width`, `height`, `top`, `left`, or `margin`. These trigger layout reflow and will cause jank.

---

## Layer 5: WebGL / Canvas Effects (Optional)

This is the "wow" layer. Use it sparingly — one WebGL element per page maximum.

### Common patterns

1. **Particle/noise background behind hero** — Three.js or OGL with a simple shader
2. **Image distortion on hover** — Curtains.js or custom WebGL plane
3. **3D model showcase** — Three.js with orbit controls
4. **Gradient mesh animation** — Canvas 2D with simplex noise

### Implementation with Three.js

```bash
npm install three
```

```js
// Minimal setup for a background canvas
import * as THREE from 'three';

const canvas = document.querySelector('.webgl-canvas');
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 100);
const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));

// Position canvas behind content
// CSS: .webgl-canvas { position: fixed; top: 0; left: 0; z-index: -1; pointer-events: none; }

function animate() {
  requestAnimationFrame(animate);
  // Update scene objects here
  renderer.render(scene, camera);
}
animate();
```

### Performance rules

- Cap `devicePixelRatio` at 2 — higher is invisible but tanks performance
- Use `alpha: true` so the canvas composites over the page background
- Add `pointer-events: none` to the canvas so it doesn't block scrolling
- Pause the render loop when the WebGL section is off-screen (use IntersectionObserver)
- Provide a **fallback** — detect `WebGL2RenderingContext` support and show a static gradient if missing

---

## Custom Cursor (bonus polish)

A custom cursor adds a tactile, "game-like" feel:

```html
<div class="cursor">
  <div class="cursor-inner"></div>
  <div class="cursor-circle"></div>
</div>
```

```css
.cursor { position: fixed; pointer-events: none; z-index: 9999; }
.cursor-inner {
  width: 8px; height: 8px;
  background: white;
  border-radius: 50%;
  transform: translate(-50%, -50%);
}
.cursor-circle {
  width: 40px; height: 40px;
  border: 1px solid rgba(255,255,255,0.5);
  border-radius: 50%;
  transform: translate(-50%, -50%);
  transition: width 0.3s, height 0.3s;
}
/* Grow on hover over interactive elements */
a:hover ~ .cursor .cursor-circle,
button:hover ~ .cursor .cursor-circle {
  width: 60px; height: 60px;
}
```

```js
document.addEventListener('mousemove', (e) => {
  // Inner dot follows instantly
  cursorInner.style.left = `${e.clientX}px`;
  cursorInner.style.top = `${e.clientY}px`;
  // Outer circle follows with lerp (smooth lag)
  gsap.to(cursorCircle, { left: e.clientX, top: e.clientY, duration: 0.15 });
});
```

Hide the system cursor: `* { cursor: none; }` — but only on non-touch devices
(`@media (hover: hover)`).

---

## Page Transitions

For multi-page sites, use view transitions to avoid hard reloads:

**Astro:** Add `<ClientRouter />` to your layout. Wrap page-specific content in
`transition:animate="fade"` or `transition:animate="slide"`.

**Vanilla / other frameworks:** Use the View Transitions API:
```js
document.startViewTransition(() => {
  // swap DOM content here
});
```

---

## Sound Design (optional, game-like)

For an interactive/game-like feel, add subtle UI sounds:

- Soft click on button hover
- Whoosh on section transition
- Ambient hum on WebGL section

Keep audio **opt-in** with a visible sound toggle. Never autoplay. Use the Web Audio API for
low-latency playback.

---

## Performance Checklist

Before shipping, verify:

- [ ] Lighthouse Performance score ≥ 90
- [ ] No layout shift from font loading (use `font-display: swap` + size-adjust)
- [ ] All animations use `transform`/`opacity` only (check with DevTools Performance tab)
- [ ] WebGL canvas pauses when off-screen
- [ ] Images use modern formats (WebP/AVIF) with `<picture>` fallbacks
- [ ] Fonts are subset to only the characters needed (use `pyftsubset`)
- [ ] `preload` tags have correct `crossorigin` attributes
- [ ] Smooth scroll doesn't break keyboard navigation or anchor links
- [ ] Site is usable with animations disabled (`prefers-reduced-motion: reduce`)
- [ ] Touch devices get simplified animations (no custom cursor, reduced parallax)

---

## Recommended Build Order

When implementing on a new site, follow this order strictly:

1. **Set up the static site generator** with component architecture
2. **Define the grid system and typography scale** — get the layout right at all breakpoints
3. **Build all sections as static content** — no animations yet, just HTML/CSS
4. **Add Lenis smooth scrolling**
5. **Add scroll-triggered reveals** (start with simple fade-up on headings)
6. **Layer in advanced animations** (parallax, horizontal scroll, text splits)
7. **Add chapter navigation** with Intersection Observer
8. **Add WebGL or canvas background** if appropriate
9. **Add page transitions** for multi-page navigation
10. **Polish** — custom cursor, sound, loading animation, `prefers-reduced-motion`

This order ensures you always have a working site. Each layer builds on the previous one.
