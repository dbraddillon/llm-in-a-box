# What's fair game to point a pack at

Not legal advice — a practical checklist to run through before adding a `source` to a
`pack.yaml`. Same posture Prepper already uses (public-domain government docs +
CC-licensed Kiwix ZIMs + your own bundled/manual files); this is that philosophy
written down since `llm-in-a-box` makes it easier to point at arbitrary URLs.

## Generally fine

- **Public domain.** Pre-1929 published works, anything explicitly PD-dedicated
  (CC0), and — importantly for reference/survival content — **US federal government
  works are public domain by default** (FEMA, CDC, NOAA, NWS, NPS, military field
  manuals). This is why Prepper's `tier1` PDFs lean on government sources.
- **Creative Commons, license permitting.** CC-BY / CC-BY-SA are fine with
  attribution (keep the `source` filename/URL in the chunk metadata — the pipeline
  already tags every chunk with its source file, which doubles as attribution).
  CC-BY-NC is murkier for anything beyond strictly personal use; CC-BY-ND means don't
  re-chunk/re-derive it. Check the specific license, don't assume from the name.
- **Wikipedia / Wikibooks / Wikiversity / WikiHow / iFixit** — all CC-BY-SA (WikiHow:
  CC-BY-NC-SA), which is why Prepper already ships them as Kiwix ZIMs. Extracting
  text from one of those ZIMs for a pack carries the same license as browsing it.
- **Content you personally own or wrote.** Your own manuals, notes, purchased ebooks
  you're keeping an offline copy of for yourself, work docs you have rights to. Personal
  offline backup for your own use is a different question than redistributing a box
  built from it to other people — mind that distinction if a box leaves your hands.
- **Open datasets with an explicit reuse license** (government open-data portals,
  OpenStreetMap, etc.).

## Not fair game

- Scraping copyrighted commercial content (news sites, textbooks, paywalled material)
  without an explicit license grant, even if it's technically downloadable.
  "reachable" is not "licensed."
- Anything whose Terms of Service explicitly forbids bulk download / scraping —
  check before pointing a `http` source at a site, not after.
- Redistributing licensed material (e.g. a purchased field guide) to anyone beyond
  yourself, unless its license says you can.

## Practical checklist before adding a source

1. Where did this come from, and what's its actual license (not just "it's on the
   internet")?
2. Is this pack for your own personal offline use, or will the assembled box leave
   your hands? The second case needs a stricter license than the first.
3. If it's `type: http`, does the site's ToS say anything about bulk/automated
   download?
4. If it's `type: local` pointing at Prepper's `content/`, remember Prepper already
   made this call per-item — check `Prepper/docs/02-content-sources.md` for the
   source type of whatever you're pointing at.
