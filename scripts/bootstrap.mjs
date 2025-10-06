
import crypto from 'crypto';
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
function rnd(arr){ return arr[Math.floor(Math.random()*arr.length)]; }
async function main(){
  let org = await prisma.organization.findFirst({ where: { name: 'Truvern Demo Org' } });
  if(!org){ org = await prisma.organization.create({ data: { name: 'Truvern Demo Org', plan: 'free', seats: 3 } }); }
  let vendor = await prisma.vendor.findFirst({ where: { slug: 'acme-labs' } });
  if(!vendor){
    vendor = await prisma.vendor.create({ data: { name: 'Acme Labs', slug: 'acme-labs', organizationId: org.id, trustPublic: true, trustToken: crypto.randomBytes(8).toString('hex') } });
  }
  const have = await prisma.answer.count({ where: { vendorId: vendor.id } });
  if(have < 10){
    const crit = ['Low','Medium','High'];
    const frameworks = ['ISO 27001','NIST CSF','SOC 2','HIPAA'];
    await prisma.answer.createMany({ data: Array.from({length:10}).map((_,i)=> ({
      vendorId: vendor.id, questionId: `Q${i+1}`, answer: rnd(['yes','no','partial']),
      maturity: rnd([undefined,1,2,3,4,5]), criticality: rnd(crit), frameworks: [rnd(frameworks)]
    }))});
  }
  const ev = await prisma.evidence.count({ where: { vendorId: vendor.id } });
  if(ev < 2){
    await prisma.evidence.createMany({ data: [
      { vendorId: vendor.id, questionId: 'Q1', url: 'https://example.com/policy.pdf', status: 'approved' },
      { vendorId: vendor.id, questionId: 'Q2', url: 'https://example.com/runbook.pdf', status: 'pending' }
    ]});
  }
  console.log('Seed complete. Visit /trust/acme-labs');
}
main().finally(()=>prisma.$disconnect());
