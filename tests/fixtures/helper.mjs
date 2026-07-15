import readline from 'node:readline'

const lines = readline.createInterface({ input: process.stdin })

for await (const line of lines) {
  const request = JSON.parse(line)
  process.stdout.write(
    `${JSON.stringify({
      id: request.id,
      result: { method: request.method, params: request.params },
    })}\n`,
  )
}
