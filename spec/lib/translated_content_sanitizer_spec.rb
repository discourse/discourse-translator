# frozen_string_literal: true

describe DiscourseTranslator::TranslatedContentSanitizer do
  describe "Posts" do
    it "sanitizes the content" do
      sanitized =
        DiscourseTranslator::TranslatedContentSanitizer.sanitize(
          Post,
          "<script>alert('test')</script><p> <h1>Testing</h1> This is a test post</p>",
        )

      expect(sanitized).to eq("<p> </p><h1>Testing</h1> This is a test post<p></p>")
    end
  end

  describe "Topics" do
    it "escapes and prettifies" do
      sanitized =
        DiscourseTranslator::TranslatedContentSanitizer.sanitize(
          Topic,
          "<script>alert('test')</script><p> <h1>Testing</h1> This is a test post</p>",
        )

      expect(sanitized).to eq(
        "&lt;script&gt;alert(&lsquo;test&rsquo;)&lt;/script&gt;&lt;p&gt; &lt;h1&gt;Testing&lt;/h1&gt; This is a test post&lt;/p&gt;",
      )
    end
  end
end
