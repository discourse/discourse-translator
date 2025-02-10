# frozen_string_literal: true

require_relative "../../db/migrate/20250205082401_move_translations_custom_fields_to_table"

module DiscourseTranslator
  describe MoveTranslationsCustomFieldsToTable do
    DETECTED_LANG_CUSTOM_FIELD = "post_detected_lang".freeze
    TRANSLATED_CUSTOM_FIELD = "translated_text".freeze

    let!(:batch_size) { 3 }

    before { described_class.const_set(:BATCH_SIZE, batch_size) }

    def create_translation_custom_fields(count)
      count.times do
        t_post = Fabricate(:post)
        t_topic = Fabricate(:topic)

        t_post.custom_fields[DETECTED_LANG_CUSTOM_FIELD] = "pt"
        t_post.save_custom_fields

        t_topic.custom_fields[DETECTED_LANG_CUSTOM_FIELD] = "es"
        t_topic.save_custom_fields

        t_post.custom_fields[TRANSLATED_CUSTOM_FIELD] = {
          en_GB: "The Romance of the Three Kingdoms",
          de: "Die Romanze der Drei Königreiche",
        }
        t_post.save_custom_fields

        t_topic.custom_fields[TRANSLATED_CUSTOM_FIELD] = {
          en_GB: "The Romance of the Three Kingdoms",
          de: "Die Romanze der Drei Königreiche",
        }
        t_topic.save_custom_fields
      end
    end

    it "correctly migrates custom fields in batches" do
      # batch size is 3
      create_translation_custom_fields(4)
      # create some random custom fields in between
      # to test the migrate loop doesn't end prematurely
      4.times do
        post = Fabricate(:post)
        post.custom_fields["x"] = "x"
        post.save_custom_fields

        topic = Fabricate(:topic)
        topic.custom_fields["x"] = "x"
        topic.save_custom_fields
      end
      # another 4
      create_translation_custom_fields(4)

      migration = described_class.new
      migration.up

      expect(PostLocale.count).to eq(8)
      expect(PostTranslation.count).to eq(16)

      expect(TopicLocale.count).to eq(8)
      expect(TopicTranslation.count).to eq(16)

      expect(PostLocale.last.detected_locale).to eq("pt")

      expect(PostTranslation.where(post_id: Post.last.id).pluck(:locale, :translation)).to include(
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
      expect { migration.up }.not_to raise_error

      expect(PostLocale.count).to eq(0)
      expect(PostTranslation.count).to eq(0)
    end
  end
end
