import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "BON Evaluation — SAP Supply Chain",
  description: "Business Ontology value demonstration with SAP-coded enterprise data",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-[var(--bg)] text-[var(--text)] antialiased">
        <header className="border-b border-[var(--border)] bg-[var(--bg-card)]">
          <div className="max-w-7xl mx-auto px-6 py-5">
            <h1 className="text-2xl font-bold tracking-tight">
              Business Ontology Evaluation
            </h1>
            <p className="text-sm text-[var(--text-muted)] mt-1">
              SAP Supply Chain — 11 questions across 3 tiers: business knowledge, cross-domain reasoning, and strategic decision support
            </p>
          </div>
        </header>
        <main className="max-w-7xl mx-auto px-6 py-6">{children}</main>
      </body>
    </html>
  );
}
