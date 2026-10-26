"use client";
import Tabs from "@/components/Tabs";
import SourceTables from "@/components/context/SourceTables";
import SemanticViewDiagram from "@/components/context/SemanticViewDiagram";
import OntologyViewer from "@/components/context/OntologyViewer";
import ValueSummary from "@/components/context/ValueSummary";
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
            <ValueSummary />
            <SemanticViewDiagram />
            <OntologyViewer />
            <div className="mt-6"><SourceTables /></div>
          </div>
        ),
        comparison: <ComparisonView />,
        analysis: <AnalysisView />,
      }}
    />
  );
}
