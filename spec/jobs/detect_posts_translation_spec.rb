# frozen_string_literal: true

require "aws-sdk-translate"

describe Jobs::DetectPostsTranslation do
  fab!(:posts) { Fabricate.times(5, :post) }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "Amazon"
    client = Aws::Translate::Client.new(stub_responses: true)
    client.stub_responses(
      :translate_text,
      { translated_text: "大丈夫", source_language_code: "en", target_language_code: "jp" },
    )
    Aws::Translate::Client.stubs(:new).returns(client)
    posts.each { |post| Discourse.redis.sadd?(DiscourseTranslator::LANG_DETECT_NEEDED, post.id) }
  end

  it "processes posts in batches and updates their translations" do
    described_class.new.execute({})

    posts.each do |post|
      post.reload
      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).not_to be_nil
    end

    expect(Discourse.redis.smembers(DiscourseTranslator::LANG_DETECT_NEEDED)).to be_empty
  end

  it "does not process posts if the translator is disabled" do
    SiteSetting.translator_enabled = false
    described_class.new.execute({})

    posts.each do |post|
      post.reload
      expect(post.custom_fields[DiscourseTranslator::DETECTED_LANG_CUSTOM_FIELD]).to be_nil
    end

    expect(Discourse.redis.smembers(DiscourseTranslator::LANG_DETECT_NEEDED)).to match_array(
      posts.map(&:id).map(&:to_s),
    )
  end

  it "processes a maximum of MAX_QUEUE_SIZE posts per run" do
    large_number = 2000
    large_number.times { |i| Discourse.redis.sadd?(DiscourseTranslator::LANG_DETECT_NEEDED, i + 1) }
    described_class.new.execute({})

    remaining = Discourse.redis.scard(DiscourseTranslator::LANG_DETECT_NEEDED)
    expect(remaining).to eq(large_number - Jobs::DetectPostsTranslation::MAX_QUEUE_SIZE)
  end

  it "handles an empty Redis queue gracefully" do
    Discourse.redis.del(DiscourseTranslator::LANG_DETECT_NEEDED)
    expect { described_class.new.execute({}) }.not_to raise_error
  end

  it "removes successfully processed posts from Redis" do
    described_class.new.execute({})

    posts.each do |post|
      expect(
        Discourse.redis.sismember(DiscourseTranslator::LANG_DETECT_NEEDED, post.id),
      ).to be_falsey
    end
  end

  it "skips posts that no longer exist" do
    non_existent_post_id = -1
    Discourse.redis.sadd?(DiscourseTranslator::LANG_DETECT_NEEDED, non_existent_post_id)

    expect { described_class.new.execute({}) }.not_to raise_error

    expect(
      Discourse.redis.sismember(DiscourseTranslator::LANG_DETECT_NEEDED, non_existent_post_id),
    ).to be_falsey
  end

  it "ensures posts are processed within a distributed mutex" do
    mutex_spy = instance_spy(DistributedMutex)
    allow(DistributedMutex).to receive(:synchronize).and_yield

    described_class.new.execute({})

    posts.each do |post|
      expect(DistributedMutex).to have_received(:synchronize).with("detect_translation_#{post.id}")
    end
  end
end
