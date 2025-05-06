# frozen_string_literal: true

describe DiscourseTranslator::PostLocaleDetector do
  describe ".detect_locale" do
    fab!(:post) { Fabricate(:post, raw: "Hello world", locale: nil) }

    let(:translator) { mock }

    before { DiscourseTranslator::Provider::TranslatorProvider.stubs(:get).returns(translator) }

    it "returns nil if post is blank" do
      expect(described_class.detect_locale(nil)).to eq(nil)
    end

    it "calls detect! on the provider with the post" do
      translator.expects(:detect!).with(post).returns("ja")
      expect(described_class.detect_locale(post)).to eq("ja")
    end

    it "updates the post locale with the detected locale" do
      translator.stubs(:detect!).with(post).returns("ja")
      expect { described_class.detect_locale(post) }.to change { post.reload.locale }.from(nil).to(
        "ja",
      )
    end
  end
end
