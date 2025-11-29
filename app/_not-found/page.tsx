import Link from "next/link";

export default function VendorsIndex() {
  return (
    <div style={{ padding: "40px", fontFamily: "sans-serif" }}>
      <h1 style={{ fontSize: "32px", marginBottom: "20px" }}>Vendors</h1>
      <p>Welcome to the Truvern Vendor Directory.</p>
      <p>Select a demo vendor below to view KPI details.</p>
      <ul style={{ lineHeight: "2" }}>
        <li>
          <Link href="/vendors/123">Vendor 123 (Demo)</Link>
        </li>
        <li>
          <Link href="/vendors/456">Vendor 456 (Demo)</Link>
        </li>
        <li>
          <Link href="/vendors/789">Vendor 789 (Demo)</Link>
        </li>
      </ul>
    </div>
  );
}