import Head from "next/head";

export default function PrivacyPage() {
  const canonical = "https://truvern.com/legal/privacy";
  const ogImage = "/opengraph-image.png";

  return (
    <>
      <Head>
        <title>Privacy Policy | Truvern</title>
        <meta name="description" content="Truvern privacy policy and data protection overview." />
        <link rel="canonical" href={canonical} />

        <meta property="og:title" content="Truvern Privacy Policy" />
        <meta property="og:description" content="Learn how Truvern protects data." />
        <meta property="og:image" content={ogImage} />
        <meta property="og:url" content={canonical} />
      </Head>

      <main className="mx-auto max-w-3xl px-6 py-10">
        <h1 className="text-2xl font-semibold mb-4">Privacy Policy</h1>
        <p className="text-sm opacity-80">
          This is placeholder text for the upcoming Truvern privacy policy.
        </p>
      </main>
    </>
  );
}
