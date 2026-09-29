# Scoring

A numeric score is useful for comparing properties against each other and against the
buyer's stated priorities. It is *not* a verdict on whether the property is a good buy,
because the weighted sub-scores describe a property's **specification** — location, size,
age, running cost — and say nothing about whether this particular one is sound.

That gap is closed by the condition adjustment below, which is applied on top. A property
with four critical defects and an end-of-life roof scores 7.3 on specification alone, so
report the specification score and the adjustment as separate lines. Quoting the unadjusted
figure on its own actively misleads.

## Base helpers

**Piecewise-under** — for things where lower is better (price, commute minutes):

```
10                              if value <= target
5                               if value or target unknown, or target <= 0
max(0, 10 - over_ratio * 20)    otherwise, where over_ratio = (value - target) / target
```

Reaches 0 at 1.5× target.

**Piecewise-over** — for things where higher is better (square metres):

```
10                              if value >= target
5                               if value or target unknown, or target <= 0
max(0, 10 - under_ratio * 20)   otherwise, where under_ratio = (target - value) / target
```

Reaches 0 at 0.5× target.

## Sub-scores

**Commute.** Per `(destination, mode)`: `piecewise_under(minutes, max_minutes)`. For transit,
if transfers exceed `max_transfers`, subtract 2.0 per extra transfer — a soft penalty only,
never an exclusion on its own. Per destination, take the weighted average across its
configured modes using each mode's weight. Overall, average across all work destinations.
Exclude `current_home` from the overall commute score.

**Price** — `piecewise_under(price_dkk, max_purchase_price)`.

**Space** — `piecewise_over(m2, min_m2)`, then the small-home penalty: if bedrooms are known
and ≤ 2, multiply by 0.7. When bedrooms are not stated but rooms are, estimate
`bedrooms = max(0, int(rooms) - 1)` before applying it.

**Floor** — unknown: 3. No allowed-floors constraint given: 8. Otherwise 10 if allowed, 0 if
not.

**Age** — unknown year: 5. Outside a configured min/max window: 0. Otherwise 10.

**Balcony / outdoor** — unknown: 4. Present: 10. Absent: 0 if required, 5 if not. For houses,
treat a private garden as present.

**Energy** — normalise to the leading band `A`–`G`. Unknown: 3. `A` = 10, `G` = 0, linearly
spaced between.

**POI** — if POI scoring is off or nothing is configured: 5, contributing no weight. Otherwise
per category: missing: 0; present with no walk cap: 10; present with a cap: piecewise-under on
walking minutes. Take the weighted average across categories.

## Total

Weighted average of: commute, price, space, floor, age, balcony, energy, and poi — the last
only when POI categories are actually configured. If none are, POI contributes no weight at
all rather than dragging a neutral 5 into the average.

### Soft adjustments, applied after the weighted average

- If a bathroom-per-floor requirement is set, the unit spans 2+ floors, and only 1 bathroom is
  known: **−0.5**
- If the postcode is in the preferred list: **+0.25**, capped at 10
- **Condition adjustment** — see below. This one is usually the largest.

### The condition adjustment

The sub-scores above describe a property's *specification*: where it is, how big, how old,
what it costs. None of them describe whether it is falling apart. A property with four
critical defects scores identically to the same property in perfect order, which is exactly
backwards for a buyer's report.

Since `extract_property_pdfs.py` produces structured severity counts, this does not have to
stay a hand-waved caveat. Compute both of these and take the **larger** penalty — they
measure the same thing by different routes, so adding them would double-count:

```
count_penalty = 0.60*critical + 0.25*serious + 0.05*minor        capped at 3.0
cost_penalty  = 16 * (remediation_reserve / purchase_price)      capped at 3.0
```

The two measure different things. `count_penalty` captures **breadth** — an inspector who
found four critical items has usually found the four that were visible, and breadth is the
best available signal of deferred maintenance behind the walls. `cost_penalty` captures
**depth** — one ruinous roof outranks a dozen cosmetic notes. A 500,000 kr reserve on a 4m kr
property is 12.5% of price and lands at −2.0.

Take the larger rather than averaging them. That is deliberately conservative, and it should
be: this is a buy-side report, where the cost of under-warning is buying a money pit and the
cost of over-warning is walking away from a merely-acceptable deal. Those are not symmetric.
Use `cost_penalty` only when you actually have a remediation estimate — a missing estimate
means unknown depth, not zero depth, so falling back to the count is the honest default.

These coefficients are a defensible starting calibration, not physics. The shape is what
matters: one critical defect should sting, four should be disqualifying, and a pile of minor
cosmetic notes should barely register. If you adjust them for a particular property, say so
and say why — a reader can argue with a stated coefficient but not with a vibe.

**Safety items sit outside the arithmetic.** A missing `redningsåbning`, a shock or fire risk
in the electrical report, or anything the inspector marks `risiko for personskade` is a
must-fix-before-occupancy item, not a score deduction. Name these individually in the red
flags whatever the total says. A property can be worth buying with a −2.0 condition penalty;
it is not worth *moving into* with an un-remediated fire risk.

## Unknown-data defaults

Unknowns should stay neutral rather than punitive — a missing data point is the analyst's
gap, not the property's fault:

| Field | Default |
|---|---|
| commute | neutral for scoring; never an exclusion |
| floor | 3 |
| balcony | 4 |
| energy | 3 |
| POI (unknown or disabled) | 5 |

## Reporting the score

Show the total, every sub-score, and the basis for each — particularly which ones fell back to
a neutral default because preferences or data were missing. A 7.3 built mostly from 5.0
defaults means something very different from a 7.3 built from real measurements, and the user
cannot tell them apart unless you show the working.

Report the score in two lines, never one:

```
Specification score    7.3   (commute, price, space, energy…)
Condition adjustment  −2.65  (count: 4 critical + 1 serious = 2.65;
                              cost: 500,000 kr reserve = 12.5% of price = 2.00;
                              larger applies)
Adjusted               4.65
```

Show both penalties and which one won, as above. It tells the reader whether the property is
being marked down for *many* problems or for *expensive* ones — a distinction that changes
how they negotiate. Many cheap defects are a bargaining lever; one ruinous defect is a reason
to walk.
Showing both is the point. The specification score answers "is this the right kind of
property for me?" and the adjustment answers "is this particular one sound?" — collapsing
them into a single number destroys the distinction the buyer most needs, and quoting only
the unadjusted 7.3 is how a report ends up recommending a house with a failing roof.
