# Recyclarr Quebec config templates

The `Remux` and `Encode` Radarr/Sonarr profile balances release quality with mandatory original audio. Its main priority is to keep the movie's original language, then prefer releases that also include French audio, with Quebec French variants ranked above everything else. Outside audio-related scoring, this profile stays close to the usual TRaSH Guides scoring model.

### Score Bands

Scores are kept as low as practical so the profile remains easy to reason about. Bands are separated so the lowest score in a higher-priority band still beats the maximum combined score of all lower-priority bands. For example, `Movie Versions` will beat the full combined score of `Streaming Services` + `Miscellaneous` tie-breakers.

| Score | Maximum Score | Purpose |
| :---: | :-----------: | ------- |
| `450-500` | `950` | Language Profiles |
| `200-225` | `225` | Release Groups |
| `25-100` | `175` | Movie Versions |
| `0-20` | `20` | Streaming Services |
| `1-3` | `3` | Miscellaneous (excl. MPEG2) |

### Intended Ordering

| Audio Languages | Minimum Score | Maximum Score |
| -------- | :---------: | :-----------: |
| Original + VFQ | `950` | `1373` |
| Original + French | `500` | `923` |
| Original only | `0` | `423` |

`Maximum Score` would include :

- Remux Tier 01 (+225)
- Special Edition (+100)
- Hybrid (+50)
- Edition Quality (+25)
- Platform Tier 01 (+20)
- Repack3 (+3).

## Notes

- Radarr only: MPEG2 receives a small bonus (+5) to prefer DVD remuxes over lower-quality DVD encodes when no better source exists.
- IMAX releases are rejected to preserve the movie's original framing and the director's intended presentation.
