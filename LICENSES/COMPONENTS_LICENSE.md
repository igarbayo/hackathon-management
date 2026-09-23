# Component licenses and the choice of license for HackBoard

This document explains **which license HackBoard uses and why**. The choice is based on
an inventory of every component in this repository, not on general preference. That
inventory covers npm packages, Ruby gems, container images, backing services, fonts,
icons, code copied from other projects, and external APIs.

> **Decision:** HackBoard is licensed under the **GNU Affero General Public License,
> version 3 or (at your option) any later version** (SPDX: `AGPL-3.0-or-later`).
> The full text is in [`LICENSE`](../LICENSE) and in
> [`AGPL-3.0-or-later.txt`](AGPL-3.0-or-later.txt).
>
> HackBoard is provided **without any warranty**, as stated in sections 15 and 16 of the
> license.

- **Copyright holder:** Ignacio Garbayo ([@igarbayo](https://github.com/igarbayo)).
  He is the only author in the git history at the time of this decision (45 of 45 commits).
- **Inventory date:** 2026-09-23. The data comes from `package-lock.json`,
  `apps/api/Gemfile.lock`, `docker-compose*.yml` and the Dockerfiles. Section 8
  explains how to regenerate it.

---

## 1. Summary

| Question | Answer |
|---|---|
| Can HackBoard legally use its dependencies under AGPL-3.0? | **Yes.** Every dependency that ends up in the application uses a permissive license (MIT, ISC, BSD, Apache-2.0, and similar) or a weak copyleft license that is compatible with AGPL-3.0 (LGPL-3.0, MPL-2.0). |
| Would a permissive license (MIT or Apache-2.0) also have been legally possible? | **Yes.** No dependency forces copyleft. The choice of AGPL is deliberate: the dependencies did not require it. |
| Is there any dependency that would rule out a license? | Several Apache-2.0 dependencies rule out **GPL-2.0-only**, which is why the choice is "version 3 or later". Nothing rules out MIT, Apache-2.0, BSD, GPL-3.0 or AGPL-3.0. |
| Are there any non-OSI components? | Yes, but none are part of HackBoard's code. They are **backing services** (MongoDB 7 under SSPL-1.0, Redis 7.4 under RSALv2/SSPLv1) and one **development tool** (Brakeman). None of them is linked into HackBoard or distributed with it; see section 5. |
| What does AGPL require of the people who deploy HackBoard? | If you run a **modified** HackBoard as a network service, you must offer your users the source code of your version (AGPL §13). See section 6 for examples. |

---

## 2. Why AGPL-3.0-or-later

### 2.1 What HackBoard is

HackBoard is not a library. It is a **web application run as a service**:

- a Next.js front end (`apps/web`);
- a Rails API (`apps/api`) with Sidekiq workers;
- a CLI (`packages/cli`) that sends Claude Code activity to that API.

People use HackBoard through a browser or through its MCP and REST endpoints. They do
not download a copy of the software. The license has to fit that model.

### 2.2 The problem with permissive licenses and plain GPL for a service

Suppose a company takes HackBoard, adds a paid "analytics" tab, and hosts it at
`hackathons.example.com` for thousands of teams. Here is what each license allows:

| License | Must the company share its changes? |
|---|---|
| MIT / BSD / Apache-2.0 | **No.** Permissive licenses never require it. |
| GPL-3.0 | **No.** The GPL is triggered by *distributing* copies. Running the software on your own server is not distribution; this gap is called the "SaaS loophole". |
| **AGPL-3.0** | **Yes.** Section 13 treats "users interacting with it remotely through a computer network" like recipients of a copy. They must be offered the modified source. |

The project describes itself as *"the open-source hackathon management platform"*.
AGPL is the only license in the table that keeps hosted derivatives open. That makes
it the license that matches this goal.

### 2.3 The stack already follows the same model

Several key components of HackBoard's own stack chose copyleft, or moved towards it, for
the same reason:

- **Sidekiq** (the job system in `apps/api`) is LGPL-3.0. Its paid features are in a
  separate commercial edition.
- **MongoDB** moved from AGPL-3.0 to SSPL-1.0 so that cloud providers could not resell it
  closed.
- **Redis** moved to RSALv2/SSPLv1 in 7.4, and added AGPL-3.0 as an option in Redis 8.

HackBoard adopts the OSI-approved version of that model, AGPL-3.0, rather than the
non-OSI licenses (SSPL, RSAL).

### 2.4 Why "or later" and not "only"

- The FSF recommends the "or later" wording. It lets HackBoard combine with code under
  a future AGPL version without asking every contributor to relicense.
- It keeps compatibility with the **Apache-2.0** dependencies, which are only compatible
  with version 3 of the GPL family.
- The trade-off is that future license versions are published by the FSF. That is accepted.

### 2.5 The costs we accept

- **Less adoption by companies.** Some organisations ban AGPL code internally. HackBoard's
  users are hackathon teams and organisers, not companies embedding HackBoard in closed
  products, so this cost is small.
- **An obligation on anyone who hosts a modified version.** They must link to their source
  code (section 6). HackBoard's own deployment must do the same (section 7, item 1).
- **Relicensing gets harder over time.** While Ignacio Garbayo is the only copyright holder,
  he can relicense, for example publishing `packages/shared-schemas` under MIT. After
  outside contributions arrive without a CLA, that needs every contributor's consent.

### 2.6 The alternatives we rejected

| Alternative | Why it was not chosen |
|---|---|
| **MIT** | Allows closed hosted forks (section 2.2). It also has no patent clause. |
| **Apache-2.0** | Adds a useful patent grant, but still allows closed hosted forks. It would be the choice if broad corporate adoption became the priority. |
| **BSD-3-Clause** | Same issue as MIT. The "no endorsement" clause adds little for this project. |
| **GPL-3.0** | Protects distributed copies, but not a hosted service. HackBoard is almost always used hosted. |
| **Dual licensing (AGPL plus commercial)** | There is no commercial model today, so it is left for the future. It would require a CLA. |

---

## 3. npm dependencies (`apps/web`, `packages/cli`, `packages/shared-schemas`)

Source: `package-lock.json` (lockfile v3). It has 814 entries, including workspace
entries and nested duplicates.

### 3.1 Direct runtime dependencies (`apps/web`)

These packages end up in the web application that users load.

| Package | Version | License | Compatible with AGPL-3.0? |
|---|---|---|---|
| `next` | 16.3.5 | MIT | Yes |
| `react` / `react-dom` | 19.2.8 | MIT | Yes |
| `@base-ui/react` | 1.8.0 | MIT | Yes |
| `@dnd-kit/core` | 6.3.1 | MIT | Yes |
| `@dnd-kit/sortable` | 10.0.0 | MIT | Yes |
| `@dnd-kit/utilities` | 3.2.2 | MIT | Yes |
| `@tanstack/react-query` | 5.103.2 | MIT | Yes |
| `chrono-node` | 2.10.1 | MIT | Yes |
| `class-variance-authority` | 0.7.1 | Apache-2.0 | Yes (GPLv3 family only) |
| `clsx` | 2.1.1 | MIT | Yes |
| `cn` | 0.4.0 | MIT | Yes |
| `date-fns` | 4.4.0 | MIT | Yes |
| `lucide-react` | 1.47.0 | ISC | Yes |
| `next-themes` | 0.4.6 | MIT | Yes |
| `react-day-picker` | 10.0.1 | MIT | Yes |
| `shadcn` | 4.21.0 | MIT | Yes |
| `sonner` | 2.0.8 | MIT | Yes |
| `tailwind-merge` | 3.7.0 | MIT | Yes |
| `tw-animate-css` | 1.4.0 | MIT | Yes |

`packages/cli` has one runtime dependency, `@hackboard/shared-schemas`, which is part of
this repository. `packages/shared-schemas` has no runtime dependencies.

### 3.2 Direct development dependencies

These are only used to build, lint or test. They are not shipped to users.

| Package | Used in | License |
|---|---|---|
| `@playwright/test` 1.63.0 | web | Apache-2.0 |
| `@tailwindcss/postcss` 4.3.3, `tailwindcss` 4.3.3 | web | MIT |
| `@testing-library/jest-dom` 7.0.1, `@testing-library/react` 16.3.3, `@testing-library/user-event` 14.6.7 | web | MIT |
| `@types/node` 20.19.43, `@types/react` 19.3.0, `@types/react-dom` 19.3.0 | web, cli | MIT |
| `@vitejs/plugin-react` 6.1.1 | web | MIT |
| `eslint` 9.39.5, `eslint-config-next` 16.3.5 | web | MIT |
| `jsdom` 29.1.1 | web | MIT |
| `typescript` 5.9.3 | web, cli, shared-schemas | Apache-2.0 |
| `vitest` 5.0.1 | web, cli, shared-schemas | MIT |
| `ajv` 8.20.0, `ajv-formats` 3.0.1 | shared-schemas | MIT |

### 3.3 All transitive packages, by license

| License | Runtime | Dev | Optional | Compatible with AGPL-3.0? |
|---|---:|---:|---:|---|
| MIT | 316 | 333 | 10 | Yes |
| ISC | 22 | 9 | 1 | Yes |
| Apache-2.0 | 10 | 20 | 13 | Yes (GPLv3 family only) |
| BSD-3-Clause | 7 | 2 | 0 | Yes |
| BSD-2-Clause | 5 | 9 | 0 | Yes |
| 0BSD | 1 | 0 | 0 | Yes |
| MIT-0 | 0 | 2 | 0 | Yes |
| BlueOak-1.0.0 | 2 | 2 | 0 | Yes (permissive, OSI-approved) |
| CC0-1.0 | 0 | 2 | 0 | Yes (public domain dedication) |
| Python-2.0 | 1 | 0 | 0 | Yes (the FSF lists it as GPL-compatible) |
| CC-BY-4.0 | 1 | 0 | 0 | Yes (data, see below) |
| MPL-2.0 | 0 | 25 | 0 | Yes (dev only; see below) |
| LGPL-3.0-or-later (alone or combined with Apache-2.0/MIT) | 0 | 0 | 14 | Yes (see below) |

*Runtime* means that the package is installed by `npm install --omit=dev`. *Optional*
means a platform-specific binary that npm installs only for the matching operating
system and CPU.

The workspace entries `apps/web` and `packages/shared-schemas` had no `license` field,
and `packages/cli` said `UNLICENSED`. **This change sets all of them to
`AGPL-3.0-or-later`.**

#### The licenses that need a closer look

- **`@img/sharp-libvips-*` (LGPL-3.0-or-later), 14 optional packages.** These are
  platform-specific builds of libvips. `sharp` (Apache-2.0) uses them for Next.js image
  optimisation.
  - They are loaded as separate shared libraries, and each package ships its own license
    and source reference. That satisfies the LGPL's "user can replace the library" condition.
  - LGPL-3.0 is compatible with AGPL-3.0.
  - Example: a Linux x64 server installs only `@img/sharp-libvips-linux-x64`. That package
    keeps its LGPL license, and HackBoard's own code stays under AGPL.
- **`lightningcss` and its 12 platform packages, and `axe-core` (MPL-2.0), dev only.**
  - `lightningcss` is used by Tailwind at build time.
  - `axe-core` is used in accessibility tests.
  - MPL-2.0 is a file-level copyleft: changes to MPL files must stay MPL, but they can be
    combined with code under other licenses. Neither package is copied into HackBoard's source.
- **`caniuse-lite` (CC-BY-4.0).** This is browser-support data used by `browserslist` at
  build time. The FSF considers CC-BY-4.0 compatible with GPLv3.
  - It requires attribution if redistributed.
  - The package carries its own notice in `node_modules/caniuse-lite/LICENSE`, and HackBoard
    does not modify it.
- **`argparse` (Python-2.0).** It is a dependency of `js-yaml` inside the `shadcn` CLI.
  It is a permissive license, and the FSF lists it as GPL-compatible.
- **`isexe` and `minimatch` (BlueOak-1.0.0).** This is a modern permissive license,
  approved by the OSI, with an explicit patent grant.

---

## 4. Ruby gems (`apps/api`)

Source: `apps/api/Gemfile.lock` (134 lines; nokogiri and thruster appear once per
platform). The licenses were looked up on the RubyGems API for the exact version in the
lockfile.

| License | Gems | Compatible with AGPL-3.0? |
|---|---|---|
| **MIT** | `action_text-trix`, `actioncable`, `actionmailbox`, `actionmailer`, `actionpack`, `actiontext`, `actionview`, `activejob`, `activemodel`, `activerecord`, `activestorage`, `activesupport`, `ast`, `bcrypt`, `builder`, `concurrent-ruby`, `connection_pool`, `crack`, `crass`, `dotenv`, `dotenv-rails`, `erubi`, `et-orbi`, `factory_bot`, `factory_bot_rails`, `faraday`, `faraday-net_http`, `faraday-retry`, `fugit`, `globalid`, `hana`, `hashdiff`, `i18n`, `json_schemer`, `jwt`, `language_server-protocol`, `lint_roller`, `loofah`, `mail`, `mini_mime`, `minitest`, `mongoid`, `nokogiri`, `parallel`, `parser`, `prism`, `public_suffix`, `raabro`, `rack`, `rack-cors`, `rack-session`, `rack-test`, `rackup`, `rails`, `rails-dom-testing`, `rails-html-sanitizer`, `railties`, `rainbow`, `rake`, `redis-client`, `regexp_parser`, `rspec-core`, `rspec-expectations`, `rspec-mocks`, `rspec-rails`, `rspec-support`, `rubocop`, `rubocop-ast`, `rubocop-performance`, `rubocop-rails`, `rubocop-rails-omakase`, `ruby-progressbar`, `sidekiq-cron`, `simpleidn`, `thor`, `thruster`, `tzinfo`, `unicode-display_width`, `unicode-emoji`, `useragent`, `webmock`, `zeitwerk` | Yes |
| **Apache-2.0** | `addressable`, `bson`, `cronex`, `mongo` (the MongoDB driver), `websocket-driver`, `websocket-extensions` | Yes (GPLv3 family only) |
| **BSD-3-Clause** | `puma` | Yes |
| **BSD-2-Clause** | `rexml` | Yes |
| **Ruby OR BSD-2-Clause** | `base64`, `bigdecimal`, `date`, `debug`, `drb`, `erb`, `io-console`, `irb`, `logger`, `net-http`, `net-imap`, `net-pop`, `net-protocol`, `ostruct`, `pp`, `prettyprint`, `racc`, `rbs`, `securerandom`, `timeout`, `tsort`, `uri` | Yes (the BSD-2-Clause option is used) |
| **Ruby** | `json` 2.7.2, `reline`, `unicode` | Yes. The Ruby license lets the recipient choose the BSD-2-Clause terms instead. |
| **Ruby OR GPL-2.0-only** | `rdoc` | Yes (the Ruby option is used; GPL-2.0-only alone would not be compatible) |
| **MIT OR Apache-2.0** | `marcel` | Yes |
| **MIT OR BSD-2-Clause** | `nio4r` | Yes |
| **MIT OR Artistic-1.0-Perl OR GPL-2.0-or-later** | `diff-lcs` (test only) | Yes (the MIT option is used) |
| **LGPL-3.0** | `sidekiq` 7.3.9 | **Yes.** See below. |
| **GPL-3.0-or-later** | `bundler-audit` (development only) | Yes, and it is never loaded by the running application |
| **Brakeman Public Use License** (not OSI) | `brakeman` (development only) | Not relevant; see section 5 |

### Notes

- **Sidekiq (LGPL-3.0).** HackBoard uses Sidekiq as a library: it defines jobs and calls
  its API, without changing Sidekiq's code. The LGPL permits that under any license.
  - If HackBoard ever *modified* Sidekiq's files, those changes would have to stay LGPL.
  - Sidekiq Pro and Enterprise are commercial products and are **not** used.
- **Nokogiri native gems.** The platform-specific builds include libxml2 and libxslt
  (MIT), zlib (Zlib) and, on some platforms, libiconv (LGPL-2.1-or-later). All of them are
  compatible with AGPL-3.0. Nokogiri documents them in its `LICENSE-DEPENDENCIES.md`.
- **Thruster.** It ships a precompiled Go binary under MIT.
- **`rdoc` and `diff-lcs`** offer GPL-2.0 as one option. Because they are dual- or
  triple-licensed, HackBoard uses the Ruby or MIT option and never needs GPL-2.0 terms.
- **`tzinfo-data`** is in the Gemfile only for Windows and JRuby, so it is not in the
  Linux lockfile.

---

## 5. Services, images and tools that are *not* part of HackBoard's code

These components run as separate programs. HackBoard talks to them over a network
socket or runs them as a command-line tool. It does not link them into its code or
distribute them. **Because of that, their licenses do not affect HackBoard's license.**
They still matter to the people who operate HackBoard.

| Component | Where it appears | License | OSI-approved? | Effect on HackBoard |
|---|---|---|---|---|
| **MongoDB 7** (`mongo:7`, 7.0.37 locally) | `docker-compose.yml` (development) | SSPL-1.0 | No | None on the code. SSPL only affects someone who offers *MongoDB itself* as a service. Self-hosting HackBoard on MongoDB is fine. Production uses an external MongoDB (`MONGODB_URI`). |
| **Redis 7** (`redis:7`, which resolves to 7.4.11) | `docker-compose.yml` (development) | RSALv2 or SSPLv1 (since 7.4) | No | None on the code. For a fully OSI-approved stack, use **Valkey** (BSD-3-Clause) or Redis 8 under AGPL-3.0. Both are drop-in replacements for Sidekiq. |
| Ruby 3.3 (`ruby:3.3`, `ruby:3.3-slim`) | `apps/api/Dockerfile*` | Ruby or BSD-2-Clause, on a Debian base | Yes | None |
| Node.js 20 (`node:20`) | `apps/web/Dockerfile` | MIT, on a Debian base | Yes | None |
| **Brakeman** | `apps/api` development group, CI | Brakeman Public Use License | No | None. It is a static analyser run in CI and not shipped. Its license allows free use for scanning your own code; it restricts offering Brakeman as a commercial service. |
| **bundler-audit** | `apps/api` development group, CI | GPL-3.0-or-later | Yes | None; it is a tool that is not linked into the application |
| GitHub Actions (`actions/checkout`, `actions/setup-node`) | `.github/workflows/` | MIT | Yes | None |

**Example.** Someone deploys HackBoard with `redis:7` from `docker-compose.yml` for their
university hackathon. HackBoard remains AGPL-licensed. Redis remains RSAL/SSPL-licensed.
That person is not reselling Redis as a hosted database, so neither license limits what
they are doing.

---

## 6. Code, assets and data copied into the repository

These components are *inside* HackBoard's source tree. They keep their original license,
and their notices must be kept.

| Component | Where | Origin and license | Status |
|---|---|---|---|
| **`DatePicker`** | `apps/web/src/components/ui/date-picker.tsx` | Adapted from [a-good-date-picker](https://github.com/gulipad/a-good-date-picker), MIT, Copyright (c) 2025 Guli Moreno | The header credits the author and license. The MIT license also requires its permission notice; **action 2**. |
| **shadcn/ui primitives** | `apps/web/src/components/ui/*.tsx` | Generated by the `shadcn` CLI from [shadcn/ui](https://github.com/shadcn-ui/ui), MIT, Copyright (c) 2023 shadcn | The notice is not in the files; **action 2**. |
| **F0 design tokens** | `apps/web/src/app/globals.css` | Copied from `@factorialco/f0-core@2.7.0`, which says `"license": "MIT"`, author Factorial | The comment cites the source but not the license. The upstream repository and npm package contain no `LICENSE` file, only the `license` field. Colour and size values are unlikely to be protected by copyright, but the MIT attribution is kept to be safe; **action 2**. |
| **Inter** and **Geist Mono** fonts | `apps/web/src/app/layout.tsx` (`next/font/google`) | SIL Open Font License 1.1 | Downloaded at build time and served by the app. OFL-1.1 allows bundling the fonts with software under any license. It only forbids selling the fonts on their own and reusing their reserved names for modified fonts. |
| **Lucide icons** | `lucide-react` | ISC | Covered in section 3.1 |
| **HackBoard logos** | `apps/web/public/*.svg`, `apps/web/public/icons/*.png` | Original work, Copyright (c) Ignacio Garbayo | Covered by AGPL for copyright purposes. **AGPL grants no trademark rights** (§7e). The name "HackBoard" and the logos may not be used to suggest endorsement of a fork. |

---

## 7. External services called at runtime

HackBoard calls these services over HTTP. They do not affect HackBoard's license. Each
deployer and user must accept their terms separately.

| Service | Used for | Terms |
|---|---|---|
| **Google Gemini API** | AI coverage analysis and attribution suggestions (`Ai::Provider`) | Google's Gemini API terms. Each person uses **their own key** ([ADR-0014](../specs/decisiones.md#adr-0014)), so each person accepts the terms directly. |
| **GitHub API and GitHub App** | Activity feed, login | GitHub Terms of Service |
| **Google Identity (OpenID Connect)** | Login | Google APIs Terms of Service |
| **Claude Code** | The CLI installs hooks and optionally registers the MCP server with `claude mcp add` | Claude Code is proprietary software from Anthropic. HackBoard's CLI only reads the JSON that Claude Code sends to the hook on stdin and runs the `claude` command. It does not include or link any Claude Code code, so there is no license interaction. |

---

## 8. What this means in practice

### 8.1 For people who use or self-host HackBoard

- **Using an unmodified HackBoard for your own hackathon:** no obligation beyond keeping
  the license notices.
- **Modifying HackBoard and hosting it for others:** you must give those users a way to
  download *your* modified source under AGPL-3.0-or-later. A "Source code" link in the
  interface to your public fork is enough.
- **Writing a separate tool that calls HackBoard's REST API or MCP server:** your tool is
  not a derivative work, and you can license it however you like.
  - Example: a Slack bot that calls `GET /api/v1/teams/:id/features` with a personal
    access token can be MIT or proprietary.

### 8.2 Actions for this repository

1. **Add a "Source code" link to the web interface** that points to this repository, for
   example in the sidebar footer and in `/llms.txt`. HackBoard's own deployment should show
   the example it asks of others. This needs a UI requirement in `specs/04-pantallas.md`,
   so it is left as a follow-up rather than done in this change.
2. **Keep third-party notices in copied code.** Add these to the top of the files listed in
   section 6:
   - `date-picker.tsx`: `SPDX-FileCopyrightText: 2025 Guli Moreno`, plus the MIT permission
     notice or a reference to it;
   - the shadcn/ui primitives: `SPDX-FileCopyrightText: 2023 shadcn`;
   - `globals.css`: a line attributing the F0 tokens to Factorial under MIT.
3. **Optional: replace `redis:7` with `valkey/valkey:8`** in `docker-compose.yml` for a
   development stack that is fully OSI-approved.
4. **Before the first external contribution, decide on DCO or CLA.** A DCO keeps the
   project AGPL-only for good. A CLA keeps open the option to relicense or dual-license
   later.

### 8.3 Regenerating this inventory

```sh
# npm: licenses from the lockfile, grouped by license and scope
node -e '
const l=require("./package-lock.json").packages, c={};
for (const [k,v] of Object.entries(l)) { if(!k||v.link) continue;
  const key=(v.license||"UNKNOWN")+" ["+(v.dev?"dev":v.optional?"opt":"prod")+"]";
  c[key]=(c[key]||0)+1 }
console.table(c)'

# Ruby: look up each locked gem version on RubyGems
cd apps/api
awk '/^GEM/{g=1;next} /^$/{g=0} g && /^    [a-z]/{print $1, $2}' Gemfile.lock | tr -d '()' |
while read n v; do
  curl -s "https://rubygems.org/api/v2/rubygems/$n/versions/${v%%-*}.json" |
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(process.argv[1],(JSON.parse(s).licenses||[]).join(" OR ")))' "$n"
done
```

Update this document whenever a dependency with a license that is **not** in the
compatible list above is added. That includes GPL-2.0-only, SSPL, BUSL, Commons Clause,
and any "source-available" or unlicensed package. Such a dependency would need to be
reviewed before it could be merged.
