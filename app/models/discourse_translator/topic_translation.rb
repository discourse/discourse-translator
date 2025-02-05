# frozen_string_literal: true

module DiscourseTranslator
  class TopicTranslation < ActiveRecord::Base
    self.table_name = "discourse_translator_topic_translations"

    belongs_to :topic

    validates :topic_id, presence: true
    validates :locale, presence: true
    validates :translation, presence: true
    validates :locale, uniqueness: { scope: :topic_id }

    def self.translation_for(topic_id, locale)
      find_by(topic_id: topic_id, locale: locale)&.translation
    end
  end
end
