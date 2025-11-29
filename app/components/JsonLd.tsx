'use client';

import { ensureArray } from '@/app/lib/safe';
import Script from 'next/script';

export default function JsonLd({ id, data }: { id: string; data: object }) {
  return (
    <Script
      id={id}
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}

