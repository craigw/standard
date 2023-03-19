require_relative "../../test_helper"

require "standard/runners/rubocop"
require "fixture/runner/bad_cop"

class Standard::Runners::RubocopTest < UnitTest
  DEFAULT_OPTIONS = {
    formatters: [["quiet", nil]]
  }.freeze

  EXPECTED_REPORT = <<~REPORT
    == test/fixture/runner/agreeable.rb ==
    C:  1:  1: [Corrected] Style/FrozenStringLiteralComment: Missing frozen string literal comment.
    C:  1:  1: [Corrected] Style/SingleLineMethods: Avoid single-line method definitions.
    C:  1:  8: [Corrected] Layout/SpaceAfterSemicolon: Space missing after semicolon.
    C:  2:  1: [Corrected] Layout/EmptyLineAfterMagicComment: Add an empty line after magic comments.
    C:  2:  8: [Corrected] Style/Semicolon: Do not use semicolons to terminate expressions.
    C:  2:  9: [Corrected] Layout/TrailingWhitespace: Trailing whitespace detected.
    C:  3:  5: Naming/MethodName: Use snake_case for method names.

    1 file inspected, 7 offenses detected, 6 offenses corrected
    ====================
  REPORT

  EXPECTED_FIXED = <<~OUT
    # frozen_string_literal: true

    def Foo
      'hi'
    end
  OUT

  def setup
    super

    @subject = Standard::Runners::Rubocop.new
  end

  def test_empty_output_on_quiet_success
    fake_out, fake_err = do_with_fake_io do
      @subject.call(create_config)
    end

    assert_equal "", fake_out.string
    assert_equal "", fake_err.string
  end

  def test_error_output_on_cop_error
    RuboCop::Cop::Standard::BadCop.send(:define_method, :on_send) { |_| raise "hell" }

    fake_out, fake_err = do_with_fake_io do
      @subject.call(create_config(
        only: ["Standard/BadCop"]
      ))
    end

    assert_equal "", fake_out.string
    assert_match(%r{An error occurred while Standard/BadCop cop was inspecting}, fake_err.string)

    RuboCop::Cop::Standard::BadCop.send(:define_method, :on_send) { |_| }
  end

  def test_print_corrected_output_on_stdin
    fake_out, fake_err = do_with_fake_io do
      @subject.call(create_config(
        autocorrect: true,
        stdin: "def Foo;'hi'end\n"
      ))
    end

    assert_equal EXPECTED_REPORT + EXPECTED_FIXED, fake_out.string
    assert_equal "", fake_err.string
  end

  def test_print_corrected_output_on_stdin_with_corrections_on_stderr
    fake_out, fake_err = do_with_fake_io do
      @subject.call(create_config(
        parallel: true, # should be removed dynamically by us to prevent RuboCop from breaking
        autocorrect: true,
        stderr: true,
        stdin: "def Foo;'hi'end\n"
      ))
    end

    assert_equal EXPECTED_FIXED, fake_out.string
    assert_equal EXPECTED_REPORT, fake_err.string
  end

  private

  def create_config(options = {}, path = "test/fixture/runner/agreeable.rb")
    Standard::Config.new(nil, [path], DEFAULT_OPTIONS.merge(options),
      RuboCop::ConfigStore.new)
  end
end
