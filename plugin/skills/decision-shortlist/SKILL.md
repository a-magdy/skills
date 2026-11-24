---
name: decision-shortlist
description: Research a shortlist of products or options and build an interactive comparison page where filter sliders grow the options that match and shrink the rest, with real photos, independent review scores, collapsible pros and cons, a metrics table and a verdict. Use when the user is choosing between several things to buy or pick, e.g. "help me choose between these", "compare these backpacks", "which of these should I get", "make a comparison page with filters", "shortlist these options", "review these and build a comparison". Not for comparing website design variants (use multi-variant-site-design), and not for recording a decision already made (use decision-log).
---

# Decision shortlist

This skill turns "help me choose between these" into a researched, interactive comparison page for any purchase: gadgets, bags, appliances, gifts, services. The user's shortlist goes in. Out comes one standalone HTML page with real photos, filter sliders that resize options by relevance and stick between visits, light and dark themes, collapsible pros and cons, a metrics table, a verdict and a list of honourable mentions.

Act as an advisor, not an order-taker. Suggest what the user hasn't thought of, and push back when a request would make the page less useful (see section 3).

**Starting point:** `assets/shortlist-template.html`. It is data-driven: copy it, fill in the one `DATA` block, and the page renders tiles, filters, cards, both tables, picks, honourable mentions and the footer from it. Don't hand-edit the engine below `DATA`. Its slider kinds, sticky filters and theme switch are already tested.

## 1. Pin down the brief (one short round)

Before researching, make sure you know:

- Who the choice is for and how they'll use it: the person, context, frequency and constraints (space, power, mobility, skill, health or dexterity).
- Must-haves and deal-breakers. These become the filter sliders.
- Taste words ("chic", "technical", "no budget brands"). These become a style or quality axis.
- The market: country, local currency, local shops, whether marketplaces abroad are acceptable, and import costs (VAT, customs) for brands sold only abroad.

If the user has already given this, don't ask again. Ask at most one round of questions. If details are missing, start anyway, turn the unknowns into sliders, and say which unknowns would change the pick.

## 2. Research each candidate

### Where to look

- **One respected independent score**, from the same source for every option where you can: the category's best hands-on tester (for example RTINGS, Wirecutter, OutdoorGearLab, Pack Hacker for bags), plus consumer organisations (Which?, Consumer Reports, Stiftung Warentest, Tænk, Testfakta and similar). Say so when a score is paywalled rather than guessing it.
- **Local prices** from the market's price-comparison site (PriceRunner, idealo, Prisjakt, Tweakers, Google Shopping). Open the offer list, not just the headline price, to see shop, shipping, delivery time and stock. For Shopify stores, `/products/<handle>.js` returns live variant availability and price.
- **Buyer ratings with review counts** from the biggest local retailer or marketplace. Treat them as a separate, weaker tier of evidence than expert tests.

### Collect for every option

- **Core specs.** The 3–6 numbers that matter for this category: size or capacity, weight, dimensions, power, battery, settings.
- **Category features, counted.** Count them; don't describe them loosely.
- **Scores and complaints.** The expert score, buyer rating and count, recurring complaints, and the warranty.
- **Best current local price**, including codes or sales, the shop and **stock**. Cached or fetched pages can be stale and may show an item as sold out when it isn't, so verify stock before stating it.
- **Colours or variants**, with the distinctive ones flagged.
- **Evidence level:** tested by an expert, one review, or buyer ratings only. Label estimated specs as estimates on the page.

### Traps to check every time

- **Regional variants.** The cheapest listing may be another region's model, with the wrong voltage or plug, a different model number or no local warranty. Match the model code to the local version.
- **Single-listing deals.** A price from one shop can be the best value. Label it as one listing that may end, and name a widely stocked fallback.
- **Marketing posing as evidence.** "Test winner", "dentist recommended" or "#1 rated" in a listing title is the seller's claim unless you can find the test. Discount affiliate round-ups and sponsored articles, and say so when they make up most of a brand's buzz.
- **Variant mix-ups.** Double-check which version has which feature. Two sizes of the same model often differ.

Keep a running list of the options you looked at and cut: name, price and a one-line reason (pricier sibling, no expert review, weaker score, fewer features, a cheaper alternative with more evidence). It becomes the honourable mentions.

Do most research inline, because each finding shapes the next search. If the list is long (8+ options) or the user asks for it, and the CLI has a subagent tool, give each agent one option or brand with the identical checklist, then cross-check any figures that disagree.

## 3. Push back and suggest

Do this at the start, while building and after every change. Keep each point to one line with a concrete alternative, then do what the user decides. Pushback informs the choice; it never blocks it.

**Sliders and filters**

- Before building, propose the slider set from the brief: the 5–8 criteria that separate the options, ranked by importance.
- Push back on a requested slider when its data is patchy (fewer than about 75 % of options have a value), when it duplicates another slider ("time per tank" next to "tank size"), when every option would pass it, or when it rests on your own judgement more than on data. Offer the better version: replace the duplicate, fold it into a multi-step needs slider, or fill the gaps with research first.
- Prefer one multi-step **needs** slider (none, some, demanding) over several checkboxes when the requirements build on each other.
- After each change, suggest 1–3 more sliders or toggles, best first, each with how solid its data is. Common ones: buy from a local shop, yearly running cost, noise, warranty length, weight, footprint, battery life, colours.

**Brands and models**

- When the user names a brand, look at its whole range, pick the models that fit the brief, and say plainly where the brand stands: evidence level, local availability, and how it compares with the leaders.
- Suggest brands and models the user didn't mention when independent tests rank them well, or when they beat a shortlisted option on value.
- Say when a brand doesn't fit the brief (promo or merch brands, travel-only versions, missing colours, no local seller), and suggest a replacement.

**Search targets**

- Name the better source when the obvious one is weak, for example "these are affiliate round-ups; the consumer organisations test this category".
- When two options are close, search for the specific fact that separates them rather than more general praise.

**Before calling it done**, answer "is this the best selection?" yourself: what is solid, what is weak (price volatility, thin evidence, estimated specs), and which facts about the person would change the pick.

## 4. Get real photos

Aim for 2–4 photos per option: the main colour, a variant or key detail, and a scale or lifestyle shot if available. Never use photos of public figures. Keep photos next to the page in `img/` and reference them relatively, because hosted page viewers often block external images.

- **Fetch with the script.** Write a `products.json` keyed by the page's option ids, and run `scripts/fetch_product_images.py products.json` where shop sites are reachable, usually the user's own machine. Sandboxed agents often get 403 from shops and image CDNs.
  - **Config format:** `{"out": "<topic>-photos", "max": 4, "size": 720, "products": {"<id>": {"pages": [...], "direct": [...], "keywords": [...]}}}`.
  - **What it collects:** from each page it takes Shopify product images, JSON-LD product images, `og:image` and `<img>` tags that mention a keyword. It asks image CDNs for larger versions, skips share banners, slivers and duplicates, and writes a manifest, a `contact.html` and a zip.
  - **Pages and direct URLs:** price-comparison product pages work well. For marketplaces that block page fetches, collect gallery image URLs in a browser and list them under `direct`.
- **Fallback with a browser.** If a browser tool is available, open the product page, fetch each image as a blob in page JavaScript, and trigger an `<a download>`. **Wait 2.5–4 s between downloads**, or some get silently dropped. Then run `scripts/prep_images.py <src> <dst> [sheet.jpg]` to fit them to 720 px at JPEG quality 78 and build a contact sheet.
- **Check every photo** on the contact sheet. Keep only the right model and colour. Drop share banners, duplicates, marketing infographics and photos of people. Name keepers `img/<id>-<variant>.jpg` and caption each one with its variant and price in `DATA.options[].photos`.
- **No photos yet?** The template draws a simple shape per option (`art.shape`: `top`, `wand` or `box`). Ship with those, say so, and add the photos later.

## 5. Build the page

The default output location is inside the calling repo: `comparisons/<topic>/index.html` plus `comparisons/<topic>/img/`. Copy the template there and fill in `DATA`:

- `topic` sets the storage keys. `title`, `kicker` ("<category> · N finalists · prices checked <date>"), `brief`, `basis` (price basis and score source), `person` ("Why it suits <person>") and `note` (how the filters behave).
- `sliders`, in this order: selective ones first, "up to" ones last. Kinds:
  - `cat`: a 3-stop categorical slider with "Any" in the middle.
  - `level`: a needs ladder. Each level names a grade key; an option grades 0 (miss), 1 (partial, grey chip) or 2 (full).
  - `min`: "at least", with an optional `soft` tolerance that turns a near miss into a grey chip.
  - `score`: ignored until moved. Options without a score drop out as "No expert score".
  - `max`: "up to", for budget or weight.
- `options`. One entry per option, in display order, with content fields plus `v`, which holds the values the sliders read. Text supports `**bold**` and `[label](https://…)`, and everything else is escaped.
- `h2h` (optional), for two close rivals. `picks`: best for the brief, best value, budget, and skip or splurge as fits.
- `table`. Grouped rows, with one cell per option in option order. A cell is a string or `[text, "best" | "bad" | "no"]`. Write "Not listed" or "Not checked", never a guess.
- `mentions` (the honourable mentions) and `footer` (sources, the date prices were checked, and volatility notes).

### What the engine already does

- **Resize, don't dim.** Matches grow with an outline. A soft miss keeps its size with a grey chip. A hard miss shrinks, and its card collapses to a row with "Show details". Chips name the reason. Table columns follow the same states.
- **Lineup tiles** have a minimum width of about 112 px and a maximum of 240 px. Eight fit on one desktop row, and a wrapped last row can't stretch into giant tiles.
- **Sticky filters.** State lives in a plain hash, `#f-<v1>-<v2>-…`, in slider order, written with `history.replaceState`. Many hosted viewers pass only a plain `#name`, never `?key=value`. It is also kept in `localStorage`. On load the hash wins, then the stored state, then the defaults. Values are clamped and re-written, and the hash clears when everything is at its defaults. Adding or reordering sliders changes the format, so old links fall back to the defaults.
- **Light and dark.** Colours are `light-dark()` tokens, so the page follows the viewer or system theme. An Auto / Light / Dark switch overrides it and is remembered. Photos sit on white tiles in both themes.
- **Reset** (disabled while everything is at its defaults) and **Esc** both reset the filters.

### Quality bar

- Extract the script and run `node --check`. Then render the page headless, if a browser is available, at desktop and phone widths in light and dark. Check that there are no script errors and no horizontal scroll, that the filters behave, that a filter hash round-trips, and that the photos aren't distorted.

## 6. Deliver and iterate

- Open the page in a browser to check it. If the environment can publish hosted pages, publish it there with the `img/` files alongside, and report in one line what the page is.
- **Before republishing a hosted page, check who can see it.** If it's public, a republish changes what everyone with the link sees, so confirm with the user first.
- Product photos belong to their retailers or brands. Keep them out of anything published publicly unless you have the rights, and say so if the user makes a page with photos public.
- With the template, adding, removing or reordering options means editing `options`, the matching table cells, `picks`, `h2h` and the finalist count in `kicker`. Nothing else needs to change.
- After each change, say in a line or two what changed and suggest the next sliders, brands or checks. Keep replies short; the page holds the detail.

## Lessons learned

- Double-check which variant has which feature before writing it.
- When the user says a stock or price fact is wrong, re-verify it at the source and fix the page. Don't defend a cached fetch.
- The cheapest listing is often the wrong regional model. Check the model code against the local version.
- Price-comparison sites can use a dark social-share banner as `og:image`. The fetch script skips the common one, but check the contact sheet anyway.
