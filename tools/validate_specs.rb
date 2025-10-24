# frozen_string_literal: true

require "yaml"

ROOT = File.expand_path("..", __dir__)

def repo_path(path)
  File.join(ROOT, path)
end

def fail_with(message)
  warn "validate: #{message}"
  exit 1
end

def collect_refs(value, refs = [])
  case value
  when Hash
    refs << value["$ref"] if value.key?("$ref")
    value.each_value { |child| collect_refs(child, refs) }
  when Array
    value.each { |child| collect_refs(child, refs) }
  end

  refs
end

def resolve_local_ref(document, ref)
  return nil unless ref.start_with?("#/")

  ref.delete_prefix("#/").split("/").reduce(document) do |cursor, segment|
    key = segment.gsub("~1", "/").gsub("~0", "~")
    return nil unless cursor.is_a?(Hash) && cursor.key?(key)

    cursor[key]
  end
end

required_files = [
  "README.md",
  "specs/001-ai-learning-assistant/spec.md",
  "specs/001-ai-learning-assistant/plan.md",
  "specs/001-ai-learning-assistant/research.md",
  "specs/001-ai-learning-assistant/data-model.md",
  "specs/001-ai-learning-assistant/quickstart.md",
  "specs/001-ai-learning-assistant/contracts/openapi.yaml"
]

missing = required_files.reject { |path| File.file?(repo_path(path)) }
fail_with("missing required spec files: #{missing.join(", ")}") unless missing.empty?

openapi_path = repo_path("specs/001-ai-learning-assistant/contracts/openapi.yaml")
begin
  openapi = YAML.load_file(openapi_path)
rescue Psych::Exception => e
  fail_with("OpenAPI YAML is not parseable: #{e.message}")
end

unless openapi.is_a?(Hash) && openapi["openapi"].to_s.start_with?("3.") &&
       openapi["paths"].is_a?(Hash)
  fail_with("OpenAPI YAML must declare an OpenAPI 3.x document with paths")
end

refs = collect_refs(openapi).uniq
invalid_refs = refs.reject { |ref| ref.is_a?(String) }
unless invalid_refs.empty?
  fail_with("OpenAPI $ref values must be strings")
end

refs = refs.sort
external_refs = refs.reject { |ref| ref.start_with?("#/") }
unless external_refs.empty?
  fail_with("OpenAPI external $ref values are not supported: #{external_refs.join(", ")}")
end

missing_refs = refs.select { |ref| resolve_local_ref(openapi, ref).nil? }
unless missing_refs.empty?
  fail_with("OpenAPI local $ref values do not resolve: #{missing_refs.join(", ")}")
end

readme = File.read(repo_path("README.md"))
readme_required_phrases = [
  "This repository is currently a specification and planning workspace, not a",
  "released product or runnable application.",
  "The repository does not currently include `package.json`, `apps/`, or",
  "`packages/` application source trees.",
  "No automated product test suite is present in the repository yet."
]

missing_phrases = readme_required_phrases.reject { |phrase| readme.include?(phrase) }
unless missing_phrases.empty?
  fail_with("README spec-only boundary changed or missing: #{missing_phrases.join(" | ")}")
end

app_scaffolds = ["package.json", "apps", "packages"].select do |path|
  File.exist?(repo_path(path))
end
fail_with("unexpected runnable app scaffold present: #{app_scaffolds.join(", ")}") unless app_scaffolds.empty?

puts "validate: spec boundary checks passed"
