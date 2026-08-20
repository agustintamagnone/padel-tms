async function getPing() {
  const res = await fetch(`${process.env.API_BASE_URL}/api/v1/public/ping`, {
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`API respondió ${res.status}`);
  return res.json();
}

export default async function Home() {
  const ping = await getPing();
  return (
    <main className="min-h-dvh flex flex-col items-center justify-center gap-2 p-6">
      <h1 className="text-2xl font-semibold">PadelTMS</h1>
      <p className="text-sm text-neutral-500">Servicio: {ping.service}</p>
      <p className="text-sm text-neutral-500">API OK · {ping.time}</p>
    </main>
  );
}