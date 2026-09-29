# Scoring

A numeric score is useful for comparing properties against each other and against the
buyer's stated priorities. It is *not* a verdict on whether the property is a good buy,
because — and this matters — **the model has no term for condition-report findings.**

A property with four critical defects and an end-of-life roof can score 7.3 here. Always
state that limitation in the report and give your adjusted judgement alongside the computed
number. A score presented without that caveat actively misleads.

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

Then give the condition-adjusted judgement in words. Something like: *"the model returns 7.3,
but it has no input for the four critical defects — judged on condition, treat this as a 6 at
best."*
