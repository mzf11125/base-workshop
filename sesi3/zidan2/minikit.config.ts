const ROOT_URL =
  process.env.NEXT_PUBLIC_URL ||
  (process.env.VERCEL_URL && `https://${process.env.VERCEL_URL}`) ||
  "http://localhost:3000";

/**
 * MiniApp configuration object. Must follow the mini app manifest specification.
 *
 * @see {@link https://docs.base.org/mini-apps/features/manifest}
 */
export const minikitConfig = {
  accountAssociation: {
    header: "eyJmaWQiOjEzNTYxMjQsInR5cGUiOiJjdXN0b2R5Iiwia2V5IjoiMHg2RDY4MzA2RDZFNDgxOTExMGE3OEU5MmY4ODEwY2I3NDc1NTk1N0U5In0",
    payload: "eyJkb21haW4iOiJiYXNlLXdvcmtzaG9wLWFzaHkudmVyY2VsLmFwcCJ9",
    signature: "MHhjN2Q2ZjZjMjBlZDc4OWE3OGNjYjIzNjlmZjg5ZTRlNTc4Mjg0YjFkZDE3NTViZDA3ZjIyMzY5MDE5ZWM2NTY5MGU1M2QzNThhMjUxZmE3ZTZhY2U3NDNmNDhkZjE5YmE0OWJiYzU4MDZmOGExNThjYTY1OWU0Yjk1YWM5NTk2ZjFj",
  },
  baseBuilder: {
    allowedAddresses: [],
  },
  miniapp: {
    version: "1",
    name: "zidan2",
    subtitle: "",
    description: "",
    screenshotUrls: [],
    iconUrl: `${ROOT_URL}/icon.png`,
    splashImageUrl: `${ROOT_URL}/splash.png`,
    splashBackgroundColor: "#000000",
    homeUrl: ROOT_URL,
    webhookUrl: `${ROOT_URL}/api/webhook`,
    primaryCategory: "utility",
    tags: ["example"],
    heroImageUrl: `${ROOT_URL}/hero.png`,
    tagline: "",
    ogTitle: "",
    ogDescription: "",
    ogImageUrl: `${ROOT_URL}/hero.png`,
  },
} as const;
