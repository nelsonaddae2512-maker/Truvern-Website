async function handleCreateVendor(formData: {
  name: string;
  riskScore?: number | string | null;
}) {
  setIsCreating(true);
  setError(null);

  try {
    const res = await fetch("/api/vendors/create", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: formData.name,
        riskScore:
          formData.riskScore === "" || formData.riskScore == null
            ? null
            : Number(formData.riskScore),
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.error || "Failed to create vendor.");
    }

    // Optional: refresh vendor list and close modal
    await refreshVendors?.();
    onClose?.();
  } catch (err: any) {
    setError(err.message ?? "Failed to create vendor.");
  } finally {
    setIsCreating(false);
  }
}
