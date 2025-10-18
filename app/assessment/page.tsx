export default function AssessmentPage() {
  return (
    <main className='max-w-3xl mx-auto p-6'>
      <h1 className='text-2xl font-semibold mb-4'>Third-Party Risk Assessment</h1>
      <p className='mb-6'>Complete the assessment below. Your results will appear after submission.</p>
      <form method='post' action='/api/assessment/submit'>
        <input name='companyName' placeholder='Company Name' className='border p-2 w-full mb-3' />
        <input name='contactEmail' placeholder='Email' className='border p-2 w-full mb-3' />
        <textarea name='answersJson' placeholder='Answers JSON' className='border p-2 w-full h-40 mb-4'></textarea>
        <button className='rounded bg-black text-white px-4 py-2'>Submit</button>
      </form>
    </main>
  )
}


