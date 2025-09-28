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
    header: "eyJmaWQiOjEzNTYxMjQsInR5cGUiOiJhdXRoIiwia2V5IjoiMHgwYkU2NDg4YWE5M0NlNmRGMTRkMDdFNWM0YzhkYUVFRTQ0NzA1QmY1In0",
    payload: "eyJkb21haW4iOiJodHRwczovL2Jhc2Utd29ya3Nob3AtYXNoeS52ZXJjZWwuYXBwLyJ9",
    signature: "0Ql1i2zdikIITUdf+1UwS++n6VRiTJCRhxKzdTV0SKVbENMgeXGi2g816mP1awoXc4YUWei5G4Dx2dDS9+5XeBw=",
  },
  baseBuilder: {
    "allowedAddresses": ["0x451b9Bb53c8C78B1095616E6e05aA3F2dD04fB32"]
  },
  miniapp: {
    version: "1",
    name: "Ez",
    subtitle: "Ez",
    description: "Ez",
    screenshotUrls: [],
    iconUrl: `${ROOT_URL}/icon.png`,
    splashImageUrl: `${ROOT_URL}/splash.png`,
    splashBackgroundColor: "#6200EA",
    homeUrl: ROOT_URL,
    webhookUrl: `${ROOT_URL}/api/webhook`,
    primaryCategory: "games",
    tags: ["example"],
    heroImageUrl: `${ROOT_URL}/hero.png`,
    tagline: "Ez",
    ogTitle: "Ez",
    ogDescription: "Ez",
    ogImageUrl: `${ROOT_URL}/hero.png`,
  },
} as const;
