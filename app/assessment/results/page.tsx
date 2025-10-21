'use client'
import { useEffect, useState } from 'react'

export default function ResultsPage() {
  const [data, setData] = useState<any>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const id = new URLSearchParams(window.location.search).get('id')
    if (!id) { setError('Missing id'); return }
    fetch('/api/assessment/results?id=' + id)
      .then(r => r.json())
      .then(setData)
      .catch(() => setError('Failed to load'))
  }, [])

  if (error) return <main className='max-w-3xl mx-auto p-6'><p className='text-red-600'>{error}</p></main>
  if (!data) return <main className='max-w-3xl mx-auto p-6'>Loading...</main>

  if (!data.ok) return <main className='max-w-3xl mx-auto p-6'><pre>{JSON.stringify(data,null,2)}</pre></main>

  const { submission, score, tier } = data
  return (
    <main className='max-w-3xl mx-auto p-6'>
      <h1 className='text-2xl font-semibold mb-2'>Assessment Results</h1>
      <p className='mb-4'>Company: <b>{submission.companyName}</b> — Email: {submission.contactEmail}</p>
      <div className='rounded border p-4 mb-6'>
        <div className='text-lg'>Score: <b>{score}</b></div>
        <div>Risk Tier: <b>{tier}</b></div>
      </div>
      <details className='border rounded p-3'>
        <summary className='cursor-pointer'>Raw submission</summary>
        <pre className='overflow-auto text-sm'>{submission.answersJson}</pre>
      </details>
    </main>
  )
}


export const dynamic = "force-dynamic";
