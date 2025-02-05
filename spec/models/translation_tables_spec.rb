# frozen_string_literal: true

require_relative "../../db/migrate/20250205082401_move_translations_custom_fields_to_table"

module DiscourseTranslator
  describe MoveTranslationsCustomFieldsToTable do
    let!(:batch_size) { 5 }

    before { described_class.const_set(:BATCH_SIZE, batch_size) }

    def create_custom_fields(count)
      count.times do
        post = Fabricate(:post)
        topic = Fabricate(:topic)

        post.custom_fields[DETECTED_LANG_CUSTOM_FIELD] = "pt"
        post.save_custom_fields

        topic.custom_fields[DETECTED_LANG_CUSTOM_FIELD] = "es"
        topic.save_custom_fields

        post.custom_fields[TRANSLATED_CUSTOM_FIELD] = {
          en_GB: "The Romance of the Three Kingdoms",
          de: "Die Romanze der Drei Königreiche",
        }
        post.save_custom_fields

        topic.custom_fields[TRANSLATED_CUSTOM_FIELD] = {
          en_GB: "The Romance of the Three Kingdoms",
          de: "Die Romanze der Drei Königreiche",
        }
        topic.save_custom_fields
      end
    end

    it "correctly migrates custom fields in batches" do
      # batch size is 5
      create_custom_fields(12)

      migration = described_class.new
      migration.up

      # 12 posts * 2 translations each
      expect(PostLocale.count).to eq(12)
      expect(PostTranslation.count).to eq(24)

      # 12 topics * 2 translations each
      expect(TopicLocale.count).to eq(12)
      expect(TopicTranslation.count).to eq(24)

      expect(PostLocale.first.detected_locale).to eq("pt")

      expect(PostTranslation.where(post_id: Post.first.id).pluck(:locale, :translation)).to include(
        ["en_GB", "The Romance of the Three Kingdoms"],
        ["de", "Die Romanze der Drei Königreiche"],
      )

      migration.down
      expect(PostLocale.count).to eq(0)
      expect(PostTranslation.count).to eq(0)
      expect(TopicLocale.count).to eq(0)
      expect(TopicTranslation.count).to eq(0)
    end

    it "ignores invalid JSON in translated_text" do
      post = Fabricate(:post)
      post.custom_fields[TRANSLATED_CUSTOM_FIELD] = "invalid json"
      post.save_custom_fields(true)

      migration = described_class.new
      expect { migration.up }.not_to raise_error
      expect(PostTranslation.count).to eq(0)
    end

    it "ignores translations with locale longer than 20 chars" do
      post = Fabricate(:post)
      post.custom_fields[TRANSLATED_CUSTOM_FIELD] = { very_very_long_locale_name: "test" }
      post.custom_fields[DETECTED_LANG_CUSTOM_FIELD] = "very_very_long_locale_name"
      post.save_custom_fields(true)

      migration = described_class.new
      migration.up
      expect(PostLocale.count).to eq(0)
      expect(PostTranslation.count).to eq(0)
    end
  end
end
