# frozen_string_literal: true

describe DiscourseTranslator::TranslatedContentSanitizer do
  it "sanitizes the content" do
    sanitized =
      DiscourseTranslator::TranslatedContentSanitizer.sanitize(
        "<script>alert('test')</script><p> <h1>Testing</h1> This is a test post</p>",
      )

    expect(sanitized).to eq("<p> </p><h1>Testing</h1> This is a test post<p></p>")
  end
end
