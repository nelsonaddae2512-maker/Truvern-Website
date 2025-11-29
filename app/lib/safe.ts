export function safeVendors(input: any): any[] {
  if (Array.isArray(input?.vendors)) return input.vendors;
  if (Array.isArray(input)) return input;
  return [];
}