import Image from "next/image";

export default function VendorCard({ v }: any) {
  return (
    <div className="rounded-2xl border bg-white p-4 shadow-sm hover:shadow-md transition">
      <div className="flex items-center gap-3">
        {v?.logoUrl ? (
          <Image
            src={v.logoUrl}
            alt={v.name || "Vendor Logo"}
            width={40}
            height={40}
            className="rounded"
          />
        ) : (
          <div className="w-10 h-10 bg-gray-200 rounded" />
        )}
        <div>
          <h3 className="text-sm font-semibold text-gray-800">{v?.name || "Vendor Name"}</h3>
          <p className="text-xs text-gray-500">{v?.industry || "Industry"}</p>
        </div>
      </div>
    </div>
  );
}
