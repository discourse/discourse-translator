# frozen_string_literal: true

require "aws-sdk-translate"

describe Jobs::DetectPostsLanguage do
  fab!(:posts) { Fabricate.times(5, :post) }
  let(:redis_key) { DiscourseTranslator::LANG_DETECT_NEEDED }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "Amazon"
    client = Aws::Translate::Client.new(stub_responses: true)
    client.stub_responses(
      :translate_text,
      { translated_text: "大丈夫", source_language_code: "en", target_language_code: "jp" },
    )
    Aws::Translate::Client.stubs(:new).returns(client)
    posts.each { |post| Discourse.redis.sadd?(redis_key, post.id) }
  end

  it "processes posts in batches and updates their translations" do
    described_class.new.execute({})

    posts.each do |post|
      post.reload
      expect(post.detected_locale).not_to be_nil
    end

    expect(Discourse.redis.smembers(redis_key)).to be_empty
  end

  it "does not process posts if the translator is disabled" do
    SiteSetting.translator_enabled = false
    described_class.new.execute({})

    posts.each do |post|
      post.reload
      expect(post.detected_locale).to be_nil
    end

    expect(Discourse.redis.smembers(redis_key)).to match_array(posts.map(&:id).map(&:to_s))
  end

  it "processes a maximum of MAX_QUEUE_SIZE posts per run" do
    queue_size = 4
    described_class.const_set(:MAX_QUEUE_SIZE, queue_size)

    existing_posts = Discourse.redis.scard(redis_key)
    posts = 5
    posts.times { |i| Discourse.redis.sadd?(redis_key, i + 1) }

    described_class.new.execute({})

    remaining = Discourse.redis.scard(redis_key)
    expect(remaining).to eq((existing_posts + posts) - queue_size)
  end

  it "handles an empty Redis queue gracefully" do
    Discourse.redis.del(redis_key)
    expect { described_class.new.execute({}) }.not_to raise_error
  end

  it "removes successfully processed posts from Redis" do
    described_class.new.execute({})

    posts.each { |post| expect(Discourse.redis.sismember(redis_key, post.id)).to be_falsey }
  end

  it "skips posts that no longer exist" do
    non_existent_post_id = -1
    Discourse.redis.sadd?(redis_key, non_existent_post_id)

    expect { described_class.new.execute({}) }.not_to raise_error

    expect(Discourse.redis.sismember(redis_key, non_existent_post_id)).to be_falsey
  end

  it "ensures posts are processed within a distributed mutex" do
    allow(DistributedMutex).to receive(:synchronize).and_yield

    described_class.new.execute({})

    posts.each do |post|
      expect(DistributedMutex).to have_received(:synchronize).with("detect_translation_#{post.id}")
    end
  end
end
