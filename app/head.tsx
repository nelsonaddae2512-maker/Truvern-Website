// app/head.tsx

export default function Head() {
  const title = "Truvern – vendor risk you can actually trust";
  const description =
    "One place to see, prove, and share third-party risk posture. Live vendor health, evidence, and board-ready reporting in a single trust network.";
  const siteUrl = "https://truvern.com";
  const imageUrl = `${siteUrl}/brand/truvern-social-card.png`;

  return (
    <>
      {/* Basic */}
      <title>{title}</title>
      <meta name="description" content={description} />

      {/* Favicon / icon (shield) */}
      <link
        rel="icon"
        href="/brand/truvern-shield.svg"
        type="image/svg+xml"
      />

      {/* Open Graph (Facebook, LinkedIn, Slack, etc.) */}
      <meta property="og:type" content="website" />
      <meta property="og:site_name" content="Truvern" />
      <meta property="og:title" content={title} />
      <meta property="og:description" content={description} />
      <meta property="og:url" content={siteUrl} />
      <meta property="og:image" content={imageUrl} />
      <meta property="og:image:width" content="1200" />
      <meta property="og:image:height" content="630" />
      <meta
        property="og:image:alt"
        content="Truvern vendor risk snapshot and integrity-sealed build."
      />

      {/* Twitter / X */}
      <meta name="twitter:card" content="summary_large_image" />
      <meta name="twitter:title" content={title} />
      <meta name="twitter:description" content={description} />
      <meta name="twitter:image" content={imageUrl} />
    </>
  );
}
