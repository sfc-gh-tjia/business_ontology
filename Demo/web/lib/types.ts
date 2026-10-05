export interface AgentResponse {
  text: string;
  htmlArtifacts: string[];
  elapsed: number;
}

export interface ComparisonResult {
  question: string;
  questionId: string;
  expected: string;
  baseline: AgentResponse | null;
  bon: AgentResponse | null;
}

export interface EvalQuestion {
  id: string;
  q: string;
  expected: string;
  tier: string;
}

export interface BonTerm {
  name: string;
  type: string;
  description: string;
  formula: string | null;
}

export interface BonRelationship {
  source: string;
  type: string;
  label: string;
  target: string;
}

export interface BonContext {
  terms: BonTerm[];
  relationships: BonRelationship[];
  raw: string;
}
