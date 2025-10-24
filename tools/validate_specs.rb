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

    case cursor
    when Hash
      return nil unless cursor.key?(key)

      cursor[key]
    when Array
      return nil unless key.match?(/\A(?:0|[1-9]\d*)\z/)

      index = key.to_i
      return nil if index >= cursor.length

      cursor[index]
    else
      return nil
    end
  end
end

def path_template_names(path)
  path.scan(/\{([^{}]+)\}/).flatten.uniq
end

def parameter_name(parameter, document)
  resolved = if parameter.is_a?(Hash) && parameter.key?("$ref")
               resolve_local_ref(document, parameter["$ref"])
             else
               parameter
             end

  return nil unless resolved.is_a?(Hash) && resolved["in"] == "path"

  resolved["name"]
end

def missing_path_parameters(openapi)
  openapi.fetch("paths").each_with_object([]) do |(path, path_item), missing|
    next unless path_item.is_a?(Hash)

    template_names = path_template_names(path)
    next if template_names.empty?

    path_parameters = Array(path_item["parameters"])

    path_item.each do |method, operation|
      next if method == "parameters" || !operation.is_a?(Hash)

      declared_names = (path_parameters + Array(operation["parameters"])).map do |parameter|
        parameter_name(parameter, openapi)
      end.compact
      missing_names = template_names - declared_names

      missing.concat(missing_names.map { |name| "#{method.upcase} #{path} missing path parameter #{name}" })
    end
  end
end

def assert_local_ref(document, ref, expected)
  resolved = resolve_local_ref(document, ref)
  return if resolved == expected

  fail_with("internal local $ref resolver self-check failed for #{ref}")
end

def assert_missing_local_ref(document, ref)
  return if resolve_local_ref(document, ref).nil?

  fail_with("internal local $ref resolver self-check unexpectedly resolved #{ref}")
end

def self_check_local_ref_resolver
  document = {
    "components" => {
      "schemas" => [
        {
          "literal/name" => {
            "tilde~key" => "resolved"
          }
        }
      ]
    }
  }

  pointer = ->(*segments) { "##{segments.join("/")}" }
  assert_local_ref(document, pointer.call("", "components", "schemas", "0", "literal~1name", "tilde~0key"), "resolved")
  assert_missing_local_ref(document, pointer.call("", "components", "schemas", "1"))
  assert_missing_local_ref(document, pointer.call("", "components", "schemas", "-1"))
end

def self_check_path_parameter_validation
  ideas_path = ["", "ideas", "{ideaId}"].join("/")
  nested_path = ["", "cards", "{cardId}", "reviews", "{reviewId}"].join("/")
  exports_path = ["", "exports", "{jobId}"].join("/")

  document = {
    "paths" => {
      ideas_path => {
        "get" => {
          "parameters" => [
            { "$ref" => ["#", "components", "parameters", "IdeaId"].join("/") }
          ]
        }
      },
      nested_path => {
        "parameters" => [
          {
            "name" => "cardId",
            "in" => "path"
          }
        ],
        "post" => {
          "parameters" => [
            {
              "name" => "reviewId",
              "in" => "path"
            }
          ]
        }
      },
      exports_path => {
        "get" => {
          "parameters" => []
        }
      }
    },
    "components" => {
      "parameters" => {
        "IdeaId" => {
          "name" => "ideaId",
          "in" => "path"
        }
      }
    }
  }

  missing = missing_path_parameters(document)
  expected = ["GET #{exports_path} missing path parameter jobId"]
  return if missing == expected

  fail_with("internal path parameter validation self-check failed")
end

self_check_local_ref_resolver
self_check_path_parameter_validation

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

path_parameter_gaps = missing_path_parameters(openapi)
unless path_parameter_gaps.empty?
  fail_with("OpenAPI path template parameters are not declared: #{path_parameter_gaps.join(", ")}")
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
