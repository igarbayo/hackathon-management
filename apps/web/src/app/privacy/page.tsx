import type { Metadata } from "next";
import Link from "next/link";
import { LogoHorizontal } from "@/components/brand/logo";
import { publicPageMetadata } from "@/lib/site";

// RF-SEC-007: public privacy policy (GDPR arts. 13 and 14). The content
// mirrors the inventory in specs/09-privacidad-seguridad.md: if a piece of
// data, a third party or a retention period changes there, change it here too.
export const metadata: Metadata = publicPageMetadata({
  title: "Privacy policy",
  description:
    "What data Hackboard processes, why, on what legal basis, who it is shared with, how long it is kept and how to use your rights.",
  path: "/privacy",
});

const UPDATED_AT = "September 24, 2026";
const CONTACT_EMAIL = "iggarbayo@gmail.com";

type Treatment = {
  title: string;
  data: string;
  purpose: string;
  basis: string;
  retention: string;
};

const TREATMENTS: Treatment[] = [
  {
    title: "Your account",
    data: "Email, name, avatar, password (only its bcrypt hash, never in plain text), GitHub login and ID, and Google ID (sub), if you sign in with them.",
    purpose: "Create your account, identify you when you log in and show you to your team.",
    basis: "Performance of a contract: providing the service you ask for when you sign up (GDPR art. 6.1.b).",
    retention: "As long as the account exists.",
  },
  {
    title: "Sessions",
    data: "A session ID (only its hash), and the IP address and browser (user agent) you logged in from.",
    purpose: "Keep you logged in and detect unauthorized access to your account.",
    basis: "Legitimate interest in the security of the service and of your account (GDPR art. 6.1.f).",
    retention: "30 days from the last use of the session, or until you log out.",
  },
  {
    title: "Team content",
    data: "What the team writes in Hackboard: objectives, features, arguments and votes, milestones, deadlines, the name you use in the team and your git identities.",
    purpose: "Let the team organize its hackathon.",
    basis: "Performance of a contract (GDPR art. 6.1.b).",
    retention: "As long as the team exists. If it is deleted, it is permanently erased after 30 days.",
  },
  {
    title: "GitHub activity",
    data: "From the repositories the team links: the sha, message (shortened), author, author email, file paths and lines added and removed of each commit.",
    purpose: "Show the activity feed and link the work to features.",
    basis: "Performance of a contract for team members; the team's legitimate interest in following its own work for other commit authors (GDPR art. 6.1.f).",
    retention: "90 days after the hackathon ends, unless the owner marks the team as “keep”.",
  },
  {
    title: "Claude Code activity (optional)",
    data: "Only if you connect the CLI: event type, times, branch, sha, relative paths of edited files, number of tools and prompt length. With the “summaries” level, also a summary of up to 500 characters that Claude writes and you see before it is sent.",
    purpose: "Show your team what you are working on.",
    basis: "Performance of a contract, in a feature that only you turn on and can pause or disconnect at any time (GDPR art. 6.1.b).",
    retention: "Same as GitHub activity. You can delete it at any time with “Disconnect and delete my events”.",
  },
  {
    title: "AI analysis (optional)",
    data: "The team's titles, descriptions, commit messages, paths and counts, and the result of the analysis. Your Gemini API key, encrypted.",
    purpose: "Work out objective coverage and link commits to features.",
    basis: "Performance of a contract, only when you set up your key and run an analysis (GDPR art. 6.1.b).",
    retention: "Analyses, same as activity. The key, until you remove it or delete your account.",
  },
  {
    title: "Tokens, connected apps and webhooks",
    data: "Name, prefix, permissions and last use of your tokens (only their hash); name and permissions of the apps you authorize; for outgoing webhooks, their URL, the encrypted secret and the status, code and duration of each delivery (never the content).",
    purpose: "Give programmatic access to Hackboard and notify the team's other tools.",
    basis: "Performance of a contract (GDPR art. 6.1.b).",
    retention: "Tokens and connections, up to 30 days after they are revoked or expire. Webhook deliveries, 14 days.",
  },
  {
    title: "Technical logs",
    data: "IP address, date, requested path and result of each request; temporary per-IP counters to limit abuse.",
    purpose: "Keep the service running and protect it from abuse and attacks.",
    basis: "Legitimate interest in the security of the service (GDPR art. 6.1.f).",
    retention: "Logs rotate and are overwritten automatically; counters last 1 hour at most.",
  },
  {
    title: "When you write to me",
    data: "Your email and what you tell me.",
    purpose: "Reply to you and handle requests to use your rights.",
    basis: "Compliance with a legal obligation when you use your rights (GDPR art. 6.1.c); legitimate interest in all other cases.",
    retention: "As long as needed to resolve the request and, after that, for the period in which liability can be claimed.",
  },
];

const PROVIDERS: { name: string; what: string; where: string }[] = [
  {
    name: "Cloudflare (Cloudflare, Inc.)",
    what: "All traffic between your browser (or the CLI) and the server goes through its network over an encrypted tunnel: it sees your IP address and the requests you make. It acts as a data processor.",
    where: "Global network, based in the United States.",
  },
  {
    name: "MongoDB Atlas (MongoDB, Inc.)",
    what: "The database where everything above is stored. It acts as a data processor.",
    where: "Servers in the European Union.",
  },
  {
    name: "Upstash (Upstash, Inc.)",
    what: "Queues and temporary data (background jobs, counters, idempotent responses kept for 24 hours). It acts as a data processor.",
    where: "Servers in the European Union.",
  },
  {
    name: "GitHub (GitHub, Inc.)",
    what: "If you sign in with GitHub or the team links repositories: Hackboard receives your public profile and reads the activity of those repositories.",
    where: "United States.",
  },
  {
    name: "Google (Google LLC)",
    what: "If you sign in with Google: it identifies you and gives us your email, name and photo. If you use AI analysis: it receives, with your Gemini key, the team context described above.",
    where: "United States.",
  },
  {
    name: "Anthropic (Anthropic, PBC)",
    what: "Only if you connect Hackboard to claude.ai: it receives what Claude reads from the board, within the permissions you approve.",
    where: "United States.",
  },
];

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section aria-labelledby={id} className="flex flex-col gap-3">
      <h2 id={id} className="text-f1-foreground text-lg font-semibold">
        {title}
      </h2>
      {children}
    </section>
  );
}

function Mail() {
  return (
    <a
      href={`mailto:${CONTACT_EMAIL}`}
      className="text-f1-foreground focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
    >
      {CONTACT_EMAIL}
    </a>
  );
}

export default function PrivacyPage() {
  return (
    <main className="flex min-h-screen flex-col items-center gap-8 px-4 py-10">
      <Link
        href="/"
        aria-label="Go to Hackboard"
        className="focus-visible:ring-f1-special-ring rounded focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
      >
        <LogoHorizontal className="h-10" priority />
      </Link>

      <article className="bg-f1-background border-f1-border text-f1-foreground-secondary flex w-full max-w-[712px] flex-col gap-8 rounded-xl border p-6 text-base sm:p-8">
        <header className="flex flex-col gap-1">
          <h1 className="text-f1-foreground text-2xl font-semibold">Privacy policy</h1>
          <p className="text-sm">Last updated: {UPDATED_AT}</p>
        </header>

        <p>
          Hackboard is a tool to organize hackathon teams. It stores the minimum it needs to work and never stores the
          text of your prompts, Claude&apos;s replies, diffs or the content of your files. Here are the details.
        </p>

        <Section id="controller" title="Who is the data controller">
          <p>
            Ignacio Garbayo, who builds and runs Hackboard as an individual. For any question about your data, write to
            me at <Mail />.
          </p>
        </Section>

        <Section id="data" title="What data I process, what for and why">
          <div className="flex flex-col gap-3">
            {TREATMENTS.map((t) => (
              <div key={t.title} className="border-f1-border-secondary flex flex-col gap-2 rounded-md border p-4">
                <h3 className="text-f1-foreground font-semibold">{t.title}</h3>
                <dl className="grid gap-x-4 gap-y-1.5 sm:grid-cols-[8rem_1fr]">
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">Data</dt>
                  <dd>{t.data}</dd>
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">What for</dt>
                  <dd>{t.purpose}</dd>
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">Legal basis</dt>
                  <dd>{t.basis}</dd>
                  <dt className="text-f1-foreground-tertiary text-sm sm:text-base">How long</dt>
                  <dd>{t.retention}</dd>
                </dl>
              </div>
            ))}
          </div>
          <p>
            Your account data is needed to use Hackboard: without it I cannot create your account. Everything marked as
            optional depends on you turning it on.
          </p>
        </Section>

        <Section id="non-users" title="If you do not use Hackboard but your name shows up">
          <p>
            If you have made commits in a repository that a team links to Hackboard, your name, your git email and the
            metadata of those commits, taken from GitHub, are stored. They are used only for that team&apos;s activity
            feed and are deleted within the periods above. If you later join that team, those commits are linked to your
            account by your login or your git email. You can object or ask for them to be deleted by writing to <Mail />.
          </p>
        </Section>

        <Section id="never-stored" title="What I never store">
          <ul className="flex list-disc flex-col gap-1 pl-5">
            <li>The text of your prompts or Claude&apos;s replies.</li>
            <li>Diffs or file contents.</li>
            <li>Your password in plain text, or your Google or GitHub tokens.</li>
            <li>The content of the webhooks I receive from GitHub, beyond what is needed to process them.</li>
          </ul>
          <p>I do not sell your data, I do not run ads and I do not build commercial profiles.</p>
        </Section>

        <Section id="third-parties" title="Who it is shared with">
          <p>Hackboard runs on its own server in Spain. These providers receive data, only what they need for their job:</p>
          <ul className="flex flex-col gap-2">
            {PROVIDERS.map((p) => (
              <li key={p.name} className="flex flex-col gap-0.5">
                <span className="text-f1-foreground font-medium">{p.name}</span>
                <span>
                  {p.what} {p.where}
                </span>
              </li>
            ))}
          </ul>
          <p>
            Also, the members of your team see what is shared in it; an owner can send team events to the tools they
            choose through webhooks (never Claude Code activity), and the apps you give a token to can access whatever
            their permissions allow. What those third parties do with the data depends on their own terms.
          </p>
          <p>
            The Gemini key is yours, so what Google does with what is sent to it depends on your plan. On the free tier
            of the Gemini API, Google may use that content to improve its products; if you do not want that, use a key
            from a paid plan.
          </p>
          <p>I only hand data to authorities when the law requires me to.</p>
        </Section>

        <Section id="transfers" title="Transfers outside the European Union">
          <p>
            GitHub, Google, Anthropic and Cloudflare are in the United States, and MongoDB and Upstash are US companies
            even though they store the data in Europe. These transfers rely on the EU-US Data Privacy Framework when the
            company has signed up to it and, if not, on the standard contractual clauses approved by the European
            Commission (GDPR art. 46). You can ask me for a copy of these safeguards.
          </p>
        </Section>

        <Section id="google" title="Google account data">
          <p>
            If you sign in with Google, Hackboard only asks for the <code className="text-sm">openid</code>,{" "}
            <code className="text-sm">email</code> and <code className="text-sm">profile</code> scopes: it receives your
            ID, your email (and whether it is verified), your name and your photo. It uses them only to create your
            account, let you log in and show you to your team. It does not access Gmail, Drive, Calendar or any other
            Google data, does not store your Google tokens, does not transfer this data to third parties except as
            described in this policy and does not use it for ads or to train AI models.
          </p>
          <p>
            Hackboard&apos;s use of information received from Google APIs adheres to the{" "}
            <a
              href="https://developers.google.com/terms/api-services-user-data-policy"
              className="text-f1-foreground focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
            >
              Google API Services User Data Policy
            </a>
            , including the Limited Use requirements.
          </p>
        </Section>

        <Section id="cookies" title="Cookies and local storage">
          <p>Hackboard only uses technical cookies that it needs to work, so they do not need your consent:</p>
          <ul className="flex list-disc flex-col gap-1 pl-5">
            <li>
              <code className="text-sm">hb_session</code>: keeps you logged in. It lasts 30 days from the last use.
            </li>
            <li>
              <code className="text-sm">hb_csrf_seed</code>: protects forms against forged requests. It is deleted when
              you close the browser.
            </li>
          </ul>
          <p>
            The browser&apos;s local storage keeps the theme (light or dark) you choose. There is no analytics, no ads
            and no third-party cookies. Profile photos load straight from GitHub or Google, which receive your IP
            address when they are shown.
          </p>
        </Section>

        <Section id="rights" title="Your rights">
          <p>At any time and for free, you can:</p>
          <ul className="flex list-disc flex-col gap-1 pl-5">
            <li>Access your data and know how it is processed.</li>
            <li>Correct it if it is inaccurate.</li>
            <li>Erase it, by deleting your account or your Claude Code events.</li>
            <li>Restrict its processing.</li>
            <li>Object to processing based on legitimate interest.</li>
            <li>Receive it in a structured, commonly used format (portability).</li>
          </ul>
          <p>
            You can do many of these things yourself from Settings: edit your profile, revoke tokens and apps, pause or
            disconnect Claude Code and delete its events, and delete your account. For anything else, write to me at{" "}
            <Mail /> from your account email. I will reply within one month at most.
          </p>
          <p>
            If you think I have not handled your data properly, you can file a complaint with the{" "}
            <a
              href="https://www.aepd.es"
              className="text-f1-foreground focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
            >
              Spanish Data Protection Agency (AEPD)
            </a>{" "}
            or with the supervisory authority in your country.
          </p>
          <p>
            When you delete your account, your profile, sessions, Gemini key and Claude Code activity are deleted, and
            your tokens and connected apps are revoked. In GitHub activity, which is part of the repository history, you
            show up as “Deleted user” next to your login. What you wrote in a team (features, arguments…) still belongs
            to the team. If any of it remains in a backup, it disappears from it when the backup expires.
          </p>
        </Section>

        <Section id="ai" title="Automated decisions">
          <p>
            AI analysis suggests which commits belong to each feature and how much of each objective is covered. These
            are hints for the team, which can correct them: no decisions with legal or similarly significant effects are
            made about anyone (GDPR art. 22).
          </p>
        </Section>

        <Section id="security" title="Security">
          <p>
            All communication is encrypted with HTTPS. Passwords and tokens are stored as hashes, keys and secrets are
            encrypted, and each team can only access its own data. If there were a security breach affecting your data,
            I would tell you and notify the supervisory authority as the law requires.
          </p>
        </Section>

        <Section id="minors" title="Minors">
          <p>
            Hackboard is not meant for people under 16 and they cannot sign up. If you know that someone under 16 has
            created an account, write to me and I will delete it.
          </p>
        </Section>

        <Section id="changes" title="Changes to this policy">
          <p>
            If I change anything important, I will announce it in the app before it takes effect. The date at the top
            shows the latest version.
          </p>
        </Section>
      </article>

      <footer className="text-f1-foreground-secondary text-sm">
        <Link
          href="/login"
          className="focus-visible:ring-f1-special-ring rounded-2xs underline focus-visible:ring-1 focus-visible:ring-offset-1 focus-visible:outline-none"
        >
          Back to Hackboard
        </Link>
      </footer>
    </main>
  );
}
