# frozen_string_literal: true

describe DiscourseTranslator::TranslatedContentNormalizer do
  fab!(:post)
  fab!(:topic)

  it "normalizes the content" do
    expect(
      DiscourseTranslator::TranslatedContentNormalizer.normalize(
        post,
        "<script>alert('test')</script><p> <h1>Testing</h1> This is a test post</p>",
      ),
    ).to eq("<p> </p><h1>Testing</h1> This is a test post<p></p>")

    expect(
      DiscourseTranslator::TranslatedContentNormalizer.normalize(
        topic,
        "<script>alert('test')</script><p> <h1>Testing</h1> This is a test post</p>",
      ),
    ).to eq("<p> </p><h1>Testing</h1> This is a test post<p></p>")
  end
end
