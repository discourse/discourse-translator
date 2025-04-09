# frozen_string_literal: true

describe Jobs::TranslateTranslatable do
  fab!(:post)
  fab!(:topic)
  let!(:job) { Jobs::TranslateTranslatable.new }

  before do
    SiteSetting.translator_enabled = true
    SiteSetting.translator_provider = "Google"
    SiteSetting.automatic_translation_backfill_rate = 100
    SiteSetting.automatic_translation_target_languages = "es|fr"
    allow(DiscourseTranslator::Google).to receive(:translate)
  end

  describe "#execute" do
    it "does nothing when translator is disabled" do
      SiteSetting.translator_enabled = false

      job.execute(type: "Post", translatable_id: post.id)

      expect(DiscourseTranslator::Google).not_to have_received(:translate)
    end

    it "does nothing when target languages are empty" do
      SiteSetting.automatic_translation_target_languages = ""

      job.execute(type: "Post", translatable_id: post.id)

      expect(DiscourseTranslator::Google).not_to have_received(:translate)
    end

    it "translates posts to configured target languages" do
      MessageBus
        .expects(:publish)
        .with("/topic/#{post.topic.id}", type: :translated_post, id: post.id)
        .once

      job.execute(type: "Post", translatable_id: post.id)

      expect(DiscourseTranslator::Google).to have_received(:translate).with(post, :es)
      expect(DiscourseTranslator::Google).to have_received(:translate).with(post, :fr)
    end

    it "translates topics to configured target languages" do
      MessageBus.expects(:publish).with("/topic/#{topic.id}", type: :translated_post, id: 1).once

      job.execute(type: "Topic", translatable_id: topic.id)

      expect(DiscourseTranslator::Google).to have_received(:translate).with(topic, :es)
      expect(DiscourseTranslator::Google).to have_received(:translate).with(topic, :fr)
    end

    it "does nothing when translatable is not found" do
      MessageBus.expects(:publish).never

      job.execute(type: "Post", translatable_id: -1)

      expect(DiscourseTranslator::Google).not_to have_received(:translate)
    end
  end
end
