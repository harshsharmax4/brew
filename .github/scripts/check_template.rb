# frozen_string_literal: true

require "yaml"

CHECKBOX_MARKER = /\A- \[[ xX]\] /
CHECKED_CHECKBOX_MARKER = /\A- \[[xX]\] /
HTML_COMMENT_LINE = /\A<!--.*-->\z/
ISSUE_FORM_HEADING = /\A### /
MARKDOWN_HORIZONTAL_LINE = /\A-+\z/
NO_RESPONSE = "_No response_"
NORMALISED_CHECKBOX_MARKER = "- [ ] "
REQUIRED_TEMPLATE_PERCENTAGE = 75
PERCENTAGE_SCALE = 100

lines = lambda do |path|
  File.read(path, mode: "rb")
      .encode("UTF-8", invalid: :replace, undef: :replace)
      .lines(chomp: true)
end

normalised_lines = lambda do |path|
  lines.call(path).each_with_object([]) do |line, normalised_lines|
    line = line.strip.sub(CHECKBOX_MARKER, NORMALISED_CHECKBOX_MARKER)
    next if line.empty?
    next if line.match?(MARKDOWN_HORIZONTAL_LINE)
    next if line.match?(HTML_COMMENT_LINE)

    normalised_lines << line
  end.uniq
end

case ARGV.fetch(0)
when "pull-request"
  pr_body_path = ARGV.fetch(1)
  template_path = ARGV.fetch(2)
  pr_lines = normalised_lines.call(pr_body_path)
  template_lines = normalised_lines.call(template_path)
  matching_template_lines = template_lines.count { |line| pr_lines.include?(line) }
  scaled_matching_percentage = matching_template_lines * PERCENTAGE_SCALE
  scaled_required_percentage = template_lines.count * REQUIRED_TEMPLATE_PERCENTAGE
  preserves_template = scaled_matching_percentage >= scaled_required_percentage
  has_checked_checkbox = lines.call(pr_body_path).any? { |line| line.match?(CHECKED_CHECKBOX_MARKER) }
  has_non_template_content = (pr_lines - template_lines).any?

  puts preserves_template && (has_checked_checkbox || has_non_template_content)
when "issue"
  issue_body = File.read(ARGV.fetch(1), mode: "rb")
                   .encode("UTF-8", invalid: :replace, undef: :replace)
  issue_lines = issue_body.lines(chomp: true)
  issue_field_responses = {}
  issue_lines.each do |line|
    if line.match?(ISSUE_FORM_HEADING)
      issue_field_responses[line.delete_prefix("### ").strip] = []
    elsif issue_field_responses.any?
      issue_field_responses.fetch(issue_field_responses.keys.last) << line
    end
  end

  puts(Dir.glob("#{ARGV.fetch(2)}/*.{yml,yaml}").any? do |template_path|
    required_fields = []
    required_checkboxes = []

    YAML.safe_load_file(template_path).fetch("body", []).each do |field|
      attributes = field.fetch("attributes", {})
      case field["type"]
      when "checkboxes"
        attributes.fetch("options", []).each do |option|
          required_checkboxes << option.fetch("label") if option["required"]
        end
      when "dropdown", "input", "textarea"
        required_fields << attributes.fetch("label") if field.dig("validations", "required")
      end
    end
    next false if required_fields.empty? && required_checkboxes.empty?

    required_fields.all? do |field|
      issue_field_responses.fetch(field, []).any? do |line|
        !line.strip.empty? && line.strip != NO_RESPONSE
      end
    end &&
      required_checkboxes.all? do |checkbox|
        issue_lines.any? { |line| line.match?(CHECKED_CHECKBOX_MARKER) && line.include?(checkbox) }
      end
  end)
else
  warn "Usage: check_template.rb pull-request BODY TEMPLATE"
  warn "       check_template.rb issue BODY TEMPLATE_DIRECTORY"
  exit 1
end
