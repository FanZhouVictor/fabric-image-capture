# Vocabulary for `acquire_case.sh` CLI flags

`acquire_case.sh` takes four flags that identify *what* you are capturing. The script validates them against the controlled vocabulary below and will refuse to run on any invalid combination. Pick a value from each table.

`acquire_batch.sh` (multi-piece batch papers) uses the same `--treatment` and `--stage` vocabulary inside its `--sample <pieceID>:<treatment>:<stage>` tuples; the coupon axis does not apply to batch pieces. See [`docs/acquisition_workflow.md`](acquisition_workflow.md) § 2-B.

If you are unsure which combination applies, ask Fan before firing the capture — the four flags get baked into the filename and the folder structure and are very awkward to rename after the fact.

---

## `--test`

| Allowed | Meaning |
|---|---|
| `C###` (e.g. `C187`, `C188`) | The combustion-test ID provided by Fan. Always three digits and always prefixed with a capital `C`. Required for every capture. |

---

## `--coupon`

| Allowed | Meaning |
|---|---|
| `parent` | The whole, uncut fabric specimen (front face up). Use for pre-exposure and post-exposure parent captures. |
| `left` | The leftmost strip cut from the parent along its length axis. Use only at stage `post_treatment`. |
| `center` | The middle strip cut from the parent along its length axis. Use only at stage `post_treatment`. |
| `right` | The rightmost strip cut from the parent along its length axis. Use only at stage `post_treatment`. |
| `left_center` | A single combined strip spanning the left and center positions, left joined instead of cut apart. Use only at stage `post_treatment`. |
| `center_right` | A single combined strip spanning the center and right positions, left joined instead of cut apart. Use only at stage `post_treatment`. |
| `left_center_right` | A single combined strip spanning all three positions (the length cuts were skipped entirely). Use only at stage `post_treatment`. |

Left / center / right are defined when the parent is viewed with its `C###-top` label at the top.

Combined positions exist for when a length cut is intentionally skipped, so two or three adjacent positions are treated and imaged as one piece. Only **contiguous** runs are valid — there is no `left_right`, because a non-adjacent join is physically impossible. A combined strip is staged and captured exactly like a single-position strip.

---

## `--treatment`

| Allowed | Meaning |
|---|---|
| `none` | No treatment applied. Allowed only when `--stage pre_exposure`. |
| `as_exposed` | Specimen has been smoke-exposed but has had no further treatment between the exposure and this capture. |
| `env_aging_<N>d` | Specimen has been environmentally aged for `N` whole days (e.g., `env_aging_3d`, `env_aging_7d`, `env_aging_14d`). The `<N>` is required and must be a positive integer. |
| `PER` | Specimen has been through the PER procedure (water-gun rinse, gentle brush, accelerated drying). |
| `advanced_cleaning` | Specimen has been through the advanced cleaning procedure. |

---

## `--stage`

| Allowed | Meaning |
|---|---|
| `pre_exposure` | Parent specimen straight out of the conditioning chamber, before any smoke exposure. Requires `--coupon parent --treatment none`. |
| `post_exposure` | Parent specimen immediately after the smoke chamber, still uncut. Requires `--coupon parent --treatment as_exposed`. |
| `post_exposure_aged` | Parent specimen after a whole-parent aging step, still uncut. Requires `--coupon parent` and `--treatment env_aging_<N>d`. |
| `post_treatment` | One coupon strip after its most recent treatment, before width-cutting. Requires `--coupon` ∈ {`left`, `center`, `right`, `left_center`, `center_right`, `left_center_right`} and `--treatment` ≠ `none`. |

---

## Which combination to use when

The script enforces the cross-axis rules above. The four combinations you will see most often, in chronological order for a typical specimen:

1. **Parent, before smoke exposure** — taken right after the conditioning chamber, before anything else.
2. **Parent, immediately after smoke exposure** — taken straight out of the smoke chamber, before any cuts.
3. **Parent, after whole-parent aging** — only if the test plan ages the *uncut* parent. Skip if aging is done at the strip level instead.
4. **Coupon strip, after its strip-level treatment** — taken for each of the three strips (left, center, right) after its assigned treatment is finished. **Skip entirely if the strip received no strip-level treatment** — Fan will tell you when this applies.

## Worked examples

```bash
# 1. Parent, before exposure (stage A)
./scripts/camera/acquire_case.sh \
    --test C187 --coupon parent --treatment none --stage pre_exposure

# 2. Parent, immediately after smoke exposure (stage B)
./scripts/camera/acquire_case.sh \
    --test C187 --coupon parent --treatment as_exposed --stage post_exposure

# 3. Parent, after a 7-day whole-parent aging (stage Bᴬ)
./scripts/camera/acquire_case.sh \
    --test C188 --coupon parent --treatment env_aging_7d --stage post_exposure_aged

# 4. Left strip, after a 3-day strip-level aging (stage D)
./scripts/camera/acquire_case.sh \
    --test C188 --coupon left --treatment env_aging_3d --stage post_treatment

# 5. Center strip, after PER (stage D)
./scripts/camera/acquire_case.sh \
    --test C188 --coupon center --treatment PER --stage post_treatment

# 6. Right strip, after advanced cleaning (stage D)
./scripts/camera/acquire_case.sh \
    --test C188 --coupon right --treatment advanced_cleaning --stage post_treatment

# 7. Left strip, untreated baseline (smoke-exposed strip, no further treatment)
./scripts/camera/acquire_case.sh \
    --test C189 --coupon left --treatment as_exposed --stage post_treatment

# 8. Combined left+center strip (length cut skipped), after 3-day aging (stage D)
./scripts/camera/acquire_case.sh \
    --test C194 --coupon left_center --treatment env_aging_3d --stage post_treatment
```

## What the script will reject

The script will exit immediately with an error if any of these holds:

- `--stage pre_exposure` paired with anything other than `--treatment none`.
- `--stage post_exposure` paired with anything other than `--treatment as_exposed`.
- `--stage post_exposure_aged` without `--coupon parent` *and* `--treatment env_aging_<N>d`.
- `--stage post_treatment` with `--coupon parent`.
- `--stage post_treatment` with `--treatment none`.
- Any `--coupon` other than `parent` outside of `--stage post_treatment`.
- `--test` not matching the regex `^C[0-9]+$`.

If the script refuses to run, re-read the four flags out loud, check the rules above, and try again. If you cannot figure out which flag is wrong, message Fan with the exact command you typed.
