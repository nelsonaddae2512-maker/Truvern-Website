// lib/prisma.ts
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as {
  prisma?: PrismaClient;
};

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
  });

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;

/**
 * Prisma runtime model shape can vary by version.
 * Some code in the app may do:
 *   prisma._runtimeDataModel.enums.find(...)
 * In newer shapes, enums can be an object (not an array). This shim makes .find exist.
 */
(function ensureRuntimeEnumFindShim() {
  try {
    const rt = (prisma as any)?._runtimeDataModel;
    if (!rt) return;

    const enums = rt.enums;
    if (!enums) return;

    // If enums is an object keyed by enum name, add a .find method for compatibility.
    if (typeof enums === "object" && !Array.isArray(enums) && typeof enums.find !== "function") {
      Object.defineProperty(enums, "find", {
        enumerable: false,
        configurable: true,
        writable: true,
        value: (predicate: (e: any) => boolean) => {
          // Normalize to array of { name, values: [{name}, ...] } to match typical callers.
          const arr = Object.entries(enums)
            .filter(([k]) => k !== "find")
            .map(([name, def]: [string, any]) => {
              const rawValues =
                def?.values ??
                def ??
                []; // could be { A: {...}, B: {...} } or [ {name}, ... ] or ["A","B"]
              const valuesArray = Array.isArray(rawValues)
                ? rawValues
                : typeof rawValues === "object"
                  ? Object.keys(rawValues)
                  : [];

              const values = valuesArray.map((v: any) =>
                typeof v === "string" ? { name: v } : { name: v?.name ?? String(v) }
              );

              return { name, values };
            });

          return arr.find(predicate);
        },
      });
    }
  } catch {
    // Never break runtime if Prisma internals change again.
  }
})();

export default prisma;
