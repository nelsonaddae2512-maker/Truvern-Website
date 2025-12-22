import SignInClient from "./SignInClient";

type SearchParams = Record<string, string | string[] | undefined>;

export default async function SignInPage({
  searchParams,
}: {
  searchParams?: Promise<SearchParams>;
}) {
  const sp = (await searchParams) ?? {};
  const raw = sp.redirect_url;

  const redirectUrl =
    typeof raw === "string"
      ? raw
      : Array.isArray(raw) && typeof raw[0] === "string"
      ? raw[0]
      : "/vendors";

  return <SignInClient redirectUrl={redirectUrl} />;
}
