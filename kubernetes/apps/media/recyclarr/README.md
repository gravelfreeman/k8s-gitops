# Recyclarr Quebec config templates

The `Remux` and `Encode` Radarr/Sonarr profile balances release quality with mandatory original audio. Its main priority is to keep the movie's original language, then prefer releases that also include French audio, with Quebec French variants ranked above everything else. Outside audio-related scoring, this profile stays close to the usual TRaSH Guides scoring model.

### Score Bands

Scores are kept as low as practical so the profile remains easy to reason about. Language scoring is isolated from the smaller quality tie-breakers, so releases with French audio stay above original-only releases. In the Radarr `Remux` profile, a local remux source bonus keeps unknown remuxes above tiered non-remux encodes.

| Score Range | Maximum Score | Purpose |
| :---: | :-----------: | ------- |
| `450-850` | `1700` | Language Profiles |
| `410` | `410` | Remux Source |
| `200-225` | `225` | Release Groups |
| `25-100` | `175` | Movie Versions |
| `0-20` | `20` | Streaming Services |
| `1-3` | `3` | Miscellaneous (excl. MPEG2) |

### Intended Ordering

| Audio Languages | Minimum Score | Maximum Score |
| -------- | :---------: | :-----------: |
| Original + VFQ | `1700` | `2533` |
| Original + French | `850` | `1683` |
| Original only | `0` | `833` |

`Maximum Score` would include the best theoretical Radarr remux path:

- Quality: Remux (+410)
- Remux Tier 01 (+225)
- Special Edition (+100)
- Hybrid (+50)
- Edition Quality (+25)
- Streaming Service (+20)
- MPEG2 (+5)
- Repack3 (+3).

## Notes

- IMAX releases are rejected to preserve the movie's original framing and the director's intended presentation.
- `Movie Versions` is only used by Radarr because it applies to movie-specific editions.
- MPEG2 receives a small bonus (+5) to prefer DVD remuxes over lower-quality DVD encodes (radarr only).
- The `Remux` profile is not intended for Sonarr because full-series remux libraries require significantly more storage.
