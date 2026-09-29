# Calculations

Formulas first, then the Danish-specific traps that generic mortgage arithmetic misses. The
traps are the reason this file exists — the arithmetic is easy, but a technically correct
calculation built on the seller's tax figures gives the buyer a number that is wrong by tens
of thousands of kroner a year.

`scripts/property_finance.py` implements all of this. Use it for consistency, but read this
file so you can explain what the numbers mean and spot when an assumption does not fit.

## 1. Mortgage

```
principal = max(0, purchase_price - down_payment)
n         = term_years * 12
r         = (annual_rate_pct / 100) / 12

monthly = principal / n                                  if r <= 0
monthly = principal * r / (1 - (1 + r)^(-n))             otherwise
```

Danish purchases normally split into a **realkreditlån** capped at **80% of the property's
value** at the mortgage-bond rate, plus a **boliglån** from the bank for the slice between
that cap and the down payment, at a materially higher rate (often the reference rate plus
~3 percentage points) and usually a shorter term. The cap is a legal limit, not a
preference — the bank loan is not optional at high LTV.

`property_finance.py` now splits these automatically and charges bidragssats only on the
realkredit portion, because bank loans do not carry it. Blending everything into one cheap
annuity understates a 95%-LTV purchase by roughly 1,000–2,400 kr/month and, worse, looks
plausible while doing it. Pass `--boliglaan-rate` and `--boliglaan-term` when you know the
bank's actual offer; otherwise the script assumes 7%/20yr and says so in the output.

**Minimum udbetaling is 5%** of the price for owner-occupied property. Anything below that
is not obtainable financing, and the script flags it rather than quietly modelling it.

### Bidragssats (contribution margin)

Realkredit lenders charge an ongoing margin on top of the coupon, and it steps up with LTV
band. Rough current shape for owner-occupied:

| LTV band | Typical bidragssats |
|---|---|
| 0–40% | ~0.40–0.55% |
| 40–60% | ~0.55–0.70% |
| 60–80% | ~0.75–1.00% |

This is charged on the outstanding balance annually — on the **realkredit loan only**. It is
why increasing the down payment from 5% to 20% improves the monthly figure by more than the
interest saving alone suggests: it shrinks the expensive bank loan and drops the bidrag
band at the same time. Showing the user that comparison explicitly often changes their plan.

### Ownership form changes the whole model

Establish whether the property is an **ejerbolig/ejerlejlighed** or an **andelsbolig**
before computing anything. They are not variations on a theme; they are different products:

| | Ejerbolig | Andelsbolig |
|---|---|---|
| What you own | The property | A share in a cooperative |
| Financing | Realkredit to 80% + boliglån | No realkredit — bank andelsboliglån only, higher rate, shorter term |
| Monthly to association | Ejerudgift | Boligafgift |
| Ejendomsværdiskat / grundskyld | Buyer pays both | Not levied on the andelshaver — the association pays, and it is already inside the boligafgift |
| Price ceiling | Market | Capped by `maksimalpris` from the andelskrone |
| The decisive document | Tilstandsrapport | The association's accounts, its debt, and any interest-rate swaps |

Run the script with `--tenure andel` for cooperatives. Applying the ejerbolig model to an
andelsbolig invents a property-tax bill that does not exist and assumes financing that is
not available, so the error is large and in both directions at once.

For an andelsbolig the association's balance sheet matters more than the flat. Check the
andelskrone and how it was valued, the association's total debt per andel, whether it holds
legacy swap contracts, and whether the boligafgift has been raised recently or is about to
be. A cheap andel in an indebted association is not cheap.

## 2. The tax trap: skatterabat does not transfer

**This is the single most consequential item in this file.**

Under the 2024 Danish property tax reform, owners who owned their property before the new
valuations took effect receive a `skatterabat` — a permanent discount freezing part of their
increase. It is **personal to that owner and is extinguished on sale.**

So the `Ejendomsværdiskat` and `Grundskyld` printed in the salgsopstilling's *Ejerudgift 1.
år* are frequently **the seller's discounted figures**, not what the buyer will pay. The buyer
pays the full rate on the current assessment from day one.

What to do:

1. Take `Grundlag for ejendomsværdiskat` and `Grundlag for grundskyld` from the salgsopstilling
2. Apply the current full rates. Ejendomsværdiskat is ~0.51% below the threshold (~9.2m kr)
   and ~1.4% above. Grundskyld is the municipal permille — and note that the 2024 reform
   **cut these dramatically**, from the old ~20–34 ‰ to roughly **5–10 ‰**. Using a
   pre-reform rate overstates the bill by a factor of three or four.
3. Compare against the printed figures and **show the delta explicitly**
4. If the assessment is marked `foreløbig` (provisional), warn that it will be back-adjusted
   via the årsopgørelse, and that when asking price sits well above the assessment the
   adjustment is more likely to go up than down

### Sanity-check by back-calculation

Before trusting any rate you looked up, divide the printed figures by their bases:

```
effective_evs_rate      = listed_ejendomsvaerdiskat / grundlag_for_ejdvaerdiskat
effective_grundskyld_permille = listed_grundskyld / grundlag_for_grundskyld * 1000
```

If the effective EVS rate comes out at ~0.51%, the listing already shows the full rate and
there is no hidden discount on that component. If the effective grundskyld permille is well
below the kommune's published rate, the seller is sitting on a rabat or a
stigningsbegrænsning that will not transfer — and the gap is what the buyer inherits.

This two-line check catches both the "I used a stale rate" error and the "the seller has a
discount" case, which otherwise look identical in the output.


If you cannot obtain the current rates confidently, say so and present the printed figures as
a **floor**, not an estimate. Understating this is the most expensive mistake available here.

## 3. Rentefradrag (interest deduction)

Brokers quote a generic rate (often ~25.4%). The real structure:

- Interest up to **50,000 kr** (single) or **100,000 kr** (couple) is deductible at the
  higher rate (~33%)
- Above that threshold the rate drops to roughly 25%

On a large mortgage the blended effective rate therefore sits below the headline. Compute it
against the household's actual situation when known; otherwise state which assumption you used
and that it is generic.

## 4. Costs the salgsopstilling legally excludes

Danish estate agents are prohibited from including financing and buyer-adviser costs. Every
figure on the front page therefore omits these. Typical ranges:

| Item | Indicative |
|---|---|
| Boligadvokat / købsrådgiver | 10,000–15,000 kr |
| Independent byggeteknisk gennemgang | 8,000–15,000 kr |
| Kurssikring | 5,000–15,000 kr |
| Bankgaranti | 3,000–8,000 kr |
| Loan establishment fees | 5,000–15,000 kr |
| **Total** | **~40,000–60,000 kr** |

Tinglysningsafgift on the deed *is* normally shown in `Kontantbehov ved køb`; check rather
than double-counting it.

## 5. Consumption

Split fixed charges from unit rates — fixed charges do not scale with frugality, so a
household that plans to heat less still pays them. District heating typically has a
substantial `fast afgift` (commonly 4,000–7,000 kr/yr) on top of the per-MWh rate.

The energy report's kWh figure is **calculated under standardised use**, not measured. Present
it as a modelled baseline and note that actual use varies with household size and habits.

## 6. Deferred maintenance vs. sinking fund

Keep these separate; conflating them hides the real exposure.

- **Deferred maintenance reserve** — one-off cost to remedy the specific defects found in the
  condition and electrical reports. Sum your per-defect indicative ranges.
- **Annual sinking fund** — ordinary ongoing upkeep, roughly **1–1.5% of building value per
  year**, entirely separate from the above. A house with a clean report still needs this.

Indicative remediation ranges (Danish market, adjust for scope and region):

| Work | Indicative |
|---|---|
| Full roof replacement, rowhouse/small house | 250,000–400,000 kr |
| Same, with asbestos removal and disposal | add 30,000–80,000 kr |
| Full wetroom rebuild | 100,000–150,000 kr |
| Electrical board + partial rewire | 30,000–80,000 kr |
| New escape window (redningsåbning) in roof or gable | 25,000–60,000 kr |
| Window replacement, per unit | 8,000–15,000 kr |
| Drain TV-inspection | 5,000–8,000 kr |
| Drain relining, per section | 30,000–80,000 kr |
| Radon measurement | 2,000–5,000 kr |

Always label these as indicative market ranges for sizing risk and negotiation — not quotes.

## 7. Stress testing

Show the monthly cost at **+2** and **+4** percentage points on the mortgage rate. For F-type
(adjustable) loans, model the reset explicitly rather than assuming the current rate holds.

This matters because Danish buyers are approved against affordability at a point in time, and
a 30-year commitment outlives any rate environment.

## 8. Break-even resale price

What must the property sell for to recover the investment?

```
break_even = purchase_price
           + buyer_transaction_costs
           + remediation_spend
           - principal_repaid_by_year_N
           + seller_costs_at_exit          (agent ~2–3% + tinglysning + reporting)
```

Present at 3, 5 and 10 years. When the asking price sits well above the public assessment,
this is usually the most sobering line in the report — and the most useful, because it
converts an abstract "is it overpriced?" into a concrete price the user must achieve.

Pair it with the crash history from `references/research-sources.md`: if the postcode fell
30% peak-to-trough in 2008 and took nine years to recover, a 3-year break-even that requires
appreciation is a real risk, not a theoretical one.

## 9. Total cost of ownership

Over 5 and 10 years, sum: mortgage payments, ejerudgift, recalculated property tax,
consumption, sinking fund, and remediation. Compare against renting an equivalent local
property over the same period. Note the equity accrued via principal repayment so the
comparison is fair.

## 10. Hard filters

Apply these separately from scoring — a property can score respectably and still be
excluded. Keep the two in distinct report sections so the user sees both.

- price above `max_purchase_price`
- total monthly cost above `max_monthly_expense`
- ejerudgift above `max_ejerudgift`
- `m2` below `min_m2`; rooms below `min_rooms`
- floor not in `allowed_floors`
- elevator / balcony / parking required but explicitly absent
- energy label worse than the minimum, when both are known
- postcode in the excluded list
- a required POI category missing within its radius

**Commute exclusion.** For each destination, evaluate only modes that have a cap. If *every*
capped mode exceeds its cap, exclude for that destination. If *any* capped mode is within
its cap, the destination is fine — one good option saves the listing. Unknown modes get the
benefit of the doubt and never trigger exclusion. Apply to `current_home` only if the user
set caps there.

## Script usage

```bash
python scripts/property_finance.py \
    --price 4000000 --down 200000 --rate 4.0 --term 30 \
    --boliglaan-rate 6.5 --boliglaan-term 20 \
    --ejerudgift 3200 \
    --tax-base-value 2500000 --tax-base-land 1400000 --kommune-permille 6.3 \
    --remediation 500000 \
    --json
```

Figures above are illustrative placeholders — substitute the ones from the salgsopstilling.
Add `--tenure andel` for an andelsbolig. The script prints `!!` warnings for anything
structurally wrong with the financing (below-minimum deposit, assumed bank rate, stale rate
constants) — surface those in the report rather than only the numbers.

### One thing not to double-count

Ejerudgift already contains the seller's property tax. Adding your recomputed buyer-basis
tax on top of it counts the tax twice; ignoring the recomputation entirely leaves the
seller's discounted figure in the buyer's budget. The script threads this by adding only
the **uplift** — the delta between what the buyer will pay and what the listing showed — and
labels it as such. If you do this arithmetic by hand, do the same.


Omit what you do not know; the script marks those outputs `unknown` rather than guessing.
`--json` emits machine-readable output for building the report tables.
