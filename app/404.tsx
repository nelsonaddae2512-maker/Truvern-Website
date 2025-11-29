import { ensureArray } from '@/app/lib/safe';
export default function NotFound() {
  return (
    <div style={{padding:24}}>
      <h1>Page not found</h1>
      <p>Try the dashboard or vendors list.</p>
      <a href="/">Go home</a>
    </div>
  );
}

