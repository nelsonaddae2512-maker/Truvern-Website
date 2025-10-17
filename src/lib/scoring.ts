export type ScoreOutput = { score: number; tier: 'LOW'|'MEDIUM'|'HIGH' }
export function computeScore(answersJson: string): ScoreOutput {
  try {
    const answers = JSON.parse(answersJson || "[]")
    // Simple example: +10 per 'yes' answer, -5 per 'no'
    let score = 0
    for (const a of answers) {
      if (String(a.value).toLowerCase() === 'yes') score += 10
      else if (String(a.value).toLowerCase() === 'no') score -= 5
    }
    let tier: ScoreOutput['tier'] = 'MEDIUM'
    if (score >= 60) tier = 'LOW'
    else if (score <= 20) tier = 'HIGH'
    return { score, tier }
  } catch { return { score: 0, tier: 'MEDIUM' } }
}
