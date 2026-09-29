#!/usr/bin/env python3
"""Danish property cost model.

Generic mortgage arithmetic gives a buyer the wrong number here, because the tax figures
printed in a salgsopstilling are frequently the *seller's* discounted ones. Since the 2024
reform the skatterabat is personal and dies on sale, so the buyer pays full rate from day
one. This script recomputes on the buyer's basis and shows the delta.

Everything unknown stays unknown rather than being guessed.

Usage (illustrative figures only — substitute the real ones):
    python property_finance.py --price 4000000 --down 200000 --rate 4.0 \
        --ejerudgift 3200 --tax-base-value 2500000 --tax-base-land 1400000 \
        --kommune-permille 6.3 --remediation 500000 --json

Note the permille: post-2024 grundskyld rates are roughly 5-10 per mille. A pre-reform
figure in the 20-34 range will overstate the tax bill several times over.
"""

from __future__ import annotations

import argparse
import datetime
import json

_THIS_YEAR = datetime.date.today().year

# Rate constants below are RATES_YEAR values. They are indexed or politically set and go
# stale; the script warns when it is run in a later year rather than quietly misreporting.
RATES_YEAR = 2024

# Ejendomsværdiskat, 2024 reform. Verify against skat.dk for the year in question —
# thresholds are indexed and these are the headline values, not tax advice.
EVS_LOW_RATE = 0.0051
EVS_HIGH_RATE = 0.0140
EVS_THRESHOLD = 9_200_000

# Rentefradrag: higher rate applies below the threshold, lower above it.
DEDUCT_HIGH = 0.3360
DEDUCT_LOW = 0.2540
DEDUCT_THRESHOLD_SINGLE = 50_000
DEDUCT_THRESHOLD_COUPLE = 100_000

BIDRAG_BANDS = [(0.40, 0.0045), (0.60, 0.0060), (0.80, 0.0085)]

# Realkredit cannot exceed 80% of value on owner-occupied property, and a buyer must put
# down at least 5%. Anything between those two limits is bank debt at a higher rate.
REALKREDIT_MAX_LTV = 0.80
MIN_DOWN_PCT = 0.05
BOLIGLAAN_DEFAULT_RATE = 7.0
BOLIGLAAN_DEFAULT_TERM = 20

BUYER_COSTS = {
    "boligadvokat": (10_000, 15_000),
    "byggeteknisk_gennemgang": (8_000, 15_000),
    "kurssikring": (5_000, 15_000),
    "bankgaranti": (3_000, 8_000),
    "laanesagsgebyr": (5_000, 15_000),
}

SELLER_EXIT_PCT = (0.02, 0.03)


def annuity(principal: float, annual_rate_pct: float, years: int) -> float:
    n = years * 12
    if n <= 0 or principal <= 0:
        return 0.0
    r = (annual_rate_pct / 100.0) / 12.0
    if r <= 0:
        return principal / n
    return principal * r / (1 - (1 + r) ** (-n))


def principal_repaid(principal: float, annual_rate_pct: float, years: int,
                     after_years: int) -> float:
    """Principal actually paid down after N years — most of an early annuity is interest."""
    if principal <= 0:
        return 0.0
    r = (annual_rate_pct / 100.0) / 12.0
    pmt = annuity(principal, annual_rate_pct, years)
    bal = principal
    for _ in range(min(after_years * 12, years * 12)):
        interest = bal * r
        bal -= max(0.0, pmt - interest)
    return principal - max(0.0, bal)


def bidragssats(ltv: float) -> float:
    for cap, rate in BIDRAG_BANDS:
        if ltv <= cap:
            return rate
    return BIDRAG_BANDS[-1][1]


def ejendomsvaerdiskat(basis: float | None) -> float | None:
    if basis is None:
        return None
    if basis <= EVS_THRESHOLD:
        return basis * EVS_LOW_RATE
    return EVS_THRESHOLD * EVS_LOW_RATE + (basis - EVS_THRESHOLD) * EVS_HIGH_RATE


def grundskyld(basis: float | None, permille: float | None) -> float | None:
    if basis is None or permille is None:
        return None
    return basis * (permille / 1000.0)


def deduction(annual_interest: float, couple: bool) -> float:
    threshold = DEDUCT_THRESHOLD_COUPLE if couple else DEDUCT_THRESHOLD_SINGLE
    low_part = min(annual_interest, threshold)
    high_part = max(0.0, annual_interest - threshold)
    return low_part * DEDUCT_HIGH + high_part * DEDUCT_LOW


def build(a) -> dict:
    out: dict = {"assumptions": {}, "unknown": [], "warnings": []}
    price = a.price
    down = a.down if a.down is not None else 0.0
    principal = max(0.0, price - down)
    ltv = principal / price if price else 0.0
    tenure = getattr(a, "tenure", "ejer")

    out["assumptions"] = {
        "price_dkk": price,
        "down_payment_dkk": down,
        "principal_dkk": round(principal),
        "ltv": round(ltv, 4),
        "rate_pct": a.rate,
        "term_years": a.term,
        "household": "couple" if a.couple else "single",
        "tenure": tenure,
        "rates_valid_for_year": RATES_YEAR,
    }

    if RATES_YEAR != _THIS_YEAR:
        out["warnings"].append(
            f"Rate constants in this script are {RATES_YEAR} values and the current year is "
            f"{_THIS_YEAR}. Verify ejendomsvaerdiskat rates, thresholds, rentefradrag and "
            f"bidragssats against skat.dk before quoting these figures."
        )

    # Minimum udbetaling is 5% for owner-occupied property. Modelling less than that
    # produces a monthly figure for financing the buyer cannot legally obtain.
    if price and down < price * MIN_DOWN_PCT:
        out["warnings"].append(
            f"Down payment is {down/price*100:.1f}% of price. Danish rules require a minimum "
            f"{MIN_DOWN_PCT*100:.0f}% udbetaling ({price*MIN_DOWN_PCT:,.0f} kr) for "
            f"owner-occupied property — this financing is not obtainable as modelled."
        )

    # Realkredit is capped at 80% of value. The slice above that cap has to be a boliglån
    # from a bank at a materially higher rate and usually a shorter term, and it carries no
    # bidragssats. Modelling the whole loan as one cheap annuity understates the real cost.
    if tenure == "andel":
        rk_principal = 0.0
        bank_principal = principal
        structure = "andelsboliglån (realkredit is not available on andelsboliger)"
    else:
        rk_principal = min(principal, price * REALKREDIT_MAX_LTV)
        bank_principal = max(0.0, principal - rk_principal)
        structure = "realkredit + boliglån" if bank_principal else "realkredit only"

    bank_rate = a.boliglaan_rate if a.boliglaan_rate is not None else BOLIGLAAN_DEFAULT_RATE
    bank_term = a.boliglaan_term if a.boliglaan_term is not None else BOLIGLAAN_DEFAULT_TERM

    rk_monthly = annuity(rk_principal, a.rate, a.term)
    bank_monthly = annuity(bank_principal, bank_rate, bank_term)
    monthly = rk_monthly + bank_monthly

    # Bidragssats is a realkredit fee; bank loans do not carry it. Its band is set by the
    # realkredit loan's own LTV, not by the combined LTV.
    rk_ltv = rk_principal / price if price else 0.0
    bid_rate = bidragssats(rk_ltv) if rk_principal else 0.0
    bid_monthly = rk_principal * bid_rate / 12.0

    year1_interest = (rk_principal * (a.rate / 100.0)
                      + bank_principal * (bank_rate / 100.0))

    out["mortgage"] = {
        "structure": structure,
        "realkredit_principal_dkk": round(rk_principal),
        "realkredit_monthly_dkk": round(rk_monthly),
        "boliglaan_principal_dkk": round(bank_principal),
        "boliglaan_monthly_dkk": round(bank_monthly),
        "boliglaan_rate_pct": bank_rate if bank_principal else None,
        "boliglaan_term_years": bank_term if bank_principal else None,
        "boliglaan_rate_is_assumed": bank_principal > 0 and a.boliglaan_rate is None,
        "monthly_payment_dkk": round(monthly),
        "bidragssats_pct": round(bid_rate * 100, 3),
        "bidrag_monthly_dkk": round(bid_monthly),
        "monthly_incl_bidrag_dkk": round(monthly + bid_monthly),
        "year1_interest_dkk": round(year1_interest),
    }

    if bank_principal and a.boliglaan_rate is None:
        out["warnings"].append(
            f"{bank_principal:,.0f} kr sits above the 80% realkredit cap and must be a "
            f"boliglån. No rate was given, so {BOLIGLAAN_DEFAULT_RATE}% over "
            f"{BOLIGLAAN_DEFAULT_TERM} years is assumed — get the bank's real offer, as this "
            f"is the least certain number in the model."
        )

    ded = deduction(year1_interest, a.couple)
    out["mortgage"]["rentefradrag_year1_dkk"] = round(ded)
    out["mortgage"]["effective_deduction_pct"] = (
        round(ded / year1_interest * 100, 2) if year1_interest else None
    )
    out["mortgage"]["net_monthly_dkk"] = round(monthly + bid_monthly - ded / 12.0)

    # Buyer-basis property tax — the point of this script. An andelshaver owns a share in a
    # cooperative rather than real property, so neither of these taxes lands on them
    # personally; the association's own property tax is already inside the boligafgift.
    if tenure == "andel":
        out["property_tax"] = {
            "applies": False,
            "note": (
                "Andelsbolig: ejendomsvaerdiskat and grundskyld are not levied on the "
                "andelshaver. The association pays property tax and it is already inside "
                "the boligafgift — do not add it again. Scrutinise the association's "
                "accounts, its debt and any interest-rate swaps instead."
            ),
        }
    else:
        evs = ejendomsvaerdiskat(a.tax_base_value)
        gs = grundskyld(a.tax_base_land, a.kommune_permille)
        tax = {
            "applies": True,
            "ejendomsvaerdiskat_dkk": round(evs) if evs is not None else None,
            "grundskyld_dkk": round(gs) if gs is not None else None,
            "warning": (
                "Recomputed on the BUYER's basis. The seller's skatterabat does not transfer "
                "(2024 reform), so figures printed in the salgsopstilling may be the seller's "
                "discounted ones. Verify current rates and the kommune permille."
            ),
        }
        if evs is None:
            out["unknown"].append("ejendomsvaerdiskat (need --tax-base-value)")
        if gs is None:
            out["unknown"].append("grundskyld (need --tax-base-land and --kommune-permille)")
        if evs is not None and gs is not None:
            tax["total_annual_dkk"] = round(evs + gs)
            tax["total_monthly_dkk"] = round((evs + gs) / 12.0)
            if a.listed_tax_annual is not None:
                delta = (evs + gs) - a.listed_tax_annual
                tax["listed_in_salgsopstilling_dkk"] = a.listed_tax_annual
                tax["delta_vs_listed_dkk"] = round(delta)
                tax["delta_note"] = (
                    f"Buyer pays {round(delta):+,} kr/yr more than the listing shows"
                    if delta > 0 else "Listing figure appears to already be the full rate"
                )

        # Back-calculate the rates the listing actually used. This distinguishes "I used a
        # stale rate" from "the seller has a rabat that won't transfer" — otherwise the two
        # look identical in the output.
        implied = {}
        if a.listed_evs is not None and a.tax_base_value:
            eff = a.listed_evs / a.tax_base_value
            implied["ejendomsvaerdiskat_effective_pct"] = round(eff * 100, 4)
            implied["evs_verdict"] = (
                "matches the full statutory rate — no hidden discount on this component"
                if abs(eff - EVS_LOW_RATE) < 0.0004
                else "below the statutory rate — seller likely holds a rabat that will NOT transfer"
            )
        if a.listed_grundskyld is not None and a.tax_base_land:
            eff_pm = a.listed_grundskyld / a.tax_base_land * 1000
            implied["grundskyld_effective_permille"] = round(eff_pm, 2)
            if a.kommune_permille:
                implied["kommune_permille_used"] = a.kommune_permille
                implied["grundskyld_verdict"] = (
                    "listing matches the kommune rate"
                    if abs(eff_pm - a.kommune_permille) < 0.5
                    else f"listing implies {eff_pm:.2f} permille vs kommune rate "
                         f"{a.kommune_permille} — check which is right before reporting"
                )
        if implied:
            tax["implied_from_listing"] = implied

        out["property_tax"] = tax

    lo = sum(v[0] for v in BUYER_COSTS.values())
    hi = sum(v[1] for v in BUYER_COSTS.values())
    out["buyer_transaction_costs"] = {
        "items": {k: list(v) for k, v in BUYER_COSTS.items()},
        "range_dkk": [lo, hi],
        "note": "Excluded from the salgsopstilling by law. Tinglysningsafgift is usually "
                "already in Kontantbehov ved køb — check before double-counting.",
    }

    ejer = a.ejerudgift
    running = monthly + bid_monthly
    if ejer is not None:
        running += ejer
    else:
        out["unknown"].append("ejerudgift (need --ejerudgift)")
    if a.consumption_monthly is not None:
        running += a.consumption_monthly
    else:
        out["unknown"].append("consumption (need --consumption-monthly)")

    # Ejerudgift already contains property tax — but the seller's, possibly discounted.
    # Adding the recomputed tax outright would double-count it, so add only the uplift the
    # buyer inherits. Without this the headline monthly figure quietly stays the seller's.
    tax_uplift = 0.0
    tax_block = out.get("property_tax", {})
    if ejer is not None and tax_block.get("delta_vs_listed_dkk", 0) > 0:
        tax_uplift = tax_block["delta_vs_listed_dkk"] / 12.0
        running += tax_uplift

    sinking = (a.building_value or price * 0.6) * 0.0125 / 12.0
    out["monthly"] = {
        "mortgage_incl_bidrag_dkk": round(monthly + bid_monthly),
        "ejerudgift_dkk": ejer,
        "property_tax_uplift_dkk": round(tax_uplift) if tax_uplift else None,
        "property_tax_uplift_note": (
            "Ejerudgift contains the seller's property tax; this is the additional amount "
            "the buyer pays once the skatterabat falls away."
        ) if tax_uplift else None,
        "consumption_dkk": a.consumption_monthly,
        "gross_total_dkk": round(running),
        "net_total_after_deduction_dkk": round(running - ded / 12.0),
        "sinking_fund_dkk": round(sinking),
        "sinking_fund_note": "1.25%/yr of building value for ordinary upkeep — separate "
                             "from one-off remediation.",
        "all_in_with_sinking_dkk": round(running - ded / 12.0 + sinking),
    }

    def split_monthly(bump: float) -> float:
        """Both loans reprice together in a rate shock, each on its own rate."""
        return (annuity(rk_principal, a.rate + bump, a.term)
                + annuity(bank_principal, bank_rate + bump, bank_term))

    out["stress_test"] = {
        f"+{bump}pp": {
            "rate_pct": a.rate + bump,
            "monthly_dkk": round(split_monthly(bump) + bid_monthly),
            "delta_dkk": round(split_monthly(bump) - monthly),
        }
        for bump in (2, 4)
    }

    remediation = a.remediation or 0.0
    be = {}
    for yr in (3, 5, 10):
        repaid = (principal_repaid(rk_principal, a.rate, a.term, yr)
                  + principal_repaid(bank_principal, bank_rate, bank_term, yr))
        base = price + hi + remediation - repaid
        be[f"year_{yr}"] = {
            "break_even_low_dkk": round(base / (1 - SELLER_EXIT_PCT[0])),
            "break_even_high_dkk": round(base / (1 - SELLER_EXIT_PCT[1])),
            "principal_repaid_dkk": round(repaid),
            "vs_purchase_price_pct": round(
                (base / (1 - SELLER_EXIT_PCT[1]) / price - 1) * 100, 1
            ),
        }
    out["break_even_resale"] = {
        "detail": be,
        "note": "Price needed to recover purchase + buyer costs + remediation, after "
                "2-3% agent commission at exit. Compare against the postcode's 2008 "
                "peak-to-trough to judge whether that is realistic.",
    }

    if a.remediation:
        out["remediation"] = {
            "reserve_dkk": remediation,
            "true_acquisition_cost_dkk": round(price + hi + remediation),
            "effective_price_per_m2": (
                round((price + remediation) / a.m2) if a.m2 else None
            ),
        }

    for yrs in (5, 10):
        months = yrs * 12
        tco = (monthly + bid_monthly) * months
        if ejer:
            tco += ejer * months
        if a.consumption_monthly:
            tco += a.consumption_monthly * months
        # Ejerudgift already carries property tax, so only the buyer's uplift is added —
        # mirroring the monthly figure. Where ejerudgift is unknown there is nothing to
        # double-count against, so the recomputed tax goes in whole.
        if ejer is None and tax_block.get("total_annual_dkk"):
            tco += tax_block["total_annual_dkk"] * yrs
        elif tax_uplift:
            tco += tax_uplift * months
        tco += sinking * months + remediation
        tco -= ded * yrs
        out.setdefault("total_cost_of_ownership", {})[f"year_{yrs}"] = {
            "total_dkk": round(tco),
            "monthly_average_dkk": round(tco / months),
            "equity_from_principal_dkk": round(
                principal_repaid(rk_principal, a.rate, a.term, yrs)
                + principal_repaid(bank_principal, bank_rate, bank_term, yrs)
            ),
        }

    out["disclaimer"] = ("Indicative model for sizing risk and negotiation. Not tax, "
                         "legal or financial advice.")
    return out


def emit_text(d: dict) -> None:
    a = d["assumptions"]
    tenure = a.get("tenure", "ejer")
    head = (f"\nPrice {a['price_dkk']:,} kr   down {a['down_payment_dkk']:,} kr   "
            f"LTV {a['ltv']*100:.1f}%")
    if tenure != "andel":
        head += f"   {a['rate_pct']}% / {a['term_years']}yr"
    print(head + f"   [{tenure}]")

    for w in d.get("warnings", []):
        print(f"\n  !! {w}")

    m = d["mortgage"]
    print(f"\nFinancing  ({m.get('structure', 'realkredit')})")
    if m.get("realkredit_principal_dkk"):
        print(f"  realkredit  {m['realkredit_principal_dkk']:,} kr  "
              f"-> {m['realkredit_monthly_dkk']:,} kr/md "
              f"(+ bidrag {m['bidrag_monthly_dkk']:,} @ {m['bidragssats_pct']}%)")
    if m.get("boliglaan_principal_dkk"):
        assumed = " [rate ASSUMED]" if m.get("boliglaan_rate_is_assumed") else ""
        print(f"  boliglån    {m['boliglaan_principal_dkk']:,} kr  "
              f"-> {m['boliglaan_monthly_dkk']:,} kr/md "
              f"@ {m['boliglaan_rate_pct']}% / {m['boliglaan_term_years']}yr{assumed}")
    print(f"  total       {m['monthly_incl_bidrag_dkk']:,} kr/md")
    print(f"  net after rentefradrag  {m['net_monthly_dkk']:,} kr/md "
          f"(effective {m['effective_deduction_pct']}%)")

    t = d["property_tax"]
    if t.get("applies") is False:
        print(f"\nProperty tax  n/a — {t['note']}")
    elif t.get("total_annual_dkk"):
        print(f"\nProperty tax (buyer basis)  {t['total_annual_dkk']:,} kr/yr "
              f"= {t['total_monthly_dkk']:,} kr/md")
        if t.get("delta_vs_listed_dkk") is not None:
            print(f"  {t['delta_note']}")
    if t.get("implied_from_listing"):
        print("  back-calculated from the listing:")
        for k, v in t["implied_from_listing"].items():
            print(f"    {k}: {v}")
    if t.get("warning"):
        print(f"  ! {t['warning']}")

    b = d["buyer_transaction_costs"]
    print(f"\nBuyer's own costs   {b['range_dkk'][0]:,}-{b['range_dkk'][1]:,} kr "
          "(excluded from salgsopstilling)")

    mo = d["monthly"]
    print(f"\nMonthly gross   {mo['gross_total_dkk']:,} kr")
    if mo.get("property_tax_uplift_dkk"):
        print(f"  (incl. {mo['property_tax_uplift_dkk']:,} kr property-tax uplift the "
              f"buyer inherits on top of the listed ejerudgift)")
    print(f"  net           {mo['net_total_after_deduction_dkk']:,} kr")
    print(f"  + sinking     {mo['all_in_with_sinking_dkk']:,} kr all-in")

    print("\nStress test")
    for k, v in d["stress_test"].items():
        print(f"  {k:5} -> {v['monthly_dkk']:,} kr/md  ({v['delta_dkk']:+,})")

    print("\nBreak-even resale")
    for k, v in d["break_even_resale"]["detail"].items():
        print(f"  {k:8} {v['break_even_low_dkk']:,} - {v['break_even_high_dkk']:,} kr "
              f"({v['vs_purchase_price_pct']:+.1f}% vs purchase)")

    if d.get("total_cost_of_ownership"):
        print("\nTotal cost of ownership")
        for k, v in d["total_cost_of_ownership"].items():
            print(f"  {k:8} {v['total_dkk']:,} kr  "
                  f"(avg {v['monthly_average_dkk']:,}/md, "
                  f"equity {v['equity_from_principal_dkk']:,})")

    if d["unknown"]:
        print("\nUnknown (not guessed):")
        for u in d["unknown"]:
            print(f"  - {u}")
    print(f"\n{d['disclaimer']}")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--price", type=float, required=True)
    p.add_argument("--down", type=float, default=0.0)
    p.add_argument("--rate", type=float, default=4.0,
                   help="realkredit rate, %% (default 4.0)")
    p.add_argument("--term", type=int, default=30)
    p.add_argument("--boliglaan-rate", type=float,
                   help=f"bank rate on the slice above the {REALKREDIT_MAX_LTV*100:.0f}%% "
                        f"realkredit cap (default {BOLIGLAAN_DEFAULT_RATE}%% if omitted)")
    p.add_argument("--boliglaan-term", type=int,
                   help=f"years on the boliglån (default {BOLIGLAAN_DEFAULT_TERM})")
    p.add_argument("--tenure", choices=("ejer", "andel"), default="ejer",
                   help="ejer = ejerbolig/ejerlejlighed (default); andel = andelsbolig, "
                        "where realkredit is unavailable and property tax is not levied "
                        "on the buyer")
    p.add_argument("--ejerudgift", type=float, help="kr per month")
    p.add_argument("--consumption-monthly", type=float, help="heat + electricity, kr/md")
    p.add_argument("--tax-base-value", type=float, help="Grundlag for ejd. værdiskat")
    p.add_argument("--tax-base-land", type=float, help="Grundlag for grundskyld")
    p.add_argument("--kommune-permille", type=float,
                   help="municipal grundskyld permille. Post-2024 reform this is roughly "
                        "5-10 promille, NOT the old 20-34. Look up the kommune, then "
                        "sanity-check by dividing the listed grundskyld by its basis.")
    p.add_argument("--listed-tax-annual", type=float,
                   help="tax total printed in the salgsopstilling, to compare against")
    p.add_argument("--listed-evs", type=float,
                   help="Ejendomsværdiskat as printed, for the back-calculation check")
    p.add_argument("--listed-grundskyld", type=float,
                   help="Grundskyld as printed, for the back-calculation check")
    p.add_argument("--remediation", type=float, help="deferred maintenance reserve, kr")
    p.add_argument("--building-value", type=float, help="for the sinking fund")
    p.add_argument("--m2", type=float)
    p.add_argument("--couple", action="store_true", help="doubles the rentefradrag threshold")
    p.add_argument("--json", action="store_true")
    a = p.parse_args()

    result = build(a)
    if a.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        emit_text(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
