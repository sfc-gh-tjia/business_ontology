"use client";
import Tabs from "@/components/Tabs";
import SourceTables from "@/components/context/SourceTables";
import SemanticViewDiagram from "@/components/context/SemanticViewDiagram";
import OntologyViewer from "@/components/context/OntologyViewer";
import ComparisonView from "@/components/comparison/ComparisonView";
import AnalysisView from "@/components/analysis/AnalysisView";

export default function Home() {
  return (
    <Tabs
      tabs={[
        { id: "context", label: "Context" },
        { id: "comparison", label: "Comparison" },
        { id: "analysis", label: "Analysis" },
      ]}
      children={{
        context: (
          <div>
            <p className="text-[var(--text-muted)] mb-6">
              SAP supply chain dataset with 3 domains (Purchasing, Finance, Sales) demonstrating where a plain Semantic View
              fails and how Business Ontology (BON) resolves the gaps.
            </p>
            <SourceTables />
            <SemanticViewDiagram />
            <OntologyViewer />
          </div>
        ),
        comparison: <ComparisonView />,
        analysis: <AnalysisView />,
      }}
    />
  );
}
