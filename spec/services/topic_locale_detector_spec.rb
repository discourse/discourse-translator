# frozen_string_literal: true

describe DiscourseTranslator::TopicLocaleDetector do
  describe ".detect_locale" do
    fab!(:topic) { Fabricate(:topic, title: "this is a cat topic", locale: nil) }

    let(:translator) { mock }

    before { DiscourseTranslator::Provider::TranslatorProvider.stubs(:get).returns(translator) }

    it "returns nil if topic is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "calls detect! on the provider with the topic" do
      translator.expects(:detect!).with(topic).returns("zh")
      expect(described_class.detect_locale(topic)).to eq("zh_CN")
    end

    it "updates the topic locale with the detected locale" do
      translator.stubs(:detect!).with(topic).returns("zh")
      expect { described_class.detect_locale(topic) }.to change { topic.reload.locale }.from(
        nil,
      ).to("zh_CN")
    end
  end
end
