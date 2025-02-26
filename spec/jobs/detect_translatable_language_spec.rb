# frozen_string_literal: true

require "aws-sdk-translate"

describe Jobs::DetectTranslatableLanguage do
  fab!(:post)
  fab!(:topic)
  let!(:job) { Jobs::DetectTranslatableLanguage.new }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "Amazon"
    client = Aws::Translate::Client.new(stub_responses: true)
    client.stub_responses(
      :translate_text,
      { translated_text: "大丈夫", source_language_code: "en", target_language_code: "jp" },
    )
    Aws::Translate::Client.stubs(:new).returns(client)
  end

  it "does nothing when type is not post or topic" do
    expect { job.execute(type: "X", translatable_id: 1) }.not_to raise_error
  end

  it "does nothing when id is not int" do
    expect { job.execute(type: "Post", translatable_id: "A") }.not_to raise_error
  end

  it "updates detected locale" do
    job.execute(type: "Post", translatable_id: post.id)
    job.execute(type: "Topic", translatable_id: topic.id)

    expect(post.detected_locale).not_to be_nil
    expect(topic.detected_locale).not_to be_nil
  end

  it "does not update detected locale the translator is disabled" do
    SiteSetting.translator_enabled = false

    job.execute(type: "Post", translatable_id: post.id)
    job.execute(type: "Topic", translatable_id: topic.id)

    expect(post.detected_locale).to be_nil
    expect(topic.detected_locale).to be_nil
  end

  it "skips content that no longer exist" do
    non_existent_id = -1

    expect { job.execute(type: "Post", translatable_id: non_existent_id) }.not_to raise_error
    expect { job.execute(type: "Topic", translatable_id: non_existent_id) }.not_to raise_error
  end
end
