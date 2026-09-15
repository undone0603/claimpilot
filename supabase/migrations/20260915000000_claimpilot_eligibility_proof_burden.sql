-- Migration: ClaimPilot Eligibility and Proof-Burden Engine Schema
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE claim_status AS ENUM ('draft', 'evaluating', 'eligible', 'ineligible', 'pending_proof', 'submitted', 'approved', 'rejected');
CREATE TYPE proof_status AS ENUM ('pending', 'uploaded', 'under_review', 'verified', 'rejected');
CREATE TYPE rule_operator AS ENUM ('eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'contains', 'in', 'regex');

CREATE TABLE claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(128) UNIQUE NOT NULL,
  title VARCHAR(255) NOT NULL,
  provider VARCHAR(255) NOT NULL,
  summary TEXT,
  description TEXT,
  filing_deadline TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE eligibility_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id UUID NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
  rule_key VARCHAR(128) NOT NULL,
  field_path VARCHAR(255) NOT NULL,
  operator rule_operator NOT NULL,
  target_value JSONB NOT NULL,
  weight NUMERIC(5,2) DEFAULT 1.0 NOT NULL,
  is_required BOOLEAN DEFAULT true NOT NULL,
  failure_message TEXT,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE proof_requirements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id UUID NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  document_type VARCHAR(64) NOT NULL,
  is_mandatory BOOLEAN DEFAULT true NOT NULL,
  validation_schema JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE user_claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  claim_id UUID NOT NULL REFERENCES claims(id) ON DELETE RESTRICT,
  status claim_status DEFAULT 'draft' NOT NULL,
  fit_score NUMERIC(5,2) DEFAULT 0.00 NOT NULL,
  user_input_data JSONB DEFAULT '{}'::jsonb NOT NULL,
  submitted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_user_claim UNIQUE (user_id, claim_id)
);

CREATE TABLE eligibility_evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_claim_id UUID NOT NULL REFERENCES user_claims(id) ON DELETE CASCADE,
  is_eligible BOOLEAN NOT NULL,
  passed_rules_count INT NOT NULL,
  total_rules_count INT NOT NULL,
  proof_satisfied_ratio NUMERIC(5,2) DEFAULT 0.00 NOT NULL,
  rule_results JSONB DEFAULT '[]'::jsonb NOT NULL,
  evaluated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE user_proof_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_claim_id UUID NOT NULL REFERENCES user_claims(id) ON DELETE CASCADE,
  proof_requirement_id UUID NOT NULL REFERENCES proof_requirements(id) ON DELETE RESTRICT,
  file_path TEXT NOT NULL,
  file_name VARCHAR(255) NOT NULL,
  file_size INT NOT NULL,
  mime_type VARCHAR(128) NOT NULL,
  status proof_status DEFAULT 'pending' NOT NULL,
  extracted_metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
  rejection_reason TEXT,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
