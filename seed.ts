import prisma from './src/lib/db'
async function main() {
  await prisma.assessmentSubmission.create({
    data: {
      companyName: 'Demo Co',
      contactEmail: 'demo@example.com',
      answersJson: JSON.stringify([{id:'q1',value:'yes'},{id:'q2',value:'no'}]),
    },
  })
  console.log('Seeded')
}
main().then(()=>process.exit(0)).catch(e=>{console.error(e);process.exit(1)})

