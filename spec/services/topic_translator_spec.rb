# frozen_string_literal: true

describe DiscourseTranslator::TopicTranslator do
  describe ".translate" do
    fab!(:topic) do
      Fabricate(
        :topic,
        title: "this is a cat topic :)",
        excerpt: "cats are great. how many do you have?",
      )
    end
    let(:translator) { mock }
    let(:translated_title) { "これは猫の話題です :)" }
    let(:translated_excerpt) { "猫は素晴らしいですね。何匹飼っていますか？" }
    let(:fancy_title) { "これは猫の話題です :slight_smile:" }
    let(:target_locale) { "ja" }

    before do
      DiscourseTranslator::Provider::TranslatorProvider.stubs(:get).returns(translator)
      translator.stubs(:translate_topic!).with(topic, :ja).returns(translated_title)
      translator.stubs(:translate_text!).with(topic.excerpt, :ja).returns(translated_excerpt)
    end

    it "returns nil if topic is blank" do
      expect(described_class.translate(nil, "ja")).to eq(nil)
    end

    it "returns nil if target_locale is blank" do
      expect(described_class.translate(topic, nil)).to eq(nil)
      expect(described_class.translate(topic, "")).to eq(nil)
    end

    it "returns nil if target_locale is same as topic locale" do
      topic.locale = "en"

      expect(described_class.translate(topic, "en")).to eq(nil)
    end

    it "translates with topic and locale" do
      translator.expects(:translate_topic!).with(topic, :ja).returns(translated_title)
      translator.expects(:translate_text!).with(topic.excerpt, :ja).returns(translated_title)

      described_class.translate(topic, "ja")
    end

    it "normalizes dashes to underscores and symbol type for locale" do
      translator.expects(:translate_topic!).with(topic, :zh_CN).returns("这是一个猫主题 :)")
      translator.expects(:translate_text!).with(topic.excerpt, :zh_CN).returns("这是一个猫主题 :)")

      described_class.translate(topic, "zh-CN")
    end

    it "finds or creates a TopicLocalization and sets its fields" do
      expect {
        res = described_class.translate(topic, target_locale)
        expect(res).to be_a(TopicLocalization)
        expect(res).to have_attributes(
          topic_id: topic.id,
          locale: target_locale,
          title: translated_title,
          excerpt: translated_excerpt,
          fancy_title: fancy_title,
          localizer_user_id: Discourse.system_user.id,
        )
      }.to change { TopicLocalization.count }.by(1)
    end

    it "updates an existing TopicLocalization if present" do
      localization =
        Fabricate(
          :topic_localization,
          topic:,
          locale: "ja",
          title: "old title",
          excerpt: "old excerpt",
          fancy_title: "old_fancy_title",
        )
      expect {
        expect(described_class.translate(topic, "ja")).to have_attributes(
          id: localization.id,
          title: translated_title,
          fancy_title: fancy_title,
          excerpt: translated_excerpt,
        )
        expect(localization.reload).to have_attributes(
          title: translated_title,
          fancy_title: fancy_title,
          excerpt: translated_excerpt,
        )
      }.to_not change { TopicLocalization.count }
    end
  end
end
