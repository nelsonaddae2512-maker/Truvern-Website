import { z } from 'zod'
export const AssessmentInput = z.object({
  companyName: z.string().min(1),
  contactEmail: z.string().email(),
  answers: z.array(z.object({ id: z.string(), value: z.any() })),
})
export type AssessmentInput = z.infer<typeof AssessmentInput>
