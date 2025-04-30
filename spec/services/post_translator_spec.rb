# frozen_string_literal: true

describe DiscourseTranslator::PostTranslator do
  describe ".translate" do
    fab!(:post) { Fabricate(:post, raw: "Hello world", version: 1) }
    let(:translator) { mock }
    let(:translated_raw) { "こんにちは世界" }
    let(:cooked) { "<p>こんにちは世界</p>" }
    let(:target_locale) { "ja" }

    before do
      DiscourseTranslator::Provider::TranslatorProvider.stubs(:get).returns(translator)
      translator.stubs(:translate_post!).with(post, :ja).returns(translated_raw)
    end

    it "returns nil if post is blank" do
      expect(described_class.translate(nil, "ja")).to eq(nil)
    end

    it "returns nil if target_locale is blank" do
      expect(described_class.translate(post, nil)).to eq(nil)
      expect(described_class.translate(post, "")).to eq(nil)
    end

    it "translates with post and locale" do
      translator.expects(:translate_post!).with(post, :ja).returns(translated_raw)

      described_class.translate(post, "ja")
    end

    it "normalizes dashes to underscores and symbol type for locale" do
      translator.expects(:translate_post!).with(post, :zh_CN).returns("你好，世界")

      described_class.translate(post, "zh-CN")
    end

    it "finds or creates a PostLocalization and sets its fields" do
      expect {
        res = described_class.translate(post, target_locale)
        expect(res).to be_a(PostLocalization)
        expect(res).to have_attributes(
          post_id: post.id,
          locale: target_locale,
          raw: translated_raw,
          cooked: cooked,
          post_version: post.version,
          localizer_user_id: Discourse.system_user.id,
        )
      }.to change { PostLocalization.count }.by(1)
    end

    it "updates an existing PostLocalization if present" do
      localization =
        Fabricate(:post_localization, post: post, locale: "ja", raw: "old", cooked: "old_cooked")
      expect {
        out = described_class.translate(post, "ja")
        expect(out.id).to eq(localization.id)
        expect(out.raw).to eq(translated_raw)
        expect(out.cooked).to eq(cooked)
      }.to_not change { PostLocalization.count }
    end
  end
end
