import { NextResponse } from "next/server";

export async function GET(req: Request) {
  const url = new URL(req.url);
  const format = url.searchParams.get("format")?.toLowerCase();

  const data = {
    generatedAt: new Date().toISOString(),
    vendors: [{ id: 1, name: "Default Vendor" }, { id: 2, name: "Sample Partner" }]
  };

  if (format === "csv") {
    const rows = [
      "id,name",
      ...data.vendors.map(v => `${v.id},${JSON.stringify(v.name).replaceAll(",", " ")}`)
    ].join("\\n");
    return new Response(rows, {
      status: 200,
      headers: { "content-type": "text/csv; charset=utf-8" }
    });
  }

  return NextResponse.json(data, { status: 200 });
}