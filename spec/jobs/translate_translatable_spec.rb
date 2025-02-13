# frozen_string_literal: true

RSpec.describe Jobs::TranslateTranslatable do
  fab!(:post) { Fabricate(:post) }
  fab!(:topic) { Fabricate(:topic) }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator = "Google"
    SiteSetting.automatic_translation_target_languages = "es|fr"
  end

  describe "#execute" do
    it "does nothing when translator is disabled" do
      SiteSetting.translator_enabled = false
      expect(DiscourseTranslator::Google).not_to receive(:translate)

      subject.execute(type: "Post", translatable_id: post.id)
    end

    it "does nothing when target languages are empty" do
      SiteSetting.automatic_translation_target_languages = ""
      expect(DiscourseTranslator::Google).not_to receive(:translate)

      subject.execute(type: "Post", translatable_id: post.id)
    end

    it "translates posts to configured target languages" do
      expect(DiscourseTranslator::Google).to receive(:translate).with(post, :es)
      expect(DiscourseTranslator::Google).to receive(:translate).with(post, :fr)
      expect(MessageBus).to receive(:publish).with(
        "/topic/#{post.topic_id}",
        type: :revised,
        id: post.id,
      )

      subject.execute(type: "Post", translatable_id: post.id)
    end

    it "translates topics to configured target languages" do
      expect(DiscourseTranslator::Google).to receive(:translate).with(topic, :es)
      expect(DiscourseTranslator::Google).to receive(:translate).with(topic, :fr)
      expect(MessageBus).to receive(:publish).with("/topic/#{topic.id}", type: :revised, id: 1)

      subject.execute(type: "Topic", translatable_id: topic.id)
    end

    it "does nothing when translatable is not found" do
      expect(DiscourseTranslator::Google).not_to receive(:translate)
      expect(MessageBus).not_to receive(:publish)

      subject.execute(type: "Post", translatable_id: -1)
    end
  end
end
